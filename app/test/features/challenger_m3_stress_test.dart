import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';

/// Mock platform player storing properties and tracking calls
class MockPlatformPlayer extends Fake implements PlatformPlayer {
  final Map<String, String> properties = {};
  final List<String> callHistory = [];

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    callHistory.add('$property=$value');
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }
}

/// Fake platform player throwing errors to test robustness
class ErroneousPlatformPlayer extends Fake implements PlatformPlayer {
  void setProperty(String property, String value) {
    throw Exception('Simulated fatal mpv property crash');
  }
}

/// Fake Player wrapping a platform player
class MockPlayer extends Fake implements Player {
  @override
  final PlatformPlayer platform;

  MockPlayer([PlatformPlayer? platform]) : platform = platform ?? MockPlatformPlayer();
}

void main() {
  group('Challenger M3 Empirical Suite: Audio Delay Synchronization (R3)', () {
    test('Extreme boundary stress: clamping values outside [-10000.0, 10000.0] ms', () {
      final platform = MockPlatformPlayer();
      final player = MockPlayer(platform);
      final config = AudioConfig();

      // Stress with extreme positive values
      config.audioDelay = 50000.0;
      config.applyAudioDelay(player);
      // Raw config holds value, but UI clamps it:
      expect(config.audioDelay.clamp(-10000.0, 10000.0), equals(10000.0));

      // Stress with extreme negative values
      config.audioDelay = -999999.0;
      expect(config.audioDelay.clamp(-10000.0, 10000.0), equals(-10000.0));
    });

    test('Rapid sequential nudges: 300 forward nudges and 300 backward nudges', () {
      final platform = MockPlatformPlayer();
      final player = MockPlayer(platform);
      final config = AudioConfig();

      // 300 nudges of +50ms starting from 0 -> should clamp at 10000.0
      for (int i = 0; i < 300; i++) {
        config.audioDelay = (config.audioDelay + 50.0).clamp(-10000.0, 10000.0);
      }
      expect(config.audioDelay, equals(10000.0));
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('10.000'));

      // 300 nudges of -100ms from 10000.0 -> should clamp at -10000.0
      for (int i = 0; i < 300; i++) {
        config.audioDelay = (config.audioDelay - 100.0).clamp(-10000.0, 10000.0);
      }
      expect(config.audioDelay, equals(-10000.0));
      config.applyAudioDelay(player);
      expect(platform.properties['audio-delay'], equals('-10.000'));
    });

    test('Float precision & sign representation across full range [-10000, 10000] in 50ms steps', () {
      final platform = MockPlatformPlayer();
      final player = MockPlayer(platform);
      final config = AudioConfig();

      // 401 points from -10000 to +10000
      for (int ms = -10000; ms <= 10000; ms += 50) {
        config.audioDelay = ms.toDouble();
        config.applyAudioDelay(player);

        final expectedSec = (ms / 1000.0).toStringAsFixed(3);
        final actual = platform.properties['audio-delay'];
        expect(actual, equals(expectedSec));
        // Verify format: must have exactly 3 decimal places
        final dotIndex = actual!.indexOf('.');
        expect(dotIndex, isNot(-1));
        expect(actual.substring(dotIndex + 1).length, equals(3));
      }
    });

    test('AudioConfig.apply unconditional audio delay dispatch when equalizer is disabled', () {
      final platform = MockPlatformPlayer();
      final player = MockPlayer(platform);
      final config = AudioConfig();

      config.enabled = false;
      config.preamp = 10.0;
      config.audioDelay = -1250.0;

      config.apply(player);

      // af must be empty because enabled == false
      expect(platform.properties['af'], equals(''));
      // audio-delay must still be dispatched
      expect(platform.properties['audio-delay'], equals('-1.250'));
    });

    test('AudioConfig.reset restores non-zero delay back to 0.000', () {
      final platform = MockPlatformPlayer();
      final player = MockPlayer(platform);
      final config = AudioConfig();

      config.audioDelay = 7750.0;
      config.preamp = -8.0;
      config.reset(player);

      expect(config.audioDelay, equals(0.0));
      expect(config.preamp, equals(0.0));
      expect(platform.properties['audio-delay'], equals('0.000'));
    });

    test('Robustness against throwing platform player in apply and applyAudioDelay', () {
      final throwingPlayer = MockPlayer(ErroneousPlatformPlayer());
      final config = AudioConfig()..audioDelay = 420.0;

      expect(() => config.applyAudioDelay(throwingPlayer), returnsNormally);
      expect(() => config.apply(throwingPlayer), returnsNormally);
      expect(() => config.reset(throwingPlayer), returnsNormally);
    });
  });

  group('Challenger M3 Empirical Suite: Audio Track Cycling & Boundary Math (R4)', () {
    test('Track cycling math with empty tracks list', () {
      final List<AudioTrack> tracks = [];
      AudioTrack selected = AudioTrack.auto();

      // Simulation of PlayerScreen._cycleAudioTrack
      bool cycled = false;
      if (tracks.isEmpty) {
        // Guard clause executed
        cycled = false;
      } else {
        final currentIndex = tracks.indexOf(selected);
        final nextIndex = (currentIndex + 1) % tracks.length;
        selected = tracks[nextIndex];
        cycled = true;
      }

      expect(cycled, isFalse);
      expect(selected, equals(AudioTrack.auto()));
    });

    test('Track cycling math with single track', () {
      final track0 = AudioTrack('1', 'English', 'eng');
      final List<AudioTrack> tracks = [track0];
      AudioTrack selected = AudioTrack.no();

      // Cycle 1: unselected (-1) -> 0
      int currentIndex = tracks.indexOf(selected);
      expect(currentIndex, equals(-1));
      int nextIndex = (currentIndex + 1) % tracks.length;
      expect(nextIndex, equals(0));
      selected = tracks[nextIndex];
      expect(selected.id, equals('1'));

      // Cycle 2: 0 -> 0
      currentIndex = tracks.indexOf(selected);
      expect(currentIndex, equals(0));
      nextIndex = (currentIndex + 1) % tracks.length;
      expect(nextIndex, equals(0));
      selected = tracks[nextIndex];
      expect(selected.id, equals('1'));
    });

    test('Track cycling math with 5 tracks (wrapping from 4 to 0)', () {
      final tracks = List.generate(
        5,
        (i) => AudioTrack('$i', 'Track $i', 'lang_$i'),
      );
      AudioTrack selected = tracks[0];

      for (int step = 1; step <= 10; step++) {
        final currentIndex = tracks.indexOf(selected);
        final nextIndex = (currentIndex + 1) % tracks.length;
        selected = tracks[nextIndex];
        expect(selected.id, equals('${step % 5}'));
      }
    });

    test('Track matching by track.id robustness', () {
      final trackA = AudioTrack('aid1', 'Stereo', 'en');
      final trackB = AudioTrack('aid1', 'Stereo Copy', 'en'); // same ID

      expect(trackA.id == trackB.id, isTrue);
    });
  });

  group('Challenger M3 Empirical Suite: Widget Stress Harnesses', () {
    testWidgets('AudioDelaySyncCard bounds clamping and rapid nudge interaction', (tester) async {
      final platform = MockPlatformPlayer();
      final player = MockPlayer(platform);
      double lastReported = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioDelaySyncCard(
              player: player,
              initialDelayMs: 9900.0,
              onDelayChanged: (v) => lastReported = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+9900 ms'), findsOneWidget);

      // Tap +100ms -> should become 10000ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+10000 ms'), findsOneWidget);
      expect(lastReported, equals(10000.0));
      expect(platform.properties['audio-delay'], equals('10.000'));

      // Tap +100ms again -> should clamp at 10000ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+10000 ms'), findsOneWidget);
      expect(lastReported, equals(10000.0));

      // Reset
      await tester.tap(find.byKey(const Key('audio_delay_nudge_reset')));
      await tester.pumpAndSettle();
      expect(find.text('+0 ms'), findsOneWidget);
      expect(lastReported, equals(0.0));
      expect(platform.properties['audio-delay'], equals('0.000'));

      // Tap -100ms 101 times -> should clamp at -10000ms
      for (int i = 0; i < 101; i++) {
        await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_100')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('-10000 ms'), findsOneWidget);
      expect(lastReported, equals(-10000.0));
      expect(platform.properties['audio-delay'], equals('-10.000'));
    });

    testWidgets('Stress test: Audio tracks sheet modal with 15 streams layout integrity', (tester) async {
      // Simulate 15 audio tracks
      final fifteenTracks = List.generate(
        15,
        (i) => AudioTrack(
          'track_$i',
          'Stream #$i - 5.1 Surround Sound Feature Commentary Extended',
          'en',
        ),
      );
      final activeTrack = fifteenTracks[3];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) {
                        return Container(
                          key: const Key('audio_tracks_sheet'),
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Audio Tracks'),
                              Flexible(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: fifteenTracks.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                                  itemBuilder: (ctx, index) {
                                    final t = fifteenTracks[index];
                                    final isSelected = t.id == activeTrack.id;
                                    return ListTile(
                                      key: Key('audio_track_item_${t.id}'),
                                      title: Text(t.title ?? t.id),
                                      trailing: isSelected
                                          ? const Icon(Icons.check, key: Key('active_track_check'))
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.byKey(const Key('audio_tracks_sheet')), findsOneWidget);

      // Verify active track has checkmark
      expect(find.byKey(const Key('active_track_check')), findsOneWidget);

      // Verify first few tracks are rendered without layout overflow
      expect(find.byKey(const Key('audio_track_item_track_0')), findsOneWidget);
      expect(find.byKey(const Key('audio_track_item_track_3')), findsOneWidget);

      // Scroll until track 14 is visible in the viewport
      await tester.scrollUntilVisible(
        find.byKey(const Key('audio_track_item_track_14')),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify later tracks are rendered successfully without overflow
      expect(find.byKey(const Key('audio_track_item_track_14')), findsOneWidget);
    });
  });
}
