import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/core/db/media_library_database.dart';
import 'package:app/core/db/media_library_repository.dart';
import 'package:app/core/db/task_queue_repository.dart';
import 'package:app/features/library/domain/auto_rescan_coordinator.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  late EPlayerTestHarness harness;
  late Database db;
  late MediaLibraryRepository repository;
  late TaskQueueRepository taskQueue;
  late AutoRescanCoordinator coordinator;

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  setUp(() async {
    final tempDir = harness.createTempDirectory('rescan_coord_test_');
    final dbPath = '${tempDir.path}/coordinator.db';
    final dbHelper = MediaLibraryDatabase.withCustomPath(dbPath);
    db = await dbHelper.database;
    repository = SqliteMediaLibraryRepository(database: db);
    taskQueue = SqliteTaskQueueRepository(database: db);
    coordinator = AutoRescanCoordinator(
      repository: repository,
      taskQueue: taskQueue,
      periodicRescanInterval: Duration.zero,
    );
    await coordinator.initializeLibrary();
  });

  tearDown(() async {
    coordinator.dispose();
    if (db.isOpen) {
      await db.close();
    }
  });

  group('AutoRescanCoordinator Lifecycle & Reconciliation Tests', () {
    test('1. Registers folder and performs initial differential crawl and task processing', () async {
      final mediaDir = harness.createTempDirectory('media_folder_');
      final video1 = await harness.createMockVideoFile(mediaDir, 'avengers.mp4');
      final video2 = await harness.createMockVideoFile(mediaDir, 'batman.mkv');

      await coordinator.registerFolder(mediaDir.path);

      // Verify folder registered in SQLite
      final folder = await repository.getFolderByPath(mediaDir.path);
      expect(folder, isNotNull);
      expect(folder!.isPresent, isTrue);

      // Verify files indexed
      final file1 = await repository.getFileByMrl(video1.path);
      final file2 = await repository.getFileByMrl(video2.path);
      expect(file1, isNotNull);
      expect(file2, isNotNull);

      // Verify Media entities created
      final allMedia = await repository.getAllMedia();
      expect(allMedia.any((m) => m.title == 'avengers'), isTrue);
      expect(allMedia.any((m) => m.title == 'batman'), isTrue);

      // Verify tasks processed and cleared
      final pendingTasks = await taskQueue.getPendingCount();
      expect(pendingTasks, equals(0));
    });

    test('2. Unregistering folder marks it banned and hides presence', () async {
      final mediaDir = harness.createTempDirectory('unreg_folder_');
      await harness.createMockVideoFile(mediaDir, 'sample.mp4');

      await coordinator.registerFolder(mediaDir.path);
      var folder = await repository.getFolderByPath(mediaDir.path);
      expect(folder!.isPresent, isTrue);

      await coordinator.unregisterFolder(mediaDir.path);
      folder = await repository.getFolderByPath(mediaDir.path);
      expect(folder!.isBanned, isTrue);
      expect(folder.isPresent, isFalse);
    });

    test('3. Differential rescan detects file removals and applies soft deletion', () async {
      final mediaDir = harness.createTempDirectory('diff_remove_');
      final video = await harness.createMockVideoFile(mediaDir, 'movie_to_delete.mp4');

      await coordinator.registerFolder(mediaDir.path);
      var file = await repository.getFileByMrl(video.path);
      expect(file!.isPresent, isTrue);

      // Delete physical file from disk
      await video.delete();

      // Trigger manual rescan
      await coordinator.triggerManualRescan(specificPath: mediaDir.path);

      file = await repository.getFileByMrl(video.path);
      expect(file!.isPresent, isFalse);

      final media = await repository.getMediaById(file.mediaId);
      expect(media!.isPresent, isFalse); // Soft-deleted, metadata preserved!
    });

    test('4. Handles device dismount and remount presence toggles', () async {
      final devices = await repository.getAllDevices();
      expect(devices, isNotEmpty);
      final dev = devices.first;

      await coordinator.handleDeviceDismount(dev.uuid);
      var devAfter = await repository.getDeviceByUuid(dev.uuid);
      expect(devAfter!.isPresent, isFalse);

      await coordinator.handleDeviceRemount(dev.uuid);
      devAfter = await repository.getDeviceByUuid(dev.uuid);
      expect(devAfter!.isPresent, isTrue);
    });
  });
}
