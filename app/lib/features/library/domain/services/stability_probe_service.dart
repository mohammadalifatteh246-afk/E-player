import 'dart:io';
import 'dart:math' as math;

/// Service interface to probe active file stability during file transfers or downloads.
abstract class IStabilityProbeService {
  Future<bool> probeFileStability(
    String filePath, {
    int maxRetries = 5,
    Duration baseDelay = const Duration(milliseconds: 200),
    Duration samplingDelay = const Duration(milliseconds: 500),
  });
}

/// Production implementation of StabilityProbeService using two-phase exponential probing.
class StabilityProbeService implements IStabilityProbeService {
  const StabilityProbeService();

  @override
  Future<bool> probeFileStability(
    String filePath, {
    int maxRetries = 5,
    Duration baseDelay = const Duration(milliseconds: 200),
    Duration samplingDelay = const Duration(milliseconds: 500),
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    int retries = 0;

    while (retries < maxRetries) {
      // 1. Lock Probe: Verify file is not exclusively locked by another process
      RandomAccessFile? raf;
      try {
        raf = await file.open(mode: FileMode.read);
        await raf.lock(FileLock.exclusive);
        await raf.unlock();
      } on FileSystemException {
        // Sharing violation (Windows errno 32) or locked file descriptor
        retries++;
        final backoffMs = math.min(
          2000,
          (baseDelay.inMilliseconds * math.pow(2, retries)).toInt(),
        );
        await Future.delayed(Duration(milliseconds: backoffMs));
        continue;
      } catch (_) {
        retries++;
        await Future.delayed(baseDelay);
        continue;
      } finally {
        try {
          await raf?.close();
        } catch (_) {}
      }

      // 2. Attribute Invariance Probe
      try {
        final stat1 = await file.stat();
        final size1 = stat1.size;
        final mtime1 = stat1.modified.millisecondsSinceEpoch;

        if (samplingDelay > Duration.zero) {
          await Future.delayed(samplingDelay);
        }

        final stat2 = await file.stat();
        final size2 = stat2.size;
        final mtime2 = stat2.modified.millisecondsSinceEpoch;

        if (size1 == size2 && mtime1 == mtime2) {
          return true; // File write is completely settled and stable
        } else {
          // File is actively growing or modified
          retries++;
          final backoffMs = math.min(
            2000,
            (baseDelay.inMilliseconds * math.pow(2, retries)).toInt(),
          );
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
      } catch (_) {
        retries++;
        await Future.delayed(baseDelay);
        continue;
      }
    }

    return false; // Timed out waiting for stability
  }
}
