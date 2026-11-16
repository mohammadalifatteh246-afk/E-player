import 'package:flutter/foundation.dart';

/// Active operational state of the Stream Recorder.
enum RecordingState {
  idle,
  recording,
  finalizing,
  error,
}

/// Container format options for dump recording (VLC sout-record parity).
enum RecordingFormat {
  auto('Auto (Source Native)', 'Picks TS for HLS/RTSP and MP4 for HTTP progressive'),
  ts('MPEG-TS (.ts)', 'Ideal for broadcast and live streams; survives abrupt termination'),
  mp4('MP4 (.mp4)', 'Widely compatible container for progressive streaming'),
  mkv('Matroska (.mkv)', 'Flexible container supporting all audio/video/sub codecs');

  final String label;
  final String description;

  const RecordingFormat(this.label, this.description);

  /// Resolves the file extension based on format or source URL.
  String extensionFor({String? sourceUrl}) {
    switch (this) {
      case RecordingFormat.ts:
        return 'ts';
      case RecordingFormat.mp4:
        return 'mp4';
      case RecordingFormat.mkv:
        return 'mkv';
      case RecordingFormat.auto:
        if (sourceUrl != null && sourceUrl.isNotEmpty) {
          final uri = Uri.tryParse(sourceUrl.toLowerCase());
          final path = uri?.path ?? '';
          if (path.endsWith('.m3u8') || sourceUrl.startsWith('rtsp:') || sourceUrl.startsWith('rtmp:') || path.endsWith('.ts')) {
            return 'ts';
          }
          if (path.endsWith('.mkv')) return 'mkv';
          if (path.endsWith('.webm')) return 'webm';
        }
        return 'mp4';
    }
  }
}

/// Configuration settings for stream recording.
@immutable
class RecordingConfig {
  final String? outputDirectory;
  final RecordingFormat format;
  final String fileNamePrefix;
  final bool autoAddToLibrary;
  final bool audioOnly;

  const RecordingConfig({
    this.outputDirectory,
    this.format = RecordingFormat.auto,
    this.fileNamePrefix = 'eplayer-record',
    this.autoAddToLibrary = true,
    this.audioOnly = false,
  });

  RecordingConfig copyWith({
    String? outputDirectory,
    RecordingFormat? format,
    String? fileNamePrefix,
    bool? autoAddToLibrary,
    bool? audioOnly,
  }) {
    return RecordingConfig(
      outputDirectory: outputDirectory ?? this.outputDirectory,
      format: format ?? this.format,
      fileNamePrefix: fileNamePrefix ?? this.fileNamePrefix,
      autoAddToLibrary: autoAddToLibrary ?? this.autoAddToLibrary,
      audioOnly: audioOnly ?? this.audioOnly,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outputDirectory': outputDirectory,
      'format': format.name,
      'fileNamePrefix': fileNamePrefix,
      'autoAddToLibrary': autoAddToLibrary,
      'audioOnly': audioOnly,
    };
  }

  factory RecordingConfig.fromJson(Map<String, dynamic> json) {
    RecordingFormat parseFormat(String? name) {
      return RecordingFormat.values.firstWhere(
        (e) => e.name == name,
        orElse: () => RecordingFormat.auto,
      );
    }

    return RecordingConfig(
      outputDirectory: json['outputDirectory'] as String?,
      format: parseFormat(json['format'] as String?),
      fileNamePrefix: (json['fileNamePrefix'] as String?) ?? 'eplayer-record',
      autoAddToLibrary: (json['autoAddToLibrary'] as bool?) ?? true,
      audioOnly: (json['audioOnly'] as bool?) ?? false,
    );
  }
}

/// Represents an ongoing or completed stream recording session.
class RecordingSession {
  final String id;
  final String filePath;
  final DateTime startTime;
  final Duration duration;
  final int byteSize;
  final RecordingState status;
  final String? mediaTitle;

  const RecordingSession({
    required this.id,
    required this.filePath,
    required this.startTime,
    this.duration = Duration.zero,
    this.byteSize = 0,
    required this.status,
    this.mediaTitle,
  });

  RecordingSession copyWith({
    String? id,
    String? filePath,
    DateTime? startTime,
    Duration? duration,
    int? byteSize,
    RecordingState? status,
    String? mediaTitle,
  }) {
    return RecordingSession(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      byteSize: byteSize ?? this.byteSize,
      status: status ?? this.status,
      mediaTitle: mediaTitle ?? this.mediaTitle,
    );
  }

  /// Formatted duration string (e.g. 01:24 or 01:15:30).
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Human-readable file size string (KB / MB / GB).
  String get formattedSize {
    if (byteSize <= 0) return '0.0 KB';
    if (byteSize < 1024 * 1024) {
      final kb = byteSize / 1024.0;
      return '${kb.toStringAsFixed(1)} KB';
    }
    if (byteSize < 1024 * 1024 * 1024) {
      final mb = byteSize / (1024.0 * 1024.0);
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = byteSize / (1024.0 * 1024.0 * 1024.0);
    return '${gb.toStringAsFixed(2)} GB';
  }
}
