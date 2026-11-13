/// Represents an intra-media chapter or interest bookmark.
/// Mirrors VLC's input_item_t bookmark markers and Qt's custom bookmarks dialog.
class MediaBookmark {
  final String id;
  final String mediaId;
  final Duration position;
  final String label;
  final DateTime createdAt;

  const MediaBookmark({
    required this.id,
    required this.mediaId,
    required this.position,
    required this.label,
    required this.createdAt,
  });

  int get timestampMs => position.inMilliseconds;

  /// Returns MM:SS or HH:MM:SS
  String get formattedTime {
    final hours = position.inHours;
    final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'timestampMs': timestampMs,
      'label': label,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MediaBookmark.fromJson(Map<String, dynamic> json) {
    return MediaBookmark(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String,
      position: Duration(milliseconds: json['timestampMs'] as int? ?? 0),
      label: json['label'] as String? ?? 'Bookmark',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  MediaBookmark copyWith({
    String? id,
    String? mediaId,
    Duration? position,
    String? label,
    DateTime? createdAt,
  }) {
    return MediaBookmark(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      position: position ?? this.position,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
