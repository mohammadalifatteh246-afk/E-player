import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/models/media_library_models.dart';

/// Segment representation for breadcrumb navigation bar.
class BreadcrumbSegment {
  final String name;
  final String path;

  const BreadcrumbSegment({
    required this.name,
    required this.path,
  });

  @override
  String toString() => 'BreadcrumbSegment(name: $name, path: $path)';
}

/// Interface for interactive file system exploration, drive discovery, and filtering.
abstract class FileSystemService {
  List<String> getLogicalDrives();
  String normalizePath(String inputPath);
  List<BreadcrumbSegment> parseBreadcrumbs(String directoryPath);
  Future<bool> hasNoMedia(String directoryPath);
  Future<List<FileSystemNode>> listDirectoryContents(
    String directoryPath, {
    bool showHidden = false,
  });
  FileNodeType determineNodeType(String path, {required bool isDirectory});
}

/// Production implementation of FileSystemService.
class DefaultFileSystemService implements FileSystemService {
  static const Set<String> videoExtensions = {
    '.mp4', '.mkv', '.avi', '.mov', '.flv', '.wmv', '.webm', '.m4v', '.3gp', '.ts',
  };

  static const Set<String> audioExtensions = {
    '.mp3', '.flac', '.wav', '.aac', '.m4a', '.ogg', '.wma', '.opus', '.alac',
  };

  static const Set<String> subtitleExtensions = {
    '.srt', '.vtt', '.ass', '.ssa', '.sub',
  };

  const DefaultFileSystemService();

  /// Discover logical drives across Windows and POSIX operating systems.
  @override
  List<String> getLogicalDrives() {
    if (Platform.isWindows) {
      final drives = <String>[];
      for (int i = 65; i <= 90; i++) {
        final driveLetter = '${String.fromCharCode(i)}:\\';
        try {
          if (Directory(driveLetter).existsSync()) {
            drives.add(driveLetter);
          }
        } catch (_) {}
      }
      return drives.isNotEmpty ? drives : ['C:\\'];
    }

    // POSIX roots
    final posixRoots = <String>['/'];
    final commonMounts = ['/storage/emulated/0', '/media', '/mnt'];
    for (final mount in commonMounts) {
      try {
        if (Directory(mount).existsSync()) {
          posixRoots.add(mount);
        }
      } catch (_) {}
    }
    return posixRoots;
  }

  /// Canonicalize path and apply Windows extended-length prefix (\\?\) for paths > 240 chars.
  @override
  String normalizePath(String inputPath) {
    if (inputPath.isEmpty) return inputPath;
    var normalized = p.normalize(inputPath);

    if (Platform.isWindows) {
      if (normalized.length > 240 && !normalized.startsWith(r'\\?\')) {
        if (normalized.startsWith(r'\\')) {
          // UNC network path: \\server\share -> \\?\UNC\server\share
          normalized = r'\\?\UNC\' + normalized.substring(2);
        } else {
          // Local drive: C:\path -> \\?\C:\path
          normalized = r'\\?\' + normalized;
        }
      }
    }
    return normalized;
  }

  /// Parse directory path into clickable breadcrumb segments.
  @override
  List<BreadcrumbSegment> parseBreadcrumbs(String directoryPath) {
    if (directoryPath.isEmpty) return const [];
    final normalized = normalizePath(directoryPath);
    final segments = <BreadcrumbSegment>[];

    if (Platform.isWindows) {
      // Handle drive letter root (e.g. C:\)
      final root = p.rootPrefix(normalized);
      if (root.isNotEmpty) {
        segments.add(BreadcrumbSegment(name: root, path: root));
      }
      final relativePart = normalized.substring(root.length);
      final parts = relativePart.split(p.separator).where((s) => s.isNotEmpty).toList();
      var currentPath = root;

      for (final part in parts) {
        currentPath = p.join(currentPath, part);
        segments.add(BreadcrumbSegment(name: part, path: currentPath));
      }
    } else {
      // POSIX root
      segments.add(const BreadcrumbSegment(name: '/', path: '/'));
      final parts = normalized.split('/').where((s) => s.isNotEmpty).toList();
      var currentPath = '';

      for (final part in parts) {
        currentPath = '$currentPath/$part';
        segments.add(BreadcrumbSegment(name: part, path: currentPath));
      }
    }

    return segments;
  }

  /// Detect `.nomedia` exclusion file in directory.
  @override
  Future<bool> hasNoMedia(String directoryPath) async {
    try {
      final noMediaFile = File(p.join(directoryPath, '.nomedia'));
      return await noMediaFile.exists();
    } catch (_) {
      return false;
    }
  }

  /// Determine node type based on path extension and directory flag.
  @override
  FileNodeType determineNodeType(String path, {required bool isDirectory}) {
    if (isDirectory) {
      final root = p.rootPrefix(path);
      if (path == root || path == '/' || (Platform.isWindows && path.endsWith(r':\'))) {
        return FileNodeType.drive;
      }
      return FileNodeType.directory;
    }

    final ext = p.extension(path).toLowerCase();
    if (videoExtensions.contains(ext)) return FileNodeType.videoFile;
    if (audioExtensions.contains(ext)) return FileNodeType.audioFile;
    if (subtitleExtensions.contains(ext)) return FileNodeType.subtitleFile;
    return FileNodeType.otherFile;
  }

  /// List immediate directory entries with zero-depth lazy loading, `.nomedia` detection,
  /// hidden file filtering, and symlink cycle prevention.
  @override
  Future<List<FileSystemNode>> listDirectoryContents(
    String directoryPath, {
    bool showHidden = false,
  }) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        return const [];
      }

      final hasNoMediaMarker = await hasNoMedia(directoryPath);
      final visitedCanonicalPaths = <String>{};
      final nodes = <FileSystemNode>[];

      final entries = await dir.list(recursive: false, followLinks: false).toList();

      for (final entry in entries) {
        final basename = p.basename(entry.path);

        // 1. Hidden file filtering
        final isHidden = basename.startsWith('.') || basename.startsWith(r'~$');
        if (isHidden && !showHidden) {
          continue;
        }

        // 2. Symlink loop protection
        try {
          final canonical = await entry.resolveSymbolicLinks();
          if (visitedCanonicalPaths.contains(canonical)) {
            continue; // Prevent recursive loops
          }
          visitedCanonicalPaths.add(canonical);
        } catch (_) {
          // If resolve fails, continue with raw path
        }

        // 3. Metadata extraction
        final isDir = entry is Directory;
        final type = determineNodeType(entry.path, isDirectory: isDir);

        // Filter out non-media files unless showHidden is explicitly true
        if (!isDir && type == FileNodeType.otherFile && !showHidden) {
          continue;
        }

        int sizeBytes = 0;
        DateTime modifiedDate = DateTime.now();
        bool hasChildren = false;
        int childMediaCount = 0;

        try {
          final stat = await entry.stat();
          sizeBytes = stat.size;
          modifiedDate = stat.modified;
        } catch (_) {}

        if (isDir) {
          // Quick non-recursive probe to check if folder has children and media count
          try {
            final childDir = Directory(entry.path);
            final childEntries = await childDir.list(recursive: false, followLinks: false).take(50).toList();
            hasChildren = childEntries.isNotEmpty;
            for (final child in childEntries) {
              final childType = determineNodeType(child.path, isDirectory: child is Directory);
              if (childType == FileNodeType.videoFile || childType == FileNodeType.audioFile) {
                childMediaCount++;
              }
            }
          } catch (_) {}
        }

        nodes.add(FileSystemNode(
          path: entry.path,
          name: basename,
          type: type,
          sizeBytes: sizeBytes,
          modifiedDate: modifiedDate,
          isHidden: isHidden || hasNoMediaMarker,
          hasChildren: hasChildren,
          childMediaCount: childMediaCount,
        ));
      }

      // Sort directories first, then files alphabetically
      nodes.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return nodes;
    } catch (_) {
      // Inaccessible directory, invalid path syntax (e.g. Windows errno 123)
      return const [];
    }
  }
}
