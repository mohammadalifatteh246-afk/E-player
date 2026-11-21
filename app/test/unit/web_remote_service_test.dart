import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/web_remote/data/web_remote_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WebRemoteService service;
  late HttpClient client;

  setUp(() {
    HttpOverrides.global = null;
    service = WebRemoteService();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await service.stop();
    service.dispose();
  });

  group('WebRemoteService HTTP & REST Tests (VLC Parity)', () {
    test('1. Starts on available port and provides status', () async {
      final started = await service.start(port: 9870);
      expect(started, isTrue);
      expect(service.isRunning, isTrue);

      service.statusProvider = () => const WebRemoteStatus(
            isPlaying: true,
            title: 'Cyberpunk Edgerunners E01',
            positionMs: 45000,
            durationMs: 1440000,
            volume: 220.0,
            aspectRatio: '16:9',
            isMuted: false,
            currentAudioTrack: 'Japanese [Dolby Atmos]',
            currentSubtitleTrack: 'English [Full]',
            abRepeatState: 'Looping',
          );

      // Request GET /api/status
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/api/status'));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(json['isPlaying'], isTrue);
      expect(json['title'], equals('Cyberpunk Edgerunners E01'));
      expect(json['volume'], equals(220.0));
      expect(json['positionMs'], equals(45000));
      expect(json['durationMs'], equals(1440000));
      expect(json['abRepeatState'], equals('Looping'));
    });

    test('2. Serves embedded Cyberpunk Web App on GET /', () async {
      await service.start(port: 9872);

      final req = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/'));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.contentType?.mimeType, equals('text/html'));

      final html = await res.transform(utf8.decoder).join();
      expect(html, contains('E-Player Web Remote'));
      expect(html, contains('Volume Boost (0-300%)'));
      expect(html, contains('fetchStatus'));
    });

    test('3. Triggers playback action callbacks via REST API', () async {
      await service.start(port: 9874);

      bool playPauseCalled = false;
      int? seekPosition;
      double? updatedVolume;
      bool cropCalled = false;
      bool stepFrameCalled = false;
      bool nextCalled = false;
      bool prevCalled = false;

      service.onPlayPause = () => playPauseCalled = true;
      service.onSeek = (pos) => seekPosition = pos;
      service.onSetVolume = (vol) => updatedVolume = vol;
      service.onCycleAspectRatio = () => cropCalled = true;
      service.onStepFrame = () => stepFrameCalled = true;
      service.onNext = () => nextCalled = true;
      service.onPrevious = () => prevCalled = true;

      // POST play-pause
      var req = await client.postUrl(Uri.parse('http://127.0.0.1:${service.port}/api/playback/play-pause'));
      var res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(playPauseCalled, isTrue);

      // POST volume
      req = await client.postUrl(Uri.parse('http://127.0.0.1:${service.port}/api/playback/volume?value=275.5'));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(updatedVolume, equals(275.5));

      // POST seek
      req = await client.postUrl(Uri.parse('http://127.0.0.1:${service.port}/api/playback/seek?position=98000'));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(seekPosition, equals(98000));

      // POST crop
      req = await client.postUrl(Uri.parse('http://127.0.0.1:${service.port}/api/playback/crop'));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(cropCalled, isTrue);

      // POST step-frame
      req = await client.postUrl(Uri.parse('http://127.0.0.1:${service.port}/api/playback/step-frame'));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(stepFrameCalled, isTrue);

      // POST next
      req = await client.postUrl(Uri.parse('http://127.0.0.1:${service.port}/api/playback/next'));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(nextCalled, isTrue);

      // POST previous
      req = await client.postUrl(Uri.parse('http://127.0.0.1:${service.port}/api/playback/previous'));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      expect(prevCalled, isTrue);
    });

    test('4. Stops cleanly and rejects subsequent requests', () async {
      await service.start(port: 9876);
      expect(service.isRunning, isTrue);

      await service.stop();
      expect(service.isRunning, isFalse);

      expect(
        () async => await client.getUrl(Uri.parse('http://127.0.0.1:9876/api/status')),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
