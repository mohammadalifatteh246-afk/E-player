import 'package:flutter/material.dart';
import '../../../../core/engine_orchestrator.dart'; // To interface with the native engine

class EnhancementConfig {
  bool masterToggle = false;
  String resolution = '1080p'; // Mapped to upscale factors internally
  String aiModel = 'General (realesr-general-x4v3)'; // New property based on PDF
  int fpsTarget = 30;
  bool audioEnhance = false;
  bool stereo3D = false;
  double audioEnhanceStrength = 1.0;
  bool nightMode = false;
}

class EnhancementStudioSheet extends StatefulWidget {
  final NativeEngineOrchestrator aiEngine;
  final String mediaPath;
  final EnhancementConfig config;

  const EnhancementStudioSheet({
    super.key,
    required this.aiEngine,
    required this.mediaPath,
    required this.config,
  });

  @override
  State<EnhancementStudioSheet> createState() => _EnhancementStudioSheetState();
}

class _EnhancementStudioSheetState extends State<EnhancementStudioSheet> {
  late EnhancementConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live AI Enhancements',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _config.masterToggle,
                activeThumbColor: Colors.amber,
                onChanged: widget.aiEngine.isLoaded ? (val) {
                  setState(() => _config.masterToggle = val);
                  if (val) {
                    widget.aiEngine.bypassAudioEnhancement(false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI Enhancement Pipeline Activated')),
                    );
                  } else {
                    widget.aiEngine.bypassAudioEnhancement(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI Enhancement Pipeline Disabled')),
                    );
                  }
                } : null, // Disable switch if engine is not loaded
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          
          if (!widget.aiEngine.isLoaded)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Engine Native Library missing. Live enhancements are currently unavailable in standard playback mode.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  )
                ],
              ),
            ),
          
          // AI Model Selection
          ListTile(
            title: const Text('AI Enhancement Model', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Select Real-ESRGAN variant', style: TextStyle(color: Colors.white54)),
            trailing: DropdownButton<String>(
              dropdownColor: Colors.grey[800],
              value: _config.aiModel,
              style: const TextStyle(color: Colors.amber),
              items: [
                'General (realesr-general-x4v3)',
                'Anime (RealESRGAN_x4plus_anime_6B)'
              ].map((model) {
                return DropdownMenuItem(value: model, child: Text(model.split(' ').first));
              }).toList(),
              onChanged: _config.masterToggle ? (val) {
                if (val != null) setState(() => _config.aiModel = val);
              } : null,
            ),
          ),
          
          // Spatial Restoration (Resolution)
          ListTile(
            title: const Text('Resolution Target', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Real-ESRGAN Spatial Upscaling', style: TextStyle(color: Colors.white54)),
            trailing: DropdownButton<String>(
              dropdownColor: Colors.grey[800],
              value: _config.resolution,
              style: const TextStyle(color: Colors.amber),
              items: ['720p', '1080p', '1440p', '4K'].map((res) {
                return DropdownMenuItem(value: res, child: Text(res));
              }).toList(),
              onChanged: _config.masterToggle ? (val) {
                if (val != null) setState(() => _config.resolution = val);
              } : null,
            ),
          ),
          
          // Temporal Interpolation (FPS)
          ListTile(
            title: const Text('Frame Rate Interpolation', style: TextStyle(color: Colors.white)),
            subtitle: const Text('RIFE Temporal Enhancement', style: TextStyle(color: Colors.white54)),
            trailing: DropdownButton<int>(
              dropdownColor: Colors.grey[800],
              value: _config.fpsTarget,
              style: const TextStyle(color: Colors.amber),
              items: [30, 60, 120].map((fps) {
                return DropdownMenuItem(value: fps, child: Text('${fps}fps'));
              }).toList(),
              onChanged: _config.masterToggle ? (val) {
                if (val != null) setState(() => _config.fpsTarget = val);
              } : null,
            ),
          ),
          
          // Audio Enhancement
          SwitchListTile(
            title: const Text('Isolate Dialogue', style: TextStyle(color: Colors.white)),
            subtitle: const Text('RNNoise background suppression', style: TextStyle(color: Colors.white54)),
            activeThumbColor: Colors.amber,
            value: _config.audioEnhance,
            onChanged: _config.masterToggle ? (val) {
              setState(() => _config.audioEnhance = val);
              // In production, sync this instantly to native backend:
              // widget.aiEngine.setAudioAiConfig(val, 1.0);
            } : null,
          ),
          
          if (_config.audioEnhance)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Text('Strength', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: _config.audioEnhanceStrength,
                      activeColor: Colors.amber,
                      onChanged: (val) {
                        setState(() => _config.audioEnhanceStrength = val);
                        // widget.aiEngine.setAudioAiConfig(_config.audioEnhance, val);
                      },
                    ),
                  ),
                ],
              ),
            ),

          SwitchListTile(
            title: const Text('Night Mode (DSP)', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Loudness normalization & Compressor', style: TextStyle(color: Colors.white54)),
            activeThumbColor: Colors.amber,
            value: _config.nightMode,
            onChanged: _config.masterToggle ? (val) {
              setState(() => _config.nightMode = val);
              // widget.aiEngine.setAudioDspConfig(enableNightMode: val, enableNormalization: val, enableCompressor: val);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Night Mode ${val ? 'Enabled' : 'Disabled'}')));
            } : null,
          ),
          
          // Phase 8B: 2D to 3D Depth
          SwitchListTile(
            title: const Text('Stereoscopic 3D (SBS)', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Depth Anything V2 Conversion', style: TextStyle(color: Colors.white54)),
            activeThumbColor: Colors.amber,
            value: _config.stereo3D,
            onChanged: _config.masterToggle ? (val) {
              // Phase 8C Capability Gating Check
              bool canEnable = widget.aiEngine.canEnablePipeline(
                needsSpatial: _config.resolution == '4K' || _config.resolution == '1440p',
                needsTemporal: _config.fpsTarget > 30,
                needsAudio: _config.audioEnhance,
                needsDepth: val,
              );
              
              if (val && !canEnable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thermal/Memory limits prevent enabling 3D alongside other heavy AI models.'))
                );
                return;
              }
              
              setState(() => _config.stereo3D = val);
              widget.aiEngine.setDepthConfig(val, 1.0, 0.5);
            } : null,
          ),

          // Phase 8A: Subtitle Generation (Offline ASR)
          ListTile(
            title: const Text('Generate Subtitles', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Offline ASR (Whisper Mobile)', style: TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.closed_caption, color: Colors.amber),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting Background ASR...')));
              // widget.aiEngine.generateSubtitles('audio.wav', 'out.srt');
            },
          ),
          
          const SizedBox(height: 20),
          
          const SizedBox(height: 20),
          
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close the sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Live Enhancements Applied (Simulated via DSP filters)')),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Apply to Live Playback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
