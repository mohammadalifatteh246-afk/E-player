import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:app/core/models/media_library_models.dart';
import 'package:app/features/browser/domain/file_system_service.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  late EPlayerTestHarness harness;
  const service = DefaultFileSystemService();

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  group('FileSystemService Navigation & Filtering Tests', () {
    test('1. Discovers logical drive roots', () {
      final drives = service.getLogicalDrives();
      expect(drives, isNotEmpty);
      if (Platform.isWindows) {
        expect(drives.any((d) => d.contains(':')), isTrue);
      } else {
        expect(drives, contains('/'));
      }
    });

    test('2. Path normalization applies extended-length prefix on long paths', () {
      final shortPath = 'C:\\Videos\\Movie.mp4';
      expect(service.normalizePath(shortPath), equals(p.normalize(shortPath)));

      if (Platform.isWindows) {
        final longPath = 'C:\\${'nested_folder\\' * 25}sample.mkv';
        final normalized = service.normalizePath(longPath);
        expect(normalized.startsWith(r'\\?\'), isTrue);
      }
    });

    test('3. Parses clickable breadcrumb segments correctly', () {
      final samplePath = Platform.isWindows ? 'C:\\Users\\Admin\\Videos' : '/home/admin/videos';
      final breadcrumbs = service.parseBreadcrumbs(samplePath);

      expect(breadcrumbs, isNotEmpty);
      expect(breadcrumbs.last.name, equals('Videos'));
      if (Platform.isWindows) {
        expect(breadcrumbs.first.name, equals('C:\\'));
      } else {
        expect(breadcrumbs.first.name, equals('/'));
      }
    });

    test('4. Detects .nomedia file and prunes directory correctly', () async {
      final tempDir = harness.createTempDirectory('nomedia_test_');
      final nomediaFile = File(p.join(tempDir.path, '.nomedia'));

      expect(await service.hasNoMedia(tempDir.path), isFalse);

      await nomediaFile.writeAsString('');
      expect(await service.hasNoMedia(tempDir.path), isTrue);
    });

    test('5. Lists directory with hidden file and media extension filters', () async {
      final tempDir = harness.createTempDirectory('list_test_');

      // Create fixtures
      await harness.createMockVideoFile(tempDir, 'movie_1.mp4');
      await harness.createMockVideoFile(tempDir, 'movie_2.mkv');
      await harness.createMockSubtitleSrt(tempDir, 'movie_1.srt');

      // Create non-media file
      final txtFile = File(p.join(tempDir.path, 'notes.txt'));
      await txtFile.writeAsString('readme text');

      // Create hidden file
      final hiddenFile = File(p.join(tempDir.path, '.hidden_config'));
      await hiddenFile.writeAsString('hidden');

      // Create child directory
      final subDir = Directory(p.join(tempDir.path, 'SubFolder'));
      await subDir.create();

      // List with showHidden = false (default)
      final contents = await service.listDirectoryContents(tempDir.path, showHidden: false);
      final names = contents.map((c) => c.name).toSet();

      expect(names, contains('SubFolder'));
      expect(names, contains('movie_1.mp4'));
      expect(names, contains('movie_2.mkv'));
      expect(names, contains('movie_1.srt'));
      expect(names, isNot(contains('.hidden_config')));
      expect(names, isNot(contains('notes.txt'))); // non-media filtered out

      // List with showHidden = true
      final contentsWithHidden = await service.listDirectoryContents(tempDir.path, showHidden: true);
      final namesWithHidden = contentsWithHidden.map((c) => c.name).toSet();
      expect(namesWithHidden, contains('.hidden_config'));
      expect(namesWithHidden, contains('notes.txt'));
    });

    test('6. Correctly categorizes FileNodeType for various media formats', () {
      expect(service.determineNodeType('video.mp4', isDirectory: false), equals(FileNodeType.videoFile));
      expect(service.determineNodeType('video.mkv', isDirectory: false), equals(FileNodeType.videoFile));
      expect(service.determineNodeType('audio.mp3', isDirectory: false), equals(FileNodeType.audioFile));
      expect(service.determineNodeType('audio.flac', isDirectory: false), equals(FileNodeType.audioFile));
      expect(service.determineNodeType('sub.srt', isDirectory: false), equals(FileNodeType.subtitleFile));
      expect(service.determineNodeType('doc.pdf', isDirectory: false), equals(FileNodeType.otherFile));
      expect(service.determineNodeType('my_folder', isDirectory: true), equals(FileNodeType.directory));
    });
  });
}
