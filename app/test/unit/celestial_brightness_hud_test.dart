import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/celestial_brightness_hud.dart';

void main() {
  group('CelestialColorResolver Unit Tests', () {
    test('Brightness 0% resolves to Lunar Silver (#94A3B8)', () {
      expect(CelestialColorResolver.resolve(0.0), equals(const Color(0xFF94A3B8)));
    });

    test('Brightness 25% resolves to Lunar Night Cyan (#67E8F9)', () {
      expect(CelestialColorResolver.resolve(25.0), equals(const Color(0xFF67E8F9)));
    });

    test('Brightness 50% resolves to Twilight Dawn Gold (#FBBF24)', () {
      expect(CelestialColorResolver.resolve(50.0), equals(const Color(0xFFFBBF24)));
    });

    test('Brightness 80% resolves to Solar Daylight Amber (#F59E0B)', () {
      expect(CelestialColorResolver.resolve(80.0), equals(const Color(0xFFF59E0B)));
    });

    test('Brightness 100% resolves to Supernova Pure White (#FFFFFF)', () {
      expect(CelestialColorResolver.resolve(100.0), equals(const Color(0xFFFFFFFF)));
    });

    test('Clamping handles negative and excessive brightness values safely', () {
      expect(CelestialColorResolver.resolve(-50.0), equals(const Color(0xFF94A3B8)));
      expect(CelestialColorResolver.resolve(999.0), equals(const Color(0xFFFFFFFF)));
    });

    test('Status labels match brightness tiers', () {
      expect(CelestialColorResolver.resolveLabel(15.0), equals('LUNAR NIGHT'));
      expect(CelestialColorResolver.resolveLabel(45.0), equals('TWILIGHT DAWN'));
      expect(CelestialColorResolver.resolveLabel(75.0), equals('SOLAR DAYLIGHT'));
      expect(CelestialColorResolver.resolveLabel(95.0), equals('SUPERNOVA MAX'));
    });
  });

  group('CelestialArcClipper & Geometry Tests', () {
    test('Clipper generates a valid compound path with 7 crescent phases', () {
      const clipper = CelestialArcClipper();
      final path = clipper.getClip(const Size(64.0, 200.0));
      final bounds = path.getBounds();

      expect(bounds.width, closeTo(58.7, 2.0));
      expect(bounds.height, closeTo(194.0, 3.0));
      expect(path.computeMetrics().length, equals(7));
    });
  });

  group('CelestialBrightnessHud Widget Tests', () {
    testWidgets('Renders properly without overflow at 75% brightness (0.75 input)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CelestialBrightnessHud(brightness: 0.75),
            ),
          ),
        ),
      );

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('SOLAR DAYLIGHT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders properly at 100% brightness (100.0 input) with supernova corona pulse', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CelestialBrightnessHud(brightness: 100.0),
            ),
          ),
        ),
      );

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('SUPERNOVA MAX'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 550));
      expect(tester.takeException(), isNull);
    });
  });
}
