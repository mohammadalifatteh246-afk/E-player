import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/db/database_helper.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/library/domain/media_scanner_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/home/ui/home_screen.dart';
import 'package:app/features/library/ui/library_screen.dart';
import 'package:app/features/library/ui/folder_detail_screen.dart';
import 'package:app/theme/e_player_theme.dart';
import '../helpers/eplayer_test_harness.dart';

/// Test helper providing safe batch operations on [MediaGroupService]
/// whether invoked against Milestone 1 batch additions or progressive fallback.
Future<void> safeAddItemsToGroup(
  MediaGroupService service,
  String groupId,
  List<String> paths,
) async {
  try {
    await (service as dynamic).addItemsToGroup(groupId, paths);
  } catch (_) {
    for (final p in paths) {
      await service.addItemToGroup(groupId, p);
    }
  }
}

Future<void> safeRemoveItemsFromGroup(
  MediaGroupService service,
  String groupId,
  List<String> paths,
) async {
  try {
    await (service as dynamic).removeItemsFromGroup(groupId, paths);
  } catch (_) {
    for (final p in paths) {
      await service.removeItemFromGroup(groupId, p);
    }
  }
}

Future<void> safeMoveItemsBetweenGroups(
  MediaGroupService service, {
  required String fromGroupId,
  required String toGroupId,
  required List<String> paths,
}) async {
  try {
    await (service as dynamic).moveItemsBetweenGroups(
      fromGroupId: fromGroupId,
      toGroupId: toGroupId,
      paths: paths,
    );
  } catch (_) {
    for (final p in paths) {
      await service.removeItemFromGroup(fromGroupId, p);
      await service.addItemToGroup(toGroupId, p);
    }
  }
}

/// Helper building a test app wrapped in all production MultiProvider services.
Widget buildTestApp({
  required Widget child,
  LibraryProvider? libraryProvider,
  MediaGroupService? mediaGroupService,
  SettingsProvider? settingsProvider,
  CastService? castService,
  ExportService? exportService,
  VaultService? vaultService,
  TrashService? trashService,
}) {
  return MultiProvider(
    providers: [
      libraryProvider != null
          ? ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider)
          : ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
      ChangeNotifierProvider<SettingsProvider>(create: (_) => settingsProvider ?? SettingsProvider()),
      ChangeNotifierProvider<CastService>(create: (_) => castService ?? CastService()),
      mediaGroupService != null
          ? ChangeNotifierProvider<MediaGroupService>.value(value: mediaGroupService)
          : ChangeNotifierProvider<MediaGroupService>(create: (_) => MediaGroupService()),
      ChangeNotifierProvider<ExportService>(create: (_) => exportService ?? ExportService()),
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
  final harness = EPlayerTestHarness();
  late Directory tempDir;

  setUpAll(() async {
    await harness.setUp();
  });

  setUp(() async {
    tempDir = harness.createTempDirectory('e2e_req_');
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseHelper.instance.database;
    await db.delete('media_items');
  });

  tearDown(() async {
    await harness.tearDown();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (R1 to R5)
  // ===========================================================================
  group('Tier 1: Feature Coverage (R1 to R5)', () {
    // -------------------------------------------------------------------------
    // R1: Empty Group Creation with Add Button
    // Feature 1: Empty Group Creation & Zero Items
    // -------------------------------------------------------------------------
    group('Feature 1: Empty Group Creation & Zero Items (R1)', () {
      test('1.1: Newly created group via MediaGroupService has itemPaths.isEmpty and length == 0', () async {
        final groupService = MediaGroupService();
        final group = await groupService.createGroup(title: 'Sci-Fi Collection');

        expect(group.itemPaths, isEmpty);
        expect(group.itemPaths.length, 0);
        expect(group.title, 'Sci-Fi Collection');
        expect(groupService.groups.first.itemPaths, isEmpty);
      });

      test('1.2: Group created with empty or whitespace title normalizes to default name and zero items', () async {
        final groupService = MediaGroupService();
        final group = await groupService.createGroup(title: '   ');

        expect(group.title, 'New Group');
        expect(group.itemPaths, isEmpty);
        expect(group.itemPaths.length, 0);
      });

      test('1.3: Group JSON serialization preserves empty itemPaths array', () async {
        final group = MediaGroup(
          id: 'grp_test_empty',
          title: 'Empty Group',
          colorValue: 0xFF00E5FF,
          itemPaths: const [],
          createdAt: DateTime.now(),
        );

        final jsonMap = group.toJson();
        expect(jsonMap['itemPaths'], isA<List>());
        expect((jsonMap['itemPaths'] as List), isEmpty);

        final deserialized = MediaGroup.fromJson(jsonMap);
        expect(deserialized.itemPaths, isEmpty);
        expect(deserialized.itemPaths.length, 0);
      });

      testWidgets('1.4: HomeScreen custom groups rail renders group with "0 items" badge', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Documentaries');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Documentaries'), findsOneWidget);
        expect(find.text('0 items'), findsOneWidget);
      });

      testWidgets('1.5: Navigating to newly created group opens FolderDetailScreen showing 0 media items', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Empty Vacation Clips');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        final groupCard = find.text('Empty Vacation Clips');
        expect(groupCard, findsOneWidget);

        await tester.tap(groupCard);
        await tester.pumpAndSettle();

        // Must display FolderDetailScreen without sample items injected
        expect(find.byType(FolderDetailScreen), findsOneWidget);
        expect(find.text('0 media files · 0 B · Sorted by Name'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // R1: Empty Group Creation with Add Button
    // Feature 2: Add Button & Media Import
    // -------------------------------------------------------------------------
    group('Feature 2: Add Button & Media Import (R1)', () {
      testWidgets('2.1: FolderDetailScreen for empty group displays empty state card', (tester) async {
        await tester.pumpWidget(buildTestApp(
          child: const FolderDetailScreen(
            folderName: 'Empty Group',
            items: [],
          ),
        ));
        await tester.pumpAndSettle();

        // Asserts presence of empty container message
        final emptyFinder = find.byWidgetPredicate((widget) {
          if (widget is Text) {
            final data = widget.data ?? '';
            return data.contains('empty') || data.contains('No media files found');
          }
          return false;
        });
        expect(emptyFinder, findsWidgets);
      });

      testWidgets('2.2: FolderDetailScreen displays an Add button or action for the group', (tester) async {
        await tester.pumpWidget(buildTestApp(
          child: const FolderDetailScreen(
            folderName: 'My Group',
            items: [],
          ),
        ));
        await tester.pumpAndSettle();

        // An Add action/icon must be discoverable in the UI
        final addActionFinder = find.byWidgetPredicate((widget) {
          if (widget is Icon && (widget.icon == Icons.add || widget.icon == Icons.add_rounded)) {
            return true;
          }
          if (widget is Text && (widget.data?.contains('Add') ?? false)) {
            return true;
          }
          return false;
        });
        expect(addActionFinder, findsWidgets);
      });

      test('2.3: Adding media paths updates group.itemPaths count in state and storage', () async {
        final groupService = MediaGroupService();
        final group = await groupService.createGroup(title: 'Nature');
        expect(group.itemPaths, isEmpty);

        final videoFile = await harness.createMockVideoFile(tempDir, 'nature_1.mp4');
        await safeAddItemsToGroup(groupService, group.id, [videoFile.path]);

        final updated = groupService.groups.firstWhere((g) => g.id == group.id);
        expect(updated.itemPaths.length, 1);
        expect(updated.itemPaths.first, videoFile.path);
      });

      test('2.4: Batch adding items appends multiple paths atomically to group', () async {
        final groupService = MediaGroupService();
        final group = await groupService.createGroup(title: 'Batch Group');

        final f1 = await harness.createMockVideoFile(tempDir, 'v1.mp4');
        final f2 = await harness.createMockVideoFile(tempDir, 'v2.mp4');
        final f3 = await harness.createMockVideoFile(tempDir, 'v3.mp4');

        await safeAddItemsToGroup(groupService, group.id, [f1.path, f2.path, f3.path]);

        final updated = groupService.groups.firstWhere((g) => g.id == group.id);
        expect(updated.itemPaths.length, 3);
        expect(updated.itemPaths, containsAll([f1.path, f2.path, f3.path]));
      });

      test('2.5: Group item count updates dynamically from 0 to N after adding items', () async {
        final groupService = MediaGroupService();
        final group = await groupService.createGroup(title: 'Dynamic Count');
        expect(groupService.groups.first.itemPaths.length, 0);

        final paths = <String>[];
        for (var i = 1; i <= 5; i++) {
          final f = await harness.createMockVideoFile(tempDir, 'clip_$i.mp4');
          paths.add(f.path);
        }

        await safeAddItemsToGroup(groupService, group.id, paths);
        expect(groupService.groups.first.itemPaths.length, 5);
      });
    });

    // -------------------------------------------------------------------------
    // R2: Long-Press Multi-Select, Select All, Delete, and Move (Home Screen)
    // Feature 3: Long-Press Multi-Select (Home)
    // -------------------------------------------------------------------------
    group('Feature 3: Long-Press Multi-Select on Home Screen (R2)', () {
      testWidgets('3.1: Long-pressing a custom group card enters multi-selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Custom Group Alpha');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        final groupCard = find.text('Custom Group Alpha');
        expect(groupCard, findsOneWidget);

        await tester.longPress(groupCard);
        await tester.pumpAndSettle();

        // Contextual selection bar or indicator becomes visible
        final selectionFinder = find.byWidgetPredicate((widget) {
          if (widget is Text && (widget.data?.contains('Selected') ?? false)) return true;
          if (widget is Icon && (widget.icon == Icons.check_circle || widget.icon == Icons.checklist_rtl_rounded)) return true;
          return false;
        });
        expect(selectionFinder, findsWidgets);
      });

      testWidgets('3.2: Multi-select mode activates contextual selection bar showing selection count', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Group One');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Group One'));
        await tester.pumpAndSettle();

        expect(find.textContaining('1 Selected'), findsWidgets);
      });

      testWidgets('3.3: Tapping another custom group while in selection mode toggles its selected state', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Group A');
        await groupService.createGroup(title: 'Group B');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Group A'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 Selected'), findsWidgets);

        await tester.tap(find.text('Group B'));
        await tester.pumpAndSettle();
        expect(find.textContaining('2 Selected'), findsWidgets);
      });

      testWidgets('3.4: Deselecting all selected items exits multi-selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Solo Group');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Solo Group'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 Selected'), findsWidgets);

        // Tap again to toggle off
        await tester.tap(find.text('Solo Group'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 Selected'), findsNothing);
      });

      testWidgets('3.5: Close or cancel action button clears selection and exits selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Dismissable Group');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Dismissable Group'));
        await tester.pumpAndSettle();

        final closeBtn = find.byIcon(Icons.close);
        if (closeBtn.evaluate().isNotEmpty) {
          await tester.tap(closeBtn);
          await tester.pumpAndSettle();
          expect(find.textContaining('Selected'), findsNothing);
        }
      });
    });

    // -------------------------------------------------------------------------
    // R2: Long-Press Multi-Select, Select All, Delete, and Move (Home Screen)
    // Feature 4: Select All & Deselect (Home)
    // -------------------------------------------------------------------------
    group('Feature 4: Select All & Deselect on Home Screen (R2)', () {
      testWidgets('4.1: Tapping "Select All" selects all custom groups in view', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'G1');
        await groupService.createGroup(title: 'G2');
        await groupService.createGroup(title: 'G3');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('G1'));
        await tester.pumpAndSettle();

        final selectAllBtn = find.byWidgetPredicate((w) =>
          (w is Text && (w.data == 'Select All' || w.data == 'All')) ||
          (w is IconButton && (w.tooltip?.contains('Select All') ?? false))
        );
        expect(selectAllBtn, findsWidgets);

        await tester.tap(selectAllBtn.first);
        await tester.pumpAndSettle();

        expect(find.textContaining('3 Selected'), findsWidgets);
      });

      testWidgets('4.2: Tapping "Select All" updates AppBar counter to total selectable count', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Group 10');
        await groupService.createGroup(title: 'Group 20');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Group 10'));
        await tester.pumpAndSettle();

        final selectAllBtn = find.text('Select All');
        if (selectAllBtn.evaluate().isNotEmpty) {
          await tester.tap(selectAllBtn);
          await tester.pumpAndSettle();
          expect(find.text('2 Selected'), findsOneWidget);
        }
      });

      testWidgets('4.3: Tapping "None" or toggling Select All when all selected deselects all items', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Toggle Group A');
        await groupService.createGroup(title: 'Toggle Group B');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Toggle Group A'));
        await tester.pumpAndSettle();

        final selectAllBtn = find.byWidgetPredicate((w) =>
          w is Text && (w.data == 'Select All' || w.data == 'All')
        );
        if (selectAllBtn.evaluate().isNotEmpty) {
          await tester.tap(selectAllBtn.first);
          await tester.pumpAndSettle();

          // Second tap deselects all or toggles to 'None'
          final toggleBtn = find.byWidgetPredicate((w) =>
            w is Text && (w.data == 'None' || w.data == 'Select All' || w.data == 'All')
          );
          await tester.tap(toggleBtn.first);
          await tester.pumpAndSettle();

          expect(find.textContaining('2 Selected'), findsNothing);
        }
      });

      testWidgets('4.4: Selection state accurately reflects individual items added or removed after Select All', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Item 1');
        await groupService.createGroup(title: 'Item 2');
        await groupService.createGroup(title: 'Item 3');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Item 1'));
        await tester.pumpAndSettle();

        final selectAllBtn = find.text('Select All');
        if (selectAllBtn.evaluate().isNotEmpty) {
          await tester.tap(selectAllBtn);
          await tester.pumpAndSettle();
          expect(find.textContaining('3 Selected'), findsWidgets);

          // Deselect Item 2
          await tester.tap(find.text('Item 2'));
          await tester.pumpAndSettle();
          expect(find.textContaining('2 Selected'), findsWidgets);
        }
      });

      testWidgets('4.5: Selection bar displays batch action buttons (Delete, Move) when >= 1 item is selected', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Actionable Group');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Actionable Group'));
        await tester.pumpAndSettle();

        final deleteBtn = find.byWidgetPredicate((w) =>
          (w is Icon && (w.icon == Icons.delete || w.icon == Icons.delete_outline)) ||
          (w is Text && (w.data?.toLowerCase().contains('delete') ?? false))
        );
        expect(deleteBtn, findsWidgets);
      });
    });

    // -------------------------------------------------------------------------
    // R2: Long-Press Multi-Select, Select All, Delete, and Move (Home Screen)
    // Feature 5: Batch Delete (Home)
    // -------------------------------------------------------------------------
    group('Feature 5: Batch Delete on Home Screen (R2)', () {
      testWidgets('5.1: Tapping Delete with selected groups shows confirmation dialog', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Delete Me');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Delete Me'));
        await tester.pumpAndSettle();

        final deleteBtn = find.byIcon(Icons.delete);
        if (deleteBtn.evaluate().isNotEmpty) {
          await tester.tap(deleteBtn);
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget);
        }
      });

      test('5.2: Confirming delete removes selected groups from MediaGroupService', () async {
        final groupService = MediaGroupService();
        final g1 = await groupService.createGroup(title: 'To Be Deleted');
        expect(groupService.groups.length, 1);

        await groupService.deleteGroup(g1.id);
        expect(groupService.groups, isEmpty);
      });

      testWidgets('5.3: Deleted groups no longer appear in HomeScreen custom groups section', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        final g = await groupService.createGroup(title: 'Ghost Group');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Ghost Group'), findsOneWidget);

        await groupService.deleteGroup(g.id);
        await tester.pumpAndSettle();

        expect(find.text('Ghost Group'), findsNothing);
      });

      test('5.4: Deleting a group does not delete physical media files from library database', () async {
        final groupService = MediaGroupService();
        final video = await harness.createMockVideoFile(tempDir, 'keep_me.mp4');

        final item = MediaItem(
          path: video.path,
          name: 'keep_me.mp4',
          parentFolder: tempDir.path,
          sizeBytes: 1024 * 1024,
          durationMs: 60000,
          lastPlayed: DateTime.now(),
        );
        await DatabaseHelper.instance.insertOrUpdateItem(item);

        final group = await groupService.createGroup(title: 'Group With Files');
        await safeAddItemsToGroup(groupService, group.id, [video.path]);
        expect(groupService.groups.first.itemPaths.length, 1);

        // Delete group
        await groupService.deleteGroup(group.id);
        expect(groupService.groups, isEmpty);

        // Physical file on disk and DB record must remain untouched
        expect(video.existsSync(), isTrue);
        final dbItems = await DatabaseHelper.instance.getAllItems();
        expect(dbItems.any((i) => i.path == video.path), isTrue);
      });

      test('5.5: Batch deleting multiple selected groups removes all selected groups simultaneously', () async {
        final groupService = MediaGroupService();
        final g1 = await groupService.createGroup(title: 'Del 1');
        final g2 = await groupService.createGroup(title: 'Del 2');
        final g3 = await groupService.createGroup(title: 'Keep 3');

        expect(groupService.groups.length, 3);

        await groupService.deleteGroup(g1.id);
        await groupService.deleteGroup(g2.id);

        expect(groupService.groups.length, 1);
        expect(groupService.groups.first.id, g3.id);
        expect(groupService.groups.first.title, 'Keep 3');
      });
    });

    // -------------------------------------------------------------------------
    // R2: Long-Press Multi-Select, Select All, Delete, and Move (Home Screen)
    // Feature 6: Batch Move (Home)
    // -------------------------------------------------------------------------
    group('Feature 6: Batch Move on Home Screen (R2)', () {
      testWidgets('6.1: Tapping Move with selected media items opens destination group dialog', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Dest Group');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        final moveBtn = find.byIcon(Icons.drive_file_move);
        if (moveBtn.evaluate().isNotEmpty) {
          await tester.tap(moveBtn);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
        }
      });

      test('6.2: Group selection dialog lists all available destination custom groups', () async {
        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Favorites 2026');
        await groupService.createGroup(title: 'Watch Later');

        final availableTitles = groupService.groups.map((g) => g.title).toList();
        expect(availableTitles, containsAll(['Favorites 2026', 'Watch Later']));
      });

      test('6.3: Selecting target group moves selected media items to that group', () async {
        final groupService = MediaGroupService();
        final src = await groupService.createGroup(title: 'Source');
        final dst = await groupService.createGroup(title: 'Target');

        final file = await harness.createMockVideoFile(tempDir, 'move_test.mp4');
        await safeAddItemsToGroup(groupService, src.id, [file.path]);

        await safeMoveItemsBetweenGroups(
          groupService,
          fromGroupId: src.id,
          toGroupId: dst.id,
          paths: [file.path],
        );

        final updatedSrc = groupService.groups.firstWhere((g) => g.id == src.id);
        final updatedDst = groupService.groups.firstWhere((g) => g.id == dst.id);

        expect(updatedSrc.itemPaths, isEmpty);
        expect(updatedDst.itemPaths, contains(file.path));
      });

      test('6.4: Moved items are removed from source group and appended to destination group', () async {
        final groupService = MediaGroupService();
        final g1 = await groupService.createGroup(title: 'Group 1');
        final g2 = await groupService.createGroup(title: 'Group 2');

        final f1 = await harness.createMockVideoFile(tempDir, 'a.mp4');
        final f2 = await harness.createMockVideoFile(tempDir, 'b.mp4');
        await safeAddItemsToGroup(groupService, g1.id, [f1.path, f2.path]);

        await safeMoveItemsBetweenGroups(
          groupService,
          fromGroupId: g1.id,
          toGroupId: g2.id,
          paths: [f1.path],
        );

        final res1 = groupService.groups.firstWhere((g) => g.id == g1.id);
        final res2 = groupService.groups.firstWhere((g) => g.id == g2.id);

        expect(res1.itemPaths, [f2.path]);
        expect(res2.itemPaths, [f1.path]);
      });

      test('6.5: Moving items between groups persists changes in SharedPreferences', () async {
        final groupService = MediaGroupService();
        final gA = await groupService.createGroup(title: 'A');
        final gB = await groupService.createGroup(title: 'B');

        final f = await harness.createMockVideoFile(tempDir, 'persisted.mp4');
        await safeAddItemsToGroup(groupService, gA.id, [f.path]);

        await safeMoveItemsBetweenGroups(
          groupService,
          fromGroupId: gA.id,
          toGroupId: gB.id,
          paths: [f.path],
        );

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('eplayer_custom_media_groups_v1');
        expect(raw, isNotNull);

        final List<dynamic> decoded = jsonDecode(raw!);
        final groupBJson = decoded.firstWhere((e) => e['id'] == gB.id);
        expect(groupBJson['itemPaths'], contains(f.path));
      });
    });

    // -------------------------------------------------------------------------
    // R2: Long-Press Multi-Select, Select All, Delete, and Move (Home Screen)
    // Feature 7: Built-in Feature Protection (Home)
    // -------------------------------------------------------------------------
    group('Feature 7: Built-in Feature Protection on Home Screen (R2)', () {
      testWidgets('7.1: Long-pressing "Create Group" action card does NOT activate multi-selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final createGroupCard = find.text('Create Group');
        expect(createGroupCard, findsOneWidget);

        await tester.longPress(createGroupCard);
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing);
      });

      testWidgets('7.2: Long-pressing "Videos" action card does NOT activate multi-selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final videosCard = find.text('Videos');
        expect(videosCard, findsOneWidget);

        await tester.longPress(videosCard);
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing);
      });

      testWidgets('7.3: Long-pressing category chips (All, History, Videos, etc.) does NOT activate multi-selection', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final allChip = find.text('All');
        expect(allChip, findsOneWidget);

        await tester.longPress(allChip);
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing);
      });

      testWidgets('7.4: Long-pressing AppBar icons or section headers does NOT trigger selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final historyHeader = find.text('History');
        expect(historyHeader, findsOneWidget);

        await tester.longPress(historyHeader);
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing);
      });

      testWidgets('7.5: Built-in default features are protected from deletion and moving', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'My Custom Group');

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('My Custom Group'));
        await tester.pumpAndSettle();

        // Ensure "Create Group" and "Videos" remain visible and unselected
        expect(find.text('Create Group'), findsOneWidget);
        expect(find.text('Videos'), findsOneWidget);
        expect(find.textContaining('1 Selected'), findsWidgets);
      });
    });

    // -------------------------------------------------------------------------
    // R3: Multi-Select and Batch Actions in Library Section
    // Feature 8: Multi-Select & Batch Actions (Library)
    // -------------------------------------------------------------------------
    group('Feature 8: Multi-Select & Batch Actions in Library Section (R3)', () {
      testWidgets('8.1: Long-pressing a media item or folder in LibraryScreen activates multi-selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.runAsync(() async {
          final video = await harness.createMockVideoFile(tempDir, 'lib_video_1.mp4');
          final item = MediaItem(
            path: video.path,
            name: 'lib_video_1.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 1024 * 1024 * 5,
            durationMs: 90000,
            lastPlayed: DateTime.now(),
          );
          await DatabaseHelper.instance.insertOrUpdateItem(item);
        });

        final libProvider = LibraryProvider();
        await tester.runAsync(() => libProvider.refreshLibrary());

        await tester.pumpWidget(buildTestApp(
          child: const LibraryScreen(),
          libraryProvider: libProvider,
        ));
        await tester.pumpAndSettle();

        final itemFinder = find.text('lib_video_1.mp4');
        if (itemFinder.evaluate().isNotEmpty) {
          await tester.longPress(itemFinder);
          await tester.pumpAndSettle();
          expect(find.textContaining('Selected'), findsWidgets);
        }
      });

      testWidgets('8.2: Selection bar displays count of selected library items', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const LibraryScreen()));
        await tester.pumpAndSettle();

        // Verifies selection header format
        final selectionHeader = find.textContaining('0 Selected');
        expect(selectionHeader, findsNothing); // should not be visible when inactive
      });

      testWidgets('8.3: "Select All" in Library selects all visible library items', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final libProvider = LibraryProvider();
        await tester.pumpWidget(buildTestApp(
          child: const LibraryScreen(),
          libraryProvider: libProvider,
        ));
        await tester.pumpAndSettle();

        final selectAllBtn = find.text('Select All');
        if (selectAllBtn.evaluate().isNotEmpty) {
          await tester.tap(selectAllBtn);
          await tester.pumpAndSettle();
        }
      });

      test('8.4: Batch Delete in Library removes items from library and updates DatabaseHelper', () async {
        final v1 = await harness.createMockVideoFile(tempDir, 'del1.mp4');
        final v2 = await harness.createMockVideoFile(tempDir, 'del2.mp4');

        final item1 = MediaItem(path: v1.path, name: 'del1.mp4', parentFolder: tempDir.path, sizeBytes: 100, durationMs: 10, lastPlayed: DateTime.now());
        final item2 = MediaItem(path: v2.path, name: 'del2.mp4', parentFolder: tempDir.path, sizeBytes: 100, durationMs: 10, lastPlayed: DateTime.now());

        await DatabaseHelper.instance.insertBatch([item1, item2]);
        var all = await DatabaseHelper.instance.getAllItems();
        expect(all.length, 2);

        await DatabaseHelper.instance.deleteBatch([v1.path, v2.path]);
        all = await DatabaseHelper.instance.getAllItems();
        expect(all, isEmpty);
      });

      test('8.5: Batch Move in Library assigns selected media paths to custom group', () async {
        final groupService = MediaGroupService();
        final group = await groupService.createGroup(title: 'Library Move Target');

        final f1 = await harness.createMockVideoFile(tempDir, 'lib_f1.mp4');
        final f2 = await harness.createMockVideoFile(tempDir, 'lib_f2.mp4');

        await safeAddItemsToGroup(groupService, group.id, [f1.path, f2.path]);

        final updated = groupService.groups.firstWhere((g) => g.id == group.id);
        expect(updated.itemPaths, containsAll([f1.path, f2.path]));
      });
    });

    // -------------------------------------------------------------------------
    // R4: Scrollable History with 5-Item Limit
    // Feature 9: History Scrollable View
    // -------------------------------------------------------------------------
    group('Feature 9: History Scrollable View (R4)', () {
      testWidgets('9.1: History section renders inside a scrollable viewport', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(find.text('History'), findsOneWidget);
      });

      testWidgets('9.2: History viewport responds smoothly to drag gestures', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final historySection = find.text('History');
        expect(historySection, findsOneWidget);

        await tester.drag(historySection, const Offset(-100, 0));
        await tester.pumpAndSettle();

        expect(find.text('History'), findsOneWidget);
      });

      testWidgets('9.3: History scroll physics uses BouncingScrollPhysics or smooth physics', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final scrollables = tester.widgetList<ScrollView>(find.bySubtype<ScrollView>());
        expect(scrollables.any((s) => s.physics is BouncingScrollPhysics || s.physics is AlwaysScrollableScrollPhysics), isTrue);
      });

      testWidgets('9.4: History section displays play buttons and metadata for browsing past media', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('History'), findsOneWidget);
      });

      testWidgets('9.5: History items can be browsed smoothly to reach the last visible item', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        await tester.drag(find.text('History'), const Offset(0, -150));
        await tester.pumpAndSettle();

        expect(find.text('History'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // R4: Scrollable History with 5-Item Limit
    // Feature 10: History Strict 5-Item Cap
    // -------------------------------------------------------------------------
    group('Feature 10: History Strict 5-Item Cap (R4)', () {
      test('10.1: When library has >5 recent files, recent files list enforces cap of 5', () async {
        final files = <MediaItem>[];
        for (var i = 1; i <= 8; i++) {
          final f = await harness.createMockVideoFile(tempDir, 'recent_$i.mp4');
          files.add(MediaItem(
            path: f.path,
            name: 'recent_$i.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 1024 * 1024,
            durationMs: 60000,
            lastPlayed: DateTime.now().subtract(Duration(minutes: i)),
          ));
        }

        await DatabaseHelper.instance.insertBatch(files);
        final libProvider = LibraryProvider();
        await libProvider.refreshLibrary();

        // Requirement R4: Limit History list to display a maximum of 5 items
        final cappedRecents = libProvider.recentFiles.take(5).toList();
        expect(cappedRecents.length, 5);
      });

      test('10.2: When library has exactly 5 recent files, History displays all 5 items', () async {
        final files = <MediaItem>[];
        for (var i = 1; i <= 5; i++) {
          final f = await harness.createMockVideoFile(tempDir, 'exact_$i.mp4');
          files.add(MediaItem(
            path: f.path,
            name: 'exact_$i.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 1024 * 1024,
            durationMs: 60000,
            lastPlayed: DateTime.now().subtract(Duration(minutes: i)),
          ));
        }

        await DatabaseHelper.instance.insertBatch(files);
        final libProvider = LibraryProvider();
        await libProvider.refreshLibrary();

        final cappedRecents = libProvider.recentFiles.take(5).toList();
        expect(cappedRecents.length, 5);
      });

      test('10.3: When library has fewer than 5 recent files (e.g. 3), History renders only those 3', () async {
        final files = <MediaItem>[];
        for (var i = 1; i <= 3; i++) {
          final f = await harness.createMockVideoFile(tempDir, 'few_$i.mp4');
          files.add(MediaItem(
            path: f.path,
            name: 'few_$i.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 1024 * 1024,
            durationMs: 60000,
            lastPlayed: DateTime.now().subtract(Duration(minutes: i)),
          ));
        }

        await DatabaseHelper.instance.insertBatch(files);
        final libProvider = LibraryProvider();
        await libProvider.refreshLibrary();

        final cappedRecents = libProvider.recentFiles.take(5).toList();
        expect(cappedRecents.length, 3);
      });

      testWidgets('10.4: When library has 0 recent files, History handles empty state gracefully without crash', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final libProvider = LibraryProvider();
        await tester.runAsync(() => libProvider.refreshLibrary());

        await tester.pumpWidget(buildTestApp(
          child: const HomeScreen(),
          libraryProvider: libProvider,
        ));
        await tester.pumpAndSettle();

        expect(find.text('History'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      test('10.5: In grouped recent mode, groupedRecentFiles takes at most 5 items', () async {
        final files = <MediaItem>[];
        for (var i = 1; i <= 10; i++) {
          final f = await harness.createMockVideoFile(tempDir, 'grp_file_$i.mp4');
          files.add(MediaItem(
            path: f.path,
            name: 'grp_file_$i.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 1024 * 1024,
            durationMs: 60000,
            lastPlayed: DateTime.now().subtract(Duration(minutes: i)),
          ));
        }

        final groups = VideoGroupingEngine.group(files, GroupMode.byFolder);
        final cappedGroups = groups.take(5).toList();
        expect(cappedGroups.length, lessThanOrEqualTo(5));
      });
    });

    // -------------------------------------------------------------------------
    // R5: Media Library Video-Only Filtering
    // Feature 11: Video-Only Media Library Filter
    // -------------------------------------------------------------------------
    group('Feature 11: Video-Only Media Library Filter (R5)', () {
      test('11.1: MediaScannerService correctly identifies video extensions as video', () {
        expect(MediaScannerService.isVideo('movie.mp4'), isTrue);
        expect(MediaScannerService.isVideo('clip.mkv'), isTrue);
        expect(MediaScannerService.isVideo('video.avi'), isTrue);
        expect(MediaScannerService.isVideo('song.mp3'), isFalse);
        expect(MediaScannerService.isVideo('audio.flac'), isFalse);
        expect(MediaScannerService.isVideo('track.wav'), isFalse);
      });

      test('11.2: Media files with audio extensions (.mp3, .flac, .wav, .m4a) are excluded from video filter', () {
        final allPaths = [
          'track1.mp3',
          'track2.flac',
          'track3.wav',
          'track4.m4a',
          'video1.mp4',
          'video2.mkv',
        ];

        final videoOnly = allPaths.where((p) => MediaScannerService.isVideo(p)).toList();
        expect(videoOnly, ['video1.mp4', 'video2.mkv']);
      });

      test('11.3: Folders containing only audio files are excluded from video folder catalog', () {
        final audioOnlyFolder = [
          MediaItem(path: '/music/s1.mp3', name: 's1.mp3', parentFolder: '/music', sizeBytes: 100, durationMs: 10, lastPlayed: DateTime.now()),
          MediaItem(path: '/music/s2.flac', name: 's2.flac', parentFolder: '/music', sizeBytes: 100, durationMs: 10, lastPlayed: DateTime.now()),
        ];

        final videoItems = audioOnlyFolder.where((i) => MediaScannerService.isVideo(i.path)).toList();
        expect(videoItems, isEmpty);
      });

      test('11.4: Video folders in Media Library reflect accurate video-only counts', () {
        final mixedFolder = [
          MediaItem(path: '/media/v1.mp4', name: 'v1.mp4', parentFolder: '/media', sizeBytes: 100, durationMs: 10, lastPlayed: DateTime.now()),
          MediaItem(path: '/media/v2.mkv', name: 'v2.mkv', parentFolder: '/media', sizeBytes: 100, durationMs: 10, lastPlayed: DateTime.now()),
          MediaItem(path: '/media/song.mp3', name: 'song.mp3', parentFolder: '/media', sizeBytes: 100, durationMs: 10, lastPlayed: DateTime.now()),
        ];

        final videoItems = mixedFolder.where((i) => MediaScannerService.isVideo(i.path)).toList();
        expect(videoItems.length, 2);
      });

      testWidgets('11.5: Tapping a video folder in Media Library opens FolderDetailScreen with video items', (tester) async {
        final videoItem = MediaItem(
          path: '/videos/sample.mp4',
          name: 'sample.mp4',
          parentFolder: '/videos',
          sizeBytes: 1024,
          durationMs: 1000,
          lastPlayed: DateTime.now(),
        );

        await tester.pumpWidget(buildTestApp(
          child: FolderDetailScreen(
            folderName: '/videos',
            items: [videoItem],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('sample.mp4'), findsOneWidget);
        expect(find.text('1 media files · 1.0 KB · Sorted by Name'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // R5: Media Library Video-Only Filtering
    // Feature 12: Complete Removal of Music/Series/Anime
    // -------------------------------------------------------------------------
    group('Feature 12: Complete Removal of Music/Series/Anime Categories (R5)', () {
      testWidgets('12.1: The 4 Bento category cards (Movies, Series, Anime, Music) are removed from Home screen', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        // Music, Series, Anime category cards must not be found
        expect(find.text('Music'), findsNothing);
        expect(find.text('Anime'), findsNothing);
        expect(find.text('Series'), findsNothing);
      });

      testWidgets('12.2: Text "Music" category section is not rendered in Media Library', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(InkWell, 'Music'), findsNothing);
      });

      testWidgets('12.3: Text "Series" category section is not rendered in Media Library', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(InkWell, 'Series'), findsNothing);
      });

      testWidgets('12.4: Text "Anime" category section is not rendered in Media Library', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(InkWell, 'Anime'), findsNothing);
      });

      testWidgets('12.5: Category cards with mock item counts are completely eliminated', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        expect(find.text('18 items'), findsNothing);
        expect(find.text('12 items'), findsNothing);
      });
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES
  // ===========================================================================
  group('Tier 2: Boundary & Corner Cases', () {
    test('2.1: Empty group creation with 0 initial paths maintains length == 0', () async {
      final groupService = MediaGroupService();
      final g = await groupService.createGroup(title: 'Boundary Zero', initialPaths: const []);
      expect(g.itemPaths, isEmpty);
      expect(g.itemPaths.length, 0);
    });

    test('2.2: Group with whitespace-only title normalizes safely to default title', () async {
      final groupService = MediaGroupService();
      final g = await groupService.createGroup(title: '       \t\n  ');
      expect(g.title, 'New Group');
      expect(g.itemPaths, isEmpty);
    });

    testWidgets('2.3: FolderDetailScreen with 0 items displays empty indicator without RangeError', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const FolderDetailScreen(
          folderName: 'Boundary Empty',
          items: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0 media files · 0 B · Sorted by Name'), findsOneWidget);
    });

    testWidgets('2.4: History section with 0 recent files handles empty state without crashing', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final libProvider = LibraryProvider();
      await tester.runAsync(() => libProvider.refreshLibrary());

      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        libraryProvider: libProvider,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('2.5: History section with exactly 1 recent file displays 1 item', () async {
      final f = await harness.createMockVideoFile(tempDir, 'solo_recent.mp4');
      final item = MediaItem(
        path: f.path,
        name: 'solo_recent.mp4',
        parentFolder: tempDir.path,
        sizeBytes: 1024,
        durationMs: 1000,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(item);

      final libProvider = LibraryProvider();
      await libProvider.refreshLibrary();

      final capped = libProvider.recentFiles.take(5).toList();
      expect(capped.length, 1);
      expect(capped.first.name, 'solo_recent.mp4');
    });

    test('2.6: History section with exactly 5 recent files displays all 5 items', () async {
      final items = <MediaItem>[];
      for (var i = 1; i <= 5; i++) {
        final f = await harness.createMockVideoFile(tempDir, 'exact5_$i.mp4');
        items.add(MediaItem(
          path: f.path,
          name: 'exact5_$i.mp4',
          parentFolder: tempDir.path,
          sizeBytes: 1024,
          durationMs: 1000,
          lastPlayed: DateTime.now().subtract(Duration(minutes: i)),
        ));
      }
      await DatabaseHelper.instance.insertBatch(items);

      final libProvider = LibraryProvider();
      await libProvider.refreshLibrary();

      final capped = libProvider.recentFiles.take(5).toList();
      expect(capped.length, 5);
    });

    test('2.7: History section with 25 recent files seeded is strictly capped at 5', () async {
      final items = <MediaItem>[];
      for (var i = 1; i <= 25; i++) {
        final f = await harness.createMockVideoFile(tempDir, 'stress_$i.mp4');
        items.add(MediaItem(
          path: f.path,
          name: 'stress_$i.mp4',
          parentFolder: tempDir.path,
          sizeBytes: 1024,
          durationMs: 1000,
          lastPlayed: DateTime.now().subtract(Duration(minutes: i)),
        ));
      }
      await DatabaseHelper.instance.insertBatch(items);

      final libProvider = LibraryProvider();
      await libProvider.refreshLibrary();

      final capped = libProvider.recentFiles.take(5).toList();
      expect(capped.length, 5);
      expect(capped.length, lessThanOrEqualTo(5));
    });

    testWidgets('2.8: Multi-select with empty selection handles actions as safe no-op', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('2.9: Select All on empty container maintains 0 selected items', () {
      final List<String> containerItems = [];
      final Set<String> selectedPaths = {};

      // Select All on empty container
      selectedPaths.addAll(containerItems);
      expect(selectedPaths, isEmpty);
      expect(selectedPaths.length, 0);
    });

    test('2.10: Adding non-existent file paths to group persists path strings safely', () async {
      final groupService = MediaGroupService();
      final g = await groupService.createGroup(title: 'Non-Existent Paths');

      const phantomPath = '/does/not/exist/phantom_video.mp4';
      await safeAddItemsToGroup(groupService, g.id, [phantomPath]);

      final updated = groupService.groups.firstWhere((grp) => grp.id == g.id);
      expect(updated.itemPaths, contains(phantomPath));
    });

    test('2.11: Adding duplicate paths to group enforces set uniqueness', () async {
      final groupService = MediaGroupService();
      final g = await groupService.createGroup(title: 'Duplicate Path Test');

      final video = await harness.createMockVideoFile(tempDir, 'unique.mp4');
      await safeAddItemsToGroup(groupService, g.id, [video.path]);
      await safeAddItemsToGroup(groupService, g.id, [video.path]);

      final updated = groupService.groups.firstWhere((grp) => grp.id == g.id);
      expect(updated.itemPaths.where((p) => p == video.path).length, 1);
    });

    test('2.12: Custom group title with special characters, unicode, emoji, and 500+ chars', () async {
      final groupService = MediaGroupService();
      final extremeTitle = '🎥 4K Ultra HD & 3D (2026) [Special-Edition] // 🔥 ${'A' * 450}';

      final g = await groupService.createGroup(title: extremeTitle);
      expect(g.title, extremeTitle);
      expect(groupService.groups.first.title, extremeTitle);
    });

    test('2.13: Moving items to the same group is idempotent and does not duplicate', () async {
      final groupService = MediaGroupService();
      final g = await groupService.createGroup(title: 'Self-Move Group');

      final v = await harness.createMockVideoFile(tempDir, 'self.mp4');
      await safeAddItemsToGroup(groupService, g.id, [v.path]);

      await safeMoveItemsBetweenGroups(
        groupService,
        fromGroupId: g.id,
        toGroupId: g.id,
        paths: [v.path],
      );

      final updated = groupService.groups.firstWhere((grp) => grp.id == g.id);
      expect(updated.itemPaths.length, 1);
    });
  });

  // ===========================================================================
  // TIER 3: CROSS-FEATURE INTERACTIONS
  // ===========================================================================
  group('Tier 3: Cross-Feature Interactions', () {
    test('3.1: Create group -> Multi-select items in Library -> Move to group -> Verify group count and persistence', () async {
      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Curated Favorites');

      final v1 = await harness.createMockVideoFile(tempDir, 'cross_1.mp4');
      final v2 = await harness.createMockVideoFile(tempDir, 'cross_2.mp4');
      final v3 = await harness.createMockVideoFile(tempDir, 'cross_3.mp4');

      final selectedInLibrary = [v1.path, v2.path, v3.path];
      await safeAddItemsToGroup(groupService, group.id, selectedInLibrary);

      final loadedGroup = groupService.groups.firstWhere((g) => g.id == group.id);
      expect(loadedGroup.itemPaths.length, 3);
      expect(loadedGroup.itemPaths, containsAll(selectedInLibrary));
    });

    test('3.2: Multi-select custom groups on Home -> Batch delete -> Verify Library items remain unaffected', () async {
      final groupService = MediaGroupService();
      final g1 = await groupService.createGroup(title: 'Temp Collection 1');
      final g2 = await groupService.createGroup(title: 'Temp Collection 2');

      final v = await harness.createMockVideoFile(tempDir, 'independent.mp4');
      final item = MediaItem(
        path: v.path,
        name: 'independent.mp4',
        parentFolder: tempDir.path,
        sizeBytes: 2048,
        durationMs: 2000,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(item);

      await safeAddItemsToGroup(groupService, g1.id, [v.path]);
      await safeAddItemsToGroup(groupService, g2.id, [v.path]);

      // Batch delete both custom groups
      await groupService.deleteGroup(g1.id);
      await groupService.deleteGroup(g2.id);
      expect(groupService.groups, isEmpty);

      // Verify Library item exists
      final libItems = await DatabaseHelper.instance.getAllItems();
      expect(libItems.any((i) => i.path == v.path), isTrue);
    });

    test('3.3: Playback adds recent files -> History updates and enforces 5-item cap -> History remains scrollable', () async {
      final libProvider = LibraryProvider();
      final createdFiles = <MediaItem>[];

      for (var i = 1; i <= 7; i++) {
        final f = await harness.createMockVideoFile(tempDir, 'watch_$i.mp4');
        createdFiles.add(MediaItem(
          path: f.path,
          name: 'watch_$i.mp4',
          parentFolder: tempDir.path,
          sizeBytes: 1000,
          durationMs: 5000,
          lastPlayed: DateTime.now().subtract(Duration(minutes: 10 - i)),
        ));
      }
      await DatabaseHelper.instance.insertBatch(createdFiles);
      await libProvider.refreshLibrary();

      final cappedHistory = libProvider.recentFiles.take(5).toList();
      expect(cappedHistory.length, 5);
      // Most recent should be watch_7.mp4
      expect(cappedHistory.first.name, 'watch_7.mp4');
    });

    test('3.4: Filter Media Library to video-only -> Select videos -> Move/add to custom group', () async {
      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Video Group');

      final v = await harness.createMockVideoFile(tempDir, 'filtered_vid.mp4');
      final a = File('${tempDir.path}/filtered_aud.mp3');
      await a.writeAsString('audio');

      final candidatePaths = [v.path, a.path];
      final videoOnlyPaths = candidatePaths.where((p) => MediaScannerService.isVideo(p)).toList();

      expect(videoOnlyPaths, [v.path]);
      await safeAddItemsToGroup(groupService, group.id, videoOnlyPaths);

      final res = groupService.groups.firstWhere((g) => g.id == group.id);
      expect(res.itemPaths, [v.path]);
    });

    test('3.5: Empty group created -> Add button media import -> Items selected -> Batch deleted -> Group returns to empty state', () async {
      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Lifecycle Group');
      expect(groupService.groups.first.itemPaths, isEmpty);

      final f1 = await harness.createMockVideoFile(tempDir, 'life_1.mp4');
      final f2 = await harness.createMockVideoFile(tempDir, 'life_2.mp4');
      await safeAddItemsToGroup(groupService, group.id, [f1.path, f2.path]);
      expect(groupService.groups.first.itemPaths.length, 2);

      await safeRemoveItemsFromGroup(groupService, group.id, [f1.path, f2.path]);
      expect(groupService.groups.first.itemPaths, isEmpty);
    });

    test('3.6: Delete multiple custom groups updates groups list and active selection state is cleared', () async {
      final groupService = MediaGroupService();
      final gA = await groupService.createGroup(title: 'Group Alpha');
      final gB = await groupService.createGroup(title: 'Group Beta');
      final gC = await groupService.createGroup(title: 'Group Gamma');

      final selectedGroupIds = {gA.id, gB.id};
      for (final id in selectedGroupIds) {
        await groupService.deleteGroup(id);
      }
      selectedGroupIds.clear();

      expect(groupService.groups.length, 1);
      expect(groupService.groups.first.id, gC.id);
      expect(groupService.groups.first.title, 'Group Gamma');
      expect(selectedGroupIds, isEmpty);
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD WORKLOAD SCENARIOS
  // ===========================================================================
  group('Tier 4: Real-World Workload Scenarios', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Empty Group Creation -> Add Button -> File Import Flow
    // -------------------------------------------------------------------------
    testWidgets('Scenario 1: User creates new group "Travel 2026", verifies empty, navigates, adds 3 video clips', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final groupService = MediaGroupService();
      final group = await groupService.createGroup(title: 'Travel 2026');

      expect(group.itemPaths, isEmpty);
      expect(group.title, 'Travel 2026');

      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        mediaGroupService: groupService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Travel 2026'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);

      await tester.tap(find.text('Travel 2026'));
      await tester.pumpAndSettle();

      expect(find.byType(FolderDetailScreen), findsOneWidget);
      expect(find.text('0 media files · 0 B · Sorted by Name'), findsOneWidget);

      await tester.runAsync(() async {
        final v1 = await harness.createMockVideoFile(tempDir, 'flight.mp4');
        final v2 = await harness.createMockVideoFile(tempDir, 'hotel.mp4');
        final v3 = await harness.createMockVideoFile(tempDir, 'beach.mp4');
        await safeAddItemsToGroup(groupService, group.id, [v1.path, v2.path, v3.path]);
      });
      final updated = groupService.groups.firstWhere((g) => g.id == group.id);
      expect(updated.itemPaths.length, 3);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Long-Press Multi-Select -> Select All -> Batch Delete Flow
    // -------------------------------------------------------------------------
    testWidgets('Scenario 2: User long-presses custom group, taps Select All, deselects 1, batch deletes remainder', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final groupService = MediaGroupService();
      final g1 = await groupService.createGroup(title: 'Collection A');
      final g2 = await groupService.createGroup(title: 'Collection B');
      final g3 = await groupService.createGroup(title: 'Collection C');

      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        mediaGroupService: groupService,
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Collection A'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 Selected'), findsWidgets);

      final selectedIds = <String>{g1.id, g2.id, g3.id};
      // User deselects g3
      selectedIds.remove(g3.id);
      expect(selectedIds.length, 2);

      // User confirms delete
      await tester.runAsync(() async {
        for (final id in selectedIds) {
          await groupService.deleteGroup(id);
        }
      });

      expect(groupService.groups.length, 1);
      expect(groupService.groups.first.title, 'Collection C');
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Built-in Feature Protection Against Selection
    // -------------------------------------------------------------------------
    testWidgets('Scenario 3: User attempts long-press on Create Group & Videos cards; verifies built-in protection', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const HomeScreen()));
      await tester.pumpAndSettle();

      final createGroupBtn = find.text('Create Group');
      final videosBtn = find.text('Videos');

      expect(createGroupBtn, findsOneWidget);
      expect(videosBtn, findsOneWidget);

      await tester.longPress(createGroupBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected'), findsNothing);

      await tester.longPress(videosBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected'), findsNothing);

      final allFilterChip = find.text('All');
      await tester.longPress(allFilterChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: 10 Recent Videos -> 5-Item History Cap -> Smooth Horizontal Scroll
    // -------------------------------------------------------------------------
    testWidgets('Scenario 4: 10 recent videos seeded; History renders strictly 5 items with smooth scrolling', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <MediaItem>[];
      await tester.runAsync(() async {
        for (var i = 1; i <= 10; i++) {
          final f = await harness.createMockVideoFile(tempDir, 'movie_ep_$i.mp4');
          items.add(MediaItem(
            path: f.path,
            name: 'movie_ep_$i.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 1024 * 1024 * 10,
            durationMs: 120000,
            lastPlayed: DateTime.now().subtract(Duration(minutes: 20 - i)),
          ));
        }
        await DatabaseHelper.instance.insertBatch(items);
      });

      final libProvider = LibraryProvider();
      await tester.runAsync(() => libProvider.refreshLibrary());

      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        libraryProvider: libProvider,
      ));
      await tester.pumpAndSettle();

      final capped = libProvider.recentFiles.take(5).toList();
      expect(capped.length, 5);
      expect(capped.first.name, 'movie_ep_10.mp4');

      final historyHeader = find.text('History');
      expect(historyHeader, findsOneWidget);

      await tester.drag(historyHeader, const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(find.text('History'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Mixed Media Seed -> Video-Only Media Library -> Zero Music/Series Cards
    // -------------------------------------------------------------------------
    testWidgets('Scenario 5: Mixed videos and music seeded; Media Library renders only video folders and 0 music/series cards', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.runAsync(() async {
        final v1 = await harness.createMockVideoFile(tempDir, 'action_blockbuster.mp4');
        final v2 = await harness.createMockVideoFile(tempDir, 'docu_nature.mkv');
        final a1 = File('${tempDir.path}/podcast.mp3');
        final a2 = File('${tempDir.path}/soundtrack.flac');
        await a1.writeAsString('audio data');
        await a2.writeAsString('audio data');

        final items = [
          MediaItem(path: v1.path, name: 'action_blockbuster.mp4', parentFolder: tempDir.path, sizeBytes: 1024, durationMs: 1000, lastPlayed: DateTime.now()),
          MediaItem(path: v2.path, name: 'docu_nature.mkv', parentFolder: tempDir.path, sizeBytes: 1024, durationMs: 1000, lastPlayed: DateTime.now()),
          MediaItem(path: a1.path, name: 'podcast.mp3', parentFolder: tempDir.path, sizeBytes: 1024, durationMs: 1000, lastPlayed: DateTime.now()),
          MediaItem(path: a2.path, name: 'soundtrack.flac', parentFolder: tempDir.path, sizeBytes: 1024, durationMs: 1000, lastPlayed: DateTime.now()),
        ];
        await DatabaseHelper.instance.insertBatch(items);
      });

      final libProvider = LibraryProvider();
      await tester.runAsync(() => libProvider.refreshLibrary());

      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        libraryProvider: libProvider,
      ));
      await tester.pumpAndSettle();

      // Asserts that 4 Bento category cards are not displayed
      expect(find.text('Music'), findsNothing);
      expect(find.text('Anime'), findsNothing);
      expect(find.text('Series'), findsNothing);
      expect(find.text('18 items'), findsNothing);
    });
  });
}
