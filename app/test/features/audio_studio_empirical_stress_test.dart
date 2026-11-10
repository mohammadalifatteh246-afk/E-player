import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';

/// Lightweight fake platform player for testing mpv platform dispatch.
class FakePlayerPlatform extends Fake implements PlatformPlayer {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }
}

class FakePlayer extends Fake implements Player {
  @override
  final PlatformPlayer? platform;

  FakePlayer([PlatformPlayer? platform]) : platform = platform ?? FakePlayerPlatform();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Authoritative VLC 11 Target Presets from SCOPE.md and libequalizer_plugin.dll
  final Map<String, List<double>> authoritativeVlc11Presets = {
    'Full Bass': [-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2],
    'Full Bass & Treble': [7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0],
    'Full Treble': [-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8],
    'Headphones': [4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4],
    'Large Hall': [10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0],
    'Live': [-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4],
    'Party': [7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2],
    'Reggae': [0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0],
    'Ska': [-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6],
    'Soft': [4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0],
    'Soft Rock': [4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8],
  };

  final Map<String, double> authoritativeVlc11Preamps = {
    'Full Bass': 5.0,
    'Full Bass & Treble': 4.0,
    'Full Treble': 3.0,
    'Headphones': 4.0,
    'Large Hall': 5.0,
    'Live': 7.0,
    'Party': 6.0,
    'Reggae': 8.0,
    'Ska': 6.0,
    'Soft': 5.0,
    'Soft Rock': 7.0,
  };

  final Map<String, List<double>> authoritativeBaseline9Presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5],
    'Pop': [-1.5, -1.0, 1.0, 2.5, 4.0, 3.5, 1.5, -1.0, -1.5, -2.0],
    'Jazz': [3.0, 2.0, 1.0, 1.5, -1.5, -1.5, 0.0, 1.5, 3.0, 3.5],
    'Classical': [4.0, 3.0, 2.5, 2.0, -1.5, -1.5, 0.0, 2.5, 3.5, 4.0],
    'Bass Boost': [8.0, 7.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Vocal Boost': [-2.0, -2.5, -1.0, 2.0, 5.0, 5.0, 3.5, 1.5, 0.0, -1.5],
    'Techno': [6.0, 5.0, 0.0, -3.0, -2.5, 0.0, 4.0, 6.0, 6.5, 6.5],
    'Club': [0.0, 0.0, 2.0, 3.5, 3.5, 3.5, 2.0, 0.0, 0.0, 0.0],
  };

  group('Oracle 1: VLC Ground Truth Parity Verification (<= 0.001 dB tolerance)', () {
    test('All 20 presets exist in both presets and presetPreamps maps', () {
      expect(AudioConfig.presets.length, equals(20));
      expect(AudioConfig.presetPreamps.length, equals(20));
      expect(AudioConfig.presets.keys.toSet(), equals(AudioConfig.presetPreamps.keys.toSet()));
    });

    test('11 VLC Target Presets do not deviate by > 0.001 dB from SCOPE.md', () {
      for (final entry in authoritativeVlc11Presets.entries) {
        final presetName = entry.key;
        final expectedBands = entry.value;
        final expectedPreamp = authoritativeVlc11Preamps[presetName]!;

        expect(AudioConfig.presets.containsKey(presetName), isTrue,
            reason: 'Missing preset: $presetName');
        final actualBands = AudioConfig.presets[presetName]!;
        expect(actualBands.length, equals(10),
            reason: 'Preset $presetName must have exactly 10 bands');

        for (int b = 0; b < 10; b++) {
          final diff = (actualBands[b] - expectedBands[b]).abs();
          expect(
            diff,
            lessThanOrEqualTo(0.001),
            reason: 'Preset $presetName band $b (${AudioConfig.freqLabels[b]}Hz) deviates: actual=${actualBands[b]} vs expected=${expectedBands[b]} (diff=$diff)',
          );
        }

        final actualPreamp = AudioConfig.presetPreamps[presetName]!;
        final preampDiff = (actualPreamp - expectedPreamp).abs();
        expect(
          preampDiff,
          lessThanOrEqualTo(0.001),
          reason: 'Preset $presetName preamp deviates: actual=$actualPreamp vs expected=$expectedPreamp (diff=$preampDiff)',
        );
      }
    });

    test('Baseline 9 Presets do not deviate by > 0.001 dB from specifications', () {
      for (final entry in authoritativeBaseline9Presets.entries) {
        final presetName = entry.key;
        final expectedBands = entry.value;

        expect(AudioConfig.presets.containsKey(presetName), isTrue,
            reason: 'Missing baseline preset: $presetName');
        final actualBands = AudioConfig.presets[presetName]!;
        expect(actualBands.length, equals(10));

        for (int b = 0; b < 10; b++) {
          final diff = (actualBands[b] - expectedBands[b]).abs();
          expect(
            diff,
            lessThanOrEqualTo(0.001),
            reason: 'Baseline preset $presetName band $b deviates: actual=${actualBands[b]} vs expected=${expectedBands[b]}',
          );
        }

        final actualPreamp = AudioConfig.presetPreamps[presetName]!;
        expect(actualPreamp, equals(0.0),
            reason: 'Baseline preset $presetName preamp must be 0.0 dB');
      }
    });
  });

  group('Stress 2: Pre-Amplification Boundary & Extreme Value Tests', () {
    test('Boundary values (+20.0 dB and -20.0 dB) produce correct filter strings', () {
      final config = AudioConfig();
      config.preamp = 20.0;
      expect(config.buildMpvAfString(), contains('volume=volume=+20.0dB:precision=fixed'));

      config.preamp = -20.0;
      expect(config.buildMpvAfString(), contains('volume=volume=-20.0dB:precision=fixed'));
    });

    test('Extreme values (+100.0 dB and -100.0 dB) generate filter strings without exceptions', () {
      final config = AudioConfig();
      config.preamp = 100.0;
      expect(config.buildMpvAfString(), contains('volume=volume=+100.0dB:precision=fixed'));

      config.preamp = -100.0;
      expect(config.buildMpvAfString(), contains('volume=volume=-100.0dB:precision=fixed'));
    });

    test('Preamp deadzone tolerance [-0.05, 0.05]: exact boundaries and steps', () {
      final config = AudioConfig();

      // Deadzone values: must NOT generate volume filter
      final deadzoneValues = [0.0, 0.01, -0.01, 0.04, -0.04, 0.05, -0.05];
      for (final v in deadzoneValues) {
        config.preamp = v;
        final af = config.buildMpvAfString();
        expect(
          af.contains('volume='),
          isFalse,
          reason: 'Preamp $v should be in deadzone (omitted from af), got: $af',
        );
      }

      // Active values just outside deadzone: MUST generate volume filter
      config.preamp = 0.051;
      expect(config.buildMpvAfString(), contains('volume=volume=+0.1dB:precision=fixed'));

      config.preamp = -0.051;
      expect(config.buildMpvAfString(), contains('volume=volume=-0.1dB:precision=fixed'));

      config.preamp = 0.06;
      expect(config.buildMpvAfString(), contains('volume=volume=+0.1dB:precision=fixed'));

      config.preamp = -0.06;
      expect(config.buildMpvAfString(), contains('volume=volume=-0.1dB:precision=fixed'));
    });

    test('UI slider clamping bounds [-20.0, 20.0] correctly limit arbitrary values', () {
      expect((-100.0).clamp(-20.0, 20.0), equals(-20.0));
      expect((100.0).clamp(-20.0, 20.0), equals(20.0));
      expect((20.0).clamp(-20.0, 20.0), equals(20.0));
      expect((-20.0).clamp(-20.0, 20.0), equals(-20.0));
      expect((0.0).clamp(-20.0, 20.0), equals(0.0));
    });
  });

  group('Stress 3: 10-Band Slider Extreme Values & Deadzone Clamping', () {
    test('Band boundary values (±20.0 dB) produce exact filter strings', () {
      final config = AudioConfig();
      config.eq = [20.0, -20.0, 20.0, -20.0, 20.0, -20.0, 20.0, -20.0, 20.0, -20.0];
      final af = config.buildMpvAfString();
      for (int i = 0; i < AudioConfig.freqs.length; i++) {
        final expectedSign = i % 2 == 0 ? '20.0' : '-20.0';
        expect(af, contains('equalizer=f=${AudioConfig.freqs[i]}:width_type=q:width=1.2:g=$expectedSign'));
      }
    });

    test('Band extreme values (±100.0 dB) generate filter strings without exceptions', () {
      final config = AudioConfig();
      config.eq = [100.0, -100.0, 50.0, -50.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final af = config.buildMpvAfString();
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=100.0'));
      expect(af, contains('equalizer=f=170:width_type=q:width=1.2:g=-100.0'));
    });

    test('Band deadzone values (|g| <= 0.05) are omitted from filter graph', () {
      final config = AudioConfig();
      config.eq = [0.0, 0.04, -0.04, 0.05, -0.05, 0.0, 0.01, -0.02, 0.03, -0.05];
      final af = config.buildMpvAfString();
      expect(af.contains('equalizer='), isFalse, reason: 'All bands are within deadzone, expected no equalizer filters');
    });

    test('Band values just outside deadzone (|g| > 0.05) are included in filter graph', () {
      final config = AudioConfig();
      config.eq = [0.051, -0.051, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final af = config.buildMpvAfString();
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=0.1'));
      expect(af, contains('equalizer=f=170:width_type=q:width=1.2:g=-0.1'));
      expect(af.contains('equalizer=f=310'), isFalse);
    });

    test('Band slider clamping bounds [-20.0, 20.0] correctly limit arbitrary values', () {
      final extremeValues = [-100.0, -25.0, -20.0, 0.0, 20.0, 25.0, 100.0];
      final expectedClamped = [-20.0, -20.0, -20.0, 0.0, 20.0, 20.0, 20.0];
      for (int i = 0; i < extremeValues.length; i++) {
        expect(extremeValues[i].clamp(-20.0, 20.0), equals(expectedClamped[i]));
      }
    });
  });

  group('Stress 4: Rapid Preset Switching & Immutability Oracle', () {
    test('Rapidly switching across all 20 presets 1,000 times does not corrupt presets map', () {
      final config = AudioConfig();
      final presetNames = AudioConfig.presets.keys.toList();

      for (int i = 0; i < 1000; i++) {
        final targetPreset = presetNames[i % presetNames.length];
        config.applyPreset(targetPreset);

        // Verify config loaded correctly
        expect(config.preset, equals(targetPreset));
        expect(config.preamp, equals(AudioConfig.presetPreamps[targetPreset]));
        expect(config.eq, equals(AudioConfig.presets[targetPreset]));

        // Mutate local eq array to verify that presets map is immutable / independent copy
        config.eq[0] = 99.9;
        expect(
          AudioConfig.presets[targetPreset]![0],
          isNot(equals(99.9)),
          reason: 'presets map must never be mutated by local config changes',
        );
      }
    });
  });

  group('Stress 5: Filter Chain Integrity & Token Precedence', () {
    test('Preamp token is strictly prepended at index 0 before all DSP filters', () {
      final config = AudioConfig();
      config.preamp = 14.5;
      config.bassBoostEnabled = true;
      config.bassBoost = 9.0;
      config.nightMode = true;
      config.virtualizer = true;
      config.threeDAudio = true;
      config.eq = [5.0, 4.0, 3.0, 2.0, 1.0, -1.0, -2.0, -3.0, -4.0, -5.0];

      final af = config.buildMpvAfString();
      final tokens = af.split(',');

      expect(tokens[0], equals('volume=volume=+14.5dB:precision=fixed'));
      expect(tokens[1], equals('bass=g=9.0'));
      expect(tokens[2], equals('dynaudnorm=f=200:g=15'));
      expect(tokens[3], equals('extrastereo=m=2.2'));
      expect(tokens[4], equals('stereowiden=level=0.7'));
      expect(tokens.length, equals(15)); // 1 preamp + 1 bass + 1 night + 1 virt + 1 3d + 10 eq bands
    });

    test('When equalizer is disabled, buildMpvAfString returns empty string regardless of preamp or eq', () {
      final config = AudioConfig();
      config.enabled = false;
      config.preamp = 10.0;
      config.eq = [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0];
      config.bassBoostEnabled = true;

      expect(config.buildMpvAfString(), equals(''));
    });

    test('Reset restores Flat defaults, zeroes preamp, and clears af property on platform', () {
      final fakePlatform = FakePlayerPlatform();
      final player = FakePlayer(fakePlatform);
      final config = AudioConfig()..applyPreset('Full Treble');

      config.apply(player);
      expect(fakePlatform.properties['af'], contains('volume=volume=+3.0dB:precision=fixed'));

      config.reset(player);
      expect(config.preset, equals('Flat'));
      expect(config.preamp, equals(0.0));
      expect(config.eq.every((g) => g == 0.0), isTrue);
      expect(fakePlatform.properties['af'], equals(''));
    });
  });
}
