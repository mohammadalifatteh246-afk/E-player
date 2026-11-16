import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_overlay_models.dart';

void main() {
  group('MarqueeTokenFormatter Unit Tests (VLC marq.c Parity)', () {
    test('Formats static text unchanged', () {
      final res = MarqueeTokenFormatter.format(template: 'Sample Watermark');
      expect(res, equals('Sample Watermark'));
    });

    test('Formats %t with media title or default fallback', () {
      final withTitle = MarqueeTokenFormatter.format(
        template: 'Video: %t',
        mediaTitle: 'Inception (2010)',
      );
      expect(withTitle, equals('Video: Inception (2010)'));

      final withFallback = MarqueeTokenFormatter.format(
        template: 'Video: %t',
        mediaTitle: null,
      );
      expect(withFallback, equals('Video: E-Player'));
    });

    test('Formats %p (position) and %l (duration)', () {
      final res = MarqueeTokenFormatter.format(
        template: 'Position: %p / %l',
        position: const Duration(minutes: 3, seconds: 25),
        duration: const Duration(hours: 1, minutes: 45, seconds: 10),
      );
      expect(res, equals('Position: 03:25 / 1:45:10'));
    });

    test('Formats clock tokens %Y, %m, %d, %H, %M, %S', () {
      final fixedDate = DateTime(2026, 11, 16, 16, 30, 45);
      final res = MarqueeTokenFormatter.format(
        template: 'Recorded on %Y-%m-%d at %H:%M:%S',
        now: fixedDate,
      );
      expect(res, equals('Recorded on 2026-11-16 at 16:30:45'));
    });

    test('Combined complex marquee string matches expectation', () {
      final fixedDate = DateTime(2026, 11, 16, 9, 5, 2);
      final res = MarqueeTokenFormatter.format(
        template: '%t • [%p / %l] • %H:%M:%S',
        mediaTitle: 'Interstellar',
        position: const Duration(minutes: 12, seconds: 4),
        duration: const Duration(hours: 2, minutes: 49, seconds: 0),
        now: fixedDate,
      );
      expect(res, equals('Interstellar • [12:04 / 2:49:00] • 09:05:02'));
    });

    test('hasDynamicTokens correctly identifies dynamic time vs static templates', () {
      expect(MarqueeTokenFormatter.hasDynamicTokens('E-Player • %t'), isFalse);
      expect(MarqueeTokenFormatter.hasDynamicTokens('Watermark text'), isFalse);
      expect(MarqueeTokenFormatter.hasDynamicTokens('%H:%M:%S'), isTrue);
      expect(MarqueeTokenFormatter.hasDynamicTokens('Time: %p'), isTrue);
    });

    test('VideoOverlayPosition bitmask mappings match VLC SPU specification', () {
      expect(VideoOverlayPosition.topLeft.vlcBitmask, equals(5));
      expect(VideoOverlayPosition.topCenter.vlcBitmask, equals(4));
      expect(VideoOverlayPosition.topRight.vlcBitmask, equals(6));
      expect(VideoOverlayPosition.bottomLeft.vlcBitmask, equals(9));
      expect(VideoOverlayPosition.bottomCenter.vlcBitmask, equals(8));
      expect(VideoOverlayPosition.bottomRight.vlcBitmask, equals(10));
      expect(VideoOverlayPosition.center.vlcBitmask, equals(0));

      expect(VideoOverlayPosition.fromBitmask(6), equals(VideoOverlayPosition.topRight));
      expect(VideoOverlayPosition.fromBitmask(999), equals(VideoOverlayPosition.topLeft));
    });
  });
}
