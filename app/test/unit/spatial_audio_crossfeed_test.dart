import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/audio/domain/spatial_audio_models.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';

void main() {
  group('Spatial Audio & Headphone Crossfeed Engine Tests (VLC REA Parity)', () {
    test('SpatialAudioConfig default state is clean and bypasses filters when disabled', () {
      final config = SpatialAudioConfig();
      expect(config.enabled, isFalse);
      expect(config.crossfeedMode, equals(CrossfeedPreset.bauerDefault));
      expect(config.roomSize, equals(0.5));
      expect(config.stereoWidth, equals(1.0));
      expect(config.virtualSurround, isFalse);

      expect(config.buildAfFilterString(), isEmpty);
    });

    test('CrossfeedPreset generates forensically accurate libavfilter strings', () {
      final config = SpatialAudioConfig(
        enabled: true,
        crossfeedMode: CrossfeedPreset.bauerDefault,
      );

      // Bauer standard: 700 Hz, 4.5 dB crossfeed
      final afString = config.buildAfFilterString();
      expect(afString, contains('crossfeed=f=700:d=4.5'));
    });

    test('Chu Moy and Jan Meier presets produce distinctive audiophile crossfeed parameters', () {
      final chuMoy = SpatialAudioConfig(
        enabled: true,
        crossfeedMode: CrossfeedPreset.chuMoy,
      );
      expect(chuMoy.buildAfFilterString(), contains('crossfeed=f=700:d=6.0'));

      final jMeier = SpatialAudioConfig(
        enabled: true,
        crossfeedMode: CrossfeedPreset.janMeier,
      );
      expect(jMeier.buildAfFilterString(), contains('crossfeed=f=650:d=9.5'));
    });

    test('Spatial Room Acoustics generates valid spatializer filter chain', () {
      final config = SpatialAudioConfig(
        enabled: true,
        crossfeedMode: CrossfeedPreset.off,
        roomSize: 0.8,
        stereoWidth: 1.5,
        virtualSurround: true,
      );

      final afString = config.buildAfFilterString();
      expect(afString, contains('stereowiden=level=0.8'));
      expect(afString, contains('extrastereo=m=1.5'));
      expect(afString, contains('surround=chl_out=stereo'));
    });

    test('Integration with AudioConfig buildMpvAfString includes spatial audio filters', () {
      final audioConfig = AudioConfig();
      audioConfig.spatialAudio.enabled = true;
      audioConfig.spatialAudio.crossfeedMode = CrossfeedPreset.bauerDefault;
      audioConfig.spatialAudio.virtualSurround = true;

      final fullAf = audioConfig.buildMpvAfString();
      expect(fullAf, contains('crossfeed=f=700:d=4.5'));
      expect(fullAf, contains('surround=chl_out=stereo'));
    });
  });
}
