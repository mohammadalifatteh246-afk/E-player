import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/casting/domain/cast_service.dart';

void main() {
  group('CastService Unit Tests', () {
    late CastService service;

    setUp(() {
      service = CastService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Initializes with default devices and starts scanning', () {
      expect(service.devices.isNotEmpty, isTrue);
      expect(service.devices.length, 5);
      expect(service.isScanning, isTrue);
      expect(service.connectedDevice, isNull);
    });

    test('Connects to target device and updates connection state', () async {
      final target = service.devices.first;
      expect(target.isConnected, isFalse);

      final success = await service.connect(target);
      expect(success, isTrue);
      expect(service.connectedDevice, isNotNull);
      expect(service.connectedDevice!.id, target.id);
      expect(target.isConnected, isTrue);
    });

    test('Disconnects active session gracefully', () async {
      final target = service.devices.first;
      await service.connect(target);
      expect(service.connectedDevice, isNotNull);

      await service.disconnect();
      expect(service.connectedDevice, isNull);
      expect(target.isConnected, isFalse);
    });

    test('Remote volume clamping and mute toggling', () {
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

    test('Audio route selection and remote play/pause', () {
      expect(service.audioRoute, 'tv');
      service.setAudioRoute('device');
      expect(service.audioRoute, 'device');

      expect(service.isRemotePlaying, isTrue);
      service.toggleRemotePlayPause();
      expect(service.isRemotePlaying, isFalse);
    });
  });
}
