import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/library_provider.dart';
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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                    decoration: const InputDecoration(
                      hintText: 'Search library...',
                      hintStyle: TextStyle(color: EDesign.textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
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
                  }
                },
                itemBuilder: (context) => [
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
            onPressed: provider.isScanning ? null : () => provider.scanDirectory(),
            backgroundColor: EDesign.primary,
            tooltip: 'Scan Media Folder',
            child: provider.isScanning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                : const Icon(Icons.create_new_folder, color: Colors.black),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryChips(),
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

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _chips.map((chip) {
          final isSelected = _selectedChip == chip;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedChip = chip),
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
              'Tap the folder button below to scan local media.',
              style: EDesign.secondaryStyle,
            ),
          ],
        ),
      );
    }

    if (_selectedChip == 'Folders') {
      final map = provider.groupedFolders;
      final filteredKeys = map.keys
          .where((k) =>
              _searchQuery.isEmpty ||
              p.basename(k).toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

      if (filteredKeys.isEmpty) {
        return const Center(
          child: Text('No folders found.', style: EDesign.secondaryStyle),
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
      List<MediaItem> displayItems = [];
      if (_selectedChip == 'All') {
        displayItems = provider.allFiles;
      } else if (_selectedChip == 'Videos') {
        displayItems = provider.allFiles.where((i) {
          final lower = i.path.toLowerCase();
          return lower.endsWith('.mp4') ||
              lower.endsWith('.mkv') ||
              lower.endsWith('.avi') ||
              lower.endsWith('.webm') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.flv') ||
              lower.endsWith('.wmv') ||
              lower.endsWith('.ts') ||
              lower.endsWith('.vob');
        }).toList();
      } else if (_selectedChip == 'Audio') {
        displayItems = provider.allFiles.where((i) {
          final lower = i.path.toLowerCase();
          return lower.endsWith('.mp3') ||
              lower.endsWith('.flac') ||
              lower.endsWith('.m4a') ||
              lower.endsWith('.wav');
        }).toList();
      }

      if (_searchQuery.isNotEmpty) {
        displayItems = displayItems
            .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
      }

      if (displayItems.isEmpty) {
        return Center(
          child: Text(
            'No $_selectedChip found.',
            style: EDesign.secondaryStyle,
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
    final isAudio = ['MP3', 'FLAC', 'M4A', 'WAV'].contains(ext);

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
