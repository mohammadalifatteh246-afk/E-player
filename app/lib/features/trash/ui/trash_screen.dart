import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../domain/trash_service.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trashService = context.watch<TrashService>();
    final items = trashService.items;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Trash'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Empty Trash',
              onPressed: () => _confirmEmptyTrash(context, trashService),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'Trash is empty',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final fileName = p.basename(item.originalPath);
                final daysLeft = TrashService.retentionDays - DateTime.now().difference(item.deletedAt).inDays;

                return ListTile(
                  leading: const Icon(Icons.video_file, color: Colors.white54),
                  title: Text(
                    fileName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Deletes in $daysLeft days',
                    style: const TextStyle(color: Colors.white38),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.blueAccent),
                        onPressed: () => trashService.restore(item),
                        tooltip: 'Restore',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        onPressed: () => trashService.permanentDelete(item),
                        tooltip: 'Delete Permanently',
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmEmptyTrash(BuildContext context, TrashService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Empty Trash?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'All items in the trash will be permanently deleted. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              service.emptyTrash();
              Navigator.pop(ctx);
            },
            child: const Text('Empty Trash', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
