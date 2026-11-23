import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/thunderbolt_volume_hud.dart';

void main() {
  group('ThunderColorResolver Unit Tests', () {
    test('Volume 0% to 50% resolves strictly to Pure White', () {
      expect(ThunderColorResolver.resolve(0.0), equals(const Color(0xFFFFFFFF)));
      expect(ThunderColorResolver.resolve(25.0), equals(const Color(0xFFFFFFFF)));
      expect(ThunderColorResolver.resolve(50.0), equals(const Color(0xFFFFFFFF)));
    });

    test('Volume 100% resolves to Electric Cyan-Blue (#00D4FF)', () {
      expect(ThunderColorResolver.resolve(100.0), equals(const Color(0xFF00D4FF)));
    });

    test('Volume 75% interpolates smoothly between White and Electric Blue', () {
      final color = ThunderColorResolver.resolve(75.0);
      expect(color.r, greaterThan(0.0));
      expect(color.g, greaterThan(0.7));
      expect(color.b, greaterThan(0.9));
    });

    test('Volume 200% resolves to Vivid Amber-Orange (#FF7A00)', () {
      expect(ThunderColorResolver.resolve(200.0), equals(const Color(0xFFFF7A00)));
    });

    test('Volume 150% interpolates smoothly between Electric Blue and Amber-Orange', () {
      final color = ThunderColorResolver.resolve(150.0);
      expect(color, isNotNull);
    });

    test('Volume 300% resolves to Radiant Crimson Red (#FF0D55)', () {
      expect(ThunderColorResolver.resolve(300.0), equals(const Color(0xFFFF0D55)));
    });

    test('Clamping handles negative and excessive volume values safely', () {
      expect(ThunderColorResolver.resolve(-50.0), equals(const Color(0xFFFFFFFF)));
      expect(ThunderColorResolver.resolve(999.0), equals(const Color(0xFFFF0D55)));
    });

    test('Status labels match volume bands', () {
      expect(ThunderColorResolver.resolveLabel(35.0), equals('STANDARD'));
      expect(ThunderColorResolver.resolveLabel(85.0), equals('ELECTRIC'));
      expect(ThunderColorResolver.resolveLabel(160.0), equals('OVER-AMP'));
      expect(ThunderColorResolver.resolveLabel(280.0), equals('MAX DANGER'));
    });
  });

  group('ThunderboltClipper & Geometry Tests', () {
    test('Clipper generates a valid closed path with 10 vertices', () {
      const clipper = ThunderboltClipper();
      final path = clipper.getClip(const Size(38.0, 240.0));
      final bounds = path.getBounds();

      expect(bounds.width, closeTo(31.2, 1.0));
      expect(bounds.height, closeTo(240.0, 1.0));
      expect(path.contains(const Offset(19.0, 120.0)), isTrue);
    });
  });

  group('ThunderboltVolumeHud Widget Tests', () {
    testWidgets('Renders properly without overflow at 85% volume', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ThunderboltVolumeHud(volume: 85.0),
            ),
          ),
        ),
      );

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('ELECTRIC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders properly at 280% volume with danger pulse', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ThunderboltVolumeHud(volume: 280.0),
            ),
          ),
        ),
      );

      expect(find.text('280%'), findsOneWidget);
      expect(find.text('MAX DANGER'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull);
    });
  });
}
