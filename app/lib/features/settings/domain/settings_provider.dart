import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // Video & Engine Defaults
  bool _hwAcceleration = true;
  String _decodingMode = 'HW+';
  String _aspectRatio = 'Fit';
  String _playbackSpeed = '1.0x';
  bool _gestureControls = true;
  bool _zeroCopyGpu = true;
  bool _dynamicResSwitching = true;

  // AI Enhancement Defaults
  String _defaultAiModel = 'Real-ESRGAN x4 Plus';
  bool _rifeDefault = false;
  String _tensorPrecision = 'FP16 Compute';
  String _vramLimit = '4.0 GB';

  // Audio DSP Defaults
  String _defaultAudioPreset = 'Flat';
  bool _speechClarity = true;
  bool _spatialVirtualizer = false;
  String _audioOutputFormat = 'Stereo (2.0)';

  // Subtitle Defaults
  String _fontSize = 'Medium';
  String _textColor = 'White';
  String _outline = '2px';
  String _subtitleLanguage = 'English [en]';
  bool _autoEncoding = true;
  bool _dualPassOutline = true;

  // Network & Stream Defaults
  bool _lowLatencyRtsp = true;
  String _networkBufferSize = '32 MB';

  // Vault & Security Defaults
  bool _decoyModeEnabled = true;
  bool _autoLockVault = true;
  bool _biometricsEnabled = true;

  // Diagnostics & Cache
  double _shaderCacheMb = 24.8;
  double _aiTempCacheMb = 142.0;

  // Getters
  bool get hwAcceleration => _hwAcceleration;
  String get decodingMode => _decodingMode;
  String get aspectRatio => _aspectRatio;
  String get playbackSpeed => _playbackSpeed;
  bool get gestureControls => _gestureControls;
  bool get zeroCopyGpu => _zeroCopyGpu;
  bool get dynamicResSwitching => _dynamicResSwitching;

  String get defaultAiModel => _defaultAiModel;
  bool get rifeDefault => _rifeDefault;
  String get tensorPrecision => _tensorPrecision;
  String get vramLimit => _vramLimit;

  String get defaultAudioPreset => _defaultAudioPreset;
  bool get speechClarity => _speechClarity;
  bool get spatialVirtualizer => _spatialVirtualizer;
  String get audioOutputFormat => _audioOutputFormat;

  String get fontSize => _fontSize;
  String get textColor => _textColor;
  String get outline => _outline;
  String get subtitleLanguage => _subtitleLanguage;
  bool get autoEncoding => _autoEncoding;
  bool get dualPassOutline => _dualPassOutline;

  bool get lowLatencyRtsp => _lowLatencyRtsp;
  String get networkBufferSize => _networkBufferSize;

  bool get decoyModeEnabled => _decoyModeEnabled;
  bool get autoLockVault => _autoLockVault;
  bool get biometricsEnabled => _biometricsEnabled;

  double get shaderCacheMb => _shaderCacheMb;
  double get aiTempCacheMb => _aiTempCacheMb;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _hwAcceleration = _prefs?.getBool('hwAcceleration') ?? true;
    _decodingMode = _prefs?.getString('decodingMode') ?? 'HW+';
    _aspectRatio = _prefs?.getString('aspectRatio') ?? 'Fit';
    _playbackSpeed = _prefs?.getString('playbackSpeed') ?? '1.0x';
    _gestureControls = _prefs?.getBool('gestureControls') ?? true;
    _zeroCopyGpu = _prefs?.getBool('zeroCopyGpu') ?? true;
    _dynamicResSwitching = _prefs?.getBool('dynamicResSwitching') ?? true;

    _defaultAiModel = _prefs?.getString('defaultAiModel') ?? 'Real-ESRGAN x4 Plus';
    _rifeDefault = _prefs?.getBool('rifeDefault') ?? false;
    _tensorPrecision = _prefs?.getString('tensorPrecision') ?? 'FP16 Compute';
    _vramLimit = _prefs?.getString('vramLimit') ?? '4.0 GB';

    _defaultAudioPreset = _prefs?.getString('defaultAudioPreset') ?? 'Flat';
    _speechClarity = _prefs?.getBool('speechClarity') ?? true;
    _spatialVirtualizer = _prefs?.getBool('spatialVirtualizer') ?? false;
    _audioOutputFormat = _prefs?.getString('audioOutputFormat') ?? 'Stereo (2.0)';

    _fontSize = _prefs?.getString('fontSize') ?? 'Medium';
    _textColor = _prefs?.getString('textColor') ?? 'White';
    _outline = _prefs?.getString('outline') ?? '2px';
    _subtitleLanguage = _prefs?.getString('subtitleLanguage') ?? 'English [en]';
    _autoEncoding = _prefs?.getBool('autoEncoding') ?? true;
    _dualPassOutline = _prefs?.getBool('dualPassOutline') ?? true;

    _lowLatencyRtsp = _prefs?.getBool('lowLatencyRtsp') ?? true;
    _networkBufferSize = _prefs?.getString('networkBufferSize') ?? '32 MB';

    _decoyModeEnabled = _prefs?.getBool('decoyModeEnabled') ?? true;
    _autoLockVault = _prefs?.getBool('autoLockVault') ?? true;
    _biometricsEnabled = _prefs?.getBool('biometricsEnabled') ?? true;

    notifyListeners();
  }

  // Setters
  Future<void> setHwAcceleration(bool val) async {
    _hwAcceleration = val;
    await _prefs?.setBool('hwAcceleration', val);
    notifyListeners();
  }

  Future<void> setDecodingMode(String val) async {
    _decodingMode = val;
    await _prefs?.setString('decodingMode', val);
    notifyListeners();
  }

  Future<void> setAspectRatio(String val) async {
    _aspectRatio = val;
    await _prefs?.setString('aspectRatio', val);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(String val) async {
    _playbackSpeed = val;
    await _prefs?.setString('playbackSpeed', val);
    notifyListeners();
  }

  Future<void> setGestureControls(bool val) async {
    _gestureControls = val;
    await _prefs?.setBool('gestureControls', val);
    notifyListeners();
  }

  Future<void> setZeroCopyGpu(bool val) async {
    _zeroCopyGpu = val;
    await _prefs?.setBool('zeroCopyGpu', val);
    notifyListeners();
  }

  Future<void> setDynamicResSwitching(bool val) async {
    _dynamicResSwitching = val;
    await _prefs?.setBool('dynamicResSwitching', val);
    notifyListeners();
  }

  Future<void> setDefaultAiModel(String val) async {
    _defaultAiModel = val;
    await _prefs?.setString('defaultAiModel', val);
    notifyListeners();
  }

  Future<void> setRifeDefault(bool val) async {
    _rifeDefault = val;
    await _prefs?.setBool('rifeDefault', val);
    notifyListeners();
  }

  Future<void> setTensorPrecision(String val) async {
    _tensorPrecision = val;
    await _prefs?.setString('tensorPrecision', val);
    notifyListeners();
  }

  Future<void> setVramLimit(String val) async {
    _vramLimit = val;
    await _prefs?.setString('vramLimit', val);
    notifyListeners();
  }

  Future<void> setDefaultAudioPreset(String val) async {
    _defaultAudioPreset = val;
    await _prefs?.setString('defaultAudioPreset', val);
    notifyListeners();
  }

  Future<void> setSpeechClarity(bool val) async {
    _speechClarity = val;
    await _prefs?.setBool('speechClarity', val);
    notifyListeners();
  }

  Future<void> setSpatialVirtualizer(bool val) async {
    _spatialVirtualizer = val;
    await _prefs?.setBool('spatialVirtualizer', val);
    notifyListeners();
  }

  Future<void> setAudioOutputFormat(String val) async {
    _audioOutputFormat = val;
    await _prefs?.setString('audioOutputFormat', val);
    notifyListeners();
  }

  Future<void> setFontSize(String val) async {
    _fontSize = val;
    await _prefs?.setString('fontSize', val);
    notifyListeners();
  }

  Future<void> setTextColor(String val) async {
    _textColor = val;
    await _prefs?.setString('textColor', val);
    notifyListeners();
  }

  Future<void> setOutline(String val) async {
    _outline = val;
    await _prefs?.setString('outline', val);
    notifyListeners();
  }

  Future<void> setSubtitleLanguage(String val) async {
    _subtitleLanguage = val;
    await _prefs?.setString('subtitleLanguage', val);
    notifyListeners();
  }

  Future<void> setAutoEncoding(bool val) async {
    _autoEncoding = val;
    await _prefs?.setBool('autoEncoding', val);
    notifyListeners();
  }

  Future<void> setDualPassOutline(bool val) async {
    _dualPassOutline = val;
    await _prefs?.setBool('dualPassOutline', val);
    notifyListeners();
  }

  Future<void> setLowLatencyRtsp(bool val) async {
    _lowLatencyRtsp = val;
    await _prefs?.setBool('lowLatencyRtsp', val);
    notifyListeners();
  }

  Future<void> setNetworkBufferSize(String val) async {
    _networkBufferSize = val;
    await _prefs?.setString('networkBufferSize', val);
    notifyListeners();
  }

  Future<void> setDecoyModeEnabled(bool val) async {
    _decoyModeEnabled = val;
    await _prefs?.setBool('decoyModeEnabled', val);
    notifyListeners();
  }

  Future<void> setAutoLockVault(bool val) async {
    _autoLockVault = val;
    await _prefs?.setBool('autoLockVault', val);
    notifyListeners();
  }

  Future<void> setBiometricsEnabled(bool val) async {
    _biometricsEnabled = val;
    await _prefs?.setBool('biometricsEnabled', val);
    notifyListeners();
  }

  Future<void> clearShaderCache() async {
    _shaderCacheMb = 0.0;
    notifyListeners();
  }

  Future<void> clearAiTempCache() async {
    _aiTempCacheMb = 0.0;
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await _prefs?.clear();
    _hwAcceleration = true;
    _decodingMode = 'HW+';
    _aspectRatio = 'Fit';
    _playbackSpeed = '1.0x';
    _gestureControls = true;
    _zeroCopyGpu = true;
    _dynamicResSwitching = true;
    _defaultAiModel = 'Real-ESRGAN x4 Plus';
    _rifeDefault = false;
    _tensorPrecision = 'FP16 Compute';
    _vramLimit = '4.0 GB';
    _defaultAudioPreset = 'Flat';
    _speechClarity = true;
    _spatialVirtualizer = false;
    _audioOutputFormat = 'Stereo (2.0)';
    _fontSize = 'Medium';
    _textColor = 'White';
    _outline = '2px';
    _subtitleLanguage = 'English [en]';
    _autoEncoding = true;
    _dualPassOutline = true;
    _lowLatencyRtsp = true;
    _networkBufferSize = '32 MB';
    _decoyModeEnabled = true;
    _autoLockVault = true;
    _biometricsEnabled = true;
    _shaderCacheMb = 0.0;
    _aiTempCacheMb = 0.0;
    notifyListeners();
  }
}
