import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/features/external_launch/data/external_launch_service.dart';
import 'package:app/features/external_launch/domain/external_launch_models.dart';
import 'package:app/main.dart' as app_entry;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExternalLaunchCoordinator Cold & Warm Routing Tests', () {
    testWidgets('1. Warm launch delegates straight to activePlayerHandler without stacking routes', (tester) async {
      ExternalLaunchService.resetForTesting(
        processRunner: (exe, args) async => ProcessResult(0, 1, '', ''),
      );
      final service = ExternalLaunchService.instance;
      await tester.runAsync(() => service.initialize());

      final handled = <ExternalLaunchRequest>[];
      Future<bool> handler(ExternalLaunchRequest req) async {
        handled.add(req);
        return true;
      }

      service.registerActivePlayerHandler(handler);
      addTearDown(() => service.unregisterActivePlayerHandler(handler));

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: app_entry.EPlayerApp.navigatorKey,
          home: const app_entry.ExternalLaunchCoordinator(
            child: Scaffold(body: Text('RootShell')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      service.triggerSimulatedLaunch(r'D:\Videos\sub_track.srt');
      await tester.pumpAndSettle();

      expect(handled.length, 1);
      expect(handled.first.kind, ExternalMediaKind.subtitle);
      expect(handled.first.displayName, 'sub_track.srt');
    });

    testWidgets('2. Orphan subtitle clicked externally without active player shows guidance SnackBar', (tester) async {
      ExternalLaunchService.resetForTesting(
        processRunner: (exe, args) async => ProcessResult(0, 1, '', ''),
      );
      final service = ExternalLaunchService.instance;
      await tester.runAsync(() => service.initialize());

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: app_entry.EPlayerApp.navigatorKey,
          home: const app_entry.ExternalLaunchCoordinator(
            child: Scaffold(body: Text('RootShell')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      service.triggerSimulatedLaunch(r'D:\Subtitles\movie.srt');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Open a video first, then select movie.srt'),
        findsOneWidget,
      );
    });
  });
}
