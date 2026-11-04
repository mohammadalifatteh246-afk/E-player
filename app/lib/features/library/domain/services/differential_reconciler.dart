import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/models/media_library_models.dart';
import '../../../../core/db/media_library_repository.dart';
import '../../../browser/domain/file_system_service.dart';

/// Result of differential set reconciliation between physical disk and SQLite database.
class ReconciliationDiff {
  final List<String> addedPaths;
  final List<FileRecord> removedRecords;
  final List<FileRecord> modifiedRecords;
  final int unchangedCount;

  const ReconciliationDiff({
    required this.addedPaths,
    required this.removedRecords,
    required this.modifiedRecords,
    required this.unchangedCount,
  });

  bool get hasChanges =>
      addedPaths.isNotEmpty || removedRecords.isNotEmpty || modifiedRecords.isNotEmpty;

  @override
  String toString() =>
      'ReconciliationDiff(added: ${addedPaths.length}, removed: ${removedRecords.length}, modified: ${modifiedRecords.length}, unchanged: $unchangedCount)';
}

/// Interface for calculating differential reconciliation.
abstract class IDifferentialReconciler {
  Future<ReconciliationDiff> reconcileDirectory({
    required String directoryPath,
    required int folderId,
    bool showHidden = false,
  });
}

/// Production implementation of DifferentialReconciler using in-memory set algebra.
class DifferentialReconciler implements IDifferentialReconciler {
  final MediaLibraryRepository repository;
  final FileSystemService fileSystemService;

  const DifferentialReconciler({
    required this.repository,
    this.fileSystemService = const DefaultFileSystemService(),
  });

  @override
  Future<ReconciliationDiff> reconcileDirectory({
    required String directoryPath,
    required int folderId,
    bool showHidden = false,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      // Directory was removed from disk: all existing files in DB are missing
      final dbFiles = await repository.getFilesByFolder(folderId, onlyPresent: true);
      return ReconciliationDiff(
        addedPaths: const [],
        removedRecords: dbFiles,
        modifiedRecords: const [],
        unchangedCount: 0,
      );
    }

    // Check for .nomedia exclusion
    final isExcluded = await fileSystemService.hasNoMedia(directoryPath);
    if (isExcluded) {
      // All existing indexed files in this folder should be soft-deleted
      final dbFiles = await repository.getFilesByFolder(folderId, onlyPresent: true);
      return ReconciliationDiff(
        addedPaths: const [],
        removedRecords: dbFiles,
        modifiedRecords: const [],
        unchangedCount: 0,
      );
    }

    // 1. Gather Disk Entries (D) with non-blocking cooperative yielding
    final diskFiles = <String, ({int mtime, int size})>{};
    try {
      final entries = await dir.list(recursive: false, followLinks: false).toList();
      int count = 0;

      for (final entity in entries) {
        count++;
        if (count % 50 == 0) {
          // Cooperative microtask yield to preserve 60/120 FPS UI responsiveness
          await Future.delayed(Duration.zero);
        }

        if (entity is! File) continue;

        final basename = p.basename(entity.path);
        if (!showHidden && (basename.startsWith('.') || basename.startsWith(r'~$'))) {
          continue;
        }

        final type = fileSystemService.determineNodeType(entity.path, isDirectory: false);
        if (type != FileNodeType.videoFile && type != FileNodeType.audioFile) {
          continue; // Media whitelist check
        }

        try {
          final stat = await entity.stat();
          diskFiles[entity.path] = (
            mtime: stat.modified.millisecondsSinceEpoch,
            size: stat.size,
          );
        } catch (_) {}
      }
    } catch (_) {
      // Access denied or filesystem read failure
      return const ReconciliationDiff(
        addedPaths: [],
        removedRecords: [],
        modifiedRecords: [],
        unchangedCount: 0,
      );
    }

    // 2. Gather DB Entries (S)
    final dbFiles = await repository.getFilesByFolder(folderId, onlyPresent: true);
    final dbFileMap = <String, FileRecord>{};
    for (final f in dbFiles) {
      dbFileMap[f.mrl] = f;
    }

    // 3. Set Algebra Partitioning
    final addedPaths = <String>[];
    final removedRecords = <FileRecord>[];
    final modifiedRecords = <FileRecord>[];
    int unchangedCount = 0;

    // A. Check for Added or Modified files from Disk
    for (final entry in diskFiles.entries) {
      final diskMrl = entry.key;
      final diskStat = entry.value;
      final dbFile = dbFileMap[diskMrl];

      if (dbFile == null) {
        // d in D and d not in S
        addedPaths.add(diskMrl);
      } else {
        // d in D and s in S with identical MRL
        if (diskStat.mtime > dbFile.mtime || diskStat.size != dbFile.size) {
          modifiedRecords.add(dbFile.copyWith(
            mtime: diskStat.mtime,
            size: diskStat.size,
          ));
        } else {
          unchangedCount++;
        }
      }
    }

    // B. Check for Removed files (s in S and s not in D)
    for (final dbFile in dbFiles) {
      if (!diskFiles.containsKey(dbFile.mrl)) {
        removedRecords.add(dbFile);
      }
    }

    return ReconciliationDiff(
      addedPaths: addedPaths,
      removedRecords: removedRecords,
      modifiedRecords: modifiedRecords,
      unchangedCount: unchangedCount,
    );
  }
}
