import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/library/ui/widgets/video_group_card.dart';
import 'package:app/features/library/ui/folder_detail_screen.dart';
import 'package:app/theme/e_player_theme.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';

Widget _buildTestWrapper({
  required Widget child,
  LibraryProvider? libraryProvider,
  VaultService? vaultService,
  TrashService? trashService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LibraryProvider>(create: (_) => libraryProvider ?? LibraryProvider()),
      ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
      ChangeNotifierProvider<CastService>(create: (_) => CastService()),
      ChangeNotifierProvider<MediaGroupService>(create: (_) => MediaGroupService()),
      ChangeNotifierProvider<ExportService>(create: (_) => ExportService()),
      ChangeNotifierProvider<VaultService>(create: (_) => vaultService ?? VaultService()),
      ChangeNotifierProvider<TrashService>(create: (_) => trashService ?? TrashService()),
    ],
    child: MaterialApp(
      theme: EPlayerTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VideoGroupCard UI Tests', () {
    final now = DateTime.now();
    final items = [
      MediaItem(
        path: '/storage/media/Dune Part 1.mp4',
        name: 'Dune Part 1.mp4',
        parentFolder: '/storage/media',
        sizeBytes: 1024 * 1024 * 1024,
        durationMs: 7200000,
        lastPlayed: now,
      ),
      MediaItem(
        path: '/storage/media/Dune Part 2.mp4',
        name: 'Dune Part 2.mp4',
        parentFolder: '/storage/media',
        sizeBytes: 1024 * 1024 * 1500,
        durationMs: 8400000,
        lastPlayed: now,
      ),
    ];

    final group = VideoGroup(
      id: 'dune',
      title: 'Dune',
      subtitle: '2 videos • /storage/media',
      folderPath: '/storage/media',
      mode: GroupMode.byName,
      items: items,
      totalDurationMs: 15600000,
      totalSizeBytes: 1024 * 1024 * 2524,
      latestDate: now,
    );

    testWidgets('Renders group card header with title, badges and metadata', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          child: VideoGroupCard(group: group, isGridView: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('2 Videos'), findsOneWidget);
      expect(find.text('COLLECTION'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('Expands when tapped to reveal child episode items and collapses on second tap', (tester) async {
      bool? expansionState;

      await tester.pumpWidget(
        _buildTestWrapper(
          child: VideoGroupCard(
            group: group,
            isGridView: true,
            initiallyExpanded: false,
            onExpansionChanged: (val) => expansionState = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(expansionState, isNull);

      // Verify child items are NOT mounted in the widget tree when collapsed (UI memory efficiency)
      expect(find.text('Dune Part 1.mp4'), findsNothing);

      // Tap card header to expand
      await tester.tap(find.text('Dune'));
      await tester.pumpAndSettle();

      expect(expansionState, isTrue);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Dune Part 1.mp4'), findsOneWidget);
      expect(find.text('Dune Part 2.mp4'), findsOneWidget);

      // Tap card header again to collapse
      await tester.tap(find.text('Dune'));
      await tester.pumpAndSettle();

      expect(expansionState, isFalse);
      expect(find.text('Dune Part 1.mp4'), findsNothing);
    });
  });

  group('FolderDetailScreen Grouping Controls Tests', () {
    final now = DateTime.now();
    final folderItems = [
      MediaItem(
        path: '/storage/shows/Breaking Bad S01E01.mp4',
        name: 'Breaking Bad S01E01.mp4',
        parentFolder: '/storage/shows',
        sizeBytes: 500000000,
        durationMs: 3000000,
        lastPlayed: now,
      ),
      MediaItem(
        path: '/storage/shows/Breaking Bad S01E02.mp4',
        name: 'Breaking Bad S01E02.mp4',
        parentFolder: '/storage/shows',
        sizeBytes: 500000000,
        durationMs: 3000000,
        lastPlayed: now,
      ),
      MediaItem(
        path: '/storage/shows/Movie.mp4',
        name: 'Movie.mp4',
        parentFolder: '/storage/shows',
        sizeBytes: 800000000,
        durationMs: 6000000,
        lastPlayed: now,
      ),
    ];

    testWidgets('Allows toggling grouping mode via AppBar popup menu', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          child: FolderDetailScreen(
            folderName: 'shows',
            items: folderItems,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the grouping popup menu button by tooltip
      final groupButton = find.byTooltip('Group Media (None)');
      expect(groupButton, findsOneWidget);

      // Tap popup menu button
      await tester.tap(groupButton);
      await tester.pumpAndSettle();

      // Expect options matching GroupMode enum labels
      expect(find.text('None'), findsOneWidget);
      expect(find.text('By Folder'), findsOneWidget);
      expect(find.text('By Name'), findsOneWidget);

      // Select 'By Name'
      await tester.tap(find.text('By Name'));
      await tester.pumpAndSettle();

      // Should now render the clustered group for Breaking Bad
      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(find.text('2 Videos'), findsOneWidget);

      // Drain sqflite idle connection timeout timer
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
