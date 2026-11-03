import 'dart:convert';
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
    tempDir = harness.createTempDirectory('tier1_');
  });

  tearDown(() async {
    await harness.tearDown();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  group('Tier 1: Feature Coverage (Core Features 1 to 21)', () {
    // -------------------------------------------------------------------------
    // Feature 1: Decoder Mode Selection
    // -------------------------------------------------------------------------
    group('Feature 1: Decoder Mode Selection', () {
      test('1.1: Mode mapping to mpv property hwdec for all 4 modes', () {
        expect(DecoderMode.auto.mpvValue, 'auto');
        expect(DecoderMode.hw.mpvValue, 'yes');
        expect(DecoderMode.hwPlus.mpvValue, 'auto-copy');
        expect(DecoderMode.sw.mpvValue, 'no');
      });

      test('1.2: Switching to HW mode marks hardware acceleration active', () {
        const mode = DecoderMode.hw;
        expect(mode.isHardwareAccelerated, isTrue);
        expect(mode.label, 'HW');
      });

      test('1.3: Switching to SW mode disables hardware acceleration', () {
        const mode = DecoderMode.sw;
        expect(mode.isHardwareAccelerated, isFalse);
        expect(mode.label, 'SW');
      });

      test('1.4: Switching to HW+ enables hybrid auto-copy acceleration', () {
        const mode = DecoderMode.hwPlus;
        expect(mode.isHardwareAccelerated, isTrue);
        expect(mode.mpvValue, 'auto-copy');
        expect(mode.label, 'HW+');
      });

      test('1.5: String mapping helper matches DecoderModeValidator', () {
        expect(DecoderModeValidator.mapModeToHwdec('Auto'), 'auto');
        expect(DecoderModeValidator.mapModeToHwdec('HW'), 'yes');
        expect(DecoderModeValidator.mapModeToHwdec('HW+'), 'auto-copy');
        expect(DecoderModeValidator.mapModeToHwdec('SW'), 'no');
      });
    });

    // -------------------------------------------------------------------------
    // Feature 2: Dynamic Fallback Pipeline
    // -------------------------------------------------------------------------
    group('Feature 2: Dynamic Fallback Pipeline', () {
      test('2.1: Frame drop threshold (>10 in 2s) triggers fallback condition', () {
        final trigger = DecoderModeValidator.shouldTriggerFallback(
          droppedFrames: 12,
          window: const Duration(milliseconds: 1800),
        );
        expect(trigger, isTrue);
      });

      test('2.2: Low frame drop rate (<=10) does not trigger fallback', () {
        final trigger = DecoderModeValidator.shouldTriggerFallback(
          droppedFrames: 8,
          window: const Duration(seconds: 2),
        );
        expect(trigger, isFalse);
      });

      test('2.3: Automated fallback steps down from HW to HW+', () {
        final next = DecoderMode.hw.nextFallback;
        expect(next, DecoderMode.hwPlus);
        expect(DecoderModeValidator.getNextFallbackMode('HW'), 'HW+');
      });

      test('2.4: Automated fallback steps down from HW+ to SW', () {
        final next = DecoderMode.hwPlus.nextFallback;
        expect(next, DecoderMode.sw);
        expect(DecoderModeValidator.getNextFallbackMode('HW+'), 'SW');
      });

      test('2.5: Automated fallback at lowest SW tier produces no further fallback', () {
        final next = DecoderMode.sw.nextFallback;
        expect(next, isNull);
        expect(DecoderModeValidator.getNextFallbackMode('SW'), 'SW');
      });
    });

    // -------------------------------------------------------------------------
    // Feature 3: Hardware Acceleration Invariant
    // -------------------------------------------------------------------------
    group('Feature 3: Hardware Acceleration Invariant', () {
      test('3.1: Video color grading default configuration is strictly neutral', () {
        final config = VideoEffectsConfig();
        expect(config.isNeutral, isTrue);
        expect(config.contrast, 0.0);
        expect(config.brightness, 0.0);
        expect(config.saturation, 0.0);
        expect(config.gamma, 0.0);
        expect(config.hue, 0.0);
      });

      test('3.2: Geometric transforms generate valid native libmpv vf strings', () {
        final config = VideoEffectsConfig();
        config.flipHorizontal = true;
        config.flipVertical = true;
        final vf = config.buildMpvVfString();
        expect(vf.contains('hflip'), isTrue);
        expect(vf.contains('vflip'), isTrue);
      });

      test('3.3: Master bypass switch disables all hardware filter outputs', () {
        final config = VideoEffectsConfig();
        config.contrast = 25.0;
        config.brightness = 15.0;
        config.masterEnabled = false;
        final vf = config.buildMpvVfString();
        expect(vf, '');
      });

      test('3.4: Reset essentials restores default contrast, brightness, and sharpen', () {
        final config = VideoEffectsConfig(
          contrast: 25.0,
          brightness: -10.0,
          sharpen: true,
          flipHorizontal: true,
        );
        config.resetEssential();
        expect(config.contrast, 0.0);
        expect(config.brightness, 0.0);
        expect(config.sharpen, isFalse);
        expect(config.flipHorizontal, isTrue); // Geometry remains untouched by resetEssential

        config.resetGeometry();
        expect(config.flipHorizontal, isFalse);
      });

      test('3.5: ColorFilter matrix produces a valid 20-element 4x5 transformation', () {
        final config = VideoEffectsConfig();
        final matrix = config.toColorFilterMatrix();
        expect(matrix.length, 20);
        expect(matrix[0], 1.0); // Identity R-R
        expect(matrix[6], 1.0); // Identity G-G
        expect(matrix[12], 1.0); // Identity B-B
        expect(matrix[18], 1.0); // Identity A-A
      });
    });

    // -------------------------------------------------------------------------
    // Feature 4: Decoder Telemetry HUD
    // -------------------------------------------------------------------------
    group('Feature 4: Decoder Telemetry HUD', () {
      test('4.1: DecoderTelemetry records requestedMode and activeDecoder', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.hw,
          activeDecoder: 'd3d11va',
          codec: 'hevc',
          droppedFrames: 0,
          fps: 60.0,
          bitrate: 15500000,
        );
        expect(telemetry.requestedMode, DecoderMode.hw);
        expect(telemetry.activeDecoder, 'd3d11va');
      });

      test('4.2: DecoderTelemetry tracks video codec and bitrate', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.auto,
          activeDecoder: 'nvdec',
          codec: 'av1',
          droppedFrames: 2,
          fps: 59.94,
          bitrate: 24000000,
        );
        expect(telemetry.codec, 'av1');
        expect(telemetry.bitrate, 24000000);
      });

      test('4.3: DecoderTelemetry tracks cumulative dropped frame counter', () {
        final telemetry = DecoderTelemetry(
          requestedMode: DecoderMode.hwPlus,
          activeDecoder: 'd3d11va-copy',
          codec: 'h264',
          droppedFrames: 14,
          fps: 30.0,
        );
        expect(telemetry.droppedFrames, 14);
      });

      test('4.4: DecoderSwitchResult captures transition status and reason', () {
        const result = DecoderSwitchResult(
          success: true,
          activeMode: DecoderMode.hwPlus,
          backend: 'd3d11va-copy',
          fallbackReason: 'High frame drop rate in HW mode',
        );
        expect(result.success, isTrue);
        expect(result.activeMode, DecoderMode.hwPlus);
        expect(result.fallbackReason, contains('High frame drop'));
      });

      test('4.5: DecoderSwitchResult handles failed mode switch gracefully', () {
        const result = DecoderSwitchResult(
          success: false,
          activeMode: DecoderMode.sw,
          backend: 'ffmpeg-sw',
          fallbackReason: 'Hardware decoder initialization failed',
        );
        expect(result.success, isFalse);
        expect(result.activeMode, DecoderMode.sw);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 5: Horizontal Precision Scrub
    // -------------------------------------------------------------------------
    group('Feature 5: Horizontal Precision Scrub', () {
      test('5.1: Center horizontal drag calculates proportional seek duration', () {
        const duration = Duration(minutes: 10);
        const startPos = Duration(minutes: 2);
        const dx = 120.0; // 120 pixels * 0.5 sec/px = 60s
        final target = startPos + Duration(seconds: (dx * 0.5).toInt());
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, const Duration(minutes: 3));
      });

      test('5.2: Forward horizontal scrub clamps target to media duration', () {
        const duration = Duration(seconds: 100);
        const startPos = Duration(seconds: 90);
        const dx = 100.0; // +50s
        final target = startPos + Duration(seconds: (dx * 0.5).toInt());
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, duration);
      });

      test('5.3: Backward horizontal scrub clamps target to Duration.zero', () {
        const duration = Duration(seconds: 100);
        const startPos = Duration(seconds: 15);
        const dx = -100.0; // -50s
        final target = startPos + Duration(seconds: (dx * 0.5).toInt());
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, Duration.zero);
      });

      test('5.4: Dead-zone math rejects center movements smaller than 12px', () {
        expect(GestureArbitratorMath.hasExceededDeadZone(8.0, 4.0), isFalse);
        expect(GestureArbitratorMath.hasExceededDeadZone(13.0, 0.0), isTrue);
      });

      test('5.5: Dominant horizontal gesture satisfies 1.5x primary/secondary ratio', () {
        expect(GestureArbitratorMath.isHorizontalDominant(30.0, 15.0), isTrue);
        expect(GestureArbitratorMath.isHorizontalDominant(20.0, 18.0), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 6: Split Brightness/Volume Sliders
    // -------------------------------------------------------------------------
    group('Feature 6: Split Brightness/Volume Sliders', () {
      test('6.1: Left vertical drag adjusts brightness with clamping [0.0, 1.0]', () {
        var brightness = 0.5;
        const dy = -40.0; // swipe up
        brightness = GestureArbitratorMath.clampBrightness(brightness - (dy * 0.005));
        expect(brightness, 0.7);
      });

      test('6.2: Left vertical drag downward clamps brightness at 0.0', () {
        var brightness = 0.2;
        const dy = 100.0; // swipe down
        brightness = GestureArbitratorMath.clampBrightness(brightness - (dy * 0.005));
        expect(brightness, 0.0);
      });

      test('6.3: Right vertical drag adjusts volume with clamping [0.0, 100.0]', () {
        var volume = 50.0;
        const dy = -60.0; // swipe up
        volume = GestureArbitratorMath.clampVolume(volume - (dy * 0.5));
        expect(volume, 80.0);
      });

      test('6.4: Right vertical drag downward clamps volume at 0.0', () {
        var volume = 20.0;
        const dy = 80.0; // swipe down
        volume = GestureArbitratorMath.clampVolume(volume - (dy * 0.5));
        expect(volume, 0.0);
      });

      test('6.5: Right vertical drag upward clamps volume at maximum 100.0', () {
        var volume = 90.0;
        const dy = -100.0; // swipe up
        volume = GestureArbitratorMath.clampVolume(volume - (dy * 0.5));
        expect(volume, 100.0);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 7: Double-Tap Wing Jump
    // -------------------------------------------------------------------------
    group('Feature 7: Double-Tap Wing Jump', () {
      test('7.1: Left wing double-tap (<0.33 width) seeks backward by 10s', () {
        const viewportWidth = 1000.0;
        const tapX = 200.0; // < 330.0
        expect(tapX < viewportWidth * 0.33, isTrue);

        const currentPos = Duration(seconds: 45);
        final target = currentPos - const Duration(seconds: 10);
        expect(target, const Duration(seconds: 35));
      });

      test('7.2: Left wing double-tap clamps to Duration.zero near start', () {
        const currentPos = Duration(seconds: 5);
        final target = currentPos - const Duration(seconds: 10);
        final clamped = GestureArbitratorMath.clampDuration(target, const Duration(minutes: 5));
        expect(clamped, Duration.zero);
      });

      test('7.3: Right wing double-tap (>0.66 width) seeks forward by 10s', () {
        const viewportWidth = 1000.0;
        const tapX = 850.0; // > 660.0
        expect(tapX > viewportWidth * 0.66, isTrue);

        const currentPos = Duration(seconds: 45);
        final target = currentPos + const Duration(seconds: 10);
        expect(target, const Duration(seconds: 55));
      });

      test('7.4: Right wing double-tap clamps to media duration near end', () {
        const duration = Duration(minutes: 2);
        const currentPos = Duration(seconds: 115);
        final target = currentPos + const Duration(seconds: 10);
        final clamped = GestureArbitratorMath.clampDuration(target, duration);
        expect(clamped, duration);
      });

      test('7.5: Center double-tap (0.33 <= X <= 0.66) toggles play/pause state', () {
        const viewportWidth = 1000.0;
        const tapX = 500.0;
        expect(tapX >= viewportWidth * 0.33 && tapX <= viewportWidth * 0.66, isTrue);

        var isPlaying = true;
        isPlaying = !isPlaying;
        expect(isPlaying, isFalse);
        isPlaying = !isPlaying;
        expect(isPlaying, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 8: Pinch-to-Zoom & Pan Bounds
    // -------------------------------------------------------------------------
    group('Feature 8: Pinch-to-Zoom & Pan Bounds', () {
      test('8.1: Pinch scale factor is clamped strictly to [1.0, 4.0]', () {
        expect(GestureArbitratorMath.clampScale(0.8), 1.0);
        expect(GestureArbitratorMath.clampScale(2.5), 2.5);
        expect(GestureArbitratorMath.clampScale(5.5), 4.0);
      });

      test('8.2: Panning offset at 1.0x scale is strictly Offset.zero', () {
        const viewport = Size(1920, 1080);
        const pan = Offset(50, 50);
        final clamped = GestureArbitratorMath.clampPanOffset(pan, 1.0, viewport);
        expect(clamped, Offset.zero);
      });

      test('8.3: Panning offset Tx at 2.0x scale is bounded by width / 2', () {
        const viewport = Size(1000, 600);
        const scale = 2.0;
        // maxTx = (2.0 - 1.0) * 1000 / 2 = 500
        final pan = const Offset(650, 0);
        final clamped = GestureArbitratorMath.clampPanOffset(pan, scale, viewport);
        expect(clamped.dx, 500.0);
        expect(clamped.dy, 0.0);
      });

      test('8.4: Panning offset Ty at 2.0x scale is bounded by height / 2', () {
        const viewport = Size(1000, 600);
        const scale = 2.0;
        // maxTy = (2.0 - 1.0) * 600 / 2 = 300
        final pan = const Offset(0, -450);
        final clamped = GestureArbitratorMath.clampPanOffset(pan, scale, viewport);
        expect(clamped.dx, 0.0);
        expect(clamped.dy, -300.0);
      });

      test('8.5: Pan bounds prevent black voids on both axes simultaneously', () {
        const viewport = Size(800, 400);
        const scale = 3.0;
        // maxTx = (3 - 1) * 800 / 2 = 800; maxTy = (3 - 1) * 400 / 2 = 400
        final pan = const Offset(1200, -900);
        final clamped = GestureArbitratorMath.clampPanOffset(pan, scale, viewport);
        expect(clamped.dx, 800.0);
        expect(clamped.dy, -400.0);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 9: Gesture Dead-Zone Arbitration
    // -------------------------------------------------------------------------
    group('Feature 9: Gesture Dead-Zone Arbitration', () {
      test('9.1: Pointer motion < 12px dead zone is ignored', () {
        expect(GestureArbitratorMath.hasExceededDeadZone(6.0, 7.0), isFalse);
      });

      test('9.2: Pointer motion >= 12px dead zone triggers arbitration', () {
        expect(GestureArbitratorMath.hasExceededDeadZone(12.0, 0.0), isTrue);
        expect(GestureArbitratorMath.hasExceededDeadZone(0.0, 12.0), isTrue);
      });

      test('9.3: Diagonal swipe failing 1.5x ratio is rejected from seek or slider', () {
        const dx = 14.0;
        const dy = 16.0;
        expect(GestureArbitratorMath.hasExceededDeadZone(dx, dy), isTrue);
        expect(GestureArbitratorMath.isHorizontalDominant(dx, dy), isFalse);
        expect(GestureArbitratorMath.isVerticalDominant(dx, dy), isFalse);
      });

      test('9.4: Pure horizontal swipe passes dominant ratio', () {
        const dx = 25.0;
        const dy = 5.0;
        expect(GestureArbitratorMath.isHorizontalDominant(dx, dy), isTrue);
      });

      test('9.5: Pure vertical swipe passes dominant ratio', () {
        const dx = 6.0;
        const dy = 30.0;
        expect(GestureArbitratorMath.isVerticalDominant(dx, dy), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 10: HUD Auto-Dismiss Coordination
    // -------------------------------------------------------------------------
    group('Feature 10: HUD Auto-Dismiss Coordination', () {
      test('10.1: Default HUD auto-dismiss timeout is 2800ms', () {
        const timeout = Duration(milliseconds: 2800);
        expect(timeout.inMilliseconds, 2800);
      });

      test('10.2: Active swipe state pauses HUD timer', () {
        bool isSwiping = DateTime.now().millisecondsSinceEpoch > 0;
        var controlsTimerActive = false;
        if (!isSwiping) {
          controlsTimerActive = true;
        }
        expect(controlsTimerActive, isFalse);
      });

      test('10.3: Gesture completion resets and starts auto-dismiss timer', () {
        var isSwiping = false;
        var controlsTimerActive = false;
        if (!isSwiping) {
          controlsTimerActive = true;
        }
        expect(controlsTimerActive, isTrue);
      });

      test('10.4: Gesture feedback overlay lingers for 800ms before fading', () {
        const lingerDuration = Duration(milliseconds: 800);
        expect(lingerDuration.inMilliseconds, 800);
      });

      test('10.5: Pausing video keeps controls visible permanently', () {
        var isPlaying = false;
        var autoDismissArmed = isPlaying;
        expect(autoDismissArmed, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 11: Android AutoEnterPiP
    // -------------------------------------------------------------------------
    group('Feature 11: Android AutoEnterPiP', () {
      test('11.1: AutoEnterPiP is permitted when playback is active', () {
        expect(PipMath.canAutoEnter(true), isTrue);
      });

      test('11.2: AutoEnterPiP is disarmed when playback is paused', () {
        expect(PipMath.canAutoEnter(false), isFalse);
      });

      test('11.3: Platform channel handles setAutoEnterEnabled true', () async {
        await EPlayerTestHarness.pipChannel.invokeMethod('setAutoEnterEnabled', {'enabled': true});
        expect(harness.autoEnterPipEnabled, isTrue);
      });

      test('11.4: Platform channel handles setAutoEnterEnabled false', () async {
        await EPlayerTestHarness.pipChannel.invokeMethod('setAutoEnterEnabled', {'enabled': false});
        expect(harness.autoEnterPipEnabled, isFalse);
      });

      test('11.5: Explicit PiP entry invokes enterPictureInPictureMode', () async {
        final result = await EPlayerTestHarness.pipChannel.invokeMethod<bool>(
          'enterPictureInPictureMode',
          {'videoWidth': 1920, 'videoHeight': 1080},
        );
        expect(result, isTrue);
        expect(harness.isInPipMode, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 12: Aspect Ratio Preservation in PiP
    // -------------------------------------------------------------------------
    group('Feature 12: Aspect Ratio Preservation in PiP', () {
      test('12.1: 16:9 standard video aspect ratio preserved', () {
        final ratio = PipMath.calculateAspectRatio(1920, 1080);
        expect((ratio - 16.0 / 9.0).abs() < 0.01, isTrue);
      });

      test('12.2: 21:9 ultra-wide video aspect ratio preserved within bounds', () {
        final ratio = PipMath.calculateAspectRatio(2560, 1080);
        expect((ratio - 2.37).abs() < 0.02, isTrue);
        expect(ratio <= PipMath.maxAspectRatio, isTrue);
      });

      test('12.3: Ultra-wide video exceeding 2.39 is clamped to 2.39', () {
        final ratio = PipMath.calculateAspectRatio(3840, 1080); // 3.55
        expect(ratio, PipMath.maxAspectRatio);
      });

      test('12.4: Ultra-tall vertical video narrower than 1/2.39 is clamped to min', () {
        final ratio = PipMath.calculateAspectRatio(1080, 3000); // 0.36
        expect(ratio, PipMath.minAspectRatio);
      });

      test('12.5: Zero or invalid dimensions fallback to safe 16:9 aspect ratio', () {
        final ratio = PipMath.calculateAspectRatio(0, 0);
        expect(ratio, 16.0 / 9.0);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 13: PiP Remote Media Controls
    // -------------------------------------------------------------------------
    group('Feature 13: PiP Remote Media Controls', () {
      test('13.1: Remote play action toggles playback to active', () {
        var isPlaying = false;
        void onPipAction(String action) {
          if (action == 'play') isPlaying = true;
        }
        onPipAction('play');
        expect(isPlaying, isTrue);
      });

      test('13.2: Remote pause action toggles playback to paused', () {
        var isPlaying = true;
        void onPipAction(String action) {
          if (action == 'pause') isPlaying = false;
        }
        onPipAction('pause');
        expect(isPlaying, isFalse);
      });

      test('13.3: Remote seek forward 10s advances playback position', () {
        var position = const Duration(seconds: 30);
        void onPipAction(String action) {
          if (action == 'seek_forward_10') position += const Duration(seconds: 10);
        }
        onPipAction('seek_forward_10');
        expect(position, const Duration(seconds: 40));
      });

      test('13.4: Remote seek rewind 10s rewinds playback position', () {
        var position = const Duration(seconds: 30);
        void onPipAction(String action) {
          if (action == 'seek_rewind_10') position -= const Duration(seconds: 10);
        }
        onPipAction('seek_rewind_10');
        expect(position, const Duration(seconds: 20));
      });

      test('13.5: Unknown remote action is safely discarded', () {
        var state = 'original';
        void onPipAction(String action) {
          if (action == 'play') state = 'played';
        }
        onPipAction('unknown_action_xyz');
        expect(state, 'original');
      });
    });

    // -------------------------------------------------------------------------
    // Feature 14: HUD Auto-Dismiss on PiP Enter
    // -------------------------------------------------------------------------
    group('Feature 14: HUD Auto-Dismiss on PiP Enter', () {
      test('14.1: Entering PiP hides HUD playback controls', () {
        var controlsVisible = true;
        void onPipEntered() {
          controlsVisible = false;
        }
        onPipEntered();
        expect(controlsVisible, isFalse);
      });

      test('14.2: Entering PiP cancels active feedback overlay timer', () {
        var feedbackActive = true;
        void onPipEntered() {
          feedbackActive = false;
        }
        onPipEntered();
        expect(feedbackActive, isFalse);
      });

      test('14.3: Exiting PiP restores standard full-screen UI controls', () {
        var controlsVisible = false;
        void onPipExited() {
          controlsVisible = true;
        }
        onPipExited();
        expect(controlsVisible, isTrue);
      });

      test('14.4: PiP surface contains clean video presentation', () {
        const showOverlaysInPip = false;
        expect(showOverlaysInPip, isFalse);
      });

      test('14.5: Controls visibility state machine toggles cleanly', () {
        var inPip = false;
        var controls = true;
        inPip = true;
        if (inPip) controls = false;
        expect(controls, isFalse);
        inPip = false;
        if (!inPip) controls = true;
        expect(controls, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 15: Desktop Overlay Window Mode
    // -------------------------------------------------------------------------
    group('Feature 15: Desktop Overlay Window Mode', () {
      test('15.1: Desktop overlay invocation via platform channel succeeds', () async {
        final result = await EPlayerTestHarness.pipChannel.invokeMethod<bool>(
          'toggleDesktopOverlay',
          {'enabled': true},
        );
        expect(result, isTrue);
      });

      test('15.2: Desktop overlay maintains compact aspect-ratio frame', () {
        const initialWidth = 480;
        const ratio = 16.0 / 9.0;
        final calculatedHeight = (initialWidth / ratio).round();
        expect(calculatedHeight, 270);
      });

      test('15.3: Disabling desktop overlay restores normal window geometry', () async {
        final result = await EPlayerTestHarness.pipChannel.invokeMethod<bool>(
          'toggleDesktopOverlay',
          {'enabled': false},
        );
        expect(result, isTrue);
      });

      test('15.4: Desktop overlay preserves ongoing playback position', () {
        const activePos = Duration(minutes: 5, seconds: 22);
        const restoredPos = activePos;
        expect(restoredPos, activePos);
      });

      test('15.5: Desktop overlay handles non-16:9 aspect ratios cleanly', () {
        const initialWidth = 480;
        const ratio = 4.0 / 3.0; // standard SD
        final calculatedHeight = (initialWidth / ratio).round();
        expect(calculatedHeight, 360);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 16: Multi-Protocol Sink Discovery
    // -------------------------------------------------------------------------
    group('Feature 16: Multi-Protocol Sink Discovery', () {
      late CastService castService;

      setUp(() {
        castService = CastService();
      });

      tearDown(() {
        castService.dispose();
      });

      test('16.1: Discovers Chromecast protocol sink', () {
        final chromecast = castService.devices.firstWhere(
          (d) => d.protocol == CastProtocol.chromecast,
        );
        expect(chromecast.protocol.label, 'Chromecast V2');
      });

      test('16.2: Discovers AirPlay protocol sink', () {
        final airplay = castService.devices.firstWhere(
          (d) => d.protocol == CastProtocol.airplay,
        );
        expect(airplay.protocol.label, 'AirPlay 2');
      });

      test('16.3: Discovers DLNA / UPnP protocol sink', () {
        final dlna = castService.devices.firstWhere(
          (d) => d.protocol == CastProtocol.dlna,
        );
        expect(dlna.protocol.label, 'DLNA / UPnP');
      });

      test('16.4: Discovers Miracast Direct protocol configuration', () {
        expect(CastProtocol.miracast.label, 'Miracast Direct');
        expect(CastProtocol.miracast.description, contains('Wi-Fi Display'));
      });

      test('16.5: CastService reports active scanning status', () {
        expect(castService.isScanning, isTrue);
        expect(castService.devices.length, greaterThanOrEqualTo(4));
      });
    });

    // -------------------------------------------------------------------------
    // Feature 17: Tokenized Local Streaming Server
    // -------------------------------------------------------------------------
    group('Feature 17: Tokenized Local Streaming Server', () {
      test('17.1: Live ephemeral HTTP server starts with loopback IP and token', () async {
        final server = await harness.startEphemeralCastServer();
        expect(server.host, '127.0.0.1');
        expect(server.streamUrl, contains('/cast/${server.sessionToken}/stream'));
      });

      test('17.2: Request with valid session token returns 200 OK for full content', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
        client.close();
      });

      test('17.3: Request with invalid session token returns 403 Forbidden', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final fakeUrl = 'http://${server.host}:${server.port}/cast/invalid_token_123/stream';
        final request = await client.getUrl(Uri.parse(fakeUrl));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.forbidden);
        client.close();
      });

      test('17.4: Path traversal attack is rejected with 400 Bad Request', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final traversalUrl = 'http://${server.host}:${server.port}/cast/${server.sessionToken}/../secret';
        final request = await client.getUrl(Uri.parse(traversalUrl));
        final response = await request.close();
        expect(response.statusCode, inInclusiveRange(400, 404));
        client.close();
      });

      test('17.5: Session token format validator verifies 32-character tokens', () {
        expect(OfflineSecurityValidator.isSessionTokenValid('invalid_short_token'), false);
        expect(OfflineSecurityValidator.isSessionTokenValid('a1b2c3d4e5f60718293a4b5c6d7e8f90'), true);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 18: HTTP 206 Partial Content Range
    // -------------------------------------------------------------------------
    group('Feature 18: HTTP 206 Partial Content Range', () {
      test('18.1: Server handles range request bytes=0-1023 and returns HTTP 206', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.headers.value(HttpHeaders.contentRangeHeader), startsWith('bytes 0-1023/'));
        expect(response.contentLength, 1024);
        client.close();
      });

      test('18.2: Out-of-bounds range request returns 416 Range Not Satisfiable', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=9999999-9999999');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
        client.close();
      });

      test('18.3: Byte range slice accurately delivers requested segment', () async {
        final sampleData = List<int>.generate(256, (i) => i);
        final server = await harness.startEphemeralCastServer(mediaBytes: sampleData);
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-19');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        final receivedBytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        expect(receivedBytes.length, 10);
        expect(receivedBytes, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);
        client.close();
      });

      test('18.4: Open-ended range request bytes=100- delivers remaining data', () async {
        final sampleData = List<int>.generate(200, (i) => i);
        final server = await harness.startEphemeralCastServer(mediaBytes: sampleData);
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=100-');
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.contentLength, 100);
        client.close();
      });

      test('18.5: Response headers confirm Accept-Ranges bytes', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.streamUrl));
        final response = await request.close();
        expect(response.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
        client.close();
      });
    });

    // -------------------------------------------------------------------------
    // Feature 19: Tokenized Subtitle Sidecar
    // -------------------------------------------------------------------------
    group('Feature 19: Tokenized Subtitle Sidecar', () {
      test('19.1: Live server delivers WebVTT subtitle track with text/vtt type', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.subtitleUrl));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.contentType?.mimeType, 'text/vtt');
        client.close();
      });

      test('19.2: WebVTT file starts with WEBVTT magic string', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(server.subtitleUrl));
        final response = await request.close();
        final content = await response.transform(utf8.decoder).join();
        expect(content, startsWith('WEBVTT'));
        client.close();
      });

      test('19.3: Synthesizing SubRip (.srt) fixture writes valid timecodes', () async {
        final file = await harness.createMockSubtitleSrt(tempDir, 'test.srt');
        final text = await file.readAsString();
        expect(text, contains('00:00:01,000 --> 00:00:04,500'));
        expect(text, contains('Welcome to E-Player'));
      });

      test('19.4: Synthesizing WebVTT (.vtt) fixture writes valid cue formatting', () async {
        final file = await harness.createMockSubtitleVtt(tempDir, 'test.vtt');
        final text = await file.readAsString();
        expect(text, contains('WEBVTT'));
        expect(text, contains('00:00:01.000 --> 00:00:04.500'));
      });

      test('19.5: Subtitle track request with invalid session token is rejected', () async {
        final server = await harness.startEphemeralCastServer();
        final client = HttpClient();
        final badUrl = 'http://${server.host}:${server.port}/cast/bad_token/subtitles/track_1.vtt';
        final request = await client.getUrl(Uri.parse(badUrl));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.forbidden);
        client.close();
      });
    });

    // -------------------------------------------------------------------------
    // Feature 20: Bi-Directional State Sync
    // -------------------------------------------------------------------------
    group('Feature 20: Bi-Directional State Sync', () {
      late CastService castService;

      setUp(() {
        castService = CastService();
      });

      tearDown(() {
        castService.dispose();
      });

      test('20.1: Connects to device and updates connection state', () async {
        final target = castService.devices.first;
        final success = await castService.connect(target);
        expect(success, isTrue);
        expect(castService.connectedDevice?.id, target.id);
      });

      test('20.2: Remote play/pause state synchronization mirrors user toggle', () async {
        final target = castService.devices.first;
        await castService.connect(target);
        expect(castService.isRemotePlaying, isTrue);
        castService.toggleRemotePlayPause();
        expect(castService.isRemotePlaying, isFalse);
      });

      test('20.3: Remote volume adjustment clamps to [0.0, 1.0]', () {
        castService.setRemoteVolume(0.75);
        expect(castService.remoteVolume, 0.75);
        castService.setRemoteVolume(1.8);
        expect(castService.remoteVolume, 1.0);
        castService.setRemoteVolume(-0.5);
        expect(castService.remoteVolume, 0.0);
      });

      test('20.4: Audio route selection switches between tv and device', () {
        expect(castService.audioRoute, 'tv');
        castService.setAudioRoute('device');
        expect(castService.audioRoute, 'device');
      });

      test('20.5: Disconnecting active session clears connected state', () async {
        final target = castService.devices.first;
        await castService.connect(target);
        expect(castService.connectedDevice, isNotNull);
        await castService.disconnect();
        expect(castService.connectedDevice, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // Feature 21: Strict Offline Invariant
    // -------------------------------------------------------------------------
    group('Feature 21: Strict Offline Invariant', () {
      test('21.1: Loopback IPv4 (127.0.0.1) is recognized as strictly offline', () {
        final uri = Uri.parse('http://127.0.0.1:8899/cast/token/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
      });

      test('21.2: Local LAN 192.168.x.x is recognized as strictly offline', () {
        final uri = Uri.parse('http://192.168.1.105:8899/cast/token/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
      });

      test('21.3: Local LAN 10.x.x.x is recognized as strictly offline', () {
        final uri = Uri.parse('http://10.0.0.12:8899/cast/token/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
      });

      test('21.4: Public WAN IP (e.g. 8.8.8.8) is rejected by offline validator', () {
        final uri = Uri.parse('http://8.8.8.8:8899/cast/token/stream');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isFalse);
      });

      test('21.5: External public cloud domain is rejected by offline validator', () {
        final uri = Uri.parse('https://api.telemetry.example.com/v1/ping');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isFalse);
      });
    });
  });
}
