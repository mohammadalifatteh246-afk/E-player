import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/network_stream/models/network_share.dart';
import 'package:app/features/network_stream/data/dlna_service.dart';
import 'package:app/features/network_stream/ui/dlna_server_browser_sheet.dart';

class MockDlnaHttpTransport implements DlnaHttpTransport {
  String? xmlResponse;
  String? soapResponse;

  @override
  Future<String> fetchXml(Uri uri) async {
    return xmlResponse ?? '''
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaServer:1</deviceType>
    <friendlyName>Test Kodi Server</friendlyName>
    <UDN>uuid:kodi-test-server</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:ContentDirectory:1</serviceType>
        <controlURL>/control/ContentDir</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';
  }

  @override
  Future<String> postSoap(Uri uri, String soapAction, String body) async {
    return soapResponse ?? '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
      <Result>&lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"&gt;
        &lt;container id="folder_movies" parentID="0" restricted="1"&gt;
          &lt;dc:title&gt;Sci-Fi Movies&lt;/dc:title&gt;
          &lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;
        &lt;/container&gt;
        &lt;item id="item_bladerunner" parentID="0" restricted="1"&gt;
          &lt;dc:title&gt;Blade_Runner_2049_HDR.mkv&lt;/dc:title&gt;
          &lt;res protocolInfo="http-get:*:video/x-matroska:*" size="3221225472" duration="02:43:20"&gt;http://192.168.1.100:8200/media/bladerunner.mkv&lt;/res&gt;
          &lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;
        &lt;/item&gt;
      &lt;/DIDL-Lite&gt;</Result>
      <NumberReturned>2</NumberReturned>
      <TotalMatches>2</TotalMatches>
    </u:BrowseResponse>
  </s:Body>
</s:Envelope>''';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DLNA / UPnP Server Browser UI Tests (VLC Parity)', () {
    late MockDlnaHttpTransport transport;
    late DlnaService service;

    setUp(() {
      transport = MockDlnaHttpTransport();
      service = DlnaService(transport: transport, includeDemoServers: true);
    });

    testWidgets('1. Renders server list and displays discovered servers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: DlnaServerBrowserSheet(
              dlnaService: service,
              onPlayMediaItem: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DLNA / UPnP Media Servers'), findsOneWidget);
      expect(find.byKey(const Key('dlna_scan_button')), findsOneWidget);
      expect(find.byKey(const Key('dlna_manual_connect_button')), findsOneWidget);
      expect(find.text('Plex Media Server (Living Room)'), findsOneWidget);
      expect(find.text('Synology NAS (DiskStation)'), findsOneWidget);
    });

    testWidgets('2. Selects server, browses folder, and plays stream item', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      NetworkMediaItem? playedItem;
      NetworkMediaItem? enqueuedItem;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: DlnaServerBrowserSheet(
              dlnaService: service,
              onPlayMediaItem: (item) => playedItem = item,
              onEnqueueMediaItem: (item) => enqueuedItem = item,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Plex server tile
      final serverTile = find.byKey(const Key('dlna_server_tile_uuid:plex-media-server-01'));
      expect(serverTile, findsOneWidget);
      await tester.tap(serverTile);
      await tester.pumpAndSettle();

      // Verify folder and media item are listed
      expect(find.text('Sci-Fi Movies'), findsOneWidget);
      expect(find.text('Blade_Runner_2049_HDR.mkv'), findsOneWidget);
      expect(find.textContaining('3.0 GB'), findsOneWidget);

      // Tap enqueue button
      final enqueueBtn = find.byKey(const Key('dlna_enqueue_item_bladerunner'));
      expect(enqueueBtn, findsOneWidget);
      await tester.tap(enqueueBtn);
      await tester.pumpAndSettle();
      expect(enqueuedItem, isNotNull);
      expect(enqueuedItem!.title, equals('Blade_Runner_2049_HDR.mkv'));

      // Tap play button
      final playBtn = find.byKey(const Key('dlna_play_item_bladerunner'));
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();
      expect(playedItem, isNotNull);
      expect(playedItem!.streamUrl, equals('http://192.168.1.100:8200/media/bladerunner.mkv'));
    });

    testWidgets('3. Navigates back from container to server list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: DlnaServerBrowserSheet(
              dlnaService: service,
              onPlayMediaItem: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drill into server
      await tester.tap(find.byKey(const Key('dlna_server_tile_uuid:plex-media-server-01')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dlna_browser_back_button')), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('dlna_browser_back_button')));
      await tester.pumpAndSettle();

      // Verify back on server list
      expect(find.text('Plex Media Server (Living Room)'), findsOneWidget);
    });

    testWidgets('4. Manual connect dialog adds server from URL', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final emptyService = DlnaService(transport: transport, includeDemoServers: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: DlnaServerBrowserSheet(
              dlnaService: emptyService,
              onPlayMediaItem: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No DLNA / UPnP Media Servers Found'), findsOneWidget);

      // Open manual connect
      await tester.tap(find.byKey(const Key('dlna_manual_connect_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dlna_url_input')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dlna_url_input')), 'http://192.168.1.55:8200/desc.xml');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dlna_url_connect_btn')));
      await tester.pumpAndSettle();

      // Should auto-drill into the newly connected Test Kodi Server
      expect(find.text('Test Kodi Server'), findsOneWidget);
      expect(find.text('Sci-Fi Movies'), findsOneWidget);
    });
  });
}
