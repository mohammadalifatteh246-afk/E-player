import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/audio/domain/audio_compressor_models.dart';

void main() {
  group('Audio Dynamic Range Compressor Engine Tests (VLC compressor.c Parity)', () {
    test('Default configuration initializes disabled with VLC default parameters', () {
      final config = AudioCompressorConfig();
      expect(config.enabled, isFalse);
      expect(config.threshold, equals(-11.0));
      expect(config.ratio, equals(4.0));
      expect(config.knee, equals(2.5));
      expect(config.attack, equals(25.0));
      expect(config.release, equals(100.0));
      expect(config.makeupGain, equals(7.0));
      expect(config.rmsDetection, isTrue);
      expect(config.preset, equals(AudioCompressorPreset.balancedDefault));
      expect(config.buildMpvAfString(), isEmpty);
    });

    test('buildMpvAfString generates authoritative libavfilter acompressor syntax', () {
      final config = AudioCompressorConfig(enabled: true);
      final af = config.buildMpvAfString();

      expect(af, contains('acompressor='));
      expect(af, contains('threshold=-11.0dB'));
      expect(af, contains('ratio=4.0'));
      expect(af, contains('knee=2.5dB'));
      expect(af, contains('attack=25.0'));
      expect(af, contains('release=100.0'));
      expect(af, contains('makeup=7.0dB'));
      expect(af, contains('detection=rms'));
    });

    test('Boundary limits are enforced within safe VLC ranges', () {
      final config = AudioCompressorConfig(enabled: true);

      // Threshold: [-30.0, 0.0]
      config.setThreshold(50.0);
      expect(config.threshold, equals(0.0));
      config.setThreshold(-100.0);
      expect(config.threshold, equals(-30.0));

      // Ratio: [1.0, 20.0]
      config.setRatio(50.0);
      expect(config.ratio, equals(20.0));
      config.setRatio(0.1);
      expect(config.ratio, equals(1.0));

      // Makeup Gain: [0.0, 24.0]
      config.setMakeupGain(50.0);
      expect(config.makeupGain, equals(24.0));
      config.setMakeupGain(-10.0);
      expect(config.makeupGain, equals(0.0));

      // Attack: [1.5, 400.0]
      config.setAttack(1000.0);
      expect(config.attack, equals(400.0));
      config.setAttack(0.5);
      expect(config.attack, equals(1.5));

      // Release: [2.0, 800.0]
      config.setRelease(2000.0);
      expect(config.release, equals(800.0));
      config.setRelease(0.5);
      expect(config.release, equals(2.0));

      // Knee: [1.0, 10.0]
      config.setKnee(20.0);
      expect(config.knee, equals(10.0));
      config.setKnee(0.2);
      expect(config.knee, equals(1.0));
    });

    test('Preset switching applies authoritative profiles and custom classification', () {
      final config = AudioCompressorConfig(enabled: true);

      // Night Cinema
      config.applyPreset(AudioCompressorPreset.nightCinema);
      expect(config.threshold, equals(-20.0));
      expect(config.ratio, equals(6.0));
      expect(config.makeupGain, equals(9.0));
      expect(config.preset, equals(AudioCompressorPreset.nightCinema));

      // Hard Limiter
      config.applyPreset(AudioCompressorPreset.hardLimiter);
      expect(config.threshold, equals(-3.0));
      expect(config.ratio, equals(16.0));
      expect(config.knee, equals(1.0));
      expect(config.attack, equals(2.0));
      expect(config.rmsDetection, isFalse);
      expect(config.buildMpvAfString(), contains('detection=peak'));

      // Nudging threshold switches to custom
      config.setThreshold(-15.0);
      expect(config.preset, equals(AudioCompressorPreset.custom));

      // Reset restores default
      config.reset();
      expect(config.preset, equals(AudioCompressorPreset.balancedDefault));
      expect(config.enabled, isFalse);
    });
  });
}
