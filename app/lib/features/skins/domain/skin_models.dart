library;

import 'package:flutter/material.dart';

/// Available skin aesthetics (VLC Skins2 module parity).
enum SkinThemePreset {
  cyberpunkNeon(
    label: 'Cyberpunk Neon',
    tagline: 'Deep navy, electric cyan & purple glow (Default)',
    icon: Icons.electric_bolt_rounded,
  ),
  classicMetallic(
    label: 'Classic VLC & Winamp',
    tagline: 'Brushed aluminum slate with VLC cone orange & green LED',
    icon: Icons.album_rounded,
  ),
  minimalistObsidian(
    label: 'Minimalist Obsidian',
    tagline: 'Pure pitch black OLED #000000 with crisp white accents',
    icon: Icons.dark_mode_rounded,
  ),
  retroAmberCrt(
    label: 'Retro Amber CRT',
    tagline: 'Vintage terminal phosphor amber with monospace aesthetic',
    icon: Icons.terminal_rounded,
  ),
  cupertinoGlass(
    label: 'Cupertino Glass',
    tagline: 'Translucent frosted acrylic with macOS sapphire pill styling',
    icon: Icons.blur_on_rounded,
  );

  final String label;
  final String tagline;
  final IconData icon;

  const SkinThemePreset({
    required this.label,
    required this.tagline,
    required this.icon,
  });
}

enum SkinHudStyle {
  roundedGlow,
  metallicBevel,
  flatSharp,
  phosphorTerminal,
  glassPill,
}

/// Comprehensive color tokens and styling parameters for a player skin.
class SkinThemeData {
  final SkinThemePreset preset;
  final String name;
  final String description;
  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color border;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color vlcConeOrange;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final double borderRadius;
  final SkinHudStyle hudStyle;
  final bool hasScanlines;

  const SkinThemeData({
    required this.preset,
    required this.name,
    required this.description,
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.border,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.vlcConeOrange,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderRadius,
    required this.hudStyle,
    this.hasScanlines = false,
  });

  factory SkinThemeData.fromPreset(SkinThemePreset preset) {
    switch (preset) {
      case SkinThemePreset.cyberpunkNeon:
        return const SkinThemeData(
          preset: SkinThemePreset.cyberpunkNeon,
          name: 'Cyberpunk Neon',
          description: 'Electric cyan and neon purple against high-contrast navy',
          background: Color(0xFF050B16),
          surface: Color(0xFF0D1728),
          elevatedSurface: Color(0xFF12213A),
          border: Color(0xFF1B3556),
          primaryAccent: Color(0xFF00E5FF),
          secondaryAccent: Color(0xFF7B42FF),
          vlcConeOrange: Color(0xFFFF8800),
          textPrimary: Color(0xFFF5F8FF),
          textSecondary: Color(0xFFA7B5CA),
          textMuted: Color(0xFF6E7E95),
          borderRadius: 14.0,
          hudStyle: SkinHudStyle.roundedGlow,
        );

      case SkinThemePreset.classicMetallic:
        return const SkinThemeData(
          preset: SkinThemePreset.classicMetallic,
          name: 'Classic VLC & Winamp',
          description: 'Brushed metal chassis, Winamp LED meters, and cone orange',
          background: Color(0xFF222428),
          surface: Color(0xFF2B2D32),
          elevatedSurface: Color(0xFF383A40),
          border: Color(0xFF50535B),
          primaryAccent: Color(0xFFFF8800),
          secondaryAccent: Color(0xFF00FF66),
          vlcConeOrange: Color(0xFFFF6600),
          textPrimary: Color(0xFFEDEDED),
          textSecondary: Color(0xFFB0B3B8),
          textMuted: Color(0xFF7C8088),
          borderRadius: 6.0,
          hudStyle: SkinHudStyle.metallicBevel,
        );

      case SkinThemePreset.minimalistObsidian:
        return const SkinThemeData(
          preset: SkinThemePreset.minimalistObsidian,
          name: 'Minimalist Obsidian',
          description: 'Zero-distraction pure OLED pitch black and monochrome accents',
          background: Color(0xFF000000),
          surface: Color(0xFF0C0C0C),
          elevatedSurface: Color(0xFF161616),
          border: Color(0xFF242424),
          primaryAccent: Color(0xFFFFFFFF),
          secondaryAccent: Color(0xFF888888),
          vlcConeOrange: Color(0xFFFF9900),
          textPrimary: Color(0xFFFFFFFF),
          textSecondary: Color(0xFFA0A0A0),
          textMuted: Color(0xFF555555),
          borderRadius: 8.0,
          hudStyle: SkinHudStyle.flatSharp,
        );

      case SkinThemePreset.retroAmberCrt:
        return const SkinThemeData(
          preset: SkinThemePreset.retroAmberCrt,
          name: 'Retro Amber CRT',
          description: 'Monochrome terminal amber phosphor glow with scanlines',
          background: Color(0xFF0A0F0A),
          surface: Color(0xFF101910),
          elevatedSurface: Color(0xFF182418),
          border: Color(0xFF2E4D2E),
          primaryAccent: Color(0xFFFFB000),
          secondaryAccent: Color(0xFFFF8000),
          vlcConeOrange: Color(0xFFFF9400),
          textPrimary: Color(0xFFFFB000),
          textSecondary: Color(0xFFCC8C00),
          textMuted: Color(0xFF805800),
          borderRadius: 12.0,
          hudStyle: SkinHudStyle.phosphorTerminal,
          hasScanlines: true,
        );

      case SkinThemePreset.cupertinoGlass:
        return const SkinThemeData(
          preset: SkinThemePreset.cupertinoGlass,
          name: 'Cupertino Glass',
          description: 'Frosted acrylic sapphire with Apple fluid rounded corners',
          background: Color(0xFF14171F),
          surface: Color(0xFF1C2230),
          elevatedSurface: Color(0xFF252D3F),
          border: Color(0xFF38455E),
          primaryAccent: Color(0xFF0A84FF),
          secondaryAccent: Color(0xFF5E5CE6),
          vlcConeOrange: Color(0xFFFF9F0A),
          textPrimary: Color(0xFFFFFFFF),
          textSecondary: Color(0xFF98989D),
          textMuted: Color(0xFF636366),
          borderRadius: 20.0,
          hudStyle: SkinHudStyle.glassPill,
        );
    }
  }

  /// Converts this skin palette into a complete Material 3 ThemeData.
  ThemeData toThemeData() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      colorScheme: base.colorScheme.copyWith(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: surface,
        error: const Color(0xFFFF5C72),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: primaryAccent,
        inactiveTrackColor: border,
        thumbColor: textPrimary,
        overlayColor: primaryAccent.withValues(alpha: 0.2),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: border),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 15, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 13, color: textSecondary),
        bodySmall: TextStyle(fontSize: 11, color: textMuted),
      ),
    );
  }
}
