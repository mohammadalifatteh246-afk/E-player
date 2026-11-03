import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/pip/domain/pip_models.dart';
import 'package:app/features/pip/data/pip_platform_bridge.dart';
import 'package:app/features/pip/domain/pip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to simulate native platform -> Flutter method invocations
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

  group('Group 1: PipModels & Enums', () {
    test('1.1: PipStatus enum exposes all expected lifecycle states', () {
      expect(PipStatus.values, contains(PipStatus.stopped));
      expect(PipStatus.values, contains(PipStatus.entering));
      expect(PipStatus.values, contains(PipStatus.active));
      expect(PipStatus.values, contains(PipStatus.exiting));
      expect(PipStatus.values.length, 4);
    });

    test('1.2: PipAction.fromString parses play correctly', () {
      expect(PipAction.fromString('play'), PipAction.play);
      expect(PipAction.fromString('PLAY'), PipAction.play);
      expect(PipAction.fromString('  play  '), PipAction.play);
    });

    test('1.3: PipAction.fromString parses pause correctly', () {
      expect(PipAction.fromString('pause'), PipAction.pause);
      expect(PipAction.fromString('PAUSE'), PipAction.pause);
      expect(PipAction.fromString('  pause  '), PipAction.pause);
    });

    test('1.4: PipAction.fromString parses seek_forward_10 and fast_forward', () {
      expect(PipAction.fromString('seek_forward_10'), PipAction.seekForward10);
      expect(PipAction.fromString('fast_forward'), PipAction.seekForward10);
      expect(PipAction.fromString('FAST_FORWARD'), PipAction.seekForward10);
    });

    test('1.5: PipAction.fromString parses seek_rewind_10 and rewind', () {
      expect(PipAction.fromString('seek_rewind_10'), PipAction.seekRewind10);
      expect(PipAction.fromString('rewind'), PipAction.seekRewind10);
      expect(PipAction.fromString('REWIND'), PipAction.seekRewind10);
    });

    test('1.6: PipAction.fromString safely falls back to unknown on unexpected values', () {
      expect(PipAction.fromString(null), PipAction.unknown);
      expect(PipAction.fromString(''), PipAction.unknown);
      expect(PipAction.fromString('unknown_intent'), PipAction.unknown);
      expect(PipAction.fromString('skip_next'), PipAction.unknown);
    });

    test('1.7: PipDimensions retains dimensions, aspect ratio, equality and string representation', () {
      final dim1 = PipDimensions.fromSize(1920, 1080);
      final dim2 = PipDimensions.fromSize(1920, 1080);
      final dim3 = PipDimensions.fromSize(1280, 720);

      expect(dim1.width, 1920);
      expect(dim1.height, 1080);
      expect((dim1.aspectRatio - 1.777).abs() < 0.01, isTrue);
      expect(dim1, equals(dim2));
      expect(dim1.hashCode, equals(dim2.hashCode));
      expect(dim1 == dim3, isFalse);
      expect(dim1.toString(), contains('1920x1080'));
    });
  });

  group('Group 2: PipMath Algorithms & Rational Clamping', () {
    test('2.1: Min and Max aspect ratio constants match Android OS limitations', () {
      expect(PipMath.minAspectRatio, closeTo(1.0 / 2.39, 0.0001));
      expect(PipMath.maxAspectRatio, closeTo(2.39, 0.0001));
      expect(PipMath.minAspectRatio < PipMath.maxAspectRatio, isTrue);
    });

    test('2.2: Standard 16:9 video aspect ratio calculates accurately', () {
      final ratio = PipMath.calculateAspectRatio(1920, 1080);
      expect((ratio - 16.0 / 9.0).abs() < 0.001, isTrue);
    });

    test('2.3: Standard 21:9 cinematic aspect ratio calculates accurately within bounds', () {
      final ratio = PipMath.calculateAspectRatio(2560, 1080);
      expect(ratio <= PipMath.maxAspectRatio, isTrue);
      expect(ratio >= PipMath.minAspectRatio, isTrue);
    });

    test('2.4: Ultra-wide video exceeding 2.39 is clamped to maxAspectRatio', () {
      final ratio = PipMath.calculateAspectRatio(3840, 1080); // 3.55
      expect(ratio, PipMath.maxAspectRatio);
    });

    test('2.5: Ultra-tall vertical video narrower than 1/2.39 is clamped to minAspectRatio', () {
      final ratio = PipMath.calculateAspectRatio(1080, 3000); // 0.36
      expect(ratio, PipMath.minAspectRatio);
    });

    test('2.6: Zero or negative dimensions safely fall back to 16:9 standard ratio', () {
      expect(PipMath.calculateAspectRatio(0, 0), 16.0 / 9.0);
      expect(PipMath.calculateAspectRatio(-1920, 1080), 16.0 / 9.0);
      expect(PipMath.calculateAspectRatio(1920, -1080), 16.0 / 9.0);
    });

    test('2.7: canAutoEnter rule permits PiP only during active playback', () {
      expect(PipMath.canAutoEnter(true), isTrue);
      expect(PipMath.canAutoEnter(false), isFalse);
    });

    test('2.8: calculateOverlaySize produces proportional desktop geometries', () {
      final size169 = PipMath.calculateOverlaySize(1920, 1080, 480.0);
      expect(size169.width, 480.0);
      expect(size169.height, 270.0);

      final size43 = PipMath.calculateOverlaySize(1440, 1080, 480.0);
      expect(size43.width, 480.0);
      expect(size43.height, 360.0);

      final sizeCustom = PipMath.calculateOverlaySize(1920, 1080, 640.0);
      expect(sizeCustom.width, 640.0);
      expect(sizeCustom.height, 360.0);
    });
  });

  group('Group 3: PipPlatformBridge Outbound Method Calls', () {
    late PipPlatformBridge bridge;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'isPipSupported':
              return true;
            case 'enterPictureInPictureMode':
              return true;
            case 'setAutoEnterEnabled':
              return true;
            case 'toggleDesktopOverlay':
              return true;
            default:
              return null;
          }
        },
      );
      bridge = PipPlatformBridge();
    });

    tearDown(() {
      bridge.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        null,
      );
    });

    test('3.1: isPipSupported invokes platform channel and returns result', () async {
      final supported = await bridge.isPipSupported();
      expect(supported, isTrue);
      expect(calls.any((c) => c.method == 'isPipSupported'), isTrue);
    });

    test('3.2: isPipSupported safely returns false on platform exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        (MethodCall call) async {
          throw PlatformException(code: 'UNAVAILABLE');
        },
      );
      final supported = await bridge.isPipSupported();
      expect(supported, isFalse);
    });

    test('3.3: enterPictureInPictureMode transmits videoWidth, videoHeight, and isPlaying', () async {
      final success = await bridge.enterPictureInPictureMode(
        videoWidth: 1920,
        videoHeight: 1080,
        isPlaying: true,
      );
      expect(success, isTrue);

      final call = calls.firstWhere((c) => c.method == 'enterPictureInPictureMode');
      expect(call.arguments['videoWidth'], 1920);
      expect(call.arguments['videoHeight'], 1080);
      expect(call.arguments['isPlaying'], isTrue);
    });

    test('3.4: enterPictureInPictureMode safely returns false on platform exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        (MethodCall call) async {
          throw PlatformException(code: 'FAILED');
        },
      );
      final success = await bridge.enterPictureInPictureMode(
        videoWidth: 1920,
        videoHeight: 1080,
        isPlaying: true,
      );
      expect(success, isFalse);
    });

    test('3.5: setAutoEnterEnabled transmits enabled flag and dimensions', () async {
      await bridge.setAutoEnterEnabled(true, videoWidth: 1280, videoHeight: 720);

      final call = calls.firstWhere((c) => c.method == 'setAutoEnterEnabled');
      expect(call.arguments['enabled'], isTrue);
      expect(call.arguments['videoWidth'], 1280);
      expect(call.arguments['videoHeight'], 720);
    });

    test('3.6: toggleDesktopOverlay transmits enabled flag and initialSize geometry', () async {
      final success = await bridge.toggleDesktopOverlay(
        enable: true,
        initialSize: const Size(480, 270),
      );
      expect(success, isTrue);

      final call = calls.firstWhere((c) => c.method == 'toggleDesktopOverlay');
      expect(call.arguments['enabled'], isTrue);
      expect(call.arguments['width'], 480);
      expect(call.arguments['height'], 270);
    });
  });

  group('Group 4: PipPlatformBridge Inbound Native Event Handling', () {
    late PipPlatformBridge bridge;

    setUp(() {
      bridge = PipPlatformBridge();
    });

    tearDown(() {
      bridge.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        null,
      );
    });

    test('4.1: onPipEntered emits event when native channel calls onPipEntered', () async {
      final enteredCompleter = Completer<bool>();
      final sub = bridge.onPipEntered.listen((_) {
        enteredCompleter.complete(true);
      });

      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipEntered');
      final result = await enteredCompleter.future.timeout(const Duration(seconds: 1));
      expect(result, isTrue);
      await sub.cancel();
    });

    test('4.2: onPipExited emits event when native channel calls onPipExited', () async {
      final exitedCompleter = Completer<bool>();
      final sub = bridge.onPipExited.listen((_) {
        exitedCompleter.complete(true);
      });

      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipExited');
      final result = await exitedCompleter.future.timeout(const Duration(seconds: 1));
      expect(result, isTrue);
      await sub.cancel();
    });

    test('4.3: onPipAction emits string for direct string arguments', () async {
      final actionCompleter = Completer<String>();
      final sub = bridge.onPipAction.listen((action) {
        actionCompleter.complete(action);
      });

      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 'pause');
      final result = await actionCompleter.future.timeout(const Duration(seconds: 1));
      expect(result, 'pause');
      await sub.cancel();
    });

    test('4.4: onPipAction emits string for map arguments', () async {
      final actionCompleter = Completer<String>();
      final sub = bridge.onPipAction.listen((action) {
        actionCompleter.complete(action);
      });

      await simulateNativeCall(
        PipPlatformBridge.channelName,
        'onPipAction',
        {'action': 'seek_forward_10'},
      );
      final result = await actionCompleter.future.timeout(const Duration(seconds: 1));
      expect(result, 'seek_forward_10');
      await sub.cancel();
    });
  });

  group('Group 5: PipService State Machine & Lifecycle', () {
    late PipService service;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(PipPlatformBridge.channelName),
        (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'isPipSupported':
              return true;
            case 'enterPictureInPictureMode':
              return true;
            case 'setAutoEnterEnabled':
              return true;
            case 'toggleDesktopOverlay':
              return true;
            default:
              return null;
          }
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

    test('5.1: Initial properties reflect stopped and inactive states', () {
      expect(service.isInPip, isFalse);
      expect(service.isDesktopOverlay, isFalse);
      expect(service.autoEnterEnabled, isFalse);
      expect(service.isSupported, isFalse);
      expect(service.desktopOverlaySize, isNull);
      expect(service.currentDimensions, isNull);
    });

    test('5.2: isPipSupported caches result and notifies listeners', () async {
      var notified = false;
      service.addListener(() => notified = true);

      final supported = await service.isPipSupported();
      expect(supported, isTrue);
      expect(service.isSupported, isTrue);
      expect(notified, isTrue);
    });

    test('5.3: enterPip transitions isInPip to true and sets dimensions', () async {
      var notifications = 0;
      service.addListener(() => notifications++);

      final success = await service.enterPip(
        videoWidth: 1920,
        videoHeight: 1080,
        isPlaying: true,
      );

      expect(success, isTrue);
      expect(service.isInPip, isTrue);
      expect(service.currentDimensions?.width, 1920);
      expect(service.currentDimensions?.height, 1080);
      expect(notifications > 0, isTrue);
    });

    test('5.4: toggleDesktopOverlay toggles overlay state and updates size', () async {
      const targetSize = Size(480, 270);
      final success = await service.toggleDesktopOverlay(
        enable: true,
        initialSize: targetSize,
      );

      expect(success, isTrue);
      expect(service.isDesktopOverlay, isTrue);
      expect(service.desktopOverlaySize, targetSize);

      await service.toggleDesktopOverlay(enable: false);
      expect(service.isDesktopOverlay, isFalse);
      expect(service.desktopOverlaySize, isNull);
    });

    test('5.5: Inbound onPipEntered and onPipExited toggle isInPip state', () async {
      expect(service.isInPip, isFalse);

      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipEntered');
      expect(service.isInPip, isTrue);

      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipExited');
      expect(service.isInPip, isFalse);
    });

    test('5.6: Inbound onPipAction parses and dispatches PipAction events', () async {
      final receivedActions = <PipAction>[];
      final sub = service.actionStream.listen(receivedActions.add);

      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 'play');
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 'pause');
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 'seek_forward_10');
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 'seek_rewind_10');
      await simulateNativeCall(PipPlatformBridge.channelName, 'onPipAction', 'unknown_cmd');

      // Wait a microtask tick for stream delivery
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedActions, [
        PipAction.play,
        PipAction.pause,
        PipAction.seekForward10,
        PipAction.seekRewind10,
        PipAction.unknown,
      ]);

      await sub.cancel();
    });
  });

  group('Group 6: PipService Playback State Synchronization & AutoEnter', () {
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

    test('6.1: Active playback arms AutoEnterPiP', () async {
      service.updatePlaybackState(
        isPlaying: true,
        videoWidth: 1920,
        videoHeight: 1080,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.autoEnterEnabled, isTrue);
      final call = calls.firstWhere((c) => c.method == 'setAutoEnterEnabled');
      expect(call.arguments['enabled'], isTrue);
      expect(call.arguments['videoWidth'], 1920);
      expect(call.arguments['videoHeight'], 1080);
    });

    test('6.2: Pausing playback disarms AutoEnterPiP', () async {
      service.updatePlaybackState(isPlaying: true, videoWidth: 1920, videoHeight: 1080);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.autoEnterEnabled, isTrue);

      service.updatePlaybackState(isPlaying: false, videoWidth: 1920, videoHeight: 1080);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.autoEnterEnabled, isFalse);

      final lastCall = calls.lastWhere((c) => c.method == 'setAutoEnterEnabled');
      expect(lastCall.arguments['enabled'], isFalse);
    });

    test('6.3: Idempotent playback state does not trigger redundant channel calls', () async {
      service.updatePlaybackState(isPlaying: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final countAfterFirst = calls.where((c) => c.method == 'setAutoEnterEnabled').length;

      // Repeat with same state
      service.updatePlaybackState(isPlaying: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final countAfterSecond = calls.where((c) => c.method == 'setAutoEnterEnabled').length;

      expect(countAfterSecond, equals(countAfterFirst));
    });
  });

  group('Group 7: PipService Resource Disposal & Cleanup', () {
    test('7.1: Disposal cancels subscriptions and closes action stream', () async {
      final service = PipService();
      expect(service.actionStream, isNotNull);
      expect(service.isDisposed, isFalse);

      service.dispose();
      expect(service.isDisposed, isTrue);

      // Subsequent dispose calls should be safely idempotent
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
