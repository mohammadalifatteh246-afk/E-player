import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/subtitles/data/opensubtitles_service.dart';
import 'package:app/features/network_stream/models/network_share.dart';
import 'package:app/features/network_stream/data/network_media_service.dart';
import 'package:app/features/cast/data/cast_discovery_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('eplayer_phase3_adversarial_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ===========================================================================
  // 1. MovieHash Calculation Edge Cases
  // ===========================================================================
  group('1. MovieHash Calculation Edge Cases', () {
    late OpenSubtitlesService service;

    setUp(() {
      service = OpenSubtitlesService();
    });

    test('Edge Case 1.1: 0-byte buffer and 0-byte file returns 0000000000000000', () async {
      final zeroBufferResult = service.computeMovieHashFromBytes(Uint8List(0));
      expect(zeroBufferResult.hash, '0000000000000000');
      expect(zeroBufferResult.byteSize, 0);

      final zeroFile = File('${tempDir.path}/zero_byte.mkv');
      await zeroFile.writeAsBytes(Uint8List(0), flush: true);
      final zeroFileResult = await service.computeMovieHash(zeroFile);
      expect(zeroFileResult.hash, '0000000000000000');
      expect(zeroFileResult.byteSize, 0);
    });

    test('Edge Case 1.2: Odd-sized byte buffers (1, 7, 8, 9, 15, 65535, 65537, 131071, 131073 bytes)', () async {
      final oddSizes = [1, 7, 8, 9, 15, 65535, 65537, 131071, 131073];

      for (final size in oddSizes) {
        final buffer = Uint8List(size);
        for (var i = 0; i < size; i++) {
          buffer[i] = (i * 37 + 13) & 0xFF;
        }

        final bufferResult = service.computeMovieHashFromBytes(buffer);
        expect(bufferResult.byteSize, size);
        expect(bufferResult.hash.length, 16);

        final file = File('${tempDir.path}/odd_file_$size.dat');
        await file.writeAsBytes(buffer, flush: true);
        final fileResult = await service.computeMovieHash(file);

        expect(fileResult.hash, bufferResult.hash, reason: 'Mismatch between file and buffer hash for size $size');
        expect(fileResult.byteSize, size);
      }
    });

    test('Edge Case 1.3: Exactly 64KB (65536 bytes) boundary chunking', () async {
      const size = 65536;
      final buffer = Uint8List(size);
      for (var i = 0; i < size; i++) {
        buffer[i] = (i & 0xFF);
      }

      final bufferResult = service.computeMovieHashFromBytes(buffer);
      expect(bufferResult.byteSize, size);

      final file = File('${tempDir.path}/exact_64k.dat');
      await file.writeAsBytes(buffer, flush: true);
      final fileResult = await service.computeMovieHash(file);

      expect(fileResult.hash, bufferResult.hash);
      expect(fileResult.byteSize, size);
    });

    test('Edge Case 1.4: Exactly 128KB (131072 bytes) boundary chunking', () async {
      const size = 131072;
      final buffer = Uint8List(size);
      for (var i = 0; i < size; i++) {
        buffer[i] = ((i >> 3) & 0xFF);
      }

      final bufferResult = service.computeMovieHashFromBytes(buffer);
      expect(bufferResult.byteSize, size);

      final file = File('${tempDir.path}/exact_128k.dat');
      await file.writeAsBytes(buffer, flush: true);
      final fileResult = await service.computeMovieHash(file);

      expect(fileResult.hash, bufferResult.hash);
      expect(fileResult.byteSize, size);
    });

    test('Edge Case 1.5: 64-bit integer overflow and signedness resilience (all 0xFF bytes)', () async {
      const size = 131072;
      final buffer = Uint8List(size);
      buffer.fillRange(0, size, 0xFF);

      // (131072 + 16384 * (-1)) mod 2^64 = 114688 = 0x000000000001C000
      final result = service.computeMovieHashFromBytes(buffer);
      expect(result.byteSize, size);
      expect(result.hash, '000000000001c000');

      final file = File('${tempDir.path}/all_ff.dat');
      await file.writeAsBytes(buffer, flush: true);
      final fileResult = await service.computeMovieHash(file);
      expect(fileResult.hash, '000000000001c000');
    });

    test('Edge Case 1.6: Single-bit modifications in head, middle (ignored), and tail chunk', () async {
      const size = 200000;
      final original = Uint8List(size);
      for (var i = 0; i < size; i++) {
        original[i] = (i & 0x7F);
      }

      final baseHash = service.computeMovieHashFromBytes(original).hash;

      // Bit flip in head (byte 100) -> Changes hash
      final modifiedHead = Uint8List.fromList(original);
      modifiedHead[100] ^= 0x01;
      final headHash = service.computeMovieHashFromBytes(modifiedHead).hash;
      expect(headHash, isNot(equals(baseHash)));

      // Bit flip in middle (byte 100000) -> Hash MUST NOT change
      final modifiedMiddle = Uint8List.fromList(original);
      modifiedMiddle[100000] ^= 0x01;
      final middleHash = service.computeMovieHashFromBytes(modifiedMiddle).hash;
      expect(middleHash, equals(baseHash));

      // Bit flip in tail (byte 199999) -> Changes hash
      final modifiedTail = Uint8List.fromList(original);
      modifiedTail[199999] ^= 0x80;
      final tailHash = service.computeMovieHashFromBytes(modifiedTail).hash;
      expect(tailHash, isNot(equals(baseHash)));
    });

    test('Edge Case 1.7: 500MB simulation file hashing verification', () async {
      const fileSize = 500 * 1024 * 1024;
      final largeFile = File('${tempDir.path}/large_500mb_sim.mkv');
      final raf = await largeFile.open(mode: FileMode.write);

      try {
        final head = Uint8List(OpenSubtitlesService.kChunkSize);
        for (var i = 0; i < head.length; i++) {
          head[i] = (i & 0xFF);
        }
        await raf.writeFrom(head);

        final tailOffset = fileSize - OpenSubtitlesService.kChunkSize;
        await raf.setPosition(tailOffset);
        final tail = Uint8List(OpenSubtitlesService.kChunkSize);
        for (var i = 0; i < tail.length; i++) {
          tail[i] = ((i * 3) & 0xFF);
        }
        await raf.writeFrom(tail);
      } finally {
        await raf.close();
      }

      expect(await largeFile.length(), fileSize);

      final stopwatch = Stopwatch()..start();
      final hashResult = await service.computeMovieHash(largeFile);
      stopwatch.stop();

      expect(hashResult.byteSize, fileSize);
      expect(hashResult.hash.length, 16);
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });
  });

  // ===========================================================================
  // 2. UPnP / DLNA DIDL-Lite XML Parsing
  // ===========================================================================
  group('2. UPnP / DLNA DIDL-Lite XML Parsing', () {
    late NetworkMediaService networkService;

    setUp(() {
      networkService = NetworkMediaService();
    });

    test('Edge Case 2.1: Empty, whitespace-only, and truncated XML', () {
      expect(networkService.parseDidlLiteXml('', shareId: 'test'), isEmpty);
      expect(networkService.parseDidlLiteXml('   \n\t   ', shareId: 'test'), isEmpty);
      expect(networkService.parseDidlLiteXml('<DIDL-Lite', shareId: 'test'), isEmpty);
      expect(networkService.parseDidlLiteXml('<item', shareId: 'test'), isEmpty);
    });

    test('Edge Case 2.2: Missing attributes and empty containers/items', () {
      const missingAttrsXml = '''
      <DIDL-Lite>
        <container>
          <dc:title>Bare Folder</dc:title>
        </container>
        <item>
          <dc:title>Bare Video</dc:title>
          <res>http://10.0.0.1/video.mp4</res>
        </item>
        <item id="item-no-title">
          <res>http://10.0.0.1/untitled.mp4</res>
        </item>
        <item id="item-no-res">
          <dc:title>No Stream Url</dc:title>
        </item>
      </DIDL-Lite>
      ''';

      final items = networkService.parseDidlLiteXml(missingAttrsXml, shareId: 'share-1');
      expect(items.length, 4);

      expect(items[0].title, 'Bare Folder');
      expect(items[0].id, startsWith('container_'));
      expect(items[0].isDirectory, isTrue);

      expect(items[1].title, 'Bare Video');
      expect(items[1].id, startsWith('item_'));
      expect(items[1].streamUrl, 'http://10.0.0.1/video.mp4');

      expect(items[2].title, 'Media File');
      expect(items[2].streamUrl, 'http://10.0.0.1/untitled.mp4');

      expect(items[3].title, 'No Stream Url');
      expect(items[3].streamUrl, isEmpty);
    });

    test('Edge Case 2.3: Malformed and boundary duration strings in parseUpnpDuration', () {
      expect(NetworkMediaService.parseUpnpDuration(''), isNull);
      expect(NetworkMediaService.parseUpnpDuration('invalid'), isNull);
      expect(NetworkMediaService.parseUpnpDuration('10:00'), isNull);
      expect(NetworkMediaService.parseUpnpDuration('10:00:00:00'), isNull);

      final d1 = NetworkMediaService.parseUpnpDuration('01:30:15');
      expect(d1?.inHours, 1);
      expect(d1?.inMinutes, 90);
      expect(d1?.inSeconds, 5415);

      final d2 = NetworkMediaService.parseUpnpDuration('00:00:05.500');
      expect(d2?.inMilliseconds, 5500);

      final d3 = NetworkMediaService.parseUpnpDuration('00:00:01.5');
      expect(d3?.inMilliseconds, 1500);

      final d4 = NetworkMediaService.parseUpnpDuration('00:00:02.123456');
      expect(d4?.inMilliseconds, 2123);

      final d5 = NetworkMediaService.parseUpnpDuration('::');
      expect(d5, Duration.zero);

      final d6 = NetworkMediaService.parseUpnpDuration('-01:00:00');
      expect(d6?.inHours, -1);

      final d7 = NetworkMediaService.parseUpnpDuration('999999999999999999999:00:00');
      expect(d7, isNotNull);
    });

    test('Edge Case 2.4: Escaped XML behavior in SOAP Result (Entity unescaping limitation observed)', () {
      const soapXml = '''
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
        <SOAP-ENV:Body>
          <u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
            <Result>&lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"&gt;
              &lt;item id="escaped-1"&gt;
                &lt;dc:title&gt;Fast &amp;amp; Furious &amp;quot;Tokyo Drift&amp;quot; &amp;lt;4K&amp;gt;&lt;/dc:title&gt;
                &lt;res size="4294967296" duration="01:44:00"&gt;http://192.168.1.10:8200/tokyo.mp4&lt;/res&gt;
              &lt;/item&gt;
            &lt;/DIDL-Lite&gt;</Result>
          </u:BrowseResponse>
        </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
      ''';

      final items = networkService.parseDidlLiteXml(soapXml, shareId: 'dlna-soap');
      expect(items.length, 1);
      // Empirical observation: SOAP layer unescapes &amp;lt; into <, but leaves inner title entities as &amp;, &quot;, &lt;
      expect(items.first.title, 'Fast &amp; Furious &quot;Tokyo Drift&quot; &lt;4K&gt;');
      expect(items.first.sizeBytes, 4294967296);
      expect(items.first.duration?.inMinutes, 104);
    });

    test('Edge Case 2.5: High volume DIDL-Lite stress test (1000 items)', () {
      final xmlBuffer = StringBuffer('<DIDL-Lite>');
      for (var i = 0; i < 1000; i++) {
        xmlBuffer.write('''
        <item id="stress_item_$i">
          <dc:title>Stress Video $i</dc:title>
          <res size="${i * 1000000}" duration="00:0$i:00">http://192.168.1.100:8200/media/$i.mkv</res>
        </item>
        ''');
      }
      xmlBuffer.write('</DIDL-Lite>');

      final stopwatch = Stopwatch()..start();
      final items = networkService.parseDidlLiteXml(xmlBuffer.toString(), shareId: 'stress-share');
      stopwatch.stop();

      expect(items.length, 1000);
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });
  });

  // ===========================================================================
  // 3. SMB Share URI Resolution
  // ===========================================================================
  group('3. SMB Share URI Resolution', () {
    test('Edge Case 3.1: Special characters in credentials (#, @, %, &, spaces, colons, unicode)', () {
      const share = NetworkShare(
        id: 'smb-special-chars',
        name: 'Secured NAS',
        host: 'storage.local',
        port: 445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'MediaShare',
        username: 'john doe@domain#1',
        password: 'p@ss#word%1&2:root™',
        isAnonymous: false,
      );

      final streamUrl = NetworkMediaService.resolveSmbStreamUrl(share, 'SciFi/Dune.mkv');
      final uri = Uri.parse(streamUrl);

      expect(uri.scheme, 'smb');
      expect(uri.host, 'storage.local');
      expect(uri.path, '/MediaShare/SciFi/Dune.mkv');

      final decodedUserInfo = Uri.decodeComponent(uri.userInfo);
      expect(decodedUserInfo, contains('john doe@domain#1'));
      expect(decodedUserInfo, contains('p@ss#word%1&2:root™'));
    });

    test('Edge Case 3.2: Port overrides (0, 445 default omitted, non-standard preserved)', () {
      const shareDefault = NetworkShare(
        id: 's1',
        name: 'S1',
        host: '10.0.0.1',
        port: 445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'share',
      );
      expect(NetworkMediaService.resolveSmbStreamUrl(shareDefault, 'file.mp4'), 'smb://10.0.0.1/share/file.mp4');

      const shareCustom = NetworkShare(
        id: 's2',
        name: 'S2',
        host: '10.0.0.1',
        port: 1445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'share',
      );
      expect(NetworkMediaService.resolveSmbStreamUrl(shareCustom, 'file.mp4'), 'smb://10.0.0.1:1445/share/file.mp4');

      const shareZero = NetworkShare(
        id: 's3',
        name: 'S3',
        host: '10.0.0.1',
        port: 0,
        protocol: NetworkProtocol.smb,
        sharedPath: 'share',
      );
      expect(NetworkMediaService.resolveSmbStreamUrl(shareZero, 'file.mp4'), 'smb://10.0.0.1/share/file.mp4');
    });

    test('Edge Case 3.3: Path normalization and traversal handling (Dart Uri collapses parent segments)', () {
      const share = NetworkShare(
        id: 's-paths',
        name: 'S',
        host: '192.168.1.5',
        port: 445,
        protocol: NetworkProtocol.smb,
        sharedPath: 'videos',
      );

      final url1 = NetworkMediaService.resolveSmbStreamUrl(share, '/sub/movie.mp4');
      expect(url1, 'smb://192.168.1.5/videos/sub/movie.mp4');

      final url2 = NetworkMediaService.resolveSmbStreamUrl(share, '');
      expect(url2, 'smb://192.168.1.5/videos');

      // Empirical observation: Dart's Uri constructor normalizes /videos/../../etc/passwd to /etc/passwd
      final url3 = NetworkMediaService.resolveSmbStreamUrl(share, '../../etc/passwd');
      expect(url3, 'smb://192.168.1.5/etc/passwd');
    });
  });

  // ===========================================================================
  // 4. mDNS Cast Discovery Packet Parsing
  // ===========================================================================
  group('4. mDNS Cast Discovery Packet Parsing', () {
    late CastDiscoveryService castService;

    setUp(() {
      castService = CastDiscoveryService();
    });

    tearDown(() async {
      await castService.dispose();
    });

    test('Edge Case 4.1: Severely truncated packets (< 12 bytes and incomplete headers)', () {
      expect(castService.handleIncomingPacket(Uint8List(0)), isEmpty);
      expect(castService.handleIncomingPacket(Uint8List(1)), isEmpty);
      expect(castService.handleIncomingPacket(Uint8List(11)), isEmpty);

      final queryHeader = Uint8List(12);
      expect(castService.handleIncomingPacket(queryHeader), isEmpty);

      final emptyResponse = Uint8List.fromList([
        0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);
      expect(castService.handleIncomingPacket(emptyResponse), isEmpty);
    });

    test('Edge Case 4.2: Truncated questions and records with exceeding rdLength', () {
      final truncatedQuestion = Uint8List.fromList([
        0x00, 0x00, 0x84, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x0B, 0x5F, 0x67,
      ]);
      expect(castService.handleIncomingPacket(truncatedQuestion), isEmpty);

      final builder = BytesBuilder();
      builder.add([0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]);
      builder.add([0x04, 0x74, 0x65, 0x73, 0x74, 0x00]);
      builder.add([0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]);
      builder.add([0x00, 0x64]); // rdLength = 100 bytes (only 5 follow)
      builder.add([0x01, 0x02, 0x03, 0x04, 0x05]);

      expect(castService.handleIncomingPacket(builder.toBytes()), isEmpty);
    });

    test('Edge Case 4.3: Circular DNS compression pointer loop vulnerability detection via subprocess', () async {
      final reproScript = File('${tempDir.path}/mdns_pointer_repro.dart');
      await reproScript.writeAsString('''
import 'dart:typed_data';
import 'package:app/features/cast/data/cast_discovery_service.dart';

void main() {
  final service = CastDiscoveryService();
  final circularPacket = Uint8List.fromList([
    0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
    0xC0, 0x0C,
    0x00, 0x0C, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78, 0x00, 0x02, 0xC0, 0x0C,
  ]);
  service.handleIncomingPacket(circularPacket);
}
''');

      final process = await Process.start(
        Platform.resolvedExecutable,
        ['run', reproScript.path],
        workingDirectory: 'D:/E-player/app',
      );

      var exited = false;
      unawaited(process.exitCode.then((_) => exited = true));

      // Wait 1.5 seconds. If the process does not exit, it is in an infinite loop!
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      final didHang = !exited;
      process.kill();

      expect(
        didHang,
        isTrue,
        reason: 'Empirically confirms that circular compression pointers cause synchronous infinite loop / process hang in _readDnsName',
      );
    });

    test('Edge Case 4.4: Corrupted TXT record key-values (missing =, null bytes, non-ASCII)', () {
      final builder = BytesBuilder();
      builder.add([0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]);

      void addLabel(String l) {
        final b = utf8.encode(l);
        builder.addByte(b.length);
        builder.add(b);
      }
      addLabel('mycast');
      addLabel('_googlecast');
      addLabel('_tcp');
      addLabel('local');
      builder.addByte(0);

      builder.add([0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78]);

      final txt = BytesBuilder();
      final p1 = utf8.encode('fn=Bedroom Cast');
      txt.addByte(p1.length);
      txt.add(p1);

      final p2 = utf8.encode('standalone_flag');
      txt.addByte(p2.length);
      txt.add(p2);

      txt.addByte(0);

      txt.addByte(50);
      txt.add([0x61, 0x62, 0x63, 0x64, 0x65]);

      final txtBytes = txt.toBytes();
      builder.add([0x00, txtBytes.length]);
      builder.add(txtBytes);

      final devices = castService.handleIncomingPacket(builder.toBytes(), fallbackHost: '192.168.1.99');
      expect(devices, isNotEmpty);
      expect(devices.first.name, 'Bedroom Cast');
    });

    test('Edge Case 4.5: High frequency packet burst bombardment (1000 randomized corrupt packets)', () {
      final random = Uint8List(128);
      for (var i = 0; i < random.length; i++) {
        random[i] = (i * 17) & 0xFF;
      }

      for (var i = 0; i < 1000; i++) {
        final corruptSlice = Uint8List.view(random.buffer, (i % 16), (i % 64) + 12);
        expect(() => castService.handleIncomingPacket(corruptSlice), returnsNormally);
      }
    });
  });
}
