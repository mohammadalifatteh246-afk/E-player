import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a user-curated media group or custom collection
class MediaGroup {
  final String id;
  final String title;
  final String description;
  final int colorValue;
  final String iconName;
  final List<String> itemPaths;
  final DateTime createdAt;

  MediaGroup({
    required this.id,
    required this.title,
    this.description = '',
    required this.colorValue,
    this.iconName = 'group',
    this.itemPaths = const [],
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'colorValue': colorValue,
        'iconName': iconName,
        'itemPaths': itemPaths,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MediaGroup.fromJson(Map<String, dynamic> json) => MediaGroup(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        colorValue: json['colorValue'] as int? ?? 0xFF00E5FF,
        iconName: json['iconName'] as String? ?? 'group',
        itemPaths: (json['itemPaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  MediaGroup copyWith({
    String? title,
    String? description,
    int? colorValue,
    String? iconName,
    List<String>? itemPaths,
  }) {
    return MediaGroup(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      itemPaths: itemPaths ?? this.itemPaths,
      createdAt: createdAt,
    );
  }
}

/// Service managing user-created collections and custom groupings
class MediaGroupService extends ChangeNotifier {
  static const String _storageKey = 'eplayer_custom_media_groups_v1';
  final List<MediaGroup> _groups = [];
  bool _isLoaded = false;

  List<MediaGroup> get groups => List.unmodifiable(_groups);
  bool get isLoaded => _isLoaded;

  MediaGroupService() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _groups.clear();
        for (var item in decoded) {
          if (item is Map<String, dynamic>) {
            _groups.add(MediaGroup.fromJson(item));
          }
        }
      }
    } catch (_) {}
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_groups.map((g) => g.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  static int _idCounter = 0;

  /// Creates a new custom group
  Future<MediaGroup> createGroup({
    required String title,
    Color color = const Color(0xFF00E5FF),
    String description = '',
    String iconName = 'group',
    List<String> initialPaths = const [],
  }) async {
    _idCounter++;
    final newGroup = MediaGroup(
      id: 'grp_${DateTime.now().microsecondsSinceEpoch}_$_idCounter',
      title: title.trim().isEmpty ? 'New Group' : title.trim(),
      description: description.trim(),
      colorValue: color.toARGB32(),
      iconName: iconName,
      itemPaths: initialPaths,
      createdAt: DateTime.now(),
    );

    _groups.insert(0, newGroup);
    await _saveToPrefs();
    notifyListeners();
    return newGroup;
  }

  /// Removes multiple groups atomically in a single persistence write
  Future<void> deleteGroups(Iterable<String> ids) async {
    final toRemove = ids.toSet();
    if (toRemove.isEmpty) return;
    final initialCount = _groups.length;
    _groups.removeWhere((g) => toRemove.contains(g.id));
    if (_groups.length != initialCount) {
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Removes an existing group
  Future<void> deleteGroup(String id) => deleteGroups([id]);

  /// Adds a media path to an existing group
  Future<void> addItemToGroup(String groupId, String path) =>
      addItemsToGroup(groupId, [path]);

  /// Adds multiple media paths to an existing group atomically (deduplicating entries)
  Future<void> addItemsToGroup(String groupId, List<String> paths) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1 && paths.isNotEmpty) {
      final current = _groups[idx];
      final updatedPaths = List<String>.from(current.itemPaths);
      bool changed = false;
      for (final p in paths) {
        if (!updatedPaths.contains(p)) {
          updatedPaths.add(p);
          changed = true;
        }
      }
      if (changed) {
        _groups[idx] = current.copyWith(itemPaths: updatedPaths);
        await _saveToPrefs();
        notifyListeners();
      }
    }
  }

  /// Removes a media path from a group
  Future<void> removeItemFromGroup(String groupId, String path) =>
      removeItemsFromGroup(groupId, [path]);

  /// Removes multiple media paths from a group atomically
  Future<void> removeItemsFromGroup(String groupId, List<String> paths) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1 && paths.isNotEmpty) {
      final current = _groups[idx];
      final toRemove = paths.toSet();
      final initialCount = current.itemPaths.length;
      final updatedPaths = current.itemPaths.where((p) => !toRemove.contains(p)).toList();
      if (updatedPaths.length != initialCount) {
        _groups[idx] = current.copyWith(itemPaths: updatedPaths);
        await _saveToPrefs();
        notifyListeners();
      }
    }
  }

  /// Moves multiple media paths between groups atomically
  Future<void> moveItemsBetweenGroups({
    required String fromGroupId,
    required String toGroupId,
    required List<String> paths,
  }) async {
    if (fromGroupId == toGroupId) return;
    final fromIdx = _groups.indexWhere((g) => g.id == fromGroupId);
    final toIdx = _groups.indexWhere((g) => g.id == toGroupId);
    if (fromIdx != -1 && toIdx != -1 && paths.isNotEmpty) {
      final fromGroup = _groups[fromIdx];
      final toGroup = _groups[toIdx];
      final toRemove = paths.toSet();

      final updatedFromPaths = fromGroup.itemPaths.where((p) => !toRemove.contains(p)).toList();
      final updatedToPaths = List<String>.from(toGroup.itemPaths);
      for (final p in paths) {
        if (!updatedToPaths.contains(p)) {
          updatedToPaths.add(p);
        }
      }

      _groups[fromIdx] = fromGroup.copyWith(itemPaths: updatedFromPaths);
      _groups[toIdx] = toGroup.copyWith(itemPaths: updatedToPaths);
      await _saveToPrefs();
      notifyListeners();
    }
  }
}
