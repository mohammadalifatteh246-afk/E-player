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
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                color: EDesign.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Compact Header with Master Toggle & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: EDesign.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(EDesign.r10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: EDesign.primaryCyan, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Live Video Enhancement',
                        style: TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Real-time Acutance, Deband & Dynamic Range',
                        style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
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
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: EDesign.textSecondary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Sleek Tab Bar (Quality Profiles vs Audio/AI Offline)
          Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.tune, size: 16), text: 'Quality Profiles'),
                Tab(icon: Icon(Icons.model_training, size: 16), text: 'AI & Audio'),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Tab Views with responsive scrollable content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQualityProfilesTab(),
                _buildAiAudioTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: CONTENT-ADAPTIVE QUALITY PROFILES ---
  Widget _buildQualityProfilesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final isMasterActive = _config.masterToggle;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner when master toggle is OFF
              if (!isMasterActive)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EDesign.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EDesign.warning.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: EDesign.warning, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Enhancement is in neutral mode. Turn switch ON above to apply live.',
                          style: TextStyle(color: EDesign.warning, fontSize: 11),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          _config.masterToggle = true;
                          _notifyChange();
                        },
                        child: const Text('Turn ON', style: TextStyle(color: EDesign.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // Global Enhancement Intensity Slider (Compact)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: EDesign.elevatedBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EDesign.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enhancement Intensity',
                          style: TextStyle(color: EDesign.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
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
                              fontSize: 11,
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
                        trackHeight: 2.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
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

              // Section Title
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'CHOOSE ENHANCEMENT PROFILE',
                  style: TextStyle(
                    color: EDesign.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Responsive Grid of Profiles (Fits cleanly on mobile landscape without cutoff)
              GridView.count(
                crossAxisCount: isWide ? 2 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 8,
                childAspectRatio: isWide ? 2.85 : 3.8,
                children: [
                  _buildProfileCard(
                    mode: EnhancementMode.superClarity,
                    icon: Icons.hd_outlined,
                    color: Colors.cyanAccent,
                    tag: 'Unsharp Mask 5x5 + Deband',
                  ),
                  _buildProfileCard(
                    mode: EnhancementMode.animeRemaster,
                    icon: Icons.brush_outlined,
                    color: Colors.pinkAccent,
                    tag: 'Cel-Shade & Line Contour',
                  ),
                  _buildProfileCard(
                    mode: EnhancementMode.cinemaHdr,
                    icon: Icons.movie_filter_outlined,
                    color: Colors.amberAccent,
                    tag: 'Dynamic S-Curve & Inky Blacks',
                  ),
                  _buildProfileCard(
                    mode: EnhancementMode.nightSight,
                    icon: Icons.nightlight_outlined,
                    color: Colors.indigoAccent,
                    tag: 'Shadow Gamma & Noise Filter',
                  ),
                  _buildProfileCard(
                    mode: EnhancementMode.sportsVivid,
                    icon: Icons.sports_soccer_outlined,
                    color: Colors.greenAccent,
                    tag: 'Motion Clarity & Rich Chroma',
                  ),
                  _buildProfileCard(
                    mode: EnhancementMode.custom,
                    icon: Icons.tune,
                    color: Colors.purpleAccent,
                    tag: 'Custom Kernel Fine-Tuning',
                  ),
                ],
              ),

              // Custom Tuning Panel (shown when Custom is active)
              if (_config.mode == EnhancementMode.custom) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EDesign.elevatedBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4), width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, color: Colors.purpleAccent, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Custom DSP Fine-Tuning',
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard({
    required EnhancementMode mode,
    required IconData icon,
    required Color color,
    required String tag,
  }) {
    final isSelected = _config.mode == mode;
    final title = EnhancementConfig.getModeTitle(mode);

    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r12),
      onTap: () {
        _config.mode = mode;
        if (!_config.masterToggle) {
          _config.masterToggle = true;
        }
        _notifyChange();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? EDesign.elevatedSurface
              : EDesign.elevatedBackground,
          borderRadius: BorderRadius.circular(EDesign.r12),
          border: Border.all(
            color: isSelected ? EDesign.primaryCyan : EDesign.border,
            width: isSelected ? 1.6 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: EDesign.primaryCyan.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : EDesign.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tag,
                    style: const TextStyle(color: EDesign.textMuted, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? EDesign.primaryCyan : EDesign.textMuted.withValues(alpha: 0.35),
              size: 18,
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: EDesign.textPrimary, fontSize: 11)),
              Text(
                displayVal,
                style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.purpleAccent,
              inactiveTrackColor: EDesign.border,
              thumbColor: Colors.white,
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio Enhancement
          SwitchListTile(
            title: const Text('Isolate Dialogue (Audio)', style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('RNNoise neural background suppression', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
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
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Text('Denoise Strength', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
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

          const Divider(color: EDesign.border, height: 16),

          // Night Mode Audio
          SwitchListTile(
            title: const Text('Night Mode Audio DSP', style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Loudness normalization & dynamic compression', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
            activeThumbColor: EDesign.primaryCyan,
            contentPadding: EdgeInsets.zero,
            value: _config.nightMode,
            onChanged: (val) {
              _config.nightMode = val;
              _notifyChange();
            },
          ),

          const Divider(color: EDesign.border, height: 16),

          // Stereoscopic 3D
          SwitchListTile(
            title: const Text('Stereoscopic 3D (SBS)', style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Depth Anything V2 2D-to-3D synthesis', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
            activeThumbColor: EDesign.primaryCyan,
            contentPadding: EdgeInsets.zero,
            value: _config.stereo3D,
            onChanged: (val) {
              _config.stereo3D = val;
              _notifyChange();
            },
          ),

          const Divider(color: EDesign.border, height: 16),

          // Offline NPU Super-Resolution Settings
          const Text(
            'Offline Batch Export AI (NPU / GPU)',
            style: TextStyle(color: EDesign.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Neural Upscale Model', style: TextStyle(color: EDesign.textPrimary, fontSize: 12)),
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
            title: const Text('Target Resolution', style: TextStyle(color: EDesign.textPrimary, fontSize: 12)),
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
