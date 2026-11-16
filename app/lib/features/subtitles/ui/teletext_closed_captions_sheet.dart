import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../data/teletext_closed_caption_controller.dart';
import '../models/teletext_closed_caption_models.dart';

/// Interactive Teletext (zvbi.c) & Closed Captions (cc.c) Configuration Studio.
class TeletextClosedCaptionsSheet extends StatefulWidget {
  final TeletextClosedCaptionController controller;

  const TeletextClosedCaptionsSheet({
    super.key,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required TeletextClosedCaptionController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: TeletextClosedCaptionsSheet(controller: controller),
      ),
    );
  }

  @override
  State<TeletextClosedCaptionsSheet> createState() =>
      _TeletextClosedCaptionsSheetState();
}

class _TeletextClosedCaptionsSheetState
    extends State<TeletextClosedCaptionsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A), // Dark slate surface
      borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.closed_caption, color: EDesign.primaryCyan, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Teletext & Closed-Captions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: EDesign.primaryCyan,
            labelColor: EDesign.primaryCyan,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.tv, size: 18), text: 'Teletext (VBI / zvbi.c)'),
              Tab(icon: Icon(Icons.subtitles, size: 18), text: 'Closed-Captions (cc.c)'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTeletextTab(),
                _buildClosedCaptionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: TELETEXT (zvbi.c) ---
  Widget _buildTeletextTab() {
    final teletext = widget.controller.teletextConfig;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          title: const Text(
            'Enable Teletext Decoder',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text(
            'Decodes VBI teletext broadcast stream with retro OSD (zvbi.c parity)',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          value: teletext.enabled,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => widget.controller.toggleTeletext(val),
        ),

        const Divider(color: Colors.white12, height: 20),

        // Page Display & Preset Shortcuts
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT TELETEXT PAGE',
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFEB3B), width: 1.5),
                  ),
                  child: Text(
                    widget.controller.hasKeypadInput
                        ? 'PAGE ${widget.controller.keypadBuffer}..'
                        : 'PAGE ${teletext.page}',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFFFFEB3B),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  tooltip: 'Previous Subpage',
                  onPressed: () => widget.controller.prevSubpage(),
                ),
                const SizedBox(width: 8),
                Text(
                  '${teletext.subpage.toString().padLeft(2, '0')}/01',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  tooltip: 'Next Subpage',
                  onPressed: () => widget.controller.nextSubpage(),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Quick Page Shortcuts', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip('100 Main Index', 100, teletext.page),
            _buildPresetChip('888 Subtitles (DHH)', 888, teletext.page),
            _buildPresetChip('777 TV Schedule', 777, teletext.page),
            _buildPresetChip('200 Sports', 200, teletext.page),
            _buildPresetChip('333 Weather', 333, teletext.page),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Fastext Navigation Keys', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFastextBtn(
                color: const Color(0xFFEF4444),
                label: 'RED (P${teletext.fastTextRed})',
                onTap: () => widget.controller.pressRed(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFastextBtn(
                color: const Color(0xFF10B981),
                label: 'GREEN (P${teletext.fastTextGreen})',
                onTap: () => widget.controller.pressGreen(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFastextBtn(
                color: const Color(0xFFF59E0B),
                label: 'YELLOW (P${teletext.fastTextYellow})',
                onTap: () => widget.controller.pressYellow(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFastextBtn(
                color: const Color(0xFF3B82F6),
                label: 'BLUE (P${teletext.fastTextBlue})',
                onTap: () => widget.controller.pressBlue(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Retro Numeric Keypad (Enter 3-Digit Page)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _buildNumericKeypad(),

        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Opaque Boxed Background', style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text('High-contrast retro black backing box (VLC vbi-opaque parity)', style: TextStyle(color: Colors.white54, fontSize: 12)),
          value: teletext.isOpaque,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            widget.controller.updateTeletextConfig(teletext.copyWith(isOpaque: val));
          },
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, int page, int activePage) {
    final isSelected = (page == activePage);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
      onSelected: (_) => widget.controller.setTeletextPage(page),
    );
  }

  Widget _buildFastextBtn({
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildKeypadDigit(1),
              _buildKeypadDigit(2),
              _buildKeypadDigit(3),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKeypadDigit(4),
              _buildKeypadDigit(5),
              _buildKeypadDigit(6),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKeypadDigit(7),
              _buildKeypadDigit(8),
              _buildKeypadDigit(9),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => widget.controller.clearKeypad(),
                  child: const Text('CLR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              _buildKeypadDigit(0),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primaryCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    if (widget.controller.hasKeypadInput) {
                      final p = int.tryParse(widget.controller.keypadBuffer);
                      if (p != null) widget.controller.setTeletextPage(p);
                    }
                  },
                  child: const Text('GO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadDigit(int digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          key: Key('teletext_digit_$digit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () => widget.controller.inputDigit(digit),
          child: Text(
            digit.toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
          ),
        ),
      ),
    );
  }

  // --- TAB 2: CLOSED CAPTIONS (cc.c) ---
  Widget _buildClosedCaptionsTab() {
    final caption = widget.controller.captionConfig;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          title: const Text(
            'Enable Closed Captions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text(
            'EIA-608 & CEA-708 DTVCC decoding with FCC styling (cc.c parity)',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          value: caption.isEnabled,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            widget.controller.setClosedCaptionChannel(
              val ? ClosedCaptionChannel.cc1 : ClosedCaptionChannel.off,
            );
          },
        ),

        const Divider(color: Colors.white12, height: 20),

        const Text('Caption Service / Channel', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        // Channel Selector Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ch in ClosedCaptionChannel.values)
              ChoiceChip(
                label: Text(ch.label),
                selected: caption.channel == ch,
                selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                onSelected: (selected) {
                  if (selected) widget.controller.setClosedCaptionChannel(ch);
                },
              ),
          ],
        ),

        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Opaque Boxed Text', style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text('Renders high-contrast black bounding box (VLC cc-opaque parity)', style: TextStyle(color: Colors.white54, fontSize: 12)),
          value: caption.isOpaque,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            widget.controller.updateCaptionConfig(caption.copyWith(isOpaque: val));
          },
        ),

        const SizedBox(height: 12),
        const Text('Font Size', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final size in [18.0, 24.0, 32.0, 40.0])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    size == 18.0 ? 'Small (75%)' : size == 24.0 ? 'Standard (100%)' : size == 32.0 ? 'Large (150%)' : 'Extra Large (200%)',
                  ),
                  selected: caption.fontSize == size,
                  selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                  onSelected: (sel) {
                    if (sel) widget.controller.updateCaptionConfig(caption.copyWith(fontSize: size));
                  },
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Text Edge Style', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final edge in CaptionEdgeStyle.values)
              ChoiceChip(
                label: Text(edge.label),
                selected: caption.edgeStyle == edge,
                selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                onSelected: (sel) {
                  if (sel) widget.controller.updateCaptionConfig(caption.copyWith(edgeStyle: edge));
                },
              ),
          ],
        ),

        const SizedBox(height: 20),
        const Text('Live Closed Caption Preview (FCC Parity)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: caption.isOpaque
                    ? caption.backgroundColor.withValues(alpha: caption.backgroundOpacity)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${caption.channel.shortCode}  "This is live closed caption dialogue."',
                style: TextStyle(
                  fontFamily: caption.fontFamily,
                  fontSize: caption.fontSize * 0.7, // scaled for preview box
                  color: caption.fontColor.withValues(alpha: caption.fontOpacity),
                  fontWeight: FontWeight.bold,
                  shadows: caption.edgeStyle == CaptionEdgeStyle.dropShadow
                      ? const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
