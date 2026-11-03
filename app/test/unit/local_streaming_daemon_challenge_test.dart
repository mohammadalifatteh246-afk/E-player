import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/casting/domain/local_streaming_daemon.dart';
import 'package:app/features/casting/domain/cast_models.dart';

void main() {
  group('Milestone 4 Adversarial Challenge: LocalStreamingDaemon', () {
    late Directory tempDir;
    late File dummyVideo;
    late File dummySrt;
    late LocalStreamingDaemon daemon;
    late HttpClient client;

    const sampleText = 'Adversarial Subtitle Verification Payload';
    // 2048 bytes of deterministic binary payload
    final sampleBytes = List<int>.generate(2048, (i) => (i * 7) % 256);
    const sampleSrt = '''1
00:00:01,234 --> 00:00:05,678
$sampleText

2
00:00:06,000 --> 00:00:10,000
Second Cue For Testing
''';

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('daemon_challenge_');
      dummyVideo = File('${tempDir.path}/media_payload.mp4');
      await dummyVideo.writeAsBytes(sampleBytes);

      dummySrt = File('${tempDir.path}/media_payload.srt');
      await dummySrt.writeAsString(sampleSrt);

      daemon = LocalStreamingDaemon();
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await daemon.dispose();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    // =========================================================================
    // SECTION 1: HTTP 206 RANGE HANDLING ADVERSARIAL CHALLENGES
    // =========================================================================
    group('Section 1: HTTP 206 Range Handling Adversarial Attacks', () {
      test('1.1 Inverted Range (start > end) returns 416 with Content-Range: bytes */total', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final testCases = [
          'bytes=500-100',
          'bytes=2047-0',
          'bytes=1-0',
          'bytes=1000-500',
          'bytes=2048-10',
        ];

        for (final header in testCases) {
          final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
          req.headers.set(HttpHeaders.rangeHeader, header);
          final resp = await req.close();

          expect(
            resp.statusCode,
            HttpStatus.requestedRangeNotSatisfiable,
            reason: 'Header "$header" must trigger HTTP 416',
          );
          expect(
            resp.headers.value(HttpHeaders.contentRangeHeader),
            'bytes */${sampleBytes.length}',
            reason: 'HTTP 416 must include Content-Range: bytes */total',
          );
          await resp.drain();
        }
      });

      test('1.2 End exceeding file size returns 416 with Content-Range: bytes */total', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final testCases = [
          'bytes=0-999999',
          'bytes=0-${sampleBytes.length}', // end == totalSize (out of bounds, 0-indexed)
          'bytes=1000-5000',
          'bytes=${sampleBytes.length}-${sampleBytes.length + 100}',
          'bytes=2047-2048',
        ];

        for (final header in testCases) {
          final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
          req.headers.set(HttpHeaders.rangeHeader, header);
          final resp = await req.close();

          expect(
            resp.statusCode,
            HttpStatus.requestedRangeNotSatisfiable,
            reason: 'Range exceeding totalSize "$header" must trigger HTTP 416',
          );
          expect(
            resp.headers.value(HttpHeaders.contentRangeHeader),
            'bytes */${sampleBytes.length}',
          );
          await resp.drain();
        }
      });

      test('1.3 Start at or exceeding totalSize returns 416', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final testCases = [
          'bytes=${sampleBytes.length}-', // start == totalSize
          'bytes=${sampleBytes.length + 1}-',
          'bytes=999999-',
          'bytes=${sampleBytes.length}-${sampleBytes.length}',
        ];

        for (final header in testCases) {
          final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
          req.headers.set(HttpHeaders.rangeHeader, header);
          final resp = await req.close();

          expect(
            resp.statusCode,
            HttpStatus.requestedRangeNotSatisfiable,
            reason: 'Start >= totalSize "$header" must return 416',
          );
          expect(
            resp.headers.value(HttpHeaders.contentRangeHeader),
            'bytes */${sampleBytes.length}',
          );
          await resp.drain();
        }
      });

      test('1.4 Zero-length single byte boundary ranges (0-0, mid-mid, last-last)', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        // First byte: 0-0
        var req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        var resp = await req.close();
        expect(resp.statusCode, HttpStatus.partialContent);
        expect(resp.contentLength, 1);
        expect(resp.headers.value(HttpHeaders.contentRangeHeader), 'bytes 0-0/${sampleBytes.length}');
        var body = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(body, [sampleBytes[0]]);

        // Mid byte: 1024-1024
        req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=1024-1024');
        resp = await req.close();
        expect(resp.statusCode, HttpStatus.partialContent);
        expect(resp.contentLength, 1);
        expect(resp.headers.value(HttpHeaders.contentRangeHeader), 'bytes 1024-1024/${sampleBytes.length}');
        body = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(body, [sampleBytes[1024]]);

        // Last byte: 2047-2047
        final lastIdx = sampleBytes.length - 1;
        req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$lastIdx-$lastIdx');
        resp = await req.close();
        expect(resp.statusCode, HttpStatus.partialContent);
        expect(resp.contentLength, 1);
        expect(resp.headers.value(HttpHeaders.contentRangeHeader), 'bytes $lastIdx-$lastIdx/${sampleBytes.length}');
        body = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(body, [sampleBytes[lastIdx]]);
      });

      test('1.5 Open-ended ranges (0-, 1-, last-)', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        // 0- (entire file via range)
        var req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
        var resp = await req.close();
        expect(resp.statusCode, HttpStatus.partialContent);
        expect(resp.contentLength, sampleBytes.length);
        expect(
          resp.headers.value(HttpHeaders.contentRangeHeader),
          'bytes 0-${sampleBytes.length - 1}/${sampleBytes.length}',
        );
        var body = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(body, sampleBytes);

        // 512-
        req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=512-');
        resp = await req.close();
        expect(resp.statusCode, HttpStatus.partialContent);
        expect(resp.contentLength, sampleBytes.length - 512);
        body = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(body, sampleBytes.sublist(512));

        // Last byte via open-ended: 2047-
        final lastIdx = sampleBytes.length - 1;
        req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$lastIdx-');
        resp = await req.close();
        expect(resp.statusCode, HttpStatus.partialContent);
        expect(resp.contentLength, 1);
        body = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(body, [sampleBytes[lastIdx]]);
      });

      test('1.6 Negative start handling and malformed range specs fallback or reject safely', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        // Negative start in parts: bytes=-100 (suffix range parsed as 0-100 or rejected)
        var req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=-100');
        var resp = await req.close();
        expect(
          resp.statusCode == HttpStatus.partialContent ||
              resp.statusCode == HttpStatus.requestedRangeNotSatisfiable ||
              resp.statusCode == HttpStatus.ok,
          isTrue,
        );
        await resp.drain();

        // Non-numeric range: bytes=abc-xyz
        req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=abc-xyz');
        resp = await req.close();
        expect(
          resp.statusCode == HttpStatus.partialContent || resp.statusCode == HttpStatus.ok,
          isTrue,
        );
        await resp.drain();

        // Multiple dashes: bytes=1-2-3
        req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=1-2-3');
        resp = await req.close();
        expect(
          resp.statusCode == HttpStatus.partialContent ||
              resp.statusCode == HttpStatus.requestedRangeNotSatisfiable ||
              resp.statusCode == HttpStatus.ok,
          isTrue,
        );
        await resp.drain();
      });
    });

    // =========================================================================
    // SECTION 2: SESSION TOKEN SECURITY ADVERSARIAL CHALLENGES
    // =========================================================================
    group('Section 2: Session Token Security Adversarial Attacks', () {
      test('2.1 Empty and missing session tokens return 403 Forbidden', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final emptyEndpoints = [
          'http://127.0.0.1:${daemon.port}/cast//stream',
          'http://127.0.0.1:${daemon.port}/cast/',
          'http://127.0.0.1:${daemon.port}/cast//subtitles/track_0.vtt',
          'http://127.0.0.1:${daemon.port}/',
          'http://127.0.0.1:${daemon.port}/stream',
        ];

        for (final url in emptyEndpoints) {
          final req = await client.getUrl(Uri.parse(url));
          final resp = await req.close();
          expect(
            resp.statusCode,
            anyOf(HttpStatus.forbidden, HttpStatus.notFound, HttpStatus.badRequest),
            reason: 'Empty token on "$url" must be rejected with 403/404/400',
          );
          await resp.drain();
        }
      });

      test('2.2 Tokens with path separators return 403 Forbidden or 400 Bad Request', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final separatorEndpoints = [
          'http://127.0.0.1:${daemon.port}/cast/prefix/suffix/stream',
          'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/extra/stream',
          'http://127.0.0.1:${daemon.port}/cast/a/b/c/d/stream',
        ];

        for (final url in separatorEndpoints) {
          final req = await client.getUrl(Uri.parse(url));
          final resp = await req.close();
          expect(
            resp.statusCode,
            anyOf(HttpStatus.forbidden, HttpStatus.notFound, HttpStatus.badRequest),
          );
          await resp.drain();
        }
      });

      test('2.3 Tokens of incorrect lengths are strictly rejected with 403 Forbidden', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final badLengthTokens = [
          'a', // 1 char
          '0123456789abcdef', // 16 chars
          '0123456789abcdef0123456789abcde', // 31 chars
          '0123456789abcdef0123456789abcdef0', // 33 chars
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', // 64 chars
        ];

        for (final token in badLengthTokens) {
          final url = 'http://127.0.0.1:${daemon.port}/cast/$token/stream';
          final req = await client.getUrl(Uri.parse(url));
          final resp = await req.close();
          expect(resp.statusCode, HttpStatus.forbidden);
          final body = await resp.transform(utf8.decoder).join();
          expect(body, contains('403 Forbidden'));
        }
      });

      test('2.4 Random 32-char tokens and non-hex tokens return 403 Forbidden', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final randomTokens = [
          '00000000000000000000000000000000',
          'ffffffffffffffffffffffffffffffff',
          '11112222333344445555666677778888',
          'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz', // non-hex
          '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!', // punctuation
        ];

        for (final token in randomTokens) {
          final url = 'http://127.0.0.1:${daemon.port}/cast/$token/stream';
          final req = await client.getUrl(Uri.parse(url));
          final resp = await req.close();
          expect(resp.statusCode, HttpStatus.forbidden);
          await resp.drain();
        }
      });

      test('2.5 URL-encoded tokens with control chars or non-matching representations', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final encodedTokens = [
          '%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20%20',
          '%00' * 32,
          'token%2fwith%2fslashes',
          'token%00nullbyte',
        ];

        for (final token in encodedTokens) {
          final url = 'http://127.0.0.1:${daemon.port}/cast/$token/stream';
          final req = await client.getUrl(Uri.parse(url));
          final resp = await req.close();
          expect(
            resp.statusCode,
            anyOf(HttpStatus.forbidden, HttpStatus.badRequest),
          );
          await resp.drain();
        }
      });
    });

    // =========================================================================
    // SECTION 3: PATH TRAVERSAL ADVERSARIAL CHALLENGES
    // =========================================================================
    group('Section 3: Path Traversal Adversarial Attacks', () {
      test('3.1 Rejects dot-dot path traversal via standard HTTP client', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final traversalUrls = [
          'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/../secret',
          'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/../../etc/passwd',
          'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/stream/..',
          'http://127.0.0.1:${daemon.port}/cast/${daemon.sessionToken}/subtitles/../../windows/win.ini',
        ];

        for (final url in traversalUrls) {
          final req = await client.getUrl(Uri.parse(url));
          final resp = await req.close();
          expect(
            resp.statusCode,
            anyOf(HttpStatus.badRequest, HttpStatus.forbidden, HttpStatus.notFound),
            reason: 'Traversal url "$url" must be rejected',
          );
          await resp.drain();
        }
      });

      test('3.2.1 Rejects dot-dot path traversal via raw TCP socket (/../../../etc/passwd)', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final socket = await Socket.connect('127.0.0.1', daemon.port!);
        socket.write('GET /cast/${daemon.sessionToken}/../../../etc/passwd HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
        await socket.flush();

        final bytes = await socket.fold<List<int>>([], (a, b) => a..addAll(b));
        final responseStr = String.fromCharCodes(bytes);
        await socket.close();

        expect(
          responseStr.contains('400 Bad Request') ||
              responseStr.contains('403 Forbidden') ||
              responseStr.contains('404 Not Found'),
          isTrue,
        );
      });

      test('3.2.2 Rejects percent-encoded slash traversal via raw TCP socket (..%2f..%2fsecret)', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final socket = await Socket.connect('127.0.0.1', daemon.port!);
        socket.write('GET /cast/${daemon.sessionToken}/..%2f..%2fsecret HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
        await socket.flush();

        final bytes = await socket.fold<List<int>>([], (a, b) => a..addAll(b));
        final responseStr = String.fromCharCodes(bytes);
        await socket.close();

        expect(
          responseStr.contains('400 Bad Request') ||
              responseStr.contains('403 Forbidden') ||
              responseStr.contains('404 Not Found'),
          isTrue,
        );
      });

      test('3.2.3 Rejects percent-encoded dot traversal via raw TCP socket (%2e%2e/%2e%2e/stream)', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final socket = await Socket.connect('127.0.0.1', daemon.port!);
        socket.write('GET /cast/%2e%2e/%2e%2e/stream HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
        await socket.flush();

        final bytes = await socket.fold<List<int>>([], (a, b) => a..addAll(b));
        final responseStr = String.fromCharCodes(bytes);
        await socket.close();

        expect(
          responseStr.contains('400 Bad Request') ||
              responseStr.contains('403 Forbidden') ||
              responseStr.contains('404 Not Found'),
          isTrue,
        );
      });

      test('3.2.4 Rejects breakout traversal via raw TCP socket (/cast/{token}/../../../)', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final socket = await Socket.connect('127.0.0.1', daemon.port!);
        socket.write('GET /cast/${daemon.sessionToken}/../../../ HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
        await socket.flush();

        final bytes = await socket.fold<List<int>>([], (a, b) => a..addAll(b));
        final responseStr = String.fromCharCodes(bytes);
        await socket.close();

        expect(
          responseStr.contains('400 Bad Request') ||
              responseStr.contains('403 Forbidden'),
          isTrue,
          reason: 'Expected 400 Bad Request or 403 Forbidden, got: $responseStr',
        );
      });

      test('3.2.5 Rejects query param traversal via raw TCP socket (?param=../../secret)', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final socket = await Socket.connect('127.0.0.1', daemon.port!);
        socket.write('GET /cast/${daemon.sessionToken}/stream?param=../../secret HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
        await socket.flush();

        final bytes = await socket.fold<List<int>>([], (a, b) => a..addAll(b));
        final responseStr = String.fromCharCodes(bytes);
        await socket.close();

        expect(
          responseStr.contains('400 Bad Request') ||
              responseStr.contains('403 Forbidden') ||
              responseStr.contains('404 Not Found'),
          isTrue,
        );
      });
    });

    // =========================================================================
    // SECTION 4: STRESS, CONCURRENCY & STREAM INTEGRITY
    // =========================================================================
    group('Section 4: Stress, Concurrency & Stream Lifecycle Integrity', () {
      test('4.1 Rapid sequential range seeks execute without socket exhaustion or stream corruption', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        for (int i = 0; i < 50; i++) {
          final start = (i * 37) % 1500;
          final end = start + 256;
          final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
          final resp = await req.close();

          expect(resp.statusCode, HttpStatus.partialContent);
          expect(resp.contentLength, 257);
          final chunk = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
          expect(chunk, sampleBytes.sublist(start, end + 1));
        }
      });

      test('4.2 Abrupt client disconnection mid-stream does not crash the daemon', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        // Connect raw socket, start streaming, and destroy socket abruptly
        final socket = await Socket.connect('127.0.0.1', daemon.port!);
        socket.write(
          'GET /cast/${daemon.sessionToken}/stream HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n',
        );
        await socket.flush();

        // Read minimal bytes then abruptly destroy socket
        final sub = socket.listen((data) {});
        await Future.delayed(const Duration(milliseconds: 20));
        await sub.cancel();
        socket.destroy();

        // Daemon must remain alive and responsive to subsequent requests
        await Future.delayed(const Duration(milliseconds: 50));
        expect(daemon.isRunning, isTrue);

        final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        final resp = await req.close();
        expect(resp.statusCode, HttpStatus.ok);
        await resp.drain();
      });

      test('4.3 Daemon start and stop recycling handles port reuse cleanly', () async {
        for (int i = 0; i < 5; i++) {
          final url = await daemon.startSession(
            filePath: dummyVideo.path,
            bindAddress: InternetAddress.loopbackIPv4,
          );
          expect(daemon.isRunning, isTrue);
          expect(url, startsWith('http://127.0.0.1:'));

          final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
          final resp = await req.close();
          expect(resp.statusCode, HttpStatus.ok);
          await resp.drain();

          await daemon.stopSession();
          expect(daemon.isRunning, isFalse);
        }
      });

      test('4.4 Non-existent video file path returns 404 Not Found cleanly without crash', () async {
        await daemon.startSession(
          filePath: '${tempDir.path}/non_existent_file.mp4',
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        final resp = await req.close();
        expect(resp.statusCode, HttpStatus.notFound);
        await resp.drain();
      });

      test('4.5 Non-existent subtitle file falls back to empty valid WEBVTT sidecar', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          subtitlePath: '${tempDir.path}/missing_sub.srt',
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final req = await client.getUrl(Uri.parse(daemon.subtitleUrl!));
        final resp = await req.close();
        expect(resp.statusCode, HttpStatus.ok);
        final body = await resp.transform(utf8.decoder).join();
        expect(body.trim(), 'WEBVTT');
      });

      test('4.6 Telemetry emissions under rapid load contain accurate byte counts and status codes', () async {
        await daemon.startSession(
          filePath: dummyVideo.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final telemetryEvents = <StreamingClientTelemetry>[];
        final sub = daemon.telemetryStream.listen(telemetryEvents.add);

        final req1 = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req1.headers.set(HttpHeaders.rangeHeader, 'bytes=0-127');
        final resp1 = await req1.close();
        await resp1.drain();

        final req2 = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req2.headers.set(HttpHeaders.rangeHeader, 'bytes=9999-9999'); // 416
        final resp2 = await req2.close();
        await resp2.drain();

        await Future.delayed(const Duration(milliseconds: 50));
        await sub.cancel();

        expect(telemetryEvents.length, 2);
        expect(telemetryEvents[0].statusCode, HttpStatus.partialContent);
        expect(telemetryEvents[0].bytesTransferred, 128);
        expect(telemetryEvents[1].statusCode, HttpStatus.requestedRangeNotSatisfiable);
      });

      test('4.7 Zero-byte media file handles full stream (200 OK) and range (416) safely', () async {
        final zeroByteFile = File('${tempDir.path}/empty_media.mp4');
        await zeroByteFile.writeAsBytes([]);

        await daemon.startSession(
          filePath: zeroByteFile.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        // Full content request
        var req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        var resp = await req.close();
        expect(resp.statusCode, HttpStatus.ok);
        expect(resp.contentLength, 0);
        var body = await resp.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(body.isEmpty, isTrue);

        // Range request on empty file
        req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        resp = await req.close();
        expect(resp.statusCode, HttpStatus.requestedRangeNotSatisfiable);
        expect(resp.headers.value(HttpHeaders.contentRangeHeader), 'bytes */0');
        await resp.drain();
      });
    });
  });
}
