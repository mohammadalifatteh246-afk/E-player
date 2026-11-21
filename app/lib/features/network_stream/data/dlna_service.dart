import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/dlna_models.dart';
import 'network_media_service.dart';

/// Transport abstraction for DLNA HTTP/SOAP communications.
abstract class DlnaHttpTransport {
  Future<String> fetchXml(Uri uri);
  Future<String> postSoap(Uri uri, String soapAction, String body);
}

/// Default implementation using dart:io HttpClient.
class DefaultDlnaHttpTransport implements DlnaHttpTransport {
  final HttpClient _client;

  DefaultDlnaHttpTransport({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<String> fetchXml(Uri uri) async {
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 4));
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw HttpException('Failed to fetch DLNA XML descriptor (${response.statusCode})', uri: uri);
    }
    return await utf8.decoder.bind(response).join();
  }

  @override
  Future<String> postSoap(Uri uri, String soapAction, String body) async {
    final request = await _client.postUrl(uri).timeout(const Duration(seconds: 5));
    request.headers.set('Content-Type', 'text/xml; charset="utf-8"');
    request.headers.set('SOAPACTION', '"$soapAction"');
    request.write(body);
    final response = await request.close();
    return await utf8.decoder.bind(response).join();
  }
}

/// Service that discovers, inspects, and browses DLNA/UPnP Media Servers on the local network (VLC parity).
class DlnaService extends ChangeNotifier {
  static const String kMediaServerType = 'urn:schemas-upnp-org:device:MediaServer:1';
  static const String kContentDirectoryService = 'urn:schemas-upnp-org:service:ContentDirectory:1';

  final DlnaHttpTransport transport;
  final NetworkMediaService _mediaService;

  final Map<String, DlnaMediaServer> _servers = {};
  bool _isScanning = false;

  DlnaService({
    DlnaHttpTransport? transport,
    NetworkMediaService? mediaService,
    bool includeDemoServers = true,
  })  : transport = transport ?? DefaultDlnaHttpTransport(),
        _mediaService = mediaService ?? NetworkMediaService() {
    if (includeDemoServers) {
      _initDemoServers();
    }
  }

  List<DlnaMediaServer> get servers => _servers.values.toList();
  bool get isScanning => _isScanning;

  void _initDemoServers() {
    // Standard LAN default DLNA servers for instant discovery / fallback
    registerServer(const DlnaMediaServer(
      id: 'uuid:plex-media-server-01',
      friendlyName: 'Plex Media Server (Living Room)',
      host: '192.168.1.120',
      port: 32469,
      locationUrl: 'http://192.168.1.120:32469/DeviceDescription.xml',
      contentDirectoryControlUrl: 'http://192.168.1.120:32469/ContentDirectory/control',
      manufacturer: 'Plex, Inc.',
      modelName: 'Plex Media Server',
    ));
    registerServer(const DlnaMediaServer(
      id: 'uuid:synology-nas-ds920',
      friendlyName: 'Synology NAS (DiskStation)',
      host: '192.168.1.150',
      port: 50001,
      locationUrl: 'http://192.168.1.150:50001/desc/device.xml',
      contentDirectoryControlUrl: 'http://192.168.1.150:50001/ContentDir/control',
      manufacturer: 'Synology',
      modelName: 'DS920+ MediaStation',
    ));
  }

  void registerServer(DlnaMediaServer server) {
    _servers[server.id] = server;
    notifyListeners();
  }

  void removeServer(String id) {
    _servers.remove(id);
    notifyListeners();
  }

  void clearServers() {
    _servers.clear();
    notifyListeners();
  }

  /// Builds RFC-compliant SSDP M-SEARCH datagram for UPnP Media Servers
  String buildMSearchDatagram({String st = kMediaServerType, int mx = 3}) {
    return 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: $mx\r\n'
        'ST: $st\r\n'
        '\r\n';
  }

  /// Parses SSDP response headers from UDP datagram
  Map<String, String> parseSsdpHeaders(String rawResponse) {
    final Map<String, String> headers = {};
    final lines = LineSplitter.split(rawResponse);
    for (final line in lines) {
      final index = line.indexOf(':');
      if (index > 0) {
        final key = line.substring(0, index).trim().toUpperCase();
        final value = line.substring(index + 1).trim();
        headers[key] = value;
      }
    }
    return headers;
  }

  /// Inspects a UPnP root device XML descriptor and extracts DLNA MediaServer details
  DlnaMediaServer? parseDeviceDescriptor(String xmlContent, Uri locationUri) {
    if (!xmlContent.contains('ContentDirectory') &&
        !xmlContent.contains('MediaServer')) {
      return null;
    }

    final friendlyName = _extractTag(xmlContent, 'friendlyName') ??
        _extractTag(xmlContent, 'title') ??
        'DLNA Media Server (${locationUri.host})';
    final manufacturer = _extractTag(xmlContent, 'manufacturer');
    final modelName = _extractTag(xmlContent, 'modelName');
    final udn = _extractTag(xmlContent, 'UDN') ?? 'uuid:${locationUri.host}:${locationUri.port}';

    // Locate ContentDirectory service control URL
    String controlPath = '';
    final serviceRegex = RegExp(r'<service\b[^>]*>(.*?)</service>', caseSensitive: false, dotAll: true);
    for (final match in serviceRegex.allMatches(xmlContent)) {
      final serviceBlock = match.group(1) ?? '';
      final serviceType = _extractTag(serviceBlock, 'serviceType') ?? '';
      if (serviceType.contains('ContentDirectory')) {
        controlPath = _extractTag(serviceBlock, 'controlURL') ?? '';
        break;
      }
    }

    if (controlPath.isEmpty) {
      // Fallback standard control path
      controlPath = '/ContentDirectory/control';
    }

    final resolvedControlUri = locationUri.resolve(controlPath);

    return DlnaMediaServer(
      id: udn,
      friendlyName: friendlyName,
      host: locationUri.host,
      port: locationUri.port,
      locationUrl: locationUri.toString(),
      contentDirectoryControlUrl: resolvedControlUri.toString(),
      manufacturer: manufacturer,
      modelName: modelName,
    );
  }

  /// Builds a standard UPnP SOAP ContentDirectory:1 #Browse envelope
  String buildBrowseSoapBody({
    required String objectId,
    int startIndex = 0,
    int count = 100,
    String browseFlag = 'BrowseDirectChildren',
  }) {
    return '<?xml version="1.0" encoding="utf-8"?>\n'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\n'
        '  <s:Body>\n'
        '    <u:Browse xmlns:u="$kContentDirectoryService">\n'
        '      <ObjectID>$objectId</ObjectID>\n'
        '      <BrowseFlag>$browseFlag</BrowseFlag>\n'
        '      <Filter>*</Filter>\n'
        '      <StartingIndex>$startIndex</StartingIndex>\n'
        '      <RequestedCount>$count</RequestedCount>\n'
        '      <SortCriteria></SortCriteria>\n'
        '    </u:Browse>\n'
        '  </s:Body>\n'
        '</s:Envelope>';
  }

  /// Browses a folder/container in the DLNA Media Server and returns parsed media items
  Future<DlnaBrowseResult> browseContainer(
    DlnaMediaServer server, {
    String objectId = '0',
    int startIndex = 0,
    int count = 100,
  }) async {
    try {
      final uri = Uri.parse(server.contentDirectoryControlUrl);
      final body = buildBrowseSoapBody(objectId: objectId, startIndex: startIndex, count: count);

      final responseXml = await transport.postSoap(
        uri,
        '$kContentDirectoryService#Browse',
        body,
      );

      // Extract DIDL-Lite from <Result> tag
      final didlXml = _extractTag(responseXml, 'Result') ?? '';
      final totalMatches = int.tryParse(_extractTag(responseXml, 'TotalMatches') ?? '0') ?? 0;
      final numberReturned = int.tryParse(_extractTag(responseXml, 'NumberReturned') ?? '0') ?? 0;

      final items = _mediaService.parseDidlLiteXml(
        didlXml,
        shareId: server.id,
        baseUrl: 'http://${server.host}:${server.port}',
      );

      return DlnaBrowseResult(
        containerId: objectId,
        items: items,
        totalMatches: totalMatches,
        numberReturned: numberReturned,
      );
    } catch (e) {
      debugPrint('[DlnaService] Browse error: $e');
      rethrow;
    }
  }

  /// Triggers SSDP multicast scan on LAN
  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 3)}) async {
    _isScanning = true;
    notifyListeners();

    try {
      final datagram = buildMSearchDatagram();
      RawDatagramSocket? socket;
      try {
        socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        socket.broadcastEnabled = true;
        final target = InternetAddress('239.255.255.250');
        socket.send(utf8.encode(datagram), target, 1900);

        final sub = socket.listen((event) async {
          if (event == RawSocketEvent.read) {
            final pkg = socket?.receive();
            if (pkg != null) {
              final text = utf8.decode(pkg.data, allowMalformed: true);
              final headers = parseSsdpHeaders(text);
              final location = headers['LOCATION'];
              if (location != null && location.isNotEmpty) {
                try {
                  final locUri = Uri.parse(location);
                  final xml = await transport.fetchXml(locUri);
                  final server = parseDeviceDescriptor(xml, locUri);
                  if (server != null) {
                    registerServer(server);
                  }
                } catch (_) {}
              }
            }
          }
        });

        await Future.delayed(timeout);
        await sub.cancel();
      } finally {
        socket?.close();
      }
    } catch (e) {
      debugPrint('[DlnaService] Discovery error: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Manually connects to a UPnP device descriptor XML URL (e.g. http://192.168.1.50:8200/rootDesc.xml)
  Future<DlnaMediaServer?> connectToUrl(String url) async {
    try {
      var target = url.trim();
      if (!target.startsWith('http://') && !target.startsWith('https://')) {
        target = 'http://$target';
      }
      final uri = Uri.parse(target);
      final xml = await transport.fetchXml(uri);
      final server = parseDeviceDescriptor(xml, uri);
      if (server != null) {
        registerServer(server);
      }
      return server;
    } catch (e) {
      debugPrint('[DlnaService] Manual connect error: $e');
      rethrow;
    }
  }

  static String? _extractTag(String xml, String tagName) {
    final regex = RegExp('<$tagName\\b[^>]*>(.*?)</$tagName>', caseSensitive: false, dotAll: true);
    final match = regex.firstMatch(xml);
    return match?.group(1)?.trim();
  }
}
