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
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F13),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audio Studio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Switch(
                value: _config.enabled,
                activeColor: const Color(0xFF00E5FF),
                activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.white12,
                onChanged: (v) {
                  _config.enabled = v;
                  _config.apply(widget.player);
                  setState(() {});
                },
              )
            ],
          ),
          const SizedBox(height: 16),
          if (!_config.enabled)
            const Expanded(child: Center(child: Text('Audio Studio is disabled.', style: TextStyle(color: Colors.white54))))
          else
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildToggleRow('Night Mode (Dynamic Range Compress)', _config.nightMode, (v) {
                    _config.nightMode = v;
                    _debouncedApply();
                  }),
                  _buildToggleRow('Vocal Boost', _config.dialogueBoost, (v) {
                    _config.dialogueBoost = v;
                    _debouncedApply();
                  }),
                  _buildToggleRow('Virtualizer (Stereo Widening)', _config.virtualizer, (v) {
                    _config.virtualizer = v;
                    _debouncedApply();
                  }),
                  const SizedBox(height: 24),
                  const Text('Bass Boost', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  Slider(
                    value: _config.bassBoost,
                    min: 0,
                    max: 15,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.white12,
                    onChanged: (v) {
                      _config.bassBoost = v;
                      _debouncedApply();
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('5-Band Equalizer (dB)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildEqSlider(0, '65Hz'),
                      _buildEqSlider(1, '250Hz'),
                      _buildEqSlider(2, '1kHz'),
                      _buildEqSlider(3, '4kHz'),
                      _buildEqSlider(4, '12kHz'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        _config.reset(widget.player);
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      label: const Text('Reset to Defaults', style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00E5FF),
        activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.white12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildEqSlider(int index, String label) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: _config.eq[index],
              min: -15.0,
              max: 15.0,
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white12,
              onChanged: (v) {
                _config.eq[index] = v;
                _debouncedApply();
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(_config.eq[index].toStringAsFixed(1), style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

}
