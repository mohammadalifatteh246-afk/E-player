import 'package:flutter/material.dart';

/// Position alignment matching VLC's SPU (Subpicture Unit) position bitmask
/// from `modules/spu/logo.c` and `modules/spu/marq.c`.
enum VideoOverlayPosition {
  topLeft(5, 'Top-Left', Alignment.topLeft),
  topCenter(4, 'Top-Center', Alignment.topCenter),
  topRight(6, 'Top-Right', Alignment.topRight),
  bottomLeft(9, 'Bottom-Left', Alignment.bottomLeft),
  bottomCenter(8, 'Bottom-Center', Alignment.bottomCenter),
  bottomRight(10, 'Bottom-Right', Alignment.bottomRight),
  center(0, 'Center', Alignment.center);

  final int vlcBitmask;
  final String label;
  final Alignment alignment;

  const VideoOverlayPosition(this.vlcBitmask, this.label, this.alignment);

  static VideoOverlayPosition fromBitmask(int mask) {
    return VideoOverlayPosition.values.firstWhere(
      (p) => p.vlcBitmask == mask,
      orElse: () => VideoOverlayPosition.topLeft,
    );
  }

  static VideoOverlayPosition fromString(String name) {
    return VideoOverlayPosition.values.firstWhere(
      (p) => p.name == name,
      orElse: () => VideoOverlayPosition.topRight,
    );
  }
}

/// Dynamic Marquee Token Formatter matching VLC `marq.c` format strings.
/// Supports %Y-%m-%d %H:%M:%S (Clock), %t (Title), %p (Playback Position), %l (Duration).
class MarqueeTokenFormatter {
  MarqueeTokenFormatter._();

  static String format({
    required String template,
    String? mediaTitle,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    DateTime? now,
  }) {
    if (template.isEmpty) return '';

    final time = now ?? DateTime.now();
    String result = template;

    // Date & Time tokens (VLC strftime parity)
    result = result.replaceAll('%Y', time.year.toString().padLeft(4, '0'));
    result = result.replaceAll('%m', time.month.toString().padLeft(2, '0'));
    result = result.replaceAll('%d', time.day.toString().padLeft(2, '0'));
    result = result.replaceAll('%H', time.hour.toString().padLeft(2, '0'));
    result = result.replaceAll('%M', time.minute.toString().padLeft(2, '0'));
    result = result.replaceAll('%S', time.second.toString().padLeft(2, '0'));

    // Playback tokens
    result = result.replaceAll('%t', mediaTitle != null && mediaTitle.isNotEmpty ? mediaTitle : 'E-Player');
    result = result.replaceAll('%p', formatDuration(position));
    result = result.replaceAll('%l', formatDuration(duration));

    return result;
  }

  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Whether the template contains time-varying tokens that require periodic repaint
  static bool hasDynamicTokens(String template) {
    return template.contains('%S') ||
        template.contains('%M') ||
        template.contains('%H') ||
        template.contains('%p');
  }
}
