import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../domain/audio_visualizer_engine.dart';

/// Real-time animated canvas widget rendering dynamic audio spectrum visualization.
/// Mirrors VLC's visualizer modules: `visual.c` (Spectrum, Scope, Spectrogram, VU-meter) and `glspectrum.c`.
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
    if (!mounted) return;
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
    _ticker.stop();
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
                engine: widget.engine,
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
  final AudioVisualizerEngine engine;
  final VisualizerStyle style;

  _VisualizerPainter({
    required this.engine,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, size);
        break;
      case VisualizerStyle.scope:
        _paintScope(canvas, size);
        break;
      case VisualizerStyle.spectrogram:
        _paintSpectrogram(canvas, size);
        break;
      case VisualizerStyle.vuMeter:
        _paintVuMeter(canvas, size);
        break;
      case VisualizerStyle.mirrorWave:
        _paintMirrorWave(canvas, size);
        break;
      case VisualizerStyle.circular:
        _paintCircular(canvas, size);
        break;
    }
  }

  // --- 1. Spectrum Analyzer with Segmented Bars & Peak Caps (VLC visual.c spectrum) ---
  void _paintBars(Canvas canvas, Size size) {
    final magnitudes = engine.magnitudes;
    final peaks = engine.peaks;
    final count = magnitudes.length;
    if (count == 0) return;

    final totalSpacing = (count - 1) * 2.5;
    final barWidth = math.max(2.0, (size.width - 24.0 - totalSpacing) / count);
    const startX = 12.0;

    for (var i = 0; i < count; i++) {
      final x = startX + i * (barWidth + 2.5);
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

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2.0));
      canvas.drawRRect(rrect, paint);

      // Peak Indicator Pip (VLC spect-show-peaks parity)
      if (engine.showPeaks) {
        final peak = peaks[i].clamp(0.02, 1.0);
        final peakY = size.height - 12.0 - peak * (size.height - 24.0);
        final peakRect = Rect.fromLTWH(x, peakY - 3.0, barWidth, 2.0);
        final peakPaint = Paint()..color = Colors.amberAccent;
        canvas.drawRRect(RRect.fromRectAndRadius(peakRect, const Radius.circular(1.0)), peakPaint);
      }
    }
  }

  // --- 2. Analog Cathode-Ray Oscilloscope with Phosphor Glow (VLC scope.c) ---
  void _paintScope(Canvas canvas, Size size) {
    // 1. Draw CRT dark background & reticle graticule grid
    final gridPaint = Paint()
      ..color = const Color(0xFF00382E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const divisionsX = 8;
    const divisionsY = 6;
    for (var i = 1; i < divisionsX; i++) {
      final gx = (size.width / divisionsX) * i;
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), gridPaint);
    }
    for (var j = 1; j < divisionsY; j++) {
      final gy = (size.height / divisionsY) * j;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }

    // 2. Draw CRT center graticule crosshair ticks
    final centerCrosshair = Paint()
      ..color = const Color(0xFF00695C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), centerCrosshair);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), centerCrosshair);

    // 3. Trace analog green phosphor waveform
    final waveform = engine.waveform;
    if (waveform.isEmpty) return;

    final centerY = size.height / 2.0;
    final stepX = size.width / (waveform.length - 1);

    final wavePath = Path();
    wavePath.moveTo(0, centerY + waveform[0] * (size.height * 0.42));

    for (var i = 1; i < waveform.length; i++) {
      final x = i * stepX;
      final y = centerY + waveform[i] * (size.height * 0.42);
      wavePath.lineTo(x, y);
    }

    // Dual-pass beam rendering: Outer Phosphor Halo Glow + Sharp Core Beam
    final glowPaint = Paint()
      ..color = const Color(0x5500FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(wavePath, glowPaint);

    final beamPaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(wavePath, beamPaint);

    // Scope HUD Legend
    const textStyle = TextStyle(color: Color(0xFF00897B), fontSize: 9, fontWeight: FontWeight.bold);
    const span1 = TextSpan(text: 'CH1: 50mV/DIV  TIME: 5ms', style: textStyle);
    final tp1 = TextPainter(text: span1, textDirection: TextDirection.ltr)..layout();
    tp1.paint(canvas, const Offset(8, 6));
  }

  // --- 3. 3D Spectrogram Waterfall with Depth Heatmap (VLC glspectrum.c) ---
  void _paintSpectrogram(Canvas canvas, Size size) {
    final history = engine.spectrogramHistory;
    if (history.isEmpty) return;

    final rows = history.length;
    final rowHeight = size.height / rows;

    for (var r = 0; r < rows; r++) {
      final slice = history[r];
      final count = slice.length;
      if (count == 0) continue;

      final colWidth = size.width / count;
      final y = size.height - (r + 1) * rowHeight;

      // Depth perspective fade
      final depthFactor = 1.0 - (r / rows) * 0.65;

      for (var c = 0; c < count; c++) {
        final mag = slice[c];
        final x = c * colWidth;

        // Thermal color map: Low=Dark Violet -> Mid=Cyan/Green -> High=Yellow/Red
        Color cellColor;
        if (mag < 0.25) {
          cellColor = Color.lerp(const Color(0xFF0D0B24), const Color(0xFF1E3C72), mag / 0.25)!;
        } else if (mag < 0.65) {
          cellColor = Color.lerp(const Color(0xFF1E3C72), const Color(0xFF00E5FF), (mag - 0.25) / 0.40)!;
        } else if (mag < 0.85) {
          cellColor = Color.lerp(const Color(0xFF00E5FF), const Color(0xFFFFD600), (mag - 0.65) / 0.20)!;
        } else {
          cellColor = Color.lerp(const Color(0xFFFFD600), const Color(0xFFFF2A6D), (mag - 0.85) / 0.15)!;
        }

        cellColor = cellColor.withValues(alpha: depthFactor);

        final cellRect = Rect.fromLTWH(x, y, colWidth + 0.5, rowHeight + 0.5);
        canvas.drawRect(cellRect, Paint()..color = cellColor);
      }
    }
  }

  // --- 4. Dual Channel Stereo Peak VU-Meter (VLC visual vu-meter) ---
  void _paintVuMeter(Canvas canvas, Size size) {
    const meterHeight = 18.0;
    final centerY = size.height / 2.0;
    final meterWidth = size.width - 56.0;

    _paintChannelVu(
      canvas: canvas,
      label: 'L',
      y: centerY - meterHeight - 8.0,
      width: meterWidth,
      height: meterHeight,
      db: engine.leftVuDb,
      peakDb: engine.leftVuPeak,
    );

    _paintChannelVu(
      canvas: canvas,
      label: 'R',
      y: centerY + 8.0,
      width: meterWidth,
      height: meterHeight,
      db: engine.rightVuDb,
      peakDb: engine.rightVuPeak,
    );
  }

  void _paintChannelVu({
    required Canvas canvas,
    required String label,
    required double y,
    required double width,
    required double height,
    required double db,
    required double peakDb,
  }) {
    // Channel Label
    final labelStyle = const TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.bold);
    final tp = TextPainter(text: TextSpan(text: label, style: labelStyle), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(12, y + (height - tp.height) / 2));

    const startX = 36.0;
    const segmentCount = 28;
    final segmentWidth = (width - (segmentCount - 1) * 2.0) / segmentCount;

    // Normalised dB from -40dB (0.0) to +3dB (1.0)
    final normLevel = ((db + 40.0) / 43.0).clamp(0.0, 1.0);
    final normPeak = ((peakDb + 40.0) / 43.0).clamp(0.0, 1.0);
    final activeSegments = (normLevel * segmentCount).round();
    final peakIndex = (normPeak * (segmentCount - 1)).round();

    for (var s = 0; s < segmentCount; s++) {
      final sx = startX + s * (segmentWidth + 2.0);
      final normSeg = s / segmentCount;

      Color segColor;
      if (normSeg < 0.65) {
        segColor = const Color(0xFF00E676); // Normal Green
      } else if (normSeg < 0.88) {
        segColor = const Color(0xFFFFD600); // Warning Amber
      } else {
        segColor = const Color(0xFFFF1744); // Overload Red
      }

      final isLit = s < activeSegments;
      final paint = Paint()
        ..color = isLit ? segColor : segColor.withValues(alpha: 0.12);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(sx, y, segmentWidth, height),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, paint);

      // Peak Hold Pip
      if (s == peakIndex && normPeak > 0.05) {
        final peakPaint = Paint()..color = Colors.white;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(sx, y, segmentWidth, height), const Radius.circular(2)),
          peakPaint,
        );
      }
    }
  }

  // --- 5. Mirrored Stereo Waveform ---
  void _paintMirrorWave(Canvas canvas, Size size) {
    final magnitudes = engine.magnitudes;
    final count = magnitudes.length;
    if (count == 0) return;

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

  // --- 6. Radial Pulsing Orb ---
  void _paintCircular(Canvas canvas, Size size) {
    final magnitudes = engine.magnitudes;
    final count = magnitudes.length;
    if (count == 0) return;

    final center = Offset(size.width / 2.0, size.height / 2.0);
    final baseRadius = math.min(size.width, size.height) * 0.24;

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
