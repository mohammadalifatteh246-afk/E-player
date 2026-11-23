import 'package:flutter/material.dart';

/// 4-tier smooth color transition resolver for E-Player Celestial Moon Phase Brightness HUD:
/// - Tier 1 (0% to 25%): Deep Lunar Night Silver-Cyan (#94A3B8 -> #67E8F9)
/// - Tier 2 (25% to 50%): Twilight Dawn Gold (#67E8F9 -> #FBBF24)
/// - Tier 3 (50% to 80%): Solar Daylight Amber (#FBBF24 -> #F59E0B)
/// - Tier 4 (80% to 100%): Supernova White-Gold (#F59E0B -> #FFFFFF) with corona pulse
class CelestialColorResolver {
  static const Color lunarSilver = Color(0xFF94A3B8);
  static const Color lunarCyan = Color(0xFF67E8F9);
  static const Color twilightGold = Color(0xFFFBBF24);
  static const Color solarAmber = Color(0xFFF59E0B);
  static const Color supernovaWhite = Color(0xFFFFFFFF);

  /// Resolves the continuous interpolated color for brightness in [0.0, 100.0].
  static Color resolve(double brightness) {
    final b = brightness.clamp(0.0, 100.0);
    if (b <= 25.0) {
      final t = b / 25.0;
      return Color.lerp(lunarSilver, lunarCyan, t)!;
    } else if (b <= 50.0) {
      final t = (b - 25.0) / 25.0;
      return Color.lerp(lunarCyan, twilightGold, t)!;
    } else if (b <= 80.0) {
      final t = (b - 50.0) / 30.0;
      return Color.lerp(twilightGold, solarAmber, t)!;
    } else {
      final t = (b - 80.0) / 20.0;
      return Color.lerp(solarAmber, supernovaWhite, t)!;
    }
  }

  /// Resolves the celestial aura glow color with opacity scaled to current tier.
  static Color resolveGlow(double brightness) {
    final baseColor = resolve(brightness);
    final b = brightness.clamp(0.0, 100.0);
    final double alpha = b > 80.0 ? 0.90 : (b > 50.0 ? 0.75 : 0.55);
    return baseColor.withValues(alpha: alpha);
  }

  /// Status badge label for the current brightness level.
  static String resolveLabel(double brightness) {
    if (brightness > 80.0) return 'SUPERNOVA MAX';
    if (brightness > 50.0) return 'SOLAR DAYLIGHT';
    if (brightness > 25.0) return 'TWILIGHT DAWN';
    return 'LUNAR NIGHT';
  }
}

/// Custom Clipper for the 7-Phase Celestial Moon Arc silhouette.
/// Normalized from viewBox="0 0 200 640".
class CelestialArcClipper extends CustomClipper<Path> {
  const CelestialArcClipper();

  static const List<List<double>> phasePoints = [
    [54.7, 0.0, 62.1, 4.0, 71.6, 13.0, 76.8, 21.0, 80.0, 31.0, 78.9, 50.1, 74.7, 59.1, 64.2, 71.1, 53.7, 77.1, 43.2, 80.1, 30.5, 80.1, 18.9, 77.1, 11.6, 73.1, 0.0, 61.1, 3.2, 67.1, 11.6, 76.1, 17.9, 80.1, 30.5, 85.1, 36.8, 86.1, 52.6, 85.1, 68.4, 78.1, 78.9, 68.1, 86.3, 53.1, 87.4, 37.1, 84.2, 26.0, 80.0, 18.0, 70.5, 8.0],
    [132.6, 88.1, 134.7, 91.1, 137.9, 102.2, 137.9, 112.2, 135.8, 121.2, 129.5, 132.2, 116.8, 143.2, 108.4, 147.2, 98.9, 149.2, 83.2, 148.2, 76.8, 146.2, 66.3, 140.2, 60.0, 134.2, 56.8, 129.2, 58.9, 137.2, 62.1, 143.2, 74.7, 156.2, 87.4, 162.3, 105.3, 164.3, 121.1, 160.3, 128.4, 156.2, 138.9, 146.2, 146.3, 131.2, 147.4, 114.2, 142.1, 99.2],
    [172.6, 181.3, 167.4, 195.3, 160.0, 204.3, 152.6, 210.3, 137.9, 216.3, 122.1, 217.3, 121.1, 216.3, 112.6, 215.3, 102.1, 210.3, 93.7, 202.3, 92.6, 203.3, 92.6, 218.3, 95.8, 228.4, 103.2, 239.4, 112.6, 247.4, 123.2, 252.4, 131.6, 253.4, 132.6, 254.4, 149.5, 253.4, 165.3, 246.4, 177.9, 233.4, 181.1, 227.4, 183.2, 216.3, 184.2, 215.3, 183.2, 200.3, 176.8, 186.3],
    [148.4, 276.4, 136.8, 279.4, 128.4, 283.4, 115.8, 295.5, 111.6, 302.5, 108.4, 312.5, 108.4, 327.5, 114.7, 343.5, 125.3, 354.6, 131.6, 358.6, 142.1, 362.6, 145.3, 362.6, 146.3, 363.6, 161.1, 363.6, 162.1, 362.6, 169.5, 361.6, 180.0, 356.6, 192.6, 344.5, 198.9, 330.5, 200.0, 314.5, 196.8, 303.5, 193.7, 297.5, 181.1, 284.4, 171.6, 279.4, 165.3, 277.4],
    [103.2, 400.6, 94.7, 414.6, 92.6, 421.7, 92.6, 436.7, 93.7, 437.7, 101.1, 430.7, 113.7, 424.7, 124.2, 423.7, 125.3, 422.7, 131.6, 422.7, 132.6, 423.7, 141.1, 424.7, 154.7, 431.7, 164.2, 440.7, 170.5, 451.7, 171.6, 457.7, 172.6, 458.7, 176.8, 453.7, 183.2, 439.7, 184.2, 424.7, 183.2, 423.7, 182.1, 415.6, 178.9, 408.6, 174.7, 402.6, 166.3, 394.6, 151.6, 387.6, 143.2, 386.6, 142.1, 385.6, 134.7, 385.6, 133.7, 386.6, 128.4, 386.6, 121.1, 388.6, 111.6, 393.6],
    [72.6, 485.8, 65.3, 492.8, 61.1, 498.8, 56.8, 510.8, 61.1, 504.8, 69.5, 497.8, 84.2, 491.8, 96.8, 490.8, 97.9, 491.8, 107.4, 492.8, 114.7, 495.8, 121.1, 499.8, 128.4, 506.8, 132.6, 512.8, 136.8, 522.8, 137.9, 537.8, 134.7, 548.9, 132.6, 551.9, 141.1, 542.8, 144.2, 536.8, 147.4, 525.8, 146.3, 508.8, 144.2, 502.8, 137.9, 492.8, 126.3, 482.8, 110.5, 476.7, 92.6, 476.7, 85.3, 478.7],
    [27.4, 555.9, 14.7, 561.9, 4.2, 571.9, 0.0, 578.9, 10.5, 567.9, 20.0, 562.9, 32.6, 559.9, 41.1, 559.9, 52.6, 562.9, 61.1, 566.9, 72.6, 577.9, 77.9, 586.9, 80.0, 593.9, 80.0, 610.0, 77.9, 617.0, 72.6, 626.0, 62.1, 636.0, 53.7, 640.0, 69.5, 633.0, 77.9, 625.0, 82.1, 619.0, 87.4, 603.9, 86.3, 586.9, 83.2, 578.9, 77.9, 570.9, 69.5, 562.9, 61.1, 557.9, 43.2, 553.9]
  ];

  @override
  Path getClip(Size size) {
    final sx = size.width / 200.0;
    final sy = size.height / 640.0;
    final path = Path();

    for (final phase in phasePoints) {
      if (phase.length < 2) continue;
      path.moveTo(phase[0] * sx, phase[1] * sy);
      for (int i = 2; i < phase.length; i += 2) {
        path.lineTo(phase[i] * sx, phase[i + 1] * sy);
      }
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom Painter for the crisp outer stroke of the Celestial Moon Arc silhouette.
class CelestialArcStrokePainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  final double glowRadius;

  const CelestialArcStrokePainter({
    required this.strokeColor,
    this.strokeWidth = 1.6,
    this.glowRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = const CelestialArcClipper().getClip(size);

    // Subtle outer solar bloom
    if (glowRadius > 0) {
      final glowPaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawPath(path, glowPaint);
    }

    // Crisp sharp outline stroke
    final strokePaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CelestialArcStrokePainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glowRadius != glowRadius;
  }
}

/// E-Player Standalone Celestial Moon Phase Brightness HUD (Right-Side).
///
/// Features:
/// - Floating standalone HUD on screen (Zero Box / Zero Border / No container outline).
/// - 7-phase vertical curved lunar crescent / solar arc geometry.
/// - Fluid bottom-to-top liquid solar energy fill (NO horizontal bars).
/// - Dynamic 4-tier color interpolation: Lunar Night -> Twilight -> Solar -> Supernova.
/// - Floating glow percentage typography placed to the left of the crescent arc.
class CelestialBrightnessHud extends StatefulWidget {
  final double brightness;
  final double width;
  final double height;

  const CelestialBrightnessHud({
    super.key,
    required this.brightness,
    this.width = 46.0,
    this.height = 240.0,
  });

  @override
  State<CelestialBrightnessHud> createState() => _CelestialBrightnessHudState();
}

class _CelestialBrightnessHudState extends State<CelestialBrightnessHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coronaPulseController;

  @override
  void initState() {
    super.initState();
    _coronaPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _coronaPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Normalize brightness to 0.0 .. 100.0 scale
    final double bValue = widget.brightness > 1.0
        ? widget.brightness.clamp(0.0, 100.0)
        : (widget.brightness * 100.0).clamp(0.0, 100.0);

    final themeColor = CelestialColorResolver.resolve(bValue);
    final glowColor = CelestialColorResolver.resolveGlow(bValue);
    final statusLabel = CelestialColorResolver.resolveLabel(bValue);
    final isSupernova = bValue > 80.0;
    final fillFraction = (bValue / 100.0).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _coronaPulseController,
      builder: (context, child) {
        final pulseScale = isSupernova
            ? 1.0 + (_coronaPulseController.value * 0.035)
            : 1.0;
        final pulseGlow = isSupernova
            ? 14.0 + (_coronaPulseController.value * 6.0)
            : 10.0;

        return Transform.scale(
          scale: pulseScale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Floating Typography (Placed to the left of the arc)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${bValue.round()}%',
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                        Shadow(
                          color: glowColor,
                          blurRadius: pulseGlow,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: themeColor.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          offset: const Offset(0, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // 2. The Celestial Arc Widget (Zero Box, Pure Standalone Arc)
              SizedBox(
                width: widget.width,
                height: widget.height,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Inactive translucent dark silhouette (ambient backdrop)
                    ClipPath(
                      clipper: const CelestialArcClipper(),
                      child: Container(
                        width: widget.width,
                        height: widget.height,
                        color: const Color(0x990E1420),
                      ),
                    ),

                    // Active liquid solar energy fill (rising from bottom to top)
                    ClipPath(
                      clipper: const CelestialArcClipper(),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: widget.width,
                          height: widget.height * fillFraction,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                themeColor,
                                Color.lerp(themeColor, Colors.white, 0.45)!,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor,
                                blurRadius: pulseGlow,
                                spreadRadius: 2.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Crisp razor-sharp stroke overlay
                    CustomPaint(
                      size: Size(widget.width, widget.height),
                      painter: CelestialArcStrokePainter(
                        strokeColor: themeColor,
                        strokeWidth: 1.5,
                        glowRadius: pulseGlow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
