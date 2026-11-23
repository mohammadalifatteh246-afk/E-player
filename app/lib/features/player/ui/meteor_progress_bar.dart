import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Single normalized component of the vector meteor playhead.
class MeteorComponent {
  final int type; // 0: flame, 1: head, 2: bow_shock, 3: rim, 4: spark
  final double tailX;
  final List<double> points;

  const MeteorComponent({
    required this.type,
    required this.tailX,
    required this.points,
  });
}

/// E-Player Cosmic Meteor Video Progress Bar (Scrubber).
///
/// Features:
/// - Sleek compact Meteor Scrubber Head (~68px wide x 26px tall) with atmospheric entry bow shock.
/// - Continuous live aerodynamic fire flame effect on the surrounding lines.
/// - Molten glowing plasma beam for the played video track.
/// - Fluid drag seeking and tap-to-seek interaction.
/// - Floating real-time scrub timestamp pill when dragging or hovering.
class MeteorProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration? buffered;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const MeteorProgressBar({
    super.key,
    required this.position,
    required this.duration,
    this.buffered,
    this.onSeek,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  State<MeteorProgressBar> createState() => _MeteorProgressBarState();
}

class _MeteorProgressBarState extends State<MeteorProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flameAnimationController;
  bool _isDragging = false;
  double? _dragFraction;

  static const List<MeteorComponent> meteorComponents = [
    MeteorComponent(type: 4, tailX: 0.675, points: [0.675, 0.9808, 0.6937, 1.0, 0.7562, 1.0, 0.775, 0.9808]),
    MeteorComponent(type: 0, tailX: 0.5312, points: [0.5312, 0.9808, 0.5437, 1.0, 0.6125, 0.9808]),
    MeteorComponent(type: 0, tailX: 0.3312, points: [0.3312, 0.8269, 0.35, 0.8269, 0.3563, 0.8462, 0.5312, 0.8462, 0.5375, 0.8269, 0.5563, 0.8269, 0.5375, 0.8269, 0.5312, 0.8077, 0.3563, 0.8077, 0.35, 0.8269]),
    MeteorComponent(type: 0, tailX: 0.125, points: [0.125, 0.8269, 0.1375, 0.8269, 0.1437, 0.8462, 0.25, 0.8462, 0.2562, 0.8269, 0.2687, 0.8269, 0.2562, 0.8269, 0.25, 0.8077, 0.1437, 0.8077, 0.1375, 0.8269]),
    MeteorComponent(type: 0, tailX: 0.2188, points: [0.2188, 0.6923, 0.3688, 0.7308, 0.575, 0.7115, 0.5875, 0.6923, 0.5312, 0.6923, 0.525, 0.6731, 0.2812, 0.6731, 0.275, 0.6923]),
    MeteorComponent(type: 0, tailX: 0.0813, points: [0.0813, 0.7115, 0.1375, 0.6923, 0.125, 0.6731, 0.0938, 0.6731]),
    MeteorComponent(type: 4, tailX: 0.675, points: [0.675, 0.5577, 0.6937, 0.5769, 0.7063, 0.5962, 0.7, 0.5385, 0.6875, 0.5577]),
    MeteorComponent(type: 0, tailX: 0.3812, points: [0.3812, 0.5577, 0.4375, 0.5769, 0.4437, 0.5962, 0.5625, 0.5962, 0.5687, 0.5769, 0.625, 0.5577, 0.575, 0.5577, 0.5687, 0.5385, 0.4375, 0.5385, 0.4313, 0.5577]),
    MeteorComponent(type: 0, tailX: 0.0437, points: [0.0437, 0.5577, 0.0563, 0.5769, 0.1375, 0.5962, 0.2125, 0.5962, 0.2188, 0.5769, 0.3, 0.5577, 0.2313, 0.5577, 0.225, 0.5385, 0.1187, 0.5385, 0.1125, 0.5577]),
    MeteorComponent(type: 0, tailX: 0.5813, points: [0.5813, 0.4423, 0.6062, 0.4423, 0.6125, 0.4615, 0.7, 0.4038, 0.6312, 0.4038, 0.625, 0.4231]),
    MeteorComponent(type: 0, tailX: 0.4125, points: [0.4125, 0.4423, 0.4313, 0.4615, 0.5125, 0.4423, 0.4938, 0.4231, 0.4875, 0.4038, 0.4437, 0.4038, 0.4375, 0.4231]),
    MeteorComponent(type: 0, tailX: 0.0, points: [0.0, 0.4423, 0.0625, 0.4423, 0.0688, 0.4615, 0.2812, 0.4615, 0.2875, 0.4423, 0.3438, 0.4423, 0.3312, 0.4423, 0.325, 0.4231, 0.2188, 0.4038, 0.1313, 0.4038, 0.025, 0.4231, 0.0187, 0.4423]),
    MeteorComponent(type: 0, tailX: 0.2562, points: [0.2562, 0.3077, 0.2938, 0.3077, 0.3, 0.3269, 0.5062, 0.3269, 0.5125, 0.3077, 0.55, 0.3077, 0.5312, 0.3077, 0.525, 0.2885, 0.2812, 0.2885, 0.275, 0.3077]),
    MeteorComponent(type: 0, tailX: 0.0437, points: [0.0437, 0.3077, 0.0625, 0.3077, 0.0688, 0.3269, 0.1562, 0.3269, 0.1625, 0.3077, 0.1812, 0.3077, 0.1688, 0.3077, 0.1625, 0.2885, 0.0563, 0.2885]),
    MeteorComponent(type: 0, tailX: 0.1125, points: [0.1125, 0.1731, 0.125, 0.1731, 0.1313, 0.1923, 0.2437, 0.1923, 0.2562, 0.1731, 0.2437, 0.1731, 0.2375, 0.1538, 0.1375, 0.1538, 0.1313, 0.1731]),
    MeteorComponent(type: 1, tailX: 0.3312, points: [0.95, 0.6154, 0.9563, 0.4808, 0.9375, 0.3077, 0.8562, 0.1346, 0.75, 0.1923, 0.7625, 0.1538, 0.3312, 0.1731, 0.7562, 0.2115, 0.7312, 0.3077, 0.625, 0.3077, 0.725, 0.3654, 0.7188, 0.6731, 0.6625, 0.6923, 0.7063, 0.7308, 0.7312, 0.6923, 0.7562, 0.7885, 0.6188, 0.8269, 0.8625, 0.8654, 0.9125, 0.7885]),
    MeteorComponent(type: 4, tailX: 0.75, points: [0.75, 0.8077, 0.7625, 0.7885, 0.775, 0.8269, 0.7625, 0.8462]),
    MeteorComponent(type: 3, tailX: 0.9062, points: [0.9125, 0.2692, 0.9313, 0.3269, 0.9437, 0.4038, 0.9437, 0.5962, 0.9313, 0.6731, 0.9125, 0.7308, 0.9062, 0.6923, 0.9187, 0.6538, 0.9313, 0.5577, 0.9313, 0.4423, 0.9187, 0.3462, 0.9062, 0.3077]),
    MeteorComponent(type: 4, tailX: 0.8812, points: [0.8812, 0.2308, 0.8938, 0.2115, 0.9125, 0.2692, 0.9, 0.2885]),
    MeteorComponent(type: 2, tailX: 0.8438, points: [0.8625, 0.0192, 0.8438, 0.0385, 0.8625, 0.0385, 0.9062, 0.0962, 0.9563, 0.25, 0.975, 0.3846, 0.9812, 0.5385, 0.975, 0.6346, 0.9313, 0.8462, 0.85, 0.9808, 0.8938, 0.9615, 0.9313, 0.9038, 0.975, 0.7692, 1.0, 0.5385, 0.9938, 0.3654, 0.975, 0.2308, 0.9313, 0.0962, 0.8938, 0.0385]),
    MeteorComponent(type: 0, tailX: 0.5938, points: [0.5938, 0.0192, 0.6375, 0.0385, 0.6438, 0.0577, 0.725, 0.0577, 0.7312, 0.0385, 0.7688, 0.0192, 0.7438, 0.0192, 0.7375, 0.0, 0.625, 0.0, 0.6188, 0.0192]),
  ];

  @override
  void initState() {
    super.initState();
    _flameAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _flameAnimationController.dispose();
    super.dispose();
  }

  double _getFractionFromOffset(Offset localPosition, double width) {
    if (width <= 0) return 0.0;
    return (localPosition.dx / width).clamp(0.0, 1.0);
  }

  void _handleDragStart(DragStartDetails details, double width) {
    setState(() {
      _isDragging = true;
      _dragFraction = _getFractionFromOffset(details.localPosition, width);
    });
    widget.onSeekStart?.call();
    _notifySeek();
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    setState(() {
      _dragFraction = _getFractionFromOffset(details.localPosition, width);
    });
    _notifySeek();
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _dragFraction = null;
    });
    widget.onSeekEnd?.call();
  }

  void _handleTapDown(TapDownDetails details, double width) {
    final fraction = _getFractionFromOffset(details.localPosition, width);
    widget.onSeekStart?.call();
    widget.onSeek?.call(Duration(milliseconds: (fraction * widget.duration.inMilliseconds).toInt()));
    widget.onSeekEnd?.call();
  }

  void _notifySeek() {
    if (_dragFraction == null) return;
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return;
    final targetMs = (_dragFraction! * totalMs).toInt();
    widget.onSeek?.call(Duration(milliseconds: targetMs));
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final posMs = widget.position.inMilliseconds;
    final currentFraction = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final effectiveFraction = _isDragging ? (_dragFraction ?? currentFraction) : currentFraction;

    final bufMs = widget.buffered?.inMilliseconds ?? 0;
    final bufferFraction = totalMs > 0 ? (bufMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final headX = width * effectiveFraction;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleTapDown(details, width),
          onHorizontalDragStart: (details) => _handleDragStart(details, width),
          onHorizontalDragUpdate: (details) => _handleDragUpdate(details, width),
          onHorizontalDragEnd: _handleDragEnd,
          onHorizontalDragCancel: () => _handleDragEnd(DragEndDetails()),
          child: SizedBox(
            height: 38.0,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 1. The Custom Painted Track & Meteor
                AnimatedBuilder(
                  animation: _flameAnimationController,
                  builder: (context, child) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        size: Size(width, 38.0),
                        painter: MeteorTrackPainter(
                          progressFraction: effectiveFraction,
                          bufferFraction: bufferFraction,
                          animValue: _flameAnimationController.value,
                          isScrubbing: _isDragging,
                          components: meteorComponents,
                        ),
                      ),
                    );
                  },
                ),

                // 2. Floating Time Tooltip Pill (Active during dragging)
                if (_isDragging)
                  Positioned(
                    left: (headX - 44.0).clamp(0.0, math.max(0.0, width - 88.0)),
                    top: -24.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xEE101622),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFF7A00),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7A00).withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        _formatDuration(Duration(milliseconds: (effectiveFraction * totalMs).toInt())),
                        style: const TextStyle(
                          color: Color(0xFFFEF08A),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom Painter for the complete Meteor Progress Bar:
/// - Unplayed Track
/// - Buffered Track
/// - Molten Plasma Played Track with Fire Glow
/// - Scaled Meteor Head with continuous multi-frequency fire lines
class MeteorTrackPainter extends CustomPainter {
  final double progressFraction;
  final double bufferFraction;
  final double animValue;
  final bool isScrubbing;
  final List<MeteorComponent> components;

  static const Color crimson = Color(0xFFDC2626);
  static const Color orange = Color(0xFFF97316);
  static const Color gold = Color(0xFFFBBF24);
  static const Color yellow = Color(0xFFFEF08A);
  static const Color white = Color(0xFFFFFFFF);

  const MeteorTrackPainter({
    required this.progressFraction,
    required this.bufferFraction,
    required this.animValue,
    required this.isScrubbing,
    required this.components,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h / 2.0;
    const trackH = 4.0;
    final headX = (w * progressFraction).clamp(0.0, w);

    // 1. Unplayed Track (Glass Dark Rail)
    final unplayedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - trackH / 2.0, w, trackH),
        const Radius.circular(2.0),
      ),
      unplayedPaint,
    );

    // 2. Buffered Track (Preload aurora)
    if (bufferFraction > 0) {
      final bufW = (w * bufferFraction).clamp(0.0, w);
      final bufPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, centerY - trackH / 2.0, bufW, trackH),
          const Radius.circular(2.0),
        ),
        bufPaint,
      );
    }

    // 3. Played Molten Plasma Track (with fiery outer bloom)
    if (headX > 0) {
      // Ambient fire glow underneath
      final glowPaint = Paint()
        ..color = orange.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackH * 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawLine(Offset(0, centerY), Offset(headX, centerY), glowPaint);

      // Incandescent core gradient line
      final grad = const LinearGradient(
        colors: [crimson, orange, gold, yellow],
        stops: [0.0, 0.4, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, centerY - trackH / 2.0, headX, trackH));

      final playedPaint = Paint()
        ..shader = grad
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, centerY - trackH / 2.0, headX, trackH),
          const Radius.circular(2.0),
        ),
        playedPaint,
      );
    }

    // 4. The Blazing Meteor Scrubber Head (~68px wide x 26px tall)
    final mw = isScrubbing ? 76.0 : 68.0;
    final mh = isScrubbing ? 29.0 : 26.0;
    final topX = headX - (0.85 * mw);
    final topY = centerY - (0.50 * mh);

    // Draw Meteor Components
    for (int i = 0; i < components.length; i++) {
      final c = components[i];
      final pts = c.points;
      if (pts.length < 4) continue;

      // 0: Flame lines with multi-frequency continuous aerodynamic flutter
      if (c.type == 0) {
        final f1 = math.sin(animValue * 12.56 + i * 1.2) * 1.8;
        final f2 = math.cos(animValue * 18.84 + i * 0.7) * 1.1;
        final flameDx = f1 + f2;
        final scaleX = 1.0 + math.sin(animValue * 9.42 + i * 1.5) * 0.10;

        final path = Path();
        path.moveTo(topX + (pts[0] * mw * scaleX) + flameDx, topY + (pts[1] * mh));
        for (int p = 2; p < pts.length; p += 2) {
          path.lineTo(topX + (pts[p] * mw * scaleX) + flameDx, topY + (pts[p + 1] * mh));
        }
        path.close();

        final Color col;
        if (c.tailX < 0.35) {
          col = Color.lerp(crimson, orange, c.tailX / 0.35)!;
        } else if (c.tailX < 0.70) {
          col = Color.lerp(orange, gold, (c.tailX - 0.35) / 0.35)!;
        } else {
          col = Color.lerp(gold, yellow, (c.tailX - 0.70) / 0.30)!;
        }

        final flamePaint = Paint()
          ..color = col.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, flamePaint);
      }

      // 4: Sparks
      else if (c.type == 4) {
        final sparkDx = math.sin(animValue * 25.0 + i) * 1.5;
        final path = Path();
        path.moveTo(topX + (pts[0] * mw) + sparkDx, topY + (pts[1] * mh));
        for (int p = 2; p < pts.length; p += 2) {
          path.lineTo(topX + (pts[p] * mw) + sparkDx, topY + (pts[p + 1] * mh));
        }
        path.close();

        final sparkPaint = Paint()
          ..color = yellow
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, sparkPaint);
      }

      // 1: Main Meteor Fireball Core
      else if (c.type == 1) {
        final path = Path();
        path.moveTo(topX + (pts[0] * mw), topY + (pts[1] * mh));
        for (int p = 2; p < pts.length; p += 2) {
          path.lineTo(topX + (pts[p] * mw), topY + (pts[p + 1] * mh));
        }
        path.close();

        // Fireball aura glow
        final coreGlowPaint = Paint()
          ..color = orange.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, coreGlowPaint);

        // Core fill
        final corePaint = Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, corePaint);
      }

      // 2: Atmospheric Entry Shockwave Crest
      else if (c.type == 2) {
        final path = Path();
        path.moveTo(topX + (pts[0] * mw), topY + (pts[1] * mh));
        for (int p = 2; p < pts.length; p += 2) {
          path.lineTo(topX + (pts[p] * mw), topY + (pts[p + 1] * mh));
        }
        path.close();

        final shockPaint = Paint()
          ..color = white
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, shockPaint);
      }

      // 3: Front Molten Rim
      else if (c.type == 3) {
        final path = Path();
        path.moveTo(topX + (pts[0] * mw), topY + (pts[1] * mh));
        for (int p = 2; p < pts.length; p += 2) {
          path.lineTo(topX + (pts[p] * mw), topY + (pts[p + 1] * mh));
        }
        path.close();

        final rimPaint = Paint()
          ..color = white.withValues(alpha: 0.90)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, rimPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MeteorTrackPainter oldDelegate) {
    return oldDelegate.progressFraction != progressFraction ||
        oldDelegate.bufferFraction != bufferFraction ||
        oldDelegate.animValue != animValue ||
        oldDelegate.isScrubbing != isScrubbing;
  }
}
