import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../../core/models/media_item.dart';
import '../../../core/db/database_helper.dart';

class LibraryProvider extends ChangeNotifier {
  List<MediaItem> _recentFiles = [];
  List<MediaItem> _favorites = [];
  List<MediaItem> _allFiles = [];

  List<MediaItem> get recentFiles => _recentFiles;
  List<MediaItem> get favorites => _favorites;
  List<MediaItem> get allFiles => _allFiles;

  Map<String, List<MediaItem>> get groupedFolders {
    final map = <String, List<MediaItem>>{};
    for (var item in _allFiles) {
      map.putIfAbsent(item.parentFolder, () => []).add(item);
    }
    return map;
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
      // Database not ready or corrupted — start with empty state
      _allFiles = [];
      _recentFiles = [];
      _favorites = [];
    }
    notifyListeners();
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

    final name = file.uri.pathSegments.last;
    final parent = file.parent.path;
    final size = await file.length();

    // Check if exists in memory
    final existingIndex = _recentFiles.indexWhere((item) => item.path == path);
    MediaItem item;
    
    if (existingIndex >= 0) {
      item = _recentFiles[existingIndex].copyWith(lastPlayed: DateTime.now());
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
    // Find item
    final allItems = await DatabaseHelper.instance.getAllItems();
    final existingIndex = allItems.indexWhere((item) => item.path == path);
    
    if (existingIndex >= 0) {
      final item = allItems[existingIndex];
      await DatabaseHelper.instance.insertOrUpdateItem(item.copyWith(isFavorite: !item.isFavorite));
    } else {
      final item = MediaItem(
        path: path,
        name: 'Unknown',
        parentFolder: '',
        lastPlayed: DateTime.now(),
        isFavorite: true,
      );
      await DatabaseHelper.instance.insertOrUpdateItem(item);
    }

    await _loadFromDB();
  }

  // --- Phase 6: Library Indexer ---
  bool isScanning = false;
  String scanProgress = '';

  Future<void> scanDirectory() async {
    
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory == null) return;

    isScanning = true;
    notifyListeners();

    try {
      final dir = Directory(selectedDirectory);
      final List<MediaItem> foundItems = [];
      final validExtensions = ['.mp4', '.mkv', '.avi', '.webm', '.mov', '.flv', '.wmv'];

      scanProgress = 'Scanning $selectedDirectory...';
      notifyListeners();

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final dotIndex = entity.path.lastIndexOf('.');
          if (dotIndex != -1) {
            final ext = entity.path.substring(dotIndex).toLowerCase();
            if (validExtensions.contains(ext)) {
              final stat = await entity.stat();
              foundItems.add(MediaItem(
                path: entity.path,
                name: entity.uri.pathSegments.last,
                parentFolder: entity.parent.path,
                sizeBytes: stat.size,
                lastPlayed: DateTime.now(), // default value
              ));
            }
          }
        }
      }

      scanProgress = 'Saving ${foundItems.length} files to database...';
      notifyListeners();

      await DatabaseHelper.instance.insertBatch(foundItems);
      
      scanProgress = 'Scan complete!';
      await _loadFromDB();
    } catch (e) {
      scanProgress = 'Error: $e';
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  Future<List<MediaItem>> getAllLibraryItems() async {
    return await DatabaseHelper.instance.getAllItems();
  }
}
