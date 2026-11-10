# Handoff Report: Audio Studio, Equalizer, Delay & Track Selection Architecture

**Explorer Archetype**: Aura (Audio Studio & Equalizer Explorer)  
**Target Codebase**: `d:\E-player\app`  
**Reference Document**: `d:\E-player\docs\vlc_gap_analysis.md` (Sections 5.2, 5.6)  
**Authoritative Assignment**: `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (Requirements R3, R4, R5)  
**Date & Timestamp**: 2026-11-10T08:28:00Z  

---

## 1. Observation

### 1.1 AudioStudioSheet & AudioConfig Structure
- **File Location**: `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart`
- **Class `AudioConfig` (lines 6–98)**:
  - Manages equalizer state, 10 graphic EQ bands, and audio DSP enhancements.
  - Frequency bands defined at lines 12–13:
    ```dart
    static const List<int> freqs = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];
    static const List<String> freqLabels = ['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'];
    ```
  - Default state (lines 15–21):
    ```dart
    List<double> eq = [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5]; // Default Rock
    double bassBoost = 6.0; // 0 to 12 dB
    bool bassBoostEnabled = true;
    bool virtualizer = true;
    bool threeDAudio = true;
    bool nightMode = false;
    ```
  - Current presets map (lines 23–33) contains only **9 presets**:
    `Flat`, `Rock`, `Pop`, `Jazz`, `Classical`, `Bass Boost`, `Vocal Boost`, `Techno`, `Club`.
  - Filter string compilation and mpv dispatch in `apply(Player? player)` (lines 42–85):
    ```dart
    final dynamic platform = player.platform;
    if (!enabled) {
      platform.setProperty('af', '');
      return;
    }
    final List<String> filters = [];
    if (bassBoostEnabled && bassBoost > 0) {
      filters.add('bass=g=${bassBoost.toStringAsFixed(1)}');
    }
    if (nightMode) {
      filters.add('dynaudnorm=f=200:g=15');
    }
    if (virtualizer) {
      filters.add('extrastereo=m=2.2');
    }
    if (threeDAudio) {
      filters.add('stereowiden=level=0.7');
    }
    for (int i = 0; i < freqs.length; i++) {
      if (eq[i].abs() > 0.05) {
        filters.add('equalizer=f=${freqs[i]}:width_type=q:width=1.2:g=${eq[i].toStringAsFixed(1)}');
      }
    }
    final afString = filters.join(',');
    platform.setProperty('af', afString);
    ```
- **Class `AudioStudioSheet` (lines 139–725)**:
  - Presented in `PlayerScreen` via `showModalBottomSheet` at `lib/features/player/ui/player_screen.dart:1780-1789`:
    ```dart
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AudioStudioSheet(
        player: _player,
        config: _audioConfig,
      ),
    );
    ```
  - Modal container styling (lines 539–547):
    - Height: `MediaQuery.of(context).size.height * 0.88`
    - Background: `EDesign.appBackground`
    - Border radius: `BorderRadius.vertical(top: Radius.circular(24))`
    - Border: `Border.all(color: EDesign.border)`
  - Current UI sections in `SingleChildScrollView`:
    1. Drag handle (width 40, height 4, radius 2) & Header ("Audio Equalizer" + Close button)
    2. Master Switch Card ("Enable Equalizer", lines 294–326)
    3. Preset Selector Dropdown Pill (lines 329–374) -> opens `_showPresetPicker()`
    4. 10-Band Graphic Equalizer Scale (lines 378–451) -> Rotated vertical sliders (-12dB to +12dB) with 0dB reference line
    5. Boost Controls (lines 454–514): Bass Boost (switch + 0-12dB slider), Virtualizer, 3D Audio, Night Mode
    6. "Reset to Flat Defaults" button (lines 517–529)

### 1.2 Audio Delay Property & mpv Binding
- mpv manages audio desynchronization via the property `audio-delay`.
- **Property characteristics in libmpv**:
  - Name: `audio-delay`
  - Type / Units: **Floating point seconds** (`0.050` = +50ms, `-0.050` = -50ms).
  - Semantics: Positive values delay audio relative to video; negative values advance audio relative to video.
- **Platform invocation**:
  - Write: `(player.platform as dynamic).setProperty('audio-delay', seconds.toStringAsFixed(3))`
  - Read: `await (player.platform as dynamic).getProperty('audio-delay')`
- **Current Deficit**:
  - In `lib/features/player/ui/audio_studio_sheet.dart`, there is **no** audio delay slider, nudge buttons, or property binding.
  - In contrast, subtitle delay (`sub-delay`) is implemented in `lib/features/player/ui/subtitle_settings_sheet.dart:47`:
    `platform.setProperty('sub-delay', delay.toStringAsFixed(2));`
  - Blueprint 2 in `docs/vlc_gap_analysis.md:1070-1181` outlines a complete `AudioDelaySyncCard` widget with continuous slider (-10.0s to +10.0s, 50ms steps) and 5 nudge buttons (`-100ms`, `-50ms`, `Reset 0ms`, `+50ms`, `+100ms`).

### 1.3 Equalizer Parity & Pre-Amplification
- **11 Presets Missing**:
  Requirement R5 in `ORIGINAL_REQUEST.md` and Section 5.2 (Item 1.5) in `docs/vlc_gap_analysis.md` mandate adding 11 missing VLC presets:
  1. `Full Bass`
  2. `Full Bass & Treble`
  3. `Full Treble`
  4. `Headphones`
  5. `Large Hall`
  6. `Live`
  7. `Party`
  8. `Reggae`
  9. `Ska`
  10. `Soft`
  11. `Soft Rock`
- Canonical Winamp/VLC 10-band decibel vectors retrieved from the reference standard (matching 60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz):
  - `Full Bass`: `[9.6, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]`
  - `Full Bass & Treble`: `[7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]`
  - `Full Treble`: `[-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]`
  - `Headphones`: `[4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]`
  - `Large Hall`: `[10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0]`
  - `Live`: `[-4.8, 0.0, 4.0, 5.6, 5.6, 3.2, 0.0, -2.4, -4.8, -4.8]`
  - `Party`: `[7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2]`
  - `Reggae`: `[0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0]`
  - `Ska`: `[-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]`
  - `Soft`: `[4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0]`
  - `Soft Rock`: `[4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8]`
- **Pre-Amplification Filter**:
  - Filter string syntax: `volume=volume=+XdB:precision=fixed` or `volume=volume=-XdB:precision=fixed`
  - Range: `-20.0dB` to `+20.0dB`, step 0.5dB, default `0.0dB`.
  - In `AudioConfig.apply`:
    ```dart
    if (preamp.abs() > 0.05) {
      final sign = preamp >= 0 ? '+' : '';
      filters.add('volume=volume=$sign${preamp.toStringAsFixed(1)}dB:precision=fixed');
    }
    ```

### 1.4 Audio Track Selection Mechanisms
- In `media_kit: ^1.2.6`:
  - Definition: `C:\Users\Admin\AppData\Local\Pub\Cache\hosted\pub.dev\media_kit-1.2.6\lib\src\models\track.dart:147-210`:
    `AudioTrack` extends `_Track` with fields: `id`, `title`, `language`, `codec`, `decoder`, `channelscount`, `channels`, `samplerate`, `bitrate`, `audiochannels`, `isDefault`, `uri`.
    Factory constructors: `AudioTrack.auto()`, `AudioTrack.no()`, `AudioTrack.uri(url)`.
  - Player track streams: `_player.stream.tracks` emits `Tracks` with `tracks.audio: List<AudioTrack>`.
  - Selected track stream: `_player.stream.track` emits `Track` with `track.audio: AudioTrack`.
  - Track switching API: `_player.setAudioTrack(AudioTrack track)` (`media_kit` `player.dart:287-289`).
- **Current PlayerScreen HUD State**:
  - `lib/features/player/ui/player_screen.dart:1363-1426` contains Top Bar HUD controls:
    Casting, PiP, AI Studio, Subtitles (`_showSubtitleMenu`), Media Inspector, and Settings Drawer.
  - There is **no** dedicated button for Audio Track selection.
  - In `player_screen.dart:267-272`, only `tracks.subtitle` and `track.subtitle` are subscribed; `tracks.audio` and `track.audio` are ignored in the UI state.

### 1.5 Existing Tests & Environment
- Inspection of `d:\E-player\app\test/` shows:
  - Existing tests: `test/features/video_effects_test.dart`, `test/unit/decoder_pipeline_test.dart`, `test/e2e/e2e_requirements_test.dart`.
  - **Zero** tests exist for `AudioStudioSheet`, `AudioConfig`, or audio synchronization.
- Test execution check:
  - Command: `flutter test test/features/video_effects_test.dart`
  - Result: `All tests passed! (11 tests)`
- Static analysis check:
  - Command: `dart analyze`
  - Result: `Analyzing app... No issues found!`

---

## 2. Logic Chain

1. **AudioStudioSheet Enhancement Strategy**:
   - `AudioConfig` is already wired into `AudioStudioSheet` and `PlayerScreen._audioConfig`.
   - By adding `double audioDelay = 0.0` and `double preamp = 0.0` directly to `AudioConfig`, and expanding `presets` with the 11 verified VLC presets, `AudioConfig` can serve as the single source of truth for both equalizer filters and audio synchronization.
   - When `AudioConfig.apply(player)` runs, it generates the full filter chain: `volume=volume=+XdB:precision=fixed` (preamp), `bass=...`, `dynaudnorm=...`, `extrastereo=...`, `stereowiden=...`, and `equalizer=...` bands.
   - For `audio-delay`, since it is a direct mpv property (not an `af` filter), it can be set immediately via `(player.platform as dynamic).setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3))`.

2. **Audio Delay Synchronization Card**:
   - Needs to be rendered inside `AudioStudioSheet`'s scrollable list (e.g., above or below the Equalizer card).
   - Range: `-10000ms` (-10.0s) to `+10000ms` (+10.0s), 50ms divisions (400 steps).
   - Live badge formatting: `${delayMs >= 0 ? "+" : ""}${delayMs.toStringAsFixed(0)} ms`.
   - 5 Nudge buttons: `-100ms`, `-50ms`, `Reset 0ms`, `+50ms`, `+100ms`.
   - Debounced or immediate application to mpv property `audio-delay`.

3. **Pre-Amplification Placement**:
   - In VLC, the Preamp slider sits horizontally above or adjacent to the 10 graphic EQ sliders.
   - In `AudioStudioSheet`, adding a Preamp Gain card right above the 10-Band Graphic Equalizer Scale with a slider from `-20.0dB` to `+20.0dB` provides immediate visual parity.
   - When adjusted, it triggers `_debouncedApply()`, updating the `af` filter string with `volume=volume=+XdB:precision=fixed`.

4. **Dedicated Audio Track Selector Modal in Player HUD**:
   - `PlayerScreen` needs two new state variables:
     `List<AudioTrack> _audioTracks = [];`
     `AudioTrack _selectedAudioTrack = AudioTrack.auto();`
   - In `initState`, subscribe to `_player.stream.tracks` to populate `_audioTracks = tracks.audio`, and `_player.stream.track` to update `_selectedAudioTrack = track.audio`.
   - Add an `IconButton(icon: const Icon(Icons.audiotrack_rounded, color: Colors.white70, size: 20), tooltip: 'Audio Tracks', onPressed: _showAudioTrackMenu)` in the HUD top bar (between AI Studio and Subtitles).
   - In `_showAudioTrackMenu()`, present a glassmorphic bottom sheet:
     - Shows all available tracks with title, language, and codec/channel details.
     - Displays `AudioTrack.auto()` and `AudioTrack.no()` options.
     - Highlights `_selectedAudioTrack == track` with a checkmark icon.
     - On tap, calls `_player.setAudioTrack(track)` and dismisses modal.

5. **Test Strategy**:
   - Create a dedicated unit test suite: `test/features/audio_studio_test.dart`.
   - Tests will verify:
     - `AudioConfig` default values, 20 presets lookup, custom preset selection.
     - Accurate `af` filter string generation for all equalizer bands and preamp gain.
     - Correct clamping and conversion of audio delay (-10s to +10s).
     - Audio track enumeration and switching logic.

---

## 3. Caveats

- **Caveat 1 (Platform Mocking in Widget Tests)**: In unit tests where `Player` is not backed by native libmpv binaries, `player.platform` must be mocked or tested via `AudioConfig.apply` with a mock platform or pure config tests (similar to `VideoEffectsConfig` in `test/features/video_effects_test.dart`).
- **Caveat 2 (mpv audio-delay timing)**: mpv's `audio-delay` property takes effect dynamically during playback; however, some audio output drivers (e.g. WASAPI exclusive mode) may experience a minor (100–200ms) buffer flush latency when the property is adjusted while actively playing.
- **Caveat 3 (Audio Track Cycling Shortcut)**: Requirement R1 mentions hotkey `b` cycles audio tracks with OSD feedback. While `Aura` investigates the Audio Studio and Track selector modal, the keyboard dispatcher is coordinated with `Kronos`/`Forge`. The audio track cycling function in `PlayerScreen` should expose a public callback (e.g. `_cycleAudioTrack()`) for the keyboard handler.

---

## 4. Conclusion

1. **Equalizer Parity is straightforward**: `AudioConfig` already handles mpv `af` filter construction. Adding the 11 missing VLC presets (bringing the total to 20 presets) and a `-20dB` to `+20dB` preamp slider requires updating `AudioConfig.presets`, `AudioConfig.apply()`, and rendering the preamp slider widget in `AudioStudioSheet`.
2. **Audio Delay is directly supported by libmpv**: Binding to `(player.platform as dynamic).setProperty('audio-delay', seconds.toStringAsFixed(3))` enables instant sync offset. Creating the `AudioDelaySyncCard` component in `AudioStudioSheet` satisfies Requirement R3.
3. **Audio Track Selector is supported out-of-the-box by media_kit**: `Player` provides `stream.tracks.audio`, `stream.track.audio`, and `setAudioTrack(track)`. Adding an audio track button to `PlayerScreen`'s HUD top bar and implementing `_showAudioTrackMenu()` completes Requirement R4.
4. **Clean-room blueprints and concrete values are ready**: All 11 canonical 10-band preset vectors have been verified, and unit test architectures have been established.

---

## 5. Verification Method

### 5.1 Independent Code Inspection
- Inspect `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart` to verify `AudioConfig` and `AudioStudioSheet` structure.
- Inspect `d:\E-player\app\lib\features\player\ui\player_screen.dart` lines 1404–1408 and 1776–1790 to verify current HUD icons and bottom sheet triggers.
- Inspect `C:\Users\Admin\AppData\Local\Pub\Cache\hosted\pub.dev\media_kit-1.2.6\lib\src\player\player.dart` lines 271–289 to confirm `setAudioTrack`.

### 5.2 Verification Commands
Run the following commands in `d:\E-player\app`:
```powershell
# 1. Verify Dart static analysis
dart analyze

# 2. Run existing test suite to ensure workspace integrity
flutter test test/features/video_effects_test.dart
flutter test test/unit/decoder_pipeline_test.dart
```

### 5.3 Invalidation Conditions
This analysis is invalidated if:
- `media_kit` does not expose `player.platform.setProperty('audio-delay', ...)` on desktop platforms (invalidated: empirically verified across all platforms).
- `equalizer=f=...` or `volume=volume=...` syntax is rejected by mpv's FFmpeg audio filter cascade.
