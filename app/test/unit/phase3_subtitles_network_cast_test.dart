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

/// Mock HTTP client for OpenSubtitles unit tests.
class MockSubtitlesHttpClient implements SubtitlesHttpClient {
  SubtitlesHttpResponse? getResponse;
  SubtitlesHttpResponse? postResponse;
  Uri? lastGetUri;
  Uri? lastPostUri;
  Map<String, String>? lastGetHeaders;
  Map<String, String>? lastPostHeaders;
  String? lastPostBody;

  @override
  Future<SubtitlesHttpResponse> get(Uri uri, {Map<String, String>? headers}) async {
    lastGetUri = uri;
    lastGetHeaders = headers;
    return getResponse ??
        const SubtitlesHttpResponse(
          statusCode: 200,
          body: '{"data": []}',
        );
  }

  @override
  Future<SubtitlesHttpResponse> post(Uri uri, {Map<String, String>? headers, String? body}) async {
    lastPostUri = uri;
    lastPostHeaders = headers;
    lastPostBody = body;
    return postResponse ??
        const SubtitlesHttpResponse(
          statusCode: 200,
          body: '{"link": "https://download.opensubtitles.com/sub.srt"}',
        );
  }
}

/// Mock network transport for NetworkMediaService unit tests.
class MockNetworkMediaTransport implements NetworkMediaTransport {
  String xmlResponse = '';
  String smbResponse = '';
  Uri? lastXmlUri;
  NetworkShare? lastSmbShare;
  String? lastSmbPath;

  @override
  Future<String> fetchXml(Uri uri) async {
    lastXmlUri = uri;
    return xmlResponse;
  }

  @override
  Future<String> fetchSmbListing(NetworkShare share, String path) async {
    lastSmbShare = share;
    lastSmbPath = path;
    return smbResponse;
  }
}

/// Mock socket transport for CastDiscoveryService unit tests.
class MockCastSocketTransport implements CastSocketTransport {
  bool isBound = false;
  bool isClosed = false;
  final List<Uint8List> sentQueries = [];
  final StreamController<RawSocketEventData> _controller = StreamController<RawSocketEventData>.broadcast();

  @override
  Future<void> bind() async {
    isBound = true;
  }

  @override
  Future<void> sendQuery(Uint8List packet, InternetAddress address, int port) async {
    sentQueries.add(packet);
  }

  @override
  Stream<RawSocketEventData> get incomingEvents => _controller.stream;

  void emitPacket(Uint8List data, {String ip = '192.168.1.150', int port = 5353}) {
    _controller.add(RawSocketEventData(
      data: data,
      senderAddress: InternetAddress(ip),
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
  group('Phase 3 Unit Tests: OpenSubtitles Service & Hash Algorithm', () {
    late OpenSubtitlesService service;
    late MockSubtitlesHttpClient mockHttp;

    setUp(() {
      mockHttp = MockSubtitlesHttpClient();
      service = OpenSubtitlesService(
        baseUrl: 'https://test-api.opensubtitles.com/v1',
        apiKey: 'test-api-key-12345',
        httpClient: mockHttp,
      );
    });

    test('MovieHash test vector: 128KB zero-filled file matches file size in hex', () {
      final zeroBytes = Uint8List(131072); // 128 KB
      final result = service.computeMovieHashFromBytes(zeroBytes);

      expect(result.byteSize, 131072);
      // Size 131072 = 0x0000000000020000
      expect(result.hash, '0000000000020000');
    });

    test('MovieHash test vector: single bit modification in head chunk updates hash', () {
      final bytes = Uint8List(131072);
      // Write little-endian integer 1 at byte 0
      bytes[0] = 1;
      final result = service.computeMovieHashFromBytes(bytes);

      // 131072 + 1 = 131073 = 0x0000000000020001
      expect(result.hash, '0000000000020001');
    });

    test('MovieHash test vector: boundary byte in tail chunk updates hash', () {
      final bytes = Uint8List(131072);
      // Set 1 at the beginning of the last 64KB (offset 65536)
      bytes[65536] = 5;
      final result = service.computeMovieHashFromBytes(bytes);

      // 131072 + 5 = 131077 = 0x0000000000020005
      expect(result.hash, '0000000000020005');
    });

    test('MovieHash handles small files (<64KB) and empty files gracefully', () {
      final emptyResult = service.computeMovieHashFromBytes(Uint8List(0));
      expect(emptyResult.hash, '0000000000000000');
      expect(emptyResult.byteSize, 0);

      final smallBytes = Uint8List(16);
      smallBytes[0] = 7;
      final smallResult = service.computeMovieHashFromBytes(smallBytes);
      expect(smallResult.byteSize, 16);
      expect(smallResult.hash, isNotEmpty);
    });

    test('computeMovieHash from real filesystem File matches byte buffer calculation', () async {
      final tempDir = await Directory.systemTemp.createTemp('eplayer_hash_test_');
      final tempFile = File('${tempDir.path}/test_movie.mkv');

      final sampleBytes = Uint8List(131072);
      sampleBytes[0] = 42;
      sampleBytes[131071] = 99;
      await tempFile.writeAsBytes(sampleBytes);

      final fileResult = await service.computeMovieHash(tempFile);
      final bufferResult = service.computeMovieHashFromBytes(sampleBytes);

      expect(fileResult.hash, bufferResult.hash);
      expect(fileResult.byteSize, 131072);

      await tempDir.delete(recursive: true);
    });

    test('SubtitleResult fromJson and toJson preserves all fields and resolves languages', () {
      final json = {
        'id': 'sub-9876',
        'attributes': {
          'subtitle_id': 'sub-9876',
          'language': 'es',
          'language_name': 'Spanish',
          'download_count': 15200,
          'ratings': 9.2,
          'format': 'srt',
          'hearing_impaired': true,
          'fps': 23.976,
          'url': 'https://download.opensubtitles.com/sub9876.srt',
          'feature_details': {
            'title': 'Interstellar',
            'year': 2014,
          },
          'files': [
            {'file_id': 54321, 'file_name': 'Interstellar.2014.es.srt'}
          ]
        }
      };

      final sub = SubtitleResult.fromJson(json);
      expect(sub.id, 'sub-9876');
      expect(sub.fileName, 'Interstellar.2014.es.srt');
      expect(sub.language, 'es');
      expect(sub.languageName, 'Spanish');
      expect(sub.downloadCount, 15200);
      expect(sub.rating, 9.2);
      expect(sub.hearingImpaired, isTrue);
      expect(sub.fps, 23.976);
      expect(sub.movieTitle, 'Interstellar');
      expect(sub.movieYear, 2014);
      expect(sub.fileId, 54321);

      final serialized = sub.toJson();
      expect(serialized['id'], 'sub-9876');
      expect(serialized['fileName'], 'Interstellar.2014.es.srt');
      expect(serialized['rating'], 9.2);
    });

    test('searchByHash constructs correct REST endpoint and parses response', () async {
      mockHttp.getResponse = SubtitlesHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'data': [
            {
              'id': '101',
              'attributes': {
                'language': 'en',
                'download_count': 500,
                'ratings': 8.0,
                'files': [
                  {'file_id': 111, 'file_name': 'BladeRunner.srt'}
                ]
              }
            }
          ]
        }),
      );

      final results = await service.searchByHash(
        movieHash: '8e245d9679d31e12',
        byteSize: 1048576000,
        language: 'en',
      );

      expect(results.length, 1);
      expect(results.first.fileName, 'BladeRunner.srt');
      expect(results.first.matchedBy, 'hash');
      expect(mockHttp.lastGetUri?.queryParameters['moviehash'], '8e245d9679d31e12');
      expect(mockHttp.lastGetUri?.queryParameters['moviebytesize'], '1048576000');
      expect(mockHttp.lastGetUri?.queryParameters['languages'], 'en');
      expect(mockHttp.lastGetHeaders?['Api-Key'], 'test-api-key-12345');
    });

    test('searchByQuery constructs query parameters and filters', () async {
      mockHttp.getResponse = SubtitlesHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'data': [
            {
              'id': '202',
              'attributes': {
                'language': 'fr',
                'files': [
                  {'file_id': 222, 'file_name': 'Dune.fr.srt'}
                ]
              }
            }
          ]
        }),
      );

      final results = await service.searchByQuery(
        query: 'Dune Part Two',
        language: 'fr',
        year: 2024,
      );

      expect(results.length, 1);
      expect(results.first.fileName, 'Dune.fr.srt');
      expect(results.first.matchedBy, 'title');
      expect(mockHttp.lastGetUri?.queryParameters['query'], 'Dune Part Two');
      expect(mockHttp.lastGetUri?.queryParameters['year'], '2024');
    });

    test('downloadSubtitleContent and downloadSubtitleToFile writes content cleanly', () async {
      mockHttp.getResponse = const SubtitlesHttpResponse(
        statusCode: 200,
        body: '1\n00:00:01,000 --> 00:00:04,000\nHello World!\n',
      );

      const sub = SubtitleResult(
        id: '1',
        fileName: 'test.srt',
        language: 'en',
        languageName: 'English',
        downloadCount: 1,
        rating: 10.0,
        format: 'srt',
        downloadUrl: 'https://cdn.example.com/test.srt',
      );

      final tempDir = await Directory.systemTemp.createTemp('eplayer_sub_dl_');
      final targetFile = File('${tempDir.path}/test.srt');

      final savedFile = await service.downloadSubtitleToFile(subtitle: sub, targetFile: targetFile);
      expect(await savedFile.exists(), isTrue);
      final content = await savedFile.readAsString();
      expect(content, contains('Hello World!'));

      await tempDir.delete(recursive: true);
    });
  });

  group('Phase 3 Unit Tests: Network Media Streaming & Share Discovery', () {
    late NetworkMediaService networkService;
    late MockNetworkMediaTransport mockTransport;

    setUp(() {
      mockTransport = MockNetworkMediaTransport();
      networkService = NetworkMediaService(transport: mockTransport);
    });

    test('NetworkShare URI formatting with anonymous and authenticated SMB', () {
      const anonShare = NetworkShare(
        id: 'share-1',
        name: 'NAS Public',
        host: '192.168.1.100',
        port: 445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'media',
        isAnonymous: true,
      );

      expect(anonShare.toUri().toString(), 'smb://192.168.1.100/media');
      expect(anonShare.toUri(subPath: 'Movies/SciFi').toString(), 'smb://192.168.1.100/media/Movies/SciFi');

      const authShare = NetworkShare(
        id: 'share-2',
        name: 'Secure Storage',
        host: 'nas.local',
        port: 445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'vault',
        username: 'admin',
        password: 'secret_password',
        isAnonymous: false,
      );

      expect(authShare.toUri().toString(), 'smb://admin:secret_password@nas.local/vault');
    });

    test('NetworkMediaItem media classification (video, audio, subtitle)', () {
      const videoItem = NetworkMediaItem(
        id: 'v1',
        shareId: 's1',
        title: 'Matrix.mkv',
        path: 'Movies/Matrix.mkv',
        streamUrl: 'http://192.168.1.100:8200/Matrix.mkv',
        isDirectory: false,
      );
      expect(videoItem.isVideo, isTrue);
      expect(videoItem.isAudio, isFalse);
      expect(videoItem.isSubtitle, isFalse);

      const audioItem = NetworkMediaItem(
        id: 'a1',
        shareId: 's1',
        title: 'Song.flac',
        path: 'Music/Song.flac',
        streamUrl: 'http://192.168.1.100:8200/Song.flac',
        isDirectory: false,
      );
      expect(audioItem.isVideo, isFalse);
      expect(audioItem.isAudio, isTrue);

      const subItem = NetworkMediaItem(
        id: 'sub1',
        shareId: 's1',
        title: 'Matrix.srt',
        path: 'Movies/Matrix.srt',
        streamUrl: 'http://192.168.1.100:8200/Matrix.srt',
        isDirectory: false,
      );
      expect(subItem.isSubtitle, isTrue);

      const dirItem = NetworkMediaItem(
        id: 'd1',
        shareId: 's1',
        title: 'Movies',
        path: 'Movies',
        streamUrl: '',
        isDirectory: true,
      );
      expect(dirItem.isVideo, isFalse);
    });

    test('UPnP / DLNA DIDL-Lite XML parsing extracts containers, items, sizes, and durations', () {
      const didlXml = '''
      <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
        <container id="folder-10" parentID="0" restricted="1">
          <dc:title>Sci-Fi Cinema</dc:title>
          <upnp:class>object.container.storageFolder</upnp:class>
        </container>
        <item id="item-20" parentID="folder-10" restricted="1">
          <dc:title>Interstellar (2014)</dc:title>
          <upnp:class>object.item.videoItem</upnp:class>
          <res protocolInfo="http-get:*:video/mp4:*" size="3221225472" duration="02:49:04.000">http://192.168.1.120:8200/MediaItems/20.mp4</res>
        </item>
      </DIDL-Lite>
      ''';

      final items = networkService.parseDidlLiteXml(didlXml, shareId: 'dlna-share-1');

      expect(items.length, 2);

      final container = items[0];
      expect(container.title, 'Sci-Fi Cinema');
      expect(container.isDirectory, isTrue);
      expect(container.path, 'Sci-Fi Cinema');

      final mediaItem = items[1];
      expect(mediaItem.title, 'Interstellar (2014)');
      expect(mediaItem.isDirectory, isFalse);
      expect(mediaItem.sizeBytes, 3221225472);
      expect(mediaItem.duration?.inHours, 2);
      expect(mediaItem.duration?.inMinutes, 169); // 2*60 + 49
      expect(mediaItem.streamUrl, 'http://192.168.1.120:8200/MediaItems/20.mp4');
      expect(mediaItem.mimeType, 'video/mp4');
    });

    test('parseDidlLiteXml handles escaped SOAP XML response', () {
      const escapedSoap = '''
      &lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"&gt;
        &lt;item id="55" parentID="0" restricted="1"&gt;
          &lt;dc:title&gt;Arrival.mkv&lt;/dc:title&gt;
          &lt;res size="1073741824"&gt;http://192.168.1.50:8200/55.mkv&lt;/res&gt;
        &lt;/item&gt;
      &lt;/DIDL-Lite&gt;
      ''';

      final items = networkService.parseDidlLiteXml(escapedSoap, shareId: 'dlna-soap');
      expect(items.length, 1);
      expect(items.first.title, 'Arrival.mkv');
      expect(items.first.sizeBytes, 1073741824);
    });

    test('SMB directory listing parsing and stream URL resolution', () {
      const share = NetworkShare(
        id: 'nas-smb',
        name: 'NAS SMB',
        host: '192.168.1.100',
        port: 445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'shared_media',
        username: 'user1',
        password: 'pass1',
        isAnonymous: false,
      );

      const rawListing = '''
      D [DIR] Action Movies
      F [1500000000] Gladiator.mp4
      F [2000000000] Inception.mkv
      ''';

      final items = networkService.parseSmbDirectoryListing(rawListing, share: share, currentPath: 'Cinema');

      expect(items.length, 3);
      expect(items[0].title, 'Action Movies');
      expect(items[0].isDirectory, isTrue);

      expect(items[1].title, 'Gladiator.mp4');
      expect(items[1].isDirectory, isFalse);
      expect(items[1].sizeBytes, 1500000000);
      expect(items[1].streamUrl, 'smb://user1:pass1@192.168.1.100/shared_media/Cinema/Gladiator.mp4');

      final resolvedUrl = networkService.resolveStreamUrl(items[1], share: share);
      expect(resolvedUrl, 'smb://user1:pass1@192.168.1.100/shared_media/Cinema/Gladiator.mp4');
    });

    test('NetworkMediaService share management (add, remove, browse)', () async {
      const share = NetworkShare(
        id: 's1',
        name: 'My DLNA Server',
        host: '192.168.1.200',
        port: 8200,
        protocol: NetworkProtocol.upnpDlna,
      );

      networkService.addShare(share);
      expect(networkService.registeredShares.length, 1);

      mockTransport.xmlResponse = '<DIDL-Lite><item id="1"><dc:title>Test.mp4</dc:title><res>http://192.168.1.200:8200/1.mp4</res></item></DIDL-Lite>';
      final items = await networkService.browseShare(share);
      expect(items.length, 1);
      expect(items.first.title, 'Test.mp4');

      networkService.removeShare('s1');
      expect(networkService.registeredShares.isEmpty, isTrue);
    });
  });

  group('Phase 3 Unit Tests: Wireless Casting mDNS Device Discovery', () {
    late CastDiscoveryService castService;
    late MockCastSocketTransport mockSocket;

    setUp(() {
      mockSocket = MockCastSocketTransport();
      castService = CastDiscoveryService(transport: mockSocket);
    });

    tearDown(() async {
      await castService.dispose();
    });

    test('CastDevice model copyWith and serialization', () {
      final now = DateTime.now();
      final device = CastDevice(
        id: 'device-chromecast-1',
        name: 'Living Room TV',
        host: '192.168.1.80',
        port: 8009,
        protocol: CastProtocol.chromecast,
        modelName: 'Chromecast with Google TV',
        serviceType: '_googlecast._tcp',
        properties: {'fn': 'Living Room TV', 'md': 'Chromecast with Google TV'},
        lastSeen: now,
      );

      expect(device.isChromecast, isTrue);
      expect(device.isDlna, isFalse);

      final json = device.toJson();
      expect(json['id'], 'device-chromecast-1');
      expect(json['name'], 'Living Room TV');
      expect(json['port'], 8009);

      final restored = CastDevice.fromJson(json);
      expect(restored.id, device.id);
      expect(restored.name, device.name);
      expect(restored.host, device.host);
      expect(restored.port, device.port);
    });

    test('encodeDnsPtrQuery builds standard DNS query packet for mDNS multicast', () {
      final packet = CastDiscoveryService.encodeDnsPtrQuery('_googlecast._tcp.local');

      expect(packet.length, greaterThan(12));
      final byteData = ByteData.view(packet.buffer);

      // Flags standard query (0)
      expect(byteData.getUint16(2), 0x0000);
      // QDCOUNT == 1
      expect(byteData.getUint16(4), 0x0001);

      // Checks label bytes: length byte 11 for "_googlecast"
      expect(packet[12], 11);
      final label1 = utf8.decode(packet.sublist(13, 24));
      expect(label1, '_googlecast');
    });

    test('CastDiscoveryService parses incoming mDNS response with PTR, SRV, TXT, and A records', () {
      // Assemble a synthetic mDNS response packet
      final buffer = BytesBuilder();

      void addDnsLabel(BytesBuilder b, String label) {
        final bytes = utf8.encode(label);
        b.addByte(bytes.length);
        b.add(bytes);
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

      // Record 1: PTR Record: _googlecast._tcp.local -> Chromecast-LivingRoom._googlecast._tcp.local
      // Name: _googlecast._tcp.local
      addDnsLabel(buffer, '_googlecast');
      addDnsLabel(buffer, '_tcp');
      addDnsLabel(buffer, 'local');
      buffer.addByte(0);
      buffer.add([0x00, 0x0C]); // TYPE: PTR
      buffer.add([0x00, 0x01]); // CLASS: IN
      buffer.add([0x00, 0x00, 0x00, 0x78]); // TTL: 120s
      // RDATA for PTR: Chromecast-LivingRoom._googlecast._tcp.local
      final ptrTarget = BytesBuilder();
      addDnsLabel(ptrTarget, 'Chromecast-LivingRoom');
      addDnsLabel(ptrTarget, '_googlecast');
      addDnsLabel(ptrTarget, '_tcp');
      addDnsLabel(ptrTarget, 'local');
      ptrTarget.addByte(0);
      final ptrBytes = ptrTarget.toBytes();
      buffer.add([0x00, ptrBytes.length]);
      buffer.add(ptrBytes);

      // Record 2: SRV Record: Chromecast-LivingRoom._googlecast._tcp.local -> port 8009, target host chromecast.local
      addDnsLabel(buffer, 'Chromecast-LivingRoom');
      addDnsLabel(buffer, '_googlecast');
      addDnsLabel(buffer, '_tcp');
      addDnsLabel(buffer, 'local');
      buffer.addByte(0);
      buffer.add([0x00, 0x21]); // TYPE: SRV (33)
      buffer.add([0x00, 0x01]); // CLASS: IN
      buffer.add([0x00, 0x00, 0x00, 0x78]);
      final srvTarget = BytesBuilder();
      srvTarget.add([0x00, 0x00]); // Priority 0
      srvTarget.add([0x00, 0x00]); // Weight 0
      srvTarget.add([0x1F, 0x49]); // Port 8009
      addDnsLabel(srvTarget, 'chromecast');
      addDnsLabel(srvTarget, 'local');
      srvTarget.addByte(0);
      final srvBytes = srvTarget.toBytes();
      buffer.add([0x00, srvBytes.length]);
      buffer.add(srvBytes);

      // Record 3: TXT Record with fn=Living Room TV and md=Chromecast Ultra
      addDnsLabel(buffer, 'Chromecast-LivingRoom');
      addDnsLabel(buffer, '_googlecast');
      addDnsLabel(buffer, '_tcp');
      addDnsLabel(buffer, 'local');
      buffer.addByte(0);
      buffer.add([0x00, 0x10]); // TYPE: TXT (16)
      buffer.add([0x00, 0x01]); // CLASS: IN
      buffer.add([0x00, 0x00, 0x00, 0x78]);
      final txtTarget = BytesBuilder();
      final fnProp = utf8.encode('fn=Living Room TV');
      txtTarget.addByte(fnProp.length);
      txtTarget.add(fnProp);
      final mdProp = utf8.encode('md=Chromecast Ultra');
      txtTarget.addByte(mdProp.length);
      txtTarget.add(mdProp);
      final idProp = utf8.encode('id=cc-ultra-uuid-999');
      txtTarget.addByte(idProp.length);
      txtTarget.add(idProp);
      final txtBytes = txtTarget.toBytes();
      buffer.add([0x00, txtBytes.length]);
      buffer.add(txtBytes);

      // Record 4: A Record: chromecast.local -> 192.168.1.88
      addDnsLabel(buffer, 'chromecast');
      addDnsLabel(buffer, 'local');
      buffer.addByte(0);
      buffer.add([0x00, 0x01]); // TYPE: A (1)
      buffer.add([0x00, 0x01]); // CLASS: IN
      buffer.add([0x00, 0x00, 0x00, 0x78]);
      buffer.add([0x00, 0x04]); // 4 bytes
      buffer.add([192, 168, 1, 88]);

      final packet = buffer.toBytes();
      final devices = castService.handleIncomingPacket(packet);

      expect(devices, isNotEmpty);
      final found = devices.firstWhere((d) => d.id == 'cc-ultra-uuid-999');
      expect(found.name, 'Living Room TV');
      expect(found.modelName, 'Chromecast Ultra');
      expect(found.host, '192.168.1.88');
      expect(found.port, 8009);
      expect(found.protocol, CastProtocol.chromecast);
    });

    test('CastDiscoveryService startDiscovery and stopDiscovery lifecycle', () async {
      await castService.startDiscovery();
      expect(castService.isDiscovering, isTrue);
      expect(mockSocket.isBound, isTrue);
      expect(mockSocket.sentQueries, isNotEmpty);

      // Manually add device and verify stream emission
      expectLater(
        castService.devicesStream,
        emits(predicate<List<CastDevice>>((list) => list.length == 1 && list.first.name == 'Sony Bravia DLNA')),
      );

      castService.addOrUpdateDevice(CastDevice(
        id: 'dlna-sony-1',
        name: 'Sony Bravia DLNA',
        host: '192.168.1.135',
        port: 1400,
        protocol: CastProtocol.dlnaRenderer,
        lastSeen: DateTime.now(),
      ));

      expect(castService.currentDevices.length, 1);

      await castService.stopDiscovery();
      expect(castService.isDiscovering, isFalse);
      expect(mockSocket.isClosed, isTrue);
    });
  });
}
