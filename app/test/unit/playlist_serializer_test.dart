import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/player/services/playlist_serializer.dart';

void main() {
  group('PlaylistSerializer Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('playlist_serializer_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final sampleItems = [
      MediaItem(
        path: Platform.isWindows ? r'D:\Movies\Clip 1.mp4' : '/movies/Clip 1.mp4',
        name: 'Action Movie Scene',
        parentFolder: Platform.isWindows ? r'D:\Movies' : '/movies',
        durationMs: 125000,
        lastPlayed: DateTime.now(),
      ),
      MediaItem(
        path: Platform.isWindows ? r'D:\Music\Song.mp3' : '/music/Song.mp3',
        name: 'Synthwave Intro',
        parentFolder: Platform.isWindows ? r'D:\Music' : '/music',
        durationMs: 240000,
        lastPlayed: DateTime.now(),
      ),
      MediaItem(
        path: 'http://example.com/live/stream.m3u8',
        name: 'Cyberpunk Radio Stream',
        parentFolder: '',
        durationMs: 0,
        lastPlayed: DateTime.now(),
      ),
    ];

    test('1. serializeM3u8 produces Extended M3U format', () {
      final m3u = PlaylistSerializer.serializeM3u8(sampleItems);

      expect(m3u, startsWith('#EXTM3U\n'));
      expect(m3u, contains('#EXTINF:125,Action Movie Scene'));
      expect(m3u, contains('#EXTINF:240,Synthwave Intro'));
      expect(m3u, contains('#EXTINF:-1,Cyberpunk Radio Stream'));
      expect(m3u, contains(sampleItems[0].path));
      expect(m3u, contains('http://example.com/live/stream.m3u8'));
    });

    test('2. parseM3u parses titles, durations, and paths', () {
      const rawM3u = '#EXTM3U\n'
          '#EXTVLCOPT:network-caching=1000\n'
          '#EXTINF:60,Trailer & Preview\n'
          'video_trailer.mp4\n'
          '#EXTINF:180,Anime Opening\n'
          'http://cdn.stream.com/anime.mkv\n';

      final items = PlaylistSerializer.parseM3u(rawM3u, baseDir: tempDir.path);

      expect(items.length, 2);
      expect(items[0].name, 'Trailer & Preview');
      expect(items[0].durationMs, 60000);
      expect(items[0].path, contains('video_trailer.mp4'));

      expect(items[1].name, 'Anime Opening');
      expect(items[1].durationMs, 180000);
      expect(items[1].path, 'http://cdn.stream.com/anime.mkv');
    });

    test('3. serializeXspf generates valid XSPF XML', () {
      final xml = PlaylistSerializer.serializeXspf(sampleItems, title: 'Test Queue');

      expect(xml, contains('<playlist version="1" xmlns="http://xspf.org/ns/0/">'));
      expect(xml, contains('<title>Test Queue</title>'));
      expect(xml, contains('<trackList>'));
      expect(xml, contains('<title>Action Movie Scene</title>'));
      expect(xml, contains('<duration>125000</duration>'));
      expect(xml, contains('<title>Cyberpunk Radio Stream</title>'));
      expect(xml, contains('<location>http://example.com/live/stream.m3u8</location>'));
    });

    test('4. parseXspf parses tracks and unescapes entities', () {
      const sampleXspf = '''<?xml version="1.0" encoding="UTF-8"?>
<playlist version="1" xmlns="http://xspf.org/ns/0/">
  <title>VLC Export</title>
  <trackList>
    <track>
      <location>http://streams.org/radio.mp3</location>
      <title>Rock &amp; Roll Live</title>
      <duration>300000</duration>
    </track>
    <track>
      <location>file:///C:/Media/Episode%201.mkv</location>
      <title>Episode 1</title>
    </track>
  </trackList>
</playlist>''';

      final items = PlaylistSerializer.parseXspf(sampleXspf);

      expect(items.length, 2);
      expect(items[0].name, 'Rock & Roll Live');
      expect(items[0].path, 'http://streams.org/radio.mp3');
      expect(items[0].durationMs, 300000);

      expect(items[1].name, 'Episode 1');
      expect(items[1].path, contains('Episode 1.mkv'));
    });

    test('5. Round-trip file save and load test (M3U8 & XSPF)', () async {
      final m3uPath = '${tempDir.path}/test_queue.m3u8';
      final xspfPath = '${tempDir.path}/test_queue.xspf';

      // Save M3U8
      final m3uFile = await PlaylistSerializer.saveToFile(sampleItems, m3uPath);
      expect(m3uFile.existsSync(), isTrue);

      // Load M3U8
      final loadedM3u = await PlaylistSerializer.loadFromFile(m3uFile);
      expect(loadedM3u.length, sampleItems.length);
      expect(loadedM3u[0].name, sampleItems[0].name);

      // Save XSPF
      final xspfFile = await PlaylistSerializer.saveToFile(sampleItems, xspfPath);
      expect(xspfFile.existsSync(), isTrue);

      // Load XSPF
      final loadedXspf = await PlaylistSerializer.loadFromFile(xspfFile);
      expect(loadedXspf.length, sampleItems.length);
      expect(loadedXspf[0].name, sampleItems[0].name);
    });
  });
}
