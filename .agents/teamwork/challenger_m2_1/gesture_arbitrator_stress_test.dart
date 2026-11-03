import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/gesture_models.dart';
import 'package:app/features/player/ui/cinematic_gesture_engine.dart';

void main() {
  const Size standardViewport = Size(1000.0, 600.0);

  group('Challenge Suite 1: Diagonal Swipe Rejection (Edge Case 4)', () {
    late GestureArbitrator arbitrator;

    setUp(() {
      arbitrator = GestureArbitrator();
    });

    test('Empirical: dx=14, dy=16 strictly remains in arbitrating mode until one axis reaches >= 1.5x', () {
      const start = Offset(100.0, 200.0); // Left zone (brightness)
      arbitrator.handleDown(start, 1, standardViewport);
      expect(arbitrator.mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);

      // Trajectory 1: dx=14, dy=16
      // primary = 16, secondary = 14. 16 < 1.5 * 14 (21.0) -> MUST BE arbitrating
      var mode = arbitrator.arbitrate(
        currentPoint: const Offset(114.0, 216.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);

      // Trajectory 2: dy increases to 18 (ratio = 1.286)
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(114.0, 218.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);

      // Trajectory 3: dy increases to 20.0 (ratio = 1.429)
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(114.0, 220.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);

      // Trajectory 4: dy increases to 20.999 (sub-pixel just below 1.5x threshold)
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(114.0, 220.999),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);

      // Trajectory 5: dy reaches 21.0 (exactly 1.5 * 14.0 = 21.0)
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(114.0, 221.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.brightnessAdjust);
      expect(arbitrator.isCommitted, isTrue);
    });

    test('Empirical: Reverse diagonal where dx overtakes dy (center zone scrub)', () {
      const start = Offset(500.0, 300.0); // Center zone (scrub)
      arbitrator.handleDown(start, 1, standardViewport);

      // dx=14, dy=16 -> arbitrating
      var mode = arbitrator.arbitrate(
        currentPoint: const Offset(514.0, 316.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);

      // dx increases to 20, dy stays 16 -> primary=20, secondary=16 (20 < 1.5 * 16 = 24.0) -> arbitrating
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(520.0, 316.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);

      // dx increases to 23.999 -> 23.999 < 24.0 -> arbitrating
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(523.999, 316.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);

      // dx reaches 24.0 (exactly 1.5 * 16.0 = 24.0) -> commits to horizontalScrub
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(524.0, 316.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.horizontalScrub);
      expect(arbitrator.isCommitted, isTrue);
    });

    test('Empirical: Diagonal swipe in all 4 coordinate quadrants', () {
      final quadrants = <String, Offset>{
        '+X, +Y': const Offset(14.0, 16.0),
        '+X, -Y': const Offset(14.0, -16.0),
        '-X, +Y': const Offset(-14.0, 16.0),
        '-X, -Y': const Offset(-14.0, -16.0),
      };

      for (final entry in quadrants.entries) {
        final arb = GestureArbitrator();
        arb.handleDown(const Offset(800.0, 300.0), 1, standardViewport); // Right zone (volume)

        // Initial diagonal point (ratio 1.143)
        final initialDelta = entry.value;
        var mode = arb.arbitrate(
          currentPoint: Offset(800.0 + initialDelta.dx, 300.0 + initialDelta.dy),
          viewportSize: standardViewport,
          pointerCount: 1,
        );
        expect(mode, GestureMode.arbitrating, reason: 'Quadrant ${entry.key} at (14, 16) failed');

        // Extended Y delta to satisfy >= 1.5x (dy = +/-25, dx = +/-14 -> 25 >= 1.5 * 14 = 21)
        final extendedDelta = Offset(initialDelta.dx, initialDelta.dy.sign * 25.0);
        mode = arb.arbitrate(
          currentPoint: Offset(800.0 + extendedDelta.dx, 300.0 + extendedDelta.dy),
          viewportSize: standardViewport,
          pointerCount: 1,
        );
        expect(mode, GestureMode.volumeAdjust, reason: 'Quadrant ${entry.key} at (14, 25) failed');
      }
    });

    test('Empirical: Strict 45-degree line (dx == dy) never commits regardless of travel distance', () {
      final arb = GestureArbitrator();
      arb.handleDown(const Offset(500.0, 300.0), 1, standardViewport);

      // Test up to 400px diagonal travel
      for (double delta = 1.0; delta <= 400.0; delta += 15.0) {
        final mode = arb.arbitrate(
          currentPoint: Offset(500.0 + delta, 300.0 + delta),
          viewportSize: standardViewport,
          pointerCount: 1,
        );
        expect(mode, GestureMode.arbitrating, reason: 'Committed prematurely at delta=$delta');
        expect(arb.isCommitted, isFalse);
      }
    });

    test('Empirical: Fuzzing 50 near-threshold diagonal points with ratio in [1.0, 1.499]', () {
      final rng = math.Random(42);
      for (int i = 0; i < 50; i++) {
        final secondary = 15.0 + rng.nextDouble() * 50.0;
        final ratio = 1.0 + rng.nextDouble() * 0.499; // ratio strictly < 1.499
        final primary = secondary * ratio;

        final arb = GestureArbitrator();
        arb.handleDown(const Offset(100.0, 300.0), 1, standardViewport);

        // Test with Y as primary
        final modeY = arb.arbitrate(
          currentPoint: Offset(100.0 + secondary, 300.0 + primary),
          viewportSize: standardViewport,
          pointerCount: 1,
        );
        expect(modeY, GestureMode.arbitrating,
            reason: 'Iteration $i: ratio $ratio (primary=$primary, secondary=$secondary) committed');

        // Test with X as primary
        final arbX = GestureArbitrator();
        arbX.handleDown(const Offset(500.0, 300.0), 1, standardViewport);
        final modeX = arbX.arbitrate(
          currentPoint: Offset(500.0 + primary, 300.0 + secondary),
          viewportSize: standardViewport,
          pointerCount: 1,
        );
        expect(modeX, GestureMode.arbitrating,
            reason: 'Iteration $i X: ratio $ratio (primary=$primary, secondary=$secondary) committed');
      }
    });
  });

  group('Challenge Suite 2: Dead-Zone Boundary (< 12.0px MUST NOT commit)', () {
    late GestureArbitrator arbitrator;

    setUp(() {
      arbitrator = GestureArbitrator();
    });

    test('Empirical: Travel < 12.0px strictly MUST NOT commit across 360-degree polar sweep', () {
      const origin = Offset(500.0, 300.0);

      // Sweep angles from 0 to 360 degrees in 15-degree steps
      for (int deg = 0; deg < 360; deg += 15) {
        final rad = deg * math.pi / 180.0;

        // Radii: 0.5, 3.0, 7.0, 10.0, 11.5, 11.9, 11.99, 11.999
        final testRadii = [0.5, 3.0, 7.0, 10.0, 11.5, 11.9, 11.99, 11.999];

        for (final r in testRadii) {
          final arb = GestureArbitrator();
          arb.handleDown(origin, 1, standardViewport);

          final dx = r * math.cos(rad);
          final dy = r * math.sin(rad);

          final mode = arb.arbitrate(
            currentPoint: Offset(origin.dx + dx, origin.dy + dy),
            viewportSize: standardViewport,
            pointerCount: 1,
          );

          expect(
            mode,
            GestureMode.arbitrating,
            reason: 'Committed at angle $deg deg with radius $r (dx=$dx, dy=$dy)',
          );
          expect(arb.isCommitted, isFalse);
        }
      }
    });

    test('Empirical: Sub-pixel boundary check: 11.999px vs 12.000px', () {
      const origin = Offset(500.0, 300.0);

      // Test 1: dx = 11.999, dy = 0.0 -> primary < 12.0 -> arbitrating
      final arb1 = GestureArbitrator();
      arb1.handleDown(origin, 1, standardViewport);
      final mode1 = arb1.arbitrate(
        currentPoint: const Offset(511.999, 300.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode1, GestureMode.arbitrating);
      expect(arb1.isCommitted, isFalse);

      // Test 2: dx = 12.000, dy = 0.0 -> primary == 12.0 -> commits to horizontalScrub
      final arb2 = GestureArbitrator();
      arb2.handleDown(origin, 1, standardViewport);
      final mode2 = arb2.arbitrate(
        currentPoint: const Offset(512.000, 300.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode2, GestureMode.horizontalScrub);
      expect(arb2.isCommitted, isTrue);

      // Test 3: Left zone vertical: dy = 11.999 vs 12.000
      final arb3 = GestureArbitrator();
      arb3.handleDown(const Offset(100.0, 300.0), 1, standardViewport);
      final mode3 = arb3.arbitrate(
        currentPoint: const Offset(100.0, 311.999),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode3, GestureMode.arbitrating);

      final arb4 = GestureArbitrator();
      arb4.handleDown(const Offset(100.0, 300.0), 1, standardViewport);
      final mode4 = arb4.arbitrate(
        currentPoint: const Offset(100.0, 312.000),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode4, GestureMode.brightnessAdjust);
      expect(arb4.isCommitted, isTrue);
    });

    test('Empirical: High axis ratio (e.g. 10x) with primary < 12px MUST NOT commit', () {
      // dx = 11.5, dy = 1.0 -> ratio is 11.5 > 1.5, but primary = 11.5 < 12.0
      final arb = GestureArbitrator();
      arb.handleDown(const Offset(500.0, 300.0), 1, standardViewport);
      final mode = arb.arbitrate(
        currentPoint: const Offset(511.5, 301.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);
      expect(arb.isCommitted, isFalse);
    });
  });

  group('Challenge Suite 3: Rapid Gesture Transitions & State Integrity', () {
    late CinematicGestureEngine engine;
    late GestureArbitrator arbitrator;

    setUp(() {
      arbitrator = GestureArbitrator();
      engine = CinematicGestureEngine(arbitrator: arbitrator);
    });

    tearDown(() {
      engine.dispose();
    });

    test('Empirical: 100 rapid alternating gestures (taps, partials, scrubs, zooms) maintain strict state consistency', () {
      final rng = math.Random(12345);

      for (int i = 0; i < 100; i++) {
        final gestureType = i % 5;

        switch (gestureType) {
          case 0:
            // Tap: scaleStart then scaleEnd immediately without movement
            engine.handleScaleStart(
              ScaleStartDetails(
                localFocalPoint: Offset(100.0 + rng.nextDouble() * 800, 300.0),
                pointerCount: 1,
              ),
              standardViewport,
            );
            expect(arbitrator.mode, GestureMode.arbitrating);
            engine.handleScaleEnd(ScaleEndDetails());
            expect(arbitrator.mode, GestureMode.idle);
            expect(arbitrator.isCommitted, isFalse);
            expect(arbitrator.startPoint, isNull);
            break;

          case 1:
            // Interrupted/aborted swipe (travel < 10px in dead zone)
            final startX = 100.0 + rng.nextDouble() * 800;
            engine.handleScaleStart(
              ScaleStartDetails(
                localFocalPoint: Offset(startX, 300.0),
                pointerCount: 1,
              ),
              standardViewport,
            );
            engine.handleScaleUpdate(
              ScaleUpdateDetails(
                localFocalPoint: Offset(startX + 5.0, 303.0),
                pointerCount: 1,
              ),
              standardViewport,
              const Duration(seconds: 10),
              const Duration(seconds: 100),
            );
            expect(arbitrator.mode, GestureMode.arbitrating);
            engine.handleScaleEnd(ScaleEndDetails());
            expect(arbitrator.mode, GestureMode.idle);
            break;

          case 2:
            // Full center horizontal scrub
            engine.handleScaleStart(
              ScaleStartDetails(
                localFocalPoint: const Offset(500.0, 300.0),
                pointerCount: 1,
              ),
              standardViewport,
            );
            engine.handleScaleUpdate(
              ScaleUpdateDetails(
                localFocalPoint: const Offset(550.0, 302.0),
                pointerCount: 1,
              ),
              standardViewport,
              const Duration(seconds: 30),
              const Duration(seconds: 120),
            );
            expect(arbitrator.mode, GestureMode.horizontalScrub);
            expect(arbitrator.isCommitted, isTrue);
            engine.handleScaleEnd(ScaleEndDetails());
            expect(arbitrator.mode, GestureMode.idle);
            expect(arbitrator.isCommitted, isFalse);
            break;

          case 3:
            // Full left-zone brightness drag
            engine.handleScaleStart(
              ScaleStartDetails(
                localFocalPoint: const Offset(150.0, 300.0),
                pointerCount: 1,
              ),
              standardViewport,
            );
            engine.handleScaleUpdate(
              ScaleUpdateDetails(
                localFocalPoint: const Offset(151.0, 260.0),
                focalPointDelta: const Offset(1.0, -40.0),
                pointerCount: 1,
              ),
              standardViewport,
              Duration.zero,
              Duration.zero,
            );
            expect(arbitrator.mode, GestureMode.brightnessAdjust);
            expect(arbitrator.isCommitted, isTrue);
            engine.handleScaleEnd(ScaleEndDetails());
            expect(arbitrator.mode, GestureMode.idle);
            break;

          case 4:
            // Two-finger pinch-to-zoom
            engine.handleScaleStart(
              ScaleStartDetails(
                localFocalPoint: const Offset(500.0, 300.0),
                pointerCount: 2,
              ),
              standardViewport,
            );
            expect(arbitrator.mode, GestureMode.pinchZoom);
            engine.handleScaleUpdate(
              ScaleUpdateDetails(
                localFocalPoint: const Offset(500.0, 300.0),
                scale: 1.8,
                pointerCount: 2,
              ),
              standardViewport,
              Duration.zero,
              Duration.zero,
            );
            expect(engine.scale, 1.8);
            engine.handleScaleEnd(ScaleEndDetails());
            engine.resetZoom();
            expect(arbitrator.mode, GestureMode.idle);
            break;
        }
      }

      // Final health check
      expect(arbitrator.mode, GestureMode.idle);
      expect(arbitrator.isCommitted, isFalse);
      expect(arbitrator.startPoint, isNull);
      expect(arbitrator.cumulativeDelta, Offset.zero);
    });

    test('Empirical: Mid-gesture pointer count transition from 1 to 2 switches cleanly to pinchZoom', () {
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500.0, 300.0),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Start horizontal scrub
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(530.0, 300.0),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 10),
        const Duration(seconds: 100),
      );
      expect(arbitrator.mode, GestureMode.horizontalScrub);

      // Second finger lands mid-gesture!
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(530.0, 300.0),
          scale: 1.5,
          pointerCount: 2,
        ),
        standardViewport,
        const Duration(seconds: 10),
        const Duration(seconds: 100),
      );
      expect(arbitrator.mode, GestureMode.pinchZoom);

      engine.handleScaleEnd(ScaleEndDetails());
      expect(arbitrator.mode, GestureMode.idle);
    });

    test('Empirical: Repeated handleDown calls without reset do not corrupt state or crash', () {
      for (int i = 0; i < 20; i++) {
        arbitrator.handleDown(Offset(10.0 * i, 20.0 * i), 1, standardViewport);
        expect(arbitrator.mode, GestureMode.arbitrating);
        expect(arbitrator.startPoint, Offset(10.0 * i, 20.0 * i));
        expect(arbitrator.cumulativeDelta, Offset.zero);
      }
      arbitrator.reset();
      expect(arbitrator.mode, GestureMode.idle);
    });
  });

  group('Challenge Suite 4: Double-Tap Jump Wing Boundaries', () {
    late CinematicGestureEngine engine;
    Duration? seekCommittedTarget;
    bool playPauseToggled = false;
    bool aiQueueInvalidated = false;

    setUp(() {
      seekCommittedTarget = null;
      playPauseToggled = false;
      aiQueueInvalidated = false;

      engine = CinematicGestureEngine(
        onSeek: (target) => seekCommittedTarget = target,
        onTogglePlayPause: () => playPauseToggled = true,
        onInvalidateAiQueue: () => aiQueueInvalidated = true,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('Empirical: Precise boundary analysis at X = 0.33 * width (330.0px on 1000px viewport)', () {
      // Case 1: X = 329.999 (strictly in left wing < 0.33 * W)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(329.999, 300.0)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(seekCommittedTarget, const Duration(seconds: 20),
          reason: 'X=329.999 must trigger left wing jump (-10s)');
      expect(aiQueueInvalidated, isTrue);
      expect(playPauseToggled, isFalse);

      // Reset test state
      seekCommittedTarget = null;
      aiQueueInvalidated = false;
      playPauseToggled = false;

      // Case 2: X = 330.000 (EXACT BOUNDARY: X == 0.33 * W)
      // Since code condition is: `dx < 0.33 * width`, at dx == 330.0:
      // dx < 330.0 is FALSE -> falls through to center zone (play/pause)!
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(330.000, 300.0)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(seekCommittedTarget, isNull,
          reason: 'X=330.000 at exact boundary falls through to center play/pause');
      expect(playPauseToggled, isTrue);

      // Reset test state
      seekCommittedTarget = null;
      aiQueueInvalidated = false;
      playPauseToggled = false;

      // Case 3: X = 330.001 (strictly in center zone > 0.33 * W)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(330.001, 300.0)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(seekCommittedTarget, isNull);
      expect(playPauseToggled, isTrue);
    });

    test('Empirical: Precise boundary analysis at X = 0.66 * width (660.0px on 1000px viewport)', () {
      // Case 1: X = 659.999 (strictly in center zone < 0.66 * W)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(659.999, 300.0)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(seekCommittedTarget, isNull);
      expect(playPauseToggled, isTrue);

      // Reset test state
      seekCommittedTarget = null;
      aiQueueInvalidated = false;
      playPauseToggled = false;

      // Case 2: X = 660.000 (EXACT BOUNDARY: X == 0.66 * W)
      // Since code condition is: `dx > 0.66 * width`, at dx == 660.0:
      // dx > 660.0 is FALSE -> falls through to center zone (play/pause)!
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(660.000, 300.0)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(seekCommittedTarget, isNull,
          reason: 'X=660.000 at exact boundary falls through to center play/pause');
      expect(playPauseToggled, isTrue);

      // Reset test state
      seekCommittedTarget = null;
      aiQueueInvalidated = false;
      playPauseToggled = false;

      // Case 3: X = 660.001 (strictly in right wing > 0.66 * W)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(660.001, 300.0)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(seekCommittedTarget, const Duration(seconds: 40),
          reason: 'X=660.001 must trigger right wing jump (+10s)');
      expect(aiQueueInvalidated, isTrue);
      expect(playPauseToggled, isFalse);
    });

    test('Empirical: Double-tap jump wing boundaries scale dynamically across different viewport sizes', () {
      final viewports = <Size>[
        const Size(1920.0, 1080.0), // Full HD landscape
        const Size(800.0, 480.0),   // Small tablet/embedded
        const Size(390.0, 844.0),   // Portrait mobile
      ];

      for (final vp in viewports) {
        final leftWingBoundary = 0.33 * vp.width;
        final rightWingBoundary = 0.66 * vp.width;

        // Test 1px inside left wing
        seekCommittedTarget = null;
        engine.handleDoubleTapDown(
          TapDownDetails(localPosition: Offset(leftWingBoundary - 1.0, vp.height / 2)),
          vp,
          const Duration(seconds: 50),
          const Duration(seconds: 200),
        );
        expect(seekCommittedTarget, const Duration(seconds: 40),
            reason: 'Left wing failed on viewport ${vp.width}x${vp.height}');

        // Test 1px inside right wing
        seekCommittedTarget = null;
        engine.handleDoubleTapDown(
          TapDownDetails(localPosition: Offset(rightWingBoundary + 1.0, vp.height / 2)),
          vp,
          const Duration(seconds: 50),
          const Duration(seconds: 200),
        );
        expect(seekCommittedTarget, const Duration(seconds: 60),
            reason: 'Right wing failed on viewport ${vp.width}x${vp.height}');
      }
    });

    test('Empirical: Extreme timeline boundary clamping on wing jumps', () {
      const total = Duration(seconds: 100);

      // Left wing jump when currentPosition is 0s -> clamps to Duration.zero
      seekCommittedTarget = null;
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(100.0, 300.0)),
        standardViewport,
        Duration.zero,
        total,
      );
      expect(seekCommittedTarget, Duration.zero);

      // Left wing jump when currentPosition is 3s (< 10s) -> clamps to Duration.zero
      seekCommittedTarget = null;
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(100.0, 300.0)),
        standardViewport,
        const Duration(seconds: 3),
        total,
      );
      expect(seekCommittedTarget, Duration.zero);

      // Right wing jump when currentPosition is 100s -> clamps to 100s
      seekCommittedTarget = null;
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(900.0, 300.0)),
        standardViewport,
        total,
        total,
      );
      expect(seekCommittedTarget, total);

      // Right wing jump when currentPosition is 97s (> 100s - 10s) -> clamps to 100s
      seekCommittedTarget = null;
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(900.0, 300.0)),
        standardViewport,
        const Duration(seconds: 97),
        total,
      );
      expect(seekCommittedTarget, total);
    });
  });

  group('Challenge Suite 5: Consecutive Scrub Behavior & _initialPosition Latching', () {
    test('Empirical: Multiple consecutive horizontal scrubs at different timestamps', () {
      final engine = CinematicGestureEngine();
      final List<SeekCommitEvent> commits = [];
      engine.seekCommitEvents.listen(commits.add);

      // Scrub 1: video is at 60s
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500.0, 300.0),
          pointerCount: 1,
        ),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(540.0, 300.0),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 60),
        const Duration(seconds: 300),
      );
      // 40px * 0.5s = +20s -> 60s + 20s = 80s
      expect(engine.scrubPreviewPosition, const Duration(seconds: 80));
      engine.handleScaleEnd(ScaleEndDetails());

      // Scrub 2: user now scrubs from 150s with +30px travel (target MUST be 150s + 15s = 165s)
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500.0, 300.0),
          pointerCount: 1,
        ),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(530.0, 300.0),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 150),
        const Duration(seconds: 300),
      );

      // Empirical Bug Check:
      // In cinematic_gesture_engine.dart line 430:
      // if (_initialPosition == Duration.zero && currentPosition > Duration.zero)
      // _initialPosition was NOT cleared upon handleScaleEnd!
      // Therefore _initialPosition remains 60s, computing candidateTarget as 60s + 15s = 75s (01:15),
      // instead of 150s + 15s = 165s (02:45)!
      print('[EMPIRICAL BUG TELEMETRY] Scrub 1 at 60s (+20s) -> preview: 80s');
      print('[EMPIRICAL BUG TELEMETRY] Scrub 2 at 150s (+15s) -> Expected: 165s (02:45), Observed: ${engine.scrubPreviewPosition}');

      expect(
        engine.scrubPreviewPosition,
        const Duration(seconds: 165),
        reason: 'CRITICAL BUG: _initialPosition latches permanently across consecutive scrubs because it is never reset in handleScaleEnd or handleScaleStart!',
      );
      engine.handleScaleEnd(ScaleEndDetails());

      engine.dispose();
    });
  });
}
