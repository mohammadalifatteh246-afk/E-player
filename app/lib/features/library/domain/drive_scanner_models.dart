library;

import 'dart:io';

/// Represents a logical drive, partition, or custom folder root for Multi-Drive Studio.
class DriveVolumeInfo {
  final String rootPath;
  final String label;
  final int indexedFileCount;
  final DateTime? lastScannedAt;
  final bool isSystemDrive;
  final bool isCustomFolder;

  const DriveVolumeInfo({
    required this.rootPath,
    required this.label,
    this.indexedFileCount = 0,
    this.lastScannedAt,
    this.isSystemDrive = false,
    this.isCustomFolder = false,
  });

  /// Returns true if this drive already has indexed media OR a recorded scan timestamp.
  bool get isScanned => indexedFileCount > 0 || lastScannedAt != null;

  DriveVolumeInfo copyWith({
    String? rootPath,
    String? label,
    int? indexedFileCount,
    DateTime? lastScannedAt,
    bool? isSystemDrive,
    bool? isCustomFolder,
  }) {
    return DriveVolumeInfo(
      rootPath: rootPath ?? this.rootPath,
      label: label ?? this.label,
      indexedFileCount: indexedFileCount ?? this.indexedFileCount,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      isSystemDrive: isSystemDrive ?? this.isSystemDrive,
      isCustomFolder: isCustomFolder ?? this.isCustomFolder,
    );
  }

  /// Generates a clean human-readable label for a drive or mount path.
  static String formatDriveLabel(String rootPath, {String? systemDriveLetter}) {
    if (Platform.isWindows || RegExp(r'^[A-Za-z]:\\?$').hasMatch(rootPath)) {
      final letter = rootPath.substring(0, 1).toUpperCase();
      final sysLetter =
          (systemDriveLetter != null && systemDriveLetter.isNotEmpty)
              ? systemDriveLetter.substring(0, 1).toUpperCase()
              : 'C';
      if (letter == sysLetter) {
        return 'Local Disk ($letter:) • System';
      }
      return 'Local Disk ($letter:)';
    }
    if (rootPath == '/') return 'Root Filesystem (/)';
    if (rootPath == '/storage/emulated/0') return 'Internal Storage';
    final segments =
        rootPath.split(RegExp(r'[/\\]+')).where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : rootPath;
  }

  /// Extracts normalized drive root prefix from any file path (e.g. `D:\Movies\a.mkv` -> `D:\`).
  static String? extractDriveRoot(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) return null;
    final winMatch = RegExp(r'^([A-Za-z]):').firstMatch(trimmed);
    if (winMatch != null) {
      return '${winMatch.group(1)!.toUpperCase()}:\\';
    }
    if (trimmed.startsWith('/storage/emulated/0')) {
      return '/storage/emulated/0';
    }
    if (trimmed.startsWith('/')) {
      return '/';
    }
    return null;
  }

  /// Normalizes drive keys for case-insensitive matching (`c:\` == `C:\`).
  static String normalizeKey(String path) {
    final trimmed = path.trim();
    if (RegExp(r'^[A-Za-z]:\\?$').hasMatch(trimmed)) {
      return '${trimmed.substring(0, 1).toUpperCase()}:\\';
    }
    return trimmed;
  }
}
