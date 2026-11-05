import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../../../core/db/database_helper.dart';
import '../../../core/models/media_item.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../domain/library_provider.dart';
import '../../player/ui/player_screen.dart';
import '../../trash/domain/trash_service.dart';
import '../../vault/domain/vault_service.dart';
import '../../home/domain/media_group_service.dart';
import 'widgets/video_group_card.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderName;
  final List<MediaItem> items;
  final String? groupId;

  const FolderDetailScreen({
    super.key,
    required this.folderName,
    required this.items,
    this.groupId,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late List<MediaItem> _displayItems;
  bool _isGridView = true;
  String _sortBy = 'Name'; // 'Name', 'Size', 'Recent'
  String _searchQuery = '';
  GroupMode _folderGroupMode = GroupMode.none;
  final TextEditingController _searchController = TextEditingController();

  // Multi-selection state (Milestone 2 - R2 & R3)
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPaths.clear();
    });
  }

  void _togglePathSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPaths.add(path);
        _isSelectionMode = true;
      }
    });
  }

  void _toggleSelectAll(List<MediaItem> visibleItems) {
    final visiblePaths = visibleItems.map((i) => i.path).toList();
    final bool isAllSelected = visiblePaths.isNotEmpty && _selectedPaths.length >= visiblePaths.length;
    setState(() {
      if (isAllSelected) {
        _selectedPaths.clear();
        _isSelectionMode = false;
      } else {
        _selectedPaths.addAll(visiblePaths);
        _isSelectionMode = true;
      }
    });
  }

  void _confirmDeleteSelected(
    BuildContext context,
    MediaGroupService? groupService,
    LibraryProvider provider,
  ) {
    final count = _selectedPaths.length;
    final isGroup = widget.groupId != null;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EDesign.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r18),
          side: const BorderSide(color: EDesign.border),
        ),
        title: Text(isGroup ? 'Remove from Group?' : 'Delete Selected Items?', style: EDesign.h3),
        content: Text(
          isGroup
              ? 'Remove $count selected item(s) from this group?'
              : 'Permanently delete $count selected item(s) from your media library?',
          style: EDesign.secondaryStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EDesign.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final toDelete = _selectedPaths.toList();
              if (isGroup && groupService != null) {
                await groupService.removeItemsFromGroup(widget.groupId!, toDelete);
              } else {
                await DatabaseHelper.instance.deleteBatch(toDelete);
                await provider.refreshLibrary();
              }
              if (mounted) {
                setState(() {
                  _displayItems.removeWhere((i) => toDelete.contains(i.path));
                });
              }
              if (dialogCtx.mounted) {
                _exitSelectionMode();
                Navigator.pop(dialogCtx);
              }
            },
            child: Text(isGroup ? 'Remove' : 'Delete'),
          ),
        ],
      ),
    );
  }

  void _showMoveToGroupDialog(
    BuildContext context,
    MediaGroupService? groupService,
  ) {
    final availableGroups = (groupService?.groups ?? [])
        .where((g) => widget.groupId == null || g.id != widget.groupId)
        .toList();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EDesign.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r18),
          side: const BorderSide(color: EDesign.border),
        ),
        title: const Text('Move to Group', style: EDesign.h3),
        content: SizedBox(
          width: double.maxFinite,
          child: availableGroups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No custom groups available. Create a group from Home first.',
                    style: EDesign.secondaryStyle,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableGroups.length,
                  itemBuilder: (ctx, idx) {
                    final targetGroup = availableGroups[idx];
                    return ListTile(
                      leading: Icon(Icons.folder, color: targetGroup.color),
                      title: Text(targetGroup.title, style: EDesign.body),
                      subtitle: Text('${targetGroup.itemPaths.length} items', style: EDesign.caption),
                      onTap: () async {
                        final pathsToMove = _selectedPaths.toList();
                        if (widget.groupId != null) {
                          await groupService?.moveItemsBetweenGroups(
                            fromGroupId: widget.groupId!,
                            toGroupId: targetGroup.id,
                            paths: pathsToMove,
                          );
                          if (mounted) {
                            setState(() {
                              _displayItems.removeWhere((i) => pathsToMove.contains(i.path));
                            });
                          }
                        } else {
                          await groupService?.addItemsToGroup(targetGroup.id, pathsToMove);
                        }
                        if (dialogCtx.mounted) {
                          _exitSelectionMode();
                          Navigator.pop(dialogCtx);
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    List<MediaItem> visibleItems,
    MediaGroupService? groupService,
    LibraryProvider provider,
  ) {
    final bool isAllSelected = visibleItems.isNotEmpty && _selectedPaths.length >= visibleItems.length;

    return AppBar(
      backgroundColor: EDesign.surface,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.close, color: EDesign.textPrimary),
        tooltip: 'Exit Selection',
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedPaths.length} Selected',
        style: EDesign.h2,
      ),
      centerTitle: false,
      actions: [
        TextButton(
          onPressed: () => _toggleSelectAll(visibleItems),
          child: Text(
            isAllSelected ? 'None' : 'Select All',
            style: const TextStyle(color: EDesign.primary, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move, color: EDesign.primary),
          tooltip: 'Move to Group',
          onPressed: () => _showMoveToGroupDialog(context, groupService),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: EDesign.danger),
          tooltip: 'Delete Selected',
          onPressed: () => _confirmDeleteSelected(context, groupService, provider),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

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

  bool get _isGroup =>
      widget.groupId != null ||
      widget.folderName.toLowerCase().contains('group');

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    MediaGroupService? groupService;
    try {
      groupService = context.watch<MediaGroupService>();
    } catch (_) {}

    List<MediaItem> currentItems;
    if (widget.groupId != null && groupService != null) {
      final group = groupService.groups.cast<MediaGroup?>().firstWhere(
            (g) => g?.id == widget.groupId,
            orElse: () => null,
          );
      if (group != null) {
        final knownItemsMap = {for (var item in libraryProvider.allFiles) item.path: item};
        currentItems = [];
        for (final path in group.itemPaths) {
          if (knownItemsMap.containsKey(path)) {
            currentItems.add(knownItemsMap[path]!);
          } else {
            int size = 0;
            try {
              final f = File(path);
              if (f.existsSync()) size = f.lengthSync();
            } catch (_) {}
            currentItems.add(
              MediaItem(
                path: path,
                name: p.basename(path),
                parentFolder: p.dirname(path),
                sizeBytes: size,
                durationMs: 0,
                lastPositionMs: 0,
                lastPlayed: DateTime.now(),
              ),
            );
          }
        }
      } else {
        currentItems = _displayItems;
      }
    } else {
      currentItems = _displayItems;
    }

    final sortedItems = List<MediaItem>.from(currentItems);
    if (_sortBy == 'Name') {
      sortedItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == 'Size') {
      sortedItems.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    } else if (_sortBy == 'Recent') {
      sortedItems.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    }

    final filtered = sortedItems
        .where((i) =>
            _searchQuery.isEmpty ||
            i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    final totalSize = filtered.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: EDesign.appBackground,
        appBar: _isSelectionMode
            ? _buildSelectionAppBar(context, filtered, groupService, libraryProvider)
            : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          p.basename(widget.folderName),
          style: EDesign.h2,
        ),
        actions: [
          if (_isGroup)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: EDesign.primary),
              tooltip: 'Add Media / Folders',
              onPressed: () => _showAddMediaModal(context),
            ),
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
          PopupMenuButton<GroupMode>(
            icon: Icon(
              _folderGroupMode == GroupMode.byFolder
                  ? Icons.folder_copy_rounded
                  : _folderGroupMode == GroupMode.byName
                      ? Icons.auto_awesome_motion_rounded
                      : Icons.workspaces_outlined,
              color: _folderGroupMode != GroupMode.none ? EDesign.primary : EDesign.textSecondary,
              size: 20,
            ),
            tooltip: 'Group Media (${_folderGroupMode.label})',
            color: EDesign.elevatedSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EDesign.r14),
              side: const BorderSide(color: EDesign.border),
            ),
            onSelected: (mode) => setState(() => _folderGroupMode = mode),
            itemBuilder: (context) => [
              for (final mode in GroupMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(
                        mode.icon,
                        color: mode == _folderGroupMode ? EDesign.primary : EDesign.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        mode.label,
                        style: TextStyle(
                          color: mode == _folderGroupMode ? EDesign.primary : EDesign.textPrimary,
                          fontWeight: mode == _folderGroupMode ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (mode == _folderGroupMode) ...[
                        const Spacer(),
                        const Icon(Icons.check, color: EDesign.primary, size: 16),
                      ],
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: EDesign.primary),
            tooltip: 'Refresh Folder & Prune Deleted',
            onPressed: () async {
              await libraryProvider.refreshLibrary();
              if (mounted) {
                setState(() {
                  final updated = libraryProvider.groupedFolders[widget.folderName] ?? [];
                  _displayItems = updated.where((i) {
                    try {
                      return File(i.path).existsSync();
                    } catch (_) {
                      return false;
                    }
                  }).toList();
                  _applySort();
                });
              }
            },
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

          // Media Content (Grid, List, or Grouped Hierarchy)
          Expanded(
            child: RefreshIndicator(
              color: EDesign.primary,
              backgroundColor: EDesign.elevatedSurface,
              onRefresh: () async {
                await libraryProvider.refreshLibrary();
                if (mounted) {
                  setState(() {
                    final updated = libraryProvider.groupedFolders[widget.folderName] ?? [];
                    _displayItems = updated.where((i) {
                      try {
                        return File(i.path).existsSync();
                      } catch (_) {
                        return false;
                      }
                    }).toList();
                    _applySort();
                  });
                }
              },
              child: filtered.isEmpty
                  ? (_isGroup
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: EDesign.cardDecoration(
                                  color: EDesign.elevatedSurface,
                                  radius: EDesign.r18,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: EDesign.primary.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.folder_open_rounded,
                                        color: EDesign.primary,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'This group is empty',
                                      style: TextStyle(
                                        color: EDesign.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add videos or folders to organize this group',
                                      style: EDesign.secondaryStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add_rounded, size: 20),
                                      label: const Text(
                                        'Add Media / Folders',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: EDesign.primary,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(EDesign.r14),
                                        ),
                                      ),
                                      onPressed: () => _showAddMediaModal(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          child: SizedBox(
                            height: 300,
                            child: Center(
                              child: Text(
                                'No media files found in "${p.basename(widget.folderName)}".',
                                style: EDesign.secondaryStyle,
                              ),
                            ),
                          ),
                        ))
                  : _folderGroupMode != GroupMode.none
                      ? Builder(
                          builder: (context) {
                            final groups = VideoGroupingEngine.group(filtered, _folderGroupMode);
                            if (groups.isEmpty) {
                              return Center(
                                child: Text(
                                  'No grouped media found.',
                                  style: EDesign.secondaryStyle,
                                ),
                              );
                            }
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: ListView.builder(
                                key: ValueKey('folder_grouped_${_folderGroupMode.name}_${_isGridView}_${groups.length}'),
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                itemCount: groups.length,
                                itemBuilder: (context, index) {
                                  return VideoGroupCard(
                                    key: ValueKey('folder_group_${groups[index].id}'),
                                    group: groups[index],
                                    isGridView: _isGridView,
                                  );
                                },
                              ),
                            );
                          },
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _isGridView
                              ? GridView.builder(
                                  key: const ValueKey('folder_flat_grid'),
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                                  key: const ValueKey('folder_flat_list'),
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    return _buildListCard(context, filtered[index], libraryProvider);
                                  },
                                ),
                        ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildGridCard(BuildContext context, MediaItem item, LibraryProvider provider) {
    final isSelected = _selectedPaths.contains(item.path);
    final ext = p.extension(item.path).replaceAll('.', '').toUpperCase();
    final isAudio = ['MP3', 'FLAC', 'M4A', 'WAV'].contains(ext);
    final progress = (item.durationMs > 0)
        ? (item.lastPositionMs / item.durationMs).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r14),
      onLongPress: () => _togglePathSelection(item.path),
      onTap: () {
        if (_isSelectionMode) {
          _togglePathSelection(item.path);
        } else {
          provider.addRecent(item.path);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
          );
        }
      },
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                color: EDesign.elevatedSurface,
                borderRadius: BorderRadius.circular(EDesign.r14),
                border: Border.all(color: EDesign.primary, width: 2.0),
              )
            : EDesign.cardDecoration(radius: EDesign.r14),
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
              top: 6,
              right: 6,
              child: _isSelectionMode
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? EDesign.primary : Colors.white70,
                        size: 22,
                      ),
                    )
                  : _buildItemPopupMenu(context, item, provider),
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
    final isSelected = _selectedPaths.contains(item.path);
    final ext = p.extension(item.path).replaceAll('.', '').toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: isSelected
          ? BoxDecoration(
              color: EDesign.elevatedSurface,
              borderRadius: BorderRadius.circular(EDesign.r14),
              border: Border.all(color: EDesign.primary, width: 2.0),
            )
          : EDesign.cardDecoration(radius: EDesign.r14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onLongPress: () => _togglePathSelection(item.path),
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
        trailing: _isSelectionMode
            ? Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? EDesign.primary : Colors.white70,
                size: 20,
              )
            : _buildItemPopupMenu(context, item, provider),
        onTap: () {
          if (_isSelectionMode) {
            _togglePathSelection(item.path);
          } else {
            provider.addRecent(item.path);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
            );
          }
        },
      ),
    );
  }

  Widget _buildItemPopupMenu(BuildContext context, MediaItem item, LibraryProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: EDesign.textSecondary, size: 20),
      color: EDesign.elevatedSurface,
      onSelected: (val) async {
        if (val == 'remove_group' && widget.groupId != null) {
          final groupService = context.read<MediaGroupService>();
          await groupService.removeItemFromGroup(widget.groupId!, item.path);
        } else if (val == 'vault') {
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
      itemBuilder: (context) => [
        if (widget.groupId != null)
          const PopupMenuItem(
            value: 'remove_group',
            child: Text('Remove from Group', style: TextStyle(color: EDesign.danger)),
          ),
        const PopupMenuItem(
          value: 'vault',
          child: Text('Move to Vault', style: TextStyle(color: EDesign.textPrimary)),
        ),
        const PopupMenuItem(
          value: 'trash',
          child: Text('Move to Trash', style: TextStyle(color: EDesign.danger)),
        ),
      ],
    );
  }

  void _showAddMediaModal(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    MediaGroupService? groupService;
    try {
      groupService = context.read<MediaGroupService>();
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.elevatedSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, color: EDesign.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Add to "${widget.folderName}"',
                        style: EDesign.h3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EDesign.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.video_library_rounded, color: EDesign.primary),
                  ),
                  title: const Text('Select from Media Library', style: TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Choose existing videos from your library (${libraryProvider.allFiles.length} available)', style: EDesign.caption),
                  trailing: const Icon(Icons.chevron_right_rounded, color: EDesign.textSecondary),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showSelectFromLibraryDialog(context, libraryProvider, groupService);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EDesign.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_open_rounded, color: EDesign.success),
                  ),
                  title: const Text('Pick Video Files', style: TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Browse device storage for video files', style: EDesign.caption),
                  trailing: const Icon(Icons.chevron_right_rounded, color: EDesign.textSecondary),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickAndAddVideoFiles(context, libraryProvider, groupService);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EDesign.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.create_new_folder_rounded, color: EDesign.warning),
                  ),
                  title: const Text('Add Folder', style: TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Import all media from a folder directory', style: EDesign.caption),
                  trailing: const Icon(Icons.chevron_right_rounded, color: EDesign.textSecondary),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickAndAddDirectory(context, libraryProvider, groupService);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _resolveGroupId(MediaGroupService? groupService) async {
    if (widget.groupId != null) return widget.groupId;
    if (groupService == null) return null;
    final match = groupService.groups.cast<MediaGroup?>().firstWhere(
          (g) => g?.title == widget.folderName,
          orElse: () => null,
        );
    if (match != null) return match.id;
    if (_isGroup) {
      final newGroup = await groupService.createGroup(title: widget.folderName);
      return newGroup.id;
    }
    return null;
  }

  void _showSelectFromLibraryDialog(
    BuildContext context,
    LibraryProvider libraryProvider,
    MediaGroupService? groupService,
  ) {
    if (!_isGroup) return;
    final allFiles = libraryProvider.allFiles;
    final selectedPaths = <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: EDesign.elevatedSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.video_library_rounded, color: EDesign.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Select from Library', style: TextStyle(color: EDesign.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (allFiles.isNotEmpty)
                    TextButton(
                      child: Text(
                        selectedPaths.length == allFiles.length ? 'Deselect' : 'Select All',
                        style: const TextStyle(color: EDesign.primary, fontSize: 13),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          if (selectedPaths.length == allFiles.length) {
                            selectedPaths.clear();
                          } else {
                            selectedPaths.addAll(allFiles.map((f) => f.path));
                          }
                        });
                      },
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: allFiles.isEmpty
                    ? Center(
                        child: Text(
                          'No media files found in library.',
                          style: EDesign.secondaryStyle,
                        ),
                      )
                    : ListView.builder(
                        itemCount: allFiles.length,
                        itemBuilder: (context, index) {
                          final item = allFiles[index];
                          final isSelected = selectedPaths.contains(item.path);
                          return CheckboxListTile(
                            activeColor: EDesign.primary,
                            checkColor: Colors.black,
                            value: isSelected,
                            title: Text(
                              item.name,
                              style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              EDesign.formatBytes(item.sizeBytes),
                              style: EDesign.caption,
                            ),
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedPaths.add(item.path);
                                } else {
                                  selectedPaths.remove(item.path);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: EDesign.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: selectedPaths.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          final targetGroupId = await _resolveGroupId(groupService);
                          if (groupService != null && targetGroupId != null) {
                            await groupService.addItemsToGroup(targetGroupId, selectedPaths.toList());
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added ${selectedPaths.length} items to group')),
                            );
                          }
                        },
                  child: Text('Add Selected (${selectedPaths.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndAddVideoFiles(
    BuildContext context,
    LibraryProvider libraryProvider,
    MediaGroupService? groupService,
  ) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.video,
      );
      if (files.isNotEmpty && _isGroup) {
        final paths = files
            .map((f) => f.path)
            .where((p) => p != null && p.isNotEmpty)
            .cast<String>()
            .toList();
        final targetGroupId = await _resolveGroupId(groupService);
        if (paths.isNotEmpty && groupService != null && targetGroupId != null) {
          await groupService.addItemsToGroup(targetGroupId, paths);
          for (final p in paths) {
            await libraryProvider.addRecent(p);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added ${paths.length} video(s) to group')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  Future<void> _pickAndAddDirectory(
    BuildContext context,
    LibraryProvider libraryProvider,
    MediaGroupService? groupService,
  ) async {
    try {
      final selectedDir = await FilePicker.getDirectoryPath();
      if (selectedDir != null && selectedDir.isNotEmpty && _isGroup) {
        final dir = Directory(selectedDir);
        final videoPaths = <String>[];
        if (await dir.exists()) {
          try {
            final entities = dir.listSync(recursive: true, followLinks: false);
            for (final entity in entities) {
              if (entity is File) {
                final ext = p.extension(entity.path).toLowerCase();
                if (['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.wmv', '.m4v', '.3gp', '.ts'].contains(ext)) {
                  videoPaths.add(entity.path);
                }
              }
            }
          } catch (_) {}
        }

        final targetGroupId = await _resolveGroupId(groupService);
        if (videoPaths.isNotEmpty && groupService != null && targetGroupId != null) {
          await groupService.addItemsToGroup(targetGroupId, videoPaths);
          await libraryProvider.scanDirectory(selectedDir);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added ${videoPaths.length} video(s) from folder')),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No videos found in selected folder')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding folder: $e')),
        );
      }
    }
  }
}
