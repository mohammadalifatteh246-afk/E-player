import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/core/db/database_helper.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/home/domain/media_group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MediaGroupService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('challenger_stress_');
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseHelper.instance.database;
    await db.delete('media_items');
    service = MediaGroupService();
    await Future.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // =========================================================================
  // 1. Batch Deletion Stress (deleteGroups)
  // =========================================================================
  group('1. Batch Deletion (deleteGroups) Atomic Stress Testing', () {
    test('Batch delete 50 custom groups simultaneously triggers exactly 1 notification', () async {
      final createdGroups = <MediaGroup>[];
      for (var i = 0; i < 50; i++) {
        final g = await service.createGroup(
          title: 'Bulk Group $i',
          initialPaths: ['/media/vid_$i.mp4'],
        );
        createdGroups.add(g);
      }
      expect(service.groups.length, 50);

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      // Delete 25 even groups
      final toDeleteIds = createdGroups
          .asMap()
          .entries
          .where((e) => e.key % 2 == 0)
          .map((e) => e.value.id)
          .toList();
      expect(toDeleteIds.length, 25);

      final sw = Stopwatch()..start();
      await service.deleteGroups(toDeleteIds);
      sw.stop();

      expect(notifyCount, 1, reason: 'Atomic batch deletion must notify listeners exactly once');
      expect(service.groups.length, 25);
      expect(sw.elapsedMilliseconds, lessThan(500));

      // Verify surviving groups are only odd ones
      for (final g in service.groups) {
        expect(toDeleteIds.contains(g.id), isFalse);
      }

      // Verify persistence by reloading
      final reloaded = MediaGroupService();
      await Future.delayed(const Duration(milliseconds: 30));
      expect(reloaded.groups.length, 25);
      for (final g in reloaded.groups) {
        expect(toDeleteIds.contains(g.id), isFalse);
      }

      // Now batch delete remaining 25
      notifyCount = 0;
      final remainingIds = service.groups.map((g) => g.id).toList();
      await service.deleteGroups(remainingIds);

      expect(notifyCount, 1);
      expect(service.groups, isEmpty);

      // Verify persistence holds empty list
      final emptyReloaded = MediaGroupService();
      await Future.delayed(const Duration(milliseconds: 30));
      expect(emptyReloaded.groups, isEmpty);
    });

    test('deleteGroups with empty list is a safe no-op and does not notify', () async {
      final g = await service.createGroup(title: 'Untouched');
      expect(service.groups.length, 1);

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.deleteGroups([]);
      await service.deleteGroups(const {});

      expect(notifyCount, 0, reason: 'Empty batch delete must not notify');
      expect(service.groups.length, 1);
      expect(service.groups.first.id, g.id);
    });

    test('deleteGroups with non-existent IDs is a safe no-op and does not notify', () async {
      final g = await service.createGroup(title: 'Safe Group');
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.deleteGroups(['phantom_1', 'phantom_2', 'phantom_3']);

      expect(notifyCount, 0);
      expect(service.groups.length, 1);
      expect(service.groups.first.id, g.id);
    });

    test('deleteGroups with mixed valid and non-existent IDs removes only valid and notifies once', () async {
      final g1 = await service.createGroup(title: 'Keep 1');
      final g2 = await service.createGroup(title: 'Remove 1');
      final g3 = await service.createGroup(title: 'Keep 2');
      final g4 = await service.createGroup(title: 'Remove 2');

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.deleteGroups([g2.id, 'phantom_x', g4.id, 'phantom_y', 'phantom_z']);

      expect(notifyCount, 1);
      expect(service.groups.length, 2);
      expect(service.groups.map((g) => g.id), containsAll([g1.id, g3.id]));
      expect(service.groups.any((g) => g.id == g2.id), isFalse);
      expect(service.groups.any((g) => g.id == g4.id), isFalse);
    });
  });

  // =========================================================================
  // 2. Self-Move Idempotency & Edge Cases (moveItemsBetweenGroups)
  // =========================================================================
  group('2. Self-Move Idempotency & Edge Cases (moveItemsBetweenGroups)', () {
    test('Self-move (fromGroupId == toGroupId) with non-empty paths is strictly idempotent', () async {
      final paths = ['/a.mp4', '/b.mp4', '/c.mp4'];
      final g = await service.createGroup(title: 'Self-Move Test', initialPaths: paths);

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.moveItemsBetweenGroups(
        fromGroupId: g.id,
        toGroupId: g.id,
        paths: ['/b.mp4', '/c.mp4'],
      );

      expect(notifyCount, 0, reason: 'Self-move must early return and not notify');
      final current = service.groups.firstWhere((grp) => grp.id == g.id);
      expect(current.itemPaths, equals(paths));
    });

    test('Self-move (fromGroupId == toGroupId) with empty paths is strictly idempotent', () async {
      final paths = ['/x.mp4', '/y.mp4'];
      final g = await service.createGroup(title: 'Self-Move Empty', initialPaths: paths);

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.moveItemsBetweenGroups(
        fromGroupId: g.id,
        toGroupId: g.id,
        paths: [],
      );

      expect(notifyCount, 0);
      final current = service.groups.firstWhere((grp) => grp.id == g.id);
      expect(current.itemPaths, equals(paths));
    });

    test('Move between different groups with empty paths does nothing and does not notify', () async {
      final g1 = await service.createGroup(title: 'G1', initialPaths: ['/1.mp4']);
      final g2 = await service.createGroup(title: 'G2', initialPaths: ['/2.mp4']);

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.moveItemsBetweenGroups(
        fromGroupId: g1.id,
        toGroupId: g2.id,
        paths: [],
      );

      expect(notifyCount, 0);
      expect(service.groups.firstWhere((g) => g.id == g1.id).itemPaths, ['/1.mp4']);
      expect(service.groups.firstWhere((g) => g.id == g2.id).itemPaths, ['/2.mp4']);
    });

    test('Move paths that do not exist in source group does not corrupt destination', () async {
      final g1 = await service.createGroup(title: 'Source', initialPaths: ['/actual.mp4']);
      final g2 = await service.createGroup(title: 'Target', initialPaths: ['/target.mp4']);

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.moveItemsBetweenGroups(
        fromGroupId: g1.id,
        toGroupId: g2.id,
        paths: ['/phantom.mp4'],
      );

      expect(notifyCount, 1);
      final updatedG1 = service.groups.firstWhere((g) => g.id == g1.id);
      final updatedG2 = service.groups.firstWhere((g) => g.id == g2.id);

      expect(updatedG1.itemPaths, ['/actual.mp4']);
      expect(updatedG2.itemPaths, ['/target.mp4', '/phantom.mp4']);
    });
  });

  // =========================================================================
  // 3. Non-Destructive Guarantees (SQLite & Disk Isolation)
  // =========================================================================
  group('3. Non-Destructive Guarantees (SQLite & Disk Isolation)', () {
    test('Deleting custom groups NEVER deletes SQLite rows in media_items table or disk files', () async {
      final file1 = File('${tempDir.path}/movie_alpha.mp4');
      await file1.writeAsBytes(List.generate(1024, (i) => i % 256), flush: true);

      final file2 = File('${tempDir.path}/movie_beta.mp4');
      await file2.writeAsBytes(List.generate(2048, (i) => (i * 3) % 256), flush: true);

      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);

      final item1 = MediaItem(
        path: file1.path,
        name: 'movie_alpha.mp4',
        parentFolder: tempDir.path,
        sizeBytes: 1024,
        durationMs: 60000,
        lastPlayed: DateTime.now(),
      );
      final item2 = MediaItem(
        path: file2.path,
        name: 'movie_beta.mp4',
        parentFolder: tempDir.path,
        sizeBytes: 2048,
        durationMs: 120000,
        lastPlayed: DateTime.now(),
      );

      await DatabaseHelper.instance.insertBatch([item1, item2]);
      var dbItems = await DatabaseHelper.instance.getAllItems();
      expect(dbItems.length, 2);

      final g1 = await service.createGroup(
        title: 'Group 1',
        initialPaths: [file1.path, file2.path],
      );
      final g2 = await service.createGroup(
        title: 'Group 2',
        initialPaths: [file1.path],
      );
      expect(service.groups.length, 2);

      await service.deleteGroups([g1.id, g2.id]);
      expect(service.groups, isEmpty);

      dbItems = await DatabaseHelper.instance.getAllItems();
      expect(dbItems.length, 2, reason: 'Deleting custom groups must NEVER alter DatabaseHelper table');
      expect(dbItems.any((i) => i.path == file1.path), isTrue);
      expect(dbItems.any((i) => i.path == file2.path), isTrue);

      expect(file1.existsSync(), isTrue, reason: 'Deleting custom groups must NEVER delete disk files');
      expect(file2.existsSync(), isTrue, reason: 'Deleting custom groups must NEVER delete disk files');
      expect(file1.lengthSync(), 1024);
      expect(file2.lengthSync(), 2048);
    });

    test('Moving items between groups NEVER affects SQLite table or disk files', () async {
      final file = File('${tempDir.path}/clip.mp4');
      await file.writeAsString('test video payload', flush: true);

      final item = MediaItem(
        path: file.path,
        name: 'clip.mp4',
        parentFolder: tempDir.path,
        sizeBytes: 18,
        durationMs: 1000,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(item);

      final g1 = await service.createGroup(title: 'Source G', initialPaths: [file.path]);
      final g2 = await service.createGroup(title: 'Dest G', initialPaths: []);

      await service.moveItemsBetweenGroups(
        fromGroupId: g1.id,
        toGroupId: g2.id,
        paths: [file.path],
      );

      expect(service.groups.firstWhere((g) => g.id == g1.id).itemPaths, isEmpty);
      expect(service.groups.firstWhere((g) => g.id == g2.id).itemPaths, [file.path]);

      final allDbItems = await DatabaseHelper.instance.getAllItems();
      expect(allDbItems.any((i) => i.path == file.path), isTrue);
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), 'test video payload');
    });
  });

  // =========================================================================
  // 4. Unicode, Emoji, Long Strings & Injection Robustness
  // =========================================================================
  group('4. Unicode, Emoji, Long Strings & Injection Robustness', () {
    test('Handles rich emoji, RTL, CJK, Cyrillic, and special symbols in group titles', () async {
      final exoticTitles = [
        '🎬 🍿 Blockbusters & Chill 🔥 🚀 🎧 🌟',
        'مجموعة أفلام 2026 الحصرية (RTL Test)',
        'סרטים וסדרות מומלצים לשנת 2026',
        '日本語のアニメ 劇場版 4K HDR [新劇場版]',
        'Фильмы и Сериалы — Шедевры Кинематографа',
        'Édition Française Spéciale: Café & Cinéma',
        r'Symbols: !@#$%^&*()_+-=[]{}|;:",.<>/?`~',
        '{"injection": true, "groups": [], "itemPaths": ["/hacked.mp4"]}',
      ];

      for (final title in exoticTitles) {
        final g = await service.createGroup(title: title);
        expect(g.title, title.trim());
      }

      expect(service.groups.length, exoticTitles.length);

      final reloaded = MediaGroupService();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(reloaded.groups.length, exoticTitles.length);
      for (final title in exoticTitles) {
        expect(
          reloaded.groups.any((g) => g.title == title.trim()),
          isTrue,
          reason: 'Group title "$title" must survive SharedPreferences round-trip',
        );
      }
    });

    test('Massive long string (10,000 chars) in title and description', () async {
      final hugeTitle = 'TITLE_${'A' * 9994}';
      final hugeDesc = 'DESC_${'D' * 9995}';

      final g = await service.createGroup(
        title: hugeTitle,
        description: hugeDesc,
      );

      expect(g.title.length, 10000);
      expect(g.description.length, 10000);

      final reloaded = MediaGroupService();
      await Future.delayed(const Duration(milliseconds: 50));
      final loadedGroup = reloaded.groups.firstWhere((grp) => grp.id == g.id);
      expect(loadedGroup.title.length, 10000);
      expect(loadedGroup.description.length, 10000);
    });

    test('Whitespace-only titles normalize to "New Group"', () async {
      final whitespaceTitles = [
        '',
        ' ',
        '   ',
        '\t\t\n  \r\n',
      ];

      for (final t in whitespaceTitles) {
        final g = await service.createGroup(title: t);
        expect(g.title, 'New Group');
      }
    });
  });

  // =========================================================================
  // 5. Interleaved & High-Frequency Concurrent Operations
  // =========================================================================
  group('5. Interleaved High-Frequency Mutex Simulation', () {
    test('Interleaved create, add, move, and batch delete maintains data consistency', () async {
      final groups = <MediaGroup>[];
      for (var i = 0; i < 10; i++) {
        final g = await service.createGroup(
          title: 'Interleaved $i',
          initialPaths: ['/seed/$i.mp4'],
        );
        groups.add(g);
      }

      for (var i = 0; i < 10; i++) {
        final paths = List.generate(20, (k) => '/data/${groups[i].id}_$k.mp4');
        await service.addItemsToGroup(groups[i].id, paths);
      }

      for (var i = 0; i < 10; i++) {
        final source = groups[i];
        final dest = groups[(i + 1) % 10];
        final moveList = List.generate(5, (k) => '/data/${source.id}_$k.mp4');
        await service.moveItemsBetweenGroups(
          fromGroupId: source.id,
          toGroupId: dest.id,
          paths: moveList,
        );
      }

      final deleteBatch = groups.take(5).map((g) => g.id).toList();
      await service.deleteGroups(deleteBatch);

      expect(service.groups.length, 5);

      final reloaded = MediaGroupService();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(reloaded.groups.length, 5);
      for (final deletedId in deleteBatch) {
        expect(reloaded.groups.any((g) => g.id == deletedId), isFalse);
      }
    });
  });
}
