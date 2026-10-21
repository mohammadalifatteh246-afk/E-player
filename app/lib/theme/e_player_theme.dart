import 'package:flutter/material.dart';
import 'e_player_colors.dart';

/// Starter dark theme. Merge into the existing application theme rather than
/// replacing routing, localization, or other project-specific configuration.
abstract final class EPlayerTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: EPlayerColors.background,
      canvasColor: EPlayerColors.background,
      dividerColor: EPlayerColors.border,
      colorScheme: base.colorScheme.copyWith(
        primary: EPlayerColors.primary,
        secondary: EPlayerColors.purple,
        surface: EPlayerColors.surface,
        error: EPlayerColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: EPlayerColors.background,
        foregroundColor: EPlayerColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: EPlayerColors.textPrimary),
        headlineMedium: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: EPlayerColors.textPrimary),
        titleLarge: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: EPlayerColors.textPrimary),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: EPlayerColors.textPrimary),
        bodyLarge: const TextStyle(fontSize: 15, color: EPlayerColors.textPrimary),
        bodyMedium: const TextStyle(fontSize: 13, color: EPlayerColors.textSecondary),
        bodySmall: const TextStyle(fontSize: 11, color: EPlayerColors.textMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EPlayerColors.surfaceElevated,
        hintStyle: const TextStyle(color: EPlayerColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EPlayerColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EPlayerColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EPlayerColors.primary, width: 1.5)),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: EPlayerColors.primary,
        inactiveTrackColor: EPlayerColors.border,
        thumbColor: EPlayerColors.textPrimary,
        overlayColor: EPlayerColors.primary.withValues(alpha: .18),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: EPlayerColors.backgroundElevated,
        indicatorColor: Color(0x3319BFFF),
        elevation: 0,
      ),
    );
  }
}
