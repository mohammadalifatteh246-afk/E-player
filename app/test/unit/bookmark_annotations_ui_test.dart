import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/bookmarks/data/bookmark_service.dart';
import 'package:app/features/bookmarks/ui/bookmark_edit_dialog.dart';
import 'package:app/features/bookmarks/ui/bookmark_export_dialog.dart';
import 'package:app/features/bookmarks/ui/bookmarks_sheet.dart';

void main() {
  group('Bookmark Annotations & Export UI Tests', () {
    final testBookmark = MediaBookmark(
      id: 'bm_test_1',
      mediaId: 'video_sample',
      position: const Duration(seconds: 42),
      label: 'Initial Theme',
      note: 'Acoustic intro melody.',
      category: 'highlight',
      colorHex: '#19BFFF',
      createdAt: DateTime(2026, 1, 1),
    );

    testWidgets('BookmarkEditDialog renders and updates annotations, category and note', (tester) async {
      MediaBookmark? savedBookmark;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarkEditDialog(
              bookmark: testBookmark,
              onSave: (updated) {
                savedBookmark = updated;
              },
            ),
          ),
        ),
      );

      // Verify initial fields
      expect(find.text('Bookmark Annotation'), findsOneWidget);
      expect(find.text('Initial Theme'), findsOneWidget);
      expect(find.text('Acoustic intro melody.'), findsOneWidget);
      expect(find.text('HIGHLIGHT'), findsOneWidget);

      // Enter new label
      final labelFinder = find.widgetWithText(TextField, 'Initial Theme');
      await tester.enterText(labelFinder, 'Renamed Theme');

      // Select 'IMPORTANT' category chip
      await tester.tap(find.text('IMPORTANT'));
      await tester.pumpAndSettle();

      // Enter new note
      final noteFinder = find.widgetWithText(TextField, 'Acoustic intro melody.');
      await tester.enterText(noteFinder, 'Extended acoustic solo with strings.');

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(savedBookmark, isNotNull);
      expect(savedBookmark!.label, equals('Renamed Theme'));
      expect(savedBookmark!.category, equals('important'));
      expect(savedBookmark!.note, equals('Extended acoustic solo with strings.'));
    });

    testWidgets('BookmarkExportDialog allows switching formats and copying', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarkExportDialog(
              bookmarks: [testBookmark],
              mediaTitle: 'Test Video',
            ),
          ),
        ),
      );

      expect(find.text('Export Bookmarks & Annotations'), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);
      expect(find.text('VLC (XSPF)'), findsOneWidget);
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);

      // Tap 'VLC (XSPF)'
      await tester.tap(find.text('VLC (XSPF)'));
      await tester.pumpAndSettle();

      // Tap 'Copy to Clipboard'
      expect(find.text('Copy to Clipboard'), findsOneWidget);
      await tester.tap(find.text('Copy to Clipboard'));
      await tester.pumpAndSettle();
    });

    testWidgets('BookmarksSheet displays category badges, notes and export action', (tester) async {
      final service = BookmarkService();
      await service.addBookmark(
        mediaId: 'video_sample',
        position: const Duration(seconds: 42),
        label: 'Initial Theme',
        note: 'Acoustic intro melody.',
        category: 'highlight',
        colorHex: '#19BFFF',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarksSheet(
              mediaId: 'video_sample',
              bookmarkService: service,
            ),
          ),
        ),
      );

      // Check header export button and badge
      expect(find.text('CHAPTERS & BOOKMARKS'), findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);

      // Check bookmark list tile details
      expect(find.text('Initial Theme'), findsOneWidget);
      expect(find.text('HIGHLIGHT'), findsOneWidget);
      expect(find.text('Acoustic intro melody.'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);

      // Tap export button to ensure it opens export dialog
      await tester.tap(find.byIcon(Icons.file_upload_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Export Bookmarks & Annotations'), findsOneWidget);
    });
  });
}
