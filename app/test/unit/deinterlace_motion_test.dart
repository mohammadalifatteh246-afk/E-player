import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';

void main() {
  group('Deinterlace & Motion Blur Models & Algorithms', () {
    test('computeMotionBlurWeights computes accurate binomial kernels for 2 to 7 frames', () {
      expect(computeMotionBlurWeights(1), '1 1'); // clamped to 2
      expect(computeMotionBlurWeights(2), '1 1');
      expect(computeMotionBlurWeights(3), '1 2 1');
      expect(computeMotionBlurWeights(4), '1 2 2 1');
      expect(computeMotionBlurWeights(5), '1 2 3 2 1');
      expect(computeMotionBlurWeights(6), '1 2 3 3 2 1');
      expect(computeMotionBlurWeights(7), '1 2 3 4 3 2 1');
      expect(computeMotionBlurWeights(10), '1 2 3 4 3 2 1'); // clamped to 7
    });

    test('MotionBlurPreset parameters match VLC motionblur.c parity specifications', () {
      expect(MotionBlurPreset.subtle.defaultFrames, 2);
      expect(MotionBlurPreset.subtle.defaultWeights, '1 1');

      expect(MotionBlurPreset.cinematic.defaultFrames, 3);
      expect(MotionBlurPreset.cinematic.defaultWeights, '1 2 1');

      expect(MotionBlurPreset.sports.defaultFrames, 4);
      expect(MotionBlurPreset.sports.defaultWeights, '1 2 2 1');

      expect(MotionBlurPreset.dreamy.defaultFrames, 6);
      expect(MotionBlurPreset.dreamy.defaultWeights, '1 2 3 3 2 1');

      expect(MotionBlurPreset.custom.defaultFrames, 3);
    });

    test('DeinterlaceFieldOrder provides correct mpv parity flags', () {
      expect(DeinterlaceFieldOrder.auto.mpvParity, 'auto');
      expect(DeinterlaceFieldOrder.tff.mpvParity, 'tff');
      expect(DeinterlaceFieldOrder.bff.mpvParity, 'bff');
    });

    test('DeinterlaceAlgorithm.buildFilterString generates correct parity-aware filters', () {
      // YADIF 1x
      expect(
        DeinterlaceAlgorithm.yadif.buildFilterString(DeinterlaceFieldOrder.auto),
        'yadif=mode=send_frame:parity=auto:deint=all',
      );
      expect(
        DeinterlaceAlgorithm.yadif.buildFilterString(DeinterlaceFieldOrder.tff),
        'yadif=mode=send_frame:parity=tff:deint=all',
      );
      expect(
        DeinterlaceAlgorithm.yadif.buildFilterString(DeinterlaceFieldOrder.bff),
        'yadif=mode=send_frame:parity=bff:deint=all',
      );

      // YADIF 2x (Field doubler 50/60fps)
      expect(
        DeinterlaceAlgorithm.yadif2x.buildFilterString(DeinterlaceFieldOrder.tff),
        'yadif=mode=send_field:parity=tff:deint=all',
      );

      // Bob Weaver BWDIF
      expect(
        DeinterlaceAlgorithm.bob.buildFilterString(DeinterlaceFieldOrder.bff),
        'bwdif=mode=send_field:parity=bff:deint=all',
      );

      // Fixed post-processing filters
      expect(DeinterlaceAlgorithm.blend.buildFilterString(), 'pp=lb');
      expect(DeinterlaceAlgorithm.linear.buildFilterString(), 'pp=li');
      expect(DeinterlaceAlgorithm.ivtc.buildFilterString(), 'pullup');
    });
  });

  group('VideoEffectsConfig libmpv Filter Graph Generation', () {
    test('buildMpvVfString returns empty string for neutral defaults', () {
      final config = VideoEffectsConfig();
      expect(config.buildMpvVfString(), '');
      expect(config.isNeutral, isTrue);
    });

    test('buildMpvVfString generates correct deinterlacing filter with parity', () {
      final config = VideoEffectsConfig(
        deinterlaceMode: DeinterlaceMode.on,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.yadif2x,
        deinterlaceFieldOrder: DeinterlaceFieldOrder.tff,
      );
      expect(config.buildMpvVfString(), 'yadif=mode=send_field:parity=tff:deint=all');
      expect(config.isNeutral, isFalse);
    });

    test('buildMpvVfString generates correct tmix motion blur filter', () {
      final config = VideoEffectsConfig(
        motionBlurEnabled: true,
        motionBlurFrames: 4,
      );
      expect(config.buildMpvVfString(), 'tmix=frames=4:weights="1 2 2 1"');
      expect(config.isNeutral, isFalse);
    });

    test('buildMpvVfString chains deinterlace and motion blur together', () {
      final config = VideoEffectsConfig(
        deinterlaceMode: DeinterlaceMode.auto,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.bob,
        deinterlaceFieldOrder: DeinterlaceFieldOrder.auto,
        motionBlurEnabled: true,
        motionBlurFrames: 3,
      );
      expect(
        config.buildMpvVfString(),
        'bwdif=mode=send_field:parity=auto:deint=all,tmix=frames=3:weights="1 2 1"',
      );
    });

    test('masterEnabled bypass suppresses all filters', () {
      final config = VideoEffectsConfig(
        masterEnabled: false,
        deinterlaceMode: DeinterlaceMode.on,
        motionBlurEnabled: true,
      );
      expect(config.buildMpvVfString(), '');
    });

    test('resetDeinterlaceAndMotionBlur resets only target fields', () {
      final config = VideoEffectsConfig(
        contrast: 20.0,
        deinterlaceMode: DeinterlaceMode.on,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.yadif2x,
        deinterlaceFieldOrder: DeinterlaceFieldOrder.bff,
        motionBlurEnabled: true,
        motionBlurFrames: 5,
        motionBlurPreset: MotionBlurPreset.custom,
      );

      config.resetDeinterlaceAndMotionBlur();

      expect(config.deinterlaceMode, DeinterlaceMode.off);
      expect(config.deinterlaceAlgorithm, DeinterlaceAlgorithm.yadif);
      expect(config.deinterlaceFieldOrder, DeinterlaceFieldOrder.auto);
      expect(config.motionBlurEnabled, isFalse);
      expect(config.motionBlurPreset, MotionBlurPreset.cinematic);
      expect(config.motionBlurFrames, 3);
      expect(config.contrast, 20.0); // Other effects untouched
    });

    test('copyWith and JSON serialization preserve deinterlace and motion blur properties', () {
      final original = VideoEffectsConfig(
        deinterlaceMode: DeinterlaceMode.on,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.bob,
        deinterlaceFieldOrder: DeinterlaceFieldOrder.tff,
        motionBlurEnabled: true,
        motionBlurPreset: MotionBlurPreset.sports,
        motionBlurFrames: 4,
      );

      final copy = original.copyWith(motionBlurFrames: 5);
      expect(copy.motionBlurFrames, 5);
      expect(copy.deinterlaceAlgorithm, DeinterlaceAlgorithm.bob);
      expect(copy.deinterlaceFieldOrder, DeinterlaceFieldOrder.tff);

      final json = original.toJson();
      expect(json['deinterlaceMode'], 'on');
      expect(json['deinterlaceAlgorithm'], 'bob');
      expect(json['deinterlaceFieldOrder'], 'tff');
      expect(json['motionBlurEnabled'], isTrue);
      expect(json['motionBlurPreset'], 'sports');
      expect(json['motionBlurFrames'], 4);

      final restored = VideoEffectsConfig.fromJson(json);
      expect(restored.deinterlaceMode, DeinterlaceMode.on);
      expect(restored.deinterlaceAlgorithm, DeinterlaceAlgorithm.bob);
      expect(restored.deinterlaceFieldOrder, DeinterlaceFieldOrder.tff);
      expect(restored.motionBlurEnabled, isTrue);
      expect(restored.motionBlurPreset, MotionBlurPreset.sports);
      expect(restored.motionBlurFrames, 4);
    });
  });
}
