import 'dart:math' as math;
import '../models/subtitle_sync_models.dart';

/// Clean-room mathematical engine for 2-Point Subtitle Synchronization (VLC subsync paradigm).
///
/// Converts speech-to-subtitle discrepancy into a linear transformation:
/// T_audio = (SpeedFactor * T_subtitle) + DelayOffset
class SubtitleSyncCalculator {
  /// Safety constraints to prevent runaway sync values
  static const double minSpeedFactor = 0.5;
  static const double maxSpeedFactor = 2.0;
  static const double minDelaySeconds = -300.0; // -5 minutes
  static const double maxDelaySeconds = 300.0;  // +5 minutes

  /// Computes the subtitle sync result using 1 or 2 reference points.
  ///
  /// - If only [point1] is supplied: Performs single-point instant linear offset with speed = 1.0.
  /// - If both [point1] and [point2] are supplied: Solves the 2-point linear equation to compute
  ///   both subtitle speed drift (PAL/NTSC/FPS correction) and delay offset.
  static SubtitleSyncResult calculate({
    required SubtitleSyncPoint point1,
    SubtitleSyncPoint? point2,
  }) {
    final a1 = point1.audioTime.inMicroseconds / 1e6;
    final s1 = point1.subtitleTime.inMicroseconds / 1e6;

    if (point2 == null) {
      final delay = (a1 - s1).clamp(minDelaySeconds, maxDelaySeconds);
      return SubtitleSyncResult(
        delaySeconds: delay,
        speedFactor: 1.0,
        hasDriftCorrection: false,
        summary: '1-Point Offset: ${_formatDelay(delay)}',
      );
    }

    final a2 = point2.audioTime.inMicroseconds / 1e6;
    final s2 = point2.subtitleTime.inMicroseconds / 1e6;

    // Normalize order so p1 is earlier than p2
    final double startAudio, endAudio, startSub, endSub;
    if (s2 >= s1) {
      startAudio = a1;
      endAudio = a2;
      startSub = s1;
      endSub = s2;
    } else {
      startAudio = a2;
      endAudio = a1;
      startSub = s2;
      endSub = s1;
    }

    final deltaSub = endSub - startSub;
    final deltaAudio = endAudio - startAudio;

    // Check for degenerate points where subtitle times or audio times are identical
    if (deltaSub.abs() < 0.05 || deltaAudio.abs() < 0.05) {
      final delay = (a1 - s1).clamp(minDelaySeconds, maxDelaySeconds);
      return SubtitleSyncResult(
        delaySeconds: delay,
        speedFactor: 1.0,
        hasDriftCorrection: false,
        summary: 'Degenerate points: fallback to 1-point offset ${_formatDelay(delay)}',
      );
    }

    // Solve for Speed Factor: F = deltaAudio / deltaSub
    double rawSpeed = deltaAudio / deltaSub;
    final speed = rawSpeed.clamp(minSpeedFactor, maxSpeedFactor);

    // Solve for Delay Offset: D = A1 - (F * S1)
    double rawDelay = startAudio - (speed * startSub);
    final delay = rawDelay.clamp(minDelaySeconds, maxDelaySeconds);

    return SubtitleSyncResult(
      delaySeconds: delay,
      speedFactor: speed,
      hasDriftCorrection: true,
      summary: '2-Point Auto-Sync: ${_formatDelay(delay)}, Speed: ${speed.toStringAsFixed(4)}x',
    );
  }

  /// Maps an original subtitle timestamp to the estimated media audio timestamp
  /// given a computed [syncResult].
  static Duration estimateVideoTimeForSubtitle({
    required Duration subtitleTime,
    required SubtitleSyncResult syncResult,
  }) {
    final subSeconds = subtitleTime.inMicroseconds / 1e6;
    final videoSeconds = (subSeconds * syncResult.speedFactor) + syncResult.delaySeconds;
    final clampedMicros = math.max(0, (videoSeconds * 1e6).round());
    return Duration(microseconds: clampedMicros);
  }

  static String _formatDelay(double delay) {
    if (delay.abs() < 0.001) return '0.000s';
    final sign = delay > 0 ? '+' : '';
    return '$sign${delay.toStringAsFixed(3)}s';
  }
}
