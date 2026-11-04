import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'package:app/core/db/database_helper.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/library/domain/library_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Deleted Files & Folders Pruning Tests', () {
    late Directory tempRoot;
    late Directory folderA;
    late Directory folderB;
    late File fileA1;
    late File fileA2;
    late File fileB1;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseHelper.instance.clearAll();

      // Create isolated temporary folder structure
      tempRoot = await Directory.systemTemp.createTemp('eplayer_delete_test_');
      folderA = Directory(p.join(tempRoot.path, 'FolderA'));
      await folderA.create(recursive: true);
      folderB = Directory(p.join(tempRoot.path, 'FolderB'));
      await folderB.create(recursive: true);

      fileA1 = File(p.join(folderA.path, 'video_a1.mp4'));
      await fileA1.writeAsBytes([0, 1, 2, 3]);

      fileA2 = File(p.join(folderA.path, 'video_a2.mkv'));
      await fileA2.writeAsBytes([0, 1, 2, 3]);

      fileB1 = File(p.join(folderB.path, 'video_b1.mp4'));
      await fileB1.writeAsBytes([0, 1, 2, 3]);

      // Seed DatabaseHelper with all 3 files
      final items = [
        MediaItem(
          path: fileA1.path,
          name: 'video_a1.mp4',
          parentFolder: folderA.path,
          sizeBytes: 4,
          durationMs: 10000,
          lastPlayed: DateTime.now(),
        ),
        MediaItem(
          path: fileA2.path,
          name: 'video_a2.mkv',
          parentFolder: folderA.path,
          sizeBytes: 4,
          durationMs: 20000,
          lastPlayed: DateTime.now(),
        ),
        MediaItem(
          path: fileB1.path,
          name: 'video_b1.mp4',
          parentFolder: folderB.path,
          sizeBytes: 4,
          durationMs: 30000,
          lastPlayed: DateTime.now(),
        ),
      ];

      await DatabaseHelper.instance.insertBatch(items);
    });

    tearDown(() async {
      try {
        await DatabaseHelper.instance.clearAll();
      } catch (_) {}
      try {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Initial state contains all 3 files across 2 folders', () async {
      final provider = LibraryProvider();
      await provider.refreshLibrary();

      expect(provider.allFiles.length, 3);
      expect(provider.groupedFolders.keys.length, 2);
      expect(provider.groupedFolders.containsKey(folderA.path), isTrue);
      expect(provider.groupedFolders.containsKey(folderB.path), isTrue);
    });

    test('Deleting a single file removes it from library and database upon refresh', () async {
      final provider = LibraryProvider();
      await provider.refreshLibrary();
      expect(provider.allFiles.length, 3);

      // Delete fileA1 from disk
      await fileA1.delete();
      expect(await fileA1.exists(), isFalse);

      // Refresh library
      await provider.refreshLibrary();

      // fileA1 must be gone from allFiles
      final remainingPaths = provider.allFiles.map((f) => f.path).toList();
      expect(remainingPaths, isNot(contains(fileA1.path)));
      expect(remainingPaths, contains(fileA2.path));
      expect(remainingPaths, contains(fileB1.path));
      expect(provider.allFiles.length, 2);

      // Verify DatabaseHelper was also pruned
      final dbItems = await DatabaseHelper.instance.getAllItems();
      final dbPaths = dbItems.map((f) => f.path).toList();
      expect(dbPaths, isNot(contains(fileA1.path)));
      expect(dbPaths.length, 2);
    });

    test('Deleting an entire folder removes all its files and the folder itself upon refresh', () async {
      final provider = LibraryProvider();
      await provider.refreshLibrary();

      expect(provider.groupedFolders.containsKey(folderB.path), isTrue);

      // Delete entire FolderB and its contents from disk
      await folderB.delete(recursive: true);
      expect(await folderB.exists(), isFalse);
      expect(await fileB1.exists(), isFalse);

      // Refresh library
      await provider.refreshLibrary();

      // FolderB must no longer exist in groupedFolders or allFiles
      expect(provider.groupedFolders.containsKey(folderB.path), isFalse);
      expect(provider.allFiles.any((f) => f.path == fileB1.path), isFalse);
      expect(provider.allFiles.length, 2);

      // Verify DatabaseHelper was also pruned of fileB1
      final dbItems = await DatabaseHelper.instance.getAllItems();
      expect(dbItems.any((f) => f.path == fileB1.path), isFalse);
    });
  });
}
