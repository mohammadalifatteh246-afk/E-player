import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/library_provider.dart';
import '../../player/ui/player_screen.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/media_item.dart';
import 'folder_detail_screen.dart';
import '../../export/ui/export_screen.dart';
import '../../settings/ui/settings_screen.dart';
import '../../vault/ui/vault_screen.dart';
import '../../trash/ui/trash_screen.dart';
import '../../vault/domain/vault_service.dart';
import '../../trash/domain/trash_service.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13), // Deep premium dark background
      appBar: AppBar(
        title: const Text('E-Player', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.security, color: Colors.blueAccent),
            tooltip: 'Private Vault',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            tooltip: 'Trash',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.amber),
            tooltip: 'Export Jobs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<LibraryProvider>(
        builder: (ctx, provider, child) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final path = await provider.pickFile();
                            if (path != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: path)),
                              );
                            }
                          },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Open File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: provider.isScanning ? null : () => provider.scanDirectory(),
                          icon: provider.isScanning 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                              : const Icon(Icons.search),
                          label: Text(provider.isScanning ? 'Scanning...' : 'Scan Folder'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (provider.recentFiles.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final latest = provider.recentFiles.first;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: latest.path)),
                              );
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Continue'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (provider.favorites.isNotEmpty)
                _buildSliverSectionTitle('Favorites'),
              if (provider.favorites.isNotEmpty)
                _buildSliverGrid(provider.favorites, provider),
              if (provider.recentFiles.isNotEmpty)
                _buildSliverSectionTitle('Recent Media'),
              if (provider.recentFiles.isNotEmpty)
                _buildSliverGrid(provider.recentFiles, provider),
              if (provider.groupedFolders.isNotEmpty)
                _buildSliverSectionTitle('Folders'),
              if (provider.groupedFolders.isNotEmpty)
                _buildFolderList(provider.groupedFolders, context),
              if (provider.allFiles.isEmpty && provider.recentFiles.isEmpty && provider.favorites.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 20),
                        Text(provider.isScanning ? provider.scanProgress : 'Your Library is Empty', style: const TextStyle(color: Colors.white54, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 10.0, top: 10.0),
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSliverGrid(List items, LibraryProvider provider) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 16 / 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return Semantics(
              label: 'Media file: ${item.name}',
              hint: 'Double tap to play',
              child: InkWell(
                onTap: () {
                  provider.addRecent(item.path);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A2A35), Color(0xFF1E1E26)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Center(child: Icon(Icons.play_circle_fill, color: Colors.white24, size: 48)),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: item.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                              button: true,
                              child: IconButton(
                                icon: Icon(
                                  item.isFavorite ? Icons.star : Icons.star_border,
                                  color: item.isFavorite ? Colors.amber : Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () => provider.toggleFavorite(item.path),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                              color: const Color(0xFF2A2A35),
                              onSelected: (value) async {
                                if (value == 'vault') {
                                  try {
                                    final vaultService = context.read<VaultService>();
                                    await vaultService.moveToVault(item);
                                    provider.scanDirectory(); // Refresh library
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to Private Vault')));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vault Error: $e')));
                                    }
                                  }
                                } else if (value == 'trash') {
                                  try {
                                    final trashService = context.read<TrashService>();
                                    await trashService.moveToTrash(item);
                                    provider.scanDirectory(); // Refresh library
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to Trash')));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trash Error: $e')));
                                    }
                                  }
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem(
                                  value: 'vault',
                                  child: Row(
                                    children: [
                                      Icon(Icons.security, color: Colors.blueAccent, size: 20),
                                      SizedBox(width: 8),
                                      Text('Move to Vault', style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'trash',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                      SizedBox(width: 8),
                                      Text('Move to Trash', style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          child: Text(
                            item.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildFolderList(Map<String, List<MediaItem>> folders, BuildContext context) {
    final folderEntries = folders.entries.toList();
    folderEntries.sort((a, b) => p.basename(a.key).toLowerCase().compareTo(p.basename(b.key).toLowerCase()));
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = folderEntries[index];
          final folderPath = entry.key;
          final items = entry.value;
          final folderName = p.basename(folderPath);
          
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: Colors.amber, size: 32),
            ),
            title: Text(folderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${items.length} video${items.length > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FolderDetailScreen(folderName: folderName, items: items),
                ),
              );
            },
          );
        },
        childCount: folderEntries.length,
      ),
    );
  }

}
