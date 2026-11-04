import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:app/features/library/domain/services/stability_probe_service.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  late EPlayerTestHarness harness;
  const probe = StabilityProbeService();

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  group('StabilityProbeService Two-Phase Probing Tests', () {
    test('1. Settled file passes stability probing immediately', () async {
      final tempDir = harness.createTempDirectory('probe_settled_');
      final file = await harness.createMockVideoFile(tempDir, 'settled_video.mp4');

      final isStable = await probe.probeFileStability(
        file.path,
        maxRetries: 2,
        baseDelay: const Duration(milliseconds: 50),
        samplingDelay: const Duration(milliseconds: 100),
      );

      expect(isStable, isTrue);
    });

    test('2. Non-existent file returns false safely', () async {
      final isStable = await probe.probeFileStability(
        'C:\\NonExistentPath\\ghost_file.mp4',
        maxRetries: 1,
      );
      expect(isStable, isFalse);
    });

    test('3. Actively locked file descriptor triggers backoff and fails if held', () async {
      final tempDir = harness.createTempDirectory('probe_lock_');
      final testFile = File(p.join(tempDir.path, 'locked_stream.mkv'));

      // Hold exclusive lock on file
      final raf = await testFile.open(mode: FileMode.write);
      await raf.lock(FileLock.exclusive);
      await raf.writeString('partial chunk header');

      // Attempt probe while locked
      final isStableWhileLocked = await probe.probeFileStability(
        testFile.path,
        maxRetries: 2,
        baseDelay: const Duration(milliseconds: 50),
        samplingDelay: const Duration(milliseconds: 50),
      );
      expect(isStableWhileLocked, isFalse);

      await raf.unlock();
      await raf.close();

      // Now closed and settled -> passes probe
      final isStableAfterClose = await probe.probeFileStability(
        testFile.path,
        maxRetries: 2,
        baseDelay: const Duration(milliseconds: 50),
        samplingDelay: const Duration(milliseconds: 50),
      );
      expect(isStableAfterClose, isTrue);
    });
  });
}
