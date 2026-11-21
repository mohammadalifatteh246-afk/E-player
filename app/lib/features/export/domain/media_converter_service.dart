import 'dart:async';
import 'package:flutter/foundation.dart';
import 'media_converter_models.dart';

/// Function signature for command execution abstraction (supports real ffmpeg or mock simulation)
typedef TranscodeExecutor = Future<void> Function(
  TranscodeTask task,
  void Function(double progress, double speed, int elapsed, int eta) onProgress,
  bool Function() isCancelled,
);

/// Transcoder service for high-speed media conversion, container remuxing,
/// and lossless/lossy audio extraction (VLC sout transcode parity).
class MediaConverterService extends ChangeNotifier {
  TranscodeTask? _activeTask;
  final List<TranscodeTask> _history = [];
  bool _isCancelled = false;
  TranscodeExecutor? customExecutor;

  TranscodeTask? get activeTask => _activeTask;
  List<TranscodeTask> get history => List.unmodifiable(_history);
  bool get isConverting => _activeTask?.status == TranscodeTaskStatus.running;

  /// Builds the command line parameters for the transcoding job
  List<String> buildFfmpegArguments(
    String sourcePath,
    String outputPath,
    TranscodePreset preset, {
    Duration? startTime,
    Duration? endTime,
  }) {
    final List<String> args = ['-y'];

    if (startTime != null && startTime > Duration.zero) {
      args.addAll(['-ss', _formatDuration(startTime)]);
    }
    if (endTime != null && endTime > Duration.zero) {
      args.addAll(['-to', _formatDuration(endTime)]);
    }

    args.addAll(['-i', sourcePath]);

    if (preset.isAudioOnly) {
      args.addAll([
        '-vn',
        '-c:a',
        preset.audioCodec,
        if (preset.audioBitrateKbps > 0 && preset.audioCodec != 'flac' && preset.audioCodec != 'pcm_s16le') ...[
          '-b:a',
          '${preset.audioBitrateKbps}k',
        ],
      ]);
    } else if (preset.isPassthrough) {
      args.addAll(['-c', 'copy']);
    } else {
      if (preset.videoCodec != null) {
        args.addAll(['-c:v', preset.videoCodec!]);
        if (preset.videoBitrateMbps != null) {
          args.addAll(['-b:v', '${(preset.videoBitrateMbps! * 1000).round()}k']);
        }
      }
      args.addAll([
        '-c:a',
        preset.audioCodec,
        '-b:a',
        '${preset.audioBitrateKbps}k',
      ]);
    }

    args.add(outputPath);
    return args;
  }

  /// Start a conversion task
  Future<TranscodeTask> startConversion({
    required String sourcePath,
    required String outputPath,
    required TranscodePreset preset,
    Duration? startTime,
    Duration? endTime,
  }) async {
    _isCancelled = false;
    final task = TranscodeTask(
      id: 'TRANSCODE-${DateTime.now().millisecondsSinceEpoch}',
      sourcePath: sourcePath,
      outputPath: outputPath,
      preset: preset,
      status: TranscodeTaskStatus.running,
    );

    _activeTask = task;
    notifyListeners();

    try {
      final executor = customExecutor ?? _defaultSimulationExecutor;
      await executor(
        task,
        (progress, speed, elapsed, eta) {
          if (_isCancelled) return;
          task.progress = progress;
          task.speedMultiplier = speed;
          task.elapsedSeconds = elapsed;
          task.etaSeconds = eta;
          notifyListeners();
        },
        () => _isCancelled,
      );

      if (_isCancelled) {
        task.status = TranscodeTaskStatus.cancelled;
      } else {
        task.status = TranscodeTaskStatus.completed;
        task.progress = 1.0;
        task.etaSeconds = 0;
      }
    } catch (e) {
      task.status = TranscodeTaskStatus.failed;
      task.error = e.toString();
    } finally {
      _history.insert(0, task);
      notifyListeners();
    }

    return task;
  }

  /// Cancels currently running transcode task
  void cancelActiveTask() {
    if (_activeTask != null && _activeTask!.status == TranscodeTaskStatus.running) {
      _isCancelled = true;
      _activeTask!.status = TranscodeTaskStatus.cancelled;
      notifyListeners();
    }
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// Default mockable simulation executor for fast tests & environments without ffmpeg installed
  static Future<void> _defaultSimulationExecutor(
    TranscodeTask task,
    void Function(double progress, double speed, int elapsed, int eta) onProgress,
    bool Function() isCancelled,
  ) async {
    const totalSteps = 10;
    for (int i = 1; i <= totalSteps; i++) {
      if (isCancelled()) return;
      await Future.delayed(const Duration(milliseconds: 30));
      if (isCancelled()) return;
      final progress = i / totalSteps;
      final elapsed = i;
      final eta = totalSteps - i;
      onProgress(progress, 3.2, elapsed, eta);
    }
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
