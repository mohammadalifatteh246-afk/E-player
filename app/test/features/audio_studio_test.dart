import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';

/// Lightweight in-memory platform mock simulating libmpv platform property store.
class FakePlayerPlatform extends Fake implements PlatformPlayer {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];
  final List<AudioTrack> setAudioTrackCalls = [];

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    setAudioTrackCalls.add(track);
  }
}

/// Fake platform player that throws on setProperty to test error handling.
class ThrowingPlatformPlayer extends Fake implements PlatformPlayer {
  void setProperty(String property, String value) {
    throw Exception('Simulated platform failure');
  }
}

class FakePlayerState extends Fake implements PlayerState {
  @override
  Duration get position => Duration.zero;
  @override
  double get volume => 100.0;
  @override
  bool get playing => false;
}

/// Lightweight mock Player satisfying Player interface via Fake.
class FakePlayer extends Fake implements Player {
  @override
  final PlatformPlayer? platform;

  @override
  final PlayerState state = FakePlayerState();

  FakePlayer([PlatformPlayer? platform]) : platform = platform ?? FakePlayerPlatform();

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    await platform?.setAudioTrack(track);
  }
}

void main() {
  group('Group 1: AudioConfig Default State & Presets Registry', () {
    test('Default configuration initializes with correct defaults', () {
      final config = AudioConfig();
      expect(config.enabled, isTrue);
      expect(config.preset, equals('Rock'));
      expect(config.preamp, equals(0.0));
      expect(config.eq.length, equals(10));
      expect(
        AudioConfig.freqs,
        equals([60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]),
      );
      expect(
        AudioConfig.freqLabels,
        equals(['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K']),
      );
    });

    test('Registry contains exactly 20 presets', () {
      expect(AudioConfig.presets.length, equals(20));
      expect(AudioConfig.presetPreamps.length, equals(20));
    });

    test('Every preset has exactly 10 bands', () {
      for (final entry in AudioConfig.presets.entries) {
        expect(
          entry.value.length,
          equals(10),
          reason: 'Preset ${entry.key} must have exactly 10 bands',
        );
      }
    });

    test('Unknown preset name is a safe no-op in applyPreset', () {
      final config = AudioConfig();
      final initialBands = List<double>.from(config.eq);
      final initialPreamp = config.preamp;
      config.applyPreset('NonExistentPresetXYZ');
      expect(config.preset, equals('Rock'));
      expect(config.eq, equals(initialBands));
      expect(config.preamp, equals(initialPreamp));
    });
  });

  group('Group 2: 20 Presets Parity & Preamp Verification', () {
    // 11 Target VLC Canonical Presets (Forensically verified against libequalizer_plugin.dll)
    test('Full Bass preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Full Bass');
      expect(config.preamp, equals(5.0));
      expect(
        config.eq,
        equals([-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]),
      );
    });

    test('Full Bass & Treble preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Full Bass & Treble');
      expect(config.preamp, equals(4.0));
      expect(
        config.eq,
        equals([7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]),
      );
    });

    test('Full Treble preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Full Treble');
      expect(config.preamp, equals(3.0));
      expect(
        config.eq,
        equals([-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]),
      );
    });

    test('Headphones preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Headphones');
      expect(config.preamp, equals(4.0));
      expect(
        config.eq,
        equals([4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]),
      );
    });

    test('Large Hall preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Large Hall');
      expect(config.preamp, equals(5.0));
      expect(
        config.eq,
        equals([10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0]),
      );
    });

    test('Live preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Live');
      expect(config.preamp, equals(7.0));
      expect(
        config.eq,
        equals([-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]),
      );
    });

    test('Party preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Party');
      expect(config.preamp, equals(6.0));
      expect(
        config.eq,
        equals([7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2]),
      );
    });

    test('Reggae preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Reggae');
      expect(config.preamp, equals(8.0));
      expect(
        config.eq,
        equals([0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0]),
      );
    });

    test('Ska preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Ska');
      expect(config.preamp, equals(6.0));
      expect(
        config.eq,
        equals([-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]),
      );
    });

    test('Soft preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Soft');
      expect(config.preamp, equals(5.0));
      expect(
        config.eq,
        equals([4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0]),
      );
    });

    test('Soft Rock preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Soft Rock');
      expect(config.preamp, equals(7.0));
      expect(
        config.eq,
        equals([4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8]),
      );
    });

    // Baseline 9 Presets Retention
    test('Baseline 9 presets remain intact with correct band counts and values', () {
      final expectedBaseline = [
        'Flat',
        'Rock',
        'Pop',
        'Jazz',
        'Classical',
        'Bass Boost',
        'Vocal Boost',
        'Techno',
        'Club',
      ];
      for (final p in expectedBaseline) {
        expect(AudioConfig.presets.containsKey(p), isTrue, reason: 'Preset $p must exist');
        expect(AudioConfig.presets[p]!.length, equals(10));
      }
    });
  });

  group('Group 3: Pre-Amplification Filter String Generation', () {
    test('Positive preamp formats as volume=volume=+X.XdB:precision=fixed', () {
      final config = AudioConfig();
      config.preamp = 5.0;
      final af = config.buildMpvAfString();
      expect(af, contains('volume=volume=+5.0dB:precision=fixed'));
    });

    test('Negative preamp formats as volume=volume=-X.XdB:precision=fixed', () {
      final config = AudioConfig();
      config.preamp = -12.5;
      final af = config.buildMpvAfString();
      expect(af, contains('volume=volume=-12.5dB:precision=fixed'));
    });

    test('Preamp is omitted when exactly 0.0 dB (bit-perfect pass-through)', () {
      final config = AudioConfig();
      config.preamp = 0.0;
      final af = config.buildMpvAfString();
      expect(af.contains('volume='), isFalse);
    });

    test('Preamp deadzone: omitted when preamp.abs() <= 0.05', () {
      final config = AudioConfig();
      config.preamp = 0.04;
      expect(config.buildMpvAfString().contains('volume='), isFalse);

      config.preamp = -0.05;
      expect(config.buildMpvAfString().contains('volume='), isFalse);

      config.preamp = 0.06;
      expect(config.buildMpvAfString(), contains('volume=volume=+0.1dB:precision=fixed'));

      config.preamp = -0.06;
      expect(config.buildMpvAfString(), contains('volume=volume=-0.1dB:precision=fixed'));
    });

    test('Preamp is prepended at index 0 before equalizer bands and DSP filters', () {
      final config = AudioConfig();
      config.preamp = 6.0;
      config.bassBoostEnabled = true;
      config.bassBoost = 4.0;
      config.nightMode = true;
      config.virtualizer = true;
      config.threeDAudio = true;
      config.eq = [2.0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

      final af = config.buildMpvAfString();
      expect(af.startsWith('volume=volume=+6.0dB:precision=fixed'), isTrue);

      final tokens = af.split(',');
      expect(tokens.first, equals('volume=volume=+6.0dB:precision=fixed'));
      expect(tokens.any((t) => t.startsWith('equalizer=')), isTrue);
    });

    test('Preamp boundary extremes (+20.0dB and -20.0dB)', () {
      final config = AudioConfig();
      config.preamp = 20.0;
      expect(config.buildMpvAfString(), contains('volume=volume=+20.0dB:precision=fixed'));

      config.preamp = -20.0;
      expect(config.buildMpvAfString(), contains('volume=volume=-20.0dB:precision=fixed'));
    });
  });

  group('Group 4: Equalizer Band Gain Scale & Filter Synthesis', () {
    test('Builds equalizer filter tokens for active bands', () {
      final config = AudioConfig();
      config.eq = [3.0, -4.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final af = config.buildMpvAfString();
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=3.0'));
      expect(af, contains('equalizer=f=170:width_type=q:width=1.2:g=-4.5'));
      expect(af.contains('equalizer=f=310'), isFalse);
    });

    test('Full ±20.0dB band headroom limits format correctly', () {
      final config = AudioConfig();
      config.eq[0] = 20.0;
      config.eq[9] = -20.0;
      final af = config.buildMpvAfString();
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=20.0'));
      expect(af, contains('equalizer=f=16000:width_type=q:width=1.2:g=-20.0'));
    });

    test('Neutral bands (|g| <= 0.05) are omitted', () {
      final config = AudioConfig();
      config.eq = [0.02, -0.04, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final af = config.buildMpvAfString();
      expect(af.contains('equalizer='), isFalse);
    });

    test('Reset restores Flat defaults and resets preamp to 0.0 and clears af', () {
      final config = AudioConfig();
      config.applyPreset('Full Bass');
      expect(config.preamp, equals(5.0));

      final fakePlatform = FakePlayerPlatform();
      final player = FakePlayer(fakePlatform);

      config.reset(player);

      expect(config.preset, equals('Flat'));
      expect(config.preamp, equals(0.0));
      expect(config.eq.every((g) => g == 0.0), isTrue);
      expect(config.bassBoost, equals(0.0));
      expect(config.bassBoostEnabled, isFalse);
      expect(config.virtualizer, isFalse);
      expect(config.threeDAudio, isFalse);
      expect(config.nightMode, isFalse);
      expect(fakePlatform.properties['af'], equals(''));
    });
  });

  group('Group 5: Player Platform Dispatch & Mock Verification', () {
    test('apply() sets af property on player.platform', () {
      final fakePlatform = FakePlayerPlatform();
      final player = FakePlayer(fakePlatform);
      final config = AudioConfig()..applyPreset('Full Bass');

      config.apply(player);

      expect(fakePlatform.properties['af'], isNotNull);
      expect(fakePlatform.properties['af'], equals(config.buildMpvAfString()));
      expect(fakePlatform.properties['af'], contains('volume=volume=+5.0dB:precision=fixed'));
    });

    test('apply() sets empty af string when enabled is false', () {
      final fakePlatform = FakePlayerPlatform();
      final player = FakePlayer(fakePlatform);
      final config = AudioConfig()
        ..applyPreset('Full Bass')
        ..enabled = false;

      config.apply(player);

      expect(fakePlatform.properties['af'], equals(''));
    });

    test('apply(null) safely no-ops without exception', () {
      final config = AudioConfig();
      expect(() => config.apply(null), returnsNormally);
    });

    test('apply() safely handles platform exceptions', () {
      final config = AudioConfig();
      final throwingPlayer = FakePlayer(ThrowingPlatformPlayer());
      expect(() => config.apply(throwingPlayer), returnsNormally);
    });
  });

  group('Group 6: Boundary & Scale Tests', () {
    test('All 20 presets in presetPreamps have gains within [-20.0, 20.0]', () {
      for (final entry in AudioConfig.presetPreamps.entries) {
        expect(
          entry.value,
          greaterThanOrEqualTo(-20.0),
          reason: 'Preset ${entry.key} preamp must be >= -20.0',
        );
        expect(
          entry.value,
          lessThanOrEqualTo(20.0),
          reason: 'Preset ${entry.key} preamp must be <= 20.0',
        );
      }
    });

    test('presetPreamps keys match presets keys exactly', () {
      expect(
        AudioConfig.presetPreamps.keys.toSet(),
        equals(AudioConfig.presets.keys.toSet()),
      );
    });

    test('Sequential preset switching updates both eq and preamp cleanly', () {
      final config = AudioConfig();

      config.applyPreset('Full Bass');
      expect(config.preamp, equals(5.0));
      expect(config.eq[0], equals(-8.0));

      config.applyPreset('Live');
      expect(config.preamp, equals(7.0));
      expect(config.eq[0], equals(-4.8));

      config.applyPreset('Full Treble');
      expect(config.preamp, equals(3.0));
      expect(config.eq[9], equals(16.8));

      config.applyPreset('Flat');
      expect(config.preamp, equals(0.0));
      expect(config.eq.every((g) => g == 0.0), isTrue);
    });

    test('Preamp single decimal precision is preserved across positive and negative values', () {
      final config = AudioConfig();
      config.preamp = 7.5;
      expect(config.buildMpvAfString(), contains('volume=volume=+7.5dB:precision=fixed'));

      config.preamp = -3.5;
      expect(config.buildMpvAfString(), contains('volume=volume=-3.5dB:precision=fixed'));
    });
  });

  group('Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch)', () {
    test('AudioConfig initializes with audioDelay == 0.0', () {
      final config = AudioConfig();
      expect(config.audioDelay, equals(0.0));
    });

    test('applyAudioDelay formats delay in seconds with exactly 3 decimals', () {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      config.audioDelay = 0.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('0.000'));

      config.audioDelay = 50.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('0.050'));

      config.audioDelay = -50.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('-0.050'));

      config.audioDelay = 100.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('0.100'));

      config.audioDelay = -100.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('-0.100'));

      config.audioDelay = 1500.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('1.500'));

      config.audioDelay = -2500.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('-2.500'));
    });

    test('Boundary values at -10000.0 and +10000.0 are formatted correctly', () {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      config.audioDelay = 10000.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('10.000'));

      config.audioDelay = -10000.0;
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('-10.000'));
    });

    test('AudioConfig.apply sends both af and audio-delay to player', () {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();
      config.audioDelay = 250.0;

      config.apply(player);
      expect(platform.properties['af'], isNotNull);
      expect(platform.properties['audio-delay'], equals('0.250'));
    });

    test('AudioConfig.apply sends audio-delay even when enabled is false', () {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();
      config.enabled = false;
      config.audioDelay = 750.0;

      config.apply(player);
      expect(platform.properties['af'], equals(''));
      expect(platform.properties['audio-delay'], equals('0.750'));
    });

    test('AudioConfig.reset restores audioDelay to 0.0 and applies 0.000 to player', () {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();
      config.audioDelay = 3500.0;

      config.reset(player);
      expect(config.audioDelay, equals(0.0));
      expect(platform.properties['audio-delay'], equals('0.000'));
    });

    test('Null player or throwing platform in applyAudioDelay is safe', () {
      final config = AudioConfig()..audioDelay = 500.0;

      // Null player must not throw
      expect(() => config.applyAudioDelay(null), returnsNormally);

      // Throwing platform must be caught and handled gracefully
      final throwingPlayer = FakePlayer(ThrowingPlatformPlayer());
      expect(() => config.applyAudioDelay(throwingPlayer), returnsNormally);
      expect(() => config.apply(throwingPlayer), returnsNormally);
    });

    testWidgets('AudioDelaySyncCard UI renders, responds to nudges, and dispatches to player', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      double? reportedDelay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioDelaySyncCard(
              player: player,
              initialDelayMs: 0.0,
              onDelayChanged: (val) => reportedDelay = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify presence of all key components
      expect(find.byKey(const Key('audio_delay_sync_card')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_badge')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_slider')), findsOneWidget);
      expect(find.text('+0 ms'), findsOneWidget);

      // Tap +50ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+50 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.050'));
      expect(reportedDelay, equals(50.0));

      // Tap +100ms -> should become 150ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+150 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.150'));
      expect(reportedDelay, equals(150.0));

      // Tap -50ms -> should become 100ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+100 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.100'));
      expect(reportedDelay, equals(100.0));

      // Tap -100ms -> should become 0ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+0 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.000'));
      expect(reportedDelay, equals(0.0));

      // Tap -50ms from 0 -> should become -50ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_50')));
      await tester.pumpAndSettle();
      expect(find.text('-50 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('-0.050'));
      expect(reportedDelay, equals(-50.0));

      // Tap Reset -> should become 0ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_reset')));
      await tester.pumpAndSettle();
      expect(find.text('+0 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.000'));
      expect(reportedDelay, equals(0.0));
    });
  });

  group('Group 8: AudioStudioSheet Full Widget Mounting & Structural Integrity', () {
    testWidgets('AudioStudioSheet mounts cleanly without Material assertion error in bottom sheet mode', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final error = tester.takeException();
      expect(error, isNull, reason: 'AudioStudioSheet must mount cleanly without Material assertion error');
      expect(find.byType(AudioStudioSheet), findsOneWidget);
      expect(find.text('Audio Equalizer'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Enable Equalizer'), findsOneWidget);
      expect(find.text('Preset'), findsOneWidget);
    });

    testWidgets('AudioStudioSheet mounts cleanly in full-screen mode', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AudioStudioSheet), findsOneWidget);
      // In full-screen mode, top handle and 'Audio Equalizer' title are omitted
      expect(find.text('Audio Equalizer'), findsNothing);
      expect(find.text('Enable Equalizer'), findsOneWidget);
    });

    testWidgets('All 10 Equalizer band vertical sliders and frequency labels build cleanly', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 10 frequency labels are present
      for (final label in AudioConfig.freqLabels) {
        expect(find.text(label), findsOneWidget, reason: 'Band frequency label $label must exist');
      }

      // Verify +20dB and -20dB scale markers exist
      expect(find.text('+20dB'), findsAtLeastNWidgets(2));
      expect(find.text('-20dB'), findsAtLeastNWidgets(2));

      // Verify 10 vertical sliders inside RotatedBox widgets
      final rotatedBoxes = find.byType(RotatedBox);
      expect(rotatedBoxes, findsNWidgets(10));
    });

    testWidgets('Pre-Amplification slider card builds cleanly with reset button and badge', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pre-Amplification'), findsOneWidget);
      expect(find.text('+0.0 dB'), findsOneWidget);
      expect(find.byTooltip('Reset Preamp to 0.0 dB'), findsOneWidget);
    });

    testWidgets('Audio Synchronization Card is embedded in AudioStudioSheet and operational', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audio_delay_sync_card')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_badge')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_slider')), findsOneWidget);
      expect(find.text('+0 ms'), findsOneWidget);

      // Verify all 5 nudge buttons exist
      expect(find.byKey(const Key('audio_delay_nudge_minus_100')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_nudge_minus_50')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_nudge_reset')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_nudge_plus_50')), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_nudge_plus_100')), findsOneWidget);

      // Tap +50ms nudge
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+50 ms'), findsOneWidget);
      expect(config.audioDelay, equals(50.0));
    });

    testWidgets('All boost switch tiles and cards build cleanly and respond to interaction', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bass Boost
      expect(find.text('Bass Boost'), findsOneWidget);
      expect(find.byIcon(Icons.speaker), findsOneWidget);

      // Virtualizer
      expect(find.text('Virtualizer'), findsOneWidget);
      expect(find.text('Stereo soundstage widening'), findsOneWidget);

      // 3D Audio
      expect(find.text('3D Audio'), findsOneWidget);
      expect(find.text('Spatial acoustic simulation'), findsOneWidget);

      // Night Mode
      expect(find.text('Night Mode'), findsOneWidget);
      expect(find.text('Loudness normalization / DRC'), findsOneWidget);

      // Toggle Virtualizer
      expect(config.virtualizer, isTrue);
      final virtualizerFinder = find.widgetWithText(SwitchListTile, 'Virtualizer');
      await tester.ensureVisible(virtualizerFinder);
      await tester.tap(virtualizerFinder);
      await tester.pumpAndSettle();
      expect(config.virtualizer, isFalse);
    });

    testWidgets('Reset to Flat Defaults button resets config and dispatches to player', (tester) async {
      final platform = FakePlayerPlatform();
      final player = FakePlayer(platform);
      final config = AudioConfig()
        ..applyPreset('Rock')
        ..preamp = 5.0
        ..audioDelay = 500.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetFinder = find.text('Reset to Flat Defaults');
      await tester.ensureVisible(resetFinder);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      expect(config.preset, equals('Flat'));
      expect(config.preamp, equals(0.0));
      expect(config.audioDelay, equals(0.0));
      expect(platform.properties['af'], equals(''));
      expect(platform.properties['audio-delay'], equals('0.000'));
    });
  });

  group('Group 9: Audio Track Selector Modal Architecture & Interaction Fixture', () {
    Widget buildAudioTracksModalFixture({
      required List<AudioTrack> tracks,
      required AudioTrack selectedTrack,
      required ValueChanged<AudioTrack> onSelected,
      required VoidCallback onClose,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final activeTrack = selectedTrack;
              return Material(
                key: const Key('audio_tracks_sheet'),
                color: const Color(0xFF1E1E2C),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                    Expanded(
                      child: tracks.isEmpty
                          ? const Center(
                              child: Text(
                                'No audio tracks found',
                                key: Key('audio_tracks_empty'),
                              ),
                            )
                          : ListView.builder(
                              itemCount: tracks.length,
                              itemBuilder: (context, index) {
                                final track = tracks[index];
                                final isSelected = activeTrack.id == track.id;

                                final List<String> metaParts = [];
                                if (track.language != null &&
                                    track.language!.isNotEmpty &&
                                    track.language != track.title) {
                                  metaParts.add(track.language!.toUpperCase());
                                }
                                if (track.codec != null && track.codec!.isNotEmpty) {
                                  metaParts.add(track.codec!.toUpperCase());
                                }
                                if (track.channels != null && track.channels!.isNotEmpty) {
                                  metaParts.add(track.channels!);
                                } else if (track.channelscount != null && track.channelscount! > 0) {
                                  metaParts.add('${track.channelscount} ch');
                                }
                                if (track.samplerate != null && track.samplerate! > 0) {
                                  metaParts.add('${(track.samplerate! / 1000).toStringAsFixed(1)} kHz');
                                }
                                final subtitleText = metaParts.join(' • ');

                                return Material(
                                  color: isSelected
                                      ? const Color(0xFF6C5CE7).withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListTile(
                                    key: Key('audio_track_item_${track.id}'),
                                    title: Text(track.title ?? track.language ?? track.id),
                                    subtitle: subtitleText.isNotEmpty ? Text(subtitleText) : null,
                                    trailing: isSelected
                                        ? const Icon(Icons.check, key: Key('active_track_check'))
                                        : null,
                                    onTap: () => onSelected(track),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('Empty tracks state renders Key("audio_tracks_empty")', (tester) async {
      await tester.pumpWidget(
        buildAudioTracksModalFixture(
          tracks: [],
          selectedTrack: AudioTrack.no(),
          onSelected: (_) {},
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audio_tracks_sheet')), findsOneWidget);
      expect(find.byKey(const Key('audio_tracks_empty')), findsOneWidget);
      expect(find.text('No audio tracks found'), findsOneWidget);
    });

    testWidgets('Populated tracks render keys, uppercase language/codec, channels, kHz sample rate', (tester) async {
      final tracks = [
        const AudioTrack('1', 'English Surround', 'eng', codec: 'aac', channelscount: 6, channels: '5.1', samplerate: 48000),
        const AudioTrack('2', 'Japanese Stereo', 'jpn', codec: 'flac', channelscount: 2, samplerate: 44100),
        const AudioTrack('3', 'Director Commentary', 'eng', codec: 'ac3', channelscount: 2, channels: 'Stereo', samplerate: 48000),
      ];
      AudioTrack? chosenTrack;

      await tester.pumpWidget(
        buildAudioTracksModalFixture(
          tracks: tracks,
          selectedTrack: tracks[0],
          onSelected: (t) => chosenTrack = t,
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audio_tracks_sheet')), findsOneWidget);
      expect(find.byKey(const Key('audio_track_item_1')), findsOneWidget);
      expect(find.byKey(const Key('audio_track_item_2')), findsOneWidget);
      expect(find.byKey(const Key('audio_track_item_3')), findsOneWidget);

      expect(find.text('English Surround'), findsOneWidget);
      expect(find.text('ENG • AAC • 5.1 • 48.0 kHz'), findsOneWidget);

      expect(find.text('Japanese Stereo'), findsOneWidget);
      expect(find.text('JPN • FLAC • 2 ch • 44.1 kHz'), findsOneWidget);

      expect(find.text('Director Commentary'), findsOneWidget);
      expect(find.text('ENG • AC3 • Stereo • 48.0 kHz'), findsOneWidget);

      expect(find.byKey(const Key('active_track_check')), findsOneWidget);

      await tester.tap(find.byKey(const Key('audio_track_item_2')));
      await tester.pumpAndSettle();
      expect(chosenTrack?.id, equals('2'));
      expect(chosenTrack?.title, equals('Japanese Stereo'));
    });
  });
}
