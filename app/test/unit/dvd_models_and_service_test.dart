import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:app/features/dvd/domain/dvd_models.dart';
import 'package:app/features/dvd/data/dvd_navigator_service.dart';

void main() {
  group('DVD & ISO Domain Models', () {
    test('DvdChapter formats time strings accurately', () {
      const ch1 = DvdChapter(
        chapterIndex: 1,
        titleNumber: 1,
        startOffset: Duration(minutes: 5, seconds: 30),
        label: 'Chapter 1',
      );
      expect(ch1.formattedTime, '05:30');

      const ch2 = DvdChapter(
        chapterIndex: 2,
        titleNumber: 1,
        startOffset: Duration(hours: 1, minutes: 24, seconds: 5),
        label: 'Chapter 2',
      );
      expect(ch2.formattedTime, '1:24:05');
    });

    test('DvdTitle formattedDuration handles hours and minutes', () {
      const t1 = DvdTitle(
        titleIndex: 1,
        duration: Duration(hours: 2, minutes: 15),
        vobFiles: ['VTS_01_1.VOB'],
        chapters: [],
      );
      expect(t1.formattedDuration, '2h 15m');

      const t2 = DvdTitle(
        titleIndex: 2,
        duration: Duration(minutes: 18, seconds: 40),
        vobFiles: ['VTS_02_1.VOB'],
        chapters: [],
      );
      expect(t2.formattedDuration, '18m 40s');
    });

    test('DvdMediaInfo and nested models serialize and deserialize safely', () {
      final info = DvdMediaInfo(
        sourcePath: '/movies/interstellar/VIDEO_TS',
        sourceType: DvdSourceType.videoTsFolder,
        volumeLabel: 'INTERSTELLAR_DISC_1',
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
                label: 'Chapter 1',
              ),
              DvdChapter(
                chapterIndex: 2,
                titleNumber: 1,
                startOffset: Duration(minutes: 15),
                label: 'Chapter 2',
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
        ],
        selectedTitleIndex: 1,
        selectedChapterIndex: 2,
      );

      final json = info.toJson();
      expect(json['volumeLabel'], 'INTERSTELLAR_DISC_1');
      expect(json['sourceType'], 'videoTsFolder');
      expect(json['selectedChapterIndex'], 2);

      final restored = DvdMediaInfo.fromJson(json);
      expect(restored.volumeLabel, 'INTERSTELLAR_DISC_1');
      expect(restored.sourceType, DvdSourceType.videoTsFolder);
      expect(restored.titles.length, 1);
      expect(restored.titles.first.isMainFeature, isTrue);
      expect(restored.currentChapter?.label, 'Chapter 2');
      expect(restored.formattedTotalDuration, '2:49:00');
    });
  });

  group('DvdNavigatorService Detection & Parsing', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dvd_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('isDvdSource detects .iso and VIDEO_TS directories accurately', () {
      expect(DvdNavigatorService.isDvdSource('movie.iso'), isTrue);
      expect(DvdNavigatorService.isDvdSource('DISC.ISO'), isTrue);
      expect(DvdNavigatorService.isDvdSource('sample.mp4'), isFalse);

      final videoTsDir = Directory(p.join(tempDir.path, 'VIDEO_TS'))..createSync();
      expect(DvdNavigatorService.isDvdSource(videoTsDir.path), isTrue);

      final rootWithVideoTs = Directory(p.join(tempDir.path, 'MyMovie'))..createSync();
      Directory(p.join(rootWithVideoTs.path, 'VIDEO_TS')).createSync();
      expect(DvdNavigatorService.isDvdSource(rootWithVideoTs.path), isTrue);
    });

    test('parseIsoVolumeLabel extracts ISO 9660 PVD Sector 16 volume identifier', () async {
      final isoFile = File(p.join(tempDir.path, 'mock_disc.iso'));
      const pvdOffset = 16 * 2048; // 32768
      final bytes = Uint8List(pvdOffset + 2048);

      // PVD Type = 1, ID = "CD001"
      bytes[pvdOffset] = 1;
      bytes.setRange(pvdOffset + 1, pvdOffset + 6, 'CD001'.codeUnits);

      // Volume Label at offset 40..71: "GLADIATOR_SPECIAL_EDITION"
      const label = 'GLADIATOR_SPECIAL_EDITION';
      bytes.setRange(pvdOffset + 40, pvdOffset + 40 + label.length, label.codeUnits);

      await isoFile.writeAsBytes(bytes);

      final parsed = await DvdNavigatorService.parseIsoVolumeLabel(isoFile);
      expect(parsed, 'GLADIATOR_SPECIAL_EDITION');
    });

    test('generateChapters creates evenly distributed and contiguous chapter offsets', () {
      const duration = Duration(minutes: 60);
      final chapters = DvdNavigatorService.generateChapters(
        titleNumber: 1,
        titleDuration: duration,
        chapterCount: 4,
      );

      expect(chapters.length, 4);
      expect(chapters[0].chapterIndex, 1);
      expect(chapters[0].startOffset, Duration.zero);
      expect(chapters[1].chapterIndex, 2);
      expect(chapters[1].startOffset, const Duration(minutes: 15));
      expect(chapters[2].startOffset, const Duration(minutes: 30));
      expect(chapters[3].startOffset, const Duration(minutes: 45));
    });

    test('inspectSource parses multi-title VIDEO_TS structure and marks longest as Main Feature', () async {
      final vtsDir = Directory(p.join(tempDir.path, 'VIDEO_TS'))..createSync();

      // Title 1: 3 VOB files (Total ~3MB)
      final vob1 = File(p.join(vtsDir.path, 'VTS_01_1.VOB'))..writeAsBytesSync(List.filled(1024 * 1024, 0));
      final vob2 = File(p.join(vtsDir.path, 'VTS_01_2.VOB'))..writeAsBytesSync(List.filled(1024 * 1024, 0));
      final vob3 = File(p.join(vtsDir.path, 'VTS_01_3.VOB'))..writeAsBytesSync(List.filled(1024 * 1024, 0));

      // Title 2: 1 VOB file (Total ~100KB)
      final vobExtra = File(p.join(vtsDir.path, 'VTS_02_1.VOB'))..writeAsBytesSync(List.filled(100 * 1024, 0));

      // Menu VOBs should be ignored from title stream list
      File(p.join(vtsDir.path, 'VTS_01_0.VOB')).writeAsBytesSync(List.filled(1024, 0));

      final dvdMedia = await DvdNavigatorService.inspectSource(tempDir.path);
      expect(dvdMedia, isNotNull);
      expect(dvdMedia!.sourceType, DvdSourceType.videoTsFolder);
      expect(dvdMedia.titles.length, 2);

      // Title 1 should be Main Feature (has more data & longer duration)
      final mainTitle = dvdMedia.titles.firstWhere((t) => t.titleIndex == 1);
      expect(mainTitle.isMainFeature, isTrue);
      expect(mainTitle.vobFiles.length, 3);
      expect(mainTitle.vobFiles[0], vob1.path);
      expect(mainTitle.vobFiles[1], vob2.path);
      expect(mainTitle.vobFiles[2], vob3.path);

      // Title 2 is extra
      final extraTitle = dvdMedia.titles.firstWhere((t) => t.titleIndex == 2);
      expect(extraTitle.isMainFeature, isFalse);
      expect(extraTitle.vobFiles.length, 1);
      expect(extraTitle.vobFiles[0], vobExtra.path);

      // Default selection is Main Feature
      expect(dvdMedia.selectedTitleIndex, 1);
      expect(dvdMedia.currentTitle?.titleIndex, 1);
    });
  });
}
