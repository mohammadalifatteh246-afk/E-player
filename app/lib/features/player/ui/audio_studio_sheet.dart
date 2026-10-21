import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';

class AudioConfig {
  bool enabled = true;
  String preset = 'Rock';

  // 10-band Graphic EQ (dB gain: -12.0 to +12.0 dB)
  // Bands: 60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz
  static const List<int> freqs = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];
  static const List<String> freqLabels = ['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'];

  List<double> eq = [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5]; // Default Rock

  double bassBoost = 6.0; // 0 to 12 dB
  bool bassBoostEnabled = true;
  bool virtualizer = true;
  bool threeDAudio = true;
  bool nightMode = false;

  static const Map<String, List<double>> presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5],
    'Pop': [-1.5, -1.0, 1.0, 2.5, 4.0, 3.5, 1.5, -1.0, -1.5, -2.0],
    'Jazz': [3.0, 2.0, 1.0, 1.5, -1.5, -1.5, 0.0, 1.5, 3.0, 3.5],
    'Classical': [4.0, 3.0, 2.5, 2.0, -1.5, -1.5, 0.0, 2.5, 3.5, 4.0],
    'Bass Boost': [8.0, 7.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Vocal Boost': [-2.0, -2.5, -1.0, 2.0, 5.0, 5.0, 3.5, 1.5, 0.0, -1.5],
    'Techno': [6.0, 5.0, 0.0, -3.0, -2.5, 0.0, 4.0, 6.0, 6.5, 6.5],
    'Club': [0.0, 0.0, 2.0, 3.5, 3.5, 3.5, 2.0, 0.0, 0.0, 0.0],
  };

  void applyPreset(String name) {
    if (presets.containsKey(name)) {
      preset = name;
      eq = List<double>.from(presets[name]!);
    }
  }

  void apply(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      if (!enabled) {
        platform.setProperty('af', '');
        return;
      }

      final List<String> filters = [];

      // Bass Boost
      if (bassBoostEnabled && bassBoost > 0) {
        filters.add('bass=g=${bassBoost.toStringAsFixed(1)}');
      }

      // Night Mode (Loudness normalization)
      if (nightMode) {
        filters.add('dynaudnorm=f=200:g=15');
      }

      // Virtualizer (Stereo widening)
      if (virtualizer) {
        filters.add('extrastereo=m=2.2');
      }

      // 3D Audio (Spatial sound widening)
      if (threeDAudio) {
        filters.add('stereowiden=level=0.7');
      }

      // 10-Band Graphic Equalizer
      for (int i = 0; i < freqs.length; i++) {
        if (eq[i].abs() > 0.05) {
          filters.add('equalizer=f=${freqs[i]}:width_type=q:width=1.2:g=${eq[i].toStringAsFixed(1)}');
        }
      }

      final afString = filters.join(',');
      platform.setProperty('af', afString);
    } catch (e) {
      debugPrint('[Audio Studio] mpv af error: $e');
    }
  }

  void reset(Player? player) {
    enabled = true;
    preset = 'Flat';
    eq = List<double>.filled(10, 0.0);
    bassBoost = 0.0;
    bassBoostEnabled = false;
    virtualizer = false;
    threeDAudio = false;
    nightMode = false;
    apply(player);
  }
}

/// Standalone Full-Screen View (Matching Screen 7)
class AudioEqualizerScreen extends StatelessWidget {
  final Player? player;
  final AudioConfig? config;

  const AudioEqualizerScreen({super.key, this.player, this.config});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: AppBar(
        backgroundColor: EDesign.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Audio Equalizer',
          style: TextStyle(
            color: EDesign.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: AudioStudioSheet(
        player: player,
        config: config ?? AudioConfig(),
        isFullScreen: true,
      ),
    );
  }
}

/// Modal Bottom Sheet & Embedded Equalizer Widget
class AudioStudioSheet extends StatefulWidget {
  final Player? player;
  final AudioConfig config;
  final bool isFullScreen;

  const AudioStudioSheet({
    super.key,
    required this.player,
    required this.config,
    this.isFullScreen = false,
  });

  @override
  State<AudioStudioSheet> createState() => _AudioStudioSheetState();
}

class _AudioStudioSheetState extends State<AudioStudioSheet> {
  late AudioConfig _config;
  Timer? _debounce;
  int? _activeSliderIndex;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  void _debouncedApply() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _config.apply(widget.player);
    });
    setState(() {});
  }

  void _showPresetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: EDesign.border),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text(
                'Equalizer Preset',
                style: TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AudioConfig.presets.keys.map((p) {
                  final isSelected = _config.preset == p;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      _config.applyPreset(p);
                      _debouncedApply();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? EDesign.primary : EDesign.elevatedSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? EDesign.primary : EDesign.border,
                        ),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          color: isSelected ? Colors.black : EDesign.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: widget.isFullScreen ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isFullScreen) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audio Equalizer',
                  style: TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 1. Master Switch Card
          Container(
            decoration: BoxDecoration(
              color: EDesign.surface,
              borderRadius: BorderRadius.circular(EDesign.r16),
              border: Border.all(color: EDesign.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Enable Equalizer',
                  style: TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Switch(
                  value: _config.enabled,
                  activeThumbColor: EDesign.primary,
                  activeTrackColor: EDesign.primary.withValues(alpha: 0.35),
                  inactiveThumbColor: EDesign.disabled,
                  inactiveTrackColor: Colors.white12,
                  onChanged: (v) {
                    _config.enabled = v;
                    _config.apply(widget.player);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Preset Selector Dropdown Pill
          Row(
            children: [
              const Text(
                'Preset',
                style: TextStyle(
                  color: EDesign.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _config.enabled ? _showPresetPicker : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: EDesign.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EDesign.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _config.preset,
                          style: TextStyle(
                            color: _config.enabled ? EDesign.primary : EDesign.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: _config.enabled ? EDesign.primary : EDesign.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. 10-Band Graphic Equalizer Scale (Reference Screen 7)
          AnimatedOpacity(
            opacity: _config.enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              decoration: BoxDecoration(
                color: EDesign.surface,
                borderRadius: BorderRadius.circular(EDesign.r18),
                border: Border.all(color: EDesign.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Scale Labels (+12dB)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('+12dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                        Text('+12dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 10 Vertical Sliders Stack with Center 0dB Datum Line
                  SizedBox(
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Center 0dB Reference Line
                        Positioned(
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        // 10 Vertical Sliders Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(10, (index) {
                            return _build10BandSlider(index);
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom Scale Labels (-12dB)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('-12dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                        Text('-12dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Audio Boost Switches & Controls (Reference Screen 7)
          _buildBoostCard(
            title: 'Bass Boost',
            icon: Icons.speaker,
            value: _config.bassBoostEnabled,
            onToggle: (v) {
              _config.bassBoostEnabled = v;
              _debouncedApply();
            },
            sliderWidget: _config.bassBoostEnabled
                ? Slider(
                    value: _config.bassBoost,
                    min: 0.0,
                    max: 12.0,
                    activeColor: EDesign.primary,
                    inactiveColor: Colors.white12,
                    onChanged: (v) {
                      _config.bassBoost = v;
                      _debouncedApply();
                    },
                  )
                : null,
            sliderLabel: '${_config.bassBoost.toStringAsFixed(1)} dB',
          ),
          const SizedBox(height: 12),

          _buildBoostSwitchTile(
            title: 'Virtualizer',
            subtitle: 'Stereo soundstage widening',
            icon: Icons.surround_sound,
            value: _config.virtualizer,
            onChanged: (v) {
              _config.virtualizer = v;
              _debouncedApply();
            },
          ),
          const SizedBox(height: 12),

          _buildBoostSwitchTile(
            title: '3D Audio',
            subtitle: 'Spatial acoustic simulation',
            icon: Icons.spatial_audio_off,
            value: _config.threeDAudio,
            onChanged: (v) {
              _config.threeDAudio = v;
              _debouncedApply();
            },
          ),
          const SizedBox(height: 12),

          _buildBoostSwitchTile(
            title: 'Night Mode',
            subtitle: 'Loudness normalization / DRC',
            icon: Icons.nightlight_round,
            value: _config.nightMode,
            onChanged: (v) {
              _config.nightMode = v;
              _debouncedApply();
            },
          ),
          const SizedBox(height: 24),

          // 5. Reset to Defaults
          Center(
            child: TextButton.icon(
              onPressed: () {
                _config.reset(widget.player);
                setState(() {});
              },
              icon: const Icon(Icons.refresh, color: EDesign.textSecondary, size: 18),
              label: const Text(
                'Reset to Flat Defaults',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (widget.isFullScreen) {
      return content;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: EDesign.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: EDesign.border),
      ),
      child: content,
    );
  }

  Widget _build10BandSlider(int index) {
    final value = _config.eq[index];
    final isFocused = _activeSliderIndex == index;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Live dB badge when adjusted
        SizedBox(
          height: 18,
          child: isFocused || value.abs() > 0.1
              ? Text(
                  '${value > 0 ? "+" : ""}${value.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: isFocused ? EDesign.primary : Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Rotated Vertical Slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: EDesign.primary,
                inactiveTrackColor: Colors.white12,
                thumbColor: EDesign.primary,
                overlayColor: EDesign.primary.withValues(alpha: 0.25),
                trackHeight: 3.0,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: isFocused ? 7.0 : 5.0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
              ),
              child: Slider(
                value: value.clamp(-12.0, 12.0),
                min: -12.0,
                max: 12.0,
                onChangeStart: (_) {
                  setState(() => _activeSliderIndex = index);
                },
                onChangeEnd: (_) {
                  setState(() => _activeSliderIndex = null);
                },
                onChanged: _config.enabled
                    ? (v) {
                        _config.preset = 'Custom';
                        _config.eq[index] = v;
                        _debouncedApply();
                      }
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Frequency Label
        Text(
          AudioConfig.freqLabels[index],
          style: TextStyle(
            color: isFocused ? EDesign.primary : EDesign.textMuted,
            fontSize: 10,
            fontWeight: isFocused ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBoostCard({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onToggle,
    Widget? sliderWidget,
    String? sliderLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r14),
        border: Border.all(color: EDesign.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: EDesign.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Switch(
                value: value,
                activeThumbColor: EDesign.primary,
                activeTrackColor: EDesign.primary.withValues(alpha: 0.35),
                inactiveThumbColor: EDesign.disabled,
                inactiveTrackColor: Colors.white12,
                onChanged: onToggle,
              ),
            ],
          ),
          if (sliderWidget != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: sliderWidget),
                if (sliderLabel != null)
                  Text(
                    sliderLabel,
                    style: const TextStyle(
                      color: EDesign.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoostSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r14),
        border: Border.all(color: EDesign.border),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: EDesign.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
        ),
        secondary: Icon(icon, color: EDesign.primary, size: 20),
        value: value,
        activeThumbColor: EDesign.primary,
        activeTrackColor: EDesign.primary.withValues(alpha: 0.35),
        inactiveThumbColor: EDesign.disabled,
        inactiveTrackColor: Colors.white12,
        onChanged: onChanged,
      ),
    );
  }
}
