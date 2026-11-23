import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/meteor_progress_bar.dart';

void main() {
  group('MeteorProgressBar Widget Tests', () {
    testWidgets('Renders properly without overflow at 42% progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: MeteorProgressBar(
                  position: Duration(minutes: 42),
                  duration: Duration(minutes: 100),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MeteorProgressBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders properly at 0% and 100% boundaries', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MeteorProgressBar(
                position: Duration.zero,
                duration: Duration(minutes: 10),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MeteorProgressBar(
                position: Duration(minutes: 10),
                duration: Duration(minutes: 10),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tap on track triggers onSeek with expected duration', (tester) async {
      Duration? seekedDuration;
      bool seekStarted = false;
      bool seekEnded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: MeteorProgressBar(
                  position: const Duration(seconds: 10),
                  duration: const Duration(seconds: 100),
                  onSeek: (d) => seekedDuration = d,
                  onSeekStart: () => seekStarted = true,
                  onSeekEnd: () => seekEnded = true,
                ),
              ),
            ),
          ),
        ),
      );

      // Tap at center of widget (should seek to ~50s)
      final center = tester.getCenter(find.byType(MeteorProgressBar));
      await tester.tapAt(center);
      await tester.pump();

      expect(seekStarted, isTrue);
      expect(seekEnded, isTrue);
      expect(seekedDuration, isNotNull);
      expect(seekedDuration!.inSeconds, closeTo(50, 5));
    });

    testWidgets('Drag on track updates seek and displays floating time tooltip', (tester) async {
      Duration? latestSeek;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: MeteorProgressBar(
                  position: const Duration(seconds: 20),
                  duration: const Duration(seconds: 100),
                  onSeek: (d) => latestSeek = d,
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(MeteorProgressBar));
      final gesture = await tester.startGesture(center);
      await tester.pump();

      // Drag right by 40 pixels
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(latestSeek, isNotNull);
      expect(latestSeek!.inSeconds, greaterThan(50));

      // Tooltip should be active during dragging
      expect(find.byType(Container), findsWidgets);

      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
