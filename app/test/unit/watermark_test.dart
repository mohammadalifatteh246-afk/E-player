import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watermark / Logo Overlay Tests (VLC logo.c Parity)', () {
    test('1. Default configuration has watermark disabled and standard defaults', () {
      final config = VideoEffectsConfig();
      expect(config.logoEnabled, isFalse);
      expect(config.logoPath, isNull);
      expect(config.logoText, isNull);
      expect(config.logoPosition, equals(VideoOverlayPosition.topRight));
      expect(config.logoOpacity, equals(0.85));
      expect(config.logoScale, equals(1.0));
      expect(config.logoOffsetX, equals(16));
      expect(config.logoOffsetY, equals(16));
    });

    test('2. 9-point grid alignment matches expected Alignment coordinates', () {
      expect(VideoOverlayPosition.topLeft.alignment, equals(Alignment.topLeft));
      expect(VideoOverlayPosition.topCenter.alignment, equals(Alignment.topCenter));
      expect(VideoOverlayPosition.topRight.alignment, equals(Alignment.topRight));
      expect(VideoOverlayPosition.centerLeft.alignment, equals(Alignment.centerLeft));
      expect(VideoOverlayPosition.center.alignment, equals(Alignment.center));
      expect(VideoOverlayPosition.centerRight.alignment, equals(Alignment.centerRight));
      expect(VideoOverlayPosition.bottomLeft.alignment, equals(Alignment.bottomLeft));
      expect(VideoOverlayPosition.bottomCenter.alignment, equals(Alignment.bottomCenter));
      expect(VideoOverlayPosition.bottomRight.alignment, equals(Alignment.bottomRight));
    });

    test('3. Serialization round-trip preserves all watermark properties', () {
      final config = VideoEffectsConfig(
        logoEnabled: true,
        logoPath: 'C:/Logos/brand.png',
        logoText: 'CONFIDENTIAL',
        logoPosition: VideoOverlayPosition.bottomCenter,
      )
        ..logoOpacity = 0.65
        ..logoScale = 1.8
        ..logoOffsetX = 45
        ..logoOffsetY = 60;

      final json = config.toJson();
      expect(json['logoEnabled'], isTrue);
      expect(json['logoPath'], equals('C:/Logos/brand.png'));
      expect(json['logoText'], equals('CONFIDENTIAL'));
      expect(json['logoPosition'], equals('bottomCenter'));
      expect(json['logoOpacity'], equals(0.65));
      expect(json['logoScale'], equals(1.8));
      expect(json['logoOffsetX'], equals(45));
      expect(json['logoOffsetY'], equals(60));

      final restored = VideoEffectsConfig.fromJson(json);
      expect(restored.logoEnabled, isTrue);
      expect(restored.logoPath, equals('C:/Logos/brand.png'));
      expect(restored.logoText, equals('CONFIDENTIAL'));
      expect(restored.logoPosition, equals(VideoOverlayPosition.bottomCenter));
      expect(restored.logoOpacity, equals(0.65));
      expect(restored.logoScale, equals(1.8));
      expect(restored.logoOffsetX, equals(45));
      expect(restored.logoOffsetY, equals(60));
    });

    test('4. resetOverlay cleans up watermark properties', () {
      final config = VideoEffectsConfig(
        logoEnabled: true,
        logoPath: 'test.png',
        logoText: 'SAMPLE',
      );
      config.resetOverlay();

      expect(config.logoEnabled, isFalse);
      expect(config.logoPath, isNull);
      expect(config.logoText, isNull);
      expect(config.logoOpacity, equals(0.85));
      expect(config.logoScale, equals(1.0));
      expect(config.logoOffsetX, equals(16));
      expect(config.logoOffsetY, equals(16));
    });
  });
}
