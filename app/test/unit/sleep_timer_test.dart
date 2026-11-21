import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/sleep_timer/models/sleep_timer_models.dart';
import 'package:app/features/sleep_timer/data/sleep_timer_controller.dart';

class MockPlatformPowerExecutor implements PlatformPowerExecutor {
  bool sleepExecuted = false;
  bool shutdownExecuted = false;
  bool hibernateExecuted = false;
  bool exitExecuted = false;

  @override
  Future<void> executeSleep() async {
    sleepExecuted = true;
  }

  @override
  Future<void> executeShutdown() async {
    shutdownExecuted = true;
  }

  @override
  Future<void> executeHibernate() async {
    hibernateExecuted = true;
  }

  @override
  Future<void> executeAppExit() async {
    exitExecuted = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sleep Timer & System Power Management Tests (VLC Parity)', () {
    late MockPlatformPowerExecutor mockPower;
    late SleepTimerController controller;
    bool pauseCalled = false;
    double? lastAttenuation;

    setUp(() {
      mockPower = MockPlatformPowerExecutor();
      pauseCalled = false;
      lastAttenuation = null;
      controller = SleepTimerController(
        powerExecutor: mockPower,
        onPausePlayback: () => pauseCalled = true,
        onVolumeAttenuationChanged: (v) => lastAttenuation = v,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('1. SleepTimerState formattedRemaining formats minutes and hours cleanly', () {
      const state1 = SleepTimerState(
        isActive: true,
        remaining: Duration(minutes: 45, seconds: 30),
      );
      expect(state1.formattedRemaining, equals('45:30'));

      const state2 = SleepTimerState(
        isActive: true,
        remaining: Duration(hours: 1, minutes: 15, seconds: 5),
      );
      expect(state2.formattedRemaining, equals('1:15:05'));

      const state3 = SleepTimerState(
        isActive: true,
        atEndOfTrack: true,
      );
      expect(state3.formattedRemaining, equals('End of Track'));

      const state4 = SleepTimerState.idle();
      expect(state4.formattedRemaining, equals('Off'));
    });

    test('2. startTimer initializes countdown and extendTimer adds duration', () {
      controller.startTimer(
        duration: const Duration(minutes: 30),
        action: SleepTimerAction.systemSleep,
      );

      expect(controller.isActive, isTrue);
      expect(controller.state.remaining, equals(const Duration(minutes: 30)));
      expect(controller.state.action, equals(SleepTimerAction.systemSleep));

      // Extend by 10 minutes
      controller.extendTimer(const Duration(minutes: 10));
      expect(controller.state.remaining, equals(const Duration(minutes: 40)));
      expect(controller.state.totalDuration, equals(const Duration(minutes: 40)));

      // Cancel timer
      controller.cancelTimer();
      expect(controller.isActive, isFalse);
      expect(lastAttenuation, equals(1.0));
    });

    test('3. End-of-track timer triggers action when track finishes', () async {
      controller.startEndOfTrackTimer(
        action: SleepTimerAction.systemShutdown,
      );

      expect(controller.isActive, isTrue);
      expect(controller.state.atEndOfTrack, isTrue);
      expect(mockPower.shutdownExecuted, isFalse);
      expect(pauseCalled, isFalse);

      controller.handleTrackFinished();

      // Should have paused and executed shutdown
      expect(pauseCalled, isTrue);
      expect(mockPower.shutdownExecuted, isTrue);
      expect(controller.isActive, isFalse);
    });

    test('4. Smooth volume fade-out calculates correct attenuation in last 30s', () {
      controller.startTimer(
        duration: const Duration(seconds: 35),
        smoothFadeOut: true,
      );

      // Remaining at start: 35s (> 30s) -> full volume 1.0
      expect(controller.state.currentVolumeAttenuation, equals(1.0));

      // Simulate ticking down to 15 seconds remaining
      final stateAt15 = controller.state.copyWith(
        remaining: const Duration(seconds: 15),
        currentVolumeAttenuation: 15 / 30.0,
      );
      expect(stateAt15.currentVolumeAttenuation, closeTo(0.5, 0.01));
    });

    test('5. SleepTimerAction triggers respective platform power functions', () async {
      // Test System Sleep action
      controller.startEndOfTrackTimer(action: SleepTimerAction.systemSleep);
      controller.handleTrackFinished();
      expect(mockPower.sleepExecuted, isTrue);

      // Test Quit E-Player action
      controller.startEndOfTrackTimer(action: SleepTimerAction.stopAndExit);
      controller.handleTrackFinished();
      expect(mockPower.exitExecuted, isTrue);

      // Test Hibernate PC action
      controller.startEndOfTrackTimer(action: SleepTimerAction.systemHibernate);
      controller.handleTrackFinished();
      expect(mockPower.hibernateExecuted, isTrue);
    });
  });
}
