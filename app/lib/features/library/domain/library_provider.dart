import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/media_item.dart';
import '../../../core/db/database_helper.dart';
import 'drive_scanner_models.dart';
import 'media_scanner_service.dart';
import 'media_search_engine.dart';
import 'video_grouping_service.dart';

export 'drive_scanner_models.dart';
export 'video_grouping_service.dart';

class LibraryProvider extends ChangeNotifier {
  List<MediaItem> _recentFiles = [];
  List<MediaItem> _favorites = [];
  List<MediaItem> _allFiles = [];
  GroupMode _groupMode = GroupMode.none;
  static const String _kGroupModePrefKey = 'eplayer_video_grouping_mode';
  static const String _kScannedDrivesMetaPrefKey = 'eplayer_scanned_drives_meta';
  static const String _kCustomScanFoldersPrefKey = 'eplayer_custom_scan_folders';
  Map<String, DateTime> _driveScanTimestamps = {};
  List<String> _customScanFolders = [];
  bool _isDisposed = false;

  final MediaScannerService _scannerService = MediaScannerService();
  MediaSearchOptions _searchOptions = const MediaSearchOptions();
  ScanProgress? _lastScanProgress;

  List<MediaItem> get recentFiles => _recentFiles;
  List<MediaItem> get favorites => _favorites;
  List<MediaItem> get allFiles => _allFiles;

  MediaSearchOptions get searchOptions => _searchOptions;
  ScanProgress? get lastScanProgress => _lastScanProgress;
  MediaScannerService get scannerService => _scannerService;

  Map<String, List<MediaItem>> get groupedFolders {
    final map = <String, List<MediaItem>>{};
    for (var item in _allFiles) {
      try {
        if (!Directory(item.parentFolder).existsSync()) continue;
        if (!File(item.path).existsSync()) continue;
      } catch (_) {}
      map.putIfAbsent(item.parentFolder, () => []).add(item);
    }
    return map;
  }

  /// Returns filtered and sorted media items based on current search options (VLC parity)
  List<MediaItem> get searchResults {
    return MediaSearchEngine.execute(_allFiles, _searchOptions);
  }

  /// Returns filtered folder groups matching the current query
  Map<String, List<MediaItem>> get filteredGroupedFolders {
    return MediaSearchEngine.filterFolders(groupedFolders, _searchOptions.query);
  }

  GroupMode get groupMode => _groupMode;

  /// Sets video grouping mode and persists to SharedPreferences
  Future<void> setGroupMode(GroupMode mode) async {
    if (_groupMode == mode) return;
    _groupMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kGroupModePrefKey, mode.name);
    } catch (_) {}
  }

  /// Groups search results in-memory with sub-16ms latency
  List<VideoGroup> get groupedSearchResults {
    return VideoGroupingEngine.group(searchResults, _groupMode);
  }

  /// Groups recent files in-memory
  List<VideoGroup> get groupedRecentFiles {
    return VideoGroupingEngine.group(recentFiles, _groupMode);
  }

  /// Groups all indexed files in-memory
  List<VideoGroup> get groupedAllFiles {
    return VideoGroupingEngine.group(allFiles, _groupMode);
  }

  /// Groups custom media items with specified or active mode
  List<VideoGroup> groupCustomItems(List<MediaItem> items, [GroupMode? mode]) {
    return VideoGroupingEngine.group(items, mode ?? _groupMode);
  }

  LibraryProvider() {
    _loadFromDB();
  }

  Future<void> _loadFromDB({bool pruneMissing = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_kGroupModePrefKey);
      if (savedMode != null) {
        _groupMode = GroupMode.values.firstWhere(
          (m) => m.name == savedMode,
          orElse: () => GroupMode.none,
        );
      }

      final drivesMetaRaw = prefs.getString(_kScannedDrivesMetaPrefKey);
      if (drivesMetaRaw != null && drivesMetaRaw.isNotEmpty) {
        final decoded = jsonDecode(drivesMetaRaw) as Map<String, dynamic>;
        _driveScanTimestamps = {
          for (final entry in decoded.entries)
            if (DateTime.tryParse(entry.value.toString()) != null)
              entry.key: DateTime.parse(entry.value.toString()),
        };
      }

      final savedCustomFolders = prefs.getStringList(_kCustomScanFoldersPrefKey);
      if (savedCustomFolders != null) {
        _customScanFolders = List<String>.from(savedCustomFolders);
      }
    } catch (_) {}

    try {
      if (pruneMissing) {
        await DatabaseHelper.instance.pruneMissingItems();
      }
      final allItems = await DatabaseHelper.instance.getAllItems();
      _allFiles = allItems.where((i) {
        try {
          return File(i.path).existsSync();
        } catch (_) {
          return false;
        }
      }).toList();

      // Sort by lastPlayed desc for recents
      final recents = List<MediaItem>.from(_allFiles);
      recents.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      _recentFiles = recents.take(50).toList();

      // Favorites
      _favorites = _allFiles.where((i) => i.isFavorite).toList();
    } catch (e) {
      _allFiles = [];
      _recentFiles = [];
      _favorites = [];
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> refreshLibrary() async {
    await _loadFromDB(pruneMissing: true);
  }

  // --- VLC Search & Filter Controls ---

  void setSearchQuery(String query) {
    if (_searchOptions.query == query) return;
    _searchOptions = _searchOptions.copyWith(query: query);
    notifyListeners();
  }

  void setCategory(MediaCategory category) {
    if (_searchOptions.category == category) return;
    _searchOptions = _searchOptions.copyWith(category: category);
    notifyListeners();
  }

  void setSort(SortField field, [SortOrder? order]) {
    _searchOptions = _searchOptions.copyWith(
      sortField: field,
      sortOrder: order ?? _searchOptions.sortOrder,
    );
    notifyListeners();
  }

  void toggleSortOrder() {
    final nextOrder = _searchOptions.sortOrder == SortOrder.ascending
        ? SortOrder.descending
        : SortOrder.ascending;
    _searchOptions = _searchOptions.copyWith(sortOrder: nextOrder);
    notifyListeners();
  }

  void clearSearch() {
    _searchOptions = _searchOptions.copyWith(query: '');
    notifyListeners();
  }

  Future<void> removeItemFromLibrary(String path) async {
    try {
      await DatabaseHelper.instance.deleteItem(path);
    } catch (_) {}
    await _loadFromDB();
  }

  Future<void> updateWatchProgress(String path, int positionMs, int durationMs) async {
    try {
      final allItems = await DatabaseHelper.instance.getAllItems();
      final existingIndex = allItems.indexWhere((item) => item.path == path);
      if (existingIndex >= 0) {
        final updated = allItems[existingIndex].copyWith(
          lastPositionMs: positionMs,
          durationMs: durationMs > 0 ? durationMs : allItems[existingIndex].durationMs,
          lastPlayed: DateTime.now(),
        );
        await DatabaseHelper.instance.insertOrUpdateItem(updated);
        await _loadFromDB();
      }
    } catch (_) {}
  }

  Future<String?> pickFile() async {
    PlatformFile? result = await FilePicker.pickFile(
      type: FileType.video,
    );

    if (result != null && result.path != null) {
      final path = result.path!;
      await addRecent(path);
      return path;
    }
    return null;
  }

  Future<void> addRecent(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    final name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : p.basename(path);
    final parent = file.parent.path;
    final size = await file.length();

    final existingIndex = _allFiles.indexWhere((item) => item.path == path);
    MediaItem item;

    if (existingIndex >= 0) {
      item = _allFiles[existingIndex].copyWith(lastPlayed: DateTime.now());
    } else {
      item = MediaItem(
        path: path,
        name: name,
        parentFolder: parent,
        sizeBytes: size,
        lastPlayed: DateTime.now(),
      );
    }

    await DatabaseHelper.instance.insertOrUpdateItem(item);
    await _loadFromDB();
  }

  Future<void> toggleFavorite(String path) async {
    final allItems = await DatabaseHelper.instance.getAllItems();
    final existingIndex = allItems.indexWhere((item) => item.path == path);

    if (existingIndex >= 0) {
      final item = allItems[existingIndex];
      await DatabaseHelper.instance.insertOrUpdateItem(
        item.copyWith(isFavorite: !item.isFavorite),
      );
    } else {
      final file = File(path);
      final name = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'Unknown';
      final item = MediaItem(
        path: path,
        name: name,
        parentFolder: file.parent.path,
        lastPlayed: DateTime.now(),
        isFavorite: true,
      );
      await DatabaseHelper.instance.insertOrUpdateItem(item);
    }

    await _loadFromDB();
  }

  // --- VLC-Inspired Multi-Drive Scanning Engine ---

  bool isScanning = false;
  String scanProgress = '';

  List<String> get customScanFolders => List.unmodifiable(_customScanFolders);

  DateTime? getLastScanTimestamp(String driveOrFolderPath) {
    final key = DriveVolumeInfo.normalizeKey(driveOrFolderPath);
    return _driveScanTimestamps[key];
  }

  /// Discovers all logical drives/partitions and merges live indexed counts + scan timestamps.
  List<DriveVolumeInfo> discoverDrives({List<String>? overrideDrives}) {
    final drives = overrideDrives ?? MediaScannerService.getAvailableDrives();
    final systemDrive = Platform.environment['SystemDrive'] ?? 'C:';
    final systemRoot = DriveVolumeInfo.normalizeKey(systemDrive);

    final countsByRoot = <String, int>{};
    for (final item in _allFiles) {
      final root = DriveVolumeInfo.extractDriveRoot(item.path);
      if (root != null) {
        final key = DriveVolumeInfo.normalizeKey(root);
        countsByRoot[key] = (countsByRoot[key] ?? 0) + 1;
      }
    }

    return drives.map((rawPath) {
      final key = DriveVolumeInfo.normalizeKey(rawPath);
      final count = countsByRoot[key] ?? 0;
      final lastScanned = _driveScanTimestamps[key];
      final isSystem = key.toLowerCase() == systemRoot.toLowerCase();
      return DriveVolumeInfo(
        rootPath: rawPath,
        label: DriveVolumeInfo.formatDriveLabel(
          rawPath,
          systemDriveLetter: systemDrive,
        ),
        indexedFileCount: count,
        lastScannedAt: lastScanned,
        isSystemDrive: isSystem,
      );
    }).toList();
  }

  /// Registers a custom folder root for scanning in Multi-Drive Studio.
  Future<void> addCustomScanFolder(String folderPath) async {
    final trimmed = folderPath.trim();
    if (trimmed.isEmpty) return;
    final key = DriveVolumeInfo.normalizeKey(trimmed);
    final alreadyExists = _customScanFolders.any(
      (f) => DriveVolumeInfo.normalizeKey(f).toLowerCase() == key.toLowerCase(),
    );
    if (!alreadyExists) {
      _customScanFolders.add(trimmed);
      await _persistDriveScannerMeta();
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Removes a custom folder from Multi-Drive Studio list.
  Future<void> removeCustomScanFolder(String folderPath) async {
    final key = DriveVolumeInfo.normalizeKey(folderPath).toLowerCase();
    _customScanFolders.removeWhere(
      (f) => DriveVolumeInfo.normalizeKey(f).toLowerCase() == key,
    );
    await _persistDriveScannerMeta();
    if (!_isDisposed) notifyListeners();
  }

  int countFilesUnderPath(String folderPath) {
    final prefix = Platform.isWindows ? folderPath.toLowerCase() : folderPath;
    int count = 0;
    for (final item in _allFiles) {
      final itemPath = Platform.isWindows ? item.path.toLowerCase() : item.path;
      if (itemPath.startsWith(prefix)) count++;
    }
    return count;
  }

  Future<void> _recordScanTimestamps(List<String> paths) async {
    final now = DateTime.now();
    final systemDrives = MediaScannerService.getAvailableDrives()
        .map((d) => DriveVolumeInfo.normalizeKey(d).toLowerCase())
        .toSet();

    for (final path in paths) {
      final key = DriveVolumeInfo.normalizeKey(path);
      _driveScanTimestamps[key] = now;

      // Track non-drive-root folder paths as custom scan folders automatically
      final isRootDrive =
          RegExp(r'^[A-Za-z]:\\?$').hasMatch(key) || systemDrives.contains(key.toLowerCase());
      if (!isRootDrive) {
        final alreadySaved = _customScanFolders.any(
          (f) => DriveVolumeInfo.normalizeKey(f).toLowerCase() == key.toLowerCase(),
        );
        if (!alreadySaved) {
          _customScanFolders.add(path.trim());
        }
      }
    }
    await _persistDriveScannerMeta();
  }

  Future<void> _persistDriveScannerMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = {
        for (final entry in _driveScanTimestamps.entries)
          entry.key: entry.value.toIso8601String(),
      };
      await prefs.setString(_kScannedDrivesMetaPrefKey, jsonEncode(encoded));
      await prefs.setStringList(_kCustomScanFoldersPrefKey, _customScanFolders);
    } catch (_) {}
  }

  /// Cancels any running scan
  void cancelScan() {
    if (isScanning) {
      _scannerService.cancelScan();
      isScanning = false;
      scanProgress = 'Scan cancelled';
      notifyListeners();
    }
  }

  /// Automatically discovers and scans system default media folders
  /// On Android: Uses MediaStore ContentResolver via Kotlin platform bridge.
  /// On Windows/Linux/macOS: Uses VLC-style directory crawling.
  Future<void> scanSystemMediaDirectories() async {
    if (isScanning) return;

    isScanning = true;
    scanProgress = 'Requesting permissions and locating media...';
    notifyListeners();

    try {
      if (Platform.isAndroid) {
        // 1. Request Android runtime storage permissions
        final granted = await MediaScannerService.requestAndroidPermissions();
        if (!granted) {
          scanProgress = 'Storage permission denied. Please grant permission in App Settings.';
          isScanning = false;
          notifyListeners();
          return;
        }

        scanProgress = 'Scanning Android MediaStore...';
        notifyListeners();

        // 2. Query Android MediaStore via ContentResolver
        final mediaItems = await MediaScannerService.scanAndroidMediaStore();
        if (mediaItems.isNotEmpty) {
          scanProgress = 'Saving ${mediaItems.length} media files to library...';
          notifyListeners();

          await DatabaseHelper.instance.insertBatch(mediaItems);
          await DatabaseHelper.instance.pruneMissingItems();
          scanProgress = 'Scan complete! Found ${mediaItems.length} media files.';
          await _loadFromDB();
          return;
        }
      }

      // Fallback for Desktop (Windows/Mac/Linux) or if MediaStore returns empty
      final systemDirs = await _scannerService.getSystemMediaDirectories();
      if (systemDirs.isEmpty) {
        scanProgress = 'No default media folders found.';
        isScanning = false;
        notifyListeners();
        return;
      }

      await _executeScan(systemDirs);
    } catch (e) {
      scanProgress = 'Error scanning media: $e';
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  /// Scans multiple selected drives or custom folders in a single batch.
  Future<void> scanDrives(
    List<String> driveOrFolderPaths, {
    bool showHiddenFiles = false,
    bool skipSystemDirectories = true,
  }) async {
    if (isScanning) return;
    final targets = driveOrFolderPaths.where((p) => p.trim().isNotEmpty).toList();
    if (targets.isEmpty) return;

    if (Platform.isAndroid) {
      final granted = await MediaScannerService.requestAndroidPermissions();
      if (!granted) {
        scanProgress = 'Storage permission denied. Please grant permission in App Settings.';
        notifyListeners();
        return;
      }
    }

    isScanning = true;
    scanProgress = 'Preparing multi-drive scan (${targets.length} locations)...';
    notifyListeners();

    try {
      await _executeScan(
        targets,
        showHiddenFiles: showHiddenFiles,
        skipSystemDirectories: skipSystemDirectories,
      );
      await _recordScanTimestamps(targets);
    } catch (e) {
      scanProgress = 'Error: $e';
    } finally {
      isScanning = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Scans all detected logical drives across the system (C:\, D:\, E:\, etc.).
  Future<void> scanAllDrives({
    bool showHiddenFiles = false,
    bool skipSystemDirectories = true,
  }) async {
    final drives = MediaScannerService.getAvailableDrives();
    await scanDrives(
      drives,
      showHiddenFiles: showHiddenFiles,
      skipSystemDirectories: skipSystemDirectories,
    );
  }

  /// Scans only drives that have NOT been scanned yet (0 indexed files & no recorded scan).
  Future<void> scanUnscannedDrives({
    bool showHiddenFiles = false,
    bool skipSystemDirectories = true,
  }) async {
    final unscanned = discoverDrives()
        .where((d) => !d.isScanned)
        .map((d) => d.rootPath)
        .toList();
    if (unscanned.isEmpty) {
      scanProgress = 'All detected drives have already been scanned.';
      notifyListeners();
      return;
    }
    await scanDrives(
      unscanned,
      showHiddenFiles: showHiddenFiles,
      skipSystemDirectories: skipSystemDirectories,
    );
  }

  /// User directory scan via folder picker with enhanced VLC crawling and extension filtering
  Future<void> scanDirectory([String? directoryPath]) async {
    if (isScanning) return;

    if (Platform.isAndroid) {
      final granted = await MediaScannerService.requestAndroidPermissions();
      if (!granted) {
        scanProgress = 'Storage permission denied. Please grant permission in App Settings.';
        notifyListeners();
        return;
      }
    }

    String? selectedDirectory = directoryPath;
    selectedDirectory ??= await FilePicker.getDirectoryPath();

    if (selectedDirectory == null) return;

    isScanning = true;
    scanProgress = 'Scanning $selectedDirectory...';
    notifyListeners();

    try {
      await _executeScan([selectedDirectory]);
      await _recordScanTimestamps([selectedDirectory]);
    } catch (e) {
      scanProgress = 'Error: $e';
    } finally {
      isScanning = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> _executeScan(
    List<String> paths, {
    bool showHiddenFiles = false,
    bool skipSystemDirectories = true,
  }) async {
    await for (final progress in _scannerService.scanDirectories(
      paths,
      showHiddenFiles: showHiddenFiles,
      skipSystemDirectories: skipSystemDirectories,
    )) {
      _lastScanProgress = progress;
      final prefix = progress.totalRoots > 1
          ? '[Drive ${progress.currentRootIndex}/${progress.totalRoots}: ${progress.activeRoot}] '
          : '';
      scanProgress =
          '${prefix}Scanned: ${progress.scannedEntities} | Media: ${progress.mediaFilesFound} (${p.basename(progress.currentDirectory)})';
      if (!_isDisposed) notifyListeners();
    }

    scanProgress =
        'Scan complete! Found ${_lastScanProgress?.mediaFilesFound ?? 0} media files.';
    await DatabaseHelper.instance.pruneMissingItems();
    await _loadFromDB();
  }

  Future<List<MediaItem>> getAllLibraryItems() async {
    return await DatabaseHelper.instance.getAllItems();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
