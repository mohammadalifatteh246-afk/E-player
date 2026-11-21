import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../models/video_effects_config.dart';
import '../domain/video_effects_service.dart';
import '../domain/puzzle_wall_controller.dart';
import '../../player/services/interactive_zoom_controller.dart';

/// Interactive Video Effects Studio Sheet for E-Player.
/// Matches VLC Media Player's Extended Video Effects dialog:
/// Essential (Adjust & Sharpen), Colors, Geometry (Transform & Rotate), and Presets.
class VideoEffectsSheet extends StatefulWidget {
  final Player player;
  final VideoEffectsConfig config;
  final VideoEffectsService service;
  final VoidCallback onConfigChanged;
  final InteractiveZoomController? zoomController;
  final PuzzleWallController? puzzleWallController;

  const VideoEffectsSheet({
    super.key,
    required this.player,
    required this.config,
    required this.service,
    required this.onConfigChanged,
    this.zoomController,
    this.puzzleWallController,
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
    _tabController = TabController(length: 5, vsync: this);
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
    return Material(
      color: EDesign.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
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
                Tab(icon: Icon(Icons.layers_outlined, size: 18), text: 'Overlay'),
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
                    _buildOverlayTab(),
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

        const Divider(color: EDesign.border, height: 24),

        _buildSectionHeader('Deinterlacing (VLC deinterlace.c)', () {
          _config.deinterlaceMode = DeinterlaceMode.off;
          _config.deinterlaceAlgorithm = DeinterlaceAlgorithm.yadif;
          _notifyChange(immediateVf: true);
        }),

        // Deinterlace Mode Segmented Selector (Off, Auto, On)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegmentedButton<DeinterlaceMode>(
            segments: const [
              ButtonSegment(
                value: DeinterlaceMode.off,
                label: Text('Off'),
                icon: Icon(Icons.videocam_off_outlined, size: 16),
              ),
              ButtonSegment(
                value: DeinterlaceMode.auto,
                label: Text('Auto'),
                icon: Icon(Icons.auto_awesome, size: 16),
              ),
              ButtonSegment(
                value: DeinterlaceMode.on,
                label: Text('On'),
                icon: Icon(Icons.tune, size: 16),
              ),
            ],
            selected: {_config.deinterlaceMode},
            onSelectionChanged: (newSelection) {
              _config.deinterlaceMode = newSelection.first;
              _notifyChange(immediateVf: true);
            },
          ),
        ),

        // Algorithm Selector Chips (active when mode != off)
        if (_config.deinterlaceMode != DeinterlaceMode.off) ...[
          const SizedBox(height: 8),
          const Text('Deinterlace Algorithm Preset', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DeinterlaceAlgorithm.values.map((algo) {
              final isSelected = _config.deinterlaceAlgorithm == algo;
              return ChoiceChip(
                label: Text(algo.label),
                selected: isSelected,
                selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                labelStyle: TextStyle(
                  color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
                onSelected: (selected) {
                  if (selected) {
                    _config.deinterlaceAlgorithm = algo;
                    _notifyChange(immediateVf: true);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            _config.deinterlaceAlgorithm.description,
            style: const TextStyle(color: EDesign.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
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

        const Divider(color: EDesign.border, height: 24),

        _buildSectionHeader('Color Threshold Isolation (VLC colorthres.c)', () {
          _config.colorThreshold = false;
          _config.colorThresholdColor = 0xFF0000;
          _config.colorThresholdSimilarity = 0.30;
          _config.colorThresholdSaturation = 0.20;
          _notifyChange(immediateVf: true);
        }),

        // Threshold Switch
        SwitchListTile(
          title: const Text('Color Threshold Isolation', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Isolates selected color while turning other hues monochrome (Sin City / Pleasantville)', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.colorThreshold,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.colorThreshold = val;
            _notifyChange(immediateVf: true);
          },
        ),

        if (_config.colorThreshold) ...[
          const SizedBox(height: 8),
          const Text(
            'Target Color Preset',
            style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildColorChip('Red', 0xFF0000, const Color(0xFFFF0000)),
              _buildColorChip('Green', 0x00FF00, const Color(0xFF00FF00)),
              _buildColorChip('Blue', 0x0000FF, const Color(0xFF0044FF)),
              _buildColorChip('Yellow', 0xFFFF00, const Color(0xFFFFFF00)),
              _buildColorChip('Cyan', 0x00FFFF, const Color(0xFF00FFFF)),
              _buildColorChip('Magenta', 0xFF00FF, const Color(0xFFFF00FF)),
              _buildColorChip('Orange', 0xFFA500, const Color(0xFFFFA500)),
            ],
          ),
          const SizedBox(height: 12),
          _buildSliderTile(
            title: 'Similarity Tolerance',
            value: _config.colorThresholdSimilarity,
            min: 0.05,
            max: 0.80,
            decimals: 2,
            onChanged: (val) {
              _config.colorThresholdSimilarity = val;
              _notifyChange();
            },
            onReset: () {
              _config.colorThresholdSimilarity = 0.30;
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Saturation Threshold',
            value: _config.colorThresholdSaturation,
            min: 0.0,
            max: 1.0,
            decimals: 2,
            onChanged: (val) {
              _config.colorThresholdSaturation = val;
              _notifyChange();
            },
            onReset: () {
              _config.colorThresholdSaturation = 0.20;
              _notifyChange();
            },
          ),
        ],
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

        if (widget.zoomController != null) ...[
          const Divider(color: EDesign.border, height: 16),
          _buildSectionHeader('Interactive Zoom & Magnifier (VLC magnify.c)', () {
            widget.zoomController!.reset();
            setState(() {});
          }),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Magnification Scale',
                  style: TextStyle(color: EDesign.textPrimary, fontSize: 14),
                ),
                Text(
                  '${widget.zoomController!.state.zoomFactor.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: EDesign.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: widget.zoomController!.state.zoomFactor,
            min: 1.0,
            max: 8.0,
            divisions: 28,
            activeColor: EDesign.primaryCyan,
            inactiveColor: EDesign.surface,
            label: '${widget.zoomController!.state.zoomFactor.toStringAsFixed(1)}x',
            onChanged: (val) {
              widget.zoomController!.setZoom(val);
              setState(() {});
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16, color: EDesign.textSecondary),
                label: const Text(
                  'Reset Magnifier',
                  style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                ),
                onPressed: () {
                  widget.zoomController!.reset();
                  setState(() {});
                },
              ),
            ],
          ),
        ],

        const Divider(color: EDesign.border, height: 24),

        // --- Interactive Puzzle Game (VLC puzzle.c parity) ---
        _buildSectionHeader('Interactive Puzzle Game (VLC puzzle.c)', () {
          _config.resetPuzzle();
          widget.puzzleWallController?.syncWithConfig(_config);
          _notifyChange();
        }),

        SwitchListTile(
          title: const Text('Enable Puzzle Game', style: TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('Slices real-time video into interactive puzzle pieces', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.puzzleEnabled,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.puzzleEnabled = val;
            if (val) _config.wallEnabled = false; // Mutually exclusive
            widget.puzzleWallController?.syncWithConfig(_config);
            _notifyChange();
          },
        ),

        if (_config.puzzleEnabled) ...[
          const SizedBox(height: 8),
          const Text('Game Mode', style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Swap Pieces'),
                selected: _config.puzzleMode == PuzzleGameMode.swap,
                selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                onSelected: (selected) {
                  if (selected) {
                    _config.puzzleMode = PuzzleGameMode.swap;
                    widget.puzzleWallController?.syncWithConfig(_config);
                    _notifyChange();
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('15-Sliding Tile'),
                selected: _config.puzzleMode == PuzzleGameMode.sliding,
                selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                onSelected: (selected) {
                  if (selected) {
                    _config.puzzleMode = PuzzleGameMode.sliding;
                    widget.puzzleWallController?.syncWithConfig(_config);
                    _notifyChange();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Grid Size', style: TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final size in [2, 3, 4, 5])
                ChoiceChip(
                  label: Text('${size}x$size ${size == 2 ? "(Easy)" : size == 3 ? "(Classic)" : size == 4 ? "(Hard)" : "(Master)"}'),
                  selected: _config.puzzleRows == size && _config.puzzleCols == size,
                  selectedColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    if (selected) {
                      _config.puzzleRows = size;
                      _config.puzzleCols = size;
                      widget.puzzleWallController?.syncWithConfig(_config);
                      _notifyChange();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Target Mini Preview', style: TextStyle(color: EDesign.textPrimary, fontSize: 13)),
            subtitle: const Text('Shows un-scrambled video thumbnail in corner', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
            value: _config.puzzleShowPreview,
            activeThumbColor: EDesign.primaryCyan,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              _config.puzzleShowPreview = val;
              _notifyChange();
            },
          ),
          SwitchListTile(
            title: const Text('Tile Rotation Difficulty', style: TextStyle(color: EDesign.textPrimary, fontSize: 13)),
            subtitle: const Text('Pieces can be rotated; right-click / double-tap to rotate', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
            value: _config.puzzleAllowRotation,
            activeThumbColor: EDesign.primaryCyan,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              _config.puzzleAllowRotation = val;
              widget.puzzleWallController?.syncWithConfig(_config);
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Tile Border Spacing',
            value: _config.puzzleBorder,
            min: 0.0,
            max: 10.0,
            unit: 'px',
            decimals: 1,
            onChanged: (val) {
              _config.puzzleBorder = val;
              _notifyChange();
            },
            onReset: () {
              _config.puzzleBorder = 2.0;
              _notifyChange();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primaryCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    widget.puzzleWallController?.shufflePuzzle();
                    _notifyChange();
                  },
                  icon: const Icon(Icons.shuffle, size: 18),
                  label: const Text('Shuffle Puzzle', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    widget.puzzleWallController?.solvePuzzle();
                    _notifyChange();
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 18, color: Colors.amber),
                  label: const Text('Solve / Reset'),
                ),
              ),
            ],
          ),
        ],

        const Divider(color: EDesign.border, height: 24),

        // --- Video Wall Display Array (VLC wall.c parity) ---
        _buildSectionHeader('Video Wall Display Array (VLC wall.c)', () {
          _config.resetWall();
          widget.puzzleWallController?.syncWithConfig(_config);
          _notifyChange();
        }),

        SwitchListTile(
          title: const Text('Enable Video Wall', style: TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('Splits live video across multi-display matrix with monitor bezels', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.wallEnabled,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.wallEnabled = val;
            if (val) _config.puzzleEnabled = false; // Mutually exclusive
            widget.puzzleWallController?.syncWithConfig(_config);
            _notifyChange();
          },
        ),

        if (_config.wallEnabled) ...[
          _buildSliderTile(
            title: 'Wall Grid Rows',
            value: _config.wallRows.toDouble(),
            min: 1.0,
            max: 6.0,
            unit: ' rows',
            decimals: 0,
            onChanged: (val) {
              _config.wallRows = val.round();
              widget.puzzleWallController?.syncWithConfig(_config);
              _notifyChange();
            },
            onReset: () {
              _config.wallRows = 3;
              widget.puzzleWallController?.syncWithConfig(_config);
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Wall Grid Columns',
            value: _config.wallCols.toDouble(),
            min: 1.0,
            max: 6.0,
            unit: ' cols',
            decimals: 0,
            onChanged: (val) {
              _config.wallCols = val.round();
              widget.puzzleWallController?.syncWithConfig(_config);
              _notifyChange();
            },
            onReset: () {
              _config.wallCols = 3;
              widget.puzzleWallController?.syncWithConfig(_config);
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Monitor Bezel Thickness',
            value: _config.wallBezel,
            min: 0.0,
            max: 20.0,
            unit: 'px',
            decimals: 0,
            onChanged: (val) {
              _config.wallBezel = val;
              widget.puzzleWallController?.syncWithConfig(_config);
              _notifyChange();
            },
            onReset: () {
              _config.wallBezel = 4.0;
              widget.puzzleWallController?.syncWithConfig(_config);
              _notifyChange();
            },
          ),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0x3300E5FF),
              borderRadius: BorderRadius.circular(EDesign.r8),
              border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app, color: EDesign.primaryCyan, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Tap any monitor display during playback to solo-zoom that screen (VLC wall-active parity). Tap again to return to full wall.',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- TAB 4: OVERLAY (VLC logo.c & marq.c parity) ---
  Widget _buildOverlayTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: EDesign.s16, vertical: EDesign.s8),
      children: [
        _buildSectionHeader('Video Logo & Watermark (VLC logo.c)', () {
          _config.resetOverlay();
          _notifyChange();
        }),

        // 1. Watermark Switch
        SwitchListTile(
          title: const Text('Enable Watermark / Logo', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Overlays a PNG/JPG graphic watermark on the video stream', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.logoEnabled,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.logoEnabled = val;
            _notifyChange();
          },
        ),

        if (_config.logoEnabled) ...[
          const SizedBox(height: 8),
          // Logo File Picker Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EDesign.elevatedBackground,
              borderRadius: BorderRadius.circular(EDesign.r10),
              border: Border.all(color: EDesign.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.image_outlined, color: EDesign.primaryCyan, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _config.logoPath != null && _config.logoPath!.isNotEmpty
                        ? _config.logoPath!
                        : 'No watermark image selected',
                    style: TextStyle(
                      color: _config.logoPath != null ? EDesign.textPrimary : EDesign.textMuted,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.elevatedSurface,
                    foregroundColor: EDesign.primaryCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Browse', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    try {
                      final result = await FilePicker.pickFile(
                        type: FileType.image,
                      );
                      if (result != null && result.path != null) {
                        setState(() {
                          _config.logoPath = result.path!;
                        });
                        _notifyChange();
                      }
                    } catch (e) {
                      debugPrint('FilePicker error: $e');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Logo Position Selector
          const Text(
            'Logo Position',
            style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VideoOverlayPosition.values.map((pos) {
              final isSelected = _config.logoPosition == pos;
              return InkWell(
                borderRadius: BorderRadius.circular(EDesign.r8),
                onTap: () {
                  _config.logoPosition = pos;
                  _notifyChange();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? EDesign.primaryCyan.withValues(alpha: 0.15)
                        : EDesign.elevatedBackground,
                    borderRadius: BorderRadius.circular(EDesign.r8),
                    border: Border.all(
                      color: isSelected ? EDesign.primaryCyan : EDesign.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    pos.label,
                    style: TextStyle(
                      color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          _buildSliderTile(
            title: 'Logo Opacity',
            value: _config.logoOpacity,
            min: 0.1,
            max: 1.0,
            decimals: 2,
            onChanged: (val) {
              _config.logoOpacity = val;
              _notifyChange();
            },
            onReset: () {
              _config.logoOpacity = 0.85;
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Logo Scale',
            value: _config.logoScale,
            min: 0.2,
            max: 2.5,
            decimals: 2,
            onChanged: (val) {
              _config.logoScale = val;
              _notifyChange();
            },
            onReset: () {
              _config.logoScale = 1.0;
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Logo Offset X (Pixels)',
            value: _config.logoOffsetX.toDouble(),
            min: 0.0,
            max: 300.0,
            decimals: 0,
            onChanged: (val) {
              _config.logoOffsetX = val.round();
              _notifyChange();
            },
            onReset: () {
              _config.logoOffsetX = 20;
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Logo Offset Y (Pixels)',
            value: _config.logoOffsetY.toDouble(),
            min: 0.0,
            max: 300.0,
            decimals: 0,
            onChanged: (val) {
              _config.logoOffsetY = val.round();
              _notifyChange();
            },
            onReset: () {
              _config.logoOffsetY = 20;
              _notifyChange();
            },
          ),
        ],

        const Divider(color: EDesign.border, height: 24),

        // 2. Marquee / Text OSD Section
        _buildSectionHeader('Text Marquee & Dynamic OSD (VLC marq.c)'),

        SwitchListTile(
          title: const Text('Enable Text Marquee OSD', style: TextStyle(color: EDesign.textPrimary, fontSize: 14)),
          subtitle: const Text('Live on-screen text with dynamic format tokens (%t, %p, %l, %H:%M:%S)', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
          value: _config.marqueeEnabled,
          activeThumbColor: EDesign.primaryCyan,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            _config.marqueeEnabled = val;
            _notifyChange();
          },
        ),

        if (_config.marqueeEnabled) ...[
          const SizedBox(height: 8),
          // Marquee Text Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: EDesign.elevatedBackground,
              borderRadius: BorderRadius.circular(EDesign.r10),
              border: Border.all(color: EDesign.border),
            ),
            child: TextField(
              controller: TextEditingController(text: _config.marqueeText)
                ..selection = TextSelection.collapsed(offset: _config.marqueeText.length),
              style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter marquee format (e.g. %t • %p / %l)',
                hintStyle: TextStyle(color: EDesign.textMuted, fontSize: 12),
              ),
              onChanged: (val) {
                _config.marqueeText = val;
                _notifyChange();
              },
            ),
          ),
          const SizedBox(height: 8),

          // Preset Format Quick Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTokenChip('Title & Time', 'E-Player • %t • %p / %l'),
              _buildTokenChip('Clock Time', '%Y-%m-%d %H:%M:%S'),
              _buildTokenChip('Watermark Only', 'CONFIDENTIAL • %t'),
              _buildTokenChip('Time Remaining', 'Time: %p of %l'),
            ],
          ),
          const SizedBox(height: 12),

          // Marquee Position Selector
          const Text(
            'Marquee Position',
            style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VideoOverlayPosition.values.map((pos) {
              final isSelected = _config.marqueePosition == pos;
              return InkWell(
                borderRadius: BorderRadius.circular(EDesign.r8),
                onTap: () {
                  _config.marqueePosition = pos;
                  _notifyChange();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? EDesign.primaryCyan.withValues(alpha: 0.15)
                        : EDesign.elevatedBackground,
                    borderRadius: BorderRadius.circular(EDesign.r8),
                    border: Border.all(
                      color: isSelected ? EDesign.primaryCyan : EDesign.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    pos.label,
                    style: TextStyle(
                      color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          _buildSliderTile(
            title: 'Font Size',
            value: _config.marqueeFontSize,
            min: 10.0,
            max: 36.0,
            decimals: 0,
            unit: 'px',
            onChanged: (val) {
              _config.marqueeFontSize = val;
              _notifyChange();
            },
            onReset: () {
              _config.marqueeFontSize = 16.0;
              _notifyChange();
            },
          ),
          _buildSliderTile(
            title: 'Text Opacity',
            value: _config.marqueeOpacity,
            min: 0.1,
            max: 1.0,
            decimals: 2,
            onChanged: (val) {
              _config.marqueeOpacity = val;
              _notifyChange();
            },
            onReset: () {
              _config.marqueeOpacity = 0.90;
              _notifyChange();
            },
          ),
          SwitchListTile(
            title: const Text('Contrast Background Badge', style: TextStyle(color: EDesign.textPrimary, fontSize: 13)),
            subtitle: const Text('Draws semi-transparent dark pill behind text for high legibility', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
            value: _config.marqueeShowBackground,
            activeThumbColor: EDesign.primaryCyan,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              _config.marqueeShowBackground = val;
              _notifyChange();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTokenChip(String label, String template) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: EDesign.primaryCyan)),
      backgroundColor: EDesign.elevatedBackground,
      side: const BorderSide(color: EDesign.border, width: 0.5),
      onPressed: () {
        _config.marqueeText = template;
        _notifyChange();
      },
    );
  }

  // --- TAB 5: PRESETS (VLC & Cinematic Grading Parity) ---
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

  Widget _buildColorChip(String label, int hexVal, Color color) {
    final bool isSelected = _config.colorThresholdColor == hexVal;
    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r8),
      onTap: () {
        _config.colorThresholdColor = hexVal;
        _notifyChange(immediateVf: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? EDesign.primaryCyan.withValues(alpha: 0.15)
              : EDesign.elevatedBackground,
          borderRadius: BorderRadius.circular(EDesign.r8),
          border: Border.all(
            color: isSelected ? EDesign.primaryCyan : EDesign.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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
