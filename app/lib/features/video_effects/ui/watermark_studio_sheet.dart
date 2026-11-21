import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../models/video_effects_config.dart';

/// Dedicated Cyberpunk Modal Sheet for Watermark & Logo Overlay (VLC logo.c parity)
class WatermarkStudioSheet extends StatefulWidget {
  final VideoEffectsConfig config;
  final ValueChanged<VideoEffectsConfig> onConfigChanged;

  const WatermarkStudioSheet({
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
      builder: (context) => WatermarkStudioSheet(
        config: config,
        onConfigChanged: onConfigChanged,
      ),
    );
  }

  @override
  State<WatermarkStudioSheet> createState() => _WatermarkStudioSheetState();
}

class _WatermarkStudioSheetState extends State<WatermarkStudioSheet> {
  late VideoEffectsConfig _config;
  late final TextEditingController _textController;
  bool _isTextMode = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _isTextMode = _config.logoText != null && _config.logoText!.isNotEmpty;
    _textController = TextEditingController(text: _config.logoText ?? 'E-PLAYER');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
                    color: EDesign.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.branding_watermark_rounded, color: EDesign.primaryCyan, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watermark & Logo Studio',
                        style: TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'VLC logo.c overlay parity',
                        style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('watermark_reset_button'),
                  onPressed: () {
                    _config.resetOverlay();
                    _textController.text = '';
                    _isTextMode = false;
                    _notify();
                  },
                  child: const Text('Reset', style: TextStyle(color: EDesign.primaryCyan, fontSize: 13)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Master Enable Switch
            SwitchListTile(
              key: const Key('watermark_enable_switch'),
              title: const Text('Enable Watermark Overlay', style: TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Render transparent logo or custom text banner on top of video', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
              value: _config.logoEnabled,
              activeThumbColor: EDesign.primaryCyan,
              activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.4),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                _config.logoEnabled = val;
                _notify();
              },
            ),

            if (_config.logoEnabled) ...[
              const Divider(color: EDesign.border, height: 20),

              // Source Selector: Image File vs Custom Text
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('watermark_mode_image'),
                      label: const Text('Image File (PNG/JPG)'),
                      selected: !_isTextMode,
                      selectedColor: EDesign.primaryCyan.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: !_isTextMode ? EDesign.primaryCyan : EDesign.textSecondary,
                        fontWeight: !_isTextMode ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          _isTextMode = false;
                          _notify();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('watermark_mode_text'),
                      label: const Text('Text Watermark'),
                      selected: _isTextMode,
                      selectedColor: EDesign.primaryCyan.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _isTextMode ? EDesign.primaryCyan : EDesign.textSecondary,
                        fontWeight: _isTextMode ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          _isTextMode = true;
                          _config.logoText ??= _textController.text;
                          _notify();
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Image Picker Card
              if (!_isTextMode)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EDesign.elevatedBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image_rounded, color: EDesign.primaryCyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _config.logoPath != null && _config.logoPath!.isNotEmpty
                              ? File(_config.logoPath!).uri.pathSegments.last
                              : 'No logo image selected',
                          style: TextStyle(
                            color: _config.logoPath != null ? EDesign.textPrimary : EDesign.textMuted,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_config.logoPath != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white70),
                          onPressed: () {
                            _config.logoPath = null;
                            _notify();
                          },
                        ),
                      ElevatedButton.icon(
                        key: const Key('watermark_browse_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EDesign.surface,
                          foregroundColor: EDesign.primaryCyan,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Browse', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          try {
                            final result = await FilePicker.pickFile(type: FileType.image);
                            if (result != null && result.path != null) {
                              _config.logoPath = result.path!;
                              _notify();
                            }
                          } catch (e) {
                            debugPrint('FilePicker error: $e');
                          }
                        },
                      ),
                    ],
                  ),
                )
              else
                TextField(
                  key: const Key('watermark_text_field'),
                  controller: _textController,
                  style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Watermark Text',
                    labelStyle: const TextStyle(color: EDesign.primaryCyan),
                    hintText: 'e.g. E-PLAYER • COPYRIGHT 2026',
                    hintStyle: const TextStyle(color: EDesign.textMuted),
                    filled: true,
                    fillColor: EDesign.elevatedBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EDesign.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EDesign.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: EDesign.primaryCyan)),
                  ),
                  onChanged: (text) {
                    _config.logoText = text;
                    _notify();
                  },
                ),

              const SizedBox(height: 16),

              // 3x3 Position Grid Selector
              const Text(
                'Position Anchor (9-Point Grid)',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Center(
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: EDesign.elevatedBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      _buildGridButton(VideoOverlayPosition.topLeft, Icons.north_west_rounded),
                      _buildGridButton(VideoOverlayPosition.topCenter, Icons.north_rounded),
                      _buildGridButton(VideoOverlayPosition.topRight, Icons.north_east_rounded),
                      _buildGridButton(VideoOverlayPosition.centerLeft, Icons.west_rounded),
                      _buildGridButton(VideoOverlayPosition.center, Icons.filter_center_focus_rounded),
                      _buildGridButton(VideoOverlayPosition.centerRight, Icons.east_rounded),
                      _buildGridButton(VideoOverlayPosition.bottomLeft, Icons.south_west_rounded),
                      _buildGridButton(VideoOverlayPosition.bottomCenter, Icons.south_rounded),
                      _buildGridButton(VideoOverlayPosition.bottomRight, Icons.south_east_rounded),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Opacity Slider
              _buildSliderRow(
                title: 'Opacity',
                label: '${(_config.logoOpacity * 100).round()}%',
                value: _config.logoOpacity,
                min: 0.05,
                max: 1.0,
                onChanged: (val) {
                  _config.logoOpacity = val;
                  _notify();
                },
              ),

              // Scale Slider
              _buildSliderRow(
                title: 'Scale Size',
                label: '${_config.logoScale.toStringAsFixed(1)}x',
                value: _config.logoScale,
                min: 0.2,
                max: 2.5,
                onChanged: (val) {
                  _config.logoScale = val;
                  _notify();
                },
              ),

              // Offset X Slider
              _buildSliderRow(
                title: 'Offset X (Pixels)',
                label: '${_config.logoOffsetX} px',
                value: _config.logoOffsetX.toDouble(),
                min: 0.0,
                max: 300.0,
                onChanged: (val) {
                  _config.logoOffsetX = val.round();
                  _notify();
                },
              ),

              // Offset Y Slider
              _buildSliderRow(
                title: 'Offset Y (Pixels)',
                label: '${_config.logoOffsetY} px',
                value: _config.logoOffsetY.toDouble(),
                min: 0.0,
                max: 300.0,
                onChanged: (val) {
                  _config.logoOffsetY = val.round();
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

  Widget _buildGridButton(VideoOverlayPosition pos, IconData icon) {
    final isSelected = _config.logoPosition == pos;
    return InkWell(
      key: Key('watermark_pos_${pos.name}'),
      onTap: () {
        _config.logoPosition = pos;
        _notify();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? EDesign.primaryCyan.withValues(alpha: 0.2) : EDesign.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? EDesign.primaryCyan : EDesign.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? EDesign.primaryCyan : EDesign.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: EDesign.textSecondary, fontSize: 13)),
              Text(label, style: const TextStyle(color: EDesign.primaryCyan, fontSize: 13, fontWeight: FontWeight.bold)),
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
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
