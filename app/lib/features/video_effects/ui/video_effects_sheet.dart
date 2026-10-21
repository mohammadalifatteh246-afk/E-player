import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../models/video_effects_config.dart';
import '../domain/video_effects_service.dart';

/// Interactive Video Effects Studio Sheet for E-Player.
/// Matches VLC Media Player's Extended Video Effects dialog:
/// Essential (Adjust & Sharpen), Colors, Geometry (Transform & Rotate), and Presets.
class VideoEffectsSheet extends StatefulWidget {
  final Player player;
  final VideoEffectsConfig config;
  final VideoEffectsService service;
  final VoidCallback onConfigChanged;

  const VideoEffectsSheet({
    super.key,
    required this.player,
    required this.config,
    required this.service,
    required this.onConfigChanged,
  });

  @override
  State<VideoEffectsSheet> createState() => _VideoEffectsSheetState();
}

class _VideoEffectsSheetState extends State<VideoEffectsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late VideoEffectsConfig _config;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _config = widget.config;
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.service.saveToPreferences(_config);
    super.dispose();
  }

  void _notifyChange({bool immediateVf = false}) {
    widget.service.apply(widget.player, _config, immediateVf: immediateVf);
    widget.onConfigChanged();
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
          // Drag Handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
            child: Row(
              children: [
                const Icon(Icons.tune, color: EDesign.primaryCyan, size: 24),
                const SizedBox(width: EDesign.s8),
                const Expanded(
                  child: Text(
                    'Video Effects Studio',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _config.resetAll();
                    _notifyChange(immediateVf: true);
                  },
                  icon: const Icon(Icons.refresh, size: 16, color: EDesign.textSecondary),
                  label: const Text(
                    'Reset All',
                    style: TextStyle(color: EDesign.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _config.masterEnabled,
                  activeThumbColor: EDesign.primaryCyan,
                  onChanged: (val) {
                    _config.masterEnabled = val;
                    _notifyChange(immediateVf: true);
                  },
                ),
              ],
            ),
          ),

          // Tab Bar (Essential, Colors, Geometry, Presets)
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
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.tune, size: 18), text: 'Essential'),
                Tab(icon: Icon(Icons.palette_outlined, size: 18), text: 'Colors'),
                Tab(icon: Icon(Icons.crop_rotate, size: 18), text: 'Geometry'),
                Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Presets'),
              ],
            ),
          ),

          const SizedBox(height: EDesign.s8),

          // Tab Content
          Expanded(
            child: Opacity(
              opacity: _config.masterEnabled ? 1.0 : 0.45,
              child: IgnorePointer(
                ignoring: !_config.masterEnabled,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEssentialTab(),
                    _buildColorsTab(),
                    _buildGeometryTab(),
                    _buildPresetsTab(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: ESSENTIAL ADJUSTMENTS (VLC adjust.c & sharpen.c parity) ---
  Widget _buildEssentialTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
      children: [
        _buildSectionHeader('Image Adjust (VLC adjust.c)', () {
          _config.resetEssential();
          _notifyChange(immediateVf: true);
        }),

        // Contrast (-100 to 100)
        _buildSliderTile(
          title: 'Contrast',
          value: _config.contrast,
          min: -100.0,
          max: 100.0,
          unit: '%',
          onChanged: (val) {
            _config.contrast = val;
            _notifyChange();
          },
          onReset: () {
            _config.contrast = 0.0;
            _notifyChange();
          },
        ),

        // Brightness (-100 to 100)
        _buildSliderTile(
          title: 'Brightness',
          value: _config.brightness,
          min: -100.0,
          max: 100.0,
          unit: '%',
          onChanged: (val) {
            _config.brightness = val;
            _notifyChange();
          },
          onReset: () {
            _config.brightness = 0.0;
            _notifyChange();
          },
        ),

        // Saturation (-100 to 100)
        _buildSliderTile(
          title: 'Saturation',
          value: _config.saturation,
          min: -100.0,
          max: 100.0,
          unit: '%',
          onChanged: (val) {
            _config.saturation = val;
            _notifyChange();
          },
          onReset: () {
            _config.saturation = 0.0;
            _notifyChange();
          },
        ),

        // Gamma (-100 to 100)
        _buildSliderTile(
          title: 'Gamma',
          value: _config.gamma,
          min: -100.0,
          max: 100.0,
          unit: '%',
          onChanged: (val) {
            _config.gamma = val;
            _notifyChange();
          },
          onReset: () {
            _config.gamma = 0.0;
            _notifyChange();
          },
        ),

        // Hue (-180 to 180)
        _buildSliderTile(
          title: 'Hue Rotation',
          value: _config.hue,
          min: -180.0,
          max: 180.0,
          unit: '°',
          onChanged: (val) {
            _config.hue = val;
            _notifyChange();
          },
          onReset: () {
            _config.hue = 0.0;
            _notifyChange();
          },
        ),

        const Divider(color: EDesign.border, height: 24),

        _buildSectionHeader('Detail & Clarity (VLC sharpen.c & gradfun.c)'),

        // Sharpen Switch & Sigma Slider
        SwitchListTile(
          title: const Text('Sharpen Filter', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Unsharp contour mask', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.sharpen,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.sharpen = val;
            _notifyChange(immediateVf: true);
          },
        ),
        if (_config.sharpen)
          _buildSliderTile(
            title: 'Sharpen Sigma',
            value: _config.sharpenSigma,
            min: 0.1,
            max: 2.0,
            decimals: 2,
            onChanged: (val) {
              _config.sharpenSigma = val;
              _notifyChange();
            },
            onReset: () {
              _config.sharpenSigma = 0.5;
              _notifyChange();
            },
          ),

        // Banding removal (Gradfun)
        SwitchListTile(
          title: const Text('Banding Removal', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Gradfun anti-posterization smoothing', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.bandingRemoval,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.bandingRemoval = val;
            _notifyChange(immediateVf: true);
          },
        ),
        if (_config.bandingRemoval)
          _buildSliderTile(
            title: 'Gradfun Radius',
            value: _config.bandingRadius.toDouble(),
            min: 4.0,
            max: 32.0,
            decimals: 0,
            unit: 'px',
            onChanged: (val) {
              _config.bandingRadius = val.round();
              _notifyChange();
            },
            onReset: () {
              _config.bandingRadius = 16;
              _notifyChange();
            },
          ),
      ],
    );
  }

  // --- TAB 2: COLORS (VLC Colors tab parity) ---
  Widget _buildColorsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
      children: [
        _buildSectionHeader('Color Tone & Inversion', () {
          _config.resetColors();
          _notifyChange(immediateVf: true);
        }),

        // Invert / Negate Colors
        SwitchListTile(
          title: const Text('Negate / Invert Colors', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Inverts all RGB chromatic and luminance channels', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.invert,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.invert = val;
            _notifyChange(immediateVf: true);
          },
        ),

        const Divider(color: EDesign.border, height: 16),

        // Sepia
        SwitchListTile(
          title: const Text('Sepia Tone Filter', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Applies warm golden-brown photographic tone', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.sepia,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.sepia = val;
            _notifyChange(immediateVf: true);
          },
        ),

        if (_config.sepia)
          _buildSliderTile(
            title: 'Sepia Intensity',
            value: _config.sepiaIntensity,
            min: 0.1,
            max: 1.0,
            decimals: 2,
            onChanged: (val) {
              _config.sepiaIntensity = val;
              _notifyChange();
            },
            onReset: () {
              _config.sepiaIntensity = 0.8;
              _notifyChange();
            },
          ),
      ],
    );
  }

  // --- TAB 3: GEOMETRY & TRANSFORMS (VLC transform.c & rotate.c parity) ---
  Widget _buildGeometryTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
      children: [
        _buildSectionHeader('Geometric Transformation', () {
          _config.resetGeometry();
          _notifyChange(immediateVf: true);
        }),

        // Horizontal Flip (Mirror)
        SwitchListTile(
          title: const Text('Horizontal Flip (Mirror)', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Mirrors stream left-to-right (hflip)', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.flipHorizontal,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.flipHorizontal = val;
            _notifyChange(immediateVf: true);
          },
        ),

        // Vertical Flip
        SwitchListTile(
          title: const Text('Vertical Flip', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Inverts stream upside-down (vflip)', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.flipVertical,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.flipVertical = val;
            _notifyChange(immediateVf: true);
          },
        ),

        const Divider(color: EDesign.border, height: 16),

        // Continuous Rotation (VLC rotate.c parity)
        _buildSliderTile(
          title: 'Fine Angle Rotation (0° - 360°)',
          value: _config.rotationAngle,
          min: 0.0,
          max: 360.0,
          unit: '°',
          decimals: 0,
          onChanged: (val) {
            _config.rotationAngle = val;
            _notifyChange();
          },
          onReset: () {
            _config.rotationAngle = 0.0;
            _notifyChange();
          },
        ),
      ],
    );
  }

  // --- TAB 4: PRESETS (VLC & Cinematic Grading Parity) ---
  Widget _buildPresetsTab() {
    final presets = [
      _PresetItem(
        title: 'Neutral / Flat',
        description: 'Original unadulterated source grading',
        icon: Icons.refresh,
        config: VideoEffectsConfig.presetNormal(),
      ),
      _PresetItem(
        title: 'Vibrant OLED',
        description: 'Punchy high dynamic range color and deep contrast',
        icon: Icons.tv,
        config: VideoEffectsConfig.presetVibrant(),
      ),
      _PresetItem(
        title: 'Cinema Warm',
        description: 'Film-look with 3200K tungsten warmth and balanced blacks',
        icon: Icons.movie_filter,
        config: VideoEffectsConfig.presetCinemaWarm(),
      ),
      _PresetItem(
        title: 'Monochrome Noir',
        description: 'Classic high-contrast black & white photographic style',
        icon: Icons.monochrome_photos,
        config: VideoEffectsConfig.presetMonochromeNoir(),
      ),
      _PresetItem(
        title: 'Night Eye-Comfort',
        description: 'Low-fatigue muted brightness and reduced contrast',
        icon: Icons.nightlight_round,
        config: VideoEffectsConfig.presetNightComfort(),
      ),
      _PresetItem(
        title: 'Crisp Detail HD',
        description: 'Enhanced edge contours and unsharp clarity',
        icon: Icons.high_quality,
        config: VideoEffectsConfig.presetCrispDetail(),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
      children: [
        _buildSectionHeader('Professional 1-Tap Presets'),
        const SizedBox(height: 8),
        ...presets.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: EDesign.elevatedBackground,
              borderRadius: BorderRadius.circular(EDesign.r14),
              border: Border.all(
                color: EDesign.border,
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EDesign.elevatedSurface,
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: Icon(p.icon, color: EDesign.primaryCyan, size: 22),
              ),
              title: Text(
                p.title,
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                p.description,
                style: const TextStyle(color: EDesign.textMuted, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: EDesign.textSecondary, size: 14),
              onTap: () {
                _config = p.config;
                _notifyChange(immediateVf: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Applied "${p.title}" Preset'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: EDesign.elevatedSurface,
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  // --- REUSABLE UI HELPERS ---

  Widget _buildSectionHeader(String title, [VoidCallback? onResetSection]) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: EDesign.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (onResetSection != null)
            GestureDetector(
              onTap: onResetSection,
              child: const Text(
                'Reset Section',
                style: TextStyle(
                  color: EDesign.primaryCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
    String unit = '',
    int decimals = 0,
  }) {
    final bool isModified = value.abs() > 0.001;
    final String displayVal = decimals > 0
        ? value.toStringAsFixed(decimals)
        : (value > 0 ? '+${value.round()}$unit' : '${value.round()}$unit');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isModified
                          ? EDesign.primaryCyan.withValues(alpha: 0.15)
                          : EDesign.elevatedBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isModified
                            ? EDesign.primaryCyan.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      displayVal,
                      style: TextStyle(
                        color: isModified ? EDesign.primaryCyan : EDesign.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isModified) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onReset,
                      child: const Icon(
                        Icons.settings_backup_restore,
                        size: 16,
                        color: EDesign.textMuted,
                      ),
                    ),
                  ],
                ],
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
}

class _PresetItem {
  final String title;
  final String description;
  final IconData icon;
  final VideoEffectsConfig config;

  _PresetItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.config,
  });
}
