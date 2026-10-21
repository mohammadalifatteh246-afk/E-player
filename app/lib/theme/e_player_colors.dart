import 'package:flutter/material.dart';

/// Central brand tokens for E-Player. Keep colors centralized to preserve visual consistency.
abstract final class EPlayerColors {
  static const background = Color(0xFF050B16);
  static const backgroundElevated = Color(0xFF091222);
  static const surface = Color(0xFF0D1728);
  static const surfaceElevated = Color(0xFF12213A);
  static const border = Color(0xFF1B3556);
  static const primary = Color(0xFF19BFFF);
  static const blue = Color(0xFF1468FF);
  static const purple = Color(0xFF7B42FF);
  static const magenta = Color(0xFFE741FF);
  static const success = Color(0xFF21D79A);
  static const warning = Color(0xFFFFB547);
  static const danger = Color(0xFFFF5C72);
  static const info = Color(0xFF48A8FF);
  static const textPrimary = Color(0xFFF5F8FF);
  static const textSecondary = Color(0xFFA7B5CA);
  static const textMuted = Color(0xFF6E7E95);
  static const textDisabled = Color(0xFF45546A);
  static const brandGradient = LinearGradient(
    colors: [primary, blue, purple, magenta],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
