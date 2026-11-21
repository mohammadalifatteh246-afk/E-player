import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/network_stream/models/online_stream_models.dart';
import 'package:app/features/network_stream/data/online_stream_service.dart';

class MockOnlineStreamHttpTransport implements OnlineStreamHttpTransport {
  String? mockResponse;

  @override
  Future<String> get(Uri uri, {Map<String, String>? headers}) async {
    return mockResponse ??
        '''
{
  "title": "Never Gonna Give You Up (Official Music Video)",
  "author_name": "Rick Astley",
  "thumbnail_url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
  "type": "video",
  "version": "1.0"
}''';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Online Stream Extractor & Video Title Fetcher Tests (VLC Parity)', () {
    late OnlineStreamService service;
    late MockOnlineStreamHttpTransport mockTransport;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockTransport = MockOnlineStreamHttpTransport();
      service = OnlineStreamService(transport: mockTransport);
    });

    test('1. YouTube Video ID extraction handles all standard formats', () {
      expect(
        service.extractYouTubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        service.extractYouTubeVideoId('https://youtu.be/dQw4w9WgXcQ?si=abcdef123'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        service.extractYouTubeVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        service.extractYouTubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        service.extractYouTubeVideoId('https://www.youtube.com/live/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        service.extractYouTubeVideoId('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
        isNull,
      );
    });

    test('2. YouTube oEmbed metadata extraction builds stream formats accurately', () async {
      final info = await service.extractStreamInfo('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

      expect(info.isYouTube, isTrue);
      expect(info.title, equals('Never Gonna Give You Up (Official Music Video)'));
      expect(info.author, equals('Rick Astley'));
      expect(info.thumbnailUrl, contains('dQw4w9WgXcQ'));
      expect(info.formats.length, equals(5));

      final fhd = info.formats.firstWhere((f) => f.qualityLabel.contains('1080p'));
      expect(fhd.resolution, equals('1920x1080'));

      final audio = info.formats.firstWhere((f) => f.isAudioOnly);
      expect(audio.qualityLabel, equals('Audio Only'));
    });

    test('3. Generic HLS and MP4 streams extract stream info cleanly', () async {
      const hlsUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
      final hlsInfo = await service.extractStreamInfo(hlsUrl);

      expect(hlsInfo.isYouTube, isFalse);
      expect(hlsInfo.title, equals('x36xhzz.m3u8'));
      expect(hlsInfo.formats.first.qualityLabel, contains('HLS'));
      expect(hlsInfo.formats.first.mimeType, equals('application/x-mpegURL'));

      const mp4Url = 'https://cdn.example.com/media/anime_episode_01.mp4';
      final mp4Info = await service.extractStreamInfo(mp4Url);

      expect(mp4Info.isYouTube, isFalse);
      expect(mp4Info.title, equals('anime_episode_01.mp4'));
      expect(mp4Info.author, equals('cdn.example.com'));
    });

    test('4. Recent streams history strictly caps at maximum 5 items (FIFO eviction)', () async {
      final prefs = await SharedPreferences.getInstance();
      await service.init(prefs);

      expect(service.recentStreams, isEmpty);

      // Add 7 items sequentially
      for (int i = 1; i <= 7; i++) {
        await service.addRecentStream(
          RecentStreamEntry(
            url: 'https://cdn.example.com/stream_$i.mp4',
            title: 'Stream #$i',
            timestamp: DateTime.now(),
          ),
          prefs: prefs,
        );
      }

      // Must be strictly capped at 5
      expect(service.recentStreams.length, equals(5));

      // Most recent should be Stream #7
      expect(service.recentStreams.first.title, equals('Stream #7'));

      // Oldest retained should be Stream #3 (1 and 2 evicted)
      expect(service.recentStreams.last.title, equals('Stream #3'));

      // Re-adding Stream #4 moves it to the top
      await service.addRecentStream(
        RecentStreamEntry(
          url: 'https://cdn.example.com/stream_4.mp4',
          title: 'Stream #4 Updated',
          timestamp: DateTime.now(),
        ),
        prefs: prefs,
      );

      expect(service.recentStreams.length, equals(5));
      expect(service.recentStreams.first.title, equals('Stream #4 Updated'));

      // Clear history
      await service.clearRecentHistory(prefs: prefs);
      expect(service.recentStreams, isEmpty);
    });
  });
}
