import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/video_effects_config.dart';

/// Clean-room implementation of VLC's SPU (Subpicture Unit) overlay layer.
/// Matches `modules/spu/logo.c` and `modules/spu/marq.c`.
///
/// Features:
/// - 0ms zero-latency GPU rendering over the video stream.
/// - Does not block touch/gesture events (`IgnorePointer`).
/// - Real-time token substitution for title (%t), position (%p), duration (%l), and clock (%Y-%m-%d %H:%M:%S).
/// - Resilient to invalid file paths or missing assets.
class VideoOverlayWidget extends StatefulWidget {
  final VideoEffectsConfig config;
  final String? mediaTitle;
  final Duration position;
  final Duration duration;

  const VideoOverlayWidget({
    super.key,
    required this.config,
    this.mediaTitle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  @override
  State<VideoOverlayWidget> createState() => _VideoOverlayWidgetState();
}

class _VideoOverlayWidgetState extends State<VideoOverlayWidget> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _checkTicker();
  }

  @override
  void didUpdateWidget(covariant VideoOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.marqueeEnabled != widget.config.marqueeEnabled ||
        oldWidget.config.marqueeText != widget.config.marqueeText) {
      _checkTicker();
    }
  }

  void _checkTicker() {
    _ticker?.cancel();
    _ticker = null;

    if (widget.config.marqueeEnabled &&
        MarqueeTokenFormatter.hasDynamicTokens(widget.config.marqueeText)) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    if (!cfg.masterEnabled || (!cfg.logoEnabled && !cfg.marqueeEnabled)) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Watermark / Logo Overlay (VLC logo.c parity)
          if (cfg.logoEnabled &&
              ((cfg.logoPath != null && cfg.logoPath!.isNotEmpty) ||
                  (cfg.logoText != null && cfg.logoText!.isNotEmpty)))
            _buildLogo(cfg),

          // 2. Text Marquee OSD Overlay (VLC marq.c parity)
          if (cfg.marqueeEnabled && cfg.marqueeText.isNotEmpty)
            _buildMarquee(cfg),
        ],
      ),
    );
  }

  Widget _buildLogo(VideoEffectsConfig cfg) {
    final opacity = cfg.logoOpacity.clamp(0.0, 1.0);

    Widget content;
    if (cfg.logoPath != null && cfg.logoPath!.isNotEmpty) {
      final file = File(cfg.logoPath!);
      content = Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } else if (cfg.logoText != null && cfg.logoText!.isNotEmpty) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35 * opacity),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2 * opacity)),
        ),
        child: Text(
          cfg.logoText!,
          style: TextStyle(
            color: Colors.white.withValues(alpha: opacity),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: cfg.logoPosition.alignment,
      child: Padding(
        padding: EdgeInsets.only(
          left: cfg.logoPosition.alignment.x <= 0 ? cfg.logoOffsetX.toDouble() : 0,
          right: cfg.logoPosition.alignment.x >= 0 ? cfg.logoOffsetX.toDouble() : 0,
          top: cfg.logoPosition.alignment.y <= 0 ? cfg.logoOffsetY.toDouble() : 0,
          bottom: cfg.logoPosition.alignment.y >= 0 ? cfg.logoOffsetY.toDouble() : 0,
        ),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: cfg.logoScale.clamp(0.1, 5.0),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildMarquee(VideoEffectsConfig cfg) {
    final formattedText = MarqueeTokenFormatter.format(
      template: cfg.marqueeText,
      mediaTitle: widget.mediaTitle,
      position: widget.position,
      duration: widget.duration,
    );

    final opacity = cfg.marqueeOpacity.clamp(0.0, 1.0);
    final textColor = Color(0xFF000000 | (cfg.marqueeColor & 0xFFFFFF)).withValues(alpha: opacity);

    Widget content = Text(
      formattedText,
      style: TextStyle(
        color: textColor,
        fontSize: cfg.marqueeFontSize.clamp(8.0, 72.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        shadows: const [
          Shadow(
            color: Colors.black87,
            blurRadius: 4.0,
            offset: Offset(1.0, 1.0),
          ),
          Shadow(
            color: Colors.black54,
            blurRadius: 8.0,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
    );

    if (cfg.marqueeShowBackground) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45 * opacity),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15 * opacity),
            width: 0.5,
          ),
        ),
        child: content,
      );
    }

    return Align(
      alignment: cfg.marqueePosition.alignment,
      child: Padding(
        padding: EdgeInsets.only(
          left: cfg.marqueePosition.alignment.x <= 0 ? cfg.marqueeOffsetX.toDouble() : 0,
          right: cfg.marqueePosition.alignment.x >= 0 ? cfg.marqueeOffsetX.toDouble() : 0,
          top: cfg.marqueePosition.alignment.y <= 0 ? cfg.marqueeOffsetY.toDouble() : 0,
          bottom: cfg.marqueePosition.alignment.y >= 0 ? cfg.marqueeOffsetY.toDouble() : 0,
        ),
        child: content,
      ),
    );
  }
}
