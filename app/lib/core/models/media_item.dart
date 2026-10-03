import 'dart:convert';

class MediaItem {
  final String path;
  final String name;
  final String parentFolder;
  final int sizeBytes;
  final int durationMs;
  final int lastPositionMs;
  final bool isFavorite;
  final DateTime lastPlayed;

  const MediaItem({
    required this.path,
    required this.name,
    required this.parentFolder,
    this.sizeBytes = 0,
    this.durationMs = 0,
    this.lastPositionMs = 0,
    this.isFavorite = false,
    required this.lastPlayed,
  });

  MediaItem copyWith({
    String? path,
    String? name,
    String? parentFolder,
    int? sizeBytes,
    int? durationMs,
    int? lastPositionMs,
    bool? isFavorite,
    DateTime? lastPlayed,
  }) {
    return MediaItem(
      path: path ?? this.path,
      name: name ?? this.name,
      parentFolder: parentFolder ?? this.parentFolder,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationMs: durationMs ?? this.durationMs,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      isFavorite: isFavorite ?? this.isFavorite,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'parentFolder': parentFolder,
      'sizeBytes': sizeBytes,
      'durationMs': durationMs,
      'lastPositionMs': lastPositionMs,
      'isFavorite': isFavorite,
      'lastPlayed': lastPlayed.millisecondsSinceEpoch,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      path: map['path'] ?? '',
      name: map['name'] ?? '',
      parentFolder: map['parentFolder'] ?? '',
      sizeBytes: map['sizeBytes']?.toInt() ?? 0,
      durationMs: map['durationMs']?.toInt() ?? 0,
      lastPositionMs: map['lastPositionMs']?.toInt() ?? 0,
      isFavorite: map['isFavorite'] ?? false,
      lastPlayed: DateTime.fromMillisecondsSinceEpoch(map['lastPlayed'] ?? 0),
    );
  }

  String toJson() => json.encode(toMap());

  factory MediaItem.fromJson(String source) =>
      MediaItem.fromMap(json.decode(source));
}
