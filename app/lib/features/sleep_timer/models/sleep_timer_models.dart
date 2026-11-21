/// Action to perform when sleep timer countdown reaches zero (VLC parity).
enum SleepTimerAction {
  pausePlayback('Pause Playback', 'Pauses video/audio smoothly'),
  stopAndExit('Quit E-Player', 'Stops playback and exits the application'),
  systemSleep('Sleep PC', 'Puts the computer into sleep/suspend mode'),
  systemShutdown('Shut Down PC', 'Gracefully shuts down the computer'),
  systemHibernate('Hibernate PC', 'Puts the computer into hibernation mode');

  final String label;
  final String description;

  const SleepTimerAction(this.label, this.description);
}

/// State representation of the active sleep timer.
class SleepTimerState {
  final bool isActive;
  final Duration totalDuration;
  final Duration remaining;
  final SleepTimerAction action;
  final bool atEndOfTrack;
  final bool smoothFadeOut;
  final double currentVolumeAttenuation; // 1.0 (normal) down to 0.0 during last 30s

  const SleepTimerState({
    this.isActive = false,
    this.totalDuration = Duration.zero,
    this.remaining = Duration.zero,
    this.action = SleepTimerAction.pausePlayback,
    this.atEndOfTrack = false,
    this.smoothFadeOut = true,
    this.currentVolumeAttenuation = 1.0,
  });

  const SleepTimerState.idle()
      : isActive = false,
        totalDuration = Duration.zero,
        remaining = Duration.zero,
        action = SleepTimerAction.pausePlayback,
        atEndOfTrack = false,
        smoothFadeOut = true,
        currentVolumeAttenuation = 1.0;

  double get progress {
    if (totalDuration.inSeconds <= 0) return 0.0;
    final elapsed = totalDuration.inSeconds - remaining.inSeconds;
    return (elapsed / totalDuration.inSeconds).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    if (!isActive) return 'Off';
    if (atEndOfTrack) return 'End of Track';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  SleepTimerState copyWith({
    bool? isActive,
    Duration? totalDuration,
    Duration? remaining,
    SleepTimerAction? action,
    bool? atEndOfTrack,
    bool? smoothFadeOut,
    double? currentVolumeAttenuation,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      totalDuration: totalDuration ?? this.totalDuration,
      remaining: remaining ?? this.remaining,
      action: action ?? this.action,
      atEndOfTrack: atEndOfTrack ?? this.atEndOfTrack,
      smoothFadeOut: smoothFadeOut ?? this.smoothFadeOut,
      currentVolumeAttenuation: currentVolumeAttenuation ?? this.currentVolumeAttenuation,
    );
  }
}
