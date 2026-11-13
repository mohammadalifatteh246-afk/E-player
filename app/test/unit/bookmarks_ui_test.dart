import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/bookmarks/data/bookmark_service.dart';
import 'package:app/features/bookmarks/ui/bookmarks_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookmarksSheet Widget Tests', () {
    late Directory tempDir;
    late BookmarkService bookmarkService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bookmarks_ui_test_');
      bookmarkService = BookmarkService(storageDir: tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('Renders empty state and Add button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarksSheet(
              currentPosition: const Duration(seconds: 30),
              mediaId: 'test-media-1',
              bookmarkService: bookmarkService,
            ),
          ),
        ),
      );

      expect(find.text('CHAPTERS & BOOKMARKS'), findsOneWidget);
      expect(find.text('No Bookmarks Yet'), findsOneWidget);
      expect(find.textContaining('Mark Current Time'), findsOneWidget);
    });

    testWidgets('Renders bookmarks list with timestamp chips and handles seek', (tester) async {
      await bookmarkService.addBookmark(
        mediaId: 'test-media-2',
        position: const Duration(minutes: 3, seconds: 15),
        label: 'Guitar Solo',
      );

      Duration? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarksSheet(
              currentPosition: Duration.zero,
              onSeek: (pos) => seekTarget = pos,
              mediaId: 'test-media-2',
              bookmarkService: bookmarkService,
            ),
          ),
        ),
      );

      expect(find.text('Guitar Solo'), findsOneWidget);
      expect(find.text('03:15'), findsOneWidget);
      expect(find.text('1 Pips'), findsOneWidget);

      await tester.tap(find.text('Guitar Solo'));
      expect(seekTarget, const Duration(minutes: 3, seconds: 15));
    });
  });
}
