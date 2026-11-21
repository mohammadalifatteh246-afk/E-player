import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../domain/dual_subtitle_controller.dart';

/// Screen / Modal Sheet: Dual Subtitle Studio
/// Allows users to render two subtitle tracks simultaneously (VLC parity):
/// - Primary Subtitle at screen bottom (default 92%)
/// - Secondary Subtitle at screen top (default 10%)
/// - Independent secondary sync offset (-30s to +30s) and 1-tap track swap
class DualSubtitleSheet extends StatefulWidget {
  final DualSubtitleController controller;
  final List<SubtitleTrack> availableTracks;

  const DualSubtitleSheet({
    super.key,
    required this.controller,
    required this.availableTracks,
  });

  /// Displays the DualSubtitleSheet as a bottom sheet
  static Future<void> show(
    BuildContext context, {
    required DualSubtitleController controller,
    required List<SubtitleTrack> availableTracks,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DualSubtitleSheet(
        controller: controller,
        availableTracks: availableTracks,
      ),
    );
  }

  @override
  State<DualSubtitleSheet> createState() => _DualSubtitleSheetState();
}

class _DualSubtitleSheetState extends State<DualSubtitleSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  String _formatTrackName(SubtitleTrack track) {
    if (track.id == 'no' || track.id.isEmpty) return 'None (Disabled)';
    if (track.id == 'auto') return 'Auto Selection';
    final title = track.title ?? '';
    final lang = track.language ?? '';
    if (title.isNotEmpty && lang.isNotEmpty) return '$title ($lang)';
    if (title.isNotEmpty) return title;
    if (lang.isNotEmpty) return lang.toUpperCase();
    return 'Track ${track.id}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isEnabled = controller.isEnabled;
    final allTracks = [SubtitleTrack.no(), ...widget.availableTracks];

    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
        border: Border.all(color: EDesign.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: EDesign.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EDesign.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(EDesign.r10),
                  ),
                  child: const Icon(Icons.subtitles_rounded, color: EDesign.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dual Subtitles Studio', style: EDesign.h3),
                      SizedBox(height: 2),
                      Text(
                        'Simultaneous Top & Bottom Tracks (VLC Parity)',
                        style: TextStyle(color: EDesign.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeThumbColor: EDesign.primary,
                  activeTrackColor: EDesign.primary.withValues(alpha: 0.4),
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    controller.toggleDualSubtitles(val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: EDesign.border, height: 1),
            const SizedBox(height: 16),

            // Track Selection Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: EDesign.cardDecoration(
                color: EDesign.elevatedSurface,
                radius: EDesign.r16,
                borderColor: isEnabled ? EDesign.primary.withValues(alpha: 0.4) : EDesign.border,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Primary Subtitle (Bottom)
                  const Row(
                    children: [
                      Icon(Icons.arrow_downward_rounded, size: 14, color: EDesign.primary),
                      SizedBox(width: 6),
                      Text(
                        'PRIMARY SUBTITLE (BOTTOM · 92%)',
                        style: TextStyle(
                          color: EDesign.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTrackDropdown(
                    selected: controller.primaryTrack,
                    tracks: allTracks,
                    onChanged: (track) {
                      if (track != null) controller.setPrimaryTrack(track);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Swap Action Button
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EDesign.primary,
                        side: BorderSide(color: EDesign.primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(EDesign.r10),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        controller.swapTracks();
                      },
                      icon: const Icon(Icons.swap_vert_rounded, size: 18),
                      label: const Text(
                        'Swap Bottom & Top Tracks',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Secondary Subtitle (Top)
                  const Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFE741FF)),
                      SizedBox(width: 6),
                      Text(
                        'SECONDARY SUBTITLE (TOP · 10%)',
                        style: TextStyle(
                          color: Color(0xFFE741FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTrackDropdown(
                    selected: controller.secondaryTrack,
                    tracks: allTracks,
                    onChanged: (track) {
                      if (track != null) controller.setSecondaryTrack(track);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Secondary Subtitle Offset & Timing Card
            if (isEnabled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: EDesign.cardDecoration(
                  color: EDesign.elevatedSurface,
                  radius: EDesign.r16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Secondary Subtitle Delay',
                          style: TextStyle(
                            color: EDesign.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${controller.secondaryDelay >= 0 ? '+' : ''}${controller.secondaryDelay.toStringAsFixed(2)}s',
                          style: const TextStyle(
                            color: Color(0xFFE741FF),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFE741FF),
                        inactiveTrackColor: EDesign.surface,
                        thumbColor: const Color(0xFFE741FF),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: controller.secondaryDelay,
                        min: -10.0,
                        max: 10.0,
                        onChanged: (val) => controller.setSecondaryDelay(val),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Nudge Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNudgeButton('-0.5s', () => controller.nudgeSecondaryDelay(-0.5)),
                        _buildNudgeButton('-0.1s', () => controller.nudgeSecondaryDelay(-0.1)),
                        _buildNudgeButton('Reset (0.0s)', () => controller.setSecondaryDelay(0.0)),
                        _buildNudgeButton('+0.1s', () => controller.nudgeSecondaryDelay(0.1)),
                        _buildNudgeButton('+0.5s', () => controller.nudgeSecondaryDelay(0.5)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Position Presets Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: EDesign.cardDecoration(
                  color: EDesign.elevatedSurface,
                  radius: EDesign.r16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Secondary Subtitle Placement',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: SecondarySubtitlePosition.values.map((preset) {
                          final isSelected =
                              (controller.secondaryPosition - preset.posValue).abs() < 1.0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(preset.label),
                              selected: isSelected,
                              selectedColor: const Color(0xFFE741FF).withValues(alpha: 0.2),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFE741FF)
                                    : EDesign.border,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFFE741FF) : EDesign.textSecondary,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                controller.setSecondaryPosition(preset.posValue);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackDropdown({
    required SubtitleTrack selected,
    required List<SubtitleTrack> tracks,
    required ValueChanged<SubtitleTrack?> onChanged,
  }) {
    // Find matching track
    final matched = tracks.firstWhere(
      (t) => t.id == selected.id,
      orElse: () => tracks.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r10),
        border: Border.all(color: EDesign.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SubtitleTrack>(
          value: matched,
          isExpanded: true,
          dropdownColor: EDesign.elevatedSurface,
          icon: const Icon(Icons.arrow_drop_down, color: EDesign.textSecondary),
          items: tracks.map((track) {
            return DropdownMenuItem<SubtitleTrack>(
              value: track,
              child: Text(
                _formatTrackName(track),
                style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildNudgeButton(String label, VoidCallback onPressed) {
    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r6),
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(EDesign.r6),
          border: Border.all(color: EDesign.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: EDesign.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
