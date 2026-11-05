import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/db/database_helper.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';
import 'package:app/features/home/ui/home_screen.dart';
import 'package:app/features/library/ui/library_screen.dart';
import 'package:app/features/library/ui/folder_detail_screen.dart';
import 'package:app/theme/e_player_theme.dart';
import '../helpers/eplayer_test_harness.dart';

Widget buildChallengerApp({
  required Widget child,
  LibraryProvider? libraryProvider,
  MediaGroupService? mediaGroupService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LibraryProvider>(create: (_) => libraryProvider ?? LibraryProvider()),
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
  final harness = EPlayerTestHarness();
  late Directory tempDir;

  setUpAll(() async {
    await harness.setUp();
  });

  setUp(() async {
    tempDir = harness.createTempDirectory('challenger_m2_');
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

  group('Milestone 2 Adversarial Challenge Suite (Empirical Challenger 2)', () {
    // =========================================================================
    // 1. STRESS TEST: Rapid Toggle Between Select All and None
    // =========================================================================
    group('Attack Vector 1: Rapid Toggle Between Select All and None', () {
      testWidgets('1.1: Rapidly alternating Select All and None 20x on HomeScreen maintains state integrity', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        for (var i = 1; i <= 6; i++) {
          await groupService.createGroup(title: 'Rapid Group $i');
        }

        await tester.pumpWidget(buildChallengerApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        // Enter selection mode via long-press on first group
        await tester.longPress(find.text('Rapid Group 1'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 Selected'), findsWidgets);

        // Perform 20 rapid toggles between 'Select All' and 'None'
        for (var i = 0; i < 20; i++) {
          final toggleFinder = find.byWidgetPredicate((w) =>
            w is Text && (w.data == 'Select All' || w.data == 'None')
          );
          expect(toggleFinder, findsOneWidget, reason: 'Toggle button must be present in selection bar');
          final isNone = (tester.widget<Text>(toggleFinder).data) == 'None';

          await tester.tap(toggleFinder);
          await tester.pump(); // fast pump without settling to stress state transitions

          if (isNone) {
            // Tapped None -> selection mode exits
            expect(find.textContaining('Selected'), findsNothing);
            // Re-enter selection mode for next toggle iteration
            if (i < 19) {
              await tester.longPress(find.text('Rapid Group 1'));
              await tester.pump();
            }
          } else {
            // Tapped Select All -> all 6 groups selected
            expect(find.textContaining('6 Selected'), findsWidgets);
          }
        }

        await tester.pumpAndSettle();
      });

      testWidgets('1.2: Rapidly toggling Select All on FolderDetailScreen with 8 items', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final items = List.generate(8, (i) => MediaItem(
          path: '/mock/folder/clip_$i.mp4',
          name: 'clip_$i.mp4',
          parentFolder: '/mock/folder',
          sizeBytes: 1024 * 1024 * (i + 1),
          durationMs: 30000,
          lastPlayed: DateTime.now(),
        ));

        await tester.pumpWidget(buildChallengerApp(
          child: FolderDetailScreen(
            folderName: 'Rapid Folder',
            items: items,
          ),
        ));
        await tester.pumpAndSettle();

        // Long press first item
        await tester.longPress(find.text('clip_0.mp4'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 Selected'), findsWidgets);

        // Rapid toggle 10 times
        for (var i = 0; i < 10; i++) {
          final toggleFinder = find.byWidgetPredicate((w) =>
            w is Text && (w.data == 'Select All' || w.data == 'None')
          );
          final text = tester.widget<Text>(toggleFinder).data;
          await tester.tap(toggleFinder);
          await tester.pump();

          if (text == 'None') {
            expect(find.textContaining('Selected'), findsNothing);
            if (i < 9) {
              await tester.longPress(find.text('clip_0.mp4'));
              await tester.pump();
            }
          } else {
            expect(find.textContaining('8 Selected'), findsWidgets);
          }
        }
        await tester.pumpAndSettle();
      });
    });

    // =========================================================================
    // 2. STRESS TEST: Deselecting Down to Zero (Zombie State Elimination)
    // =========================================================================
    group('Attack Vector 2: Deselecting Down to Zero (Zombie State Elimination)', () {
      testWidgets('2.1: HomeScreen - Select 3 groups and deselect one by one; mode terminates at zero without zombie bar', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Alpha');
        await groupService.createGroup(title: 'Beta');
        await groupService.createGroup(title: 'Gamma');

        await tester.pumpWidget(buildChallengerApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        // Step 1: Long press Alpha -> 1 Selected
        await tester.longPress(find.text('Alpha'));
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);

        // Step 2: Tap Beta -> 2 Selected
        await tester.tap(find.text('Beta'));
        await tester.pumpAndSettle();
        expect(find.text('2 Selected'), findsOneWidget);

        // Step 3: Tap Gamma -> 3 Selected
        await tester.tap(find.text('Gamma'));
        await tester.pumpAndSettle();
        expect(find.text('3 Selected'), findsOneWidget);

        // Step 4: Deselect Alpha -> 2 Selected
        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();
        expect(find.text('2 Selected'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Step 5: Deselect Beta -> 1 Selected
        await tester.tap(find.text('Beta'));
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Step 6: Deselect Gamma (last item) -> 0 Selected
        // MUST immediately exit selection mode and dismantle contextual AppBar
        await tester.tap(find.text('Gamma'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing, reason: 'Zombie selection counter must NOT remain in UI');
        expect(find.byIcon(Icons.close), findsNothing, reason: 'Exit button must be dismantled');
        expect(find.byIcon(Icons.drive_file_move), findsNothing, reason: 'Move action must be dismantled');
        expect(find.byIcon(Icons.delete), findsNothing, reason: 'Delete action must be dismantled');

        // Confirm standard UI is fully interactive: tapping Alpha navigates to FolderDetailScreen rather than toggling selection
        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();
        expect(find.byType(FolderDetailScreen), findsOneWidget, reason: 'Tapping after deselecting to zero must open group, not toggle selection');
      });

      testWidgets('2.2: FolderDetailScreen - Deselecting items down to zero cleanly restores normal AppBar', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final items = [
          MediaItem(
            path: '/mock/a.mp4',
            name: 'a.mp4',
            parentFolder: '/mock',
            sizeBytes: 1000,
            durationMs: 10000,
            lastPlayed: DateTime.now(),
          ),
          MediaItem(
            path: '/mock/b.mp4',
            name: 'b.mp4',
            parentFolder: '/mock',
            sizeBytes: 2000,
            durationMs: 20000,
            lastPlayed: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(buildChallengerApp(
          child: FolderDetailScreen(
            folderName: 'Test Folder',
            items: items,
          ),
        ));
        await tester.pumpAndSettle();

        // Long press first item
        await tester.longPress(find.text('a.mp4'));
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);

        // Select second item
        await tester.tap(find.text('b.mp4'));
        await tester.pumpAndSettle();
        expect(find.text('2 Selected'), findsOneWidget);

        // Deselect b.mp4
        await tester.tap(find.text('b.mp4'));
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);

        // Deselect a.mp4 (last item)
        await tester.tap(find.text('a.mp4'));
        await tester.pumpAndSettle();

        // Verify clean exit
        expect(find.textContaining('Selected'), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);
      });
    });

    // =========================================================================
    // 3. STRESS TEST: Unselectable Built-in Features & Protections
    // =========================================================================
    group('Attack Vector 3: Protection of Built-in Features from Gestures', () {
      testWidgets('3.1: Long-pressing Create Group card does NOT trigger selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildChallengerApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final createGroupFinder = find.text('Create Group');
        expect(createGroupFinder, findsOneWidget);

        await tester.longPress(createGroupFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);
      });

      testWidgets('3.2: Long-pressing Videos action card does NOT trigger selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildChallengerApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final videosCardFinder = find.text('Videos');
        expect(videosCardFinder, findsOneWidget);

        await tester.longPress(videosCardFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);
      });

      testWidgets('3.3: Long-pressing Category Chips does NOT trigger selection mode', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildChallengerApp(child: const HomeScreen()));
        await tester.pumpAndSettle();

        final allChipFinder = find.text('All');
        expect(allChipFinder, findsOneWidget);

        await tester.longPress(allChipFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.textContaining('Selected'), findsNothing);
      });

      testWidgets('3.4: LibraryScreen - Smart Playlists ignore long press and Select All', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final libProvider = LibraryProvider();

        await tester.pumpWidget(buildChallengerApp(
          child: const LibraryScreen(),
          libraryProvider: libProvider,
        ));
        await tester.pumpAndSettle();

        // Switch to Playlists tab
        final playlistsTab = find.text('Playlists');
        if (playlistsTab.evaluate().isNotEmpty) {
          await tester.tap(playlistsTab);
          await tester.pumpAndSettle();

          // Locate smart playlist
          final favPlaylist = find.text('Favorite Media');
          if (favPlaylist.evaluate().isNotEmpty) {
            await tester.longPress(favPlaylist, warnIfMissed: false);
            await tester.pumpAndSettle();
            expect(find.textContaining('Selected'), findsNothing, reason: 'Smart playlists must not enter selection mode');
          }
        }
      });
    });

    // =========================================================================
    // 4. STRESS TEST: Hardware Back Navigation (PopScope) Dismissal
    // =========================================================================
    group('Attack Vector 4: Hardware Back Navigation (PopScope) Dismissal', () {
      testWidgets('4.1: HomeScreen - Back navigation in selection mode cancels selection without popping screen', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final groupService = MediaGroupService();
        await groupService.createGroup(title: 'Back Test Group');

        await tester.pumpWidget(buildChallengerApp(
          child: const HomeScreen(),
          mediaGroupService: groupService,
        ));
        await tester.pumpAndSettle();

        // Long press to enter selection mode
        await tester.longPress(find.text('Back Test Group'));
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);

        // Simulate Hardware Back Button via PopScope / handlePopRoute
        final didPop = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Pop must be intercepted: handlePopRoute returns true because it handled it internally
        expect(didPop, isTrue);

        // HomeScreen must STILL be mounted and visible in the widget tree
        expect(find.byType(HomeScreen), findsOneWidget);

        // Selection mode MUST be dismissed
        expect(find.textContaining('Selected'), findsNothing, reason: 'Selection mode must be cancelled by hardware back navigation');
        expect(find.byIcon(Icons.close), findsNothing);
      });

      testWidgets('4.2: LibraryScreen - Back navigation in selection mode cancels selection without popping screen', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final libProvider = LibraryProvider();
        await tester.runAsync(() async {
          final video = await harness.createMockVideoFile(tempDir, 'lib_pop_test.mp4');
          final item = MediaItem(
            path: video.path,
            name: 'lib_pop_test.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 1024 * 1024,
            durationMs: 45000,
            lastPlayed: DateTime.now(),
          );
          await DatabaseHelper.instance.insertOrUpdateItem(item);
          await libProvider.refreshLibrary();
        });

        await tester.pumpWidget(buildChallengerApp(
          child: const LibraryScreen(),
          libraryProvider: libProvider,
        ));
        await tester.pumpAndSettle();

        // Long press item to enter selection
        final itemFinder = find.text('lib_pop_test.mp4');
        if (itemFinder.evaluate().isNotEmpty) {
          await tester.longPress(itemFinder, warnIfMissed: false);
          await tester.pumpAndSettle();

          expect(find.textContaining('Selected'), findsWidgets);

          // Simulate Hardware Back Button
          final didPop = await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          expect(didPop, isTrue);
          expect(find.byType(LibraryScreen), findsOneWidget);
          expect(find.textContaining('Selected'), findsNothing);
        }
      });

      testWidgets('4.3: FolderDetailScreen - Back navigation dismisses selection first, then pops screen on second back', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final items = [
          MediaItem(
            path: '/mock/pop1.mp4',
            name: 'pop1.mp4',
            parentFolder: '/mock',
            sizeBytes: 1024,
            durationMs: 5000,
            lastPlayed: DateTime.now(),
          ),
        ];

        // Wrap in a Navigator stack with a parent DummyHome screen
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
              ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
              ChangeNotifierProvider<CastService>(create: (_) => CastService()),
              ChangeNotifierProvider<MediaGroupService>(create: (_) => MediaGroupService()),
              ChangeNotifierProvider<ExportService>(create: (_) => ExportService()),
              ChangeNotifierProvider<VaultService>(create: (_) => VaultService()),
              ChangeNotifierProvider<TrashService>(create: (_) => TrashService()),
            ],
            child: MaterialApp(
              theme: EPlayerTheme.darkTheme,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => FolderDetailScreen(
                              folderName: 'Nav Folder',
                              items: items,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Folder'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Push FolderDetailScreen
        await tester.tap(find.text('Open Folder'));
        await tester.pumpAndSettle();
        expect(find.byType(FolderDetailScreen), findsOneWidget);

        // Enter selection mode
        await tester.longPress(find.text('pop1.mp4'));
        await tester.pumpAndSettle();
        expect(find.text('1 Selected'), findsOneWidget);

        // Back 1: MUST dismiss selection mode, NOT pop FolderDetailScreen
        final firstBack = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(firstBack, isTrue);
        expect(find.byType(FolderDetailScreen), findsOneWidget, reason: 'FolderDetailScreen must remain on screen after first back');
        expect(find.textContaining('Selected'), findsNothing, reason: 'Selection mode must be dismissed');

        // Back 2: NOT in selection mode, so MUST pop FolderDetailScreen back to parent
        final secondBack = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(secondBack, isTrue);
        expect(find.byType(FolderDetailScreen), findsNothing, reason: 'FolderDetailScreen must now be popped');
        expect(find.text('Open Folder'), findsOneWidget, reason: 'Parent screen must be revealed');
      });
    });
  });
}
