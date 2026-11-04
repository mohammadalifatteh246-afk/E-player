import 'package:flutter/material.dart';
import '../../../../core/models/media_library_models.dart';
import '../../../../theme/e_player_colors.dart';

/// Interactive list tile displaying folders and media files in the file browser.
class FolderListTile extends StatelessWidget {
  final FileSystemNode node;
  final bool isMonitored;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleMonitor;
  final VoidCallback? onInfoTap;

  const FolderListTile({
    super.key,
    required this.node,
    this.isMonitored = false,
    required this.onTap,
    this.onLongPress,
    this.onToggleMonitor,
    this.onInfoTap,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  IconData _getIcon() {
    switch (node.type) {
      case FileNodeType.drive:
        return Icons.storage_rounded;
      case FileNodeType.directory:
        return Icons.folder_rounded;
      case FileNodeType.videoFile:
        return Icons.movie_outlined;
      case FileNodeType.audioFile:
        return Icons.music_note_outlined;
      case FileNodeType.subtitleFile:
        return Icons.subtitles_outlined;
      case FileNodeType.otherFile:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getIconColor() {
    switch (node.type) {
      case FileNodeType.drive:
        return EPlayerColors.primary;
      case FileNodeType.directory:
        return EPlayerColors.warning;
      case FileNodeType.videoFile:
        return EPlayerColors.info;
      case FileNodeType.audioFile:
        return EPlayerColors.purple;
      case FileNodeType.subtitleFile:
        return EPlayerColors.success;
      case FileNodeType.otherFile:
        return EPlayerColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleText = node.isDirectory
        ? (node.childMediaCount > 0 ? '${node.childMediaCount} media items' : 'Folder')
        : _formatBytes(node.sizeBytes);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _getIconColor().withValues(alpha: .15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getIcon(), color: _getIconColor(), size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              node.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: EPlayerColors.textPrimary,
              ),
            ),
          ),
          if (node.isHidden) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: EPlayerColors.danger.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '.nomedia',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: EPlayerColors.danger,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitleText,
        style: const TextStyle(fontSize: 12, color: EPlayerColors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.isDirectory && onToggleMonitor != null)
            IconButton(
              icon: Icon(
                isMonitored ? Icons.folder_special : Icons.create_new_folder_outlined,
                color: isMonitored ? EPlayerColors.primary : EPlayerColors.textMuted,
                size: 20,
              ),
              tooltip: isMonitored ? 'Monitored in Library' : 'Add to Library',
              onPressed: onToggleMonitor,
            ),
          if (node.isMedia && onInfoTap != null)
            IconButton(
              icon: const Icon(
                Icons.info_outline_rounded,
                color: EPlayerColors.textMuted,
                size: 20,
              ),
              tooltip: 'Media Details',
              onPressed: onInfoTap,
            ),
          if (node.isDirectory)
            const Icon(
              Icons.chevron_right,
              color: EPlayerColors.textDisabled,
              size: 18,
            ),
        ],
      ),
    );
  }
}
