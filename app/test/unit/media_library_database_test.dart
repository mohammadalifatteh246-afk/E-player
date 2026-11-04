import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app/core/db/media_library_database.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  late EPlayerTestHarness harness;
  late Database db;

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  setUp(() async {
    final tempDir = harness.createTempDirectory('db_test_');
    final dbPath = '${tempDir.path}/test_media_library.db';
    final dbHelper = MediaLibraryDatabase.withCustomPath(dbPath);
    db = await dbHelper.database;
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }
  });

  group('MediaLibraryDatabase SQLite Engine Tests', () {
    test('1. Pragmas and schemas are correctly initialized', () async {
      // Referential integrity
      final fkResult = await db.rawQuery('PRAGMA foreign_keys;');
      expect(Sqflite.firstIntValue(fkResult), equals(1));

      // Recursive triggers
      final rtResult = await db.rawQuery('PRAGMA recursive_triggers;');
      expect(Sqflite.firstIntValue(rtResult), equals(1));

      // Verify all tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('Device', 'Folder', 'Media', 'File', 'VideoTrack', 'AudioTrack', 'Task');",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();
      expect(tableNames, containsAll({'Device', 'Folder', 'Media', 'File', 'VideoTrack', 'AudioTrack', 'Task'}));
    });

    test('2. Reactive presence trigger cascades on device disconnect and reconnect', () async {
      // Insert Device
      final now = DateTime.now().millisecondsSinceEpoch;
      final devId = await db.insert('Device', {
        'uuid': 'usb_drive_alpha',
        'scheme': 'file://',
        'is_removable': 1,
        'is_present': 1,
        'last_seen': now,
      });

      // Insert Folder
      final folderId = await db.insert('Folder', {
        'path': 'E:\\Movies',
        'name': 'Movies',
        'device_id': devId,
        'mtime': now,
        'is_present': 1,
        'is_banned': 0,
        'nb_media': 1,
      });

      // Insert Media
      final mediaId = await db.insert('Media', {
        'type': 1,
        'title': 'Inception 4K',
        'duration': 8880000,
        'insertion_date': now,
        'is_present': 1,
      });

      // Insert File
      final fileId = await db.insert('File', {
        'media_id': mediaId,
        'folder_id': folderId,
        'mrl': 'E:\\Movies\\Inception.mkv',
        'type': 1,
        'mtime': now,
        'size': 1400000000,
        'is_present': 1,
      });

      expect(devId, greaterThan(0));
      expect(folderId, greaterThan(0));
      expect(mediaId, greaterThan(0));
      expect(fileId, greaterThan(0));

      // --- SIMULATE DEVICE DISMOUNT ---
      await db.update('Device', {'is_present': 0}, where: 'id_device = ?', whereArgs: [devId]);

      // Check cascading presence updates
      final folderAfterDismount = await db.query('Folder', where: 'id_folder = ?', whereArgs: [folderId]);
      expect(folderAfterDismount.first['is_present'], equals(0));

      final fileAfterDismount = await db.query('File', where: 'id_file = ?', whereArgs: [fileId]);
      expect(fileAfterDismount.first['is_present'], equals(0));

      final mediaAfterDismount = await db.query('Media', where: 'id_media = ?', whereArgs: [mediaId]);
      expect(mediaAfterDismount.first['is_present'], equals(0));

      // Invariant check: Metadata is NEVER deleted
      expect(mediaAfterDismount.first['title'], equals('Inception 4K'));
      expect(mediaAfterDismount.first['duration'], equals(8880000));

      // --- SIMULATE DEVICE REMOUNT ---
      await db.update('Device', {'is_present': 1}, where: 'id_device = ?', whereArgs: [devId]);

      final folderAfterRemount = await db.query('Folder', where: 'id_folder = ?', whereArgs: [folderId]);
      expect(folderAfterRemount.first['is_present'], equals(1));

      final fileAfterRemount = await db.query('File', where: 'id_file = ?', whereArgs: [fileId]);
      expect(fileAfterRemount.first['is_present'], equals(1));

      final mediaAfterRemount = await db.query('Media', where: 'id_media = ?', whereArgs: [mediaId]);
      expect(mediaAfterRemount.first['is_present'], equals(1));
    });

    test('3. FTS5 Search and sync triggers index titles dynamically', () async {
      // Check if MediaFts exists
      final ftsTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='MediaFts';",
      );
      if (ftsTables.isEmpty) return; // Skip if FTS5 not compiled in test SQLite binary

      final now = DateTime.now().millisecondsSinceEpoch;
      final mediaId = await db.insert('Media', {
        'type': 1,
        'title': 'Interstellar IMAX',
        'duration': 100000,
        'insertion_date': now,
        'is_present': 1,
      });

      // Verify trigger_media_ai inserted into MediaFts
      final ftsSearch = await db.rawQuery(
        "SELECT * FROM MediaFts WHERE MediaFts MATCH 'Interstellar*';",
      );
      expect(ftsSearch, isNotEmpty);
      expect(ftsSearch.first['title'], equals('Interstellar IMAX'));

      // Update Media title -> trigger_media_au updates FTS
      await db.update('Media', {'title': 'Interstellar Ultimate Cut'}, where: 'id_media = ?', whereArgs: [mediaId]);
      final ftsSearchUpdated = await db.rawQuery(
        "SELECT * FROM MediaFts WHERE MediaFts MATCH 'Ultimate*';",
      );
      expect(ftsSearchUpdated, isNotEmpty);

      // Delete Media -> trigger_media_ad cleans up FTS
      await db.delete('Media', where: 'id_media = ?', whereArgs: [mediaId]);
      final ftsSearchDeleted = await db.rawQuery(
        "SELECT * FROM MediaFts WHERE MediaFts MATCH 'Interstellar*';",
      );
      expect(ftsSearchDeleted, isEmpty);
    });

    test('4. migrateLegacyTable smoothly transfers flat media_items data', () async {
      // Create legacy table in test DB
      await db.execute('''
        CREATE TABLE IF NOT EXISTS media_items (
          _id INTEGER PRIMARY KEY AUTOINCREMENT,
          path TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          parentFolder TEXT NOT NULL,
          sizeBytes INTEGER NOT NULL,
          durationMs INTEGER NOT NULL,
          lastPositionMs INTEGER NOT NULL,
          lastPlayed INTEGER NOT NULL,
          isFavorite INTEGER NOT NULL
        );
      ''');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('media_items', {
        'path': 'C:\\Videos\\Nature.mp4',
        'name': 'Nature.mp4',
        'parentFolder': 'C:\\Videos',
        'sizeBytes': 25000000,
        'durationMs': 60000,
        'lastPositionMs': 12000,
        'lastPlayed': now,
        'isFavorite': 1,
      });

      // Run migration
      final helper = MediaLibraryDatabase.instance;
      await helper.migrateLegacyTable(db);

      // Verify Device created
      final devices = await db.query('Device', where: "uuid = 'local_fixed_volume'");
      expect(devices, isNotEmpty);

      // Verify Folder created
      final folders = await db.query('Folder', where: "path = 'C:\\Videos'");
      expect(folders, isNotEmpty);
      expect(folders.first['name'], equals('Videos'));

      // Verify Media created with favorite and position preserved
      final media = await db.query('Media', where: "title = 'Nature.mp4'");
      expect(media, isNotEmpty);
      expect(media.first['duration'], equals(60000));
      expect(media.first['last_position'], equals(12000));
      expect(media.first['is_favorite'], equals(1));

      // Verify File created
      final files = await db.query('File', where: "mrl = 'C:\\Videos\\Nature.mp4'");
      expect(files, isNotEmpty);
      expect(files.first['size'], equals(25000000));
    });
  });
}
