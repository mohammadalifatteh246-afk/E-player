import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../domain/cdda_models.dart';

/// Function signature for command execution abstraction (supports real ffmpeg or mock simulation)
typedef CdRipExecutor = Future<void> Function(
  List<String> arguments,
  void Function(double trackProgress) onTrackProgress,
  bool Function() isCancelled,
);

/// Transcoding and metadata injection engine for CD Digital Audio (cdda.c parity).
class AudioCdRipperService extends ChangeNotifier {
  CdRipProgress _progress = const CdRipProgress();
  bool _isCancelled = false;
  CdRipExecutor? customExecutor;

  AudioCdRipperService({this.customExecutor});

  final StreamController<CdRipProgress> _progressController =
      StreamController<CdRipProgress>.broadcast();

  CdRipProgress get progress => _progress;
  Stream<CdRipProgress> get progressStream => _progressController.stream;
  bool get isRipping => _progress.isRipping;

  /// Builds FFmpeg extraction and metadata tagging CLI arguments
  List<String> buildRipArguments({
    required String sourcePath,
    required String outputPath,
    required AudioRipFormat format,
    required CdTrackInfo track,
    required AudioCdDiscInfo disc,
  }) {
    final List<String> args = ['-y'];

    // Start offset
    if (track.startOffset > Duration.zero) {
      args.addAll(['-ss', _formatDuration(track.startOffset)]);
    }

    // Exact track duration
    if (track.duration > Duration.zero) {
      args.addAll(['-t', _formatDuration(track.duration)]);
    }

    // Input source
    args.addAll(['-i', sourcePath]);

    // Audio encoding parameters
    args.addAll(['-vn', '-c:a', format.codec]);
    if (format.bitrateKbps > 0) {
      args.addAll(['-b:a', '${format.bitrateKbps}k']);
    }

    // Embed Red Book & CUE sheet metadata tags
    args.addAll(['-metadata', 'title=${track.title}']);
    args.addAll(['-metadata', 'artist=${track.artist}']);
    args.addAll(['-metadata', 'album=${disc.albumTitle}']);
    args.addAll(['-metadata', 'track=${track.trackNumber}/${disc.tracks.length}']);

    if (disc.releaseYear != null && disc.releaseYear!.isNotEmpty) {
      args.addAll(['-metadata', 'date=${disc.releaseYear}']);
    }
    if (disc.genre != null && disc.genre!.isNotEmpty) {
      args.addAll(['-metadata', 'genre=${disc.genre}']);
    }

    // Output target
    args.add(outputPath);
    return args;
  }

  /// Batch rips all currently selected tracks in [disc]
  Future<void> ripSelectedTracks({
    required AudioCdDiscInfo disc,
    required String outputDirectory,
    AudioRipFormat format = AudioRipFormat.flac,
  }) async {
    final selectedTracks = disc.tracks.where((t) => t.isSelected).toList();
    if (selectedTracks.isEmpty) {
      _updateProgress(
        const CdRipProgress(
          status: CdRipStatus.error,
          errorMessage: 'No tracks selected for ripping.',
        ),
      );
      return;
    }

    final sourceAudio = disc.audioSourcePath;
    if (sourceAudio == null || !File(sourceAudio).existsSync()) {
      _updateProgress(
        const CdRipProgress(
          status: CdRipStatus.error,
          errorMessage: 'Audio CD source file not found or inaccessible.',
        ),
      );
      return;
    }

    // Create target directory if needed
    final targetDir = Directory(outputDirectory);
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    _isCancelled = false;
    final totalTracks = selectedTracks.length;
    final stopwatch = Stopwatch()..start();

    _updateProgress(
      CdRipProgress(
        status: CdRipStatus.ripping,
        currentTrackIndex: 1,
        totalSelectedTracks: totalTracks,
        currentTrackTitle: selectedTracks.first.title,
        progressPercent: 0.0,
      ),
    );

    for (int i = 0; i < totalTracks; i++) {
      if (_isCancelled) {
        _updateProgress(
          CdRipProgress(
            status: CdRipStatus.cancelled,
            currentTrackIndex: i + 1,
            totalSelectedTracks: totalTracks,
            elapsedSeconds: stopwatch.elapsed.inSeconds,
          ),
        );
        return;
      }

      final track = selectedTracks[i];
      final sanitizedTitle = _sanitizeFilename(track.title);
      final padTrackNum = track.trackNumber.toString().padLeft(2, '0');
      final outputFilename = '$padTrackNum - $sanitizedTitle.${format.extension}';
      final outputPath = p.join(outputDirectory, outputFilename);

      final args = buildRipArguments(
        sourcePath: sourceAudio,
        outputPath: outputPath,
        format: format,
        track: track,
        disc: disc,
      );

      _updateProgress(
        CdRipProgress(
          status: CdRipStatus.ripping,
          currentTrackIndex: i + 1,
          totalSelectedTracks: totalTracks,
          currentTrackTitle: track.title,
          progressPercent: (i / totalTracks) * 100.0,
          elapsedSeconds: stopwatch.elapsed.inSeconds,
        ),
      );

      try {
        final executor = customExecutor ?? _defaultProcessExecutor;
        await executor(
          args,
          (trackProgress) {
            final overallPercent = ((i + trackProgress) / totalTracks) * 100.0;
            _updateProgress(
              CdRipProgress(
                status: CdRipStatus.ripping,
                currentTrackIndex: i + 1,
                totalSelectedTracks: totalTracks,
                currentTrackTitle: track.title,
                progressPercent: overallPercent.clamp(0.0, 100.0),
                elapsedSeconds: stopwatch.elapsed.inSeconds,
              ),
            );
          },
          () => _isCancelled,
        );
      } catch (e) {
        _updateProgress(
          CdRipProgress(
            status: CdRipStatus.error,
            currentTrackIndex: i + 1,
            totalSelectedTracks: totalTracks,
            currentTrackTitle: track.title,
            errorMessage: 'Error ripping track ${track.trackNumber}: $e',
          ),
        );
        return;
      }
    }

    _updateProgress(
      CdRipProgress(
        status: CdRipStatus.completed,
        currentTrackIndex: totalTracks,
        totalSelectedTracks: totalTracks,
        currentTrackTitle: 'All tracks ripped successfully',
        progressPercent: 100.0,
        elapsedSeconds: stopwatch.elapsed.inSeconds,
      ),
    );
  }

  /// Cancels an active ripping job
  void cancelRip() {
    _isCancelled = true;
    _updateProgress(
      CdRipProgress(
        status: CdRipStatus.cancelled,
        currentTrackIndex: _progress.currentTrackIndex,
        totalSelectedTracks: _progress.totalSelectedTracks,
        progressPercent: _progress.progressPercent,
      ),
    );
  }

  void _updateProgress(CdRipProgress newProgress) {
    _progress = newProgress;
    _progressController.add(newProgress);
    notifyListeners();
  }

  static Future<void> _defaultProcessExecutor(
    List<String> arguments,
    void Function(double progress) onProgress,
    bool Function() isCancelled,
  ) async {
    final process = await Process.start('ffmpeg', arguments);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException('ffmpeg', arguments, 'Process exited with code $exitCode');
    }
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds.$ms';
  }

  static String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }
}
