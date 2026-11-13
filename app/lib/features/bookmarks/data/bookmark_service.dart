import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/bookmark_models.dart';

export '../domain/bookmark_models.dart';

/// Service managing intra-media chapter bookmarks with in-memory caching and persistent disk storage.
/// Parity with VLC's input_item_t bookmark markers and custom bookmarks dialog.
class BookmarkService extends ChangeNotifier {
  static BookmarkService? _instance;
  static BookmarkService get instance => _instance ??= BookmarkService();

  final Directory? _customStorageDir;
  final Map<String, List<MediaBookmark>> _cache = {};
  bool _isLoaded = false;
  File? _storageFile;

  bool get isLoaded => _isLoaded;

  BookmarkService({Directory? storageDir}) : _customStorageDir = storageDir {
    _initStorage();
  }

  Future<void> _initStorage() async {
    try {
      Directory dir;
      if (_customStorageDir != null) {
        dir = _customStorageDir;
      } else {
        try {
          dir = await getApplicationDocumentsDirectory();
        } catch (_) {
          dir = Directory.systemTemp;
        }
      }

      _storageFile = File('${dir.path}/eplayer_bookmarks.json');
      if (_storageFile!.existsSync()) {
        final content = _storageFile!.readAsStringSync();
        if (content.isNotEmpty) {
          final decoded = json.decode(content) as Map<String, dynamic>;
          _cache.clear();
          for (final entry in decoded.entries) {
            final list = (entry.value as List<dynamic>)
                .map((item) => MediaBookmark.fromJson(item as Map<String, dynamic>))
                .toList();
            _cache[entry.key] = list;
          }
        }
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('BookmarkService initStorage error: $e');
      _isLoaded = true;
    }
  }

  void _persistSync() {
    if (_storageFile == null) return;
    try {
      final jsonMap = <String, dynamic>{};
      for (final entry in _cache.entries) {
        jsonMap[entry.key] = entry.value.map((b) => b.toJson()).toList();
      }
      _storageFile!.writeAsStringSync(json.encode(jsonMap));
    } catch (e) {
      debugPrint('BookmarkService persist error: $e');
    }
  }

  /// Returns sorted list of bookmarks for the given [mediaId]
  List<MediaBookmark> getBookmarks(String mediaId) {
    final list = _cache[mediaId] ?? [];
    list.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return List.unmodifiable(list);
  }

  /// Adds a new bookmark at [position] for [mediaId].
  /// If a bookmark already exists within 250ms, it is returned without duplicate insertion.
  Future<MediaBookmark> addBookmark({
    required String mediaId,
    required Duration position,
    String? label,
  }) async {
    final existing = _cache[mediaId] ?? [];

    // Deduplication check (threshold 250ms)
    final duplicate = existing.where((b) {
      return (b.position.inMilliseconds - position.inMilliseconds).abs() <= 250;
    }).firstOrNull;

    if (duplicate != null) {
      return duplicate;
    }

    final String resolvedLabel = (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : 'Bookmark at ${_formatDuration(position)}';

    final id = 'bm_${DateTime.now().microsecondsSinceEpoch}';
    final bookmark = MediaBookmark(
      id: id,
      mediaId: mediaId,
      position: position,
      label: resolvedLabel,
      createdAt: DateTime.now(),
    );

    if (!_cache.containsKey(mediaId)) {
      _cache[mediaId] = [];
    }
    _cache[mediaId]!.add(bookmark);
    _cache[mediaId]!.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    _persistSync();
    notifyListeners();
    return bookmark;
  }

  /// Renames an existing bookmark by [id]
  Future<bool> renameBookmark(String id, String newLabel) async {
    for (final entry in _cache.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == id) {
          list[i] = list[i].copyWith(label: newLabel.trim());
          _persistSync();
          notifyListeners();
          return true;
        }
      }
    }
    return false;
  }

  /// Removes a bookmark by [id]
  Future<bool> removeBookmark(String id) async {
    for (final entry in _cache.entries) {
      final list = entry.value;
      final initialLength = list.length;
      list.removeWhere((b) => b.id == id);
      if (list.length < initialLength) {
        _persistSync();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Clears all bookmarks for [mediaId]
  Future<void> clearBookmarks(String mediaId) async {
    if (_cache.remove(mediaId) != null) {
      _persistSync();
      notifyListeners();
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
