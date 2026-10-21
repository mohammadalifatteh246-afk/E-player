import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../../core/models/media_item.dart';
import '../../../core/db/database_helper.dart';
import 'media_scanner_service.dart';
import 'media_search_engine.dart';

class LibraryProvider extends ChangeNotifier {
  List<MediaItem> _recentFiles = [];
  List<MediaItem> _favorites = [];
  List<MediaItem> _allFiles = [];

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

  LibraryProvider() {
    _loadFromDB();
  }

  Future<void> _loadFromDB() async {
    try {
      final allItems = await DatabaseHelper.instance.getAllItems();
      _allFiles = allItems;

      // Sort by lastPlayed desc for recents
      final recents = List<MediaItem>.from(allItems);
      recents.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      _recentFiles = recents.take(50).toList();

      // Favorites
      _favorites = allItems.where((i) => i.isFavorite).toList();
    } catch (e) {
      _allFiles = [];
      _recentFiles = [];
      _favorites = [];
    }
    notifyListeners();
  }

  Future<void> refreshLibrary() async {
    await _loadFromDB();
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

  // --- VLC-Inspired Scanning Engine ---

  bool isScanning = false;
  String scanProgress = '';

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
    if (selectedDirectory == null) {
      selectedDirectory = await FilePicker.getDirectoryPath();
    }

    if (selectedDirectory == null) return;

    isScanning = true;
    scanProgress = 'Scanning $selectedDirectory...';
    notifyListeners();

    try {
      await _executeScan([selectedDirectory]);
    } catch (e) {
      scanProgress = 'Error: $e';
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> _executeScan(List<String> paths) async {
    await for (final progress in _scannerService.scanDirectories(paths)) {
      _lastScanProgress = progress;
      scanProgress =
          'Scanned: ${progress.scannedEntities} | Media: ${progress.mediaFilesFound} (${p.basename(progress.currentDirectory)})';
      notifyListeners();
    }

    scanProgress =
        'Scan complete! Found ${_lastScanProgress?.mediaFilesFound ?? 0} media files.';
    await _loadFromDB();
  }

  Future<List<MediaItem>> getAllLibraryItems() async {
    return await DatabaseHelper.instance.getAllItems();
  }
}
