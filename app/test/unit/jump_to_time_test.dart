import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/jump_to_time_models.dart';

void main() {
  group('JumpToTimeParser Unit Tests (VLC goto_time Parity)', () {
    const totalDuration = Duration(hours: 2, minutes: 30); // 2h 30m = 9000s
    const currentPos = Duration(minutes: 45); // 45m = 2700s

    test('Parses HH:MM:SS and MM:SS accurately', () {
      expect(
        JumpToTimeParser.parse('01:15:30'),
        const Duration(hours: 1, minutes: 15, seconds: 30),
      );
      expect(
        JumpToTimeParser.parse('0:05:12'),
        const Duration(minutes: 5, seconds: 12),
      );
      expect(
        JumpToTimeParser.parse('25:10'),
        const Duration(minutes: 25, seconds: 10),
      );
      expect(
        JumpToTimeParser.parse('02:00'),
        const Duration(minutes: 2),
      );
    });

    test('Parses plain numbers and units (s, m, h)', () {
      expect(JumpToTimeParser.parse('90'), const Duration(seconds: 90));
      expect(JumpToTimeParser.parse('45s'), const Duration(seconds: 45));
      expect(JumpToTimeParser.parse('15m'), const Duration(minutes: 15));
      expect(JumpToTimeParser.parse('1.5h'), const Duration(hours: 1, minutes: 30));
    });

    test('Parses percentage expressions relative to totalDuration', () {
      // 50% of 2h 30m (150m) = 75m (1h 15m)
      expect(
        JumpToTimeParser.parse('50%', totalDuration: totalDuration),
        const Duration(hours: 1, minutes: 15),
      );
      // 100% = totalDuration
      expect(
        JumpToTimeParser.parse('100%', totalDuration: totalDuration),
        totalDuration,
      );
      // 0% = Duration.zero
      expect(
        JumpToTimeParser.parse('0%', totalDuration: totalDuration),
        Duration.zero,
      );
    });

    test('Parses relative offsets (+/-) based on currentPosition', () {
      // currentPos = 45m -> +15m = 60m (1h)
      expect(
        JumpToTimeParser.parse('+15m', currentPosition: currentPos, totalDuration: totalDuration),
        const Duration(hours: 1),
      );
      // currentPos = 45m -> -10m = 35m
      expect(
        JumpToTimeParser.parse('-10m', currentPosition: currentPos, totalDuration: totalDuration),
        const Duration(minutes: 35),
      );
      // currentPos = 45m -> +30s = 45m 30s
      expect(
        JumpToTimeParser.parse('+30s', currentPosition: currentPos, totalDuration: totalDuration),
        const Duration(minutes: 45, seconds: 30),
      );
    });

    test('Clamps out-of-bounds targets to Duration.zero and totalDuration', () {
      // Negative relative jump clamps to zero
      expect(
        JumpToTimeParser.parse('-2h', currentPosition: currentPos, totalDuration: totalDuration),
        Duration.zero,
      );
      // Beyond total duration clamps to totalDuration
      expect(
        JumpToTimeParser.parse('5h', totalDuration: totalDuration),
        totalDuration,
      );
    });

    test('Returns null on invalid or unparseable input', () {
      expect(JumpToTimeParser.parse(''), isNull);
      expect(JumpToTimeParser.parse('   '), isNull);
      expect(JumpToTimeParser.parse('invalid_string'), isNull);
      expect(JumpToTimeParser.parse('12:75:99'), isNull); // 75 mins / 99 secs is invalid
    });

    test('Formats durations into readable strings', () {
      expect(JumpToTimeParser.format(const Duration(minutes: 4, seconds: 20)), '04:20');
      expect(JumpToTimeParser.format(const Duration(hours: 1, minutes: 30, seconds: 5)), '1:30:05');
    });
  });
}
