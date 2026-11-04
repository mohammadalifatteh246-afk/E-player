import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:app/core/db/media_library_database.dart';
import 'package:app/core/db/media_library_repository.dart';
import 'package:app/core/db/task_queue_repository.dart';
import 'package:app/features/browser/ui/file_browser_screen.dart';
import 'package:app/features/browser/ui/widgets/breadcrumb_bar.dart';
import 'package:app/features/browser/ui/widgets/drive_selector_bar.dart';
import 'package:app/features/library/domain/auto_rescan_coordinator.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  late EPlayerTestHarness harness;
  late Directory tempRoot;
  late AutoRescanCoordinator coordinator;

  Future<void> pumpScreen(WidgetTester tester, [Duration duration = const Duration(milliseconds: 500)]) async {
    await tester.pump();
    // 1. Wait for real async tasks (file I/O, SQLite) while spinner is active
    final sw = Stopwatch()..start();
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty && sw.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 2. Advance fake async time for timers, debounces, and animations
    int pumpedMs = 0;
    while (pumpedMs < duration.inMilliseconds) {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 50));
      pumpedMs += 50;
    }
    await tester.pump();
  }

  setUpAll(() async {
    harness = EPlayerTestHarness();
    await harness.setUp();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  setUp(() async {
    tempRoot = harness.createTempDirectory('browser_ui_root_');

    // Create a subfolder with files
    final subDir = Directory(p.join(tempRoot.path, 'SciFi'));
    await subDir.create();
    await harness.createMockVideoFile(subDir, 'matrix.mp4');
    await harness.createMockVideoFile(subDir, 'alien.mkv');

    // Create a file in root
    await harness.createMockVideoFile(tempRoot, 'intro.mp4');

    final dbPath = '${tempRoot.path}/test_ui_db.db';
    final dbHelper = MediaLibraryDatabase.withCustomPath(dbPath);
    final db = await dbHelper.database;
    final repo = SqliteMediaLibraryRepository(database: db);
    final queue = SqliteTaskQueueRepository(database: db);

    coordinator = AutoRescanCoordinator(
      repository: repo,
      taskQueue: queue,
      periodicRescanInterval: Duration.zero,
    );
    await coordinator.initializeLibrary();
  });

  tearDown(() async {
    coordinator.dispose();
  });

  group('FileBrowserScreen Widget UI Tests', () {
    testWidgets('1. Renders FileBrowserScreen with Breadcrumbs, DriveSelector, and Search', (tester) async {
      await tester.pumpWidget(
        harness.wrapWithAppProviders(
          FileBrowserScreen(
            initialPath: tempRoot.path,
            rescanCoordinator: coordinator,
          ),
        ),
      );
      await pumpScreen(tester);

      // Verify Screen Elements
      expect(find.text('File Browser'), findsOneWidget);
      expect(find.byType(DriveSelectorBar), findsOneWidget);
      expect(find.byType(BreadcrumbBar), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify entries rendered in root
      expect(find.text('SciFi'), findsOneWidget);
      expect(find.text('intro.mp4'), findsOneWidget);
    });

    testWidgets('2. Navigates into subdirectory when tapped', (tester) async {
      await tester.pumpWidget(
        harness.wrapWithAppProviders(
          FileBrowserScreen(
            initialPath: tempRoot.path,
            rescanCoordinator: coordinator,
          ),
        ),
      );
      await pumpScreen(tester);

      // Tap on 'SciFi' directory
      await tester.tap(find.text('SciFi'));
      await pumpScreen(tester);

      // Inside SciFi: should see child videos
      expect(find.text('matrix.mp4'), findsOneWidget);
      expect(find.text('alien.mkv'), findsOneWidget);
    });

    testWidgets('3. Filters entries via debounced search input', (tester) async {
      await tester.pumpWidget(
        harness.wrapWithAppProviders(
          FileBrowserScreen(
            initialPath: tempRoot.path,
            rescanCoordinator: coordinator,
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('SciFi'), findsOneWidget);
      expect(find.text('intro.mp4'), findsOneWidget);

      // Type filter for 'intro'
      await tester.enterText(find.byType(TextField), 'intro');
      await pumpScreen(tester, const Duration(milliseconds: 300));

      expect(find.text('intro.mp4'), findsOneWidget);
      expect(find.text('SciFi'), findsNothing);
    });

    testWidgets('4. Long press or info button displays MediaItemDetailsSheet', (tester) async {
      await tester.pumpWidget(
        harness.wrapWithAppProviders(
          FileBrowserScreen(
            initialPath: tempRoot.path,
            rescanCoordinator: coordinator,
          ),
        ),
      );
      await pumpScreen(tester);

      // Tap info icon for 'intro.mp4'
      final infoIcon = find.byIcon(Icons.info_outline_rounded).first;
      await tester.tap(infoIcon);
      await pumpScreen(tester, const Duration(milliseconds: 300));

      // Details Sheet should appear
      expect(find.text('FILE ATTRIBUTES'), findsOneWidget);
      expect(find.text('VIDEO STREAM'), findsOneWidget);
      expect(find.text('AUDIO STREAM'), findsOneWidget);
      expect(find.text('Play Now'), findsOneWidget);

      // Close sheet
      await tester.scrollUntilVisible(find.text('Close'), 150, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Close'));
      await pumpScreen(tester, const Duration(milliseconds: 300));
      expect(find.text('FILE ATTRIBUTES'), findsNothing);
    });

    testWidgets('5. Toggling folder monitor registers directory in Media Library', (tester) async {
      await tester.pumpWidget(
        harness.wrapWithAppProviders(
          FileBrowserScreen(
            initialPath: tempRoot.path,
            rescanCoordinator: coordinator,
          ),
        ),
      );
      await pumpScreen(tester);

      // Find monitor folder icon for SciFi directory
      final addIcon = find.byIcon(Icons.create_new_folder_outlined).first;
      await tester.tap(addIcon);
      await pumpScreen(tester, const Duration(milliseconds: 400));

      // SnackBar confirmation should appear
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Added'), findsOneWidget);
    });
  });
}
