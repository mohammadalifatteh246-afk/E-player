import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/gesture_models.dart';
import 'package:app/features/player/ui/cinematic_gesture_engine.dart';

void main() {
  const Size standardViewport = Size(1000.0, 600.0);

  group('Directional Dead-Zone Arbitration Tests (INV-GEST-003, Edge Case 4)', () {
    late GestureArbitrator arbitrator;

    setUp(() {
      arbitrator = GestureArbitrator();
    });

    test('Initial state is idle', () {
      expect(arbitrator.mode, GestureMode.idle);
      expect(arbitrator.isCommitted, isFalse);
    });

    test('Movement < 12px physical dead-zone remains in arbitrating', () {
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);
      expect(arbitrator.mode, GestureMode.arbitrating);

      // Moved 8px horizontally, 3px vertically
      final mode = arbitrator.arbitrate(
        currentPoint: const Offset(508, 303),
        viewportSize: standardViewport,
        pointerCount: 1,
      );

      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);
    });

    test('Movement >= 12px but failing 1.5x axis dominance remains in arbitrating', () {
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);

      // dx = 14px, dy = 16px: primary is 16, secondary is 14.
      // 16 < 1.5 * 14 (21.0) -> fails axis dominance
      final mode = arbitrator.arbitrate(
        currentPoint: const Offset(514, 316),
        viewportSize: standardViewport,
        pointerCount: 1,
      );

      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);
    });

    test('Edge Case 4: Diagonal swipe resolves to brightnessAdjust once 1.5x ratio met', () {
      // User initiates diagonal swipe starting at (X: 100, Y: 200) with dx=14, dy=16
      arbitrator.handleDown(const Offset(100, 200), 1, standardViewport);

      var mode = arbitrator.arbitrate(
        currentPoint: const Offset(114, 216),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);

      // Once dy reaches 30px with dx=16px:
      // primary = 30, secondary = 16 -> 30 >= 1.5 * 16 (24.0)
      // startX = 100 <= 0.35 * 1000 (350) -> Brightness zone!
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(116, 230),
        viewportSize: standardViewport,
        pointerCount: 1,
      );

      expect(mode, GestureMode.brightnessAdjust);
      expect(arbitrator.isCommitted, isTrue);
    });

    test('Horizontal swipe in center zone commits to horizontalScrub', () {
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);

      // dx = 25px, dy = 2px -> 25 >= 12 and 25 >= 1.5 * 2
      final mode = arbitrator.arbitrate(
        currentPoint: const Offset(525, 302),
        viewportSize: standardViewport,
        pointerCount: 1,
      );

      expect(mode, GestureMode.horizontalScrub);
      expect(arbitrator.isCommitted, isTrue);
    });

    test('Pure 45-degree diagonal swipe (dx == dy) is ignored and remains arbitrating', () {
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);

      final mode = arbitrator.arbitrate(
        currentPoint: const Offset(550, 350),
        viewportSize: standardViewport,
        pointerCount: 1,
      );

      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);
    });

    test('Standalone evaluateSwipe produces deterministic outcomes', () {
      // Small movement
      expect(
        GestureArbitrator.evaluateSwipe(
          startPoint: const Offset(200, 200),
          currentPoint: const Offset(205, 205),
          viewportSize: standardViewport,
        ),
        GestureMode.arbitrating,
      );

      // Left zone vertical swipe
      expect(
        GestureArbitrator.evaluateSwipe(
          startPoint: const Offset(200, 200),
          currentPoint: const Offset(202, 240),
          viewportSize: standardViewport,
        ),
        GestureMode.brightnessAdjust,
      );

      // Right zone vertical swipe
      expect(
        GestureArbitrator.evaluateSwipe(
          startPoint: const Offset(800, 200),
          currentPoint: const Offset(802, 240),
          viewportSize: standardViewport,
        ),
        GestureMode.volumeAdjust,
      );

      // Center zone horizontal swipe
      expect(
        GestureArbitrator.evaluateSwipe(
          startPoint: const Offset(500, 200),
          currentPoint: const Offset(540, 202),
          viewportSize: standardViewport,
        ),
        GestureMode.horizontalScrub,
      );
    });

    test('reset clears arbitration state back to idle', () {
      arbitrator.handleDown(const Offset(100, 200), 1, standardViewport);
      arbitrator.arbitrate(
        currentPoint: const Offset(100, 250),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(arbitrator.mode, GestureMode.brightnessAdjust);

      arbitrator.reset();
      expect(arbitrator.mode, GestureMode.idle);
      expect(arbitrator.startPoint, isNull);
    });
  });

  group('Spatial Zones Verification (INV-GEST-002)', () {
    test('Left 35% zone triggers brightness adjustment', () {
      // 0.0 <= X <= 350 on 1000px width
      for (final startX in [0.0, 100.0, 250.0, 350.0]) {
        final mode = GestureArbitrator.evaluateSwipe(
          startPoint: Offset(startX, 300),
          currentPoint: Offset(startX + 2, 340),
          viewportSize: standardViewport,
        );
        expect(mode, GestureMode.brightnessAdjust, reason: 'Failed at X=$startX');
      }
    });

    test('Right 35% zone triggers volume adjustment', () {
      // 650 <= X <= 1000 on 1000px width
      for (final startX in [650.0, 750.0, 900.0, 1000.0]) {
        final mode = GestureArbitrator.evaluateSwipe(
          startPoint: Offset(startX, 300),
          currentPoint: Offset(startX + 2, 340),
          viewportSize: standardViewport,
        );
        expect(mode, GestureMode.volumeAdjust, reason: 'Failed at X=$startX');
      }
    });

    test('Center zone triggers horizontal scrub', () {
      // 350 < X < 650 on 1000px width
      for (final startX in [360.0, 450.0, 500.0, 640.0]) {
        final mode = GestureArbitrator.evaluateSwipe(
          startPoint: Offset(startX, 300),
          currentPoint: Offset(startX + 40, 302),
          viewportSize: standardViewport,
        );
        expect(mode, GestureMode.horizontalScrub, reason: 'Failed at X=$startX');
      }
    });

    test('Vertical swipe in center zone does not trigger brightness or volume', () {
      final mode = GestureArbitrator.evaluateSwipe(
        startPoint: const Offset(500, 300),
        currentPoint: const Offset(502, 350),
        viewportSize: standardViewport,
      );
      expect(mode, GestureMode.arbitrating);
    });

    test('Horizontal swipe outside center zone does not trigger horizontalScrub', () {
      // X = 100 (left zone)
      final leftMode = GestureArbitrator.evaluateSwipe(
        startPoint: const Offset(100, 300),
        currentPoint: const Offset(150, 302),
        viewportSize: standardViewport,
      );
      expect(leftMode, GestureMode.arbitrating);

      // X = 900 (right zone)
      final rightMode = GestureArbitrator.evaluateSwipe(
        startPoint: const Offset(900, 300),
        currentPoint: const Offset(950, 302),
        viewportSize: standardViewport,
      );
      expect(rightMode, GestureMode.arbitrating);
    });
  });

  group('Double-Tap Wing Jump & Boundary Clamping (INV-GEST-002, INV-GEST-006, Edge Case 6)', () {
    late CinematicGestureEngine engine;
    bool aiQueueInvalidated = false;
    Duration? seekCommittedTarget;
    bool playPauseToggled = false;

    setUp(() {
      aiQueueInvalidated = false;
      seekCommittedTarget = null;
      playPauseToggled = false;

      engine = CinematicGestureEngine(
        onInvalidateAiQueue: () => aiQueueInvalidated = true,
        onSeek: (target) => seekCommittedTarget = target,
        onTogglePlayPause: () => playPauseToggled = true,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('Left wing double-tap (X < 33%) seeks -10s and emits feedback event', () async {
      GestureFeedbackEvent? receivedEvent;
      final sub = engine.feedbackEvents.listen((e) => receivedEvent = e);

      // Double-tap at X=200 on 1000px viewport (20% < 33%)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(200, 300)),
        standardViewport,
        const Duration(seconds: 45),
        const Duration(seconds: 120),
      );

      await pumpEventQueue();

      expect(seekCommittedTarget, const Duration(seconds: 35));
      expect(aiQueueInvalidated, isTrue);
      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.type, GestureFeedbackType.wingJump);
      expect(receivedEvent!.value, -10.0);
      expect(receivedEvent!.label, '-10s');
      expect(receivedEvent!.seekTarget, const Duration(seconds: 35));

      await sub.cancel();
    });

    test('Left wing double-tap clamps to Duration.zero at start of media', () {
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(150, 300)),
        standardViewport,
        const Duration(seconds: 4), // 4s - 10s = -6s -> clamped to 0s
        const Duration(seconds: 120),
      );

      expect(seekCommittedTarget, Duration.zero);
      expect(aiQueueInvalidated, isTrue);
    });

    test('Right wing double-tap (X > 66%) seeks +10s and emits feedback event', () async {
      GestureFeedbackEvent? receivedEvent;
      final sub = engine.feedbackEvents.listen((e) => receivedEvent = e);

      // Double-tap at X=800 on 1000px viewport (80% > 66%)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(800, 300)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );

      await pumpEventQueue();

      expect(seekCommittedTarget, const Duration(seconds: 40));
      expect(aiQueueInvalidated, isTrue);
      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.type, GestureFeedbackType.wingJump);
      expect(receivedEvent!.value, 10.0);
      expect(receivedEvent!.label, '+10s');
      expect(receivedEvent!.seekTarget, const Duration(seconds: 40));

      await sub.cancel();
    });

    test('Right wing double-tap clamps to totalDuration at end of media', () {
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(850, 300)),
        standardViewport,
        const Duration(seconds: 115),
        const Duration(seconds: 120), // 115s + 10s = 125s -> clamped to 120s
      );

      expect(seekCommittedTarget, const Duration(seconds: 120));
      expect(aiQueueInvalidated, isTrue);
    });

    test('Center double-tap (33% <= X <= 66%) toggles play/pause without seeking', () {
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(500, 300)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );

      expect(playPauseToggled, isTrue);
      expect(seekCommittedTarget, isNull);
      expect(aiQueueInvalidated, isFalse);
    });
  });

  group('Pinch-to-Zoom Scaling & Pan Boundary Clamping (INV-GEST-004, Edge Case 5)', () {
    test('Scale <= 1.0 clamps pan offset strictly to zero', () {
      expect(
        CinematicGestureEngine.clampPanOffset(
          const Offset(100, 100),
          1.0,
          standardViewport,
        ),
        Offset.zero,
      );

      expect(
        CinematicGestureEngine.clampPanOffset(
          const Offset(-50, 80),
          0.8,
          standardViewport,
        ),
        Offset.zero,
      );
    });

    test('Scale = 2.0 bounds |Tx| <= 500 and |Ty| <= 300 on 1000x600 viewport', () {
      // (2.0 - 1.0) * 1000 / 2 = 500
      // (2.0 - 1.0) * 600 / 2 = 300
      final offsetInside = CinematicGestureEngine.clampPanOffset(
        const Offset(250, -150),
        2.0,
        standardViewport,
      );
      expect(offsetInside, const Offset(250, -150));

      final offsetExceedingX = CinematicGestureEngine.clampPanOffset(
        const Offset(650, 100),
        2.0,
        standardViewport,
      );
      expect(offsetExceedingX, const Offset(500, 100));

      final offsetExceedingY = CinematicGestureEngine.clampPanOffset(
        const Offset(100, -450),
        2.0,
        standardViewport,
      );
      expect(offsetExceedingY, const Offset(100, -300));
    });

    test('Edge Case 5: 3.0x zoom dragged to top-right is clamped to viewport boundary with 0 void', () {
      // scale = 3.0 -> maxTx = (3.0 - 1.0) * 1000 / 2 = 1000
      //              maxTy = (3.0 - 1.0) * 600 / 2 = 600
      final clamped = CinematicGestureEngine.clampPanOffset(
        const Offset(1500, -900),
        3.0,
        standardViewport,
      );
      expect(clamped.dx, 1000.0);
      expect(clamped.dy, -600.0);
    });

    test('Multi-touch pinch updates scale within [1.0, 4.0]', () {
      final engine = CinematicGestureEngine();

      // Start two-finger gesture
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 2,
        ),
        standardViewport,
      );
      expect(engine.currentMode, GestureMode.pinchZoom);

      // Pinch to 2.5x
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(500, 300),
          scale: 2.5,
          pointerCount: 2,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.scale, 2.5);

      // Pinch beyond max (5.0x) -> clamped to 4.0x
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(500, 300),
          scale: 5.0,
          pointerCount: 2,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.scale, 4.0);

      engine.dispose();
    });

    test('Double-tap resets zoom scale to 1.0x and pan offset to zero', () {
      final engine = CinematicGestureEngine();

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 2,
        ),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(500, 300),
          scale: 2.5,
          focalPointDelta: const Offset(100, 50),
          pointerCount: 2,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.scale, 2.5);
      expect(engine.panOffset, isNot(Offset.zero));

      // Double tap resets
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(500, 300)),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );

      expect(engine.scale, 1.0);
      expect(engine.panOffset, Offset.zero);

      engine.dispose();
    });
  });

  group('HUD Auto-Dismiss Coordination & Invariants (INV-GEST-005)', () {
    late CinematicGestureEngine engine;

    setUp(() {
      engine = CinematicGestureEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('controlsInhibited emits true on gesture start and false on gesture end', () async {
      final List<bool> emissions = [];
      final sub = engine.controlsInhibited.listen(emissions.add);

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      engine.handleScaleEnd(ScaleEndDetails());

      await pumpEventQueue();

      expect(emissions, [true, false]);
      await sub.cancel();
    });

    test('Configuration constants match specification', () {
      expect(CinematicGestureConfig.deadZoneThreshold, 12.0);
      expect(CinematicGestureConfig.axisDominanceRatio, 1.5);
      expect(CinematicGestureConfig.leftZoneRatio, 0.35);
      expect(CinematicGestureConfig.rightZoneRatio, 0.65);
      expect(CinematicGestureConfig.leftWingRatio, 0.33);
      expect(CinematicGestureConfig.rightWingRatio, 0.66);
      expect(CinematicGestureConfig.minZoomScale, 1.0);
      expect(CinematicGestureConfig.maxZoomScale, 4.0);
      expect(CinematicGestureConfig.hudResetTimeout, const Duration(milliseconds: 2800));
      expect(CinematicGestureConfig.feedbackLingeringDuration, const Duration(milliseconds: 800));
    });
  });

  group('Precision Scrubbing and Seek Commit Tests', () {
    late CinematicGestureEngine engine;
    bool invalidated = false;
    SeekCommitEvent? committedSeek;

    setUp(() {
      invalidated = false;
      committedSeek = null;

      engine = CinematicGestureEngine(
        onInvalidateAiQueue: () => invalidated = true,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('Center horizontal drag emits scrub feedback and commits on release', () async {
      final List<GestureFeedbackEvent> feedback = [];
      final feedbackSub = engine.feedbackEvents.listen(feedback.add);
      final commitSub = engine.seekCommitEvents.listen((e) => committedSeek = e);

      // Start in center
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Drag right by 40px (at currentPosition = 60s, duration = 300s)
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(540, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 60),
        const Duration(seconds: 300),
      );

      expect(engine.currentMode, GestureMode.horizontalScrub);
      // 40px * 0.5s/px = +20s -> target = 80s
      expect(engine.scrubPreviewPosition, const Duration(seconds: 80));

      // Release gesture
      engine.handleScaleEnd(ScaleEndDetails());

      await pumpEventQueue();

      expect(invalidated, isTrue);
      expect(committedSeek, isNotNull);
      expect(committedSeek!.target, const Duration(seconds: 80));
      expect(committedSeek!.previewDuration, const Duration(seconds: 300));

      expect(feedback.isNotEmpty, isTrue);
      expect(feedback.last.type, GestureFeedbackType.scrub);
      expect(feedback.last.seekTarget, const Duration(seconds: 80));

      await feedbackSub.cancel();
      await commitSub.cancel();
    });

    test('Sequential scrub gestures at different timestamps reset baseline correctly (Finding 1 remediation)', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final commitSub = engine.seekCommitEvents.listen(committedSeeks.add);

      // Scrub 1: At 60s, drag right +40px (+20s) -> target 80s
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(540, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 60),
        const Duration(seconds: 600),
      );

      expect(engine.currentMode, GestureMode.horizontalScrub);
      expect(engine.scrubPreviewPosition, const Duration(seconds: 80));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 1);
      expect(committedSeeks.last.target, const Duration(seconds: 80));

      // Scrub 2: At 300s, drag right +20px (+10s) -> target 310s (relative to 300s baseline)
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(520, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 300),
        const Duration(seconds: 600),
      );

      expect(engine.currentMode, GestureMode.horizontalScrub);
      expect(engine.scrubPreviewPosition, const Duration(seconds: 310));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 2);
      expect(committedSeeks.last.target, const Duration(seconds: 310));

      await commitSub.cancel();
    });

    test('Scrub starting at Duration.zero anchors baseline correctly without persisting', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final commitSub = engine.seekCommitEvents.listen(committedSeeks.add);

      // Scrub 1 at Duration.zero: drag right +30px (+15s) -> target 15s
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(530, 300),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        const Duration(seconds: 600),
      );

      expect(engine.currentMode, GestureMode.horizontalScrub);
      expect(engine.scrubPreviewPosition, const Duration(seconds: 15));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 1);
      expect(committedSeeks.last.target, const Duration(seconds: 15));

      // Scrub 2 at 120s: drag left -20px (-10s) -> target 110s
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(480, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 120),
        const Duration(seconds: 600),
      );

      expect(engine.currentMode, GestureMode.horizontalScrub);
      expect(engine.scrubPreviewPosition, const Duration(seconds: 110));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 2);
      expect(committedSeeks.last.target, const Duration(seconds: 110));

      await commitSub.cancel();
    });
  });

  group('Brightness & Volume Sliders Tests', () {
    test('Left zone adjusts brightness clamped to [0.0, 1.0]', () {
      double? reportedBrightness;
      final engine = CinematicGestureEngine(
        initialBrightness: 0.5,
        onBrightnessChanged: (v) => reportedBrightness = v,
      );

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(150, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Drag up by 50px (negative dy increases brightness)
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(150, 250),
          focalPointDelta: const Offset(0, -50),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );

      expect(engine.currentMode, GestureMode.brightnessAdjust);
      expect(engine.brightness, greaterThan(0.5));
      expect(reportedBrightness, engine.brightness);

      // Force clamp to max
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(150, 50),
          focalPointDelta: const Offset(0, -1000),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.brightness, 1.0);

      engine.dispose();
    });

    test('Right zone adjusts volume clamped to [0.0, 100.0]', () {
      double? reportedVolume;
      final engine = CinematicGestureEngine(
        initialVolume: 50.0,
        onVolumeChanged: (v) => reportedVolume = v,
      );

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(850, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Drag down by 50px (positive dy decreases volume)
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 350),
          focalPointDelta: const Offset(0, 50),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );

      expect(engine.currentMode, GestureMode.volumeAdjust);
      expect(engine.volume, lessThan(50.0));
      expect(reportedVolume, engine.volume);

      // Force clamp to zero
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 600),
          focalPointDelta: const Offset(0, 1000),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, 0.0);

      engine.dispose();
    });
  });
}
