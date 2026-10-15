import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../../ui/theme/e_design_tokens.dart';
import '../../library/domain/library_provider.dart';
import '../domain/trash_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedTrashPaths = {};

  void _toggleSelection(String trashPath) {
    setState(() {
      if (_selectedTrashPaths.contains(trashPath)) {
        _selectedTrashPaths.remove(trashPath);
        if (_selectedTrashPaths.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedTrashPaths.add(trashPath);
        _isMultiSelectMode = true;
      }
    });
  }

  void _selectAll(List<TrashItem> items) {
    setState(() {
      if (_selectedTrashPaths.length == items.length) {
        _selectedTrashPaths.clear();
      } else {
        _selectedTrashPaths
          ..clear()
          ..addAll(items.map((e) => e.trashPath));
      }
    });
  }

  Future<void> _restoreSelected(TrashService trashService, LibraryProvider libraryProvider) async {
    final toRestore = trashService.items
        .where((i) => _selectedTrashPaths.contains(i.trashPath))
        .toList();
    for (final item in toRestore) {
      await trashService.restore(item);
      await libraryProvider.addRecent(item.originalPath);
    }
    if (mounted) {
      setState(() {
        _selectedTrashPaths.clear();
        _isMultiSelectMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${toRestore.length} items to Library.'),
          backgroundColor: EDesign.success,
        ),
      );
    }
  }

  Future<void> _deleteSelected(TrashService trashService) async {
    final toDelete = trashService.items
        .where((i) => _selectedTrashPaths.contains(i.trashPath))
        .toList();
    for (final item in toDelete) {
      await trashService.permanentDelete(item);
    }
    if (mounted) {
      setState(() {
        _selectedTrashPaths.clear();
        _isMultiSelectMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permanently deleted ${toDelete.length} items.'),
          backgroundColor: EDesign.danger,
        ),
      );
    }
  }

  Color _retentionBadgeColor(int daysLeft) {
    if (daysLeft <= 2) return EDesign.danger;
    if (daysLeft <= 7) return EDesign.warning;
    return EDesign.primary;
  }

  @override
  Widget build(BuildContext context) {
    final trashService = context.watch<TrashService>();
    final libraryProvider = context.read<LibraryProvider>();
    final items = trashService.items;

    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isMultiSelectMode
              ? '${_selectedTrashPaths.length} Selected'
              : 'Trash',
          style: EDesign.h2,
        ),
        centerTitle: true,
        actions: [
          if (items.isNotEmpty) ...[
            if (_isMultiSelectMode)
              TextButton(
                onPressed: () => _selectAll(items),
                child: Text(
                  _selectedTrashPaths.length == items.length ? 'None' : 'All',
                  style: const TextStyle(color: EDesign.primary, fontWeight: FontWeight.bold),
                ),
              ),
            IconButton(
              icon: Icon(
                _isMultiSelectMode ? Icons.close : Icons.checklist_rtl_rounded,
                color: EDesign.textPrimary,
              ),
              tooltip: _isMultiSelectMode ? 'Exit Selection' : 'Multi-Select',
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = !_isMultiSelectMode;
                  if (!_isMultiSelectMode) _selectedTrashPaths.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined, color: EDesign.danger),
              tooltip: 'Empty Trash',
              onPressed: () => _confirmEmptyTrash(context, trashService),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: (_isMultiSelectMode && _selectedTrashPaths.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: EDesign.surface,
                border: Border(top: BorderSide(color: EDesign.border)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EDesign.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EDesign.r10),
                            ),
                          ),
                          icon: const Icon(Icons.restore),
                          label: Text(
                            'Restore (${_selectedTrashPaths.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _restoreSelected(trashService, libraryProvider),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: EDesign.danger,
                            side: const BorderSide(color: EDesign.danger),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EDesign.r10),
                            ),
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: Text(
                            'Delete (${_selectedTrashPaths.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _deleteSelected(trashService),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // Summary Banner Card
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                      color: EDesign.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(EDesign.r14),
                    ),
                    child: const Icon(
                      Icons.auto_delete_outlined,
                      color: EDesign.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${items.length} Items in Trash', style: EDesign.h3),
                            const SizedBox(width: 8),
                            EDesign.buildBadge(
                              '${TrashService.retentionDays}D RETENTION',
                              color: EDesign.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reclaimable storage: ${EDesign.formatBytes(trashService.totalTrashSize)} · Items auto-purge after 30 days.',
                          style: EDesign.secondaryStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Trash List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 72,
                          color: EDesign.textMuted.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Trash is Empty',
                          style: EDesign.h3.copyWith(color: EDesign.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Deleted media stays here for 30 days before permanent removal.',
                          style: EDesign.secondaryStyle,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final fileName = p.basename(item.originalPath);
                      final parentDir = p.basename(p.dirname(item.originalPath));
                      final daysLeft = (TrashService.retentionDays -
                              DateTime.now().difference(item.deletedAt).inDays)
                          .clamp(0, TrashService.retentionDays);
                      final isSelected = _selectedTrashPaths.contains(item.trashPath);
                      final badgeColor = _retentionBadgeColor(daysLeft);

                      return GestureDetector(
                        onLongPress: () => _toggleSelection(item.trashPath),
                        onTap: _isMultiSelectMode
                            ? () => _toggleSelection(item.trashPath)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: EDesign.cardDecoration(
                            color: isSelected
                                ? EDesign.elevatedSurface
                                : EDesign.surface,
                            borderColor:
                                isSelected ? EDesign.primary : EDesign.border,
                            radius: EDesign.r14,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: _isMultiSelectMode
                                ? Checkbox(
                                    value: isSelected,
                                    activeColor: EDesign.primary,
                                    checkColor: Colors.black,
                                    onChanged: (_) => _toggleSelection(item.trashPath),
                                  )
                                : Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: EDesign.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(EDesign.r10),
                                    ),
                                    child: const Icon(
                                      Icons.video_file_outlined,
                                      color: EDesign.primary,
                                    ),
                                  ),
                            title: Text(
                              fileName,
                              style: const TextStyle(
                                color: EDesign.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  EDesign.buildBadge(
                                    '$daysLeft days left',
                                    color: badgeColor,
                                    icon: Icons.schedule,
                                  ),
                                  Text(
                                    '${EDesign.formatBytes(item.sizeBytes)} · from $parentDir',
                                    style: EDesign.caption,
                                  ),
                                ],
                              ),
                            ),
                            trailing: _isMultiSelectMode
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.restore_rounded,
                                          color: EDesign.primary,
                                        ),
                                        tooltip: 'Restore Media',
                                        onPressed: () async {
                                          await trashService.restore(item);
                                          await libraryProvider.addRecent(item.originalPath);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Restored "$fileName"'),
                                                backgroundColor: EDesign.success,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_forever_rounded,
                                          color: EDesign.danger,
                                        ),
                                        tooltip: 'Delete Permanently',
                                        onPressed: () =>
                                            trashService.permanentDelete(item),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context, TrashService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EDesign.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r18),
          side: const BorderSide(color: EDesign.border),
        ),
        title: const Text('Empty Trash?', style: EDesign.h3),
        content: Text(
          'All ${service.items.length} items (${EDesign.formatBytes(service.totalTrashSize)}) will be permanently erased. This action cannot be undone.',
          style: EDesign.secondaryStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EDesign.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              service.emptyTrash();
              setState(() {
                _selectedTrashPaths.clear();
                _isMultiSelectMode = false;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
  }
}
