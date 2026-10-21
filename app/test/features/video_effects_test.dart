import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';

void main() {
  group('VideoEffectsConfig Unit Tests (VLC Parity)', () {
    test('Default configuration is completely neutral', () {
      final config = VideoEffectsConfig();
      expect(config.masterEnabled, isTrue);
      expect(config.brightness, equals(0.0));
      expect(config.contrast, equals(0.0));
      expect(config.saturation, equals(0.0));
      expect(config.gamma, equals(0.0));
      expect(config.hue, equals(0.0));
      expect(config.sharpen, isFalse);
      expect(config.sharpenSigma, equals(0.5));
      expect(config.bandingRemoval, isFalse);
      expect(config.invert, isFalse);
      expect(config.sepia, isFalse);
      expect(config.flipHorizontal, isFalse);
      expect(config.flipVertical, isFalse);
      expect(config.rotationAngle, equals(0.0));
      expect(config.isNeutral, isTrue);
    });

    test('isNeutral correctly detects non-neutral mutations', () {
      final config = VideoEffectsConfig();
      expect(config.isNeutral, isTrue);

      config.contrast = 15.0;
      expect(config.isNeutral, isFalse);

      config.contrast = 0.0;
      expect(config.isNeutral, isTrue);

      config.sharpen = true;
      expect(config.isNeutral, isFalse);
    });

    test('resetEssential restores only adjust and sharpen values', () {
      final config = VideoEffectsConfig(
        contrast: 20.0,
        brightness: -10.0,
        saturation: 30.0,
        gamma: 5.0,
        hue: 45.0,
        sharpen: true,
        bandingRemoval: true,
        invert: true,
        flipHorizontal: true,
      );

      config.resetEssential();

      expect(config.contrast, equals(0.0));
      expect(config.brightness, equals(0.0));
      expect(config.saturation, equals(0.0));
      expect(config.gamma, equals(0.0));
      expect(config.hue, equals(0.0));
      expect(config.sharpen, isFalse);
      expect(config.bandingRemoval, isFalse);
      // Colors and geometry remain untouched
      expect(config.invert, isTrue);
      expect(config.flipHorizontal, isTrue);
    });

    test('resetColors restores only color effect filters', () {
      final config = VideoEffectsConfig(
        contrast: 25.0,
        invert: true,
        sepia: true,
        flipVertical: true,
      );

      config.resetColors();

      expect(config.invert, isFalse);
      expect(config.sepia, isFalse);
      expect(config.contrast, equals(25.0));
      expect(config.flipVertical, isTrue);
    });

    test('resetGeometry restores only flip and continuous rotation', () {
      final config = VideoEffectsConfig(
        contrast: 10.0,
        flipHorizontal: true,
        flipVertical: true,
        rotationAngle: 180.0,
      );

      config.resetGeometry();

      expect(config.flipHorizontal, isFalse);
      expect(config.flipVertical, isFalse);
      expect(config.rotationAngle, equals(0.0));
      expect(config.contrast, equals(10.0));
    });

    test('buildMpvVfString generates correct ffmpeg/mpv filter chains', () {
      final config = VideoEffectsConfig(
        sharpen: true,
        sharpenSigma: 0.75,
        bandingRemoval: true,
        bandingRadius: 20,
        flipHorizontal: true,
        flipVertical: true,
        invert: true,
        sepia: true,
      );

      final vf = config.buildMpvVfString();

      expect(vf, contains('unsharp=lx=5:ly=5:la=0.75'));
      expect(vf, contains('gradfun=radius=20'));
      expect(vf, contains('hflip'));
      expect(vf, contains('vflip'));
      expect(vf, contains('negate'));
      expect(vf, contains('colorchannelmixer='));
    });

    test('buildMpvVfString returns empty string when master is disabled', () {
      final config = VideoEffectsConfig(
        masterEnabled: false,
        sharpen: true,
        invert: true,
      );

      expect(config.buildMpvVfString(), equals(''));
    });

    test('toColorFilterMatrix returns valid 20-element 4x5 matrix', () {
      final config = VideoEffectsConfig();
      final matrix = config.toColorFilterMatrix();

      expect(matrix.length, equals(20));
      // Neutral identity matrix diagonal: 1, 1, 1, 1
      expect(matrix[0], closeTo(1.0, 0.001));
      expect(matrix[6], closeTo(1.0, 0.001));
      expect(matrix[12], closeTo(1.0, 0.001));
      expect(matrix[18], closeTo(1.0, 0.001));
    });

    test('toColorFilterMatrix handles Invert Negate transformation', () {
      final config = VideoEffectsConfig(invert: true);
      final matrix = config.toColorFilterMatrix();

      expect(matrix[0], closeTo(-1.0, 0.001));
      expect(matrix[4], closeTo(255.0, 0.001)); // offset
      expect(matrix[6], closeTo(-1.0, 0.001));
      expect(matrix[9], closeTo(255.0, 0.001));
      expect(matrix[12], closeTo(-1.0, 0.001));
      expect(matrix[14], closeTo(255.0, 0.001));
    });

    test('Presets produce expected creative grading values', () {
      final vibrant = VideoEffectsConfig.presetVibrant();
      expect(vibrant.contrast, equals(18.0));
      expect(vibrant.saturation, equals(28.0));

      final warm = VideoEffectsConfig.presetCinemaWarm();
      expect(warm.sepia, isTrue);
      expect(warm.sepiaIntensity, equals(0.15));

      final mono = VideoEffectsConfig.presetMonochromeNoir();
      expect(mono.saturation, equals(-100.0));
      expect(mono.contrast, equals(25.0));

      final night = VideoEffectsConfig.presetNightComfort();
      expect(night.brightness, equals(-15.0));

      final crisp = VideoEffectsConfig.presetCrispDetail();
      expect(crisp.sharpen, isTrue);
      expect(crisp.sharpenSigma, equals(0.85));
    });

    test('JSON serialization round-trip retains all parameters', () {
      final original = VideoEffectsConfig(
        brightness: 12.0,
        contrast: -8.0,
        saturation: 44.0,
        gamma: 3.0,
        hue: -25.0,
        sharpen: true,
        sharpenSigma: 1.25,
        bandingRemoval: true,
        bandingRadius: 24,
        invert: true,
        sepia: true,
        sepiaIntensity: 0.65,
        flipHorizontal: true,
        flipVertical: false,
        rotationAngle: 45.0,
      );

      final json = original.toJson();
      final restored = VideoEffectsConfig.fromJson(json);

      expect(restored.brightness, equals(12.0));
      expect(restored.contrast, equals(-8.0));
      expect(restored.saturation, equals(44.0));
      expect(restored.gamma, equals(3.0));
      expect(restored.hue, equals(-25.0));
      expect(restored.sharpen, isTrue);
      expect(restored.sharpenSigma, equals(1.25));
      expect(restored.bandingRemoval, isTrue);
      expect(restored.bandingRadius, equals(24));
      expect(restored.invert, isTrue);
      expect(restored.sepia, isTrue);
      expect(restored.sepiaIntensity, equals(0.65));
      expect(restored.flipHorizontal, isTrue);
      expect(restored.flipVertical, isFalse);
      expect(restored.rotationAngle, equals(45.0));
    });
  });
}
