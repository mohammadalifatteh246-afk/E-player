import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/library_provider.dart';
import '../domain/media_search_engine.dart';
import '../../player/ui/player_screen.dart';
import '../../../core/models/media_item.dart';
import '../../../ui/theme/e_design_tokens.dart';
import 'folder_detail_screen.dart';
import '../../export/ui/export_screen.dart';
import '../../vault/ui/vault_screen.dart';
import '../../trash/ui/trash_screen.dart';
import '../../vault/domain/vault_service.dart';
import '../../trash/domain/trash_service.dart';
import 'package:path/path.dart' as p;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedChip = 'All';
  final List<String> _chips = ['All', 'Videos', 'Audio', 'Folders'];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, LibraryProvider provider) {
    // Parity with VLC Qt `searchDelayed` (250ms debounce)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      provider.setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: EDesign.appBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: EDesign.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search files, folders, formats (e.g. 1080p)...',
                      hintStyle: const TextStyle(color: EDesign.textMuted),
                      border: InputBorder.none,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: EDesign.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                provider.clearSearch();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      setState(() {});
                      _onSearchChanged(v, provider);
                    },
                  )
                : const Text(
                    'Media Library',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
            centerTitle: !_isSearching,
            actions: [
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: EDesign.textPrimary,
                ),
                tooltip: _isSearching ? 'Close Search' : 'Search Library',
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      provider.clearSearch();
                    }
                  });
                },
              ),
              // Sort menu (VLC parity)
              PopupMenuButton<SortField>(
                icon: const Icon(Icons.sort_rounded, color: EDesign.textPrimary),
                tooltip: 'Sort Options',
                color: EDesign.elevatedSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r14),
                  side: const BorderSide(color: EDesign.border),
                ),
                onSelected: (field) {
                  if (provider.searchOptions.sortField == field) {
                    provider.toggleSortOrder();
                  } else {
                    provider.setSort(field);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: SortField.name,
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_by_alpha,
                          color: provider.searchOptions.sortField == SortField.name
                              ? EDesign.primary
                              : EDesign.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text('Name (A-Z)', style: TextStyle(color: EDesign.textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortField.date,
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          color: provider.searchOptions.sortField == SortField.date
                              ? EDesign.primary
                              : EDesign.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text('Date Added / Modified', style: TextStyle(color: EDesign.textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortField.size,
                    child: Row(
                      children: [
                        Icon(
                          Icons.data_usage_rounded,
                          color: provider.searchOptions.sortField == SortField.size
                              ? EDesign.primary
                              : EDesign.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text('File Size', style: TextStyle(color: EDesign.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
              // Scan System Media (VLC libmediadirs parity)
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: EDesign.primary),
                tooltip: 'Quick Scan Media (Videos/Music/Downloads)',
                onPressed: provider.isScanning ? null : () => provider.scanSystemMediaDirectories(),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: EDesign.textPrimary),
                color: EDesign.elevatedSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r14),
                  side: const BorderSide(color: EDesign.border),
                ),
                onSelected: (val) {
                  if (val == 'vault') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VaultScreen()),
                    );
                  } else if (val == 'trash') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  } else if (val == 'export') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExportScreen()),
                    );
                  } else if (val == 'system_scan') {
                    provider.scanSystemMediaDirectories();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'system_scan',
                    child: Row(
                      children: [
                        Icon(Icons.folder_special_outlined, color: EDesign.primary, size: 20),
                        SizedBox(width: 12),
                        Text('Scan Device Media', style: TextStyle(color: EDesign.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'vault',
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: EDesign.primary, size: 20),
                        SizedBox(width: 12),
                        Text('Private Vault', style: TextStyle(color: EDesign.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'trash',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: EDesign.warning, size: 20),
                        SizedBox(width: 12),
                        Text('Trash', style: TextStyle(color: EDesign.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, color: EDesign.aiAccent, size: 20),
                        SizedBox(width: 12),
                        Text('Export Jobs', style: TextStyle(color: EDesign.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: provider.isScanning ? null : () => provider.scanSystemMediaDirectories(),
            backgroundColor: EDesign.primary,
            tooltip: 'Scan Device Media',
            child: provider.isScanning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.black),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.isScanning) _buildScanningBanner(provider),
              _buildCategoryChips(provider),
              const SizedBox(height: 16),
              Expanded(
                child: _buildMainContent(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScanningBanner(LibraryProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EDesign.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EDesign.r10),
        border: Border.all(color: EDesign.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: EDesign.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scanning media (VLC engine)...',
                  style: TextStyle(
                    color: EDesign.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  provider.scanProgress,
                  style: const TextStyle(color: EDesign.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => provider.cancelScan(),
            child: const Text('Cancel', style: TextStyle(color: EDesign.warning, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(LibraryProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _chips.map((chip) {
          final isSelected = _selectedChip == chip;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedChip = chip);
                if (chip == 'All') {
                  provider.setCategory(MediaCategory.all);
                } else if (chip == 'Videos') {
                  provider.setCategory(MediaCategory.videos);
                } else if (chip == 'Audio') {
                  provider.setCategory(MediaCategory.audio);
                } else if (chip == 'Folders') {
                  provider.setCategory(MediaCategory.folders);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? EDesign.primary.withValues(alpha: 0.15)
                      : EDesign.surface,
                  border: Border.all(
                    color: isSelected ? EDesign.primary : EDesign.border,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: isSelected ? EDesign.primary : EDesign.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainContent(LibraryProvider provider) {
    if (provider.allFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_rounded,
              size: 80,
              color: EDesign.primary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            Text(
              provider.isScanning ? provider.scanProgress : 'Your Library is Empty',
              style: EDesign.h3.copyWith(color: EDesign.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap below to scan device media (Videos, Music, Downloads).',
              style: EDesign.secondaryStyle,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.isScanning ? null : () => provider.scanSystemMediaDirectories(),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Scan Device Media'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EDesign.primary,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedChip == 'Folders') {
      final map = provider.filteredGroupedFolders;
      final filteredKeys = map.keys.toList();

      if (filteredKeys.isEmpty) {
        return const Center(
          child: Text('No folders matching search.', style: EDesign.secondaryStyle),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: filteredKeys.length,
        itemBuilder: (context, index) {
          final folderName = filteredKeys[index];
          final items = map[folderName]!;
          return _buildFolderTile(folderName, items);
        },
      );
    } else {
      final displayItems = provider.searchResults;

      if (displayItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: EDesign.textMuted),
              const SizedBox(height: 12),
              Text(
                'No ${_selectedChip.toLowerCase()} matching "${provider.searchOptions.query}"',
                style: EDesign.secondaryStyle,
              ),
            ],
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.45,
        ),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          return _buildMediaCard(item, provider);
        },
      );
    }
  }

  Widget _buildFolderTile(String folderName, List<MediaItem> items) {
    final totalBytes = items.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: EDesign.cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EDesign.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(EDesign.r10),
          ),
          child: const Icon(Icons.folder_outlined, color: EDesign.primary, size: 26),
        ),
        title: Text(
          p.basename(folderName),
          style: const TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${items.length} items · ${EDesign.formatBytes(totalBytes)}',
          style: EDesign.secondaryStyle,
        ),
        trailing: const Icon(Icons.chevron_right, color: EDesign.textSecondary),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FolderDetailScreen(folderName: folderName, items: items),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaCard(MediaItem item, LibraryProvider provider) {
    final ext = p.extension(item.path).replaceAll('.', '').toUpperCase();
    final isAudio = ['MP3', 'FLAC', 'M4A', 'WAV', 'AAC', 'OGG', 'OPUS'].contains(ext);

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
                color: EDesign.primary.withValues(alpha: 0.18),
                size: 48,
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
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: EDesign.textSecondary, size: 20),
                color: EDesign.elevatedSurface,
                onSelected: (value) async {
                  if (value == 'favorite') {
                    await provider.toggleFavorite(item.path);
                  } else if (value == 'vault') {
                    try {
                      final vaultService = context.read<VaultService>();
                      if (!vaultService.isUnlocked) {
                        final unlocked = await vaultService.authenticate(context);
                        if (!unlocked) return;
                      }
                      await vaultService.moveToVault(item);
                      await provider.removeItemFromLibrary(item.path);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Moved "${item.name}" to Private Vault')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  } else if (value == 'trash') {
                    try {
                      final trashService = context.read<TrashService>();
                      await trashService.moveToTrash(item);
                      await provider.removeItemFromLibrary(item.path);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Moved "${item.name}" to Trash')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(
                      item.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
                      style: const TextStyle(color: EDesign.textPrimary),
                    ),
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
              ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
