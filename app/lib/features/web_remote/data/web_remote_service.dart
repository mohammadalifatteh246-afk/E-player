import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Status model for the E-Player Web Remote Control (VLC Parity)
class WebRemoteStatus {
  final bool isPlaying;
  final String title;
  final int positionMs;
  final int durationMs;
  final double volume; // 0.0 to 300.0
  final String aspectRatio;
  final bool isMuted;
  final String currentAudioTrack;
  final String currentSubtitleTrack;
  final String abRepeatState;

  const WebRemoteStatus({
    required this.isPlaying,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    required this.volume,
    required this.aspectRatio,
    required this.isMuted,
    required this.currentAudioTrack,
    required this.currentSubtitleTrack,
    required this.abRepeatState,
  });

  Map<String, dynamic> toJson() => {
    'isPlaying': isPlaying,
    'title': title,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'volume': volume,
    'aspectRatio': aspectRatio,
    'isMuted': isMuted,
    'currentAudioTrack': currentAudioTrack,
    'currentSubtitleTrack': currentSubtitleTrack,
    'abRepeatState': abRepeatState,
  };
}

/// Lightweight HTTP Web Remote Service (VLC --extraintf http parity)
/// Serves an embedded Cyberpunk mobile web app and REST endpoints over local Wi-Fi.
class WebRemoteService extends ChangeNotifier {
  HttpServer? _server;
  int _port = 8080;
  String _localIp = '127.0.0.1';
  bool _isRunning = false;
  String? overrideIp;
  int defaultPort = 8080;

  // Status provider callback
  WebRemoteStatus Function()? statusProvider;

  // Player action callbacks
  VoidCallback? onPlayPause;
  Function(int positionMs)? onSeek;
  Function(double volume)? onSetVolume;
  VoidCallback? onCycleAspectRatio;
  VoidCallback? onStepFrame;
  VoidCallback? onCycleABRepeat;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  VoidCallback? onToggleFullscreen;
  VoidCallback? onCycleSubtitle;
  VoidCallback? onCycleAudio;

  bool get isRunning => _isRunning;
  int get port => _port;
  String get localIp => _localIp;
  String get url => 'http://$_localIp:$_port';

  /// Starts the HTTP server on [port]. If [port] is busy, increments port up to 5 times.
  Future<bool> start({int? port}) async {
    if (_isRunning) return true;

    _localIp = overrideIp ?? await detectLocalIp();
    int currentPort = port ?? defaultPort;
    HttpServer? server;

    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, currentPort);
        server.idleTimeout = null;
        _port = currentPort;
        break;
      } catch (e) {
        debugPrint('[WebRemoteService] Port $currentPort occupied, trying next: $e');
        currentPort++;
      }
    }

    if (server == null) {
      debugPrint('[WebRemoteService] Failed to bind any port starting from $currentPort');
      return false;
    }

    _server = server;
    _isRunning = true;
    _server!.listen(_handleRequest);
    notifyListeners();
    debugPrint('[WebRemoteService] Server active at $url');
    return true;
  }

  /// Stops the HTTP server.
  Future<void> stop() async {
    if (!_isRunning || _server == null) return;
    await _server!.close(force: true);
    _server = null;
    _isRunning = false;
    notifyListeners();
    debugPrint('[WebRemoteService] Server stopped');
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Detects local network IPv4 address (e.g. 192.168.x.x, 10.x.x.x)
  static Future<String> detectLocalIp({Duration timeout = const Duration(milliseconds: 500)}) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      ).timeout(timeout);

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              !addr.address.startsWith('169.254') &&
              !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('[WebRemoteService] IP detection error or timeout: $e');
    }
    return '127.0.0.1';
  }

  void _handleRequest(HttpRequest request) async {
    // Add CORS headers for web remote clients
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      if (path == '/' || path == '/index.html') {
        _serveWebRemoteHtml(request);
      } else if (path == '/api/status') {
        _serveStatus(request);
      } else if (path.startsWith('/api/playback/')) {
        _handlePlaybackAction(request, path);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e) {
      debugPrint('[WebRemoteService] Request error ($path): $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error: $e');
      await request.response.close();
    }
  }

  void _serveStatus(HttpRequest request) async {
    final status = statusProvider?.call() ??
        const WebRemoteStatus(
          isPlaying: false,
          title: 'No media playing',
          positionMs: 0,
          durationMs: 0,
          volume: 100.0,
          aspectRatio: '16:9',
          isMuted: false,
          currentAudioTrack: 'Default',
          currentSubtitleTrack: 'None',
          abRepeatState: 'Off',
        );

    request.response.headers.contentType = ContentType.json;
    request.response.statusCode = HttpStatus.ok;
    request.response.write(jsonEncode(status.toJson()));
    await request.response.close();
  }

  void _handlePlaybackAction(HttpRequest request, String path) async {
    final action = path.replaceFirst('/api/playback/', '');

    switch (action) {
      case 'play-pause':
        onPlayPause?.call();
        break;
      case 'seek':
        final posParam = request.uri.queryParameters['position'];
        if (posParam != null) {
          final pos = int.tryParse(posParam);
          if (pos != null) onSeek?.call(pos);
        }
        break;
      case 'volume':
        final volParam = request.uri.queryParameters['value'];
        if (volParam != null) {
          final vol = double.tryParse(volParam);
          if (vol != null) onSetVolume?.call(vol.clamp(0.0, 300.0));
        }
        break;
      case 'step-frame':
        onStepFrame?.call();
        break;
      case 'crop':
        onCycleAspectRatio?.call();
        break;
      case 'ab-repeat':
        onCycleABRepeat?.call();
        break;
      case 'next':
        onNext?.call();
        break;
      case 'previous':
        onPrevious?.call();
        break;
      case 'toggle-fullscreen':
        onToggleFullscreen?.call();
        break;
      case 'subtitles':
        onCycleSubtitle?.call();
        break;
      case 'audio':
        onCycleAudio?.call();
        break;
      default:
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Unknown action: $action');
        await request.response.close();
        return;
    }

    // Return updated status immediately
    _serveStatus(request);
  }

  void _serveWebRemoteHtml(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.statusCode = HttpStatus.ok;
    request.response.write(_embeddedCyberpunkHtml);
    await request.response.close();
  }

  static const String _embeddedCyberpunkHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>E-Player Web Remote</title>
  <style>
    :root {
      --bg: #050B16;
      --surface: #0D1728;
      --surface-elevated: #12213A;
      --primary: #00E5FF;
      --accent: #E741FF;
      --text: #F5F8FF;
      --text-muted: #8A9BB5;
      --green: #22C55E;
      --amber: #F59E0B;
      --red: #EF4444;
      --border: #1B3556;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-tap-highlight-color: transparent; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 16px;
    }
    .header {
      width: 100%;
      max-width: 420px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
    }
    .brand {
      font-size: 20px;
      font-weight: 800;
      color: var(--primary);
      text-transform: uppercase;
      letter-spacing: 1.5px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .live-badge {
      font-size: 11px;
      background: rgba(0, 229, 255, 0.15);
      color: var(--primary);
      border: 1px solid var(--primary);
      border-radius: 12px;
      padding: 3px 8px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 5px;
    }
    .dot { width: 6px; height: 6px; background: var(--primary); border-radius: 50%; box-shadow: 0 0 8px var(--primary); }
    .card {
      width: 100%;
      max-width: 420px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 20px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
      margin-bottom: 16px;
    }
    .title {
      font-size: 18px;
      font-weight: 700;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-bottom: 12px;
      text-align: center;
    }
    .progress-container { margin: 16px 0; }
    .slider {
      width: 100%;
      appearance: none;
      height: 6px;
      background: #1B3556;
      border-radius: 3px;
      outline: none;
    }
    .slider::-webkit-slider-thumb {
      appearance: none;
      width: 18px;
      height: 18px;
      border-radius: 50%;
      background: var(--primary);
      cursor: pointer;
      box-shadow: 0 0 10px var(--primary);
    }
    .time-labels {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 6px;
    }
    .controls-row {
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 16px;
      margin: 16px 0;
    }
    .btn {
      background: var(--surface-elevated);
      border: 1px solid var(--border);
      color: var(--text);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .btn:active { transform: scale(0.92); filter: brightness(1.2); }
    .btn-sm { width: 44px; height: 44px; font-size: 16px; }
    .btn-lg { width: 68px; height: 68px; font-size: 28px; background: rgba(0, 229, 255, 0.15); border-color: var(--primary); color: var(--primary); box-shadow: 0 0 16px rgba(0, 229, 255, 0.3); }
    .volume-container { margin-top: 20px; }
    .vol-header { display: flex; justify-content: space-between; font-size: 13px; font-weight: 600; margin-bottom: 8px; }
    .vol-slider {
      width: 100%;
      appearance: none;
      height: 8px;
      background: #1B3556;
      border-radius: 4px;
      outline: none;
    }
    .vol-slider::-webkit-slider-thumb {
      appearance: none;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: var(--green);
      cursor: pointer;
      box-shadow: 0 0 10px var(--green);
    }
    .grid-actions {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      width: 100%;
      max-width: 420px;
    }
    .action-chip {
      background: var(--surface);
      border: 1px solid var(--border);
      color: var(--text);
      padding: 12px 8px;
      border-radius: 12px;
      text-align: center;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
    }
    .action-chip:active { background: var(--surface-elevated); border-color: var(--primary); }
    .chip-val { font-size: 11px; color: var(--primary); }
  </style>
</head>
<body>
  <div class="header">
    <div class="brand">⚡ E-PLAYER</div>
    <div class="live-badge"><div class="dot"></div> Wi-Fi Remote</div>
  </div>

  <div class="card">
    <div class="title" id="trackTitle">Loading playback...</div>

    <div class="progress-container">
      <input type="range" class="slider" id="seekBar" min="0" max="100" value="0">
      <div class="time-labels">
        <span id="elapsedTime">00:00</span>
        <span id="remainingTime">00:00</span>
      </div>
    </div>

    <div class="controls-row">
      <button class="btn btn-sm" onclick="sendAction('previous')">⏮</button>
      <button class="btn btn-sm" onclick="sendAction('step-frame')">⏯+1</button>
      <button class="btn btn-lg" id="playBtn" onclick="sendAction('play-pause')">▶</button>
      <button class="btn btn-sm" onclick="sendAction('ab-repeat')">🔁</button>
      <button class="btn btn-sm" onclick="sendAction('next')">⏭</button>
    </div>

    <div class="volume-container">
      <div class="vol-header">
        <span>Volume Boost (0-300%)</span>
        <span id="volLabel" style="color: var(--green);">100%</span>
      </div>
      <input type="range" class="vol-slider" id="volSlider" min="0" max="300" value="100" oninput="onVolumeChange(this.value)">
    </div>
  </div>

  <div class="grid-actions">
    <div class="action-chip" onclick="sendAction('crop')">
      <span>Aspect Crop</span>
      <span class="chip-val" id="cropVal">16:9</span>
    </div>
    <div class="action-chip" onclick="sendAction('subtitles')">
      <span>Subtitles</span>
      <span class="chip-val" id="subVal">Cycle</span>
    </div>
    <div class="action-chip" onclick="sendAction('audio')">
      <span>Audio Track</span>
      <span class="chip-val" id="audioVal">Cycle</span>
    </div>
    <div class="action-chip" onclick="sendAction('toggle-fullscreen')">
      <span>Fullscreen</span>
      <span class="chip-val">⛶</span>
    </div>
    <div class="action-chip" onclick="seekRelative(-10)">
      <span>Rewind</span>
      <span class="chip-val">-10s</span>
    </div>
    <div class="action-chip" onclick="seekRelative(10)">
      <span>Forward</span>
      <span class="chip-val">+10s</span>
    </div>
  </div>

  <script>
    let currentPos = 0;
    let totalDuration = 0;
    let isUserScrubbing = false;

    function formatTime(ms) {
      if (!ms || ms <= 0) return "00:00";
      const totalSec = Math.floor(ms / 1000);
      const m = Math.floor(totalSec / 60);
      const s = totalSec % 60;
      return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
    }

    async function fetchStatus() {
      if (isUserScrubbing) return;
      try {
        const res = await fetch('/api/status');
        if (!res.ok) return;
        const data = await res.json();
        
        document.getElementById('trackTitle').innerText = data.title || "No Media Playing";
        document.getElementById('playBtn').innerText = data.isPlaying ? "⏸" : "▶";
        
        currentPos = data.positionMs || 0;
        totalDuration = data.durationMs || 0;

        if (totalDuration > 0) {
          document.getElementById('seekBar').max = totalDuration;
          document.getElementById('seekBar').value = currentPos;
          document.getElementById('elapsedTime').innerText = formatTime(currentPos);
          document.getElementById('remainingTime').innerText = "-" + formatTime(totalDuration - currentPos);
        }

        const vol = Math.round(data.volume || 100);
        document.getElementById('volSlider').value = vol;
        updateVolColor(vol);

        document.getElementById('cropVal').innerText = data.aspectRatio || "16:9";
      } catch(e) {}
    }

    function updateVolColor(vol) {
      const label = document.getElementById('volLabel');
      label.innerText = vol + "%";
      if (vol <= 100) {
        label.style.color = "var(--green)";
      } else if (vol <= 200) {
        label.style.color = "var(--amber)";
      } else {
        label.style.color = "var(--red)";
      }
    }

    async function sendAction(action, query = '') {
      try {
        const url = '/api/playback/' + action + (query ? '?' + query : '');
        await fetch(url, { method: 'POST' });
        fetchStatus();
      } catch(e) {}
    }

    function onVolumeChange(val) {
      updateVolColor(val);
      sendAction('volume', 'value=' + val);
    }

    function seekRelative(deltaSec) {
      const target = Math.max(0, currentPos + deltaSec * 1000);
      sendAction('seek', 'position=' + target);
    }

    const seekBar = document.getElementById('seekBar');
    seekBar.addEventListener('mousedown', () => isUserScrubbing = true);
    seekBar.addEventListener('touchstart', () => isUserScrubbing = true);
    seekBar.addEventListener('change', (e) => {
      isUserScrubbing = false;
      sendAction('seek', 'position=' + e.target.value);
    });

    setInterval(fetchStatus, 750);
    fetchStatus();
  </script>
</body>
</html>
''';
}
