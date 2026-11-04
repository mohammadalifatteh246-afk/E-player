import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/core/models/media_library_models.dart';
import 'package:app/core/db/media_library_database.dart';
import 'package:app/core/db/media_library_repository.dart';
import 'package:app/core/db/task_queue_repository.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  late EPlayerTestHarness harness;
  late Database db;
  late MediaLibraryRepository repository;
  late TaskQueueRepository taskQueue;

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  setUp(() async {
    final tempDir = harness.createTempDirectory('repo_test_');
    final dbPath = '${tempDir.path}/test_repo.db';
    final dbHelper = MediaLibraryDatabase.withCustomPath(dbPath);
    db = await dbHelper.database;
    repository = SqliteMediaLibraryRepository(database: db);
    taskQueue = SqliteTaskQueueRepository(database: db);
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }
  });

  group('MediaLibraryRepository & TaskQueueRepository Tests', () {
    test('1. Device and Folder CRUD operations', () async {
      final now = DateTime.now();
      final devId = await repository.upsertDevice(DeviceRecord(
        uuid: 'test_drive_uuid',
        scheme: 'file://',
        isRemovable: true,
        lastSeen: now,
      ));
      expect(devId, greaterThan(0));

      final dev = await repository.getDeviceByUuid('test_drive_uuid');
      expect(dev, isNotNull);
      expect(dev!.isRemovable, isTrue);

      final folderId = await repository.upsertFolder(FolderRecord(
        path: 'D:\\Media',
        name: 'Media',
        deviceId: devId,
        mtime: now.millisecondsSinceEpoch,
        isPresent: true,
        isBanned: false,
      ));
      expect(folderId, greaterThan(0));

      final folder = await repository.getFolderByPath('D:\\Media');
      expect(folder, isNotNull);
      expect(folder!.name, equals('Media'));

      // Update media count
      await repository.updateFolderMediaCount(folderId, 42);
      final updatedFolder = await repository.getFolderById(folderId);
      expect(updatedFolder!.nbMedia, equals(42));
    });

    test('2. Media and File CRUD, favorites and playback updates', () async {
      final now = DateTime.now();
      final mediaId = await repository.insertMedia(MediaRecord(
        type: MediaType.video,
        title: 'The Dark Knight',
        duration: 9000000,
        insertionDate: now,
      ));
      expect(mediaId, greaterThan(0));

      final media = await repository.getMediaById(mediaId);
      expect(media, isNotNull);
      expect(media!.title, equals('The Dark Knight'));

      // Toggle favorite
      await repository.setMediaFavorite(mediaId, true);
      final favMedia = await repository.getMediaById(mediaId);
      expect(favMedia!.isFavorite, isTrue);

      // Update playback progress
      await repository.updateMediaPlayback(mediaId, position: 150000, duration: 9000000);
      final playedMedia = await repository.getMediaById(mediaId);
      expect(playedMedia!.lastPosition, equals(150000));
      expect(playedMedia.playCount, equals(1));

      // Upsert File
      final fileId = await repository.upsertFile(FileRecord(
        mediaId: mediaId,
        mrl: 'D:\\Media\\TheDarkKnight.mkv',
        mtime: now.millisecondsSinceEpoch,
        size: 2048000,
      ));
      expect(fileId, greaterThan(0));

      final file = await repository.getFileByMrl('D:\\Media\\TheDarkKnight.mkv');
      expect(file, isNotNull);
      expect(file!.mediaId, equals(mediaId));
    });

    test('3. Cursor pagination and full text search', () async {
      final now = DateTime.now();
      // Seed 100 media records
      for (int i = 1; i <= 100; i++) {
        await repository.insertMedia(MediaRecord(
          type: MediaType.video,
          title: 'Movie ${i.toString().padLeft(3, '0')}',
          insertionDate: now,
        ));
      }

      final totalCount = await repository.getMediaCount();
      expect(totalCount, equals(100));

      // Fetch Page 0 (size 20)
      final page0 = await repository.getMediaPage(page: 0, pageSize: 20);
      expect(page0.length, equals(20));
      expect(page0.first.title, equals('Movie 001'));
      expect(page0.last.title, equals('Movie 020'));

      // Fetch Page 2 (size 20)
      final page2 = await repository.getMediaPage(page: 2, pageSize: 20);
      expect(page2.length, equals(20));
      expect(page2.first.title, equals('Movie 041'));

      // Search
      final searchResults = await repository.searchMedia('Movie 05');
      expect(searchResults, isNotEmpty);
      expect(searchResults.any((m) => m.title == 'Movie 050'), isTrue);
    });

    test('4. Task queue persistence, retry escalation and completion', () async {
      final now = DateTime.now();
      final mediaId = await repository.insertMedia(MediaRecord(
        type: MediaType.video,
        title: 'Task Video',
        insertionDate: now,
      ));
      final fileId = await repository.upsertFile(FileRecord(
        mediaId: mediaId,
        mrl: 'C:\\Videos\\TaskVideo.mp4',
        mtime: now.millisecondsSinceEpoch,
        size: 500000,
      ));

      final taskId = await taskQueue.enqueueTask(fileId);
      expect(taskId, greaterThan(0));

      var pendingCount = await taskQueue.getPendingCount();
      expect(pendingCount, equals(1));

      final task = await taskQueue.getNextPendingTask();
      expect(task, isNotNull);
      expect(task!.fileId, equals(fileId));
      expect(task.step, equals(TaskStep.discovered));

      // Advance step
      await taskQueue.updateTaskStep(task.idTask!, TaskStep.metadataExtraction);
      final updated = await taskQueue.getNextPendingTask();
      expect(updated!.step, equals(TaskStep.metadataExtraction));

      // Increment retries
      await taskQueue.incrementRetry(task.idTask!);
      final retried = await taskQueue.getNextPendingTask();
      expect(retried!.retryCount, equals(1));

      // Mark complete and delete
      await taskQueue.deleteTask(task.idTask!);
      pendingCount = await taskQueue.getPendingCount();
      expect(pendingCount, equals(0));
    });

    test('5. Transaction rollbacks preserve referential integrity', () async {
      final now = DateTime.now();
      try {
        await repository.transaction((txn) async {
          await txn.insert('Media', {
            'type': 1,
            'title': 'Rollback Movie',
            'duration': 100,
            'insertion_date': now.millisecondsSinceEpoch,
            'is_present': 1,
          });
          // Deliberate error to trigger rollback
          throw Exception('Simulated transaction failure');
        });
      } catch (_) {}

      final count = await repository.getMediaCount();
      expect(count, equals(0)); // Record rolled back successfully
    });
  });
}
