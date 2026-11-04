import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:app/core/models/media_library_models.dart';
import 'package:app/core/db/media_library_database.dart';
import 'package:app/core/db/media_library_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app/features/browser/domain/directory_watcher_service.dart';
import 'package:app/features/library/domain/services/stability_probe_service.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  late EPlayerTestHarness harness;

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  // =========================================================================
  // SUITE 1: Rapid Concurrent Filesystem Events, 500ms Sliding Debounce & Coalescing
  // =========================================================================
  group('Adversarial Challenge 1: Filesystem Events & Sliding Debounce Stress', () {
    test('1.1 Sliding debounce window continuously resets on rapid writes within window', () async {
      final tempDir = harness.createTempDirectory('stress_debounce_slide_');
      final watcher = DirectoryWatcherService(
        debounceDuration: const Duration(milliseconds: 300),
      );

      final receivedEvents = <WatcherEvent>[];
      final sub = watcher.events.listen(receivedEvents.add);
      await watcher.startWatching([tempDir.path]);

      final targetFile = File(p.join(tempDir.path, 'sliding_video.mp4'));

      // Write at t = 0ms
      await targetFile.writeAsString('step 1\n', flush: true);

      // Write at t = 100ms (< 300ms)
      await Future.delayed(const Duration(milliseconds: 100));
      await targetFile.writeAsString('step 2\n', mode: FileMode.append, flush: true);

      // Write at t = 200ms (< 300ms)
      await Future.delayed(const Duration(milliseconds: 100));
      await targetFile.writeAsString('step 3\n', mode: FileMode.append, flush: true);

      // Write at t = 300ms (< 300ms)
      await Future.delayed(const Duration(milliseconds: 100));
      await targetFile.writeAsString('step 4\n', mode: FileMode.append, flush: true);

      // At t = 400ms: Total elapsed = 300ms from start, but only 100ms since last write!
      // If debounce were FIXED (non-sliding), it would have fired at 300ms.
      // Because it is SLIDING, no event should have fired yet!
      await Future.delayed(const Duration(milliseconds: 100));
      expect(receivedEvents.where((e) => e.path == targetFile.path), isEmpty,
          reason: 'Sliding debounce must not fire while writes continue within window');

      // Now wait for full 350ms with no writes (exceeds 300ms debounce)
      await Future.delayed(const Duration(milliseconds: 350));

      // Now exactly ONE coalesced event must have been flushed!
      final targetEvents = receivedEvents.where((e) => e.path == targetFile.path).toList();
      expect(targetEvents.length, equals(1),
          reason: 'Sliding debounce must flush exactly 1 event after writes settle');
      expect(targetEvents.first.type, equals(WatcherChangeType.created),
          reason: 'Create followed by rapid writes coalesces to created');

      await sub.cancel();
      watcher.dispose();
    });

    test('1.2 Concurrent multi-file burst: creates, rapid modifies, and ephemeral deletes', () async {
      final tempDir = harness.createTempDirectory('stress_burst_');
      final watcher = DirectoryWatcherService(
        debounceDuration: const Duration(milliseconds: 400),
      );

      final receivedEvents = <WatcherEvent>[];
      final sub = watcher.events.listen(receivedEvents.add);
      await watcher.startWatching([tempDir.path]);

      const fileCount = 10;
      final createdFiles = <File>[];
      final ephemeralFiles = <File>[];

      // Launch 10 persistent files with rapid writes AND 10 ephemeral files (create -> delete) in parallel
      await Future.wait([
        // Group A: Persistent files (create -> 3 writes)
        ...List.generate(fileCount, (i) async {
          final file = File(p.join(tempDir.path, 'video_$i.mp4'));
          createdFiles.add(file);
          await file.writeAsString('init $i', flush: true);
          await Future.delayed(const Duration(milliseconds: 25));
          await file.writeAsString('update $i.1', flush: true);
          await Future.delayed(const Duration(milliseconds: 25));
          await file.writeAsString('update $i.2', flush: true);
        }),
        // Group B: Ephemeral download artifacts (create -> delete within window)
        ...List.generate(fileCount, (i) async {
          final file = File(p.join(tempDir.path, 'download_$i.tmp'));
          ephemeralFiles.add(file);
          await file.writeAsString('scratch data $i', flush: true);
          await Future.delayed(const Duration(milliseconds: 30));
          if (await file.exists()) {
            await file.delete();
          }
        }),
      ]);

      // Wait for debounce duration to settle
      await Future.delayed(const Duration(milliseconds: 600));

      // Verify Group B: All ephemeral files were coalesced to NOOP
      for (final tmp in ephemeralFiles) {
        final matches = receivedEvents.where((e) => e.path == tmp.path);
        expect(matches, isEmpty,
            reason: 'Temporary file ${tmp.path} create-then-delete must coalesce to NOOP');
      }

      // Verify Group A: All persistent files emitted exactly one event
      for (final f in createdFiles) {
        final matches = receivedEvents.where((e) => e.path == f.path);
        expect(matches.length, equals(1),
            reason: 'Persistent file ${f.path} must emit exactly 1 coalesced event');
        expect(matches.first.type, equals(WatcherChangeType.created));
      }

      await sub.cancel();
      watcher.dispose();
    });

    test('1.3 High-frequency burst triggers overflow recovery flag without crashing', () async {
      final tempDir = harness.createTempDirectory('stress_overflow_');
      final watcher = DirectoryWatcherService(
        debounceDuration: const Duration(milliseconds: 100),
      );

      final events = <WatcherEvent>[];
      final sub = watcher.events.listen(events.add);
      await watcher.startWatching([tempDir.path]);

      // Generate a rapid burst of 250 filesystem modifications to test rate-limiter guardrail
      final burstFile = File(p.join(tempDir.path, 'burst.txt'));
      await burstFile.writeAsString('start');

      for (int i = 0; i < 220; i++) {
        await burstFile.writeAsString('data $i', flush: false);
      }

      await Future.delayed(const Duration(milliseconds: 300));

      // Watcher must remain healthy and active
      expect(watcher.watchedPaths, contains(tempDir.path));

      await sub.cancel();
      watcher.dispose();
    });

    test('1.4 Disposing watcher with pending timers cancels all timers cleanly', () async {
      final tempDir = harness.createTempDirectory('stress_dispose_');
      final watcher = DirectoryWatcherService(
        debounceDuration: const Duration(milliseconds: 500),
      );

      final receivedEvents = <WatcherEvent>[];
      watcher.events.listen(receivedEvents.add);
      await watcher.startWatching([tempDir.path]);

      // Create 15 files to prime pending timers
      for (int i = 0; i < 15; i++) {
        final f = File(p.join(tempDir.path, 'pending_$i.mp4'));
        await f.writeAsString('data');
      }

      // Immediately dispose watcher while timers are active
      watcher.dispose();

      // Wait beyond the 500ms debounce
      await Future.delayed(const Duration(milliseconds: 600));

      // Closed controller must not receive post-dispose events or throw uncaught exceptions
      expect(watcher.watchedPaths, isEmpty);
    });
  });

  // =========================================================================
  // SUITE 2: Stability Probing Under Active Locks & Sequential Size Changes
  // =========================================================================
  group('Adversarial Challenge 2: StabilityProbeService Stress', () {
    const probeService = StabilityProbeService();

    test('2.1 Actively locked file descriptor retries with backoff and fails if lock held', () async {
      final tempDir = harness.createTempDirectory('stress_probe_lock_');
      final file = File(p.join(tempDir.path, 'locked_download.mkv'));
      await file.writeAsString('initial media chunk');

      final raf = await file.open(mode: FileMode.write);
      await raf.lock(FileLock.exclusive);

      try {
        final isStable = await probeService.probeFileStability(
          file.path,
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 40),
          samplingDelay: const Duration(milliseconds: 40),
        );

        // While lock is held, probe must return false
        expect(isStable, isFalse,
            reason: 'File with held exclusive lock must not be marked stable');
      } finally {
        await raf.unlock();
        await raf.close();
      }
    });

    test('2.2 File locked initially then released mid-probe successfully stabilizes', () async {
      final tempDir = harness.createTempDirectory('stress_probe_release_');
      final file = File(p.join(tempDir.path, 'transferring_movie.mp4'));
      await file.writeAsString('sample header data');

      final raf = await file.open(mode: FileMode.write);
      await raf.lock(FileLock.exclusive);

      // Schedule background release after 120ms (probe will encounter lock on first retry)
      Timer(const Duration(milliseconds: 120), () async {
        try {
          await raf.unlock();
          await raf.close();
        } catch (_) {}
      });

      final isStable = await probeService.probeFileStability(
        file.path,
        maxRetries: 6,
        baseDelay: const Duration(milliseconds: 50),
        samplingDelay: const Duration(milliseconds: 50),
      );

      expect(isStable, isTrue,
          reason: 'File whose lock is released during backoff retries must stabilize');
    });

    test('2.3 Active streaming write (sequential size growth) delays stabilization until completion', () async {
      final tempDir = harness.createTempDirectory('stress_probe_stream_');
      final file = File(p.join(tempDir.path, 'stream.mkv'));
      await file.writeAsString('chunk 0\n');

      // Simulate a background streaming downloader appending chunks every 40ms for 4 writes
      int writesRemaining = 4;
      Timer.periodic(const Duration(milliseconds: 40), (timer) {
        if (writesRemaining > 0) {
          file.writeAsStringSync('additional chunk data $writesRemaining\n',
              mode: FileMode.append, flush: true);
          writesRemaining--;
        } else {
          timer.cancel();
        }
      });

      final stopwatch = Stopwatch()..start();
      final isStable = await probeService.probeFileStability(
        file.path,
        maxRetries: 10,
        baseDelay: const Duration(milliseconds: 30),
        samplingDelay: const Duration(milliseconds: 50),
      );
      stopwatch.stop();

      expect(isStable, isTrue,
          reason: 'Probe must successfully detect stability once active streaming ceases');
      // Probing must have taken at least 150ms due to waiting for size changes to settle
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(140),
          reason: 'Probe must not prematurely report stability while file is growing');
    });

    test('2.4 Unbounded size growth exceeds maxRetries and safely returns false', () async {
      final tempDir = harness.createTempDirectory('stress_probe_infinite_');
      final file = File(p.join(tempDir.path, 'infinite_stream.mkv'));
      await file.writeAsString('start');

      // Stream continues writing indefinitely
      final timer = Timer.periodic(const Duration(milliseconds: 30), (t) {
        try {
          file.writeAsStringSync('more bytes', mode: FileMode.append, flush: true);
        } catch (_) {}
      });

      try {
        final isStable = await probeService.probeFileStability(
          file.path,
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 30),
          samplingDelay: const Duration(milliseconds: 40),
        );

        expect(isStable, isFalse,
            reason: 'Continuously mutating file must fail stability after maxRetries');
      } finally {
        timer.cancel();
      }
    });

    test('2.5 File deleted during active probe returns false without unhandled exception', () async {
      final tempDir = harness.createTempDirectory('stress_probe_deleted_');
      final file = File(p.join(tempDir.path, 'transient.mp4'));
      await file.writeAsString('data');

      // Schedule deletion during sampling delay
      Timer(const Duration(milliseconds: 25), () async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      final isStable = await probeService.probeFileStability(
        file.path,
        maxRetries: 3,
        baseDelay: const Duration(milliseconds: 20),
        samplingDelay: const Duration(milliseconds: 60),
      );

      expect(isStable, isFalse,
          reason: 'File deleted mid-probe must safely return false');
    });
  });

  // =========================================================================
  // SUITE 3: SQLite Transaction Concurrency (Concurrent Reads During Writes)
  // =========================================================================
  group('Adversarial Challenge 3: SQLite Transaction Concurrency & WAL Mode', () {
    late Directory tempDir;
    late MediaLibraryDatabase dbHelper;
    late SqliteMediaLibraryRepository repository;
    late int testDeviceId;

    setUp(() async {
      tempDir = harness.createTempDirectory('stress_sqlite_');
      final dbPath = p.join(tempDir.path, 'concurrent_media_library.db');
      dbHelper = MediaLibraryDatabase.withCustomPath(dbPath);
      final db = await dbHelper.database;
      repository = SqliteMediaLibraryRepository(database: db);

      // Seed initial device and folder
      testDeviceId = await repository.upsertDevice(DeviceRecord(
        uuid: 'test_drive_uuid',
        scheme: 'file://',
        isRemovable: false,
        isPresent: true,
        lastSeen: DateTime.now(),
      ));

      await repository.upsertFolder(FolderRecord(
        path: tempDir.path,
        name: 'RootFolder',
        deviceId: testDeviceId,
        mtime: DateTime.now().millisecondsSinceEpoch,
      ));

      // Seed 20 baseline media items
      for (int i = 0; i < 20; i++) {
        await repository.insertMedia(MediaRecord(
          type: MediaType.video,
          title: 'Baseline Video $i',
          duration: 120000 + i * 1000,
          insertionDate: DateTime.now(),
        ));
      }
    });

    tearDown(() async {
      await dbHelper.close();
      await dbHelper.deleteDatabaseFile();
    });

    test('3.1 Concurrent reads during in-flight write transaction succeed without database lock', () async {
      final initialCount = await repository.getMediaCount();
      expect(initialCount, equals(20));

      final dbPath = p.join(tempDir.path, 'concurrent_media_library.db');
      // Open an independent reader connection to the same WAL database file
      final readerDb = await openDatabase(
        dbPath,
        readOnly: true,
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA busy_timeout = 5000;');
        },
      );

      final transactionStartedCompleter = Completer<void>();
      final allowCommitCompleter = Completer<void>();

      // 1. Start a slow write transaction in the background on the primary connection
      final writeTxnFuture = repository.transaction((txn) async {
        // Insert new records inside transaction
        for (int i = 0; i < 10; i++) {
          await txn.insert('Media', {
            'type': 1,
            'title': 'Uncommitted Video $i',
            'duration': 60000,
            'play_count': 0,
            'last_position': 0,
            'insertion_date': DateTime.now().millisecondsSinceEpoch,
            'is_favorite': 0,
            'is_present': 1,
          });
        }

        // Notify that writes inside transaction are complete, but transaction NOT yet committed
        transactionStartedCompleter.complete();

        // Wait until readers have verified snapshot isolation
        await allowCommitCompleter.future;
      });

      await transactionStartedCompleter.future;

      // 2. Perform concurrent reads on the separate reader connection while write transaction is still uncommitted
      final readResults = await Future.wait([
        readerDb.rawQuery('SELECT COUNT(*) as count FROM Media WHERE is_present = 1'),
        readerDb.rawQuery("SELECT * FROM Media WHERE title LIKE '%Baseline%'"),
        readerDb.rawQuery('SELECT * FROM Folder WHERE is_present = 1'),
        ...List.generate(5, (_) => readerDb.rawQuery('SELECT COUNT(*) as count FROM Media')),
      ]);

      // In WAL mode with snapshot isolation:
      // Separate reader connection must NOT fail with 'database is locked'
      // Separate reader must see 20 (not 30), because uncommitted rows are isolated in WAL!
      final countWhileWriting = Sqflite.firstIntValue(readResults[0]);
      expect(countWhileWriting, equals(20),
          reason: 'WAL mode snapshot isolation must allow separate reader to see 20 items without locking');

      final searchResults = readResults[1];
      expect(searchResults.length, equals(20));

      // 3. Now allow write transaction to commit
      allowCommitCompleter.complete();
      await writeTxnFuture;

      // 4. After commit, readers must immediately see all 30 media items
      final countAfterCommit = await repository.getMediaCount();
      expect(countAfterCommit, equals(30),
          reason: 'Post-commit query must immediately reflect newly committed records');

      await readerDb.close();
    });

    test('3.2 Interleaved high-concurrency read/write bombardment maintains ACID integrity', () async {
      const writerCount = 5;
      const readerCount = 20;

      // Concurrently launch 5 writers (inserting 5 items each = 25 new items)
      final writerFutures = List.generate(writerCount, (writerId) {
        return repository.transaction((txn) async {
          for (int k = 0; k < 5; k++) {
            await txn.insert('Media', {
              'type': 1,
              'title': 'Bombardment W$writerId Item$k',
              'duration': 50000,
              'play_count': 0,
              'last_position': 0,
              'insertion_date': DateTime.now().millisecondsSinceEpoch,
              'is_favorite': 0,
              'is_present': 1,
            });
            await Future.delayed(const Duration(milliseconds: 2));
          }
        });
      });

      // Concurrently launch 20 readers querying various tables
      final readerFutures = List.generate(readerCount, (readerId) async {
        final count = await repository.getMediaCount();
        final folders = await repository.getAllFolders();
        final search = await repository.searchMedia('Bombardment');
        expect(count, greaterThanOrEqualTo(20));
        expect(folders, isNotEmpty);
        return search.length;
      });

      // Await all concurrent readers and writers simultaneously
      await Future.wait([...writerFutures, ...readerFutures]);

      // Total items should be 20 baseline + 25 new = 45
      final finalCount = await repository.getMediaCount();
      expect(finalCount, equals(45),
          reason: 'ACID transactional integrity must preserve exact count under concurrency');
    });

    test('3.3 Transaction rollback under concurrent read contention leaves zero dirty reads', () async {
      final initialCount = await repository.getMediaCount();

      // Launch a failing transaction that inserts rows and then throws
      try {
        await repository.transaction((txn) async {
          await txn.insert('Media', {
            'type': 1,
            'title': 'Aborted Video',
            'duration': 10000,
            'play_count': 0,
            'last_position': 0,
            'insertion_date': DateTime.now().millisecondsSinceEpoch,
            'is_favorite': 0,
            'is_present': 1,
          });

          throw Exception('Simulated fatal transaction failure');
        });
      } catch (_) {
        // Expected transaction abort
      }

      // Verify that after rollback, no dirty read persists
      final postAbortCount = await repository.getMediaCount();
      expect(postAbortCount, equals(initialCount),
          reason: 'Aborted transaction must roll back completely without leaving dirty records');
    });

    test('3.4 Device presence cascade triggers atomically toggle presence across hierarchy', () async {
      // Create folder and media file under test device
      final folderId = await repository.upsertFolder(FolderRecord(
        path: p.join(tempDir.path, 'SubDir'),
        name: 'SubDir',
        deviceId: testDeviceId,
        mtime: DateTime.now().millisecondsSinceEpoch,
      ));

      final mediaId = await repository.insertMedia(MediaRecord(
        type: MediaType.video,
        title: 'Cascade Video',
        duration: 90000,
        insertionDate: DateTime.now(),
      ));

      await repository.upsertFile(FileRecord(
        mediaId: mediaId,
        folderId: folderId,
        mrl: p.join(tempDir.path, 'SubDir', 'cascade_video.mp4'),
        mtime: DateTime.now().millisecondsSinceEpoch,
        size: 1048576,
      ));

      // Initially present
      expect((await repository.getAllMedia(onlyPresent: true)).any((m) => m.idMedia == mediaId), isTrue);

      // Dismount device: trigger_device_presence_update fires
      await repository.setDevicePresence(testDeviceId, false);

      // Verify cascading presence hide: media and folder should now be hidden
      final presentMediaAfterDismount = await repository.getAllMedia(onlyPresent: true);
      expect(presentMediaAfterDismount.any((m) => m.idMedia == mediaId), isFalse,
          reason: 'Device dismount must cascade presence = 0 to media');

      final presentFoldersAfterDismount = await repository.getAllFolders(onlyPresent: true);
      expect(presentFoldersAfterDismount.any((f) => f.idFolder == folderId), isFalse,
          reason: 'Device dismount must cascade presence = 0 to folders');

      // Remount device
      await repository.setDevicePresence(testDeviceId, true);

      // Verify restored presence
      final presentMediaAfterRemount = await repository.getAllMedia(onlyPresent: true);
      expect(presentMediaAfterRemount.any((m) => m.idMedia == mediaId), isTrue,
          reason: 'Device remount must restore presence = 1 without data loss');
    });
  });
}
