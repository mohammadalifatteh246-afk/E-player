import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/media_item.dart';
import 'playlist_serializer.dart';

/// Manages active playback queue, track navigation, search filtering,
/// and undocked / detached floating window geometry (VLC Parity: `--pl-dock-status=0`, `Ctrl+L`).
class PlaylistController extends ChangeNotifier {
  List<MediaItem> _items = [];
  String? _currentPlayingPath;
  bool _isVisible = false;
  bool _isUndocked = true; // Floating detached mode
  bool _isMinimized = false;
  Offset _position = const Offset(30, 80);
  final Size _panelSize = const Size(360, 460);
  String _searchQuery = '';
  bool _isShuffle = false;
  bool _isRepeatAll = false;

  List<MediaItem> get items => _items;
  String? get currentPlayingPath => _currentPlayingPath;
  bool get isVisible => _isVisible;
  bool get isUndocked => _isUndocked;
  bool get isMinimized => _isMinimized;
  Offset get position => _position;
  Size get panelSize => _panelSize;
  String get searchQuery => _searchQuery;
  bool get isShuffle => _isShuffle;
  bool get isRepeatAll => _isRepeatAll;

  int get currentIndex {
    if (_currentPlayingPath == null) return -1;
    return _items.indexWhere((item) => item.path == _currentPlayingPath);
  }

  MediaItem? get currentItem {
    final idx = currentIndex;
    if (idx >= 0 && idx < _items.length) {
      return _items[idx];
    }
    return null;
  }

  List<MediaItem> get filteredItems {
    if (_searchQuery.trim().isEmpty) {
      return _items;
    }
    final q = _searchQuery.toLowerCase();
    return _items.where((item) => item.name.toLowerCase().contains(q)).toList();
  }

  void setItems(List<MediaItem> newItems, {String? activePath}) {
    _items = List.from(newItems);
    if (activePath != null) {
      _currentPlayingPath = activePath;
    }
    notifyListeners();
  }

  void setCurrentPlayingPath(String path) {
    _currentPlayingPath = path;
    notifyListeners();
  }

  void setVisible(bool visible) {
    if (_isVisible != visible) {
      _isVisible = visible;
      notifyListeners();
    }
  }

  void toggleVisible() {
    _isVisible = !_isVisible;
    notifyListeners();
  }

  void setUndocked(bool undocked) {
    if (_isUndocked != undocked) {
      _isUndocked = undocked;
      notifyListeners();
    }
  }

  void toggleDock() {
    _isUndocked = !_isUndocked;
    notifyListeners();
  }

  void toggleMinimized() {
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  void updatePosition(Offset delta, {Size? screenSize}) {
    double newX = _position.dx + delta.dx;
    double newY = _position.dy + delta.dy;

    if (screenSize != null) {
      final maxX = math.max(0.0, screenSize.width - _panelSize.width);
      final maxY = math.max(0.0, screenSize.height - (_isMinimized ? 48.0 : _panelSize.height));
      newX = newX.clamp(0.0, maxX);
      newY = newY.clamp(0.0, maxY);
    }

    _position = Offset(newX, newY);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatAll = !_isRepeatAll;
    notifyListeners();
  }

  MediaItem? getNextTrack() {
    if (_items.isEmpty) return null;
    if (_isShuffle) {
      final rand = math.Random();
      return _items[rand.nextInt(_items.length)];
    }
    final nextIdx = currentIndex + 1;
    if (nextIdx < _items.length) {
      return _items[nextIdx];
    } else if (_isRepeatAll) {
      return _items.first;
    }
    return null;
  }

  MediaItem? getPreviousTrack() {
    if (_items.isEmpty) return null;
    final prevIdx = currentIndex - 1;
    if (prevIdx >= 0) {
      return _items[prevIdx];
    } else if (_isRepeatAll) {
      return _items.last;
    }
    return null;
  }

  /// Imports playlist items from a local .m3u, .m3u8, or .xspf file.
  /// If [append] is true, appends tracks to the existing queue; otherwise replaces it.
  Future<int> importPlaylist(String filePath, {bool append = false}) async {
    final file = File(filePath);
    if (!file.existsSync()) return 0;

    final parsedItems = await PlaylistSerializer.loadFromFile(file);
    if (parsedItems.isEmpty) return 0;

    if (append) {
      _items.addAll(parsedItems);
    } else {
      _items = List.from(parsedItems);
      if (_items.isNotEmpty) {
        _currentPlayingPath = _items.first.path;
      }
    }
    notifyListeners();
    return parsedItems.length;
  }

  /// Exports current playlist queue to a .m3u8 or .xspf file at [targetPath].
  Future<File> exportPlaylist(
    String targetPath, {
    String title = 'E-Player Playlist',
  }) async {
    return PlaylistSerializer.saveToFile(_items, targetPath, title: title);
  }
}
