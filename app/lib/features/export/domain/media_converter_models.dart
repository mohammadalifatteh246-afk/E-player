/// Supported container formats for Media Transcoding and Audio Extraction (VLC sout transcode parity).
enum TranscodeFormat {
  mp4('MP4 (H.264 / AAC)', 'Universal video format compatible with all modern devices', '.mp4'),
  mp3('MP3 (Audio Extraction)', 'Standard MP3 audio extraction (128k–320k)', '.mp3', isAudioOnly: true),
  m4a('M4A / AAC (Audio Extraction)', 'High-fidelity AAC audio extraction', '.m4a', isAudioOnly: true),
  flac('FLAC (Lossless)', 'Lossless compressed audio format', '.flac', isAudioOnly: true),
  wav('WAV (PCM)', 'Uncompressed studio audio stream', '.wav', isAudioOnly: true),
  webm('WebM (VP9 / Opus)', 'Open-source web video container', '.webm'),
  mkv('MKV Remux (Passthrough)', 'Lossless stream remux without re-encoding', '.mkv');

  final String label;
  final String description;
  final String fileExtension;
  final bool isAudioOnly;

  const TranscodeFormat(
    this.label,
    this.description,
    this.fileExtension, {
    this.isAudioOnly = false,
  });
}

/// Transcoding profile specification.
class TranscodePreset {
  final String id;
  final String name;
  final TranscodeFormat format;
  final String? videoCodec; // 'libx264', 'libvpx-vp9', 'copy', null
  final String audioCodec; // 'libmp3lame', 'aac', 'flac', 'pcm_s16le', 'libopus', 'copy'
  final int audioBitrateKbps; // 128, 192, 256, 320
  final double? videoBitrateMbps; // 2.5, 5.0, 10.0, null
  final bool isAudioOnly;
  final bool isPassthrough;

  const TranscodePreset({
    required this.id,
    required this.name,
    required this.format,
    this.videoCodec,
    required this.audioCodec,
    this.audioBitrateKbps = 192,
    this.videoBitrateMbps,
    this.isAudioOnly = false,
    this.isPassthrough = false,
  });

  static const TranscodePreset mp3_320k = TranscodePreset(
    id: 'mp3_320k',
    name: 'MP3 High Quality (320 kbps)',
    format: TranscodeFormat.mp3,
    audioCodec: 'libmp3lame',
    audioBitrateKbps: 320,
    isAudioOnly: true,
  );

  static const TranscodePreset mp3_192k = TranscodePreset(
    id: 'mp3_192k',
    name: 'MP3 Standard (192 kbps)',
    format: TranscodeFormat.mp3,
    audioCodec: 'libmp3lame',
    audioBitrateKbps: 192,
    isAudioOnly: true,
  );

  static const TranscodePreset m4a_256k = TranscodePreset(
    id: 'm4a_256k',
    name: 'M4A / AAC High Fidelity (256 kbps)',
    format: TranscodeFormat.m4a,
    audioCodec: 'aac',
    audioBitrateKbps: 256,
    isAudioOnly: true,
  );

  static const TranscodePreset flacLossless = TranscodePreset(
    id: 'flac_lossless',
    name: 'FLAC Lossless Audio',
    format: TranscodeFormat.flac,
    audioCodec: 'flac',
    audioBitrateKbps: 1000,
    isAudioOnly: true,
  );

  static const TranscodePreset mp4H264 = TranscodePreset(
    id: 'mp4_h264',
    name: 'MP4 Universal (H.264 / AAC)',
    format: TranscodeFormat.mp4,
    videoCodec: 'libx264',
    audioCodec: 'aac',
    audioBitrateKbps: 192,
    videoBitrateMbps: 5.0,
  );

  static const TranscodePreset webmVp9 = TranscodePreset(
    id: 'webm_vp9',
    name: 'WebM (VP9 / Opus)',
    format: TranscodeFormat.webm,
    videoCodec: 'libvpx-vp9',
    audioCodec: 'libopus',
    audioBitrateKbps: 128,
    videoBitrateMbps: 4.0,
  );

  static const TranscodePreset mkvPassthrough = TranscodePreset(
    id: 'mkv_remux',
    name: 'MKV Remux (Lossless Passthrough)',
    format: TranscodeFormat.mkv,
    videoCodec: 'copy',
    audioCodec: 'copy',
    isPassthrough: true,
  );

  static const List<TranscodePreset> allPresets = [
    mp3_320k,
    mp3_192k,
    m4a_256k,
    flacLossless,
    mp4H264,
    webmVp9,
    mkvPassthrough,
  ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'format': format.name,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'audioBitrateKbps': audioBitrateKbps,
        'videoBitrateMbps': videoBitrateMbps,
        'isAudioOnly': isAudioOnly,
        'isPassthrough': isPassthrough,
      };

  factory TranscodePreset.fromJson(Map<String, dynamic> json) {
    final formatStr = json['format'] as String? ?? 'mp4';
    final format = TranscodeFormat.values.firstWhere(
      (e) => e.name == formatStr,
      orElse: () => TranscodeFormat.mp4,
    );
    return TranscodePreset(
      id: json['id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Custom Preset',
      format: format,
      videoCodec: json['videoCodec'] as String?,
      audioCodec: json['audioCodec'] as String? ?? 'copy',
      audioBitrateKbps: (json['audioBitrateKbps'] as num?)?.toInt() ?? 192,
      videoBitrateMbps: (json['videoBitrateMbps'] as num?)?.toDouble(),
      isAudioOnly: json['isAudioOnly'] as bool? ?? format.isAudioOnly,
      isPassthrough: json['isPassthrough'] as bool? ?? false,
    );
  }
}

/// Execution status of a media transcode task.
enum TranscodeTaskStatus {
  idle,
  running,
  paused,
  completed,
  failed,
  cancelled,
}

/// Active or completed media conversion job.
class TranscodeTask {
  final String id;
  final String sourcePath;
  final String outputPath;
  final TranscodePreset preset;
  TranscodeTaskStatus status;
  double progress; // 0.0 to 1.0
  double speedMultiplier; // e.g. 2.5x
  int elapsedSeconds;
  int etaSeconds;
  String? error;
  int bytesWritten;

  TranscodeTask({
    required this.id,
    required this.sourcePath,
    required this.outputPath,
    required this.preset,
    this.status = TranscodeTaskStatus.idle,
    this.progress = 0.0,
    this.speedMultiplier = 1.0,
    this.elapsedSeconds = 0,
    this.etaSeconds = 0,
    this.error,
    this.bytesWritten = 0,
  });

  int get progressPercent => (progress.clamp(0.0, 1.0) * 100).round();

  String get formattedSpeed => '${speedMultiplier.toStringAsFixed(1)}x';

  String get formattedElapsed {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get formattedEta {
    if (status == TranscodeTaskStatus.completed) return '00:00';
    if (etaSeconds <= 0) return '--:--';
    final m = (etaSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (etaSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
