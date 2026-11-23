import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../models/video_effects_config.dart';

/// Dedicated Cyberpunk Modal Sheet for Deinterlacing & Frame-by-Frame Motion Blur
/// (VLC deinterlace.c and motionblur.c parity).
class DeinterlaceMotionStudioSheet extends StatefulWidget {
  final VideoEffectsConfig config;
  final ValueChanged<VideoEffectsConfig> onConfigChanged;

  const DeinterlaceMotionStudioSheet({
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
      builder: (context) => DeinterlaceMotionStudioSheet(
        config: config,
        onConfigChanged: onConfigChanged,
      ),
    );
  }

  @override
  State<DeinterlaceMotionStudioSheet> createState() => _DeinterlaceMotionStudioSheetState();
}

class _DeinterlaceMotionStudioSheetState extends State<DeinterlaceMotionStudioSheet> {
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
                          EDesign.primaryCyan.withValues(alpha: 0.25),
                          EDesign.secondary.withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.motion_photos_on_rounded, color: EDesign.primaryCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deinterlace & Motion Blur Studio',
                          style: TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'VLC deinterlace.c & motionblur.c parity',
                          style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('deinterlace_motion_reset_button'),
                    onPressed: () {
                      _config.resetDeinterlaceAndMotionBlur();
                      _notify();
                    },
                    child: const Text('Reset', style: TextStyle(color: EDesign.primaryCyan, fontSize: 13)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // SECTION 1: INTERLACED DEINTERLACER
              const Text(
                'Interlaced Video Deinterlacer',
                style: TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Eliminates comb artifacts & field tearing in broadcast/DVD recordings',
                style: TextStyle(color: EDesign.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),

              // Mode Segmented Button
              SegmentedButton<DeinterlaceMode>(
                key: const Key('deinterlace_mode_segmented_button'),
                segments: const [
                  ButtonSegment(
                    value: DeinterlaceMode.off,
                    label: Text('Off'),
                    icon: Icon(Icons.videocam_off_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: DeinterlaceMode.auto,
                    label: Text('Auto'),
                    icon: Icon(Icons.auto_awesome, size: 16),
                  ),
                  ButtonSegment(
                    value: DeinterlaceMode.on,
                    label: Text('On'),
                    icon: Icon(Icons.tune, size: 16),
                  ),
                ],
                selected: {_config.deinterlaceMode},
                onSelectionChanged: (newSelection) {
                  _config.deinterlaceMode = newSelection.first;
                  _notify();
                },
              ),

              if (_config.deinterlaceMode != DeinterlaceMode.off) ...[
                const SizedBox(height: 14),

                // Algorithm ChoiceChips
                const Text(
                  'Deinterlace Algorithm',
                  style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DeinterlaceAlgorithm.values.map((algo) {
                    final isSelected = _config.deinterlaceAlgorithm == algo;
                    return ChoiceChip(
                      key: Key('algo_chip_${algo.name}'),
                      label: Text(algo.label),
                      selected: isSelected,
                      selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _config.deinterlaceAlgorithm = algo;
                          _notify();
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                Text(
                  _config.deinterlaceAlgorithm.description,
                  style: const TextStyle(color: EDesign.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 14),

                // Field Parity Dominance
                const Text(
                  'Field Parity Dominance (Field Order)',
                  style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DeinterlaceFieldOrder.values.map((order) {
                    final isSelected = _config.deinterlaceFieldOrder == order;
                    return ChoiceChip(
                      key: Key('field_order_${order.name}'),
                      label: Text(order.label),
                      selected: isSelected,
                      selectedColor: EDesign.secondary.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? EDesign.secondary : EDesign.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _config.deinterlaceFieldOrder = order;
                          _notify();
                        }
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(color: EDesign.border, height: 20),

              // SECTION 2: FRAME-BY-FRAME MOTION BLUR
              SwitchListTile(
                key: const Key('motion_blur_enable_switch'),
                title: const Text(
                  'Frame-by-Frame Motion Blur',
                  style: TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Cinematic 180° shutter emulation & judder reduction via libavfilter tmix',
                  style: TextStyle(color: EDesign.textMuted, fontSize: 12),
                ),
                value: _config.motionBlurEnabled,
                activeThumbColor: EDesign.primaryCyan,
                activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.4),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  _config.motionBlurEnabled = val;
                  _notify();
                },
              ),

              if (_config.motionBlurEnabled) ...[
                const SizedBox(height: 10),

                // Motion Blur Presets
                const Text(
                  'Motion Blur Shutter Preset',
                  style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MotionBlurPreset.values.map((preset) {
                    final isSelected = _config.motionBlurPreset == preset;
                    return ChoiceChip(
                      key: Key('motion_preset_${preset.name}'),
                      label: Text(preset.label),
                      selected: isSelected,
                      selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _config.motionBlurPreset = preset;
                          if (preset != MotionBlurPreset.custom) {
                            _config.motionBlurFrames = preset.defaultFrames;
                          }
                          _notify();
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                Text(
                  _config.motionBlurPreset.description,
                  style: const TextStyle(color: EDesign.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 14),

                // Temporal Frame Span Slider (2 to 7 frames)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Temporal Mixing Window',
                      style: TextStyle(color: EDesign.textSecondary, fontSize: 13),
                    ),
                    Text(
                      '${_config.motionBlurFrames} Frames',
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
                    key: const Key('motion_blur_frames_slider'),
                    value: _config.motionBlurFrames.toDouble(),
                    min: 2.0,
                    max: 7.0,
                    divisions: 5,
                    onChanged: (val) {
                      _config.motionBlurFrames = val.round();
                      _config.motionBlurPreset = MotionBlurPreset.custom;
                      _notify();
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Kernel Formula Badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: EDesign.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: EDesign.textMuted, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kernel: tmix=frames=${_config.motionBlurFrames}:weights="${computeMotionBlurWeights(_config.motionBlurFrames)}"',
                          style: const TextStyle(
                            color: EDesign.textSecondary,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
