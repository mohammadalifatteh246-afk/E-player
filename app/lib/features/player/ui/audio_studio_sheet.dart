import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class AudioConfig {
  bool enabled = false;
  
  // 5-band EQ (dB gain: -15 to +15)
  // Bands: 65Hz, 250Hz, 1kHz, 4kHz, 12kHz
  List<double> eq = [0.0, 0.0, 0.0, 0.0, 0.0];
  
  double bassBoost = 0.0; // 0 to 15 dB
  bool nightMode = false;
  bool virtualizer = false;
  bool dialogueBoost = false;

  void apply(Player player) {
    try {
      if (!enabled) {
        (player.platform as dynamic).setProperty('af', '');
        return;
      }

      List<String> filters = [];

      // Night Mode (Loudness normalization / Dynamic Range Compression)
      if (nightMode) {
        filters.add('dynaudnorm=f=200:g=15');
      }

      // Dialogue Boost (Center channel boost / Vocal frequency boost)
      if (dialogueBoost) {
        filters.add('equalizer=f=2500:width_type=q:width=1:g=5');
      }

      // Virtualizer (Stereo widening)
      if (virtualizer) {
        filters.add('extrastereo=m=2.5');
      }

      // Bass Boost
      if (bassBoost > 0) {
        filters.add('bass=g=${bassBoost.toStringAsFixed(1)}');
      }

      // 5-Band EQ
      final freqs = [65, 250, 1000, 4000, 12000];
      for (int i = 0; i < 5; i++) {
        if (eq[i] != 0.0) {
          filters.add('equalizer=f=${freqs[i]}:width_type=q:width=1:g=${eq[i].toStringAsFixed(1)}');
        }
      }

      final afString = filters.join(',');
      (player.platform as dynamic).setProperty('af', afString);
    } catch (e) {
      debugPrint("Audio Config Error: $e");
    }
  }

  void reset(Player player) {
    enabled = false;
    eq = [0.0, 0.0, 0.0, 0.0, 0.0];
    bassBoost = 0.0;
    nightMode = false;
    virtualizer = false;
    dialogueBoost = false;
    apply(player);
  }
}

class AudioStudioSheet extends StatefulWidget {
  final Player player;
  final AudioConfig config;

  const AudioStudioSheet({super.key, required this.player, required this.config});

  @override
  State<AudioStudioSheet> createState() => _AudioStudioSheetState();
}

class _AudioStudioSheetState extends State<AudioStudioSheet> {
  late AudioConfig _config;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  void _debouncedApply() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _config.apply(widget.player);
    });
    setState(() {}); // Update UI immediately
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audio Studio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Switch(
                value: _config.enabled,
                activeColor: Colors.blueAccent,
                onChanged: (v) {
                  _config.enabled = v;
                  _config.apply(widget.player);
                  setState(() {});
                },
              )
            ],
          ),
          const Divider(color: Colors.white24),
          if (!_config.enabled)
            const Expanded(child: Center(child: Text('Audio Studio is disabled.', style: TextStyle(color: Colors.white54))))
          else
            Expanded(
              child: ListView(
                children: [
                  _buildEqSliders(),
                  const SizedBox(height: 16),
                  _buildSlider('Bass Boost', _config.bassBoost, 0, 15, (v) => _config.bassBoost = v),
                  const Divider(color: Colors.white24),
                  SwitchListTile(
                    title: const Text('Night Mode', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Dynamic loudness normalization', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _config.nightMode,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) { _config.nightMode = v; _debouncedApply(); },
                  ),
                  SwitchListTile(
                    title: const Text('Virtualizer (3D)', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Stereo widening for headphones', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _config.virtualizer,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) { _config.virtualizer = v; _debouncedApply(); },
                  ),
                  SwitchListTile(
                    title: const Text('Dialogue Boost', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Enhances vocal clarity', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _config.dialogueBoost,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) { _config.dialogueBoost = v; _debouncedApply(); },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEqSliders() {
    final labels = ['65Hz', '250Hz', '1kHz', '4kHz', '12kHz'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('5-Band Equalizer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {
                _config.eq = [0.0, 0.0, 0.0, 0.0, 0.0];
                _debouncedApply();
              },
              child: const Text('Flat', style: TextStyle(color: Colors.blueAccent)),
            )
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            return Column(
              children: [
                Text('${_config.eq[i] > 0 ? '+' : ''}${_config.eq[i].toInt()} dB', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                SizedBox(
                  height: 150,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _config.eq[i],
                      min: -15,
                      max: 15,
                      divisions: 30,
                      activeColor: Colors.blueAccent,
                      onChanged: (v) {
                        _config.eq[i] = v;
                        _debouncedApply();
                      },
                    ),
                  ),
                ),
                Text(labels[i], style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            Text('${value > 0 ? '+' : ''}${value.toInt()} dB', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          activeColor: Colors.blueAccent,
          onChanged: (v) {
            onChanged(v);
            _debouncedApply();
          },
        ),
      ],
    );
  }
}
