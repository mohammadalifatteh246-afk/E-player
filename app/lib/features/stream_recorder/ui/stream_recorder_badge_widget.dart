import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../data/stream_recorder_controller.dart';
import 'stream_recorder_sheet.dart';

/// Glassmorphic animated HUD indicator displayed on top of video playback
/// while a stream recording session is actively dumping packets to disk.
class StreamRecorderBadgeWidget extends StatefulWidget {
  final StreamRecorderController controller;

  const StreamRecorderBadgeWidget({
    super.key,
    required this.controller,
  });

  @override
  State<StreamRecorderBadgeWidget> createState() => _StreamRecorderBadgeWidgetState();
}

class _StreamRecorderBadgeWidgetState extends State<StreamRecorderBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isRecording) {
      return const SizedBox.shrink();
    }

    final durationStr = widget.controller.activeFormattedDuration;
    final sizeStr = widget.controller.activeFormattedSize;

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => StreamRecorderSheet(controller: widget.controller),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing Red Recording Dot
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: _pulseAnimation.value),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: _pulseAnimation.value),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // REC tag
                    const Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Live Time Counter
                    Text(
                      durationStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Live Size badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sizeStr,
                        style: const TextStyle(
                          color: EDesign.primaryCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Stop Button
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.controller.stopRecording(),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.stop_circle, color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
