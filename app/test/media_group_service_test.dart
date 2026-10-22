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
  });
}
