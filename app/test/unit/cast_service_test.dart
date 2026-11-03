import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/casting/domain/cast_service.dart';

void main() {
  group('CastService Subsystem & Unit Tests', () {
    late CastService service;
    late Directory tempDir;
    late File tempVideo;
    late File tempSrt;

    setUp(() async {
      service = CastService();
      tempDir = Directory.systemTemp.createTempSync('cast_service_test_');
      tempVideo = File('${tempDir.path}/clip.mp4');
      await tempVideo.writeAsBytes(List<int>.generate(1024, (i) => i % 256));

      tempSrt = File('${tempDir.path}/clip.srt');
      await tempSrt.writeAsString('1\n00:00:01,000 --> 00:00:03,000\nSub text\n');
    });

    tearDown(() async {
      service.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Initializes with default devices and starts scanning', () {
      expect(service.devices.isNotEmpty, isTrue);
      expect(service.devices.length, greaterThanOrEqualTo(5));
      expect(service.isScanning, isTrue);
      expect(service.connectedDevice, isNull);
    });

    test('2. Discovers multi-protocol sinks (Chromecast, AirPlay, DLNA, Miracast)', () {
      final chromecast = service.devices.where((d) => d.protocol == CastProtocol.chromecast);
      expect(chromecast.isNotEmpty, isTrue);
      expect(chromecast.first.protocol.label, 'Chromecast V2');

      final airplay = service.devices.where((d) => d.protocol == CastProtocol.airplay);
      expect(airplay.isNotEmpty, isTrue);
      expect(airplay.first.protocol.label, 'AirPlay 2');

      final dlna = service.devices.where((d) => d.protocol == CastProtocol.dlna);
      expect(dlna.isNotEmpty, isTrue);
      expect(dlna.first.protocol.label, 'DLNA / UPnP');

      // Verify Miracast enum attributes
      expect(CastProtocol.miracast.label, 'Miracast Direct');
      expect(CastProtocol.miracast.colorHex, 0xFFFFB300);
    });

    test('3. Resolves correct transcode profiles based on container and protocol', () {
      expect(
        service.resolveTranscodeProfile('movie.mp4', CastProtocol.chromecast),
        CastTranscodeProfile.directPassthrough,
      );
      expect(
        service.resolveTranscodeProfile('video.m4v', CastProtocol.airplay),
        CastTranscodeProfile.directPassthrough,
      );
      expect(
        service.resolveTranscodeProfile('show.mkv', CastProtocol.chromecast),
        CastTranscodeProfile.videoTranscode,
      );
      expect(
        service.resolveTranscodeProfile('show.mkv', CastProtocol.airplay),
        CastTranscodeProfile.audioRemux,
      );
      expect(
        service.resolveTranscodeProfile('legacy.avi', CastProtocol.dlna),
        CastTranscodeProfile.videoTranscode,
      );
      expect(
        service.resolveTranscodeProfile('stream.ts', CastProtocol.dlna),
        CastTranscodeProfile.fullRemux,
      );
    });

    test('4. Connects to target device and updates connection state', () async {
      final target = service.devices.first;
      expect(target.isConnected, isFalse);

      final success = await service.connect(target);
      expect(success, isTrue);
      expect(service.connectedDevice, isNotNull);
      expect(service.connectedDevice!.id, target.id);
      expect(target.isConnected, isTrue);
      expect(service.activeSession, isNotNull);
      expect(service.activeSession!.device.id, target.id);
    });

    test('5. Spawns LocalStreamingDaemon session when connecting with existing media file', () async {
      final target = service.devices.first;

      final success = await service.connect(
        target,
        mediaTitle: 'Sample Clip',
        mediaPath: tempVideo.path,
        subtitlePath: tempSrt.path,
      );

      expect(success, isTrue);
      final session = service.activeSession;
      expect(session, isNotNull);
      expect(session!.streamUrl, isNotNull);
      expect(session.streamUrl, contains('/cast/'));
      expect(session.streamUrl, endsWith('/stream'));
      expect(session.subtitleUrl, isNotNull);
      expect(session.subtitleUrl, contains('/subtitles/track_0.vtt'));
      expect(service.streamingDaemon.isRunning, isTrue);
    });

    test('6. Disconnects active session and terminates LocalStreamingDaemon gracefully', () async {
      final target = service.devices.first;
      await service.connect(
        target,
        mediaPath: tempVideo.path,
      );
      expect(service.connectedDevice, isNotNull);
      expect(service.streamingDaemon.isRunning, isTrue);

      await service.disconnect();
      expect(service.connectedDevice, isNull);
      expect(service.activeSession, isNull);
      expect(target.isConnected, isFalse);
      expect(service.streamingDaemon.isRunning, isFalse);
    });

    test('7. Remote volume clamping and mute toggling', () {
      service.setRemoteVolume(0.5);
      expect(service.remoteVolume, 0.5);
      expect(service.isMuted, isFalse);

      service.toggleMute();
      expect(service.isMuted, isTrue);

      service.toggleMute();
      expect(service.isMuted, isFalse);

      service.setRemoteVolume(1.5);
      expect(service.remoteVolume, 1.0);

      service.setRemoteVolume(-0.5);
      expect(service.remoteVolume, 0.0);
    });

    test('8. Audio route selection and remote play/pause', () {
      expect(service.audioRoute, 'tv');
      service.setAudioRoute('device');
      expect(service.audioRoute, 'device');

      expect(service.isRemotePlaying, isTrue);
      service.toggleRemotePlayPause();
      expect(service.isRemotePlaying, isFalse);
    });

    test('9. Seek updates active session position', () async {
      final target = service.devices.first;
      await service.connect(target);
      expect(service.activeSession?.position, Duration.zero);

      service.seek(const Duration(seconds: 45));
      expect(service.activeSession?.position, const Duration(seconds: 45));
    });

    test('10. Switching target device automatically tears down previous session', () async {
      final device1 = service.devices[0];
      final device2 = service.devices[1];

      await service.connect(device1, mediaPath: tempVideo.path);
      expect(service.connectedDevice?.id, device1.id);
      expect(device1.isConnected, isTrue);

      await service.connect(device2, mediaPath: tempVideo.path);
      expect(service.connectedDevice?.id, device2.id);
      expect(device2.isConnected, isTrue);
      expect(device1.isConnected, isFalse);
    });
  });
}
