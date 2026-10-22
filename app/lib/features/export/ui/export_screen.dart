import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../../ui/theme/e_design_tokens.dart';
import '../../player/ui/player_screen.dart';
import '../domain/export_service.dart';

/// Screen 13: Export Queue & Multi-Stage Pipeline Monitor
/// Master Stitch Cyberpunk Aesthetics with 6-Stage Progress Stepper,
/// Real-time Rendering FPS & ETA Telemetry, and Animated Sweep Line Preview.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _selectedFilter = 'all';

  Future<void> _promptNewExportJob(ExportService service) async {
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
        resolutionTarget: '4K',
        fpsTarget: 60,
        enableAudioEnhancement: true,
        enableSubtitles: true,
        modelId: 'realesr-general-x4v3',
        totalFrames: 3600,
        currentFps: 49.8,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EDesign.surface,
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: EDesign.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added "$base" to AI Export Pipeline',
                style: const TextStyle(color: EDesign.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r12),
          side: const BorderSide(color: EDesign.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExportService>(
      builder: (context, exportService, child) {
        final allJobs = exportService.jobs;
        final activeJobs = allJobs
            .where((j) =>
                j.status == ExportStatus.processing ||
                j.status == ExportStatus.pending)
            .toList();
        final completedJobs =
            allJobs.where((j) => j.status == ExportStatus.completed).toList();
        final failedJobs = allJobs
            .where((j) =>
                j.status == ExportStatus.failed ||
                j.status == ExportStatus.cancelled)
            .toList();

        List<ExportJob> displayedJobs;
        switch (_selectedFilter) {
          case 'active':
            displayedJobs = activeJobs;
            break;
          case 'completed':
            displayedJobs = completedJobs;
            break;
          case 'failed':
            displayedJobs = failedJobs;
            break;
          default:
            displayedJobs = allJobs;
            break;
        }

        return Scaffold(
          backgroundColor: EDesign.appBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EDesign.textPrimary, size: 20),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stream_rounded, color: EDesign.primary, size: 22),
                const SizedBox(width: 10),
                const Text('AI Pipeline Monitor', style: EDesign.h2),
                const SizedBox(width: 8),
                EDesign.buildBadge(
                  activeJobs.isNotEmpty ? 'RUNNING' : 'STANDBY',
                  color: activeJobs.isNotEmpty ? EDesign.primary : EDesign.textSecondary,
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.science_outlined, color: EDesign.aiAccent),
                tooltip: 'Simulate Demo AI Job',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  exportService.createDemoJob();
                },
              ),
              if (completedJobs.isNotEmpty || failedJobs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.cleaning_services_outlined, color: EDesign.textSecondary),
                  tooltip: 'Clear Finished Jobs',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    exportService.clearCompleted();
                  },
                ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _promptNewExportJob(exportService),
            backgroundColor: EDesign.primary,
            foregroundColor: Colors.black,
            elevation: 8,
            icon: const Icon(Icons.add_task_rounded, size: 22),
            label: const Text(
              'Add Video to Pipeline',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          body: Column(
            children: [
              _buildGlobalTelemetryCard(
                activeCount: activeJobs.length,
                completedCount: completedJobs.length,
                failedCount: failedJobs.length,
                exportService: exportService,
              ),
              _buildFilterChips(
                totalCount: allJobs.length,
                activeCount: activeJobs.length,
                completedCount: completedJobs.length,
                failedCount: failedJobs.length,
              ),
              Expanded(
                child: displayedJobs.isEmpty
                    ? _buildEmptyState(exportService)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        physics: const BouncingScrollPhysics(),
                        itemCount: displayedJobs.length,
                        itemBuilder: (context, index) {
                          return _ExportJobPipelineCard(
                            key: ValueKey(displayedJobs[index].id),
                            job: displayedJobs[index],
                            exportService: exportService,
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

  Widget _buildGlobalTelemetryCard({
    required int activeCount,
    required int completedCount,
    required int failedCount,
    required ExportService exportService,
  }) {
    final bool isEngineActive = activeCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: EDesign.cardDecoration(
          color: EDesign.elevatedSurface,
          radius: EDesign.r18,
          withGlow: isEngineActive,
          glowColor: EDesign.primary,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        EDesign.primary.withValues(alpha: 0.2),
                        EDesign.aiAccent.withValues(alpha: 0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(EDesign.r14),
                    border: Border.all(
                      color: isEngineActive
                          ? EDesign.primary.withValues(alpha: 0.5)
                          : EDesign.border,
                    ),
                  ),
                  child: Icon(
                    Icons.developer_board_rounded,
                    color: isEngineActive ? EDesign.primary : EDesign.textSecondary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('C++ ONNX Neural Engine', style: EDesign.h3),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isEngineActive ? EDesign.primary : EDesign.border,
                              boxShadow: isEngineActive
                                  ? [
                                      BoxShadow(
                                        color: EDesign.primary.withValues(alpha: 0.8),
                                        blurRadius: 6,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEngineActive
                            ? 'D3D11VA Hardware Accelerated · Tiled Tensor Pool'
                            : 'Engine in standby · 0 active background compute threads',
                        style: EDesign.secondaryStyle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildStatPill(
                  label: 'ACTIVE',
                  value: '$activeCount',
                  color: isEngineActive ? EDesign.primary : EDesign.textSecondary,
                  icon: Icons.sync_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  label: 'COMPLETED',
                  value: '$completedCount',
                  color: EDesign.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  label: 'FAILED',
                  value: '$failedCount',
                  color: failedCount > 0 ? EDesign.danger : EDesign.textSecondary,
                  icon: Icons.error_outline_rounded,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: EDesign.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r8),
                    ),
                  ),
                  onPressed: exportService.createDemoJob,
                  icon: const Icon(Icons.play_circle_outline, color: EDesign.aiAccent, size: 16),
                  label: const Text(
                    '+ Sim Job',
                    style: TextStyle(color: EDesign.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: EDesign.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required int totalCount,
    required int activeCount,
    required int completedCount,
    required int failedCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildFilterChip('all', 'All Jobs ($totalCount)'),
          const SizedBox(width: 8),
          _buildFilterChip('active', 'Active ($activeCount)'),
          const SizedBox(width: 8),
          _buildFilterChip('completed', 'Completed ($completedCount)'),
          const SizedBox(width: 8),
          _buildFilterChip('failed', 'Failed / Cancelled ($failedCount)'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String title) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? EDesign.primary.withValues(alpha: 0.15) : EDesign.surface,
          borderRadius: BorderRadius.circular(EDesign.r16),
          border: Border.all(
            color: isSelected ? EDesign.primary : EDesign.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: EDesign.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? EDesign.primary : EDesign.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ExportService service) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EDesign.surface,
                border: Border.all(color: EDesign.primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: EDesign.primary.withValues(alpha: 0.1),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.memory_rounded,
                size: 64,
                color: EDesign.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pipeline Idle · No Jobs Queued',
              style: EDesign.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Queue a video to run multi-stage AI upscaling (Real-ESRGAN),\nRIFE 60FPS motion vector interpolation, and audio enhancement.',
              style: EDesign.secondaryStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r12),
                    ),
                  ),
                  onPressed: () => _promptNewExportJob(service),
                  icon: const Icon(Icons.file_upload_outlined, size: 20),
                  label: const Text(
                    'Pick Video File',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EDesign.aiAccent,
                    side: const BorderSide(color: EDesign.aiAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r12),
                    ),
                  ),
                  onPressed: service.createDemoJob,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    'Simulate Demo Job',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual Export Job Card with Multi-Stage Stepper, Live Telemetry & Sweep Preview
class _ExportJobPipelineCard extends StatelessWidget {
  final ExportJob job;
  final ExportService exportService;

  const _ExportJobPipelineCard({
    super.key,
    required this.job,
    required this.exportService,
  });

  @override
  Widget build(BuildContext context) {
    final bool isProcessing = job.status == ExportStatus.processing;
    final bool isCompleted = job.status == ExportStatus.completed;
    final bool isFailed = job.status == ExportStatus.failed;
    final bool isCancelled = job.status == ExportStatus.cancelled;

    final fileName = p.basename(job.sourcePath);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: EDesign.cardDecoration(
        color: EDesign.surface,
        borderColor: isProcessing
            ? EDesign.primary.withValues(alpha: 0.6)
            : isCompleted
                ? EDesign.success.withValues(alpha: 0.4)
                : isFailed
                    ? EDesign.danger.withValues(alpha: 0.4)
                    : EDesign.border,
        radius: EDesign.r16,
        withGlow: isProcessing,
        glowColor: EDesign.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EDesign.elevatedSurface,
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  border: Border.all(
                    color: isProcessing ? EDesign.primary : EDesign.border,
                  ),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_outline_rounded
                      : isFailed
                          ? Icons.error_outline_rounded
                          : Icons.movie_filter_outlined,
                  color: isCompleted
                      ? EDesign.success
                      : isFailed
                          ? EDesign.danger
                          : EDesign.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.isNotEmpty ? fileName : job.id,
                      style: const TextStyle(
                        color: EDesign.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Target: ${p.basename(job.outputPath)}',
                      style: EDesign.caption.copyWith(color: EDesign.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(job.status),
            ],
          ),

          const SizedBox(height: 12),

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
              EDesign.buildBadge(
                job.modelId,
                color: EDesign.textSecondary,
                icon: Icons.model_training,
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (isProcessing || isCompleted) ...[
            _SweepLineThumbnailPreview(
              job: job,
              isProcessing: isProcessing,
            ),
            const SizedBox(height: 16),
          ],

          _buildMultiStageStepper(job.stage, job.status),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                job.stageLabel,
                style: TextStyle(
                  color: isProcessing ? EDesign.primary : EDesign.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(job.progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isCompleted ? 1.0 : job.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: EDesign.elevatedSurface,
              color: isFailed
                  ? EDesign.danger
                  : isCompleted
                      ? EDesign.success
                      : EDesign.primary,
            ),
          ),

          if (isProcessing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: EDesign.appBackground,
                borderRadius: BorderRadius.circular(EDesign.r10),
                border: Border.all(color: EDesign.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTelemetryMetric(
                    label: 'RENDER SPEED',
                    value: '${job.currentFps.toStringAsFixed(1)} FPS',
                    color: EDesign.primary,
                  ),
                  _buildTelemetryDivider(),
                  _buildTelemetryMetric(
                    label: 'FRAMES',
                    value: '${job.processedFrames} / ${job.totalFrames}',
                    color: EDesign.aiAccent,
                  ),
                  _buildTelemetryDivider(),
                  _buildTelemetryMetric(
                    label: 'EST. TIME LEFT',
                    value: job.etaString,
                    color: EDesign.secondary,
                  ),
                ],
              ),
            ),
          ],

          if (isFailed && job.error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: EDesign.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(EDesign.r8),
                border: Border.all(color: EDesign.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: EDesign.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.error!,
                      style: const TextStyle(color: EDesign.danger, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isProcessing || job.status == ExportStatus.pending)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    exportService.cancelJob(job.id);
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: EDesign.danger,
                    size: 18,
                  ),
                  label: const Text(
                    'Cancel & Clean .tmp',
                    style: TextStyle(color: EDesign.danger, fontWeight: FontWeight.bold),
                  ),
                ),
              if (isFailed || isCancelled)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    exportService.retryJob(job.id);
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: EDesign.primary,
                    size: 18,
                  ),
                  label: const Text(
                    'Retry Pipeline',
                    style: TextStyle(color: EDesign.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              if (isCompleted)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r10),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(mediaPath: job.outputPath),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
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
  }

  Widget _buildStatusBadge(ExportStatus status) {
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

  Widget _buildTelemetryMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: EDesign.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryDivider() {
    return Container(
      width: 1,
      height: 24,
      color: EDesign.border,
    );
  }

  Widget _buildMultiStageStepper(ExportPipelineStage currentStage, ExportStatus status) {
    final stages = [
      {'name': 'Prep', 'stage': ExportPipelineStage.preparing},
      {'name': 'Decode', 'stage': ExportPipelineStage.decoding},
      {'name': 'Enhance', 'stage': ExportPipelineStage.enhancing},
      {'name': 'Encode', 'stage': ExportPipelineStage.encoding},
      {'name': 'Mux', 'stage': ExportPipelineStage.muxing},
      {'name': 'Validate', 'stage': ExportPipelineStage.validating},
    ];

    int activeStageIndex;
    if (status == ExportStatus.completed) {
      activeStageIndex = stages.length;
    } else {
      switch (currentStage) {
        case ExportPipelineStage.queued:
          activeStageIndex = -1;
          break;
        case ExportPipelineStage.preparing:
          activeStageIndex = 0;
          break;
        case ExportPipelineStage.decoding:
          activeStageIndex = 1;
          break;
        case ExportPipelineStage.enhancing:
          activeStageIndex = 2;
          break;
        case ExportPipelineStage.encoding:
          activeStageIndex = 3;
          break;
        case ExportPipelineStage.muxing:
          activeStageIndex = 4;
          break;
        case ExportPipelineStage.validating:
          activeStageIndex = 5;
          break;
        default:
          activeStageIndex = 0;
          break;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(stages.length, (idx) {
          final isPast = idx < activeStageIndex;
          final isCurrent = idx == activeStageIndex && status == ExportStatus.processing;
          final isFailedCurrent = idx == activeStageIndex && status == ExportStatus.failed;

          final nodeColor = isPast
              ? EDesign.success
              : isFailedCurrent
                  ? EDesign.danger
                  : isCurrent
                      ? EDesign.primary
                      : EDesign.border;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPast
                          ? EDesign.success.withValues(alpha: 0.2)
                          : isCurrent
                              ? EDesign.primary.withValues(alpha: 0.2)
                              : EDesign.elevatedSurface,
                      border: Border.all(
                        color: nodeColor,
                        width: isCurrent ? 2 : 1.5,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: EDesign.primary.withValues(alpha: 0.6),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isPast
                          ? const Icon(Icons.check, size: 14, color: EDesign.success)
                          : isFailedCurrent
                              ? const Icon(Icons.close, size: 14, color: EDesign.danger)
                              : isCurrent
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(EDesign.primary),
                                      ),
                                    )
                                  : Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: nodeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stages[idx]['name'] as String,
                    style: TextStyle(
                      color: isCurrent
                          ? EDesign.primary
                          : isPast
                              ? EDesign.textPrimary
                              : EDesign.textSecondary,
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (idx < stages.length - 1)
                Container(
                  width: 22,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: isPast ? EDesign.success : EDesign.border,
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// Sweep Line Thumbnail Preview Box
class _SweepLineThumbnailPreview extends StatefulWidget {
  final ExportJob job;
  final bool isProcessing;

  const _SweepLineThumbnailPreview({
    required this.job,
    required this.isProcessing,
  });

  @override
  State<_SweepLineThumbnailPreview> createState() => _SweepLineThumbnailPreviewState();
}

class _SweepLineThumbnailPreviewState extends State<_SweepLineThumbnailPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.isProcessing) {
      _sweepController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SweepLineThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProcessing && !_sweepController.isAnimating) {
      _sweepController.repeat();
    } else if (!widget.isProcessing && _sweepController.isAnimating) {
      _sweepController.stop();
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(EDesign.r12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF030710),
            border: Border.all(color: EDesign.border),
            borderRadius: BorderRadius.circular(EDesign.r12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _SimulatedFramePainter(),
              ),
              if (widget.isProcessing)
                AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _SweepLinePainter(
                        progress: _sweepController.value,
                      ),
                    );
                  },
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHudTag(
                          icon: Icons.auto_awesome,
                          text: 'AI RASTER: ${widget.job.modelId.toUpperCase()}',
                          color: EDesign.primary,
                        ),
                        _buildHudTag(
                          icon: Icons.memory_rounded,
                          text: 'TILE: 256x256 · D3D11VA',
                          color: EDesign.aiAccent,
                        ),
                      ],
                    ),
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: EDesign.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.crop_free_rounded,
                          size: 20,
                          color: EDesign.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHudTag(
                          icon: Icons.layers_outlined,
                          text: 'FRAME ${widget.job.processedFrames} / ${widget.job.totalFrames}',
                          color: EDesign.textPrimary,
                        ),
                        _buildHudTag(
                          icon: Icons.speed_rounded,
                          text: '${widget.job.currentFps.toStringAsFixed(1)} FPS · ETA ${widget.job.etaString}',
                          color: EDesign.secondary,
                        ),
                      ],
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

  Widget _buildHudTag({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF070E1B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(EDesign.r6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Simulated Cyber Frame Painter
class _SimulatedFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF040814),
          Color(0xFF071120),
          Color(0xFF050B16),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF19BFFF).withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 8.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final bracketPaint = Paint()
      ..color = const Color(0xFF19BFFF).withValues(alpha: 0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const bracketLen = 16.0;
    const pad = 8.0;

    // Top-Left
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + bracketLen, pad), bracketPaint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad, pad + bracketLen), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - bracketLen, pad), bracketPaint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + bracketLen), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + bracketLen, size.height - pad), bracketPaint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - bracketLen), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - bracketLen, size.height - pad), bracketPaint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - bracketLen), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter that renders a glowing vertical scanning beam across the 16:9 preview
class _SweepLinePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _SweepLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * progress;
    const beamWidth = 32.0;

    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF19BFFF).withValues(alpha: 0.0),
          const Color(0xFF19BFFF).withValues(alpha: 0.22),
          const Color(0xFFE741FF).withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromLTWH(x - beamWidth, 0, beamWidth, size.height));

    canvas.drawRect(Rect.fromLTWH(x - beamWidth, 0, beamWidth, size.height), glowPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF19BFFF)
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);

    final haloPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), haloPaint);
  }

  @override
  bool shouldRepaint(covariant _SweepLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
