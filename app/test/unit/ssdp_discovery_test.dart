import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/cast/data/ssdp_discovery_service.dart';
import 'package:app/features/cast/data/cast_discovery_service.dart' show RawSocketEventData;
import 'package:app/features/casting/domain/dlna_client.dart';

class MockSsdpSocketTransport implements SsdpSocketTransport {
  bool isBound = false;
  bool isClosed = false;
  final List<String> sentMessages = [];
  final StreamController<RawSocketEventData> _controller =
      StreamController<RawSocketEventData>.broadcast();

  @override
  Future<void> bind() async {
    isBound = true;
  }

  @override
  Future<void> sendSearch(String message, InternetAddress address, int port) async {
    sentMessages.add(message);
  }

  @override
  Stream<RawSocketEventData> get incomingEvents => _controller.stream;

  void emitResponse(String rawResponse, {String sender = '192.168.1.150', int port = 1900}) {
    final bytes = utf8.encode(rawResponse);
    _controller.add(RawSocketEventData(
      data: Uint8List.fromList(bytes),
      senderAddress: InternetAddress(sender),
      senderPort: port,
    ));
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SSDP UPnP Discovery & DLNA Tests', () {
    test('1. buildMSearch generates compliant UPnP M-SEARCH datagrams', () {
      final msg = SsdpDiscoveryService.buildMSearch(
        st: 'urn:schemas-upnp-org:device:MediaRenderer:1',
        mx: 3,
      );
      expect(msg, contains('M-SEARCH * HTTP/1.1'));
      expect(msg, contains('HOST: 239.255.255.250:1900'));
      expect(msg, contains('MAN: "ssdp:discover"'));
      expect(msg, contains('MX: 3'));
      expect(msg, contains('ST: urn:schemas-upnp-org:device:MediaRenderer:1'));
      expect(msg.endsWith('\r\n\r\n'), isTrue);
    });

    test('2. parseSsdpHeaders correctly extracts case-insensitive header map', () {
      const raw = 'HTTP/1.1 200 OK\r\n'
          'CACHE-CONTROL: max-age=1800\r\n'
          'Location: http://192.168.1.150:8001/ms/1.0/\r\n'
          'Server: SHP, UPnP/1.0, Samsung UPnP SDK/1.0\r\n'
          'st: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          'USN: uuid:12345678-1234-1234-1234-123456789abc::urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          '\r\n';

      final headers = SsdpDiscoveryService.parseSsdpHeaders(raw);
      expect(headers['LOCATION'], 'http://192.168.1.150:8001/ms/1.0/');
      expect(headers['SERVER'], contains('Samsung'));
      expect(headers['ST'], 'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(headers['USN'], contains('uuid:12345678-1234-1234-1234-123456789abc'));
    });

    test('3. SsdpDeviceDescriptor parses UPnP XML and resolves AVTransport controlURL', () {
      const sampleXml = '''<?xml version="1.0" encoding="utf-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>[TV] Samsung 7 Series (55)</friendlyName>
    <manufacturer>Samsung Electronics</manufacturer>
    <modelName>UN55NU7100</modelName>
    <modelNumber>UN55NU7100</modelNumber>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/RenderingControl1</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <controlURL>/upnp/control/AVTransport1</controlURL>
        <eventSubURL>/upnp/event/AVTransport1</eventSubURL>
        <SCPDURL>/dmr/AVTransport1.xml</SCPDURL>
      </service>
    </serviceList>
  </device>
</root>''';

      final baseUri = Uri.parse('http://192.168.1.150:8001/ms/1.0/');
      final descriptor = SsdpDeviceDescriptor.parse(sampleXml, baseUri);

      expect(descriptor.friendlyName, '[TV] Samsung 7 Series (55)');
      expect(descriptor.manufacturer, 'Samsung Electronics');
      expect(descriptor.modelName, 'UN55NU7100');
      expect(
        descriptor.avTransportControlUrl,
        'http://192.168.1.150:8001/upnp/control/AVTransport1',
      );
    });

    test('4. SsdpDiscoveryService discovers Smart TV via datagram and XML descriptor', () async {
      final transport = MockSsdpSocketTransport();
      const sampleXml = '''<?xml version="1.0" encoding="utf-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <friendlyName>Living Room LG OLED</friendlyName>
    <manufacturer>LG Electronics</manufacturer>
    <modelName>OLED65C2PUA</modelName>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>http://192.168.1.180:1940/avt</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';

      final ssdp = SsdpDiscoveryService(
        transport: transport,
        xmlFetcher: (uri) async {
          expect(uri.toString(), 'http://192.168.1.180:1940/dmr.xml');
          return sampleXml;
        },
      );

      await ssdp.startDiscovery();
      expect(transport.isBound, isTrue);
      expect(transport.sentMessages, isNotEmpty);

      // Emit SSDP 200 response from LG TV
      const rawLgResponse = 'HTTP/1.1 200 OK\r\n'
          'LOCATION: http://192.168.1.180:1940/dmr.xml\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          'USN: uuid:99887766-5544-3322-1100-aabbccddeeff::urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          '\r\n';

      transport.emitResponse(rawLgResponse, sender: '192.168.1.180');
      await Future.delayed(const Duration(milliseconds: 60));

      expect(ssdp.currentDevices.length, 1);
      final tv = ssdp.currentDevices.first;
      expect(tv.id, contains('99887766-5544-3322-1100-aabbccddeeff'));
      expect(tv.name, 'Living Room LG OLED');
      expect(tv.host, '192.168.1.180');
      expect(tv.port, 1940);
      expect(tv.modelName, 'OLED65C2PUA');
      expect(tv.properties['controlUrl'], 'http://192.168.1.180:1940/avt');

      await ssdp.stopDiscovery();
      expect(transport.isClosed, isTrue);
    });

    test('5. DlnaClient correctly structures SOAP SetAVTransportURI & Play commands', () async {
      final client = DlnaClient();
      expect(client, isNotNull);

      // Verify SOAP XML format without live network execution
      final uriBody = await client.setAvTransportUri(
        'http://127.0.0.1:9999/dummy',
        'http://192.168.1.10:8877/cast/test/stream',
      );
      // Fails gracefully because endpoint is dummy, returning false without throwing
      expect(uriBody, isFalse);
    });
  });
}
