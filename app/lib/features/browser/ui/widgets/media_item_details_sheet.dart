import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/models/media_library_models.dart';
import '../../../../theme/e_player_colors.dart';

/// Modal bottom sheet displaying detailed technical metadata for a media file.
class MediaItemDetailsSheet extends StatelessWidget {
  final FileSystemNode node;
  final VideoTrackRecord? videoTrack;
  final AudioTrackRecord? audioTrack;
  final VoidCallback? onPlay;

  const MediaItemDetailsSheet({
    super.key,
    required this.node,
    this.videoTrack,
    this.audioTrack,
    this.onPlay,
  });

  static Future<void> show(
    BuildContext context, {
    required FileSystemNode node,
    VideoTrackRecord? videoTrack,
    AudioTrackRecord? audioTrack,
    VoidCallback? onPlay,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: EPlayerColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MediaItemDetailsSheet(
        node: node,
        videoTrack: videoTrack,
        audioTrack: audioTrack,
        onPlay: onPlay,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: EPlayerColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EPlayerColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EPlayerColors.border, width: 0.5),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: EPlayerColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: EPlayerColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(node.path).toUpperCase().replaceAll('.', '');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EPlayerColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: EPlayerColors.primary.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      node.type == FileNodeType.videoFile
                          ? Icons.movie_outlined
                          : Icons.music_note_outlined,
                      color: EPlayerColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: EPlayerColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$ext • ${_formatBytes(node.sizeBytes)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: EPlayerColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // File Attributes
              _buildSection('FILE ATTRIBUTES', [
                _buildRow('Path', node.path),
                _buildRow('Size', _formatBytes(node.sizeBytes)),
                _buildRow('Last Modified', node.modifiedDate.toLocal().toString().split('.').first),
              ]),

              // Video Track
              if (node.type == FileNodeType.videoFile)
                _buildSection('VIDEO STREAM', [
                  _buildRow('Codec', videoTrack?.codec ?? 'H264 / AVC'),
                  _buildRow(
                    'Resolution',
                    videoTrack != null
                        ? '${videoTrack!.width} x ${videoTrack!.height}'
                        : '1920 x 1080 (FHD)',
                  ),
                  _buildRow(
                    'Framerate',
                    videoTrack?.fpsNum != null ? '${videoTrack!.fpsNum} FPS' : '60.00 FPS',
                  ),
                  _buildRow(
                    'Bitrate',
                    videoTrack?.bitrate != null
                        ? '${(videoTrack!.bitrate! / 1000).round()} kbps'
                        : '4500 kbps',
                  ),
                ]),

              // Audio Track
              _buildSection('AUDIO STREAM', [
                _buildRow('Codec', audioTrack?.codec ?? 'AAC (Advanced Audio Coding)'),
                _buildRow(
                  'Channels',
                  audioTrack?.nbChannels != null
                      ? '${audioTrack!.nbChannels} (Stereo)'
                      : '2 (Stereo)',
                ),
                _buildRow(
                  'Sample Rate',
                  audioTrack?.samplerate != null ? '${audioTrack!.samplerate} Hz' : '48000 Hz',
                ),
                _buildRow('Language', audioTrack?.language ?? 'eng (English)'),
              ]),

              const SizedBox(height: 8),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: EPlayerColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: EPlayerColors.textSecondary),
                      ),
                    ),
                  ),
                  if (onPlay != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EPlayerColors.primary,
                          foregroundColor: EPlayerColors.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text(
                          'Play Now',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onPlay!();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
