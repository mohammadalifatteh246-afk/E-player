import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/subtitles/models/subtitle_sync_models.dart';
import 'package:app/features/subtitles/data/subtitle_sync_calculator.dart';

void main() {
  group('SubtitleSyncCalculator (TDD - 2-Point VLC Subsync Engine)', () {
    test('1-Point Mode: calculates exact constant delay offset with 1.0x speed', () {
      // Audio heard at 00:01:30.000 (90s), Subtitle showed at 00:01:28.500 (88.5s)
      // Delay = Audio - Subtitle = +1.5s (subtitles are early, need to be delayed by +1.5s)
      final point1 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 90),
        subtitleTime: const Duration(milliseconds: 88500),
      );

      final result = SubtitleSyncCalculator.calculate(point1: point1);

      expect(result.delaySeconds, closeTo(1.5, 0.001));
      expect(result.speedFactor, equals(1.0));
      expect(result.hasDriftCorrection, isFalse);
    });

    test('1-Point Mode: negative delay when subtitles appear late', () {
      // Audio heard at 00:00:10.000 (10s), Subtitle showed at 00:00:12.000 (12s)
      // Delay = Audio - Subtitle = -2.0s
      final point1 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 10),
        subtitleTime: const Duration(seconds: 12),
      );

      final result = SubtitleSyncCalculator.calculate(point1: point1);

      expect(result.delaySeconds, closeTo(-2.0, 0.001));
      expect(result.speedFactor, equals(1.0));
      expect(result.hasDriftCorrection, isFalse);
    });

    test('2-Point Mode: PAL (25.0fps) to Film (23.976fps) drift calculation', () {
      // Subtitle is timed for 25.0 fps, but video audio plays at 23.976 fps (~4.271% slower)
      // Point 1 at video audio 100s, sub was at 100s
      // Point 2 at video audio 1042.71s, sub was at 1000s
      final point1 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 100),
        subtitleTime: const Duration(seconds: 100),
      );
      final point2 = SubtitleSyncPoint(
        audioTime: const Duration(milliseconds: 1042710),
        subtitleTime: const Duration(seconds: 1000),
      );

      final result = SubtitleSyncCalculator.calculate(
        point1: point1,
        point2: point2,
      );

      // Speed factor F = (1042.71 - 100) / (1000 - 100) = 942.71 / 900 = 1.04745
      expect(result.speedFactor, closeTo(1.0474, 0.001));
      expect(result.hasDriftCorrection, isTrue);

      // Check estimated video time for sub at 500s:
      // T_av = F * T_sub + D
      // D = A1 - F * S1 = 100 - (1.04745 * 100) = -4.745s
      expect(result.delaySeconds, closeTo(-4.745, 0.01));
    });

    test('2-Point Mode: handles inverted order of points gracefully', () {
      // If user marks later point as point1 and earlier as point2
      final laterPoint = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 1000),
        subtitleTime: const Duration(seconds: 1000),
      );
      final earlierPoint = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 100),
        subtitleTime: const Duration(seconds: 100),
      );

      final result = SubtitleSyncCalculator.calculate(
        point1: laterPoint,
        point2: earlierPoint,
      );

      expect(result.speedFactor, closeTo(1.0, 0.001));
      expect(result.delaySeconds, closeTo(0.0, 0.001));
    });

    test('2-Point Mode: degenerate identical subtitle times fall back safely to 1-point', () {
      final point1 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 10),
        subtitleTime: const Duration(seconds: 10),
      );
      final point2 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 50),
        subtitleTime: const Duration(seconds: 10), // Identical subtitle time!
      );

      final result = SubtitleSyncCalculator.calculate(
        point1: point1,
        point2: point2,
      );

      // Should safely fallback to point1 offset without division by zero NaN/Infinity
      expect(result.speedFactor, equals(1.0));
      expect(result.delaySeconds, equals(0.0));
      expect(result.hasDriftCorrection, isFalse);
    });

    test('Clamping: clamps extreme speed factor to [0.5, 2.0]', () {
      final point1 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 10),
        subtitleTime: const Duration(seconds: 10),
      );
      final point2 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 1000), // Huge audio jump
        subtitleTime: const Duration(seconds: 20), // Tiny subtitle jump -> F = 99
      );

      final result = SubtitleSyncCalculator.calculate(
        point1: point1,
        point2: point2,
      );

      expect(result.speedFactor, equals(2.0));
    });

    test('Subtitle time estimation helper functions accurately', () {
      final point1 = SubtitleSyncPoint(
        audioTime: const Duration(seconds: 10),
        subtitleTime: const Duration(seconds: 5), // D = +5s, F = 1.0
      );
      final result = SubtitleSyncCalculator.calculate(point1: point1);

      final mappedTime = SubtitleSyncCalculator.estimateVideoTimeForSubtitle(
        subtitleTime: const Duration(seconds: 20),
        syncResult: result,
      );

      // 20 * 1.0 + 5 = 25s
      expect(mappedTime.inSeconds, equals(25));
    });
  });
}
