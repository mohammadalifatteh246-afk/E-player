import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/home/domain/media_group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaGroupService Unit Tests', () {
    late MediaGroupService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = MediaGroupService();
    });

    test('Initializes with empty groups', () {
      expect(service.groups, isEmpty);
    });

    test('Creates new group and notifies listeners', () async {
      final group = await service.createGroup(
        title: 'Action Movies',
        color: const Color(0xFF00E5FF),
        description: 'High octane films',
      );

      expect(service.groups.length, 1);
      expect(service.groups.first.title, 'Action Movies');
      expect(service.groups.first.description, 'High octane films');
      expect(service.groups.first.id, group.id);
    });

    test('Adds and removes media paths from group', () async {
      final group = await service.createGroup(
        title: '4K Demos',
        color: const Color(0xFF21D79A),
      );

      await service.addItemToGroup(group.id, '/storage/demo1.mp4');
      await service.addItemToGroup(group.id, '/storage/demo2.mkv');

      expect(service.groups.first.itemPaths.length, 2);
      expect(service.groups.first.itemPaths, contains('/storage/demo1.mp4'));

      await service.removeItemFromGroup(group.id, '/storage/demo1.mp4');
      expect(service.groups.first.itemPaths.length, 1);
      expect(service.groups.first.itemPaths, contains('/storage/demo2.mkv'));
    });

    test('Deletes group properly', () async {
      final g1 = await service.createGroup(title: 'Group 1');
      final g2 = await service.createGroup(title: 'Group 2');

      expect(service.groups.length, 2);

      await service.deleteGroup(g1.id);
      expect(service.groups.length, 1);
      expect(service.groups.first.id, g2.id);
    });

    test('addItemsToGroup adds multiple paths atomically and deduplicates', () async {
      final group = await service.createGroup(title: 'Batch Group');
      await service.addItemToGroup(group.id, '/media/existing.mp4');

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.addItemsToGroup(group.id, [
        '/media/existing.mp4',
        '/media/new1.mp4',
        '/media/new2.mkv',
        '/media/new1.mp4',
      ]);

      expect(service.groups.first.itemPaths, [
        '/media/existing.mp4',
        '/media/new1.mp4',
        '/media/new2.mkv',
      ]);
      expect(notifyCount, 1);

      // Verify persistence
      final reloadedService = MediaGroupService();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(reloadedService.groups.first.itemPaths, [
        '/media/existing.mp4',
        '/media/new1.mp4',
        '/media/new2.mkv',
      ]);
    });

    test('removeItemsFromGroup removes multiple paths atomically', () async {
      final group = await service.createGroup(
        title: 'Batch Remove',
        initialPaths: ['/m/1.mp4', '/m/2.mp4', '/m/3.mp4', '/m/4.mp4'],
      );

      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.removeItemsFromGroup(group.id, ['/m/2.mp4', '/m/4.mp4', '/m/nonexistent.mp4']);

      expect(service.groups.first.itemPaths, ['/m/1.mp4', '/m/3.mp4']);
      expect(notifyCount, 1);
    });

    test('moveItemsBetweenGroups atomically transfers items between groups', () async {
      final g1 = await service.createGroup(title: 'Source', initialPaths: ['/a.mp4', '/b.mp4', '/c.mp4']);
      final g2 = await service.createGroup(title: 'Destination', initialPaths: ['/x.mp4']);

      await service.moveItemsBetweenGroups(
        fromGroupId: g1.id,
        toGroupId: g2.id,
        paths: ['/a.mp4', '/c.mp4'],
      );

      final updatedG1 = service.groups.firstWhere((g) => g.id == g1.id);
      final updatedG2 = service.groups.firstWhere((g) => g.id == g2.id);

      expect(updatedG1.itemPaths, ['/b.mp4']);
      expect(updatedG2.itemPaths, ['/x.mp4', '/a.mp4', '/c.mp4']);
    });
  });
}
