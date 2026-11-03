import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/casting/domain/local_streaming_daemon.dart';
import 'package:app/features/casting/domain/cast_models.dart';

void main() {
  group('LocalStreamingDaemon Unit Tests', () {
    late Directory tempDir;
    late File dummyVideo;
    late File dummySrt;
    late LocalStreamingDaemon daemon;
    late HttpClient client;

    const sampleText = 'Welcome to E-Player Tokenized Casting!';
    final sampleBytes = List<int>.generate(2048, (i) => i % 256);
    const sampleSrt = '''1
00:00:01,000 --> 00:00:04,500
$sampleText

2
00:00:05,200 --> 00:00:08,800
Second Subtitle Cue
''';

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('daemon_test_');
      dummyVideo = File('${tempDir.path}/sample_video.mp4');
      await dummyVideo.writeAsBytes(sampleBytes);

      dummySrt = File('${tempDir.path}/sample_sub.srt');
      await dummySrt.writeAsString(sampleSrt);

      daemon = LocalStreamingDaemon();
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await daemon.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Binds loopback ephemeral port and generates valid 32-char hex session token', () async {
      final baseUrl = await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      expect(daemon.isRunning, isTrue);
      expect(daemon.host, '127.0.0.1');
      expect(daemon.port, isNotNull);
      expect(daemon.port, greaterThan(0));
      expect(daemon.sessionToken, isNotNull);
      expect(daemon.sessionToken!.length, 32);
      expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(daemon.sessionToken!), isTrue);
      expect(baseUrl, 'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/');
    });

    test('2. Constructs valid streamUrl and subtitleUrl endpoints matching spec', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        subtitlePath: dummySrt.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      expect(daemon.streamUrl, 'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/stream');
      expect(daemon.subtitleUrl, 'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/subtitles/track_0.vtt');
    });

    test('3. Delivers 200 OK full content when valid session token is provided without range', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
      expect(resp.headers.contentType?.mimeType, 'video/mp4');
      expect(resp.contentLength, sampleBytes.length);

      final body = await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      expect(body, sampleBytes);
    });

    test('4. Rejects request with 403 Forbidden when session token is invalid', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final badUrl = 'http://127.0.0.1:${daemon.port}/cast/invalid_session_token_123456789/stream';
      final req = await client.getUrl(Uri.parse(badUrl));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.forbidden);
      final body = await resp.transform(utf8.decoder).join();
      expect(body, contains('403 Forbidden'));
    });

    test('5. Rejects request with 403 Forbidden when session token is missing', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final missingTokenUrl = 'http://127.0.0.1:${daemon.port}/cast/';
      final req = await client.getUrl(Uri.parse(missingTokenUrl));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.forbidden);
    });

    test('6. Rejects path traversal attack with 400 Bad Request', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      // Traversal using raw socket with Connection: close
      final socket = await Socket.connect('127.0.0.1', daemon.port!);
      socket.write('GET /cast/${daemon.sessionToken}/../secret HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
      await socket.flush();

      final responseStr = await utf8.decodeStream(socket);
      await socket.close();

      expect(
        responseStr.contains('400 Bad Request') || responseStr.contains('403 Forbidden'),
        isTrue,
      );

      // Also test traversal via HttpClient
      final traversalUrl = 'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/../secret';
      final req = await client.getUrl(Uri.parse(traversalUrl));
      final resp = await req.close();
      expect(resp.statusCode, inInclusiveRange(400, 404));
    });

    test('7. Handles HTTP 206 Partial Content range bytes=0-1023', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.partialContent);
      expect(resp.headers.value(HttpHeaders.contentRangeHeader), 'bytes 0-1023/${sampleBytes.length}');
      expect(resp.contentLength, 1024);

      final body = await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      expect(body.length, 1024);
      expect(body, sampleBytes.sublist(0, 1024));
    });

    test('8. Handles open-ended HTTP 206 range bytes=1000-', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=1000-');
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.partialContent);
      expect(resp.contentLength, sampleBytes.length - 1000);
      expect(
        resp.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 1000-${sampleBytes.length - 1}/${sampleBytes.length}',
      );

      final body = await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      expect(body, sampleBytes.sublist(1000));
    });

    test('9. Handles boundary range slices bytes=0-0 and bytes=last-last', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      // Single first byte
      var req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      var resp = await req.close();
      expect(resp.statusCode, HttpStatus.partialContent);
      expect(resp.contentLength, 1);
      var body = await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      expect(body, [sampleBytes[0]]);

      // Single last byte
      final lastIdx = sampleBytes.length - 1;
      req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=$lastIdx-$lastIdx');
      resp = await req.close();
      expect(resp.statusCode, HttpStatus.partialContent);
      expect(resp.contentLength, 1);
      body = await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      expect(body, [sampleBytes[lastIdx]]);
    });

    test('10. Returns 416 Requested Range Not Satisfiable for out-of-bounds byte range', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=99999-99999');
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(resp.headers.value(HttpHeaders.contentRangeHeader), 'bytes */${sampleBytes.length}');
    });

    test('11. Gracefully falls back to 200 OK on malformed or non-bytes Range headers', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      req.headers.set(HttpHeaders.rangeHeader, 'malformed-range-syntax');
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.contentLength, sampleBytes.length);
    });

    test('12. Delivers converted WebVTT sidecar with text/vtt and no-cache header', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        subtitlePath: dummySrt.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final req = await client.getUrl(Uri.parse(daemon.subtitleUrl!));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.headers.contentType?.mimeType, 'text/vtt');
      expect(resp.headers.value(HttpHeaders.cacheControlHeader), 'no-cache');

      final text = await resp.transform(utf8.decoder).join();
      expect(text.startsWith('WEBVTT'), isTrue);
      expect(text, contains('00:00:01.000 --> 00:00:04.500'));
      expect(text, contains('00:00:05.200 --> 00:00:08.800'));
      expect(text, contains(sampleText));
    });

    test('13. convertSrtToVtt transforms comma timecodes to period decimal notation', () {
      const srt = '1\n01:23:45,678 --> 01:23:49,999\nTest Cue Line';
      final vtt = LocalStreamingDaemon.convertSrtToVtt(srt);
      expect(vtt.startsWith('WEBVTT\n\n'), isTrue);
      expect(vtt, contains('01:23:45.678 --> 01:23:49.999'));
      expect(vtt, contains('Test Cue Line'));

      // Idempotent when already WebVTT
      final vttAgain = LocalStreamingDaemon.convertSrtToVtt(vtt);
      expect(vttAgain, vtt);
    });

    test('14. Subtitle request with invalid session token is rejected with 403 Forbidden', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        subtitlePath: dummySrt.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final badSubUrl = 'http://127.0.0.1:${daemon.port}/cast/bad_token_123/subtitles/track_0.vtt';
      final req = await client.getUrl(Uri.parse(badSubUrl));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.forbidden);
    });

    test('15. Emits real-time StreamingClientTelemetry events during requests', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );

      final telemetryFuture = daemon.telemetryStream.first;

      final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-511');
      final resp = await req.close();
      await resp.drain();

      final telem = await telemetryFuture;
      expect(telem, isA<StreamingClientTelemetry>());
      expect(telem.statusCode, HttpStatus.partialContent);
      expect(telem.bytesTransferred, 512);
      expect(telem.path, contains('/stream'));
      expect(telem.rangeHeader, 'bytes=0-511');
      expect(telem.duration, greaterThanOrEqualTo(Duration.zero));
    });

    test('16. stopSession terminates HTTP server and releases bound port', () async {
      await daemon.startSession(
        filePath: dummyVideo.path,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      final boundPort = daemon.port!;
      expect(daemon.isRunning, isTrue);

      await daemon.stopSession();
      expect(daemon.isRunning, isFalse);
      expect(daemon.port, isNull);
      expect(daemon.streamUrl, isNull);

      // Verify port is no longer actively responding
      expect(
        () async {
          final req = await client.getUrl(Uri.parse('http://127.0.0.1:$boundPort/test'));
          await req.close();
        },
        throwsA(isA<SocketException>()),
      );
    });

    test('17. Offline IP validation correctly validates LAN and rejects public WAN', () {
      expect(LocalStreamingDaemon.isPrivateLanIp('127.0.0.1'), isTrue);
      expect(LocalStreamingDaemon.isPrivateLanIp('localhost'), isTrue);
      expect(LocalStreamingDaemon.isPrivateLanIp('192.168.1.15'), isTrue);
      expect(LocalStreamingDaemon.isPrivateLanIp('10.0.0.42'), isTrue);
      expect(LocalStreamingDaemon.isPrivateLanIp('172.20.10.5'), isTrue);

      // WAN / Public addresses rejected
      expect(LocalStreamingDaemon.isPrivateLanIp('8.8.8.8'), isFalse);
      expect(LocalStreamingDaemon.isPrivateLanIp('1.1.1.1'), isFalse);
      expect(LocalStreamingDaemon.isPrivateLanIp('172.35.0.1'), isFalse);
      expect(LocalStreamingDaemon.isPrivateLanIp('api.cloudservice.com'), isFalse);
    });
  });
}
