/// Domain models for Phase 11 Tokenized Wireless Casting & Streaming
/// Supporting multi-protocol sink discovery (Chromecast, AirPlay, DLNA, Miracast)
/// and real-time state synchronization.
library;

/// Supported Wireless Cast Protocols (Mirroring VLC's services_discovery plugins)
enum CastProtocol {
  chromecast('Chromecast V2', 'Google Cast Protocol', 0xFF19BFFF),
  airplay('AirPlay 2', 'Apple AirPlay RAOP', 0xFFE741FF),
  dlna('DLNA / UPnP', 'Universal Media Renderer (SSDP)', 0xFF00E676),
  miracast('Miracast Direct', 'Wi-Fi Display (WFD/RTSP)', 0xFFFFB300);

  final String label;
  final String description;
  final int colorHex;

  const CastProtocol(this.label, this.description, this.colorHex);
}

/// Transcoding profile negotiated during connection handshake (Mirroring VLC's libstream_out_transcode)
enum CastTranscodeProfile {
  directPassthrough(
    'Direct Passthrough',
    'Native H.264/AAC bitstream passthrough without re-encoding',
    0xFF00E676,
  ),
  audioRemux(
    'Audio Remux (AAC)',
    'Lossless video passthrough with DTS/AC3 -> AAC 256k transcoding',
    0xFF19BFFF,
  ),
  videoTranscode(
    'Real-time Transcode (H.264)',
    'On-the-fly HEVC/VP9 to H.264 hardware-accelerated transcoding',
    0xFFFFB300,
  ),
  fullRemux(
    'MPEG-TS Container Remux',
    'Container adaptation for legacy UPnP/DLNA renderers',
    0xFFE741FF,
  );

  final String label;
  final String description;
  final int colorHex;

  const CastTranscodeProfile(this.label, this.description, this.colorHex);
}

/// Connection state machine for active casting sessions
enum CastSessionState {
  disconnected,
  discovering,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Represents a discovered wireless network display target (Mirroring VLC's vlc_renderer_item_t)
class CastDevice {
  final String id;
  final String name;
  final CastProtocol protocol;
  final String model;
  final String ipAddress;
  final int signalPercentage;
  final String resolutionCapability;
  bool isConnected;
  bool isConnecting;
  final Map<String, dynamic>? metadata;

  CastDevice({
    required this.id,
    required this.name,
    required this.protocol,
    required this.model,
    required this.ipAddress,
    required this.signalPercentage,
    required this.resolutionCapability,
    this.isConnected = false,
    this.isConnecting = false,
    this.metadata,
  });

  CastDevice copyWith({
    String? id,
    String? name,
    CastProtocol? protocol,
    String? model,
    String? ipAddress,
    int? signalPercentage,
    String? resolutionCapability,
    bool? isConnected,
    bool? isConnecting,
    Map<String, dynamic>? metadata,
  }) {
    return CastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      model: model ?? this.model,
      ipAddress: ipAddress ?? this.ipAddress,
      signalPercentage: signalPercentage ?? this.signalPercentage,
      resolutionCapability: resolutionCapability ?? this.resolutionCapability,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Immutable snapshot of remote playback transport state
class CastPlaybackState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final String audioRoute;

  const CastPlaybackState({
    this.isPlaying = true,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 0.85,
    this.isMuted = false,
    this.audioRoute = 'tv',
  });

  CastPlaybackState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMuted,
    String? audioRoute,
  }) {
    return CastPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      audioRoute: audioRoute ?? this.audioRoute,
    );
  }
}

/// Active streaming session state with live pipeline telemetry (Mirroring VLC's sout_stream_t)
class CastSession {
  final CastDevice device;
  final String mediaTitle;
  final String mediaPath;
  final DateTime startedAt;
  final CastTranscodeProfile transcodeProfile;

  String? streamUrl;
  String? subtitleUrl;
  Duration position;
  Duration duration;
  bool isPlaying;
  double volume;
  bool isMuted;
  String audioRoute; // 'tv', 'device', 'bluetooth'
  double bitrateMbps;
  int pingMs;
  CastSessionState connectionState;

  CastSession({
    required this.device,
    required this.mediaTitle,
    required this.mediaPath,
    required this.startedAt,
    required this.transcodeProfile,
    this.streamUrl,
    this.subtitleUrl,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = true,
    this.volume = 0.85,
    this.isMuted = false,
    this.audioRoute = 'tv',
    this.bitrateMbps = 46.2,
    this.pingMs = 14,
    this.connectionState = CastSessionState.connected,
  });
}

/// Diagnostic metrics emitted per client streaming request
class StreamingClientTelemetry {
  final String clientIp;
  final String path;
  final int statusCode;
  final int bytesTransferred;
  final Duration duration;
  final DateTime timestamp;
  final String? rangeHeader;

  const StreamingClientTelemetry({
    required this.clientIp,
    required this.path,
    required this.statusCode,
    required this.bytesTransferred,
    required this.duration,
    required this.timestamp,
    this.rangeHeader,
  });

  @override
  String toString() =>
      'StreamingClientTelemetry($clientIp -> $path, status: $statusCode, bytes: $bytesTransferred, duration: ${duration.inMilliseconds}ms)';
}
