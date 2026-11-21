import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// Metadata for a media item discovered inside an archive
class ArchiveMediaEntry {
  final String name;
  final String pathInArchive;
  final int uncompressedSize;
  final bool isVideo;
  final bool isAudio;

  const ArchiveMediaEntry({
    required this.name,
    required this.pathInArchive,
    required this.uncompressedSize,
    required this.isVideo,
    required this.isAudio,
  });

  bool get isMedia => isVideo || isAudio;
}

/// Service for directly playing media out of .zip and .tar archives (VLC Parity)
/// without requiring manual archive extraction by the user.
class ArchiveMediaService {
  static const Set<String> _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'ts', 'm2ts', 'webm', 'vob', 'm4v',
  };

  static const Set<String> _audioExtensions = {
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'opus', 'ogg', 'wma',
  };

  static const Set<String> supportedArchiveExtensions = {
    'zip', 'tar', 'gz', 'tgz',
  };

  /// Returns true if [filePath] points to a supported archive (.zip, .tar, .tgz, .tar.gz)
  static bool isArchive(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.tar.gz')) return true;
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    return supportedArchiveExtensions.contains(ext);
  }

  /// Lists all playable media items found within [archivePath]
  static Future<List<ArchiveMediaEntry>> listMediaInArchive(String archivePath) async {
    final file = File(archivePath);
    if (!await file.exists()) {
      debugPrint('[ArchiveMediaService] Archive file does not exist: $archivePath');
      return [];
    }

    try {
      final bytes = await file.readAsBytes();
      final archive = _decodeArchive(bytes, archivePath);
      if (archive == null) return [];

      final entries = <ArchiveMediaEntry>[];
      for (final item in archive) {
        if (!item.isFile) continue;

        final ext = p.extension(item.name).replaceFirst('.', '').toLowerCase();
        final isVid = _videoExtensions.contains(ext);
        final isAud = _audioExtensions.contains(ext);

        if (isVid || isAud) {
          entries.add(
            ArchiveMediaEntry(
              name: p.basename(item.name),
              pathInArchive: item.name,
              uncompressedSize: item.size,
              isVideo: isVid,
              isAudio: isAud,
            ),
          );
        }
      }

      return entries;
    } catch (e) {
      debugPrint('[ArchiveMediaService] Error listing archive: $e');
      return [];
    }
  }

  /// Extracts a specific [pathInArchive] from [archivePath] to a cached temporary file
  /// and returns the absolute local path ready for libmpv playback.
  static Future<String?> extractMedia(
    String archivePath,
    String pathInArchive, {
    Directory? customCacheDir,
  }) async {
    final file = File(archivePath);
    if (!await file.exists()) return null;

    try {
      final cacheDir = customCacheDir ?? await getArchiveCacheDirectory(archivePath);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final targetFileName = p.basename(pathInArchive);
      final cachedFile = File(p.join(cacheDir.path, targetFileName));

      // If already extracted and non-empty, reuse it
      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        debugPrint('[ArchiveMediaService] Cache hit for $pathInArchive -> ${cachedFile.path}');
        return cachedFile.path;
      }

      final bytes = await file.readAsBytes();
      final archive = _decodeArchive(bytes, archivePath);
      if (archive == null) return null;

      for (final item in archive) {
        if (item.isFile && (item.name == pathInArchive || p.basename(item.name) == targetFileName)) {
          final content = item.content as List<int>;
          await cachedFile.writeAsBytes(content, flush: true);
          debugPrint('[ArchiveMediaService] Extracted ${cachedFile.path} (${content.length} bytes)');
          return cachedFile.path;
        }
      }

      debugPrint('[ArchiveMediaService] Entry not found in archive: $pathInArchive');
      return null;
    } catch (e) {
      debugPrint('[ArchiveMediaService] Failed to extract media: $e');
      return null;
    }
  }

  /// Computes a deterministic cache directory for a given archive
  static Future<Directory> getArchiveCacheDirectory(String archivePath) async {
    final hash = md5.convert(archivePath.codeUnits).toString();
    final tempDir = Directory.systemTemp;
    return Directory(p.join(tempDir.path, 'eplayer_archive_cache', hash));
  }

  /// Cleans up temporary extracted cache files
  static Future<void> cleanupCache({String? archivePath}) async {
    try {
      if (archivePath != null) {
        final cacheDir = await getArchiveCacheDirectory(archivePath);
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          debugPrint('[ArchiveMediaService] Cleaned cache for: $archivePath');
        }
      } else {
        final baseCacheDir = Directory(p.join(Directory.systemTemp.path, 'eplayer_archive_cache'));
        if (await baseCacheDir.exists()) {
          await baseCacheDir.delete(recursive: true);
          debugPrint('[ArchiveMediaService] Cleaned entire archive cache');
        }
      }
    } catch (e) {
      debugPrint('[ArchiveMediaService] Error during cache cleanup: $e');
    }
  }

  static Archive? _decodeArchive(Uint8List bytes, String archivePath) {
    final lower = archivePath.toLowerCase();

    if (lower.endsWith('.zip')) {
      return ZipDecoder().decodeBytes(bytes);
    } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      final decompressed = GZipDecoder().decodeBytes(bytes);
      return TarDecoder().decodeBytes(decompressed);
    } else if (lower.endsWith('.tar')) {
      return TarDecoder().decodeBytes(bytes);
    }

    // Fallback: try zip, then tar
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      try {
        return TarDecoder().decodeBytes(bytes);
      } catch (_) {
        return null;
      }
    }
  }
}
