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
/// Normalized from viewBox="0 0 240 640" with pronounced parabolic crescent curve.
class CelestialArcClipper extends CustomClipper<Path> {
  const CelestialArcClipper();

  static const List<List<double>> phasePoints = [
    [52.4, 10.0, 58.1, 13.9, 65.4, 22.6, 69.5, 30.4, 71.9, 40.1, 71.1, 58.5, 67.9, 67.2, 59.7, 78.9, 51.6, 84.7, 43.4, 87.6, 33.6, 87.6, 24.7, 84.7, 19.0, 80.8, 10.0, 69.2, 12.4, 75.0, 19.0, 83.7, 33.6, 92.5, 50.7, 92.5, 63.0, 85.7, 71.1, 76.0, 76.8, 61.4, 77.6, 45.9, 71.9, 27.5, 64.6, 17.8],
    [148.9, 95.4, 153.0, 109.0, 153.0, 118.7, 151.3, 127.4, 146.4, 138.1, 136.7, 148.7, 130.1, 152.6, 122.8, 154.6, 110.6, 153.6, 97.5, 145.8, 90.2, 135.2, 94.3, 148.7, 104.1, 161.4, 113.8, 167.2, 127.7, 169.1, 139.9, 165.2, 145.6, 161.4, 153.8, 151.7, 159.5, 137.1, 160.3, 120.6, 156.2, 106.1],
    [201.6, 185.6, 197.5, 199.2, 191.8, 207.9, 186.1, 213.8, 174.7, 219.6, 162.5, 220.5, 155.1, 218.6, 147.0, 213.8, 140.5, 206.0, 139.6, 207.0, 139.6, 221.5, 142.1, 231.2, 147.8, 241.9, 155.1, 249.7, 163.3, 254.5, 170.6, 256.4, 183.6, 255.5, 195.9, 248.7, 205.6, 236.1, 208.1, 230.3, 210.5, 218.6, 209.7, 204.1, 204.8, 190.5],
    [190.1, 277.8, 181.1, 280.7, 174.6, 284.6, 164.8, 296.2, 161.6, 303.0, 159.1, 312.7, 159.1, 327.3, 164.0, 342.8, 172.1, 353.5, 177.0, 357.4, 185.2, 361.2, 199.9, 362.2, 206.4, 360.3, 214.5, 355.4, 224.3, 343.8, 229.2, 330.2, 230.0, 314.7, 225.1, 298.2, 215.3, 285.6, 203.1, 278.8],
    [147.8, 398.1, 141.3, 411.7, 139.6, 418.5, 139.6, 433.0, 140.5, 434.0, 146.2, 427.2, 155.9, 421.4, 164.9, 419.5, 177.1, 421.4, 187.7, 428.2, 195.1, 436.9, 199.9, 447.6, 200.8, 453.4, 201.6, 454.4, 204.8, 449.5, 209.7, 435.9, 210.5, 421.4, 206.5, 405.9, 196.7, 392.3, 185.3, 385.5, 172.2, 383.6, 161.6, 386.5, 154.3, 391.3],
    [102.4, 480.6, 93.5, 493.2, 90.2, 504.8, 93.5, 499.0, 100.0, 492.2, 111.4, 486.4, 121.2, 485.4, 135.0, 490.3, 145.6, 501.0, 152.1, 516.5, 153.0, 531.0, 148.9, 544.6, 155.4, 535.9, 160.3, 519.4, 159.5, 502.9, 153.0, 487.4, 144.0, 477.7, 131.8, 471.8, 117.9, 471.8, 112.2, 473.8],
    [31.2, 548.5, 21.4, 554.3, 13.3, 564.0, 10.0, 570.8, 18.1, 560.1, 25.5, 555.3, 35.3, 552.4, 41.8, 552.4, 57.3, 559.2, 66.2, 569.8, 70.3, 578.6, 71.9, 585.4, 71.9, 600.9, 70.3, 607.7, 66.2, 616.4, 58.1, 626.1, 52.4, 630.0, 63.8, 623.2, 73.6, 609.6, 77.6, 595.1, 76.8, 578.6, 70.3, 563.1, 63.8, 555.3, 57.3, 550.4, 43.4, 546.6]
  ];

  @override
  Path getClip(Size size) {
    final sx = size.width / 240.0;
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
    this.strokeWidth = 1.3,
    this.glowRadius = 9.0,
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
    this.width = 64.0,
    this.height = 200.0,
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
                      fontSize: 18,
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
                          blurRadius: pulseGlow * 0.7,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: themeColor.withValues(alpha: 0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
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

              const SizedBox(width: 10),

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
                        strokeWidth: 1.3,
                        glowRadius: pulseGlow * 0.7,
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
