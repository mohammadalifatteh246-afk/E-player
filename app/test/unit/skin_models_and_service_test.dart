import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/skins/domain/skin_models.dart';
import 'package:app/features/skins/data/skin_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modern Classic Skin Models & Presets (VLC Skins2 Parity)', () {
    test('All 5 presets have distinct color palettes and valid ThemeData', () {
      expect(SkinThemePreset.values.length, 5);

      for (final preset in SkinThemePreset.values) {
        final data = SkinThemeData.fromPreset(preset);
        expect(data.name, isNotEmpty);
        expect(data.description, isNotEmpty);
        expect(data.background, isNotNull);
        expect(data.surface, isNotNull);
        expect(data.primaryAccent, isNotNull);
        expect(data.vlcConeOrange, isNotNull);
        expect(data.borderRadius, greaterThan(0));

        final theme = data.toThemeData();
        expect(theme.brightness, Brightness.dark);
        expect(theme.scaffoldBackgroundColor, data.background);
        expect(theme.colorScheme.primary, data.primaryAccent);
      }
    });

    test('Cyberpunk Neon default matches Stitch V3 high-contrast navy', () {
      final data = SkinThemeData.fromPreset(SkinThemePreset.cyberpunkNeon);
      expect(data.background, const Color(0xFF050B16));
      expect(data.primaryAccent, const Color(0xFF00E5FF));
      expect(data.hudStyle, SkinHudStyle.roundedGlow);
    });

    test('Classic VLC & Winamp has metallic grey and cone orange tokens', () {
      final data = SkinThemeData.fromPreset(SkinThemePreset.classicMetallic);
      expect(data.background, const Color(0xFF222428));
      expect(data.primaryAccent, const Color(0xFFFF8800));
      expect(data.secondaryAccent, const Color(0xFF00FF66)); // Winamp LED green
      expect(data.borderRadius, 6.0);
      expect(data.hudStyle, SkinHudStyle.metallicBevel);
    });

    test('Minimalist Obsidian has OLED pitch black #000000', () {
      final data = SkinThemeData.fromPreset(SkinThemePreset.minimalistObsidian);
      expect(data.background, const Color(0xFF000000));
      expect(data.primaryAccent, const Color(0xFFFFFFFF));
      expect(data.hudStyle, SkinHudStyle.flatSharp);
    });

    test('Retro Amber CRT has amber phosphor text and scanlines flag', () {
      final data = SkinThemeData.fromPreset(SkinThemePreset.retroAmberCrt);
      expect(data.primaryAccent, const Color(0xFFFFB000));
      expect(data.textPrimary, const Color(0xFFFFB000));
      expect(data.hasScanlines, isTrue);
      expect(data.hudStyle, SkinHudStyle.phosphorTerminal);
    });

    test('Cupertino Glass has frosted sapphire and pill curvature', () {
      final data = SkinThemeData.fromPreset(SkinThemePreset.cupertinoGlass);
      expect(data.background, const Color(0xFF14171F));
      expect(data.primaryAccent, const Color(0xFF0A84FF));
      expect(data.borderRadius, 20.0);
      expect(data.hudStyle, SkinHudStyle.glassPill);
    });
  });

  group('SkinThemeService State & SharedPreferences Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads default cyberpunkNeon on fresh start', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SkinThemeService(prefs: prefs);

      expect(service.currentPreset, SkinThemePreset.cyberpunkNeon);
      expect(service.currentSkin.name, 'Cyberpunk Neon');
    });

    test('setSkin updates preset, notifies listeners, and persists to disk', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SkinThemeService(prefs: prefs);

      var notified = false;
      service.addListener(() => notified = true);

      await service.setSkin(SkinThemePreset.classicMetallic);

      expect(service.currentPreset, SkinThemePreset.classicMetallic);
      expect(service.currentSkin.name, 'Classic VLC & Winamp');
      expect(notified, isTrue);
      expect(prefs.getString(SkinThemeService.skinPrefKey), 'classicMetallic');

      // Next session restores saved choice
      final newService = SkinThemeService(prefs: prefs);
      expect(newService.currentPreset, SkinThemePreset.classicMetallic);
    });

    test('resetToDefault reverts to cyberpunkNeon', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SkinThemeService(prefs: prefs);

      await service.setSkin(SkinThemePreset.retroAmberCrt);
      expect(service.currentPreset, SkinThemePreset.retroAmberCrt);

      await service.resetToDefault();
      expect(service.currentPreset, SkinThemePreset.cyberpunkNeon);
      expect(prefs.getString(SkinThemeService.skinPrefKey), 'cyberpunkNeon');
    });
  });
}
