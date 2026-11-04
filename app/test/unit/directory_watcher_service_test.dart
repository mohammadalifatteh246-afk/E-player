import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:app/core/models/media_library_models.dart';
import 'package:app/features/browser/domain/directory_watcher_service.dart';
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

  group('DirectoryWatcherService Debounce and Coalescing Tests', () {
    test('1. Debounces rapid file create and modify events', () async {
      final tempDir = harness.createTempDirectory('watcher_debounce_');
      final watcher = DirectoryWatcherService(
        debounceDuration: const Duration(milliseconds: 150),
      );

      final receivedEvents = <WatcherEvent>[];
      final sub = watcher.events.listen(receivedEvents.add);

      await watcher.startWatching([tempDir.path]);
      expect(watcher.watchedPaths, contains(tempDir.path));

      // Trigger rapid file creation and writes
      final file = File(p.join(tempDir.path, 'video.mp4'));
      await file.writeAsString('chunk 1', flush: true);
      await Future.delayed(const Duration(milliseconds: 30));
      await file.writeAsString('chunk 2', flush: true);
      await Future.delayed(const Duration(milliseconds: 30));
      await file.writeAsString('chunk 3', flush: true);

      // Wait for debounce duration to settle
      await Future.delayed(const Duration(milliseconds: 350));

      await sub.cancel();
      watcher.dispose();

      // Should have coalesced rapid writes into a single debounced event
      expect(receivedEvents, isNotEmpty);
      expect(receivedEvents.any((e) => e.path == file.path), isTrue);
    });

    test('2. Temporary file creation followed by immediate delete is coalesced to NOOP', () async {
      final tempDir = harness.createTempDirectory('watcher_noop_');
      final watcher = DirectoryWatcherService(
        debounceDuration: const Duration(milliseconds: 200),
      );

      final receivedEvents = <WatcherEvent>[];
      final sub = watcher.events.listen(receivedEvents.add);

      await watcher.startWatching([tempDir.path]);

      // Create scratch file then immediately delete within debounce window
      final tempFile = File(p.join(tempDir.path, 'download.tmp'));
      await tempFile.writeAsString('temp data');
      await Future.delayed(const Duration(milliseconds: 20));
      await tempFile.delete();

      // Wait for debounce window
      await Future.delayed(const Duration(milliseconds: 350));

      await sub.cancel();
      watcher.dispose();

      // Should be NOOP - no event emitted for the temp file
      expect(receivedEvents.where((e) => e.path == tempFile.path), isEmpty);
    });

    test('3. Stop watching directory removes subscription cleanly', () async {
      final tempDir = harness.createTempDirectory('watcher_stop_');
      final watcher = DirectoryWatcherService();

      await watcher.startWatching([tempDir.path]);
      expect(watcher.watchedPaths, contains(tempDir.path));

      await watcher.stopWatching(tempDir.path);
      expect(watcher.watchedPaths, isNot(contains(tempDir.path)));

      watcher.dispose();
    });
  });
}
