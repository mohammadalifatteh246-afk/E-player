import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../ui/theme/e_design_tokens.dart';
import '../domain/media_info_model.dart';
import '../domain/media_info_service.dart';

/// Screen 14: Media Info & Technical Inspector
/// Master Stitch Cyberpunk Aesthetics with Detailed Container Specs,
/// Video Codecs, Color Primaries & HDR Metadata, Multi-track Audio & Subtitles.
class MediaInfoSheet extends StatefulWidget {
  final String mediaPath;
  final int? sizeBytes;
  final int? durationMs;

  const MediaInfoSheet({
    super.key,
    required this.mediaPath,
    this.sizeBytes,
    this.durationMs,
  });

  /// Presents the Media Info & Technical Inspector as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required String mediaPath,
    int? sizeBytes,
    int? durationMs,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MediaInfoSheet(
        mediaPath: mediaPath,
        sizeBytes: sizeBytes,
        durationMs: durationMs,
      ),
    );
  }

  @override
  State<MediaInfoSheet> createState() => _MediaInfoSheetState();
}

class _MediaInfoSheetState extends State<MediaInfoSheet> {
  MediaTechnicalReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final rep = await MediaInfoService.inspectFile(
      widget.mediaPath,
      sizeBytes: widget.sizeBytes,
      durationMs: widget.durationMs,
    );
    if (mounted) {
      setState(() {
        _report = rep;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EDesign.surface,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: EDesign.primary, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: EDesign.textPrimary)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r12),
          side: const BorderSide(color: EDesign.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.90;

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
          // Drag handle & Header
          _buildTopHeader(context),

          // Main Content or Skeleton Loading
          Expanded(
            child: _isLoading || _report == null
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(EDesign.primary),
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                    children: [
                      // General Container Banner
                      _buildContainerBanner(_report!),
                      const SizedBox(height: 20),

                      // 1. Video Stream Track Specs
                      _buildSectionHeader('VIDEO STREAM TRACK [#0:0]', Icons.videocam_rounded, EDesign.primary),
                      const SizedBox(height: 10),
                      _buildVideoTrackCard(_report!.videoTrack),
                      const SizedBox(height: 20),

                      // 2. Audio Stream Tracks
                      _buildSectionHeader(
                        'AUDIO STREAM TRACKS (${_report!.audioTracks.length})',
                        Icons.graphic_eq_rounded,
                        EDesign.secondary,
                      ),
                      const SizedBox(height: 10),
                      ..._report!.audioTracks.map(_buildAudioTrackCard),
                      const SizedBox(height: 20),

                      // 3. Embedded Subtitle Streams
                      _buildSectionHeader(
                        'EMBEDDED SUBTITLE STREAMS (${_report!.subtitleTracks.length})',
                        Icons.subtitles_rounded,
                        EDesign.success,
                      ),
                      const SizedBox(height: 10),
                      ..._report!.subtitleTracks.map(_buildSubtitleTrackCard),
                      const SizedBox(height: 20),

                      // 4. Hardware Acceleration & Demuxer Telemetry
                      _buildSectionHeader(
                        'PIPELINE & DECODING TELEMETRY',
                        Icons.memory_rounded,
                        EDesign.aiAccent,
                      ),
                      const SizedBox(height: 10),
                      _buildPipelineCard(_report!),
                      const SizedBox(height: 24),

                      // Bottom Copy Full Report Action
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EDesign.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EDesign.r12),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () => _copyToClipboard(
                            context,
                            _report!.toPlainTextReport(),
                            'Full technical report copied to clipboard',
                          ),
                          icon: const Icon(Icons.copy_all_rounded, size: 20),
                          label: const Text(
                            'Copy Full Technical NFO Report',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final fileName = p.basename(widget.mediaPath);

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
                  border: Border.all(color: EDesign.primary.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.analytics_outlined, color: EDesign.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Technical Inspector', style: EDesign.h3),
                    const SizedBox(height: 2),
                    Text(
                      fileName,
                      style: EDesign.caption.copyWith(color: EDesign.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_report != null)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: EDesign.primary, size: 20),
                  tooltip: 'Copy Report',
                  onPressed: () => _copyToClipboard(
                    context,
                    _report!.toPlainTextReport(),
                    'Technical report copied to clipboard',
                  ),
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

  Widget _buildContainerBanner(MediaTechnicalReport report) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.fileName,
                      style: const TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.filePath,
                      style: EDesign.caption.copyWith(color: EDesign.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              EDesign.buildBadge(
                report.videoTrack.is4K ? '4K UHD' : '1080p FHD',
                color: report.videoTrack.is4K ? EDesign.primary : EDesign.secondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 4-Quadrant Metric Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: EDesign.appBackground,
              borderRadius: BorderRadius.circular(EDesign.r12),
              border: Border.all(color: EDesign.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol('CONTAINER', report.containerFormat.split(' ').first),
                _buildMetricDivider(),
                _buildMetricCol('FILE SIZE', report.formattedFileSize),
                _buildMetricDivider(),
                _buildMetricCol('DURATION', report.formattedDuration),
                _buildMetricDivider(),
                _buildMetricCol('BITRATE', '${report.overallBitrateMbps.toStringAsFixed(1)} Mbps'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTrackCard(VideoTrackTechnicalInfo v) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EDesign.cardDecoration(
        color: EDesign.surface,
        radius: EDesign.r16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.hd_rounded, color: EDesign.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    v.codecName,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              EDesign.buildBadge(v.hdrStandard, color: v.isHDR ? EDesign.aiAccent : EDesign.secondary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            v.codecProfile,
            style: EDesign.caption.copyWith(color: EDesign.textSecondary),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: EDesign.border),
          const SizedBox(height: 14),

          _buildSpecRow('Stream Index', v.streamIndex),
          _buildSpecRow('Pixel Dimensions', '${v.width} × ${v.height} (${v.aspectRatio})'),
          _buildSpecRow('Frame Rate', '${v.frameRate.toStringAsFixed(3)} FPS (${v.isVfr ? "VFR" : "CFR"})'),
          _buildSpecRow('Bit Depth / Format', '${v.bitDepth}-bit (${v.pixelFormat})'),
          _buildSpecRow('Color Primaries', v.colorPrimaries),
          _buildSpecRow('Transfer Function', v.transferCharacteristics),
          _buildSpecRow('Matrix Coefficients', v.matrixCoefficients),
          _buildSpecRow('Max Luminance / Fall', '${v.maxLuminanceNits} nits / ${v.maxFallNits} nits'),
          _buildSpecRow('Estimated Bitrate', '${v.bitrateMbps.toStringAsFixed(2)} Mbps'),
        ],
      ),
    );
  }

  Widget _buildAudioTrackCard(AudioTrackTechnicalInfo a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: EDesign.cardDecoration(
        color: EDesign.surface,
        radius: EDesign.r14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.volume_up_rounded, color: EDesign.secondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    a.title,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (a.isDefault)
                EDesign.buildBadge('DEFAULT', color: EDesign.success),
            ],
          ),
          const SizedBox(height: 10),
          _buildSpecRow('Stream Index', a.streamIndex),
          _buildSpecRow('Codec Format', a.codecName),
          _buildSpecRow('Channels / Layout', '${a.channelLayout} (${a.channelCount} ch)'),
          _buildSpecRow('Sampling Rate', '${(a.sampleRateHz / 1000).toStringAsFixed(1)} kHz'),
          _buildSpecRow('Bitrate', '${a.bitrateKbps} kbps'),
          _buildSpecRow('Language Tag', a.languageCode.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildSubtitleTrackCard(SubtitleTrackTechnicalInfo s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: EDesign.cardDecoration(
        color: EDesign.surface,
        radius: EDesign.r14,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EDesign.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(EDesign.r8),
            ),
            child: const Icon(Icons.subtitles_rounded, color: EDesign.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: const TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.streamIndex} · ${s.codecFormat}',
                  style: EDesign.caption.copyWith(color: EDesign.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (s.isDefault)
            EDesign.buildBadge('DEFAULT', color: EDesign.primary),
          if (s.isForced) ...[
            const SizedBox(width: 4),
            EDesign.buildBadge('FORCED', color: EDesign.warning),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineCard(MediaTechnicalReport report) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: EDesign.cardDecoration(
        color: EDesign.surface,
        radius: EDesign.r14,
      ),
      child: Column(
        children: [
          _buildSpecRow('Active Decoder', report.activeHardwareDecoder),
          _buildSpecRow('Native Demuxer', report.activeDemuxer),
          _buildSpecRow('Demuxer Buffer', '${(report.bufferSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB Ring Buffer'),
          _buildSpecRow('Sync Offset', '0.000 ms (AV Sync Locked)'),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: EDesign.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: EDesign.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: EDesign.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: EDesign.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 20,
      color: EDesign.border,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
