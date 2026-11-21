import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';

/// Interactive Floating Banner prompting the user to continue playback
/// from their saved position (VLC Parity: `--qt-continue=1`).
class ResumePlaybackBannerWidget extends StatefulWidget {
  final Duration resumePosition;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onDismiss;
  final Duration autoDismissDuration;

  const ResumePlaybackBannerWidget({
    super.key,
    required this.resumePosition,
    required this.onResume,
    required this.onRestart,
    required this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 8),
  });

  @override
  State<ResumePlaybackBannerWidget> createState() =>
      _ResumePlaybackBannerWidgetState();
}

class _ResumePlaybackBannerWidgetState extends State<ResumePlaybackBannerWidget>
    with SingleTickerProviderStateMixin {
  Timer? _autoDismissTimer;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    // Start auto-dismiss countdown
    if (widget.autoDismissDuration > Duration.zero) {
      _autoDismissTimer = Timer(widget.autoDismissDuration, () {
        _dismissWithAnimation();
      });
    }
  }

  void _dismissWithAnimation() {
    _autoDismissTimer?.cancel();
    if (mounted) {
      _animController.reverse().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: EDesign.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: EDesign.primaryCyan.withValues(alpha: 0.40),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Leading Icon with Cyan Glow
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: EDesign.primaryCyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: EDesign.primaryCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Timestamp Information
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continue playback?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Resume from ${_formatDuration(widget.resumePosition)}',
                        style: TextStyle(
                          color: EDesign.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Resume Action Button (Primary filled)
                ElevatedButton.icon(
                  key: const Key('resume_playback_confirm_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primaryCyan,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text(
                    'Resume',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    _autoDismissTimer?.cancel();
                    widget.onResume();
                  },
                ),
                const SizedBox(width: 8),

                // Restart Action Button (Outlined)
                OutlinedButton.icon(
                  key: const Key('resume_playback_restart_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 15),
                  label: const Text(
                    'Restart',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    _autoDismissTimer?.cancel();
                    widget.onRestart();
                  },
                ),
                const SizedBox(width: 4),

                // Close / Dismiss Icon Button
                IconButton(
                  key: const Key('resume_playback_dismiss_button'),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: EDesign.textSecondary,
                  tooltip: 'Dismiss',
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: _dismissWithAnimation,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
