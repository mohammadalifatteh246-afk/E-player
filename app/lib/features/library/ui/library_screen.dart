import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../domain/library_provider.dart';
import '../../player/ui/player_screen.dart';
import '../../../core/models/media_item.dart';
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF09090E),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Media Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {},
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF1A1A24),
                onSelected: (val) {
                  if (val == 'vault') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
                  } else if (val == 'trash') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen()));
                  } else if (val == 'export') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen()));
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'vault', child: Text('Private Vault', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'trash', child: Text('Trash', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'export', child: Text('Export Jobs', style: TextStyle(color: Colors.white))),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: provider.isScanning ? null : () => provider.scanDirectory(),
            backgroundColor: const Color(0xFF00E5FF),
            child: provider.isScanning 
                ? const CircularProgressIndicator(color: Colors.black)
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
                  color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.white24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
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
            Icon(Icons.video_library_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 20),
            Text(provider.isScanning ? provider.scanProgress : 'Your Library is Empty', style: const TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      );
    }

    if (_selectedChip == 'Folders') {
      final map = provider.groupedFolders;
      if (map.isEmpty) {
         return const Center(child: Text('No folders found.', style: TextStyle(color: Colors.white54)));
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: map.keys.length,
        itemBuilder: (context, index) {
          final folderName = map.keys.elementAt(index);
          final items = map[folderName]!;
          return _buildFolderTile(folderName, items, provider);
        },
      );
    } else {
      List<MediaItem> displayItems = [];
      if (_selectedChip == 'All') {
        displayItems = provider.allFiles;
      } else if (_selectedChip == 'Videos') {
        displayItems = provider.allFiles.where((i) => i.path.toLowerCase().endsWith('.mp4') || i.path.toLowerCase().endsWith('.mkv') || i.path.toLowerCase().endsWith('.avi')).toList();
      } else if (_selectedChip == 'Audio') {
        displayItems = provider.allFiles.where((i) => i.path.toLowerCase().endsWith('.mp3') || i.path.toLowerCase().endsWith('.flac') || i.path.toLowerCase().endsWith('.m4a') || i.path.toLowerCase().endsWith('.wav')).toList();
      }

      if (displayItems.isEmpty) {
        return Center(child: Text('No \ found.', style: const TextStyle(color: Colors.white54)));
      }

      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
        ),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          return _buildMediaCard(item, provider);
        },
      );
    }
  }

  Widget _buildFolderTile(String folderName, List<MediaItem> items, LibraryProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.folder_outlined, color: Color(0xFF00E5FF), size: 32),
        title: Text(p.basename(folderName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('\ items', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FolderDetailScreen(folderName: folderName, items: items)),
          );
        },
      ),
    );
  }

  Widget _buildMediaCard(MediaItem item, LibraryProvider provider) {
    return InkWell(
      onTap: () {
        provider.addRecent(item.path);
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                item.path.toLowerCase().endsWith('.mp3') || item.path.toLowerCase().endsWith('.flac') 
                  ? Icons.music_note 
                  : Icons.play_circle_fill, 
                color: Colors.white.withValues(alpha: 0.1), size: 48
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                color: const Color(0xFF1A1A24),
                onSelected: (value) async {
                  if (value == 'vault') {
                    try {
                      final vaultService = context.read<VaultService>();
                      await vaultService.moveToVault(item);
                      provider.scanDirectory();
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
                    }
                  } else if (value == 'trash') {
                    try {
                      final trashService = context.read<TrashService>();
                      await trashService.moveToTrash(item);
                      provider.scanDirectory();
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'vault', child: Text('Move to Vault', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'trash', child: Text('Move to Trash', style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                item.name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
