import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/subtitles/models/subtitle_result.dart';
import 'package:app/features/subtitles/data/opensubtitles_service.dart';
import 'package:app/features/subtitles/ui/online_subtitles_sheet.dart';

class MockSubtitlesHttpClient implements SubtitlesHttpClient {
  final Map<String, SubtitlesHttpResponse> responses = {};

  @override
  Future<SubtitlesHttpResponse> get(Uri uri, {Map<String, String>? headers}) async {
    for (final entry in responses.entries) {
      if (uri.toString().contains(entry.key)) {
        return entry.value;
      }
    }
    return const SubtitlesHttpResponse(statusCode: 200, body: '{"data": []}');
  }

  @override
  Future<SubtitlesHttpResponse> post(Uri uri, {Map<String, String>? headers, String? body}) async {
    for (final entry in responses.entries) {
      if (uri.toString().contains(entry.key)) {
        return entry.value;
      }
    }
    return const SubtitlesHttpResponse(
      statusCode: 200,
      body: '{"link": "https://download.opensubtitles.com/test_sub.srt"}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnlineSubtitlesSheet Unit & Widget Tests', () {
    late Directory tempDir;
    late File dummyVideoFile;
    late MockSubtitlesHttpClient mockHttp;
    late OpenSubtitlesService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('eplayer_sub_ui_test_');
      dummyVideoFile = File('${tempDir.path}/Inception.mkv');
      final data = Uint8List(131072);
      data[0] = 0x1A;
      data[1] = 0x45;
      data[131071] = 0x99;
      dummyVideoFile.writeAsBytesSync(data, flush: true);

      mockHttp = MockSubtitlesHttpClient();
      service = OpenSubtitlesService(
        baseUrl: 'https://api.opensubtitles.com/api/v1',
        apiKey: 'test_key',
        httpClient: mockHttp,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    testWidgets('Renders search input and initial title correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnlineSubtitlesSheet(
              videoFile: dummyVideoFile,
              videoTitle: 'Inception',
              service: service,
              onSubtitleLoaded: (file, sub) {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Online Subtitles (VLSub)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Inception'), findsOneWidget);
    });

    testWidgets('Populates subtitle results when search succeeds', (tester) async {
      mockHttp.responses['query=Inception'] = SubtitlesHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'total_count': 1,
          'data': [
            {
              'id': 'sub-inc-1',
              'type': 'subtitle',
              'attributes': {
                'subtitle_id': 'sub-inc-1',
                'language': 'en',
                'language_name': 'English',
                'download_count': 14200,
                'ratings': 9.2,
                'format': 'srt',
                'hearing_impaired': false,
                'feature_details': {
                  'title': 'Inception',
                  'year': 2010,
                },
                'url': 'https://download.opensubtitles.com/sub_inc_1.srt',
                'files': [
                  {'file_id': 991, 'file_name': 'Inception.2010.en.srt'}
                ]
              }
            }
          ]
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnlineSubtitlesSheet(
              videoFile: dummyVideoFile,
              videoTitle: 'Inception',
              service: service,
              onSubtitleLoaded: (file, sub) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'English'), findsOneWidget);
      expect(find.text('★ 9.2'), findsOneWidget);
      expect(find.text('★ 9.2'), findsOneWidget);
    });

    testWidgets('Selecting a subtitle triggers download and onSubtitleLoaded callback', (tester) async {
      mockHttp.responses['query=Inception'] = SubtitlesHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'total_count': 1,
          'data': [
            {
              'id': 'sub-inc-1',
              'type': 'subtitle',
              'attributes': {
                'subtitle_id': 'sub-inc-1',
                'language': 'en',
                'language_name': 'English',
                'download_count': 14200,
                'ratings': 9.2,
                'format': 'srt',
                'hearing_impaired': false,
                'feature_details': {
                  'title': 'Inception',
                  'year': 2010,
                },
                'url': 'https://download.opensubtitles.com/sub_inc_1.srt',
                'files': [
                  {'file_id': 991, 'file_name': 'Inception.2010.en.srt'}
                ]
              }
            }
          ]
        }),
      );

      mockHttp.responses['sub_inc_1.srt'] = const SubtitlesHttpResponse(
        statusCode: 200,
        body: '''1
00:00:01,000 --> 00:00:04,000
An idea is like a virus.
''',
      );

      File? loadedFile;
      SubtitleResult? loadedSub;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnlineSubtitlesSheet(
              videoFile: dummyVideoFile,
              videoTitle: 'Inception',
              service: service,
              onSubtitleLoaded: (file, sub) {
                loadedFile = file;
                loadedSub = sub;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'English'), findsOneWidget);
      expect(find.text('★ 9.2'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'English'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(loadedFile, isNotNull);
      expect(loadedSub?.id, 'sub-inc-1');
      expect(loadedFile!.readAsStringSync(), contains('An idea is like a virus.'));
    });
  });
}
