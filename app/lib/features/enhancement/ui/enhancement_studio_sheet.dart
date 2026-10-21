import 'package:flutter/material.dart';
import '../../../../core/engine_orchestrator.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../models/enhancement_profile.dart';

export '../models/enhancement_profile.dart';

/// Professional Live AI & DSP Video Enhancement Studio.
/// Combines VLC-grade real-time video filtering (unsharp mask, gradfun deband,
/// perceptual tone curves) with optional native NPU offline models.
class EnhancementStudioSheet extends StatefulWidget {
  final NativeEngineOrchestrator aiEngine;
  final String mediaPath;
  final EnhancementConfig config;
  final VoidCallback? onConfigChanged;

  const EnhancementStudioSheet({
    super.key,
    required this.aiEngine,
    required this.mediaPath,
    required this.config,
    this.onConfigChanged,
  });

  @override
  State<EnhancementStudioSheet> createState() => _EnhancementStudioSheetState();
}

class _EnhancementStudioSheetState extends State<EnhancementStudioSheet>
    with SingleTickerProviderStateMixin {
  late EnhancementConfig _config;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onConfigChanged?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: EDesign.s12, bottom: EDesign.s8),
              decoration: BoxDecoration(
                color: EDesign.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with Master Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: EDesign.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(EDesign.r10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: EDesign.primaryCyan, size: 22),
                ),
                const SizedBox(width: EDesign.s8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Video Enhancement',
                        style: TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Real-time Acutance, Deband & Dynamic Range',
                        style: TextStyle(color: EDesign.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _config.masterToggle,
                  activeThumbColor: EDesign.primaryCyan,
                  onChanged: (val) {
                    _config.masterToggle = val;
                    if (val && widget.aiEngine.isLoaded) {
                      widget.aiEngine.bypassAudioEnhancement(false);
                    }
                    _notifyChange();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'Enhanced Video Pipeline Activated'
                              : 'Video Enhancement Bypassed (Neutral)',
                        ),
                        duration: const Duration(seconds: 1),
                        backgroundColor: EDesign.elevatedSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Engine Status Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: EDesign.elevatedBackground,
                borderRadius: BorderRadius.circular(EDesign.r10),
                border: Border.all(
                  color: _config.masterToggle
                      ? EDesign.primaryCyan.withValues(alpha: 0.4)
                      : EDesign.border,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt,
                    size: 16,
                    color: _config.masterToggle ? EDesign.primaryCyan : EDesign.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _config.masterToggle
                          ? 'Engine: Hardware GPU / libmpv DSP Pipeline (Active 60fps)'
                          : 'Engine: Standby (Toggle master switch to engage)',
                      style: TextStyle(
                        color: _config.masterToggle ? EDesign.primaryCyan : EDesign.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.aiEngine.isLoaded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NPU Ready',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: EDesign.s8),

          // Tab Bar (Live Profiles vs Audio/AI Offline)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: EDesign.s16),
            decoration: BoxDecoration(
              color: EDesign.elevatedBackground,
              borderRadius: BorderRadius.circular(EDesign.r10),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: EDesign.elevatedSurface,
                borderRadius: BorderRadius.circular(EDesign.r10),
                border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
              ),
              labelColor: EDesign.primaryCyan,
              unselectedLabelColor: EDesign.textMuted,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.tune, size: 18), text: 'Quality Profiles'),
                Tab(icon: Icon(Icons.model_training, size: 18), text: 'AI & Audio'),
              ],
            ),
          ),

          const SizedBox(height: EDesign.s8),

          // Tab Views
          Expanded(
            child: Opacity(
              opacity: _config.masterToggle ? 1.0 : 0.45,
              child: IgnorePointer(
                ignoring: !_config.masterToggle,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQualityProfilesTab(),
                    _buildAiAudioTab(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: CONTENT-ADAPTIVE QUALITY PROFILES ---
  Widget _buildQualityProfilesTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
      children: [
        // Global Enhancement Intensity Slider
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enhancement Intensity',
                    style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: EDesign.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(_config.strength * 100).round()}%',
                      style: const TextStyle(
                        color: EDesign.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: EDesign.primaryCyan,
                  inactiveTrackColor: EDesign.border,
                  thumbColor: EDesign.textPrimary,
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                ),
                child: Slider(
                  value: _config.strength,
                  min: 0.2,
                  max: 1.5,
                  onChanged: (val) {
                    _config.strength = val;
                    _notifyChange();
                  },
                ),
              ),
            ],
          ),
        ),

        const Text(
          'Select Enhancement Preset',
          style: TextStyle(
            color: EDesign.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        // Profile Cards
        _buildProfileTile(
          mode: EnhancementMode.superClarity,
          icon: Icons.hd_outlined,
          color: Colors.cyanAccent,
          badges: const ['Unsharp 5x5', 'Gradfun Deband', 'Acutance Boost'],
        ),
        _buildProfileTile(
          mode: EnhancementMode.animeRemaster,
          icon: Icons.brush_outlined,
          color: Colors.pinkAccent,
          badges: const ['Contour Edge', 'Heavy Deband', 'Cel-Shade Vibrance'],
        ),
        _buildProfileTile(
          mode: EnhancementMode.cinemaHdr,
          icon: Icons.movie_filter_outlined,
          color: Colors.amberAccent,
          badges: const ['Dynamic S-Curve', 'Inky Blacks', 'Tungsten Warmth'],
        ),
        _buildProfileTile(
          mode: EnhancementMode.nightSight,
          icon: Icons.nightlight_outlined,
          color: Colors.indigoAccent,
          badges: const ['Shadow Gamma Lift', 'Noise Suppressed', 'Anti-Dull'],
        ),
        _buildProfileTile(
          mode: EnhancementMode.sportsVivid,
          icon: Icons.sports_soccer_outlined,
          color: Colors.greenAccent,
          badges: const ['Fast Motion Clarity', 'Saturated Turf', 'Contour Lock'],
        ),
        _buildProfileTile(
          mode: EnhancementMode.custom,
          icon: Icons.tune,
          color: Colors.purpleAccent,
          badges: const ['Custom Kernel', 'Manual Sliders'],
        ),

        // Custom Tuning Panel (shown when Custom is active)
        if (_config.mode == EnhancementMode.custom) ...[
          const Divider(color: EDesign.border, height: 28),
          const Text(
            'Custom DSP Fine-Tuning',
            style: TextStyle(
              color: EDesign.primaryCyan,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          _buildFineTuneSlider(
            title: 'Unsharp Mask Sigma (Sharpening)',
            value: _config.customSharpenSigma,
            min: 0.0,
            max: 2.0,
            decimals: 2,
            onChanged: (v) {
              _config.customSharpenSigma = v;
              _notifyChange();
            },
          ),
          _buildFineTuneSlider(
            title: 'Debanding Radius (Gradfun)',
            value: _config.customDebandRadius.toDouble(),
            min: 0.0,
            max: 32.0,
            decimals: 0,
            unit: 'px',
            onChanged: (v) {
              _config.customDebandRadius = v.round();
              _notifyChange();
            },
          ),
          _buildFineTuneSlider(
            title: 'Dynamic Contrast',
            value: _config.customContrast,
            min: -50.0,
            max: 50.0,
            decimals: 0,
            unit: '%',
            onChanged: (v) {
              _config.customContrast = v;
              _notifyChange();
            },
          ),
          _buildFineTuneSlider(
            title: 'Chroma Vibrance (Saturation)',
            value: _config.customSaturation,
            min: -50.0,
            max: 50.0,
            decimals: 0,
            unit: '%',
            onChanged: (v) {
              _config.customSaturation = v;
              _notifyChange();
            },
          ),
          _buildFineTuneSlider(
            title: 'Shadow Detail Gamma',
            value: _config.customGamma,
            min: -50.0,
            max: 50.0,
            decimals: 0,
            unit: '%',
            onChanged: (v) {
              _config.customGamma = v;
              _notifyChange();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildProfileTile({
    required EnhancementMode mode,
    required IconData icon,
    required Color color,
    required List<String> badges,
  }) {
    final isSelected = _config.mode == mode;
    final title = EnhancementConfig.getModeTitle(mode);
    final subtitle = EnhancementConfig.getModeSubtitle(mode);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? EDesign.elevatedSurface
            : EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r14),
        border: Border.all(
          color: isSelected ? EDesign.primaryCyan : EDesign.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(EDesign.r14),
        onTap: () {
          _config.mode = mode;
          _notifyChange();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? EDesign.textPrimary : EDesign.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle, color: EDesign.primaryCyan, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: EDesign.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: badges.map((b) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: EDesign.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: EDesign.border, width: 0.5),
                          ),
                          child: Text(
                            b,
                            style: const TextStyle(color: EDesign.textSecondary, fontSize: 10),
                          ),
                        );
                      }).toList(),
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

  Widget _buildFineTuneSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String unit = '',
    int decimals = 0,
  }) {
    final displayVal = decimals > 0
        ? value.toStringAsFixed(decimals)
        : (value > 0 ? '+${value.round()}$unit' : '${value.round()}$unit');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: EDesign.textPrimary, fontSize: 12)),
              Text(
                displayVal,
                style: const TextStyle(color: EDesign.primaryCyan, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EDesign.primaryCyan,
              inactiveTrackColor: EDesign.border,
              thumbColor: EDesign.textPrimary,
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
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

  // --- TAB 2: AI OFFLINE & AUDIO DSP ---
  Widget _buildAiAudioTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
      children: [
        // Audio Enhancement
        SwitchListTile(
          title: const Text('Isolate Dialogue (Audio)', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('RNNoise neural background suppression', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          value: _config.audioEnhance,
          onChanged: (val) {
            _config.audioEnhance = val;
            _notifyChange();
          },
        ),
        if (_config.audioEnhance)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Text('Denoise Strength', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _config.audioEnhanceStrength,
                    activeColor: EDesign.primaryCyan,
                    onChanged: (val) {
                      _config.audioEnhanceStrength = val;
                      _notifyChange();
                    },
                  ),
                ),
              ],
            ),
          ),

        const Divider(color: EDesign.border, height: 20),

        // Night Mode Audio
        SwitchListTile(
          title: const Text('Night Mode Audio DSP', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Loudness normalization & dynamic compression', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          value: _config.nightMode,
          onChanged: (val) {
            _config.nightMode = val;
            _notifyChange();
          },
        ),

        const Divider(color: EDesign.border, height: 20),

        // Stereoscopic 3D
        SwitchListTile(
          title: const Text('Stereoscopic 3D (SBS)', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Depth Anything V2 2D-to-3D synthesis', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          value: _config.stereo3D,
          onChanged: (val) {
            _config.stereo3D = val;
            _notifyChange();
          },
        ),

        const Divider(color: EDesign.border, height: 20),

        // Offline NPU Super-Resolution Settings
        const Text(
          'Offline Batch Export AI (NPU / GPU)',
          style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Neural Upscale Model', style: TextStyle(color: EDesign.textPrimary, fontSize: 13)),
          subtitle: Text(_config.aiModel, style: const TextStyle(color: EDesign.textMuted, fontSize: 11)),
          trailing: DropdownButton<String>(
            dropdownColor: EDesign.elevatedSurface,
            value: _config.aiModel,
            style: const TextStyle(color: EDesign.primaryCyan, fontSize: 12),
            items: [
              'General (realesr-general-x4v3)',
              'Anime (RealESRGAN_x4plus_anime_6B)',
            ].map((m) => DropdownMenuItem(value: m, child: Text(m.split(' ').first))).toList(),
            onChanged: (val) {
              if (val != null) {
                _config.aiModel = val;
                _notifyChange();
              }
            },
          ),
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Target Resolution', style: TextStyle(color: EDesign.textPrimary, fontSize: 13)),
          subtitle: Text(_config.resolution, style: const TextStyle(color: EDesign.textMuted, fontSize: 11)),
          trailing: DropdownButton<String>(
            dropdownColor: EDesign.elevatedSurface,
            value: _config.resolution,
            style: const TextStyle(color: EDesign.primaryCyan, fontSize: 12),
            items: ['720p', '1080p', '1440p', '4K']
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                _config.resolution = val;
                _notifyChange();
              }
            },
          ),
        ),
      ],
    );
  }
}
