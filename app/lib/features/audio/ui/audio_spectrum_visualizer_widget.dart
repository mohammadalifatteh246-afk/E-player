import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../domain/audio_visualizer_engine.dart';

/// Real-time animated canvas widget rendering dynamic audio spectrum visualization.
/// Mirrors VLC's glspectrum and 3D visualizer display filters.
class AudioSpectrumVisualizerWidget extends StatefulWidget {
  final AudioVisualizerEngine engine;
  final VisualizerStyle style;
  final double height;
  final bool isInteractive;

  const AudioSpectrumVisualizerWidget({
    super.key,
    required this.engine,
    this.style = VisualizerStyle.bars,
    this.height = 140.0,
    this.isInteractive = false,
  });

  @override
  State<AudioSpectrumVisualizerWidget> createState() => _AudioSpectrumVisualizerWidgetState();
}

class _AudioSpectrumVisualizerWidgetState extends State<AudioSpectrumVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController.unbounded(vsync: this);
    _ticker.addListener(_onTick);
    _ticker.repeat(min: 0.0, max: 1.0, period: const Duration(seconds: 1));
  }

  void _onTick() {
    final now = DateTime.now();
    final elapsed = _lastTick == Duration.zero
        ? const Duration(milliseconds: 16)
        : Duration(microseconds: now.microsecondsSinceEpoch - _lastTick.inMicroseconds);
    _lastTick = Duration(microseconds: now.microsecondsSinceEpoch);

    // Limit delta time to prevent physics explosions on backgrounding
    final clampedDt = Duration(microseconds: elapsed.inMicroseconds.clamp(5000, 50000));
    widget.engine.tick(clampedDt);
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.engine,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(EDesign.r16),
          child: Container(
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: EDesign.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(EDesign.r16),
              border: Border.all(color: EDesign.border),
            ),
            child: CustomPaint(
              painter: _VisualizerPainter(
                magnitudes: widget.engine.magnitudes,
                peaks: widget.engine.peaks,
                style: widget.style,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> magnitudes;
  final List<double> peaks;
  final VisualizerStyle style;

  _VisualizerPainter({
    required this.magnitudes,
    required this.peaks,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (magnitudes.isEmpty) return;

    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, size);
        break;
      case VisualizerStyle.mirrorWave:
        _paintMirrorWave(canvas, size);
        break;
      case VisualizerStyle.circular:
        _paintCircular(canvas, size);
        break;
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    final count = magnitudes.length;
    final totalSpacing = (count - 1) * 3.0;
    final barWidth = math.max(2.0, (size.width - 24.0 - totalSpacing) / count);
    const startX = 12.0;

    for (var i = 0; i < count; i++) {
      final x = startX + i * (barWidth + 3.0);
      final mag = magnitudes[i].clamp(0.02, 1.0);
      final barHeight = mag * (size.height - 24.0);
      final y = size.height - 12.0 - barHeight;

      // Vertical Bar Gradient (Cyan -> Electric Indigo -> Magenta)
      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            EDesign.primaryCyan,
            EDesign.primaryStrong,
            EDesign.aiAccent,
          ],
        ).createShader(rect);

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2.5));
      canvas.drawRRect(rrect, paint);

      // Peak Indicator Pip
      final peak = peaks[i].clamp(0.02, 1.0);
      final peakY = size.height - 12.0 - peak * (size.height - 24.0);
      final peakRect = Rect.fromLTWH(x, peakY - 3.0, barWidth, 2.5);
      final peakPaint = Paint()..color = Colors.amberAccent;
      canvas.drawRRect(RRect.fromRectAndRadius(peakRect, const Radius.circular(1.0)), peakPaint);
    }
  }

  void _paintMirrorWave(Canvas canvas, Size size) {
    final count = magnitudes.length;
    final centerY = size.height / 2.0;
    final stepX = (size.width - 24.0) / (count - 1);

    final pathTop = Path();
    final pathBottom = Path();

    pathTop.moveTo(12.0, centerY);
    pathBottom.moveTo(12.0, centerY);

    for (var i = 0; i < count; i++) {
      final x = 12.0 + i * stepX;
      final mag = magnitudes[i] * (size.height * 0.42);
      pathTop.lineTo(x, centerY - mag);
      pathBottom.lineTo(x, centerY + mag);
    }

    final paint = Paint()
      ..color = EDesign.primaryCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(pathTop, paint);
    canvas.drawPath(pathBottom, paint);
  }

  void _paintCircular(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final baseRadius = math.min(size.width, size.height) * 0.24;
    final count = magnitudes.length;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          EDesign.primaryCyan.withValues(alpha: 0.8),
          EDesign.aiAccent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2.0 * math.pi;
      final mag = magnitudes[i] * (baseRadius * 0.7);

      final p1 = Offset(
        center.dx + baseRadius * math.cos(angle),
        center.dy + baseRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (baseRadius + mag) * math.cos(angle),
        center.dy + (baseRadius + mag) * math.sin(angle),
      );

      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return true;
  }
}
