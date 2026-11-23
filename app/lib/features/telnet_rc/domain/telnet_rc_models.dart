library;

/// Domain models for Telnet / TCP Socket CLI Remote Control (VLC rc.c Parity)

enum TelnetLogDirection {
  incoming,
  outgoing,
  system,
}

/// A single timestamped event or command log in the terminal session
class TelnetCommandLog {
  final DateTime timestamp;
  final TelnetLogDirection direction;
  final String text;
  final String? clientAddress;

  const TelnetCommandLog({
    required this.timestamp,
    required this.direction,
    required this.text,
    this.clientAddress,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'direction': direction.name,
        'text': text,
        'clientAddress': clientAddress,
      };

  factory TelnetCommandLog.fromJson(Map<String, dynamic> json) => TelnetCommandLog(
        timestamp: DateTime.parse(json['timestamp'] as String),
        direction: TelnetLogDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => TelnetLogDirection.system,
        ),
        text: json['text'] as String? ?? '',
        clientAddress: json['clientAddress'] as String?,
      );
}

/// Runtime state and health of the Telnet RC Server
class TelnetServerStatus {
  final bool isRunning;
  final int port;
  final String host;
  final int activeClients;
  final int totalCommandsProcessed;

  const TelnetServerStatus({
    this.isRunning = false,
    this.port = 4212,
    this.host = '127.0.0.1',
    this.activeClients = 0,
    this.totalCommandsProcessed = 0,
  });

  String get connectionEndpoint => '$host:$port';

  TelnetServerStatus copyWith({
    bool? isRunning,
    int? port,
    String? host,
    int? activeClients,
    int? totalCommandsProcessed,
  }) {
    return TelnetServerStatus(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      host: host ?? this.host,
      activeClients: activeClients ?? this.activeClients,
      totalCommandsProcessed: totalCommandsProcessed ?? this.totalCommandsProcessed,
    );
  }
}

/// Playback snapshot queried by `status`, `get_time`, etc.
class TelnetPlayerSnapshot {
  final bool isPlaying;
  final String title;
  final Duration position;
  final Duration duration;
  final double volume; // 0.0 - 300.0
  final bool isMuted;
  final String aspectRatio;
  final String audioTrack;
  final String subtitleTrack;

  const TelnetPlayerSnapshot({
    required this.isPlaying,
    required this.title,
    required this.position,
    required this.duration,
    required this.volume,
    this.isMuted = false,
    this.aspectRatio = 'default',
    this.audioTrack = 'default',
    this.subtitleTrack = 'none',
  });

  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String toVlcStatusString() {
    final stateStr = isPlaying ? 'playing' : 'paused';
    final posSec = position.inSeconds;
    final durSec = duration.inSeconds;
    final posFormatted = formatDuration(position);
    final durFormatted = formatDuration(duration);
    final volInt = volume.round();

    return '( state $stateStr ) ( title $title ) ( position $posSec/$durSec [$posFormatted/$durFormatted] ) ( volume $volInt% )';
  }
}
