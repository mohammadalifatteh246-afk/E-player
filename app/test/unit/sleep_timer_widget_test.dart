import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/sleep_timer/models/sleep_timer_models.dart';
import 'package:app/features/sleep_timer/data/sleep_timer_controller.dart';
import 'package:app/features/sleep_timer/ui/sleep_timer_sheet.dart';

class MockPlatformPowerExecutor implements PlatformPowerExecutor {
  @override
  Future<void> executeSleep() async {}
  @override
  Future<void> executeShutdown() async {}
  @override
  Future<void> executeHibernate() async {}
  @override
  Future<void> executeAppExit() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sleep Timer Sheet UI Tests (VLC Parity)', () {
    late SleepTimerController controller;
    late MockPlatformPowerExecutor mockPower;

    setUp(() {
      mockPower = MockPlatformPowerExecutor();
      controller = SleepTimerController(powerExecutor: mockPower);
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('1. Renders sheet with presets, actions, and start button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SleepTimerSheet(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sleep Timer & Power Manager'), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_15')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_30')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_preset_end_of_track')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_start_button')), findsOneWidget);
      expect(find.byKey(const Key('sleep_timer_fade_switch')), findsOneWidget);
    });

    testWidgets('2. Selects 45 min preset and starts sleep timer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SleepTimerSheet(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 45 min chip
      final chip45 = find.byKey(const Key('sleep_timer_preset_45'));
      await tester.ensureVisible(chip45);
      await tester.tap(chip45);
      await tester.pumpAndSettle();

      // Tap start button
      final startBtn = find.byKey(const Key('sleep_timer_start_button'));
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pump();

      expect(controller.isActive, isTrue);
      expect(controller.state.totalDuration.inMinutes, equals(45));
      expect(controller.state.atEndOfTrack, isFalse);

      controller.cancelTimer();
    });

    testWidgets('3. Displays active countdown card, extends by 10m, and cancels timer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      controller.startTimer(
        duration: const Duration(minutes: 20),
        action: SleepTimerAction.systemSleep,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SleepTimerSheet(controller: controller),
          ),
        ),
      );
      await tester.pump();

      // Verify active banner text
      expect(find.byKey(const Key('sleep_timer_active_countdown_text')), findsOneWidget);
      expect(find.textContaining('Active:'), findsOneWidget);
      expect(find.text('Sleep PC'), findsNWidgets(2));

      // Extend +10 min
      final extendBtn = find.byKey(const Key('sleep_timer_extend_10m_btn'));
      await tester.ensureVisible(extendBtn);
      await tester.tap(extendBtn);
      await tester.pump();
      expect(controller.state.totalDuration.inMinutes, equals(30));

      // Cancel timer
      final cancelBtn = find.byKey(const Key('sleep_timer_cancel_btn'));
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pump();
      expect(controller.isActive, isFalse);
      expect(find.byKey(const Key('sleep_timer_active_countdown_text')), findsNothing);
    });

    testWidgets('4. Selects End of Track and sets timer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SleepTimerSheet(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap End of Track chip
      final endChip = find.byKey(const Key('sleep_timer_preset_end_of_track'));
      await tester.ensureVisible(endChip);
      await tester.tap(endChip);
      await tester.pumpAndSettle();

      // Start timer
      final startBtn = find.byKey(const Key('sleep_timer_start_button'));
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pump();

      expect(controller.isActive, isTrue);
      expect(controller.state.atEndOfTrack, isTrue);

      controller.cancelTimer();
    });
  });
}
