import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/home/ui/home_screen.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/library/ui/folder_detail_screen.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';
import 'package:app/theme/e_player_theme.dart';

class TestLibraryProvider extends ChangeNotifier implements LibraryProvider {
  final List<MediaItem> _files;
  TestLibraryProvider([List<MediaItem>? files]) : _files = files ?? [];

  @override
  List<MediaItem> get allFiles => _files;

  @override
  List<MediaItem> get recentFiles => _files;

  @override
  List<MediaItem> get favorites => const [];

  @override
  Map<String, List<MediaItem>> get groupedFolders => {};

  @override
  GroupMode get groupMode => GroupMode.none;

  @override
  Future<void> refreshLibrary() async {}

  @override
  Future<void> addRecent(String path) async {}

  @override
  List<VideoGroup> groupCustomItems(List<MediaItem> items, [GroupMode? mode]) => const [];

  @override
  List<VideoGroup> get groupedRecentFiles => const [];

  @override
  List<VideoGroup> get groupedAllFiles => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _buildTestApp({
  required Widget child,
  LibraryProvider? libraryProvider,
  MediaGroupService? mediaGroupService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LibraryProvider>(create: (_) => libraryProvider ?? TestLibraryProvider()),
      ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
      ChangeNotifierProvider<CastService>(create: (_) => CastService()),
      ChangeNotifierProvider<MediaGroupService>(create: (_) => mediaGroupService ?? MediaGroupService()),
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Milestone 1 UI & Navigation Empirical Stress Tests', () {
    testWidgets('STRESS 1: Multi-group rapid creation & navigation guarantees 0 items and eliminates fallback sample bug', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 15 sample media files in library
      final sampleFiles = List.generate(
        15,
        (i) => MediaItem(
          path: '/storage/emulated/0/Movies/sample_movie_${i + 1}.mp4',
          name: 'sample_movie_${i + 1}.mp4',
          parentFolder: '/storage/emulated/0/Movies',
          sizeBytes: 1024 * 1024 * (i + 1) * 50,
          durationMs: 7200000,
          lastPositionMs: 0,
          lastPlayed: DateTime.now().subtract(Duration(days: i)),
        ),
      );

      final libraryProvider = TestLibraryProvider(sampleFiles);
      final groupService = MediaGroupService();

      final g1 = await groupService.createGroup(title: 'Empty Sci-Fi Vault');
      final g2 = await groupService.createGroup(title: 'Empty Documentaries');
      final g3 = await groupService.createGroup(title: 'Empty Anime Clips');
      expect(g1.itemPaths, isEmpty);
      expect(g2.itemPaths, isEmpty);
      expect(g3.itemPaths, isEmpty);

      await tester.pumpWidget(_buildTestApp(
        libraryProvider: libraryProvider,
        mediaGroupService: groupService,
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify custom groups rail renders with "0 items" badge
      expect(find.text('Empty Sci-Fi Vault'), findsOneWidget);
      expect(find.text('Empty Documentaries'), findsOneWidget);
      expect(find.text('Empty Anime Clips'), findsOneWidget);
      expect(find.text('0 items'), findsNWidgets(3));

      // Tap first empty group
      await tester.tap(find.text('Empty Anime Clips'));
      await tester.pumpAndSettle();

      // Verify FolderDetailScreen is loaded
      expect(find.byType(FolderDetailScreen), findsOneWidget);

      // Verify 0 items displayed
      expect(find.text('0 media files · 0 B · Sorted by Name'), findsOneWidget);
      expect(find.text('This group is empty'), findsOneWidget);
      expect(find.text('Add videos or folders to organize this group'), findsOneWidget);

      // Verify NONE of the 15 library sample files leaked into this newly created group
      for (final sample in sampleFiles) {
        expect(find.text(sample.name), findsNothing);
      }
    });

    testWidgets('STRESS 2: Empty state card in FolderDetailScreen displays exact copy and tappable Add button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Action Pack');

      await tester.pumpWidget(_buildTestApp(
        mediaGroupService: groupService,
        child: FolderDetailScreen(
          folderName: group.title,
          items: const [],
          groupId: group.id,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert empty state card text
      expect(find.text('This group is empty'), findsOneWidget);
      expect(find.text('Add videos or folders to organize this group'), findsOneWidget);

      // Assert button is present and tappable
      final addButton = find.widgetWithText(ElevatedButton, 'Add Media / Folders');
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Modal options shown
      expect(find.text('Add to "Action Pack"'), findsOneWidget);
      expect(find.text('Select from Media Library'), findsOneWidget);
      expect(find.text('Pick Video Files'), findsOneWidget);
      expect(find.text('Add Folder'), findsOneWidget);
    });

    testWidgets('STRESS 3: AppBar Add button presence when groupId != null and absence when groupId == null', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'My Custom Group');

      // Test 3A: groupId != null (Custom group) -> AppBar Add button MUST be present
      await tester.pumpWidget(_buildTestApp(
        mediaGroupService: groupService,
        child: FolderDetailScreen(
          folderName: group.title,
          items: const [],
          groupId: group.id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add Media / Folders'), findsOneWidget);

      // Test 3B: groupId == null (Regular filesystem folder) -> AppBar Add button MUST be absent
      await tester.pumpWidget(_buildTestApp(
        mediaGroupService: groupService,
        child: const FolderDetailScreen(
          folderName: '/storage/emulated/0/DCIM/Camera',
          items: [],
          groupId: null,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add Media / Folders'), findsNothing);
      expect(find.text('This group is empty'), findsNothing);
      expect(find.text('No media files found in "Camera".'), findsOneWidget);
    });

    testWidgets('STRESS 4: Adding items via library modal immediately updates FolderDetailScreen and persists to disk', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        MediaItem(
          path: '/storage/emulated/0/Videos/clip_a.mp4',
          name: 'clip_a.mp4',
          parentFolder: '/storage/emulated/0/Videos',
          sizeBytes: 1024 * 1024 * 10,
          durationMs: 60000,
          lastPositionMs: 0,
          lastPlayed: DateTime.now(),
        ),
        MediaItem(
          path: '/storage/emulated/0/Videos/clip_b.mp4',
          name: 'clip_b.mp4',
          parentFolder: '/storage/emulated/0/Videos',
          sizeBytes: 1024 * 1024 * 20,
          durationMs: 120000,
          lastPositionMs: 0,
          lastPlayed: DateTime.now(),
        ),
        MediaItem(
          path: '/storage/emulated/0/Videos/clip_c.mp4',
          name: 'clip_c.mp4',
          parentFolder: '/storage/emulated/0/Videos',
          sizeBytes: 1024 * 1024 * 30,
          durationMs: 180000,
          lastPositionMs: 0,
          lastPlayed: DateTime.now(),
        ),
      ];

      final libraryProvider = TestLibraryProvider(items);
      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Top Hits');

      await tester.pumpWidget(_buildTestApp(
        libraryProvider: libraryProvider,
        mediaGroupService: groupService,
        child: FolderDetailScreen(
          folderName: group.title,
          items: const [],
          groupId: group.id,
        ),
      ));
      await tester.pumpAndSettle();

      // Empty initially
      expect(find.text('This group is empty'), findsOneWidget);

      // Open Add Modal
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Media / Folders'));
      await tester.pumpAndSettle();

      // Open Select from Library
      await tester.tap(find.text('Select from Media Library'));
      await tester.pumpAndSettle();

      expect(find.text('Select from Library'), findsOneWidget);
      expect(find.text('clip_a.mp4'), findsOneWidget);
      expect(find.text('clip_b.mp4'), findsOneWidget);
      expect(find.text('clip_c.mp4'), findsOneWidget);

      // Select clip_a and clip_b
      final checkboxes = find.byType(CheckboxListTile);
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Tap "Add Selected (2)"
      await tester.tap(find.widgetWithText(FilledButton, 'Add Selected (2)'));
      await tester.pumpAndSettle();

      // Immediate UI update check:
      // Empty card MUST disappear
      expect(find.text('This group is empty'), findsNothing);
      // Selected clips MUST appear
      expect(find.text('clip_a.mp4'), findsWidgets);
      expect(find.text('clip_b.mp4'), findsWidgets);
      expect(find.text('clip_c.mp4'), findsNothing);

      // Summary text updated
      expect(find.text('2 media files · 30.0 MB · Sorted by Name'), findsOneWidget);

      // Persistence check in service and SharedPreferences
      final activeGroup = groupService.groups.firstWhere((g) => g.id == group.id);
      expect(activeGroup.itemPaths, containsAll([items[0].path, items[1].path]));

      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getString('eplayer_custom_media_groups_v1');
      expect(storedData, contains(items[0].path));
      expect(storedData, contains(items[1].path));
      expect(storedData, isNot(contains(items[2].path)));
    });

    testWidgets('STRESS 5: Atomic deduplication and reactivity on item removal', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Resilience Test');

      const testPath = '/storage/emulated/0/Videos/single_clip.mp4';

      // Deduplication check
      await groupService.addItemsToGroup(group.id, [testPath, testPath, testPath]);
      expect(groupService.groups.first.itemPaths.length, 1);

      await tester.pumpWidget(_buildTestApp(
        mediaGroupService: groupService,
        child: FolderDetailScreen(
          folderName: group.title,
          items: [
            MediaItem(
              path: testPath,
              name: 'single_clip.mp4',
              parentFolder: '/storage/emulated/0/Videos',
              sizeBytes: 1024,
              durationMs: 1000,
              lastPositionMs: 0,
              lastPlayed: DateTime.now(),
            ),
          ],
          groupId: group.id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('single_clip.mp4'), findsWidgets);
      expect(find.text('This group is empty'), findsNothing);

      // Remove item externally: empty state card must immediately reappear
      await groupService.removeItemsFromGroup(group.id, [testPath]);
      await tester.pumpAndSettle();

      expect(find.text('This group is empty'), findsOneWidget);
      expect(find.text('0 media files · 0 B · Sorted by Name'), findsOneWidget);
    });
  });
}
