import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/audio/domain/audio_pitch_models.dart';

void main() {
  group('Audio Pitch Shifter & Scaler Engine Tests (VLC scaletempo.c Parity)', () {
    test('Default AudioPitchConfig initializes disabled with neutral 1.0x ratio', () {
      final config = AudioPitchConfig();
      expect(config.enabled, isFalse);
      expect(config.semitones, equals(0));
      expect(config.cents, equals(0.0));
      expect(config.totalCents, equals(0.0));
      expect(config.pitchRatio, closeTo(1.0, 1e-6));
      expect(config.speedCompensation, closeTo(1.0, 1e-6));
      expect(config.preset, equals(AudioPitchPreset.flat));
      expect(config.buildMpvAfString(), isEmpty);
      expect(config.buildUniversalAfString(), isEmpty);
    });

    test('Octave Shift calculations conform exactly to mathematical acoustics (2^N)', () {
      final config = AudioPitchConfig(enabled: true);

      // +1 Octave (+12 semitones) => 2.0x pitch
      config.setSemitones(12);
      expect(config.pitchRatio, closeTo(2.0, 1e-5));
      expect(config.speedCompensation, closeTo(0.5, 1e-5));
      expect(config.buildMpvAfString(), contains('rubberband=pitch-scale=2.000000'));
      expect(config.buildUniversalAfString(baseSampleRate: 48000), contains('asetrate=96000,atempo=0.500000,aresample=48000'));

      // -1 Octave (-12 semitones) => 0.5x pitch
      config.setSemitones(-12);
      expect(config.pitchRatio, closeTo(0.5, 1e-5));
      expect(config.speedCompensation, closeTo(2.0, 1e-5));
      expect(config.buildMpvAfString(), contains('rubberband=pitch-scale=0.500000'));
      expect(config.buildUniversalAfString(baseSampleRate: 48000), contains('asetrate=24000,atempo=2.000000,aresample=48000'));
    });

    test('Semitone interval ratios match 12-TET equal temperament scale', () {
      final config = AudioPitchConfig(enabled: true);

      // +7 semitones (Perfect Fifth) => 2^(7/12) ≈ 1.498307
      config.setSemitones(7);
      expect(config.pitchRatio, closeTo(1.498307, 1e-4));

      // +4 semitones (Major Third / Male->Female) => 2^(4/12) ≈ 1.259921
      config.setSemitones(4);
      expect(config.pitchRatio, closeTo(1.259921, 1e-4));

      // -4 semitones (Female->Male) => 2^(-4/12) ≈ 0.793701
      config.setSemitones(-4);
      expect(config.pitchRatio, closeTo(0.793701, 1e-4));
    });

    test('Fine cent detuning accurately shifts pitch without semitone jump', () {
      final config = AudioPitchConfig(enabled: true);

      // Concert A432 Hz tuning from A440 Hz standard = 1200 * log2(432/440) ≈ -31.766 cents
      config.applyPreset(AudioPitchPreset.concertPitch432);
      expect(config.semitones, equals(0));
      expect(config.cents, closeTo(-31.77, 0.05));
      expect(config.pitchRatio, closeTo(432.0 / 440.0, 1e-4));

      // +50 cents = quarter tone sharp
      config.reset();
      config.enabled = true;
      config.setCents(50.0);
      expect(config.pitchRatio, closeTo(1.029302, 1e-4));
    });

    test('Boundary limits are enforced within safe range [-12, +12] and [-100, +100]', () {
      final config = AudioPitchConfig(enabled: true);

      config.setSemitones(50);
      expect(config.semitones, equals(12));

      config.setSemitones(-50);
      expect(config.semitones, equals(-12));

      config.setCents(500.0);
      expect(config.cents, equals(100.0));

      config.setCents(-500.0);
      expect(config.cents, equals(-100.0));
    });

    test('Preset application updates semitones, cents, and preserves custom fallback', () {
      final config = AudioPitchConfig(enabled: true);

      config.applyPreset(AudioPitchPreset.chipmunk);
      expect(config.semitones, equals(12));
      expect(config.preset, equals(AudioPitchPreset.chipmunk));

      config.applyPreset(AudioPitchPreset.deepVoice);
      expect(config.semitones, equals(-12));
      expect(config.preset, equals(AudioPitchPreset.deepVoice));

      // Nudge semitones manually changes preset to custom
      config.setSemitones(3);
      expect(config.preset, equals(AudioPitchPreset.custom));

      // Reset restores flat preset
      config.reset();
      expect(config.preset, equals(AudioPitchPreset.flat));
      expect(config.enabled, isFalse);
    });
  });
}
