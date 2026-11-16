import 'dart:async';
import 'package:flutter/foundation.dart';

/// Commands issued from the desktop system tray or background audio daemon.
enum TrayPlaybackCommand {
  playPause,
  next,
  previous,
  volumeUp,
  volumeDown,
  toggleWindow,
  stop,
}

/// Immutable snapshot representing current background audio and tray daemon state.
class TrayState {
  final bool isPlaying;
  final String mediaTitle;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMinimizedToTray;

  const TrayState({
    this.isPlaying = false,
    this.mediaTitle = '',
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100.0,
    this.isMinimizedToTray = false,
  });

  String get formattedStatus {
    final stateStr = isPlaying ? 'Playing' : 'Paused';
    if (mediaTitle.isEmpty) {
      return stateStr;
    }
    return '$stateStr: $mediaTitle';
  }

  TrayState copyWith({
    bool? isPlaying,
    String? mediaTitle,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMinimizedToTray,
  }) {
    return TrayState(
      isPlaying: isPlaying ?? this.isPlaying,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMinimizedToTray: isMinimizedToTray ?? this.isMinimizedToTray,
    );
  }
}

/// Service managing background audio playback and desktop system tray interaction.
/// VLC Parity: replicates VLC's systray integration, background audio daemon,
/// and mini playback controls.
class DesktopTrayAudioService extends ChangeNotifier {
  static DesktopTrayAudioService? _instance;
  static DesktopTrayAudioService get instance => _instance ??= DesktopTrayAudioService();

  TrayState _currentState = const TrayState();
  bool _minimizeToTrayEnabled = false;

  final StreamController<TrayPlaybackCommand> _commandController =
      StreamController<TrayPlaybackCommand>.broadcast();

  TrayState get currentState => _currentState;
  bool get minimizeToTrayEnabled => _minimizeToTrayEnabled;
  Stream<TrayPlaybackCommand> get commandStream => _commandController.stream;

  /// Updates active playback metrics and notifies tray daemon listeners.
  void updatePlaybackState({
    bool? isPlaying,
    String? mediaTitle,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMinimizedToTray,
  }) {
    _currentState = _currentState.copyWith(
      isPlaying: isPlaying,
      mediaTitle: mediaTitle,
      position: position,
      duration: duration,
      volume: volume,
      isMinimizedToTray: isMinimizedToTray,
    );
    notifyListeners();
  }

  /// Dispatches a command received from system tray click or hotkey.
  void dispatchCommand(TrayPlaybackCommand command) {
    if (!_commandController.isClosed) {
      _commandController.add(command);
    }
  }

  /// Sets whether the window should hide into system tray upon minimize.
  void setMinimizeToTray(bool enabled) {
    _minimizeToTrayEnabled = enabled;
    notifyListeners();
  }

  /// Sets whether the app is currently hidden/minimized to tray.
  void setMinimizedToTray(bool isMinimized) {
    _currentState = _currentState.copyWith(isMinimizedToTray: isMinimized);
    notifyListeners();
  }

  @override
  void dispose() {
    _commandController.close();
    super.dispose();
  }
}
