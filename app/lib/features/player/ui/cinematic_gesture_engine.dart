import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gesture_models.dart';

/// Arbitration state machine for resolving multi-touch gestures, dead-zone gating,
/// and spatial zone classification.
class GestureArbitrator {
  GestureMode _mode = GestureMode.idle;
  Offset? _startPoint;
  Offset _cumulativeDelta = Offset.zero;

  /// Current gesture mode.
  GestureMode get mode => _mode;

  /// Touch down origin coordinates.
  Offset? get startPoint => _startPoint;

  /// Cumulative travel delta from origin.
  Offset get cumulativeDelta => _cumulativeDelta;

  /// Whether the gesture has satisfied dead-zone gating and committed to a functional mode.
  bool get isCommitted =>
      _mode != GestureMode.idle && _mode != GestureMode.arbitrating;

  /// Initializes arbitration on pointer contact.
  void handleDown(Offset localPoint, int pointerCount, Size viewportSize) {
    if (pointerCount >= 2) {
      _mode = GestureMode.pinchZoom;
      _startPoint = localPoint;
      _cumulativeDelta = Offset.zero;
      return;
    }

    _mode = GestureMode.arbitrating;
    _startPoint = localPoint;
    _cumulativeDelta = Offset.zero;
  }

  /// Evaluates pointer movements against the directional dead zone (>=12px)
  /// and axis dominance ratio (1.5x) to transition out of [GestureMode.arbitrating].
  GestureMode arbitrate({
    required Offset currentPoint,
    required Size viewportSize,
    required int pointerCount,
  }) {
    if (pointerCount >= 2) {
      _mode = GestureMode.pinchZoom;
      return _mode;
    }

    // If already committed to a gesture mode, maintain that mode for the gesture lifespan.
    if (isCommitted) {
      return _mode;
    }

    if (_startPoint == null) {
      _startPoint = currentPoint;
      _mode = GestureMode.arbitrating;
      return _mode;
    }

    final dx = currentPoint.dx - _startPoint!.dx;
    final dy = currentPoint.dy - _startPoint!.dy;
    _cumulativeDelta = Offset(dx, dy);

    final absDx = dx.abs();
    final absDy = dy.abs();
    final primaryDelta = math.max(absDx, absDy);
    final secondaryDelta = math.min(absDx, absDy);

    // INV-GEST-003: Must move >= 12 physical pixels
    if (primaryDelta < CinematicGestureConfig.deadZoneThreshold) {
      _mode = GestureMode.arbitrating;
      return _mode;
    }

    // INV-GEST-003: Must satisfy |primaryAxisDelta| >= 1.5 * |secondaryAxisDelta|
    if (primaryDelta < CinematicGestureConfig.axisDominanceRatio * secondaryDelta) {
      _mode = GestureMode.arbitrating;
      return _mode;
    }

    // Committing to functional mode based on spatial zone and dominant axis
    final startX = _startPoint!.dx;
    final width = viewportSize.width;

    if (absDy >= absDx) {
      // Dominant vertical axis
      if (startX <= CinematicGestureConfig.leftZoneRatio * width) {
        _mode = GestureMode.brightnessAdjust;
      } else if (startX >= CinematicGestureConfig.rightZoneRatio * width) {
        _mode = GestureMode.volumeAdjust;
      } else {
        // Center vertical swipe is not mapped to single-finger action
        _mode = GestureMode.arbitrating;
      }
    } else {
      // Dominant horizontal axis
      if (startX > CinematicGestureConfig.leftZoneRatio * width &&
          startX < CinematicGestureConfig.rightZoneRatio * width) {
        _mode = GestureMode.horizontalScrub;
      } else {
        // Horizontal swipes strictly on extreme edges do not trigger center precision scrub
        _mode = GestureMode.arbitrating;
      }
    }

    return _mode;
  }

  /// Standalone evaluation helper for deterministic unit testing.
  static GestureMode evaluateSwipe({
    required Offset startPoint,
    required Offset currentPoint,
    required Size viewportSize,
    int pointerCount = 1,
  }) {
    final arbitrator = GestureArbitrator();
    arbitrator.handleDown(startPoint, pointerCount, viewportSize);
    return arbitrator.arbitrate(
      currentPoint: currentPoint,
      viewportSize: viewportSize,
      pointerCount: pointerCount,
    );
  }

  /// Resets arbitrator to idle state.
  void reset() {
    _mode = GestureMode.idle;
    _startPoint = null;
    _cumulativeDelta = Offset.zero;
  }
}

/// Unified Cinematic Gesture Engine for video playback viewports.
/// Enforces directional dead zones, focal-point bounded zoom, precision scrub,
/// split brightness/volume sliders, double-tap wing jump, and HUD timer coordination.
class CinematicGestureEngine {
  final GestureArbitrator arbitrator;

  // Configuration & Callbacks
  final VoidCallback? onInvalidateAiQueue;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onTogglePlayPause;
  final ValueChanged<Duration>? onSeek;

  // Stream Controllers
  final StreamController<GestureFeedbackEvent> _feedbackController =
      StreamController<GestureFeedbackEvent>.broadcast();
  final StreamController<SeekCommitEvent> _seekCommitController =
      StreamController<SeekCommitEvent>.broadcast();
  final StreamController<bool> _controlsInhibitedController =
      StreamController<bool>.broadcast();

  // Internal Interaction State
  double _brightness;
  double _volume;
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;

  double _initialScale = 1.0;
  Duration? _initialPosition;
  Duration _scrubPreviewPosition = Duration.zero;
  Duration _lastTotalDuration = Duration.zero;

  CinematicGestureEngine({
    GestureArbitrator? arbitrator,
    double initialBrightness = 0.5,
    double initialVolume = 100.0,
    this.onInvalidateAiQueue,
    this.onBrightnessChanged,
    this.onVolumeChanged,
    this.onTogglePlayPause,
    this.onSeek,
  })  : arbitrator = arbitrator ?? GestureArbitrator(),
        _brightness = initialBrightness.clamp(0.0, 1.0),
        _volume = initialVolume.clamp(0.0, 100.0);

  // Streams matching PROJECT.md interface contract
  Stream<GestureFeedbackEvent> get feedbackEvents => _feedbackController.stream;
  Stream<SeekCommitEvent> get seekCommitEvents => _seekCommitController.stream;
  Stream<bool> get controlsInhibited => _controlsInhibitedController.stream;

  // State Getters
  GestureMode get currentMode => arbitrator.mode;
  double get brightness => _brightness;
  double get volume => _volume;
  double get scale => _scale;
  Offset get panOffset => _panOffset;
  Duration get scrubPreviewPosition => _scrubPreviewPosition;

  /// External state updates (e.g., from system volume or player events).
  void setExternalBrightness(double value) {
    _brightness = value.clamp(0.0, 1.0);
  }

  void setExternalVolume(double value) {
    _volume = value.clamp(0.0, 100.0);
  }

  /// Clamps panning translation offsets according to INV-GEST-004:
  /// `|Tx| <= (scale - 1.0) * width / 2` and `|Ty| <= (scale - 1.0) * height / 2`.
  /// Guarantees that zero black void is exposed outside the video viewport.
  static Offset clampPanOffset(Offset offset, double scale, Size viewportSize) {
    if (scale <= 1.0) {
      return Offset.zero;
    }
    final maxTx = (scale - 1.0) * viewportSize.width / 2.0;
    final maxTy = (scale - 1.0) * viewportSize.height / 2.0;

    return Offset(
      offset.dx.clamp(-maxTx, maxTx),
      offset.dy.clamp(-maxTy, maxTy),
    );
  }

  /// Formats duration for feedback labels.
  static String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  /// Resets zoom and pan offset back to 1.0x with zero translation.
  void resetZoom() {
    _scale = 1.0;
    _panOffset = Offset.zero;
  }

  /// Handles gesture start event from GestureDetector.
  void handleScaleStart(ScaleStartDetails details, Size viewportSize) {
    _initialPosition = null;
    _controlsInhibitedController.add(true);
    _initialScale = _scale;
    arbitrator.handleDown(
      details.localFocalPoint,
      details.pointerCount,
      viewportSize,
    );
  }

  /// Handles gesture update event from GestureDetector.
  void handleScaleUpdate(
    ScaleUpdateDetails details,
    Size viewportSize,
    Duration currentPosition,
    Duration totalDuration,
  ) {
    _lastTotalDuration = totalDuration;
    final mode = arbitrator.arbitrate(
      currentPoint: details.localFocalPoint,
      viewportSize: viewportSize,
      pointerCount: details.pointerCount,
    );

    switch (mode) {
      case GestureMode.pinchZoom:
        _handlePinchZoom(details, viewportSize);
        break;
      case GestureMode.brightnessAdjust:
        _handleBrightnessAdjust(details, viewportSize);
        break;
      case GestureMode.volumeAdjust:
        _handleVolumeAdjust(details, viewportSize);
        break;
      case GestureMode.horizontalScrub:
        _handleHorizontalScrub(
          details,
          viewportSize,
          currentPosition,
          totalDuration,
        );
        break;
      case GestureMode.arbitrating:
      case GestureMode.idle:
        break;
    }
  }

  /// Handles gesture release and commits any active seeking operation.
  void handleScaleEnd(ScaleEndDetails details) {
    final mode = arbitrator.mode;

    if (mode == GestureMode.horizontalScrub) {
      onInvalidateAiQueue?.call();
      _seekCommitController.add(SeekCommitEvent(
        target: _scrubPreviewPosition,
        previewDuration: _lastTotalDuration,
      ));
      onSeek?.call(_scrubPreviewPosition);
    }

    _initialPosition = null;
    arbitrator.reset();
    _controlsInhibitedController.add(false);
  }

  /// Handles double tap interactions for wing jumps (+/-10s), play/pause, or zoom reset.
  void handleDoubleTapDown(
    TapDownDetails details,
    Size viewportSize,
    Duration currentPosition,
    Duration totalDuration,
  ) {
    // If video is zoomed, double tap resets scale to 1.0x
    if (_scale > 1.0) {
      resetZoom();
      _feedbackController.add(const GestureFeedbackEvent(
        type: GestureFeedbackType.zoom,
        value: 1.0,
        label: '1.00x',
        deltaFormatted: '1.0x',
      ));
      return;
    }

    final dx = details.localPosition.dx;
    final width = viewportSize.width;

    if (dx < CinematicGestureConfig.leftWingRatio * width) {
      // Left wing: seek backward 10s with boundary clamping
      final target = currentPosition - CinematicGestureConfig.wingJumpDuration;
      final clamped = target < Duration.zero ? Duration.zero : target;
      onInvalidateAiQueue?.call();
      _seekCommitController.add(SeekCommitEvent(
        target: clamped,
        previewDuration: totalDuration,
      ));
      onSeek?.call(clamped);
      _feedbackController.add(GestureFeedbackEvent(
        type: GestureFeedbackType.wingJump,
        value: -10.0,
        label: '-10s',
        seekTarget: clamped,
        deltaFormatted: '-10s',
      ));
    } else if (dx > CinematicGestureConfig.rightWingRatio * width) {
      // Right wing: seek forward 10s with boundary clamping
      final target = currentPosition + CinematicGestureConfig.wingJumpDuration;
      final clamped = target > totalDuration ? totalDuration : target;
      onInvalidateAiQueue?.call();
      _seekCommitController.add(SeekCommitEvent(
        target: clamped,
        previewDuration: totalDuration,
      ));
      onSeek?.call(clamped);
      _feedbackController.add(GestureFeedbackEvent(
        type: GestureFeedbackType.wingJump,
        value: 10.0,
        label: '+10s',
        seekTarget: clamped,
        deltaFormatted: '+10s',
      ));
    } else {
      // Center zone double tap toggles playback
      onTogglePlayPause?.call();
    }
  }

  // --- Private Gesture Handlers ---

  void _handlePinchZoom(ScaleUpdateDetails details, Size viewportSize) {
    final candidateScale = (_initialScale * details.scale).clamp(
      CinematicGestureConfig.minZoomScale,
      CinematicGestureConfig.maxZoomScale,
    );
    _scale = candidateScale;

    if (_scale > 1.0) {
      final candidatePan = _panOffset + details.focalPointDelta;
      _panOffset = clampPanOffset(candidatePan, _scale, viewportSize);
    } else {
      _panOffset = Offset.zero;
    }

    _feedbackController.add(GestureFeedbackEvent(
      type: GestureFeedbackType.zoom,
      value: _scale,
      label: '${_scale.toStringAsFixed(2)}x',
      deltaFormatted: '${_scale.toStringAsFixed(1)}x',
    ));
  }

  void _handleBrightnessAdjust(
    ScaleUpdateDetails details,
    Size viewportSize,
  ) {
    final effectiveHeight = viewportSize.height > 0 ? viewportSize.height : 600.0;
    // Dragging upwards (negative dy) increases brightness
    final delta = -details.focalPointDelta.dy / (effectiveHeight * 0.7);
    _brightness = (_brightness + delta).clamp(0.0, 1.0);
    onBrightnessChanged?.call(_brightness);

    _feedbackController.add(GestureFeedbackEvent(
      type: GestureFeedbackType.brightness,
      value: _brightness,
      label: '${(_brightness * 100).round()}%',
      deltaFormatted: '${(_brightness * 100).round()}%',
    ));
  }

  void _handleVolumeAdjust(
    ScaleUpdateDetails details,
    Size viewportSize,
  ) {
    final effectiveHeight = viewportSize.height > 0 ? viewportSize.height : 600.0;
    // Dragging upwards (negative dy) increases volume
    final delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 100.0;
    _volume = (_volume + delta).clamp(0.0, 100.0);
    onVolumeChanged?.call(_volume);

    _feedbackController.add(GestureFeedbackEvent(
      type: GestureFeedbackType.volume,
      value: _volume,
      label: '${_volume.round()}%',
      deltaFormatted: '${_volume.round()}%',
    ));
  }

  void _handleHorizontalScrub(
    ScaleUpdateDetails details,
    Size viewportSize,
    Duration currentPosition,
    Duration totalDuration,
  ) {
    if (arbitrator.startPoint == null) return;

    _initialPosition ??= currentPosition;

    final cumulativeDx = details.localFocalPoint.dx - arbitrator.startPoint!.dx;
    // 0.5s per pixel travel for precision scrubbing
    final deltaSeconds = (cumulativeDx * 0.5).round();
    final candidateTarget = _initialPosition! + Duration(seconds: deltaSeconds);

    Duration clampedTarget;
    if (candidateTarget < Duration.zero) {
      clampedTarget = Duration.zero;
    } else if (totalDuration > Duration.zero && candidateTarget > totalDuration) {
      clampedTarget = totalDuration;
    } else {
      clampedTarget = candidateTarget;
    }

    _scrubPreviewPosition = clampedTarget;

    final formattedDelta = deltaSeconds >= 0 ? '+$deltaSeconds s' : '$deltaSeconds s';
    _feedbackController.add(GestureFeedbackEvent(
      type: GestureFeedbackType.scrub,
      value: clampedTarget.inMilliseconds.toDouble(),
      label: formatDuration(clampedTarget),
      seekTarget: clampedTarget,
      deltaFormatted: formattedDelta,
    ));
  }

  /// Disposes stream controllers and clears state.
  void dispose() {
    _feedbackController.close();
    _seekCommitController.close();
    _controlsInhibitedController.close();
  }
}
