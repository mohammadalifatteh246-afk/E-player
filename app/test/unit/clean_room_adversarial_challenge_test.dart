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
import 'package:app/features/library/domain/services/differential_reconciler.dart';
import '../helpers/eplayer_test_harness.dart';

class FakeDirectoryWatcherService implements IDirectoryWatcherService {
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
  final fileSystemService = const DefaultFileSystemService();

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  setUp(() async {
    final tempDir = harness.createTempDirectory('adv_challenge_db_');
    final dbPath = '${tempDir.path}/adv_challenge.db';
    final dbHelper = MediaLibraryDatabase.withCustomPath(dbPath);
    db = await dbHelper.database;
    repository = SqliteMediaLibraryRepository(database: db);
    taskQueue = SqliteTaskQueueRepository(database: db);
    coordinator = AutoRescanCoordinator(
      repository: repository,
      taskQueue: taskQueue,
      fileSystemService: fileSystemService,
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

  // =========================================================================
  // MISSION 1: Path Traversal & Forbidden Characters
  // =========================================================================
  group('Mission 1: Adversarial Path Traversal & Forbidden Characters', () {
    test('1.1: normalizePath collapses .. segments and preserves root boundaries', () {
      if (Platform.isWindows) {
        expect(fileSystemService.normalizePath(r'C:\Videos\..\Windows'), equals(r'C:\Windows'));
        expect(fileSystemService.normalizePath(r'C:\foo\bar\baz\..\..\qux'), equals(r'C:\foo\qux'));
        // Deep traversal above root
        expect(fileSystemService.normalizePath(r'C:\..\..\..\Windows'), equals(r'C:\Windows'));
      } else {
        expect(fileSystemService.normalizePath('/var/log/../../etc'), equals('/etc'));
        expect(fileSystemService.normalizePath('/../../../../'), equals('/'));
      }
    });

    test('1.2: parseBreadcrumbs handles traversal segments without crashing or infinite loops', () {
      final segments = fileSystemService.parseBreadcrumbs(
        Platform.isWindows ? r'C:\Movies\..\..\Secret\..\Videos' : '/home/user/../../var/log',
      );
      expect(segments, isNotEmpty);
      // Normalized path should be used in breadcrumbs
      if (Platform.isWindows) {
        expect(segments.last.path, equals(r'C:\Videos'));
      } else {
        expect(segments.last.path, equals('/var/log'));
      }
    });

    test('1.3: listDirectoryContents handles non-existent and traversal paths gracefully', () async {
      final nonExistentTraversal = Platform.isWindows ? r'C:\NonExistent_12345\..\..\Foo' : '/tmp/nonexistent/../../etc';
      final results = await fileSystemService.listDirectoryContents(nonExistentTraversal);
      expect(results, isEmpty);
    });

    test('1.4: listDirectoryContents with Windows forbidden characters safely returns empty list without crashing', () async {
      if (!Platform.isWindows) return;
      const badPath = r'C:\Test<Tag>\video.mp4';

      final results = await fileSystemService.listDirectoryContents(badPath);
      expect(results, isEmpty, reason: 'dir.exists() inside try-catch safely catches OS Error 123 and returns empty list');
    });

    test('1.5: Repository parameter binding prevents SQL injection attacks via path/MRL', () async {
      const sqlInjectionPath = "C:\\Videos'; DROP TABLE Media; --";
      const sqlInjectionTitle = "Inception' OR '1'='1";

      // Insert folder with SQL injection string in path
      final folderId = await repository.upsertFolder(FolderRecord(
        path: sqlInjectionPath,
        name: 'InjectedFolder',
        deviceId: 1,
        mtime: 1000,
      ));
      expect(folderId, greaterThan(0));

      // Query by injected path
      final retrievedFolder = await repository.getFolderByPath(sqlInjectionPath);
      expect(retrievedFolder, isNotNull);
      expect(retrievedFolder!.name, equals('InjectedFolder'));

      // Check that Media table was NOT dropped!
      final mediaCheck = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='Media';");
      expect(mediaCheck, isNotEmpty, reason: 'Media table must survive SQL injection attempts');

      // Search with SQL injection payload
      final searchResults = await repository.searchMedia(sqlInjectionTitle);
      // Should not throw SQL syntax error
      expect(searchResults, isA<List<MediaRecord>>());
    });

    test('1.6: Unicode, emoji, and non-ASCII character handling in paths and titles', () async {
      final unicodeDir = harness.createTempDirectory('unicode_test_🎬_');
      await harness.createMockVideoFile(unicodeDir, '🎥_interstellar_星际穿越_фильм.mp4');

      final entries = await fileSystemService.listDirectoryContents(unicodeDir.path);
      expect(entries, isNotEmpty);
      expect(entries.first.name, equals('🎥_interstellar_星际穿越_фильм.mp4'));

      // Index into coordinator
      await coordinator.registerFolder(unicodeDir.path);
      final media = await repository.getAllMedia();
      expect(media.any((m) => m.title.contains('星际穿越')), isTrue);
    });
  });

  // =========================================================================
  // MISSION 2: Deep Recursion and Paths Exceeding 240 Chars (\\?\)
  // =========================================================================
  group('Mission 2: Deep Directory Recursion and Paths Exceeding 240 Characters', () {
    test('2.1: normalizePath prefixes extended-length indicator \\?\\ on Windows for paths > 240 chars', () {
      if (!Platform.isWindows) return;

      final repeatedSegments = 'nested_folder_dir\\' * 20;

      // 1. Standard long drive path
      final longDrivePath = 'C:\\${repeatedSegments}test_video.mp4';
      expect(longDrivePath.length, greaterThan(240));

      final normalizedDrive = fileSystemService.normalizePath(longDrivePath);
      expect(normalizedDrive.startsWith(r'\\?\C:\'), isTrue);

      // 2. Already prefixed path should not be double-prefixed
      final alreadyPrefixed = '\\\\?\\C:\\${repeatedSegments}test_video.mp4';
      final reNormalized = fileSystemService.normalizePath(alreadyPrefixed);
      expect(reNormalized.startsWith(r'\\?\C:\'), isTrue);
      expect(reNormalized.startsWith(r'\\?\\?\'), isFalse);

      // 3. UNC network path: \\server\share -> \\?\UNC\server\share
      final repeatedSubs = 'sub_directory\\' * 20;
      final longUncPath = '\\\\nas_server\\media_share\\${repeatedSubs}movie.mkv';
      expect(longUncPath.length, greaterThan(240));

      final normalizedUnc = fileSystemService.normalizePath(longUncPath);
      expect(normalizedUnc.startsWith(r'\\?\UNC\nas_server\media_share\'), isTrue);

      // 4. Short path should NOT receive \\?\ prefix
      const shortPath = r'C:\Videos\movie.mp4';
      final normalizedShort = fileSystemService.normalizePath(shortPath);
      expect(normalizedShort, equals(shortPath));
    });

    test('2.2: Physical filesystem traversal and reconciliation at deep path boundaries (>200 chars)', () async {
      final baseDir = harness.createTempDirectory('deep_base_');
      var currentDir = baseDir;

      // Create a chain of subdirectories to push path length near OS boundaries
      final chain = ['level_alpha_first_stage', 'level_beta_second_stage', 'level_gamma_third_stage', 'level_delta_fourth_stage'];
      for (final segment in chain) {
        currentDir = Directory(p.join(currentDir.path, segment));
        await currentDir.create();
      }

      final deepVideo = await harness.createMockVideoFile(currentDir, 'deeply_nested_feature_presentation.mp4');
      expect(deepVideo.path.length, greaterThan(150));

      // Test listing contents
      final listResult = await fileSystemService.listDirectoryContents(currentDir.path);
      expect(listResult, hasLength(1));
      expect(listResult.first.name, equals('deeply_nested_feature_presentation.mp4'));

      // Test reconciliation
      final folderId = await repository.upsertFolder(FolderRecord(
        path: currentDir.path,
        name: 'level_delta_fourth_stage',
        deviceId: 1,
        mtime: 1000,
      ));

      final reconciler = DifferentialReconciler(
        repository: repository,
        fileSystemService: fileSystemService,
      );

      final diff = await reconciler.reconcileDirectory(
        directoryPath: currentDir.path,
        folderId: folderId,
      );

      expect(p.normalize(diff.addedPaths.first), equals(p.normalize(deepVideo.path)));
    });
  });

  // =========================================================================
  // MISSION 3: Dynamic .nomedia Insertion into Already Indexed Tree
  // =========================================================================
  group('Mission 3: Dynamic .nomedia Insertion & Pruning', () {
    test('3.1: DifferentialReconciler returns all active records as removed when .nomedia is inserted', () async {
      final mediaDir = harness.createTempDirectory('nomedia_recon_');
      final video1 = await harness.createMockVideoFile(mediaDir, 'movie1.mp4');
      final video2 = await harness.createMockVideoFile(mediaDir, 'movie2.mkv');

      final folderId = await repository.upsertFolder(FolderRecord(
        path: mediaDir.path,
        name: 'nomedia_recon',
        deviceId: 1,
        mtime: 1000,
      ));

      // First reconciliation without .nomedia -> 2 added
      final reconciler = DifferentialReconciler(
        repository: repository,
        fileSystemService: fileSystemService,
      );
      final diff1 = await reconciler.reconcileDirectory(directoryPath: mediaDir.path, folderId: folderId);
      expect(diff1.addedPaths, hasLength(2));
      expect(diff1.removedRecords, isEmpty);

      // Simulate ingestion
      final m1 = await repository.insertMedia(MediaRecord(type: MediaType.video, title: 'movie1', insertionDate: DateTime.now()));
      final f1 = await repository.upsertFile(FileRecord(mediaId: m1, folderId: folderId, mrl: video1.path, mtime: 1000, size: 5000));
      final m2 = await repository.insertMedia(MediaRecord(type: MediaType.video, title: 'movie2', insertionDate: DateTime.now()));
      final f2 = await repository.upsertFile(FileRecord(mediaId: m2, folderId: folderId, mrl: video2.path, mtime: 1000, size: 5000));

      // Now dynamically insert .nomedia
      final noMediaFile = File(p.join(mediaDir.path, '.nomedia'));
      await noMediaFile.writeAsString('');

      // Second reconciliation with .nomedia -> all DB files returned as removedRecords!
      final diff2 = await reconciler.reconcileDirectory(directoryPath: mediaDir.path, folderId: folderId);
      expect(diff2.addedPaths, isEmpty);
      expect(diff2.removedRecords, hasLength(2));
      expect(diff2.removedRecords.map((r) => r.idFile).toSet(), containsAll({f1, f2}));
    });

    test('3.2: Dynamic .nomedia insertion triggers immediate soft-deletion and hides media in coordinator', () async {
      final mediaDir = harness.createTempDirectory('nomedia_coord_');
      final video1 = await harness.createMockVideoFile(mediaDir, 'gladiator.mp4');
      final video2 = await harness.createMockVideoFile(mediaDir, 'matrix.mkv');

      // 1. Register folder
      await coordinator.registerFolder(mediaDir.path);

      // Verify both videos indexed and present
      var mediaList = await repository.getAllMedia(onlyPresent: true);
      expect(mediaList, hasLength(2));

      var file1 = await repository.getFileByMrl(video1.path);
      var file2 = await repository.getFileByMrl(video2.path);
      expect(file1!.isPresent, isTrue);
      expect(file2!.isPresent, isTrue);

      // 2. DYNAMICALLY INSERT .nomedia
      final noMediaFile = File(p.join(mediaDir.path, '.nomedia'));
      await noMediaFile.writeAsString('');

      // Trigger manual rescan
      await coordinator.triggerManualRescan(specificPath: mediaDir.path);

      // 3. Verify immediate soft-deletion (is_present = 0)
      file1 = await repository.getFileByMrl(video1.path);
      file2 = await repository.getFileByMrl(video2.path);
      expect(file1!.isPresent, isFalse, reason: 'File 1 must be soft-deleted after .nomedia insertion');
      expect(file2!.isPresent, isFalse, reason: 'File 2 must be soft-deleted after .nomedia insertion');

      final media1 = await repository.getMediaById(file1.mediaId);
      final media2 = await repository.getMediaById(file2.mediaId);
      expect(media1!.isPresent, isFalse, reason: 'Media 1 must be soft-deleted after .nomedia insertion');
      expect(media2!.isPresent, isFalse, reason: 'Media 2 must be soft-deleted after .nomedia insertion');

      // Verify hidden from normal queries
      mediaList = await repository.getAllMedia(onlyPresent: true);
      expect(mediaList, isEmpty, reason: 'Active media query must return 0 items when folder is masked by .nomedia');

      // CRITICAL INVARIANT: Records must NOT be hard-deleted from database
      final allMediaIncludingHidden = await repository.getAllMedia(onlyPresent: false);
      expect(allMediaIncludingHidden, hasLength(2), reason: 'Metadata must be preserved permanently in SQLite');
      expect(allMediaIncludingHidden.any((m) => m.title == 'gladiator'), isTrue);
      expect(allMediaIncludingHidden.any((m) => m.title == 'matrix'), isTrue);

      // 4. DYNAMICALLY REMOVE .nomedia AND RESCAN
      await noMediaFile.delete();
      await coordinator.triggerManualRescan(specificPath: mediaDir.path);

      // Files should re-appear upon rescan
      file1 = await repository.getFileByMrl(video1.path);
      expect(file1!.isPresent, isTrue, reason: 'File should be restored to active presence after .nomedia removal');
    });

    test('3.3: Watcher event with .nomedia path exposes gap in _handleWatcherEvent classification', () async {
      final mediaDir = harness.createTempDirectory('nomedia_watcher_');
      await harness.createMockVideoFile(mediaDir, 'movie_stream.mp4');
      await coordinator.registerFolder(mediaDir.path);

      // Verify video is indexed
      final initialMedia = await repository.getAllMedia(onlyPresent: true);
      expect(initialMedia, hasLength(1));

      // Create .nomedia on disk
      final noMediaFile = File(p.join(mediaDir.path, '.nomedia'));
      await noMediaFile.writeAsString('');

      // Check how determineNodeType classifies .nomedia
      final nodeType = fileSystemService.determineNodeType(noMediaFile.path, isDirectory: false);
      expect(nodeType, equals(FileNodeType.otherFile));

      // Note: 'otherFile'.contains('File') is TRUE, so non-media files matching 'File' substring
      // pass the filter check in _handleWatcherEvent.
      expect(nodeType.name.contains('File'), isTrue);
    });

    test('3.4: Watcher event with non-media file (.txt or .nomedia) is ignored by whitelist and NOT ingested', () async {
      final fakeWatcher = FakeDirectoryWatcherService();
      final coord = AutoRescanCoordinator(
        repository: repository,
        taskQueue: taskQueue,
        watcherService: fakeWatcher,
        fileSystemService: fileSystemService,
        periodicRescanInterval: Duration.zero,
      );
      await coord.initializeLibrary();

      final mediaDir = harness.createTempDirectory('leak_test_dir_');
      await coord.registerFolder(mediaDir.path);

      final dummyTextFile = File(p.join(mediaDir.path, 'notes.txt'));
      await dummyTextFile.writeAsString('Not a media file');

      // Emit watcher event for notes.txt
      fakeWatcher.emit(WatcherEvent(
        path: dummyTextFile.path,
        type: WatcherChangeType.created,
        timestamp: DateTime.now(),
      ));

      // Wait for stability probe and DB transaction
      await Future.delayed(const Duration(milliseconds: 600));

      final allMedia = await repository.getAllMedia();
      final textMedia = allMedia.where((m) => m.title == 'notes').toList();
      expect(textMedia, isEmpty, reason: "Remediation verified: _handleWatcherEvent filters out non-media files via media node type whitelist");

      coord.dispose();
    });

    test('3.5: Dynamic .nomedia watcher event triggers folder reconciliation and soft-deletes media', () async {
      final fakeWatcher = FakeDirectoryWatcherService();
      final coord = AutoRescanCoordinator(
        repository: repository,
        taskQueue: taskQueue,
        watcherService: fakeWatcher,
        fileSystemService: fileSystemService,
        periodicRescanInterval: Duration.zero,
      );
      await coord.initializeLibrary();

      final mediaDir = harness.createTempDirectory('watcher_nomedia_');
      final video = await harness.createMockVideoFile(mediaDir, 'stream_movie.mp4');
      await coord.registerFolder(mediaDir.path);

      // Verify initially present
      var mediaList = await repository.getAllMedia(onlyPresent: true);
      expect(mediaList, hasLength(1));

      // Create .nomedia on disk and emit watcher event
      final noMediaFile = File(p.join(mediaDir.path, '.nomedia'));
      await noMediaFile.writeAsString('');

      fakeWatcher.emit(WatcherEvent(
        path: noMediaFile.path,
        type: WatcherChangeType.created,
        timestamp: DateTime.now(),
      ));

      // Wait for folder reconciliation to execute
      await Future.delayed(const Duration(milliseconds: 300));

      // Verify soft-deleted
      mediaList = await repository.getAllMedia(onlyPresent: true);
      expect(mediaList, isEmpty, reason: 'Dynamic .nomedia watcher event must soft-delete media in folder');

      final fileRecord = await repository.getFileByMrl(video.path);
      expect(fileRecord!.isPresent, isFalse);

      coord.dispose();
    });
  });

  // =========================================================================
  // MISSION 4: Device Disconnection Simulation (Device.is_present = 0)
  // =========================================================================
  group('Mission 4: Device Disconnection Simulation & Isolation', () {
    test('4.1: Device.is_present = 0 trigger cascades across all descendant folders, files, and media', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Device A (Removable USB drive)
      final devAId = await db.insert('Device', {
        'uuid': 'usb_sandisk_001',
        'scheme': 'file://',
        'is_removable': 1,
        'is_present': 1,
        'last_seen': now,
      });

      // 2 Folders on Device A
      final folderA1 = await db.insert('Folder', {
        'path': r'E:\Action',
        'name': 'Action',
        'device_id': devAId,
        'mtime': now,
        'is_present': 1,
      });
      final folderA2 = await db.insert('Folder', {
        'path': r'E:\Drama',
        'name': 'Drama',
        'device_id': devAId,
        'mtime': now,
        'is_present': 1,
      });

      // Media & Files on Folder A1
      final mediaA1 = await db.insert('Media', {'type': 1, 'title': 'Die Hard', 'duration': 7800000, 'insertion_date': now, 'is_present': 1, 'play_count': 5, 'is_favorite': 1});
      final fileA1 = await db.insert('File', {'media_id': mediaA1, 'folder_id': folderA1, 'mrl': r'E:\Action\die_hard.mp4', 'type': 1, 'mtime': now, 'size': 120000, 'is_present': 1});

      // Media & Files on Folder A2
      final mediaA2 = await db.insert('Media', {'type': 1, 'title': 'Casablanca', 'duration': 6000000, 'insertion_date': now, 'is_present': 1, 'play_count': 2, 'last_position': 3000});
      final fileA2 = await db.insert('File', {'media_id': mediaA2, 'folder_id': folderA2, 'mrl': r'E:\Drama\casablanca.mkv', 'type': 1, 'mtime': now, 'size': 150000, 'is_present': 1});

      // 2. Device B (Local Fixed Disk - CONTROL DEVICE)
      final devBId = await db.insert('Device', {
        'uuid': 'fixed_nvme_c',
        'scheme': 'file://',
        'is_removable': 0,
        'is_present': 1,
        'last_seen': now,
      });
      final folderB = await db.insert('Folder', {
        'path': r'C:\Users\Videos',
        'name': 'Videos',
        'device_id': devBId,
        'mtime': now,
        'is_present': 1,
      });
      final mediaB = await db.insert('Media', {'type': 1, 'title': 'Home Video', 'duration': 120000, 'insertion_date': now, 'is_present': 1});
      final fileB = await db.insert('File', {'media_id': mediaB, 'folder_id': folderB, 'mrl': r'C:\Users\Videos\home.mp4', 'type': 1, 'mtime': now, 'size': 50000, 'is_present': 1});

      // Pre-condition: All 3 media items present
      expect(await repository.getMediaCount(onlyPresent: true), equals(3));

      // --- SIMULATE DISCONNECT OF DEVICE A ---
      await repository.setDevicePresence(devAId, false);

      // Verify Device A is_present = 0
      final devARecord = await repository.getDeviceById(devAId);
      expect(devARecord!.isPresent, isFalse);

      // Verify Folder A1 & A2 presence cascaded to 0
      final folderA1Rec = await repository.getFolderById(folderA1);
      final folderA2Rec = await repository.getFolderById(folderA2);
      expect(folderA1Rec!.isPresent, isFalse);
      expect(folderA2Rec!.isPresent, isFalse);

      // Verify File A1 & A2 presence cascaded to 0
      final fileA1Rec = await repository.getFileById(fileA1);
      final fileA2Rec = await repository.getFileById(fileA2);
      expect(fileA1Rec!.isPresent, isFalse);
      expect(fileA2Rec!.isPresent, isFalse);

      // Verify Media A1 & A2 presence cascaded to 0
      final mediaA1Rec = await repository.getMediaById(mediaA1);
      final mediaA2Rec = await repository.getMediaById(mediaA2);
      expect(mediaA1Rec!.isPresent, isFalse);
      expect(mediaA2Rec!.isPresent, isFalse);

      // CRITICAL CROSS-DEVICE ISOLATION INVARIANT:
      // Device B records MUST REMAIN is_present = 1!
      final devBRecord = await repository.getDeviceById(devBId);
      final folderBRec = await repository.getFolderById(folderB);
      final fileBRec = await repository.getFileById(fileB);
      final mediaBRec = await repository.getMediaById(mediaB);
      expect(devBRecord!.isPresent, isTrue, reason: 'Device B must not be affected by Device A disconnect');
      expect(folderBRec!.isPresent, isTrue);
      expect(fileBRec!.isPresent, isTrue);
      expect(mediaBRec!.isPresent, isTrue);

      // Only Media B is visible in public queries
      final activeMedia = await repository.getAllMedia(onlyPresent: true);
      expect(activeMedia, hasLength(1));
      expect(activeMedia.first.title, equals('Home Video'));

      // Metadata preservation check on disconnected items:
      expect(mediaA1Rec.playCount, equals(5));
      expect(mediaA1Rec.isFavorite, isTrue);
      expect(mediaA2Rec.lastPosition, equals(3000));

      // --- SIMULATE RECONNECT OF DEVICE A ---
      await repository.setDevicePresence(devAId, true);

      // Verify all Device A items restored
      final mediaA1Restored = await repository.getMediaById(mediaA1);
      final mediaA2Restored = await repository.getMediaById(mediaA2);
      expect(mediaA1Restored!.isPresent, isTrue);
      expect(mediaA2Restored!.isPresent, isTrue);
      expect(mediaA1Restored.playCount, equals(5), reason: 'Play count must survive disconnect/reconnect cycle');
      expect(mediaA1Restored.isFavorite, isTrue, reason: 'Favorite status must survive disconnect/reconnect cycle');

      // All 3 items visible again
      expect(await repository.getMediaCount(onlyPresent: true), equals(3));
    });

    test('4.2: Coordinator handleDeviceDismount and handleDeviceRemount by UUID', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final devId = await repository.upsertDevice(DeviceRecord(
        uuid: 'external_usb_beta',
        scheme: 'file://',
        isRemovable: true,
        isPresent: true,
        lastSeen: DateTime.now(),
      ));

      final folderId = await repository.upsertFolder(FolderRecord(
        path: r'F:\Audio',
        name: 'Audio',
        deviceId: devId,
        mtime: now,
      ));

      final mId = await repository.insertMedia(MediaRecord(type: MediaType.audio, title: 'Podcast Episode 1', insertionDate: DateTime.now()));
      await repository.upsertFile(FileRecord(mediaId: mId, folderId: folderId, mrl: r'F:\Audio\ep1.mp3', mtime: now, size: 4000));

      // Dismount via coordinator
      await coordinator.handleDeviceDismount('external_usb_beta');
      var media = await repository.getMediaById(mId);
      expect(media!.isPresent, isFalse);

      // Remount via coordinator
      await coordinator.handleDeviceRemount('external_usb_beta');
      media = await repository.getMediaById(mId);
      expect(media!.isPresent, isTrue);
    });
  });

  // =========================================================================
  // MISSION 5: Invariant Verification & Zero Temporary Artifacts
  // =========================================================================
  group('Mission 5: Test Data Lifecycle & Invariant Verification', () {
    test('5.1: Ephemeral test fixtures are purged completely on teardown', () async {
      final dir = harness.createTempDirectory('ephemeral_probe_');
      final testFile = await harness.createMockVideoFile(dir, 'temp_test.mp4');
      expect(await testFile.exists(), isTrue);

      // Test tearDown deletes it
      await harness.tearDown();
      expect(dir.existsSync(), isFalse, reason: 'Temporary directories must be deleted by test harness');
    });
  });
}
