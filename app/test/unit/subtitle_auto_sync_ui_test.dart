import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/subtitles/ui/subtitle_auto_sync_sheet.dart';

void main() {
  group('SubtitleAutoSyncSheet Widget Tests', () {
    testWidgets('renders all essential elements, header, points and buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitleAutoSyncSheet(
              currentDelay: 0.0,
              currentSpeed: 1.0,
              onApply: (delay, speed) {},
            ),
          ),
        ),
      );

      // Verify title & info
      expect(find.text('2-Point Subtitle Auto-Sync'), findsOneWidget);
      expect(find.text('Point 1: Reference Anchor'), findsOneWidget);
      expect(find.text('Point 2: Drift Correction (Later Scene)'), findsOneWidget);
      expect(find.text('Calculated Sync Output'), findsOneWidget);
      expect(find.text('Apply Sync to Subtitles'), findsOneWidget);
    });

    testWidgets('toggling point 2 switch updates output between 1-point and 2-point', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitleAutoSyncSheet(
              currentDelay: 1.5,
              currentSpeed: 1.0,
              onApply: (delay, speed) {},
            ),
          ),
        ),
      );

      // Point 2 is enabled by default
      expect(find.text('2-Point Drift Aligned'), findsOneWidget);

      // Toggle Point 2 switch to disable it
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Should now show 1-Point Constant Offset
      expect(find.text('1-Point Constant Offset'), findsOneWidget);
    });

    testWidgets('nudging time values updates calculated delay and invokes onApply with correct values', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      double? appliedDelay;
      double? appliedSpeed;
      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitleAutoSyncSheet(
              currentDelay: 0.0,
              currentSpeed: 1.0,
              onApply: (delay, speed) {
                appliedDelay = delay;
                appliedSpeed = speed;
              },
              onReset: () {
                resetCalled = true;
              },
            ),
          ),
        ),
      );

      // Disable point 2 for simple 1-point test
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Nudge Point 1 Audio by +1s (first '+1s' button)
      final plusOneButtons = find.text('+1s');
      expect(plusOneButtons, findsWidgets);
      await tester.tap(plusOneButtons.first);
      await tester.pumpAndSettle();

      // Now audio is 1s, sub is 0s -> delay should be +1.000s
      expect(find.text('+1.000s'), findsOneWidget);

      // Tap Apply Sync button
      await tester.tap(find.text('Apply Sync to Subtitles'));
      await tester.pumpAndSettle();

      expect(appliedDelay, closeTo(1.0, 0.01));
      expect(appliedSpeed, closeTo(1.0, 0.01));
      expect(resetCalled, isFalse);
    });

    testWidgets('tapping reset button invokes onReset callback', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitleAutoSyncSheet(
              currentDelay: 2.0,
              currentSpeed: 1.05,
              onApply: (delay, speed) {},
              onReset: () {
                resetCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Reset'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
    });
  });
}
