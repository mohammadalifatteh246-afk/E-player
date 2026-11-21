import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/sleep_timer_models.dart';

/// Abstraction for OS-level power management and process execution (mockable for unit tests).
abstract class PlatformPowerExecutor {
  Future<void> executeSleep();
  Future<void> executeShutdown();
  Future<void> executeHibernate();
  Future<void> executeAppExit();
}

/// Default production implementation using Platform processes (Windows/macOS/Linux).
class DefaultPlatformPowerExecutor implements PlatformPowerExecutor {
  @override
  Future<void> executeSleep() async {
    try {
      if (Platform.isWindows) {
        await Process.run('rundll32.exe', ['powrprof.dll,SetSuspendState', '0,1,0']);
      } else if (Platform.isMacOS) {
        await Process.run('pmset', ['sleepnow']);
      } else if (Platform.isLinux) {
        await Process.run('systemctl', ['suspend']);
      }
    } catch (e) {
      debugPrint('[PlatformPowerExecutor] Sleep error: $e');
    }
  }

  @override
  Future<void> executeShutdown() async {
    try {
      if (Platform.isWindows) {
        await Process.run('shutdown', ['/s', '/t', '30', '/c', 'E-Player Sleep Timer initiated shutdown.']);
      } else if (Platform.isMacOS) {
        await Process.run('osascript', ['-e', 'tell app "System Events" to shut down']);
      } else if (Platform.isLinux) {
        await Process.run('systemctl', ['poweroff']);
      }
    } catch (e) {
      debugPrint('[PlatformPowerExecutor] Shutdown error: $e');
    }
  }

  @override
  Future<void> executeHibernate() async {
    try {
      if (Platform.isWindows) {
        await Process.run('shutdown', ['/h']);
      } else if (Platform.isLinux) {
        await Process.run('systemctl', ['hibernate']);
      }
    } catch (e) {
      debugPrint('[PlatformPowerExecutor] Hibernate error: $e');
    }
  }

  @override
  Future<void> executeAppExit() async {
    exit(0);
  }
}

/// Manages sleep countdowns, volume fade-outs, and triggers shutdown/pause upon completion (VLC parity).
class SleepTimerController extends ChangeNotifier {
  final PlatformPowerExecutor powerExecutor;
  final VoidCallback? onPausePlayback;
  final ValueChanged<double>? onVolumeAttenuationChanged;
  final VoidCallback? onActionTriggered;

  Timer? _timer;
  SleepTimerState _state = const SleepTimerState.idle();

  SleepTimerController({
    PlatformPowerExecutor? powerExecutor,
    this.onPausePlayback,
    this.onVolumeAttenuationChanged,
    this.onActionTriggered,
  }) : powerExecutor = powerExecutor ?? DefaultPlatformPowerExecutor();

  SleepTimerState get state => _state;
  bool get isActive => _state.isActive;

  /// Starts a countdown timer for the specified [duration].
  void startTimer({
    required Duration duration,
    SleepTimerAction action = SleepTimerAction.pausePlayback,
    bool smoothFadeOut = true,
  }) {
    _timer?.cancel();

    _state = SleepTimerState(
      isActive: true,
      totalDuration: duration,
      remaining: duration,
      action: action,
      atEndOfTrack: false,
      smoothFadeOut: smoothFadeOut,
      currentVolumeAttenuation: 1.0,
    );
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  /// Sets sleep timer to trigger immediately when the current playing media track ends.
  void startEndOfTrackTimer({
    SleepTimerAction action = SleepTimerAction.pausePlayback,
    bool smoothFadeOut = true,
  }) {
    _timer?.cancel();

    _state = SleepTimerState(
      isActive: true,
      totalDuration: Duration.zero,
      remaining: Duration.zero,
      action: action,
      atEndOfTrack: true,
      smoothFadeOut: smoothFadeOut,
      currentVolumeAttenuation: 1.0,
    );
    notifyListeners();
  }

  /// Extends active timer duration by [extra] (e.g. +5 min or +10 min).
  void extendTimer(Duration extra) {
    if (!_state.isActive) return;

    final newRemaining = _state.remaining + extra;
    final newTotal = _state.totalDuration + extra;

    _state = _state.copyWith(
      remaining: newRemaining,
      totalDuration: newTotal,
      currentVolumeAttenuation: 1.0,
    );
    onVolumeAttenuationChanged?.call(1.0);
    notifyListeners();
  }

  /// Cancels active sleep timer and restores volume attenuation.
  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _state = const SleepTimerState.idle();
    onVolumeAttenuationChanged?.call(1.0);
    notifyListeners();
  }

  /// Called when active media finishes playback.
  void handleTrackFinished() {
    if (_state.isActive && _state.atEndOfTrack) {
      _triggerAction();
    }
  }

  void _onTick(Timer timer) {
    if (!_state.isActive) {
      timer.cancel();
      return;
    }

    final newRemainingSeconds = _state.remaining.inSeconds - 1;

    if (newRemainingSeconds <= 0) {
      timer.cancel();
      _triggerAction();
      return;
    }

    final remaining = Duration(seconds: newRemainingSeconds);
    double attenuation = 1.0;

    // Smooth audio fade-out during last 30 seconds
    if (_state.smoothFadeOut && newRemainingSeconds <= 30) {
      attenuation = (newRemainingSeconds / 30.0).clamp(0.0, 1.0);
      onVolumeAttenuationChanged?.call(attenuation);
    }

    _state = _state.copyWith(
      remaining: remaining,
      currentVolumeAttenuation: attenuation,
    );
    notifyListeners();
  }

  Future<void> _triggerAction() async {
    final action = _state.action;
    _timer?.cancel();
    _timer = null;

    _state = const SleepTimerState.idle();
    notifyListeners();
    onActionTriggered?.call();

    // 1. Pause playback
    onPausePlayback?.call();

    // 2. Perform target power/app action
    switch (action) {
      case SleepTimerAction.pausePlayback:
        // Already paused
        break;
      case SleepTimerAction.stopAndExit:
        await powerExecutor.executeAppExit();
        break;
      case SleepTimerAction.systemSleep:
        await powerExecutor.executeSleep();
        break;
      case SleepTimerAction.systemShutdown:
        await powerExecutor.executeShutdown();
        break;
      case SleepTimerAction.systemHibernate:
        await powerExecutor.executeHibernate();
        break;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
