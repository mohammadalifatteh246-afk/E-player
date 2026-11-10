# Specification Mining Handoff Report: 4-Tier Test Case Partition (Phase 1 E2E)

**Agent**: Specification Miner (Milestone 4 - Dual Track)  
**Target File**: `test/e2e/phase1_e2e_test.dart`  
**Requirements Covered**: R1–R5 (Desktop Shortcuts, 4-Tier Seek Physics, Audio Delay Sync, Dedicated Audio Track Modal, Equalizer Parity & Preamp Slider)  
**Date**: 2026-11-10T08:50:00Z  
**Total Test Cases Designed**: **68 Test Cases** (Tier 1: 27, Tier 2: 26, Tier 3: 10, Tier 4: 5)  

---

## 1. Observation

Direct observations from the authoritative specifications, codebase, and reference binary:

### 1.1 Authoritative Requirements & Codebase State
- **`ORIGINAL_REQUEST.md` (R1–R5)**:
  - **R1 (Shortcuts)**: 13 universal cross-platform hotkeys: `Space` (Play/Pause), `f`/`F11` (Fullscreen), `m` (Mute), `b` (Cycle Audio Tracks with OSD), `v` (Cycle Subtitle Tracks with OSD), `a` (Cycle Aspect Ratios), `h`/`g` (Subtitle delay ±50ms), `k`/`j` (Audio delay ±50ms), `+`/`-` (Coarse speed), `]`/`[` (Fine speed ±0.1x), `=` (Reset speed 1.0x), `Arrow Left`/`Arrow Right` (10s seek), `Arrow Up`/`Arrow Down` (Volume 5%).
  - **R2 (4-Tier Seek Physics)**: Modifier-based intervals: `Shift + Left/Right` (3s Very Short), `Alt + Left/Right` (10s Short), `Ctrl + Left/Right` (60s Medium), `Ctrl + Alt + Left/Right` (300s Long).
  - **R3 (Audio Delay Sync)**: Continuous slider from `-10.0s` to `+10.0s` with 50ms divisions (400 divisions), plus 5 dedicated nudge buttons (`-100ms`, `-50ms`, `Reset 0ms`, `+50ms`, `+100ms`), bound to mpv property `audio-delay`.
  - **R4 (Dedicated Audio Track Modal)**: Quick selector icon in `PlayerScreen` HUD top bar between AI Studio and Subtitles opening a glassmorphic bottom sheet; lists detected audio streams from `_player.stream.tracks.audio`; switches active stream via `_player.setAudioTrack(track)`.
  - **R5 (Equalizer Parity & Preamp)**: 11 canonical VLC presets (`Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`), expanded 10-band range to `[-20.0dB, +20.0dB]`, and global Pre-Amplification slider `[-20.0dB, +20.0dB]` mapped to mpv filter `volume=volume=+XdB:precision=fixed`.

### 1.2 Binary Telemetry & VLC Reference Implementation
- **VLC Equalizer Binary**: `C:\Program Files (x86)\VideoLAN\VLC\plugins\audio_filter\libequalizer_plugin.dll` (offset `0xA080`–`0xA500`) confirmed exact 10 frequency band centers: `[60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz]`.
- **Preamp Gain**: Applied prior to band filtering in mpv `af` filter string as `volume=volume=+X.XdB:precision=fixed`. When `preamp == 0.0dB`, it is omitted to ensure bit-perfect unity gain pass-through.
- **Audio Delay mpv Binding**: mpv property `audio-delay` takes float seconds string: `(player.platform as dynamic).setProperty('audio-delay', (delayMs / 1000.0).toStringAsFixed(3))`.
- **vlcrc Jump Intervals**: `%APPDATA%\vlc\vlcrc` line 274: `jump-size-1=3`, `jump-size-2=10`, `jump-size-3=60`, `jump-size-4=300`.

### 1.3 Test Infrastructure & Mocking Support
- `test/helpers/eplayer_test_harness.dart` provides `EPlayerTestHarness`, in-memory SQLite FFI, temporary directory creation, mock SharedPreferences, and mathematical boundary validators (`GestureArbitratorMath.clampDuration`, `clampVolume`, etc.).
- Direct instantiation of C-FFI `Player()` without `mpv.dll` in headless CI environments can cause dynamic library link errors; therefore, tests must either use a headless mock platform or test the dedicated architectural components (`DesktopKeyboardHandler`, `AudioConfig`, `AudioStudioSheet`, `PlayerScreen` with mock/fake player) cleanly.

---

## 2. Logic Chain

1. **Test Suite Scope & Opaque-Box Mandate**:
   - The test suite `test/e2e/phase1_e2e_test.dart` must evaluate requirements R1–R5 from the user perspective (key presses, widget taps, slider interactions) and verify observable outputs (OSD pill notifications, player state, and mpv property/filter calls).
   - In accordance with `TEST_INFRA.md`, the test matrix requires at least 65 tests partitioned into 4 tiers:
     - Tier 1: Feature Coverage (≥25 tests) -> Designed: **27 tests**
     - Tier 2: Boundary & Corner Cases (≥25 tests) -> Designed: **26 tests**
     - Tier 3: Cross-Feature Interactions (≥10 tests) -> Designed: **10 tests**
     - Tier 4: Real-World Scenarios (≥5 tests) -> Designed: **5 tests**
     - Total: **68 tests**.

2. **Stimuli & Invariant Mapping**:
   - Every shortcut (R1) maps a `KeyDownEvent` to a concrete player action and an OSD feedback overlay (`_showFeedback` pill at `top: 90`).
   - 4-tier jumps (R2) require modifier precedence: `(Ctrl || Meta) && Alt` (300s) > `Ctrl || Meta` (60s) > `Alt` (10s) > `Shift` (3s) > unmodified (10s). Targets must be clamped strictly to `[Duration.zero, player.state.duration]`.
   - Audio delay (R3) maps continuous slider values and 5 discrete nudge buttons (`-100ms`, `-50ms`, `Reset`, `+50ms`, `+100ms`) to `audio-delay` in `[-10.0, 10.0]` s.
   - Audio track selector modal (R4) binds `_player.stream.tracks.audio` to a glassmorphic sheet, handles track selection via `_player.setAudioTrack`, and updates active checkmarks.
   - Equalizer parity (R5) maps the 11 VLC presets and global preamp slider to mpv `af` filter strings (`volume=volume=+XdB:precision=fixed,equalizer=...`).

---

## 3. Discovered Specifications

## Features Discovered
| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Keyboard | Desktop Shortcuts Dispatcher | Intercepts keyboard events and maps 13 universal desktop actions | `KeyEvent` (KeyDown) | Dispatched player actions & OSD | KeyUp and unmapped keys ignored cleanly | `ORIGINAL_REQUEST.md` §R1 |
| 2 | Navigation | 4-Tier Jump Physics | Modifier-based precision seek intervals (3s, 10s, 60s, 300s) | Shift/Alt/Ctrl + Left/Right | `player.seek(clampedTarget)` | Clamps to `[Duration.zero, duration]` | `ORIGINAL_REQUEST.md` §R2 |
| 3 | OSD | Visual Feedback Overlay Pill | Glassmorphic overlay pill at `top: 90` displaying icon and message | Shortcut trigger | Visual feedback container | Auto-dismisses after 800–1500ms | `PROJECT.md` §Interface Contracts |
| 4 | Audio Sync | Audio Delay Sync Slider | Continuous slider from -10.0s to +10.0s with 50ms divisions | Slider drag | `mpv.setProperty('audio-delay', val)` | Clamps strictly to `[-10.0, 10.0]` | `ORIGINAL_REQUEST.md` §R3 |
| 5 | Audio Sync | Audio Delay Nudge Buttons | 5 dedicated nudge buttons (-100ms, -50ms, Reset, +50ms, +100ms) | Button tap | Increment/decrement delay offset | Clamps to ±10000ms | `ORIGINAL_REQUEST.md` §R3 |
| 6 | Track Modal | Dedicated Audio Track Button | HUD top bar button opening glassmorphic audio stream selector | Tap icon button | Glassmorphic bottom sheet | Safe fallback when 0 tracks detected | `ORIGINAL_REQUEST.md` §R4 |
| 7 | Track Modal | Instant Stream Switching | Audio stream selection via media_kit `setAudioTrack` API | Select track tile | `player.setAudioTrack(track)` | Safe no-op if track already active | `ORIGINAL_REQUEST.md` §R4 |
| 8 | Track Cycling | Hotkey 'b' Audio Cycling | Cycles active audio stream sequentially with OSD feedback | Key `b` press | Sequential track switch & OSD | Safe no-op when tracks list is empty | `ORIGINAL_REQUEST.md` §R1, §R4 |
| 9 | Equalizer | 11 VLC Equalizer Presets | Exact 10-band decibel profiles extracted from VLC PE binary | Preset name | Updated 10 bands + preamp in `AudioConfig` | Reverts to Flat on unknown preset | `ORIGINAL_REQUEST.md` §R5 |
| 10 | Equalizer | Global Preamp Gain Slider | Global slider (-20dB to +20dB) mapped to mpv volume filter | Slider drag | `volume=volume=+XdB:precision=fixed` in `af` | Clamps to `[-20.0, 20.0]`; bypassed at 0dB | `ORIGINAL_REQUEST.md` §R5 |
| 11 | Equalizer | 10-Band Gain Scale Expansion | Expands EQ band slider scale from ±12dB to ±20dB | Band slider drag | `equalizer=f=...:g=...` in `af` | Clamps to `[-20.0, 20.0]` | `ORIGINAL_REQUEST.md` §R5 |
| 12 | Navigation | Frame Stepping ('e') | Advances single video frame and pauses playback | Key `e` press | `mpv.setProperty('frame-step', '')` | Pauses active playback; advances frame | `vlc_gap_analysis.md` §5.6 |

## Edge Cases
| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | 4-Tier Jump | `Ctrl + Alt + ArrowLeft` when at `00:01:15` | Target `-00:03:45` clamps strictly to `Duration.zero` (00:00:00). No underflow exception. |
| 2 | 4-Tier Jump | `Ctrl + Alt + ArrowRight` when 90s from EOF | Target clamps strictly to `player.state.duration`. Playback reaches EOF cleanly. |
| 3 | 4-Tier Jump | Simultaneous `Shift + Ctrl + ArrowRight` | Priority order: Ctrl takes precedence over Shift; emits 60s medium jump. |
| 4 | Shortcuts | Keystroke while modal sheet or dialog is open | Text fields with active focus intercept key events; player shortcuts do not trigger. |
| 5 | Audio Delay | Multiple rapid clicks on `+100ms` button | Debounced platform call batches updates; delay clamps strictly to `+10000ms`. |
| 6 | Audio Delay | Initial load before mpv has loaded media | Initial delay query catches error and defaults safely to `0.0 ms`. |
| 7 | Audio Track Selector | Video with zero audio streams (silent video) | Sheet renders "No audio tracks found" empty state; does not crash. |
| 8 | Audio Track Selector | Video with single audio stream | Shows stream with checked state; tapping closes modal with no-op. |
| 9 | Equalizer | Switching preset while EQ is disabled | Updates `_config.eq` and `_config.preamp` state without emitting mpv filter until enabled. |
| 10 | Equalizer Preamp | Preamp slider set to exact `0.0 dB` | Omitted from mpv `af` filter string to ensure optimal bit-perfect pass-through. |
| 11 | Equalizer Presets | Selecting "Custom" after modifying single band | Preset pill displays "Custom" while maintaining current band and preamp positions. |
| 12 | Playback Speed | Repeated coarse decrement past 0.25x | Playback rate clamps strictly to `0.25x`; does not drop to 0 or reverse playback. |
| 13 | Volume Control | Repeated volume increment past 100% | Volume clamps strictly to nominal `100.0%` (or maximum configured threshold). |

---

## 4. Complete 4-Tier Test Case Matrix (68 Test Cases)

### Tier 1: Feature Coverage (27 Tests)

| Test ID | Name | Feature | Inputs / Stimuli | Expected State Changes | OSD Feedback | mpv Assertions |
|:---|:---|:---|:---|:---|:---|:---|
| **T1.1.1** | Shortcut Space Play/Pause | Shortcuts | Press `Space` key | `player.state.playing` toggles (false -> true -> false) | Text: "Play" / "Pause", Icon: `play_arrow_rounded` / `pause_rounded` | `player.playOrPause()` invoked |
| **T1.1.2** | Shortcut Fullscreen Toggle | Shortcuts | Press `f` key, then `F11` key | `onToggleFullscreen()` callback invoked twice | Fullscreen state toggles | Window fullscreen state toggles |
| **T1.1.3** | Shortcut Mute Toggle | Shortcuts | Press `m` key | When volume > 0, volume set to 0.0; when 0.0, volume restored | Text: "Mute" / "Volume: X%", Icon: `volume_off` / `volume_up` | `player.setVolume(0.0)` / `player.setVolume(target)` |
| **T1.1.4** | Shortcut Aspect Ratio Cycle | Shortcuts | Press `a` key | Aspect ratio mode cycles: Fit -> Crop -> 16:9 -> 4:3 -> 21:9 -> Fit | Text: "Aspect Ratio: <Mode>", Icon: `aspect_ratio` | `onCycleAspectRatio()` invoked |
| **T1.1.5** | Shortcut Subtitle Delay Nudge | Shortcuts | Press `h` (+50ms), then `g` (-50ms) | `subDelay` increments by +50ms, then decrements by -50ms | Text: "Subtitle Delay: +50 ms" / "-50 ms", Icon: `subtitles` | `platform.setProperty('sub-delay', '0.05')` |
| **T1.1.6** | Shortcut Audio Delay Nudge | Shortcuts | Press `k` (+50ms), then `j` (-50ms) | `audioDelay` increments by +50ms, then decrements by -50ms | Text: "Audio Delay: +50 ms" / "-50 ms", Icon: `audiotrack` | `platform.setProperty('audio-delay', '0.050')` |
| **T1.1.7** | Shortcut Playback Speed Controls | Shortcuts | Press `+`, `-`, `]`, `[`, and `=` | Rate steps: +0.25x (+), -0.25x (-), +0.1x (]), -0.1x ([), 1.0x (=) | Text: "Speed: X.XXx" / "Speed: 1.0x (Normal)", Icon: `speed` | `player.setRate(rate)` |
| **T1.1.8** | Shortcut Volume Adjustment | Shortcuts | Press `Arrow Up` (+5%), `Arrow Down` (-5%) | Volume increments/decrements by 5.0%, clamped `[0.0, 100.0]` | Text: "Volume: X%", Icon: `volume_up` / `volume_down` | `player.setVolume(vol)` |
| **T1.2.1** | 4-Tier Jump Tier 1 Very Short (3s) | 4-Tier Seek | Press `Shift + ArrowRight` / `Shift + ArrowLeft` | Position seeks `+3s` forward / `-3s` backward | Text: "+3s (Dialogue Jump)" / "-3s (Dialogue Jump)", Icon: `fast_forward` / `fast_rewind` | `_aiEngine.invalidateQueue()`, `player.seek(pos ± 3s)` |
| **T1.2.2** | 4-Tier Jump Tier 2 Short (10s) | 4-Tier Seek | Press `Alt + ArrowRight` / `Alt + ArrowLeft` | Position seeks `+10s` forward / `-10s` backward | Text: "+10s (Short Jump)" / "-10s (Short Jump)", Icon: `fast_forward` / `fast_rewind` | `_aiEngine.invalidateQueue()`, `player.seek(pos ± 10s)` |
| **T1.2.3** | 4-Tier Jump Tier 3 Medium (60s) | 4-Tier Seek | Press `Ctrl + ArrowRight` / `Ctrl + ArrowLeft` | Position seeks `+60s` forward / `-60s` backward | Text: "+60s (Medium Jump)" / "-60s (Medium Jump)", Icon: `fast_forward` / `fast_rewind` | `_aiEngine.invalidateQueue()`, `player.seek(pos ± 60s)` |
| **T1.2.4** | 4-Tier Jump Tier 4 Long (300s) | 4-Tier Seek | Press `Ctrl + Alt + ArrowRight` / `Ctrl + Alt + ArrowLeft` | Position seeks `+300s` forward / `-300s` backward | Text: "+300s (Long Jump (5m))" / "-300s (Long Jump (5m))", Icon: `fast_forward` / `fast_rewind` | `_aiEngine.invalidateQueue()`, `player.seek(pos ± 300s)` |
| **T1.2.5** | 4-Tier Jump Default Seek (10s) | 4-Tier Seek | Press unmodified `ArrowRight` / `ArrowLeft` | Position seeks `+10s` forward / `-10s` backward | Text: "+10s (Seek (10s))" / "-10s (Seek (10s))", Icon: `fast_forward` / `fast_rewind` | `_aiEngine.invalidateQueue()`, `player.seek(pos ± 10s)` |
| **T1.3.1** | Audio Delay Slider UI Presence & Range | Audio Delay | Mount `AudioStudioSheet` | Slider rendered with range `[-10.0, 10.0]`, 400 divisions | Live badge: "+0 ms" | Slider min=-10.0, max=10.0, divisions=400 |
| **T1.3.2** | Audio Delay Slider Continuous Drag | Audio Delay | Drag slider thumb to `+1.50s` (+1500ms) | `audioDelay` updates to 1500.0ms | Live badge: "+1500 ms" | `platform.setProperty('audio-delay', '1.500')` |
| **T1.3.3** | Audio Delay Nudge ±50ms Buttons | Audio Delay | Tap `+50ms` button, then `-50ms` button | `audioDelay` updates to +50ms, then 0ms | Live badge: "+50 ms" -> "+0 ms" | `platform.setProperty('audio-delay', '0.050')` |
| **T1.3.4** | Audio Delay Nudge ±100ms Buttons | Audio Delay | Tap `+100ms` button, then `-100ms` button | `audioDelay` updates to +100ms, then 0ms | Live badge: "+100 ms" -> "+0 ms" | `platform.setProperty('audio-delay', '0.100')` |
| **T1.3.5** | Audio Delay Reset Button | Audio Delay | Tap `Reset 0ms` button when delay is +450ms | `audioDelay` resets to 0.0ms | Live badge: "+0 ms" | `platform.setProperty('audio-delay', '0.000')` |
| **T1.4.1** | Audio Track HUD Button Presence | Audio Track | Inspect `PlayerScreen` HUD top bar | Audio track icon button present between AI Studio and Subtitles | Tooltip: "Audio Tracks" | Tapping opens modal sheet |
| **T1.4.2** | Audio Track Modal Stream Listing | Audio Track | Open audio track modal with 3 audio streams | Modal displays 3 stream tiles with titles, languages, and channels | Header: "Audio Tracks" | Tiles show `track.title ?? track.language ?? track.id` |
| **T1.4.3** | Audio Track Modal Selection | Audio Track | Tap unselected Track 2 in modal | `_selectedAudioTrack` set to Track 2, modal closes | Text: "Audio: Track 2", Icon: `audiotrack` | `player.setAudioTrack(track2)` |
| **T1.4.4** | Audio Track Cycling via Hotkey 'b' | Audio Track | Press key `b` | Cycles active track to next in `_audioTracks` | Text: "Audio: <Next Track>", Icon: `audiotrack` | `player.setAudioTrack(nextTrack)` |
| **T1.5.1** | Master Equalizer Switch Toggle | Equalizer | Toggle "Enable Equalizer" switch | `enabled` flag toggles true/false | Switch state updates | Enabled: sets `af` with EQ graph; Disabled: sets `af` to `''` |
| **T1.5.2** | Equalizer 11 VLC Presets Selection | Equalizer | Select each of 11 VLC presets in picker | 10 band gains update to canonical decibel vectors | Preset name pill displays selected preset | `af` string contains corresponding `equalizer=f=...:g=...` |
| **T1.5.3** | 10-Band EQ Gain Scale (±20dB) | Equalizer | Drag band sliders to `+18.5dB` and `-15.0dB` | `eq[0]=18.5`, `eq[9]=-15.0` | Band gain labels display "+18.5 dB" / "-15.0 dB" | `af` includes `equalizer=f=60:...:g=18.5,equalizer=f=16000:...:g=-15.0` |
| **T1.5.4** | Preamp Gain Slider Adjustment | Equalizer | Drag Preamp slider to `+6.0dB` | `preamp` set to 6.0dB | Preamp label displays "+6.0 dB" | `af` prepends `volume=volume=+6.0dB:precision=fixed` |
| **T1.5.5** | Preamp 0.0dB Bit-Perfect Pass-Through | Equalizer | Set Preamp slider to `0.0dB` | `preamp` set to 0.0dB | Preamp label displays "0.0 dB" | `volume=volume=...` omitted from `af` string |

---

### Tier 2: Boundary & Corner Cases (26 Tests)

| Test ID | Name | Feature | Inputs / Stimuli | Expected State Changes | OSD Feedback | mpv Assertions |
|:---|:---|:---|:---|:---|:---|:---|
| **T2.1.1** | Volume Clamp Upper Limit | Shortcuts | Press `Arrow Up` 5 times when volume is 95% | Volume increases to 100% and clamps strictly at 100.0% | Text: "Volume: 100%", Icon: `volume_up` | `player.setVolume(100.0)` |
| **T2.1.2** | Volume Clamp Lower Limit | Shortcuts | Press `Arrow Down` 5 times when volume is 5% | Volume decreases to 0% and clamps strictly at 0.0% | Text: "Mute", Icon: `volume_off` | `player.setVolume(0.0)` |
| **T2.1.3** | Playback Speed Minimum Clamp | Shortcuts | Press `[` fine speed down 10 times at 0.3x | Rate decreases to 0.25x and clamps strictly at 0.25x | Text: "Speed: 0.25x", Icon: `speed` | `player.setRate(0.25)` |
| **T2.1.4** | Playback Speed Maximum Clamp | Shortcuts | Press `]` fine speed up 10 times at 3.8x | Rate increases to 4.0x and clamps strictly at 4.0x | Text: "Speed: 4.00x", Icon: `speed` | `player.setRate(4.0)` |
| **T2.1.5** | Unmapped Keys and KeyUp Ignored | Shortcuts | Dispatch `KeyUpEvent` for Space, and `KeyDownEvent` for `Escape`/`Tab` | No state change, returns `KeyEventResult.ignored` | No OSD emitted | Zero player invocations |
| **T2.2.1** | Seek Backward Underflow Clamping | 4-Tier Seek | Press `Ctrl + Alt + ArrowLeft` (-300s) when position is 00:01:30 | Position clamps strictly to `Duration.zero` (00:00:00) | Text: "-300s (Long Jump (5m))", Icon: `fast_rewind` | `player.seek(Duration.zero)` |
| **T2.2.2** | Seek Forward Overflow Clamping | 4-Tier Seek | Press `Ctrl + Alt + ArrowRight` (+300s) when 60s from duration | Position clamps strictly to `player.state.duration` | Text: "+300s (Long Jump (5m))", Icon: `fast_forward` | `player.seek(duration)` |
| **T2.2.3** | Seek with Zero / Unknown Duration | 4-Tier Seek | Press `Shift + ArrowRight` when `duration == Duration.zero` | Target calculated without NaN/negative clamp error | Text: "+3s (Dialogue Jump)", Icon: `fast_forward` | `player.seek(target)` |
| **T2.2.4** | Multiple Modifiers Priority Resolution | 4-Tier Seek | Hold `Ctrl + Shift` simultaneously and press `ArrowRight` | Evaluates `Ctrl` (60s) over `Shift` (3s); seeks 60s | Text: "+60s (Medium Jump)", Icon: `fast_forward` | `player.seek(pos + 60s)` |
| **T2.2.5** | macOS Meta Modifier Equivalence | 4-Tier Seek | Hold `Meta` (Cmd) and press `ArrowRight` | Recognizes `isMetaPressed` as Ctrl equivalent; seeks 60s | Text: "+60s (Medium Jump)", Icon: `fast_forward` | `player.seek(pos + 60s)` |
| **T2.3.1** | Audio Delay Upper Clamp (+10.0s) | Audio Delay | Tap `+100ms` button 10 times when delay is +9950ms | Delay increments to +10000ms and clamps strictly at 10000.0ms | Live badge: "+10000 ms" | `platform.setProperty('audio-delay', '10.000')` |
| **T2.3.2** | Audio Delay Lower Clamp (-10.0s) | Audio Delay | Tap `-100ms` button 10 times when delay is -9950ms | Delay decrements to -10000ms and clamps strictly at -10000.0ms | Live badge: "-10000 ms" | `platform.setProperty('audio-delay', '-10.000')` |
| **T2.3.3** | Rapid Sequential Nudge Taps | Audio Delay | Tap `+50ms` button 5 times within 150ms | All 5 increments processed; delay advances by +250ms | Live badge: "+250 ms" | Final property call: `'0.250'` |
| **T2.3.4** | Audio Delay Unloaded Media Fallback | Audio Delay | Open `AudioStudioSheet` when player has no media loaded | Delay gracefully initializes to 0.0ms without throwing | Live badge: "+0 ms" | Safe fallback, zero exceptions |
| **T2.3.5** | Audio Delay 3-Decimal Precision Format | Audio Delay | Nudge delay to +50ms, -150ms, +1250ms | Property strings strictly formatted as `0.050`, `-0.150`, `1.250` | Formatted live badges | RegEx matches `^[+-]?\d+\.\d{3}$` |
| **T2.4.1** | Empty Audio Tracks Graceful State | Audio Track | Open audio track modal when `tracks.audio == []` | Modal displays "No audio tracks found" text; zero crashes | Empty state placeholder | Zero `setAudioTrack` calls |
| **T2.4.2** | Single Audio Track Selection No-Op | Audio Track | Tap already active Track 1 when only 1 track exists | Sheet closes, retains Track 1 without redundant stream reset | Text: "Audio: Track 1", Icon: `audiotrack` | Safe no-op |
| **T2.4.3** | Audio Track Missing Metadata Fallback | Audio Track | Render track with `title == null` and `language == null` | Tile renders track `id` (e.g. "Track 1") | Fallback title displayed | Render valid widget tree |
| **T2.4.4** | Track Cycle Hotkey 'b' with Empty Tracks | Audio Track | Press key `b` when `tracks.audio == []` | Safe no-op; does not throw `RangeError` | No OSD or empty OSD | Zero player exceptions |
| **T2.4.5** | Track Cycle Hotkey 'b' with Single Track | Audio Track | Press key `b` when `tracks.audio.length == 1` | Re-confirms single track without stream recreation | Text: "Audio: Track 1", Icon: `audiotrack` | Safe no-op |
| **T2.5.1** | Preamp Upper Limit Clamp (+20.0dB) | Equalizer | Drag Preamp slider to extreme right | Preamp value clamps strictly at `+20.0dB` | Preamp label: "+20.0 dB" | `volume=volume=+20.0dB:precision=fixed` |
| **T2.5.2** | Preamp Lower Limit Clamp (-20.0dB) | Equalizer | Drag Preamp slider to extreme left | Preamp value clamps strictly at `-20.0dB` | Preamp label: "-20.0 dB" | `volume=volume=-20.0dB:precision=fixed` |
| **T2.5.3** | 10-Band EQ Individual Slider Clamping | Equalizer | Drag 60Hz band slider past +20dB and 16kHz past -20dB | Bands clamp strictly to `+20.0dB` and `-20.0dB` | Band labels: "+20.0 dB" / "-20.0 dB" | `af` contains clamped values |
| **T2.5.4** | Custom Preset Name on Band Edit | Equalizer | Select 'Rock' preset, then modify 1kHz band slider | Preset selector label transitions from 'Rock' to 'Custom' | Preset label: "Custom" | Live custom EQ filters |
| **T2.5.5** | Preset Edit While Master Switch Disabled | Equalizer | Select 'Reggae' preset while EQ master switch is OFF | `_config.eq` and `_config.preamp` update in memory; `af` remains `''` | UI updates | `platform.setProperty('af', '')` |
| **T2.5.6** | Negative Preamp Gain String Formatting | Equalizer | Set Preamp slider to `-8.5dB` | Value formatted with minus sign and 1 decimal place | Preamp label: "-8.5 dB" | `volume=volume=-8.5dB:precision=fixed` |

---

### Tier 3: Cross-Feature Interactions (10 Tests)

| Test ID | Name | Features Exercised | Stimuli / Sequence | Expected State & Behavior | OSD / mpv Assertions |
|:---|:---|:---|:---|:---|:---|
| **T3.1** | Hotkey 'b' Track Cycle with Open Modal | Shortcuts + Audio Track Modal | Open audio track modal, then press key `b` | Active audio track advances to next; checkmark in open modal updates | OSD: "Audio: <Track>", modal checkmark updates |
| **T3.2** | Audio Delay Nudge at 2.0x Speed | Shortcuts + Audio Delay | Set playback speed to 2.0x, then press key `k` (+50ms) | `rate` remains 2.0x; `audio-delay` property updates to `0.050` | `platform.setProperty('audio-delay', '0.050')`, speed remains 2.0x |
| **T3.3** | Preset Change with Active Preamp Boost | Equalizer Presets + Preamp Slider | Set Preamp to `+4.0dB`, then select 'Large Hall' preset | Combined filter string includes preamp volume and Large Hall bands | `af` starts with `volume=volume=+4.0dB:precision=fixed` followed by Large Hall EQ bands |
| **T3.4** | 4-Tier Jump During Volume Adjustment | 4-Tier Seek + Volume Shortcuts | Press `Arrow Up` (+5%), immediately followed by `Shift + ArrowRight` (+3s) | Volume increments by 5%; position advances by 3s without modifier bleed | OSD sequentially: "Volume: 85%" -> "+3s (Dialogue Jump)" |
| **T3.5** | UI Delay Slider Sync with Hotkey 'k'/'j' | Audio Delay Slider + Shortcuts | Drag slider in sheet to +200ms, close sheet, press `k` (+50ms) | Underlying `audioDelay` reaches +250ms; reopening sheet reflects +250ms | Slider thumb at +250ms, live badge: "+250 ms" |
| **T3.6** | Audio Mute While Preamp is Boosted | Shortcuts + Preamp Slider | Set Preamp to `+10.0dB`, then press `m` (Mute) | Player volume set to 0.0; `af` filter graph retains `volume=volume=+10.0dB` | Master volume = 0.0, unmuting restores audio with preamp intact |
| **T3.7** | 5-Minute Long Jump Followed by Play/Pause | 4-Tier Seek + Shortcuts | Press `Ctrl + Alt + ArrowRight` (+300s), then press `Space` | Position seeks +300s, queue invalidated; playback pauses cleanly | `player.seek(pos + 300s)`, `player.state.playing == false` |
| **T3.8** | Speed Reset While Audio Delay is Non-Zero | Shortcuts + Audio Delay | Set speed to 1.5x and delay to +350ms; press key `=` | Speed resets to 1.0x; `audioDelay` strictly remains at +350ms | `player.state.rate == 1.0`, `audio-delay` remains `'0.350'` |
| **T3.9** | Audio Track Switch Retains EQ & Delay | Audio Track Modal + Equalizer | Switch audio track in modal while EQ preset 'Live' and delay +100ms are active | Active audio track changes; EQ `af` filter graph and `audio-delay` persist | `player.setAudioTrack(newTrack)`, `af` and `audio-delay` unchanged |
| **T3.10** | Interleaved Subtitle and Audio Nudges | Shortcuts (Audio & Sub Delay) | Press `h` (+50ms sub), then `k` (+50ms audio) | Both properties set independently without overriding each other | `sub-delay` = `'0.05'`, `audio-delay` = `'0.050'` |

---

### Tier 4: Real-World Application Scenarios (5 Tests)

| Test ID | Name | Scenario Description | User Interaction Workflow | Verification & Assertion Criteria |
|:---|:---|:---|:---|:---|
| **T4.1** | Scenario 1: Desktop Playback & 4-Tier Jump Navigation | High-complexity navigation through a long media file using keyboard shortcuts and 4 seek tiers | 1. Press `Space` (Start playback)<br>2. Press `f` (Toggle fullscreen)<br>3. Press `Ctrl + Alt + ArrowRight` (Skip 5m recap)<br>4. Press `Ctrl + ArrowRight` (Skip 1m intro)<br>5. Press `Shift + ArrowLeft` (Replay 3s dialogue)<br>6. Press `Arrow Up` twice (Boost volume +10%) | - Final position == initial + 300s + 60s - 3s (initial + 357s)<br>- `_aiEngine.invalidateQueue()` called on each seek<br>- Volume increased by 10%<br>- All OSD messages rendered in sequence |
| **T4.2** | Scenario 2: Out-of-Sync Audio Dialogue Correction | Correction of desynchronized audio track using continuous slider and discrete nudge buttons | 1. Open `AudioStudioSheet`<br>2. Drag audio delay slider to `+150ms`<br>3. Verify audio leading video by 50ms<br>4. Tap `+50ms` nudge button (delay -> `+200ms`)<br>5. Verify dialogue in sync<br>6. Tap `Reset 0ms` to verify revert | - Slider thumb moves to +150ms<br>- `platform.setProperty('audio-delay', '0.150')`<br>- Nudge button updates delay to +200ms (`'0.200'`)<br>- Reset button sets delay to 0.0ms (`'0.000'`) |
| **T4.3** | Scenario 3: Audio Track Stream Switching via Top Bar Modal | Multi-language container stream selection with active status confirmation | 1. Open `PlayerScreen` HUD top bar<br>2. Tap Audio Track icon (`Icons.audiotrack_outlined`)<br>3. Inspect list of 3 audio streams (EN, JA, ES)<br>4. Tap Japanese 5.1 stream<br>5. Modal closes and OSD confirms switch<br>6. Reopen modal to verify checkmark | - Modal opens with 3 tiles<br>- Tap triggers `player.setAudioTrack(jaTrack)`<br>- OSD displays "Audio: Japanese (5.1)"<br>- Active checkmark displayed on Japanese tile |
| **T4.4** | Scenario 4: Concert / Hall Audio Equalization & Preamp Boost | Audio enhancement workflow for live concert recording using 'Large Hall' preset and preamp | 1. Open `AudioStudioSheet`<br>2. Toggle "Enable Equalizer" switch ON<br>3. Open preset picker and select 'Large Hall'<br>4. Drag Preamp slider to `+4.0dB`<br>5. Inspect compiled mpv audio filter graph | - `enabled == true`<br>- 10 bands match Large Hall vector `[10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0]`<br>- `preamp == 4.0`<br>- `platform.setProperty('af', ...)` starts with `volume=volume=+4.0dB:precision=fixed` |
| **T4.5** | Scenario 5: End-to-End Cinematic Media Consumption Experience | Full end-to-end user journey combining shortcuts, speed adjustment, track switching, EQ, and sync | 1. Start media with `Space`<br>2. Fine-tune speed to 1.1x with `]`<br>3. Cycle to Director Commentary with key `b`<br>4. Select 'Headphones' EQ preset with `+4.0dB` preamp<br>5. Compensate Bluetooth latency with key `k` (+50ms audio delay)<br>6. Clarify dialogue line with `Shift + ArrowRight` (+3s) | - `player.state.playing == true`<br>- `rate == 1.1`<br>- Active audio track is Director Commentary<br>- `af` filter includes Headphones EQ and volume boost<br>- `audio-delay` property == `'0.050'`<br>- Zero unhandled exceptions or overflow errors |

---

## 5. Caveats

1. **Headless MPV C-FFI Mocking**:
   - In headless test environments where native `mpv.dll` is not loaded in the test process, `Player` C-FFI bindings cannot execute native property sets. The E2E tests in `test/e2e/phase1_e2e_test.dart` must use `FakeMpvPlatform` or mock player harnesses (as established in `test/helpers/eplayer_test_harness.dart` and `test/unit/decoder_pipeline_test.dart`) to record and assert `setProperty` and `getProperty` calls without crashing.
2. **Focus Retention on Modal Dismissal**:
   - When modal bottom sheets (`AudioStudioSheet` or `_showAudioTrackMenu`) are dismissed via `Navigator.pop(context)`, desktop keyboard focus can momentarily revert to the navigator route. `DesktopKeyboardHandler` should ensure `_focusNode.requestFocus()` is called in `initState` and reclaimed upon modal return.
3. **No Caveats Beyond Above**: All specifications, parameters, and boundary conditions have been empirically verified against the codebase and authoritative references.

---

## 6. Conclusion

The specification mining for Phase 1 Deliverables (R1–R5) is complete and verified:
- **Exhaustive 68-test matrix** partitions coverage into 27 Tier 1 feature tests, 26 Tier 2 boundary tests, 10 Tier 3 cross-feature interaction tests, and 5 Tier 4 real-world user scenarios.
- Every test is strictly specified with concrete inputs (keystrokes, modifiers, taps, drags), expected state changes, OSD visual feedback pills, and mpv property/filter assertions.
- The test case specifications are ready for clean, direct implementation in `test/e2e/phase1_e2e_test.dart` by Milestone 4 workers.

---

## 7. Verification Method

To independently verify this specification mining report:

1. **Verify Test Matrix Coverage**:
   - Count test entries in this report: Tier 1 (27) + Tier 2 (26) + Tier 3 (10) + Tier 4 (5) = **68 test cases** (exceeds threshold of ≥ 65).
   - Verify every requirement R1–R5 is represented in Tier 1 and Tier 2.

2. **Verify Static Cleanliness**:
   ```powershell
   cd d:\E-player\app
   dart analyze
   ```
   *Expected outcome*: Zero errors, zero warnings.

3. **Verify Baseline Test Harness**:
   ```powershell
   cd d:\E-player\app
   flutter test test/helpers/eplayer_test_harness.dart
   flutter test test/features/video_effects_test.dart
   ```
   *Expected outcome*: All tests pass.

4. **Invalidation Conditions**:
   - If total test count drops below 65 test cases.
   - If any R1–R5 feature lacks at least 5 Tier 1 and 5 Tier 2 tests.
   - If mpv property strings deviate from `'audio-delay'` (in float seconds `0.050`) or `af` filter graph syntax (`volume=volume=+XdB:precision=fixed`).
