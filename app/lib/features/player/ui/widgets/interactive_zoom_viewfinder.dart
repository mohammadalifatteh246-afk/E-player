import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../../services/interactive_zoom_controller.dart';

/// Floating Mini-Map Viewfinder HUD providing real-time spatial orientation and pan control
/// during zoomed video playback. Parity with VLC's interactive zoom overlay (magnify.c).
class InteractiveZoomViewfinder extends StatefulWidget {
  final InteractiveZoomController controller;
  final VoidCallback? onClose;

  const InteractiveZoomViewfinder({
    super.key,
    required this.controller,
    this.onClose,
  });

  @override
  State<InteractiveZoomViewfinder> createState() => _InteractiveZoomViewfinderState();
}

class _InteractiveZoomViewfinderState extends State<InteractiveZoomViewfinder> {
  static const double _viewfinderWidth = 180.0;
  static const double _viewfinderHeight = 101.0; // ~16:9 aspect ratio

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final state = widget.controller.state;
    if (state.zoomFactor <= 1.0) return;

    // Convert pixel delta to normalized pan delta (-1.0 to 1.0)
    final dxNormalized = details.delta.dx / (_viewfinderWidth * 0.5);
    final dyNormalized = details.delta.dy / (_viewfinderHeight * 0.5);

    widget.controller.setPan(
      (state.panX + dxNormalized).clamp(-1.0, 1.0),
      (state.panY + dyNormalized).clamp(-1.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final rect = state.viewportRect;

    return Container(
      width: _viewfinderWidth + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1220), // Frosted dark glass
        borderRadius: BorderRadius.circular(EDesign.r12),
        border: Border.all(color: EDesign.primary.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with zoom level and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.zoom_in, color: EDesign.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${state.zoomFactor.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: EDesign.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.onClose != null)
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, color: EDesign.textMuted, size: 14),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Mini-map Viewport Canvas
          GestureDetector(
            onPanUpdate: _onPanUpdate,
            child: Container(
              width: _viewfinderWidth,
              height: _viewfinderHeight,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(EDesign.r6),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Stack(
                children: [
                  // Grid guidelines
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MiniMapGridPainter(),
                    ),
                  ),

                  // Active Zoom Viewport Box
                  Positioned(
                    left: rect.left * _viewfinderWidth,
                    top: rect.top * _viewfinderHeight,
                    width: rect.width * _viewfinderWidth,
                    height: rect.height * _viewfinderHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: EDesign.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: EDesign.primary,
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.crop_free,
                          color: Colors.white70,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Quick Zoom Nudge Bar
          Row(
            children: [
              Expanded(child: _buildSmallButton('-', () => widget.controller.nudgeZoom(-0.5))),
              const SizedBox(width: 3),
              Expanded(child: _buildSmallButton('1.0x', () => widget.controller.reset())),
              const SizedBox(width: 3),
              Expanded(child: _buildSmallButton('2.0x', () => widget.controller.setZoom(2.0))),
              const SizedBox(width: 3),
              Expanded(child: _buildSmallButton('4.0x', () => widget.controller.setZoom(4.0))),
              const SizedBox(width: 3),
              Expanded(child: _buildSmallButton('+', () => widget.controller.nudgeZoom(0.5))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EDesign.border, width: 0.6),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: EDesign.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MiniMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;

    // Draw horizontal & vertical rule-of-thirds lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
