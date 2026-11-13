import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/audio/domain/audio_visualizer_engine.dart';

void main() {
  group('AudioVisualizerEngine Physics & Calculations Tests', () {
    test('Default initialization with 32 frequency bands', () {
      final engine = AudioVisualizerEngine(bandCount: 32);

      expect(engine.bandCount, 32);
      expect(engine.magnitudes.length, 32);
      expect(engine.peaks.length, 32);
      expect(engine.isActive, isFalse);
    });

    test('Engine produces zero amplitudes when inactive or paused', () {
      final engine = AudioVisualizerEngine(bandCount: 16);
      engine.tick(const Duration(milliseconds: 50));

      for (final mag in engine.magnitudes) {
        expect(mag, 0.0);
      }
      for (final peak in engine.peaks) {
        expect(peak, 0.0);
      }
    });

    test('Activating engine generates positive frequency magnitudes', () {
      final engine = AudioVisualizerEngine(bandCount: 16);
      engine.setActive(true);
      engine.updateAudioContext(
        position: const Duration(seconds: 10),
        volume: 100.0,
        isPlaying: true,
      );

      engine.tick(const Duration(milliseconds: 33));

      expect(engine.magnitudes.any((m) => m > 0.0), isTrue);
      expect(engine.peaks.any((p) => p > 0.0), isTrue);

      for (final m in engine.magnitudes) {
        expect(m, inInclusiveRange(0.0, 1.0));
      }
      for (final p in engine.peaks) {
        expect(p, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Peak decay physics: peaks decay slower than instantaneous magnitudes', () {
      final engine = AudioVisualizerEngine(bandCount: 16);
      engine.setActive(true);
      engine.updateAudioContext(
        position: const Duration(seconds: 5),
        volume: 100.0,
        isPlaying: true,
      );

      // Force a high magnitude spike
      engine.feedSampleBand(4, 0.95);
      expect(engine.peaks[4], 0.95);
      engine.tick(const Duration(milliseconds: 16));

      final peak1 = engine.peaks[4];
      expect(peak1, greaterThan(0.90));

      // Now feed a low magnitude
      engine.feedSampleBand(4, 0.2);
      engine.tick(const Duration(milliseconds: 16));

      expect(engine.magnitudes[4], lessThan(0.95));
      // Peak should still be elevated due to gravity decay
      expect(engine.peaks[4], greaterThan(engine.magnitudes[4]));
    });

    test('Band count reconfiguration updates buffer dimensions smoothly', () {
      final engine = AudioVisualizerEngine(bandCount: 16);
      expect(engine.bandCount, 16);

      engine.setBandCount(64);
      expect(engine.bandCount, 64);
      expect(engine.magnitudes.length, 64);
      expect(engine.peaks.length, 64);
    });

    test('Sensitivity scaling amplifies or dampens magnitudes', () {
      final engine = AudioVisualizerEngine(bandCount: 16, sensitivity: 1.0);
      engine.setActive(true);
      engine.updateAudioContext(position: const Duration(seconds: 1), volume: 80.0, isPlaying: true);
      engine.tick(const Duration(milliseconds: 33));
      final normalSum = engine.magnitudes.reduce((a, b) => a + b);

      engine.setSensitivity(2.0);
      engine.updateAudioContext(position: const Duration(seconds: 1), volume: 80.0, isPlaying: true);
      engine.tick(const Duration(milliseconds: 33));
      final boostedSum = engine.magnitudes.reduce((a, b) => a + b);

      expect(boostedSum, greaterThanOrEqualTo(normalSum));
    });
  });
}
