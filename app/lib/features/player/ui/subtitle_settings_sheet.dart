import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';

/// Configuration model managing live subtitle rendering and sync properties in libmpv.
class SubtitleConfig {
  double delay; // -30.0s to +30.0s sync offset
  double fontSize; // 18.0 to 72.0
  Color fontColor;
  Color outlineColor;
  Color backgroundColor;
  double outlineSize; // 0.0 to 6.0
  double position; // 0 to 100
  String fontFamily; // Inter, Roboto, Serif, Monospace
  String encoding;
  bool overrideAss;
  bool isBold;
  bool isItalic;

  SubtitleConfig({
    this.delay = 0.0,
    this.fontSize = 36.0,
    this.fontColor = Colors.white,
    this.outlineColor = Colors.black,
    this.backgroundColor = Colors.transparent,
    this.outlineSize = 2.5,
    this.position = 92.0,
    this.fontFamily = 'Inter',
    this.encoding = 'UTF-8',
    this.overrideAss = false,
    this.isBold = true,
    this.isItalic = false,
  });

  static String _colorToHex(Color c) {
    final r = ((c.r * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((c.g * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = ((c.b * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  void apply(Player? player) {
    if (player == null) return;
    try {
      final platform = player.platform as dynamic;
      platform.setProperty('sub-delay', delay.toStringAsFixed(2));
      platform.setProperty('sub-font-size', fontSize.round().toString());
      platform.setProperty('sub-color', _colorToHex(fontColor));
      platform.setProperty('sub-border-color', _colorToHex(outlineColor));
      platform.setProperty('sub-back-color', _colorToHex(backgroundColor));
      platform.setProperty('sub-border-size', outlineSize.toStringAsFixed(1));
      platform.setProperty('sub-pos', position.round().toString());
      platform.setProperty('sub-codepage', encoding);
      platform.setProperty('sub-ass-override', overrideAss ? 'force' : 'no');
      platform.setProperty('sub-font', fontFamily);
      platform.setProperty('sub-bold', isBold ? 'yes' : 'no');
      platform.setProperty('sub-italic', isItalic ? 'yes' : 'no');
    } catch (e) {
      debugPrint('[SubtitleConfig] Error applying subtitle properties: $e');
    }
  }

  void reset(Player? player) {
    delay = 0.0;
    fontSize = 36.0;
    fontColor = Colors.white;
    outlineColor = Colors.black;
    backgroundColor = Colors.transparent;
    outlineSize = 2.5;
    position = 92.0;
    fontFamily = 'Inter';
    encoding = 'UTF-8';
    overrideAss = false;
    isBold = true;
    isItalic = false;
    apply(player);
  }
}

/// Standalone Full-Page Route for Global Settings Navigation
class SubtitleCustomizationScreen extends StatelessWidget {
  final Player? player;
  final SubtitleConfig? config;

  const SubtitleCustomizationScreen({super.key, this.player, this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Subtitle Customization', style: EDesign.h2),
        centerTitle: true,
      ),
      body: SubtitleSettingsSheet(
        player: player,
        config: config ?? SubtitleConfig(),
        isFullScreen: true,
      ),
    );
  }
}

/// Screen 6: Subtitle Customization Sheet
///
/// Features:
/// - Live 16:9 letterboxed rendering preview box ("This is a subtitle preview")
/// - Synchronized audio/sub offset slider with wide -30.0s to +30.0s range
/// - Precision step buttons (-0.5s, -0.1s, +0.1s, +0.5s) for zero-friction sync
/// - Typography: Font Size, Font Family, Bold, Italic
/// - Colors: Text Fill, Stroke Outline, and Background Scrim
/// - Advanced: ASS/SSA Style Override & Character Codepage Selector
class SubtitleSettingsSheet extends StatefulWidget {
  final Player? player;
  final SubtitleConfig config;
  final bool isFullScreen;

  const SubtitleSettingsSheet({
    super.key,
    this.player,
    required this.config,
    this.isFullScreen = false,
  });

  @override
  State<SubtitleSettingsSheet> createState() => _SubtitleSettingsSheetState();
}

class _SubtitleSettingsSheetState extends State<SubtitleSettingsSheet> {
  late SubtitleConfig _config;
  Timer? _debounceTimer;

  // Curated color choices
  static const List<Color> _textColors = [
    Colors.white,
    Color(0xFF19BFFF), // Electric Cyan
    Color(0xFFFFEB3B), // Classic Subtitle Yellow
    Color(0xFFFFC107), // Warm Amber
    Color(0xFF69F0AE), // Mint Green
    Color(0xFFFF5252), // Soft Coral Red
  ];

  static const List<Color> _outlineColors = [
    Colors.black,
    Color(0xFF1B3556), // Navy Border
    Color(0xFF263238), // Charcoal
    Colors.transparent,
  ];

  static const List<Color> _bgColors = [
    Colors.transparent,
    Color(0x66000000), // 40% Black Scrim
    Color(0xCC000000), // 80% Solid Box
    Color(0x800D1728), // Frosted Navy
  ];

  static const List<String> _fontFamilies = [
    'Inter',
    'Roboto',
    'Serif',
    'Monospace',
  ];

  static const List<String> _encodings = [
    'UTF-8',
    'Windows-1252',
    'ISO-8859-1',
    'GBK',
    'Shift-JIS',
    'EUC-KR',
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debouncedApply() {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 160), () {
      _config.apply(widget.player);
    });
  }

  void _nudgeDelay(double delta) {
    setState(() {
      _config.delay = (_config.delay + delta).clamp(-30.0, 30.0);
    });
    _debouncedApply();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isFullScreen) ...[
          // Bottom Sheet Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: EDesign.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Sheet Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: const Icon(Icons.subtitles, color: EDesign.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subtitle Customization',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Live Video Preview, Sync Offset & Font Styling',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: EDesign.textMuted, size: 20),
                tooltip: 'Reset to Defaults',
                onPressed: () {
                  setState(() {
                    _config.reset(widget.player);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subtitles reset to system defaults.'),
                      backgroundColor: EDesign.elevatedSurface,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // 1. Live Letterboxed Subtitle Preview Box
        _buildLetterboxPreview(),
        const SizedBox(height: 18),

        // 2. Scrollable Controls Body
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Section A: Sync Offset (-30.0s to +30.0s)
              _buildSectionTitle('Timing & Audio Synchronization', Icons.sync),
              _buildSyncOffsetCard(),
              const SizedBox(height: 20),

              // Section B: Typography & Sizing
              _buildSectionTitle('Typography & Dimensions', Icons.format_size),
              _buildTypographyCard(),
              const SizedBox(height: 20),

              // Section C: Color Palette & Outline
              _buildSectionTitle('Colors & Contrast', Icons.palette_outlined),
              _buildColorSectionCard(),
              const SizedBox(height: 20),

              // Section D: Position & Advanced Overrides
              _buildSectionTitle('Position & Advanced Engine', Icons.tune),
              _buildAdvancedCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );

    if (widget.isFullScreen) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: content,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: content,
    );
  }

  // --- 1. LIVE LETTERBOXED SUBTITLE PREVIEW BOX ---
  Widget _buildLetterboxPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: EDesign.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 21 / 9, // Cinematic widescreen letterbox
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cinematic Background Frame
            Image.asset(
              'assets/thumbnails/demo_city.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF0A111F),
                child: const Center(
                  child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 36),
                ),
              ),
            ),

            // Top letterbox gradient overlay for cinematic contrast
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Top-left preview badge
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(EDesign.r6),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: EDesign.primary, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'LIVE PREVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dynamic Subtitle Rendering Box
            Align(
              alignment: Alignment(
                0.0,
                ((_config.position - 50.0) / 50.0).clamp(-0.85, 0.85),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _config.backgroundColor,
                  borderRadius: BorderRadius.circular(EDesign.r6),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pass 1: Outline / Stroke
                    if (_config.outlineSize > 0 &&
                        _config.outlineColor != Colors.transparent)
                      Text(
                        'This is a subtitle preview',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: (_config.fontSize * 0.46).clamp(12.0, 32.0),
                          fontFamily: _config.fontFamily,
                          fontWeight: _config.isBold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: _config.isItalic ? FontStyle.italic : FontStyle.normal,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = _config.outlineSize * 1.4
                            ..color = _config.outlineColor,
                        ),
                      ),

                    // Pass 2: Text Fill
                    Text(
                      'This is a subtitle preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: (_config.fontSize * 0.46).clamp(12.0, 32.0),
                        fontFamily: _config.fontFamily,
                        fontWeight: _config.isBold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: _config.isItalic ? FontStyle.italic : FontStyle.normal,
                        color: _config.fontColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. SYNC OFFSET CARD (-30.0s to +30.0s) ---
  Widget _buildSyncOffsetCard() {
    final delay = _config.delay;
    String statusText;
    Color statusColor;

    if (delay.abs() < 0.05) {
      statusText = '0.0s (Exact AV Sync)';
      statusColor = EDesign.success;
    } else if (delay < 0) {
      statusText = '${delay.toStringAsFixed(1)}s (Subtitles Appearing Early)';
      statusColor = EDesign.warning;
    } else {
      statusText = '+${delay.toStringAsFixed(1)}s (Subtitles Delayed)';
      statusColor = EDesign.primary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      child: Column(
        children: [
          // Header with live sync status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Audio-to-Subtitle Offset',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Wide -30.0s to +30.0s continuous slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EDesign.primary,
              inactiveTrackColor: EDesign.border,
              thumbColor: Colors.white,
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
            ),
            child: Slider(
              value: delay.clamp(-30.0, 30.0),
              min: -30.0,
              max: 30.0,
              onChanged: (v) {
                setState(() => _config.delay = v);
                _debouncedApply();
              },
            ),
          ),

          // Micro & Macro Nudge Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNudgeButton('-0.5s', () => _nudgeDelay(-0.5)),
              _buildNudgeButton('-0.1s', () => _nudgeDelay(-0.1)),
              TextButton(
                onPressed: () {
                  setState(() => _config.delay = 0.0);
                  _debouncedApply();
                },
                child: const Text('Reset Sync', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
              ),
              _buildNudgeButton('+0.1s', () => _nudgeDelay(0.1)),
              _buildNudgeButton('+0.5s', () => _nudgeDelay(0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EDesign.r8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(EDesign.r8),
          border: Border.all(color: EDesign.border, width: 0.8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: EDesign.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- 3. TYPOGRAPHY CARD ---
  Widget _buildTypographyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font Size Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Font Size', style: TextStyle(color: EDesign.textSecondary, fontSize: 13)),
              Text(
                '${_config.fontSize.round()} pt',
                style: const TextStyle(color: EDesign.primary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EDesign.primary,
              inactiveTrackColor: EDesign.border,
              thumbColor: Colors.white,
              trackHeight: 3.0,
            ),
            child: Slider(
              value: _config.fontSize.clamp(18.0, 72.0),
              min: 18.0,
              max: 72.0,
              onChanged: (v) {
                setState(() => _config.fontSize = v);
                _debouncedApply();
              },
            ),
          ),
          const SizedBox(height: 12),

          // Font Family Selector
          const Text('Font Family', style: TextStyle(color: EDesign.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: _fontFamilies.map((fam) {
              final isSelected = _config.fontFamily == fam;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _config.fontFamily = fam);
                      _debouncedApply();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? EDesign.primary.withValues(alpha: 0.18)
                            : EDesign.surface,
                        borderRadius: BorderRadius.circular(EDesign.r8),
                        border: Border.all(
                          color: isSelected ? EDesign.primary : EDesign.border,
                          width: isSelected ? 1.4 : 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        fam,
                        style: TextStyle(
                          color: isSelected ? EDesign.primary : EDesign.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: fam,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Weight & Style Toggles (Bold & Italic)
          Row(
            children: [
              Expanded(
                child: _buildStyleToggle(
                  label: 'Bold Weight',
                  icon: Icons.format_bold,
                  isActive: _config.isBold,
                  onTap: () {
                    setState(() => _config.isBold = !_config.isBold);
                    _debouncedApply();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStyleToggle(
                  label: 'Italic Style',
                  icon: Icons.format_italic,
                  isActive: _config.isItalic,
                  onTap: () {
                    setState(() => _config.isItalic = !_config.isItalic);
                    _debouncedApply();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyleToggle({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? EDesign.primary.withValues(alpha: 0.18) : EDesign.surface,
          borderRadius: BorderRadius.circular(EDesign.r8),
          border: Border.all(
            color: isActive ? EDesign.primary : EDesign.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? EDesign.primary : EDesign.textMuted, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? EDesign.primary : EDesign.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. COLOR PALETTE & OUTLINE CARD ---
  Widget _buildColorSectionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text Fill Color
          _buildColorPickerRow(
            label: 'Text Color',
            colors: _textColors,
            selectedColor: _config.fontColor,
            onSelect: (c) {
              setState(() => _config.fontColor = c);
              _debouncedApply();
            },
          ),
          const Divider(height: 20, color: EDesign.border),

          // Outline Color
          _buildColorPickerRow(
            label: 'Outline Stroke Color',
            colors: _outlineColors,
            selectedColor: _config.outlineColor,
            onSelect: (c) {
              setState(() => _config.outlineColor = c);
              _debouncedApply();
            },
          ),
          const SizedBox(height: 10),

          // Outline Width Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Outline Thickness', style: TextStyle(color: EDesign.textSecondary, fontSize: 12)),
              Text(
                '${_config.outlineSize.toStringAsFixed(1)} px',
                style: const TextStyle(color: EDesign.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EDesign.primary,
              inactiveTrackColor: EDesign.border,
              thumbColor: Colors.white,
              trackHeight: 2.5,
            ),
            child: Slider(
              value: _config.outlineSize.clamp(0.0, 6.0),
              min: 0.0,
              max: 6.0,
              onChanged: (v) {
                setState(() => _config.outlineSize = v);
                _debouncedApply();
              },
            ),
          ),
          const Divider(height: 20, color: EDesign.border),

          // Background Box / Scrim
          _buildColorPickerRow(
            label: 'Background Box Scrim',
            colors: _bgColors,
            selectedColor: _config.backgroundColor,
            onSelect: (c) {
              setState(() => _config.backgroundColor = c);
              _debouncedApply();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerRow({
    required String label,
    required List<Color> colors,
    required Color selectedColor,
    required ValueChanged<Color> onSelect,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: EDesign.textSecondary, fontSize: 13)),
        Row(
          children: colors.map((c) {
            final isSelected = selectedColor.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c == Colors.transparent ? Colors.grey.shade900 : c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? EDesign.primary : Colors.white24,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: EDesign.primary.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: c == Colors.transparent
                    ? const Icon(Icons.block, size: 14, color: Colors.white54)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- 5. POSITION & ADVANCED SETTINGS CARD ---
  Widget _buildAdvancedCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical Position Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vertical Position', style: TextStyle(color: EDesign.textSecondary, fontSize: 13)),
              Text(
                '${_config.position.round()}%',
                style: const TextStyle(color: EDesign.primary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EDesign.primary,
              inactiveTrackColor: EDesign.border,
              thumbColor: Colors.white,
              trackHeight: 2.5,
            ),
            child: Slider(
              value: _config.position.clamp(0.0, 100.0),
              min: 0.0,
              max: 100.0,
              onChanged: (v) {
                setState(() => _config.position = v);
                _debouncedApply();
              },
            ),
          ),
          const Divider(height: 20, color: EDesign.border),

          // Override ASS/SSA Styles Switch
          SwitchListTile(
            title: const Text(
              'Override Embedded ASS Styles',
              style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Force custom typography & color over embedded scripts',
              style: TextStyle(color: EDesign.textMuted, fontSize: 11),
            ),
            value: _config.overrideAss,
            activeThumbColor: EDesign.primary,
            activeTrackColor: EDesign.primary.withValues(alpha: 0.35),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white12,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() => _config.overrideAss = val);
              _debouncedApply();
            },
          ),
          const Divider(height: 20, color: EDesign.border),

          // Character Codepage Encoding Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Character Encoding',
                    style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Codepage for legacy .srt files',
                    style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: EDesign.surface,
                  borderRadius: BorderRadius.circular(EDesign.r8),
                  border: Border.all(color: EDesign.border, width: 0.8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _config.encoding,
                    dropdownColor: EDesign.elevatedSurface,
                    icon: const Icon(Icons.arrow_drop_down, color: EDesign.primary),
                    style: const TextStyle(color: EDesign.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    items: _encodings.map((enc) {
                      return DropdownMenuItem(value: enc, child: Text(enc));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _config.encoding = val);
                        _debouncedApply();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: EDesign.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: EDesign.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
