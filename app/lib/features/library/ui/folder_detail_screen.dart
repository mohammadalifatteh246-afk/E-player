import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/media_item.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../domain/library_provider.dart';
import '../../player/ui/player_screen.dart';
import '../../trash/domain/trash_service.dart';
import '../../vault/domain/vault_service.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderName;
  final List<MediaItem> items;

  const FolderDetailScreen({
    super.key,
    required this.folderName,
    required this.items,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late List<MediaItem> _displayItems;
  bool _isGridView = true;
  String _sortBy = 'Name'; // 'Name', 'Size', 'Recent'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayItems = List<MediaItem>.from(widget.items);
    _applySort();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySort() {
    setState(() {
      if (_sortBy == 'Name') {
        _displayItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else if (_sortBy == 'Size') {
        _displayItems.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      } else if (_sortBy == 'Recent') {
        _displayItems.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final filtered = _displayItems
        .where((i) =>
            _searchQuery.isEmpty ||
            i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    final totalSize = filtered.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          p.basename(widget.folderName),
          style: EDesign.h2,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: EDesign.textPrimary),
            tooltip: 'Sort Media',
            color: EDesign.elevatedSurface,
            onSelected: (val) {
              _sortBy = val;
              _applySort();
            },
            itemBuilder: (context) => [
              for (final opt in ['Name', 'Size', 'Recent'])
                PopupMenuItem(
                  value: opt,
                  child: Row(
                    children: [
                      Icon(
                        _sortBy == opt ? Icons.check : Icons.sort,
                        color: _sortBy == opt ? EDesign.primary : EDesign.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text('Sort by $opt', style: EDesign.body),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: EDesign.primary,
            ),
            tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Folder Summary Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: EDesign.cardDecoration(
                color: EDesign.elevatedSurface,
                radius: EDesign.r18,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EDesign.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(EDesign.r14),
                    ),
                    child: const Icon(Icons.folder_open_rounded, color: EDesign.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.basename(widget.folderName),
                          style: EDesign.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filtered.length} media files · ${EDesign.formatBytes(totalSize)} · Sorted by $_sortBy',
                          style: EDesign.secondaryStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Filter Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: EDesign.cardDecoration(radius: EDesign.r10),
              child: TextField(
                controller: _searchController,
                style: EDesign.body,
                decoration: InputDecoration(
                  hintText: 'Filter files in folder...',
                  hintStyle: const TextStyle(color: EDesign.textMuted),
                  prefixIcon: const Icon(Icons.search, color: EDesign.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: EDesign.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Media Content (Grid or List)
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No media files found in "${p.basename(widget.folderName)}".',
                      style: EDesign.secondaryStyle,
                    ),
                  )
                : _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.45,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildGridCard(context, filtered[index], libraryProvider);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildListCard(context, filtered[index], libraryProvider);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, MediaItem item, LibraryProvider provider) {
    final ext = p.extension(item.path).replaceAll('.', '').toUpperCase();
    final isAudio = ['MP3', 'FLAC', 'M4A', 'WAV'].contains(ext);
    final progress = (item.durationMs > 0)
        ? (item.lastPositionMs / item.durationMs).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r14),
      onTap: () {
        provider.addRecent(item.path);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
        );
      },
      child: Container(
        decoration: EDesign.cardDecoration(radius: EDesign.r14),
        child: Stack(
          children: [
            Center(
              child: Icon(
                isAudio ? Icons.music_note_rounded : Icons.play_circle_fill_rounded,
                size: 46,
                color: EDesign.primary.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: EDesign.buildBadge(
                ext.isEmpty ? 'MEDIA' : ext,
                color: isAudio ? EDesign.secondary : EDesign.primary,
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: _buildItemPopupMenu(context, item, provider),
            ),
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    EDesign.formatBytes(item.sizeBytes),
                    style: EDesign.caption,
                  ),
                  if (progress > 0) ...[
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.white12,
                      color: EDesign.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context, MediaItem item, LibraryProvider provider) {
    final ext = p.extension(item.path).replaceAll('.', '').toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: EDesign.cardDecoration(radius: EDesign.r14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: EDesign.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(EDesign.r10),
          ),
          child: const Icon(Icons.play_arrow_rounded, color: EDesign.primary),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            color: EDesign.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              EDesign.buildBadge(ext.isEmpty ? 'VIDEO' : ext, color: EDesign.primary),
              const SizedBox(width: 8),
              Text(EDesign.formatBytes(item.sizeBytes), style: EDesign.caption),
            ],
          ),
        ),
        trailing: _buildItemPopupMenu(context, item, provider),
        onTap: () {
          provider.addRecent(item.path);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
          );
        },
      ),
    );
  }

  Widget _buildItemPopupMenu(BuildContext context, MediaItem item, LibraryProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: EDesign.textSecondary, size: 20),
      color: EDesign.elevatedSurface,
      onSelected: (val) async {
        if (val == 'vault') {
          final vaultService = context.read<VaultService>();
          if (!vaultService.isUnlocked) {
            final unlocked = await vaultService.authenticate(context);
            if (!unlocked) return;
          }
          await vaultService.moveToVault(item);
          await provider.removeItemFromLibrary(item.path);
          setState(() => _displayItems.removeWhere((i) => i.path == item.path));
        } else if (val == 'trash') {
          final trashService = context.read<TrashService>();
          await trashService.moveToTrash(item);
          await provider.removeItemFromLibrary(item.path);
          setState(() => _displayItems.removeWhere((i) => i.path == item.path));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'vault',
          child: Text('Move to Vault', style: TextStyle(color: EDesign.textPrimary)),
        ),
        PopupMenuItem(
          value: 'trash',
          child: Text('Move to Trash', style: TextStyle(color: EDesign.danger)),
        ),
      ],
    );
  }
}
