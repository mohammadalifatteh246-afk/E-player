import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../data/teletext_closed_caption_controller.dart';
import '../models/teletext_closed_caption_models.dart';

/// Retro Broadcast Teletext (zvbi.c) & Closed Captions (cc.c) On-Screen Display (OSD) Overlay.
class TeletextOsdOverlayWidget extends StatefulWidget {
  final TeletextClosedCaptionController controller;
  final VoidCallback? onOpenSettings;

  const TeletextOsdOverlayWidget({
    super.key,
    required this.controller,
    this.onOpenSettings,
  });

  @override
  State<TeletextOsdOverlayWidget> createState() => _TeletextOsdOverlayWidgetState();
}

class _TeletextOsdOverlayWidgetState extends State<TeletextOsdOverlayWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TeletextOsdOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final teletext = widget.controller.teletextConfig;
    final caption = widget.controller.captionConfig;

    if (!teletext.enabled && !caption.isEnabled) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Fullscreen / Boxed Retro Teletext Screen (zvbi.c parity)
        if (teletext.enabled) _buildTeletextScreen(teletext),

        // Closed Captions Channel Badge & Status (cc.c parity)
        if (caption.isEnabled && !teletext.enabled) _buildClosedCaptionsBadge(caption),
      ],
    );
  }

  Widget _buildTeletextScreen(TeletextConfig teletext) {
    final pageContent = TeletextPageContent.generate(teletext.page, teletext.subpage);
    final isOpaque = teletext.isOpaque;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 580),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isOpaque ? const Color(0xFF000000) : const Color(0xCC000000),
          border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Retro Teletext Top Status Header
            Container(
              color: const Color(0xFF0B1220),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.controller.hasKeypadInput
                          ? 'P${widget.controller.keypadBuffer}..'
                          : 'P${teletext.page}',
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SUB ${teletext.subpage.toString().padLeft(2, '0')}/01',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white70, size: 18),
                    tooltip: 'Teletext & CC Settings',
                    onPressed: widget.onOpenSettings,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    tooltip: 'Close Teletext',
                    onPressed: () => widget.controller.toggleTeletext(false),
                  ),
                ],
              ),
            ),

            // Teletext 40x24 ASCII Content Screen
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  physics: const ClampingScrollPhysics(),
                  itemCount: pageContent.lines.length,
                  itemBuilder: (context, i) {
                    final line = pageContent.lines[i];
                    return Text(
                      line,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: i < 3 ? pageContent.headerColor : const Color(0xFFFFFFFF),
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Fastext 4-Color Quick Navigation Bar (Red, Green, Yellow, Blue)
            Container(
              color: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFastextPill(
                      color: const Color(0xFFEF4444),
                      label: 'P${teletext.fastTextRed}',
                      onTap: () => widget.controller.pressRed(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFastextPill(
                      color: const Color(0xFF10B981),
                      label: 'P${teletext.fastTextGreen}',
                      onTap: () => widget.controller.pressGreen(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFastextPill(
                      color: const Color(0xFFF59E0B),
                      label: 'P${teletext.fastTextYellow}',
                      onTap: () => widget.controller.pressYellow(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFastextPill(
                      color: const Color(0xFF3B82F6),
                      label: 'P${teletext.fastTextBlue}',
                      onTap: () => widget.controller.pressBlue(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFastextPill({
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Courier',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClosedCaptionsBadge(ClosedCaptionConfig caption) {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xDD000000),
          borderRadius: BorderRadius.circular(EDesign.r8),
          border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.closed_caption, color: Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 6),
            Text(
              caption.channel.shortCode,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Courier',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
