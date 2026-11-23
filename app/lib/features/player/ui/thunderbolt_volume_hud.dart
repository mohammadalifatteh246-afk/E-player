import 'package:flutter/material.dart';

/// 4-tier smooth color transition resolver for E-Player Thunderbolt Volume HUD:
/// - Tier 1 (0% to 50%): Crisp Electric White (#FFFFFF)
/// - Tier 2 (50% to 100%): Smooth transition from White to Electric Cyan-Blue (#00D4FF)
/// - Tier 3 (100% to 200%): Smooth transition from Electric Cyan-Blue to Vivid Amber-Orange (#FF7A00)
/// - Tier 4 (200% to 300%): Smooth transition from Vivid Amber-Orange to Radiant Crimson Red (#FF0D55) with danger pulse
class ThunderColorResolver {
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color electricBlue = Color(0xFF00D4FF);
  static const Color amberOrange = Color(0xFFFF7A00);
  static const Color crimsonRed = Color(0xFFFF0D55);

  /// Resolves the continuous interpolated color for volume in [0.0, 300.0].
  static Color resolve(double volume) {
    final v = volume.clamp(0.0, 300.0);
    if (v <= 50.0) {
      return pureWhite;
    } else if (v <= 100.0) {
      final t = (v - 50.0) / 50.0;
      return Color.lerp(pureWhite, electricBlue, t)!;
    } else if (v <= 200.0) {
      final t = (v - 100.0) / 100.0;
      return Color.lerp(electricBlue, amberOrange, t)!;
    } else {
      final t = (v - 200.0) / 100.0;
      return Color.lerp(amberOrange, crimsonRed, t)!;
    }
  }

  /// Resolves the electric aura glow color with opacity scaled to current tier.
  static Color resolveGlow(double volume) {
    final baseColor = resolve(volume);
    final v = volume.clamp(0.0, 300.0);
    final double alpha = v > 200.0 ? 0.85 : (v > 100.0 ? 0.70 : 0.50);
    return baseColor.withValues(alpha: alpha);
  }

  /// Status badge label for the current volume level.
  static String resolveLabel(double volume) {
    if (volume > 200.0) return 'MAX DANGER';
    if (volume > 100.0) return 'OVER-AMP';
    if (volume > 50.0) return 'ELECTRIC';
    return 'STANDARD';
  }
}

/// Custom Clipper for the razor-sharp 10-point vector Thunderbolt silhouette.
/// Normalized from viewBox="0 0 100 300".
class ThunderboltClipper extends CustomClipper<Path> {
  const ThunderboltClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // 10 mathematically crisp vertices (normalized 100 x 300 viewBox)
    path.moveTo(0.75 * w, 0.0);                       // Pt 0: Top sharp needle
    path.lineTo(0.10 * w, (135.0 / 300.0) * h);      // Pt 1: Left tooth 1
    path.lineTo(0.36 * w, (138.0 / 300.0) * h);      // Pt 2: Left inner 1
    path.lineTo(0.18 * w, (185.0 / 300.0) * h);      // Pt 3: Left tooth 2
    path.lineTo(0.38 * w, (187.0 / 300.0) * h);      // Pt 4: Left inner 2
    path.lineTo(0.15 * w, 1.00 * h);                 // Pt 5: Bottom sharp needle
    path.lineTo(0.88 * w, (165.0 / 300.0) * h);      // Pt 6: Right tooth 2
    path.lineTo(0.62 * w, (162.0 / 300.0) * h);      // Pt 7: Right inner 2
    path.lineTo(0.92 * w, (112.0 / 300.0) * h);      // Pt 8: Right tooth 1
    path.lineTo(0.58 * w, (110.0 / 300.0) * h);      // Pt 9: Right inner 1
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom Painter for the crisp outer stroke of the Thunderbolt silhouette.
class ThunderboltStrokePainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  final double glowRadius;

  const ThunderboltStrokePainter({
    required this.strokeColor,
    this.strokeWidth = 1.6,
    this.glowRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = const ThunderboltClipper().getClip(size);

    // Subtle outer electric bloom
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
  bool shouldRepaint(covariant ThunderboltStrokePainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glowRadius != glowRadius;
  }
}

/// E-Player Medium-Thin Standalone Thunderbolt Volume HUD.
///
/// Features:
/// - Floating standalone HUD on screen (Zero Box / Zero Border / No container outline).
/// - Sleek medium-thin razor-sharp 10-point vector thunderbolt silhouette.
/// - Fluid bottom-to-top liquid energy fill (NO horizontal bars or tick marks).
/// - Dynamic 4-tier color interpolation: White -> Blue -> Orange -> Crimson.
/// - Floating glow percentage typography next to the bolt.
class ThunderboltVolumeHud extends StatefulWidget {
  final double volume;
  final double width;
  final double height;

  const ThunderboltVolumeHud({
    super.key,
    required this.volume,
    this.width = 38.0,
    this.height = 240.0,
  });

  @override
  State<ThunderboltVolumeHud> createState() => _ThunderboltVolumeHudState();
}

class _ThunderboltVolumeHudState extends State<ThunderboltVolumeHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dangerPulseController;

  @override
  void initState() {
    super.initState();
    _dangerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dangerPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ThunderColorResolver.resolve(widget.volume);
    final glowColor = ThunderColorResolver.resolveGlow(widget.volume);
    final statusLabel = ThunderColorResolver.resolveLabel(widget.volume);
    final isDanger = widget.volume > 200.0;
    final fillFraction = (widget.volume / 300.0).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _dangerPulseController,
      builder: (context, child) {
        final pulseScale = isDanger ? 1.0 + (_dangerPulseController.value * 0.035) : 1.0;
        final pulseGlow = isDanger ? 14.0 + (_dangerPulseController.value * 6.0) : 10.0;

        return Transform.scale(
          scale: pulseScale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. The Thunderbolt Widget (Zero Box, Pure Standalone Bolt)
              SizedBox(
                width: widget.width,
                height: widget.height,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Inactive translucent dark bolt silhouette (ambient backdrop)
                    ClipPath(
                      clipper: const ThunderboltClipper(),
                      child: Container(
                        width: widget.width,
                        height: widget.height,
                        color: const Color(0x990E1420),
                      ),
                    ),

                    // Active liquid energy fill (NO BARS - Height rises from bottom upwards)
                    ClipPath(
                      clipper: const ThunderboltClipper(),
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
                                Color.lerp(themeColor, Colors.white, 0.4)!,
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
                      painter: ThunderboltStrokePainter(
                        strokeColor: themeColor,
                        strokeWidth: 1.5,
                        glowRadius: pulseGlow,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // 2. Floating Typography (No Box, Just Clean Glowing Text)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.volume.round()}%',
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
            ],
          ),
        );
      },
    );
  }
}
