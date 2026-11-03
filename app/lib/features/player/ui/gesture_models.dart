import 'package:flutter/foundation.dart';

/// Supported discrete gesture modes in the Cinematic Gesture Engine state machine.
enum GestureMode {
  /// No touch or pointer interaction active.
  idle,

  /// Touch down detected; evaluating directional dead zone (>=12px) and 1.5x axis dominance.
  arbitrating,

  /// Horizontal precision scrub in the center zone (0.35 <= X <= 0.65).
  horizontalScrub,

  /// Vertical brightness adjustment in the left zone (0.0 <= X <= 0.35).
  brightnessAdjust,

  /// Vertical volume adjustment in the right zone (0.65 <= X <= 1.0).
  volumeAdjust,

  /// Two-finger pinch-to-zoom and focal-point panning.
  pinchZoom,
}

/// Category of interactive feedback to display on the HUD overlay.
enum GestureFeedbackType {
  scrub,
  brightness,
  volume,
  zoom,
  wingJump,
}

/// Event emitted during gesture interaction to update HUD visual indicators.
@immutable
class GestureFeedbackEvent {
  /// The functional classification of the gesture.
  final GestureFeedbackType type;

  /// Normalized or scaled value:
  /// - Brightness: 0.0 to 1.0
  /// - Volume: 0.0 to 100.0
  /// - Zoom: 1.0 to 4.0
  /// - Scrub: scrub progress fraction or position milliseconds
  /// - Wing Jump: delta in seconds (+10 or -10)
  final double value;

  /// User-facing label (e.g., "75%", "1.50x", "+10s", "01:24:30").
  final String label;

  /// Target playback position when scrubbing or jumping.
  final Duration? seekTarget;

  /// Formatted delta string (e.g. "+00:15", "-00:10", "+10s").
  final String deltaFormatted;

  const GestureFeedbackEvent({
    required this.type,
    required this.value,
    required this.label,
    this.seekTarget,
    this.deltaFormatted = '',
  });

  /// Alias for seekTarget to satisfy contract definitions in PROJECT.md.
  Duration? get position => seekTarget;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GestureFeedbackEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value &&
          label == other.label &&
          seekTarget == other.seekTarget &&
          deltaFormatted == other.deltaFormatted;

  @override
  int get hashCode =>
      type.hashCode ^
      value.hashCode ^
      label.hashCode ^
      seekTarget.hashCode ^
      deltaFormatted.hashCode;

  @override
  String toString() =>
      'GestureFeedbackEvent(type: $type, value: $value, label: $label, seekTarget: $seekTarget, deltaFormatted: $deltaFormatted)';
}

/// Event dispatched when a seeking gesture is released and must be committed to the media player.
@immutable
class SeekCommitEvent {
  /// Target seek position on the playback timeline.
  final Duration target;

  /// Total duration of the media when committed.
  final Duration previewDuration;

  const SeekCommitEvent({
    required this.target,
    required this.previewDuration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeekCommitEvent &&
          runtimeType == other.runtimeType &&
          target == other.target &&
          previewDuration == other.previewDuration;

  @override
  int get hashCode => target.hashCode ^ previewDuration.hashCode;

  @override
  String toString() =>
      'SeekCommitEvent(target: $target, previewDuration: $previewDuration)';
}

/// Configuration constants for cinematic gesture arbitration and boundary limits.
class CinematicGestureConfig {
  /// Minimum travel distance (in physical/logical pixels) before committing to a swipe direction.
  static const double deadZoneThreshold = 12.0;

  /// Minimum ratio between primary and secondary axes (|primary| >= 1.5 * |secondary|).
  static const double axisDominanceRatio = 1.5;

  /// Left vertical zone boundary (0.0 to 0.35 * width).
  static const double leftZoneRatio = 0.35;

  /// Right vertical zone boundary (0.65 * width to 1.0 * width).
  static const double rightZoneRatio = 0.65;

  /// Left wing double-tap boundary (X < 0.33 * width).
  static const double leftWingRatio = 0.33;

  /// Right wing double-tap boundary (X > 0.66 * width).
  static const double rightWingRatio = 0.66;

  /// Minimum zoom scale factor.
  static const double minZoomScale = 1.0;

  /// Maximum zoom scale factor.
  static const double maxZoomScale = 4.0;

  /// Duration to seek on wing double-tap.
  static const Duration wingJumpDuration = Duration(seconds: 10);

  /// Auto-dismiss timer delay for HUD controls after gesture ends.
  static const Duration hudResetTimeout = Duration(milliseconds: 2800);

  /// Lingering visual feedback delay before fading out.
  static const Duration feedbackLingeringDuration = Duration(milliseconds: 800);
}
