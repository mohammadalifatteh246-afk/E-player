import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/network_stream/domain/smb_models.dart';
import 'package:app/features/network_stream/data/smb_service.dart';

void main() {
  group('SmbShareConfig Domain Unit Tests (VLC smb2.c Parity)', () {
    test('1. Anonymous share produces clean standard smb:// MRL', () {
      const config = SmbShareConfig(
        host: '192.168.1.100',
        shareName: 'Media',
        subPath: 'Movies/film.mkv',
        isAnonymous: true,
      );

      expect(config.toMrl(), 'smb://192.168.1.100/Media/Movies/film.mkv');
      expect(config.toSafeDisplayMrl(), 'smb://192.168.1.100/Media/Movies/film.mkv');
      expect(config.displayTitle, '192.168.1.100/Media');
    });

    test('2. Custom port is included in MRL if not default 445', () {
      const config = SmbShareConfig(
        host: 'nas.local',
        port: 4455,
        shareName: 'Shared',
        isAnonymous: true,
      );

      expect(config.toMrl(), 'smb://nas.local:4455/Shared');
      expect(config.toSafeDisplayMrl(), 'smb://nas.local:4455/Shared');
    });

    test('3. Authenticated share formats credentials in MRL', () {
      const config = SmbShareConfig(
        host: '10.0.0.5',
        shareName: 'Video',
        username: 'mediauser',
        password: 'p@ssword#1',
      );

      expect(config.toMrl(), 'smb://mediauser:p%40ssword%231@10.0.0.5/Video');
      expect(config.toSafeDisplayMrl(), 'smb://mediauser:****@10.0.0.5/Video');
    });

    test('4. Windows domain / workgroup prefix is formatted properly', () {
      const config = SmbShareConfig(
        host: '192.168.1.20',
        shareName: 'Public',
        domain: 'HOMEGROUP',
        username: 'bob',
        password: 'secret',
      );

      expect(config.toMrl(), 'smb://HOMEGROUP;bob:secret@192.168.1.20/Public');
      expect(config.toSafeDisplayMrl(), 'smb://HOMEGROUP;bob:****@192.168.1.20/Public');
    });

    test('5. JSON round-trip correctly serializes and restores config and recent share', () {
      final config = const SmbShareConfig(
        host: '192.168.1.88',
        port: 445,
        shareName: 'Storage',
        subPath: 'Clips',
        domain: 'OFFICE',
        username: 'admin',
        isAnonymous: false,
      );

      final json = config.toJson();
      final restored = SmbShareConfig.fromJson(json);

      expect(restored.host, '192.168.1.88');
      expect(restored.shareName, 'Storage');
      expect(restored.subPath, 'Clips');
      expect(restored.domain, 'OFFICE');
      expect(restored.username, 'admin');

      final recent = SmbRecentShare(
        config: config,
        lastAccessed: DateTime(2026, 11, 23, 12, 0),
      );
      final recentJson = recent.toJson();
      final restoredRecent = SmbRecentShare.fromJson(recentJson);

      expect(restoredRecent.config.host, '192.168.1.88');
      expect(restoredRecent.lastAccessed.year, 2026);
    });
  });

  group('SmbShareService Unit Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('6. Saves recent shares in FIFO order up to 5 items', () async {
      final service = SmbShareService(prefs: prefs);
      expect(service.recentShares, isEmpty);

      for (int i = 1; i <= 7; i++) {
        await service.saveRecentShare(SmbShareConfig(
          host: '192.168.1.$i',
          shareName: 'Share$i',
        ));
      }

      expect(service.recentShares.length, 5);
      // Newest should be 192.168.1.7 at index 0
      expect(service.recentShares.first.config.host, '192.168.1.7');
      expect(service.recentShares.last.config.host, '192.168.1.3');
    });

    test('7. Deduplicates recent shares with same host and shareName', () async {
      final service = SmbShareService(prefs: prefs);

      await service.saveRecentShare(const SmbShareConfig(
        host: '192.168.1.50',
        shareName: 'Movies',
      ));
      await service.saveRecentShare(const SmbShareConfig(
        host: '192.168.1.60',
        shareName: 'Series',
      ));
      // Re-add 192.168.1.50/Movies
      await service.saveRecentShare(const SmbShareConfig(
        host: '192.168.1.50',
        shareName: 'Movies',
      ));

      expect(service.recentShares.length, 2);
      expect(service.recentShares[0].config.host, '192.168.1.50');
      expect(service.recentShares[1].config.host, '192.168.1.60');
    });

    test('8. probeHost returns true when socket connects successfully', () async {
      // Mock socket connector that returns an open dummy socket
      Future<Socket> mockConnector(dynamic host, int port, {Duration? timeout}) async {
        return _MockSocket();
      }

      final service = SmbShareService(prefs: prefs, socketConnector: mockConnector);
      final reachable = await service.probeHost('192.168.1.100');
      expect(reachable, isTrue);
    });

    test('9. probeHost returns false when socket connection throws or host is empty', () async {
      Future<Socket> failingConnector(dynamic host, int port, {Duration? timeout}) async {
        throw const SocketException('Connection refused');
      }

      final service = SmbShareService(prefs: prefs, socketConnector: failingConnector);
      final reachable = await service.probeHost('192.168.1.100');
      expect(reachable, isFalse);

      final emptyReachable = await service.probeHost('   ');
      expect(emptyReachable, isFalse);
    });
  });
}

class _MockSocket implements Socket {
  bool isDestroyed = false;

  @override
  void destroy() {
    isDestroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
