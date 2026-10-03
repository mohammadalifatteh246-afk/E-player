import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/media_item.dart';

class TrashItem {
  final String originalPath;
  final String trashPath;
  final DateTime deletedAt;
  final int sizeBytes;

  TrashItem({
    required this.originalPath,
    required this.trashPath,
    required this.deletedAt,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'originalPath': originalPath,
        'trashPath': trashPath,
        'deletedAt': deletedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
        originalPath: json['originalPath'],
        trashPath: json['trashPath'],
        deletedAt: DateTime.parse(json['deletedAt']),
        sizeBytes: json['sizeBytes'] ?? 0,
      );
}

class TrashService extends ChangeNotifier {
  static const int retentionDays = 30;
  List<TrashItem> _items = [];
  
  List<TrashItem> get items => _items;
  
  int get totalTrashSize => _items.fold(0, (sum, item) => sum + item.sizeBytes);

  TrashService() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('trash_items');
    if (jsonStr != null) {
      final List decoded = jsonDecode(jsonStr);
      _items = decoded.map((e) => TrashItem.fromJson(e)).toList();
    }
    
    await _autoPurge();
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString('trash_items', jsonStr);
    notifyListeners();
  }

  Future<Directory> getTrashDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final trashDir = Directory(p.join(docDir.path, '.eplayer_trash'));
    if (!await trashDir.exists()) await trashDir.create(recursive: true);
    return trashDir;
  }

  Future<void> moveToTrash(MediaItem item) async {
    final sourceFile = File(item.path);
    if (!await sourceFile.exists()) return;

    final trashDir = await getTrashDirectory();
    final String destName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(item.path)}';
    final String destPath = p.join(trashDir.path, destName);
    
    // Move file
    await sourceFile.rename(destPath);
    
    final trashItem = TrashItem(
      originalPath: item.path,
      trashPath: destPath,
      deletedAt: DateTime.now(),
      sizeBytes: item.sizeBytes,
    );
    
    _items.add(trashItem);
    await _saveState();
  }

  Future<void> restore(TrashItem item) async {
    final trashFile = File(item.trashPath);
    if (await trashFile.exists()) {
      // Ensure original directory still exists
      final originalDir = Directory(p.dirname(item.originalPath));
      if (!await originalDir.exists()) await originalDir.create(recursive: true);
      
      await trashFile.rename(item.originalPath);
    }
    
    _items.removeWhere((i) => i.trashPath == item.trashPath);
    await _saveState();
  }

  Future<void> permanentDelete(TrashItem item) async {
    final trashFile = File(item.trashPath);
    if (await trashFile.exists()) {
      await trashFile.delete();
    }
    _items.removeWhere((i) => i.trashPath == item.trashPath);
    await _saveState();
  }

  Future<void> emptyTrash() async {
    for (var item in _items) {
      final trashFile = File(item.trashPath);
      if (await trashFile.exists()) await trashFile.delete();
    }
    _items.clear();
    await _saveState();
  }

  Future<void> _autoPurge() async {
    final now = DateTime.now();
    final expiredItems = _items.where((i) => now.difference(i.deletedAt).inDays >= retentionDays).toList();
    
    if (expiredItems.isEmpty) return;

    for (var item in expiredItems) {
      final trashFile = File(item.trashPath);
      if (await trashFile.exists()) await trashFile.delete();
    }
    
    _items.removeWhere((i) => expiredItems.contains(i));
    await _saveState();
  }
}
