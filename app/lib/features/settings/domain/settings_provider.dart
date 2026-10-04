import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // Defaults
  bool _hwAcceleration = true;
  String _decodingMode = 'HW+';
  String _aspectRatio = 'Fit';
  String _playbackSpeed = '1.0x';
  bool _gestureControls = true;
  String _fontSize = 'Medium';
  String _textColor = 'White';
  String _outline = '2px';

  // Getters
  bool get hwAcceleration => _hwAcceleration;
  String get decodingMode => _decodingMode;
  String get aspectRatio => _aspectRatio;
  String get playbackSpeed => _playbackSpeed;
  bool get gestureControls => _gestureControls;
  String get fontSize => _fontSize;
  String get textColor => _textColor;
  String get outline => _outline;

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
    _fontSize = _prefs?.getString('fontSize') ?? 'Medium';
    _textColor = _prefs?.getString('textColor') ?? 'White';
    _outline = _prefs?.getString('outline') ?? '2px';
    
    notifyListeners();
  }

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
}
