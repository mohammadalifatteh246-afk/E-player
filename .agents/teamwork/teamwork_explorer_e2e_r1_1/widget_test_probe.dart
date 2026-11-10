import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'test_harness_probe.dart';

void main() {
  testWidgets('Probe: Desktop keyboard event interception with FakePlatformPlayer', (tester) async {
    final fakePlatform = FakePlatformPlayer();
    final player = Player(platformPlayer: fakePlatform);

    Duration? soughtTarget;
    String? osdMessage;

    // Minimal DesktopKeyboardHandler replica conforming to PROJECT.md interface contract
    final handler = Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final isShift = HardwareKeyboard.instance.isShiftPressed;
        final isAlt = HardwareKeyboard.instance.isAltPressed;
        final isCtrl = HardwareKeyboard.instance.isControlPressed;

        if (event.logicalKey == LogicalKeyboardKey.space) {
          player.playOrPause();
          osdMessage = player.state.playing ? 'Play' : 'Pause';
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          final int jumpSec = (isCtrl && isAlt)
              ? 300
              : isCtrl
                  ? 60
                  : isAlt
                      ? 10
                      : isShift
                          ? 3
                          : 10;
          final target = player.state.position + Duration(seconds: jumpSec);
          player.seek(target);
          soughtTarget = target;
          osdMessage = '+$jumpSec s';
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: const SizedBox(width: 100, height: 100),
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: handler)));
    await tester.pumpAndSettle();

    // 1. Space -> playOrPause
    expect(player.state.playing, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.state.playing, isFalse);
    expect(osdMessage, 'Pause');

    // 2. Shift + ArrowRight -> 3s jump
    expect(player.state.position, const Duration(seconds: 120));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(soughtTarget, const Duration(seconds: 123));
    expect(fakePlatform.seekCalls.last, const Duration(seconds: 123));
    expect(osdMessage, '+3 s');

    // 3. Ctrl + Alt + ArrowRight -> 300s jump
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(soughtTarget, const Duration(seconds: 423));
    expect(fakePlatform.seekCalls.last, const Duration(seconds: 423));
    expect(osdMessage, '+300 s');

    await player.dispose();
  });
}
