import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  group('Milestone 4 Adversarial Challenge: Offline Invariants & Network Isolation', () {
    late Directory tempDir;
    late File dummyMedia;
    late HttpClient client;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('m4_challenge_offline_');
      dummyMedia = File('${tempDir.path}/test_stream.mp4');
      await dummyMedia.writeAsBytes(List<int>.generate(1024, (i) => i % 128));
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // -------------------------------------------------------------------------
    // Challenge 1.1: isPrivateLanIp rejects public WAN IPs and Cloud Domains
    // -------------------------------------------------------------------------
    test('1.1: isPrivateLanIp rigorously rejects all public WAN IPs and cloud hostnames', () {
      final publicIps = [
        '8.8.8.8',
        '8.8.4.4',
        '1.1.1.1',
        '1.0.0.1',
        '142.250.190.46', // google.com
        '208.67.222.222', // OpenDNS
        '13.107.42.14',   // Microsoft
        '151.101.1.69',   // Fastly CDN
        '104.244.42.1',   // Twitter / X
        '172.15.255.255', // Just below Class B private (172.16)
        '172.32.0.1',     // Just above Class B private (172.31)
        '100.64.0.1',     // CGNAT (RFC 6598) - WAN scope
        '169.254.1.1',    // Link-local / APIPA
        '192.169.1.1',    // Adjacent to 192.168
        '11.0.0.1',       // Adjacent to 10.0
        '9.255.255.255',  // Adjacent to 10.0
        '0.0.0.0',
        '255.255.255.255',
      ];

      for (final ip in publicIps) {
        expect(
          LocalStreamingDaemon.isPrivateLanIp(ip),
          isFalse,
          reason: 'Public IP $ip must be rejected by isPrivateLanIp',
        );
      }

      final cloudHostnames = [
        'google.com',
        'api.telemetry.example.com',
        'telemetry.sink.com',
        'analytics.google.com',
        'stream.cloudflare.com',
        'aws.amazon.com',
        'azure.microsoft.com',
        'tracker.cdn.net',
        '',
        '   ',
        'invalid..ip',
      ];

      for (final host in cloudHostnames) {
        expect(
          LocalStreamingDaemon.isPrivateLanIp(host),
          isFalse,
          reason: 'Cloud hostname / invalid string "$host" must be rejected',
        );
      }
    });

    // -------------------------------------------------------------------------
    // Challenge 1.2: isPrivateLanIp accepts legitimate offline private LAN IPs
    // -------------------------------------------------------------------------
    test('1.2: isPrivateLanIp accepts loopback and standard RFC1918 private subnets', () {
      final validPrivateIps = [
        '127.0.0.1',
        'localhost',
        '::1',
        // 192.168.0.0/16
        '192.168.0.1',
        '192.168.1.1',
        '192.168.1.100',
        '192.168.254.254',
        '192.168.255.255',
        // 10.0.0.0/8
        '10.0.0.1',
        '10.0.0.254',
        '10.10.10.10',
        '10.255.255.255',
        // 172.16.0.0/12 (172.16.0.0 – 172.31.255.255)
        '172.16.0.1',
        '172.20.10.5',
        '172.28.1.50',
        '172.31.255.254',
        '172.31.255.255',
      ];

      for (final ip in validPrivateIps) {
        expect(
          LocalStreamingDaemon.isPrivateLanIp(ip),
          isTrue,
          reason: 'Private LAN IP $ip must be accepted by isPrivateLanIp',
        );
      }
    });

    // -------------------------------------------------------------------------
    // Challenge 1.3: resolveBindAddress rejects public IP even if preferred
    // -------------------------------------------------------------------------
    test('1.3: resolveBindAddress rejects preferred public WAN IP and falls back safely', () async {
      // Attempting to pass public WAN addresses as preferred address
      final publicAddress = InternetAddress('8.8.8.8');
      final resolved = await LocalStreamingDaemon.resolveBindAddress(
        preferredAddress: publicAddress,
      );

      // Must NOT be 8.8.8.8
      expect(resolved.address, isNot('8.8.8.8'));
      // Must be a private LAN or loopback IP
      expect(
        resolved.isLoopback || LocalStreamingDaemon.isPrivateLanIp(resolved.address),
        isTrue,
        reason: 'Resolved address must be private LAN or loopback',
      );
    });

    // -------------------------------------------------------------------------
    // Challenge 1.4: LocalStreamingDaemon server binds only to offline private interface
    // -------------------------------------------------------------------------
    test('1.4: LocalStreamingDaemon server binds strictly to private LAN/loopback and makes zero WAN calls', () async {
      final daemon = LocalStreamingDaemon();
      try {
        final baseUrl = await daemon.startSession(
          filePath: dummyMedia.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        expect(daemon.isRunning, isTrue);
        expect(daemon.host, '127.0.0.1');
        expect(baseUrl, startsWith('http://127.0.0.1:'));
        expect(LocalStreamingDaemon.isPrivateLanIp(daemon.host!), isTrue);

        // Make an HTTP request to ensure server responds locally
        final req = await client.getUrl(Uri.parse(daemon.streamUrl!));
        final resp = await req.close();
        expect(resp.statusCode, HttpStatus.ok);
        await resp.drain();
      } finally {
        await daemon.dispose();
      }
    });

    // -------------------------------------------------------------------------
    // Challenge 1.5: CastService discovery list and protocol sinks are 100% LAN scoped
    // -------------------------------------------------------------------------
    test('1.5: CastService sink inventory contains only private LAN IP addresses with zero WAN telemetry', () async {
      final castService = CastService();
      try {
        expect(castService.devices.isNotEmpty, isTrue);

        // Every discovered device must be on a private LAN subnet
        for (final device in castService.devices) {
          expect(
            LocalStreamingDaemon.isPrivateLanIp(device.ipAddress),
            isTrue,
            reason: 'Cast device "${device.name}" IP ${device.ipAddress} must be private LAN',
          );
        }

        // Connecting to device starts local daemon on private interface
        final target = castService.devices.first;
        final connected = await castService.connect(
          target,
          mediaPath: dummyMedia.path,
        );
        expect(connected, isTrue);
        expect(castService.activeSession, isNotNull);
        expect(castService.activeSession!.streamUrl, isNotNull);

        final streamUri = Uri.parse(castService.activeSession!.streamUrl!);
        expect(LocalStreamingDaemon.isPrivateLanIp(streamUri.host), isTrue);
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(streamUri), isTrue);

        // Bi-directional state operations remain strictly local
        castService.setRemoteVolume(0.9);
        castService.toggleMute();
        castService.seek(const Duration(seconds: 12));
        expect(castService.activeSession!.volume, 0.9);
        expect(castService.activeSession!.isMuted, isTrue);
        expect(castService.activeSession!.position, const Duration(seconds: 12));

        await castService.disconnect();
        expect(castService.activeSession, isNull);
        expect(castService.streamingDaemon.isRunning, isFalse);
      } finally {
        castService.dispose();
      }
    });

    // -------------------------------------------------------------------------
    // Challenge 1.6: OfflineSecurityValidator parity test
    // -------------------------------------------------------------------------
    test('1.6: OfflineSecurityValidator rejects all WAN URIs and accepts private LAN URIs', () {
      final wanUris = [
        Uri.parse('http://8.8.8.8:8080/cast/stream'),
        Uri.parse('http://1.1.1.1/cast/stream'),
        Uri.parse('https://api.telemetry.sink.com/ping'),
        Uri.parse('http://142.250.190.46:8080/media'),
        Uri.parse('http://172.35.0.1:8080/stream'),
      ];

      for (final uri in wanUris) {
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isFalse);
      }

      final lanUris = [
        Uri.parse('http://127.0.0.1:8080/cast/stream'),
        Uri.parse('http://localhost:8080/cast/stream'),
        Uri.parse('http://192.168.1.100:8080/cast/stream'),
        Uri.parse('http://10.0.0.1:8080/cast/stream'),
        Uri.parse('http://172.16.0.1:8080/cast/stream'),
        Uri.parse('http://172.31.255.254:8080/cast/stream'),
      ];

      for (final uri in lanUris) {
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
      }
    });
  });

  group('Milestone 4 Adversarial Challenge: WebVTT Subtitle Conversion & Fidelity', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('m4_challenge_vtt_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // -------------------------------------------------------------------------
    // Challenge 2.1: Standard comma timecode conversion
    // -------------------------------------------------------------------------
    test('2.1: Comma timecodes (00:01:23,456) converted to dot decimal (00:01:23.456)', () {
      const srt = '''1
00:01:23,456 --> 00:01:28,789
Standard dialogue line.
''';

      final vtt = LocalStreamingDaemon.convertSrtToVtt(srt);
      expect(vtt.startsWith('WEBVTT\n\n'), isTrue);
      expect(vtt, contains('00:01:23.456 --> 00:01:28.789'));
      expect(vtt, contains('Standard dialogue line.'));
      expect(vtt, isNot(contains('00:01:23,456')));
      expect(vtt, isNot(contains('00:01:28,789')));
    });

    // -------------------------------------------------------------------------
    // Challenge 2.2: Boundary and multi-hour timecodes
    // -------------------------------------------------------------------------
    test('2.2: Zero-boundary and multi-hour timecodes converted accurately', () {
      const srt = '''1
00:00:00,000 --> 00:00:00,001
First millisecond

2
01:59:59,999 --> 02:00:00,000
Hour transition

3
99:59:59,000 --> 99:59:59,999
Extreme upper bound
''';

      final vtt = LocalStreamingDaemon.convertSrtToVtt(srt);
      expect(vtt.startsWith('WEBVTT\n\n'), isTrue);
      expect(vtt, contains('00:00:00.000 --> 00:00:00.001'));
      expect(vtt, contains('01:59:59.999 --> 02:00:00.000'));
      expect(vtt, contains('99:59:59.000 --> 99:59:59.999'));
    });

    // -------------------------------------------------------------------------
    // Challenge 2.3: Multi-line cues preservation
    // -------------------------------------------------------------------------
    test('2.3: Multi-line cues with complex dialogue and formatting remain intact', () {
      const srt = '''1
00:00:10,000 --> 00:00:15,000
- Speaker 1: Line one of dialogue.
- Speaker 2: Line two of dialogue.
- Speaker 3: Line three of dialogue.
Additional annotation notes.
''';

      final vtt = LocalStreamingDaemon.convertSrtToVtt(srt);
      expect(vtt.startsWith('WEBVTT\n\n'), isTrue);
      expect(vtt, contains('00:00:10.000 --> 00:00:15.000'));
      expect(vtt, contains('- Speaker 1: Line one of dialogue.'));
      expect(vtt, contains('- Speaker 2: Line two of dialogue.'));
      expect(vtt, contains('- Speaker 3: Line three of dialogue.'));
      expect(vtt, contains('Additional annotation notes.'));
    });

    // -------------------------------------------------------------------------
    // Challenge 2.4: Empty cues, blank cues, and whitespace handling
    // -------------------------------------------------------------------------
    test('2.4: Empty cues, spacing gaps, and empty input do not corrupt WEBVTT header', () {
      // Empty input
      final emptyResult = LocalStreamingDaemon.convertSrtToVtt('');
      expect(emptyResult.startsWith('WEBVTT'), isTrue);

      // Whitespace only
      final whitespaceResult = LocalStreamingDaemon.convertSrtToVtt('   \n\r\n\t  ');
      expect(whitespaceResult.startsWith('WEBVTT'), isTrue);

      // Cue with empty text
      const emptyCueSrt = '''1
00:00:01,000 --> 00:00:02,000


2
00:00:03,000 --> 00:00:04,000
Non-empty cue
''';
      final vtt = LocalStreamingDaemon.convertSrtToVtt(emptyCueSrt);
      expect(vtt.startsWith('WEBVTT\n\n'), isTrue);
      expect(vtt, contains('00:00:01.000 --> 00:00:02.000'));
      expect(vtt, contains('00:00:03.000 --> 00:00:04.000'));
      expect(vtt, contains('Non-empty cue'));
    });

    // -------------------------------------------------------------------------
    // Challenge 2.5: Multilingual Non-ASCII / Unicode Text Fidelity
    // -------------------------------------------------------------------------
    test('2.5: Full Unicode text (CJK, Cyrillic, Arabic RTL, Diacritics, Emoji) preserved without corruption', () {
      const unicodeSrt = '''1
00:00:01,100 --> 00:00:04,200
日本語字幕：こんにちは世界！映画を楽しんでください。

2
00:00:05,300 --> 00:00:08,400
简体中文：你好世界，离线投屏测试字幕。
繁體中文：離線無線投屏高保真字幕串流。

3
00:00:09,500 --> 00:00:12,600
한국어: 안녕하세요 세계, 오프라인 미디어 플레이어 자막입니다.

4
00:00:13,700 --> 00:00:16,800
Русский: Привет, мир! Тестирование преобразования субтитров WebVTT.

5
00:00:17,900 --> 00:00:20,000
العربية: مرحبا بكم في مشغل الوسائط دون اتصال بالإنترنت!

6
00:00:21,100 --> 00:00:24,200
Accents & Symbols: Ça va très bien! Über den Wolken, señor niño, naïve café, €100, §12.

7
00:00:25,300 --> 00:00:28,400
Emojis: 🎬 🍿 🔊 🌟 🚀 💡 ❤️ 👍 📺
''';

      final vtt = LocalStreamingDaemon.convertSrtToVtt(unicodeSrt);

      // Verify WEBVTT header
      expect(vtt.startsWith('WEBVTT\n\n'), isTrue);

      // Verify timecodes converted
      expect(vtt, contains('00:00:01.100 --> 00:00:04.200'));
      expect(vtt, contains('00:00:05.300 --> 00:00:08.400'));
      expect(vtt, contains('00:00:09.500 --> 00:00:12.600'));
      expect(vtt, contains('00:00:13.700 --> 00:00:16.800'));
      expect(vtt, contains('00:00:17.900 --> 00:00:20.000'));
      expect(vtt, contains('00:00:21.100 --> 00:00:24.200'));
      expect(vtt, contains('00:00:25.300 --> 00:00:28.400'));

      // Verify exact Unicode preservation
      expect(vtt, contains('日本語字幕：こんにちは世界！映画を楽しんでください。'));
      expect(vtt, contains('简体中文：你好世界，离线投屏测试字幕。'));
      expect(vtt, contains('繁體中文：離線無線投屏高保真字幕串流。'));
      expect(vtt, contains('한국어: 안녕하세요 세계, 오프라인 미디어 플레이어 자막입니다.'));
      expect(vtt, contains('Русский: Привет, мир! Тестирование преобразования субтитров WebVTT.'));
      expect(vtt, contains('العربية: مرحبا بكم في مشغل الوسائط دون اتصال بالإنترنت!'));
      expect(vtt, contains('Ça va très bien! Über den Wolken, señor niño, naïve café, €100, §12.'));
      expect(vtt, contains('Emojis: 🎬 🍿 🔊 🌟 🚀 💡 ❤️ 👍 📺'));
    });

    // -------------------------------------------------------------------------
    // Challenge 2.6: Idempotency when input is already WebVTT
    // -------------------------------------------------------------------------
    test('2.6: WebVTT input is detected and returned idempotently without double-headering', () {
      const alreadyVtt = '''WEBVTT

1
00:00:01.000 --> 00:00:04.000
Already WebVTT cue.
''';

      final result1 = LocalStreamingDaemon.convertSrtToVtt(alreadyVtt);
      expect(result1, alreadyVtt);

      // Leading whitespace before WEBVTT
      const vttWithLeadingSpaces = '''   WEBVTT

1
00:00:01.000 --> 00:00:04.000
Leading spaces cue.
''';
      final result2 = LocalStreamingDaemon.convertSrtToVtt(vttWithLeadingSpaces);
      expect(result2, vttWithLeadingSpaces);
    });

    // -------------------------------------------------------------------------
    // Challenge 2.7: Live HTTP Subtitle Sidecar Delivery with Unicode Verification
    // -------------------------------------------------------------------------
    test('2.7: Live LocalStreamingDaemon serves converted Unicode WebVTT over HTTP with correct MIME and headers', () async {
      final srtFile = File('${tempDir.path}/unicode_test.srt');
      final videoFile = File('${tempDir.path}/dummy.mp4');
      await videoFile.writeAsBytes([0, 1, 2, 3]);

      const testSubtitle = '''1
00:00:01,500 --> 00:00:05,500
Multilingual Subtitle: 日本語 · 简体中文 · Русский · 🎬
''';
      await srtFile.writeAsString(testSubtitle, encoding: utf8);

      final daemon = LocalStreamingDaemon();
      final client = HttpClient();

      try {
        await daemon.startSession(
          filePath: videoFile.path,
          subtitlePath: srtFile.path,
          bindAddress: InternetAddress.loopbackIPv4,
        );

        expect(daemon.subtitleUrl, isNotNull);

        final req = await client.getUrl(Uri.parse(daemon.subtitleUrl!));
        final resp = await req.close();

        expect(resp.statusCode, HttpStatus.ok);
        expect(resp.headers.contentType?.mimeType, 'text/vtt');
        expect(resp.headers.value(HttpHeaders.cacheControlHeader), 'no-cache');

        final body = await resp.transform(utf8.decoder).join();
        expect(body.startsWith('WEBVTT\n\n'), isTrue);
        expect(body, contains('00:00:01.500 --> 00:00:05.500'));
        expect(body, contains('Multilingual Subtitle: 日本語 · 简体中文 · Русский · 🎬'));
      } finally {
        client.close(force: true);
        await daemon.dispose();
      }
    });

    // -------------------------------------------------------------------------
    // Challenge 2.8: Non-existent subtitle path falls back safely without crash
    // -------------------------------------------------------------------------
    test('2.8: Non-existent subtitle path delivers minimal valid WEBVTT sidecar without crashing', () async {
      final videoFile = File('${tempDir.path}/dummy2.mp4');
      await videoFile.writeAsBytes([0, 1, 2, 3]);

      final daemon = LocalStreamingDaemon();
      final client = HttpClient();

      try {
        await daemon.startSession(
          filePath: videoFile.path,
          subtitlePath: '${tempDir.path}/does_not_exist.srt',
          bindAddress: InternetAddress.loopbackIPv4,
        );

        final req = await client.getUrl(Uri.parse(daemon.subtitleUrl!));
        final resp = await req.close();

        expect(resp.statusCode, HttpStatus.ok);
        expect(resp.headers.contentType?.mimeType, 'text/vtt');

        final body = await resp.transform(utf8.decoder).join();
        expect(body, 'WEBVTT\n\n');
      } finally {
        client.close(force: true);
        await daemon.dispose();
      }
    });
  });
}
