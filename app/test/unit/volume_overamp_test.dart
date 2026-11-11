import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/gesture_models.dart';
import 'package:app/features/player/ui/cinematic_gesture_engine.dart';
import 'package:app/features/player/ui/widgets/desktop_keyboard_handler.dart';

/// Headless FakePlayer implementing [Player] for unit and widget testing.
class FakePlayer extends Fake implements Player {
  PlayerState _state;
  final List<String> callLog = [];

  FakePlayer({
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
  Future<void> playOrPause() async {
    callLog.add('playOrPause');
    updateState(playing: !_state.playing);
  }

  @override
  Future<void> setVolume(double volume) async {
    callLog.add('setVolume:$volume');
    updateState(volume: volume);
  }

  @override
  Future<void> setRate(double rate) async {
    callLog.add('setRate:$rate');
    updateState(rate: rate);
  }

  @override
  Future<void> seek(Duration position) async {
    callLog.add('seek:$position');
    updateState(position: position);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const Size standardViewport = Size(1000.0, 600.0);

  group('VolumeSafetyColors - 3-Color Safety Indicator Specifications', () {
    test('Safety color constants match exact hex specifications', () {
      expect(VolumeSafetyColors.green, const Color(0xFF22C55E));
      expect(VolumeSafetyColors.amber, const Color(0xFFF59E0B));
      expect(VolumeSafetyColors.softRed, const Color(0xFFEF4444));
    });

    test('Zone 1 (0% to 100%): Nominal Unity Gain resolves to Green', () {
      expect(VolumeSafetyColors.resolve(0.0), VolumeSafetyColors.green);
      expect(VolumeSafetyColors.resolve(25.0), VolumeSafetyColors.green);
      expect(VolumeSafetyColors.resolve(50.0), VolumeSafetyColors.green);
      expect(VolumeSafetyColors.resolve(75.0), VolumeSafetyColors.green);
      expect(VolumeSafetyColors.resolve(100.0), VolumeSafetyColors.green);
    });

    test('Zone 2 (101% to 200%): Software Pre-Amp Boost resolves to Amber', () {
      expect(VolumeSafetyColors.resolve(100.001), VolumeSafetyColors.amber);
      expect(VolumeSafetyColors.resolve(101.0), VolumeSafetyColors.amber);
      expect(VolumeSafetyColors.resolve(150.0), VolumeSafetyColors.amber);
      expect(VolumeSafetyColors.resolve(199.9), VolumeSafetyColors.amber);
      expect(VolumeSafetyColors.resolve(200.0), VolumeSafetyColors.amber);
    });

    test('Zone 3 (201% to 300%): High Over-Amplification Warning resolves to Soft Red', () {
      expect(VolumeSafetyColors.resolve(200.001), VolumeSafetyColors.softRed);
      expect(VolumeSafetyColors.resolve(201.0), VolumeSafetyColors.softRed);
      expect(VolumeSafetyColors.resolve(250.0), VolumeSafetyColors.softRed);
      expect(VolumeSafetyColors.resolve(300.0), VolumeSafetyColors.softRed);
      // Beyond 300 also returns softRed
      expect(VolumeSafetyColors.resolve(350.0), VolumeSafetyColors.softRed);
    });

    test('resolveGlow applies 0.4 alpha to the corresponding safety color', () {
      final greenGlow = VolumeSafetyColors.resolveGlow(50.0);
      expect(greenGlow.r, VolumeSafetyColors.green.r);
      expect(greenGlow.g, VolumeSafetyColors.green.g);
      expect(greenGlow.b, VolumeSafetyColors.green.b);
      expect(greenGlow.a, closeTo(0.4, 0.05));

      final amberGlow = VolumeSafetyColors.resolveGlow(150.0);
      expect(amberGlow.r, VolumeSafetyColors.amber.r);
      expect(amberGlow.g, VolumeSafetyColors.amber.g);
      expect(amberGlow.b, VolumeSafetyColors.amber.b);
      expect(amberGlow.a, closeTo(0.4, 0.05));

      final redGlow = VolumeSafetyColors.resolveGlow(250.0);
      expect(redGlow.r, VolumeSafetyColors.softRed.r);
      expect(redGlow.g, VolumeSafetyColors.softRed.g);
      expect(redGlow.b, VolumeSafetyColors.softRed.b);
      expect(redGlow.a, closeTo(0.4, 0.05));
    });
  });

  group('CinematicGestureEngine - Volume Scaling across 0% to 300%', () {
    test('Initial volume clamps strictly between 0.0 and 300.0', () {
      final engineUnder = CinematicGestureEngine(initialVolume: -50.0);
      expect(engineUnder.volume, 0.0);
      engineUnder.dispose();

      final engineNormal = CinematicGestureEngine(initialVolume: 100.0);
      expect(engineNormal.volume, 100.0);
      engineNormal.dispose();

      final engineBoost = CinematicGestureEngine(initialVolume: 250.0);
      expect(engineBoost.volume, 250.0);
      engineBoost.dispose();

      final engineOver = CinematicGestureEngine(initialVolume: 350.0);
      expect(engineOver.volume, 300.0);
      engineOver.dispose();
    });

    test('setExternalVolume clamps strictly between 0.0 and 300.0', () {
      final engine = CinematicGestureEngine(initialVolume: 50.0);

      engine.setExternalVolume(175.0);
      expect(engine.volume, 175.0);

      engine.setExternalVolume(300.0);
      expect(engine.volume, 300.0);

      engine.setExternalVolume(400.0);
      expect(engine.volume, 300.0);

      engine.setExternalVolume(-20.0);
      expect(engine.volume, 0.0);

      engine.dispose();
    });

    test('Right edge vertical swipe scales volume smoothly across 0% to 300%', () async {
      double? reportedVolume;
      final engine = CinematicGestureEngine(
        initialVolume: 0.0,
        onVolumeChanged: (v) => reportedVolume = v,
      );

      final List<GestureFeedbackEvent> feedbackEvents = [];
      final sub = engine.feedbackEvents.listen(feedbackEvents.add);

      // Start gesture in right 35% zone (X=850 on 1000px viewport)
      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(850, 400),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Effective track = 600 * 0.7 = 420.0px.
      // Swipe up 420px -> delta = (-(-420) / 420) * 150 = +150.0%
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 400 - 420),
          focalPointDelta: const Offset(0, -420),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      await pumpEventQueue();

      expect(engine.currentMode, GestureMode.volumeAdjust);
      expect(engine.volume, closeTo(150.0, 0.1));
      expect(reportedVolume, closeTo(150.0, 0.1));
      expect(feedbackEvents.isNotEmpty, isTrue);
      expect(feedbackEvents.last.type, GestureFeedbackType.volume);
      expect(feedbackEvents.last.value, closeTo(150.0, 0.1));
      expect(feedbackEvents.last.label, '150%');

      // Swipe up another 420px -> reaches 300.0%
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 400 - 840),
          focalPointDelta: const Offset(0, -420),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      await pumpEventQueue();

      expect(engine.volume, closeTo(300.0, 0.1));
      expect(reportedVolume, closeTo(300.0, 0.1));
      expect(feedbackEvents.last.label, '300%');

      // Dragging further upwards clamps strictly to 300.0%
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 400 - 1000),
          focalPointDelta: const Offset(0, -200),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      await pumpEventQueue();
      expect(engine.volume, 300.0);

      // Dragging downwards clamps strictly to 0.0%
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 1000),
          focalPointDelta: const Offset(0, 2000),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );
      await pumpEventQueue();
      expect(engine.volume, 0.0);
      expect(feedbackEvents.last.label, '0%');

      await sub.cancel();
      engine.dispose();
    });

    test('Zero jump discontinuity across 100% boundary (smooth monotonic travel)', () {
      final engine = CinematicGestureEngine(initialVolume: 95.0);

      engine.handleScaleStart(
        ScaleStartDetails(
          localFocalPoint: const Offset(850, 300),
          pointerCount: 1,
        ),
        standardViewport,
      );

      // Small drag upwards across 100% boundary:
      // delta = (-(-28) / 420) * 150 = +10.0% -> 95 + 10 = 105.0%
      engine.handleScaleUpdate(
        ScaleUpdateDetails(
          localFocalPoint: const Offset(850, 272),
          focalPointDelta: const Offset(0, -28),
          pointerCount: 1,
        ),
        standardViewport,
        Duration.zero,
        Duration.zero,
      );

      expect(engine.volume, closeTo(105.0, 0.1));
      engine.dispose();
    });
  });

  group('DesktopKeyboardHandler - Volume Adjustments (0%–300% in 5% Steps & 3-Color OSD)', () {
    late FakePlayer player;
    late List<String> osdMessages;
    late List<IconData> osdIcons;
    late List<Color?> osdColors;
    int userActivityCount = 0;

    setUp(() {
      player = FakePlayer();
      osdMessages = [];
      osdIcons = [];
      osdColors = [];
      userActivityCount = 0;
    });

    Widget buildTestWidget() {
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
            onUserActivity: () => userActivityCount++,
            child: const Center(child: Text('Video Surface')),
          ),
        ),
      );
    }

    testWidgets('ArrowUp increases volume by 5% and passes Green safety color in Zone 1 (0–100%)',
        (tester) async {
      player.updateState(volume: 50.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(player.state.volume, 55.0);
      expect(osdMessages.last, 'Volume: 55%');
      expect(osdIcons.last, Icons.volume_up_rounded);
      expect(osdColors.last, VolumeSafetyColors.green);
      expect(userActivityCount, 1);
    });

    testWidgets('ArrowUp advances volume into Zone 2 (101%–200%) with Amber safety color',
        (tester) async {
      player.updateState(volume: 100.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(player.state.volume, 105.0);
      expect(osdMessages.last, 'Volume: 105%');
      expect(osdIcons.last, Icons.volume_up_rounded);
      expect(osdColors.last, VolumeSafetyColors.amber);
    });

    testWidgets('ArrowUp advances volume into Zone 3 (201%–300%) with Soft Red safety color & warning icon',
        (tester) async {
      player.updateState(volume: 200.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(player.state.volume, 205.0);
      expect(osdMessages.last, 'Volume: 205%');
      expect(osdIcons.last, Icons.warning_amber_rounded);
      expect(osdColors.last, VolumeSafetyColors.softRed);
    });

    testWidgets('ArrowUp clamps strictly at 300.0%', (tester) async {
      player.updateState(volume: 298.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(player.state.volume, 300.0);
      expect(osdMessages.last, 'Volume: 300%');
      expect(osdColors.last, VolumeSafetyColors.softRed);

      // Subsequent ArrowUp stays at 300.0
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(player.state.volume, 300.0);
    });

    testWidgets('ArrowDown decreases volume by 5% and clamps strictly at 0.0% with Mute OSD',
        (tester) async {
      player.updateState(volume: 5.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(player.state.volume, 0.0);
      expect(osdMessages.last, 'Mute');
      expect(osdIcons.last, Icons.volume_off_rounded);
      expect(osdColors.last, VolumeSafetyColors.green);

      // Subsequent ArrowDown stays at 0.0
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.state.volume, 0.0);
    });

    testWidgets('Key m toggles mute and restores boost volume (e.g. 250%)',
        (tester) async {
      player.updateState(volume: 250.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(player.state.volume, 0.0);
      expect(osdMessages.last, 'Mute');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(player.state.volume, 250.0);
      expect(osdMessages.last, 'Volume: 250%');
    });
  });
}
