import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform bridge encapsulating communication with native Picture-in-Picture
/// subsystems over the `com.example.app/pip` MethodChannel.
class PipPlatformBridge {
  static const String channelName = 'com.example.app/pip';

  final MethodChannel _channel;

  final StreamController<void> _pipEnteredController =
      StreamController<void>.broadcast();
  final StreamController<void> _pipExitedController =
      StreamController<void>.broadcast();
  final StreamController<String> _pipActionController =
      StreamController<String>.broadcast();

  bool _isDisposed = false;

  PipPlatformBridge([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Inbound stream emitted when system enters Picture-in-Picture mode.
  Stream<void> get onPipEntered => _pipEnteredController.stream;

  /// Inbound stream emitted when system exits Picture-in-Picture mode.
  Stream<void> get onPipExited => _pipExitedController.stream;

  /// Inbound stream emitted when a remote PiP action is triggered (play, pause, seek, etc.).
  Stream<String> get onPipAction => _pipActionController.stream;

  /// Handles incoming calls from native platform (Android activity / desktop window).
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (_isDisposed) return null;

    switch (call.method) {
      case 'onPipEntered':
        if (!_pipEnteredController.isClosed) {
          _pipEnteredController.add(null);
        }
        return true;
      case 'onPipExited':
        if (!_pipExitedController.isClosed) {
          _pipExitedController.add(null);
        }
        return true;
      case 'onPipAction':
        String? action;
        if (call.arguments is String) {
          action = call.arguments as String;
        } else if (call.arguments is Map) {
          final map = call.arguments as Map;
          action = map['action'] as String?;
        }
        if (action != null && !_pipActionController.isClosed) {
          _pipActionController.add(action);
        }
        return true;
      default:
        debugPrint('[PipPlatformBridge] Unhandled native call: ${call.method}');
        return null;
    }
  }

  /// Queries whether the host platform supports Picture-in-Picture mode.
  Future<bool> isPipSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } on PlatformException catch (e) {
      debugPrint('[PipPlatformBridge] isPipSupported error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the native host to enter Picture-in-Picture mode with given video parameters.
  Future<bool> enterPictureInPictureMode({
    required int videoWidth,
    required int videoHeight,
    required bool isPlaying,
  }) async {
    try {
      final success = await _channel.invokeMethod<bool>(
        'enterPictureInPictureMode',
        <String, dynamic>{
          'videoWidth': videoWidth,
          'videoHeight': videoHeight,
          'isPlaying': isPlaying,
        },
      );
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[PipPlatformBridge] enterPictureInPictureMode error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Configures Android 12+ (API 31+) automatic PiP entry upon system home gesture.
  Future<void> setAutoEnterEnabled(
    bool enabled, {
    int? videoWidth,
    int? videoHeight,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'setAutoEnterEnabled',
        <String, dynamic>{
          'enabled': enabled,
          'videoWidth': videoWidth,
          'videoHeight': videoHeight,
        },
      );
    } on PlatformException catch (e) {
      debugPrint('[PipPlatformBridge] setAutoEnterEnabled error: $e');
    } catch (_) {}
  }

  /// Toggles desktop floating borderless always-on-top window mode.
  Future<bool> toggleDesktopOverlay({
    required bool enable,
    Size? initialSize,
  }) async {
    try {
      final params = <String, dynamic>{
        'enabled': enable,
        if (initialSize != null) ...{
          'width': initialSize.width.toInt(),
          'height': initialSize.height.toInt(),
        },
      };
      final success = await _channel.invokeMethod<bool>(
        'toggleDesktopOverlay',
        params,
      );
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[PipPlatformBridge] toggleDesktopOverlay error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Cleans up native call handlers and closes all stream controllers.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _channel.setMethodCallHandler(null);
    _pipEnteredController.close();
    _pipExitedController.close();
    _pipActionController.close();
  }
}
