import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/bookmarks/data/bookmark_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaBookmark Domain Model Tests', () {
    test('MediaBookmark serialization and deserialization', () {
      final now = DateTime.now();
      final bookmark = MediaBookmark(
        id: 'bm-1',
        mediaId: 'video-100',
        position: const Duration(minutes: 5, seconds: 32),
        label: 'Opening Scene',
        createdAt: now,
      );

      expect(bookmark.timestampMs, 332000);
      expect(bookmark.formattedTime, '05:32');

      final json = bookmark.toJson();
      expect(json['id'], 'bm-1');
      expect(json['mediaId'], 'video-100');
      expect(json['timestampMs'], 332000);
      expect(json['label'], 'Opening Scene');

      final restored = MediaBookmark.fromJson(json);
      expect(restored.id, bookmark.id);
      expect(restored.mediaId, bookmark.mediaId);
      expect(restored.position, bookmark.position);
      expect(restored.label, bookmark.label);
    });

    test('Formatted time handles hours correctly', () {
      final bookmark = MediaBookmark(
        id: 'bm-2',
        mediaId: 'video-100',
        position: const Duration(hours: 1, minutes: 24, seconds: 5),
        label: 'Climax Action',
        createdAt: DateTime.now(),
      );

      expect(bookmark.formattedTime, '01:24:05');
    });
  });

  group('BookmarkService In-Memory & Storage Operations', () {
    late Directory tempDir;
    late BookmarkService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bookmark_test_');
      service = BookmarkService(storageDir: tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Add, list, and sort bookmarks in chronological order', () async {
      await service.addBookmark(
        mediaId: 'movie-1',
        position: const Duration(minutes: 10),
        label: 'Chapter 2',
      );

      await service.addBookmark(
        mediaId: 'movie-1',
        position: const Duration(minutes: 2),
        label: 'Chapter 1',
      );

      await service.addBookmark(
        mediaId: 'movie-1',
        position: const Duration(minutes: 25),
        label: 'Chapter 3',
      );

      final bookmarks = service.getBookmarks('movie-1');
      expect(bookmarks.length, 3);
      // Chronological sort check
      expect(bookmarks[0].label, 'Chapter 1');
      expect(bookmarks[1].label, 'Chapter 2');
      expect(bookmarks[2].label, 'Chapter 3');
    });

    test('Auto-generated default label if label is null or empty', () async {
      final bm = await service.addBookmark(
        mediaId: 'movie-2',
        position: const Duration(seconds: 45),
      );

      expect(bm.label, 'Bookmark at 00:45');
    });

    test('Rename and remove bookmark', () async {
      final bm = await service.addBookmark(
        mediaId: 'movie-3',
        position: const Duration(minutes: 1),
        label: 'Old Name',
      );

      final renamed = await service.renameBookmark(bm.id, 'New Name');
      expect(renamed, isTrue);
      expect(service.getBookmarks('movie-3').first.label, 'New Name');

      final removed = await service.removeBookmark(bm.id);
      expect(removed, isTrue);
      expect(service.getBookmarks('movie-3'), isEmpty);
    });

    test('Deduplicates nearby bookmarks under 250ms threshold', () async {
      final bm1 = await service.addBookmark(
        mediaId: 'movie-4',
        position: const Duration(seconds: 10, milliseconds: 100),
        label: 'Initial',
      );

      final bm2 = await service.addBookmark(
        mediaId: 'movie-4',
        position: const Duration(seconds: 10, milliseconds: 200),
        label: 'Duplicate Attempt',
      );

      expect(bm2.id, bm1.id);
      expect(service.getBookmarks('movie-4').length, 1);
    });
  });
}
