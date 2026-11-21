import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/dual_audio_models.dart';
import '../domain/dual_audio_service.dart';

/// Cyberpunk Modal Sheet for Dual Audio Output & Dubbing (VLC audio-device parity).
class DualAudioSheet extends StatefulWidget {
  final DualAudioService service;
  final Player? player;

  const DualAudioSheet({
    super.key,
    required this.service,
    this.player,
  });

  static Future<void> show(
    BuildContext context, {
    required DualAudioService service,
    Player? player,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DualAudioSheet(
        service: service,
        player: player,
      ),
    );
  }

  @override
  State<DualAudioSheet> createState() => _DualAudioSheetState();
}

class _DualAudioSheetState extends State<DualAudioSheet> {
  @override
  void initState() {
    super.initState();
    widget.service.refreshDevices(widget.player);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final config = widget.service.config;
        final devices = widget.service.devices;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: EDesign.surface.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: EDesign.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EDesign.primaryCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.speaker_group_rounded, color: EDesign.primaryCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dual Audio & Dubbing Studio',
                              style: TextStyle(
                                color: EDesign.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Multi-device soundcard & Bluetooth sync',
                              style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const Key('dual_audio_reset_button'),
                        onPressed: () {
                          widget.service.reset(widget.player);
                        },
                        child: const Text('Reset', style: TextStyle(color: EDesign.primaryCyan, fontSize: 13)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Master Enable Switch
                  SwitchListTile(
                    key: const Key('dual_audio_enable_switch'),
                    title: const Text(
                      'Enable Dual Audio Output',
                      style: TextStyle(color: EDesign.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Concurrently output audio to two independent soundcards or Bluetooth devices',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 12),
                    ),
                    value: config.enabled,
                    activeThumbColor: EDesign.primaryCyan,
                    activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.4),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      widget.service.toggleEnabled(widget.player);
                    },
                  ),

                  if (config.enabled) ...[
                    const Divider(color: EDesign.border, height: 20),

                    // Routing Mode Chips
                    const Text(
                      'Audio Routing Mode',
                      style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('dual_audio_mode_mirror'),
                            label: const Text('Mirror Duplicate'),
                            selected: config.routingMode == DualAudioRoutingMode.mirrorDuplicate,
                            selectedColor: EDesign.primaryCyan.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: config.routingMode == DualAudioRoutingMode.mirrorDuplicate
                                  ? EDesign.primaryCyan
                                  : EDesign.textSecondary,
                              fontWeight: config.routingMode == DualAudioRoutingMode.mirrorDuplicate
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                widget.service.setRoutingMode(DualAudioRoutingMode.mirrorDuplicate, widget.player);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('dual_audio_mode_dubbing'),
                            label: const Text('Dual-Track Dubbing'),
                            selected: config.routingMode == DualAudioRoutingMode.dualTrackDubbing,
                            selectedColor: EDesign.primaryCyan.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: config.routingMode == DualAudioRoutingMode.dualTrackDubbing
                                  ? EDesign.primaryCyan
                                  : EDesign.textSecondary,
                              fontWeight: config.routingMode == DualAudioRoutingMode.dualTrackDubbing
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                widget.service.setRoutingMode(DualAudioRoutingMode.dualTrackDubbing, widget.player);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Primary Output Device Card
                    _buildDeviceCard(
                      title: 'Primary Device (Speakers / HDMI)',
                      icon: Icons.speaker_rounded,
                      selectedId: config.primaryDeviceId,
                      devices: devices,
                      dropdownKey: const Key('dual_audio_primary_device_dropdown'),
                      volumeKey: const Key('dual_audio_primary_volume_slider'),
                      volume: config.primaryVolume,
                      isMuted: false,
                      onDeviceSelected: (id) => widget.service.setPrimaryDevice(id, widget.player),
                      onVolumeChanged: (vol) => widget.service.setPrimaryVolume(vol, widget.player),
                      onMuteToggled: null,
                    ),

                    const SizedBox(height: 12),

                    // Secondary Output Device Card
                    _buildDeviceCard(
                      title: 'Secondary Device (Headset / Bluetooth)',
                      icon: Icons.headphones_rounded,
                      selectedId: config.secondaryDeviceId ?? (devices.length > 2 ? devices[2].id : devices.last.id),
                      devices: devices,
                      dropdownKey: const Key('dual_audio_secondary_device_dropdown'),
                      volumeKey: const Key('dual_audio_secondary_volume_slider'),
                      volume: config.secondaryVolume,
                      isMuted: config.isSecondaryMuted,
                      muteKey: const Key('dual_audio_secondary_mute_button'),
                      onDeviceSelected: (id) => widget.service.setSecondaryDevice(id, widget.player),
                      onVolumeChanged: (vol) => widget.service.setSecondaryVolume(vol),
                      onMuteToggled: () => widget.service.toggleSecondaryMute(),
                    ),

                    const SizedBox(height: 16),

                    // Bluetooth Latency Synchronization Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bluetooth Latency Sync (Offset)',
                          style: TextStyle(color: EDesign.textSecondary, fontSize: 13),
                        ),
                        Text(
                          '${config.secondaryDelayMs > 0 ? "+" : ""}${config.secondaryDelayMs.round()} ms',
                          style: const TextStyle(color: EDesign.primaryCyan, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: EDesign.primaryCyan,
                        inactiveTrackColor: EDesign.border,
                        thumbColor: EDesign.primaryCyan,
                        overlayColor: EDesign.primaryCyan.withValues(alpha: 0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        key: const Key('dual_audio_delay_slider'),
                        value: config.secondaryDelayMs.clamp(-1000.0, 1000.0),
                        min: -1000.0,
                        max: 1000.0,
                        divisions: 200,
                        onChanged: (val) {
                          widget.service.setSecondaryDelay(val, widget.player);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceCard({
    required String title,
    required IconData icon,
    required String selectedId,
    required List<AudioDeviceEndpoint> devices,
    required Key dropdownKey,
    required Key volumeKey,
    required double volume,
    required bool isMuted,
    Key? muteKey,
    required ValueChanged<String> onDeviceSelected,
    required ValueChanged<double> onVolumeChanged,
    VoidCallback? onMuteToggled,
  }) {
    final validSelection = devices.any((d) => d.id == selectedId)
        ? selectedId
        : (devices.isNotEmpty ? devices.first.id : 'auto');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: EDesign.primaryCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (onMuteToggled != null && muteKey != null)
                IconButton(
                  key: muteKey,
                  icon: Icon(
                    isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: isMuted ? Colors.redAccent : EDesign.primaryCyan,
                    size: 18,
                  ),
                  onPressed: onMuteToggled,
                  tooltip: isMuted ? 'Unmute' : 'Mute',
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Device Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: EDesign.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: EDesign.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: dropdownKey,
                value: validSelection,
                isExpanded: true,
                dropdownColor: EDesign.surface,
                icon: const Icon(Icons.arrow_drop_down, color: EDesign.primaryCyan),
                items: devices.map((d) {
                  return DropdownMenuItem<String>(
                    value: d.id,
                    child: Row(
                      children: [
                        if (d.isBluetooth)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.bluetooth_rounded, size: 14, color: Colors.blueAccent),
                          )
                        else if (d.isUsb)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.usb_rounded, size: 14, color: Colors.greenAccent),
                          ),
                        Expanded(
                          child: Text(
                            d.name,
                            style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) onDeviceSelected(id);
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Volume Slider
          Row(
            children: [
              Text(
                'Vol: ${isMuted ? 0 : volume.round()}%',
                style: TextStyle(
                  color: isMuted ? Colors.redAccent : EDesign.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: isMuted ? EDesign.border : EDesign.primaryCyan,
                    inactiveTrackColor: EDesign.border,
                    thumbColor: isMuted ? EDesign.textMuted : EDesign.primaryCyan,
                    trackHeight: 2,
                  ),
                  child: Slider(
                    key: volumeKey,
                    value: (isMuted ? 0.0 : volume).clamp(0.0, 200.0),
                    min: 0.0,
                    max: 200.0,
                    onChanged: isMuted ? null : onVolumeChanged,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
