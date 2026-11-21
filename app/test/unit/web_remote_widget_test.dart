import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/web_remote/data/web_remote_service.dart';
import 'package:app/features/web_remote/ui/web_remote_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WebRemoteService service;

  setUp(() {
    HttpOverrides.global = null;
    service = WebRemoteService();
    service.overrideIp = '127.0.0.1';
    service.defaultPort = 9884;
  });

  tearDown(() async {
    await service.stop();
    service.dispose();
  });

  group('WebRemoteSheet Widget Tests (VLC Parity)', () {
    testWidgets('1. Displays offline status when server is stopped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebRemoteSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Web Remote Control'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('Server stopped'), findsOneWidget);
      expect(find.byKey(const Key('web_remote_qr_container')), findsNothing);
    });

    testWidgets('2. Displays QR Code, Wi-Fi URL and online badge when server is active', (tester) async {
      await tester.runAsync(() async {
        await service.start(port: 9880);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebRemoteSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Active on port ${service.port}'), findsOneWidget);
      expect(find.byKey(const Key('web_remote_qr_container')), findsOneWidget);
      expect(find.byKey(const Key('web_remote_copy_button')), findsOneWidget);

      // Verify URL is shown
      expect(find.text(service.url), findsOneWidget);

      await tester.runAsync(() async {
        await service.stop();
      });
      await tester.pumpAndSettle();
    });

    testWidgets('3. Toggle switch starts and stops server dynamically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebRemoteSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.isRunning, isFalse);
      expect(find.text('OFFLINE'), findsOneWidget);

      final switchFinder = find.byKey(const Key('web_remote_toggle_switch'));

      // Tap toggle switch to turn ON inside real async zone
      await tester.runAsync(() async {
        await tester.tap(switchFinder);
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(service.isRunning, isTrue);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.byKey(const Key('web_remote_qr_container')), findsOneWidget);

      // Tap toggle switch to turn OFF inside real async zone
      await tester.runAsync(() async {
        await tester.tap(switchFinder);
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(service.isRunning, isFalse);
      expect(find.text('OFFLINE'), findsOneWidget);
    });
  });
}
