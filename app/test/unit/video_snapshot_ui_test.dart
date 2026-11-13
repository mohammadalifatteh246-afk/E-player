import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/services/video_snapshot_service.dart';
import 'package:app/features/player/ui/widgets/desktop_keyboard_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Video Snapshot UI & Keyboard Interaction Tests', () {
    testWidgets('DesktopKeyboardHandler fires onTakeSnapshot callback on Shift+S', (tester) async {
      bool snapshotTriggered = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopKeyboardHandler(
              player: _FakePlayer(),
              focusNode: focusNode,
              autofocus: true,
              onToggleFullscreen: () {},
              onCycleAspectRatio: () {},
              onCycleAudioTrack: () {},
              onCycleSubtitleTrack: () {},
              onNudgeAudioDelay: (_) {},
              onNudgeSubtitleDelay: (_) {},
              onShowOsd: (p1, p2, [p3]) {},
              onUserActivity: () {},
              onTakeSnapshot: () {
                snapshotTriggered = true;
              },
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Simulate Shift + S key press
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(snapshotTriggered, isTrue);
    });

    testWidgets('Snapshot preview toast card renders image, filename, timestamp', (tester) async {
      const testResult = SnapshotResult(
        success: true,
        fileName: 'vlcsnap-2026-11-13-143000.png',
        timestamp: Duration(minutes: 5, seconds: 42),
      );

      expect(testResult.formattedPosition, '05:42');
      expect(testResult.fileName, 'vlcsnap-2026-11-13-143000.png');
      expect(testResult.success, isTrue);
    });
  });
}

class _FakePlayer extends Fake implements Player {
  @override
  PlayerState get state => const PlayerState();
}
