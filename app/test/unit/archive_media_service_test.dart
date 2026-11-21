import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:app/features/archive/services/archive_media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String zipPath;
  late String tarPath;

  final sampleVideoBytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
  final sampleAudioBytes = Uint8List.fromList(List.generate(512, (i) => (i * 3) % 256));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('eplayer_archive_test_');

    // 1. Create test zip archive
    final zipArchive = Archive()
      ..addFile(ArchiveFile('episodes/intro.mp4', sampleVideoBytes.length, sampleVideoBytes))
      ..addFile(ArchiveFile('soundtrack.flac', sampleAudioBytes.length, sampleAudioBytes))
      ..addFile(ArchiveFile('notes.txt', 12, 'Hello World!'.codeUnits));

    final zipData = ZipEncoder().encode(zipArchive);
    final zipFile = File('${tempDir.path}/media_bundle.zip');
    await zipFile.writeAsBytes(zipData);
    zipPath = zipFile.path;

    // 2. Create test tar archive
    final tarArchive = Archive()
      ..addFile(ArchiveFile('movies/clip.mkv', sampleVideoBytes.length, sampleVideoBytes));
    final tarData = TarEncoder().encode(tarArchive);
    final tarFile = File('${tempDir.path}/video_pack.tar');
    await tarFile.writeAsBytes(tarData);
    tarPath = tarFile.path;
  });

  tearDown(() async {
    await ArchiveMediaService.cleanupCache(archivePath: zipPath);
    await ArchiveMediaService.cleanupCache(archivePath: tarPath);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ArchiveMediaService Tests (VLC Parity)', () {
    test('1. isArchive identifies supported archive formats', () {
      expect(ArchiveMediaService.isArchive('C:/Downloads/show.zip'), isTrue);
      expect(ArchiveMediaService.isArchive('D:/Torrents/anime.tar'), isTrue);
      expect(ArchiveMediaService.isArchive('/home/user/media.tar.gz'), isTrue);
      expect(ArchiveMediaService.isArchive('/home/user/pack.tgz'), isTrue);

      expect(ArchiveMediaService.isArchive('C:/Videos/movie.mp4'), isFalse);
      expect(ArchiveMediaService.isArchive('C:/Playlists/list.m3u8'), isFalse);
    });

    test('2. listMediaInArchive lists video and audio while filtering non-media', () async {
      final entries = await ArchiveMediaService.listMediaInArchive(zipPath);

      expect(entries.length, equals(2));
      final names = entries.map((e) => e.name).toList();
      expect(names, contains('intro.mp4'));
      expect(names, contains('soundtrack.flac'));
      expect(names, isNot(contains('notes.txt')));

      final videoEntry = entries.firstWhere((e) => e.name == 'intro.mp4');
      expect(videoEntry.isVideo, isTrue);
      expect(videoEntry.isAudio, isFalse);
      expect(videoEntry.uncompressedSize, equals(1024));

      final audioEntry = entries.firstWhere((e) => e.name == 'soundtrack.flac');
      expect(audioEntry.isAudio, isTrue);
      expect(audioEntry.isVideo, isFalse);
    });

    test('3. extractMedia extracts targeted media file to playable cache', () async {
      final extractedPath = await ArchiveMediaService.extractMedia(zipPath, 'episodes/intro.mp4');

      expect(extractedPath, isNotNull);
      final file = File(extractedPath!);
      expect(await file.exists(), isTrue);
      expect(await file.length(), equals(1024));

      final readBytes = await file.readAsBytes();
      expect(readBytes, equals(sampleVideoBytes));

      // Test cache hit: extracting again returns same path without error
      final secondPath = await ArchiveMediaService.extractMedia(zipPath, 'episodes/intro.mp4');
      expect(secondPath, equals(extractedPath));
    });

    test('4. extractMedia extracts from TAR archive accurately', () async {
      final entries = await ArchiveMediaService.listMediaInArchive(tarPath);
      expect(entries.length, equals(1));
      expect(entries.first.name, equals('clip.mkv'));

      final extractedPath = await ArchiveMediaService.extractMedia(tarPath, 'movies/clip.mkv');
      expect(extractedPath, isNotNull);
      final file = File(extractedPath!);
      expect(await file.exists(), isTrue);
      expect(await file.length(), equals(sampleVideoBytes.length));
    });

    test('5. cleanupCache deletes temporary cached files cleanly', () async {
      final extractedPath = await ArchiveMediaService.extractMedia(zipPath, 'episodes/intro.mp4');
      expect(extractedPath, isNotNull);
      expect(await File(extractedPath!).exists(), isTrue);

      await ArchiveMediaService.cleanupCache(archivePath: zipPath);
      expect(await File(extractedPath).exists(), isFalse);
    });
  });
}
