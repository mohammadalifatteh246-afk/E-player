import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class SubtitleConfig {
  double delay = 0.0; // seconds
  double fontSize = 45.0;
  Color fontColor = Colors.white;
  Color outlineColor = Colors.black;
  Color backgroundColor = Colors.transparent;
  double outlineSize = 2.0;
  double position = 100.0; // 0 to 100
  String encoding = 'UTF-8';
  bool overrideAss = false;

  void apply(Player player) {
    try {
      final platform = player.platform as dynamic;
      platform.setProperty('sub-delay', delay.toString());
      platform.setProperty('sub-font-size', fontSize.toString());
      
      String colorToHex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      platform.setProperty('sub-color', colorToHex(fontColor));
      platform.setProperty('sub-border-color', colorToHex(outlineColor));
      platform.setProperty('sub-back-color', colorToHex(backgroundColor));
      
      platform.setProperty('sub-border-size', outlineSize.toString());
      platform.setProperty('sub-pos', position.toString());
      platform.setProperty('sub-codepage', encoding);
      platform.setProperty('sub-ass-override', overrideAss ? 'force' : 'no');
    } catch (e) {
      debugPrint("Subtitle apply error: $e");
    }
  }

  void reset(Player player) {
    delay = 0.0;
    fontSize = 45.0;
    fontColor = Colors.white;
    outlineColor = Colors.black;
    backgroundColor = Colors.transparent;
    outlineSize = 2.0;
    position = 100.0;
    encoding = 'UTF-8';
    overrideAss = false;
    apply(player);
  }
}

class SubtitleSettingsSheet extends StatefulWidget {
  final Player player;
  final SubtitleConfig config;

  const SubtitleSettingsSheet({super.key, required this.player, required this.config});

  @override
  State<SubtitleSettingsSheet> createState() => _SubtitleSettingsSheetState();
}

class _SubtitleSettingsSheetState extends State<SubtitleSettingsSheet> {
  late SubtitleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  void _update() {
    _config.apply(widget.player);
    setState(() {});
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
              const Text('Subtitle Styles', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  _config.reset(widget.player);
                  setState(() {});
                },
                child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView(
              children: [
                _buildSlider('Delay (s)', _config.delay, -10.0, 10.0, (v) => _config.delay = v, 20),
                _buildSlider('Font Size', _config.fontSize, 10.0, 100.0, (v) => _config.fontSize = v, 90),
                _buildSlider('Position', _config.position, 0.0, 100.0, (v) => _config.position = v, 100),
                _buildSlider('Outline Size', _config.outlineSize, 0.0, 10.0, (v) => _config.outlineSize = v, 20),
                const SizedBox(height: 16),
                const Text('Colors', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildColorPicker('Text Color', _config.fontColor, (c) => _config.fontColor = c),
                _buildColorPicker('Outline', _config.outlineColor, (c) => _config.outlineColor = c),
                _buildColorPicker('Background', _config.backgroundColor, (c) => _config.backgroundColor = c),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Override ASS/SSA Styles', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Forces text subtitle styles on animated subtitles', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _config.overrideAss,
                  activeColor: Colors.blueAccent,
                  onChanged: (v) {
                    _config.overrideAss = v;
                    _update();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, int divisions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: Colors.blueAccent,
          onChanged: (v) {
            onChanged(v);
            _update();
          },
        ),
      ],
    );
  }

  Widget _buildColorPicker(String label, Color currentColor, Function(Color) onChanged) {
    final colors = [
      Colors.transparent, Colors.black, Colors.white, Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.cyan,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white70))),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: colors.map((c) {
                  final isSelected = c.value == currentColor.value;
                  return GestureDetector(
                    onTap: () {
                      onChanged(c);
                      _update();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c == Colors.transparent ? Colors.grey[800] : c,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white24, width: isSelected ? 3 : 1),
                      ),
                      child: c == Colors.transparent ? const Icon(Icons.format_color_reset, size: 16, color: Colors.white54) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
