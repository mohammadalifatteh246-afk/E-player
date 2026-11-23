import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/dvd/domain/dvd_models.dart';
import 'package:app/features/dvd/ui/dvd_navigator_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DvdNavigatorSheet Widget Tests (VLC dvdnav.c Parity)', () {
    late DvdMediaInfo mockDvdInfo;

    setUp(() {
      mockDvdInfo = DvdMediaInfo(
        sourcePath: '/path/to/movie/VIDEO_TS',
        sourceType: DvdSourceType.videoTsFolder,
        volumeLabel: 'INTERSTELLAR_SPECIAL_EDITION',
        titles: [
          const DvdTitle(
            titleIndex: 1,
            duration: Duration(hours: 2, minutes: 49),
            vobFiles: ['VTS_01_1.VOB', 'VTS_01_2.VOB'],
            chapters: [
              DvdChapter(
                chapterIndex: 1,
                titleNumber: 1,
                startOffset: Duration.zero,
                label: 'Chapter 1 - Earth Dust',
              ),
              DvdChapter(
                chapterIndex: 2,
                titleNumber: 1,
                startOffset: Duration(minutes: 42, seconds: 15),
                label: 'Chapter 2 - Gargantua Launch',
              ),
            ],
            audioTracks: [
              DvdAudioTrackInfo(
                streamId: 1,
                format: 'AC3',
                channels: 6,
                languageCode: 'en',
                label: 'English AC3 5.1',
              ),
            ],
            subtitleTracks: [
              DvdSubtitleTrackInfo(
                streamId: 1,
                languageCode: 'en',
                label: 'English [VobSub]',
              ),
            ],
            isMainFeature: true,
          ),
          const DvdTitle(
            titleIndex: 2,
            duration: Duration(minutes: 18),
            vobFiles: ['VTS_02_1.VOB'],
            chapters: [
              DvdChapter(
                chapterIndex: 1,
                titleNumber: 2,
                startOffset: Duration.zero,
                label: 'Chapter 1 - Behind The Scenes',
              ),
            ],
            isMainFeature: false,
          ),
        ],
        selectedTitleIndex: 1,
        selectedChapterIndex: 1,
      );
    });

    testWidgets('1. Displays DVD header, titles, audio/sub streams and chapters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DvdNavigatorSheet(
              dvdInfo: mockDvdInfo,
              onSelectTitle: (_) {},
              onSeekToChapter: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INTERSTELLAR_SPECIAL_EDITION'), findsOneWidget);
      expect(find.text('VIDEO_TS Folder'), findsOneWidget);
      expect(find.text('MAIN FEATURE'), findsOneWidget);

      // Title chips
      expect(find.byKey(const Key('dvd_title_chip_1')), findsOneWidget);
      expect(find.byKey(const Key('dvd_title_chip_2')), findsOneWidget);

      // Streams
      expect(find.text('English AC3 5.1'), findsOneWidget);
      expect(find.text('English [VobSub]'), findsOneWidget);

      // Chapters
      expect(find.text('Chapter 1 - Earth Dust'), findsOneWidget);
      expect(find.text('Chapter 2 - Gargantua Launch'), findsOneWidget);
    });

    testWidgets('2. Selecting a different title calls onSelectTitle callback', (tester) async {
      DvdTitle? selectedTitle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DvdNavigatorSheet(
              dvdInfo: mockDvdInfo,
              onSelectTitle: (title) => selectedTitle = title,
              onSeekToChapter: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title2Chip = find.byKey(const Key('dvd_title_chip_2'));
      expect(title2Chip, findsOneWidget);

      await tester.tap(title2Chip);
      await tester.pumpAndSettle();

      expect(selectedTitle, isNotNull);
      expect(selectedTitle!.titleIndex, 2);
      expect(selectedTitle!.isMainFeature, isFalse);
    });

    testWidgets('3. Tapping a chapter tile calls onSeekToChapter callback', (tester) async {
      DvdChapter? seekChapter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DvdNavigatorSheet(
              dvdInfo: mockDvdInfo,
              onSelectTitle: (_) {},
              onSeekToChapter: (chapter) => seekChapter = chapter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ch2Tile = find.byKey(const Key('dvd_chapter_tile_2'));
      expect(ch2Tile, findsOneWidget);

      await tester.tap(ch2Tile);
      await tester.pumpAndSettle();

      expect(seekChapter, isNotNull);
      expect(seekChapter!.chapterIndex, 2);
      expect(seekChapter!.startOffset, const Duration(minutes: 42, seconds: 15));
      expect(seekChapter!.label, 'Chapter 2 - Gargantua Launch');
    });
  });
}
