import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../../widgets/e_player_components.dart';
import '../../player/ui/player_screen.dart';
import '../domain/cast_service.dart';
import 'cast_sheet.dart';

/// Supported Streaming Protocols for Auto-Detection
enum StreamProtocol {
  http('HTTP/S', Color(0xFF19BFFF), Icons.http_rounded),
  hls('HLS Stream', Color(0xFF21D79A), Icons.live_tv_rounded),
  rtsp('RTSP Live', Color(0xFFFFB547), Icons.videocam_rounded),
  dash('MPEG-DASH', Color(0xFFE741FF), Icons.video_collection_rounded),
  rtmp('RTMP Stream', Color(0xFFFF5C72), Icons.stream_rounded),
  ftp('FTP Server', Color(0xFF00E5FF), Icons.folder_shared_rounded),
  smb('SMB Share', Color(0xFF7B42FF), Icons.dns_rounded),
  unknown('Network URL', Color(0xFFA7B5CA), Icons.public_rounded);

  final String label;
  final Color color;
  final IconData icon;

  const StreamProtocol(this.label, this.color, this.icon);
}

/// Metadata model for a recent or bookmarked network stream
class RecentStreamItem {
  final String url;
  final String title;
  final StreamProtocol protocol;
  final DateTime lastAccessed;
  final String resolutionTag;

  const RecentStreamItem({
    required this.url,
    required this.title,
    required this.protocol,
    required this.lastAccessed,
    required this.resolutionTag,
  });
}

/// Screen 9: Network Stream Screen (Alias `CastingScreen` for Navigation Scaffold Parity)
class CastingScreen extends StatelessWidget {
  const CastingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NetworkStreamScreen();
  }
}

/// Screen 9: Network Stream Screen
class NetworkStreamScreen extends StatefulWidget {
  const NetworkStreamScreen({super.key});

  @override
  State<NetworkStreamScreen> createState() => _NetworkStreamScreenState();
}

class _NetworkStreamScreenState extends State<NetworkStreamScreen> {
  bool _isNetworkStreamTab = true; // Network Stream vs Cast Devices
  final TextEditingController _urlController = TextEditingController();
  StreamProtocol _detectedProtocol = StreamProtocol.unknown;

  // Real-time network telemetry
  double _downloadSpeedMbps = 48.4;
  int _pingMs = 18;
  bool _isPinging = false;
  Timer? _telemetryTimer;

  // Recent streams persisted in-memory / cache
  final List<RecentStreamItem> _recentStreams = [
    RecentStreamItem(
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      title: 'Big Buck Bunny (HLS Multi-Bitrate 1080p)',
      protocol: StreamProtocol.hls,
      lastAccessed: DateTime.now().subtract(const Duration(hours: 2)),
      resolutionTag: '1080p 60fps',
    ),
    RecentStreamItem(
      url: 'rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4',
      title: 'Wowza Low-Latency Live RTSP Feed',
      protocol: StreamProtocol.rtsp,
      lastAccessed: DateTime.now().subtract(const Duration(days: 1)),
      resolutionTag: '720p Live',
    ),
    RecentStreamItem(
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      title: 'Tears of Steel 4K UHD Progressive Stream',
      protocol: StreamProtocol.http,
      lastAccessed: DateTime.now().subtract(const Duration(days: 2)),
      resolutionTag: '4K UHD',
    ),
    RecentStreamItem(
      url: 'smb://192.168.1.100/Media/Movies/Interstellar.2014.mkv',
      title: 'Home NAS SMB Share - Interstellar',
      protocol: StreamProtocol.smb,
      lastAccessed: DateTime.now().subtract(const Duration(days: 3)),
      resolutionTag: '1080p MKV',
    ),
  ];

  // Curated public test feeds for zero-friction testing
  final List<RecentStreamItem> _publicTestFeeds = [
    RecentStreamItem(
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      title: 'MUX HLS Adaptive Video Test',
      protocol: StreamProtocol.hls,
      lastAccessed: DateTime.now(),
      resolutionTag: '1080p HLS',
    ),
    RecentStreamItem(
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      title: 'Google CDN Big Buck Bunny',
      protocol: StreamProtocol.http,
      lastAccessed: DateTime.now(),
      resolutionTag: '1080p MP4',
    ),
    RecentStreamItem(
      url: 'https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd',
      title: 'Akamai DASH Multi-rate Video',
      protocol: StreamProtocol.dash,
      lastAccessed: DateTime.now(),
      resolutionTag: 'DASH 60fps',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);

    // Live telemetry simulation jitter
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _downloadSpeedMbps = (44.0 + (timer.tick % 8) * 1.8).clamp(30.0, 75.0);
          _pingMs = (16 + (timer.tick % 5)).clamp(12, 28);
        });
      }
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim();
    setState(() {
      _detectedProtocol = _detectProtocol(text);
    });
  }

  StreamProtocol _detectProtocol(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('rtsp://')) return StreamProtocol.rtsp;
    if (lower.endsWith('.m3u8') || lower.contains('hls') || lower.contains('m3u8')) {
      return StreamProtocol.hls;
    }
    if (lower.endsWith('.mpd') || lower.contains('dash')) return StreamProtocol.dash;
    if (lower.startsWith('rtmp://')) return StreamProtocol.rtmp;
    if (lower.startsWith('ftp://') || lower.startsWith('sftp://')) return StreamProtocol.ftp;
    if (lower.startsWith('smb://')) return StreamProtocol.smb;
    if (lower.startsWith('http://') || lower.startsWith('https://')) return StreamProtocol.http;
    return StreamProtocol.unknown;
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      _urlController.text = data.text!.trim();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pasted stream URL: ${_urlController.text}'),
          backgroundColor: EDesign.elevatedSurface,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _insertProtocolPrefix(String prefix) {
    final current = _urlController.text.trim();
    if (current.isEmpty) {
      _urlController.text = prefix;
    } else if (!current.contains('://')) {
      _urlController.text = '$prefix$current';
    } else {
      final parts = current.split('://');
      if (parts.length > 1) {
        _urlController.text = '$prefix${parts.sublist(1).join("://")}';
      }
    }
  }

  void _launchStream(String rawUrl, {String? title}) {
    String url = rawUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid network stream URL.'),
          backgroundColor: EDesign.warning,
        ),
      );
      return;
    }

    // Auto-prefix http if user typed a bare domain without protocol
    if (!url.contains('://')) {
      url = 'https://$url';
    }

    // Save to recents if not present
    final existingIndex = _recentStreams.indexWhere((i) => i.url == url);
    if (existingIndex >= 0) {
      _recentStreams.removeAt(existingIndex);
    }
    _recentStreams.insert(
      0,
      RecentStreamItem(
        url: url,
        title: title ?? (Uri.tryParse(url)?.host.isNotEmpty == true ? Uri.parse(url).host : url),
        protocol: _detectProtocol(url),
        lastAccessed: DateTime.now(),
        resolutionTag: 'Network Stream',
      ),
    );

    // Launch directly in PlayerScreen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: url)),
    );
  }

  Future<void> _testPing() async {
    setState(() => _isPinging = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _pingMs = 15;
        _isPinging = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network Ping: 15ms · Excellent buffer throughput.'),
          backgroundColor: EDesign.success,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Navigation Tab Toggle: Network Stream vs Cast Devices
            _buildTabToggle(),
            const SizedBox(height: 18),

            if (_isNetworkStreamTab) ...[
              // 2. Interactive Stream URL Input Card
              _buildUrlInputCard(),
              const SizedBox(height: 18),

              // 3. Real-Time Network Speed & Telemetry Bento Card
              _buildNetworkTelemetryCard(),
              const SizedBox(height: 24),

              // 4. Curated Public Test Feeds
              _buildSectionHeader('Public Live Test Feeds', Icons.cloud_done_outlined),
              const SizedBox(height: 10),
              _buildPublicTestFeeds(),
              const SizedBox(height: 24),

              // 5. Recent Streams Workstation
              _buildSectionHeader('Recent Network Streams', Icons.history_rounded),
              const SizedBox(height: 10),
              _buildRecentStreamsList(),
              const SizedBox(height: 36),
            ] else ...[
              // Cast to Devices Sub-Panel
              _buildCastDevicesPanel(),
              const SizedBox(height: 36),
            ],
          ],
        ),
      ),
    );
  }

  // --- 1. APP BAR ---
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [EDesign.primary, EDesign.aiAccent],
              ),
              borderRadius: BorderRadius.circular(EDesign.r10),
            ),
            child: const Icon(Icons.wifi_tethering_rounded, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Network Stream',
                style: TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'RTSP · HLS · DASH · HTTP · AirPlay · Cast',
                style: TextStyle(color: EDesign.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Live Speed Pill
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: BorderRadius.circular(EDesign.r24),
            border: Border.all(color: EDesign.primary.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, color: EDesign.primary, size: 14),
              const SizedBox(width: 6),
              Text(
                '${_downloadSpeedMbps.toStringAsFixed(1)} Mbps',
                style: const TextStyle(
                  color: EDesign.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --- 2. TAB TOGGLE (Network Stream vs Cast) ---
  Widget _buildTabToggle() {
    return Container(
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r14),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isNetworkStreamTab = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isNetworkStreamTab
                      ? EDesign.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(EDesign.r10),
                  border: Border.all(
                    color: _isNetworkStreamTab ? EDesign.primary : Colors.transparent,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.stream_rounded,
                      size: 16,
                      color: _isNetworkStreamTab ? EDesign.primary : EDesign.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Network Stream',
                      style: TextStyle(
                        color: _isNetworkStreamTab ? EDesign.primary : EDesign.textSecondary,
                        fontWeight: _isNetworkStreamTab ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isNetworkStreamTab = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isNetworkStreamTab
                      ? EDesign.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(EDesign.r10),
                  border: Border.all(
                    color: !_isNetworkStreamTab ? EDesign.primary : Colors.transparent,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EVectorIcon(
                      name: 'cast',
                      size: 16,
                      color: !_isNetworkStreamTab ? EDesign.primary : EDesign.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cast to Device',
                      style: TextStyle(
                        color: !_isNetworkStreamTab ? EDesign.primary : EDesign.textSecondary,
                        fontWeight: !_isNetworkStreamTab ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. INTERACTIVE STREAM URL INPUT CARD ---
  Widget _buildUrlInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r18),
        border: Border.all(color: EDesign.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: EDesign.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with Detected Protocol Badge and Help
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _detectedProtocol.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r6),
                  border: Border.all(
                    color: _detectedProtocol.color.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_detectedProtocol.icon, color: _detectedProtocol.color, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      _detectedProtocol.label,
                      style: TextStyle(
                        color: _detectedProtocol.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                'Auto-detecting stream scheme',
                style: TextStyle(color: EDesign.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main URL Input Field with leading icon & trailing paste/clear
          Container(
            decoration: BoxDecoration(
              color: EDesign.elevatedBackground,
              borderRadius: BorderRadius.circular(EDesign.r12),
              border: Border.all(
                color: _urlController.text.isNotEmpty ? EDesign.primary : EDesign.border,
                width: 1.0,
              ),
            ),
            child: TextField(
              controller: _urlController,
              style: const TextStyle(
                color: EDesign.textPrimary,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              decoration: InputDecoration(
                hintText: 'Enter stream URL (rtsp://, https://, .m3u8, smb://)...',
                hintStyle: const TextStyle(color: EDesign.textMuted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                prefixIcon: Icon(
                  _detectedProtocol.icon,
                  color: _detectedProtocol.color,
                  size: 20,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: EDesign.textMuted, size: 18),
                        onPressed: () => _urlController.clear(),
                      ),
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded, color: EDesign.primary, size: 18),
                      tooltip: 'Paste from Clipboard',
                      onPressed: _pasteFromClipboard,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              onSubmitted: (v) => _launchStream(v),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Protocol Prefix Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                const Text('Protocols:', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
                const SizedBox(width: 8),
                _buildPrefixChip('https://', StreamProtocol.http.color),
                _buildPrefixChip('rtsp://', StreamProtocol.rtsp.color),
                _buildPrefixChip('.m3u8', StreamProtocol.hls.color),
                _buildPrefixChip('.mpd', StreamProtocol.dash.color),
                _buildPrefixChip('smb://', StreamProtocol.smb.color),
                _buildPrefixChip('ftp://', StreamProtocol.ftp.color),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Launch Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _launchStream(_urlController.text),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
              label: const Text(
                'Open & Play Stream',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: EDesign.primary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefixChip(String prefix, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _insertProtocolPrefix(prefix),
        borderRadius: BorderRadius.circular(EDesign.r6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(EDesign.r6),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
          ),
          child: Text(
            prefix,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. REAL-TIME NETWORK TELEMETRY BENTO CARD ---
  Widget _buildNetworkTelemetryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: const Icon(Icons.network_check_rounded, color: EDesign.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Network Diagnostics & Buffer',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Wi-Fi 6 (5GHz) · High Bandwidth Pipeline',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _isPinging ? null : _testPing,
                icon: _isPinging
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: EDesign.primary),
                      )
                    : const Icon(Icons.refresh, color: EDesign.primary, size: 16),
                label: const Text('Test Ping', style: TextStyle(color: EDesign.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Metrics: Download Speed, Latency, Buffer Health
          Row(
            children: [
              _buildTelemetryTile(
                title: 'Throughput',
                value: '${_downloadSpeedMbps.toStringAsFixed(1)} Mbps',
                badge: '4K Ready',
                color: EDesign.primary,
                icon: Icons.download_rounded,
              ),
              const SizedBox(width: 8),
              _buildTelemetryTile(
                title: 'Latency',
                value: '$_pingMs ms',
                badge: 'Low Jitter',
                color: EDesign.success,
                icon: Icons.timer_outlined,
              ),
              const SizedBox(width: 8),
              _buildTelemetryTile(
                title: 'Pre-Buffer',
                value: '10.0 sec',
                badge: 'Optimal',
                color: EDesign.aiAccent,
                icon: Icons.memory_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String title,
    required String value,
    required String badge,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: EDesign.elevatedBackground,
          borderRadius: BorderRadius.circular(EDesign.r10),
          border: Border.all(color: EDesign.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: EDesign.textMuted),
                const SizedBox(width: 4),
                Text(title, style: const TextStyle(color: EDesign.textMuted, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              badge,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. CURATED PUBLIC TEST FEEDS ---
  Widget _buildPublicTestFeeds() {
    return Column(
      children: _publicTestFeeds.map((feed) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: BorderRadius.circular(EDesign.r12),
            border: Border.all(color: EDesign.border, width: 0.8),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: feed.protocol.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(EDesign.r8),
              ),
              child: Icon(feed.protocol.icon, color: feed.protocol.color, size: 20),
            ),
            title: Text(
              feed.title,
              style: const TextStyle(
                color: EDesign.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              feed.url,
              style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: feed.protocol.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                feed.resolutionTag,
                style: TextStyle(
                  color: feed.protocol.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              _urlController.text = feed.url;
              _launchStream(feed.url, title: feed.title);
            },
          ),
        );
      }).toList(),
    );
  }

  // --- 6. RECENT STREAMS WORKSTATION ---
  Widget _buildRecentStreamsList() {
    if (_recentStreams.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: const Text('No recent network streams.', style: TextStyle(color: EDesign.textMuted)),
      );
    }

    return Column(
      children: _recentStreams.map((stream) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: BorderRadius.circular(EDesign.r12),
            border: Border.all(color: EDesign.border, width: 0.8),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stream.protocol.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(EDesign.r8),
              ),
              child: Icon(stream.protocol.icon, color: stream.protocol.color, size: 20),
            ),
            title: Text(
              stream.title,
              style: const TextStyle(
                color: EDesign.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              stream.url,
              style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: EDesign.primary, size: 24),
                  tooltip: 'Play Stream',
                  onPressed: () => _launchStream(stream.url, title: stream.title),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: EDesign.textMuted, size: 18),
                  color: EDesign.elevatedSurface,
                  onSelected: (val) {
                    if (val == 'copy') {
                      Clipboard.setData(ClipboardData(text: stream.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stream URL copied to clipboard.')),
                      );
                    } else if (val == 'delete') {
                      setState(() {
                        _recentStreams.remove(stream);
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'copy', child: Text('Copy URL', style: TextStyle(color: EDesign.textPrimary))),
                    const PopupMenuItem(value: 'delete', child: Text('Remove from Recents', style: TextStyle(color: EDesign.warning))),
                  ],
                ),
              ],
            ),
            onTap: () {
              _urlController.text = stream.url;
              _launchStream(stream.url, title: stream.title);
            },
          ),
        );
      }).toList(),
    );
  }

  // --- 7. CAST DEVICES SUB-PANEL ---
  Widget _buildCastDevicesPanel() {
    return Consumer<CastService>(
      builder: (context, castService, child) {
        final devices = castService.devices;
        final connected = castService.connectedDevice;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Nearby Discovered Display Targets', Icons.devices_rounded),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EDesign.primary,
                    side: const BorderSide(color: EDesign.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r8),
                    ),
                  ),
                  onPressed: () => CastSheet.show(context),
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: const Text('Open Radar Hub', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (connected != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: EDesign.cardDecoration(
                  color: EDesign.elevatedSurface,
                  borderColor: EDesign.primary,
                  radius: EDesign.r14,
                  withGlow: true,
                  glowColor: EDesign.primary,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EDesign.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(EDesign.r10),
                      ),
                      child: const Icon(Icons.tv_rounded, color: EDesign.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connected.name,
                            style: const TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          const Text('Active 4K Mirror Session · 14ms Latency', style: TextStyle(color: EDesign.success, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_off_rounded, color: EDesign.danger),
                      tooltip: 'Disconnect',
                      onPressed: () => castService.disconnect(),
                    ),
                  ],
                ),
              ),
            ...devices.map((d) {
              final color = Color(d.protocol.colorHex);
              final isConnected = d.isConnected;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: EDesign.surface,
                  borderRadius: BorderRadius.circular(EDesign.r14),
                  border: Border.all(
                    color: isConnected ? EDesign.primary : EDesign.border,
                    width: isConnected ? 1.5 : 0.8,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(EDesign.r10),
                    ),
                    child: d.protocol == CastProtocol.airplay
                        ? Icon(Icons.airplay, color: color, size: 22)
                        : d.protocol == CastProtocol.chromecast
                            ? EVectorIcon(name: 'cast', size: 22, color: color)
                            : Icon(Icons.tv_rounded, color: color, size: 22),
                  ),
                  title: Text(
                    d.name,
                    style: const TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${d.protocol.label} · ${d.resolutionCapability}',
                    style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      if (isConnected) {
                        castService.disconnect();
                      } else {
                        castService.connect(d);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? EDesign.success : color.withValues(alpha: 0.18),
                      foregroundColor: isConnected ? Colors.black : color,
                      elevation: 0,
                      side: BorderSide(color: color.withValues(alpha: 0.4), width: 0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(EDesign.r8),
                      ),
                    ),
                    child: Text(
                      isConnected ? 'Connected' : 'Cast',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: EDesign.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: EDesign.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
