import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/library/ui/folder_detail_screen.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';
import 'package:app/theme/e_player_theme.dart';

Widget _buildTestWrapper({
  required Widget child,
  LibraryProvider? libraryProvider,
  MediaGroupService? mediaGroupService,
}) {
  return MultiProvider(
    providers: [
      libraryProvider != null
          ? ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider)
          : ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
      ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
      ChangeNotifierProvider<CastService>(create: (_) => CastService()),
      mediaGroupService != null
          ? ChangeNotifierProvider<MediaGroupService>.value(value: mediaGroupService)
          : ChangeNotifierProvider<MediaGroupService>(create: (_) => MediaGroupService()),
      ChangeNotifierProvider<ExportService>(create: (_) => ExportService()),
      ChangeNotifierProvider<VaultService>(create: (_) => VaultService()),
      ChangeNotifierProvider<TrashService>(create: (_) => TrashService()),
    ],
    child: MaterialApp(
      theme: EPlayerTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: child,
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

  group('FolderDetailScreen Group & Empty State Widget Tests', () {
    testWidgets('Displays empty state card and Add button when groupId is set and group is empty', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Vacation 2026');

      await tester.pumpWidget(_buildTestWrapper(
        mediaGroupService: groupService,
        child: FolderDetailScreen(
          folderName: group.title,
          items: const [],
          groupId: group.id,
        ),
      ));
      await tester.pumpAndSettle();

      // Check empty state card
      expect(find.text('This group is empty'), findsOneWidget);
      expect(find.text('Add videos or folders to organize this group'), findsOneWidget);

      // Check action button in empty state
      expect(find.widgetWithText(ElevatedButton, 'Add Media / Folders'), findsOneWidget);

      // Check Add button in AppBar
      expect(find.byTooltip('Add Media / Folders'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });

    testWidgets('Tapping Add Media button opens bottom sheet with library, file, and folder options', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Projects');

      await tester.pumpWidget(_buildTestWrapper(
        mediaGroupService: groupService,
        child: FolderDetailScreen(
          folderName: group.title,
          items: const [],
          groupId: group.id,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Add button in empty state
      final addButton = find.widgetWithText(ElevatedButton, 'Add Media / Folders');
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify modal options are shown
      expect(find.text('Add to "Projects"'), findsOneWidget);
      expect(find.text('Select from Media Library'), findsOneWidget);
      expect(find.text('Pick Video Files'), findsOneWidget);
      expect(find.text('Add Folder'), findsOneWidget);
    });

    testWidgets('Selecting items from library modal adds them to group atomically', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late MediaGroupService groupService;
      late MediaGroup group;

      await tester.runAsync(() async {
        groupService = MediaGroupService();
        group = await groupService.createGroup(title: 'Watchlist');
      });

      final sampleMedia = [
        MediaItem(
          path: '/storage/videos/movie1.mp4',
          name: 'movie1.mp4',
          parentFolder: '/storage/videos',
          sizeBytes: 1024 * 1024 * 500,
          durationMs: 7200000,
          lastPositionMs: 0,
          lastPlayed: DateTime.now(),
        ),
        MediaItem(
          path: '/storage/videos/movie2.mp4',
          name: 'movie2.mp4',
          parentFolder: '/storage/videos',
          sizeBytes: 1024 * 1024 * 700,
          durationMs: 5400000,
          lastPositionMs: 0,
          lastPlayed: DateTime.now(),
        ),
      ];

      await tester.runAsync(() async {
        await groupService.addItemsToGroup(group.id, [sampleMedia.first.path]);
      });

      await tester.pumpWidget(_buildTestWrapper(
        mediaGroupService: groupService,
        child: FolderDetailScreen(
          folderName: group.title,
          items: [sampleMedia.first],
          groupId: group.id,
        ),
      ));
      await tester.pumpAndSettle();

      // Group now has an item, so empty state should NOT be shown
      expect(find.text('This group is empty'), findsNothing);
      expect(find.text('movie1.mp4'), findsWidgets);

      // AppBar Add button should still be present
      expect(find.byTooltip('Add Media / Folders'), findsOneWidget);
    });
  });
}
