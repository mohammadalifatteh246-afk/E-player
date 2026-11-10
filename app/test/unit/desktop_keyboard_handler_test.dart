import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/widgets/desktop_keyboard_handler.dart';

/// Pure headless FakePlayer implementing [Player] for unit and widget testing.
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

  late FakePlayer player;
  late List<String> osdMessages;
  late List<IconData> osdIcons;
  int userActivityCount = 0;
  int toggleFullscreenCount = 0;
  int cycleAspectRatioCount = 0;
  int cycleAudioTrackCount = 0;
  int cycleSubtitleTrackCount = 0;
  int audioDelayOffset = 0;
  int subtitleDelayOffset = 0;
  int beforeSeekCount = 0;
  Duration? lastCustomSeekTarget;

  setUp(() {
    player = FakePlayer();
    osdMessages = [];
    osdIcons = [];
    userActivityCount = 0;
    toggleFullscreenCount = 0;
    cycleAspectRatioCount = 0;
    cycleAudioTrackCount = 0;
    cycleSubtitleTrackCount = 0;
    audioDelayOffset = 0;
    subtitleDelayOffset = 0;
    beforeSeekCount = 0;
    lastCustomSeekTarget = null;
  });

  Widget buildTestWidget({
    Player? customPlayer,
    void Function(Duration)? onSeek,
    VoidCallback? onBeforeSeek,
    FocusNode? focusNode,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DesktopKeyboardHandler(
          player: customPlayer ?? player,
          focusNode: focusNode,
          onToggleFullscreen: () => toggleFullscreenCount++,
          onCycleAspectRatio: () => cycleAspectRatioCount++,
          onCycleAudioTrack: () => cycleAudioTrackCount++,
          onCycleSubtitleTrack: () => cycleSubtitleTrackCount++,
          onNudgeAudioDelay: (offset) => audioDelayOffset += offset,
          onNudgeSubtitleDelay: (offset) => subtitleDelayOffset += offset,
          onShowOsd: (msg, icon) {
            osdMessages.add(msg);
            osdIcons.add(icon);
          },
          onUserActivity: () => userActivityCount++,
          onBeforeSeek: onBeforeSeek,
          onSeek: onSeek,
          child: const Center(child: Text('Video Surface')),
        ),
      ),
    );
  }

  group('DesktopKeyboardHandler - 4-Tier Seek Physics', () {
    testWidgets('Shift + ArrowRight triggers Tier 1 (3s) Dialogue Jump forward',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 13));
      expect(osdMessages.last, contains('+3s (Dialogue Jump (3s))'));
      expect(userActivityCount, 1);
    });

    testWidgets('Shift + ArrowLeft triggers Tier 1 (3s) Dialogue Jump backward',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 7));
      expect(osdMessages.last, contains('-3s (Dialogue Jump (3s))'));
    });

    testWidgets('Alt + ArrowRight triggers Tier 2 (10s) Short Jump forward',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 20));
      expect(osdMessages.last, contains('+10s (Short Jump (10s))'));
    });

    testWidgets('Alt + ArrowLeft triggers Tier 2 (10s) Short Jump backward',
        (tester) async {
      player.updateState(position: const Duration(seconds: 20));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 10));
      expect(osdMessages.last, contains('-10s (Short Jump (10s))'));
    });

    testWidgets('Ctrl + ArrowRight triggers Tier 3 (60s) Medium Jump forward',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 70));
      expect(osdMessages.last, contains('+60s (Medium Jump (1m))'));
    });

    testWidgets('Ctrl + ArrowLeft triggers Tier 3 (60s) Medium Jump backward',
        (tester) async {
      player.updateState(position: const Duration(seconds: 100));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 40));
      expect(osdMessages.last, contains('-60s (Medium Jump (1m))'));
    });

    testWidgets('Meta (macOS Cmd) + ArrowRight triggers Tier 3 (60s)',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 70));
      expect(osdMessages.last, contains('+60s (Medium Jump (1m))'));
    });

    testWidgets('Ctrl + Alt + ArrowRight triggers Tier 4 (300s) Long Jump',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 310));
      expect(osdMessages.last, contains('+300s (Long Jump (5m))'));
    });

    testWidgets('Ctrl + Alt + ArrowLeft triggers Tier 4 (300s) Long Jump backward',
        (tester) async {
      player.updateState(position: const Duration(seconds: 400));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 100));
      expect(osdMessages.last, contains('-300s (Long Jump (5m))'));
    });

    testWidgets('Bare Arrow Right and Left trigger Default 10s seek',
        (tester) async {
      player.updateState(position: const Duration(seconds: 30));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(player.state.position, const Duration(seconds: 40));
      expect(osdMessages.last, contains('+10s (Seek (10s))'));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(player.state.position, const Duration(seconds: 30));
      expect(osdMessages.last, contains('-10s (Seek (10s))'));
    });

    testWidgets('Modifier precedence: Ctrl + Alt + Shift triggers Tier 4 (300s)',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 310));
      expect(osdMessages.last, contains('300s (Long Jump (5m))'));
    });

    testWidgets('Modifier precedence: Ctrl + Shift triggers Tier 3 (60s)',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 70));
      expect(osdMessages.last, contains('60s (Medium Jump (1m))'));
    });
  });

  group('DesktopKeyboardHandler - Boundary Clamping & Edge Cases', () {
    testWidgets('Backward seek clamps strictly to Duration.zero on underflow',
        (tester) async {
      player.updateState(position: const Duration(seconds: 2));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(player.state.position, Duration.zero);
    });

    testWidgets('Forward seek clamps to duration on overflow', (tester) async {
      player.updateState(
        position: const Duration(minutes: 9, seconds: 50),
        duration: const Duration(minutes: 10),
      );
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(player.state.position, const Duration(minutes: 10));
    });

    testWidgets('Zero duration stream does not truncate forward seek to zero',
        (tester) async {
      player.updateState(
        position: const Duration(seconds: 15),
        duration: Duration.zero,
      );
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(player.state.position, const Duration(seconds: 25));
    });

    testWidgets('Repeated backward seek at Duration.zero remains zero',
        (tester) async {
      player.updateState(position: Duration.zero);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(player.state.position, Duration.zero);
    });
  });

  group('DesktopKeyboardHandler - Transport & Window Shortcuts', () {
    testWidgets('Space toggles play/pause and reports OSD', (tester) async {
      player.updateState(playing: false);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(player.state.playing, isTrue);
      expect(osdMessages.last, 'Play');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(player.state.playing, isFalse);
      expect(osdMessages.last, 'Pause');
    });

    testWidgets('f and F11 toggle fullscreen', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(toggleFullscreenCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(toggleFullscreenCount, 2);
    });

    testWidgets('a cycles aspect ratio', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(cycleAspectRatioCount, 1);
    });

    testWidgets('b cycles audio track and v cycles subtitle track',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      expect(cycleAudioTrackCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(cycleSubtitleTrackCount, 1);
    });

    testWidgets('h and g nudge subtitle delay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      expect(subtitleDelayOffset, 50);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      expect(subtitleDelayOffset, 0);
    });

    testWidgets('k and j nudge audio delay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      expect(audioDelayOffset, 50);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      expect(audioDelayOffset, 0);
    });
  });

  group('DesktopKeyboardHandler - Playback Speed Controls', () {
    testWidgets('+ / numpadAdd / Shift+= increase speed by 0.25x',
        (tester) async {
      player.updateState(rate: 1.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(player.state.rate, 1.25);
      expect(osdMessages.last, 'Speed: 1.25x');

      await tester.sendKeyEvent(
        LogicalKeyboardKey.add,
        physicalKey: PhysicalKeyboardKey.numpadAdd,
      );
      await tester.pump();
      expect(player.state.rate, 1.50);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
      await tester.pump();
      expect(player.state.rate, 1.75);
    });

    testWidgets('- / numpadSubtract decrease speed by 0.25x', (tester) async {
      player.updateState(rate: 1.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      expect(player.state.rate, 0.75);
      expect(osdMessages.last, 'Speed: 0.75x');

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadSubtract);
      await tester.pump();
      expect(player.state.rate, 0.50);
    });

    testWidgets('] and [ adjust speed finely by 0.1x', (tester) async {
      player.updateState(rate: 1.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(player.state.rate, 1.1);

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(player.state.rate, 1.0);
    });

    testWidgets('= resets speed to 1.0x', (tester) async {
      player.updateState(rate: 2.5);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();

      expect(player.state.rate, 1.0);
      expect(osdMessages.last, 'Speed: 1.0x (Normal)');
    });

    testWidgets('Speed is clamped between 0.25x and 4.0x', (tester) async {
      player.updateState(rate: 3.9);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(player.state.rate, 4.0);

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(player.state.rate, 4.0);

      player.updateState(rate: 0.3);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(player.state.rate, 0.25);

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(player.state.rate, 0.25);
    });
  });

  group('DesktopKeyboardHandler - Volume & Mute Controls', () {
    testWidgets('ArrowUp and ArrowDown adjust volume in 5% increments',
        (tester) async {
      player.updateState(volume: 50.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(player.state.volume, 55.0);
      expect(osdMessages.last, 'Volume: 55%');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.state.volume, 50.0);
      expect(osdMessages.last, 'Volume: 50%');
    });

    testWidgets('Volume is clamped to 0.0 and 150.0', (tester) async {
      player.updateState(volume: 148.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(player.state.volume, 150.0);

      player.updateState(volume: 2.0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.state.volume, 0.0);
      expect(osdMessages.last, 'Mute');
    });

    testWidgets('Key m toggles mute and restores cached volume', (tester) async {
      player.updateState(volume: 75.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(player.state.volume, 0.0);
      expect(osdMessages.last, 'Mute');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(player.state.volume, 75.0);
      expect(osdMessages.last, 'Volume: 75%');
    });

    testWidgets('Key m restores 100% if initial volume was 0.0', (tester) async {
      player.updateState(volume: 0.0);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(player.state.volume, 100.0);
      expect(osdMessages.last, 'Volume: 100%');
    });
  });

  group('DesktopKeyboardHandler - Callbacks & Delegation', () {
    testWidgets('onBeforeSeek is called prior to player.seek', (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget(
        onBeforeSeek: () => beforeSeekCount++,
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(beforeSeekCount, 1);
      expect(player.state.position, const Duration(seconds: 20));
    });

    testWidgets('onSeek interceptor overrides direct player.seek when provided',
        (tester) async {
      player.updateState(position: const Duration(seconds: 10));
      await tester.pumpWidget(buildTestWidget(
        onSeek: (target) {
          lastCustomSeekTarget = target;
        },
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(lastCustomSeekTarget, const Duration(seconds: 20));
      // Custom onSeek didn't update player.state.position directly
      expect(player.state.position, const Duration(seconds: 10));
    });

    testWidgets('Unmapped keys are ignored and do not trigger activity',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(userActivityCount, 0);
    });

    testWidgets('KeyUpEvent does not trigger shortcuts', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(player.callLog, isEmpty);
      expect(userActivityCount, 0);
    });
  });
}
