import 'package:flutter/foundation.dart';

/// Strongly typed decoder mode representing user or pipeline configuration.
///
/// Maps directly to `libmpv` `hwdec` property options:
/// - [auto] -> `'auto'` (mpv selects best available hardware decoder)
/// - [hw] -> `'yes'` (strict zero-copy direct hardware decoding)
/// - [hwPlus] -> `'auto-copy'` (hybrid hardware decode with copy-back for filter graph / subtitle compositing)
/// - [sw] -> `'no'` (software CPU decoding via FFmpeg)
enum DecoderMode {
  auto,
  hw,
  hwPlus,
  sw;

  /// Human-readable label for UI buttons and HUD diagnostics.
  String get label {
    switch (this) {
      case DecoderMode.auto:
        return 'Auto';
      case DecoderMode.hw:
        return 'HW';
      case DecoderMode.hwPlus:
        return 'HW+';
      case DecoderMode.sw:
        return 'SW';
    }
  }

  /// Corresponding `libmpv` `hwdec` option string.
  String get mpvValue {
    switch (this) {
      case DecoderMode.auto:
        return 'auto';
      case DecoderMode.hw:
        return 'yes';
      case DecoderMode.hwPlus:
        return 'auto-copy';
      case DecoderMode.sw:
        return 'no';
    }
  }

  /// Whether this mode leverages hardware decoder acceleration.
  bool get isHardwareAccelerated => this != DecoderMode.sw;

  /// The next degraded tier in the automated fallback cascade:
  /// Auto -> HW+ -> SW -> (null)
  /// HW -> HW+ -> SW -> (null)
  /// HW+ -> SW -> (null)
  DecoderMode? get nextFallback {
    switch (this) {
      case DecoderMode.auto:
        return DecoderMode.hwPlus;
      case DecoderMode.hw:
        return DecoderMode.hwPlus;
      case DecoderMode.hwPlus:
        return DecoderMode.sw;
      case DecoderMode.sw:
        return null;
    }
  }

  /// Parse a string into a [DecoderMode].
  static DecoderMode fromString(String? value) {
    if (value == null) return DecoderMode.auto;
    final normalized = value.trim().toLowerCase().replaceAll('-', '').replaceAll(' ', '');
    switch (normalized) {
      case 'hw':
      case 'hardware':
      case 'yes':
        return DecoderMode.hw;
      case 'hw+':
      case 'hwplus':
      case 'autocopy':
        return DecoderMode.hwPlus;
      case 'sw':
      case 'software':
      case 'no':
        return DecoderMode.sw;
      case 'auto':
      default:
        return DecoderMode.auto;
    }
  }
}

/// Real-time diagnostic telemetry emitted by [DecoderPipelineService].
@immutable
class DecoderTelemetry {
  /// The user-configured or pipeline-requested decoder mode.
  final DecoderMode requestedMode;

  /// The active hardware/software decoding backend reported by mpv (`hwdec-current`),
  /// e.g. `'mediacodec'`, `'d3d11va'`, `'nvdec'`, `'vaapi'`, `'videotoolbox'`, `'no'`.
  final String activeDecoder;

  /// The video codec identifier (e.g. `'hevc'`, `'h264'`, `'av1'`, `'vp9'`).
  final String codec;

  /// Total dropped frames accumulated by video output (`vo-drop-frame-count`).
  final int droppedFrames;

  /// Estimated current playback frame rate.
  final double fps;

  /// Video or container bitrate in bits per second.
  final int bitrate;

  /// Native video width in pixels.
  final int width;

  /// Native video height in pixels.
  final int height;

  /// Diagnostic description if a fallback transition was recently performed.
  final String? fallbackReason;

  /// Telemetry emission timestamp.
  final DateTime? timestamp;

  const DecoderTelemetry({
    required this.requestedMode,
    required this.activeDecoder,
    required this.codec,
    required this.droppedFrames,
    required this.fps,
    this.bitrate = 0,
    this.width = 0,
    this.height = 0,
    this.fallbackReason,
    this.timestamp,
  });

  /// Inferred active mode based on [activeDecoder] and [requestedMode].
  DecoderMode get activeMode {
    final lower = activeDecoder.toLowerCase();
    if (lower == 'no' || lower == 'none' || lower == 'sw') {
      return DecoderMode.sw;
    }
    if (lower.contains('copy')) {
      return DecoderMode.hwPlus;
    }
    if (lower.isNotEmpty && lower != 'unknown' && lower != 'no') {
      return DecoderMode.hw;
    }
    return requestedMode;
  }

  /// Whether the active decoder is hardware-accelerated.
  bool get isHardwareAccelerated => activeMode != DecoderMode.sw;

  DecoderTelemetry copyWith({
    DecoderMode? requestedMode,
    String? activeDecoder,
    String? codec,
    int? droppedFrames,
    double? fps,
    int? bitrate,
    int? width,
    int? height,
    String? fallbackReason,
    DateTime? timestamp,
  }) {
    return DecoderTelemetry(
      requestedMode: requestedMode ?? this.requestedMode,
      activeDecoder: activeDecoder ?? this.activeDecoder,
      codec: codec ?? this.codec,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      fps: fps ?? this.fps,
      bitrate: bitrate ?? this.bitrate,
      width: width ?? this.width,
      height: height ?? this.height,
      fallbackReason: fallbackReason ?? this.fallbackReason,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DecoderTelemetry &&
        other.requestedMode == requestedMode &&
        other.activeDecoder == activeDecoder &&
        other.codec == codec &&
        other.droppedFrames == droppedFrames &&
        other.fps == fps &&
        other.bitrate == bitrate &&
        other.width == width &&
        other.height == height &&
        other.fallbackReason == fallbackReason;
  }

  @override
  int get hashCode => Object.hash(
        requestedMode,
        activeDecoder,
        codec,
        droppedFrames,
        fps,
        bitrate,
        width,
        height,
        fallbackReason,
      );

  @override
  String toString() {
    return 'DecoderTelemetry(requested: ${requestedMode.label}, active: $activeDecoder, codec: $codec, drops: $droppedFrames, fps: ${fps.toStringAsFixed(1)}, bitrate: $bitrate, res: ${width}x$height, fallback: $fallbackReason)';
  }
}

/// Result returned from a decoder switch or fallback transition.
@immutable
class DecoderSwitchResult {
  /// Whether the target decoder mode was successfully dispatched to `libmpv`.
  final bool success;

  /// The active decoder mode after the switch attempt.
  final DecoderMode activeMode;

  /// The active decoder backend or mpv property value applied.
  final String backend;

  /// Diagnostic reason if the switch was triggered by automated fallback.
  final String? fallbackReason;

  const DecoderSwitchResult({
    required this.success,
    required this.activeMode,
    required this.backend,
    this.fallbackReason,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DecoderSwitchResult &&
        other.success == success &&
        other.activeMode == activeMode &&
        other.backend == backend &&
        other.fallbackReason == fallbackReason;
  }

  @override
  int get hashCode => Object.hash(success, activeMode, backend, fallbackReason);

  @override
  String toString() =>
      'DecoderSwitchResult(success: $success, activeMode: ${activeMode.label}, backend: $backend, fallbackReason: $fallbackReason)';
}
