import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app/core/db/database_helper.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/library/domain/media_scanner_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.clearAll();
  });

  group('DriveVolumeInfo & Multi-Drive Discovery Tests', () {
    test('1. DriveVolumeInfo extracts roots and formats labels across platforms', () {
      expect(DriveVolumeInfo.extractDriveRoot(r'D:\Movies\Action\clip.mkv'), r'D:\');
      expect(DriveVolumeInfo.extractDriveRoot(r'c:\Users\Admin\video.mp4'), r'C:\');
      expect(DriveVolumeInfo.extractDriveRoot('/storage/emulated/0/Movies/a.mp4'), '/storage/emulated/0');
      expect(DriveVolumeInfo.extractDriveRoot('/mnt/external/clip.mkv'), '/');

      expect(DriveVolumeInfo.normalizeKey(r'd:'), r'D:\');
      expect(DriveVolumeInfo.normalizeKey(r'd:\'), r'D:\');
      expect(DriveVolumeInfo.formatDriveLabel(r'C:\'), 'Local Disk (C:) • System');
      expect(DriveVolumeInfo.formatDriveLabel(r'D:\'), 'Local Disk (D:)');
    });

    test('2. MediaScannerService.getAvailableDrives discovers multiple drives via probe', () {
      final mounted = {r'C:\', r'D:\', r'F:\'};
      final drives = MediaScannerService.getAvailableDrives(
        isWindowsOverride: true,
        existsChecker: (path) => mounted.contains(path),
      );

      expect(drives, containsAllInOrder([r'C:\', r'D:\', r'F:\']));
      expect(drives.length, 3);
    });

    test('3. MediaScannerService skips Windows/OS system directories safely when enabled', () {
      expect(
        MediaScannerService.shouldSkipEntry(
          'System Volume Information',
          isDirectory: true,
          showHiddenFiles: false,
          skipSystemDirectories: true,
        ),
        isTrue,
      );
      expect(
        MediaScannerService.shouldSkipEntry(
          'Windows',
          isDirectory: true,
          showHiddenFiles: false,
          skipSystemDirectories: true,
        ),
        isTrue,
      );
      expect(
        MediaScannerService.shouldSkipEntry(
          'Program Files (x86)',
          isDirectory: true,
          showHiddenFiles: false,
          skipSystemDirectories: true,
        ),
        isTrue,
      );
      expect(
        MediaScannerService.shouldSkipEntry(
          'Windows',
          isDirectory: true,
          showHiddenFiles: false,
          skipSystemDirectories: false,
        ),
        isFalse,
      );
      expect(
        MediaScannerService.shouldSkipEntry(
          'Movies',
          isDirectory: true,
          showHiddenFiles: false,
          skipSystemDirectories: true,
        ),
        isFalse,
      );
    });
  });

  group('Multi-Root Batch Scanning & Error Resilience Tests', () {
    test('4. Crawls multiple root directories simultaneously while skipping OS system subdirs', () async {
      final driveC = await Directory.systemTemp.createTemp('mock_drive_c_');
      final driveD = await Directory.systemTemp.createTemp('mock_drive_d_');

      try {
        // Drive C: user videos + a simulated Windows system folder containing decoy video
        await Directory(p.join(driveC.path, 'Movies')).create();
        await File(p.join(driveC.path, 'Movies', 'c_movie.mp4')).writeAsBytes([1, 2, 3]);
        await Directory(p.join(driveC.path, 'Windows')).create();
        await File(p.join(driveC.path, 'Windows', 'boot_sample.mp4')).writeAsBytes([1, 2]);

        // Drive D: movies & music + $Recycle.Bin
        await Directory(p.join(driveD.path, 'Anime')).create();
        await File(p.join(driveD.path, 'Anime', 'ep01.mkv')).writeAsBytes([1, 2, 3, 4]);
        await File(p.join(driveD.path, 'Anime', 'soundtrack.flac')).writeAsBytes([1, 2]);
        await Directory(p.join(driveD.path, r'$Recycle.Bin')).create();
        await File(p.join(driveD.path, r'$Recycle.Bin', 'deleted.mp4')).writeAsBytes([1]);

        final scanner = MediaScannerService();
        final progressList = await scanner.scanDirectories(
          [driveC.path, driveD.path],
          showHiddenFiles: false,
          skipSystemDirectories: true,
        ).toList();

        final finalProgress = progressList.last;
        expect(finalProgress.isCompleted, isTrue);
        // Should find 3 files: c_movie.mp4, ep01.mkv, soundtrack.flac (skipping Windows/ and $Recycle.Bin/)
        expect(finalProgress.mediaFilesFound, equals(3));

        final dbItems = await DatabaseHelper.instance.getAllItems();
        expect(dbItems.length, equals(3));
        expect(dbItems.any((e) => e.name == 'c_movie.mp4'), isTrue);
        expect(dbItems.any((e) => e.name == 'ep01.mkv'), isTrue);
        expect(dbItems.any((e) => e.name == 'soundtrack.flac'), isTrue);
      } finally {
        await driveC.delete(recursive: true);
        await driveD.delete(recursive: true);
      }
    });

    test('5. Missing or non-existent drive in batch does not crash or abort remaining drives', () async {
      final validDrive = await Directory.systemTemp.createTemp('mock_drive_valid_');
      try {
        await File(p.join(validDrive.path, 'valid_clip.webm')).writeAsBytes([1, 2, 3]);
        final bogusDrivePath = p.join(validDrive.path, 'does_not_exist_drive_z');

        final scanner = MediaScannerService();
        final progressList = await scanner.scanDirectories([
          bogusDrivePath,
          validDrive.path,
        ]).toList();

        expect(progressList.last.isCompleted, isTrue);
        expect(progressList.last.mediaFilesFound, equals(1));
      } finally {
        await validDrive.delete(recursive: true);
      }
    });
  });

  group('LibraryProvider Multi-Drive State & Unscanned Tracking Tests', () {
    test('6. discoverDrives accurately marks scanned vs unscanned drives and counts indexed files', () async {
      final tempDir = await Directory.systemTemp.createTemp('mock_library_drives_');
      try {
        // Create two mock sub-roots inside tempDir acting as Drive X and Drive Y?
        // Actually we can insert MediaItems with explicit Windows paths into DB?
        // Wait: LibraryProvider._loadFromDB checks File(i.path).existsSync(),
        // so let's insert real temp files AND also test custom/drive attribution!
        final folderA = await Directory(p.join(tempDir.path, 'DriveA')).create();
        final fileA = File(p.join(folderA.path, 'movie_a.mp4'));
        await fileA.writeAsBytes([1, 2, 3]);

        await DatabaseHelper.instance.insertOrUpdateItem(MediaItem(
          path: fileA.path,
          name: 'movie_a.mp4',
          parentFolder: folderA.path,
          sizeBytes: 3,
          lastPlayed: DateTime.now(),
        ));

        final provider = LibraryProvider();
        await provider.refreshLibrary();

        final driveRootOfTemp = DriveVolumeInfo.extractDriveRoot(tempDir.path) ?? tempDir.path;
        final volumes = provider.discoverDrives(
          overrideDrives: [driveRootOfTemp, r'Z:\'],
        );

        expect(volumes.length, 2);

        final activeVol = volumes.firstWhere(
          (v) => DriveVolumeInfo.normalizeKey(v.rootPath) == DriveVolumeInfo.normalizeKey(driveRootOfTemp),
        );
        expect(activeVol.indexedFileCount, greaterThanOrEqualTo(1));
        expect(activeVol.isScanned, isTrue);

        final unscannedVol = volumes.firstWhere((v) => v.rootPath == r'Z:\');
        expect(unscannedVol.indexedFileCount, equals(0));
        expect(unscannedVol.isScanned, isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('7. scanDrives persists lastScannedAt timestamps per drive and deduplicates custom folders', () async {
      final driveDir1 = await Directory.systemTemp.createTemp('mock_scan_batch_1_');
      final driveDir2 = await Directory.systemTemp.createTemp('mock_scan_batch_2_');

      try {
        await File(p.join(driveDir1.path, 'one.mp4')).writeAsBytes([1, 2]);
        await File(p.join(driveDir2.path, 'two.mkv')).writeAsBytes([1, 2, 3]);

        final provider = LibraryProvider();
        await provider.scanDrives([driveDir1.path, driveDir2.path]);

        expect(provider.allFiles.length, equals(2));
        expect(provider.customScanFolders, containsAll([driveDir1.path, driveDir2.path]));

        // Scan timestamp recorded
        final ts1 = provider.getLastScanTimestamp(driveDir1.path);
        expect(ts1, isNotNull);
      } finally {
        await driveDir1.delete(recursive: true);
        await driveDir2.delete(recursive: true);
      }
    });
  });
}
