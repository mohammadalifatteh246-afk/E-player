import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// State representation of the Interactive Zoom & Pan magnification engine.
/// Provides mathematical parity with VLC's `modules/video_filter/magnify.c`.
@immutable
class InteractiveZoomState {
  static const double minZoom = 1.0;
  static const double maxZoom = 8.0;

  final double zoomFactor;
  final double panX;
  final double panY;

  InteractiveZoomState({
    double zoomFactor = 1.0,
    double panX = 0.0,
    double panY = 0.0,
  })  : zoomFactor = zoomFactor.clamp(minZoom, maxZoom),
        panX = panX.clamp(-1.0, 1.0),
        panY = panY.clamp(-1.0, 1.0);

  bool get isActive =>
      zoomFactor > 1.001 || panX.abs() > 0.001 || panY.abs() > 0.001;

  /// Log2 scale required by libmpv `video-zoom` property.
  /// (mpv: 0 = 1.0x, 1 = 2.0x, 2 = 4.0x, 3 = 8.0x).
  double get mpvZoomValue =>
      zoomFactor <= 1.0 ? 0.0 : math.log(zoomFactor) / math.ln2;

  /// Normalized [0.0, 1.0] viewport rectangle for rendering the mini-map viewfinder.
  Rect get viewportRect {
    final width = (1.0 / zoomFactor).clamp(0.01, 1.0);
    final height = (1.0 / zoomFactor).clamp(0.01, 1.0);

    // Max pan travel in normalized coordinates
    final maxTravelX = (1.0 - width) / 2.0;
    final maxTravelY = (1.0 - height) / 2.0;

    final centerX = 0.5 + (panX * maxTravelX);
    final centerY = 0.5 + (panY * maxTravelY);

    final left = (centerX - width / 2.0).clamp(0.0, 1.0 - width);
    final top = (centerY - height / 2.0).clamp(0.0, 1.0 - height);

    return Rect.fromLTWH(left, top, width, height);
  }

  InteractiveZoomState copyWith({
    double? zoomFactor,
    double? panX,
    double? panY,
  }) {
    return InteractiveZoomState(
      zoomFactor: zoomFactor ?? this.zoomFactor,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractiveZoomState &&
          runtimeType == other.runtimeType &&
          (zoomFactor - other.zoomFactor).abs() < 1e-4 &&
          (panX - other.panX).abs() < 1e-4 &&
          (panY - other.panY).abs() < 1e-4;

  @override
  int get hashCode => Object.hash(zoomFactor, panX, panY);

  @override
  String toString() =>
      'InteractiveZoomState(zoom: ${zoomFactor.toStringAsFixed(2)}x, pan: (${panX.toStringAsFixed(2)}, ${panY.toStringAsFixed(2)}))';
}

/// Controller coordinating real-time interactive zoom, pan gestures, and hardware video properties in libmpv.
class InteractiveZoomController extends ChangeNotifier {
  Player? _player;
  InteractiveZoomState _state = InteractiveZoomState();

  InteractiveZoomState get state => _state;

  InteractiveZoomController({Player? player}) {
    if (player != null) {
      attachPlayer(player);
    }
  }

  void attachPlayer(Player? player) {
    _player = player;
    _applyToPlayer();
  }

  void setZoom(double factor) {
    _state = _state.copyWith(zoomFactor: factor);
    _applyToPlayer();
    notifyListeners();
  }

  void setPan(double x, double y) {
    _state = _state.copyWith(panX: x, panY: y);
    _applyToPlayer();
    notifyListeners();
  }

  void nudgeZoom(double delta) {
    setZoom(_state.zoomFactor + delta);
  }

  void reset() {
    _state = InteractiveZoomState();
    _applyToPlayer();
    notifyListeners();
  }

  void _applyToPlayer() {
    if (_player == null) return;
    try {
      final dynamic platform = _player!.platform;
      platform.setProperty('video-zoom', _state.mpvZoomValue.toStringAsFixed(4));
      platform.setProperty('video-pan-x', _state.panX.toStringAsFixed(4));
      platform.setProperty('video-pan-y', _state.panY.toStringAsFixed(4));
    } catch (e) {
      debugPrint('[InteractiveZoomController] Error setting mpv pan-zoom properties: $e');
    }
  }
}
