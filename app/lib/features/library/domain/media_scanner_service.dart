import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/media_item.dart';
import '../../../core/db/database_helper.dart';

/// Progress information emitted during directory scanning.
class ScanProgress {
  final int scannedEntities;
  final int mediaFilesFound;
  final String currentDirectory;
  final bool isCompleted;
  final String? errorMessage;

  const ScanProgress({
    this.scannedEntities = 0,
    this.mediaFilesFound = 0,
    this.currentDirectory = '',
    this.isCompleted = false,
    this.errorMessage,
  });

  ScanProgress copyWith({
    int? scannedEntities,
    int? mediaFilesFound,
    String? currentDirectory,
    bool? isCompleted,
    String? errorMessage,
  }) {
    return ScanProgress(
      scannedEntities: scannedEntities ?? this.scannedEntities,
      mediaFilesFound: mediaFilesFound ?? this.mediaFilesFound,
      currentDirectory: currentDirectory ?? this.currentDirectory,
      isCompleted: isCompleted ?? this.isCompleted,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Media Scanner Service inspired by VLC media player's directory crawler,
/// blacklist/whitelist extension filter, and OS media directory discovery.
class MediaScannerService {
  static const MethodChannel _androidChannel = MethodChannel('com.example.app/media_scanner');

  /// Whitelist of supported video file extensions matching VLC's core parser
  static const Set<String> videoExtensions = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.flv',
    '.webm',
    '.wmv',
    '.ts',
    '.m4v',
    '.3gp',
    '.vob',
    '.ogv',
    '.ogx',
    '.m2ts',
    '.mts',
    '.divx',
    '.f4v',
    '.asf',
  };

  /// Whitelist of supported audio file extensions matching VLC's core parser
  static const Set<String> audioExtensions = {
    '.mp3',
    '.flac',
    '.m4a',
    '.wav',
    '.aac',
    '.ogg',
    '.opus',
    '.wma',
    '.ape',
    '.alac',
    '.aiff',
  };

  /// Blacklist of ignored file extensions (matches VLC's `ignore-filetypes` parameter)
  static const Set<String> ignoredExtensions = {
    '.m3u',
    '.m3u8',
    '.db',
    '.nfo',
    '.ini',
    '.jpg',
    '.jpeg',
    '.gif',
    '.png',
    '.bmp',
    '.webp',
    '.tif',
    '.tiff',
    '.txt',
    '.sfv',
    '.cue',
    '.exe',
    '.dll',
    '.bin',
    '.log',
    '.tmp',
    '.part',
    '.download',
  };

  /// Subtitle sidecar extensions (matching VLC's `sub-autodetect-file` slave track discovery)
  static const Set<String> subtitleExtensions = {
    '.srt',
    '.ass',
    '.ssa',
    '.vtt',
    '.sub',
    '.idx',
  };

  bool _isCancelled = false;

  /// Cancels an in-progress scan
  void cancelScan() {
    _isCancelled = true;
  }

  /// Requests runtime permissions on Android
  static Future<bool> requestAndroidPermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _androidChannel.invokeMethod<bool>('checkAndRequestPermissions');
      return granted ?? false;
    } catch (e) {
      debugPrint('Error requesting Android permissions: $e');
      return false;
    }
  }

  /// Scans Android MediaStore directly via platform channel
  static Future<List<MediaItem>> scanAndroidMediaStore() async {
    if (!Platform.isAndroid) return [];
    try {
      final List<dynamic>? rawList = await _androidChannel.invokeMethod<List<dynamic>>('queryMediaStore');
      if (rawList == null) return [];

      return rawList.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        return MediaItem(
          path: map['path'] as String? ?? '',
          name: map['name'] as String? ?? '',
          parentFolder: map['parentFolder'] as String? ?? '',
          sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
          durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
          lastPositionMs: 0,
          isFavorite: false,
          lastPlayed: DateTime.fromMillisecondsSinceEpoch(
            (map['lastPlayed'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }).where((item) => item.path.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error querying Android MediaStore: $e');
      return [];
    }
  }

  /// Determines whether a given file path is a supported media file
  static bool isMediaFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext.isEmpty || ignoredExtensions.contains(ext)) return false;
    return videoExtensions.contains(ext) || audioExtensions.contains(ext);
  }

  /// Determines whether a given file path is a video file
  static bool isVideo(String filePath) {
    return videoExtensions.contains(p.extension(filePath).toLowerCase());
  }

  /// Determines whether a given file path is an audio file
  static bool isAudio(String filePath) {
    return audioExtensions.contains(p.extension(filePath).toLowerCase());
  }

  /// Discovers system standard media directories (similar to VLC's `mediadirs.c` / `config_GetUserDir`)
  Future<List<String>> getSystemMediaDirectories() async {
    final List<String> directories = [];

    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final candidates = [
            p.join(userProfile, 'Videos'),
            p.join(userProfile, 'Music'),
            p.join(userProfile, 'Downloads'),
            p.join(userProfile, 'Documents'),
          ];
          for (final dir in candidates) {
            if (await Directory(dir).exists()) {
              directories.add(dir);
            }
          }
        }
      } else if (Platform.isAndroid) {
        final storage = Directory('/storage/emulated/0');
        if (await storage.exists()) {
          final candidates = [
            p.join(storage.path, 'Movies'),
            p.join(storage.path, 'Music'),
            p.join(storage.path, 'Download'),
            p.join(storage.path, 'DCIM'),
          ];
          for (final dir in candidates) {
            if (await Directory(dir).exists()) {
              directories.add(dir);
            }
          }
        }
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          final candidates = [
            p.join(home, 'Movies'),
            p.join(home, 'Music'),
            p.join(home, 'Downloads'),
            p.join(home, 'Videos'),
          ];
          for (final dir in candidates) {
            if (await Directory(dir).exists()) {
              directories.add(dir);
            }
          }
        }
      }

      // Add downloads directory from path_provider as cross-platform fallback
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null && !directories.contains(downloads.path)) {
          if (await downloads.exists()) {
            directories.add(downloads.path);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error getting system media directories: $e');
    }

    return directories;
  }

  /// Finds companion sidecar subtitles for a media file (e.g., movie.srt, movie.en.vtt)
  static Future<List<String>> findCompanionSubtitles(String mediaPath) async {
    final List<String> subtitles = [];
    final file = File(mediaPath);
    final parent = file.parent;
    final baseName = p.basenameWithoutExtension(mediaPath);

    if (!await parent.exists()) return subtitles;

    try {
      await for (final entity in parent.list(followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (subtitleExtensions.contains(ext)) {
            final subBase = p.basenameWithoutExtension(entity.path);
            if (subBase.startsWith(baseName)) {
              subtitles.add(entity.path);
            }
          }
        }
      }
    } catch (_) {}

    return subtitles;
  }

  /// Scans multiple directories asynchronously, reports progress, and batches database persistence
  Stream<ScanProgress> scanDirectories(
    List<String> directoryPaths, {
    bool showHiddenFiles = false,
    int batchSize = 100,
  }) async* {
    _isCancelled = false;
    int scannedEntities = 0;
    int mediaFilesFound = 0;
    final List<MediaItem> buffer = [];

    yield const ScanProgress(
      scannedEntities: 0,
      mediaFilesFound: 0,
      currentDirectory: 'Starting media scanner...',
      isCompleted: false,
    );

    for (final dirPath in directoryPaths) {
      if (_isCancelled) break;

      final directory = Directory(dirPath);
      if (!await directory.exists()) continue;

      yield ScanProgress(
        scannedEntities: scannedEntities,
        mediaFilesFound: mediaFilesFound,
        currentDirectory: dirPath,
        isCompleted: false,
      );

      try {
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (_isCancelled) break;

          scannedEntities++;

          // Skip hidden directories/files unless explicitly enabled (matches VLC show-hiddenfiles)
          final name = p.basename(entity.path);
          if (!showHiddenFiles && (name.startsWith('.') || name.startsWith('\$'))) {
            continue;
          }

          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();

            // Ignore blacklisted file types
            if (ignoredExtensions.contains(ext)) {
              continue;
            }

            // Check if matches video or audio whitelist
            if (videoExtensions.contains(ext) || audioExtensions.contains(ext)) {
              try {
                final stat = await entity.stat();
                final item = MediaItem(
                  path: entity.path,
                  name: p.basename(entity.path),
                  parentFolder: entity.parent.path,
                  sizeBytes: stat.size,
                  durationMs: 0,
                  lastPositionMs: 0,
                  isFavorite: false,
                  lastPlayed: stat.modified,
                );

                buffer.add(item);
                mediaFilesFound++;

                // Yield progress update periodically
                if (mediaFilesFound % 10 == 0 || scannedEntities % 50 == 0) {
                  yield ScanProgress(
                    scannedEntities: scannedEntities,
                    mediaFilesFound: mediaFilesFound,
                    currentDirectory: entity.parent.path,
                    isCompleted: false,
                  );
                }

                // Batch insert into database to maximize SQLite throughput
                if (buffer.length >= batchSize) {
                  await DatabaseHelper.instance.insertBatch(List.from(buffer));
                  buffer.clear();
                }
              } catch (_) {
                // Ignore single file I/O permissions errors and proceed
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning directory $dirPath: $e');
      }
    }

    // Flush any remaining items in buffer
    if (buffer.isNotEmpty) {
      await DatabaseHelper.instance.insertBatch(buffer);
      buffer.clear();
    }

    yield ScanProgress(
      scannedEntities: scannedEntities,
      mediaFilesFound: mediaFilesFound,
      currentDirectory: _isCancelled ? 'Scan cancelled' : 'Scan completed',
      isCompleted: true,
    );
  }
}
