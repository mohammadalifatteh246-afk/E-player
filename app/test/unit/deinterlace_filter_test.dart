import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';

void main() {
  group('Deinterlacing Filter (deinterlace.c Parity) - Unit Tests', () {
    test('DeinterlaceMode maps to VLC/libmpv property values correctly', () {
      expect(DeinterlaceMode.off.mpvValue, equals('no'));
      expect(DeinterlaceMode.auto.mpvValue, equals('auto'));
      expect(DeinterlaceMode.on.mpvValue, equals('yes'));
      expect(DeinterlaceMode.off.vlcValue, equals(0));
      expect(DeinterlaceMode.auto.vlcValue, equals(-1));
      expect(DeinterlaceMode.on.vlcValue, equals(1));
    });

    test('DeinterlaceAlgorithm resolves correct FFmpeg/mpv filter strings', () {
      expect(DeinterlaceAlgorithm.yadif.mpvFilterString, equals('yadif=mode=send_frame:parity=auto:deint=all'));
      expect(DeinterlaceAlgorithm.yadif2x.mpvFilterString, equals('yadif=mode=send_field:parity=auto:deint=all'));
      expect(DeinterlaceAlgorithm.bob.mpvFilterString, equals('bwdif=mode=send_field:parity=auto:deint=all'));
      expect(DeinterlaceAlgorithm.blend.mpvFilterString, equals('pp=lb'));
      expect(DeinterlaceAlgorithm.linear.mpvFilterString, equals('pp=li'));
      expect(DeinterlaceAlgorithm.ivtc.mpvFilterString, equals('pullup'));
    });

    test('DeinterlaceMode cycle helper replicates VLC hotkey "d" sequence', () {
      expect(DeinterlaceMode.off.next(), equals(DeinterlaceMode.auto));
      expect(DeinterlaceMode.auto.next(), equals(DeinterlaceMode.on));
      expect(DeinterlaceMode.on.next(), equals(DeinterlaceMode.off));
    });

    test('VideoEffectsConfig initializes with deinterlacing disabled by default', () {
      final config = VideoEffectsConfig();
      expect(config.deinterlaceMode, equals(DeinterlaceMode.off));
      expect(config.deinterlaceAlgorithm, equals(DeinterlaceAlgorithm.yadif));
    });

    test('VideoEffectsConfig toMpvFilterString includes deinterlace filter when active', () {
      final config = VideoEffectsConfig(
        deinterlaceMode: DeinterlaceMode.on,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.yadif2x,
      );

      final vfString = config.toMpvFilterString();
      expect(vfString, contains('yadif=mode=send_field:parity=auto:deint=all'));
    });

    test('VideoEffectsConfig toMpvFilterString excludes deinterlace filter when mode is off', () {
      final config = VideoEffectsConfig(
        deinterlaceMode: DeinterlaceMode.off,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.yadif,
      );

      final vfString = config.toMpvFilterString();
      expect(vfString, isNot(contains('yadif')));
    });

    test('VideoEffectsConfig JSON serialization round-trip retains deinterlace settings', () {
      final config = VideoEffectsConfig(
        deinterlaceMode: DeinterlaceMode.on,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.bob,
      );

      final json = config.toJson();
      final restored = VideoEffectsConfig.fromJson(json);

      expect(restored.deinterlaceMode, equals(DeinterlaceMode.on));
      expect(restored.deinterlaceAlgorithm, equals(DeinterlaceAlgorithm.bob));
    });

    test('VideoEffectsConfig copyWith updates deinterlace parameters cleanly', () {
      final config = VideoEffectsConfig();
      final updated = config.copyWith(
        deinterlaceMode: DeinterlaceMode.auto,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.ivtc,
      );

      expect(updated.deinterlaceMode, equals(DeinterlaceMode.auto));
      expect(updated.deinterlaceAlgorithm, equals(DeinterlaceAlgorithm.ivtc));
    });
  });
}
