import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/features/external_launch/domain/external_launch_models.dart';
import 'package:app/features/external_launch/data/external_launch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExternalLaunchParser Unit Tests (Windows CLI & Android Intents)', () {
    test('1. Strips quotes and converts file:/// URI into native Windows path', () {
      expect(
        ExternalLaunchParser.normalizeInputTarget(
          r'"D:\My Movies\Inception (2010).mkv"',
          isWindowsOverride: true,
        ),
        r'D:\My Movies\Inception (2010).mkv',
      );

      expect(
        ExternalLaunchParser.normalizeInputTarget(
          'file:///D:/My%20Movies/sample.mp4',
          isWindowsOverride: true,
        ),
        r'D:\My Movies\sample.mp4',
      );

      expect(
        ExternalLaunchParser.normalizeInputTarget('https://example.com/stream.m3u8'),
        'https://example.com/stream.m3u8',
      );
    });

    test('2. Ignores Flutter/Dart CLI flags and picks playable media over subtitle', () {
      final req = ExternalLaunchParser.parseCliArgs(
        [
          '--enable-dart-profiling',
          '--observatory-port=12345',
          r'D:\Anime\ep01.ass',
          r'"D:\Anime\ep01.mkv"',
          r'D:\Anime\ep02.mkv',
        ],
        isWindowsOverride: true,
      );

      expect(req, isNotNull);
      expect(req!.uri, r'D:\Anime\ep01.mkv');
      expect(req.displayName, 'ep01.mkv');
      expect(req.kind, ExternalMediaKind.videoAudio);
      expect(req.extraUris, containsAll([r'D:\Anime\ep01.ass', r'D:\Anime\ep02.mkv']));
      expect(req.sourcePlatform, 'windows_cli');
    });

    test('3. Returns null when CLI args contain only engine flags or whitespace', () {
      expect(
        ExternalLaunchParser.parseCliArgs(['--enable-impeller', '   ', '-v']),
        isNull,
      );
    });

    test('4. Parses Android fdclose:// intent payload preserving original displayName and kind', () {
      final req = ExternalLaunchParser.fromPlatformPayload({
        'uri': 'fdclose://42',
        'displayName': 'Interstellar.2014.IMAX.mkv',
        'mimeType': 'video/x-matroska',
        'source': 'android_intent',
      });

      expect(req, isNotNull);
      expect(req!.uri, 'fdclose://42');
      expect(req.displayName, 'Interstellar.2014.IMAX.mkv');
      expect(req.kind, ExternalMediaKind.videoAudio);
      expect(req.isPlayable, isTrue);
    });

    test('5. Classifies subtitles, playlists, archives, DVD ISO, and network streams accurately', () {
      expect(
        ExternalLaunchParser.classifyTarget(r'D:\Subs\movie.srt'),
        ExternalMediaKind.subtitle,
      );
      expect(
        ExternalLaunchParser.classifyTarget(r'D:\Lists\iptv.m3u8'),
        ExternalMediaKind.playlist,
      );
      expect(
        ExternalLaunchParser.classifyTarget(r'D:\Bundles\tracks.zip'),
        ExternalMediaKind.archive,
      );
      expect(
        ExternalLaunchParser.classifyTarget(r'D:\Disc\Concert.iso'),
        ExternalMediaKind.dvdFolder,
      );
      expect(
        ExternalLaunchParser.classifyTarget('rtsp://192.168.1.10:554/live'),
        ExternalMediaKind.networkStream,
      );
    });
  });

  group('ExternalLaunchService Lifecycle & Warm Stream Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExternalLaunchService.resetForTesting();
    });

    test('6. Buffers cold-start CLI args and pulls Android initial intent once', () async {
      const channel = MethodChannel('com.example.app/external_launch');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialLaunch') {
          return {
            'uri': '/storage/emulated/0/Movies/trailer.mp4',
            'displayName': 'trailer.mp4',
            'mimeType': 'video/mp4',
            'source': 'android_intent',
          };
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final service = ExternalLaunchService.instance;
      await service.initialize(cliArgs: const []);

      final cold = service.consumePendingColdStart();
      expect(cold, isNotNull);
      expect(cold!.uri, '/storage/emulated/0/Movies/trailer.mp4');
      expect(cold.displayName, 'trailer.mp4');

      // Consumed once -> second call returns null
      expect(service.consumePendingColdStart(), isNull);
      expect(service.history.length, 1);
    });

    test('7. Emits live warm launches on stream and persists Studio settings', () async {
      final service = ExternalLaunchService.instance;
      await service.initialize(cliArgs: const []);

      final emitted = <ExternalLaunchRequest>[];
      final sub = service.launchStream.listen(emitted.add);
      addTearDown(sub.cancel);

      await service.setWarmLaunchBehavior(WarmLaunchBehavior.enqueueToPlaylist);
      await service.setSingleInstanceMode(false);
      await service.setAutoPlayStreams(false);

      expect(service.warmLaunchBehavior, WarmLaunchBehavior.enqueueToPlaylist);
      expect(service.singleInstanceMode, isFalse);
      expect(service.autoPlayStreams, isFalse);

      final triggered = service.triggerSimulatedLaunch(
        r'D:\Videos\clip_two.mkv',
        sourcePlatform: 'studio_simulator',
      );
      expect(triggered, isNotNull);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 1);
      expect(emitted.first.displayName, 'clip_two.mkv');
      expect(service.history.first.sourcePlatform, 'studio_simulator');
    });
  });
}
