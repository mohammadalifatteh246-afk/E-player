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
          const Text('Subtitle Customization', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSectionTitle('Timing & Position'),
                _buildSliderRow('Delay (s)', _config.delay, -10.0, 10.0, (v) { _config.delay = v; _debouncedApply(); }),
                _buildSliderRow('Position', _config.position, 0.0, 150.0, (v) { _config.position = v; _debouncedApply(); }),
                
                const SizedBox(height: 24),
                _buildSectionTitle('Appearance'),
                _buildSliderRow('Font Size', _config.fontSize, 10.0, 100.0, (v) { _config.fontSize = v; _debouncedApply(); }),
                _buildSliderRow('Outline Size', _config.outlineSize, 0.0, 10.0, (v) { _config.outlineSize = v; _debouncedApply(); }),
                
                const SizedBox(height: 16),
                _buildColorRow('Font Color', _config.fontColor, (c) { _config.fontColor = c; _debouncedApply(); }),
                _buildColorRow('Outline Color', _config.outlineColor, (c) { _config.outlineColor = c; _debouncedApply(); }),
                _buildColorRow('Background', _config.backgroundColor, (c) { _config.backgroundColor = c; _debouncedApply(); }),
                
                const SizedBox(height: 24),
                _buildSectionTitle('Advanced'),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SwitchListTile(
                    title: const Text('Override ASS Styles', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Force custom styling on ASS/SSA subs', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _config.overrideAss,
                    activeColor: const Color(0xFF00E5FF),
                    activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white12,
                    onChanged: (v) {
                      _config.overrideAss = v;
                      _debouncedApply();
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      // Reset logic
                      _config.delay = 0.0;
                      _config.fontSize = 45.0;
                      _config.fontColor = Colors.white;
                      _config.outlineColor = Colors.black;
                      _config.backgroundColor = Colors.transparent;
                      _config.outlineSize = 2.0;
                      _config.position = 100.0;
                      _config.overrideAss = false;
                      _debouncedApply();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                    label: const Text('Reset', style: TextStyle(color: Colors.white54)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF00E5FF),
          inactiveColor: Colors.white12,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildColorRow(String label, Color currentColor, Function(Color) onColorSelected) {
    final colors = [Colors.transparent, Colors.white, Colors.black, Colors.yellow, Colors.cyan, Colors.red];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Row(
            children: colors.map((c) {
              final isSelected = currentColor.value == c.value;
              return GestureDetector(
                onTap: () => onColorSelected(c),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.white24, width: isSelected ? 2 : 1),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

}
