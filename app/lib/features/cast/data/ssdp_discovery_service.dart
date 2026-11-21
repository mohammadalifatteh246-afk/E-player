import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/cast_device.dart';
import 'cast_discovery_service.dart' show RawSocketEventData;

/// Transport interface for sending and receiving raw SSDP datagrams.
abstract class SsdpSocketTransport {
  Future<void> bind();
  Future<void> sendSearch(String message, InternetAddress address, int port);
  Stream<RawSocketEventData> get incomingEvents;
  Future<void> close();
}

/// Default UDP multicast socket transport for SSDP discovery (239.255.255.250:1900).
class DefaultSsdpSocketTransport implements SsdpSocketTransport {
  RawDatagramSocket? _socket;
  final StreamController<RawSocketEventData> _controller =
      StreamController<RawSocketEventData>.broadcast();

  @override
  Future<void> bind() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: false,
      );
      _socket?.broadcastEnabled = true;
      _socket?.multicastHops = 4;
      _socket?.multicastLoopback = false;

      final ssdpGroup = InternetAddress('239.255.255.250');
      try {
        _socket?.joinMulticast(ssdpGroup);
      } catch (_) {}

      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          try {
            _socket?.joinMulticast(ssdpGroup, iface);
          } catch (_) {}
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
    } catch (e) {
      debugPrint('DefaultSsdpSocketTransport bind failed: $e');
    }
  }

  @override
  Future<void> sendSearch(String message, InternetAddress address, int port) async {
    try {
      final bytes = utf8.encode(message);
      _socket?.send(bytes, address, port);
    } catch (_) {}
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

/// Parsed device descriptor fetched from an SSDP LOCATION URL.
class SsdpDeviceDescriptor {
  final String friendlyName;
  final String? modelName;
  final String? manufacturer;
  final String? modelNumber;
  final String? avTransportControlUrl;

  const SsdpDeviceDescriptor({
    required this.friendlyName,
    this.modelName,
    this.manufacturer,
    this.modelNumber,
    this.avTransportControlUrl,
  });

  /// Extracts UPnP device properties from the device XML description document.
  static SsdpDeviceDescriptor parse(String xmlContent, Uri baseUri) {
    String extractTag(String xml, String tagName) {
      final match = RegExp(
        '<$tagName(?:\\s+[^>]*)?>(.*?)</$tagName>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(xml);
      return match?.group(1)?.trim() ?? '';
    }

    final friendlyNameRaw = extractTag(xmlContent, 'friendlyName');
    final friendlyName = friendlyNameRaw.isNotEmpty ? friendlyNameRaw : 'DLNA Smart TV';
    final modelName = extractTag(xmlContent, 'modelName');
    final manufacturer = extractTag(xmlContent, 'manufacturer');
    final modelNumber = extractTag(xmlContent, 'modelNumber');

    // Parse AVTransport service controlURL
    String? avTransportControlUrl;
    final serviceRegex = RegExp(
      r'<service>(.*?)</service>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in serviceRegex.allMatches(xmlContent)) {
      final serviceBlock = match.group(1) ?? '';
      final serviceType = extractTag(serviceBlock, 'serviceType');
      if (serviceType.contains('AVTransport')) {
        final rawControlUrl = extractTag(serviceBlock, 'controlURL');
        if (rawControlUrl.isNotEmpty) {
          try {
            avTransportControlUrl = baseUri.resolve(rawControlUrl).toString();
          } catch (_) {
            avTransportControlUrl = rawControlUrl;
          }
          break;
        }
      }
    }

    return SsdpDeviceDescriptor(
      friendlyName: friendlyName,
      modelName: modelName.isNotEmpty ? modelName : null,
      manufacturer: manufacturer.isNotEmpty ? manufacturer : null,
      modelNumber: modelNumber.isNotEmpty ? modelNumber : null,
      avTransportControlUrl: avTransportControlUrl,
    );
  }
}

/// Function signature for fetching UPnP XML descriptors over HTTP.
typedef SsdpXmlFetcher = Future<String?> Function(Uri uri);

/// Default HTTP XML fetcher using dart:io HttpClient with a 2.5s timeout.
Future<String?> defaultSsdpXmlFetcher(Uri uri) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(milliseconds: 2500);
    final req = await client.getUrl(uri).timeout(const Duration(milliseconds: 2500));
    final resp = await req.close().timeout(const Duration(milliseconds: 2500));
    if (resp.statusCode == 200) {
      return await resp.transform(utf8.decoder).join();
    }
  } catch (e) {
    debugPrint('SSDP XML fetch failed for $uri: $e');
  } finally {
    client?.close();
  }
  return null;
}

/// Service that discovers Smart TVs and media renderers using SSDP (UPnP).
/// Discovers Samsung Tizen, LG webOS, Sony Bravia, Roku, and generic DLNA devices.
class SsdpDiscoveryService {
  static const String kSsdpMulticastAddress = '239.255.255.250';
  static const int kSsdpPort = 1900;

  static const String kTargetMediaRenderer = 'urn:schemas-upnp-org:device:MediaRenderer:1';
  static const String kTargetAvTransport = 'urn:schemas-upnp-org:service:AVTransport:1';
  static const String kTargetAll = 'ssdp:all';

  final SsdpSocketTransport transport;
  final SsdpXmlFetcher xmlFetcher;

  final Map<String, CastDevice> _devices = {};
  final StreamController<List<CastDevice>> _devicesController =
      StreamController<List<CastDevice>>.broadcast();

  StreamSubscription<RawSocketEventData>? _subscription;
  Timer? _searchTimer;
  bool _isDiscovering = false;

  SsdpDiscoveryService({
    SsdpSocketTransport? transport,
    SsdpXmlFetcher? xmlFetcher,
  })  : transport = transport ?? DefaultSsdpSocketTransport(),
        xmlFetcher = xmlFetcher ?? defaultSsdpXmlFetcher;

  bool get isDiscovering => _isDiscovering;

  List<CastDevice> get currentDevices => List.unmodifiable(_devices.values.toList());

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;

  /// Builds an RFC-compliant SSDP M-SEARCH datagram.
  static String buildMSearch({String st = kTargetMediaRenderer, int mx = 2}) {
    return 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: $kSsdpMulticastAddress:$kSsdpPort\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: $mx\r\n'
        'ST: $st\r\n'
        '\r\n';
  }

  /// Parses SSDP HTTP packet headers into a case-insensitive map.
  static Map<String, String> parseSsdpHeaders(String packetStr) {
    final headers = <String, String>{};
    final lines = packetStr.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final colonIdx = line.indexOf(':');
      if (colonIdx > 0) {
        final key = line.substring(0, colonIdx).trim().toUpperCase();
        final value = line.substring(colonIdx + 1).trim();
        headers[key] = value;
      }
    }
    return headers;
  }

  /// Starts SSDP device discovery loop.
  Future<void> startDiscovery({
    Duration period = const Duration(seconds: 4),
  }) async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    await transport.bind();
    _subscription = transport.incomingEvents.listen((event) {
      handleIncomingPacket(event.data, fallbackHost: event.senderAddress.address);
    });

    await _broadcastSearches();

    _searchTimer = Timer.periodic(period, (_) async {
      if (_isDiscovering) {
        await _broadcastSearches();
      }
    });
  }

  /// Stops discovery loop and releases socket resources.
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _searchTimer?.cancel();
    _searchTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await transport.close();
  }

  Future<void> _broadcastSearches() async {
    final target = InternetAddress(kSsdpMulticastAddress);
    final searches = [
      buildMSearch(st: kTargetMediaRenderer),
      buildMSearch(st: kTargetAvTransport),
      buildMSearch(st: kTargetAll),
    ];

    for (final msg in searches) {
      await transport.sendSearch(msg, target, kSsdpPort);
    }
  }

  /// Processes raw incoming UDP datagram from an SSDP responder.
  Future<void> handleIncomingPacket(
    Uint8List data, {
    required String fallbackHost,
  }) async {
    try {
      final packetStr = utf8.decode(data, allowMalformed: true);
      final headers = parseSsdpHeaders(packetStr);

      final location = headers['LOCATION'];
      if (location == null || location.isEmpty) return;

      final st = headers['ST'] ?? headers['NT'] ?? '';
      final isRelevant = st.contains('MediaRenderer') ||
          st.contains('AVTransport') ||
          st.contains('device') ||
          st.contains('ssdp:all');

      if (!isRelevant) return;

      final uri = Uri.tryParse(location);
      if (uri == null) return;

      final host = uri.host.isNotEmpty ? uri.host : fallbackHost;
      final port = uri.port > 0 ? uri.port : 1400;

      // Extract UUID from USN if available
      final usn = headers['USN'] ?? '';
      final id = _extractUuidFromUsn(usn) ?? 'dlna_${host}_$port';

      // Avoid refetching descriptor if recently seen
      if (_devices.containsKey(id)) {
        final existing = _devices[id]!;
        _devices[id] = CastDevice(
          id: existing.id,
          name: existing.name,
          host: existing.host,
          port: existing.port,
          protocol: existing.protocol,
          modelName: existing.modelName,
          serviceType: existing.serviceType,
          properties: existing.properties,
          state: existing.state,
          lastSeen: DateTime.now(),
        );
        _devicesController.add(currentDevices);
        return;
      }

      // Fetch device XML descriptor
      final xmlContent = await xmlFetcher(uri);
      if (xmlContent == null || xmlContent.isEmpty) return;

      final descriptor = SsdpDeviceDescriptor.parse(xmlContent, uri);

      final device = CastDevice(
        id: id,
        name: descriptor.friendlyName,
        host: host,
        port: port,
        protocol: CastProtocol.dlnaRenderer,
        modelName: descriptor.modelName ??
            descriptor.manufacturer ??
            'Universal Media Renderer (DLNA)',
        serviceType: kTargetMediaRenderer,
        properties: {
          'location': location,
          'controlUrl': descriptor.avTransportControlUrl ?? '',
          if (descriptor.manufacturer != null) 'manufacturer': descriptor.manufacturer!,
          if (descriptor.modelNumber != null) 'modelNumber': descriptor.modelNumber!,
        },
        state: CastDeviceState.idle,
        lastSeen: DateTime.now(),
      );

      _devices[id] = device;
      _devicesController.add(currentDevices);
    } catch (e) {
      debugPrint('Error handling SSDP packet: $e');
    }
  }

  static String? _extractUuidFromUsn(String usn) {
    final match = RegExp(r'uuid:([0-9a-fA-F-]+)', caseSensitive: false).firstMatch(usn);
    if (match != null) {
      return match.group(0);
    }
    return null;
  }

  void clearDevices() {
    _devices.clear();
    _devicesController.add(currentDevices);
  }

  Future<void> dispose() async {
    await stopDiscovery();
    await _devicesController.close();
  }
}
