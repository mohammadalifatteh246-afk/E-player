import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';

/// Result object for video snapshot frame capture.
class SnapshotResult {
  final bool success;
  final File? file;
  final String fileName;
  final Duration timestamp;
  final String? errorMessage;
  final Uint8List? previewBytes;

  const SnapshotResult({
    required this.success,
    this.file,
    this.fileName = '',
    this.timestamp = Duration.zero,
    this.errorMessage,
    this.previewBytes,
  });

  String get formattedPosition {
    final hours = timestamp.inHours;
    final minutes = timestamp.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = timestamp.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

/// Service managing video frame snapshot captures.
/// Replicates VLC's snapshot engine (`vlc_action_snapshot`, `Shift+S`),
/// outputting standardized `vlcsnap-YYYY-MM-DD-HHmmss.png` frames.
class VideoSnapshotService {
  static VideoSnapshotService? _instance;
  static VideoSnapshotService get instance => _instance ??= VideoSnapshotService();

  final Directory? customStorageDir;

  VideoSnapshotService({this.customStorageDir});

  /// Resolves the target directory for saving snapshots (e.g. ~/Pictures/E-Player Snapshots)
  Future<Directory> getSnapshotDirectory() async {
    final custom = customStorageDir;
    if (custom != null) {
      if (!custom.existsSync()) {
        custom.createSync(recursive: true);
      }
      return custom;
    }

    try {
      Directory? baseDir;
      try {
        baseDir = await getDownloadsDirectory();
      } catch (_) {}

      baseDir ??= await getApplicationDocumentsDirectory();
      final targetDir = Directory('${baseDir.path}/E-Player Snapshots');
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      return targetDir;
    } catch (_) {
      final fallback = Directory('${Directory.systemTemp.path}/E-Player Snapshots');
      if (!fallback.existsSync()) {
        fallback.createSync(recursive: true);
      }
      return fallback;
    }
  }

  /// Generates standardized VLC filename: vlcsnap-YYYY-MM-DD-HHmmss.png
  String generateSnapshotFileName({DateTime? timestamp, int suffix = 0}) {
    final t = timestamp ?? DateTime.now();
    final year = t.year.toString().padLeft(4, '0');
    final month = t.month.toString().padLeft(2, '0');
    final day = t.day.toString().padLeft(2, '0');
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    final second = t.second.toString().padLeft(2, '0');

    final suffixStr = suffix > 0 ? '-$suffix' : '';
    return 'vlcsnap-$year-$month-$day-$hour$minute$second$suffixStr.png';
  }

  /// Saves raw image [bytes] to disk with deduplication and metadata tracking.
  Future<SnapshotResult> saveSnapshotBytes({
    required Uint8List? bytes,
    required Duration position,
    String? mediaTitle,
    DateTime? overrideTime,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      return const SnapshotResult(
        success: false,
        errorMessage: 'Snapshot frame buffer was empty or null.',
      );
    }

    try {
      final dir = await getSnapshotDirectory();
      final now = overrideTime ?? DateTime.now();

      var suffix = 0;
      var fileName = generateSnapshotFileName(timestamp: now, suffix: suffix);
      var file = File('${dir.path}/$fileName');

      // Collision avoidance within same-second bursts
      while (file.existsSync()) {
        suffix++;
        fileName = generateSnapshotFileName(timestamp: now, suffix: suffix);
        file = File('${dir.path}/$fileName');
      }

      file.writeAsBytesSync(bytes, flush: true);

      return SnapshotResult(
        success: true,
        file: file,
        fileName: fileName,
        timestamp: position,
        previewBytes: bytes,
      );
    } catch (e) {
      return SnapshotResult(
        success: false,
        errorMessage: 'Failed to write snapshot file: $e',
      );
    }
  }

  /// Captures active frame directly from [player] and writes snapshot.
  Future<SnapshotResult> captureFromPlayer(
    Player player, {
    String? mediaTitle,
  }) async {
    try {
      final bytes = await player.screenshot(format: 'image/png');
      return await saveSnapshotBytes(
        bytes: bytes,
        position: player.state.position,
        mediaTitle: mediaTitle,
      );
    } catch (e) {
      return SnapshotResult(
        success: false,
        errorMessage: 'Player screenshot error: $e',
      );
    }
  }
}
