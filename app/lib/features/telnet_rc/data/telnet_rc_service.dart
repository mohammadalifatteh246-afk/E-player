import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/telnet_rc_models.dart';

/// Full-featured Telnet / TCP Socket CLI Remote Control Server (VLC rc.c parity).
/// Binds to a local port (default 4212) and executes interactive CLI control commands.
class TelnetRcService extends ChangeNotifier {
  ServerSocket? _server;
  final List<Socket> _activeClients = [];
  final List<TelnetCommandLog> _logs = [];
  final StreamController<TelnetCommandLog> _logController =
      StreamController<TelnetCommandLog>.broadcast();

  TelnetServerStatus _status = const TelnetServerStatus();
  bool _isDisposed = false;

  // Callbacks wired to Player & App state
  TelnetPlayerSnapshot Function()? statusProvider;
  List<String> Function()? playlistProvider;
  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onStop;
  void Function(Duration target)? onSeek;
  void Function(double volume)? onSetVolume;
  VoidCallback? onStepFrame;
  void Function(String? ratio)? onSetAspectRatio;
  VoidCallback? onCycleAspectRatio;
  VoidCallback? onToggleFullscreen;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  void Function(String media, bool playImmediately)? onAddMedia;
  VoidCallback? onCycleAudioTrack;
  VoidCallback? onCycleSubtitleTrack;
  VoidCallback? onToggleABRepeat;
  VoidCallback? onClearPlaylist;

  TelnetServerStatus get status => _status;
  List<TelnetCommandLog> get logs => List.unmodifiable(_logs);
  Stream<TelnetCommandLog> get logStream => _logController.stream;
  bool get isRunning => _status.isRunning;
  int get activeClientsCount => _activeClients.length;

  static const String welcomeBanner =
      '+----[ Remote Control CLI Interface - E-Player v1.0 ]\r\n'
      '| Type `help` for interactive command listing.\r\n'
      '| Type `quit` to disconnect this terminal session.\r\n'
      '+----[ Ready ]\r\n'
      '> ';

  void _safeNotifyListeners() {
    if (!_isDisposed && hasListeners) {
      notifyListeners();
    }
  }

  /// Starts the TCP socket server on [preferredPort].
  /// Attempts up to 5 consecutive ports if busy.
  Future<bool> start({
    int preferredPort = 4212,
    bool loopbackOnly = true,
  }) async {
    if (_status.isRunning) return true;

    final bindAddress = loopbackOnly ? InternetAddress.loopbackIPv4 : InternetAddress.anyIPv4;
    int currentPort = preferredPort;
    ServerSocket? server;

    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        server = await ServerSocket.bind(bindAddress, currentPort);
        break;
      } catch (e) {
        debugPrint('[TelnetRcService] Port $currentPort occupied, trying next: $e');
        currentPort++;
      }
    }

    if (server == null) {
      debugPrint('[TelnetRcService] Failed to bind any port starting from $preferredPort');
      _addLog(
        TelnetLogDirection.system,
        'Failed to bind Telnet server on port $preferredPort',
      );
      return false;
    }

    _server = server;
    _status = _status.copyWith(
      isRunning: true,
      port: currentPort,
      host: bindAddress.address,
      activeClients: 0,
    );

    _addLog(
      TelnetLogDirection.system,
      'Telnet CLI Server listening on ${bindAddress.address}:$currentPort',
    );
    _safeNotifyListeners();

    server.listen(
      _handleNewClient,
      onError: (err) {
        _addLog(TelnetLogDirection.system, 'Server socket error: $err');
      },
      onDone: () {
        stop();
      },
    );

    return true;
  }

  /// Stops the TCP socket server and disconnects active clients
  Future<void> stop() async {
    if (!_status.isRunning && _server == null) return;

    _status = _status.copyWith(
      isRunning: false,
      activeClients: 0,
    );

    for (final client in List<Socket>.from(_activeClients)) {
      try {
        client.write('\r\nServer shutting down. Goodbye!\r\n');
        await client.flush();
        client.destroy();
      } catch (_) {}
    }
    _activeClients.clear();

    final s = _server;
    _server = null;
    try {
      await s?.close();
    } catch (_) {}

    _addLog(TelnetLogDirection.system, 'Telnet CLI Server stopped');
    _safeNotifyListeners();
  }

  /// Clears the terminal log buffer
  void clearLogs() {
    _logs.clear();
    _safeNotifyListeners();
  }

  void _handleNewClient(Socket client) {
    _activeClients.add(client);
    final clientEp = '${client.remoteAddress.address}:${client.remotePort}';

    _status = _status.copyWith(activeClients: _activeClients.length);
    _addLog(TelnetLogDirection.system, 'Client connected from $clientEp', clientAddress: clientEp);
    _safeNotifyListeners();

    // Send welcome banner
    client.write(welcomeBanner);

    client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) async {
            final trimmed = line.trim();
            if (trimmed.isEmpty) {
              client.write('> ');
              return;
            }

            final reply = await executeCommand(trimmed, clientAddress: clientEp);
            if (trimmed.toLowerCase() == 'quit' || trimmed.toLowerCase() == 'logout') {
              client.write('Bye!\r\n');
              await client.flush();
              client.destroy();
              return;
            }

            if (trimmed.toLowerCase() == 'shutdown') {
              client.write('Shutting down server. Goodbye!\r\n');
              await client.flush();
              await stop();
              return;
            }

            client.write('$reply\r\n> ');
          },
          onError: (err) {
            _addLog(TelnetLogDirection.system, 'Client error ($clientEp): $err',
                clientAddress: clientEp);
            _removeClient(client, clientEp);
          },
          onDone: () {
            _removeClient(client, clientEp);
          },
          cancelOnError: true,
        );
  }

  void _removeClient(Socket client, String clientEp) {
    _activeClients.remove(client);
    _status = _status.copyWith(activeClients: _activeClients.length);
    _addLog(TelnetLogDirection.system, 'Client disconnected ($clientEp)', clientAddress: clientEp);
    _safeNotifyListeners();
  }

  /// Executes a single command string and returns the terminal reply text.
  /// Also callable directly from the UI without an open TCP socket.
  Future<String> executeCommand(String rawCommand, {String? clientAddress}) async {
    final trimmed = rawCommand.trim();
    if (trimmed.isEmpty) return '';

    _status = _status.copyWith(
      totalCommandsProcessed: _status.totalCommandsProcessed + 1,
    );

    _addLog(
      TelnetLogDirection.incoming,
      trimmed,
      clientAddress: clientAddress ?? 'Local UI',
    );

    final parts = trimmed.split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    final reply = await _dispatchCommand(cmd, args);

    _addLog(
      TelnetLogDirection.outgoing,
      reply,
      clientAddress: clientAddress ?? 'Local UI',
    );

    _safeNotifyListeners();
    return reply;
  }

  Future<String> _dispatchCommand(String cmd, List<String> args) async {
    final snapshot = statusProvider?.call() ??
        const TelnetPlayerSnapshot(
          isPlaying: false,
          title: 'Idle',
          position: Duration.zero,
          duration: Duration.zero,
          volume: 100.0,
        );

    switch (cmd) {
      case 'help':
      case '?':
        return _buildHelpText();

      case 'play':
        onPlay?.call();
        return 'status: playing';

      case 'pause':
        onPause?.call();
        return snapshot.isPlaying ? 'status: paused' : 'status: playing';

      case 'stop':
        onStop?.call();
        return 'status: stopped';

      case 'is_playing':
        return snapshot.isPlaying ? '1' : '0';

      case 'status':
        return snapshot.toVlcStatusString();

      case 'get_time':
        return '${snapshot.position.inSeconds}';

      case 'get_length':
        return '${snapshot.duration.inSeconds}';

      case 'get_title':
        return snapshot.title;

      case 'seek':
        if (args.isEmpty) return 'Error: seek requires seconds, relative offset (+10/-10) or percentage (50%)';
        final seekArg = args.first;
        Duration target = snapshot.position;

        if (seekArg.endsWith('%')) {
          final pct = double.tryParse(seekArg.replaceAll('%', ''));
          if (pct != null && snapshot.duration > Duration.zero) {
            target = Duration(milliseconds: ((pct / 100.0) * snapshot.duration.inMilliseconds).round());
          }
        } else if (seekArg.startsWith('+')) {
          final deltaSec = int.tryParse(seekArg.substring(1)) ?? 0;
          target = snapshot.position + Duration(seconds: deltaSec);
        } else if (seekArg.startsWith('-')) {
          final deltaSec = int.tryParse(seekArg.substring(1)) ?? 0;
          target = snapshot.position - Duration(seconds: deltaSec);
        } else {
          final absSec = int.tryParse(seekArg);
          if (absSec != null) {
            target = Duration(seconds: absSec);
          }
        }

        if (target < Duration.zero) target = Duration.zero;
        if (snapshot.duration > Duration.zero && target > snapshot.duration) {
          target = snapshot.duration;
        }

        onSeek?.call(target);
        return 'seek: ${snapshot.formatDuration(target)} (${target.inSeconds}s)';

      case 'step':
      case 'frame_step':
        onStepFrame?.call();
        return 'step: advanced 1 frame';

      case 'volume':
        if (args.isEmpty) {
          return 'volume: ${snapshot.volume.round()}%';
        }
        final vol = double.tryParse(args.first);
        if (vol != null) {
          final clamped = vol.clamp(0.0, 300.0);
          onSetVolume?.call(clamped);
          return 'volume: ${clamped.round()}%';
        }
        return 'Error: volume must be a number between 0 and 300';

      case 'volup':
        final step = args.isNotEmpty ? (double.tryParse(args.first) ?? 5.0) : 5.0;
        final newVol = (snapshot.volume + step).clamp(0.0, 300.0);
        onSetVolume?.call(newVol);
        return 'volume: ${newVol.round()}%';

      case 'voldown':
        final step = args.isNotEmpty ? (double.tryParse(args.first) ?? 5.0) : 5.0;
        final newVol = (snapshot.volume - step).clamp(0.0, 300.0);
        onSetVolume?.call(newVol);
        return 'volume: ${newVol.round()}%';

      case 'mute':
        final targetVol = snapshot.isMuted ? 100.0 : 0.0;
        onSetVolume?.call(targetVol);
        return snapshot.isMuted ? 'mute: unmuted (100%)' : 'mute: muted (0%)';

      case 'aspect':
        if (args.isNotEmpty) {
          final ratio = args.first;
          onSetAspectRatio?.call(ratio);
          return 'aspect: $ratio';
        }
        onCycleAspectRatio?.call();
        return 'aspect: cycled';

      case 'fullscreen':
        onToggleFullscreen?.call();
        return 'fullscreen: toggled';

      case 'atrack':
        onCycleAudioTrack?.call();
        return 'audio track: cycled';

      case 'strack':
        onCycleSubtitleTrack?.call();
        return 'subtitle track: cycled';

      case 'ab_repeat':
        onToggleABRepeat?.call();
        return 'ab_repeat: toggled';

      case 'next':
        onNext?.call();
        return 'playlist: next';

      case 'prev':
        onPrevious?.call();
        return 'playlist: previous';

      case 'add':
        if (args.isEmpty) return 'Error: add requires a media path or URL';
        final media = args.join(' ');
        onAddMedia?.call(media, true);
        return 'added and playing: $media';

      case 'enqueue':
        if (args.isEmpty) return 'Error: enqueue requires a media path or URL';
        final media = args.join(' ');
        onAddMedia?.call(media, false);
        return 'enqueued: $media';

      case 'playlist':
        final playlist = playlistProvider?.call() ?? [];
        if (playlist.isEmpty) return '( empty playlist )';
        final buffer = StringBuffer('+----[ Playlist Items ]\r\n');
        for (int i = 0; i < playlist.length; i++) {
          final marker = (playlist[i] == snapshot.title) ? '* ' : '  ';
          buffer.writeln('$marker${i + 1}. ${playlist[i]}');
        }
        buffer.write('+----[ End of playlist ]');
        return buffer.toString();

      case 'clear':
        onClearPlaylist?.call();
        return 'playlist: cleared';

      case 'info':
        return '+----[ Stream Info ]\r\n'
            '| Title: ${snapshot.title}\r\n'
            '| Duration: ${snapshot.formatDuration(snapshot.duration)}\r\n'
            '| Position: ${snapshot.formatDuration(snapshot.position)}\r\n'
            '| Aspect Ratio: ${snapshot.aspectRatio}\r\n'
            '| Audio Track: ${snapshot.audioTrack}\r\n'
            '| Subtitle Track: ${snapshot.subtitleTrack}\r\n'
            '+----[ End Info ]';

      case 'quit':
      case 'logout':
        return 'Disconnecting session...';

      case 'shutdown':
        return 'Shutting down server...';

      default:
        return 'Unknown command `$cmd`. Type `help` for interactive command listing.';
    }
  }

  void _addLog(TelnetLogDirection direction, String text, {String? clientAddress}) {
    if (_isDisposed) return;
    final entry = TelnetCommandLog(
      timestamp: DateTime.now(),
      direction: direction,
      text: text,
      clientAddress: clientAddress,
    );

    _logs.add(entry);
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
    if (!_logController.isClosed) {
      _logController.add(entry);
    }
  }

  String _buildHelpText() {
    return '+----[ VLC rc.c Remote Control CLI Commands ]\r\n'
        '| Playback:\r\n'
        '|   play                  Start/resume playback\r\n'
        '|   pause                 Toggle playback pause\r\n'
        '|   stop                  Stop media playback\r\n'
        '|   is_playing            Returns 1 if playing, 0 if paused\r\n'
        '|   status                Print VLC formatted status line\r\n'
        '|\r\n'
        '| Navigation & Seeking:\r\n'
        '|   seek <sec|+delta|-delta|pct%>  Seek (e.g. seek 90, seek +10, seek 50%)\r\n'
        '|   step / frame_step     Advance playback by exactly 1 video frame\r\n'
        '|   next / prev           Skip to next or previous playlist item\r\n'
        '|\r\n'
        '| Volume & Audio (0-300% boost):\r\n'
        '|   volume [<0..300>]     Get or set volume level\r\n'
        '|   volup [<delta>]       Increase volume by delta (default 5%)\r\n'
        '|   voldown [<delta>]     Decrease volume by delta (default 5%)\r\n'
        '|   mute                  Toggle audio mute\r\n'
        '|\r\n'
        '| Video & Tracks:\r\n'
        '|   aspect [<ratio>]      Set or cycle aspect ratio (e.g. 16:9, 4:3)\r\n'
        '|   fullscreen            Toggle fullscreen mode\r\n'
        '|   atrack / strack       Cycle audio or subtitle tracks\r\n'
        '|   ab_repeat             Toggle A-B repeat loop\r\n'
        '|\r\n'
        '| Queries & Playlist:\r\n'
        '|   get_time              Current playback position in seconds\r\n'
        '|   get_length            Total media duration in seconds\r\n'
        '|   get_title             Currently playing media title\r\n'
        '|   add <url|path>        Add item and play immediately\r\n'
        '|   enqueue <url|path>    Add item to end of playlist\r\n'
        '|   playlist              List all items in current playlist\r\n'
        '|   clear                 Clear playlist\r\n'
        '|   info                  Detailed media and track information\r\n'
        '|\r\n'
        '| Session:\r\n'
        '|   help / ?              Show this help menu\r\n'
        '|   quit / logout         Disconnect this terminal session\r\n'
        '|   shutdown              Stop the remote control server\r\n'
        '+----[ End of Help ]';
  }

  @override
  void dispose() {
    _isDisposed = true;
    stop();
    _logController.close();
    super.dispose();
  }
}
