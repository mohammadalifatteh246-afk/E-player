import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/casting/domain/cast_service.dart';

void main() {
  group('CastService Subsystem & Unit Tests', () {
    late CastService service;
    late Directory tempDir;
    late File tempVideo;
    late File tempSrt;
    late CastDevice sampleDevice;

    setUp(() async {
      service = CastService();
      tempDir = Directory.systemTemp.createTempSync('cast_service_test_');
      tempVideo = File('${tempDir.path}/clip.mp4');
      await tempVideo.writeAsBytes(List<int>.generate(1024, (i) => i % 256));

      tempSrt = File('${tempDir.path}/clip.srt');
      await tempSrt.writeAsString('1\n00:00:01,000 --> 00:00:03,000\nSub text\n');

      sampleDevice = CastDevice(
        id: 'sample_device_1',
        name: 'Living Room TV',
        protocol: CastProtocol.chromecast,
        model: 'Google Chromecast Ultra 4K',
        ipAddress: '192.168.1.104',
        signalPercentage: 95,
        resolutionCapability: '4K UHD · 60 FPS',
      );
    });

    tearDown(() async {
      service.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Initializes with empty device list and starts scanning', () {
      expect(service.devices.isEmpty, isTrue);
      expect(service.isScanning, isTrue);
      expect(service.connectedDevice, isNull);
    });

    test('2. Discovers multi-protocol sinks (Chromecast, AirPlay, DLNA, Miracast)', () {
      final chromecast = CastDevice(
        id: 'test_cc',
        name: 'Test Chromecast',
        protocol: CastProtocol.chromecast,
        model: 'Google Chromecast Ultra',
        ipAddress: '192.168.1.104',
        signalPercentage: 98,
        resolutionCapability: '4K UHD',
      );
      final airplay = CastDevice(
        id: 'test_ap',
        name: 'Test Apple TV',
        protocol: CastProtocol.airplay,
        model: 'Apple TV 4K',
        ipAddress: '192.168.1.118',
        signalPercentage: 92,
        resolutionCapability: '4K Dolby Vision',
      );
      final dlna = CastDevice(
        id: 'test_dlna',
        name: 'Test Sony Bravia',
        protocol: CastProtocol.dlna,
        model: 'Sony Bravia OLED',
        ipAddress: '192.168.1.150',
        signalPercentage: 100,
        resolutionCapability: '4K HDR10',
      );

      service.registerDevice(chromecast);
      service.registerDevice(airplay);
      service.registerDevice(dlna);

      expect(service.devices.length, 3);
      expect(chromecast.protocol.label, 'Chromecast V2');
      expect(airplay.protocol.label, 'AirPlay 2');
      expect(dlna.protocol.label, 'DLNA / UPnP');

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
      service.registerDevice(sampleDevice);
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
      service.registerDevice(sampleDevice);
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
      service.registerDevice(sampleDevice);
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
      service.registerDevice(sampleDevice);
      final target = service.devices.first;
      await service.connect(target);
      expect(service.activeSession?.position, Duration.zero);

      service.seek(const Duration(seconds: 45));
      expect(service.activeSession?.position, const Duration(seconds: 45));
    });

    test('10. Switching target device automatically tears down previous session', () async {
      final device1 = sampleDevice;
      final device2 = CastDevice(
        id: 'sample_device_2',
        name: 'Bedroom TV',
        protocol: CastProtocol.dlna,
        model: 'Samsung QLED',
        ipAddress: '192.168.1.162',
        signalPercentage: 80,
        resolutionCapability: '4K UHD',
      );
      service.registerDevice(device1);
      service.registerDevice(device2);

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
