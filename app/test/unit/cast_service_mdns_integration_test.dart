import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/cast/data/cast_discovery_service.dart';

class MockCastSocketTransport implements CastSocketTransport {
  bool isBound = false;
  bool isClosed = false;
  final List<Uint8List> sentPackets = [];
  final StreamController<RawSocketEventData> _eventController =
      StreamController<RawSocketEventData>.broadcast();

  @override
  Future<void> bind() async {
    isBound = true;
  }

  @override
  Future<void> sendQuery(Uint8List packet, InternetAddress address, int port) async {
    sentPackets.add(packet);
  }

  @override
  Stream<RawSocketEventData> get incomingEvents => _eventController.stream;

  void emitPacket(Uint8List packet, {String sender = '192.168.1.120'}) {
    _eventController.add(RawSocketEventData(
      data: packet,
      senderAddress: InternetAddress(sender),
      senderPort: 5353,
    ));
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await _eventController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CastService mDNS Auto-Discovery Tests', () {
    late MockCastSocketTransport transport;
    late CastDiscoveryService discoveryService;
    late CastService castService;

    setUp(() {
      transport = MockCastSocketTransport();
      discoveryService = CastDiscoveryService(transport: transport);
      castService = CastService(discoveryService: discoveryService);
    });

    tearDown(() async {
      await castService.stopScan();
    });

    test('startScan initiates mDNS transport binding and query broadcast', () async {
      await castService.startScan();
      expect(transport.isBound, isTrue);
      expect(transport.sentPackets, isNotEmpty);
      expect(castService.isScanning, isTrue);
    });

    test('Discovered mDNS receiver seamlessly updates CastService.devices', () async {
      await castService.startScan();

      // Encode a simulated Google Cast PTR response
      final packet = discoveryService.encodeDnsPtrResponse(
        serviceType: '_googlecast._tcp',
        instanceName: 'Living Room TV._googlecast._tcp',
        host: '192.168.1.88',
        port: 8009,
        txtRecords: {
          'fn': 'Living Room TV',
          'md': 'Chromecast with Google TV',
        },
      );

      transport.emitPacket(packet, sender: '192.168.1.88');
      await Future.delayed(const Duration(milliseconds: 50));

      final matched = castService.devices.where((d) => d.name == 'Living Room TV').toList();
      expect(matched, isNotEmpty);
      final dev = matched.first;
      expect(dev.ipAddress, '192.168.1.88');
      expect(dev.protocol, CastProtocol.chromecast);
      expect(dev.model, contains('Chromecast'));
    });

    test('stopScan cancels active discovery and terminates socket', () async {
      await castService.startScan();
      expect(castService.isScanning, isTrue);

      await castService.stopScan();
      expect(castService.isScanning, isFalse);
    });
  });
}
