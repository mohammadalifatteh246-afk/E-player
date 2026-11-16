import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/gesture_models.dart';
import 'package:app/features/player/ui/cinematic_gesture_engine.dart';
import 'package:app/features/player/ui/widgets/desktop_keyboard_handler.dart';

/// Headless FakePlayer implementing [Player] for adversarial stress testing.
class FakeStressPlayer extends Fake implements Player {
  PlayerState _state;
  final List<String> callLog = [];

  FakeStressPlayer({
    bool playing = false,
    double volume = 100.0,
    double rate = 1.0,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 10),
  }) : _state = PlayerState(
          playing: playing,
          volume: volume,
          rate: rate,
          position: position,
          duration: duration,
        );

  @override
  PlayerState get state => _state;

  void updateState({
    bool? playing,
    double? volume,
    double? rate,
    Duration? position,
    Duration? duration,
  }) {
    _state = PlayerState(
      playing: playing ?? _state.playing,
      volume: volume ?? _state.volume,
      rate: rate ?? _state.rate,
      position: position ?? _state.position,
      duration: duration ?? _state.duration,
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    callLog.add('setVolume:$volume');
    updateState(volume: volume);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const Size standardViewport = Size(1000.0, 600.0);

  group('Adversarial Stress 1: Mathematical Boundaries & Exact Transitions', () {
    test('Boundary threshold mapping matches exact specifications', () {
      final thresholds = [
        0.0,
        50.0,
        100.0,
        100.0001,
        150.0,
        200.0,
        200.0001,
        250.0,
        300.0,
      ];

      for (final v in thresholds) {
        final color = VolumeSafetyColors.resolve(v);
        if (v <= 100.0) {
          expect(color, VolumeSafetyColors.green, reason: 'Volume $v should be Green');
        } else if (v <= 200.0) {
          expect(color, VolumeSafetyColors.amber, reason: 'Volume $v should be Amber');
        } else {
          expect(color, VolumeSafetyColors.softRed, reason: 'Volume $v should be Soft Red');
        }
      }
    });

    test('Microscopic epsilon transition at 100.0 and 200.0', () {
      expect(VolumeSafetyColors.resolve(100.0), VolumeSafetyColors.green);
      expect(VolumeSafetyColors.resolve(100.0 + 1e-9), VolumeSafetyColors.amber);

      expect(VolumeSafetyColors.resolve(200.0), VolumeSafetyColors.amber);
      expect(VolumeSafetyColors.resolve(200.0 + 1e-9), VolumeSafetyColors.softRed);
    });

    test('Extreme out-of-bounds volume colors degrade gracefully', () {
      expect(VolumeSafetyColors.resolve(-1e6), VolumeSafetyColors.green);
      expect(VolumeSafetyColors.resolve(1e6), VolumeSafetyColors.softRed);
    });

    test('Glow alpha is consistently ~0.4 across all zones', () {
      for (double v = 0.0; v <= 300.0; v += 15.0) {
        final glow = VolumeSafetyColors.resolveGlow(v);
        expect(glow.a, closeTo(0.4, 0.02), reason: 'Glow alpha for volume $v must be ~0.4');
      }
    });
  });

  group('Adversarial Stress 2: Jump Discontinuity & Derivative Continuity Check', () {
    test('Derivative dV/dy is strictly identical across 100% boundary (zero jerk / spike)', () {
      final engine = CinematicGestureEngine(initialVolume: 95.0);
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(850, 400),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Commit gesture into volumeAdjust mode by passing 12px dead zone (move 14px)
      // delta = (-(-14) / 420) * 150 = +5.0% -> volume reaches 100.0%
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 386),
          focalPointDelta: const Offset(0, -14),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.currentMode, GestureMode.volumeAdjust);
      expect(engine.volume, closeTo(100.0, 0.1));

      // Now that the gesture is committed, move in 1,000 infinitesimal steps across the boundary (100% to 120%)
      // dy per step = -0.056px -> delta = (0.056 / 420) * 150 = 0.02%
      const int steps = 1000;
      const double dyStep = -0.056;
      final expectedDeltaPerStep = (-dyStep / (600.0 * 0.7)) * 150.0;

      double previousVolume = engine.volume;
      for (int i = 0; i < steps; i++) {
        engine.handleScaleUpdate(
          ScaleUpdateDetails(
            localFocalPoint: Offset(850, 386.0 + (i + 1) * dyStep),
            focalPointDelta: const Offset(0, dyStep),
            pointerCount: 1,
          ),
          standardViewport,
          Duration.zero,
          Duration.zero,
        );

        final currentVolume = engine.volume;
        final observedDelta = currentVolume - previousVolume;

        // Verify delta per step is strictly invariant to within floating precision
        expect(
          observedDelta,
          closeTo(expectedDeltaPerStep, 1e-6),
          reason: 'Step $i across boundary produced non-linear jump: $observedDelta vs $expectedDeltaPerStep',
        );

        previousVolume = currentVolume;
      }

      engine.dispose();
    });
  });

  group('Adversarial Stress 3: Gesture Physics & Dynamic Viewport Travel', () {
    test('Exactly 2 full 70% viewport swipes spans 0% to 300% (K=150.0)', () {
      final engine = CinematicGestureEngine(initialVolume: 0.0);
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(850, 500),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Viewport height 600 -> 70% track is 420px.
      // Swipe 1: 420px upward
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 80),
          focalPointDelta: const Offset(0, -420),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, closeTo(150.0, 1e-5), reason: 'Swipe 1 must reach exactly 150%');

      // Swipe 2: 420px upward
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, -340),
          focalPointDelta: const Offset(0, -420),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, closeTo(300.0, 1e-5), reason: 'Swipe 2 must reach exactly 300%');

      // Reverse Swipe 1: 420px downward
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 80),
          focalPointDelta: const Offset(0, 420),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, closeTo(150.0, 1e-5), reason: 'Reverse swipe 1 must reach exactly 150%');

      // Reverse Swipe 2: 420px downward
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 500),
          focalPointDelta: const Offset(0, 420),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, closeTo(0.0, 1e-5), reason: 'Reverse swipe 2 must reach exactly 0%');

      engine.dispose();
    });

    test('Gesture travel invariance on 4K, 1080p, Mobile and zero-size viewports', () {
      final viewports = [
        const Size(3840, 2160), // 4K UHD
        const Size(1920, 1080), // Full HD
        const Size(390, 844),   // iPhone 14
        const Size(360, 640),   // Android Compact
        const Size(0, 0),       // Fallback to 600.0
      ];

      for (final vp in viewports) {
        final engine = CinematicGestureEngine(initialVolume: 0.0);
        final startX = vp.width > 0 ? vp.width * 0.8 : 500.0;
        final startY = vp.height > 0 ? vp.height * 0.8 : 400.0;

        engine.handleScaleStart(
          ScaleStartDetails(
            localFocalPoint: Offset(startX, startY),
            pointerCount: 1,
          ),
          vp,
        );

        final effectiveH = vp.height > 0 ? vp.height : 600.0;
        final swipe70 = effectiveH * 0.7;

        // Perform 1 full 70% swipe
        engine.handleScaleUpdate(
          ScaleUpdateDetails(
            localFocalPoint: Offset(startX, startY - swipe70),
            focalPointDelta: Offset(0, -swipe70),
            pointerCount: 1,
          ),
          vp,
          Duration.zero,
          Duration.zero,
        );

        expect(
          engine.volume,
          closeTo(150.0, 1e-4),
          reason: 'Viewport $vp 70% swipe must produce exactly 150% volume',
        );

        engine.dispose();
      }
    });

    test('Massive delta clamping stress: +1,000,000px and -1,000,000px', () {
      final engine = CinematicGestureEngine(initialVolume: 150.0);
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(850, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Colossal upward delta
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, -1000000),
          focalPointDelta: const Offset(0, -1000000),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, 300.0, reason: 'Massive upward delta must clamp strictly to 300.0');

      // Additional upward deltas while clamped at 300
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, -2000000),
          focalPointDelta: const Offset(0, -50000),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, 300.0);

      // Colossal downward delta
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 1000000),
          focalPointDelta: const Offset(0, 3000000),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, 0.0, reason: 'Massive downward delta must clamp strictly to 0.0');

      // Additional downward deltas while clamped at 0
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 2000000),
          focalPointDelta: const Offset(0, 50000),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      expect(engine.volume, 0.0);

      engine.dispose();
    });

    test('10,000 cycles of rapid oscillatory swipe jitter produces zero cumulative drift', () {
      final engine = CinematicGestureEngine(initialVolume: 150.0);
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(850, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      final rng = math.Random(42);
      double currentY = 300.0;

      // Execute 10,000 micro jitter updates: +dy followed by -dy
      for (int i = 0; i < 5000; i++) {
        final jitter = (rng.nextDouble() * 10.0) + 0.1;

        // Upward
        currentY -= jitter;
        engine.handleScaleUpdate(
          ScaleUpdateDetails(
            localFocalPoint: Offset(850, currentY),
            focalPointDelta: Offset(0, -jitter),
            pointerCount: 1,
          ),
          standardViewport,
          Duration.zero,
          Duration.zero,
        );

        // Downward
        currentY += jitter;
        engine.handleScaleUpdate(
          ScaleUpdateDetails(
            localFocalPoint: Offset(850, currentY),
            focalPointDelta: Offset(0, jitter),
            pointerCount: 1,
          ),
          standardViewport,
          Duration.zero,
          Duration.zero,
        );
      }

      // Net displacement is 0.0, so final volume must equal initial volume (150.0)
      expect(
        engine.volume,
        closeTo(150.0, 1e-4),
        reason: 'Symmetric oscillatory jitter must not cause numerical drift',
      );

      engine.dispose();
    });
  });

  group('Adversarial Stress 4: DesktopKeyboardHandler Quantization & Traversal', () {
    late FakeStressPlayer player;
    late List<String> osdMessages;
    late List<IconData> osdIcons;
    late List<Color?> osdColors;

    setUp(() {
      player = FakeStressPlayer();
      osdMessages = [];
      osdIcons = [];
      osdColors = [];
    });

    Widget buildTestHarness() {
      return MaterialApp(
        home: Scaffold(
          body: DesktopKeyboardHandler(
            player: player,
            onToggleFullscreen: () {},
            onCycleAspectRatio: () {},
            onCycleAudioTrack: () {},
            onCycleSubtitleTrack: () {},
            onNudgeAudioDelay: (_) {},
            onNudgeSubtitleDelay: (_) {},
            onShowOsd: (msg, icon, [color]) {
              osdMessages.add(msg);
              osdIcons.add(icon);
              osdColors.add(color);
            },
            onUserActivity: () {},
            child: const Center(child: Text('Surface')),
          ),
        ),
      );
    }

    testWidgets('Arbitrary float quantization (3.3%, 98.7%, 299.1%, 0.001%) snap to 5% grids',
        (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Test Case 1: 3.3%
      player.updateState(volume: 3.3);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(player.state.volume, 10.0, reason: '3.3 + 5 = 8.3 -> rounds to 10.0');

      player.updateState(volume: 3.3);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.state.volume, 0.0, reason: '3.3 - 5 = -1.7 -> rounds to 0.0');

      // Test Case 2: 98.7%
      player.updateState(volume: 98.7);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(player.state.volume, 105.0, reason: '98.7 + 5 = 103.7 -> rounds to 105.0');
      expect(osdColors.last, VolumeSafetyColors.amber);

      player.updateState(volume: 98.7);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.state.volume, 95.0, reason: '98.7 - 5 = 93.7 -> rounds to 95.0');
      expect(osdColors.last, VolumeSafetyColors.green);

      // Test Case 3: 299.1%
      player.updateState(volume: 299.1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(player.state.volume, 300.0, reason: '299.1 + 5 = 304.1 -> clamps to 300.0');
      expect(osdColors.last, VolumeSafetyColors.softRed);
      expect(osdIcons.last, Icons.warning_amber_rounded);

      player.updateState(volume: 299.1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.state.volume, 295.0, reason: '299.1 - 5 = 294.1 -> rounds to 295.0');
      expect(osdColors.last, VolumeSafetyColors.softRed);

      // Test Case 4: 0.001%
      player.updateState(volume: 0.001);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.state.volume, 0.0);
      expect(osdMessages.last, 'Mute');
    });

    testWidgets('Full 65-step ascending traversal across 0% to 300% and boundary clamp verification',
        (tester) async {
      player.updateState(volume: 0.0);
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Ascend 65 steps (0 -> 300 requires exactly 60 steps)
      for (int i = 1; i <= 65; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        final expectedVolume = (i * 5.0).clamp(0.0, 300.0);
        expect(
          player.state.volume,
          expectedVolume,
          reason: 'Step $i should set volume to $expectedVolume',
        );

        final expectedColor = VolumeSafetyColors.resolve(expectedVolume);
        expect(
          osdColors.last,
          expectedColor,
          reason: 'Step $i (vol $expectedVolume) color mismatch',
        );

        if (expectedVolume > 200.0) {
          expect(
            osdIcons.last,
            Icons.warning_amber_rounded,
            reason: 'Step $i (vol $expectedVolume) must display warning icon',
          );
        } else {
          expect(
            osdIcons.last,
            Icons.volume_up_rounded,
            reason: 'Step $i (vol $expectedVolume) must display volume_up icon',
          );
        }
      }

      // Descend 65 steps
      for (int i = 1; i <= 65; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        final expectedVolume = (300.0 - i * 5.0).clamp(0.0, 300.0);
        expect(
          player.state.volume,
          expectedVolume,
          reason: 'Descending step $i should set volume to $expectedVolume',
        );

        final expectedColor = VolumeSafetyColors.resolve(expectedVolume);
        expect(osdColors.last, expectedColor);

        if (expectedVolume == 0.0) {
          expect(osdMessages.last, 'Mute');
          expect(osdIcons.last, Icons.volume_off_rounded);
        }
      }
    });

    testWidgets('Mute and unmute restoration from over-amplified states (300%, 250%, 150%)',
        (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      final testVolumes = [300.0, 250.0, 185.0, 120.0, 85.0, 5.0];

      for (final v in testVolumes) {
        player.updateState(volume: v);

        // Mute
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.pump();
        expect(player.state.volume, 0.0, reason: 'Mute must set volume to 0.0');
        expect(osdMessages.last, 'Mute');
        expect(osdIcons.last, Icons.volume_off_rounded);

        // Unmute -> restores original volume
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.pump();
        expect(player.state.volume, v, reason: 'Unmute must restore previous volume $v');
        expect(osdMessages.last, 'Volume: ${v.round()}%');
      }
    });

    testWidgets('DesktopKeyboardHandler backward compatibility with legacy 2-parameter onShowOsd',
        (tester) async {
      final legacyMessages = <String>[];
      final legacyIcons = <IconData>[];

      // Declare strict legacy signature: void Function(String, IconData)
      void legacyOsd(String message, IconData icon) {
        legacyMessages.add(message);
        legacyIcons.add(icon);
      }

      final widget = MaterialApp(
        home: Scaffold(
          body: DesktopKeyboardHandler(
            player: player,
            onToggleFullscreen: () {},
            onCycleAspectRatio: () {},
            onCycleAudioTrack: () {},
            onCycleSubtitleTrack: () {},
            onNudgeAudioDelay: (_) {},
            onNudgeSubtitleDelay: (_) {},
            onShowOsd: legacyOsd,
            onUserActivity: () {},
            child: const Center(child: Text('Legacy Test')),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      player.updateState(volume: 100.0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(player.state.volume, 105.0);
      expect(legacyMessages.last, 'Volume: 105%');
      expect(legacyIcons.last, Icons.volume_up_rounded);
    });
  });
}
