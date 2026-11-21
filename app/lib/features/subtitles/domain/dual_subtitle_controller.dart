import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Position preset for secondary subtitle placement
enum SecondarySubtitlePosition {
  top('Top (10%)', 10.0),
  upperThird('Upper Third (25%)', 25.0),
  center('Center (50%)', 50.0),
  lowerThird('Lower Third (75%)', 75.0);

  final String label;
  final double posValue;
  const SecondarySubtitlePosition(this.label, this.posValue);
}

/// Interface for dispatching mpv subtitle properties.
/// Decouples controller logic from native libmpv FFI for unit testing.
abstract class MpvSubtitlePropertyDispatcher {
  Future<void> setProperty(String name, String value);
  Future<void> setPrimaryTrack(SubtitleTrack track);
}

/// Default implementation binding directly to Player.platform.
class PlayerMpvPropertyDispatcher implements MpvSubtitlePropertyDispatcher {
  final Player player;
  PlayerMpvPropertyDispatcher(this.player);

  @override
  Future<void> setProperty(String name, String value) async {
    try {
      final platform = player.platform as dynamic;
      platform.setProperty(name, value);
    } catch (e) {
      debugPrint('[PlayerMpvPropertyDispatcher] Error setting $name to $value: $e');
    }
  }

  @override
  Future<void> setPrimaryTrack(SubtitleTrack track) async {
    try {
      await player.setSubtitleTrack(track);
    } catch (e) {
      debugPrint('[PlayerMpvPropertyDispatcher] Error setting primary track: $e');
    }
  }
}

/// Controller managing simultaneous Dual Subtitles (Primary at bottom, Secondary at top).
/// Parity with VLC's secondary subtitle and libmpv's `secondary-sid` architecture.
class DualSubtitleController extends ChangeNotifier {
  MpvSubtitlePropertyDispatcher? _dispatcher;

  bool _isEnabled = false;
  SubtitleTrack _primaryTrack = SubtitleTrack.no();
  SubtitleTrack _secondaryTrack = SubtitleTrack.no();
  double _secondaryDelay = 0.0;
  double _secondaryPosition = 10.0; // default near top
  bool _isSecondaryVisible = true;

  bool get isEnabled => _isEnabled;
  SubtitleTrack get primaryTrack => _primaryTrack;
  SubtitleTrack get secondaryTrack => _secondaryTrack;
  double get secondaryDelay => _secondaryDelay;
  double get secondaryPosition => _secondaryPosition;
  bool get isSecondaryVisible => _isSecondaryVisible;

  /// True when dual subtitles are active with a non-null secondary track selected
  bool get isDualActive =>
      _isEnabled && _secondaryTrack.id != 'no' && _secondaryTrack.id.isNotEmpty;

  DualSubtitleController({MpvSubtitlePropertyDispatcher? dispatcher}) {
    if (dispatcher != null) {
      _dispatcher = dispatcher;
    }
  }

  /// Attach active Player instance
  void attachPlayer(Player player) {
    _dispatcher = PlayerMpvPropertyDispatcher(player);
    _syncPropertiesToMpv();
  }

  /// Attach mock or custom property dispatcher
  void setDispatcher(MpvSubtitlePropertyDispatcher dispatcher) {
    _dispatcher = dispatcher;
    _syncPropertiesToMpv();
  }

  /// Toggle dual subtitle mode on or off
  void toggleDualSubtitles(bool enabled) {
    _isEnabled = enabled;
    _syncPropertiesToMpv();
    notifyListeners();
  }

  /// Select primary subtitle track (rendered at bottom)
  void setPrimaryTrack(SubtitleTrack track) {
    _primaryTrack = track;
    _dispatcher?.setPrimaryTrack(track);
    notifyListeners();
  }

  /// Select secondary subtitle track (rendered at top)
  void setSecondaryTrack(SubtitleTrack track) {
    _secondaryTrack = track;
    if (!_isEnabled && track.id != 'no' && track.id.isNotEmpty) {
      _isEnabled = true;
    }
    _syncPropertiesToMpv();
    notifyListeners();
  }

  /// 1-tap quick swap between Primary and Secondary subtitles
  void swapTracks() {
    final temp = _primaryTrack;
    _primaryTrack = _secondaryTrack;
    _secondaryTrack = temp;

    _dispatcher?.setPrimaryTrack(_primaryTrack);
    _syncPropertiesToMpv();
    notifyListeners();
  }

  /// Set secondary subtitle sync delay offset in seconds (-30.0s to +30.0s)
  void setSecondaryDelay(double delay) {
    _secondaryDelay = delay.clamp(-30.0, 30.0);
    _dispatcher?.setProperty(
      'secondary-sub-delay',
      _secondaryDelay.toStringAsFixed(2),
    );
    notifyListeners();
  }

  /// Nudge secondary subtitle delay by delta (e.g. +0.1s, -0.5s)
  void nudgeSecondaryDelay(double delta) {
    setSecondaryDelay(_secondaryDelay + delta);
  }

  /// Set secondary subtitle vertical position (0 = top, 100 = bottom)
  void setSecondaryPosition(double position) {
    _secondaryPosition = position.clamp(0.0, 100.0);
    _dispatcher?.setProperty(
      'secondary-sub-pos',
      _secondaryPosition.round().toString(),
    );
    notifyListeners();
  }

  /// Toggle secondary subtitle visibility
  void toggleSecondaryVisibility() {
    _isSecondaryVisible = !_isSecondaryVisible;
    _dispatcher?.setProperty(
      'secondary-sub-visibility',
      _isSecondaryVisible ? 'yes' : 'no',
    );
    notifyListeners();
  }

  /// Reset dual subtitle settings
  void reset() {
    _isEnabled = false;
    _secondaryTrack = SubtitleTrack.no();
    _secondaryDelay = 0.0;
    _secondaryPosition = 10.0;
    _isSecondaryVisible = true;
    _syncPropertiesToMpv();
    notifyListeners();
  }

  void _syncPropertiesToMpv() {
    if (_dispatcher == null) return;

    if (_isEnabled && _secondaryTrack.id != 'no' && _secondaryTrack.id.isNotEmpty) {
      _dispatcher!.setProperty('secondary-sid', _secondaryTrack.id);
      _dispatcher!.setProperty(
        'secondary-sub-visibility',
        _isSecondaryVisible ? 'yes' : 'no',
      );
      _dispatcher!.setProperty(
        'secondary-sub-pos',
        _secondaryPosition.round().toString(),
      );
      _dispatcher!.setProperty(
        'secondary-sub-delay',
        _secondaryDelay.toStringAsFixed(2),
      );
      // Ensure primary stays positioned at bottom (default 92)
      _dispatcher!.setProperty('sub-pos', '92');
    } else {
      _dispatcher!.setProperty('secondary-sid', 'no');
    }
  }
}
