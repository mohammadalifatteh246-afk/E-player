/// Technical specifications for a video/audio container and its elementary streams
class MediaTechnicalReport {
  final String filePath;
  final String fileName;
  final String containerFormat;
  final int fileSizeBytes;
  final Duration duration;
  final double overallBitrateMbps;
  final DateTime dateModified;

  final VideoTrackTechnicalInfo videoTrack;
  final List<AudioTrackTechnicalInfo> audioTracks;
  final List<SubtitleTrackTechnicalInfo> subtitleTracks;

  final String activeHardwareDecoder;
  final String activeDemuxer;
  final int bufferSizeBytes;

  const MediaTechnicalReport({
    required this.filePath,
    required this.fileName,
    required this.containerFormat,
    required this.fileSizeBytes,
    required this.duration,
    required this.overallBitrateMbps,
    required this.dateModified,
    required this.videoTrack,
    required this.audioTracks,
    required this.subtitleTracks,
    this.activeHardwareDecoder = 'D3D11VA (HW+ Zero-Copy)',
    this.activeDemuxer = 'libmpv native demuxer',
    this.bufferSizeBytes = 268435456, // 256 MB
  });

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return 'Unknown size';
    final gb = fileSizeBytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(2)} GB';
    }
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Generates a complete diagnostic report in standard MediaInfo / NFO plain-text format
  String toPlainTextReport() {
    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln('E-PLAYER TECHNICAL MEDIA INSPECTOR REPORT');
    buffer.writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln('================================================================\n');

    buffer.writeln('GENERAL CONTAINER SPECIFICATIONS:');
    buffer.writeln('  File Name: $fileName');
    buffer.writeln('  Full Path: $filePath');
    buffer.writeln('  Container: $containerFormat');
    buffer.writeln('  File Size: $formattedFileSize ($fileSizeBytes bytes)');
    buffer.writeln('  Duration:  $formattedDuration');
    buffer.writeln('  Bitrate:   ${overallBitrateMbps.toStringAsFixed(2)} Mbps');
    buffer.writeln('  Modified:  ${dateModified.toIso8601String()}\n');

    buffer.writeln('VIDEO STREAM [Track #0:0]:');
    buffer.writeln('  Codec:     ${videoTrack.codecName} (${videoTrack.codecProfile})');
    buffer.writeln('  Geometry:  ${videoTrack.width}x${videoTrack.height} (${videoTrack.aspectRatio})');
    buffer.writeln('  Framerate: ${videoTrack.frameRate.toStringAsFixed(3)} FPS (${videoTrack.isVfr ? "VFR" : "CFR"})');
    buffer.writeln('  Bit Depth: ${videoTrack.bitDepth}-bit');
    buffer.writeln('  Format:    ${videoTrack.pixelFormat}');
    buffer.writeln('  Color:     ${videoTrack.colorPrimaries}');
    buffer.writeln('  Transfer:  ${videoTrack.transferCharacteristics}');
    buffer.writeln('  Matrix:    ${videoTrack.matrixCoefficients}');
    buffer.writeln('  HDR Spec:  ${videoTrack.hdrStandard}');
    buffer.writeln('  Max Luma:  ${videoTrack.maxLuminanceNits} nits (MaxFALL: ${videoTrack.maxFallNits} nits)\n');

    buffer.writeln('AUDIO STREAMS [Total ${audioTracks.length}]:');
    for (int i = 0; i < audioTracks.length; i++) {
      final a = audioTracks[i];
      buffer.writeln('  Track #${i + 1}: [${a.languageCode}] ${a.title}');
      buffer.writeln('    Codec:      ${a.codecName}');
      buffer.writeln('    Channels:   ${a.channelLayout} (${a.channelCount} channels)');
      buffer.writeln('    Sampling:   ${a.sampleRateHz} Hz');
      buffer.writeln('    Bitrate:    ${a.bitrateKbps} kbps');
      buffer.writeln('    Default:    ${a.isDefault ? "Yes" : "No"}');
    }
    buffer.writeln('');

    buffer.writeln('SUBTITLE STREAMS [Total ${subtitleTracks.length}]:');
    for (int i = 0; i < subtitleTracks.length; i++) {
      final s = subtitleTracks[i];
      buffer.writeln('  Track #${i + 1}: [${s.languageCode}] ${s.title}');
      buffer.writeln('    Format:     ${s.codecFormat}');
      buffer.writeln('    Default:    ${s.isDefault ? "Yes" : "No"}');
      buffer.writeln('    Forced:     ${s.isForced ? "Yes" : "No"}');
    }
    buffer.writeln('');

    buffer.writeln('RENDER PIPELINE & HARDWARE DECODING:');
    buffer.writeln('  Decoder:   $activeHardwareDecoder');
    buffer.writeln('  Demuxer:   $activeDemuxer');
    buffer.writeln('  Ring Buffer: ${(bufferSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB');
    buffer.writeln('================================================================');

    return buffer.toString();
  }
}

class VideoTrackTechnicalInfo {
  final String streamIndex;
  final String codecName;
  final String codecProfile;
  final int width;
  final int height;
  final String aspectRatio;
  final double frameRate;
  final bool isVfr;
  final int bitDepth;
  final String pixelFormat;
  final String colorPrimaries;
  final String transferCharacteristics;
  final String matrixCoefficients;
  final String hdrStandard;
  final int maxLuminanceNits;
  final int maxFallNits;
  final double bitrateMbps;

  const VideoTrackTechnicalInfo({
    this.streamIndex = '#0:0',
    required this.codecName,
    required this.codecProfile,
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.frameRate,
    this.isVfr = false,
    required this.bitDepth,
    required this.pixelFormat,
    required this.colorPrimaries,
    required this.transferCharacteristics,
    required this.matrixCoefficients,
    required this.hdrStandard,
    this.maxLuminanceNits = 1000,
    this.maxFallNits = 400,
    required this.bitrateMbps,
  });

  bool get is4K => width >= 3840 || height >= 2160;
  bool get isHDR => hdrStandard != 'SDR BT.709' && bitDepth >= 10;
}

class AudioTrackTechnicalInfo {
  final String streamIndex;
  final String codecName;
  final String languageCode;
  final String title;
  final int channelCount;
  final String channelLayout;
  final int sampleRateHz;
  final int bitrateKbps;
  final bool isDefault;

  const AudioTrackTechnicalInfo({
    required this.streamIndex,
    required this.codecName,
    required this.languageCode,
    required this.title,
    required this.channelCount,
    required this.channelLayout,
    required this.sampleRateHz,
    required this.bitrateKbps,
    this.isDefault = false,
  });
}

class SubtitleTrackTechnicalInfo {
  final String streamIndex;
  final String codecFormat;
  final String languageCode;
  final String title;
  final bool isDefault;
  final bool isForced;

  const SubtitleTrackTechnicalInfo({
    required this.streamIndex,
    required this.codecFormat,
    required this.languageCode,
    required this.title,
    this.isDefault = false,
    this.isForced = false,
  });
}
