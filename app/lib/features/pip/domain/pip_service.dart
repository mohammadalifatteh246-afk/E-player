import 'dart:async';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import '../data/pip_platform_bridge.dart';
import 'pip_models.dart';

/// Service coordinating Picture-in-Picture lifecycle, auto-enter management,
/// desktop overlay sizing, and incoming remote action dispatch.
class PipService extends ChangeNotifier {
  final PipPlatformBridge _bridge;

  bool _isInPip = false;
  bool _isDesktopOverlay = false;
  bool _autoEnterEnabled = false;
  bool _isSupported = false;
  Size? _desktopOverlaySize;
  PipDimensions? _currentDimensions;

  final StreamController<PipAction> _actionController =
      StreamController<PipAction>.broadcast();

  StreamSubscription<void>? _pipEnteredSub;
  StreamSubscription<void>? _pipExitedSub;
  StreamSubscription<String>? _pipActionSub;

  PipService({PipPlatformBridge? bridge})
      : _bridge = bridge ?? PipPlatformBridge() {
    _initBridgeListeners();
  }

  /// Whether the app is currently in native Picture-in-Picture mode.
  bool get isInPip => _isInPip;

  /// Whether the app is currently in desktop floating overlay mode.
  bool get isDesktopOverlay => _isDesktopOverlay;

  /// Whether Android 12+ AutoEnterPiP is currently armed.
  bool get autoEnterEnabled => _autoEnterEnabled;

  /// Cached capability status of Picture-in-Picture on the current device.
  bool get isSupported => _isSupported;

  /// Active geometry size for desktop overlay window.
  Size? get desktopOverlaySize => _desktopOverlaySize;

  /// Active dimensions and aspect ratio for the PiP video surface.
  PipDimensions? get currentDimensions => _currentDimensions;

  /// Stream of parsed remote control actions (play, pause, seekForward10, seekRewind10).
  Stream<PipAction> get actionStream => _actionController.stream;

  void _initBridgeListeners() {
    _pipEnteredSub = _bridge.onPipEntered.listen((_) {
      _isInPip = true;
      notifyListeners();
    });

    _pipExitedSub = _bridge.onPipExited.listen((_) {
      _isInPip = false;
      notifyListeners();
    });

    _pipActionSub = _bridge.onPipAction.listen((rawAction) {
      final action = PipAction.fromString(rawAction);
      if (!_actionController.isClosed) {
        _actionController.add(action);
      }
    });
  }

  /// Queries native platform to determine if Picture-in-Picture is supported.
  Future<bool> isPipSupported() async {
    _isSupported = await _bridge.isPipSupported();
    notifyListeners();
    return _isSupported;
  }

  /// Enters Picture-in-Picture mode with the specified video dimensions and playback state.
  Future<bool> enterPip({
    required int videoWidth,
    required int videoHeight,
    required bool isPlaying,
  }) async {
    _currentDimensions = PipDimensions.fromSize(videoWidth, videoHeight);
    final success = await _bridge.enterPictureInPictureMode(
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      isPlaying: isPlaying,
    );

    if (success) {
      _isInPip = true;
      notifyListeners();
    }
    return success;
  }

  /// Arms or disarms automatic transition to PiP when user navigates home.
  Future<void> setAutoEnterEnabled(
    bool enabled, {
    int? videoWidth,
    int? videoHeight,
  }) async {
    if (videoWidth != null && videoHeight != null) {
      _currentDimensions = PipDimensions.fromSize(videoWidth, videoHeight);
    }
    await _bridge.setAutoEnterEnabled(
      enabled,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
    );
    _autoEnterEnabled = enabled;
    notifyListeners();
  }

  /// Toggles desktop floating borderless window mode with aspect ratio preservation.
  Future<bool> toggleDesktopOverlay({
    required bool enable,
    Size? initialSize,
  }) async {
    final success = await _bridge.toggleDesktopOverlay(
      enable: enable,
      initialSize: initialSize,
    );

    if (success) {
      _isDesktopOverlay = enable;
      _desktopOverlaySize = enable ? (initialSize ?? _desktopOverlaySize) : null;
      notifyListeners();
    }
    return success;
  }

  /// Synchronizes playback state with AutoEnterPiP rules.
  /// When media is playing, AutoEnterPiP is armed; when paused/stopped, it is disarmed.
  void updatePlaybackState({
    required bool isPlaying,
    int? videoWidth,
    int? videoHeight,
  }) {
    final shouldAutoEnter = PipMath.canAutoEnter(isPlaying);
    if (_autoEnterEnabled != shouldAutoEnter) {
      setAutoEnterEnabled(
        shouldAutoEnter,
        videoWidth: videoWidth,
        videoHeight: videoHeight,
      );
    }
  }

  bool _isDisposed = false;

  /// Whether this service instance has been disposed.
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _pipEnteredSub?.cancel();
    _pipExitedSub?.cancel();
    _pipActionSub?.cancel();
    _actionController.close();
    _bridge.dispose();
    super.dispose();
  }
}
