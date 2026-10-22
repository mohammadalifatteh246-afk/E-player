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

  /// Removes an existing group
  Future<void> deleteGroup(String id) async {
    _groups.removeWhere((g) => g.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  /// Adds a media path to an existing group
  Future<void> addItemToGroup(String groupId, String path) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final current = _groups[idx];
      if (!current.itemPaths.contains(path)) {
        final updated = current.copyWith(
          itemPaths: [...current.itemPaths, path],
        );
        _groups[idx] = updated;
        await _saveToPrefs();
        notifyListeners();
      }
    }
  }

  /// Removes a media path from a group
  Future<void> removeItemFromGroup(String groupId, String path) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final current = _groups[idx];
      final updated = current.copyWith(
        itemPaths: current.itemPaths.where((p) => p != path).toList(),
      );
      _groups[idx] = updated;
      await _saveToPrefs();
      notifyListeners();
    }
  }
}
