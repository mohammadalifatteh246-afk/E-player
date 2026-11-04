import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/models/media_library_models.dart';
import '../../../../core/db/media_library_repository.dart';
import '../../../../core/db/task_queue_repository.dart';
import '../../../../theme/e_player_colors.dart';
import '../../library/domain/auto_rescan_coordinator.dart';
import '../domain/file_system_service.dart';
import 'widgets/breadcrumb_bar.dart';
import 'widgets/drive_selector_bar.dart';
import 'widgets/folder_list_tile.dart';
import 'widgets/media_item_details_sheet.dart';

/// Production interactive File Browser screen providing zero-depth navigation,
/// drive root switching, debounced instant search, and Media Library integration.
class FileBrowserScreen extends StatefulWidget {
  final String? initialPath;
  final FileSystemService fileSystemService;
  final AutoRescanCoordinator? rescanCoordinator;
  final MediaLibraryRepository? repository;
  final ValueChanged<String>? onFileSelected;

  const FileBrowserScreen({
    super.key,
    this.initialPath,
    this.fileSystemService = const DefaultFileSystemService(),
    this.rescanCoordinator,
    this.repository,
    this.onFileSelected,
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  late String _currentPath;
  List<String> _drives = [];
  List<FileSystemNode> _allEntries = [];
  List<FileSystemNode> _filteredEntries = [];
  Set<String> _monitoredPaths = {};

  bool _isLoading = true;
  bool _isGridView = false;
  bool _showHidden = false;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  late final AutoRescanCoordinator _coordinator;
  bool _ownsCoordinator = false;

  @override
  void initState() {
    super.initState();
    _initCoordinator();
    _loadDrivesAndInitialDirectory();
    _searchController.addListener(_onSearchChanged);
  }

  void _initCoordinator() {
    if (widget.rescanCoordinator != null) {
      _coordinator = widget.rescanCoordinator!;
    } else {
      final repo = widget.repository ?? SqliteMediaLibraryRepository();
      _coordinator = AutoRescanCoordinator(
        repository: repo,
        taskQueue: SqliteTaskQueueRepository(),
        fileSystemService: widget.fileSystemService,
      );
      _ownsCoordinator = true;
    }
  }

  void _loadDrivesAndInitialDirectory() {
    _drives = widget.fileSystemService.getLogicalDrives();
    final defaultRoot = _drives.isNotEmpty ? _drives.first : '/';
    _currentPath = widget.initialPath ?? defaultRoot;
    _navigateToDirectory(_currentPath);
  }

  Future<void> _navigateToDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final normalized = widget.fileSystemService.normalizePath(path);
      final entries = await widget.fileSystemService.listDirectoryContents(
        normalized,
        showHidden: _showHidden,
      );

      // Check monitored folders in database
      final folders = await _coordinator.repository.getAllFolders(onlyPresent: true);
      final monitoredSet = <String>{};
      for (final f in folders) {
        if (!f.isBanned) monitoredSet.add(f.path);
      }

      setState(() {
        _currentPath = normalized;
        _allEntries = entries;
        _monitoredPaths = monitoredSet;
        _isLoading = false;
      });

      _applyFilter(_searchController.text);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to open directory: $e';
      });
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _applyFilter(_searchController.text);
    });
  }

  void _applyFilter(String query) {
    final trimmed = query.trim().toLowerCase();
    setState(() {
      if (trimmed.isEmpty) {
        _filteredEntries = List.of(_allEntries);
      } else {
        _filteredEntries = _allEntries
            .where((node) => node.name.toLowerCase().contains(trimmed))
            .toList();
      }
    });
  }

  Future<void> _toggleMonitoring(String directoryPath) async {
    final normalized = widget.fileSystemService.normalizePath(directoryPath);
    if (_monitoredPaths.contains(normalized)) {
      await _coordinator.unregisterFolder(normalized);
      setState(() {
        _monitoredPaths.remove(normalized);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$normalized" from Media Library'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _monitoredPaths.add(normalized);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$normalized" to Media Library (Auto-rescan active)'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      try {
        await _coordinator.registerFolder(normalized);
      } catch (e) {
        // If registration fails, rollback
        setState(() {
          _monitoredPaths.remove(normalized);
        });
      }
    }
  }

  void _handleNodeTap(FileSystemNode node) {
    if (node.isDirectory) {
      _navigateToDirectory(node.path);
    } else if (node.isMedia) {
      if (widget.onFileSelected != null) {
        widget.onFileSelected!(node.path);
      } else {
        MediaItemDetailsSheet.show(
          context,
          node: node,
          onPlay: () {
            if (widget.onFileSelected != null) {
              widget.onFileSelected!(node.path);
            }
          },
        );
      }
    }
  }

  void _handleNodeInfo(FileSystemNode node) {
    MediaItemDetailsSheet.show(
      context,
      node: node,
      onPlay: () {
        if (widget.onFileSelected != null) {
          widget.onFileSelected!(node.path);
        }
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    if (_ownsCoordinator) {
      _coordinator.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breadcrumbs = widget.fileSystemService.parseBreadcrumbs(_currentPath);
    final isCurrentMonitored = _monitoredPaths.contains(_currentPath);

    return Scaffold(
      backgroundColor: EPlayerColors.background,
      appBar: AppBar(
        title: const Text(
          'File Browser',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isCurrentMonitored ? Icons.folder_special : Icons.create_new_folder_outlined,
              color: isCurrentMonitored ? EPlayerColors.primary : EPlayerColors.textSecondary,
            ),
            tooltip: isCurrentMonitored ? 'Monitored in Library' : 'Add Current Folder to Library',
            onPressed: () => _toggleMonitoring(_currentPath),
          ),
          IconButton(
            icon: Icon(
              _showHidden ? Icons.visibility : Icons.visibility_off,
              color: _showHidden ? EPlayerColors.primary : EPlayerColors.textSecondary,
            ),
            tooltip: _showHidden ? 'Hide hidden files' : 'Show hidden files',
            onPressed: () {
              setState(() {
                _showHidden = !_showHidden;
              });
              _navigateToDirectory(_currentPath);
            },
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: EPlayerColors.textSecondary,
            ),
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: EPlayerColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => _navigateToDirectory(_currentPath),
          ),
        ],
      ),
      body: Column(
        children: [
          // Drive Switcher Bar
          DriveSelectorBar(
            drives: _drives,
            activeRoot: _currentPath,
            onDriveSelected: _navigateToDirectory,
          ),

          // Breadcrumb Bar
          BreadcrumbBar(
            segments: breadcrumbs,
            onSegmentSelected: _navigateToDirectory,
          ),

          // Search Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: EPlayerColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Filter current folder...',
                prefixIcon: const Icon(Icons.search, size: 18, color: EPlayerColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: EPlayerColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: EPlayerColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: EPlayerColors.danger),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: EPlayerColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EPlayerColors.primary,
                  foregroundColor: EPlayerColors.background,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                onPressed: () => _navigateToDirectory(_currentPath),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded, size: 52, color: EPlayerColors.border),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No matching files found'
                  : 'Directory is empty',
              style: const TextStyle(color: EPlayerColors.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: _filteredEntries.length,
        itemBuilder: (context, index) {
          final node = _filteredEntries[index];
          return _buildGridItem(node);
        },
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final node = _filteredEntries[index];
        final isNodeMonitored = _monitoredPaths.contains(node.path);

        return FolderListTile(
          node: node,
          isMonitored: isNodeMonitored,
          onTap: () => _handleNodeTap(node),
          onLongPress: () => _handleNodeInfo(node),
          onInfoTap: () => _handleNodeInfo(node),
          onToggleMonitor: node.isDirectory ? () => _toggleMonitoring(node.path) : null,
        );
      },
    );
  }

  Widget _buildGridItem(FileSystemNode node) {
    IconData icon;
    Color color;

    switch (node.type) {
      case FileNodeType.drive:
        icon = Icons.storage_rounded;
        color = EPlayerColors.primary;
        break;
      case FileNodeType.directory:
        icon = Icons.folder_rounded;
        color = EPlayerColors.warning;
        break;
      case FileNodeType.videoFile:
        icon = Icons.movie_outlined;
        color = EPlayerColors.info;
        break;
      case FileNodeType.audioFile:
        icon = Icons.music_note_outlined;
        color = EPlayerColors.purple;
        break;
      case FileNodeType.subtitleFile:
        icon = Icons.subtitles_outlined;
        color = EPlayerColors.success;
        break;
      case FileNodeType.otherFile:
        icon = Icons.insert_drive_file_outlined;
        color = EPlayerColors.textMuted;
        break;
    }

    return InkWell(
      onTap: () => _handleNodeTap(node),
      onLongPress: () => _handleNodeInfo(node),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: EPlayerColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EPlayerColors.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              node.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: EPlayerColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
