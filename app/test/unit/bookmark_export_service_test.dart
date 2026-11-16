import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/bookmarks/domain/bookmark_models.dart';
import 'package:app/features/bookmarks/data/bookmark_export_service.dart';

void main() {
  group('BookmarkExportService & Annotations Tests', () {
    final sampleBookmarks = [
      MediaBookmark(
        id: 'bm_1',
        mediaId: 'video_101',
        position: const Duration(seconds: 45),
        label: 'Intro Theme',
        note: 'Main theme acoustic guitar intro begins.',
        category: 'highlight',
        colorHex: '#19BFFF',
        createdAt: DateTime(2026, 1, 1, 10, 0),
      ),
      MediaBookmark(
        id: 'bm_2',
        mediaId: 'video_101',
        position: const Duration(minutes: 5, seconds: 20),
        endPosition: const Duration(minutes: 6, seconds: 0),
        label: 'Important Dialogue',
        note: 'Crucial plot reveal between character A and B.',
        category: 'important',
        colorHex: '#FF5252',
        createdAt: DateTime(2026, 1, 1, 10, 5),
      ),
    ];

    test('MediaBookmark model backwards compatibility and annotation fields', () {
      final bm = sampleBookmarks.first;
      expect(bm.note, equals('Main theme acoustic guitar intro begins.'));
      expect(bm.category, equals('highlight'));
      expect(bm.colorHex, equals('#19BFFF'));

      // Test JSON serialization & deserialization roundtrip
      final jsonMap = bm.toJson();
      final reconstructed = MediaBookmark.fromJson(jsonMap);

      expect(reconstructed.id, equals(bm.id));
      expect(reconstructed.label, equals(bm.label));
      expect(reconstructed.note, equals(bm.note));
      expect(reconstructed.category, equals(bm.category));
      expect(reconstructed.colorHex, equals(bm.colorHex));
      expect(reconstructed.position, equals(bm.position));

      // Test backwards compatibility with legacy JSON missing annotation fields
      final legacyJson = {
        'id': 'legacy_1',
        'mediaId': 'video_101',
        'timestampMs': 30000,
        'label': 'Legacy Bookmark',
        'createdAt': '2026-01-01T00:00:00.000',
      };
      final legacyBm = MediaBookmark.fromJson(legacyJson);
      expect(legacyBm.label, equals('Legacy Bookmark'));
      expect(legacyBm.note, isNull);
      expect(legacyBm.category, equals('general'));
      expect(legacyBm.colorHex, isNull);
    });

    test('Export to JSON format contains full structured annotations', () {
      final jsonOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.json,
        mediaTitle: 'Sample Media',
      );

      expect(jsonOutput, contains('"mediaTitle": "Sample Media"'));
      expect(jsonOutput, contains('"label": "Intro Theme"'));
      expect(jsonOutput, contains('"note": "Main theme acoustic guitar intro begins."'));
      expect(jsonOutput, contains('"category": "highlight"'));
    });

    test('Export to Markdown format produces readable notes with timestamps', () {
      final mdOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.markdown,
        mediaTitle: 'Test Movie',
      );

      expect(mdOutput, contains('# Bookmarks & Annotations: Test Movie'));
      expect(mdOutput, contains('**[00:45]** Intro Theme'));
      expect(mdOutput, contains('Main theme acoustic guitar intro begins.'));
      expect(mdOutput, contains('**[05:20 - 06:00]** Important Dialogue'));
    });

    test('Export to CSV format contains header and comma-separated records', () {
      final csvOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.csv,
      );

      final lines = csvOutput.trim().split('\n');
      expect(lines.first.trim(), equals('TimestampMs,Time,EndTime,Label,Category,Notes'));
      expect(lines.length, equals(3));
      expect(lines[1], contains('45000,00:45,,Intro Theme,highlight'));
    });

    test('Export to VLC XSPF Playlist format creates valid VLC bookmark nodes', () {
      final xspfOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.vlcXspf,
        mediaTitle: 'Sample Clip',
      );

      expect(xspfOutput, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xspfOutput, contains('<playlist version="1" xmlns="http://xspf.org/ns/0/"'));
      expect(xspfOutput, contains('http://www.videolan.org/vlc/playlist/0'));
      expect(xspfOutput, contains('<vlc:node title="bookmarks">'));
      expect(xspfOutput, contains('time="45"'));
      expect(xspfOutput, contains('name="Intro Theme"'));
      expect(xspfOutput, contains('description="Main theme acoustic guitar intro begins."'));
    });

    test('Export to FFmpeg chapters format creates valid FFMETADATA chapters', () {
      final ffOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.ffmpegChapters,
      );

      expect(ffOutput, contains(';FFMETADATA1'));
      expect(ffOutput, contains('[CHAPTER]'));
      expect(ffOutput, contains('TIMEBASE=1/1000'));
      expect(ffOutput, contains('START=45000'));
      expect(ffOutput, contains('title=Intro Theme'));
    });

    test('Export to SRT subtitle format generates timestamped annotation cues', () {
      final srtOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.srt,
      );

      expect(srtOutput, contains('1\n00:00:45,000 -->'));
      expect(srtOutput, contains('[Intro Theme]'));
      expect(srtOutput, contains('Main theme acoustic guitar intro begins.'));
    });

    test('Import from JSON restores all annotations accurately', () {
      final jsonOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.json,
      );

      final imported = BookmarkExportService.importFromString(
        jsonOutput,
        mediaId: 'new_video_id',
      );

      expect(imported.length, equals(2));
      expect(imported[0].mediaId, equals('new_video_id'));
      expect(imported[0].label, equals('Intro Theme'));
      expect(imported[0].note, equals('Main theme acoustic guitar intro begins.'));
      expect(imported[0].category, equals('highlight'));
      expect(imported[1].endPosition, equals(const Duration(minutes: 6)));
    });

    test('Import from CSV format parses tabular bookmarks cleanly', () {
      final csvOutput = BookmarkExportService.exportToString(
        sampleBookmarks,
        BookmarkExportFormat.csv,
      );

      final imported = BookmarkExportService.importFromString(
        csvOutput,
        mediaId: 'video_csv',
      );

      expect(imported.length, equals(2));
      expect(imported[0].label, equals('Intro Theme'));
      expect(imported[0].category, equals('highlight'));
      expect(imported[1].label, equals('Important Dialogue'));
    });
  });
}
