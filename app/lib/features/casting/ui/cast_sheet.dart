import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../../widgets/e_player_components.dart';
import '../domain/cast_service.dart';

/// Screen 12: Cast Sheet & Network Device Radar
/// Master Cyberpunk Aesthetics with Real-Time Discovery Radar,
/// Discovered Device Bento List, and Remote Synchronizer Dock.
/// Architecture mirrors VLC's vlc_renderer_discovery and stream_out_chromecast.
class CastSheet extends StatefulWidget {
  final Player? player;
  final String? mediaTitle;

  const CastSheet({
    super.key,
    this.player,
    this.mediaTitle,
  });

  /// Displays the CastSheet as a floating modal bottom sheet over any screen/player
  static Future<void> show(
    BuildContext context, {
    Player? player,
    String? mediaTitle,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CastSheet(
        player: player,
        mediaTitle: mediaTitle,
      ),
    );
  }

  @override
  State<CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<CastSheet> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  CastProtocol? _selectedProtocolFilter;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // Attach active player to CastService for bi-directional state synchronization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.player != null) {
        Provider.of<CastService>(context, listen: false).attachPlayer(
          widget.player!,
          mediaTitle: widget.mediaTitle,
        );
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CastService>(
      builder: (context, castService, child) {
        final connectedDevice = castService.connectedDevice;
        final allDevices = castService.devices;

        final displayedDevices = _selectedProtocolFilter == null
            ? allDevices
            : allDevices.where((d) => d.protocol == _selectedProtocolFilter).toList();

        final height = MediaQuery.of(context).size.height * 0.88;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
            border: Border.all(color: EDesign.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 36,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Title Bar
              _buildTopBar(context, castService),

              // Scrollable Radar, Connected Hub, and Devices List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
                  children: [
                    // Active Connected Device Remote Hub (Displayed when streaming)
                    if (connectedDevice != null) ...[
                      _buildConnectedDeviceHub(context, castService, connectedDevice),
                      const SizedBox(height: 20),
                    ],

                    // Radar Scanner Scope (Displayed when no active cast or searching)
                    if (connectedDevice == null) ...[
                      _buildRadarScanner(castService),
                      const SizedBox(height: 18),
                    ],

                    // Protocol Filter Chips
                    _buildProtocolFilters(allDevices),
                    const SizedBox(height: 14),

                    // Discovered Target Devices Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DISCOVERED TARGETS (${displayedDevices.length})',
                          style: const TextStyle(
                            color: EDesign.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (castService.isScanning)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: EDesign.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: EDesign.primary.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Scanning...',
                                style: TextStyle(color: EDesign.primary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Target Devices Cards
                    ...displayedDevices.map((device) {
                      return _buildDeviceTile(context, castService, device);
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, CastService castService) {
    return Column(
      children: [
        const SizedBox(height: 10),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: const EVectorIcon(name: 'cast', color: EDesign.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cast & Network Radar', style: EDesign.h3),
                    const SizedBox(height: 2),
                    Text(
                      widget.mediaTitle != null
                          ? 'Targeting: ${widget.mediaTitle}'
                          : 'Mirror 4K HDR stream to wireless displays',
                      style: EDesign.caption.copyWith(color: EDesign.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: EDesign.primary, size: 22),
                tooltip: 'Scan for Devices',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  castService.startScan();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: EDesign.textSecondary, size: 22),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: EDesign.border),
      ],
    );
  }

  /// Animated Concentric Radar Scanner Scope (Mirroring VLC's background discovery loop)
  Widget _buildRadarScanner(CastService castService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EDesign.cardDecoration(
        color: EDesign.elevatedSurface,
        radius: EDesign.r18,
        withGlow: castService.isScanning,
        glowColor: EDesign.primary,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.radar_rounded, color: EDesign.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'mDNS / SSDP Discovery Radar',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              EDesign.buildBadge(
                castService.isScanning ? 'RADAR ACTIVE' : 'RADAR IDLE',
                color: castService.isScanning ? EDesign.primary : EDesign.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Central Radar Scope Animation
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(220, 140),
                      painter: _RadarScopePainter(
                        progress: _radarController.value,
                        isScanning: castService.isScanning,
                      ),
                    );
                  },
                ),
                // Center Glowing Hub Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EDesign.surface,
                    border: Border.all(color: EDesign.primary, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: EDesign.primary.withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.wifi_tethering_rounded,
                    color: EDesign.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Text(
            castService.isScanning
                ? 'Broadcasting discovery probes across local subnet 192.168.1.0/24...'
                : 'Found 5 local wireless display targets ready for 4K streaming.',
            style: EDesign.caption.copyWith(color: EDesign.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Active Connected Device Hub with Live Telemetry, Seek & Volume Sync
  Widget _buildConnectedDeviceHub(
    BuildContext context,
    CastService castService,
    CastDevice device,
  ) {
    final session = castService.activeSession;
    final currentPos = session?.position ?? widget.player?.state.position ?? Duration.zero;
    final totalDur = session?.duration ?? widget.player?.state.duration ?? Duration.zero;
    final maxSeconds = totalDur.inSeconds > 0 ? totalDur.inSeconds.toDouble() : 1.0;
    final posSeconds = currentPos.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EDesign.cardDecoration(
        color: EDesign.elevatedSurface,
        borderColor: EDesign.primary.withValues(alpha: 0.8),
        radius: EDesign.r18,
        withGlow: true,
        glowColor: EDesign.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Connected Target Name & Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  border: Border.all(color: EDesign.primary),
                ),
                child: const Icon(Icons.tv_rounded, color: EDesign.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.model} · ${device.ipAddress}',
                      style: EDesign.caption.copyWith(color: EDesign.textSecondary),
                    ),
                  ],
                ),
              ),
              EDesign.buildBadge('STREAMING 4K', color: EDesign.success),
            ],
          ),

          const SizedBox(height: 14),

          // Live Stream Telemetry Grid (Mirroring VLC sout telemetry)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: EDesign.appBackground,
              borderRadius: BorderRadius.circular(EDesign.r10),
              border: Border.all(color: EDesign.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TelemetryItem(
                  label: 'PIPELINE',
                  value: session?.transcodeProfile.label ?? 'Direct Stream',
                ),
                _TelemetryItem(
                  label: 'AUDIO',
                  value: session?.audioRoute == 'tv' ? 'Display 5.1' : 'Device Audio',
                ),
                _TelemetryItem(
                  label: 'LATENCY',
                  value: '${session?.pingMs ?? 14} ms sync',
                ),
                _TelemetryItem(
                  label: 'BITRATE',
                  value: '${(session?.bitrateMbps ?? 48.2).toStringAsFixed(1)} Mbps',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Remote Playback Scrub Bar with Timestamps
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: EDesign.primary,
                  inactiveTrackColor: EDesign.surface,
                  thumbColor: EDesign.primary,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 3,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: posSeconds,
                  min: 0.0,
                  max: maxSeconds,
                  onChanged: (val) {
                    castService.seek(Duration(seconds: val.round()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(currentPos),
                      style: EDesign.caption.copyWith(
                        color: EDesign.primary,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDuration(totalDur),
                      style: EDesign.caption.copyWith(
                        color: EDesign.textSecondary,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Remote Playback Sync Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, color: EDesign.textPrimary, size: 28),
                tooltip: 'Rewind 10s',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final current = currentPos;
                  castService.seek(
                    current > const Duration(seconds: 10)
                        ? current - const Duration(seconds: 10)
                        : Duration.zero,
                  );
                },
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  castService.toggleRemotePlayPause();
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EDesign.primary,
                    boxShadow: [
                      BoxShadow(
                        color: EDesign.primary.withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(
                    castService.isRemotePlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, color: EDesign.textPrimary, size: 28),
                tooltip: 'Forward 10s',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final current = currentPos;
                  castService.seek(current + const Duration(seconds: 10));
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Remote Volume Control Slider
          Row(
            children: [
              IconButton(
                icon: Icon(
                  castService.isMuted || castService.remoteVolume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: castService.isMuted ? EDesign.danger : EDesign.primary,
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  castService.toggleMute();
                },
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: EDesign.primary,
                    inactiveTrackColor: EDesign.surface,
                    thumbColor: EDesign.primary,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: castService.isMuted ? 0.0 : castService.remoteVolume,
                    onChanged: (val) {
                      castService.setRemoteVolume(val);
                    },
                  ),
                ),
              ),
              Text(
                '${((castService.isMuted ? 0.0 : castService.remoteVolume) * 100).round()}%',
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Audio Stream Routing Segmented Selector
          Row(
            children: [
              const Text(
                'Audio Route:',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              _buildRouteChip(
                label: 'Display Speakers',
                key: 'tv',
                current: castService.audioRoute,
                onSelected: castService.setAudioRoute,
              ),
              const SizedBox(width: 6),
              _buildRouteChip(
                label: 'This Device',
                key: 'device',
                current: castService.audioRoute,
                onSelected: castService.setAudioRoute,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Disconnect Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: EDesign.danger,
                side: const BorderSide(color: EDesign.danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                castService.disconnect();
              },
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text(
                'Disconnect & Return to Local Display',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteChip({
    required String label,
    required String key,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    final isSelected = key == current;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? EDesign.primary.withValues(alpha: 0.15) : EDesign.surface,
          borderRadius: BorderRadius.circular(EDesign.r6),
          border: Border.all(
            color: isSelected ? EDesign.primary : EDesign.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? EDesign.primary : EDesign.textSecondary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolFilters(List<CastDevice> allDevices) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All Protocols (${allDevices.length})', null),
          const SizedBox(width: 8),
          _buildFilterChip('Chromecast', CastProtocol.chromecast),
          const SizedBox(width: 8),
          _buildFilterChip('AirPlay', CastProtocol.airplay),
          const SizedBox(width: 8),
          _buildFilterChip('DLNA / UPnP', CastProtocol.dlna),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, CastProtocol? protocol) {
    final isSelected = _selectedProtocolFilter == protocol;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedProtocolFilter = protocol);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? EDesign.primary.withValues(alpha: 0.15) : EDesign.elevatedSurface,
          borderRadius: BorderRadius.circular(EDesign.r16),
          border: Border.all(
            color: isSelected ? EDesign.primary : EDesign.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? EDesign.primary : EDesign.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    CastService castService,
    CastDevice device,
  ) {
    final isConnected = device.isConnected;
    final isConnecting = device.isConnecting;
    final protocolColor = Color(device.protocol.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isConnected ? EDesign.elevatedSurface : EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r14),
        border: Border.all(
          color: isConnected ? EDesign.primary : EDesign.border,
          width: isConnected ? 1.5 : 1.0,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: EDesign.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: protocolColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(EDesign.r10),
            border: Border.all(color: protocolColor.withValues(alpha: 0.4)),
          ),
          child: device.protocol == CastProtocol.airplay
              ? Icon(Icons.airplay_rounded, color: protocolColor, size: 22)
              : device.protocol == CastProtocol.chromecast
                  ? EVectorIcon(name: 'cast', size: 22, color: protocolColor)
                  : Icon(Icons.tv_rounded, color: protocolColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.name,
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: EDesign.appBackground,
                borderRadius: BorderRadius.circular(EDesign.r6),
                border: Border.all(color: EDesign.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_rounded, size: 10, color: protocolColor),
                  const SizedBox(width: 3),
                  Text(
                    '${device.signalPercentage}%',
                    style: const TextStyle(
                      color: EDesign.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${device.protocol.label} · ${device.resolutionCapability}',
            style: EDesign.caption.copyWith(color: EDesign.textSecondary),
          ),
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(EDesign.primary),
                ),
              )
            : isConnected
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EDesign.success,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(EDesign.r8),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      castService.disconnect();
                    },
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text(
                      'Connected',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: protocolColor),
                      foregroundColor: protocolColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(EDesign.r8),
                      ),
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await castService.connect(
                        device,
                        mediaTitle: widget.mediaTitle,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: EDesign.surface,
                            content: Row(
                              children: [
                                EVectorIcon(name: 'cast', color: protocolColor, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Connected to ${device.name}. Streaming 4K.',
                                    style: const TextStyle(color: EDesign.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EDesign.r12),
                              side: BorderSide(color: protocolColor),
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Cast',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
      ),
    );
  }
}

class _TelemetryItem extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryItem({required this.label, required this.value});

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

/// CustomPainter that renders a rotating radar sweep beam with concentric ripple rings
class _RadarScopePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final bool isScanning;

  _RadarScopePainter({required this.progress, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width / 2, size.height / 2) - 4;

    // Draw 3 Concentric Ring Grids
    final ringPaint = Paint()
      ..color = const Color(0xFF19BFFF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final r = (maxRadius / 3) * i;
      canvas.drawCircle(center, r, ringPaint);
    }

    // Crosshair axes
    final axisPaint = Paint()
      ..color = const Color(0xFF19BFFF).withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), axisPaint);

    if (isScanning) {
      // Rotating Sweep Beam
      final angle = progress * 2 * math.pi;
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: math.pi / 2,
          colors: [
            const Color(0xFF19BFFF).withValues(alpha: 0.35),
            const Color(0xFF19BFFF).withValues(alpha: 0.0),
          ],
          transform: GradientRotation(angle - math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

      canvas.drawCircle(center, maxRadius, sweepPaint);

      // Bright Leading Sweep Line
      final linePaint = Paint()
        ..color = const Color(0xFF19BFFF)
        ..strokeWidth = 1.5;

      final endX = center.dx + maxRadius * math.cos(angle);
      final endY = center.dy + maxRadius * math.sin(angle);
      canvas.drawLine(center, Offset(endX, endY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarScopePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isScanning != isScanning;
  }
}
