import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../models/video_effects_config.dart';

/// Dedicated Cyberpunk Modal Sheet for 3D Anaglyph Stereoscopic Video Filter (VLC anaglyph.c parity)
class AnaglyphStudioSheet extends StatefulWidget {
  final VideoEffectsConfig config;
  final ValueChanged<VideoEffectsConfig> onConfigChanged;

  const AnaglyphStudioSheet({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VideoEffectsConfig config,
    required ValueChanged<VideoEffectsConfig> onConfigChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnaglyphStudioSheet(
        config: config,
        onConfigChanged: onConfigChanged,
      ),
    );
  }

  @override
  State<AnaglyphStudioSheet> createState() => _AnaglyphStudioSheetState();
}

class _AnaglyphStudioSheetState extends State<AnaglyphStudioSheet> {
  late VideoEffectsConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  void _notify() {
    widget.onConfigChanged(_config);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: EDesign.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EDesign.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent.withValues(alpha: 0.25),
                          EDesign.primaryCyan.withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.remove_red_eye_rounded, color: EDesign.primaryCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3D Anaglyph Studio',
                          style: TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'VLC anaglyph.c stereoscopic 3D parity',
                          style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('anaglyph_reset_button'),
                    onPressed: () {
                      _config.resetAnaglyph();
                      _notify();
                    },
                    child: const Text('Reset', style: TextStyle(color: EDesign.primaryCyan, fontSize: 13)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Master Enable Switch
              SwitchListTile(
                key: const Key('anaglyph_enable_switch'),
                title: const Text(
                  'Enable 3D Stereoscopic Filter',
                  style: TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Render video with Red-Cyan stereoscopic anaglyph glasses filter',
                  style: TextStyle(color: EDesign.textMuted, fontSize: 12),
                ),
                value: _config.anaglyphEnabled,
                activeThumbColor: EDesign.primaryCyan,
                activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.4),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  _config.anaglyphEnabled = val;
                  _notify();
                },
              ),

              if (_config.anaglyphEnabled) ...[
                const Divider(color: EDesign.border, height: 20),

                // Source Mode Selector
                const Text(
                  'Input Video Format',
                  style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSourceChip(
                      AnaglyphSourceMode.synthetic2D,
                      '2D Synthetic (Parallax)',
                      Icons.auto_awesome_motion_rounded,
                    ),
                    _buildSourceChip(
                      AnaglyphSourceMode.sideBySideHalf,
                      'Side-by-Side (SBS 3D)',
                      Icons.view_column_rounded,
                    ),
                    _buildSourceChip(
                      AnaglyphSourceMode.topAndBottomHalf,
                      'Top-and-Bottom (TaB 3D)',
                      Icons.view_agenda_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Glasses Color Scheme Selector
                const Text(
                  'Glasses Color Scheme',
                  style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMatrixChip(
                      AnaglyphColorMatrix.redCyanDubois,
                      'Red-Cyan (Dubois)',
                      Colors.cyanAccent,
                    ),
                    _buildMatrixChip(
                      AnaglyphColorMatrix.redCyanColor,
                      'Red-Cyan (Color)',
                      Colors.redAccent,
                    ),
                    _buildMatrixChip(
                      AnaglyphColorMatrix.greenMagenta,
                      'Green-Magenta',
                      Colors.purpleAccent,
                    ),
                    _buildMatrixChip(
                      AnaglyphColorMatrix.amberBlue,
                      'Amber-Blue (ColorCode)',
                      Colors.amberAccent,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Parallax Disparity Slider (Only in synthetic mode or fine-tuning)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Parallax Disparity (Horizontal Offset)',
                      style: TextStyle(color: EDesign.textSecondary, fontSize: 13),
                    ),
                    Text(
                      '${_config.anaglyphParallax > 0 ? "+" : ""}${_config.anaglyphParallax.round()} px',
                      style: const TextStyle(color: EDesign.primaryCyan, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: EDesign.primaryCyan,
                    inactiveTrackColor: EDesign.border,
                    thumbColor: EDesign.primaryCyan,
                    overlayColor: EDesign.primaryCyan.withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    key: const Key('anaglyph_parallax_slider'),
                    value: _config.anaglyphParallax.clamp(-30.0, 30.0),
                    min: -30.0,
                    max: 30.0,
                    divisions: 60,
                    onChanged: (val) {
                      _config.anaglyphParallax = val;
                      _notify();
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Left / Right Eye Swapping Switch
                SwitchListTile(
                  key: const Key('anaglyph_swap_eyes_switch'),
                  title: const Text(
                    'Swap Left / Right Eyes',
                    style: TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Invert 3D depth polarity (Cross-eye / Right eye first)',
                    style: TextStyle(color: EDesign.textMuted, fontSize: 12),
                  ),
                  value: _config.anaglyphSwapEyes,
                  activeThumbColor: EDesign.primaryCyan,
                  activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.4),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    _config.anaglyphSwapEyes = val;
                    _notify();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceChip(AnaglyphSourceMode mode, String label, IconData icon) {
    final isSelected = _config.anaglyphSource == mode;
    return ChoiceChip(
      key: Key('anaglyph_source_${mode.name}'),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? EDesign.primaryCyan : EDesign.textMuted,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: EDesign.primaryCyan.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? EDesign.primaryCyan : EDesign.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) {
          _config.anaglyphSource = mode;
          _notify();
        }
      },
    );
  }

  Widget _buildMatrixChip(AnaglyphColorMatrix matrix, String label, Color accentColor) {
    final isSelected = _config.anaglyphMatrix == matrix;
    return ChoiceChip(
      key: Key('anaglyph_matrix_${matrix.name}'),
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
        ),
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: EDesign.primaryCyan.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? EDesign.primaryCyan : EDesign.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) {
          _config.anaglyphMatrix = matrix;
          _notify();
        }
      },
    );
  }
}
