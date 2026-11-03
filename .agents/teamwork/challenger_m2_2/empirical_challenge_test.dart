import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/gesture_models.dart';
import 'package:app/features/player/ui/cinematic_gesture_engine.dart';

void main() {
  const Size standardViewport = Size(1000.0, 600.0);

  group('CHALLENGE 1: Zoom Scale Factor Clamping [1.0, 4.0]', () {
    late CinematicGestureEngine engine;

    setUp(() {
      engine = CinematicGestureEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('Initial scale factor is exactly 1.0', () {
      expect(engine.scale, 1.0);
      expect(engine.panOffset, Offset.zero);
    });

    test('Sub-1.0 pinch gestures clamp strictly to 1.0', () {
      final subScaleInputs = [0.99, 0.8, 0.5, 0.25, 0.1, 0.0];

      for (final inputScale in subScaleInputs) {
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
            scale: inputScale,
            pointerCount: 2,
          ),
          standardViewport,
          Duration.zero,
          Duration.zero,
        );

        expect(
          engine.scale,
          1.0,
          reason: 'Scale $inputScale did not clamp to minZoomScale (1.0)',
        );
        expect(
          engine.panOffset,
          Offset.zero,
          reason: 'Pan offset must remain zero when scale is 1.0',
        );

        engine.handleScaleEnd(ScaleEndDetails());
      }
    });

    test('Over-4.0 pinch gestures clamp strictly to 4.0', () {
      final overScaleInputs = [4.01, 4.5, 5.0, 8.0, 10.0, 50.0, 1000.0];

      for (final inputScale in overScaleInputs) {
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
            scale: inputScale,
            pointerCount: 2,
          ),
          standardViewport,
          Duration.zero,
          Duration.zero,
        );

        expect(
          engine.scale,
          4.0,
          reason: 'Scale $inputScale did not clamp to maxZoomScale (4.0)',
        );

        engine.handleScaleEnd(ScaleEndDetails());
      }
    });

    test('Sequential multi-touch pinch operations respect cumulative boundaries [1.0, 4.0]', () {
      // Step 1: Pinch to 2.0x
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 2),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(500, 300), scale: 2.0, pointerCount: 2),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      engine.handleScaleEnd(ScaleEndDetails());
      expect(engine.scale, 2.0);

      // Step 2: Pinch by 1.5x from 2.0x -> 3.0x
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 2),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(500, 300), scale: 1.5, pointerCount: 2),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      engine.handleScaleEnd(ScaleEndDetails());
      expect(engine.scale, 3.0);

      // Step 3: Pinch by 2.0x from 3.0x -> 6.0x (must clamp to 4.0)
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 2),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(500, 300), scale: 2.0, pointerCount: 2),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      engine.handleScaleEnd(ScaleEndDetails());
      expect(engine.scale, 4.0);

      // Step 4: Pinch by 0.1x from 4.0x -> 0.4x (must clamp to 1.0)
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 2),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(500, 300), scale: 0.1, pointerCount: 2),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      engine.handleScaleEnd(ScaleEndDetails());
      expect(engine.scale, 1.0);
      expect(engine.panOffset, Offset.zero);
    });

    test('Double-tap resets zoom and pan back to 1.0x and Offset.zero', () {
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 2),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(500, 300),
          scale: 3.5,
          focalPointDelta: const Offset(300, -150),
          pointerCount: 2,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      engine.handleScaleEnd(ScaleEndDetails());

      expect(engine.scale, 3.5);
      expect(engine.panOffset, const Offset(300, -150));

      // Double-tap anywhere resets zoom
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(500, 300)),
        standardViewport,
        const Duration(seconds: 40),
        const Duration(seconds: 120),
      );

      expect(engine.scale, 1.0);
      expect(engine.panOffset, Offset.zero);
    });
  });

  group('CHALLENGE 2: Zero Black Void Pan Bounds & Mathematical Invariants', () {
    test('Scale S = 2.5 strictly enforces |Tx| <= (S-1)*W/2 and |Ty| <= (S-1)*H/2 on 1000x600', () {
      const scale = 2.5;
      const width = 1000.0;
      const height = 600.0;
      const maxTx = (scale - 1.0) * width / 2.0; // 750.0
      const maxTy = (scale - 1.0) * height / 2.0; // 450.0

      expect(maxTx, 750.0);
      expect(maxTy, 450.0);

      // 1. Points within bounds are unaffected
      final inside = CinematicGestureEngine.clampPanOffset(
        const Offset(600, -350),
        scale,
        standardViewport,
      );
      expect(inside, const Offset(600, -350));

      // 2. Exact boundary points
      final posBoundary = CinematicGestureEngine.clampPanOffset(
        const Offset(750, 450),
        scale,
        standardViewport,
      );
      expect(posBoundary, const Offset(750, 450));

      final negBoundary = CinematicGestureEngine.clampPanOffset(
        const Offset(-750, -450),
        scale,
        standardViewport,
      );
      expect(negBoundary, const Offset(-750, -450));

      // 3. Just outside boundary
      final justOutside = CinematicGestureEngine.clampPanOffset(
        const Offset(750.1, 450.1),
        scale,
        standardViewport,
      );
      expect(justOutside.dx, 750.0);
      expect(justOutside.dy, 450.0);
    });

    test('Extreme pan inputs (Tx = 50000, Ty = -50000) are clamped to exact boundary without black void', () {
      const scale = 2.5;
      const width = 1000.0;
      const height = 600.0;
      const maxTx = (scale - 1.0) * width / 2.0; // 750.0
      const maxTy = (scale - 1.0) * height / 2.0; // 450.0

      final extreme1 = CinematicGestureEngine.clampPanOffset(
        const Offset(50000, -50000),
        scale,
        standardViewport,
      );
      expect(extreme1.dx, maxTx);
      expect(extreme1.dy, -maxTy);

      final extreme2 = CinematicGestureEngine.clampPanOffset(
        const Offset(-50000, 50000),
        scale,
        standardViewport,
      );
      expect(extreme2.dx, -maxTx);
      expect(extreme2.dy, maxTy);

      final massive = CinematicGestureEngine.clampPanOffset(
        const Offset(10000000, -10000000),
        scale,
        standardViewport,
      );
      expect(massive.dx, maxTx);
      expect(massive.dy, -maxTy);
    });

    test('Empirical Zero Black Void invariant verification across multi-resolution matrix', () {
      final viewports = [
        const Size(1000.0, 600.0), // Baseline desktop
        const Size(1920.0, 1080.0), // 1080p FHD
        const Size(3840.0, 2160.0), // 4K UHD
        const Size(2560.0, 1080.0), // Ultrawide 21:9
        const Size(1080.0, 2400.0), // Mobile 20:9 Portrait
      ];

      final testScales = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 3.75, 4.0];
      final extremeDeltas = [
        -1000000.0,
        -50000.0,
        -10000.0,
        -500.0,
        0.0,
        500.0,
        10000.0,
        50000.0,
        1000000.0,
      ];

      for (final vp in viewports) {
        for (final s in testScales) {
          final maxAllowedTx = (s - 1.0) * vp.width / 2.0;
          final maxAllowedTy = (s - 1.0) * vp.height / 2.0;

          for (final rawX in extremeDeltas) {
            for (final rawY in extremeDeltas) {
              final clamped = CinematicGestureEngine.clampPanOffset(
                Offset(rawX, rawY),
                s,
                vp,
              );

              // 1. Check bound invariants
              if (s <= 1.0) {
                expect(clamped, Offset.zero);
                continue;
              }

              expect(
                clamped.dx.abs(),
                lessThanOrEqualTo(maxAllowedTx + 1e-9),
                reason: 'Tx ${clamped.dx} exceeded max allowed $maxAllowedTx at scale $s, vp $vp',
              );
              expect(
                clamped.dy.abs(),
                lessThanOrEqualTo(maxAllowedTy + 1e-9),
                reason: 'Ty ${clamped.dy} exceeded max allowed $maxAllowedTy at scale $s, vp $vp',
              );

              // 2. Mathematical Zero Black Void Geometry Verification:
              // Video is centered at (vp.width/2 + Tx, vp.height/2 + Ty) with dimensions (s * vp.width, s * vp.height)
              final videoLeft = vp.width / 2.0 + clamped.dx - (s * vp.width / 2.0);
              final videoRight = vp.width / 2.0 + clamped.dx + (s * vp.width / 2.0);
              final videoTop = vp.height / 2.0 + clamped.dy - (s * vp.height / 2.0);
              final videoBottom = vp.height / 2.0 + clamped.dy + (s * vp.height / 2.0);

              // Viewport boundaries: [0, vp.width] x [0, vp.height]
              // Zero black void requires: videoLeft <= 0, videoRight >= vp.width, videoTop <= 0, videoBottom >= vp.height
              expect(
                videoLeft,
                lessThanOrEqualTo(1e-9),
                reason: 'Black void exposed on LEFT: videoLeft = $videoLeft > 0 at scale $s, vp $vp',
              );
              expect(
                videoRight,
                greaterThanOrEqualTo(vp.width - 1e-9),
                reason: 'Black void exposed on RIGHT: videoRight = $videoRight < ${vp.width} at scale $s, vp $vp',
              );
              expect(
                videoTop,
                lessThanOrEqualTo(1e-9),
                reason: 'Black void exposed on TOP: videoTop = $videoTop > 0 at scale $s, vp $vp',
              );
              expect(
                videoBottom,
                greaterThanOrEqualTo(vp.height - 1e-9),
                reason: 'Black void exposed on BOTTOM: videoBottom = $videoBottom < ${vp.height} at scale $s, vp $vp',
              );
            }
          }
        }
      }
    });
  });

  group('CHALLENGE 3: Seek Duration Clamping Invariants', () {
    late CinematicGestureEngine engine;
    SeekCommitEvent? committedSeek;
    Duration? seekCallbackTarget;

    setUp(() {
      committedSeek = null;
      seekCallbackTarget = null;
      engine = CinematicGestureEngine(
        onSeek: (target) => seekCallbackTarget = target,
      );
      engine.seekCommitEvents.listen((event) => committedSeek = event);
    });

    tearDown(() {
      engine.dispose();
    });

    test('Scrub seek underflow: negative target clamps strictly to Duration.zero', () async {
      // Start in center at currentPosition = 10s, totalDuration = 100s
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );

      // Drag left by 50px -> cumulativeDx = -50 -> deltaSeconds = -25s
      // candidateTarget = 10s - 25s = -15s -> clamped to Duration.zero
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(450, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 10),
        const Duration(seconds: 100),
      );

      expect(engine.scrubPreviewPosition, Duration.zero);

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeek, isNotNull);
      expect(committedSeek!.target, Duration.zero);
      expect(seekCallbackTarget, Duration.zero);
    });

    test('Scrub seek extreme underflow: -10000px drag clamps to Duration.zero', () async {
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );

      // Drag left by 10000px -> deltaSeconds = -5000s
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(-9500, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 100),
      );

      expect(engine.scrubPreviewPosition, Duration.zero);

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeek!.target, Duration.zero);
    });

    test('Scrub seek overflow: past totalDuration clamps strictly to totalDuration', () async {
      // Start in center at currentPosition = 80s, totalDuration = 100s
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );

      // Drag right by 60px -> deltaSeconds = +30s
      // candidateTarget = 80s + 30s = 110s -> clamped to totalDuration (100s)
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(560, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 80),
        const Duration(seconds: 100),
      );

      expect(engine.scrubPreviewPosition, const Duration(seconds: 100));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeek, isNotNull);
      expect(committedSeek!.target, const Duration(seconds: 100));
      expect(seekCallbackTarget, const Duration(seconds: 100));
    });

    test('Scrub seek extreme overflow: +10000px drag clamps to totalDuration', () async {
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );

      // Drag right by 10000px -> deltaSeconds = +5000s
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(10500, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 20),
        const Duration(seconds: 120),
      );

      expect(engine.scrubPreviewPosition, const Duration(seconds: 120));

      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeek!.target, const Duration(seconds: 120));
    });

    test('Wing double-tap underflow and overflow clamp strictly to bounds', () async {
      // Left wing at 2 seconds in 100s video (2s - 10s = -8s -> clamps to 0s)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(100, 300)),
        standardViewport,
        const Duration(seconds: 2),
        const Duration(seconds: 100),
      );
      await pumpEventQueue();
      expect(committedSeek!.target, Duration.zero);
      expect(seekCallbackTarget, Duration.zero);

      // Left wing at exactly 0s (0s - 10s = -10s -> clamps to 0s)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(100, 300)),
        standardViewport,
        Duration.zero,
        const Duration(seconds: 100),
      );
      await pumpEventQueue();
      expect(committedSeek!.target, Duration.zero);

      // Right wing at 95s in 100s video (95s + 10s = 105s -> clamps to 100s)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(900, 300)),
        standardViewport,
        const Duration(seconds: 95),
        const Duration(seconds: 100),
      );
      await pumpEventQueue();
      expect(committedSeek!.target, const Duration(seconds: 100));

      // Right wing at exactly 100s in 100s video (100s + 10s = 110s -> clamps to 100s)
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(900, 300)),
        standardViewport,
        const Duration(seconds: 100),
        const Duration(seconds: 100),
      );
      await pumpEventQueue();
      expect(committedSeek!.target, const Duration(seconds: 100));
    });
  });

  group('CHALLENGE 4: AI Queue Invalidation Verification', () {
    test('AI queue invalidation triggers on scrub seek commit and wing jumps, but NOT on non-seek gestures', () async {
      int invalidationCount = 0;
      final engine = CinematicGestureEngine(
        onInvalidateAiQueue: () => invalidationCount++,
      );

      // 1. Center horizontal scrub commit
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(550, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(invalidationCount, 0); // Not invalidated during scrub preview
      engine.handleScaleEnd(ScaleEndDetails());
      expect(invalidationCount, 1); // Invalidated on scrub release commit

      // 2. Left wing jump
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(100, 300)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(invalidationCount, 2);

      // 3. Right wing jump
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(900, 300)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(invalidationCount, 3);

      // 4. Center double-tap (play/pause) -> MUST NOT invalidate AI queue
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(500, 300)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(invalidationCount, 3);

      // 5. Left zone brightness swipe -> MUST NOT invalidate AI queue
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(100, 300), pointerCount: 1),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(100, 200),
          focalPointDelta: const Offset(0, -100),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      engine.handleScaleEnd(ScaleEndDetails());
      expect(invalidationCount, 3);

      // 6. Right zone volume swipe -> MUST NOT invalidate AI queue
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(900, 300), pointerCount: 1),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(900, 200),
          focalPointDelta: const Offset(0, -100),
          pointerCount: 1,
        ),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      engine.handleScaleEnd(ScaleEndDetails());
      expect(invalidationCount, 3);

      // 7. Pinch zoom -> MUST NOT invalidate AI queue
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 2),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(500, 300), scale: 2.0, pointerCount: 2),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      engine.handleScaleEnd(ScaleEndDetails());
      expect(invalidationCount, 3);

      // 8. Zoom double-tap reset -> MUST NOT invalidate AI queue
      engine.handleDoubleTapDown(
        TapDownDetails(localPosition: const Offset(500, 300)),
        standardViewport,
        const Duration(seconds: 30),
        const Duration(seconds: 120),
      );
      expect(invalidationCount, 3);

      engine.dispose();
    });
  });

  group('CHALLENGE 5: Consecutive Scrub State Invariant Stress Test', () {
    test('Consecutive scrubs from different playback positions evaluate targets correctly', () async {
      SeekCommitEvent? committedSeek;
      final engine = CinematicGestureEngine();
      engine.seekCommitEvents.listen((e) => committedSeek = e);

      // Scrub 1: At 60s, scrub forward 40px (+20s) -> target 80s
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(540, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 60),
        const Duration(seconds: 300),
      );
      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeek!.target, const Duration(seconds: 80));

      // Scrub 2: Media has played up to 150s. User scrubs forward 40px (+20s).
      // Expected target: 150s + 20s = 170s.
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(540, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 150),
        const Duration(seconds: 300),
      );
      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      // Check whether second scrub uses the current position (150s) or leaked initial position (60s)
      // Note: If engine fails to reset _initialPosition, target will be 80s instead of 170s.
      expect(
        committedSeek!.target,
        const Duration(seconds: 170),
        reason: 'Consecutive scrub failed: target was ${committedSeek!.target} instead of 170s due to leaked _initialPosition',
      );

      engine.dispose();
    });
  });
}
