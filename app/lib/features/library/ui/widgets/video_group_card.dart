import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/models/media_item.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../../../player/ui/player_screen.dart';
import '../../../media_info/ui/media_info_sheet.dart';
import '../../../vault/domain/vault_service.dart';
import '../../../trash/domain/trash_service.dart';
import '../../domain/library_provider.dart';
import 'package:provider/provider.dart';

/// Production-grade collapsible group card displaying a media collection (folder or series).
///
/// Features:
/// - 16:9 stacked poster card with multi-layer depth styling.
/// - Folder & Series mode indicator badges with frosted metadata tags.
/// - Item count, total duration, and total storage footprint.
/// - Smooth animated expand/collapse transitions revealing child items.
/// - Full interactive child cards (tap to play, technical specs sheet, context menu).
/// - Safe error handling for single-file groups and empty directories.
class VideoGroupCard extends StatefulWidget {
  final VideoGroup group;
  final bool isGridView;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const VideoGroupCard({
    super.key,
    required this.group,
    this.isGridView = true,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  @override
  State<VideoGroupCard> createState() => _VideoGroupCardState();
}

class _VideoGroupCardState extends State<VideoGroupCard> with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late bool _isChildrenMounted;
  late AnimationController _chevronController;
  late Animation<double> _chevronAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _isChildrenMounted = widget.initiallyExpanded;
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _chevronController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted && !_isExpanded && _isChildrenMounted) {
          setState(() {
            _isChildrenMounted = false;
          });
        }
      }
    });
    _chevronAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant VideoGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded &&
        widget.initiallyExpanded != _isExpanded) {
      _toggleExpansion();
    }
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _isChildrenMounted = true;
        _chevronController.forward();
      } else {
        _chevronController.reverse();
      }
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  String _formatDuration(int durationMs) {
    if (durationMs <= 0) return '00:00';
    final seconds = (durationMs / 1000).round();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  String _pickThumbnail(MediaItem item) {
    final nameLower = item.name.toLowerCase();
    final folderLower = item.parentFolder.toLowerCase();
    final ext = p.extension(item.path).replaceAll('.', '').toLowerCase();

    if (['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus'].contains(ext) ||
        nameLower.contains('music') ||
        folderLower.contains('music')) {
      return 'assets/thumbnails/demo_music.png';
    }
    if (nameLower.contains('anime') || folderLower.contains('anime')) {
      return 'assets/thumbnails/demo_anime.png';
    }
    if (nameLower.contains('nature') ||
        nameLower.contains('documentary') ||
        folderLower.contains('documentary')) {
      return 'assets/thumbnails/demo_documentary.png';
    }
    if (nameLower.contains('landscape') || nameLower.contains('outdoor')) {
      return 'assets/thumbnails/demo_landscape.png';
    }
    return 'assets/thumbnails/demo_city.png';
  }

  String _pickBadge(MediaItem item) {
    final nameLower = item.name.toLowerCase();
    final ext = p.extension(item.path).replaceAll('.', '').toUpperCase();

    if (nameLower.contains('4k') ||
        nameLower.contains('2160p') ||
        item.sizeBytes > 1024 * 1024 * 1024) {
      return '4K UHD';
    }
    if (nameLower.contains('1080p') || nameLower.contains('fhd')) {
      return '1080p';
    }
    if (nameLower.contains('720p')) {
      return '720p HD';
    }
    return ext.isEmpty ? 'VIDEO' : ext;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isFolder = group.mode == GroupMode.byFolder;
    final accentColor = isFolder ? EDesign.primary : const Color(0xFF7B42FF);
    final countLabel = group.itemCount == 1 ? '1 Video' : '${group.itemCount} Videos';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(
          color: _isExpanded ? accentColor.withValues(alpha: 0.6) : EDesign.border,
          width: _isExpanded ? 1.4 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: _isExpanded ? accentColor.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.25),
            blurRadius: _isExpanded ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header Card (Clickable to Expand / Collapse)
          InkWell(
            onTap: _toggleExpansion,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Stacked Thumbnail Visual
                  _buildStackedThumbnail(group, accentColor),
                  const SizedBox(width: 14),

                  // Group Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isFolder ? Icons.folder_rounded : Icons.auto_awesome_motion_rounded,
                                    size: 11,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isFolder ? 'FOLDER' : 'COLLECTION',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                countLabel,
                                style: const TextStyle(
                                  color: EDesign.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          group.title,
                          style: const TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Subtitle & Footprint
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.subtitle,
                                style: const TextStyle(
                                  color: EDesign.textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(group.totalDurationMs),
                              style: const TextStyle(
                                color: EDesign.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('·', style: TextStyle(color: EDesign.textMuted, fontSize: 11)),
                            const SizedBox(width: 6),
                            Text(
                              EDesign.formatBytes(group.totalSizeBytes),
                              style: const TextStyle(
                                color: EDesign.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Quick Play First Item Button
                  if (group.items.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, color: EDesign.primary, size: 28),
                      tooltip: 'Play First (${group.items.first.name})',
                      onPressed: () {
                        final provider = context.read<LibraryProvider>();
                        provider.addRecent(group.items.first.path);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(mediaPath: group.items.first.path),
                          ),
                        );
                      },
                    ),

                  // Animated Rotating Chevron Indicator
                  RotationTransition(
                    turns: _chevronAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: EDesign.elevatedSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: EDesign.border),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: EDesign.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated Collapsible Children Container with lazy offstage unmounting
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _isChildrenMounted
                ? _buildExpandedChildrenList(context, group)
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedThumbnail(VideoGroup group, Color accentColor) {
    final preview = group.previewItem;
    final thumbAsset = preview != null ? _pickThumbnail(preview) : 'assets/thumbnails/demo_city.png';

    return SizedBox(
      width: 76,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background subtle offset card for collection depth
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 66,
              height: 46,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(EDesign.r8),
                border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 0.8),
              ),
            ),
          ),
          // Foreground real poster thumbnail
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 68,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(EDesign.r8),
                border: Border.all(color: Colors.white24, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    thumbAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF0F1A2C),
                      child: const Icon(Icons.movie_outlined, color: Colors.white30, size: 20),
                    ),
                  ),
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        group.mode == GroupMode.byFolder ? Icons.folder : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedChildrenList(BuildContext context, VideoGroup group) {
    if (group.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'No videos discovered in this group.',
          style: TextStyle(color: EDesign.textMuted, fontSize: 12),
        ),
      );
    }

    final provider = context.read<LibraryProvider>();

    return Container(
      decoration: BoxDecoration(
        color: EDesign.appBackground.withValues(alpha: 0.7),
        border: const Border(top: BorderSide(color: EDesign.border, width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: EDesign.primary),
                const SizedBox(width: 6),
                Text(
                  '${group.itemCount} items in this group',
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.items.length,
            separatorBuilder: (context, index) => const Divider(color: EDesign.border, height: 8),
            itemBuilder: (context, index) {
              final item = group.items[index];
              return _buildChildItemRow(context, item, provider, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChildItemRow(
    BuildContext context,
    MediaItem item,
    LibraryProvider provider,
    int indexNumber,
  ) {
    final thumbAsset = _pickThumbnail(item);
    final badgeLabel = _pickBadge(item);
    final durationStr = _formatDuration(item.durationMs);

    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r10),
      onTap: () {
        provider.addRecent(item.path);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            // Sequence Number Tag
            SizedBox(
              width: 24,
              child: Text(
                '$indexNumber',
                style: const TextStyle(
                  color: EDesign.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),

            // Mini Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 36,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      thumbAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF0F1A2C),
                        child: const Icon(Icons.movie_creation_outlined, size: 16, color: Colors.white24),
                      ),
                    ),
                    Container(color: Colors.black26),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                        color: Colors.black87,
                        child: Text(
                          durationStr,
                          style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Item Title & Meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: EDesign.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          badgeLabel,
                          style: const TextStyle(
                            color: EDesign.primary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        EDesign.formatBytes(item.sizeBytes),
                        style: const TextStyle(color: EDesign.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions & Context Menu
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.favorite, color: EDesign.danger, size: 14),
                  ),
                _buildContextMenu(context, item, provider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenu(BuildContext context, MediaItem item, LibraryProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: EDesign.textSecondary, size: 18),
      color: EDesign.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EDesign.r12),
        side: const BorderSide(color: EDesign.border),
      ),
      onSelected: (val) async {
        if (val == 'play') {
          provider.addRecent(item.path);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
          );
        } else if (val == 'info') {
          MediaInfoSheet.show(
            context,
            mediaPath: item.path,
            sizeBytes: item.sizeBytes,
            durationMs: item.durationMs,
          );
        } else if (val == 'favorite') {
          await provider.toggleFavorite(item.path);
        } else if (val == 'vault') {
          try {
            final vaultService = context.read<VaultService>();
            if (!vaultService.isUnlocked) {
              final unlocked = await vaultService.authenticate(context);
              if (!unlocked) return;
            }
            await vaultService.moveToVault(item);
            await provider.removeItemFromLibrary(item.path);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Moved "${item.name}" to Private Vault')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        } else if (val == 'trash') {
          try {
            final trashService = context.read<TrashService>();
            await trashService.moveToTrash(item);
            await provider.removeItemFromLibrary(item.path);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Moved "${item.name}" to Trash')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'play',
          child: Row(
            children: [
              Icon(Icons.play_arrow_rounded, color: EDesign.primary, size: 18),
              SizedBox(width: 8),
              Text('Play in E-Player', style: TextStyle(color: EDesign.textPrimary)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'info',
          child: Row(
            children: [
              Icon(Icons.analytics_outlined, color: EDesign.primary, size: 18),
              SizedBox(width: 8),
              Text('Technical Specs & Info', style: TextStyle(color: EDesign.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(
                item.isFavorite ? Icons.favorite_border : Icons.favorite,
                color: EDesign.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                item.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
                style: const TextStyle(color: EDesign.textPrimary),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'vault',
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: EDesign.primary, size: 18),
              SizedBox(width: 8),
              Text('Move to Vault', style: TextStyle(color: EDesign.textPrimary)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'trash',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: EDesign.warning, size: 18),
              SizedBox(width: 8),
              Text('Move to Trash', style: TextStyle(color: EDesign.warning)),
            ],
          ),
        ),
      ],
    );
  }
}
