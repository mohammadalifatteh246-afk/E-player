import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String formatPosition(Duration d) {
    if (d < Duration.zero) d = Duration.zero;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:$minutes:$seconds';
    } else {
      final minutes = d.inMinutes.remainder(60).toString();
      return '$minutes:$seconds';
    }
  }

  String formatRemainingDuration(Duration pos, Duration dur) {
    if (dur <= Duration.zero || dur < pos) return '- 0:00';
    final remaining = dur - pos;
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (remaining.inHours > 0) {
      final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '- ${remaining.inHours}:$minutes:$seconds';
    } else {
      final minutes = remaining.inMinutes.remainder(60).toString();
      return '- $minutes:$seconds';
    }
  }

  group('Time Label Click Toggle (VLC Parity) - Unit & Widget Tests', () {
    test('Formatted duration formats correctly for both remaining and total modes', () {
      const position = Duration(minutes: 2, seconds: 30);
      const total = Duration(minutes: 10, seconds: 0);

      expect(formatPosition(total), equals('10:00'));
      expect(formatRemainingDuration(position, total), equals('- 7:30'));

      const longTotal = Duration(hours: 2, minutes: 15, seconds: 40);
      const longPos = Duration(minutes: 45, seconds: 0);

      expect(formatPosition(longTotal), equals('2:15:40'));
      expect(formatRemainingDuration(longPos, longTotal), equals('- 1:30:40'));
    });

    testWidgets('Interactive click toggles between Remaining and Total Duration', (tester) async {
      bool showRemaining = true;
      const position = Duration(minutes: 3, seconds: 15);
      const duration = Duration(minutes: 12, seconds: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Row(
                  children: [
                    Text('Pos: ${formatPosition(position)}'),
                    GestureDetector(
                      key: const Key('timeline_duration_toggle'),
                      onTap: () {
                        setState(() {
                          showRemaining = !showRemaining;
                        });
                      },
                      child: Text(
                        showRemaining
                            ? formatRemainingDuration(position, duration)
                            : formatPosition(duration),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state: shows remaining duration (- 8:45)
      expect(find.text('- 8:45'), findsOneWidget);
      expect(find.text('12:00'), findsNothing);

      // First Tap: toggles to total duration (12:00)
      await tester.tap(find.byKey(const Key('timeline_duration_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('- 8:45'), findsNothing);

      // Second Tap: toggles back to remaining duration (- 8:45)
      await tester.tap(find.byKey(const Key('timeline_duration_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('- 8:45'), findsOneWidget);
      expect(find.text('12:00'), findsNothing);
    });
  });
}
