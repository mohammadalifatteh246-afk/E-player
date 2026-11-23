import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/network_stream/domain/smb_models.dart';
import 'package:app/features/network_stream/data/smb_service.dart';
import 'package:app/features/network_stream/ui/smb_share_browser_sheet.dart';

void main() {
  group('SmbShareBrowserSheet Widget Tests (VLC smb2.c & dsm Parity)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('1. Renders title, inputs, anonymous switch, and Connect button', (tester) async {
      final service = SmbShareService(prefs: prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmbShareBrowserSheet(
              smbService: service,
              onPlayMrl: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SMB / Windows Network Share'), findsOneWidget);
      expect(find.byKey(const Key('smb_host_input')), findsOneWidget);
      expect(find.byKey(const Key('smb_port_input')), findsOneWidget);
      expect(find.byKey(const Key('smb_share_input')), findsOneWidget);
      expect(find.byKey(const Key('smb_path_input')), findsOneWidget);
      expect(find.byKey(const Key('smb_anonymous_switch')), findsOneWidget);
      expect(find.byKey(const Key('smb_connect_button')), findsOneWidget);
    });

    testWidgets('2. Entering host, share, credentials updates MRL preview with password masking', (tester) async {
      final service = SmbShareService(prefs: prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmbShareBrowserSheet(
              smbService: service,
              onPlayMrl: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('smb_host_input')), '192.168.1.150');
      await tester.enterText(find.byKey(const Key('smb_share_input')), 'Movies');
      await tester.enterText(find.byKey(const Key('smb_path_input')), 'SciFi/matrix.mkv');
      await tester.enterText(find.byKey(const Key('smb_domain_input')), 'WORKGROUP');
      await tester.enterText(find.byKey(const Key('smb_user_input')), 'neo');
      await tester.enterText(find.byKey(const Key('smb_pass_input')), 'secret777');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('smb_mrl_preview')), findsOneWidget);
      final previewText = tester.widget<Text>(find.byKey(const Key('smb_mrl_preview'))).data;
      expect(previewText, 'smb://WORKGROUP;neo:****@192.168.1.150/Movies/SciFi/matrix.mkv');
    });

    testWidgets('3. Clicking probe button invokes probeHost and renders status badge', (tester) async {
      Future<Socket> mockConnector(dynamic host, int port, {Duration? timeout}) async {
        return _MockSocket();
      }

      final service = SmbShareService(prefs: prefs, socketConnector: mockConnector);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmbShareBrowserSheet(
              smbService: service,
              onPlayMrl: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('smb_host_input')), '192.168.1.100');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('smb_probe_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('smb_probe_status')), findsOneWidget);
      expect(find.text('Reachable (Port Open)'), findsOneWidget);
    });

    testWidgets('4. Submitting Connect & Play invokes onPlayMrl and saves recent share', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = SmbShareService(prefs: prefs);
      String? playedMrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmbShareBrowserSheet(
              smbService: service,
              onPlayMrl: (mrl) => playedMrl = mrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('smb_host_input')), '192.168.1.200');
      await tester.enterText(find.byKey(const Key('smb_share_input')), 'Public');
      await tester.pumpAndSettle();

      final connectBtn = find.byKey(const Key('smb_connect_button'));
      await tester.ensureVisible(connectBtn);
      await tester.tap(connectBtn);
      await tester.pumpAndSettle();

      expect(playedMrl, 'smb://192.168.1.200/Public');
      expect(service.recentShares.length, 1);
      expect(service.recentShares.first.config.host, '192.168.1.200');
    });

    testWidgets('5. Selecting a recent share chip populates form fields', (tester) async {
      final service = SmbShareService(prefs: prefs);
      await service.saveRecentShare(const SmbShareConfig(
        host: '10.0.0.99',
        shareName: 'Downloads',
        subPath: 'video.mp4',
        domain: 'MYLAN',
        username: 'bob',
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmbShareBrowserSheet(
              smbService: service,
              onPlayMrl: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chip exists
      final chipKey = const Key('smb_recent_10.0.0.99_Downloads');
      expect(find.byKey(chipKey), findsOneWidget);

      // Change host field to something else
      await tester.enterText(find.byKey(const Key('smb_host_input')), 'different.host');
      await tester.pumpAndSettle();

      // Tap chip to restore
      await tester.tap(find.byKey(chipKey));
      await tester.pumpAndSettle();

      expect(find.text('10.0.0.99'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('video.mp4'), findsOneWidget);
    });
  });
}

class _MockSocket implements Socket {
  @override
  void destroy() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
