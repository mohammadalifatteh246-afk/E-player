import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/services/desktop_drag_drop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DesktopDragDropService service;

  setUp(() {
    service = DesktopDragDropService();
    service.initialize(isTest: true);
  });

  tearDown(() {
    service.dispose();
  });

  group('Desktop Drag-and-Drop Ingestion (VLC Parity) - Unit Tests', () {
    test('DroppedItem classifies video and audio formats correctly', () {
      final testCases = [
        ('C:/Videos/movie.mp4', DroppedItemType.videoAudio, 'mp4'),
        ('D:/Media/clip.mkv', DroppedItemType.videoAudio, 'mkv'),
        ('E:/Archive/stream.ts', DroppedItemType.videoAudio, 'ts'),
        ('/home/user/song.mp3', DroppedItemType.videoAudio, 'mp3'),
        ('C:/Music/audio.flac', DroppedItemType.videoAudio, 'flac'),
        ('C:/Music/podcast.opus', DroppedItemType.videoAudio, 'opus'),
      ];

      for (final (path, expectedType, expectedExt) in testCases) {
        final item = DroppedItem.fromPath(path);
        expect(item.type, equals(expectedType), reason: 'Failed for $path');
        expect(item.extension, equals(expectedExt));
      }
    });

    test('DroppedItem classifies subtitle formats correctly', () {
      final testCases = [
        ('C:/Subtitles/movie.srt', DroppedItemType.subtitle, 'srt'),
        ('D:/Media/caption.vtt', DroppedItemType.subtitle, 'vtt'),
        ('C:/Anime/dialogue.ass', DroppedItemType.subtitle, 'ass'),
        ('E:/Subs/legacy.sub', DroppedItemType.subtitle, 'sub'),
        ('C:/Subs/script.ssa', DroppedItemType.subtitle, 'ssa'),
      ];

      for (final (path, expectedType, expectedExt) in testCases) {
        final item = DroppedItem.fromPath(path);
        expect(item.type, equals(expectedType), reason: 'Failed for $path');
        expect(item.extension, equals(expectedExt));
      }
    });

    test('DroppedItem classifies playlist formats correctly (M3U, M3U8, XSPF)', () {
      final testCases = [
        ('C:/Playlists/anime.m3u', DroppedItemType.playlist, 'm3u'),
        ('D:/Music/chill.m3u8', DroppedItemType.playlist, 'm3u8'),
        ('E:/Mixes/tracks.xspf', DroppedItemType.playlist, 'xspf'),
      ];

      for (final (path, expectedType, expectedExt) in testCases) {
        final item = DroppedItem.fromPath(path);
        expect(item.type, equals(expectedType), reason: 'Failed for $path');
        expect(item.extension, equals(expectedExt));
      }
    });

    test('DroppedItem classifies directories and unsupported files', () {
      final tempDir = Directory.systemTemp.createTempSync('eplayer_drop_test');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final folderItem = DroppedItem.fromPath(tempDir.path);
      expect(folderItem.type, equals(DroppedItemType.folder));

      final unsupportedItem = DroppedItem.fromPath('C:/Documents/report.pdf');
      expect(unsupportedItem.type, equals(DroppedItemType.unsupported));
    });

    test('DroppedMediaEvent categorizes mixed dropped files correctly', () {
      final items = [
        DroppedItem.fromPath('C:/Movies/Inception.mkv'),
        DroppedItem.fromPath('C:/Movies/Inception_en.srt'),
        DroppedItem.fromPath('C:/Playlists/movies.m3u8'),
        DroppedItem.fromPath('C:/Movies/Notes.pdf'),
      ];

      final event = DroppedMediaEvent(items: items);

      expect(event.hasVideoAudio, isTrue);
      expect(event.hasSubtitle, isTrue);
      expect(event.hasPlaylist, isTrue);
      expect(event.videoAudioItems.length, equals(1));
      expect(event.videoAudioItems.first.name, equals('Inception.mkv'));
      expect(event.subtitleItems.length, equals(1));
      expect(event.subtitleItems.first.name, equals('Inception_en.srt'));
      expect(event.playlistItems.length, equals(1));
      expect(event.playlistItems.first.name, equals('movies.m3u8'));
      expect(event.primaryItem?.name, equals('Inception.mkv'));
    });

    test('DesktopDragDropService broadcasts dropped events through stream', () async {
      DroppedMediaEvent? receivedEvent;
      final sub = service.stream.listen((event) {
        receivedEvent = event;
      });
      addTearDown(() => sub.cancel());

      final droppedPaths = [
        'C:/Downloads/video.mp4',
        'C:/Downloads/subs.vtt',
      ];

      service.simulateDrop(droppedPaths);

      // Allow microtask queue to process
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.items.length, equals(2));
      expect(receivedEvent!.hasVideoAudio, isTrue);
      expect(receivedEvent!.hasSubtitle, isTrue);
      expect(receivedEvent!.videoAudioItems.first.name, equals('video.mp4'));
      expect(receivedEvent!.subtitleItems.first.name, equals('subs.vtt'));
    });

    test('DesktopDragDropService gracefully handles empty drop list', () async {
      var eventEmitted = false;
      final sub = service.stream.listen((_) {
        eventEmitted = true;
      });
      addTearDown(() => sub.cancel());

      service.simulateDrop([]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(eventEmitted, isFalse);
    });
  });
}
