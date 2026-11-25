import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app/core/db/database_helper.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/library/ui/drive_scanner_studio_sheet.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DriveScannerStudioSheet Cyberpunk Widget Tests', () {
    testWidgets('1. Displays detected drives and marks unscanned drives clearly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tempDir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('widget_drive_studio_'),
      );
      expect(tempDir, isNotNull);

      try {
        final provider = await tester.runAsync(() async {
          await DatabaseHelper.instance.clearAll();
          final mediaFile = File(p.join(tempDir!.path, 'clip.mp4'));
          await mediaFile.writeAsBytes([1, 2, 3]);

          await DatabaseHelper.instance.insertOrUpdateItem(MediaItem(
            path: mediaFile.path,
            name: 'clip.mp4',
            parentFolder: tempDir.path,
            sizeBytes: 3,
            lastPlayed: DateTime.now(),
          ));

          final pvd = LibraryProvider();
          await pvd.refreshLibrary();
          return pvd;
        });

        final scannedRoot =
            DriveVolumeInfo.extractDriveRoot(tempDir!.path) ?? r'C:\';
        const unscannedRoot = r'Z:\';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DriveScannerStudioSheet(
                provider: provider,
                overrideDrives: [scannedRoot, unscannedRoot],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Multi-Drive & Storage Studio'), findsOneWidget);
        expect(find.text('2 Drives Detected'), findsOneWidget);
        expect(find.text('1 Scanned'), findsOneWidget);
        expect(find.text('1 Unscanned'), findsOneWidget);

        // Unscanned drive badge
        expect(find.byKey(const Key('drive_status_$unscannedRoot')), findsOneWidget);
        expect(find.text('Not Scanned Yet'), findsOneWidget);

        // Pre-selection should automatically select the unscanned drive (1)
        expect(find.text('Scan Selected (1)'), findsOneWidget);
      } finally {
        await tester.runAsync(() => tempDir!.delete(recursive: true));
      }
    });

    testWidgets('2. Toggle All and Select Unscanned chips update selection count', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = await tester.runAsync(() async {
        await DatabaseHelper.instance.clearAll();
        final pvd = LibraryProvider();
        await pvd.refreshLibrary();
        return pvd;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriveScannerStudioSheet(
              provider: provider,
              overrideDrives: const [r'C:\', r'D:\', r'E:\'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially all 3 are unscanned -> all 3 selected
      expect(find.text('Scan Selected (3)'), findsOneWidget);

      // Tap Toggle All -> deselects all 3
      await tester.tap(find.byKey(const Key('studio_select_all_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Scan Selected (0)'), findsOneWidget);

      // Check single drive D:\
      await tester.tap(find.byKey(const Key(r'drive_checkbox_D:\')));
      await tester.pumpAndSettle();
      expect(find.text('Scan Selected (1)'), findsOneWidget);

      // Tap Select Unscanned -> selects all 3
      await tester.tap(find.byKey(const Key('studio_select_unscanned_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Scan Selected (3)'), findsOneWidget);
    });

    testWidgets('3. Adding custom folder and tapping Scan Selected indexes files across folders', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final customDir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('custom_scan_dir_'),
      );
      expect(customDir, isNotNull);

      try {
        final provider = await tester.runAsync(() async {
          await DatabaseHelper.instance.clearAll();
          await File(p.join(customDir!.path, 'anime_movie.mkv'))
              .writeAsBytes([1, 2, 3, 4]);
          final pvd = LibraryProvider();
          await pvd.refreshLibrary();
          return pvd;
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DriveScannerStudioSheet(
                provider: provider,
                overrideDrives: const [],
                onPickCustomFolder: () async => customDir!.path,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pick custom folder
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('studio_add_folder_btn')));
          await Future.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();

        expect(find.byKey(Key('folder_checkbox_${customDir!.path}')), findsOneWidget);
        expect(find.text('Scan Selected (1)'), findsOneWidget);

        // Execute scan via Studio CTA
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('studio_start_scan_btn')));
          // Wait briefly for SQLite scan batch to complete cleanly on real event loop
          for (int i = 0; i < 20 && provider!.isScanning; i++) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pumpAndSettle();

        expect(provider!.allFiles.length, equals(1));
        expect(provider.allFiles.first.name, equals('anime_movie.mkv'));
      } finally {
        await tester.runAsync(() => customDir!.delete(recursive: true));
      }
    });
  });
}
