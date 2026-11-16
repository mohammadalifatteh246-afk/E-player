import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/stream_recorder_models.dart';

/// Coordinates live stream recording, duration tracking, file sizing,
/// and libmpv backend stream dumping (VLC record.c parity).
class StreamRecorderController extends ChangeNotifier {
  RecordingConfig _config;
  RecordingSession? _currentSession;
  RecordingState _state = RecordingState.idle;
  Timer? _timer;
  Player? _player;

  String? _sourceUrl;
  String? _mediaTitle;

  StreamRecorderController({
    RecordingConfig? config,
    Player? player,
  })  : _config = config ?? const RecordingConfig() {
    _player = player;
  }

  // --- Getters ---
  RecordingConfig get config => _config;
  RecordingSession? get currentSession => _currentSession;
  RecordingState get state => _state;
  bool get isRecording => _state == RecordingState.recording;
  Duration get activeDuration => _currentSession?.duration ?? Duration.zero;
  int get activeByteSize => _currentSession?.byteSize ?? 0;
  String get activeFormattedDuration => _currentSession?.formattedDuration ?? '00:00';
  String get activeFormattedSize => _currentSession?.formattedSize ?? '0.0 KB';

  /// Attaches media player instance and current stream metadata.
  void attachPlayer(Player? player, {String? sourceUrl, String? mediaTitle}) {
    _player = player;
    _sourceUrl = sourceUrl;
    _mediaTitle = mediaTitle;
  }

  /// Updates recording configuration settings.
  void updateConfig(RecordingConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  /// Generates timestamped destination filename following VLC convention:
  /// `prefix-YYYY-MM-DD-HHhMMmSSs-Title.ext`
  String generateFilename({
    DateTime? now,
    String? mediaTitle,
    RecordingFormat? format,
    String? sourceUrl,
  }) {
    final timestamp = now ?? DateTime.now();
    final fmt = format ?? _config.format;
    final ext = fmt.extensionFor(sourceUrl: sourceUrl ?? _sourceUrl);

    final dateStr = '${timestamp.year.toString().padLeft(4, '0')}-'
        '${timestamp.month.toString().padLeft(2, '0')}-'
        '${timestamp.day.toString().padLeft(2, '0')}';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}h'
        '${timestamp.minute.toString().padLeft(2, '0')}m'
        '${timestamp.second.toString().padLeft(2, '0')}s';

    final title = (mediaTitle ?? _mediaTitle ?? 'Stream')
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    final cleanTitle = title.isEmpty ? 'Stream' : title;
    return '${_config.fileNamePrefix}-$dateStr-$timeStr-$cleanTitle.$ext';
  }

  /// Resolves target directory on disk for storing recorded files.
  Future<String> resolveOutputDirectory({String? mockDestinationDir}) async {
    if (mockDestinationDir != null && mockDestinationDir.isNotEmpty) {
      return mockDestinationDir;
    }
    if (_config.outputDirectory != null && _config.outputDirectory!.isNotEmpty) {
      return _config.outputDirectory!;
    }

    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final capturesDir = Directory(p.join(downloads.path, 'E-Player Captures'));
          if (!capturesDir.existsSync()) {
            capturesDir.createSync(recursive: true);
          }
          return capturesDir.path;
        }
      }
      final docs = await getApplicationDocumentsDirectory();
      final capturesDir = Directory(p.join(docs.path, 'Captures'));
      if (!capturesDir.existsSync()) {
        capturesDir.createSync(recursive: true);
      }
      return capturesDir.path;
    } catch (_) {
      return Directory.current.path;
    }
  }

  /// Starts live stream recording dump via libmpv `stream-record`.
  Future<String> startRecording({
    String? customPath,
    String? mediaTitle,
    String? sourceUrl,
    String? mockDestinationDir,
  }) async {
    if (_state == RecordingState.recording) {
      return _currentSession?.filePath ?? '';
    }

    _sourceUrl = sourceUrl ?? _sourceUrl;
    _mediaTitle = mediaTitle ?? _mediaTitle;

    String finalPath = customPath ?? '';
    if (finalPath.isEmpty) {
      final outDir = await resolveOutputDirectory(mockDestinationDir: mockDestinationDir);
      final filename = generateFilename(
        mediaTitle: _mediaTitle,
        format: _config.format,
        sourceUrl: _sourceUrl,
      );
      finalPath = p.join(outDir, filename);
    }

    final session = RecordingSession(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      filePath: finalPath,
      startTime: DateTime.now(),
      status: RecordingState.recording,
      mediaTitle: _mediaTitle,
    );

    _currentSession = session;
    _state = RecordingState.recording;

    // Apply to libmpv backend (stream-record property)
    try {
      final platform = _player?.platform as dynamic;
      await platform?.setProperty('stream-record', finalPath);
    } catch (e) {
      debugPrint('[StreamRecorder] Failed to set stream-record property: $e');
    }

    _startDurationTimer(finalPath);
    notifyListeners();
    return finalPath;
  }

  /// Stops stream recording dump, flushes file, and finalizes session.
  Future<RecordingSession?> stopRecording() async {
    if (_state != RecordingState.recording) return _currentSession;

    _state = RecordingState.finalizing;
    notifyListeners();

    _timer?.cancel();
    _timer = null;

    // Unset libmpv stream-record property to stop dump and close file
    try {
      final platform = _player?.platform as dynamic;
      await platform?.setProperty('stream-record', '');
    } catch (e) {
      debugPrint('[StreamRecorder] Failed to reset stream-record: $e');
    }

    int finalSize = _currentSession?.byteSize ?? 0;
    if (_currentSession != null) {
      try {
        final f = File(_currentSession!.filePath);
        if (f.existsSync()) {
          finalSize = f.lengthSync();
        }
      } catch (_) {}
    }

    final finishedSession = _currentSession?.copyWith(
      status: RecordingState.idle,
      byteSize: finalSize,
    );

    _currentSession = finishedSession;
    _state = RecordingState.idle;
    notifyListeners();
    return finishedSession;
  }

  /// Toggles between start and stop recording.
  Future<void> toggleRecording({
    String? mediaTitle,
    String? sourceUrl,
    String? mockDestinationDir,
  }) async {
    if (isRecording) {
      await stopRecording();
    } else {
      await startRecording(
        mediaTitle: mediaTitle,
        sourceUrl: sourceUrl,
        mockDestinationDir: mockDestinationDir,
      );
    }
  }

  /// Internal timer updating elapsed recording duration and disk file size.
  void _startDurationTimer(String targetPath) {
    _timer?.cancel();
    final start = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != RecordingState.recording) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(start);
      int size = 0;
      try {
        final file = File(targetPath);
        if (file.existsSync()) {
          size = file.lengthSync();
        }
      } catch (_) {}

      _currentSession = _currentSession?.copyWith(
        duration: elapsed,
        byteSize: size,
      );
      notifyListeners();
    });
  }

  /// Allows unit tests to advance duration and size without real timer or file IO.
  @visibleForTesting
  void tickForTesting(Duration duration, int byteSize) {
    _currentSession = _currentSession?.copyWith(
      duration: duration,
      byteSize: byteSize,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_state == RecordingState.recording) {
      try {
        final platform = _player?.platform as dynamic;
        platform?.setProperty('stream-record', '');
      } catch (_) {}
    }
    super.dispose();
  }
}
