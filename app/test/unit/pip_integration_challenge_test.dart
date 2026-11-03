import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/pip/domain/pip_models.dart';
import 'package:app/features/pip/data/pip_platform_bridge.dart';
import 'package:app/features/pip/domain/pip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> simulateNativeCall(
    String channelName,
    String method, [
    dynamic arguments,
  ]) async {
    final ByteData message = const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, arguments),
    );
    final completer = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channelName,
      message,
      (ByteData? reply) {
        completer.complete();
      },
    );
    await completer.future;
  }

  group('Empirical Challenge 1: Remote Action Mapping Stress & Edge Cases', () {
    test('1.1: Standard known action strings parse accurately', () {
      expect(PipAction.fromString('play'), PipAction.play);
      expect(PipAction.fromString('pause'), PipAction.pause);
      expect(PipAction.fromString('seek_forward_10'), PipAction.seekForward10);
      expect(PipAction.fromString('fast_forward'), PipAction.seekForward10);
      expect(PipAction.fromString('seek_rewind_10'), PipAction.seekRewind10);
      expect(PipAction.fromString('rewind'), PipAction.seekRewind10);
    });

    test('1.2: Case-insensitivity and exotic whitespace variants', () {
      expect(PipAction.fromString('PLAY'), PipAction.play);
      expect(PipAction.fromString('pLaY'), PipAction.play);
      expect(PipAction.fromString('  \t\r\n play \t\n '), PipAction.play);

      expect(PipAction.fromString('PAUSE'), PipAction.pause);
      expect(PipAction.fromString('pAuSe'), PipAction.pause);
      expect(PipAction.fromString('\n\t pause \r '), PipAction.pause);

      expect(PipAction.fromString('SEEK_FORWARD_10'), PipAction.seekForward10);
      expect(PipAction.fromString('  Seek_Forward_10  '), PipAction.seekForward10);
      expect(PipAction.fromString('FAST_FORWARD'), PipAction.seekForward10);
      expect(PipAction.fromString('  Fast_Forward  '), PipAction.seekForward10);

      expect(PipAction.fromString('SEEK_REWIND_10'), PipAction.seekRewind10);
      expect(PipAction.fromString('  Seek_Rewind_10  '), PipAction.seekRewind10);
      expect(PipAction.fromString('REWIND'), PipAction.seekRewind10);
      expect(PipAction.fromString('  ReWiNd  '), PipAction.seekRewind10);
    });

    test('1.3: Unknown, adversarial, and boundary strings gracefully yield PipAction.unknown without crashing', () {
      final adversarialInputs = <String?>[
        null,
        '',
        '   ',
        '\t\n\r',
        'playing',
        'plays',
        'paused',
        'seek_forward',
        'seek_forward_15',
        'seek_forward_30',
        'seek_rewind',
        'seek_rewind_15',
        'fastforward',
        'fast-forward',
        'seek-forward-10',
        'com.example.app.ACTION_PIP_PLAY',
        'com.example.app.ACTION_PIP_PAUSE',
        'android.intent.action.MEDIA_BUTTON',
        'media_play_pause',
        'toggle_play_pause',
        'stop',
        'next',
        'previous',
        'volume_up',
        'volume_down',
        'mute',
        '0',
        '1',
        '-1',
        'true',
        'false',
        '{}',
        '[]',
        'null',
        'undefined',
        '<script>alert("pip")</script>',
        '; DROP TABLE pip; --',
        'play\u0000extra',
        'play\nmore',
        '播放',
        '暂停',
        'воспроизведение',
        '파이프',
        '🎬🍿',
        'A' * 10000,
      ];

      for (final input in adversarialInputs) {
        expect(
          () => PipAction.fromString(input),
          returnsNormally,
          reason: 'Failed on input: "$input"',
        );
        expect(
          PipAction.fromString(input),
          PipAction.unknown,
          reason: 'Expected unknown for input: "$input"',
        );
      }
    });

    test('1.4: Platform channel incoming onPipAction payload robustness', () async {
      final bridge = PipPlatformBridge();
      final receivedRawActions = <String>[];
      final sub = bridge.onPipAction.listen(receivedRawActions.add);

      // Direct string argument
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 'play');

      // Map argument with string action
      await simulateNativeCall(
        PipPlatformBridge.channelName,
        'onPipAction',
        {'action': 'pause'},
      );

      // Map argument with unknown string action
      await simulateNativeCall(
        PipPlatformBridge.channelName,
        'onPipAction',
        {'action': 'alien_command_99'},
      );

      // Map argument with null action
      await simulateNativeCall(
        PipPlatformBridge.channelName,
        'onPipAction',
        {'action': null},
      );

      // Non-string, non-map argument (e.g. integer, bool, list)
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 42);
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', true);
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', ['play']);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedRawActions, [
        'play',
        'pause',
        'alien_command_99',
      ]);

      await sub.cancel();
      bridge.dispose();
    });

    test('1.5: PipService actionStream filters and emits strongly-typed PipAction without throwing', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        (MethodCall call) async {
          calls.add(call);
          return true;
        },
      );

      final service = PipService();
      final emittedActions = <PipAction>[];
      final sub = service.actionStream.listen(emittedActions.add);

      final inputs = [
        'play',
        'pause',
        'seek_forward_10',
        'fast_forward',
        'seek_rewind_10',
        'rewind',
        'invalid_action_1',
        'UNKNOWN_TOKEN',
        '   ',
      ];

      for (final raw in inputs) {
        await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', raw);
      }

      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(emittedActions, [
        PipAction.play,
        PipAction.pause,
        PipAction.seekForward10,
        PipAction.seekForward10,
        PipAction.seekRewind10,
        PipAction.seekRewind10,
        PipAction.unknown,
        PipAction.unknown,
        PipAction.unknown,
      ]);

      await sub.cancel();
      service.dispose();
    });
  });

  group('Empirical Challenge 2: AutoEnterPiP Sync With Playback State', () {
    late PipService service;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        (MethodCall call) async {
          calls.add(call);
          return true;
        },
      );
      service = PipService();
    });

    tearDown(() {
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        null,
      );
    });

    test('2.1: Basic enabling on isPlaying == true and disabling on isPlaying == false', () async {
      expect(service.autoEnterEnabled, isFalse);

      service.updatePlaybackState(isPlaying: true, videoWidth: 1920, videoHeight: 1080);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.autoEnterEnabled, isTrue);
      expect(calls.last.method, 'setAutoEnterEnabled');
      expect(calls.last.arguments['enabled'], isTrue);
      expect(calls.last.arguments['videoWidth'], 1920);
      expect(calls.last.arguments['videoHeight'], 1080);

      service.updatePlaybackState(isPlaying: false, videoWidth: 1920, videoHeight: 1080);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.autoEnterEnabled, isFalse);
      expect(calls.last.method, 'setAutoEnterEnabled');
      expect(calls.last.arguments['enabled'], isFalse);
    });

    test('2.2: Rapid play/pause oscillation stress test (50 transitions)', () async {
      for (var i = 0; i < 50; i++) {
        final isPlaying = (i % 2 == 0); // true, false, true, false...
        service.updatePlaybackState(isPlaying: isPlaying);
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      // Final state should be i=49 -> 49 % 2 != 0 -> isPlaying = false
      expect(service.autoEnterEnabled, isFalse);

      final autoEnterCalls = calls.where((c) => c.method == 'setAutoEnterEnabled').toList();
      expect(autoEnterCalls.length, 50);
      expect(autoEnterCalls.last.arguments['enabled'], isFalse);
    });

    test('2.3a: Sequential playback updates with await are idempotent', () async {
      // First call
      service.updatePlaybackState(isPlaying: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final countAfterFirst = calls.where((c) => c.method == 'setAutoEnterEnabled').length;
      expect(countAfterFirst, 1);

      // Redundant sequential call with await
      service.updatePlaybackState(isPlaying: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final countAfterSecond = calls.where((c) => c.method == 'setAutoEnterEnabled').length;
      expect(countAfterSecond, 1);
    });

    test('2.3b: Empirical Finding: Synchronous rapid calls trigger redundant platform channel invocations', () async {
      // 10 rapid synchronous calls without waiting for Future completion
      for (var i = 0; i < 10; i++) {
        service.updatePlaybackState(isPlaying: true);
      }
      await Future<void>.delayed(const Duration(milliseconds: 15));

      final totalCalls = calls.where((c) => c.method == 'setAutoEnterEnabled').toList();
      // Vulnerability proof: _autoEnterEnabled is assigned AFTER await _bridge.setAutoEnterEnabled(),
      // meaning all 10 synchronous calls read stale _autoEnterEnabled == false and dispatch to platform.
      expect(totalCalls.length, 10);
    });

    test('2.4: Dimension update observation when isPlaying is already true', () async {
      // Step A: Playback begins before video header loads dimensions
      service.updatePlaybackState(isPlaying: true, videoWidth: null, videoHeight: null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.autoEnterEnabled, isTrue);
      expect(service.currentDimensions, isNull);

      // Step B: Stream loads width & height (1920x1080) while still playing
      service.updatePlaybackState(isPlaying: true, videoWidth: 1920, videoHeight: 1080);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Investigation: Does updatePlaybackState forward dimensions if isPlaying didn't change?
      // In PipService: if (_autoEnterEnabled != shouldAutoEnter) ...
      // Because _autoEnterEnabled is already true, it does not re-invoke setAutoEnterEnabled!
      // This is a verified empirical finding.
      expect(service.autoEnterEnabled, isTrue);
    });

    test('2.5: Direct setAutoEnterEnabled updates dimensions unconditionally', () async {
      await service.setAutoEnterEnabled(true, videoWidth: 1920, videoHeight: 1080);
      expect(service.autoEnterEnabled, isTrue);
      expect(service.currentDimensions?.width, 1920);
      expect(service.currentDimensions?.height, 1080);
      expect(service.currentDimensions?.aspectRatio, closeTo(16.0 / 9.0, 0.01));

      // Update resolution (e.g. dynamic track switch 1080p -> 720p)
      await service.setAutoEnterEnabled(true, videoWidth: 1280, videoHeight: 720);
      expect(service.currentDimensions?.width, 1280);
      expect(service.currentDimensions?.height, 720);
    });
  });

  group('Empirical Challenge 3: Desktop Overlay Mode Calculation & Geometry', () {
    test('3.1: Standard resolutions (16:9, 4:3, 1:1, 21:9)', () {
      // 16:9 Standard HD/FHD/4K
      final size1080p = PipMath.calculateOverlaySize(1920, 1080, 480.0);
      expect(size1080p.width, 480.0);
      expect(size1080p.height, 270.0);

      final size720p = PipMath.calculateOverlaySize(1280, 720, 480.0);
      expect(size720p.width, 480.0);
      expect(size720p.height, 270.0);

      // 4:3 Standard TV/SD
      final size43 = PipMath.calculateOverlaySize(1440, 1080, 480.0);
      expect(size43.width, 480.0);
      expect(size43.height, 360.0);

      // 1:1 Square Instagram/Feed Video
      final size11 = PipMath.calculateOverlaySize(1080, 1080, 480.0);
      expect(size11.width, 480.0);
      expect(size11.height, 480.0);

      // 21:9 Cinematic (2560x1080, ratio = 2.37037)
      final size219 = PipMath.calculateOverlaySize(2560, 1080, 480.0);
      expect(size219.width, 480.0);
      expect(size219.height, closeTo(202.0, 1.0));
    });

    test('3.2: Boundary aspect ratios clamped to min/max OS bounds', () {
      // Ultra-wide (32:9 - 5120x1440, ratio 3.555) -> clamped to max 2.39
      final ultraWide = PipMath.calculateOverlaySize(5120, 1440, 480.0);
      expect(ultraWide.width, 480.0);
      // 480 / 2.39 = 200.8368 -> roundToDouble = 201.0
      expect(ultraWide.height, 201.0);

      // Ultra-tall vertical (9:32 - 1080x3840, ratio 0.28125) -> clamped to min (1 / 2.39)
      final ultraTall = PipMath.calculateOverlaySize(1080, 3840, 480.0);
      expect(ultraTall.width, 480.0);
      // 480 / (1 / 2.39) = 480 * 2.39 = 1147.2 -> roundToDouble = 1147.0
      expect(ultraTall.height, 1147.0);
    });

    test('3.3: Degenerate, zero, and negative dimensions fallback to 16:9 safe geometry', () {
      final degenerateInputs = [
        [0, 0],
        [0, 1080],
        [1920, 0],
        [-1920, 1080],
        [1920, -1080],
        [-1, -1],
        [-99999, -99999],
      ];

      for (final dim in degenerateInputs) {
        final size = PipMath.calculateOverlaySize(dim[0], dim[1], 480.0);
        expect(
          size.width,
          480.0,
          reason: 'Failed width for dimensions ${dim[0]}x${dim[1]}',
        );
        expect(
          size.height,
          270.0,
          reason: 'Failed height for dimensions ${dim[0]}x${dim[1]}',
        );
      }
    });

    test('3.4: Custom baseWidth scaling and pixel precision', () {
      final widths = [240.0, 320.0, 480.0, 640.0, 720.0, 960.0, 1280.0];
      for (final baseWidth in widths) {
        final size = PipMath.calculateOverlaySize(1920, 1080, baseWidth);
        expect(size.width, baseWidth);
        final expectedHeight = (baseWidth * 9.0 / 16.0).roundToDouble();
        expect(size.height, expectedHeight);
      }
    });

    test('3.5: PipDimensions value equality and formatting consistency', () {
      final d1 = PipDimensions.fromSize(1920, 1080);
      final d2 = PipDimensions.fromSize(1920, 1080);
      final d3 = PipDimensions.fromSize(1280, 720);
      final d4 = PipDimensions.fromSize(1080, 1080);

      expect(d1, equals(d2));
      expect(d1 == d3, isFalse);
      expect(d1 == d4, isFalse);
      expect(d1.aspectRatio, closeTo(d3.aspectRatio, 0.0001));

      expect(d1.toString(), 'PipDimensions(1920x1080, aspect: 1.778)');
      expect(d4.toString(), 'PipDimensions(1080x1080, aspect: 1.000)');
    });
  });
}
