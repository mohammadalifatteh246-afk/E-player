import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/media_item.dart';
import '../../../core/db/database_helper.dart';

typedef DirectoryExistsChecker = bool Function(String path);

/// Progress information emitted during directory and multi-drive scanning.
class ScanProgress {
  final int scannedEntities;
  final int mediaFilesFound;
  final String currentDirectory;
  final String activeRoot;
  final int currentRootIndex;
  final int totalRoots;
  final bool isCompleted;
  final String? errorMessage;

  const ScanProgress({
    this.scannedEntities = 0,
    this.mediaFilesFound = 0,
    this.currentDirectory = '',
    this.activeRoot = '',
    this.currentRootIndex = 0,
    this.totalRoots = 0,
    this.isCompleted = false,
    this.errorMessage,
  });

  ScanProgress copyWith({
    int? scannedEntities,
    int? mediaFilesFound,
    String? currentDirectory,
    String? activeRoot,
    int? currentRootIndex,
    int? totalRoots,
    bool? isCompleted,
    String? errorMessage,
  }) {
    return ScanProgress(
      scannedEntities: scannedEntities ?? this.scannedEntities,
      mediaFilesFound: mediaFilesFound ?? this.mediaFilesFound,
      currentDirectory: currentDirectory ?? this.currentDirectory,
      activeRoot: activeRoot ?? this.activeRoot,
      currentRootIndex: currentRootIndex ?? this.currentRootIndex,
      totalRoots: totalRoots ?? this.totalRoots,
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

  /// System / OS protected or developer cache directories skipped during full-drive scans
  static const Set<String> systemSkipDirectories = {
    'system volume information',
    r'$recycle.bin',
    r'$windows.~bt',
    r'$windows.~ws',
    'windows',
    'program files',
    'program files (x86)',
    'programdata',
    'recovery',
    'perflogs',
    'msocache',
    'config.msi',
    'appdata',
    'windowsapps',
    'wpsystem',
    'node_modules',
    '.git',
    '.dart_tool',
    '.gradle',
    '.idea',
    '.vscode',
    '__pycache__',
    'proc',
    'sys',
    'dev',
  };

  /// Discovers all logical drives / mounted storage volumes on the host OS.
  static List<String> getAvailableDrives({
    DirectoryExistsChecker? existsChecker,
    bool? isWindowsOverride,
  }) {
    final checkExists = existsChecker ?? (path) => Directory(path).existsSync();
    final isWin = isWindowsOverride ?? Platform.isWindows;

    if (isWin) {
      final drives = <String>[];
      for (int i = 65; i <= 90; i++) {
        final driveLetter = '${String.fromCharCode(i)}:\\';
        try {
          if (checkExists(driveLetter)) {
            drives.add(driveLetter);
          }
        } catch (_) {}
      }
      return drives.isNotEmpty ? drives : [r'C:\'];
    }

    if (Platform.isAndroid) {
      final roots = <String>[];
      if (checkExists('/storage/emulated/0')) {
        roots.add('/storage/emulated/0');
      }
      try {
        final storage = Directory('/storage');
        if (storage.existsSync()) {
          for (final entity in storage.listSync(followLinks: false)) {
            if (entity is Directory &&
                entity.path != '/storage/emulated' &&
                entity.path != '/storage/self' &&
                !roots.contains(entity.path)) {
              roots.add(entity.path);
            }
          }
        }
      } catch (_) {}
      return roots.isNotEmpty ? roots : ['/'];
    }

    // macOS / Linux mount roots
    final roots = <String>[];
    for (final mountBase in ['/Volumes', '/media', '/mnt']) {
      try {
        final dir = Directory(mountBase);
        if (dir.existsSync()) {
          for (final entity in dir.listSync(followLinks: false)) {
            if (entity is Directory && !roots.contains(entity.path)) {
              roots.add(entity.path);
            }
          }
        }
      } catch (_) {}
    }
    if (checkExists('/')) {
      roots.insert(0, '/');
    }
    return roots.isNotEmpty ? roots : ['/'];
  }

  /// Determines whether a child directory or file entry should be skipped during crawling.
  static bool shouldSkipEntry(
    String entryName, {
    required bool isDirectory,
    bool showHiddenFiles = false,
    bool skipSystemDirectories = true,
  }) {
    if (entryName.isEmpty) return true;
    if (!showHiddenFiles && (entryName.startsWith('.') || entryName.startsWith('\$'))) {
      return true;
    }
    if (isDirectory &&
        skipSystemDirectories &&
        systemSkipDirectories.contains(entryName.toLowerCase())) {
      return true;
    }
    return false;
  }

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

  /// Scans multiple drives or directories asynchronously with resilient per-directory
  /// BFS traversal (never aborts on OS permission-denied folders) and batches SQLite writes.
  Stream<ScanProgress> scanDirectories(
    List<String> directoryPaths, {
    bool showHiddenFiles = false,
    bool skipSystemDirectories = true,
    int batchSize = 100,
  }) async* {
    _isCancelled = false;
    int scannedEntities = 0;
    int mediaFilesFound = 0;
    final List<MediaItem> buffer = [];

    // Preserve insertion order while removing empty / duplicate targets
    final seen = <String>{};
    final roots = <String>[];
    for (final raw in directoryPaths) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final dedupKey = Platform.isWindows ? trimmed.toLowerCase() : trimmed;
      if (seen.add(dedupKey)) {
        roots.add(trimmed);
      }
    }

    yield ScanProgress(
      scannedEntities: 0,
      mediaFilesFound: 0,
      currentDirectory: 'Starting multi-drive media scanner...',
      activeRoot: roots.isNotEmpty ? roots.first : '',
      currentRootIndex: 0,
      totalRoots: roots.length,
      isCompleted: false,
    );

    for (int rootIndex = 0; rootIndex < roots.length; rootIndex++) {
      if (_isCancelled) break;

      final dirPath = roots[rootIndex];
      final rootDir = Directory(dirPath);
      try {
        if (!await rootDir.exists()) continue;
      } catch (_) {
        continue;
      }

      yield ScanProgress(
        scannedEntities: scannedEntities,
        mediaFilesFound: mediaFilesFound,
        currentDirectory: dirPath,
        activeRoot: dirPath,
        currentRootIndex: rootIndex + 1,
        totalRoots: roots.length,
        isCompleted: false,
      );

      final queue = ListQueue<Directory>()..add(rootDir);

      while (queue.isNotEmpty && !_isCancelled) {
        final currentDir = queue.removeFirst();

        try {
          await for (final entity in currentDir
              .list(recursive: false, followLinks: false)
              .handleError((_) {})) {
            if (_isCancelled) break;
            if (entity is Link) continue;

            scannedEntities++;
            final isDir = entity is Directory;
            final name = p.basename(entity.path);

            if (shouldSkipEntry(
              name,
              isDirectory: isDir,
              showHiddenFiles: showHiddenFiles,
              skipSystemDirectories: skipSystemDirectories,
            )) {
              continue;
            }

            if (isDir) {
              queue.add(entity);
              if (scannedEntities % 80 == 0) {
                yield ScanProgress(
                  scannedEntities: scannedEntities,
                  mediaFilesFound: mediaFilesFound,
                  currentDirectory: entity.path,
                  activeRoot: dirPath,
                  currentRootIndex: rootIndex + 1,
                  totalRoots: roots.length,
                  isCompleted: false,
                );
              }
            } else if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase();

              if (ignoredExtensions.contains(ext)) {
                continue;
              }

              if (videoExtensions.contains(ext) || audioExtensions.contains(ext)) {
                try {
                  final stat = await entity.stat();
                  final item = MediaItem(
                    path: entity.path,
                    name: name,
                    parentFolder: entity.parent.path,
                    sizeBytes: stat.size,
                    durationMs: 0,
                    lastPositionMs: 0,
                    isFavorite: false,
                    lastPlayed: stat.modified,
                  );

                  buffer.add(item);
                  mediaFilesFound++;

                  if (mediaFilesFound % 10 == 0 || scannedEntities % 80 == 0) {
                    yield ScanProgress(
                      scannedEntities: scannedEntities,
                      mediaFilesFound: mediaFilesFound,
                      currentDirectory: entity.parent.path,
                      activeRoot: dirPath,
                      currentRootIndex: rootIndex + 1,
                      totalRoots: roots.length,
                      isCompleted: false,
                    );
                  }

                  if (buffer.length >= batchSize) {
                    await DatabaseHelper.instance.insertBatch(List.from(buffer));
                    buffer.clear();
                  }
                } catch (_) {
                  // Ignore single file permission/read errors and keep scanning
                }
              }
            }
          }
        } catch (e) {
          // Gracefully skip protected / unreadable subdirectories without aborting the drive scan
          debugPrint('Skipping inaccessible directory ${currentDir.path}: $e');
        }
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
      activeRoot: roots.isNotEmpty ? roots.last : '',
      currentRootIndex: roots.length,
      totalRoots: roots.length,
      isCompleted: true,
    );
  }
}
