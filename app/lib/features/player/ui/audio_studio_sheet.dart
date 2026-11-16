import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../audio/domain/audio_visualizer_engine.dart';
import '../../audio/domain/spatial_audio_models.dart';
import '../../audio/domain/audio_pitch_models.dart';
import '../../audio/ui/audio_spectrum_visualizer_widget.dart';

class AudioConfig {
  bool enabled = true;
  String preset = 'Rock';
  double preamp = 0.0;
  double audioDelay = 0.0; // in milliseconds [-10000.0, 10000.0]

  // 10-band Graphic EQ (dB gain: -20.0 to +20.0 dB)
  // Bands: 60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz
  static const List<int> freqs = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];
  static const List<String> freqLabels = ['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'];

  List<double> eq = [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5]; // Default Rock

  double bassBoost = 6.0; // 0 to 12 dB
  bool bassBoostEnabled = true;
  bool virtualizer = true;
  bool threeDAudio = true;
  bool nightMode = false;
  bool visualizerEnabled = false;
  VisualizerStyle visualizerStyle = VisualizerStyle.bars;
  SpatialAudioConfig spatialAudio = SpatialAudioConfig();
  AudioPitchConfig pitch = AudioPitchConfig();

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
    // 11 VLC Canonical Presets (Forensically verified against libequalizer_plugin.dll)
    'Full Bass': [-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2],
    'Full Bass & Treble': [7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0],
    'Full Treble': [-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8],
    'Headphones': [4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4],
    'Large Hall': [10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0],
    'Live': [-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4],
    'Party': [7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2],
    'Reggae': [0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0],
    'Ska': [-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6],
    'Soft': [4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0],
    'Soft Rock': [4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8],
  };

  static const Map<String, double> presetPreamps = {
    'Flat': 0.0,
    'Rock': 0.0,
    'Pop': 0.0,
    'Jazz': 0.0,
    'Classical': 0.0,
    'Bass Boost': 0.0,
    'Vocal Boost': 0.0,
    'Techno': 0.0,
    'Club': 0.0,
    'Full Bass': 5.0,
    'Full Bass & Treble': 4.0,
    'Full Treble': 3.0,
    'Headphones': 4.0,
    'Large Hall': 5.0,
    'Live': 7.0,
    'Party': 6.0,
    'Reggae': 8.0,
    'Ska': 6.0,
    'Soft': 5.0,
    'Soft Rock': 7.0,
  };

  void applyPreset(String name) {
    if (presets.containsKey(name)) {
      preset = name;
      eq = List<double>.from(presets[name]!);
      preamp = presetPreamps[name] ?? 0.0;
    }
  }

  String buildMpvAfString() {
    if (!enabled) return '';

    final List<String> filters = [];

    // Pre-Amplification (MUST precede equalizer bands and DSP)
    if (preamp.abs() > 0.05) {
      final sign = preamp >= 0 ? '+' : '';
      filters.add('volume=volume=$sign${preamp.toStringAsFixed(1)}dB:precision=fixed');
    }

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

    // Spatial Audio & Headphone Crossfeed (VLC parity)
    final spatialFilters = spatialAudio.buildAfFilterString();
    if (spatialFilters.isNotEmpty) {
      filters.add(spatialFilters);
    }

    // Audio Pitch Shifter & Scaler (VLC scaletempo.c parity)
    final pitchFilter = pitch.buildMpvAfString();
    if (pitchFilter.isNotEmpty) {
      filters.add(pitchFilter);
    }

    // 10-Band Graphic Equalizer
    for (int i = 0; i < freqs.length; i++) {
      if (eq[i].abs() > 0.05) {
        filters.add('equalizer=f=${freqs[i]}:width_type=q:width=1.2:g=${eq[i].toStringAsFixed(1)}');
      }
    }

    return filters.join(',');
  }

  /// Sets only the audio-delay property in mpv without re-pushing the 'af' filter chain.
  void applyAudioDelay(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      if (platform == null) return;
      platform.setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3));
    } catch (e) {
      debugPrint('[Audio Studio] mpv audio-delay error: $e');
    }
  }

  void apply(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      if (platform == null) return;
      platform.setProperty('af', buildMpvAfString());
    } catch (e) {
      debugPrint('[Audio Studio] mpv af error: $e');
    }
    applyAudioDelay(player);
  }

  void reset(Player? player) {
    enabled = true;
    preset = 'Flat';
    eq = List<double>.filled(10, 0.0);
    preamp = 0.0;
    audioDelay = 0.0;
    bassBoost = 0.0;
    bassBoostEnabled = false;
    virtualizer = false;
    threeDAudio = false;
    nightMode = false;
    spatialAudio.reset();
    pitch.reset();
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
  Timer? _delayDebounce;
  int? _activeSliderIndex;
  late final AudioVisualizerEngine _visualizerEngine;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _visualizerEngine = AudioVisualizerEngine(bandCount: 32);
    _visualizerEngine.setActive(_config.visualizerEnabled);
    if (widget.player != null) {
      try {
        _visualizerEngine.updateAudioContext(
          position: widget.player!.state.position,
          volume: widget.player!.state.volume,
          isPlaying: widget.player!.state.playing,
        );
      } catch (_) {
        _visualizerEngine.updateAudioContext(
          position: const Duration(seconds: 1),
          volume: 100.0,
          isPlaying: true,
        );
      }
    } else {
      _visualizerEngine.updateAudioContext(
        position: const Duration(seconds: 1),
        volume: 100.0,
        isPlaying: true,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _delayDebounce?.cancel();
    _visualizerEngine.dispose();
    super.dispose();
  }

  void _debouncedApplyAudioDelay() {
    if (_delayDebounce?.isActive ?? false) _delayDebounce!.cancel();
    _delayDebounce = Timer(const Duration(milliseconds: 50), () {
      _config.applyAudioDelay(widget.player);
    });
  }

  void _nudgeAudioDelay(double deltaMs) {
    _config.audioDelay = (_config.audioDelay + deltaMs).clamp(-10000.0, 10000.0);
    _config.applyAudioDelay(widget.player);
    setState(() {});
  }

  void _resetAudioDelay() {
    _config.audioDelay = 0.0;
    _config.applyAudioDelay(widget.player);
    setState(() {});
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
                      setState(() {});
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
          const SizedBox(height: 16),

          // Real-time FFT Audio Spectrum Visualizer
          _buildSpectrumVisualizerCard(),
          const SizedBox(height: 16),

          // Audio Synchronization Card
          _buildAudioDelaySyncCard(),
          const SizedBox(height: 16),

          // Pre-Amplification Slider Card
          _buildPreampCard(),
          const SizedBox(height: 16),

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
                  // Top Scale Labels (+20dB)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('+20dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                        Text('+20dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
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

                  // Bottom Scale Labels (-20dB)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('-20dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                        Text('-20dB', style: TextStyle(color: EDesign.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
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

          // Spatial Audio & Headphone Crossfeed Studio Card (VLC Parity)
          _buildSpatialAudioCard(),
          const SizedBox(height: 12),

          // Audio Pitch Shifter & Scaler (VLC scaletempo.c Parity)
          _buildPitchShifterCard(),
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

  Widget _buildSpectrumVisualizerCard() {
    return Container(
      key: const Key('audio_visualizer_card'),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: EDesign.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Real-Time Spectrum Visualizer',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _config.visualizerEnabled,
                activeThumbColor: EDesign.primary,
                activeTrackColor: EDesign.primary.withValues(alpha: 0.35),
                inactiveThumbColor: EDesign.disabled,
                inactiveTrackColor: Colors.white12,
                onChanged: (v) {
                  _config.visualizerEnabled = v;
                  _visualizerEngine.setActive(v);
                  setState(() {});
                },
              ),
            ],
          ),
          if (_config.visualizerEnabled) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: VisualizerStyle.values.map((style) {
                  final isSelected = _config.visualizerStyle == style;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(style.label),
                      selected: isSelected,
                      selectedColor: EDesign.primary.withValues(alpha: 0.25),
                      backgroundColor: EDesign.elevatedSurface,
                      labelStyle: TextStyle(
                        color: isSelected ? EDesign.primary : EDesign.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? EDesign.primary : EDesign.border,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _config.visualizerStyle = style;
                          setState(() {});
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            AudioSpectrumVisualizerWidget(
              engine: _visualizerEngine,
              style: _config.visualizerStyle,
              height: 110,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpatialAudioCard() {
    final spatial = _config.spatialAudio;
    return Container(
      key: const Key('spatial_audio_crossfeed_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(
          color: spatial.enabled ? EDesign.primary.withValues(alpha: 0.4) : EDesign.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r8),
                ),
                child: const Icon(Icons.headphones_outlined, color: EDesign.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spatial Audio & Crossfeed',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Binaural headphone crossfeed & room acoustics (VLC parity)',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('spatial_audio_toggle'),
                value: spatial.enabled,
                activeThumbColor: EDesign.primary,
                activeTrackColor: EDesign.primary.withValues(alpha: 0.5),
                onChanged: (val) {
                  setState(() => spatial.enabled = val);
                  _debouncedApply();
                },
              ),
            ],
          ),
          if (spatial.enabled) ...[
            const SizedBox(height: 12),
            const Text(
              'Binaural Crossfeed Preset (Anti-Fatigue)',
              style: TextStyle(color: EDesign.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildCrossfeedChip('Bauer Std (700Hz/4.5dB)', CrossfeedPreset.bauerDefault),
                _buildCrossfeedChip('Chu Moy (700Hz/6dB)', CrossfeedPreset.chuMoy),
                _buildCrossfeedChip('Jan Meier (650Hz/9.5dB)', CrossfeedPreset.janMeier),
                _buildCrossfeedChip('Off', CrossfeedPreset.off),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Room Acoustic Size', style: TextStyle(color: EDesign.textSecondary, fontSize: 11)),
                Text('${(spatial.roomSize * 100).round()}%', style: const TextStyle(color: EDesign.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: spatial.roomSize,
              min: 0.0,
              max: 1.0,
              activeColor: EDesign.primary,
              onChanged: (v) {
                setState(() => spatial.roomSize = v);
                _debouncedApply();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stereo Soundstage Width', style: TextStyle(color: EDesign.textSecondary, fontSize: 11)),
                Text('${spatial.stereoWidth.toStringAsFixed(1)}x', style: const TextStyle(color: EDesign.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: spatial.stereoWidth,
              min: 0.5,
              max: 2.5,
              activeColor: EDesign.primary,
              onChanged: (v) {
                setState(() => spatial.stereoWidth = v);
                _debouncedApply();
              },
            ),
            Row(
              children: [
                const Icon(Icons.surround_sound, color: EDesign.textMuted, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Virtual Multichannel Surround',
                    style: TextStyle(color: EDesign.textPrimary, fontSize: 11.5),
                  ),
                ),
                Switch.adaptive(
                  value: spatial.virtualSurround,
                  activeThumbColor: EDesign.primary,
                  activeTrackColor: EDesign.primary.withValues(alpha: 0.5),
                  onChanged: (val) {
                    setState(() => spatial.virtualSurround = val);
                    _debouncedApply();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrossfeedChip(String label, CrossfeedPreset preset) {
    final isSelected = _config.spatialAudio.crossfeedMode == preset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : EDesign.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: EDesign.primary,
      backgroundColor: EDesign.surface,
      side: BorderSide(
        color: isSelected ? EDesign.primary : EDesign.border,
        width: 0.8,
      ),
      onSelected: (val) {
        if (val) {
          setState(() => _config.spatialAudio.crossfeedMode = preset);
          _debouncedApply();
        }
      },
    );
  }

  Widget _buildPitchShifterCard() {
    final pitch = _config.pitch;
    final semitones = pitch.semitones;
    final cents = pitch.cents;
    final sign = semitones > 0 ? '+' : '';
    final centsSign = cents > 0 ? '+' : '';

    return Container(
      key: const Key('audio_pitch_shifter_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(
          color: pitch.enabled ? EDesign.primaryCyan.withValues(alpha: 0.4) : EDesign.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: EDesign.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r8),
                ),
                child: const Icon(Icons.music_note_rounded, color: EDesign.primaryCyan, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pitch Shifter & Scaler',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Transpose tone without altering playback speed (VLC scaletempo.c)',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('pitch_shifter_toggle'),
                value: pitch.enabled,
                activeThumbColor: EDesign.primaryCyan,
                activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.5),
                onChanged: (val) {
                  setState(() => pitch.enabled = val);
                  _debouncedApply();
                },
              ),
            ],
          ),
          if (pitch.enabled) ...[
            const SizedBox(height: 12),
            const Text(
              'Acoustic Pitch Presets',
              style: TextStyle(color: EDesign.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPitchPresetChip('Flat', AudioPitchPreset.flat),
                _buildPitchPresetChip('Chipmunk (+12st)', AudioPitchPreset.chipmunk),
                _buildPitchPresetChip('Deep Voice (-12st)', AudioPitchPreset.deepVoice),
                _buildPitchPresetChip('Male->Female (+4st)', AudioPitchPreset.maleToFemale),
                _buildPitchPresetChip('Female->Male (-4st)', AudioPitchPreset.femaleToMale),
                _buildPitchPresetChip('A432 Hz', AudioPitchPreset.concertPitch432),
                _buildPitchPresetChip('Fifth (+7st)', AudioPitchPreset.fifthInterval),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Semitone Transposition', style: TextStyle(color: EDesign.textSecondary, fontSize: 11)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: EDesign.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$sign$semitones st (${pitch.pitchRatio.toStringAsFixed(2)}x)',
                    style: const TextStyle(
                      color: EDesign.primaryCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: const Key('pitch_nudge_semitone_minus'),
                  icon: const Icon(Icons.remove_circle_outline, color: EDesign.textSecondary, size: 20),
                  tooltip: '-1 Semitone',
                  onPressed: () {
                    setState(() => pitch.setSemitones(pitch.semitones - 1));
                    _debouncedApply();
                  },
                ),
                Expanded(
                  child: Slider(
                    key: const Key('pitch_semitone_slider'),
                    value: pitch.semitones.toDouble(),
                    min: -12.0,
                    max: 12.0,
                    divisions: 24,
                    activeColor: EDesign.primaryCyan,
                    inactiveColor: EDesign.surface,
                    onChanged: (v) {
                      setState(() => pitch.setSemitones(v.round()));
                      _debouncedApply();
                    },
                  ),
                ),
                IconButton(
                  key: const Key('pitch_nudge_semitone_plus'),
                  icon: const Icon(Icons.add_circle_outline, color: EDesign.primaryCyan, size: 20),
                  tooltip: '+1 Semitone',
                  onPressed: () {
                    setState(() => pitch.setSemitones(pitch.semitones + 1));
                    _debouncedApply();
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fine Tuning (Cents)', style: TextStyle(color: EDesign.textSecondary, fontSize: 11)),
                Text(
                  '$centsSign${cents.toStringAsFixed(1)} cents',
                  style: const TextStyle(color: EDesign.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              key: const Key('pitch_cents_slider'),
              value: pitch.cents,
              min: -100.0,
              max: 100.0,
              divisions: 40,
              activeColor: EDesign.primaryCyan,
              inactiveColor: EDesign.surface,
              onChanged: (v) {
                setState(() => pitch.setCents(v));
                _debouncedApply();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  key: const Key('pitch_reset_button'),
                  icon: const Icon(Icons.refresh, size: 14, color: EDesign.textSecondary),
                  label: const Text('Reset Pitch', style: TextStyle(color: EDesign.textSecondary, fontSize: 11)),
                  onPressed: () {
                    setState(() => pitch.reset());
                    _debouncedApply();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPitchPresetChip(String label, AudioPitchPreset preset) {
    final isSelected = _config.pitch.preset == preset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.black : EDesign.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: EDesign.primaryCyan,
      backgroundColor: EDesign.surface,
      side: BorderSide(
        color: isSelected ? EDesign.primaryCyan : EDesign.border,
        width: 0.8,
      ),
      onSelected: (val) {
        if (val) {
          setState(() => _config.pitch.applyPreset(preset));
          _debouncedApply();
        }
      },
    );
  }

  Widget _buildAudioDelaySyncCard() {
    final delayVal = _config.audioDelay;
    return Container(
      key: const Key('audio_delay_sync_card'),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync, color: EDesign.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio Synchronization',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('audio_delay_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EDesign.elevatedSurface,
                  borderRadius: BorderRadius.circular(EDesign.r8),
                  border: Border.all(color: EDesign.border),
                ),
                child: Text(
                  '${delayVal >= 0 ? "+" : ""}${delayVal.toStringAsFixed(0)} ms',
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '-10.0s',
                style: TextStyle(
                  color: EDesign.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: EDesign.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: EDesign.primary,
                    overlayColor: EDesign.primary.withValues(alpha: 0.25),
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                  ),
                  child: Slider(
                    key: const Key('audio_delay_slider'),
                    value: (delayVal / 1000.0).clamp(-10.0, 10.0),
                    min: -10.0,
                    max: 10.0,
                    divisions: 400,
                    onChanged: (v) {
                      final ms = ((v * 1000.0) / 50.0).round() * 50.0;
                      _config.audioDelay = ms.clamp(-10000.0, 10000.0);
                      _debouncedApplyAudioDelay();
                      setState(() {});
                    },
                  ),
                ),
              ),
              const Text(
                '+10.0s',
                style: TextStyle(
                  color: EDesign.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNudgeButton('-100ms', const Key('audio_delay_nudge_minus_100'), () => _nudgeAudioDelay(-100)),
              _buildNudgeButton('-50ms', const Key('audio_delay_nudge_minus_50'), () => _nudgeAudioDelay(-50)),
              _buildNudgeButton('Reset', const Key('audio_delay_nudge_reset'), _resetAudioDelay),
              _buildNudgeButton('+50ms', const Key('audio_delay_nudge_plus_50'), () => _nudgeAudioDelay(50)),
              _buildNudgeButton('+100ms', const Key('audio_delay_nudge_plus_100'), () => _nudgeAudioDelay(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeButton(String label, Key key, VoidCallback onTap) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: EDesign.textPrimary,
        side: const BorderSide(color: EDesign.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(54, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPreampCard() {
    final preampVal = _config.preamp;
    return AnimatedOpacity(
      opacity: _config.enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(EDesign.r16),
          border: Border.all(color: EDesign.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: EDesign.primary, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Pre-Amplification',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: EDesign.elevatedSurface,
                        borderRadius: BorderRadius.circular(EDesign.r8),
                        border: Border.all(color: EDesign.border),
                      ),
                      child: Text(
                        '${preampVal >= 0 ? "+" : ""}${preampVal.toStringAsFixed(1)} dB',
                        style: const TextStyle(
                          color: EDesign.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      color: (_config.enabled && preampVal != 0.0)
                          ? EDesign.textSecondary
                          : EDesign.disabled,
                      tooltip: 'Reset Preamp to 0.0 dB',
                      onPressed: (_config.enabled && preampVal != 0.0)
                          ? () {
                              _config.preamp = 0.0;
                              _debouncedApply();
                              setState(() {});
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  '-20dB',
                  style: TextStyle(
                    color: EDesign.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: EDesign.primary,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: EDesign.primary,
                      overlayColor: EDesign.primary.withValues(alpha: 0.25),
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                    ),
                    child: Slider(
                      value: preampVal.clamp(-20.0, 20.0),
                      min: -20.0,
                      max: 20.0,
                      divisions: 80,
                      onChanged: _config.enabled
                          ? (v) {
                              _config.preamp = (v * 2).round() / 2.0;
                              _debouncedApply();
                              setState(() {});
                            }
                          : null,
                    ),
                  ),
                ),
                const Text(
                  '+20dB',
                  style: TextStyle(
                    color: EDesign.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                value: value.clamp(-20.0, 20.0),
                min: -20.0,
                max: 20.0,
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
                        setState(() {});
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
    return Material(
      color: EDesign.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EDesign.r14),
        side: const BorderSide(color: EDesign.border),
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

/// Standalone Audio Delay Synchronization Card conforming to R3 specification.
class AudioDelaySyncCard extends StatefulWidget {
  final Player? player;
  final double initialDelayMs;
  final ValueChanged<double>? onDelayChanged;

  const AudioDelaySyncCard({
    super.key,
    required this.player,
    this.initialDelayMs = 0.0,
    this.onDelayChanged,
  });

  @override
  State<AudioDelaySyncCard> createState() => AudioDelaySyncCardState();
}

class AudioDelaySyncCardState extends State<AudioDelaySyncCard> {
  late double _delayMs;

  @override
  void initState() {
    super.initState();
    _delayMs = widget.initialDelayMs;
  }

  void updateDelay(double ms) {
    final clamped = ms.clamp(-10000.0, 10000.0);
    setState(() {
      _delayMs = clamped;
    });
    if (widget.player != null) {
      try {
        final dynamic platform = widget.player!.platform;
        platform.setProperty('audio-delay', (_delayMs / 1000.0).toStringAsFixed(3));
      } catch (_) {}
    }
    widget.onDelayChanged?.call(_delayMs);
  }

  void nudge(double deltaMs) {
    updateDelay(_delayMs + deltaMs);
  }

  void reset() {
    updateDelay(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('audio_delay_sync_card'),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync, color: EDesign.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio Synchronization',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('audio_delay_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EDesign.elevatedSurface,
                  borderRadius: BorderRadius.circular(EDesign.r8),
                  border: Border.all(color: EDesign.border),
                ),
                child: Text(
                  '${_delayMs >= 0 ? "+" : ""}${_delayMs.toStringAsFixed(0)} ms',
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('-10.0s', style: TextStyle(color: EDesign.textMuted, fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: EDesign.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: EDesign.primary,
                    overlayColor: EDesign.primary.withValues(alpha: 0.25),
                  ),
                  child: Slider(
                    key: const Key('audio_delay_slider'),
                    value: (_delayMs / 1000.0).clamp(-10.0, 10.0),
                    min: -10.0,
                    max: 10.0,
                    divisions: 400,
                    onChanged: (v) {
                      updateDelay((v * 1000.0 * 2).round() / 2.0);
                    },
                  ),
                ),
              ),
              const Text('+10.0s', style: TextStyle(color: EDesign.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNudgeBtn('-100ms', const Key('audio_delay_nudge_minus_100'), () => nudge(-100)),
              _buildNudgeBtn('-50ms', const Key('audio_delay_nudge_minus_50'), () => nudge(-50)),
              _buildNudgeBtn('Reset', const Key('audio_delay_nudge_reset'), reset),
              _buildNudgeBtn('+50ms', const Key('audio_delay_nudge_plus_50'), () => nudge(50)),
              _buildNudgeBtn('+100ms', const Key('audio_delay_nudge_plus_100'), () => nudge(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeBtn(String label, Key key, VoidCallback onTap) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: EDesign.textPrimary,
        side: const BorderSide(color: EDesign.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(54, 32),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
