import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/services/video_snapshot_service.dart';

void main() {
  group('VideoSnapshotService Logic & File Operations Tests', () {
    late Directory tempDir;
    late VideoSnapshotService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('snapshot_test_');
      service = VideoSnapshotService(customStorageDir: tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Generates standardized VLC filename pattern: vlcsnap-YYYY-MM-DD-HHmmss', () {
      final now = DateTime(2026, 11, 13, 14, 30, 45);
      final fileName = service.generateSnapshotFileName(timestamp: now);

      expect(fileName, startsWith('vlcsnap-2026-11-13-143045'));
      expect(fileName, endsWith('.png'));
    });

    test('Saves snapshot bytes to PNG file and preserves preview data', () async {
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG Header
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      ]);

      final result = await service.saveSnapshotBytes(
        bytes: dummyPngBytes,
        position: const Duration(minutes: 12, seconds: 34),
        mediaTitle: 'Cyberpunk 2077',
      );

      expect(result.success, isTrue);
      expect(result.file, isNotNull);
      expect(result.file!.existsSync(), isTrue);
      expect(result.file!.lengthSync(), dummyPngBytes.length);
      expect(result.formattedPosition, '12:34');
      expect(result.previewBytes, dummyPngBytes);
    });

    test('Deduplicates filenames when multiple snapshots taken in same second', () async {
      final dummyBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final fixedTime = DateTime(2026, 11, 13, 15, 0, 0);

      final r1 = await service.saveSnapshotBytes(
        bytes: dummyBytes,
        position: const Duration(seconds: 1),
        overrideTime: fixedTime,
      );

      final r2 = await service.saveSnapshotBytes(
        bytes: dummyBytes,
        position: const Duration(seconds: 2),
        overrideTime: fixedTime,
      );

      expect(r1.file!.path, isNot(equals(r2.file!.path)));
      expect(r2.file!.path, contains('-1.png'));
    });

    test('Handles null or empty image bytes gracefully with failure result', () async {
      final result = await service.saveSnapshotBytes(
        bytes: null,
        position: Duration.zero,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(result.file, isNull);
    });
  });
}
