import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/network_stream/models/online_stream_models.dart';
import 'package:app/features/network_stream/data/online_stream_service.dart';
import 'package:app/features/network_stream/ui/online_stream_sheet.dart';

class MockOnlineStreamHttpTransport implements OnlineStreamHttpTransport {
  String? mockResponse;

  @override
  Future<String> get(Uri uri, {Map<String, String>? headers}) async {
    return mockResponse ??
        '''
{
  "title": "Never Gonna Give You Up",
  "author_name": "Rick Astley",
  "thumbnail_url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
}''';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Online Stream Sheet UI Tests (VLC Ctrl+N Parity)', () {
    late OnlineStreamService service;
    late MockOnlineStreamHttpTransport transport;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      transport = MockOnlineStreamHttpTransport();
      service = OnlineStreamService(transport: transport);
    });

    testWidgets('1. Renders sheet with input, extract button, and empty history', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: OnlineStreamSheet(
              service: service,
              onPlayStream: (url, title) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Network Stream'), findsOneWidget);
      expect(find.byKey(const Key('online_stream_url_input')), findsOneWidget);
      expect(find.byKey(const Key('online_stream_extract_button')), findsOneWidget);
      expect(find.byKey(const Key('online_stream_paste_button')), findsOneWidget);
      expect(find.textContaining('No recent online streams'), findsOneWidget);
    });

    testWidgets('2. Enters YouTube URL, extracts metadata, selects quality, and plays stream', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? playedUrl;
      String? playedTitle;
      String? enqueuedUrl;
      String? enqueuedTitle;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: OnlineStreamSheet(
              service: service,
              onPlayStream: (url, title) {
                playedUrl = url;
                playedTitle = title;
              },
              onEnqueueStream: (url, title) {
                enqueuedUrl = url;
                enqueuedTitle = title;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter YouTube URL
      await tester.enterText(
        find.byKey(const Key('online_stream_url_input')),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      await tester.pumpAndSettle();

      // Tap Extract
      await tester.tap(find.byKey(const Key('online_stream_extract_button')));
      await tester.pumpAndSettle();

      // Verify preview card
      expect(find.byKey(const Key('online_stream_preview_title')), findsOneWidget);
      expect(find.text('Never Gonna Give You Up'), findsOneWidget);
      expect(find.text('Rick Astley'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);

      // Verify Quality dropdown is present
      expect(find.byKey(const Key('online_stream_quality_dropdown')), findsOneWidget);

      // Tap Enqueue
      final enqueueBtn = find.byKey(const Key('online_stream_enqueue_button'));
      expect(enqueueBtn, findsOneWidget);
      await tester.tap(enqueueBtn);
      await tester.pumpAndSettle();

      expect(enqueuedUrl, contains('dQw4w9WgXcQ'));
      expect(enqueuedTitle, equals('Never Gonna Give You Up'));

      // Tap Play
      final playBtn = find.byKey(const Key('online_stream_play_button'));
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      expect(playedUrl, contains('dQw4w9WgXcQ'));
      expect(playedTitle, equals('Never Gonna Give You Up'));

      // Verify added to recent streams
      expect(service.recentStreams.length, equals(1));
      expect(service.recentStreams.first.title, equals('Never Gonna Give You Up'));
    });

    testWidgets('3. Recent streams list renders and can be cleared', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await SharedPreferences.getInstance();
      await service.init(prefs);

      // Add dummy stream to history
      await service.addRecentStream(
        RecentStreamEntry(
          url: 'https://test.com/video.mp4',
          title: 'Cyberpunk Trailer 4K',
          author: 'test.com',
          timestamp: DateTime.now(),
        ),
        prefs: prefs,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: OnlineStreamSheet(
              service: service,
              onPlayStream: (url, title) {},
              prefs: prefs,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cyberpunk Trailer 4K'), findsOneWidget);
      expect(find.byKey(const Key('online_stream_clear_history_button')), findsOneWidget);

      // Tap Clear
      await tester.tap(find.byKey(const Key('online_stream_clear_history_button')));
      await tester.pumpAndSettle();

      expect(find.text('Cyberpunk Trailer 4K'), findsNothing);
      expect(service.recentStreams, isEmpty);
    });
  });
}
