import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hwAcceleration = true;
  bool _gestureControls = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Playback'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchRow('Hardware Acceleration', Icons.memory, _hwAcceleration, (val) => setState(() => _hwAcceleration = val)),
              _buildDivider(),
              _buildValueRow('Decoding Mode', Icons.settings_suggest, 'HW+'),
              _buildDivider(),
              _buildValueRow('Aspect Ratio', Icons.aspect_ratio, 'Fit'),
            ]),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Player'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildValueRow('Playback Speed', Icons.speed, '1.0x'),
              _buildDivider(),
              _buildSwitchRow('Gesture Controls', Icons.touch_app, _gestureControls, (val) => setState(() => _gestureControls = val)),
            ]),
            const SizedBox(height: 24),

            _buildSectionTitle('Subtitles'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildValueRow('Font Size', Icons.format_size, 'Medium'),
              _buildDivider(),
              _buildValueRow('Text Color', Icons.format_color_text, 'White'),
              _buildDivider(),
              _buildValueRow('Outline', Icons.border_outer, '2px'),
            ]),
            const SizedBox(height: 24),

            _buildSectionTitle('Audio'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildValueRow('Equalizer', Icons.equalizer, ''),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchRow(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00E5FF),
            activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildValueRow(String title, IconData icon, String value) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))),
            if (value.isNotEmpty)
              Text(value, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
    );
  }
}
