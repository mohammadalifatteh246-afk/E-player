import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/gesture_models.dart';
import 'package:app/features/player/ui/cinematic_gesture_engine.dart';

void main() {
  const Size standardViewport = Size(1000.0, 600.0);

  group('ADVERSARIAL DEFECT REPRODUCTION: Consecutive Scrub State Leak', () {
    test('BUG REPRODUCTION: Leaked _initialPosition causes subsequent scrubs to jump back to first scrub time', () async {
      SeekCommitEvent? committedSeek;
      final engine = CinematicGestureEngine();
      engine.seekCommitEvents.listen((e) => committedSeek = e);

      // Scrub 1: User is watching video at currentPosition = 60s (1m 00s).
      // They scrub forward by +40px (+20 seconds).
      // Expected and Actual: target is 80s (1m 20s).
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(540, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 60),
        const Duration(seconds: 600),
      );
      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      expect(committedSeek, isNotNull);
      expect(committedSeek!.target, const Duration(seconds: 80));

      // Playback advances: 5 minutes later, user is watching at currentPosition = 300s (5m 00s).
      // They perform a second scrub forward by +40px (+20 seconds).
      // Expected target: 300s + 20s = 320s (5m 20s).
      engine.handleScaleStart(
        ScaleStartDetails(localFocalPoint: const Offset(500, 300), pointerCount: 1),
        standardViewport,
      );
      engine.handleScaleUpdate(
        ScaleUpdateDetails(localFocalPoint: const Offset(540, 300), pointerCount: 1),
        standardViewport,
        const Duration(seconds: 300),
        const Duration(seconds: 600),
      );
      engine.handleScaleEnd(ScaleEndDetails());
      await pumpEventQueue();

      // EMPIRICAL BUG REPRODUCTION:
      // In app/lib/features/player/ui/cinematic_gesture_engine.dart, line 430:
      // `if (_initialPosition == Duration.zero && currentPosition > Duration.zero) { _initialPosition = currentPosition; }`
      // But _initialPosition is NEVER reset to Duration.zero or null on handleScaleStart or handleScaleEnd!
      // Thus, _initialPosition remains 60s.
      // candidateTarget evaluates to: 60s + 20s = 80s (instead of 300s + 20s = 320s)!
      // The player seeks BACKWARDS to 80s!
      print('=== BUG TELEMETRY ===');
      print('Expected second scrub target: 320s (05:20)');
      print('Actual second scrub target:   ${committedSeek!.target.inSeconds}s (${committedSeek!.target})');
      print('Timestamp drift:             ${(committedSeek!.target - const Duration(seconds: 320)).inSeconds}s');
      print('=====================');

      expect(
        committedSeek!.target,
        const Duration(seconds: 320),
        reason: 'CRITICAL STATE LEAK: _initialPosition was not cleared between gestures, anchoring all future scrubs to the first scrub position!',
      );

      engine.dispose();
    });
  });
}
