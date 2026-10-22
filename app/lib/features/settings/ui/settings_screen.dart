import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../player/ui/audio_studio_sheet.dart';
import '../../player/ui/subtitle_settings_sheet.dart';
import '../domain/settings_provider.dart';

/// Screen 5: Cyber-Stitch Settings Hub
/// Master Cyberpunk media engine settings hub with hardware decoders,
/// neural AI defaults, audio DSP, subtitle typography, and cache diagnostics.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _showSelectionSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
            border: Border.all(color: EDesign.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EDesign.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(icon, color: EDesign.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(title, style: EDesign.h3),
                ],
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final isSelected = opt == currentValue;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(opt);
                    Navigator.of(ctx).pop();
                  },
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? EDesign.primary.withValues(alpha: 0.12)
                          : EDesign.elevatedSurface,
                      borderRadius: BorderRadius.circular(EDesign.r12),
                      border: Border.all(
                        color: isSelected ? EDesign.primary : EDesign.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt,
                          style: TextStyle(
                            color: isSelected ? EDesign.primary : EDesign.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: EDesign.primary, size: 20)
                        else
                          Icon(Icons.radio_button_unchecked, color: EDesign.border, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showResetConfirmDialog(SettingsProvider provider) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: EDesign.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EDesign.r18),
            side: const BorderSide(color: EDesign.danger),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: EDesign.danger, size: 26),
              SizedBox(width: 10),
              Text('Reset Preferences', style: EDesign.h3),
            ],
          ),
          content: const Text(
            'Are you sure you want to restore all video playback, AI enhancement, audio DSP, and security preferences to factory defaults?',
            style: EDesign.secondaryStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: EDesign.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r8),
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await provider.resetToDefaults();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: EDesign.surface,
                    content: const Text(
                      'All settings reset to default',
                      style: TextStyle(color: EDesign.textPrimary),
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r12),
                      side: const BorderSide(color: EDesign.primary),
                    ),
                  ),
                );
              },
              child: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: EDesign.appBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EDesign.textPrimary, size: 20),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text('System Settings', style: EDesign.h2),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Diagnostics Engine Banner
                _buildEngineBanner(),
                const SizedBox(height: 20),

                // 1. Video & Hardware Decoders
                _buildSectionHeader('VIDEO & HARDWARE ACCELERATION', Icons.memory_rounded, EDesign.primary),
                const SizedBox(height: 10),
                _buildCard([
                  _buildSwitchTile(
                    title: 'Hardware Acceleration (HW+)',
                    subtitle: 'Direct3D11VA / Vulkan GPU decoding pipeline',
                    icon: Icons.speed_rounded,
                    value: provider.hwAcceleration,
                    onChanged: (val) => provider.setHwAcceleration(val),
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'Decoding Engine Mode',
                    subtitle: 'Active backend video decoder',
                    icon: Icons.settings_suggest_rounded,
                    value: provider.decodingMode,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Select Decoding Mode',
                        icon: Icons.settings_suggest_rounded,
                        options: ['HW+', 'HW', 'SW'],
                        currentValue: provider.decodingMode,
                        onSelected: (val) => provider.setDecodingMode(val),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Zero-Copy Direct Presentation',
                    subtitle: 'Bypass CPU memory copying for maximum 4K 120Hz throughput',
                    icon: Icons.layers_outlined,
                    value: provider.zeroCopyGpu,
                    onChanged: (val) => provider.setZeroCopyGpu(val),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Dynamic Display Rate Sync',
                    subtitle: 'Match monitor refresh rate to source video framerate',
                    icon: Icons.sync_rounded,
                    value: provider.dynamicResSwitching,
                    onChanged: (val) => provider.setDynamicResSwitching(val),
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'Default Aspect Ratio',
                    subtitle: 'Initial video display framing',
                    icon: Icons.aspect_ratio_rounded,
                    value: provider.aspectRatio,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Select Default Aspect Ratio',
                        icon: Icons.aspect_ratio_rounded,
                        options: ['Fit', 'Fill', '16:9', '4:3', '21:9'],
                        currentValue: provider.aspectRatio,
                        onSelected: (val) => provider.setAspectRatio(val),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'Initial Playback Speed',
                    subtitle: 'Default playback rate on open',
                    icon: Icons.fast_forward_rounded,
                    value: provider.playbackSpeed,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Select Playback Speed',
                        icon: Icons.fast_forward_rounded,
                        options: ['0.5x', '0.75x', '1.0x', '1.25x', '1.5x', '2.0x'],
                        currentValue: provider.playbackSpeed,
                        onSelected: (val) => provider.setPlaybackSpeed(val),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // 2. Neural AI Super-Resolution & RIFE
                _buildSectionHeader('AI ENHANCEMENT & FRAME INTERPOLATION', Icons.auto_awesome, EDesign.aiAccent),
                const SizedBox(height: 10),
                _buildCard([
                  _buildValueTile(
                    title: 'Default AI Super-Resolution Model',
                    subtitle: 'Tiled ONNX neural upscaler',
                    icon: Icons.model_training_rounded,
                    value: provider.defaultAiModel,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Select AI Upscaling Model',
                        icon: Icons.model_training_rounded,
                        options: [
                          'Real-ESRGAN x4 Plus',
                          'Anime4K v4.0',
                          'FSRCNN Fast',
                          'RealESR-AnimeVideoV3',
                        ],
                        currentValue: provider.defaultAiModel,
                        onSelected: (val) => provider.setDefaultAiModel(val),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Auto-Enable RIFE 60 FPS',
                    subtitle: 'Real-time motion vector frame interpolation for cinematic media',
                    icon: Icons.motion_photos_on_rounded,
                    value: provider.rifeDefault,
                    onChanged: (val) => provider.setRifeDefault(val),
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'Tensor Compute Precision',
                    subtitle: 'Floating point engine trade-off',
                    icon: Icons.precision_manufacturing_rounded,
                    value: provider.tensorPrecision,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Tensor Precision',
                        icon: Icons.precision_manufacturing_rounded,
                        options: [
                          'FP16 Compute',
                          'INT8 Low-Power',
                          'FP32 Full Precision',
                        ],
                        currentValue: provider.tensorPrecision,
                        onSelected: (val) => provider.setTensorPrecision(val),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'VRAM Allocation Safety Limit',
                    subtitle: 'Upper bound for GPU tensor buffer pool',
                    icon: Icons.sd_card_alert_rounded,
                    value: provider.vramLimit,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'VRAM Allocation Limit',
                        icon: Icons.sd_card_alert_rounded,
                        options: ['2.0 GB', '4.0 GB', '6.0 GB', 'Unlimited'],
                        currentValue: provider.vramLimit,
                        onSelected: (val) => provider.setVramLimit(val),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // 3. Audio Studio & DSP
                _buildSectionHeader('AUDIO STUDIO & DSP ENGINE', Icons.graphic_eq_rounded, EDesign.secondary),
                const SizedBox(height: 10),
                _buildCard([
                  _buildActionTile(
                    title: '10-Band Graphic Equalizer Studio',
                    subtitle: 'Precision dB pins, acoustic presets & live filter engine',
                    icon: Icons.equalizer_rounded,
                    badgeText: provider.defaultAudioPreset,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AudioEqualizerScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Speech Clarity Normalization',
                    subtitle: 'AI neural vocal isolation & dynamic dialogue leveling',
                    icon: Icons.record_voice_over_rounded,
                    value: provider.speechClarity,
                    onChanged: (val) => provider.setSpeechClarity(val),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: '3D Spatial Audio Virtualizer',
                    subtitle: 'HRTF binaural acoustic space for headphones & speakers',
                    icon: Icons.surround_sound_rounded,
                    value: provider.spatialVirtualizer,
                    onChanged: (val) => provider.setSpatialVirtualizer(val),
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'Audio Output Channel Layout',
                    subtitle: 'Speaker mixing format',
                    icon: Icons.speaker_group_rounded,
                    value: provider.audioOutputFormat,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Select Output Layout',
                        icon: Icons.speaker_group_rounded,
                        options: ['Stereo (2.0)', 'Surround (5.1)', 'Spatial Binaural'],
                        currentValue: provider.audioOutputFormat,
                        onSelected: (val) => provider.setAudioOutputFormat(val),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // 4. Subtitles & Typography
                _buildSectionHeader('SUBTITLES & TYPOGRAPHY STUDIO', Icons.subtitles_rounded, EDesign.success),
                const SizedBox(height: 10),
                _buildCard([
                  _buildActionTile(
                    title: 'Subtitle Customization Studio',
                    subtitle: 'Live letterbox preview, sync nudge (-30s..+30s), font & outline styling',
                    icon: Icons.palette_outlined,
                    badgeText: 'Studio',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubtitleCustomizationScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'Preferred Subtitle Language',
                    subtitle: 'Auto-select on stream load',
                    icon: Icons.language_rounded,
                    value: provider.subtitleLanguage,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Select Preferred Language',
                        icon: Icons.language_rounded,
                        options: [
                          'English [en]',
                          'Spanish [es]',
                          'Japanese [ja]',
                          'French [fr]',
                          'German [de]',
                          'Auto-Detect Track',
                        ],
                        currentValue: provider.subtitleLanguage,
                        onSelected: (val) => provider.setSubtitleLanguage(val),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Auto Encoding Detection',
                    subtitle: 'Detect UTF-8, Shift-JIS, and Windows-1252 encodings',
                    icon: Icons.font_download_outlined,
                    value: provider.autoEncoding,
                    onChanged: (val) => provider.setAutoEncoding(val),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Dual-Pass Outline & Shadow',
                    subtitle: 'High-contrast black stroke for readability across bright highlights',
                    icon: Icons.border_outer_rounded,
                    value: provider.dualPassOutline,
                    onChanged: (val) => provider.setDualPassOutline(val),
                  ),
                ]),
                const SizedBox(height: 24),

                // 5. Network & Streaming
                _buildSectionHeader('NETWORK & BUFFERING', Icons.wifi_tethering_rounded, EDesign.primary),
                const SizedBox(height: 10),
                _buildCard([
                  _buildSwitchTile(
                    title: 'Low-Latency RTSP Mode',
                    subtitle: 'Reduces streaming buffer for IP cameras and live broadcasts',
                    icon: Icons.network_check_rounded,
                    value: provider.lowLatencyRtsp,
                    onChanged: (val) => provider.setLowLatencyRtsp(val),
                  ),
                  _buildDivider(),
                  _buildValueTile(
                    title: 'Network Cache Buffer Size',
                    subtitle: 'Pre-buffered media capacity in memory',
                    icon: Icons.save_alt_rounded,
                    value: provider.networkBufferSize,
                    onTap: () {
                      _showSelectionSheet(
                        context: context,
                        title: 'Network Cache Buffer',
                        icon: Icons.save_alt_rounded,
                        options: ['16 MB', '32 MB', '64 MB', '128 MB'],
                        currentValue: provider.networkBufferSize,
                        onSelected: (val) => provider.setNetworkBufferSize(val),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // 6. Privacy & Secret Vault
                _buildSectionHeader('PRIVACY & SECRET VAULT', Icons.lock_outline_rounded, EDesign.warning),
                const SizedBox(height: 10),
                _buildCard([
                  _buildSwitchTile(
                    title: 'Decoy Safe PIN Mode',
                    subtitle: 'Entering PIN 0000 unlocks empty decoy storage mode with real media hidden',
                    icon: Icons.shield_outlined,
                    value: provider.decoyModeEnabled,
                    onChanged: (val) => provider.setDecoyModeEnabled(val),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Auto-Lock on Background',
                    subtitle: 'Immediately require master PIN when minimizing or switching apps',
                    icon: Icons.screen_lock_portrait_rounded,
                    value: provider.autoLockVault,
                    onChanged: (val) => provider.setAutoLockVault(val),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Biometric Fast Unlock',
                    subtitle: 'Allow fingerprint / Windows Hello authentication for vault access',
                    icon: Icons.fingerprint_rounded,
                    value: provider.biometricsEnabled,
                    onChanged: (val) => provider.setBiometricsEnabled(val),
                  ),
                ]),
                const SizedBox(height: 24),

                // 7. Storage, Shaders & Cache
                _buildSectionHeader('STORAGE & CACHE DIAGNOSTICS', Icons.storage_rounded, EDesign.danger),
                const SizedBox(height: 10),
                _buildCard([
                  _buildActionTile(
                    title: 'MPV Shader Compilation Cache',
                    subtitle: 'Cached Direct3D/Vulkan SPIR-V compute kernels',
                    icon: Icons.memory_rounded,
                    badgeText: '${provider.shaderCacheMb.toStringAsFixed(1)} MB',
                    actionLabel: 'Purge',
                    actionColor: EDesign.danger,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await provider.clearShaderCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: EDesign.surface,
                            content: const Text(
                              'Shader cache cleared',
                              style: TextStyle(color: EDesign.textPrimary),
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EDesign.r12),
                              side: const BorderSide(color: EDesign.primary),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'AI Temporary Render Cache',
                    subtitle: 'Orphaned .tmp video chunks and unfinished export buffers',
                    icon: Icons.cleaning_services_rounded,
                    badgeText: '${provider.aiTempCacheMb.toStringAsFixed(1)} MB',
                    actionLabel: 'Clean',
                    actionColor: EDesign.primary,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await provider.clearAiTempCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: EDesign.surface,
                            content: const Text(
                              'AI temporary render cache cleaned',
                              style: TextStyle(color: EDesign.textPrimary),
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EDesign.r12),
                              side: const BorderSide(color: EDesign.primary),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    title: 'Reset All Preferences',
                    subtitle: 'Restore all player, AI, audio, and subtitle options to defaults',
                    icon: Icons.restore_rounded,
                    badgeText: 'Default',
                    actionLabel: 'Reset',
                    actionColor: EDesign.danger,
                    onTap: () => _showResetConfirmDialog(provider),
                  ),
                ]),
                const SizedBox(height: 36),

                // Footer Build Signature
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'E-Player Ultra · Neural Studio v3.0.0',
                        style: TextStyle(
                          color: EDesign.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Engine: Libmpv 0.38 · ONNX DirectML · C++ Native FFI',
                        style: EDesign.caption.copyWith(color: EDesign.border),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEngineBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EDesign.cardDecoration(
        color: EDesign.elevatedSurface,
        radius: EDesign.r18,
        withGlow: true,
        glowColor: EDesign.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EDesign.primary.withValues(alpha: 0.25),
                      EDesign.aiAccent.withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  border: Border.all(color: EDesign.primary.withValues(alpha: 0.6)),
                ),
                child: const Icon(
                  Icons.developer_board_rounded,
                  color: EDesign.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('E-Player Neural Engine v3.0', style: EDesign.h3),
                    SizedBox(height: 3),
                    Text(
                      'Direct3D11VA GPU Acceleration · ONNX Runtime Active',
                      style: TextStyle(color: EDesign.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              EDesign.buildBadge('ACTIVE', color: EDesign.success),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: EDesign.appBackground,
              borderRadius: BorderRadius.circular(EDesign.r10),
              border: Border.all(color: EDesign.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BannerMetric(label: 'CORE DEMUXER', value: 'libmpv 0.38'),
                _BannerMetricDivider(),
                _BannerMetric(label: 'AI COMPUTE', value: 'DirectML ONNX'),
                _BannerMetricDivider(),
                _BannerMetric(label: 'HW STATUS', value: 'D3D11VA HW+'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: EDesign.cardDecoration(
        color: EDesign.surface,
        radius: EDesign.r16,
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: EDesign.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: EDesign.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeThumbColor: EDesign.primary,
            activeTrackColor: EDesign.primary.withValues(alpha: 0.35),
            inactiveThumbColor: EDesign.textSecondary,
            inactiveTrackColor: EDesign.elevatedSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildValueTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EDesign.r16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: EDesign.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: EDesign.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: EDesign.elevatedSurface,
                borderRadius: BorderRadius.circular(EDesign.r8),
                border: Border.all(color: EDesign.border),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: EDesign.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: EDesign.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    String? actionLabel,
    Color? actionColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EDesign.r16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: EDesign.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: EDesign.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (actionColor ?? EDesign.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(EDesign.r8),
                border: Border.all(color: (actionColor ?? EDesign.primary).withValues(alpha: 0.5)),
              ),
              child: Text(
                actionLabel ?? badgeText,
                style: TextStyle(
                  color: actionColor ?? EDesign.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: EDesign.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: EDesign.border),
    );
  }
}

class _BannerMetric extends StatelessWidget {
  final String label;
  final String value;

  const _BannerMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: EDesign.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: EDesign.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _BannerMetricDivider extends StatelessWidget {
  const _BannerMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: EDesign.border,
    );
  }
}
