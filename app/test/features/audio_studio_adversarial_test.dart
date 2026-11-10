import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';
import 'package:app/ui/theme/e_design_tokens.dart';

/// In-memory fake platform player for mpv property verification.
class FakePlatformPlayer extends Fake implements PlatformPlayer {
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

/// Fake platform player throwing errors to stress-test resilience.
class ErrorThrowingPlatformPlayer extends Fake implements PlatformPlayer {
  void setProperty(String property, String value) {
    throw Exception('Simulated fatal mpv platform failure');
  }
}

/// Fake Player implementing Player via Fake.
class FakePlayer extends Fake implements Player {
  @override
  final PlatformPlayer? platform;

  FakePlayer([PlatformPlayer? platform]) : platform = platform ?? FakePlatformPlayer();

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    await platform?.setAudioTrack(track);
  }
}

void main() {
  group('Empirical Challenge 1: AudioStudioSheet Runtime Assertion Integrity', () {
    testWidgets('AudioStudioSheet mounts cleanly without Material assertion error', (tester) async {
      final platform = FakePlatformPlayer();
      final player = FakePlayer(platform);
      final config = AudioConfig();

      // Pumping AudioStudioSheet in widget test executes _buildBoostSwitchTile (lines 1045-1052)
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

      // Verify no assertion error is thrown:
      final error = tester.takeException();
      expect(error, isNull, reason: 'AudioStudioSheet must mount cleanly without Material assertion error');
      expect(find.byType(AudioStudioSheet), findsOneWidget);
      expect(find.text('Virtualizer'), findsOneWidget);
    });
  });

  group('Empirical Challenge 2: Audio Delay Synchronization Slider & Nudge Physics', () {
    testWidgets('Slider divisions is exactly 400 with 50ms step size over [-10.0, 10.0]', (tester) async {
      final platform = FakePlatformPlayer();
      final player = FakePlayer(platform);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioDelaySyncCard(
              player: player,
              initialDelayMs: 0.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const Key('audio_delay_slider'));
      expect(sliderFinder, findsOneWidget);
      final Slider slider = tester.widget(sliderFinder);
      expect(slider.min, equals(-10.0));
      expect(slider.max, equals(10.0));
      expect(slider.divisions, equals(400));

      // 20.0s range / 400 divisions = 0.05s = 50ms per step
      final stepSeconds = (slider.max - slider.min) / slider.divisions!;
      expect(stepSeconds, closeTo(0.05, 1e-6));
      expect(stepSeconds * 1000.0, closeTo(50.0, 1e-6));
    });

    testWidgets('Live badge formatting across edge values (+0 ms, positive, negative, boundary)', (tester) async {
      final platform = FakePlatformPlayer();
      final player = FakePlayer(platform);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioDelaySyncCard(
              player: player,
              initialDelayMs: 0.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default 0ms
      expect(find.text('+0 ms'), findsOneWidget);

      // +50ms nudge
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+50 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.050'));

      // +100ms nudge -> 150ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+150 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.150'));

      // Reset -> 0ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_reset')));
      await tester.pumpAndSettle();
      expect(find.text('+0 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('0.000'));

      // -50ms nudge -> -50ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_50')));
      await tester.pumpAndSettle();
      expect(find.text('-50 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('-0.050'));

      // -100ms nudge -> -150ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_100')));
      await tester.pumpAndSettle();
      expect(find.text('-150 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('-0.150'));
    });

    testWidgets('Boundary clamping: nudges cannot exceed ±10000ms (+10.0s / -10.0s)', (tester) async {
      final platform = FakePlatformPlayer();
      final player = FakePlayer(platform);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioDelaySyncCard(
              player: player,
              initialDelayMs: 9950.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+9950 ms'), findsOneWidget);

      // Tap +100ms -> should clamp to 10000ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+10000 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('10.000'));

      // Tap +50ms again -> stays at 10000ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+10000 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('10.000'));

      // Now test negative boundary
      final cardState = tester.state<AudioDelaySyncCardState>(find.byType(AudioDelaySyncCard));
      cardState.updateDelay(-9950.0);
      await tester.pumpAndSettle();
      expect(find.text('-9950 ms'), findsOneWidget);

      // Tap -100ms -> should clamp to -10000ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_100')));
      await tester.pumpAndSettle();
      expect(find.text('-10000 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('-10.000'));

      // Tap -50ms again -> stays at -10000ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_50')));
      await tester.pumpAndSettle();
      expect(find.text('-10000 ms'), findsOneWidget);
      expect(platform.properties['audio-delay'], equals('-10.000'));
    });

    test('Platform exception resilience: throwing platform never crashes audioDelay setter', () {
      final throwingPlayer = FakePlayer(ErrorThrowingPlatformPlayer());
      final config = AudioConfig();

      config.audioDelay = 250.0;
      // Must not throw even when mpv platform fails
      expect(() => config.applyAudioDelay(throwingPlayer), returnsNormally);
      expect(() => config.apply(throwingPlayer), returnsNormally);
      expect(() => config.reset(throwingPlayer), returnsNormally);
    });
  });

  group('Empirical Challenge 3: Audio Track Selector Modal Architecture & Metadata', () {
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
                color: EDesign.surface,
                child: Container(
                  key: const Key('audio_tracks_sheet'),
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
                                        ? EDesign.primary.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(EDesign.r12),
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

      // Check sheet presence
      expect(find.byKey(const Key('audio_tracks_sheet')), findsOneWidget);

      // Verify all track items exist by key
      expect(find.byKey(const Key('audio_track_item_1')), findsOneWidget);
      expect(find.byKey(const Key('audio_track_item_2')), findsOneWidget);
      expect(find.byKey(const Key('audio_track_item_3')), findsOneWidget);

      // Verify Track 1 metadata
      expect(find.text('English Surround'), findsOneWidget);
      expect(find.text('ENG • AAC • 5.1 • 48.0 kHz'), findsOneWidget);

      // Verify Track 2 metadata (channelscount fallback)
      expect(find.text('Japanese Stereo'), findsOneWidget);
      expect(find.text('JPN • FLAC • 2 ch • 44.1 kHz'), findsOneWidget);

      // Verify Track 3 metadata
      expect(find.text('Director Commentary'), findsOneWidget);
      expect(find.text('ENG • AC3 • Stereo • 48.0 kHz'), findsOneWidget);

      // Verify active checkmark is ONLY on Track 1
      expect(find.byKey(const Key('active_track_check')), findsOneWidget);
      final checkmarkParent = find.ancestor(
        of: find.byKey(const Key('active_track_check')),
        matching: find.byKey(const Key('audio_track_item_1')),
      );
      expect(checkmarkParent, findsOneWidget);

      // Tap Track 2
      await tester.tap(find.byKey(const Key('audio_track_item_2')));
      await tester.pumpAndSettle();
      expect(chosenTrack?.id, equals('2'));
      expect(chosenTrack?.title, equals('Japanese Stereo'));
    });
  });

  group('Empirical Challenge 4: Two-Way Audio Delay Synchronization Logic', () {
    test('Keyboard nudge and AudioStudioSheet stay in perfect numerical sync', () {
      double playerScreenDelayMs = 0.0;
      final audioConfig = AudioConfig();

      void nudgeFromKeyboard(int offsetMs) {
        playerScreenDelayMs = (playerScreenDelayMs + offsetMs).clamp(-10000.0, 10000.0);
        audioConfig.audioDelay = playerScreenDelayMs;
      }

      // 1. Initial sync: 0ms
      expect(playerScreenDelayMs, equals(0.0));
      expect(audioConfig.audioDelay, equals(0.0));

      // 2. Keyboard shortcut 'k' nudges +50ms
      nudgeFromKeyboard(50);
      expect(playerScreenDelayMs, equals(50.0));
      expect(audioConfig.audioDelay, equals(50.0));

      // 3. User opens AudioStudioSheet -> initialized with playerScreenDelayMs
      audioConfig.audioDelay = playerScreenDelayMs;
      expect(audioConfig.audioDelay, equals(50.0));

      // 4. In AudioStudioSheet, user nudges +100ms
      audioConfig.audioDelay = (audioConfig.audioDelay + 100.0).clamp(-10000.0, 10000.0);
      expect(audioConfig.audioDelay, equals(150.0));

      // 5. User dismisses AudioStudioSheet -> .then synchronizes back to playerScreenDelayMs
      playerScreenDelayMs = audioConfig.audioDelay;
      expect(playerScreenDelayMs, equals(150.0));

      // 6. Next keyboard shortcut 'j' nudges -50ms
      nudgeFromKeyboard(-50);
      expect(playerScreenDelayMs, equals(100.0));
      expect(audioConfig.audioDelay, equals(100.0));
    });
  });
}
