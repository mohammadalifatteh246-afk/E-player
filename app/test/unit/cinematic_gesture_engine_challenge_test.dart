import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/gesture_models.dart';
import 'package:app/features/player/ui/cinematic_gesture_engine.dart';

void main() {
  const Size standardViewport = Size(1000.0, 600.0);

  group('Adversarial Challenge 1: Sequential Scrub & State Isolation', () {
    late CinematicGestureEngine engine;

    setUp(() {
      engine = CinematicGestureEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('10-step sequential scrub across alternating timeline baselines never leaks _initialPosition', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      final List<Map<String, dynamic>> testCases = [
        {'baseline': const Duration(seconds: 0), 'dx': 40.0, 'expected': const Duration(seconds: 20)},
        {'baseline': const Duration(seconds: 120), 'dx': -30.0, 'expected': const Duration(seconds: 105)},
        {'baseline': const Duration(seconds: 500), 'dx': 60.0, 'expected': const Duration(seconds: 530)},
        {'baseline': const Duration(seconds: 530), 'dx': -100.0, 'expected': const Duration(seconds: 480)},
        {'baseline': const Duration(seconds: 0), 'dx': 10.0, 'expected': const Duration(seconds: 0)}, // dx=10 < 12 dead-zone, not committed
        {'baseline': const Duration(seconds: 30), 'dx': 50.0, 'expected': const Duration(seconds: 55)},
        {'baseline': const Duration(seconds: 600), 'dx': 40.0, 'expected': const Duration(seconds: 600)}, // clamped to totalDuration (600s)
        {'baseline': const Duration(seconds: 10), 'dx': -60.0, 'expected': const Duration(seconds: 0)}, // clamped to zero
        {'baseline': const Duration(seconds: 250), 'dx': 20.0, 'expected': const Duration(seconds: 260)},
        {'baseline': const Duration(seconds: 350), 'dx': -40.0, 'expected': const Duration(seconds: 330)},
      ];

      int expectedCommitCount = 0;

      for (int i = 0; i < testCases.length; i++) {
        final tc = testCases[i];
        final Duration baseline = tc['baseline'];
        final double dx = tc['dx'];
        final Duration expected = tc['expected'];

        engine.handleScaleStart(
          ScaleStartDetails(
            localFocalPoint: const Offset(500, 300),
            pointerCount: 1,
          ),
          standardViewport,
        );

        engine.handleScaleUpdate(
          ScaleUpdateDetails(
            localFocalPoint: Offset(500 + dx, 300),
            pointerCount: 1,
          ),
          standardViewport,
          baseline,
          const Duration(seconds: 600),
        );

        if (dx.abs() >= CinematicGestureConfig.deadZoneThreshold) {
          expectedCommitCount++;
          expect(engine.currentMode, GestureMode.horizontalScrub, reason: 'Step $i should commit to scrub');
          expect(engine.scrubPreviewPosition, expected, reason: 'Step $i preview mismatch');
        } else {
          expect(engine.currentMode, GestureMode.arbitrating, reason: 'Step $i should stay arbitrating');
        }

        engine.handleScaleEnd(ScaleEndDetails());
        await pumpEventQueue();

        expect(committedSeeks.length, expectedCommitCount, reason: 'Step $i commit count mismatch');
        if (dx.abs() >= CinematicGestureConfig.deadZoneThreshold) {
          expect(committedSeeks.last.target, expected, reason: 'Step $i committed target mismatch');
          expect(committedSeeks.last.previewDuration, const Duration(seconds: 600));
        }
      }

      await sub.cancel();
    });

    test('Baseline _initialPosition remains anchored even when currentPosition mutates during gesture', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // First update at baseline 100s, dx = +30px (+15s) -> preview 115s
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(530, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 100),
        const Duration(seconds: 600),
      );
      expect(engine.scrubPreviewPosition, const Duration(seconds: 115));

      // Player timeline ticks from 100s to 105s, while finger stays at +30px
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(530, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 105), // player ticked!
        const Duration(seconds: 600),
      );
      // Must STILL be 115s because initialPosition was anchored at 100s
      expect(engine.scrubPreviewPosition, const Duration(seconds: 115));

      // Finger moves further to +50px (+25s), player ticks to 110s
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(550, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 110),
        const Duration(seconds: 600),
      );
      // Must be 100s + 25s = 125s, NOT 110s + 25s
      expect(engine.scrubPreviewPosition, const Duration(seconds: 125));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 1);
      expect(committedSeeks.first.target, const Duration(seconds: 125));

      await sub.cancel();
    });

    test('Consecutive handleScaleStart without handleScaleEnd resets _initialPosition cleanly', () async {
      // Gesture 1 aborted without scaleEnd
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(550, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 50),
        const Duration(seconds: 600),
      );
      expect(engine.scrubPreviewPosition, const Duration(seconds: 75));

      // New gesture starts immediately (e.g. gesture interruption)
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );
      // New gesture at baseline 200s, dx = +20px (+10s) -> should be 210s
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(520, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 200),
        const Duration(seconds: 600),
      );
      expect(engine.scrubPreviewPosition, const Duration(seconds: 210));
    });
  });

  group('Adversarial Challenge 2: Mathematical Exactness of Seek Commit Targets', () {
    late CinematicGestureEngine engine;

    setUp(() {
      engine = CinematicGestureEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('Seek commit targets match exact formula: initialPosition + round(dx * 0.5)', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      const Duration baseline = Duration(seconds: 100);
      const Duration total = Duration(seconds: 500);

      final pixelDeltas = [-50.0, -31.0, -20.0, -15.0, -12.0, 12.0, 15.0, 20.0, 31.0, 50.0, 100.0];

      for (final dx in pixelDeltas) {
        engine.handleScaleStart(
          ScaleStartDetails(
            localFocalPoint: const Offset(500, 300),
            pointerCount: 1,
          ),
          standardViewport,
        );

        engine.handleScaleUpdate(
          ScaleUpdateDetails(
            localFocalPoint: Offset(500 + dx, 300),
            pointerCount: 1,
          ),
          standardViewport,
          baseline,
          total,
        );

        final expectedDeltaSeconds = (dx * 0.5).round();
        final expectedTarget = baseline + Duration(seconds: expectedDeltaSeconds);

        expect(engine.scrubPreviewPosition, expectedTarget);

        engine.handleScaleEnd(ScaleEndDetails());
        await pumpEventQueue();

        expect(committedSeeks.last.target, expectedTarget);
      }

      expect(committedSeeks.length, pixelDeltas.length);
      await sub.cancel();
    });

    test('Re-centering after crossing dead zone commits exact initialPosition', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Move +30px to commit to horizontalScrub
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(530, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 150),
        const Duration(seconds: 500),
      );
      expect(engine.currentMode, GestureMode.horizontalScrub);
      expect(engine.scrubPreviewPosition, const Duration(seconds: 165));

      // Move back to exact origin (500, 300)
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 150),
        const Duration(seconds: 500),
      );
      expect(engine.scrubPreviewPosition, const Duration(seconds: 150));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 1);
      expect(committedSeeks.first.target, const Duration(seconds: 150));

      await sub.cancel();
    });
  });

  group('Adversarial Challenge 3: Zero Duration & Media End Boundaries', () {
    late CinematicGestureEngine engine;

    setUp(() {
      engine = CinematicGestureEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('Zero totalDuration clamps backward scrub to Duration.zero and records previewDuration', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Drag left -40px (-20s) with baseline 0s and totalDuration 0s
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(460, 300),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );

      expect(engine.scrubPreviewPosition, Duration.zero);

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 1);
      expect(committedSeeks.first.target, Duration.zero);
      expect(committedSeeks.first.previewDuration, Duration.zero);

      await sub.cancel();
    });

    test('Double-tap wing jumps with zero totalDuration clamp safely to Duration.zero', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      // Left wing double tap: -10s from 0s -> clamps to 0s
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(100, 300)),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      await pumpEventQueue();

      expect(committedSeeks.length, 1);
      expect(committedSeeks.first.target, Duration.zero);

      // Right wing double tap: +10s from 0s with totalDuration 0s -> clamps to totalDuration (0s)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(900, 300)),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      await pumpEventQueue();

      expect(committedSeeks.length, 2);
      expect(committedSeeks.last.target, Duration.zero);

      await sub.cancel();
    });

    test('Scrubbing at end of media boundary clamps forward movement to totalDuration', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      const total = Duration(seconds: 300);

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Drag forward +100px (+50s) from 290s on 300s total
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(600, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 290),
        total,
      );

      expect(engine.scrubPreviewPosition, total);

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeeks.length, 1);
      expect(committedSeeks.first.target, total);

      await sub.cancel();
    });
  });

  group('Adversarial Challenge 4: Diagonal Swipe & Dead-Zone Arbitration Stress', () {
    late GestureArbitrator arbitrator;

    setUp(() {
      arbitrator = GestureArbitrator();
    });

    test('Near-ratio boundary stress: 1.49x fails dominance, 1.50x and 1.51x pass', () {
      // Sub-threshold dominance: dx=14.9, dy=10.0 -> primary 14.9 < 1.5 * 10 (15.0)
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);
      var mode = arbitrator.arbitrate(
        currentPoint: const Offset(514.9, 310.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.arbitrating);
      expect(arbitrator.isCommitted, isFalse);

      // Exact dominance ratio: dx=15.0, dy=10.0 -> primary 15.0 == 1.5 * 10 (15.0)
      // primary < 1.5 * secondary is false -> passes!
      arbitrator.reset();
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(515.0, 310.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.horizontalScrub);
      expect(arbitrator.isCommitted, isTrue);

      // Above dominance ratio: dx=15.1, dy=10.0 -> passes!
      arbitrator.reset();
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);
      mode = arbitrator.arbitrate(
        currentPoint: const Offset(515.1, 310.0),
        viewportSize: standardViewport,
        pointerCount: 1,
      );
      expect(mode, GestureMode.horizontalScrub);
      expect(arbitrator.isCommitted, isTrue);
    });

    test('Complex wandering gesture in center zone eventually commits when dominant', () {
      arbitrator.handleDown(const Offset(500, 300), 1, standardViewport);

      // Wander 1: small move
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(505, 305), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.arbitrating,
      );

      // Wander 2: 45 degree diagonal move (dx=15, dy=15)
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(515, 315), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.arbitrating,
      );

      // Wander 3: vertical center swipe (dx=15, dy=40) -> vertical in center zone stays arbitrating
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(515, 340), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.arbitrating,
      );

      // Wander 4: user breaks out horizontally (dx=80, dy=40) -> primary 80 >= 1.5 * 40 (60)
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(580, 340), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.horizontalScrub,
      );
      expect(arbitrator.isCommitted, isTrue);

      // Wander 5: once committed, subsequent sharp vertical movement does NOT change mode
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(580, 500), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.horizontalScrub,
      );
    });

    test('Diagonal swipe in left zone resolves to brightness when vertical dominance achieved', () {
      arbitrator.handleDown(const Offset(100, 300), 1, standardViewport);

      // dx=18, dy=20 (fails dominance: 20 < 1.5 * 18 = 27)
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(118, 320), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.arbitrating,
      );

      // dx=18, dy=35 (passes dominance: 35 >= 1.5 * 18 = 27)
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(118, 335), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.brightnessAdjust,
      );
      expect(arbitrator.isCommitted, isTrue);
    });

    test('Diagonal swipe in right zone resolves to volume when vertical dominance achieved', () {
      arbitrator.handleDown(const Offset(800, 300), 1, standardViewport);

      // dx=18, dy=20
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(818, 320), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.arbitrating,
      );

      // dx=18, dy=35
      expect(
        arbitrator.arbitrate(currentPoint: const Offset(818, 335), viewportSize: standardViewport, pointerCount: 1),
        GestureMode.volumeAdjust,
      );
      expect(arbitrator.isCommitted, isTrue);
    });
  });

  group('Adversarial Challenge 5: Rapid Scale Updates & Strict Pan Boundary Invariant', () {
    late CinematicGestureEngine engine;

    setUp(() {
      engine = CinematicGestureEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('500 rapid scale & pan updates strictly satisfy pan boundary invariants', () {
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 2,
        ),
        standardViewport,
      );

      final rng = math.Random(42);

      for (int i = 0; i < 500; i++) {
        // Random scale multiplier from 0.05 to 10.0
        final scaleMultiplier = 0.05 + rng.nextDouble() * 9.95;
        // Random panning delta from -200 to +200
        final deltaX = (rng.nextDouble() - 0.5) * 400.0;
        final deltaY = (rng.nextDouble() - 0.5) * 400.0;

        engine.handleScaleUpdate(
          ScaleUpdateDetails(
            localFocalPoint: Offset(500 + deltaX, 300 + deltaY),
            focalPointDelta: Offset(deltaX, deltaY),
            scale: scaleMultiplier,
            pointerCount: 2,
          ),
          standardViewport,
          Duration.zero,
          const Duration(seconds: 300),
        );

        // Verification 1: Scale clamped within [1.0, 4.0]
        expect(engine.scale, greaterThanOrEqualTo(CinematicGestureConfig.minZoomScale));
        expect(engine.scale, lessThanOrEqualTo(CinematicGestureConfig.maxZoomScale));

        // Verification 2: Pan boundary limits strictly satisfied (zero black void invariant)
        final maxTx = (engine.scale - 1.0) * standardViewport.width / 2.0;
        final maxTy = (engine.scale - 1.0) * standardViewport.height / 2.0;

        expect(
          engine.panOffset.dx.abs(),
          lessThanOrEqualTo(maxTx + 1e-6),
          reason: 'Iter $i: panOffset.dx ${engine.panOffset.dx} exceeded maxTx $maxTx at scale ${engine.scale}',
        );
        expect(
          engine.panOffset.dy.abs(),
          lessThanOrEqualTo(maxTy + 1e-6),
          reason: 'Iter $i: panOffset.dy ${engine.panOffset.dy} exceeded maxTy $maxTy at scale ${engine.scale}',
        );

        if (engine.scale <= 1.0) {
          expect(engine.panOffset, Offset.zero);
        }
      }

      engine.handleScaleEnd(ScaleEndDetails());
    });

    test('Two-finger pinch escalation cancels single-finger scrub without committing seek', () async {
      final List<SeekCommitEvent> committedSeeks = [];
      final sub = engine.seekCommitEvents.listen(committedSeeks.add);

      // Start 1-finger scrub
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(500, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(550, 300),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 100),
        const Duration(seconds: 600),
      );
      expect(engine.currentMode, GestureMode.horizontalScrub);
      expect(engine.scrubPreviewPosition, const Duration(seconds: 125));

      // Second finger touches down -> pointerCount = 2
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(550, 300),
          scale: 1.5,
          pointerCount: 2,
        ),
        standardViewport,
        const Duration(seconds: 100),
        const Duration(seconds: 600),
      );
      expect(engine.currentMode, GestureMode.pinchZoom);
      expect(engine.scale, 1.5);

      // Gesture ends
      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      // Crucial: no seek commit must have occurred because gesture escalated to pinchZoom!
      expect(committedSeeks, isEmpty);

      await sub.cancel();
    });
  });
}
