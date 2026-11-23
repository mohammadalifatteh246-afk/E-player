import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/cdda_models.dart';
import '../data/audio_cd_ripper_service.dart';

/// Cyberpunk Modal Sheet for Audio CD Track Extraction & Tagging (VLC cdda.c parity).
class AudioCdRipperSheet extends StatefulWidget {
  final AudioCdDiscInfo disc;
  final AudioCdRipperService ripperService;
  final String outputDirectory;

  const AudioCdRipperSheet({
    super.key,
    required this.disc,
    required this.ripperService,
    required this.outputDirectory,
  });

  static Future<void> show(
    BuildContext context, {
    required AudioCdDiscInfo disc,
    required AudioCdRipperService ripperService,
    required String outputDirectory,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AudioCdRipperSheet(
        disc: disc,
        ripperService: ripperService,
        outputDirectory: outputDirectory,
      ),
    );
  }

  @override
  State<AudioCdRipperSheet> createState() => _AudioCdRipperSheetState();
}

class _AudioCdRipperSheetState extends State<AudioCdRipperSheet> {
  late AudioRipFormat _selectedFormat;
  late AudioCdDiscInfo _disc;

  @override
  void initState() {
    super.initState();
    _disc = widget.disc;
    _selectedFormat = AudioRipFormat.flac;
    widget.ripperService.addListener(_onRipperUpdate);
  }

  @override
  void dispose() {
    widget.ripperService.removeListener(_onRipperUpdate);
    super.dispose();
  }

  void _onRipperUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      for (final track in _disc.tracks) {
        track.isSelected = select;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ripper = widget.ripperService;
    final progress = ripper.progress;
    final selectedCount = _disc.tracks.where((t) => t.isSelected).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
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

              // Disc Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          EDesign.primaryCyan.withValues(alpha: 0.25),
                          EDesign.secondary.withValues(alpha: 0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.album_rounded, color: EDesign.primaryCyan, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _disc.albumTitle,
                          style: const TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_disc.artist} • ${_disc.tracks.length} Tracks • ${_disc.formattedTotalDuration}',
                          style: const TextStyle(color: EDesign.textSecondary, fontSize: 12),
                        ),
                        if (_disc.genre != null || _disc.releaseYear != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (_disc.genre != null) _disc.genre,
                              if (_disc.releaseYear != null) _disc.releaseYear,
                            ].join(' • '),
                            style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: EDesign.border, height: 1),
              const SizedBox(height: 14),

              // SECTION 1: OUTPUT FORMAT SELECTOR
              const Text(
                'TARGET AUDIO ENCODING FORMAT',
                style: TextStyle(
                  color: EDesign.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AudioRipFormat.values.map((format) {
                  final isSelected = _selectedFormat == format;
                  return ChoiceChip(
                    key: Key('rip_format_${format.name}'),
                    avatar: Icon(
                      format.isLossless ? Icons.high_quality_rounded : Icons.audiotrack_rounded,
                      size: 16,
                      color: isSelected ? EDesign.primaryCyan : EDesign.textMuted,
                    ),
                    label: Text(format.label),
                    selected: isSelected,
                    selectedColor: EDesign.primaryCyan.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: ripper.isRipping
                        ? null
                        : (selected) {
                            if (selected) {
                              setState(() => _selectedFormat = format);
                            }
                          },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              const Divider(color: EDesign.border, height: 1),
              const SizedBox(height: 12),

              // SECTION 2: TRACK LIST SELECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DISC TRACKS ($selectedCount/${_disc.tracks.length} SELECTED)',
                    style: const TextStyle(
                      color: EDesign.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (!ripper.isRipping)
                    Row(
                      children: [
                        TextButton(
                          key: const Key('rip_select_all_button'),
                          onPressed: () => _toggleSelectAll(true),
                          child: const Text('All', style: TextStyle(color: EDesign.primaryCyan, fontSize: 12)),
                        ),
                        TextButton(
                          key: const Key('rip_deselect_all_button'),
                          onPressed: () => _toggleSelectAll(false),
                          child: const Text('None', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _disc.tracks.length,
                separatorBuilder: (_, index) => const Divider(color: EDesign.border, height: 1),
                itemBuilder: (context, index) {
                  final track = _disc.tracks[index];
                  return CheckboxListTile(
                    key: Key('cd_track_checkbox_${track.trackNumber}'),
                    value: track.isSelected,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    activeColor: EDesign.primaryCyan,
                    checkColor: EDesign.appBackground,
                    onChanged: ripper.isRipping
                        ? null
                        : (val) {
                            setState(() {
                              track.isSelected = val ?? false;
                            });
                          },
                    title: Text(
                      '${track.trackNumber.toString().padLeft(2, '0')}. ${track.title}',
                      style: TextStyle(
                        color: track.isSelected ? EDesign.textPrimary : EDesign.textMuted,
                        fontSize: 13,
                        fontWeight: track.isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${track.artist} • ${track.formattedDuration}',
                      style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),
              const Divider(color: EDesign.border, height: 1),
              const SizedBox(height: 14),

              // SECTION 3: RIP PROGRESS & CONTROLS
              if (progress.isRipping) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Ripping Track ${progress.currentTrackIndex}/${progress.totalSelectedTracks}: "${progress.currentTrackTitle}"',
                        style: const TextStyle(color: EDesign.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${progress.progressPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(color: EDesign.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: const Key('rip_progress_indicator'),
                    value: (progress.progressPercent / 100.0).clamp(0.0, 1.0),
                    backgroundColor: EDesign.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primaryCyan),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('rip_cancel_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EDesign.danger,
                      side: const BorderSide(color: EDesign.danger),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Ripping'),
                    onPressed: ripper.cancelRip,
                  ),
                ),
              ] else if (progress.isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EDesign.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EDesign.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: EDesign.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Extraction Complete! ${progress.totalSelectedTracks} tracks ripped to ${widget.outputDirectory}',
                          style: const TextStyle(color: EDesign.success, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (progress.hasError) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EDesign.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EDesign.danger),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: EDesign.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          progress.errorMessage ?? 'An error occurred during ripping.',
                          style: const TextStyle(color: EDesign.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (!progress.isRipping)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('start_rip_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EDesign.primaryCyan,
                      foregroundColor: EDesign.appBackground,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      selectedCount > 0 ? 'Rip $selectedCount Track(s) (${_selectedFormat.label})' : 'Select Tracks to Rip',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: selectedCount == 0
                        ? null
                        : () {
                            ripper.ripSelectedTracks(
                              disc: _disc,
                              outputDirectory: widget.outputDirectory,
                              format: _selectedFormat,
                            );
                          },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
