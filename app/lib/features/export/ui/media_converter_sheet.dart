import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/media_converter_models.dart';
import '../domain/media_converter_service.dart';

/// Cyberpunk Modal Sheet for Quick Media Transcoding and Audio Extraction (VLC sout transcode parity).
class MediaConverterSheet extends StatefulWidget {
  final MediaConverterService service;
  final String? initialSourcePath;
  final Duration? currentDuration;

  const MediaConverterSheet({
    super.key,
    required this.service,
    this.initialSourcePath,
    this.currentDuration,
  });

  static Future<void> show(
    BuildContext context, {
    required MediaConverterService service,
    String? initialSourcePath,
    Duration? currentDuration,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MediaConverterSheet(
        service: service,
        initialSourcePath: initialSourcePath,
        currentDuration: currentDuration,
      ),
    );
  }

  @override
  State<MediaConverterSheet> createState() => _MediaConverterSheetState();
}

class _MediaConverterSheetState extends State<MediaConverterSheet> {
  late String _sourcePath;
  late String _outputPath;
  TranscodePreset _selectedPreset = TranscodePreset.mp3_320k;

  @override
  void initState() {
    super.initState();
    _sourcePath = widget.initialSourcePath ?? 'Sample_Media.mkv';
    _updateDefaultOutputPath();
  }

  void _updateDefaultOutputPath() {
    if (_sourcePath.isEmpty) {
      _outputPath = 'output${_selectedPreset.format.fileExtension}';
      return;
    }
    final lastDot = _sourcePath.lastIndexOf('.');
    final base = lastDot != -1 ? _sourcePath.substring(0, lastDot) : _sourcePath;
    _outputPath = '${base}_converted${_selectedPreset.format.fileExtension}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final activeTask = widget.service.activeTask;
        final isConverting = widget.service.isConverting;

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
                        child: const Icon(Icons.transform_rounded, color: EDesign.primaryCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Media Converter & Extractor',
                              style: TextStyle(
                                color: EDesign.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'VLC sout transcode & audio extraction parity',
                              style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Source File Selection Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EDesign.elevatedBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EDesign.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.movie_outlined, color: EDesign.primaryCyan, size: 16),
                            SizedBox(width: 8),
                            Text('Source Media File', style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _sourcePath,
                                style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ElevatedButton.icon(
                              key: const Key('converter_browse_source_button'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: EDesign.surface,
                                foregroundColor: EDesign.primaryCyan,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: const Text('Browse', style: TextStyle(fontSize: 12)),
                              onPressed: isConverting
                                  ? null
                                  : () async {
                                      try {
                                        final result = await FilePicker.pickFile(type: FileType.media);
                                        if (result != null && result.path != null) {
                                          setState(() {
                                            _sourcePath = result.path!;
                                            _updateDefaultOutputPath();
                                          });
                                        }
                                      } catch (e) {
                                        debugPrint('Picker error: $e');
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Presets Selection
                  const Text(
                    'Conversion & Extraction Presets',
                    style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TranscodePreset.allPresets.map((preset) {
                      final isSelected = _selectedPreset.id == preset.id;
                      return ChoiceChip(
                        key: Key('converter_preset_${preset.id}'),
                        avatar: Icon(
                          preset.isAudioOnly ? Icons.music_note_rounded : Icons.video_file_rounded,
                          size: 14,
                          color: isSelected ? EDesign.primaryCyan : EDesign.textMuted,
                        ),
                        label: Text(preset.name),
                        selected: isSelected,
                        selectedColor: EDesign.primaryCyan.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? EDesign.primaryCyan : EDesign.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: isConverting
                            ? null
                            : (val) {
                                if (val) {
                                  setState(() {
                                    _selectedPreset = preset;
                                    _updateDefaultOutputPath();
                                  });
                                }
                              },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Output Destination Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EDesign.elevatedBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EDesign.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.output_rounded, color: EDesign.primaryCyan, size: 16),
                            SizedBox(width: 8),
                            Text('Output Destination', style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _outputPath,
                          style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Conversion Progress & Action Controls
                  if (isConverting && activeTask != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: EDesign.elevatedBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Transcoding... ${activeTask.progressPercent}%',
                                style: const TextStyle(color: EDesign.primaryCyan, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                activeTask.formattedSpeed,
                                style: const TextStyle(color: EDesign.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: activeTask.progress,
                              backgroundColor: EDesign.surface,
                              valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primaryCyan),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Elapsed: ${activeTask.formattedElapsed}',
                                style: const TextStyle(color: EDesign.textMuted, fontSize: 12),
                              ),
                              Text(
                                'ETA: ${activeTask.formattedEta}',
                                style: const TextStyle(color: EDesign.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: const Key('converter_cancel_button'),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Cancel Conversion'),
                              onPressed: () => widget.service.cancelActiveTask(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    if (activeTask != null && activeTask.status == TranscodeTaskStatus.completed)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Transcoding Complete! Output file ready.',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('converter_start_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EDesign.primaryCyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.flash_on_rounded, size: 20),
                        label: Text(
                          _selectedPreset.isAudioOnly ? 'Extract Audio Track' : 'Convert Video Stream',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () {
                          widget.service.startConversion(
                            sourcePath: _sourcePath,
                            outputPath: _outputPath,
                            preset: _selectedPreset,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
