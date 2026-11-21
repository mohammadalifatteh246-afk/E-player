import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/cast_device.dart';
import 'ssdp_discovery_service.dart';

/// Transport interface for sending and receiving raw mDNS datagrams.
abstract class CastSocketTransport {
  Future<void> bind();
  Future<void> sendQuery(Uint8List packet, InternetAddress address, int port);
  Stream<RawSocketEventData> get incomingEvents;
  Future<void> close();
}

/// Event data emitted by CastSocketTransport.
class RawSocketEventData {
  final Uint8List data;
  final InternetAddress senderAddress;
  final int senderPort;

  const RawSocketEventData({
    required this.data,
    required this.senderAddress,
    required this.senderPort,
  });
}

/// Default UDP multicast socket transport for mDNS discovery.
class DefaultCastSocketTransport implements CastSocketTransport {
  RawDatagramSocket? _socket;
  final StreamController<RawSocketEventData> _controller = StreamController<RawSocketEventData>.broadcast();

  @override
  Future<void> bind() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true, reusePort: false);
      _socket?.broadcastEnabled = true;
      _socket?.multicastHops = 255;
      _socket?.multicastLoopback = false;

      final mDnsGroup = InternetAddress('224.0.0.251');
      try {
        _socket?.joinMulticast(mDnsGroup);
      } catch (_) {
        // Platform or interface limitation joining multicast group
      }

      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          try {
            _socket?.joinMulticast(mDnsGroup, iface);
          } catch (_) {
            // Ignore non-multicast or unjoinable interface
          }
        }
      } catch (_) {}

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _controller.add(RawSocketEventData(
              data: datagram.data,
              senderAddress: datagram.address,
              senderPort: datagram.port,
            ));
          }
        }
      });
    } catch (_) {
      // Socket bind failed
    }
  }

  @override
  Future<void> sendQuery(Uint8List packet, InternetAddress address, int port) async {
    _socket?.send(packet, address, port);
  }

  @override
  Stream<RawSocketEventData> get incomingEvents => _controller.stream;

  @override
  Future<void> close() async {
    try {
      _socket?.close();
    } catch (_) {}
    await _controller.close();
  }
}

/// Service that discovers wireless casting endpoints (Chromecast, DLNA) using mDNS (RFC 6762 / RFC 6763).
class CastDiscoveryService {
  static const String kChromecastService = '_googlecast._tcp';
  static const String kDlnaRendererService = '_render._tcp';
  static const String kUpnpMediaRendererService = '_upnp._tcp';
  static const String kAirplayService = '_airplay._tcp';

  static const List<String> kDefaultServiceTypes = [
    kChromecastService,
    kDlnaRendererService,
    kUpnpMediaRendererService,
    kAirplayService,
  ];

  final CastSocketTransport transport;
  final SsdpDiscoveryService? ssdpService;
  final Map<String, CastDevice> _devices = {};
  final StreamController<List<CastDevice>> _devicesController = StreamController<List<CastDevice>>.broadcast();
  StreamSubscription<RawSocketEventData>? _subscription;
  StreamSubscription<List<CastDevice>>? _ssdpSubscription;
  Timer? _queryTimer;
  bool _isDiscovering = false;

  CastDiscoveryService({
    CastSocketTransport? transport,
    SsdpDiscoveryService? ssdpService,
  })  : transport = transport ?? DefaultCastSocketTransport(),
        ssdpService = ssdpService ?? (transport != null ? null : SsdpDiscoveryService());

  bool get isDiscovering => _isDiscovering;

  List<CastDevice> get currentDevices => List.unmodifiable(_devices.values.toList());

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;

  /// Starts mDNS and SSDP device discovery for the specified [serviceTypes].
  Future<void> startDiscovery({
    Duration period = const Duration(seconds: 4),
    List<String> serviceTypes = kDefaultServiceTypes,
  }) async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    await transport.bind();
    _subscription = transport.incomingEvents.listen((event) {
      handleIncomingPacket(event.data, fallbackHost: event.senderAddress.address);
    });

    try {
      await ssdpService?.startDiscovery();
      _ssdpSubscription = ssdpService?.devicesStream.listen((ssdpDevices) {
        for (final device in ssdpDevices) {
          addOrUpdateDevice(device);
        }
      });
    } catch (_) {}

    // Send initial queries
    await _broadcastQueries(serviceTypes);

    // Periodically re-query
    _queryTimer = Timer.periodic(period, (_) async {
      if (_isDiscovering) {
        await _broadcastQueries(serviceTypes);
      }
    });
  }

  /// Stops discovery and closes sockets.
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _queryTimer?.cancel();
    _queryTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _ssdpSubscription?.cancel();
    _ssdpSubscription = null;
    try {
      await ssdpService?.stopDiscovery();
    } catch (_) {}
    await transport.close();
  }

  /// Manually registers or updates a [device] in the discovery repository.
  void addOrUpdateDevice(CastDevice device) {
    _devices[device.id] = device;
    _devicesController.add(currentDevices);
  }

  /// Removes a device by [deviceId].
  void removeDevice(String deviceId) {
    if (_devices.remove(deviceId) != null) {
      _devicesController.add(currentDevices);
    }
  }

  /// Clears all discovered devices.
  void clearDevices() {
    _devices.clear();
    try {
      ssdpService?.clearDevices();
    } catch (_) {}
    _devicesController.add(currentDevices);
  }

  /// Disposes controller and discovery resources.
  Future<void> dispose() async {
    await stopDiscovery();
    try {
      await ssdpService?.dispose();
    } catch (_) {}
    await _devicesController.close();
  }

  Future<void> _broadcastQueries(List<String> serviceTypes) async {
    final multicastAddress = InternetAddress('224.0.0.251');
    for (final service in serviceTypes) {
      final fqdn = service.endsWith('.local') ? service : '$service.local';
      final packet = encodeDnsPtrQuery(fqdn);
      await transport.sendQuery(packet, multicastAddress, 5353);
    }
  }

  /// Builds a DNS PTR query packet for [serviceFqdn].
  /// By default sets the RFC 6762 QU (unicast-response) bit in QCLASS (0x8001),
  /// instructing responders to send unicast responses to our ephemeral UDP port.
  static Uint8List encodeDnsPtrQuery(String serviceFqdn, {bool unicastResponse = true}) {
    final buffer = BytesBuilder();

    // DNS Header
    buffer.add([
      0x00, 0x00, // ID: 0
      0x00, 0x00, // Flags: Standard Query
      0x00, 0x01, // QDCOUNT: 1
      0x00, 0x00, // ANCOUNT: 0
      0x00, 0x00, // NSCOUNT: 0
      0x00, 0x00, // ARCOUNT: 0
    ]);

    // Question Section: QNAME
    final labels = serviceFqdn.split('.');
    for (final label in labels) {
      if (label.isNotEmpty) {
        final bytes = utf8.encode(label);
        buffer.addByte(bytes.length);
        buffer.add(bytes);
      }
    }
    buffer.addByte(0x00); // Root label null terminator

    // QTYPE: PTR (12)
    buffer.add([0x00, 0x0C]);

    // QCLASS: IN (1) with RFC 6762 Section 5.4 QU bit (0x8001)
    final qclass = unicastResponse ? 0x8001 : 0x0001;
    buffer.add([(qclass >> 8) & 0xFF, qclass & 0xFF]);

    return buffer.toBytes();
  }

  /// Assembles a synthetic RFC 6762 / 6763 mDNS response datagram with PTR, SRV, TXT, and A records.
  Uint8List encodeDnsPtrResponse({
    required String serviceType,
    required String instanceName,
    required String host,
    required int port,
    Map<String, String> txtRecords = const {},
  }) {
    final buffer = BytesBuilder();

    void addDnsLabel(BytesBuilder b, String label) {
      final bytes = utf8.encode(label);
      b.addByte(bytes.length);
      b.add(bytes);
    }

    void writeFqdn(BytesBuilder b, String fqdn) {
      final labels = fqdn.split('.');
      for (final l in labels) {
        if (l.isNotEmpty) addDnsLabel(b, l);
      }
      b.addByte(0);
    }

    // Header: ID=0, Flags=0x8400 (Authoritative Response), QD=0, AN=4, NS=0, AR=0
    buffer.add([
      0x00, 0x00,
      0x84, 0x00,
      0x00, 0x00,
      0x00, 0x04,
      0x00, 0x00,
      0x00, 0x00,
    ]);

    final cleanService = serviceType.endsWith('.local') ? serviceType : '$serviceType.local';
    final cleanInstance = instanceName.endsWith('.local') ? instanceName : '$instanceName.local';
    final cleanHost = host.endsWith('.local') ? host : '$host.local';

    // Record 1: PTR Record
    writeFqdn(buffer, cleanService);
    buffer.add([0x00, 0x0C]); // TYPE: PTR
    buffer.add([0x00, 0x01]); // CLASS: IN
    buffer.add([0x00, 0x00, 0x00, 0x78]); // TTL: 120s
    final ptrTarget = BytesBuilder();
    writeFqdn(ptrTarget, cleanInstance);
    final ptrBytes = ptrTarget.toBytes();
    buffer.add([0x00, ptrBytes.length]);
    buffer.add(ptrBytes);

    // Record 2: SRV Record
    writeFqdn(buffer, cleanInstance);
    buffer.add([0x00, 0x21]); // TYPE: SRV (33)
    buffer.add([0x00, 0x01]); // CLASS: IN
    buffer.add([0x00, 0x00, 0x00, 0x78]);
    final srvTarget = BytesBuilder();
    srvTarget.add([0x00, 0x00]); // Priority
    srvTarget.add([0x00, 0x00]); // Weight
    srvTarget.add([(port >> 8) & 0xFF, port & 0xFF]); // Port
    writeFqdn(srvTarget, cleanHost);
    final srvBytes = srvTarget.toBytes();
    buffer.add([0x00, srvBytes.length]);
    buffer.add(srvBytes);

    // Record 3: TXT Record
    writeFqdn(buffer, cleanInstance);
    buffer.add([0x00, 0x10]); // TYPE: TXT (16)
    buffer.add([0x00, 0x01]); // CLASS: IN
    buffer.add([0x00, 0x00, 0x00, 0x78]);
    final txtTarget = BytesBuilder();
    for (final entry in txtRecords.entries) {
      final prop = utf8.encode('${entry.key}=${entry.value}');
      txtTarget.addByte(prop.length);
      txtTarget.add(prop);
    }
    final txtBytes = txtTarget.toBytes();
    buffer.add([0x00, txtBytes.length]);
    buffer.add(txtBytes);

    // Record 4: A Record
    writeFqdn(buffer, cleanHost);
    buffer.add([0x00, 0x01]); // TYPE: A (1)
    buffer.add([0x00, 0x01]); // CLASS: IN
    buffer.add([0x00, 0x00, 0x00, 0x78]);
    final ipParts = host.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    if (ipParts.length == 4) {
      buffer.add([0x00, 0x04]);
      buffer.add(ipParts);
    } else {
      buffer.add([0x00, 0x04, 127, 0, 0, 1]);
    }

    return buffer.toBytes();
  }

  /// Parses an incoming mDNS response datagram and updates the device list.
  List<CastDevice> handleIncomingPacket(Uint8List packetBytes, {String? fallbackHost}) {
    if (packetBytes.length < 12) return [];

    try {
      final byteData = ByteData.view(packetBytes.buffer, packetBytes.offsetInBytes, packetBytes.lengthInBytes);

      final flags = byteData.getUint16(2);
      final isResponse = (flags & 0x8000) != 0;
      if (!isResponse) return [];

      final qdCount = byteData.getUint16(4);
      final anCount = byteData.getUint16(6);
      final nsCount = byteData.getUint16(8);
      final arCount = byteData.getUint16(10);

      var offset = 12;

      // Skip question records
      for (var i = 0; i < qdCount; i++) {
        offset = _skipDnsName(packetBytes, offset);
        offset += 4; // QTYPE (2) + QCLASS (2)
        if (offset > packetBytes.length) return [];
      }

      final totalRecords = anCount + nsCount + arCount;
      final ptrRecords = <String, String>{}; // serviceType -> instanceName
      final srvRecords = <String, _SrvRecord>{}; // instanceName -> SrvRecord
      final txtRecords = <String, Map<String, String>>{}; // instanceName -> properties
      final aRecords = <String, String>{}; // hostName -> ipv4

      for (var i = 0; i < totalRecords; i++) {
        if (offset >= packetBytes.length) break;

        final nameResult = _readDnsName(packetBytes, offset);
        final recordName = nameResult.name;
        offset = nameResult.nextOffset;

        if (offset + 10 > packetBytes.length) break;

        final type = byteData.getUint16(offset);
        final rdLength = byteData.getUint16(offset + 8);
        offset += 10;

        if (offset + rdLength > packetBytes.length) break;

        final rdataEnd = offset + rdLength;

        if (type == 12) {
          // PTR Record
          final ptrName = _readDnsName(packetBytes, offset).name;
          ptrRecords[recordName] = ptrName;
        } else if (type == 33) {
          // SRV Record: Priority (2), Weight (2), Port (2), Target
          if (rdLength >= 6) {
            final port = byteData.getUint16(offset + 4);
            final target = _readDnsName(packetBytes, offset + 6).name;
            srvRecords[recordName] = _SrvRecord(port: port, target: target);
          }
        } else if (type == 16) {
          // TXT Record
          final props = _parseTxtRecord(packetBytes, offset, rdLength);
          txtRecords[recordName] = props;
        } else if (type == 1) {
          // A Record: IPv4 address (4 bytes)
          if (rdLength == 4) {
            final ip = '${packetBytes[offset]}.${packetBytes[offset + 1]}.${packetBytes[offset + 2]}.${packetBytes[offset + 3]}';
            aRecords[recordName] = ip;
          }
        }

        offset = rdataEnd;
      }

      // Correlate records into CastDevices
      final discovered = <CastDevice>[];

      // Identify service instances
      final instances = <String>{...srvRecords.keys, ...txtRecords.keys, ...ptrRecords.values};

      for (final instance in instances) {
        // Determine service type and protocol
        CastProtocol protocol = CastProtocol.chromecast;
        String serviceType = kChromecastService;

        if (instance.contains('_googlecast')) {
          protocol = CastProtocol.chromecast;
          serviceType = kChromecastService;
        } else if (instance.contains('_render') || instance.contains('_upnp')) {
          protocol = CastProtocol.dlnaRenderer;
          serviceType = kDlnaRendererService;
        } else if (instance.contains('_airplay')) {
          protocol = CastProtocol.airplay;
          serviceType = kAirplayService;
        }

        final srv = srvRecords[instance];
        final txt = txtRecords[instance] ?? {};

        final port = srv?.port ?? CastDevice.defaultPortFor(protocol);
        final targetHost = srv?.target;
        final resolvedIp = (targetHost != null ? aRecords[targetHost] : null) ??
            aRecords.values.firstOrNull ??
            fallbackHost ??
            '127.0.0.1';

        // Extract friendly name
        String name = txt['fn'] ?? txt['friendlyName'] ?? txt['name'] ?? '';
        if (name.isEmpty) {
          final instanceLabels = instance.split('.');
          name = instanceLabels.isNotEmpty ? instanceLabels.first : 'Cast Device';
        }

        // Extract model name
        final model = txt['md'] ?? txt['modelName'] ?? txt['model'];

        // Unique ID
        final id = txt['id'] ?? '$resolvedIp:$port';

        final device = CastDevice(
          id: id,
          name: name,
          host: resolvedIp,
          port: port,
          protocol: protocol,
          modelName: model,
          serviceType: serviceType,
          properties: txt,
          state: CastDeviceState.idle,
          lastSeen: DateTime.now(),
        );

        discovered.add(device);
        addOrUpdateDevice(device);
      }

      return discovered;
    } catch (_) {
      return [];
    }
  }

  static Map<String, String> _parseTxtRecord(Uint8List packetBytes, int offset, int length) {
    final properties = <String, String>{};
    var current = offset;
    final end = offset + length;

    while (current < end) {
      final strLen = packetBytes[current++];
      if (strLen == 0 || current + strLen > end) break;

      final strBytes = packetBytes.sublist(current, current + strLen);
      final txtStr = utf8.decode(strBytes, allowMalformed: true);
      current += strLen;

      final eqIdx = txtStr.indexOf('=');
      if (eqIdx > 0) {
        final key = txtStr.substring(0, eqIdx);
        final val = txtStr.substring(eqIdx + 1);
        properties[key] = val;
      } else {
        properties[txtStr] = '';
      }
    }

    return properties;
  }

  static _DnsNameResult _readDnsName(Uint8List packetBytes, int initialOffset) {
    final buffer = StringBuffer();
    var offset = initialOffset;
    var jumped = false;
    var nextOffset = -1;

    while (offset < packetBytes.length) {
      final len = packetBytes[offset];
      if (len == 0) {
        if (!jumped) nextOffset = offset + 1;
        break;
      }

      if ((len & 0xC0) == 0xC0) {
        // Pointer (compression)
        if (offset + 1 >= packetBytes.length) break;
        final pointerOffset = ((len & 0x3F) << 8) | packetBytes[offset + 1];
        if (!jumped) {
          nextOffset = offset + 2;
          jumped = true;
        }
        offset = pointerOffset;
      } else {
        offset++;
        if (offset + len > packetBytes.length) break;
        final label = utf8.decode(packetBytes.sublist(offset, offset + len), allowMalformed: true);
        if (buffer.isNotEmpty) buffer.write('.');
        buffer.write(label);
        offset += len;
      }
    }

    return _DnsNameResult(name: buffer.toString(), nextOffset: nextOffset != -1 ? nextOffset : offset);
  }

  static int _skipDnsName(Uint8List packetBytes, int initialOffset) {
    var offset = initialOffset;
    while (offset < packetBytes.length) {
      final len = packetBytes[offset];
      if (len == 0) return offset + 1;
      if ((len & 0xC0) == 0xC0) return offset + 2;
      offset += len + 1;
    }
    return offset;
  }
}

class _DnsNameResult {
  final String name;
  final int nextOffset;

  const _DnsNameResult({required this.name, required this.nextOffset});
}

class _SrvRecord {
  final int port;
  final String target;

  const _SrvRecord({required this.port, required this.target});
}
