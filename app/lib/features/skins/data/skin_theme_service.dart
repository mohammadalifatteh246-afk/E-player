library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/skin_models.dart';

/// Central skin and theme state controller (VLC Skins2 module parity).
/// Persists user skin preference across restarts and broadcasts dynamic theme updates.
class SkinThemeService extends ChangeNotifier {
  static const String skinPrefKey = 'e_player_active_skin';

  SharedPreferences? _prefs;
  late SkinThemeData _currentSkin;

  SkinThemeService({SharedPreferences? prefs}) {
    _currentSkin = SkinThemeData.fromPreset(SkinThemePreset.cyberpunkNeon);
    if (prefs != null) {
      _prefs = prefs;
      _loadFromPrefs();
    } else {
      _initPrefs();
    }
  }

  SkinThemeData get currentSkin => _currentSkin;
  SkinThemePreset get currentPreset => _currentSkin.preset;
  ThemeData get themeData => _currentSkin.toThemeData();

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadFromPrefs();
    } catch (e) {
      debugPrint('[SkinThemeService] Failed to load SharedPreferences: $e');
    }
  }

  void _loadFromPrefs() {
    final savedName = _prefs?.getString(skinPrefKey);
    if (savedName != null) {
      final matchingPreset = SkinThemePreset.values.firstWhere(
        (p) => p.name == savedName,
        orElse: () => SkinThemePreset.cyberpunkNeon,
      );
      _currentSkin = SkinThemeData.fromPreset(matchingPreset);
      notifyListeners();
    }
  }

  /// Sets the active skin and persists choice to disk.
  Future<void> setSkin(SkinThemePreset preset) async {
    if (_currentSkin.preset == preset) return;

    _currentSkin = SkinThemeData.fromPreset(preset);
    notifyListeners();

    try {
      await _prefs?.setString(skinPrefKey, preset.name);
    } catch (e) {
      debugPrint('[SkinThemeService] Failed to save skin choice: $e');
    }
  }

  /// Reverts skin back to default Cyberpunk Neon.
  Future<void> resetToDefault() async {
    await setSkin(SkinThemePreset.cyberpunkNeon);
  }
}
