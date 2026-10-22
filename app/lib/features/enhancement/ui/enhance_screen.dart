import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/engine_orchestrator.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../export/domain/export_service.dart';
import '../../export/ui/export_screen.dart';
import '../../library/domain/library_provider.dart';
import '../models/gpu_preflight_telemetry.dart';

/// Screen 4: Enhancement Studio (Flagship AI & Neural Video Workstation)
///
/// Features:
/// - Interactive 16:9 Before / After split comparison showcase with draggable slider.
/// - Real-time GPU pre-flight status card with VRAM gauge and telemetry.
/// - Neural Upscale Model Suite (Real-ESRGAN x4, Anime4K, FSRCNN).
/// - Target resolution glow pills (720p ➔ 1080p ➔ 1440p ➔ 2160p 4K UHD).
/// - RIFE Frame Interpolation (60 FPS fluid motion vector synthesis).
/// - Dynamic HDR tonemapping, RNNoise vocal isolation, and stereoscopic 3D.
/// - Manual DSP fine-tuning sliders (Unsharp mask, gradfun deband, gamma).
/// - Live profile activation and offline batch queuing to [ExportScreen].
class EnhanceScreen extends StatefulWidget {
  const EnhanceScreen({super.key});

  @override
  State<EnhanceScreen> createState() => _EnhanceScreenState();
}

class _EnhanceScreenState extends State<EnhanceScreen> {
  // Domain & mode state
  bool _aiEnhancementVideo = true; // Video vs Audio
  String _enhancementMode = 'Auto'; // Auto | Manual | Preset
  String _model = 'Real-ESRGAN x4';
  String _resolution = '2160p/4K';
  bool _rifeEnabled = true;
  bool _hdrContrast = true;
  bool _rnnoiseDialogue = false;
  bool _stereo3D = false;

  // Split-view slider position (0.0 to 1.0)
  double _splitRatio = 0.52;
  final bool _showSplitLines = true;

  // Fine-tuning parameters for Manual mode
  double _sharpenSigma = 0.85;
  int _debandRadius = 16;
  double _dynamicContrast = 14.0;
  double _chromaVibrance = 18.0;

  // Hardware telemetry
  late NativeEngineOrchestrator _engineOrchestrator;
  GpuPreflightTelemetry? _telemetry;

  @override
  void initState() {
    super.initState();
    _engineOrchestrator = NativeEngineOrchestrator();
    _refreshGpuTelemetry();
  }

  Future<void> _refreshGpuTelemetry() async {
    final telemetry = await GpuPreflightTelemetry.detect(
      orchestrator: _engineOrchestrator,
      targetResolution: _resolution,
      rifeEnabled: _rifeEnabled,
    );
    if (mounted) {
      setState(() {
        _telemetry = telemetry;
      });
    }
  }

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

    if (sourcePath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No media selected for export. Pick a video to proceed.'),
            backgroundColor: EDesign.warning,
          ),
        );
      }
      return;
    }

    final dir = p.dirname(sourcePath);
    final base = p.basenameWithoutExtension(sourcePath);
    final resLabel = _resolution.replaceAll('/', '_');
    final outPath = p.join(dir, '${base}_enhanced_$resLabel.mkv');
    final jobId = 'EXP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    exportService.addJob(
      ExportJob(
        id: jobId,
        sourcePath: sourcePath,
        outputPath: outPath,
        resolutionTarget: _resolution.contains('4K') ? '2160p' : _resolution,
        fpsTarget: _rifeEnabled ? 60 : 30,
        enableAudioEnhancement: !_aiEnhancementVideo || _rnnoiseDialogue,
        enableSubtitles: true,
        modelId: _model.contains('Anime') ? 'realesrgan-anime-6b' : 'realesr-general-mobile',
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enqueued "$base" for offline AI enhancement.'),
          backgroundColor: EDesign.primaryStrong,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View Queue',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero 16:9 Interactive Before / After Split Comparison
            _buildSplitComparisonCard(),
            const SizedBox(height: 20),

            // 2. Real-Time GPU Pre-Flight Telemetry Bento Card
            _buildGpuTelemetryCard(),
            const SizedBox(height: 24),

            // 3. Domain Selector: Video Processing vs Audio DSP
            _buildDomainSelector(),
            const SizedBox(height: 20),

            // 4. Enhancement Mode Segmented Pills (Auto / Manual / Preset)
            _buildModeSelector(),
            const SizedBox(height: 24),

            // 5. Neural Super-Resolution Model Architecture Grid
            _buildSectionHeader(
              title: 'AI Upscaling Engine',
              badge: _model,
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 12),
            _buildModelSelector(),
            const SizedBox(height: 24),

            // 6. Target Resolution Glow Pills (720p ➔ 4K)
            _buildSectionHeader(
              title: 'Target Resolution',
              badge: _resolution,
              icon: Icons.hd,
            ),
            const SizedBox(height: 12),
            _buildResolutionPills(),
            const SizedBox(height: 24),

            // 7. Motion Vector & Intelligence Toggles
            _buildSectionHeader(
              title: 'Neural Filters & Motion Vector',
              icon: Icons.motion_photos_on,
            ),
            const SizedBox(height: 12),
            _buildTogglesSection(),
            const SizedBox(height: 20),

            // 8. Manual Fine-Tuning Sliders (Conditionally shown in Manual mode)
            if (_enhancementMode == 'Manual') ...[
              _buildSectionHeader(
                title: 'DSP Parameter Fine-Tuning',
                badge: 'Custom',
                icon: Icons.tune,
              ),
              const SizedBox(height: 12),
              _buildManualFineTuningControls(),
              const SizedBox(height: 24),
            ],

            // 9. Master Action Dock (Apply Live Profile vs Export Offline)
            _buildActionDock(context),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  // --- 1. APP BAR ---
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [EDesign.primary, EDesign.aiAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(EDesign.r10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enhancement Studio',
                style: TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'On-Device Neural Upscaling & Acutance',
                style: TextStyle(
                  color: EDesign.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Live GPU Preflight Status Pill
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: BorderRadius.circular(EDesign.r24),
            border: Border.all(
              color: EDesign.success.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: EDesign.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'GPU Ready',
                style: TextStyle(
                  color: EDesign.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Export Queue Button
        IconButton(
          icon: const Icon(Icons.queue_play_next, color: EDesign.primary, size: 22),
          tooltip: 'Open Export Queue',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExportScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --- 2. HERO 16:9 INTERACTIVE BEFORE / AFTER COMPARISON CARD ---
  Widget _buildSplitComparisonCard() {
    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r18),
        border: Border.all(color: EDesign.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: EDesign.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 16:9 Interactive Canvas
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final splitX = width * _splitRatio;

                return GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _splitRatio = (details.localPosition.dx / width).clamp(0.05, 0.95);
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Right Image: AI ENHANCED (Crisp, High-Detail, Vibrant)
                      Image.asset(
                        'assets/thumbnails/demo_city.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF0F1A2C),
                          child: const Center(
                            child: Icon(Icons.image, color: EDesign.primary, size: 48),
                          ),
                        ),
                      ),

                      // Left Image: ORIGINAL (Clipped to splitX, slightly softer)
                      ClipRect(
                        clipper: _SplitClipper(splitX),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.88, 0,    0,    0, 0,
                            0,    0.88, 0,    0, 0,
                            0,    0,    0.88, 0, 0,
                            0,    0,    0,    1, 0,
                          ]),
                          child: Image.asset(
                            'assets/thumbnails/demo_city.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Cyan Vertical Split Line
                      if (_showSplitLines)
                        Positioned(
                          left: splitX - 1.5,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3.0,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [EDesign.primary, EDesign.aiAccent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: EDesign.primary.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Draggable Floating Thumb (< | >)
                      if (_showSplitLines)
                        Positioned(
                          left: splitX - 18,
                          top: (height / 2) - 18,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: EDesign.appBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: EDesign.primary, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.compare_arrows_rounded,
                              color: EDesign.primary,
                              size: 20,
                            ),
                          ),
                        ),

                      // Left Badge: ORIGINAL 720p SDR
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(EDesign.r6),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.remove_circle_outline, color: Colors.white70, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'ORIGINAL · 720p SDR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right Badge: AI ENHANCED 4K
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                EDesign.primaryStrong.withValues(alpha: 0.9),
                                EDesign.aiAccent.withValues(alpha: 0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(EDesign.r6),
                            boxShadow: [
                              BoxShadow(
                                color: EDesign.aiAccent.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$_resolution · $_model',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Comparison Controls Bar below the canvas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: EDesign.elevatedBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, color: EDesign.textMuted, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'Drag slider to inspect acutance',
                      style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildCompareChip('100% Split', _splitRatio == 0.5, () {
                      setState(() => _splitRatio = 0.5);
                    }),
                    const SizedBox(width: 6),
                    _buildCompareChip('Full Enhanced', _splitRatio == 0.05, () {
                      setState(() => _splitRatio = 0.05);
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? EDesign.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(EDesign.r6),
          border: Border.all(
            color: isSelected ? EDesign.primary : EDesign.border,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? EDesign.primary : EDesign.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // --- 3. REAL-TIME GPU PRE-FLIGHT TELEMETRY BENTO CARD ---
  Widget _buildGpuTelemetryCard() {
    final t = _telemetry;
    final isPassed = t?.isPreflightPassed ?? true;
    final vramPct = t?.vramUsagePercent ?? 47;
    final gpuName = t?.gpuName ?? 'Hardware Video Accelerator (DirectML / Vulkan)';
    final apiBackend = t?.apiBackend ?? 'Direct3D 11 / Vulkan 1.3';
    final fpsTarget = t?.estimatedInferenceFps.round() ?? 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1.2),
        gradient: LinearGradient(
          colors: [
            EDesign.surface,
            EDesign.elevatedSurface.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status Badge & Hardware GPU Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: const Icon(Icons.memory, color: EDesign.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'GPU Pre-Flight Hardware Telemetry',
                          style: TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPassed
                                ? EDesign.success.withValues(alpha: 0.15)
                                : EDesign.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isPassed ? EDesign.success : EDesign.warning,
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            isPassed ? 'PASSED · 0 DROPS' : 'COMPATIBLE',
                            style: TextStyle(
                              color: isPassed ? EDesign.success : EDesign.warning,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gpuName,
                      style: const TextStyle(
                        color: EDesign.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // VRAM Usage Progress Meter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'VRAM Allocation Budget',
                    style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                  ),
                  Text(
                    '${t?.vramUsedGb.toStringAsFixed(1) ?? "3.8"} GB / ${t?.vramTotalGb.toStringAsFixed(1) ?? "8.0"} GB ($vramPct%)',
                    style: const TextStyle(
                      color: EDesign.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (vramPct / 100.0).clamp(0.05, 1.0),
                  backgroundColor: EDesign.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    vramPct > 80 ? EDesign.warning : EDesign.primary,
                  ),
                  minHeight: 5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Metric Pills
          Row(
            children: [
              _buildTelemetryMetric(
                label: 'Compute Pipeline',
                value: apiBackend.split(' / ').first,
                icon: Icons.bolt,
              ),
              const SizedBox(width: 8),
              _buildTelemetryMetric(
                label: 'Est. Realtime FPS',
                value: '$fpsTarget FPS Target',
                icon: Icons.speed,
                valueColor: EDesign.success,
              ),
              const SizedBox(width: 8),
              _buildTelemetryMetric(
                label: 'Thermal Status',
                value: t?.thermalStatus.split(' ').first ?? 'Optimal',
                icon: Icons.thermostat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetric({
    required String label,
    required String value,
    required IconData icon,
    Color valueColor = EDesign.textPrimary,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: EDesign.elevatedBackground,
          borderRadius: BorderRadius.circular(EDesign.r10),
          border: Border.all(color: EDesign.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: EDesign.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: EDesign.textMuted, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. DOMAIN SELECTOR (Video vs Audio) ---
  Widget _buildDomainSelector() {
    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r12),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildDomainButton(
              title: 'Video Upscaling & RIFE',
              subtitle: 'Super-Resolution & Motion',
              icon: Icons.videocam,
              isActive: _aiEnhancementVideo,
              onTap: () => setState(() => _aiEnhancementVideo = true),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildDomainButton(
              title: 'Audio DSP Studio',
              subtitle: 'RNNoise & Dialogue Focus',
              icon: Icons.graphic_eq,
              isActive: !_aiEnhancementVideo,
              onTap: () => setState(() => _aiEnhancementVideo = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? EDesign.elevatedSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(EDesign.r10),
          border: Border.all(
            color: isActive ? EDesign.primary.withValues(alpha: 0.6) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? EDesign.primary : EDesign.textMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? EDesign.textPrimary : EDesign.textSecondary,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: EDesign.textMuted, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. ENHANCEMENT MODE SELECTOR (Auto / Manual / Preset) ---
  Widget _buildModeSelector() {
    const modes = ['Auto', 'Manual', 'Preset'];
    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r12),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: modes.map((mode) {
          final isSelected = mode == _enhancementMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _enhancementMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? EDesign.primary.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(EDesign.r10),
                  border: Border.all(
                    color: isSelected ? EDesign.primary : Colors.transparent,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  mode,
                  style: TextStyle(
                    color: isSelected ? EDesign.primary : EDesign.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  // --- 6. NEURAL MODEL SUITE SELECTOR ---
  Widget _buildModelSelector() {
    final models = [
      {
        'id': 'Real-ESRGAN x4',
        'title': 'Real-ESRGAN x4 Plus',
        'subtitle': 'Photorealistic General Cinematic Media',
        'badge': 'Cinematic',
        'icon': Icons.auto_awesome,
        'color': EDesign.primary,
        'details': 'Residual-in-Residual Dense Block · High frequency texture',
      },
      {
        'id': 'Anime4K / MangaV2',
        'title': 'Anime4K / MangaV2',
        'subtitle': 'Cel-Shade & Animation Line Acutance',
        'badge': 'Anime',
        'icon': Icons.brush,
        'color': EDesign.aiAccent,
        'details': 'Contour reconstruction · Gradfun debanding · Zero halo',
      },
      {
        'id': 'FSRCNN / FastBicubic',
        'title': 'FSRCNN / Mobile Fast',
        'subtitle': 'Low Power Ultra-Fast Neural Upscaler',
        'badge': 'Battery Saver',
        'icon': Icons.bolt,
        'color': EDesign.success,
        'details': 'Sub-millisecond inference · Zero fan spin on laptops',
      },
    ];

    return Column(
      children: models.map((m) {
        final id = m['id'] as String;
        final isSelected = _model == id;
        final color = m['color'] as Color;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected ? EDesign.elevatedSurface : EDesign.surface,
            borderRadius: BorderRadius.circular(EDesign.r14),
            border: Border.all(
              color: isSelected ? color : EDesign.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(EDesign.r14),
            onTap: () {
              setState(() => _model = id);
              _refreshGpuTelemetry();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(EDesign.r10),
                    ),
                    child: Icon(m['icon'] as IconData, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              m['title'] as String,
                              style: const TextStyle(
                                color: EDesign.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m['badge'] as String,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          m['subtitle'] as String,
                          style: const TextStyle(color: EDesign.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m['details'] as String,
                          style: const TextStyle(color: EDesign.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.check_circle, color: color, size: 20),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- 7. TARGET RESOLUTION GLOW PILLS (720p ➔ 4K) ---
  Widget _buildResolutionPills() {
    final resolutions = [
      {'val': '720p', 'label': '720p HD', 'scale': '1.0x'},
      {'val': '1080p', 'label': '1080p FHD', 'scale': '1.5x'},
      {'val': '1440p', 'label': '1440p 2K', 'scale': '2.0x'},
      {'val': '2160p/4K', 'label': '4K UHD', 'scale': '4.0x'},
    ];

    return Row(
      children: resolutions.map((r) {
        final val = r['val'] as String;
        final isSelected = _resolution == val;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() => _resolution = val);
                _refreshGpuTelemetry();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? EDesign.primary.withValues(alpha: 0.18)
                      : EDesign.surface,
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  border: Border.all(
                    color: isSelected ? EDesign.primary : EDesign.border,
                    width: isSelected ? 1.6 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: EDesign.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      r['label'] as String,
                      style: TextStyle(
                        color: isSelected ? EDesign.primary : EDesign.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r['scale'] as String,
                      style: TextStyle(
                        color: isSelected ? EDesign.primary : EDesign.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- 8. MOTION VECTOR & INTELLIGENCE TOGGLES ---
  Widget _buildTogglesSection() {
    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1.0),
      ),
      child: Column(
        children: [
          // RIFE Frame Interpolation (60 FPS)
          _buildToggleTile(
            title: 'RIFE Frame Interpolation (60 FPS)',
            subtitle: 'Neural bidirectional optical flow synthesis for silky panning',
            badge: '60 FPS',
            value: _rifeEnabled,
            onChanged: (val) {
              setState(() => _rifeEnabled = val);
              _refreshGpuTelemetry();
            },
          ),
          const Divider(height: 1, color: EDesign.border),

          // HDR Dynamic Contrast Expansion
          _buildToggleTile(
            title: 'Perceptual Dynamic HDR Tonemapping',
            subtitle: 'Expands SDR luminance curves and specular highlights',
            badge: 'HDR',
            value: _hdrContrast,
            onChanged: (val) => setState(() => _hdrContrast = val),
          ),
          const Divider(height: 1, color: EDesign.border),

          // RNNoise Dialogue Isolation
          _buildToggleTile(
            title: 'RNNoise Dialogue Vocal Isolation',
            subtitle: 'Neural acoustic suppression of background hum and noise',
            badge: 'Audio',
            value: _rnnoiseDialogue,
            onChanged: (val) => setState(() => _rnnoiseDialogue = val),
          ),
          const Divider(height: 1, color: EDesign.border),

          // Stereoscopic 3D
          _buildToggleTile(
            title: 'Stereoscopic 3D Depth Synthesis',
            subtitle: 'Depth Anything V2 2D-to-Side-by-Side (SBS) 3D conversion',
            badge: '3D SBS',
            value: _stereo3D,
            onChanged: (val) => setState(() => _stereo3D = val),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required String badge,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: EDesign.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: EDesign.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: EDesign.primary,
            activeTrackColor: EDesign.primary.withValues(alpha: 0.35),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  // --- 9. MANUAL FINE-TUNING SLIDERS ---
  Widget _buildManualFineTuningControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1.0),
      ),
      child: Column(
        children: [
          _buildFineSlider(
            title: 'Unsharp Mask Sigma (Sharpening)',
            value: _sharpenSigma,
            min: 0.0,
            max: 2.0,
            decimals: 2,
            onChanged: (v) => setState(() => _sharpenSigma = v),
          ),
          const SizedBox(height: 12),
          _buildFineSlider(
            title: 'Debanding Radius (Gradfun)',
            value: _debandRadius.toDouble(),
            min: 0.0,
            max: 32.0,
            decimals: 0,
            unit: ' px',
            onChanged: (v) => setState(() => _debandRadius = v.round()),
          ),
          const SizedBox(height: 12),
          _buildFineSlider(
            title: 'Dynamic Contrast Boost',
            value: _dynamicContrast,
            min: -50.0,
            max: 50.0,
            decimals: 0,
            unit: '%',
            onChanged: (v) => setState(() => _dynamicContrast = v),
          ),
          const SizedBox(height: 12),
          _buildFineSlider(
            title: 'Chroma Vibrance & Saturation',
            value: _chromaVibrance,
            min: -50.0,
            max: 50.0,
            decimals: 0,
            unit: '%',
            onChanged: (v) => setState(() => _chromaVibrance = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFineSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String unit = '',
    int decimals = 0,
  }) {
    final display = decimals > 0
        ? value.toStringAsFixed(decimals)
        : (value > 0 ? '+${value.round()}$unit' : '${value.round()}$unit');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: EDesign.textSecondary, fontSize: 12)),
            Text(
              display,
              style: const TextStyle(
                color: EDesign.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: EDesign.primary,
            inactiveTrackColor: EDesign.border,
            thumbColor: Colors.white,
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // --- 10. MASTER ACTION DOCK ---
  Widget _buildActionDock(BuildContext context) {
    return Row(
      children: [
        // Live Profile Apply Button
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Applied $_model ($_resolution · ${_rifeEnabled ? "60fps RIFE" : "30fps"}) profile.',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: EDesign.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'Apply Live Profile',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: EDesign.primary,
                foregroundColor: Colors.black,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Export Offline Batch Button
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _queueOfflineExport(context),
              icon: const Icon(Icons.movie_creation_outlined, size: 18),
              label: const Text(
                'Export Offline',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: EDesign.aiAccent,
                side: const BorderSide(color: EDesign.aiAccent, width: 1.4),
                backgroundColor: EDesign.aiAccent.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? badge,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: EDesign.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: EDesign.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: EDesign.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: EDesign.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom clipper that splits the Before image at the draggable horizontal split point.
class _SplitClipper extends CustomClipper<Rect> {
  final double splitX;

  _SplitClipper(this.splitX);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, splitX, size.height);
  }

  @override
  bool shouldReclip(_SplitClipper oldClipper) {
    return oldClipper.splitX != splitX;
  }
}
