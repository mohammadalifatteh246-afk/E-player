/// Supported digital audio extraction formats for CDDA ripping (VLC transcode parity).
enum AudioRipFormat {
  flac(
    label: 'FLAC Lossless',
    codec: 'flac',
    extension: 'flac',
    bitrateKbps: 0,
    isLossless: true,
  ),
  mp3(
    label: 'MP3 High Quality',
    codec: 'libmp3lame',
    extension: 'mp3',
    bitrateKbps: 320,
    isLossless: false,
  ),
  aac(
    label: 'AAC / M4A',
    codec: 'aac',
    extension: 'm4a',
    bitrateKbps: 256,
    isLossless: false,
  ),
  wav(
    label: 'WAV Uncompressed (16-bit 44.1kHz)',
    codec: 'pcm_s16le',
    extension: 'wav',
    bitrateKbps: 0,
    isLossless: true,
  ),
  opus(
    label: 'Opus Modern',
    codec: 'libopus',
    extension: 'opus',
    bitrateKbps: 160,
    isLossless: false,
  );

  final String label;
  final String codec;
  final String extension;
  final int bitrateKbps;
  final bool isLossless;

  const AudioRipFormat({
    required this.label,
    required this.codec,
    required this.extension,
    required this.bitrateKbps,
    required this.isLossless,
  });
}

/// Information about an individual track on an Audio CD disc.
class CdTrackInfo {
  final int trackNumber; // 1-based (Track 1, Track 2...)
  final String title;
  final String artist;
  final Duration startOffset; // Start timestamp relative to audio image
  final Duration duration;
  final int startSector; // Red Book sector frame (75 fps)
  bool isSelected;

  CdTrackInfo({
    required this.trackNumber,
    required this.title,
    required this.artist,
    required this.startOffset,
    required this.duration,
    this.startSector = 0,
    this.isSelected = true,
  });

  String get formattedStart => _formatDuration(startOffset);
  String get formattedDuration => _formatDuration(duration);

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'trackNumber': trackNumber,
        'title': title,
        'artist': artist,
        'startOffsetMs': startOffset.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'startSector': startSector,
        'isSelected': isSelected,
      };

  factory CdTrackInfo.fromJson(Map<String, dynamic> json) => CdTrackInfo(
        trackNumber: json['trackNumber'] as int,
        title: json['title'] as String,
        artist: json['artist'] as String,
        startOffset: Duration(milliseconds: json['startOffsetMs'] as int),
        duration: Duration(milliseconds: json['durationMs'] as int),
        startSector: json['startSector'] as int? ?? 0,
        isSelected: json['isSelected'] as bool? ?? true,
      );
}

/// Metadata and track collection of an Audio CD disc or image rip.
class AudioCdDiscInfo {
  final String albumTitle;
  final String artist;
  final String? genre;
  final String? releaseYear;
  final String? audioSourcePath;
  final String? cueSheetPath;
  final List<CdTrackInfo> tracks;

  const AudioCdDiscInfo({
    required this.albumTitle,
    required this.artist,
    this.genre,
    this.releaseYear,
    this.audioSourcePath,
    this.cueSheetPath,
    required this.tracks,
  });

  Duration get totalDuration => tracks.fold(Duration.zero, (prev, t) => prev + t.duration);

  String get formattedTotalDuration {
    final d = totalDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'albumTitle': albumTitle,
        'artist': artist,
        'genre': genre,
        'releaseYear': releaseYear,
        'audioSourcePath': audioSourcePath,
        'cueSheetPath': cueSheetPath,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory AudioCdDiscInfo.fromJson(Map<String, dynamic> json) => AudioCdDiscInfo(
        albumTitle: json['albumTitle'] as String,
        artist: json['artist'] as String,
        genre: json['genre'] as String?,
        releaseYear: json['releaseYear'] as String?,
        audioSourcePath: json['audioSourcePath'] as String?,
        cueSheetPath: json['cueSheetPath'] as String?,
        tracks: (json['tracks'] as List<dynamic>?)
                ?.map((t) => CdTrackInfo.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Operational state of the CDDA extraction ripper engine.
enum CdRipStatus {
  idle,
  ripping,
  completed,
  cancelled,
  error,
}

/// Real-time progress update during Audio CD batch extraction.
class CdRipProgress {
  final CdRipStatus status;
  final int currentTrackIndex; // 1-based index among selected tracks
  final int totalSelectedTracks;
  final String currentTrackTitle;
  final double progressPercent; // 0.0 to 100.0
  final double speedMultiplier; // e.g. 18.5x
  final int elapsedSeconds;
  final String? errorMessage;

  const CdRipProgress({
    this.status = CdRipStatus.idle,
    this.currentTrackIndex = 0,
    this.totalSelectedTracks = 0,
    this.currentTrackTitle = '',
    this.progressPercent = 0.0,
    this.speedMultiplier = 1.0,
    this.elapsedSeconds = 0,
    this.errorMessage,
  });

  bool get isRipping => status == CdRipStatus.ripping;
  bool get isCompleted => status == CdRipStatus.completed;
  bool get isCancelled => status == CdRipStatus.cancelled;
  bool get hasError => status == CdRipStatus.error;
}
