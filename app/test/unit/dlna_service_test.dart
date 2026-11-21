import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/network_stream/models/dlna_models.dart';
import 'package:app/features/network_stream/data/dlna_service.dart';

class MockDlnaHttpTransport implements DlnaHttpTransport {
  String? xmlResponse;
  String? soapResponse;

  @override
  Future<String> fetchXml(Uri uri) async {
    return xmlResponse ?? '';
  }

  @override
  Future<String> postSoap(Uri uri, String soapAction, String body) async {
    return soapResponse ?? '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DLNA / UPnP Media Server Ingestion Tests (VLC Parity)', () {
    test('1. DlnaMediaServer serialization round-trip works accurately', () {
      const server = DlnaMediaServer(
        id: 'uuid:jellyfin-home-srv',
        friendlyName: 'Jellyfin Media Server',
        host: '192.168.1.200',
        port: 8096,
        locationUrl: 'http://192.168.1.200:8096/dlna/desc',
        contentDirectoryControlUrl: 'http://192.168.1.200:8096/dlna/control/content',
        manufacturer: 'Jellyfin',
        modelName: 'Jellyfin 10.9',
      );

      final json = server.toJson();
      expect(json['id'], equals('uuid:jellyfin-home-srv'));
      expect(json['friendlyName'], equals('Jellyfin Media Server'));
      expect(json['host'], equals('192.168.1.200'));
      expect(json['port'], equals(8096));

      final restored = DlnaMediaServer.fromJson(json);
      expect(restored.id, equals(server.id));
      expect(restored.friendlyName, equals(server.friendlyName));
      expect(restored.contentDirectoryControlUrl, equals(server.contentDirectoryControlUrl));
      expect(restored.manufacturer, equals('Jellyfin'));
    });

    test('2. buildMSearchDatagram creates valid UPnP MediaServer M-SEARCH datagram', () {
      final service = DlnaService();
      final msg = service.buildMSearchDatagram();

      expect(msg, contains('M-SEARCH * HTTP/1.1'));
      expect(msg, contains('HOST: 239.255.255.250:1900'));
      expect(msg, contains('MAN: "ssdp:discover"'));
      expect(msg, contains('ST: urn:schemas-upnp-org:device:MediaServer:1'));
    });

    test('3. parseSsdpHeaders parses UDP response datagram headers cleanly', () {
      final service = DlnaService();
      const raw = 'HTTP/1.1 200 OK\r\n'
          'CACHE-CONTROL: max-age=1800\r\n'
          'LOCATION: http://192.168.1.80:8200/rootDesc.xml\r\n'
          'SERVER: Linux/5.4 UPnP/1.0 MiniDLNA/1.3.0\r\n'
          'ST: urn:schemas-upnp-org:device:MediaServer:1\r\n'
          'USN: uuid:12345678-abcd-1234::urn:schemas-upnp-org:device:MediaServer:1\r\n';

      final headers = service.parseSsdpHeaders(raw);
      expect(headers['LOCATION'], equals('http://192.168.1.80:8200/rootDesc.xml'));
      expect(headers['ST'], equals('urn:schemas-upnp-org:device:MediaServer:1'));
      expect(headers['SERVER'], contains('MiniDLNA'));
    });

    test('4. parseDeviceDescriptor extracts ContentDirectory controlURL from UPnP XML', () {
      final service = DlnaService();
      const descriptorXml = '''
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaServer:1</deviceType>
    <friendlyName>Synology DiskStation DS920+</friendlyName>
    <manufacturer>Synology Inc.</manufacturer>
    <modelName>DiskStation</modelName>
    <UDN>uuid:synology-ds920-upnp-media</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:ContentDirectory:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:ContentDirectory</serviceId>
        <controlURL>/upnp/control/ContentDir</controlURL>
        <eventSubURL>/upnp/event/ContentDir</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
        <controlURL>/upnp/control/ConnMgr</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';

      final server = service.parseDeviceDescriptor(
        descriptorXml,
        Uri.parse('http://192.168.1.150:50001/desc/device.xml'),
      );

      expect(server, isNotNull);
      expect(server!.friendlyName, equals('Synology DiskStation DS920+'));
      expect(server.manufacturer, equals('Synology Inc.'));
      expect(server.contentDirectoryControlUrl, equals('http://192.168.1.150:50001/upnp/control/ContentDir'));
    });

    test('5. buildBrowseSoapBody creates compliant ContentDirectory:1 #Browse XML envelope', () {
      final service = DlnaService();
      final soap = service.buildBrowseSoapBody(
        objectId: '0\$1\$4',
        startIndex: 0,
        count: 50,
      );

      expect(soap, contains('<u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">'));
      expect(soap, contains('<ObjectID>0\$1\$4</ObjectID>'));
      expect(soap, contains('<BrowseFlag>BrowseDirectChildren</BrowseFlag>'));
      expect(soap, contains('<RequestedCount>50</RequestedCount>'));
    });

    test('6. browseContainer fetches and parses DIDL-Lite folders and streamable items', () async {
      final mockTransport = MockDlnaHttpTransport();
      mockTransport.soapResponse = '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
      <Result>&lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"&gt;
        &lt;container id="folder_01" parentID="0" restricted="1"&gt;
          &lt;dc:title&gt;Cyberpunk Anime Collection&lt;/dc:title&gt;
          &lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;
        &lt;/container&gt;
        &lt;item id="video_01" parentID="0" restricted="1"&gt;
          &lt;dc:title&gt;Edgerunners_Ep01_4K.mkv&lt;/dc:title&gt;
          &lt;res protocolInfo="http-get:*:video/x-matroska:*" size="2147483648" duration="00:24:30"&gt;http://192.168.1.120:32469/stream/video_01.mkv&lt;/res&gt;
          &lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;
        &lt;/item&gt;
      &lt;/DIDL-Lite&gt;</Result>
      <NumberReturned>2</NumberReturned>
      <TotalMatches>2</TotalMatches>
    </u:BrowseResponse>
  </s:Body>
</s:Envelope>''';

      final service = DlnaService(transport: mockTransport);
      const server = DlnaMediaServer(
        id: 'uuid:plex-01',
        friendlyName: 'Plex Server',
        host: '192.168.1.120',
        port: 32469,
        locationUrl: 'http://192.168.1.120:32469/desc.xml',
        contentDirectoryControlUrl: 'http://192.168.1.120:32469/ctl/ContentDir',
      );

      final result = await service.browseContainer(server, objectId: '0');

      expect(result.items.length, equals(2));
      expect(result.items[0].isDirectory, isTrue);
      expect(result.items[0].title, equals('Cyberpunk Anime Collection'));

      expect(result.items[1].isDirectory, isFalse);
      expect(result.items[1].title, equals('Edgerunners_Ep01_4K.mkv'));
      expect(result.items[1].streamUrl, equals('http://192.168.1.120:32469/stream/video_01.mkv'));
      expect(result.items[1].duration, equals(const Duration(minutes: 24, seconds: 30)));
      expect(result.items[1].sizeBytes, equals(2147483648));
    });
  });
}
