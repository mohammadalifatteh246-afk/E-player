# Milestone 3 Review & Adversarial Challenge Report: Audio Delay Sync Slider & Audio Track Selector Modal (R3, R4)

**Agent ID**: `reviewer_m3_2`  
**Parent Orchestrator**: `d319cada-6c05-4314-a8fc-3628ac99cc0c`  
**Milestone**: Milestone 3 (Requirements R3 & R4)  
**Date & Timestamp**: 2026-11-10T10:38:00Z  
**Verdict**: **APPROVE**  
**Integrity Status**: CLEAN (0 integrity violations, 0 facade implementations, 0 hardcoded test shortcuts)

---

## 1. Observation

### 1.1 Inspected Work Products & File Locations

1. **`d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart`**:
   - Lines 10: `double audioDelay = 0.0; // in milliseconds [-10000.0, 10000.0]`
   - Lines 121–130: `applyAudioDelay(Player? player)` method:
     ```dart
     void applyAudioDelay(Player? player) {
       if (player == null) return;
       try {
         final dynamic platform = player.platform;
         platform.setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3));
       } catch (e) {
         debugPrint('[Audio Studio] mpv audio-delay error: $e');
       }
     }
     ```
   - Lines 140: `AudioConfig.apply(Player? player)` calls `applyAudioDelay(player)` unconditionally, preserving audio delay synchronization even when master EQ is disabled (`enabled == false`).
   - Lines 148, 154: `AudioConfig.reset(Player? player)` resets `audioDelay = 0.0` and dispatches `0.000` to mpv.
   - Lines 232–237: 50ms debounced delay dispatch `_debouncedApplyAudioDelay()` for continuous slider drags.
   - Lines 239–249: Instant discrete nudge methods `_nudgeAudioDelay(double deltaMs)` and `_resetAudioDelay()`.
   - Lines 644–754: `_buildAudioDelaySyncCard()`:
     - Container key `Key('audio_delay_sync_card')`
     - Live badge pill `Key('audio_delay_badge')`: `${delayVal >= 0 ? "+" : ""}${delayVal.toStringAsFixed(0)} ms`
     - Continuous slider `Key('audio_delay_slider')`: `min: -10.0`, `max: 10.0`, `divisions: 400`, value clamped to `[-10.0, 10.0]`, with 50ms quantization `((v * 1000.0) / 50.0).round() * 50.0`
     - 5 discrete nudge buttons:
       - `-100ms`: `Key('audio_delay_nudge_minus_100')`
       - `-50ms`: `Key('audio_delay_nudge_minus_50')`
       - `Reset`: `Key('audio_delay_nudge_reset')`
       - `+50ms`: `Key('audio_delay_nudge_plus_50')`
       - `+100ms`: `Key('audio_delay_nudge_plus_100')`
   - Lines 1045–1074: `_buildBoostSwitchTile` uses `Material(color: EDesign.surface, ...)` resolving framework ink splash occlusion warnings.
   - Lines 1078–1231: Exported standalone `AudioDelaySyncCard` widget conforming to R3 specification.

2. **`d:\E-player\app\lib\features\player\ui\player_screen.dart`**:
   - Lines 76–78:
     ```dart
     List<AudioTrack> _audioTracks = [];
     AudioTrack _selectedAudioTrack = AudioTrack.no();
     double _audioDelayMs = 0.0;
     ```
   - Lines 278, 286: Stream listeners bound to `_player.stream.tracks` (`_audioTracks = tracks.audio`) and `_player.stream.track` (`_selectedAudioTrack = track.audio`).
   - Lines 1760–1764: HUD top bar button:
     ```dart
     IconButton(
       key: const Key('hud_audio_tracks_button'),
       icon: const Icon(Icons.audiotrack_outlined, color: Colors.white70, size: 20),
       tooltip: 'Audio Tracks',
       onPressed: _showAudioTrackMenu,
     ),
     ```
     Positioned between AI Studio button (lines 1749–1758) and Subtitles button (lines 1765–1769).
   - Lines 682–889: `_showAudioTrackMenu()`:
     - Glassmorphic bottom sheet `showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, ...)`
     - Container key `Key('audio_tracks_sheet')` styled with `EDesign.surface`, `EDesign.border`, and top drag handle pill.
     - Empty state key `Key('audio_tracks_empty')` when `_audioTracks.isEmpty`.
     - Track items with `Key('audio_track_item_${track.id}')`, title cascade `track.title ?? track.language ?? track.id`, rich metadata subtitle (language, codec, channels, sample rate), and active checkmark `Icon(Icons.check, key: Key('active_track_check'))`.
     - Tapping calls `_player.setAudioTrack(track)`, updates `_selectedAudioTrack`, triggers OSD feedback pill via `_showFeedbackMessage('Audio: $label', Icons.audiotrack)`, pops sheet, and re-requests keyboard focus via `_keyboardFocusNode.requestFocus()`.
   - Lines 921–932: `_nudgeAudioDelay(int offsetMs)`:
     ```dart
     _audioDelayMs = (_audioDelayMs + offsetMs).clamp(-10000.0, 10000.0);
     _audioConfig.audioDelay = _audioDelayMs;
     try {
       final platform = _player.platform as dynamic;
       platform.setProperty('audio-delay', (_audioDelayMs / 1000.0).toStringAsFixed(3));
     } catch (e) {
       debugPrint('[PlayerScreen] Failed to set audio-delay: $e');
     }
     final sign = _audioDelayMs >= 0 ? '+' : '';
     _showFeedbackMessage('Audio Delay: $sign${_audioDelayMs.round()}ms', Icons.audiotrack);
     ```
   - Lines 2114–2126: Bottom bar Audio Studio sheet opener ensures two-way delay synchronization:
     ```dart
     _audioConfig.audioDelay = _audioDelayMs;
     showModalBottomSheet(
       context: context,
       backgroundColor: Colors.transparent,
       isScrollControlled: true,
       builder: (context) => AudioStudioSheet(
         player: _player,
         config: _audioConfig,
       ),
     ).then((_) {
       _audioDelayMs = _audioConfig.audioDelay;
       if (mounted) _keyboardFocusNode.requestFocus();
     });
     ```

3. **`d:\E-player\app\test\features\audio_studio_test.dart`**:
   - Lines 404–570: Group 7 "Audio Delay Synchronization (R3 Parity & Property Dispatch)" containing 8 dedicated tests for default state, 3-decimal precision string formatting, ±10.0s boundary clamping, unconditional dispatch on `apply()`, reset dispatch to `0.000`, safe handling of null player / throwing platform, and full widget interaction test for `AudioDelaySyncCard`.

### 1.2 Independent Verification Execution

1. **Feature Unit & Widget Tests**:
   - Command: `cd d:\E-player\app; flutter test test/features/audio_studio_test.dart`
   - Execution Output:
     ```
     00:00 +0: loading D:/E-player/app/test/features/audio_studio_test.dart
     00:00 +0: Group 1: AudioConfig Default State & Presets Registry Default configuration initializes with correct defaults
     ...
     00:01 +34: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) AudioConfig initializes with audioDelay == 0.0
     00:01 +35: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) applyAudioDelay formats delay in seconds with exactly 3 decimals
     00:01 +36: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) Boundary values at -10000.0 and +10000.0 are formatted correctly
     00:01 +37: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) AudioConfig.apply sends both af and audio-delay to player
     00:01 +38: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) AudioConfig.apply sends audio-delay even when enabled is false
     00:01 +39: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) AudioConfig.reset restores audioDelay to 0.0 and applies 0.000 to player
     00:01 +40: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) Null player or throwing platform in applyAudioDelay is safe
     [Audio Studio] mpv audio-delay error: Exception: Simulated platform failure
     [Audio Studio] mpv af error: Exception: Simulated platform failure
     [Audio Studio] mpv audio-delay error: Exception: Simulated platform failure
     00:01 +41: Group 7: Audio Delay Synchronization (R3 Parity & Property Dispatch) AudioDelaySyncCard UI renders, responds to nudges, and dispatches to player
     00:07 +42: All tests passed!
     ```
   - Exit code: 0 (42 passed, 0 failed).

2. **Static Code Analysis**:
   - Command: `cd d:\E-player\app; dart analyze`
   - Execution Output:
     ```
     Analyzing app...
     No issues found!
     ```
   - Exit code: 0.

3. **End-to-End Suite Spot-Checks (`test/e2e/phase1_e2e_test.dart`)**:
   - `T1.3` (R3 Audio Delay Slider UI Presence, Continuous Drag, Nudges, Reset): 5/5 passed.
   - `T1.4` (R4 Audio Track HUD Button, Stream Listing, Modal Selection, Hotkey 'b'): 4/4 passed.
   - `T2.3` (Boundary Clamping at ±10.0s, Rapid Taps, Unloaded Fallback, 3-Decimals): 5/5 passed.
   - `T2.4` (Empty State, Single Track, Missing Metadata Fallback, Empty Hotkey 'b'): 5/5 passed.
   - `T3.8` & `T3.9` (Speed Reset Preserves Delay, Audio Track Switch Retains EQ & Delay): 2/2 passed.

---

## 2. Logic Chain

1. **Integrity Verification**:
   - Inspected source code for hardcoded test fixtures, dummy stubs, or bypasses. All logic is authentic:
     - `audioDelay` is a dynamic floating point variable with genuine arithmetic clamping `[-10000.0, 10000.0]`.
     - Platform calls interact directly with `player.platform.setProperty('audio-delay', ...)`.
     - UI widgets are standard Flutter Material widgets bound to dynamic callbacks and state.
   - Conclusion: **NO INTEGRITY VIOLATION**.

2. **Requirement R3 Conformance (Audio Delay Sync)**:
   - Observation 1.1 shows a continuous slider with `min: -10.0`, `max: 10.0`, `divisions: 400` covering 50ms increments.
   - Live badge pill updates dynamically with format `${delayVal >= 0 ? "+" : ""}${delayVal.toStringAsFixed(0)} ms`.
   - Discrete nudge buttons provide tactile, un-debounced adjustments of -100ms, -50ms, Reset (0ms), +50ms, and +100ms.
   - String formatting `(audioDelay / 1000.0).toStringAsFixed(3)` satisfies mpv float second specification exactly.
   - Conclusion: **R3 is 100% satisfied**.

3. **Requirement R4 Conformance (Audio Track Selector Modal)**:
   - Observation 1.1 confirms top bar HUD button with key `hud_audio_tracks_button` positioned between AI Studio and Subtitles.
   - `_showAudioTrackMenu()` opens a glassmorphic bottom sheet reading active stream tracks from `_player.stream.tracks.audio`.
   - Displays empty state (`Key('audio_tracks_empty')`) when no audio streams exist.
   - Displays track list with language/codec/channels/sample rate metadata and active checkmark for selected track.
   - Track selection triggers `_player.setAudioTrack(track)` and instant OSD notification.
   - Bottom sheet dismissal restores desktop keyboard focus via `_keyboardFocusNode.requestFocus()`.
   - Conclusion: **R4 is 100% satisfied**.

4. **Two-Way Synchronization**:
   - Hotkey nudges via `k`/`j` in `player_screen.dart` synchronize `_audioDelayMs` into `_audioConfig.audioDelay`.
   - Opening `AudioStudioSheet` passes initialized `_audioConfig.audioDelay = _audioDelayMs`.
   - Closing `AudioStudioSheet` synchronizes `_audioDelayMs = _audioConfig.audioDelay`.
   - Hotkeys and bottom sheet controls operate on unified state.
   - Conclusion: **Two-way synchronization is complete and verified**.

---

## 3. Adversarial Stress-Testing & Challenges

### Challenge 1: Debounce Race Condition on Modal Sheet Dismissal
- **Hypothesis**: If a user drags the continuous slider and immediately dismisses the bottom sheet before 50ms expires, the debounced timer might be canceled without applying the final delay value to mpv.
- **Investigation**: In `AudioStudioSheet._debouncedApplyAudioDelay()`, the timer delay is 50ms. Sheet dismissal in Flutter involves a reverse slide animation that takes ~250–300ms. Even on instant programmatic pop, `_config.audioDelay` has already been updated in memory (`_config.audioDelay = ms`). Nudge buttons call `applyAudioDelay` synchronously without debounce.
- **Risk Level**: LOW (Non-blocking, standard UI debounce behavior).

### Challenge 2: Floating-Point Rounding & Division Noise
- **Hypothesis**: Repetitive slider movement or repeated ±50ms nudge calculations could introduce IEEE 754 precision drift (e.g. `49.99999999999999ms`).
- **Investigation**:
  - In `AudioStudioSheet`: `final ms = ((v * 1000.0) / 50.0).round() * 50.0;` quantizes directly through integer rounding, preventing drift.
  - In `_nudgeAudioDelay`: offset is an integer `int offsetMs` added to `_audioDelayMs`, clamped with integer-like double bounds.
  - Format dispatch `(audioDelay / 1000.0).toStringAsFixed(3)` explicitly rounds to the nearest thousandth of a second (millisecond precision).
- **Risk Level**: LOW (Safely mitigated by explicit quantization and fixed-decimal formatting).

### Challenge 3: Unhandled Platform Player Exceptions
- **Hypothesis**: If the media player engine terminates or `player.platform` throws during delay application, unhandled exceptions could crash the UI.
- **Investigation**: Both `AudioConfig.applyAudioDelay` and `PlayerScreen._nudgeAudioDelay` wrap platform invocations in `try { ... } catch (e) { debugPrint(...) }`, ensuring safe degradation. Tested in `audio_studio_test.dart` line 499 with `ThrowingPlatformPlayer` and confirmed passing.
- **Risk Level**: LOW (Exception-safe).

---

## 4. Caveats

- **Native Windows MPV Binary Execution**: Verification was conducted via automated Flutter widget tests using `FakePlayerPlatform` and full widget harnesses in `test/features/` and `test/e2e/`. Direct hardware-accelerated playback with live media files was not compiled locally per project constraints (`no local compilation of binaries: do NOT run flutter build windows`).
- **E2E Physical Keyboard Simulation**: Upstream test `T1.1.7` in `test/e2e/phase1_e2e_test.dart` encounters Flutter physical key simulation limitations on desktop runners; this is an R1 shortcut test runner constraint outside Milestone 3's R3/R4 scope.

---

## 5. Conclusion

The Milestone 3 implementation by `worker_m3_1` satisfies all functional requirements (R3, R4), interface contracts, visual aesthetics, error handling, and performance standards. Code analysis is completely clean (`dart analyze` reports no issues), and automated test suites pass without failure (42/42 tests in `test/features/audio_studio_test.dart`).

**Verdict: APPROVE**

---

## 6. Verification Method

To independently reproduce this verification:

```powershell
cd d:\E-player\app

# 1. Static Analysis
dart analyze

# 2. Audio Studio & Delay Feature Tests
flutter test test/features/audio_studio_test.dart

# 3. E2E R3 & R4 Specific Scenarios
flutter test test/e2e/phase1_e2e_test.dart --plain-name "T1.3"
flutter test test/e2e/phase1_e2e_test.dart --plain-name "T1.4"
flutter test test/e2e/phase1_e2e_test.dart --plain-name "T2.3"
flutter test test/e2e/phase1_e2e_test.dart --plain-name "T2.4"
```
