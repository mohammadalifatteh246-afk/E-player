import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../data/stream_recorder_controller.dart';
import '../models/stream_recorder_models.dart';

/// Modal bottom sheet allowing users to configure output format,
/// manage recording destination, and start/stop stream recording (VLC record.c parity).
class StreamRecorderSheet extends StatefulWidget {
  final StreamRecorderController controller;
  final String? mediaTitle;
  final String? sourceUrl;

  const StreamRecorderSheet({
    super.key,
    required this.controller,
    this.mediaTitle,
    this.sourceUrl,
  });

  @override
  State<StreamRecorderSheet> createState() => _StreamRecorderSheetState();
}

class _StreamRecorderSheetState extends State<StreamRecorderSheet> {
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

  @override
  Widget build(BuildContext context) {
    final isRec = widget.controller.isRecording;
    final config = widget.controller.config;
    final session = widget.controller.currentSession;

    return Material(
      color: const Color(0xFF0F172A), // Dark slate background
      borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    color: isRec ? Colors.redAccent : EDesign.primaryCyan,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Stream Recorder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'record.c',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Live Recording Monitor Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isRec ? Colors.redAccent.withValues(alpha: 0.1) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRec ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isRec ? Colors.redAccent : Colors.white38,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isRec ? 'RECORDING IN PROGRESS' : 'RECORDER IDLE',
                              style: TextStyle(
                                color: isRec ? Colors.redAccent : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        if (isRec)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.controller.activeFormattedSize,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Big Monospace Time Display
                    Text(
                      isRec ? widget.controller.activeFormattedDuration : '00:00:00',
                      style: TextStyle(
                        color: isRec ? Colors.white : Colors.white38,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                        letterSpacing: 2,
                      ),
                    ),

                    if (isRec && session != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        session.filePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Courier'),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Big Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('stream_recorder_toggle_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRec ? Colors.redAccent : EDesign.primaryCyan,
                          foregroundColor: isRec ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(isRec ? Icons.stop : Icons.fiber_manual_record),
                        label: Text(
                          isRec ? 'Stop Recording (Save Stream Dump)' : 'Start Stream Recording',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () {
                          widget.controller.toggleRecording(
                            mediaTitle: widget.mediaTitle,
                            sourceUrl: widget.sourceUrl,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Container Format Selection
              const Text(
                'Container Format Preset',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RecordingFormat.values.map((fmt) {
                  final isSelected = config.format == fmt;
                  return ChoiceChip(
                    label: Text(fmt.label),
                    selected: isSelected,
                    selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                    labelStyle: TextStyle(
                      color: isSelected ? EDesign.primaryCyan : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: isRec
                        ? null
                        : (selected) {
                            if (selected) {
                              widget.controller.updateConfig(config.copyWith(format: fmt));
                            }
                          },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white12),

              // Storage & Automation Toggles
              SwitchListTile(
                title: const Text('Auto-add to Media Library', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Add finished capture to video playlist immediately', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: config.autoAddToLibrary,
                activeThumbColor: EDesign.primaryCyan,
                contentPadding: EdgeInsets.zero,
                onChanged: isRec
                    ? null
                    : (val) {
                        widget.controller.updateConfig(config.copyWith(autoAddToLibrary: val));
                      },
              ),

              SwitchListTile(
                title: const Text('Audio Only Stream Dump', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Discard video packets and record audio stream only', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: config.audioOnly,
                activeThumbColor: EDesign.primaryCyan,
                contentPadding: EdgeInsets.zero,
                onChanged: isRec
                    ? null
                    : (val) {
                        widget.controller.updateConfig(config.copyWith(audioOnly: val));
                      },
              ),

              const SizedBox(height: 12),
              // Shortcut Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.keyboard, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'VLC Parity Shortcut: Press Shift + R during playback to instantly start or stop stream recording.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
