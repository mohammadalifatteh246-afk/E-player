import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/network_stream/models/network_share.dart';
import 'package:app/features/network_stream/data/network_media_service.dart';
import 'package:app/features/network_stream/ui/network_browser_view.dart';
import 'package:app/features/network_stream/ui/add_network_share_sheet.dart';

class MockNetworkMediaTransport implements NetworkMediaTransport {
  final Map<String, String> xmlResponses = {};
  final Map<String, String> smbListings = {};

  @override
  Future<String> fetchXml(Uri uri) async {
    return xmlResponses[uri.path] ?? '<DIDL-Lite></DIDL-Lite>';
  }

  @override
  Future<String> fetchSmbListing(NetworkShare share, String path) async {
    return smbListings['${share.id}:$path'] ?? '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkBrowserView & AddNetworkShareSheet Tests', () {
    late NetworkMediaService networkService;
    late MockNetworkMediaTransport transport;

    setUp(() {
      transport = MockNetworkMediaTransport();
      networkService = NetworkMediaService(transport: transport);
    });

    testWidgets('Renders empty state with Add Share button when no shares configured', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkBrowserView(
              service: networkService,
              initialShares: const [],
              onPlayStream: (_, _) {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Local Network & Streams'), findsOneWidget);
      expect(find.text('No network shares configured'), findsOneWidget);
      expect(find.text('Add Network Location'), findsOneWidget);
    });

    testWidgets('Renders configured shares and allows browsing items', (tester) async {
      final sampleShare = NetworkShare(
        id: 'nas_1',
        name: 'Synology NAS',
        protocol: NetworkProtocol.smb,
        host: '192.168.1.50',
        port: 445,
        sharedPath: 'video',
      );

      transport.smbListings['nas_1:'] = '''
D [DIR] Movies
F [104857600] Dune.Part.Two.mkv
''';

      NetworkMediaItem? playedItem;
      String? playedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkBrowserView(
              service: networkService,
              initialShares: [sampleShare],
              onPlayStream: (item, url) {
                playedItem = item;
                playedUrl = url;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Synology NAS'), findsOneWidget);
      expect(find.text('SMB • 192.168.1.50/video'), findsOneWidget);

      // Tap on the share to open folder contents
      await tester.tap(find.text('Synology NAS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Dune.Part.Two.mkv'), findsOneWidget);

      // Tap on video item to trigger playback
      await tester.tap(find.text('Dune.Part.Two.mkv'));
      await tester.pump();

      expect(playedItem?.title, 'Dune.Part.Two.mkv');
      expect(playedUrl, contains('smb://192.168.1.50/video/Dune.Part.Two.mkv'));
    });

    testWidgets('AddNetworkShareSheet allows creating a custom network stream', (tester) async {
      NetworkShare? createdShare;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AddNetworkShareSheet.show(
                    ctx,
                    onShareAdded: (share) {
                      createdShare = share;
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add Network Storage or Stream'), findsOneWidget);

      // Enter stream name and URL
      await tester.enterText(find.byKey(const Key('share_name_input')), 'Live CCTV');
      await tester.enterText(find.byKey(const Key('share_host_input')), 'rtsp://192.168.1.200:554/live');

      await tester.tap(find.text('Save & Connect'));
      await tester.pumpAndSettle();

      expect(createdShare?.name, 'Live CCTV');
      expect(createdShare?.host, '192.168.1.200');
    });
  });
}
