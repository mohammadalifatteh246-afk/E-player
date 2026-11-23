import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/jump_to_time_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JumpToTimeDialog Widget Tests (VLC goto_time Parity)', () {
    const currentPos = Duration(minutes: 20); // 20m
    const totalDuration = Duration(hours: 1, minutes: 40); // 100m

    testWidgets('1. Renders dialog header, hotkey badge, and current/total times', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JumpToTimeDialog(
              currentPosition: currentPos,
              totalDuration: totalDuration,
              onSeek: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JUMP TO TIME'), findsOneWidget);
      expect(find.text('Ctrl+T'), findsOneWidget);
      expect(find.textContaining('Current: 20:00  •  Total: 1:40:00'), findsOneWidget);
      expect(find.byKey(const Key('jump_to_time_input')), findsOneWidget);
      expect(find.byKey(const Key('jump_submit_button')), findsOneWidget);
    });

    testWidgets('2. Entering valid timestamp previews target and submits on Jump', (tester) async {
      Duration? seekedTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JumpToTimeDialog(
              currentPosition: currentPos,
              totalDuration: totalDuration,
              onSeek: (t) => seekedTarget = t,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('jump_to_time_input'));
      await tester.enterText(input, '00:45:00');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jump_preview_target')), findsOneWidget);
      expect(find.text('Target: 45:00'), findsOneWidget);

      // Tap Jump button
      await tester.tap(find.byKey(const Key('jump_submit_button')));
      await tester.pumpAndSettle();

      expect(seekedTarget, const Duration(minutes: 45));
    });

    testWidgets('3. Entering invalid timestamp shows error and disables Jump', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JumpToTimeDialog(
              currentPosition: currentPos,
              totalDuration: totalDuration,
              onSeek: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('jump_to_time_input'));
      await tester.enterText(input, 'not_a_timestamp');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jump_preview_error')), findsOneWidget);
      expect(find.textContaining('Invalid timestamp format'), findsOneWidget);

      // Jump button is disabled
      final jumpButton = tester.widget<ElevatedButton>(find.byKey(const Key('jump_submit_button')));
      expect(jumpButton.onPressed, isNull);
    });

    testWidgets('4. Quick jump chips update input text and calculate target', (tester) async {
      Duration? seekedTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JumpToTimeDialog(
              currentPosition: currentPos,
              totalDuration: totalDuration,
              onSeek: (t) => seekedTarget = t,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap +10 min chip
      final plus10Chip = find.byKey(const Key('quick_jump_+10m'));
      expect(plus10Chip, findsOneWidget);
      await tester.tap(plus10Chip);
      await tester.pumpAndSettle();

      // 20m + 10m = 30m
      expect(find.text('Target: 30:00'), findsOneWidget);

      // Tap 50% chip
      final halfChip = find.byKey(const Key('quick_jump_50%'));
      expect(halfChip, findsOneWidget);
      await tester.tap(halfChip);
      await tester.pumpAndSettle();

      // 50% of 100m = 50m
      expect(find.text('Target: 50:00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('jump_submit_button')));
      await tester.pumpAndSettle();

      expect(seekedTarget, const Duration(minutes: 50));
    });
  });
}
