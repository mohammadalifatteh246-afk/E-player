/// Quality stream format representation (e.g. 1080p, 720p, 480p, 360p, Audio Only).
class StreamFormat {
  final String qualityLabel;
  final String? resolution;
  final String mimeType;
  final String url;
  final bool isAudioOnly;
  final int? bitrate;

  const StreamFormat({
    required this.qualityLabel,
    this.resolution,
    required this.mimeType,
    required this.url,
    this.isAudioOnly = false,
    this.bitrate,
  });

  Map<String, dynamic> toJson() => {
        'qualityLabel': qualityLabel,
        'resolution': resolution,
        'mimeType': mimeType,
        'url': url,
        'isAudioOnly': isAudioOnly,
        'bitrate': bitrate,
      };

  factory StreamFormat.fromJson(Map<String, dynamic> json) {
    return StreamFormat(
      qualityLabel: json['qualityLabel'] as String? ?? 'Auto',
      resolution: json['resolution'] as String?,
      mimeType: json['mimeType'] as String? ?? 'video/mp4',
      url: json['url'] as String? ?? '',
      isAudioOnly: json['isAudioOnly'] as bool? ?? false,
      bitrate: (json['bitrate'] as num?)?.toInt(),
    );
  }
}

/// Metadata and resolved stream URLs for an online stream (YouTube or generic).
class OnlineStreamInfo {
  final String originalUrl;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final Duration? duration;
  final bool isYouTube;
  final List<StreamFormat> formats;
  final String resolvedStreamUrl;

  const OnlineStreamInfo({
    required this.originalUrl,
    required this.title,
    this.author,
    this.thumbnailUrl,
    this.duration,
    this.isYouTube = false,
    this.formats = const [],
    required this.resolvedStreamUrl,
  });

  StreamFormat? get bestFormat {
    if (formats.isEmpty) return null;
    return formats.firstWhere(
      (f) => !f.isAudioOnly,
      orElse: () => formats.first,
    );
  }

  OnlineStreamInfo copyWith({
    String? originalUrl,
    String? title,
    String? author,
    String? thumbnailUrl,
    Duration? duration,
    bool? isYouTube,
    List<StreamFormat>? formats,
    String? resolvedStreamUrl,
  }) {
    return OnlineStreamInfo(
      originalUrl: originalUrl ?? this.originalUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      isYouTube: isYouTube ?? this.isYouTube,
      formats: formats ?? this.formats,
      resolvedStreamUrl: resolvedStreamUrl ?? this.resolvedStreamUrl,
    );
  }
}

/// Lightweight recent stream history entry (strictly limited to max 5 in list).
class RecentStreamEntry {
  final String url;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final DateTime timestamp;

  const RecentStreamEntry({
    required this.url,
    required this.title,
    this.author,
    this.thumbnailUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'author': author,
        'thumbnailUrl': thumbnailUrl,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RecentStreamEntry.fromJson(Map<String, dynamic> json) {
    return RecentStreamEntry(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Stream',
      author: json['author'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
