import 'package:flutter/material.dart';
import '../../../../core/models/media_item.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../../services/playlist_controller.dart';

/// Undocked / Detached Floating Multi-Window Playlist Panel (VLC Parity: `--pl-dock-status=0`, `Ctrl+L`).
/// Provides a draggable floating window overlay over the video surface, with real-time search,
/// track switching, queue progression, and re-docking.
class UndockedPlaylistPanelWidget extends StatefulWidget {
  final PlaylistController controller;
  final Function(MediaItem item) onSelectTrack;
  final VoidCallback onClose;
  final VoidCallback onDockToggle;
  final VoidCallback? onImportPlaylist;
  final VoidCallback? onExportPlaylist;

  const UndockedPlaylistPanelWidget({
    super.key,
    required this.controller,
    required this.onSelectTrack,
    required this.onClose,
    required this.onDockToggle,
    this.onImportPlaylist,
    this.onExportPlaylist,
  });

  @override
  State<UndockedPlaylistPanelWidget> createState() =>
      _UndockedPlaylistPanelWidgetState();
}

class _UndockedPlaylistPanelWidgetState
    extends State<UndockedPlaylistPanelWidget> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.controller.searchQuery);
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '00:00';
    final d = Duration(milliseconds: ms);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isMinimized = controller.isMinimized;
    final screenSize = MediaQuery.of(context).size;

    return Container(
      width: controller.panelSize.width,
      height: isMinimized ? 52 : controller.panelSize.height,
      decoration: BoxDecoration(
        color: EDesign.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EDesign.primaryCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Draggable Header Bar
            _buildDraggableHeader(screenSize),

            // Body (Search Bar, Controls & Track List)
            if (!isMinimized) ...[
              _buildSearchBar(),
              _buildControlBar(),
              const Divider(color: Colors.white12, height: 1),
              Expanded(child: _buildTrackList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableHeader(Size screenSize) {
    final controller = widget.controller;

    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        key: const Key('undocked_playlist_drag_handle'),
        onPanUpdate: (details) {
          controller.updatePosition(details.delta, screenSize: screenSize);
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: EDesign.elevatedSurface.withValues(alpha: 0.70),
            border: const Border(
              bottom: BorderSide(color: Colors.white12, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                color: EDesign.primaryCyan,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Playlist',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: EDesign.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${controller.items.length}',
                  key: const Key('undocked_playlist_count_badge'),
                  style: const TextStyle(
                    color: EDesign.primaryCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),

              // Re-dock Button (VLC Parity)
              IconButton(
                key: const Key('undocked_playlist_dock_toggle_button'),
                icon: const Icon(Icons.vertical_align_bottom_rounded, size: 18),
                color: EDesign.textSecondary,
                tooltip: 'Dock to player bottom',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: widget.onDockToggle,
              ),

              // Minimize / Expand Button
              IconButton(
                key: const Key('undocked_playlist_minimize_button'),
                icon: Icon(
                  controller.isMinimized
                      ? Icons.crop_square_rounded
                      : Icons.remove_rounded,
                  size: 18,
                ),
                color: EDesign.textSecondary,
                tooltip: controller.isMinimized ? 'Expand' : 'Minimize',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: controller.toggleMinimized,
              ),

              // Close Button
              IconButton(
                key: const Key('undocked_playlist_close_button'),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: EDesign.textSecondary,
                tooltip: 'Close playlist (Ctrl+L)',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        key: const Key('undocked_playlist_search_field'),
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search playlist items...',
          hintStyle: TextStyle(color: EDesign.textSecondary, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded,
              color: EDesign.primaryCyan, size: 18),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  color: EDesign.textSecondary,
                  onPressed: () {
                    _searchController.clear();
                    widget.controller.setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (val) {
          widget.controller.setSearchQuery(val);
        },
      ),
    );
  }

  Widget _buildControlBar() {
    final controller = widget.controller;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Previous Track Button
          IconButton(
            key: const Key('undocked_playlist_prev_button'),
            icon: const Icon(Icons.skip_previous_rounded, size: 20),
            color: Colors.white,
            tooltip: 'Previous track',
            onPressed: () {
              final prev = controller.getPreviousTrack();
              if (prev != null) widget.onSelectTrack(prev);
            },
          ),

          // Next Track Button
          IconButton(
            key: const Key('undocked_playlist_next_button'),
            icon: const Icon(Icons.skip_next_rounded, size: 20),
            color: Colors.white,
            tooltip: 'Next track',
            onPressed: () {
              final next = controller.getNextTrack();
              if (next != null) widget.onSelectTrack(next);
            },
          ),

          const Spacer(),

          // Import Playlist Button (VLC Parity)
          IconButton(
            key: const Key('undocked_playlist_import_button'),
            icon: const Icon(Icons.file_open_rounded, size: 18),
            color: EDesign.primaryCyan,
            tooltip: 'Import Playlist (.m3u, .m3u8, .xspf)',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onImportPlaylist,
          ),

          // Export Playlist Button (VLC Parity)
          IconButton(
            key: const Key('undocked_playlist_export_button'),
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            color: EDesign.textSecondary,
            tooltip: 'Export Playlist (.m3u8)',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onExportPlaylist,
          ),

          const SizedBox(width: 4),

          // Shuffle Button
          IconButton(
            key: const Key('undocked_playlist_shuffle_button'),
            icon: Icon(
              Icons.shuffle_rounded,
              size: 18,
              color: controller.isShuffle
                  ? EDesign.primaryCyan
                  : EDesign.textSecondary,
            ),
            tooltip: 'Shuffle playback',
            onPressed: controller.toggleShuffle,
          ),

          // Repeat Button
          IconButton(
            key: const Key('undocked_playlist_repeat_button'),
            icon: Icon(
              Icons.repeat_rounded,
              size: 18,
              color: controller.isRepeatAll
                  ? EDesign.primaryCyan
                  : EDesign.textSecondary,
            ),
            tooltip: 'Repeat playlist',
            onPressed: controller.toggleRepeat,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList() {
    final filtered = widget.controller.filteredItems;

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          widget.controller.searchQuery.isEmpty
              ? 'Playlist is empty'
              : 'No matching tracks',
          style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      key: const Key('undocked_playlist_list_view'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: filtered.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isPlaying = item.path == widget.controller.currentPlayingPath;

        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          tileColor: isPlaying
              ? EDesign.primaryCyan.withValues(alpha: 0.12)
              : Colors.transparent,
          leading: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPlaying
                  ? EDesign.primaryCyan
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: isPlaying
                ? const Icon(Icons.play_arrow_rounded,
                    color: Colors.black, size: 16)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying ? EDesign.primaryCyan : Colors.white,
              fontSize: 12,
              fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            _formatDuration(item.durationMs),
            style: TextStyle(
              color: EDesign.textSecondary,
              fontSize: 10,
            ),
          ),
          trailing: isPlaying
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: EDesign.primaryCyan.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PLAYING',
                    style: TextStyle(
                      color: EDesign.primaryCyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
          onTap: () {
            widget.controller.setCurrentPlayingPath(item.path);
            widget.onSelectTrack(item);
          },
        );
      },
    );
  }
}
