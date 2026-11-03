import 'dart:ui' show Size;

/// Operational lifecycle status of Picture-in-Picture mode.
enum PipStatus {
  stopped,
  entering,
  active,
  exiting,
}

/// Remote playback action intents dispatched by Picture-in-Picture controls.
enum PipAction {
  play,
  pause,
  seekForward10,
  seekRewind10,
  unknown;

  /// Parses raw platform action strings into strongly-typed [PipAction].
  static PipAction fromString(String? raw) {
    if (raw == null) return PipAction.unknown;
    switch (raw.trim().toLowerCase()) {
      case 'play':
        return PipAction.play;
      case 'pause':
        return PipAction.pause;
      case 'seek_forward_10':
      case 'fast_forward':
        return PipAction.seekForward10;
      case 'seek_rewind_10':
      case 'rewind':
        return PipAction.seekRewind10;
      default:
        return PipAction.unknown;
    }
  }
}

/// Strongly-typed dimensions and aspect-ratio metadata for Picture-in-Picture windows.
class PipDimensions {
  final int width;
  final int height;
  final double aspectRatio;

  const PipDimensions({
    required this.width,
    required this.height,
    required this.aspectRatio,
  });

  /// Factory calculating clamped aspect ratio from video resolution width and height.
  factory PipDimensions.fromSize(int width, int height) {
    final ratio = PipMath.calculateAspectRatio(width, height);
    return PipDimensions(
      width: width,
      height: height,
      aspectRatio: ratio,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PipDimensions &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          (aspectRatio - other.aspectRatio).abs() < 0.0001;

  @override
  int get hashCode => Object.hash(width, height, aspectRatio);

  @override
  String toString() =>
      'PipDimensions(${width}x$height, aspect: ${aspectRatio.toStringAsFixed(3)})';
}

/// Pure mathematical and rational bounds validators for Picture-in-Picture.
class PipMath {
  /// Android OS strictly limits PiP aspect ratio between 1:2.39 (~0.4184) and 2.39:1.
  static const double minAspectRatio = 1.0 / 2.39; // ~0.41841004184100417
  static const double maxAspectRatio = 2.39 / 1.0; // 2.39

  /// Calculates aspect ratio clamped to Android OS hardware limitations.
  /// If width or height are invalid (<= 0), defaults to standard 16:9 ratio.
  static double calculateAspectRatio(int width, int height) {
    if (width <= 0 || height <= 0) return 16.0 / 9.0;
    final rawRatio = width / height;
    return rawRatio.clamp(minAspectRatio, maxAspectRatio);
  }

  /// Determines whether auto-entering PiP is permitted based on playback state.
  static bool canAutoEnter(bool isPlaying) => isPlaying;

  /// Calculates desktop overlay window size preserving video aspect ratio.
  static Size calculateOverlaySize(int width, int height, [double baseWidth = 480.0]) {
    final ratio = calculateAspectRatio(width, height);
    return Size(baseWidth, (baseWidth / ratio).roundToDouble());
  }
}
