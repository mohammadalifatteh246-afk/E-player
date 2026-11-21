import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/audio/domain/dual_audio_models.dart';
import 'package:app/features/audio/domain/dual_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dual Audio Output & Dubbing Tests (VLC audio-device Parity)', () {
    test('1. Default configuration has dual audio disabled with standard defaults', () {
      final config = DualAudioConfig();
      expect(config.enabled, isFalse);
      expect(config.primaryDeviceId, equals('auto'));
      expect(config.secondaryDeviceId, isNull);
      expect(config.routingMode, equals(DualAudioRoutingMode.mirrorDuplicate));
      expect(config.primaryVolume, equals(100.0));
      expect(config.secondaryVolume, equals(100.0));
      expect(config.secondaryDelayMs, equals(0.0));
      expect(config.isSecondaryMuted, isFalse);
    });

    test('2. copyWith modifies requested properties correctly', () {
      final config = DualAudioConfig();
      final updated = config.copyWith(
        enabled: true,
        primaryDeviceId: 'wasapi/{spk}',
        secondaryDeviceId: 'wasapi/{bt}',
        routingMode: DualAudioRoutingMode.dualTrackDubbing,
        primaryVolume: 150.0,
        secondaryVolume: 80.0,
        secondaryDelayMs: 120.0,
        isSecondaryMuted: true,
      );

      expect(updated.enabled, isTrue);
      expect(updated.primaryDeviceId, equals('wasapi/{spk}'));
      expect(updated.secondaryDeviceId, equals('wasapi/{bt}'));
      expect(updated.routingMode, equals(DualAudioRoutingMode.dualTrackDubbing));
      expect(updated.primaryVolume, equals(150.0));
      expect(updated.secondaryVolume, equals(80.0));
      expect(updated.secondaryDelayMs, equals(120.0));
      expect(updated.isSecondaryMuted, isTrue);
    });

    test('3. Serialization round-trip preserves all fields', () {
      final config = DualAudioConfig(
        enabled: true,
        primaryDeviceId: 'wasapi/{hdmi}',
        secondaryDeviceId: 'wasapi/{usb}',
        routingMode: DualAudioRoutingMode.dualTrackDubbing,
        primaryVolume: 180.0,
        secondaryVolume: 95.0,
        secondaryDelayMs: -250.0,
        secondaryTrackId: 'track_2_dubbed',
        isSecondaryMuted: true,
      );

      final json = config.toJson();
      expect(json['enabled'], isTrue);
      expect(json['primaryDeviceId'], equals('wasapi/{hdmi}'));
      expect(json['secondaryDeviceId'], equals('wasapi/{usb}'));
      expect(json['routingMode'], equals('dualTrackDubbing'));
      expect(json['primaryVolume'], equals(180.0));
      expect(json['secondaryVolume'], equals(95.0));
      expect(json['secondaryDelayMs'], equals(-250.0));
      expect(json['secondaryTrackId'], equals('track_2_dubbed'));
      expect(json['isSecondaryMuted'], isTrue);

      final restored = DualAudioConfig.fromJson(json);
      expect(restored.enabled, isTrue);
      expect(restored.primaryDeviceId, equals('wasapi/{hdmi}'));
      expect(restored.secondaryDeviceId, equals('wasapi/{usb}'));
      expect(restored.routingMode, equals(DualAudioRoutingMode.dualTrackDubbing));
      expect(restored.primaryVolume, equals(180.0));
      expect(restored.secondaryVolume, equals(95.0));
      expect(restored.secondaryDelayMs, equals(-250.0));
      expect(restored.secondaryTrackId, equals('track_2_dubbed'));
      expect(restored.isSecondaryMuted, isTrue);
    });

    test('4. reset restores default values', () {
      final config = DualAudioConfig(
        enabled: true,
        primaryDeviceId: 'wasapi/{spk}',
        secondaryDeviceId: 'wasapi/{bt}',
        primaryVolume: 175.0,
        secondaryVolume: 50.0,
        secondaryDelayMs: 200.0,
        isSecondaryMuted: true,
      );

      config.reset();
      expect(config.enabled, isFalse);
      expect(config.primaryDeviceId, equals('auto'));
      expect(config.secondaryDeviceId, isNull);
      expect(config.routingMode, equals(DualAudioRoutingMode.mirrorDuplicate));
      expect(config.primaryVolume, equals(100.0));
      expect(config.secondaryVolume, equals(100.0));
      expect(config.secondaryDelayMs, equals(0.0));
      expect(config.isSecondaryMuted, isFalse);
    });

    test('5. DualAudioService manages endpoints and state reactively', () async {
      final service = DualAudioService();
      expect(service.devices.isNotEmpty, isTrue);
      expect(service.devices.any((d) => d.isBluetooth), isTrue);

      bool notified = false;
      service.addListener(() => notified = true);

      service.toggleEnabled();
      expect(service.config.enabled, isTrue);
      expect(notified, isTrue);

      notified = false;
      service.setSecondaryVolume(140.0);
      expect(service.config.secondaryVolume, equals(140.0));
      expect(notified, isTrue);

      notified = false;
      service.setSecondaryDelay(150.0);
      expect(service.config.secondaryDelayMs, equals(150.0));
      expect(notified, isTrue);

      notified = false;
      service.toggleSecondaryMute();
      expect(service.config.isSecondaryMuted, isTrue);
      expect(notified, isTrue);

      notified = false;
      service.reset();
      expect(service.config.enabled, isFalse);
      expect(service.config.secondaryVolume, equals(100.0));
      expect(notified, isTrue);
    });
  });
}
