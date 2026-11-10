# Specification Miner Handoff Report: Milestone 3 (Iteration 2 Remediation)

**Agent ID**: `spec_miner_m3_r2_1`  
**Role**: Specification Miner (read-only investigator, spec designer)  
**Parent Orchestrator**: `d319cada-6c05-4314-a8fc-3628ac99cc0c`  
**Milestone**: Milestone 3 Remediation (R3 Audio Delay Synchronization & R4 Dedicated Audio Track Selector Modal)  
**Date & Timestamp**: 2026-11-10T10:55:00Z  

---

## Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Audio Studio UI | `AudioStudioSheet` Widget Mounting | Instantiates full `AudioStudioSheet` containing master switch, presets, delay sync card, preamp card, 10-band EQ, boost controls, and reset button | `Player? player`, `AudioConfig config`, `bool isFullScreen` | Mounted widget tree in bottom sheet mode (`isFullScreen: false`) or full-screen page (`isFullScreen: true`) | If `_buildBoostSwitchTile` specifies both `borderRadius` and `shape` to `Material`, throws `AssertionError` (`!(shape != null && borderRadius != null)`) | `audio_studio_sheet.dart:197-642`, `challenger_m3_2/handoff.md` |
| 2 | Audio Boost Controls | Boost Switch Tiles (`Virtualizer`, `3D Audio`, `Night Mode`) | Three `SwitchListTile` cards controlling spatial simulation, stereo widening, and loudness normalization | Tile title, subtitle, icon, bool value, `onChanged` callback | `Material` container wrapping `SwitchListTile` with `EDesign.surface` and rounded border | Flutter asserts `!(shape != null && borderRadius != null)`. Removing `borderRadius` ensures zero-assertion rendering | `audio_studio_sheet.dart:1038-1074` |
| 3 | Audio Equalizer UI | 10-Band Graphic Equalizer Sliders & Scale | 10 vertical sliders inside `RotatedBox(quarterTurns: 3)` with center 0dB datum line and scale labels `+20dB` / `-20dB` | EQ band gains in `AudioConfig.eq` (length 10, range [-20.0, 20.0]) | Interactive vertical sliders for frequencies: 60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz | Moving band slider clamps to [-20.0, 20.0], updates `preset` to `'Custom'`, and triggers debounced `apply()` | `audio_studio_sheet.dart:471-545`, `898-969` |
| 4 | Audio Preamp UI | Pre-Amplification Slider Card | Card with title, live dB badge, reset button, and continuous slider (-20dB to +20dB with 80 divisions, 0.5dB step) | `AudioConfig.preamp` [-20.0, 20.0] dB | Preamp slider widget with ±20dB scale markers, live `${preamp >= 0 ? "+" : ""}${preamp.toStringAsFixed(1)} dB` badge, reset button | Disabled when master switch is OFF; reset button enabled only when `preamp != 0.0`; applies `volume=volume=+X.XdB:precision=fixed` | `audio_studio_sheet.dart:776-896` |
| 5 | Audio Delay Sync UI | Audio Synchronization Card (`_buildAudioDelaySyncCard` & `AudioDelaySyncCard`) | Frosted card with live badge, continuous slider (-10.0s to +10.0s, 400 divisions), and 5 discrete nudge buttons (-100ms, -50ms, Reset, +50ms, +100ms) | `AudioConfig.audioDelay` [-10000.0, 10000.0] ms | Formatted live badge (`+X ms`), slider position, and dispatches to `(player.platform as dynamic).setProperty('audio-delay', ...)` | Clamps strictly at ±10000.0ms; platform exceptions are caught safely in `try ... catch` without crashing UI | `audio_studio_sheet.dart:644-754`, `1078-1231` |
| 6 | Audio Boost Controls | Bass Boost Card (`_buildBoostCard`) | Card containing Bass Boost toggle switch and continuous gain slider (0.0 to 12.0 dB) | `AudioConfig.bassBoostEnabled`, `AudioConfig.bassBoost` | Toggle switch, slider, and live `${bassBoost.toStringAsFixed(1)} dB` label | Slider visible only when `bassBoostEnabled` is true; compiles `bass=g=X.X` filter token | `audio_studio_sheet.dart:549-571`, `971-1036` |
| 7 | Audio Studio UI | Master Enable Switch & Presets Picker | Master switch enabling/disabling audio DSP; dropdown pill opening preset bottom sheet with 20 presets | `AudioConfig.enabled`, `AudioConfig.preset` | Toggles EQ graph; clicking preset pill opens bottom sheet displaying all 20 presets in wrap chips | When disabled, presets, preamp, and 10 bands are dimmed (opacity 0.4) and sliders disabled | `audio_studio_sheet.dart:379-460`, `259-334` |
| 8 | Audio Track Selection | Dedicated Audio Track HUD Button | HUD top bar icon button with `Icons.audiotrack_outlined` and tooltip `'Audio Tracks'` | User tap on HUD button in `PlayerScreen` | Invokes `_showAudioTrackMenu()` modal | None | `player_screen.dart:635-640` |
| 9 | Audio Track Selection | Glassmorphic Audio Track Modal (`_showAudioTrackMenu`) | Bottom sheet displaying detected audio streams from `_player.stream.tracks.audio` or empty state | `List<AudioTrack> _audioTracks`, `AudioTrack _selectedAudioTrack` | Empty view with `Key('audio_tracks_empty')` or `ListView` with `Key('audio_track_item_${track.id}')`, metadata subtitle, and `Key('active_track_check')` | Tapping track calls `_player.setAudioTrack(track)`, pops modal, displays OSD message `Audio: $label`, and restores focus to keyboard node | `player_screen.dart:677-889` |
| 10 | Audio Track Selection | Audio Track Metadata Subtitle Formatter | Formats audio stream language, codec, channel layout, and sample rate into unified dot-separated string | `AudioTrack(language, codec, channels, channelscount, samplerate)` | String like `'ENG • AAC • 5.1 • 48.0 kHz'` or `'JPN • FLAC • 2 ch • 44.1 kHz'` | Null or empty fields are omitted gracefully; channelscount used as fallback if channels is null | `player_screen.dart:803-820`, `audio_studio_adversarial_test.dart:257-274` |

---

## Edge Cases

| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | `AudioStudioSheet` Mounting | Mount with `AudioConfig()` | If `Material` in `_buildBoostSwitchTile` receives both `shape` and `borderRadius`, Flutter crashes with `AssertionError: line 209 pos 15: '!(shape != null && borderRadius != null)'`. When `borderRadius` is removed, sheet mounts cleanly with 0 exceptions. |
| 2 | Audio Delay Synchronization | Nudge `+100ms` when initial delay is `9950ms` | Value clamps at `+10000ms`, live badge displays `+10000 ms`, and mpv property receives `'10.000'`. Further nudges remain at boundary. |
| 3 | Audio Delay Synchronization | Nudge `-100ms` when initial delay is `-9950ms` | Value clamps at `-10000ms`, live badge displays `-10000 ms`, and mpv property receives `'-10.000'`. |
| 4 | Audio Delay Synchronization | Platform throws `Exception('Simulated mpv crash')` | Platform exception is caught and logged as `[Audio Studio] mpv audio-delay error: Exception...`, and does not bubble up or crash Flutter widget tree. |
| 5 | Audio Track Selector Modal | `_audioTracks` is empty `[]` | Renders `Key('audio_tracks_empty')` with text `'No audio tracks found'` and caption `'This media stream does not contain selectable audio tracks.'`. No null exceptions thrown. |
| 6 | Audio Track Selector Modal | Track has `language == title` (e.g. `'English'`) | Subtitle formatter omits duplicate language token to avoid redundant display (e.g., `'English • ENGLISH'`). |
| 7 | Audio Track Selector Modal | Track has `channels == null` but `channelscount == 2` | Subtitle formatter falls back to `'2 ch'` and includes sample rate (e.g., `'FLAC • 2 ch • 44.1 kHz'`). |
| 8 | Audio Track Selector Modal | Track selection tap | Triggers `_player.setAudioTrack(track)`, closes modal via `Navigator.pop(context)`, displays OSD feedback pill `Audio: $label`, and restores focus to `_keyboardFocusNode`. |
| 9 | 10-Band EQ Slider Interaction | Drag 60Hz band from +4.5dB to -12.0dB | `_config.preset` immediately switches to `'Custom'`, band value updates to -12.0, live dB badge shows `-12.0`, and debounced `apply()` updates mpv `af` filter. |
| 10 | Equalizer Reset to Flat Defaults | Tap `'Reset to Flat Defaults'` text button | `config.reset(player)` resets all 10 bands to 0.0dB, preset to `'Flat'`, preamp to 0.0dB, delay to 0.0ms, and sets `af=''` and `audio-delay='0.000'` on player platform. |

---

## 1. Observation

1. **Defect in `lib/features/player/ui/audio_studio_sheet.dart:1045-1052`**:
   ```dart
   Widget _buildBoostSwitchTile({
     required String title,
     required String subtitle,
     required IconData icon,
     required bool value,
     required ValueChanged<bool> onChanged,
   }) {
     return Material(
       color: EDesign.surface,
       borderRadius: BorderRadius.circular(EDesign.r14),
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(EDesign.r14),
         side: const BorderSide(color: EDesign.border),
       ),
       child: SwitchListTile(...),
     );
   }
   ```
   Flutter's `Material` constructor (`package:flutter/src/material/material.dart:209:15`) enforces:
   ```dart
   assert(!(shape != null && borderRadius != null), 'Cannot provide both a shape and a borderRadius');
   ```
   Whenever `AudioStudioSheet` is built in debug/profile/test execution environments, Flutter throws an unhandled `AssertionError` halting rendering.

2. **Blindspot in `test/features/audio_studio_test.dart`**:
   - `test/features/audio_studio_test.dart` currently contains 42 tests across 7 groups.
   - In lines 504–569, only `AudioDelaySyncCard` (the isolated sub-widget) was tested.
   - `AudioStudioSheet` itself was **never once pumped or mounted** in `test/features/audio_studio_test.dart`.
   - The Audio Track modal was **never tested** in `test/features/audio_studio_test.dart`.

3. **Adversarial Test Suite Behavior (`test/features/audio_studio_adversarial_test.dart`)**:
   - Challenger 2 authored Challenge 1 (`audio_studio_adversarial_test.dart:49-77`) which specifically asserts that `tester.takeException()` is not null and contains `'!(shape != null && borderRadius != null)'`.
   - When the worker fixes `_buildBoostSwitchTile`, this test in `audio_studio_adversarial_test.dart` will need to assert that `tester.takeException()` is `isNull` so that the adversarial suite also passes cleanly.

4. **Ink Ripple Occlusion in `lib/features/player/ui/player_screen.dart:694-712`**:
   - `_showAudioTrackMenu` wraps the sheet in `Container(decoration: BoxDecoration(color: EDesign.surface, ...))`, inside which `ListTile` items are wrapped in `Material(color: Colors.transparent)`.
   - This triggers Flutter framework warnings about invisible ink splashes. Replacing the outer `Container` decoration with `Material(color: EDesign.surface, shape: RoundedRectangleBorder(...), child: ...)` resolves this.

---

## 2. Logic Chain

1. **Why `audio_studio_test.dart` passed while E2E tests failed**:
   - In `audio_studio_test.dart`, only `AudioDelaySyncCard` was pumped. `AudioDelaySyncCard` does not invoke `_buildBoostSwitchTile`, so it never encountered the assertion.
   - In `test/e2e/phase1_e2e_test.dart`, tests `T1.5.1`, `T2.5.4`, and `T4.4` pump `AudioStudioSheet`, which unconditionally builds `_buildBoostSwitchTile` three times (`Virtualizer`, `3D Audio`, `Night Mode`). Consequently, all three tests crash immediately.

2. **Remediation Requirement**:
   - Fix `lib/features/player/ui/audio_studio_sheet.dart`: remove `borderRadius: BorderRadius.circular(EDesign.r14)` from `Material` in `_buildBoostSwitchTile`.
   - Add comprehensive widget test coverage directly to `test/features/audio_studio_test.dart` (Group 8 and Group 9) that pumps `AudioStudioSheet` and the `AudioTrack` modal fixture.
   - Update Challenge 1 in `test/features/audio_studio_adversarial_test.dart` to assert that `tester.takeException()` is null once the fix lands.

---

## 3. Caveats

- **Read-Only Invariant**: As Specification Miner, no source files in `lib/` or `test/` have been modified during this phase.
- **Upstream Flutter Physical Key Simulation**: In `test/e2e/phase1_e2e_test.dart:385`, test `T1.1.7` encounters Flutter's desktop test runner limitation with `LogicalKeyboardKey.add` physical keys. This is separate from the `Material` assertion crash.

---

## 4. Conclusion & Test Specification

### 4.1 Implementation Fixes (for Worker)

1. **`lib/features/player/ui/audio_studio_sheet.dart:1045-1052`**:
   Change:
   ```dart
   Widget _buildBoostSwitchTile({
     required String title,
     required String subtitle,
     required IconData icon,
     required bool value,
     required ValueChanged<bool> onChanged,
   }) {
     return Material(
       color: EDesign.surface,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(EDesign.r14),
         side: const BorderSide(color: EDesign.border),
       ),
       child: SwitchListTile(
   ```

2. **`lib/features/player/ui/player_screen.dart:694-712`**:
   Replace outer `Container` decoration in `_showAudioTrackMenu` with `Material`:
   ```dart
   return Material(
     key: const Key('audio_tracks_sheet'),
     color: EDesign.surface,
     shape: const RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
       side: BorderSide(color: EDesign.border, width: 1.0),
     ),
     child: ConstrainedBox(
       constraints: BoxConstraints(
         maxHeight: MediaQuery.of(context).size.height * 0.65,
       ),
       child: Column(...),
     ),
   );
   ```

### 4.2 Test Suite Enhancements for `test/features/audio_studio_test.dart`

Add `setAudioTrack` to `FakePlayerPlatform` and `FakePlayer` (lines 7–35):
```dart
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

class FakePlayer extends Fake implements Player {
  @override
  final PlatformPlayer? platform;

  FakePlayer([PlatformPlayer? platform]) : platform = platform ?? FakePlayerPlatform();

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    await platform?.setAudioTrack(track);
  }
}
```

Add **Group 8: AudioStudioSheet Full Widget Mounting & Structural Integrity**:
```dart
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
      await tester.tap(find.widgetWithText(SwitchListTile, 'Virtualizer'));
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

      await tester.tap(find.text('Reset to Flat Defaults'));
      await tester.pumpAndSettle();

      expect(config.preset, equals('Flat'));
      expect(config.preamp, equals(0.0));
      expect(config.audioDelay, equals(0.0));
      expect(platform.properties['af'], equals(''));
      expect(platform.properties['audio-delay'], equals('0.000'));
    });
  });
```

Add **Group 9: Audio Track Selector Modal Architecture & Interaction Fixture**:
```dart
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
```

### 4.3 Update for `test/features/audio_studio_adversarial_test.dart` (Post-Fix)

In `test/features/audio_studio_adversarial_test.dart:69-75`:
Once `_buildBoostSwitchTile` is fixed, Challenge 1 must assert:
```dart
      // Verify no assertion error is thrown:
      final error = tester.takeException();
      expect(error, isNull, reason: 'AudioStudioSheet must mount cleanly without Material assertion error');
```

---

## 5. Verification Method

To independently verify the implementation and tests:

1. **Feature Test Suite Execution**:
   ```powershell
   cd d:\E-player\app
   flutter test test/features/audio_studio_test.dart
   ```
   *Expected Output*: All tests (including new Groups 8 & 9) pass with 0 failures.

2. **Adversarial Test Suite Execution**:
   ```powershell
   cd d:\E-player\app
   flutter test test/features/audio_studio_adversarial_test.dart
   ```
   *Expected Output*: `All tests passed!`

3. **E2E Suite Execution**:
   ```powershell
   cd d:\E-player\app
   flutter test test/e2e/phase1_e2e_test.dart --name "T1.5.1"
   ```
   *Expected Output*: `00:0X +1: All tests passed!`

4. **Static Code Analysis**:
   ```powershell
   cd d:\E-player\app
   dart analyze
   ```
   *Expected Output*: `No issues found!`
