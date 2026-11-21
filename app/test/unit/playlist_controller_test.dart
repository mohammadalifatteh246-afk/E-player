import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/player/services/playlist_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistController controller;
  late List<MediaItem> sampleItems;

  setUp(() {
    controller = PlaylistController();
    sampleItems = [
      MediaItem(
        path: 'C:/Movies/Inception.mkv',
        name: 'Inception.mkv',
        parentFolder: 'C:/Movies',
        durationMs: 8880000,
        lastPlayed: DateTime.now(),
      ),
      MediaItem(
        path: 'C:/Movies/Interstellar.mkv',
        name: 'Interstellar.mkv',
        parentFolder: 'C:/Movies',
        durationMs: 10140000,
        lastPlayed: DateTime.now(),
      ),
      MediaItem(
        path: 'C:/Movies/Dunkirk.mp4',
        name: 'Dunkirk.mp4',
        parentFolder: 'C:/Movies',
        durationMs: 6360000,
        lastPlayed: DateTime.now(),
      ),
    ];
  });

  tearDown(() {
    controller.dispose();
  });

  group('PlaylistController (VLC pl-dock-status Parity) - Unit Tests', () {
    test('Initializes with default geometry and undocked floating mode', () {
      expect(controller.items, isEmpty);
      expect(controller.isUndocked, isTrue);
      expect(controller.isMinimized, isFalse);
      expect(controller.isVisible, isFalse);
      expect(controller.searchQuery, isEmpty);
      expect(controller.currentIndex, equals(-1));
      expect(controller.currentItem, isNull);
    });

    test('Setting items and active path updates current track accurately', () {
      controller.setItems(sampleItems, activePath: 'C:/Movies/Interstellar.mkv');

      expect(controller.items.length, equals(3));
      expect(controller.currentIndex, equals(1));
      expect(controller.currentItem?.name, equals('Interstellar.mkv'));
      expect(controller.currentPlayingPath, equals('C:/Movies/Interstellar.mkv'));
    });

    test('Track progression (next and previous) works sequentially', () {
      controller.setItems(sampleItems, activePath: 'C:/Movies/Inception.mkv');

      final nextTrack = controller.getNextTrack();
      expect(nextTrack?.name, equals('Interstellar.mkv'));

      controller.setCurrentPlayingPath(nextTrack!.path);
      final thirdTrack = controller.getNextTrack();
      expect(thirdTrack?.name, equals('Dunkirk.mp4'));

      controller.setCurrentPlayingPath(thirdTrack!.path);
      // End of playlist without repeat
      expect(controller.getNextTrack(), isNull);

      // With repeat all
      controller.toggleRepeat();
      expect(controller.isRepeatAll, isTrue);
      expect(controller.getNextTrack()?.name, equals('Inception.mkv'));

      // Previous track
      final prevTrack = controller.getPreviousTrack();
      expect(prevTrack?.name, equals('Interstellar.mkv'));
    });

    test('Search query filters items dynamically', () {
      controller.setItems(sampleItems);

      controller.setSearchQuery('Dunk');
      expect(controller.filteredItems.length, equals(1));
      expect(controller.filteredItems.first.name, equals('Dunkirk.mp4'));

      controller.setSearchQuery('non_existent');
      expect(controller.filteredItems, isEmpty);

      controller.setSearchQuery('');
      expect(controller.filteredItems.length, equals(3));
    });

    test('Position updates clamp cleanly within screen boundaries', () {
      const screenSize = Size(1000, 800);
      controller.updatePosition(const Offset(200, 200), screenSize: screenSize);

      expect(controller.position.dx, equals(230)); // 30 + 200
      expect(controller.position.dy, equals(280)); // 80 + 200

      // Clamp test exceeding right edge
      controller.updatePosition(const Offset(2000, 2000), screenSize: screenSize);
      final maxX = 1000 - controller.panelSize.width;
      expect(controller.position.dx, equals(maxX));
    });

    test('Dock and minimize toggles change flags and notify listeners', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.toggleDock();
      expect(controller.isUndocked, isFalse);
      expect(notified, isTrue);

      notified = false;
      controller.toggleMinimized();
      expect(controller.isMinimized, isTrue);
      expect(notified, isTrue);
    });

    test('Export and import playlist roundtrip updates items accurately', () async {
      final tempDir = Directory.systemTemp.createTempSync('playlist_ctrl_test_');
      final exportPath = '${tempDir.path}/exported_queue.m3u8';

      controller.setItems(sampleItems);
      expect(controller.items.length, 3);

      final exportedFile = await controller.exportPlaylist(exportPath);
      expect(exportedFile.existsSync(), isTrue);

      // Create a new controller and import
      final newController = PlaylistController();
      final count = await newController.importPlaylist(exportPath);
      expect(count, 3);
      expect(newController.items.length, 3);
      expect(newController.items[0].name, 'Inception.mkv');
      expect(newController.currentPlayingPath, sampleItems[0].path);

      newController.dispose();
      tempDir.deleteSync(recursive: true);
    });
  });
}
