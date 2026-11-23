library;

/// Precision timestamp parser and formatter for VLC `goto_time.cpp` parity.
class JumpToTimeParser {
  JumpToTimeParser._();

  /// Parses diverse timestamp expressions into a target [Duration].
  /// Supports:
  /// - `HH:MM:SS` (e.g. "01:23:45", "1:05:10")
  /// - `MM:SS` (e.g. "23:45", "5:30")
  /// - Plain seconds (e.g. "90" -> 1m 30s, "300" -> 5m)
  /// - Percentage (e.g. "50%" -> halfway through [totalDuration])
  /// - Relative offsets with [currentPosition] (e.g. "+10m", "-5m", "+30s", "-1h")
  static Duration? parse(
    String rawInput, {
    Duration totalDuration = Duration.zero,
    Duration currentPosition = Duration.zero,
  }) {
    final input = rawInput.trim();
    if (input.isEmpty) return null;

    // 1. Percentage Expression (e.g. "50%", "75.5%")
    if (input.endsWith('%')) {
      final numStr = input.substring(0, input.length - 1).trim();
      final pct = double.tryParse(numStr);
      if (pct != null && pct >= 0.0) {
        final ms = ((pct / 100.0) * totalDuration.inMilliseconds).round();
        return _clamp(Duration(milliseconds: ms), totalDuration);
      }
      return null;
    }

    // 2. Relative Jumps (e.g. "+10m", "-5m", "+30s", "+1h")
    if (input.startsWith('+') || input.startsWith('-')) {
      final sign = input.startsWith('-') ? -1 : 1;
      final rest = input.substring(1).trim().toLowerCase();

      final relRegex = RegExp(r'^(\d+(?:\.\d+)?)\s*(h|hr|hours?|m|min|minutes?|s|sec|seconds?)?$');
      final match = relRegex.firstMatch(rest);
      if (match != null) {
        final val = double.tryParse(match.group(1) ?? '');
        final unit = match.group(2) ?? 's';
        if (val != null) {
          int addedMs = 0;
          if (unit.startsWith('h')) {
            addedMs = (val * 3600 * 1000).round();
          } else if (unit.startsWith('m')) {
            addedMs = (val * 60 * 1000).round();
          } else {
            addedMs = (val * 1000).round();
          }

          final target = currentPosition + Duration(milliseconds: sign * addedMs);
          return _clamp(target, totalDuration);
        }
      }
    }

    // 3. Colon-separated formats (HH:MM:SS or MM:SS)
    if (input.contains(':')) {
      final segments = input.split(':').map((s) => s.trim()).toList();
      if (segments.length == 2) {
        // MM:SS
        final m = int.tryParse(segments[0]);
        final s = int.tryParse(segments[1]);
        if (m != null && s != null && m >= 0 && s >= 0 && s < 60) {
          return _clamp(Duration(minutes: m, seconds: s), totalDuration);
        }
      } else if (segments.length == 3) {
        // HH:MM:SS
        final h = int.tryParse(segments[0]);
        final m = int.tryParse(segments[1]);
        final s = int.tryParse(segments[2]);
        if (h != null && m != null && s != null && h >= 0 && m >= 0 && m < 60 && s >= 0 && s < 60) {
          return _clamp(Duration(hours: h, minutes: m, seconds: s), totalDuration);
        }
      }
      return null;
    }

    // 4. Plain seconds / minutes suffix (e.g. "120", "45s", "10m")
    final suffixRegex = RegExp(r'^(\d+(?:\.\d+)?)\s*(h|m|s)?$', caseSensitive: false);
    final match = suffixRegex.firstMatch(input);
    if (match != null) {
      final val = double.tryParse(match.group(1) ?? '');
      final unit = match.group(2)?.toLowerCase();
      if (val != null) {
        if (unit == 'h') {
          return _clamp(Duration(milliseconds: (val * 3600 * 1000).round()), totalDuration);
        } else if (unit == 'm') {
          return _clamp(Duration(milliseconds: (val * 60 * 1000).round()), totalDuration);
        } else {
          return _clamp(Duration(milliseconds: (val * 1000).round()), totalDuration);
        }
      }
    }

    return null;
  }

  static Duration _clamp(Duration target, Duration max) {
    if (target < Duration.zero) return Duration.zero;
    if (max > Duration.zero && target > max) return max;
    return target;
  }

  /// Formats duration into `HH:MM:SS` (or `MM:SS` if under 1 hour).
  static String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Alias for [format].
  static String formatDuration(Duration d) => format(d);
}
