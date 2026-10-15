import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../../ui/theme/e_design_tokens.dart';
import '../../player/ui/player_screen.dart';
import '../domain/export_service.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  Future<void> _promptNewExportJob(BuildContext context, ExportService service) async {
    final picked = await FilePicker.pickFile(type: FileType.video);
    if (picked == null || picked.path == null) return;

    final srcPath = picked.path!;
    final dir = p.dirname(srcPath);
    final base = p.basenameWithoutExtension(srcPath);
    final outPath = p.join(dir, '${base}_eplayer_enhanced.mkv');
    final jobId = 'EXP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    service.addJob(
      ExportJob(
        id: jobId,
        sourcePath: srcPath,
        outputPath: outPath,
        resolutionTarget: '1080p',
        fpsTarget: 60,
        enableAudioEnhancement: true,
        enableSubtitles: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExportService>(
      builder: (context, exportService, child) {
        final jobs = exportService.jobs;
        final activeCount = jobs
            .where((j) =>
                j.status == ExportStatus.processing ||
                j.status == ExportStatus.pending)
            .length;
        final completedCount =
            jobs.where((j) => j.status == ExportStatus.completed).length;

        return Scaffold(
          backgroundColor: EDesign.appBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('AI Export Queue', style: EDesign.h2),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: EDesign.primary),
                tooltip: 'New AI Export Job',
                onPressed: () => _promptNewExportJob(context, exportService),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _promptNewExportJob(context, exportService),
            backgroundColor: EDesign.primary,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.auto_awesome),
            label: const Text(
              'New AI Export',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: Column(
            children: [
              // Queue Summary Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: EDesign.cardDecoration(
                    color: EDesign.elevatedSurface,
                    radius: EDesign.r18,
                    withGlow: activeCount > 0,
                    glowColor: EDesign.secondary,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              EDesign.primary.withValues(alpha: 0.2),
                              EDesign.secondary.withValues(alpha: 0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(EDesign.r14),
                        ),
                        child: const Icon(
                          Icons.memory_rounded,
                          color: EDesign.aiAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Offline AI Engine', style: EDesign.h3),
                                const SizedBox(width: 8),
                                EDesign.buildBadge(
                                  activeCount > 0 ? 'PROCESSING' : 'IDLE',
                                  color: activeCount > 0
                                      ? EDesign.aiAccent
                                      : EDesign.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$activeCount active · $completedCount completed · C++ FFI Tiled ONNX',
                              style: EDesign.secondaryStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Export Jobs List
              Expanded(
                child: jobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_filter_outlined,
                              size: 72,
                              color: EDesign.secondary.withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Active or Completed Exports',
                              style: EDesign.h3.copyWith(color: EDesign.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Queue an offline Real-ESRGAN / RIFE export job to enhance media locally.',
                              style: EDesign.secondaryStyle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
                        physics: const BouncingScrollPhysics(),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          final srcName = p.basename(job.sourcePath);
                          final stageText = job.stageLabel;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: EDesign.cardDecoration(
                              color: EDesign.surface,
                              borderColor: job.status == ExportStatus.processing
                                  ? EDesign.primary.withValues(alpha: 0.6)
                                  : EDesign.border,
                              radius: EDesign.r14,
                              withGlow: job.status == ExportStatus.processing,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_outlined,
                                      color: EDesign.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        srcName.isNotEmpty ? srcName : job.id,
                                        style: const TextStyle(
                                          color: EDesign.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusChip(job.status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Job ${job.id} → ${p.basename(job.outputPath)}',
                                  style: EDesign.caption,
                                ),
                                const SizedBox(height: 12),

                                // Enhancement Spec Badges
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    EDesign.buildBadge(
                                      'TARGET ${job.resolutionTarget}',
                                      color: EDesign.primary,
                                      icon: Icons.hd_outlined,
                                    ),
                                    EDesign.buildBadge(
                                      '${job.fpsTarget} FPS RIFE',
                                      color: EDesign.secondary,
                                      icon: Icons.speed,
                                    ),
                                    if (job.enableAudioEnhancement)
                                      EDesign.buildBadge(
                                        'RNNOISE AUDIO',
                                        color: EDesign.aiAccent,
                                        icon: Icons.graphic_eq,
                                      ),
                                    if (job.enableSubtitles)
                                      EDesign.buildBadge(
                                        'SUBS MUX',
                                        color: EDesign.success,
                                        icon: Icons.subtitles_outlined,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Stage & Progress Bar
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      stageText,
                                      style: TextStyle(
                                        color: job.status == ExportStatus.processing
                                            ? EDesign.primary
                                            : EDesign.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${(job.progress * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: EDesign.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: job.status == ExportStatus.completed
                                        ? 1.0
                                        : job.progress.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: EDesign.elevatedSurface,
                                    color: job.status == ExportStatus.failed
                                        ? EDesign.danger
                                        : job.status == ExportStatus.completed
                                            ? EDesign.success
                                            : EDesign.primary,
                                  ),
                                ),

                                if (job.status == ExportStatus.failed && job.error != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    job.error!,
                                    style: const TextStyle(color: EDesign.danger, fontSize: 12),
                                  ),
                                ],

                                // Action Buttons
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (job.status == ExportStatus.processing ||
                                        job.status == ExportStatus.pending)
                                      TextButton.icon(
                                        onPressed: () => exportService.cancelJob(job.id),
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          color: EDesign.danger,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Cancel & Clean .tmp',
                                          style: TextStyle(color: EDesign.danger),
                                        ),
                                      ),
                                    if (job.status == ExportStatus.completed)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: EDesign.primary,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(EDesign.r10),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PlayerScreen(mediaPath: job.outputPath),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.play_arrow, size: 18),
                                        label: const Text(
                                          'Play Enhanced Output',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(ExportStatus status) {
    Color color;
    String label;

    switch (status) {
      case ExportStatus.pending:
        color = EDesign.textSecondary;
        label = 'QUEUED';
        break;
      case ExportStatus.processing:
        color = EDesign.primary;
        label = 'PROCESSING';
        break;
      case ExportStatus.completed:
        color = EDesign.success;
        label = 'COMPLETED';
        break;
      case ExportStatus.failed:
        color = EDesign.danger;
        label = 'FAILED';
        break;
      case ExportStatus.cancelled:
        color = EDesign.warning;
        label = 'CANCELLED';
        break;
      case ExportStatus.paused:
        color = EDesign.warning;
        label = 'PAUSED';
        break;
    }

    return EDesign.buildBadge(label, color: color);
  }
}
