import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3D Anaglyph Video Filter Tests (VLC anaglyph.c & stereo3d Parity)', () {
    test('1. Default configuration has anaglyph disabled with standard defaults', () {
      final config = VideoEffectsConfig();
      expect(config.anaglyphEnabled, isFalse);
      expect(config.anaglyphSource, equals(AnaglyphSourceMode.synthetic2D));
      expect(config.anaglyphMatrix, equals(AnaglyphColorMatrix.redCyanDubois));
      expect(config.anaglyphParallax, equals(8.0));
      expect(config.anaglyphSwapEyes, isFalse);
      expect(config.isNeutral, isTrue);

      config.anaglyphEnabled = true;
      expect(config.isNeutral, isFalse);
    });

    test('2. Synthetic 2D mode generates correct rgbashift horizontal parallax filters', () {
      // Default Red-Cyan
      final cfg1 = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.synthetic2D,
        anaglyphMatrix: AnaglyphColorMatrix.redCyanDubois,
        anaglyphParallax: 10.0,
        anaglyphSwapEyes: false,
      );
      expect(cfg1.buildMpvVfString(), equals('rgbashift=rh=10:gh=-10:bh=-10'));

      // Red-Cyan with Swapped Eyes (inverted shift)
      final cfg2 = cfg1.copyWith(anaglyphSwapEyes: true);
      expect(cfg2.buildMpvVfString(), equals('rgbashift=rh=-10:gh=10:bh=10'));

      // Green-Magenta Trioscopic
      final cfg3 = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.synthetic2D,
        anaglyphMatrix: AnaglyphColorMatrix.greenMagenta,
        anaglyphParallax: 12.0,
      );
      expect(cfg3.buildMpvVfString(), equals('rgbashift=gh=12:rh=-12:bh=-12'));

      // Amber-Blue ColorCode
      final cfg4 = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.synthetic2D,
        anaglyphMatrix: AnaglyphColorMatrix.amberBlue,
        anaglyphParallax: 6.0,
      );
      expect(cfg4.buildMpvVfString(), equals('rgbashift=rh=6:gh=6:bh=-6'));
    });

    test('3. Stereoscopic 3D modes generate correct stereo3d in/out filters', () {
      // Side-by-Side Half (Half-SBS) -> Dubois Red/Cyan
      final sbsHalf = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.sideBySideHalf,
        anaglyphMatrix: AnaglyphColorMatrix.redCyanDubois,
        anaglyphSwapEyes: false,
      );
      expect(sbsHalf.buildMpvVfString(), equals('stereo3d=in=sbs2l:out=arrc'));

      // Side-by-Side Half with Swapped Eyes
      final sbsHalfSwapped = sbsHalf.copyWith(anaglyphSwapEyes: true);
      expect(sbsHalfSwapped.buildMpvVfString(), equals('stereo3d=in=sbs2r:out=arrc'));

      // Side-by-Side Full -> Full Color Red/Cyan
      final sbsFull = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.sideBySideFull,
        anaglyphMatrix: AnaglyphColorMatrix.redCyanColor,
      );
      expect(sbsFull.buildMpvVfString(), equals('stereo3d=in=sbsl:out=arcc'));

      // Top-and-Bottom Half -> Green-Magenta Trioscopic
      final tabHalf = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.topAndBottomHalf,
        anaglyphMatrix: AnaglyphColorMatrix.greenMagenta,
      );
      expect(tabHalf.buildMpvVfString(), equals('stereo3d=in=ab2l:out=agmd'));

      // Top-and-Bottom Full -> Amber-Blue ColorCode
      final tabFull = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.topAndBottomFull,
        anaglyphMatrix: AnaglyphColorMatrix.amberBlue,
      );
      expect(tabFull.buildMpvVfString(), equals('stereo3d=in=abl:out=aybd'));
    });

    test('4. Serialization round-trip preserves all 3D anaglyph properties', () {
      final config = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.topAndBottomHalf,
        anaglyphMatrix: AnaglyphColorMatrix.amberBlue,
        anaglyphParallax: 18.5,
        anaglyphSwapEyes: true,
      );

      final json = config.toJson();
      expect(json['anaglyphEnabled'], isTrue);
      expect(json['anaglyphSource'], equals('topAndBottomHalf'));
      expect(json['anaglyphMatrix'], equals('amberBlue'));
      expect(json['anaglyphParallax'], equals(18.5));
      expect(json['anaglyphSwapEyes'], isTrue);

      final restored = VideoEffectsConfig.fromJson(json);
      expect(restored.anaglyphEnabled, isTrue);
      expect(restored.anaglyphSource, equals(AnaglyphSourceMode.topAndBottomHalf));
      expect(restored.anaglyphMatrix, equals(AnaglyphColorMatrix.amberBlue));
      expect(restored.anaglyphParallax, equals(18.5));
      expect(restored.anaglyphSwapEyes, isTrue);
    });

    test('5. resetAnaglyph restores defaults cleanly', () {
      final config = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.sideBySideHalf,
        anaglyphMatrix: AnaglyphColorMatrix.greenMagenta,
        anaglyphParallax: 25.0,
        anaglyphSwapEyes: true,
      );
      config.resetAnaglyph();

      expect(config.anaglyphEnabled, isFalse);
      expect(config.anaglyphSource, equals(AnaglyphSourceMode.synthetic2D));
      expect(config.anaglyphMatrix, equals(AnaglyphColorMatrix.redCyanDubois));
      expect(config.anaglyphParallax, equals(8.0));
      expect(config.anaglyphSwapEyes, isFalse);
    });
  });
}
