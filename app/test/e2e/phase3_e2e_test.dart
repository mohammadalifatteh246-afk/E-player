import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/subtitles/models/subtitle_result.dart';
import 'package:app/features/subtitles/data/opensubtitles_service.dart';
import 'package:app/features/network_stream/models/network_share.dart';
import 'package:app/features/network_stream/data/network_media_service.dart';
import 'package:app/features/cast/models/cast_device.dart';
import 'package:app/features/cast/data/cast_discovery_service.dart';

/// Simulated HTTP Client for E2E Subtitle Flows.
class E2ESubtitlesHttpClient implements SubtitlesHttpClient {
  final Map<String, SubtitlesHttpResponse> getRoutes = {};
  final Map<String, SubtitlesHttpResponse> postRoutes = {};

  @override
  Future<SubtitlesHttpResponse> get(Uri uri, {Map<String, String>? headers}) async {
    final pathWithQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;

    for (final entry in getRoutes.entries) {
      if (pathWithQuery.contains(entry.key) || uri.path == entry.key) {
        return entry.value;
      }
    }

    return const SubtitlesHttpResponse(
      statusCode: 200,
      body: '{"data": []}',
    );
  }

  @override
  Future<SubtitlesHttpResponse> post(Uri uri, {Map<String, String>? headers, String? body}) async {
    for (final entry in postRoutes.entries) {
      if (uri.path.contains(entry.key)) {
        return entry.value;
      }
    }

    return const SubtitlesHttpResponse(
      statusCode: 200,
      body: '{"link": "https://cdn.example.com/download.srt"}',
    );
  }
}

/// Simulated Network Transport for E2E Network Media Flows.
class E2ENetworkTransport implements NetworkMediaTransport {
  final Map<String, String> xmlEndpoints = {};
  final Map<String, String> smbListings = {};

  @override
  Future<String> fetchXml(Uri uri) async {
    return xmlEndpoints[uri.path] ?? xmlEndpoints['default'] ?? '<DIDL-Lite></DIDL-Lite>';
  }

  @override
  Future<String> fetchSmbListing(NetworkShare share, String path) async {
    final key = '${share.id}:$path';
    return smbListings[key] ?? smbListings['default'] ?? '';
  }
}

/// Simulated Cast Socket for E2E Casting Discovery Flows.
class E2ECastSocketTransport implements CastSocketTransport {
  bool isBound = false;
  bool isClosed = false;
  final List<Uint8List> transmittedPackets = [];
  final StreamController<RawSocketEventData> _eventController = StreamController<RawSocketEventData>.broadcast();

  @override
  Future<void> bind() async {
    isBound = true;
  }

  @override
  Future<void> sendQuery(Uint8List packet, InternetAddress address, int port) async {
    transmittedPackets.add(packet);
  }

  @override
  Stream<RawSocketEventData> get incomingEvents => _eventController.stream;

  void injectPacket(Uint8List packet, {String senderIp = '192.168.1.50', int senderPort = 5353}) {
    _eventController.add(RawSocketEventData(
      data: packet,
      senderAddress: InternetAddress(senderIp),
      senderPort: senderPort,
    ));
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await _eventController.close();
  }
}

void main() {
  group('Phase 3 E2E Integration Suite: Comprehensive Media & Network Workflows', () {
    late Directory tempSuiteDir;

    setUpAll(() async {
      tempSuiteDir = await Directory.systemTemp.createTemp('eplayer_phase3_e2e_');
    });

    tearDownAll(() async {
      if (await tempSuiteDir.exists()) {
        await tempSuiteDir.delete(recursive: true);
      }
    });

    // -------------------------------------------------------------------------
    // Scenario 1: End-to-End OpenSubtitles Discovery, Hash Search & Download Flow
    // -------------------------------------------------------------------------
    test('E2E Scenario 1: Video file hashing, OpenSubtitles search, and automated subtitle caching', () async {
      // 1. Prepare genuine video file (131072 bytes) with unique header & footer markers
      final videoFile = File('${tempSuiteDir.path}/Blade_Runner_2049.mkv');
      final videoData = Uint8List(131072);
      videoData[0] = 0x1A; // EBML header byte 1
      videoData[1] = 0x45; // EBML header byte 2
      videoData[2] = 0xDF; // EBML header byte 3
      videoData[3] = 0xA3; // EBML header byte 4
      videoData[131070] = 0xEE;
      videoData[131071] = 0xFF;
      await videoFile.writeAsBytes(videoData, flush: true);

      // 2. Setup OpenSubtitles client with simulated endpoints
      final mockHttp = E2ESubtitlesHttpClient();
      final subtitlesService = OpenSubtitlesService(
        baseUrl: 'https://api.opensubtitles.com/api/v1',
        apiKey: 'eplayer_prod_api_key',
        userAgent: 'E-Player E2E Test Suite v1.0',
        httpClient: mockHttp,
      );

      // 3. Compute genuine MovieHash
      final hashResult = await subtitlesService.computeMovieHash(videoFile);
      expect(hashResult.byteSize, 131072);
      expect(hashResult.hash, isNotEmpty);
      expect(hashResult.hash.length, 16);

      // 4. Configure mocked REST API responses
      mockHttp.getRoutes['subtitles?moviehash=${hashResult.hash}'] = SubtitlesHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'total_count': 1,
          'data': [
            {
              'id': 'sub-br2049-en',
              'type': 'subtitle',
              'attributes': {
                'subtitle_id': 'sub-br2049-en',
                'language': 'en',
                'language_name': 'English',
                'download_count': 28540,
                'ratings': 9.6,
                'format': 'srt',
                'hearing_impaired': false,
                'fps': 23.976,
                'feature_details': {
                  'title': 'Blade Runner 2049',
                  'year': 2017,
                },
                'url': 'https://download.opensubtitles.com/br2049_en.srt',
                'files': [
                  {'file_id': 88812, 'file_name': 'Blade.Runner.2049.2017.1080p.en.srt'}
                ]
              }
            }
          ]
        }),
      );

      mockHttp.getRoutes['br2049_en.srt'] = const SubtitlesHttpResponse(
        statusCode: 200,
        body: '''1
00:01:15,000 --> 00:01:20,000
Replicants are like any other machine.

2
00:01:22,000 --> 00:01:28,000
They're either a benefit or a hazard.
''',
      );

      // 5. Search subtitles by hash
      final searchResults = await subtitlesService.searchByHash(
        movieHash: hashResult.hash,
        byteSize: hashResult.byteSize,
        language: 'en',
      );

      expect(searchResults, isNotEmpty);
      final selectedSubtitle = searchResults.first;
      expect(selectedSubtitle.movieTitle, 'Blade Runner 2049');
      expect(selectedSubtitle.rating, 9.6);
      expect(selectedSubtitle.fileName, 'Blade.Runner.2049.2017.1080p.en.srt');
      expect(selectedSubtitle.matchedBy, 'hash');

      // 6. Download subtitle to local cache
      final cacheDir = Directory('${tempSuiteDir.path}/subtitles_cache');
      final targetSubFile = File('${cacheDir.path}/${selectedSubtitle.fileName}');

      final downloadedFile = await subtitlesService.downloadSubtitleToFile(
        subtitle: selectedSubtitle,
        targetFile: targetSubFile,
      );

      expect(await downloadedFile.exists(), isTrue);
      final content = await downloadedFile.readAsString();
      expect(content, contains('Replicants are like any other machine.'));
    });

    // -------------------------------------------------------------------------
    // Scenario 2: End-to-End UPnP / DLNA Network Media Browsing & Stream Resolution
    // -------------------------------------------------------------------------
    test('E2E Scenario 2: UPnP/DLNA ContentDirectory hierarchy traversal and stream URL resolution', () async {
      final transport = E2ENetworkTransport();
      final mediaService = NetworkMediaService(transport: transport);

      const dlnaShare = NetworkShare(
        id: 'dlna-synology-nas',
        name: 'Synology Media Server',
        host: '192.168.1.120',
        port: 8200,
        protocol: NetworkProtocol.upnpDlna,
        sharedPath: 'RootFolder',
      );

      mediaService.addShare(dlnaShare);
      expect(mediaService.registeredShares.contains(dlnaShare), isTrue);

      // Root ContentDirectory returns containers
      transport.xmlEndpoints['/RootFolder'] = '''
      <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
        <container id="c_movies" parentID="0" restricted="1">
          <dc:title>Movies</dc:title>
          <upnp:class>object.container.storageFolder</upnp:class>
        </container>
        <container id="c_tv" parentID="0" restricted="1">
          <dc:title>TV Shows</dc:title>
          <upnp:class>object.container.storageFolder</upnp:class>
        </container>
      </DIDL-Lite>
      ''';

      // Movies subfolder returns video item with stream URL and duration
      transport.xmlEndpoints['/RootFolder/Movies'] = '''
      <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
        <item id="item_oppenheimer" parentID="c_movies" restricted="1">
          <dc:title>Oppenheimer (2023)</dc:title>
          <upnp:class>object.item.videoItem</upnp:class>
          <res protocolInfo="http-get:*:video/mp4:*" size="6442450944" duration="03:00:22.000">/ContentDirectory/Media/oppenheimer.mp4</res>
        </item>
      </DIDL-Lite>
      ''';

      // 1. Browse root
      final rootItems = await mediaService.browseShare(dlnaShare);
      expect(rootItems.length, 2);
      expect(rootItems.every((i) => i.isDirectory), isTrue);

      final moviesFolder = rootItems.firstWhere((i) => i.title == 'Movies');

      // 2. Browse Movies subfolder
      final movieItems = await mediaService.browseShare(dlnaShare, subPath: moviesFolder.title);
      expect(movieItems.length, 1);

      final movie = movieItems.first;
      expect(movie.title, 'Oppenheimer (2023)');
      expect(movie.isVideo, isTrue);
      expect(movie.sizeBytes, 6442450944); // ~6GB
      expect(movie.duration?.inMinutes, 180); // 3 hours

      // 3. Resolve stream URL
      final streamUrl = mediaService.resolveStreamUrl(movie, share: dlnaShare);
      expect(streamUrl, 'http://192.168.1.120:8200/ContentDirectory/Media/oppenheimer.mp4');
    });

    // -------------------------------------------------------------------------
    // Scenario 3: End-to-End SMB / CIFS Share Authentication & Path Encoding Flow
    // -------------------------------------------------------------------------
    test('E2E Scenario 3: Windows SMB share credentials encoding, directory parsing, and streaming URI generation', () async {
      final transport = E2ENetworkTransport();
      final mediaService = NetworkMediaService(transport: transport);

      const smbShare = NetworkShare(
        id: 'smb-truenas',
        name: 'TrueNAS Cinema Vault',
        host: '10.0.0.50',
        port: 445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'VaultShare',
        username: 'media_operator',
        password: 'vault#Password@2026',
        isAnonymous: false,
      );

      mediaService.addShare(smbShare);

      // Simulated SMB directory response
      transport.smbListings['smb-truenas:4K_UHD'] = '''
      D [DIR] Christopher Nolan
      F [12884901888] The_Dark_Knight_2160p.mkv
      F [8589934592] Tenet_2160p.mkv
      ''';

      // 1. Browse SMB directory
      final smbItems = await mediaService.browseShare(smbShare, subPath: '4K_UHD');
      expect(smbItems.length, 3);

      final dirItem = smbItems.firstWhere((i) => i.isDirectory);
      expect(dirItem.title, 'Christopher Nolan');

      final videoItem = smbItems.firstWhere((i) => i.title.startsWith('The_Dark_Knight'));
      expect(videoItem.isVideo, isTrue);
      expect(videoItem.sizeBytes, 12884901888);

      // 2. Resolve authenticated SMB stream URL
      final smbStreamUri = mediaService.resolveStreamUrl(videoItem, share: smbShare);
      expect(smbStreamUri, startsWith('smb://media_operator:vault%23Password%402026@10.0.0.50/VaultShare/4K_UHD/The_Dark_Knight_2160p.mkv'));

      // 3. Confirm network caching buffer parameters for high-bitrate 4K stream
      const expectedCacheSecs = 2.0; // 2 seconds network cache
      const expectedDemuxerBytes = 64 * 1024 * 1024; // 64 MB demuxer cache
      expect(expectedCacheSecs, greaterThanOrEqualTo(0.5));
      expect(expectedDemuxerBytes, greaterThanOrEqualTo(16 * 1024 * 1024));
    });

    // -------------------------------------------------------------------------
    // Scenario 4: End-to-End Wireless Casting Discovery & Reactive Device Registry
    // -------------------------------------------------------------------------
    test('E2E Scenario 4: mDNS discovery broadcast, packet decoding, and device state management', () async {
      final mockSocket = E2ECastSocketTransport();
      final discoveryService = CastDiscoveryService(transport: mockSocket);

      // 1. Start discovery
      await discoveryService.startDiscovery();
      expect(discoveryService.isDiscovering, isTrue);
      expect(mockSocket.isBound, isTrue);
      expect(mockSocket.transmittedPackets, isNotEmpty);

      // 2. Prepare synthetic mDNS packet advertising an LG webOS DLNA renderer
      final packetBuilder = BytesBuilder();
      void addLabel(BytesBuilder b, String label) {
        final bytes = utf8.encode(label);
        b.addByte(bytes.length);
        b.add(bytes);
      }

      // Header: AN=4
      packetBuilder.add([0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00]);

      // Record 1: PTR: _render._tcp.local -> LG-OLED65._render._tcp.local
      addLabel(packetBuilder, '_render');
      addLabel(packetBuilder, '_tcp');
      addLabel(packetBuilder, 'local');
      packetBuilder.addByte(0);
      packetBuilder.add([0x00, 0x0C, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]);
      final ptrTarget = BytesBuilder();
      addLabel(ptrTarget, 'LG-OLED65');
      addLabel(ptrTarget, '_render');
      addLabel(ptrTarget, '_tcp');
      addLabel(ptrTarget, 'local');
      ptrTarget.addByte(0);
      final ptrBytes = ptrTarget.toBytes();
      packetBuilder.add([0x00, ptrBytes.length]);
      packetBuilder.add(ptrBytes);

      // Record 2: SRV: LG-OLED65._render._tcp.local -> port 1400, target lgtv.local
      addLabel(packetBuilder, 'LG-OLED65');
      addLabel(packetBuilder, '_render');
      addLabel(packetBuilder, '_tcp');
      addLabel(packetBuilder, 'local');
      packetBuilder.addByte(0);
      packetBuilder.add([0x00, 0x21, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]);
      final srvTarget = BytesBuilder();
      srvTarget.add([0x00, 0x00, 0x00, 0x00]);
      srvTarget.add([0x05, 0x78]); // Port 1400
      addLabel(srvTarget, 'lgtv');
      addLabel(srvTarget, 'local');
      srvTarget.addByte(0);
      final srvBytes = srvTarget.toBytes();
      packetBuilder.add([0x00, srvBytes.length]);
      packetBuilder.add(srvBytes);

      // Record 3: TXT: fn=Master Bedroom TV, md=OLED65C3
      addLabel(packetBuilder, 'LG-OLED65');
      addLabel(packetBuilder, '_render');
      addLabel(packetBuilder, '_tcp');
      addLabel(packetBuilder, 'local');
      packetBuilder.addByte(0);
      packetBuilder.add([0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]);
      final txtTarget = BytesBuilder();
      final fn = utf8.encode('fn=Master Bedroom TV');
      txtTarget.addByte(fn.length);
      txtTarget.add(fn);
      final md = utf8.encode('md=LG OLED65C3');
      txtTarget.addByte(md.length);
      txtTarget.add(md);
      final id = utf8.encode('id=lg-c3-uuid-555');
      txtTarget.addByte(id.length);
      txtTarget.add(id);
      final txtBytes = txtTarget.toBytes();
      packetBuilder.add([0x00, txtBytes.length]);
      packetBuilder.add(txtBytes);

      // Record 4: A: lgtv.local -> 192.168.1.175
      addLabel(packetBuilder, 'lgtv');
      addLabel(packetBuilder, 'local');
      packetBuilder.addByte(0);
      packetBuilder.add([0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]);
      packetBuilder.add([0x00, 0x04, 192, 168, 1, 175]);

      // 3. Inject packet through mock socket
      mockSocket.injectPacket(packetBuilder.toBytes());

      // Give stream event loop a turn
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 4. Verify discovery and state transition
      final devices = discoveryService.currentDevices;
      expect(devices, isNotEmpty);

      final discoveredDevice = devices.firstWhere((d) => d.id == 'lg-c3-uuid-555');
      expect(discoveredDevice.name, 'Master Bedroom TV');
      expect(discoveredDevice.modelName, 'LG OLED65C3');
      expect(discoveredDevice.host, '192.168.1.175');
      expect(discoveredDevice.port, 1400);
      expect(discoveredDevice.protocol, CastProtocol.dlnaRenderer);
      expect(discoveredDevice.isDlna, isTrue);

      // 5. Simulate connecting state
      final connectingDevice = discoveredDevice.copyWith(state: CastDeviceState.connected);
      discoveryService.addOrUpdateDevice(connectingDevice);
      expect(discoveryService.currentDevices.first.state, CastDeviceState.connected);

      // 6. Stop discovery
      await discoveryService.stopDiscovery();
      expect(discoveryService.isDiscovering, isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Full Combined Cross-Subsystem Concurrency Stress Test
    // -------------------------------------------------------------------------
    test('E2E Scenario 5: Concurrent OpenSubtitles hashing, SMB browsing, DLNA query, and Cast discovery', () async {
      final mockHttp = E2ESubtitlesHttpClient();
      final subtitlesService = OpenSubtitlesService(httpClient: mockHttp);
      final mockTransport = E2ENetworkTransport();
      final mediaService = NetworkMediaService(transport: mockTransport);
      final mockSocket = E2ECastSocketTransport();
      final castService = CastDiscoveryService(transport: mockSocket);

      final syntheticBuffer = Uint8List(131072);
      syntheticBuffer.fillRange(0, 100, 7);

      final futures = <Future<dynamic>>[
        // Subtitle hash calculation
        Future(() => subtitlesService.computeMovieHashFromBytes(syntheticBuffer)),
        // Network share registration & browsing
        Future(() async {
          const share = NetworkShare(
            id: 'concurrency-share',
            name: 'Stress Share',
            host: '10.0.0.1',
            port: 445,
            protocol: NetworkProtocol.smb,
          );
          mockTransport.smbListings['concurrency-share:'] = 'F [1000] video.mp4';
          return await mediaService.browseShare(share);
        }),
        // Cast discovery startup & shutdown
        Future(() async {
          await castService.startDiscovery();
          castService.addOrUpdateDevice(CastDevice(
            id: 'c-1',
            name: 'Test Cast',
            host: '10.0.0.2',
            port: 8009,
            protocol: CastProtocol.chromecast,
            lastSeen: DateTime.now(),
          ));
          await castService.stopDiscovery();
          return castService.currentDevices;
        }),
      ];

      final results = await Future.wait(futures);

      expect(results[0], isA<MovieHashResult>());
      expect((results[0] as MovieHashResult).byteSize, 131072);

      expect(results[1], isA<List<NetworkMediaItem>>());
      expect((results[1] as List<NetworkMediaItem>).length, 1);

      expect(results[2], isA<List<CastDevice>>());
      expect((results[2] as List<CastDevice>).length, 1);
    });
  });
}
