import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../../ui/theme/e_design_tokens.dart';
import '../../export/domain/export_service.dart';
import '../../export/ui/export_screen.dart';
import '../../library/domain/library_provider.dart';

class EnhanceScreen extends StatefulWidget {
  const EnhanceScreen({super.key});

  @override
  State<EnhanceScreen> createState() => _EnhanceScreenState();
}

class _EnhanceScreenState extends State<EnhanceScreen> {
  bool _aiEnhancementVideo = true;
  String _enhancementMode = 'Auto';
  String _model = 'Real-ESRGAN';
  String _resolution = '1080p';
  bool _rifeEnabled = false;
  bool _nightMode = false;
  bool _stereo3D = false;

  Future<void> _queueOfflineExport(BuildContext context) async {
    final libraryProvider = context.read<LibraryProvider>();
    final exportService = context.read<ExportService>();

    String? sourcePath = libraryProvider.recentFiles.isNotEmpty
        ? libraryProvider.recentFiles.first.path
        : null;

    if (sourcePath == null) {
      final picked = await FilePicker.pickFile(type: FileType.video);
      sourcePath = picked?.path;
    }
    if (sourcePath == null) return;

    final dir = p.dirname(sourcePath);
    final base = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(dir, '${base}_${_resolution}_enhanced.mkv');
    final jobId = 'EXP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    exportService.addJob(
      ExportJob(
        id: jobId,
        sourcePath: sourcePath,
        outputPath: outPath,
        resolutionTarget: _resolution,
        fpsTarget: _rifeEnabled ? 60 : 30,
        enableAudioEnhancement: !_aiEnhancementVideo || _nightMode,
        enableSubtitles: true,
      ),
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExportScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Enhancement Studio', style: EDesign.h2),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_play_next, color: EDesign.primary),
            tooltip: 'Open Export Queue',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('AI Enhancement'),
            const SizedBox(height: 12),
            _buildToggle(
              'Video',
              'Audio',
              _aiEnhancementVideo,
              (val) => setState(() => _aiEnhancementVideo = val),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('Enhancement Mode'),
            const SizedBox(height: 12),
            _buildSegmentedControl(
              ['Auto', 'Manual', 'Preset'],
              _enhancementMode,
              (val) => setState(() => _enhancementMode = val),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('Model'),
            const SizedBox(height: 12),
            _buildDropdown(
              ['Real-ESRGAN', 'Anime4K', 'FSRCNN'],
              _model,
              (val) => setState(() => _model = val),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('Resolution'),
            const SizedBox(height: 12),
            _buildSegmentedControl(
              ['720p', '1080p', '1440p', '2160p/4K'],
              _resolution,
              (val) => setState(() => _resolution = val),
            ),

            const SizedBox(height: 32),
            _buildSwitchRow(
              'RIFE Frame Interpolation (60 FPS)',
              _rifeEnabled,
              (val) => setState(() => _rifeEnabled = val),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              'Night Mode (Loudness & Dynamic Range)',
              _nightMode,
              (val) => setState(() => _nightMode = val),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              'Stereoscopic 3D (Depth Anything V2)',
              _stereo3D,
              (val) => setState(() => _stereo3D = val),
            ),

            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Applied $_model ($_resolution${_rifeEnabled ? " · 60fps RIFE" : ""}) profile.',
                            ),
                            backgroundColor: EDesign.primary,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EDesign.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(EDesign.r14),
                        ),
                      ),
                      child: const Text(
                        'Apply Live Profile',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () => _queueOfflineExport(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EDesign.aiAccent,
                        side: const BorderSide(color: EDesign.secondary, width: 1.5),
                        backgroundColor: EDesign.secondary.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(EDesign.r14),
                        ),
                      ),
                      icon: const Icon(Icons.movie_filter_outlined, size: 20),
                      label: const Text(
                        'Export Offline',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: EDesign.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildToggle(String left, String right, bool isLeft, Function(bool) onChanged) {
    return Container(
      decoration: EDesign.cardDecoration(radius: EDesign.r14),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isLeft ? EDesign.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(EDesign.r14),
                  border: isLeft
                      ? Border.all(color: EDesign.primary)
                      : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text(
                  left,
                  style: TextStyle(
                    color: isLeft ? EDesign.primary : EDesign.textSecondary,
                    fontWeight: isLeft ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isLeft ? EDesign.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(EDesign.r14),
                  border: !isLeft
                      ? Border.all(color: EDesign.primary)
                      : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text(
                  right,
                  style: TextStyle(
                    color: !isLeft ? EDesign.primary : EDesign.textSecondary,
                    fontWeight: !isLeft ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(
    List<String> options,
    String current,
    Function(String) onChanged,
  ) {
    return Container(
      decoration: EDesign.cardDecoration(radius: EDesign.r14),
      child: Row(
        children: options.map((opt) {
          final isActive = opt == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? EDesign.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(EDesign.r14),
                  border: isActive
                      ? Border.all(color: EDesign.primary)
                      : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isActive ? EDesign.primary : EDesign.textSecondary,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdown(
    List<String> options,
    String current,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: EDesign.cardDecoration(radius: EDesign.r14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          dropdownColor: EDesign.elevatedSurface,
          icon: const Icon(Icons.keyboard_arrow_down, color: EDesign.textSecondary),
          style: const TextStyle(color: EDesign.textPrimary, fontSize: 16),
          items: options.map((opt) {
            return DropdownMenuItem(value: opt, child: Text(opt));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String title, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: EDesign.cardDecoration(radius: EDesign.r14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title, style: EDesign.body),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: EDesign.primary,
            activeTrackColor: EDesign.primary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}
