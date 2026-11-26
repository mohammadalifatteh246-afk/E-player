library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/external_launch_models.dart';

typedef RegistryCommandRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

typedef WarmPlayerHandler = FutureOr<bool> Function(
  ExternalLaunchRequest request,
);

/// Coordinates cold-start & warm external file launches (Android ACTION_VIEW intents,
/// Windows CLI arguments & WM_COPYDATA single-instance IPC, plus HKCU file associations).
class ExternalLaunchService extends ChangeNotifier {
  static const String channelName = 'com.example.app/external_launch';
  static const String _kPrefSingleInstance = 'eplayer_ext_single_instance';
  static const String _kPrefWarmBehavior = 'eplayer_ext_warm_behavior';
  static const String _kPrefAutoPlayStreams = 'eplayer_ext_auto_play_streams';
  static const int maxHistoryEntries = 15;

  static ExternalLaunchService? _instance;
  static ExternalLaunchService get instance =>
      _instance ??= ExternalLaunchService._();

  @visibleForTesting
  static void resetForTesting({
    RegistryCommandRunner? processRunner,
  }) {
    _instance?._disposeInternal();
    _instance = ExternalLaunchService._(processRunner: processRunner);
  }

  final MethodChannel _channel = const MethodChannel(channelName);
  final RegistryCommandRunner _processRunner;
  final StreamController<ExternalLaunchRequest> _launchStreamController =
      StreamController<ExternalLaunchRequest>.broadcast();

  bool _isInitialized = false;
  bool _singleInstanceMode = true;
  WarmLaunchBehavior _warmLaunchBehavior = WarmLaunchBehavior.playImmediately;
  bool _autoPlayStreams = true;
  bool _windowsFileAssocRegistered = false;
  bool _isBusyUpdatingRegistry = false;

  ExternalLaunchRequest? _pendingColdStart;
  WarmPlayerHandler? _activePlayerHandler;
  final List<ExternalLaunchRequest> _history = [];

  ExternalLaunchService._({RegistryCommandRunner? processRunner})
      : _processRunner = processRunner ?? Process.run;

  Stream<ExternalLaunchRequest> get launchStream =>
      _launchStreamController.stream;

  WarmPlayerHandler? get activePlayerHandler => _activePlayerHandler;

  void registerActivePlayerHandler(WarmPlayerHandler handler) {
    _activePlayerHandler = handler;
  }

  void unregisterActivePlayerHandler(WarmPlayerHandler handler) {
    if (_activePlayerHandler == handler) {
      _activePlayerHandler = null;
    }
  }

  bool get isInitialized => _isInitialized;
  bool get singleInstanceMode => _singleInstanceMode;
  WarmLaunchBehavior get warmLaunchBehavior => _warmLaunchBehavior;
  bool get autoPlayStreams => _autoPlayStreams;
  bool get windowsFileAssocRegistered => _windowsFileAssocRegistered;
  bool get isBusyUpdatingRegistry => _isBusyUpdatingRegistry;
  List<ExternalLaunchRequest> get history => List.unmodifiable(_history);

  /// Initializes preferences, attaches the native MethodChannel listener,
  /// parses desktop CLI arguments, and queries Android's initial Intent payload.
  Future<void> initialize({List<String> cliArgs = const []}) async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadPrefs();

    // 1. Register handler for warm launches (Android onNewIntent / Windows WM_COPYDATA)
    try {
      _channel.setMethodCallHandler(_handlePlatformMethodCall);
    } catch (e) {
      debugPrint('[ExternalLaunch] MethodChannel handler registration skipped: $e');
    }

    // 2. Parse cold-start CLI arguments (Windows / Linux / macOS desktop)
    final cliReq = ExternalLaunchParser.parseCliArgs(
      cliArgs,
      sourcePlatform: Platform.isWindows ? 'windows_cli' : 'desktop_cli',
    );
    if (cliReq != null) {
      _pendingColdStart = cliReq;
      _recordHistory(cliReq);
    } else {
      // 3. Otherwise pull pending initial Android ACTION_VIEW / ACTION_SEND Intent
      try {
        final rawPayload =
            await _channel.invokeMethod<dynamic>('getInitialLaunch');
        if (rawPayload is Map) {
          final intentReq =
              ExternalLaunchParser.fromPlatformPayload(rawPayload);
          if (intentReq != null) {
            _pendingColdStart = intentReq;
            _recordHistory(intentReq);
          }
        }
      } catch (e) {
        debugPrint('[ExternalLaunch] getInitialLaunch skipped/unsupported: $e');
      }
    }

    if (Platform.isWindows) {
      unawaited(checkWindowsFileAssociations());
    }
    notifyListeners();
  }

  Future<void> _handlePlatformMethodCall(MethodCall call) async {
    if (call.method == 'onExternalLaunch' && call.arguments is Map) {
      final req =
          ExternalLaunchParser.fromPlatformPayload(call.arguments as Map);
      if (req != null) {
        _dispatchWarmLaunch(req);
      }
    }
  }

  /// Returns and clears the cold-start launch request once the app navigator is ready.
  ExternalLaunchRequest? consumePendingColdStart() {
    final req = _pendingColdStart;
    _pendingColdStart = null;
    return req;
  }

  /// Parses and dispatches a simulated or manual path/URI launch for Studio verification.
  ExternalLaunchRequest? triggerSimulatedLaunch(
    String rawTarget, {
    String sourcePlatform = 'studio_simulator',
  }) {
    final normalized = ExternalLaunchParser.normalizeInputTarget(rawTarget);
    if (normalized.isEmpty) return null;

    final req = ExternalLaunchRequest(
      uri: normalized,
      displayName: ExternalLaunchParser.extractDisplayName(normalized),
      kind: ExternalLaunchParser.classifyTarget(normalized),
      sourcePlatform: sourcePlatform,
    );
    _dispatchWarmLaunch(req);
    return req;
  }

  void _dispatchWarmLaunch(ExternalLaunchRequest req) {
    _recordHistory(req);
    if (!_launchStreamController.isClosed) {
      _launchStreamController.add(req);
    }
    notifyListeners();
  }

  void _recordHistory(ExternalLaunchRequest req) {
    _history.insert(0, req);
    if (_history.length > maxHistoryEntries) {
      _history.removeRange(maxHistoryEntries, _history.length);
    }
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _singleInstanceMode = prefs.getBool(_kPrefSingleInstance) ?? true;
      _autoPlayStreams = prefs.getBool(_kPrefAutoPlayStreams) ?? true;
      final behaviorIdx = prefs.getInt(_kPrefWarmBehavior) ?? 0;
      if (behaviorIdx >= 0 && behaviorIdx < WarmLaunchBehavior.values.length) {
        _warmLaunchBehavior = WarmLaunchBehavior.values[behaviorIdx];
      }
    } catch (_) {}
  }

  Future<void> setSingleInstanceMode(bool enabled) async {
    _singleInstanceMode = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefSingleInstance, enabled);
      if (Platform.isWindows) {
        await _processRunner('reg', [
          'add',
          r'HKCU\Software\E-Player',
          '/v',
          'SingleInstance',
          '/t',
          'REG_DWORD',
          '/d',
          enabled ? '1' : '0',
          '/f',
        ]);
      }
    } catch (_) {}
  }

  Future<void> setWarmLaunchBehavior(WarmLaunchBehavior behavior) async {
    _warmLaunchBehavior = behavior;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefWarmBehavior, behavior.index);
    } catch (_) {}
  }

  Future<void> setAutoPlayStreams(bool enabled) async {
    _autoPlayStreams = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefAutoPlayStreams, enabled);
    } catch (_) {}
  }

  OsIntegrationDiagnostics getDiagnostics() {
    return OsIntegrationDiagnostics(
      platformName: Platform.operatingSystem,
      androidManifestIntentReady: true,
      windowsCliArgsReady: true,
      windowsSingleInstanceIpcReady: _singleInstanceMode,
      windowsFileAssociationRegistered: _windowsFileAssocRegistered,
      registeredExtensions: ExternalLaunchParser.associableExtensions,
    );
  }

  /// Checks whether E-Player.exe is registered under `HKCU\Software\Classes\Applications\E-Player.exe`.
  Future<bool> checkWindowsFileAssociations() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await _processRunner('reg', [
        'query',
        r'HKCU\Software\Classes\Applications\E-Player.exe\shell\open\command',
      ]);
      _windowsFileAssocRegistered = result.exitCode == 0;
      notifyListeners();
      return _windowsFileAssocRegistered;
    } catch (_) {
      return false;
    }
  }

  /// Registers per-user Windows Explorer "Open With" associations (`HKCU\Software\Classes`, no UAC required).
  Future<bool> registerWindowsFileAssociations({String? customExePath}) async {
    if (!Platform.isWindows && customExePath == null) return false;
    _isBusyUpdatingRegistry = true;
    notifyListeners();

    try {
      final exePath = customExePath ?? Platform.resolvedExecutable;
      final openCommand = '"$exePath" "%1"';

      final appRes = await _processRunner('reg', [
        'add',
        r'HKCU\Software\Classes\Applications\E-Player.exe\shell\open\command',
        '/ve',
        '/t',
        'REG_SZ',
        '/d',
        openCommand,
        '/f',
      ]);
      if (appRes.exitCode != 0) {
        _windowsFileAssocRegistered = false;
        return false;
      }

      await _processRunner('reg', [
        'add',
        r'HKCU\Software\Classes\Applications\E-Player.exe',
        '/v',
        'FriendlyAppName',
        '/t',
        'REG_SZ',
        '/d',
        'E-Player Media Studio',
        '/f',
      ]);

      await _processRunner('reg', [
        'add',
        r'HKCU\Software\Classes\EPlayer.MediaFile\shell\open\command',
        '/ve',
        '/t',
        'REG_SZ',
        '/d',
        openCommand,
        '/f',
      ]);

      for (final ext in ExternalLaunchParser.associableExtensions) {
        await _processRunner('reg', [
          'add',
          'HKCU\\Software\\Classes\\$ext\\OpenWithProgids',
          '/v',
          'EPlayer.MediaFile',
          '/t',
          'REG_NONE',
          '/f',
        ]);
        await _processRunner('reg', [
          'add',
          'HKCU\\Software\\Classes\\Applications\\E-Player.exe\\SupportedTypes',
          '/v',
          ext,
          '/t',
          'REG_SZ',
          '/d',
          '',
          '/f',
        ]);
      }

      _windowsFileAssocRegistered = true;
      return true;
    } catch (e) {
      debugPrint('[ExternalLaunch] Failed to register Windows file associations: $e');
      return false;
    } finally {
      _isBusyUpdatingRegistry = false;
      notifyListeners();
    }
  }

  /// Removes E-Player per-user "Open With" entries cleanly.
  Future<bool> unregisterWindowsFileAssociations({bool bypassPlatformCheck = false}) async {
    if (!Platform.isWindows && !bypassPlatformCheck) return false;
    _isBusyUpdatingRegistry = true;
    notifyListeners();

    try {
      await _processRunner('reg', [
        'delete',
        r'HKCU\Software\Classes\Applications\E-Player.exe',
        '/f',
      ]);
      await _processRunner('reg', [
        'delete',
        r'HKCU\Software\Classes\EPlayer.MediaFile',
        '/f',
      ]);
      for (final ext in ExternalLaunchParser.associableExtensions) {
        await _processRunner('reg', [
          'delete',
          'HKCU\\Software\\Classes\\$ext\\OpenWithProgids',
          '/v',
          'EPlayer.MediaFile',
          '/f',
        ]);
      }
      _windowsFileAssocRegistered = false;
      return true;
    } catch (e) {
      debugPrint('[ExternalLaunch] Failed to unregister Windows file associations: $e');
      return false;
    } finally {
      _isBusyUpdatingRegistry = false;
      notifyListeners();
    }
  }

  void _disposeInternal() {
    if (!_launchStreamController.isClosed) {
      _launchStreamController.close();
    }
  }
}
