import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/telnet_rc/domain/telnet_rc_models.dart';
import 'package:app/features/telnet_rc/data/telnet_rc_service.dart';
import 'package:app/features/telnet_rc/ui/telnet_rc_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TelnetRcSheet Widget Tests (VLC rc.c Parity)', () {
    late TelnetRcService service;

    setUp(() {
      service = TelnetRcService();
      service.statusProvider = () => const TelnetPlayerSnapshot(
            isPlaying: true,
            title: 'Blade_Runner_2049.mkv',
            position: Duration(minutes: 45),
            duration: Duration(minutes: 163),
            volume: 140.0,
          );
    });

    tearDown(() async {
      await service.stop();
      service.dispose();
    });

    testWidgets('1. Renders header, status badge, connection command, and empty terminal', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelnetRcSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLI REMOTE CONTROL'), findsOneWidget);
      expect(find.textContaining('OFFLINE • Port 4212'), findsOneWidget);
      expect(find.byKey(const Key('telnet_server_toggle')), findsOneWidget);
      expect(find.textContaining('Start server to connect'), findsOneWidget);
      expect(find.byKey(const Key('telnet_cmd_input')), findsOneWidget);
      expect(find.byKey(const Key('telnet_cmd_send_button')), findsOneWidget);
    });

    testWidgets('2. Toggle switch starts and stops TCP socket server dynamically', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelnetRcSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.isRunning, isFalse);
      expect(find.textContaining('OFFLINE'), findsOneWidget);

      final switchFinder = find.byKey(const Key('telnet_server_toggle'));

      // Tap toggle switch to turn ON inside real async zone
      await tester.runAsync(() async {
        await tester.tap(switchFinder);
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(service.isRunning, isTrue);
      expect(find.textContaining('ONLINE • 127.0.0.1:'), findsOneWidget);
      expect(find.textContaining('nc 127.0.0.1'), findsOneWidget);

      // Tap toggle switch to turn OFF inside real async zone
      await tester.runAsync(() async {
        await tester.tap(switchFinder);
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(service.isRunning, isFalse);
      expect(find.textContaining('OFFLINE'), findsOneWidget);
    });

    testWidgets('3. Submitting CLI command in input bar logs command and reply in terminal', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelnetRcSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter status command in input
      final inputFinder = find.byKey(const Key('telnet_cmd_input'));
      await tester.enterText(inputFinder, 'status');
      await tester.tap(find.byKey(const Key('telnet_cmd_send_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Terminal should now contain incoming command and outgoing response
      expect(find.textContaining('> status'), findsOneWidget);
      expect(find.textContaining('( title Blade_Runner_2049.mkv )'), findsOneWidget);
    });

    testWidgets('4. Quick command chips execute commands and clear log button empties terminal', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelnetRcSheet(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap quick chip 'volume 150'
      final chipFinder = find.byKey(const Key('quick_chip_volume 150'));
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('> volume 150'), findsOneWidget);
      expect(find.textContaining('volume: 150%'), findsOneWidget);

      // Tap Clear Log button
      final clearButton = find.byKey(const Key('clear_terminal_logs_button'));
      await tester.tap(clearButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(service.logs.isEmpty, isTrue);
    });
  });
}
