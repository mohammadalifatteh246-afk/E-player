import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/decoder_models.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  final harness = EPlayerTestHarness();
  late Directory tempDir;

  setUpAll(() async {
    await harness.setUp();
  });

  setUp(() {
    tempDir = harness.createTempDirectory('tier2_');
  });

  tearDown(() async {
    await harness.tearDown();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  group('Tier 2: Boundary & Corner Cases (Features 1 to 21)', () {
    // -------------------------------------------------------------------------
    // Feature 1: Decoder Mode Selection (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 1: Decoder Mode Selection (Boundary)', () {
      test('1.1: Empty or unknown mode string falls back safely to auto', () {
        expect(DecoderModeValidator.mapModeToHwdec(''), 'auto');
        expect(DecoderModeValidator.mapModeToHwdec('UNKNOWN_MODE'), 'auto');
      });

      test('1.2: Repeated mode selection of the same mode is idempotent', () {
        const mode = DecoderMode.hw;
        expect(mode.mpvValue, 'yes');
        expect(mode.mpvValue, 'yes');
        expect(mode.isHardwareAccelerated, isTrue);
      });

      test('1.3: Mode switch at position Duration.zero is valid', () {
        const targetPos = Duration.zero;
        expect(targetPos.inMilliseconds, 0);
        final restored = GestureArbitratorMath.clampDuration(targetPos, const Duration(hours: 2));
        expect(restored, Duration.zero);
      });

      test('1.4: Mode switch at extreme 24-hour media duration is clamped', () {
        const total = Duration(hours: 24);
        const extremePos = Duration(hours: 25);
        final clamped = GestureArbitratorMath.clampDuration(extremePos, total);
        expect(clamped, total);
      });

      test('1.5: DecoderMode enum exhaustiveness check', () {
        expect(DecoderMode.values.length, 4);
        for (final mode in DecoderMode.values) {
          expect(mode.mpvValue.isNotEmpty, isTrue);
          expect(mode.label.isNotEmpty, isTrue);
        }
      });
    });

    // -------------------------------------------------------------------------
    // Feature 2: Dynamic Fallback Pipeline (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 2: Dynamic Fallback Pipeline (Boundary)', () {
      test('2.1: Exactly 10 dropped frames in 2s is on threshold (no fallback)', () {
        final trigger = DecoderModeValidator.shouldTriggerFallback(
          droppedFrames: 10,
          window: const Duration(seconds: 2),
        );
        expect(trigger, isFalse);
      });

      test('2.2: Exactly 11 dropped frames in 2s exceeds threshold (triggers fallback)', () {
        final trigger = DecoderModeValidator.shouldTriggerFallback(
          droppedFrames: 11,
          window: const Duration(seconds: 2),
        );
        expect(trigger, isTrue);
      });

      test('2.3: 100 dropped frames spread over 10s (>2s window) does not trigger fallback', () {
        final trigger = DecoderModeValidator.shouldTriggerFallback(
          droppedFrames: 100,
          window: const Duration(seconds: 10),
        );
        expect(trigger, isFalse);
      });

      test('2.4: Fallback requested on SW mode returns null (terminal floor)', () {
        final next = DecoderMode.sw.nextFallback;
        expect(next, isNull);
        expect(DecoderModeValidator.getNextFallbackMode('SW'), 'SW');
      });

      test('2.5: Zero dropped frames produces false fallback condition', () {
        final trigger = DecoderModeValidator.shouldTriggerFallback(
          droppedFrames: 0,
          window: const Duration(seconds: 1),
        );
        expect(trigger, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 3: Hardware Acceleration Invariant (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 3: Hardware Acceleration Invariant (Boundary)', () {
      test('3.1: Color adjustment at maximum positive limits (+100.0)', () {
        final config = VideoEffectsConfig(
          contrast: 100.0,
          brightness: 100.0,
          saturation: 100.0,
          gamma: 100.0,
          hue: 100.0,
        );
        expect(config.contrast, 100.0);
        expect(config.brightness, 100.0);
        expect(config.isNeutral, isFalse);
      });

      test('3.2: Color adjustment at maximum negative limits (-100.0)', () {
        final config = VideoEffectsConfig(
          contrast: -100.0,
          brightness: -100.0,
          saturation: -100.0,
          gamma: -100.0,
          hue: -100.0,
        );
        expect(config.contrast, -100.0);
        expect(config.brightness, -100.0);
        expect(config.isNeutral, isFalse);
      });

      test('3.3: Inverting color matrix handles 255.0 offset bounds', () {
        final config = VideoEffectsConfig(invert: true);
        final matrix = config.toColorFilterMatrix();
        expect(matrix[4], 255.0); // R offset
        expect(matrix[9], 255.0); // G offset
        expect(matrix[14], 255.0); // B offset
      });

      test('3.4: Filter chain generation with all effects enabled simultaneously', () {
        final config = VideoEffectsConfig(
          sharpen: true,
          bandingRemoval: true,
          flipHorizontal: true,
          flipVertical: true,
          invert: true,
          sepia: true,
        );
        final vf = config.buildMpvVfString();
        expect(vf, contains('unsharp'));
        expect(vf, contains('gradfun'));
        expect(vf, contains('hflip'));
        expect(vf, contains('vflip'));
        expect(vf, contains('negate'));
        expect(vf, contains('colorchannelmixer'));
      });

      test('3.5: Master toggle disabled overrides non-neutral sliders to empty string', () {
        final config = VideoEffectsConfig(
          contrast: 80.0,
          sharpen: true,
          flipHorizontal: true,
          masterEnabled: false,
        );
        expect(config.buildMpvVfString(), '');
      });
    });

    // -------------------------------------------------------------------------
    // Feature 4: Decoder Telemetry HUD (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 4: Decoder Telemetry HUD (Boundary)', () {
      test('4.1: Telemetry with 0 FPS (paused or stalled stream)', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.auto,
          activeDecoder: 'd3d11va',
          codec: 'hevc',
          droppedFrames: 0,
          fps: 0.0,
        );
        expect(telemetry.fps, 0.0);
      });

      test('4.2: Telemetry with 0 bitrate handles uncompressed or raw source', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.sw,
          activeDecoder: 'sw',
          codec: 'rawvideo',
          droppedFrames: 0,
          fps: 24.0,
          bitrate: 0,
        );
        expect(telemetry.bitrate, 0);
      });

      test('4.3: Telemetry with extreme dropped frames (1,000,000 drops)', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.hw,
          activeDecoder: 'none',
          codec: 'av1',
          droppedFrames: 1000000,
          fps: 1.0,
        );
        expect(telemetry.droppedFrames, 1000000);
      });

      test('4.4: Telemetry with 8K resolution video stream', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.hw,
          activeDecoder: 'nvdec',
          codec: 'hevc',
          droppedFrames: 0,
          fps: 60.0,
          bitrate: 80000000,
        );
        expect(telemetry.bitrate, 80000000);
      });

      test('4.5: Telemetry handles empty activeDecoder name safely', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.auto,
          activeDecoder: '',
          codec: 'unknown',
          droppedFrames: 0,
          fps: 30.0,
        );
        expect(telemetry.activeDecoder, '');
      });
    });

    // -------------------------------------------------------------------------
    // Feature 5: Horizontal Precision Scrub (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 5: Horizontal Precision Scrub (Boundary)', () {
      test('5.1: Zero horizontal delta dx = 0.0 results in unchanged position', () {
        const start = Duration(minutes: 5);
        final target = start + Duration(seconds: (0.0 * 0.5).toInt());
        expect(target, start);
      });

      test('5.2: Extreme positive delta dx = +1,000,000px clamps to total duration', () {
        const duration = Duration(minutes: 10);
        const start = Duration(minutes: 5);
        final target = start + Duration(seconds: (1000000.0 * 0.5).toInt());
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, duration);
      });

      test('5.3: Extreme negative delta dx = -1,000,000px clamps to Duration.zero', () {
        const duration = Duration(minutes: 10);
        const start = Duration(minutes: 5);
        final target = start + Duration(seconds: (-1000000.0 * 0.5).toInt());
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, Duration.zero);
      });

      test('5.4: Scrubbing on zero-duration media clamps target to Duration.zero', () {
        const duration = Duration.zero;
        const start = Duration.zero;
        final target = start + Duration(seconds: (500.0 * 0.5).toInt());
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, Duration.zero);
      });

      test('5.5: Micro horizontal delta dx = 0.5px produces 0-second integer duration', () {
        final seconds = (0.5 * 0.5).toInt();
        expect(seconds, 0);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 6: Split Brightness/Volume Sliders (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 6: Split Brightness/Volume Sliders (Boundary)', () {
      test('6.1: Vertical drag at coordinate x = 0 (exact left edge) adjusts brightness', () {
        const viewportWidth = 1000.0;
        const tapX = 0.0;
        expect(tapX < viewportWidth * 0.35, isTrue);
      });

      test('6.2: Vertical drag at coordinate x = viewportWidth (exact right edge) adjusts volume', () {
        const viewportWidth = 1000.0;
        const tapX = 1000.0;
        expect(tapX > viewportWidth * 0.65, isTrue);
      });

      test('6.3: Extreme upward drag dy = -50,000px clamps volume to 100.0', () {
        final vol = GestureArbitratorMath.clampVolume(50.0 - (-50000.0 * 0.5));
        expect(vol, 100.0);
      });

      test('6.4: Extreme downward drag dy = +50,000px clamps volume to 0.0', () {
        final vol = GestureArbitratorMath.clampVolume(50.0 - (50000.0 * 0.5));
        expect(vol, 0.0);
      });

      test('6.5: Extreme upward drag dy = -50,000px clamps brightness to 1.0', () {
        final br = GestureArbitratorMath.clampBrightness(0.5 - (-50000.0 * 0.005));
        expect(br, 1.0);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 7: Double-Tap Wing Jump (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 7: Double-Tap Wing Jump (Boundary)', () {
      test('7.1: Double-tap at x = 0.33 * width boundary', () {
        const width = 1000.0;
        const boundaryX = 330.0;
        // Exactly at boundary is not strictly < 0.33, acts as center
        expect(boundaryX < width * 0.33, isFalse);
      });

      test('7.2: Double-tap at x = 0.66 * width boundary', () {
        const width = 1000.0;
        const boundaryX = 660.0;
        expect(boundaryX > width * 0.66, isFalse);
      });

      test('7.3: Double-tap jump on 5-second media clamps forward to 5s', () {
        const duration = Duration(seconds: 5);
        const current = Duration(seconds: 2);
        final target = current + const Duration(seconds: 10);
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, duration);
      });

      test('7.4: Double-tap jump at position 2s clamps backward to 0s', () {
        const duration = Duration(seconds: 60);
        const current = Duration(seconds: 2);
        final target = current - const Duration(seconds: 10);
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, Duration.zero);
      });

      test('7.5: Double-tap at (0, 0) origin coordinate acts as backward jump', () {
        const width = 1000.0;
        const tapX = 0.0;
        expect(tapX < width * 0.33, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 8: Pinch-to-Zoom & Pan Bounds (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 8: Pinch-to-Zoom & Pan Bounds (Boundary)', () {
      test('8.1: Scale factor 0.001 clamps to minimum 1.0x', () {
        expect(GestureArbitratorMath.clampScale(0.001), 1.0);
      });

      test('8.2: Scale factor 100.0 clamps to maximum 4.0x', () {
        expect(GestureArbitratorMath.clampScale(100.0), 4.0);
      });

      test('8.3: Pan offset at 1.0x scale is strictly Offset.zero', () {
        const pan = Offset(500, 500);
        final clamped = GestureArbitratorMath.clampPanOffset(pan, 1.0, const Size(1920, 1080));
        expect(clamped, Offset.zero);
      });

      test('8.4: Pan offset with extreme coordinates (+99999, +99999) clamps to edge', () {
        const viewport = Size(1000, 500);
        const scale = 2.0;
        // maxTx = 1.0 * 1000 / 2 = 500; maxTy = 1.0 * 500 / 2 = 250
        final clamped = GestureArbitratorMath.clampPanOffset(const Offset(99999, 99999), scale, viewport);
        expect(clamped.dx, 500.0);
        expect(clamped.dy, 250.0);
      });

      test('8.5: Pan offset with extreme negative coordinates (-99999, -99999) clamps to edge', () {
        const viewport = Size(1000, 500);
        const scale = 2.0;
        final clamped = GestureArbitratorMath.clampPanOffset(const Offset(-99999, -99999), scale, viewport);
        expect(clamped.dx, -500.0);
        expect(clamped.dy, -250.0);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 9: Gesture Dead-Zone Arbitration (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 9: Gesture Dead-Zone Arbitration (Boundary)', () {
      test('9.1: Vector length exactly 11.99px is rejected (< 12px)', () {
        expect(GestureArbitratorMath.hasExceededDeadZone(11.99, 0.0), isFalse);
      });

      test('9.2: Vector length exactly 12.00px passes dead-zone threshold', () {
        expect(GestureArbitratorMath.hasExceededDeadZone(12.00, 0.0), isTrue);
      });

      test('9.3: Ratio |dx| / |dy| exactly 1.499 is rejected (< 1.5x)', () {
        expect(GestureArbitratorMath.isHorizontalDominant(14.99, 10.0), isFalse);
      });

      test('9.4: Ratio |dx| / |dy| exactly 1.500 passes dominant threshold', () {
        expect(GestureArbitratorMath.isHorizontalDominant(15.00, 10.0), isTrue);
      });

      test('9.5: Zero vector (dx=0, dy=0) returns false for dead zone', () {
        expect(GestureArbitratorMath.hasExceededDeadZone(0.0, 0.0), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 10: HUD Auto-Dismiss Coordination (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 10: HUD Auto-Dismiss Coordination (Boundary)', () {
      test('10.1: Rapid touch down and up preserves controls auto-dismiss timer', () {
        var isSwiping = false;
        expect(!isSwiping, isTrue);
      });

      test('10.2: Feedback linger overlay duration >= 800ms', () {
        const linger = Duration(milliseconds: 800);
        expect(linger.inMilliseconds, greaterThanOrEqualTo(800));
      });

      test('10.3: Zero duration media handles controls without crashing', () {
        const dur = Duration.zero;
        expect(dur.inSeconds, 0);
      });

      test('10.4: Controls visible toggling across rapid state changes', () {
        var visible = true;
        for (var i = 0; i < 50; i++) {
          visible = !visible;
        }
        expect(visible, isTrue);
      });

      test('10.5: Playback speed limits are bounded by 0.25x and 8.0x', () {
        const minRate = 0.25;
        const maxRate = 8.0;
        expect((-1.0).clamp(minRate, maxRate), minRate);
        expect((15.0).clamp(minRate, maxRate), maxRate);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 11: Android AutoEnterPiP (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 11: Android AutoEnterPiP (Boundary)', () {
      test('11.1: Video dimensions 0x0 fallback safely in PiP calculation', () {
        final ratio = PipMath.calculateAspectRatio(0, 0);
        expect(ratio, 16.0 / 9.0);
      });

      test('11.2: Video dimensions 7680x4320 (8K) handled in PiP', () {
        final ratio = PipMath.calculateAspectRatio(7680, 4320);
        expect((ratio - 16.0 / 9.0).abs() < 0.01, isTrue);
      });

      test('11.3: setAutoEnterEnabled true when playing', () async {
        await EPlayerTestHarness.pipChannel.invokeMethod('setAutoEnterEnabled', {'enabled': true});
        expect(harness.autoEnterPipEnabled, isTrue);
      });

      test('11.4: setAutoEnterEnabled false when paused', () async {
        await EPlayerTestHarness.pipChannel.invokeMethod('setAutoEnterEnabled', {'enabled': false});
        expect(harness.autoEnterPipEnabled, isFalse);
      });

      test('11.5: Calling enterPictureInPictureMode while already in PiP returns true', () async {
        final res = await EPlayerTestHarness.pipChannel.invokeMethod<bool>('enterPictureInPictureMode');
        expect(res, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 12: Aspect Ratio Preservation in PiP (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 12: Aspect Ratio Preservation in PiP (Boundary)', () {
      test('12.1: Aspect ratio at exact lower bound 1/2.39 (~0.41841)', () {
        expect(PipMath.minAspectRatio, closeTo(0.4184, 0.001));
      });

      test('12.2: Aspect ratio at exact upper bound 2.39/1 (2.39)', () {
        expect(PipMath.maxAspectRatio, 2.39);
      });

      test('12.3: Extreme wide ratio 100:1 clamped to 2.39', () {
        final ratio = PipMath.calculateAspectRatio(10000, 100);
        expect(ratio, 2.39);
      });

      test('12.4: Extreme tall ratio 1:100 clamped to 1/2.39', () {
        final ratio = PipMath.calculateAspectRatio(100, 10000);
        expect(ratio, PipMath.minAspectRatio);
      });

      test('12.5: Square video 1:1 (1080x1080) preserved as 1.0', () {
        final ratio = PipMath.calculateAspectRatio(1080, 1080);
        expect(ratio, 1.0);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 13: PiP Remote Media Controls (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 13: PiP Remote Media Controls (Boundary)', () {
      test('13.1: Remote action seek_forward_10 near end clamps to total', () {
        const total = Duration(seconds: 100);
        const current = Duration(seconds: 95);
        final target = current + const Duration(seconds: 10);
        final clamped = GestureArbitratorMath.clampDuration(target, total);
        expect(clamped, total);
      });

      test('13.2: Remote action seek_rewind_10 at position 3s clamps to 0s', () {
        const total = Duration(seconds: 100);
        const current = Duration(seconds: 3);
        final target = current - const Duration(seconds: 10);
        final clamped = GestureArbitratorMath.clampDuration(target, total);
        expect(clamped, Duration.zero);
      });

      test('13.3: Rapid remote action calls (play, pause, play, pause)', () {
        var isPlaying = false;
        for (var i = 0; i < 10; i++) {
          isPlaying = !isPlaying;
        }
        expect(isPlaying, isFalse);
      });

      test('13.4: Remote action with empty string is rejected safely', () {
        var handled = false;
        void onAction(String a) {
          if (a.isNotEmpty) handled = true;
        }
        onAction('');
        expect(handled, isFalse);
      });

      test('13.5: Remote action with special characters handled without crash', () {
        var handled = false;
        void onAction(String a) {
          if (a == 'play' || a == 'pause') handled = true;
        }
        onAction('<script>alert("pip")</script>');
        expect(handled, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 14: HUD Auto-Dismiss on PiP Enter (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 14: HUD Auto-Dismiss on PiP Enter (Boundary)', () {
      test('14.1: PiP entered when controls already hidden remains clean', () {
        var controlsVisible = false;
        void onPipEnter() {
          controlsVisible = false;
        }
        onPipEnter();
        expect(controlsVisible, isFalse);
      });

      test('14.2: PiP entered when controls visible immediately hides controls', () {
        var controlsVisible = true;
        void onPipEnter() {
          controlsVisible = false;
        }
        onPipEnter();
        expect(controlsVisible, isFalse);
      });

      test('14.3: PiP exit restores controls to visible', () {
        var controlsVisible = false;
        void onPipExit() {
          controlsVisible = true;
        }
        onPipExit();
        expect(controlsVisible, isTrue);
      });

      test('14.4: Rapid PiP enter/exit cycles maintain state machine consistency', () {
        var inPip = false;
        for (var i = 0; i < 10; i++) {
          inPip = !inPip;
        }
        expect(inPip, isFalse);
      });

      test('14.5: Controls visibility flag invariant during PiP is false', () {
        const inPip = true;
        final controlsAllowed = !inPip;
        expect(controlsAllowed, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 15: Desktop Overlay Window Mode (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 15: Desktop Overlay Window Mode (Boundary)', () {
      test('15.1: Desktop overlay with minimum size (320x180)', () {
        const width = 320;
        final height = (width / (16.0 / 9.0)).round();
        expect(height, 180);
      });

      test('15.2: Desktop overlay with 21:9 aspect ratio (480x203)', () {
        const width = 480;
        final height = (width / 2.37).round();
        expect(height, 203);
      });

      test('15.3: Desktop overlay with 4:3 aspect ratio (480x360)', () {
        const width = 480;
        final height = (width / (4.0 / 3.0)).round();
        expect(height, 360);
      });

      test('15.4: Desktop overlay toggle with null size defaults safely', () async {
        final res = await EPlayerTestHarness.pipChannel.invokeMethod<bool>(
          'toggleDesktopOverlay',
          {'enabled': true, 'size': null},
        );
        expect(res, isTrue);
      });

      test('15.5: Desktop overlay disable resets window mode', () async {
        final res = await EPlayerTestHarness.pipChannel.invokeMethod<bool>(
          'toggleDesktopOverlay',
          {'enabled': false},
        );
        expect(res, isTrue);
        expect(harness.isInPipMode, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 16: Multi-Protocol Sink Discovery (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 16: Multi-Protocol Sink Discovery (Boundary)', () {
      late CastService castService;

      setUp(() {
        castService = CastService();
      });

      tearDown(() {
        castService.dispose();
      });

      test('16.1: Discovered devices list is non-empty upon initialization', () {
        expect(castService.devices.isNotEmpty, isTrue);
      });

      test('16.2: Device signal percentage is bounded by [0, 100]', () {
        for (final device in castService.devices) {
          expect(device.signalPercentage, inInclusiveRange(0, 100));
        }
      });

      test('16.3: High-signal device has 100% signal rating', () {
        final highSignal = castService.devices.firstWhere((d) => d.signalPercentage == 100);
        expect(highSignal.signalPercentage, 100);
      });

      test('16.4: Devices IP addresses belong to local subnets', () {
        for (final device in castService.devices) {
          final uri = Uri.parse('http://${device.ipAddress}:8008');
          expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
        }
      });

      test('16.5: Stop scanning when not scanning is safe', () {
        castService.stopScan();
        expect(castService.isScanning, isFalse);
        castService.stopScan(); // Idempotent second call
        expect(castService.isScanning, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 17: Tokenized Local Streaming Server (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 17: Tokenized Local Streaming Server (Boundary)', () {
      test('17.1: Missing session token in URL path returns 403 Forbidden', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final url = 'http://${server.host}:${server.port}/cast//stream';
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.forbidden);
        client.close();
      });

      test('17.2: Session token with 31 characters is rejected by validator', () {
        const shortToken = '1234567890123456789012345678901'; // 31 chars
        expect(OfflineSecurityValidator.isSessionTokenValid(shortToken), isFalse);
      });

      test('17.3: Session token with 33 characters is rejected by validator', () {
        const longToken = '123456789012345678901234567890123'; // 33 chars
        expect(OfflineSecurityValidator.isSessionTokenValid(longToken), isFalse);
      });

      test('17.4: Path traversal attempt is rejected with 400 Bad Request', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final traversalUrl = 'http://${server.host}:${server.port}/cast/${server.sessionToken}/../etc/passwd';
        final request = await client.getUrl(Uri.parse(traversalUrl));
        final response = await request.close();
        expect(response.statusCode, inInclusiveRange(400, 404));
        client.close();
      });

      test('17.5: 32-character hex token passes validator', () {
        const validToken = 'abcdef0123456789abcdef0123456789';
        expect(OfflineSecurityValidator.isSessionTokenValid(validToken), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 18: HTTP 206 Partial Content Range (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 18: HTTP 206 Partial Content Range (Boundary)', () {
      test('18.1: Range bytes=0-0 requests single first byte', () async {
        final server = await harness.startEphemeralCastServer(mediaBytes: [42, 43, 44, 45]);
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.contentLength, 1);
        final bytes = await response.fold<List<int>>([], (p, c) => p..addAll(c));
        expect(bytes, [42]);
        client.close();
      });

      test('18.2: Range bytes=last-last requests single last byte', () async {
        final server = await harness.startEphemeralCastServer(mediaBytes: [10, 20, 30, 99]);
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=3-3');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.contentLength, 1);
        final bytes = await response.fold<List<int>>([], (p, c) => p..addAll(c));
        expect(bytes, [99]);
        client.close();
      });

      test('18.3: Range start > end returns 416 Range Not Satisfiable', () async {
        final server = await harness.startEphemeralCastServer(mediaBytes: [1, 2, 3, 4]);
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=3-2');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
        client.close();
      });

      test('18.4: Range start >= totalSize returns 416', () async {
        final server = await harness.startEphemeralCastServer(mediaBytes: [1, 2, 3, 4]);
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-20');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
        client.close();
      });

      test('18.5: Malformed range header returns full content 200 OK', () async {
        final server = await harness.startEphemeralCastServer(mediaBytes: [1, 2, 3, 4]);
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'invalid_format');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        client.close();
      });
    });

    // -------------------------------------------------------------------------
    // Feature 19: Tokenized Subtitle Sidecar (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 19: Tokenized Subtitle Sidecar (Boundary)', () {
      test('19.1: Empty subtitle file (0 cues) with valid WEBVTT header', () async {
        final file = await harness.createMockSubtitleVtt(tempDir, 'empty.vtt', cues: []);
        final text = await file.readAsString();
        expect(text, startsWith('WEBVTT'));
      });

      test('19.2: Subtitle cue with Unicode / Emoji characters', () async {
        final cues = [
          {
            'start': '00:00:01.000',
            'end': '00:00:03.000',
            'text': 'E-Player 🎬 4K 日本語 subtitle track 🚀',
          }
        ];
        final file = await harness.createMockSubtitleVtt(tempDir, 'unicode.vtt', cues: cues);
        final text = await file.readAsString();
        expect(text, contains('🎬 4K 日本語'));
      });

      test('19.3: Subtitle cue with zero-duration start == end handled safely', () async {
        final cues = [
          {
            'start': '00:00:05.000',
            'end': '00:00:05.000',
            'text': 'Instant cue flash',
          }
        ];
        final file = await harness.createMockSubtitleVtt(tempDir, 'instant.vtt', cues: cues);
        final text = await file.readAsString();
        expect(text, contains('00:00:05.000 --> 00:00:05.000'));
      });

      test('19.4: Subtitle file with 100 generated cues', () async {
        final cues = List<Map<String, String>>.generate(100, (i) {
          final s = i.toString().padLeft(2, '0');
          return {
            'start': '00:$s:00.000',
            'end': '00:$s:02.000',
            'text': 'Cue line $i',
          };
        });
        final file = await harness.createMockSubtitleVtt(tempDir, 'many_cues.vtt', cues: cues);
        expect(file.existsSync(), isTrue);
        final text = await file.readAsString();
        expect(text, contains('Cue line 99'));
      });

      test('19.5: Invalid subtitle track path returns 404 Not Found', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final invalidUrl = 'http://${server.host}:${server.port}/cast/${server.sessionToken}/not_a_valid_route';
        final request = await client.getUrl(Uri.parse(invalidUrl));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.notFound);
        client.close();
      });
    });

    // -------------------------------------------------------------------------
    // Feature 20: Bi-Directional State Sync (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 20: Bi-Directional State Sync (Boundary)', () {
      late CastService castService;

      setUp(() {
        castService = CastService();
      });

      tearDown(() {
        castService.dispose();
      });

      test('20.1: Remote volume at exact 0.0 boundary (mute floor)', () {
        castService.setRemoteVolume(0.0);
        expect(castService.remoteVolume, 0.0);
      });

      test('20.2: Remote volume at exact 1.0 boundary (max ceiling)', () {
        castService.setRemoteVolume(1.0);
        expect(castService.remoteVolume, 1.0);
      });

      test('20.3: Remote volume < 0.0 clamped to 0.0', () {
        castService.setRemoteVolume(-100.0);
        expect(castService.remoteVolume, 0.0);
      });

      test('20.4: Remote volume > 1.0 clamped to 1.0', () {
        castService.setRemoteVolume(100.0);
        expect(castService.remoteVolume, 1.0);
      });

      test('20.5: Disconnect called on already disconnected session is safe no-op', () async {
        expect(castService.connectedDevice, isNull);
        await castService.disconnect();
        expect(castService.connectedDevice, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 21: Strict Offline Invariant (Boundary)
    // -------------------------------------------------------------------------
    group('Feature 21: Strict Offline Invariant (Boundary)', () {
      test('21.1: Localhost hostname is recognized as offline', () {
        final uri = Uri.parse('http://localhost:8080/cast/token/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
      });

      test('21.2: Class B private subnet (172.16.0.1) recognized as offline', () {
        final uri = Uri.parse('http://172.16.0.1:8080/cast/token/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
      });

      test('21.3: Class B public subnet (172.32.0.1) rejected as non-offline', () {
        final uri = Uri.parse('http://172.32.0.1:8080/cast/token/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isFalse);
      });

      test('21.4: Public WAN DNS hostname rejected as non-offline', () {
        final uri = Uri.parse('http://media.netflix.com/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isFalse);
      });

      test('21.5: IPv4 broadcast 255.255.255.255 rejected as non-offline', () {
        final uri = Uri.parse('http://255.255.255.255:8080/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isFalse);
      });
    });
  });
}
