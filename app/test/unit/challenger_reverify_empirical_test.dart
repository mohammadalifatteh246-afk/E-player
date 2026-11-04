import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/core/models/media_library_models.dart';
import 'package:app/core/db/media_library_database.dart';
import 'package:app/core/db/media_library_repository.dart';
import 'package:app/core/db/task_queue_repository.dart';
import 'package:app/features/browser/domain/directory_watcher_service.dart';
import 'package:app/features/browser/domain/file_system_service.dart';
import 'package:app/features/library/domain/auto_rescan_coordinator.dart';
import '../helpers/eplayer_test_harness.dart';

class EmpiricalMockWatcherService implements IDirectoryWatcherService {
  final _controller = StreamController<WatcherEvent>.broadcast();
  @override
  Stream<WatcherEvent> get events => _controller.stream;
  @override
  Set<String> get watchedPaths => {};
  @override
  Future<void> startWatching(List<String> paths) async {}
  @override
  Future<void> stopWatching(String path) async {}
  @override
  Future<void> stopAll() async {}
  @override
  void dispose() => _controller.close();
  void emit(WatcherEvent event) => _controller.add(event);
}

void main() {
  late EPlayerTestHarness harness;
  late Database db;
  late MediaLibraryRepository repository;
  late TaskQueueRepository taskQueue;
  late AutoRescanCoordinator coordinator;
  late EmpiricalMockWatcherService watcherService;
  final fileSystemService = const DefaultFileSystemService();

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  setUp(() async {
    final tempDir = harness.createTempDirectory('reverify_db_');
    final dbPath = p.join(tempDir.path, 'reverify.db');
    final dbHelper = MediaLibraryDatabase.withCustomPath(dbPath);
    db = await dbHelper.database;
    repository = SqliteMediaLibraryRepository(database: db);
    taskQueue = SqliteTaskQueueRepository(database: db);
    watcherService = EmpiricalMockWatcherService();
    coordinator = AutoRescanCoordinator(
      repository: repository,
      taskQueue: taskQueue,
      watcherService: watcherService,
      fileSystemService: fileSystemService,
      periodicRescanInterval: Duration.zero,
    );
    await coordinator.initializeLibrary();
  });

  tearDown(() async {
    coordinator.dispose();
    watcherService.dispose();
    if (db.isOpen) {
      await db.close();
    }
  });

  Future<File> createMockAudioFile(Directory dir, String filename) async {
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], flush: true);
    return file;
  }

  // =========================================================================
  // FIX 1: Windows Forbidden Characters & Inaccessible Paths in listDirectoryContents
  // =========================================================================
  group('Fix 1 Verification: Windows Forbidden Characters & Inaccessible Paths', () {
    test('1.1: listDirectoryContents handles all forbidden Win32 characters (<>:"|?*) safely', () async {
      final forbiddenPaths = [
        r'C:\Test<Tag>\video.mp4',
        r'C:\Videos>Test\file.mkv',
        r'C:\Folder:Colon\file.mp4',
        r'C:\Folder"Quote\file.mp4',
        r'C:\Folder|Pipe\file.mp4',
        r'C:\Folder?Question\file.mp4',
        r'C:\Folder*Asterisk\file.mp4',
        r'C:\Folder<>:"|?*\deep\bad.mp4',
        r'C:\CON\video.mp4',
        r'C:\PRN\test.mkv',
        r'C:\AUX\media.avi',
        r'C:\NUL\stream.mp4',
        r'C:\COM1\track.mp3',
        r'C:\LPT1\audio.flac',
        r'::\invalid_drive_syntax',
        r'   ',
        '',
      ];

      for (final badPath in forbiddenPaths) {
        final result = await fileSystemService.listDirectoryContents(badPath);
        expect(result, isEmpty, reason: 'Failed for bad path: "$badPath"');
      }
    });

    test('1.2: listDirectoryContents handles deeply nested non-existent directory without exception', () async {
      const nonExistent = r'C:\NonExistentDrive_Z_12345\deep\nested\folder\path';
      final result = await fileSystemService.listDirectoryContents(nonExistent);
      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // FIX 2: Strict Media Whitelisting & Dynamic .nomedia Lifecycle
  // =========================================================================
  group('Fix 2 Verification: Strict Media Whitelisting & Dynamic .nomedia Handling', () {
    test('2.1: Watcher events for arbitrary non-media files are ignored and NOT ingested into SQLite', () async {
      final testDir = harness.createTempDirectory('reverify_whitelist_');
      await coordinator.registerFolder(testDir.path);

      // Verify directory registered in DB
      final folder = await repository.getFolderByPath(testDir.path);
      expect(folder, isNotNull);

      final nonMediaExtensions = ['.txt', '.pdf', '.log', '.exe', '.json', '.zip', '.xml', '.docx', '.bin'];
      for (final ext in nonMediaExtensions) {
        final dummyFile = File(p.join(testDir.path, 'document$ext'));
        await dummyFile.writeAsString('sample non-media content');

        watcherService.emit(WatcherEvent(
          path: dummyFile.path,
          type: WatcherChangeType.created,
          timestamp: DateTime.now(),
        ));
      }

      // Allow stability probe window to process
      await Future.delayed(const Duration(milliseconds: 600));

      final allMedia = await repository.getAllMedia(onlyPresent: false);
      expect(allMedia, isEmpty, reason: 'Non-media files must be strictly rejected by media type whitelist');
    });

    test('2.2: Legitimate media files are successfully ingested via watcher', () async {
      final testDir = harness.createTempDirectory('reverify_media_');
      await coordinator.registerFolder(testDir.path);

      final videoFile = await harness.createMockVideoFile(testDir, 'feature_film.mp4');
      final audioFile = await createMockAudioFile(testDir, 'soundtrack.mp3');

      watcherService.emit(WatcherEvent(
        path: videoFile.path,
        type: WatcherChangeType.created,
        timestamp: DateTime.now(),
      ));
      watcherService.emit(WatcherEvent(
        path: audioFile.path,
        type: WatcherChangeType.created,
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 600));

      final media = await repository.getAllMedia(onlyPresent: true);
      expect(media, hasLength(2));
      expect(media.any((m) => m.title == 'feature_film' && m.type == MediaType.video), isTrue);
      expect(media.any((m) => m.title == 'soundtrack' && m.type == MediaType.audio), isTrue);
    });

    test('2.3: Dynamic .nomedia creation soft-deletes files while preserving user metadata, and deletion restores without duplicates', () async {
      final testDir = harness.createTempDirectory('reverify_nomedia_lifecycle_');
      final v1 = await harness.createMockVideoFile(testDir, 'alpha.mp4');
      await createMockAudioFile(testDir, 'beta.mp3');
      await harness.createMockVideoFile(testDir, 'gamma.mkv');

      await coordinator.registerFolder(testDir.path);

      // Precondition: 3 media items present
      var activeMedia = await repository.getAllMedia(onlyPresent: true);
      expect(activeMedia, hasLength(3));

      // Simulate user engagement: add play count, favorite, and last position to alpha.mp4
      final fileAlpha = await repository.getFileByMrl(v1.path);
      expect(fileAlpha, isNotNull);
      final mediaAlpha = await repository.getMediaById(fileAlpha!.mediaId);
      expect(mediaAlpha, isNotNull);

      await repository.updateMedia(mediaAlpha!.copyWith(
        playCount: 42,
        isFavorite: true,
        lastPosition: 12345,
      ));

      // Check folder media count is 3
      final folder = await repository.getFolderByPath(testDir.path);
      expect(folder, isNotNull);
      var folderFiles = await repository.getFilesByFolder(folder!.idFolder!, onlyPresent: true);
      expect(folderFiles, hasLength(3));

      // --- PHASE 1: DYNAMIC .nomedia CREATION VIA WATCHER ---
      final noMediaFile = File(p.join(testDir.path, '.nomedia'));
      await noMediaFile.writeAsString('');

      watcherService.emit(WatcherEvent(
        path: noMediaFile.path,
        type: WatcherChangeType.created,
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 300));

      // Assert: Soft-deleted
      activeMedia = await repository.getAllMedia(onlyPresent: true);
      expect(activeMedia, isEmpty, reason: 'Active media query must return 0 items when masked by .nomedia');

      folderFiles = await repository.getFilesByFolder(folder.idFolder!, onlyPresent: true);
      expect(folderFiles, isEmpty, reason: 'Active folder files query must return 0 items');

      // Assert: Metadata preserved in database
      final allMediaIncludingHidden = await repository.getAllMedia(onlyPresent: false);
      expect(allMediaIncludingHidden, hasLength(3), reason: 'Metadata must remain stored in database');

      final preservedAlpha = await repository.getMediaById(mediaAlpha.idMedia!);
      expect(preservedAlpha!.isPresent, isFalse);
      expect(preservedAlpha.playCount, equals(42), reason: 'Play count must be preserved across soft-deletion');
      expect(preservedAlpha.isFavorite, isTrue, reason: 'Favorite status must be preserved');
      expect(preservedAlpha.lastPosition, equals(12345), reason: 'Last playback position must be preserved');

      // --- PHASE 2: DYNAMIC .nomedia DELETION VIA WATCHER ---
      await noMediaFile.delete();

      watcherService.emit(WatcherEvent(
        path: noMediaFile.path,
        type: WatcherChangeType.deleted,
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 300));

      // Assert: Restored
      activeMedia = await repository.getAllMedia(onlyPresent: true);
      expect(activeMedia, hasLength(3), reason: 'Deleting .nomedia must un-soft-delete media');

      folderFiles = await repository.getFilesByFolder(folder.idFolder!, onlyPresent: true);
      expect(folderFiles, hasLength(3));

      // Assert: No duplicate records created
      final allMediaAfterRestore = await repository.getAllMedia(onlyPresent: false);
      expect(allMediaAfterRestore, hasLength(3), reason: 'Zero duplicate rows must be created on restore');

      final restoredAlpha = await repository.getMediaById(mediaAlpha.idMedia!);
      expect(restoredAlpha!.isPresent, isTrue);
      expect(restoredAlpha.playCount, equals(42), reason: 'Play count must remain intact after restoration');
      expect(restoredAlpha.isFavorite, isTrue);
      expect(restoredAlpha.lastPosition, equals(12345));
    });

    test('2.4: Dynamic .nomedia modification via watcher also reconciles safely', () async {
      final testDir = harness.createTempDirectory('reverify_nomedia_mod_');
      await harness.createMockVideoFile(testDir, 'clip.mp4');
      await coordinator.registerFolder(testDir.path);

      expect(await repository.getAllMedia(onlyPresent: true), hasLength(1));

      // Create .nomedia and emit modified event
      final noMediaFile = File(p.join(testDir.path, '.nomedia'));
      await noMediaFile.writeAsString('mod');

      watcherService.emit(WatcherEvent(
        path: noMediaFile.path,
        type: WatcherChangeType.modified,
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(await repository.getAllMedia(onlyPresent: true), isEmpty);
    });
  });
}
