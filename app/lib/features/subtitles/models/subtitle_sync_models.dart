import 'package:flutter/foundation.dart';

/// Represents a single AV synchronization anchor point.
///
/// In 2-point subtitle synchronization (VLC subsync paradigm):
/// - [audioTime] is the exact media playback timestamp where the spoken dialogue is heard.
/// - [subtitleTime] is the timestamp embedded in the subtitle stream/file when that subtitle was rendered.
@immutable
class SubtitleSyncPoint {
  final Duration audioTime;
  final Duration subtitleTime;
  final String? label;

  const SubtitleSyncPoint({
    required this.audioTime,
    required this.subtitleTime,
    this.label,
  });

  /// Offset between audio and subtitle for this individual point.
  /// Positive value indicates subtitle appears earlier than audio (needs positive delay).
  Duration get rawOffset => audioTime - subtitleTime;

  SubtitleSyncPoint copyWith({
    Duration? audioTime,
    Duration? subtitleTime,
    String? label,
  }) {
    return SubtitleSyncPoint(
      audioTime: audioTime ?? this.audioTime,
      subtitleTime: subtitleTime ?? this.subtitleTime,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleSyncPoint &&
          runtimeType == other.runtimeType &&
          audioTime == other.audioTime &&
          subtitleTime == other.subtitleTime &&
          label == other.label;

  @override
  int get hashCode => Object.hash(audioTime, subtitleTime, label);

  @override
  String toString() =>
      'SubtitleSyncPoint(audio: $audioTime, sub: $subtitleTime, label: $label)';
}

/// The computed linear synchronization parameters resulting from 1-point or 2-point alignment.
@immutable
class SubtitleSyncResult {
  /// The constant time delay (in seconds) to apply via libmpv `sub-delay`.
  final double delaySeconds;

  /// The subtitle speed multiplier to apply via libmpv `sub-speed`.
  /// Default 1.0 (no stretch). PAL to Film is ~1.0427, Film to PAL is ~0.9590.
  final double speedFactor;

  /// Whether a 2-point drift calculation was successfully performed.
  final bool hasDriftCorrection;

  /// Human-readable explanation of the sync adjustment.
  final String summary;

  const SubtitleSyncResult({
    required this.delaySeconds,
    required this.speedFactor,
    required this.hasDriftCorrection,
    required this.summary,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleSyncResult &&
          runtimeType == other.runtimeType &&
          (delaySeconds - other.delaySeconds).abs() < 1e-6 &&
          (speedFactor - other.speedFactor).abs() < 1e-6 &&
          hasDriftCorrection == other.hasDriftCorrection;

  @override
  int get hashCode => Object.hash(delaySeconds, speedFactor, hasDriftCorrection);

  @override
  String toString() =>
      'SubtitleSyncResult(delay: ${delaySeconds.toStringAsFixed(3)}s, speed: ${speedFactor.toStringAsFixed(4)}x, drift: $hasDriftCorrection)';
}
