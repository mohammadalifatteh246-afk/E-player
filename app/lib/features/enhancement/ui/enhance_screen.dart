import 'package:flutter/material.dart';

class EnhanceScreen extends StatefulWidget {
  const EnhanceScreen({super.key});

  @override
  State<EnhanceScreen> createState() => _EnhanceScreenState();
}

class _EnhanceScreenState extends State<EnhanceScreen> {
  bool _aiEnhancementVideo = true;
  String _enhancementMode = 'Auto';
  String _model = 'Real-ESRGAN';
  String _resolution = '1080p';
  bool _rifeEnabled = false;
  bool _nightMode = false;
  bool _stereo3D = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Enhancement Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_overscan, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('AI Enhancement'),
            const SizedBox(height: 12),
            _buildToggle('Video', 'Audio', _aiEnhancementVideo, (val) => setState(() => _aiEnhancementVideo = val)),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Enhancement Mode'),
            const SizedBox(height: 12),
            _buildSegmentedControl(['Auto', 'Manual', 'Preset'], _enhancementMode, (val) => setState(() => _enhancementMode = val)),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Model'),
            const SizedBox(height: 12),
            _buildDropdown(['Real-ESRGAN', 'Anime4K', 'FSRCNN'], _model, (val) => setState(() => _model = val)),

            const SizedBox(height: 24),
            _buildSectionTitle('Resolution'),
            const SizedBox(height: 12),
            _buildSegmentedControl(['720p', '1080p', '1440p', '2160p/4K'], _resolution, (val) => setState(() => _resolution = val)),

            const SizedBox(height: 32),
            _buildSwitchRow('RIFE Frame Interpolation', _rifeEnabled, (val) => setState(() => _rifeEnabled = val)),
            const SizedBox(height: 16),
            _buildSwitchRow('Night Mode', _nightMode, (val) => setState(() => _nightMode = val)),
            const SizedBox(height: 16),
            _buildSwitchRow('Stereoscopic 3D', _stereo3D, (val) => setState(() => _stereo3D = val)),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 8,
                  shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildToggle(String left, String right, bool isLeft, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isLeft ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isLeft ? Border.all(color: const Color(0xFF00E5FF)) : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text(left, style: TextStyle(color: isLeft ? const Color(0xFF00E5FF) : Colors.white70, fontWeight: isLeft ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isLeft ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: !isLeft ? Border.all(color: const Color(0xFF00E5FF)) : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text(right, style: TextStyle(color: !isLeft ? const Color(0xFF00E5FF) : Colors.white70, fontWeight: !isLeft ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(List<String> options, String current, Function(String) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: options.map((opt) {
          final isActive = opt == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isActive ? Border.all(color: const Color(0xFF00E5FF)) : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isActive ? const Color(0xFF00E5FF) : Colors.white70,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdown(List<String> options, String current, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A24),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: options.map((opt) {
            return DropdownMenuItem(value: opt, child: Text(opt));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String title, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
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
}
