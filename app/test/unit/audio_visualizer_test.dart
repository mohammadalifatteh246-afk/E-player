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

    test('Oscilloscope time-domain waveform synthesizes valid normalized signal (scope.c parity)', () {
      final engine = AudioVisualizerEngine(bandCount: 32);
      expect(engine.waveform.every((w) => w == 0.0), isTrue);

      engine.setActive(true);
      engine.updateAudioContext(position: const Duration(seconds: 4), volume: 100.0, isPlaying: true);
      engine.tick(const Duration(milliseconds: 20));

      expect(engine.waveform.length, equals(64));
      expect(engine.waveform.any((w) => w.abs() > 0.0), isTrue);
      for (final sample in engine.waveform) {
        expect(sample, inInclusiveRange(-1.0, 1.0));
      }

      // Reset on deactivation
      engine.setActive(false);
      expect(engine.waveform.every((w) => w == 0.0), isTrue);
    });

    test('3D Spectrogram history buffer maintains rolling temporal window (glspectrum.c parity)', () {
      final engine = AudioVisualizerEngine(bandCount: 16);
      engine.setActive(true);
      engine.updateAudioContext(position: const Duration(seconds: 2), volume: 100.0, isPlaying: true);

      // Tick multiple frames
      for (var i = 0; i < 20; i++) {
        engine.tick(const Duration(milliseconds: 16));
      }

      expect(engine.spectrogramHistory.length, equals(16));
      for (final slice in engine.spectrogramHistory) {
        expect(slice.length, equals(16));
      }
    });

    test('Stereo VU decibel meter ballistics and peak hold calculation', () {
      final engine = AudioVisualizerEngine(bandCount: 32);
      engine.setActive(true);
      engine.updateAudioContext(position: const Duration(seconds: 8), volume: 100.0, isPlaying: true);
      engine.tick(const Duration(milliseconds: 33));

      expect(engine.leftVuDb, inInclusiveRange(-60.0, 3.0));
      expect(engine.rightVuDb, inInclusiveRange(-60.0, 3.0));
      expect(engine.leftVuPeak, greaterThanOrEqualTo(engine.leftVuDb));
      expect(engine.rightVuPeak, greaterThanOrEqualTo(engine.rightVuDb));
    });

    test('setShowPeaks toggles peak caps and notifies listeners', () {
      final engine = AudioVisualizerEngine(bandCount: 16);
      expect(engine.showPeaks, isTrue);

      int notifies = 0;
      engine.addListener(() => notifies++);

      engine.setShowPeaks(false);
      expect(engine.showPeaks, isFalse);
      expect(notifies, equals(1));
    });
  });
}
