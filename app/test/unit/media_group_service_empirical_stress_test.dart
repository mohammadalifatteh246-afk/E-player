import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/home/domain/media_group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaGroupService Empirical Stress Tests (Milestone 1)', () {
    late MediaGroupService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = MediaGroupService();
    });

    // =========================================================================
    // 1. High Volume Batch Operations
    // =========================================================================
    group('1. High Volume Scale & Batch Performance', () {
      test('Batch adding 150+ paths atomically in a single operation', () async {
        final group = await service.createGroup(title: 'High Volume Group');
        expect(group.itemPaths, isEmpty);

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        final bulk150 = List.generate(150, (i) => '/storage/emulated/0/Movies/vid_${i.toString().padLeft(4, '0')}.mp4');
        final stopwatch = Stopwatch()..start();
        await service.addItemsToGroup(group.id, bulk150);
        stopwatch.stop();

        expect(notifyCount, 1, reason: 'Must notify listeners exactly once per batch');
        final currentGroup = service.groups.firstWhere((g) => g.id == group.id);
        expect(currentGroup.itemPaths.length, 150);
        expect(currentGroup.itemPaths, equals(bulk150));
        expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Batch add 150 must complete efficiently');

        // Add 500 more items on top
        final bulk500 = List.generate(500, (i) => '/storage/emulated/0/Movies/vid_${(i + 150).toString().padLeft(4, '0')}.mp4');
        await service.addItemsToGroup(group.id, bulk500);

        expect(notifyCount, 2);
        final updatedGroup = service.groups.firstWhere((g) => g.id == group.id);
        expect(updatedGroup.itemPaths.length, 650);
      });

      test('Batch removing 300+ paths atomically from large group', () async {
        final initialPaths = List.generate(500, (i) => '/storage/media/item_$i.mp4');
        final group = await service.createGroup(
          title: 'Bulk Remove Group',
          initialPaths: initialPaths,
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        final toRemove = List.generate(300, (i) => '/storage/media/item_$i.mp4');
        await service.removeItemsFromGroup(group.id, toRemove);

        expect(notifyCount, 1);
        final currentGroup = service.groups.firstWhere((g) => g.id == group.id);
        expect(currentGroup.itemPaths.length, 200);

        // Verify remaining items are items 300..499
        final expectedRemaining = List.generate(200, (i) => '/storage/media/item_${i + 300}.mp4');
        expect(currentGroup.itemPaths, equals(expectedRemaining));
      });

      test('Massive high-volume scale (1,000 items) batch add and verify order', () async {
        final group = await service.createGroup(title: '1K Items Group');
        final bulk1000 = List.generate(1000, (i) => '/storage/sdcard/4k_clip_${i.toString().padLeft(4, '0')}.mkv');

        final sw = Stopwatch()..start();
        await service.addItemsToGroup(group.id, bulk1000);
        sw.stop();

        final updated = service.groups.firstWhere((g) => g.id == group.id);
        expect(updated.itemPaths.length, 1000);
        expect(updated.itemPaths.first, '/storage/sdcard/4k_clip_0000.mkv');
        expect(updated.itemPaths.last, '/storage/sdcard/4k_clip_0999.mkv');
        expect(sw.elapsedMilliseconds, lessThan(1000), reason: '1,000 items batch add should execute within 1s');
      });
    });

    // =========================================================================
    // 2. Duplicate Resilience
    // =========================================================================
    group('2. Duplicate Resilience', () {
      test('Intra-batch duplicates are filtered out during add', () async {
        final group = await service.createGroup(
          title: 'Deduplication Test',
          initialPaths: ['/existing/a.mp4', '/existing/b.mp4'],
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        final batchWithDuplicates = [
          '/batch/new1.mp4',
          '/batch/new2.mp4',
          '/batch/new1.mp4', // duplicate
          '/batch/new3.mp4',
          '/batch/new2.mp4', // duplicate
          '/batch/new1.mp4', // duplicate
        ];

        await service.addItemsToGroup(group.id, batchWithDuplicates);

        expect(notifyCount, 1);
        final current = service.groups.firstWhere((g) => g.id == group.id);
        expect(current.itemPaths, [
          '/existing/a.mp4',
          '/existing/b.mp4',
          '/batch/new1.mp4',
          '/batch/new2.mp4',
          '/batch/new3.mp4',
        ]);
      });

      test('Inter-batch duplicates: items already in group are not duplicated', () async {
        final group = await service.createGroup(
          title: 'Existing Duplicates Test',
          initialPaths: ['/lib/vid1.mp4', '/lib/vid2.mp4'],
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.addItemsToGroup(group.id, [
          '/lib/vid1.mp4', // already exists
          '/lib/vid3.mp4', // new
          '/lib/vid2.mp4', // already exists
        ]);

        expect(notifyCount, 1);
        final current = service.groups.firstWhere((g) => g.id == group.id);
        expect(current.itemPaths, [
          '/lib/vid1.mp4',
          '/lib/vid2.mp4',
          '/lib/vid3.mp4',
        ]);
      });

      test('No-op batch add does not notify listeners or mutate storage', () async {
        final group = await service.createGroup(
          title: 'No-Op Add Test',
          initialPaths: ['/lib/a.mp4', '/lib/b.mp4'],
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        // Adding only items that already exist
        await service.addItemsToGroup(group.id, ['/lib/a.mp4', '/lib/b.mp4']);

        expect(notifyCount, 0, reason: 'Listeners must not be notified if no items were added');
        final current = service.groups.firstWhere((g) => g.id == group.id);
        expect(current.itemPaths, ['/lib/a.mp4', '/lib/b.mp4']);
      });

      test('Duplicate paths in remove batch are handled smoothly', () async {
        final group = await service.createGroup(
          title: 'Duplicate Remove Test',
          initialPaths: ['/item/1.mp4', '/item/2.mp4', '/item/3.mp4'],
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.removeItemsFromGroup(group.id, [
          '/item/2.mp4',
          '/item/2.mp4',
          '/item/2.mp4',
          '/item/nonexistent.mp4',
        ]);

        expect(notifyCount, 1);
        final current = service.groups.firstWhere((g) => g.id == group.id);
        expect(current.itemPaths, ['/item/1.mp4', '/item/3.mp4']);
      });

      test('No-op batch remove does not notify listeners or mutate storage', () async {
        final group = await service.createGroup(
          title: 'No-Op Remove Test',
          initialPaths: ['/item/1.mp4'],
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.removeItemsFromGroup(group.id, ['/nonexistent/1.mp4', '/nonexistent/2.mp4']);

        expect(notifyCount, 0, reason: 'Listeners must not be notified if no items were removed');
        final current = service.groups.firstWhere((g) => g.id == group.id);
        expect(current.itemPaths, ['/item/1.mp4']);
      });
    });

    // =========================================================================
    // 3. Edge Cases
    // =========================================================================
    group('3. Edge Cases', () {
      test('Non-existent group IDs do not throw or notify', () async {
        final group = await service.createGroup(title: 'Valid Group');
        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        // add to non-existent group
        await expectLater(
          service.addItemsToGroup('bogus_group_id', ['/test.mp4']),
          completes,
        );

        // remove from non-existent group
        await expectLater(
          service.removeItemsFromGroup('bogus_group_id', ['/test.mp4']),
          completes,
        );

        // move with non-existent source
        await expectLater(
          service.moveItemsBetweenGroups(
            fromGroupId: 'bogus_from',
            toGroupId: group.id,
            paths: ['/test.mp4'],
          ),
          completes,
        );

        // move with non-existent destination
        await expectLater(
          service.moveItemsBetweenGroups(
            fromGroupId: group.id,
            toGroupId: 'bogus_to',
            paths: ['/test.mp4'],
          ),
          completes,
        );

        // move between two non-existent groups
        await expectLater(
          service.moveItemsBetweenGroups(
            fromGroupId: 'bogus_1',
            toGroupId: 'bogus_2',
            paths: ['/test.mp4'],
          ),
          completes,
        );

        expect(notifyCount, 0, reason: 'Operations on non-existent groups must be silent no-ops');
        expect(service.groups.first.itemPaths, isEmpty);
      });

      test('Empty path lists in batch operations are safe no-ops', () async {
        final g1 = await service.createGroup(title: 'G1', initialPaths: ['/a.mp4']);
        final g2 = await service.createGroup(title: 'G2', initialPaths: ['/b.mp4']);

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.addItemsToGroup(g1.id, []);
        await service.removeItemsFromGroup(g1.id, []);
        await service.moveItemsBetweenGroups(fromGroupId: g1.id, toGroupId: g2.id, paths: []);

        expect(notifyCount, 0);
        expect(service.groups.firstWhere((g) => g.id == g1.id).itemPaths, ['/a.mp4']);
        expect(service.groups.firstWhere((g) => g.id == g2.id).itemPaths, ['/b.mp4']);
      });

      test('Whitespace paths, symbols, and Unicode strings are preserved and serialized', () async {
        final group = await service.createGroup(title: 'Special Paths Group');

        final specialPaths = [
          '/storage/Spaces in folder name/My Video File (2024).mp4',
          '/storage/日本語/アニメ 第一話.mkv',
          '/storage/Symbols !@#\$%^&*()-_+=~[]{};:,.<>?.mp4',
          '   ', // pure whitespace
          '',      // empty string
        ];

        await service.addItemsToGroup(group.id, specialPaths);

        final current = service.groups.firstWhere((g) => g.id == group.id);
        expect(current.itemPaths.length, 5);
        expect(current.itemPaths, equals(specialPaths));

        // Verify remove works on special paths
        await service.removeItemsFromGroup(group.id, ['', '   ']);
        final afterRemove = service.groups.firstWhere((g) => g.id == group.id);
        expect(afterRemove.itemPaths.length, 3);
        expect(afterRemove.itemPaths, equals(specialPaths.sublist(0, 3)));
      });

      test('Self-move edge case (fromGroupId == toGroupId) is safe', () async {
        final group = await service.createGroup(
          title: 'Self Move Group',
          initialPaths: ['/a.mp4', '/b.mp4', '/c.mp4'],
        );

        await service.moveItemsBetweenGroups(
          fromGroupId: group.id,
          toGroupId: group.id,
          paths: ['/b.mp4'],
        );

        final current = service.groups.firstWhere((g) => g.id == group.id);
        // Ensure no corruption occurs
        expect(current.itemPaths.toSet(), equals({'/a.mp4', '/b.mp4', '/c.mp4'}));
      });
    });

    // =========================================================================
    // 4. Transfer Integrity
    // =========================================================================
    group('4. Transfer Integrity (moveItemsBetweenGroups)', () {
      test('Moving items from non-empty group to empty group', () async {
        final g1 = await service.createGroup(
          title: 'Source G1',
          initialPaths: List.generate(100, (i) => '/path/item_$i.mp4'),
        );
        final g2 = await service.createGroup(
          title: 'Destination G2 (Empty)',
          initialPaths: [],
        );

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        final toMove = List.generate(40, (i) => '/path/item_$i.mp4');
        await service.moveItemsBetweenGroups(
          fromGroupId: g1.id,
          toGroupId: g2.id,
          paths: toMove,
        );

        expect(notifyCount, 1, reason: 'Atomic transfer must trigger single notification');

        final updatedG1 = service.groups.firstWhere((g) => g.id == g1.id);
        final updatedG2 = service.groups.firstWhere((g) => g.id == g2.id);

        expect(updatedG1.itemPaths.length, 60);
        expect(updatedG2.itemPaths.length, 40);

        // Verify G1 no longer has any moved items
        for (final p in toMove) {
          expect(updatedG1.itemPaths.contains(p), isFalse);
        }
        // Verify G2 has exact moved items in order
        expect(updatedG2.itemPaths, equals(toMove));
      });

      test('Moving ALL items between groups (drains source completely)', () async {
        final g1 = await service.createGroup(
          title: 'Drain Source',
          initialPaths: ['/vid1.mp4', '/vid2.mp4', '/vid3.mp4'],
        );
        final g2 = await service.createGroup(
          title: 'Target Group',
          initialPaths: ['/existing.mp4'],
        );

        await service.moveItemsBetweenGroups(
          fromGroupId: g1.id,
          toGroupId: g2.id,
          paths: ['/vid1.mp4', '/vid2.mp4', '/vid3.mp4'],
        );

        final updatedG1 = service.groups.firstWhere((g) => g.id == g1.id);
        final updatedG2 = service.groups.firstWhere((g) => g.id == g2.id);

        expect(updatedG1.itemPaths, isEmpty);
        expect(updatedG2.itemPaths, [
          '/existing.mp4',
          '/vid1.mp4',
          '/vid2.mp4',
          '/vid3.mp4',
        ]);
      });

      test('Moving items with overlapping elements into destination deduplicates', () async {
        final g1 = await service.createGroup(
          title: 'Overlap Source',
          initialPaths: ['/a.mp4', '/b.mp4', '/overlap.mp4'],
        );
        final g2 = await service.createGroup(
          title: 'Overlap Target',
          initialPaths: ['/overlap.mp4', '/c.mp4'],
        );

        await service.moveItemsBetweenGroups(
          fromGroupId: g1.id,
          toGroupId: g2.id,
          paths: ['/b.mp4', '/overlap.mp4'],
        );

        final updatedG1 = service.groups.firstWhere((g) => g.id == g1.id);
        final updatedG2 = service.groups.firstWhere((g) => g.id == g2.id);

        expect(updatedG1.itemPaths, ['/a.mp4']);
        // Destination should not have duplicate /overlap.mp4
        expect(updatedG2.itemPaths, ['/overlap.mp4', '/c.mp4', '/b.mp4']);
      });
    });

    // =========================================================================
    // 5. Persistence Integrity (SharedPreferences Reload)
    // =========================================================================
    group('5. Persistence Integrity & Cold Reload', () {
      test('Complex sequence of batch mutations persists and reloads with exact match', () async {
        // Step 1: Create 4 groups
        final g0 = await service.createGroup(title: 'G0 Empty');
        final g1 = await service.createGroup(
          title: 'G1 150 Items',
          initialPaths: List.generate(150, (i) => '/g1/path_$i.mp4'),
        );
        final g2 = await service.createGroup(
          title: 'G2 50 Items',
          initialPaths: List.generate(50, (i) => '/g2/path_$i.mp4'),
        );
        final g3 = await service.createGroup(
          title: 'G3 20 Items',
          initialPaths: List.generate(20, (i) => '/g3/path_$i.mp4'),
        );

        // Step 2: Batch add items to g0
        await service.addItemsToGroup(g0.id, ['/g0/new1.mp4', '/g0/new2.mp4']);

        // Step 3: Batch move 30 items from g1 to g0
        final moveList = List.generate(30, (i) => '/g1/path_$i.mp4');
        await service.moveItemsBetweenGroups(
          fromGroupId: g1.id,
          toGroupId: g0.id,
          paths: moveList,
        );

        // Step 4: Batch remove 20 items from g2
        final removeList = List.generate(20, (i) => '/g2/path_$i.mp4');
        await service.removeItemsFromGroup(g2.id, removeList);

        // Step 5: Delete g3
        await service.deleteGroup(g3.id);

        // Capture memory state before reload
        final expectedGroups = List<MediaGroup>.from(service.groups);
        expect(expectedGroups.length, 3);

        // Step 6: Create completely new service instance simulating app restart
        final reloadedService = MediaGroupService();
        int attempts = 0;
        while (!reloadedService.isLoaded && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 25));
          attempts++;
        }

        expect(reloadedService.isLoaded, isTrue);
        expect(reloadedService.groups.length, expectedGroups.length);

        for (int i = 0; i < expectedGroups.length; i++) {
          final expected = expectedGroups[i];
          final actual = reloadedService.groups[i];

          expect(actual.id, equals(expected.id));
          expect(actual.title, equals(expected.title));
          expect(actual.description, equals(expected.description));
          expect(actual.colorValue, equals(expected.colorValue));
          expect(actual.iconName, equals(expected.iconName));
          expect(actual.itemPaths, equals(expected.itemPaths));
        }

        // Verify g0 contents in reloaded service
        final reloadedG0 = reloadedService.groups.firstWhere((g) => g.id == g0.id);
        expect(reloadedG0.itemPaths.length, 32); // 2 + 30 moved
        expect(reloadedG0.itemPaths.take(2).toList(), ['/g0/new1.mp4', '/g0/new2.mp4']);

        // Verify g1 contents in reloaded service
        final reloadedG1 = reloadedService.groups.firstWhere((g) => g.id == g1.id);
        expect(reloadedG1.itemPaths.length, 120); // 150 - 30 moved

        // Verify g2 contents in reloaded service
        final reloadedG2 = reloadedService.groups.firstWhere((g) => g.id == g2.id);
        expect(reloadedG2.itemPaths.length, 30); // 50 - 20 removed
      });

      test('High volume (1,000 paths) persistence round-trip integrity', () async {
        final bulk1000 = List.generate(1000, (i) => '/storage/emulated/0/DCIM/Camera/VID_20261104_${i.toString().padLeft(6, '0')}.mp4');
        final group = await service.createGroup(
          title: 'High Vol Persistence',
          initialPaths: bulk1000,
        );

        // Verify directly in SharedPreferences raw string
        final prefs = await SharedPreferences.getInstance();
        final rawJson = prefs.getString('eplayer_custom_media_groups_v1');
        expect(rawJson, isNotNull);
        final decoded = jsonDecode(rawJson!) as List<dynamic>;
        expect(decoded.length, 1);
        final storedGroup = decoded.first as Map<String, dynamic>;
        expect(storedGroup['id'], group.id);
        expect((storedGroup['itemPaths'] as List).length, 1000);

        // Reload via new service instance
        final freshService = MediaGroupService();
        int attempts = 0;
        while (!freshService.isLoaded && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 25));
          attempts++;
        }

        expect(freshService.isLoaded, isTrue);
        final reloadedGroup = freshService.groups.firstWhere((g) => g.id == group.id);
        expect(reloadedGroup.itemPaths.length, 1000);
        expect(reloadedGroup.itemPaths, equals(bulk1000));
      });
    });
  });
}
