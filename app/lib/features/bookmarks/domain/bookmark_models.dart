import 'package:flutter/foundation.dart';

/// Represents an intra-media chapter or interest bookmark with rich annotations.
/// Mirrors VLC's input_item_t bookmark markers and Qt's custom bookmarks dialog with extended metadata.
@immutable
class MediaBookmark {
  final String id;
  final String mediaId;
  final Duration position;
  final Duration? endPosition;
  final String label;
  final String? note;
  final String category;
  final String? colorHex;
  final DateTime createdAt;

  const MediaBookmark({
    required this.id,
    required this.mediaId,
    required this.position,
    this.endPosition,
    required this.label,
    this.note,
    this.category = 'general',
    this.colorHex,
    required this.createdAt,
  });

  int get timestampMs => position.inMilliseconds;
  int? get endTimestampMs => endPosition?.inMilliseconds;

  bool get isRange => endPosition != null && endPosition! > position;

  /// Returns MM:SS or HH:MM:SS
  String get formattedTime => _formatDuration(position);

  /// Returns formatted end time if range exists
  String? get formattedEndTime =>
      endPosition != null ? _formatDuration(endPosition!) : null;

  /// Formatted range string like [00:45 - 01:20] or single point [00:45]
  String get formattedRange {
    if (isRange) {
      return '$formattedTime - $formattedEndTime';
    }
    return formattedTime;
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
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
      if (endPosition != null) 'endTimestampMs': endTimestampMs,
      'label': label,
      if (note != null) 'note': note,
      'category': category,
      if (colorHex != null) 'colorHex': colorHex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MediaBookmark.fromJson(Map<String, dynamic> json) {
    return MediaBookmark(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String? ?? '',
      position: Duration(milliseconds: json['timestampMs'] as int? ?? 0),
      endPosition: json['endTimestampMs'] != null
          ? Duration(milliseconds: json['endTimestampMs'] as int)
          : null,
      label: json['label'] as String? ?? 'Bookmark',
      note: json['note'] as String?,
      category: json['category'] as String? ?? 'general',
      colorHex: json['colorHex'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  MediaBookmark copyWith({
    String? id,
    String? mediaId,
    Duration? position,
    Duration? endPosition,
    String? label,
    String? note,
    String? category,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return MediaBookmark(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      position: position ?? this.position,
      endPosition: endPosition ?? this.endPosition,
      label: label ?? this.label,
      note: note ?? this.note,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaBookmark &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          mediaId == other.mediaId &&
          position == other.position &&
          endPosition == other.endPosition &&
          label == other.label &&
          note == other.note &&
          category == other.category &&
          colorHex == other.colorHex;

  @override
  int get hashCode => Object.hash(
        id,
        mediaId,
        position,
        endPosition,
        label,
        note,
        category,
        colorHex,
      );

  @override
  String toString() =>
      'MediaBookmark(id: $id, time: $formattedRange, label: $label, category: $category)';
}
