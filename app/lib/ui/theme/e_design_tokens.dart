import 'package:flutter/material.dart';

/// E-Player V3 Stitch Design System Tokens
/// Source of Truth: stitch/E_PLAYER_STITCH_UIUX_PACK/.stitch/DESIGN.md
class EDesign {
  EDesign._();

  // --- Colors (DESIGN.md) ---
  static const Color appBackground = Color(0xFF050B16);
  static const Color elevatedBackground = Color(0xFF091222);
  static const Color surface = Color(0xFF0D1728);
  static const Color elevatedSurface = Color(0xFF12213A);
  static const Color border = Color(0xFF1B3556);

  static const Color primary = Color(0xFF19BFFF);
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryStrong = Color(0xFF1468FF);
  static const Color secondary = Color(0xFF7B42FF);
  static const Color aiAccent = Color(0xFFE741FF);

  static const Color success = Color(0xFF21D79A);
  static const Color warning = Color(0xFFFFB547);
  static const Color danger = Color(0xFFFF5C72);

  static const Color textPrimary = Color(0xFFF5F8FF);
  static const Color textSecondary = Color(0xFFA7B5CA);
  static const Color textMuted = Color(0xFF6E7E95);
  static const Color disabled = Color(0xFF45546A);

  // --- Radii (DESIGN.md: 6 / 10 / 14 / 18 / 24px) ---
  static const double r6 = 6.0;
  static const double r10 = 10.0;
  static const double r14 = 14.0;
  static const double r18 = 18.0;
  static const double r24 = 24.0;

  // --- Spacing (DESIGN.md: base unit 4px -> 4/8/12/16/20/24/32) ---
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  // --- Typography (DESIGN.md) ---
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFamily: 'Inter',
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFamily: 'Inter',
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFamily: 'Inter',
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: 'Inter',
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    fontFamily: 'Inter',
  );

  static const TextStyle secondaryStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    fontFamily: 'Inter',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textMuted,
    fontFamily: 'Inter',
  );

  // --- Reusable Decorations ---
  static BoxDecoration cardDecoration({
    Color color = surface,
    Color borderColor = border,
    double radius = r14,
    bool withGlow = false,
    Color glowColor = primary,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: withGlow
          ? [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  static Widget buildBadge(
    String label, {
    Color color = primary,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(r6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < suffixes.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${suffixes[unitIndex]}';
  }
}
