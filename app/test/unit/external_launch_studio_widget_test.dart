import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/features/external_launch/data/external_launch_service.dart';
import 'package:app/features/external_launch/domain/external_launch_models.dart';
import 'package:app/features/external_launch/ui/external_launch_studio_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExternalLaunchStudioSheet Widget Tests', () {
    testWidgets('1. Renders Studio header, Android/Windows diagnostics pills, and behavior toggles', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ExternalLaunchService.resetForTesting(
        processRunner: (exe, args) async => ProcessResult(0, 1, '', ''),
      );
      final service = ExternalLaunchService.instance;
      await tester.runAsync(() => service.initialize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExternalLaunchStudioSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('External Launch & OS Studio'), findsOneWidget);
      expect(find.byKey(const Key('ext_diag_android')), findsOneWidget);
      expect(find.byKey(const Key('ext_diag_windows')), findsOneWidget);
      expect(find.byKey(const Key('ext_diag_assoc')), findsOneWidget);
      expect(find.byKey(const Key('ext_studio_single_instance_switch')), findsOneWidget);
      expect(find.byKey(const Key('ext_studio_register_btn')), findsOneWidget);
    });

    testWidgets('2. Updating behavior chips and registering Windows associations updates service state', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final registryCalls = <List<String>>[];
      ExternalLaunchService.resetForTesting(
        processRunner: (exe, args) async {
          registryCalls.add(args);
          return ProcessResult(0, 0, '', '');
        },
      );
      final service = ExternalLaunchService.instance;
      await tester.runAsync(() => service.initialize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExternalLaunchStudioSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch warm launch behavior to Enqueue to Playlist
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('ext_behavior_enqueue')));
        await Future.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(service.warmLaunchBehavior, WarmLaunchBehavior.enqueueToPlaylist);

      // Register Windows File Associations via injected HKCU process runner
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('ext_studio_register_btn')));
        await Future.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();

      if (Platform.isWindows) {
        expect(service.windowsFileAssocRegistered, isTrue);
        expect(find.text('Open With: Registered'), findsOneWidget);
        expect(
          registryCalls.any((args) => args.join(' ').contains('Applications\\E-Player.exe')),
          isTrue,
        );
      }
    });

    testWidgets('3. Launch Simulator validates path, emits event, and adds entry to launch log', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ExternalLaunchService.resetForTesting(
        processRunner: (exe, args) async => ProcessResult(0, 1, '', ''),
      );
      final service = ExternalLaunchService.instance;
      await tester.runAsync(() => service.initialize());

      final received = <ExternalLaunchRequest>[];
      final sub = service.launchStream.listen(received.add);
      addTearDown(sub.cancel);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExternalLaunchStudioSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ext_studio_test_input')),
        r'D:\Videos\demo_trailer.mkv',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ext_studio_test_btn')));
      await tester.pumpAndSettle();

      expect(received.length, 1);
      expect(received.first.displayName, 'demo_trailer.mkv');
      expect(find.text('INCOMING LAUNCH LOG'), findsOneWidget);
      expect(find.text('demo_trailer.mkv'), findsOneWidget);
    });
  });
}
