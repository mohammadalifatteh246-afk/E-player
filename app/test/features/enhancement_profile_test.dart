import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/enhancement/models/enhancement_profile.dart';

void main() {
  group('EnhancementProfile Unit Tests (VLC DSP Parity)', () {
    test('Default EnhancementConfig is disabled and defaults to superClarity', () {
      final config = EnhancementConfig();
      expect(config.masterToggle, isFalse);
      expect(config.mode, equals(EnhancementMode.superClarity));
      expect(config.strength, equals(1.0));

      final effects = config.toVideoEffectsConfig();
      expect(effects.masterEnabled, isFalse);
    });

    test('superClarity mode generates acutance unsharp filter and debanding', () {
      final config = EnhancementConfig(
        masterToggle: true,
        mode: EnhancementMode.superClarity,
      );

      final effects = config.toVideoEffectsConfig();
      expect(effects.masterEnabled, isTrue);
      expect(effects.sharpen, isTrue);
      expect(effects.sharpenSigma, closeTo(0.85, 0.01));
      expect(effects.bandingRemoval, isTrue);
      expect(effects.bandingRadius, equals(16));
      expect(effects.contrast, closeTo(10.0, 0.01));
      expect(effects.brightness, equals(0.0));
      expect(effects.saturation, closeTo(8.0, 0.01));
      expect(effects.gamma, closeTo(-4.0, 0.01));

      final vf = effects.buildMpvVfString();
      expect(vf, contains('unsharp=lx=5:ly=5:la=0.85'));
      expect(vf, contains('gradfun=radius=16'));
    });

    test('animeRemaster generates high-acutance line contours and heavy debanding', () {
      final config = EnhancementConfig(
        masterToggle: true,
        mode: EnhancementMode.animeRemaster,
      );

      final effects = config.toVideoEffectsConfig();
      expect(effects.sharpen, isTrue);
      expect(effects.sharpenSigma, closeTo(1.15, 0.01));
      expect(effects.bandingRemoval, isTrue);
      expect(effects.bandingRadius, equals(24));
      expect(effects.saturation, closeTo(24.0, 0.01));

      final vf = effects.buildMpvVfString();
      expect(vf, contains('unsharp=lx=5:ly=5:la=1.15'));
      expect(vf, contains('gradfun=radius=24'));
    });

    test('cinemaHdr generates deep dynamic contrast, warm tone and inky blacks', () {
      final config = EnhancementConfig(
        masterToggle: true,
        mode: EnhancementMode.cinemaHdr,
      );

      final effects = config.toVideoEffectsConfig();
      expect(effects.contrast, closeTo(18.0, 0.01));
      expect(effects.brightness, closeTo(-2.0, 0.01)); // inky blacks
      expect(effects.gamma, closeTo(-6.0, 0.01)); // rich S-curve
      expect(effects.sepia, isTrue); // subtle filmic warmth
      expect(effects.sepiaIntensity, closeTo(0.08, 0.01));
    });

    test('nightSight expands midtone gamma without lifting true black point', () {
      final config = EnhancementConfig(
        masterToggle: true,
        mode: EnhancementMode.nightSight,
      );

      final effects = config.toVideoEffectsConfig();
      expect(effects.gamma, closeTo(24.0, 0.01)); // shadow lift
      expect(effects.bandingRemoval, isTrue);
      expect(effects.bandingRadius, equals(28)); // noise suppression
      expect(effects.saturation, closeTo(-4.0, 0.01)); // color noise reduction
    });

    test('sportsVivid generates punchy saturation and fast-motion sharpness', () {
      final config = EnhancementConfig(
        masterToggle: true,
        mode: EnhancementMode.sportsVivid,
      );

      final effects = config.toVideoEffectsConfig();
      expect(effects.sharpen, isTrue);
      expect(effects.sharpenSigma, closeTo(1.05, 0.01));
      expect(effects.saturation, closeTo(26.0, 0.01));
      expect(effects.contrast, closeTo(16.0, 0.01));
    });

    test('Enhancement strength scales all parameters proportionally', () {
      final config = EnhancementConfig(
        masterToggle: true,
        mode: EnhancementMode.superClarity,
        strength: 0.5,
      );

      final effects = config.toVideoEffectsConfig();
      expect(effects.sharpenSigma, closeTo(0.85 * 0.5, 0.01));
      expect(effects.contrast, closeTo(10.0 * 0.5, 0.01));
      expect(effects.saturation, closeTo(8.0 * 0.5, 0.01));
    });

    test('JSON serialization round-trip retains all enhancement properties', () {
      final original = EnhancementConfig(
        masterToggle: true,
        mode: EnhancementMode.cinemaHdr,
        strength: 1.25,
        resolution: '4K',
        aiModel: 'Anime (RealESRGAN_x4plus_anime_6B)',
        fpsTarget: 60,
        audioEnhance: true,
        audioEnhanceStrength: 0.85,
        nightMode: true,
        stereo3D: false,
        customSharpenSigma: 1.4,
        customDebandRadius: 20,
        customContrast: 18.0,
        customSaturation: 22.0,
        customGamma: -5.0,
        customBrightness: 3.0,
      );

      final json = original.toJson();
      final restored = EnhancementConfig.fromJson(json);

      expect(restored.masterToggle, isTrue);
      expect(restored.mode, equals(EnhancementMode.cinemaHdr));
      expect(restored.strength, equals(1.25));
      expect(restored.resolution, equals('4K'));
      expect(restored.aiModel, equals('Anime (RealESRGAN_x4plus_anime_6B)'));
      expect(restored.fpsTarget, equals(60));
      expect(restored.audioEnhance, isTrue);
      expect(restored.audioEnhanceStrength, equals(0.85));
      expect(restored.nightMode, isTrue);
      expect(restored.customSharpenSigma, equals(1.4));
      expect(restored.customDebandRadius, equals(20));
      expect(restored.customContrast, equals(18.0));
      expect(restored.customSaturation, equals(22.0));
    });
  });
}
