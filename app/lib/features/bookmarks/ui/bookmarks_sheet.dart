import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../data/bookmark_service.dart';

/// Modal bottom sheet allowing users to view, jump to, rename, and add chapter bookmarks.
/// Complete parity with VLC's custom bookmarks dialog and hotkey accelerator suite.
class BookmarksSheet extends StatefulWidget {
  final Player? player;
  final Duration? currentPosition;
  final void Function(Duration)? onSeek;
  final String mediaId;
  final BookmarkService bookmarkService;

  const BookmarksSheet({
    super.key,
    this.player,
    this.currentPosition,
    this.onSeek,
    required this.mediaId,
    required this.bookmarkService,
  });

  static Future<void> show(
    BuildContext context, {
    Player? player,
    Duration? currentPosition,
    void Function(Duration)? onSeek,
    required String mediaId,
    BookmarkService? bookmarkService,
  }) {
    HapticFeedback.lightImpact();
    final service = bookmarkService ?? BookmarkService.instance;
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BookmarksSheet(
        player: player,
        currentPosition: currentPosition,
        onSeek: onSeek,
        mediaId: mediaId,
        bookmarkService: service,
      ),
    );
  }

  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet> {
  late BookmarkService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.bookmarkService;
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Duration get _currentPosition =>
      widget.player?.state.position ?? widget.currentPosition ?? Duration.zero;

  void _seek(Duration position) {
    if (widget.onSeek != null) {
      widget.onSeek!(position);
    } else {
      widget.player?.seek(position);
    }
  }

  Future<void> _addNewBookmark() async {
    final currentPos = _currentPosition;
    final controller = TextEditingController(
      text: 'Bookmark at ${_formatDuration(currentPos)}',
    );

    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EDesign.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r16),
          side: const BorderSide(color: EDesign.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.bookmark_add_outlined, color: EDesign.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Bookmark',
              style: TextStyle(color: EDesign.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Bookmark Name',
            hintStyle: const TextStyle(color: EDesign.textSecondary),
            filled: true,
            fillColor: EDesign.elevatedSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EDesign.r8),
              borderSide: const BorderSide(color: EDesign.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EDesign.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (label != null && label.trim().isNotEmpty) {
      await _service.addBookmark(
        mediaId: widget.mediaId,
        position: currentPos,
        label: label.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added bookmark at ${_formatDuration(currentPos)}'),
            backgroundColor: EDesign.elevatedSurface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _renameBookmark(MediaBookmark bm) async {
    final controller = TextEditingController(text: bm.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EDesign.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r16),
          side: const BorderSide(color: EDesign.border),
        ),
        title: const Text(
          'Rename Bookmark',
          style: TextStyle(color: EDesign.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: EDesign.elevatedSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EDesign.r8),
              borderSide: const BorderSide(color: EDesign.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EDesign.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.trim().isNotEmpty) {
      await _service.renameBookmark(bm.id, newLabel.trim());
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = _service.getBookmarks(widget.mediaId);
    final currentPos = _currentPosition;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
        border: Border.all(color: EDesign.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 14),

            // Header Title Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_outline_rounded, color: EDesign.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'CHAPTERS & BOOKMARKS',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: EDesign.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(EDesign.r8),
                      border: Border.all(color: EDesign.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${bookmarks.length} Pips',
                      style: const TextStyle(
                        color: EDesign.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: EDesign.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: EDesign.border, height: 16),

            // Quick Add Bookmark Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.elevatedSurface,
                    foregroundColor: EDesign.primary,
                    side: const BorderSide(color: EDesign.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: Text(
                    'Mark Current Time (${_formatDuration(currentPos)})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _addNewBookmark,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Bookmarks List
            Flexible(
              child: bookmarks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 48,
                            color: EDesign.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Bookmarks Yet',
                            style: TextStyle(
                              color: EDesign.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add bookmarks to mark key scenes or study points. Use Ctrl+B or F1..F10 hotkeys during playback.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: EDesign.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: bookmarks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final bm = bookmarks[index];
                        final isNearby =
                            (currentPos.inMilliseconds - bm.timestampMs).abs() <= 2000;

                        return Container(
                          decoration: BoxDecoration(
                            color: isNearby
                                ? EDesign.primary.withValues(alpha: 0.12)
                                : EDesign.elevatedSurface,
                            borderRadius: BorderRadius.circular(EDesign.r12),
                            border: Border.all(
                              color: isNearby
                                  ? EDesign.primary.withValues(alpha: 0.6)
                                  : EDesign.border,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(EDesign.r8),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  bm.formattedTime,
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              title: Text(
                                bm.label,
                                style: const TextStyle(
                                  color: EDesign.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    color: EDesign.textSecondary,
                                    tooltip: 'Rename',
                                    onPressed: () => _renameBookmark(bm),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    color: Colors.redAccent,
                                    tooltip: 'Delete',
                                    onPressed: () => _service.removeBookmark(bm.id),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _seek(bm.position);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
