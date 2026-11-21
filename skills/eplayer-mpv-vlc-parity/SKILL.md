---
name: eplayer-mpv-vlc-parity
description: "Control libmpv properties, filter graphs, and audio/video playback parity features via media_kit."
version: "1.0.0"
author: "Hermes Agent"
license: "MIT"
platforms: ["windows", "linux", "macos"]
metadata:
  hermes:
    tags: ["eplayer", "mpv", "vlc-parity", "media-kit", "filter-graphs", "playback-core"]
---

# E-Player libmpv Core Control & VLC Parity Engine

## When to Use
- Interfacing with libmpv low-level properties and commands through `media_kit` native controller channels.
- Calibrating volume over-amplification up to $300\%$ with software pre-amplification and soft-clipping safety guards.
- Implementing or debugging single-frame precision stepping (`e` key) with automatic playback pause gating.
- Operating the 4-state A-B repeat scene looper (`ABRepeatController`) and real-time position boundary listeners.
- Configuring video aspect ratio crop cycling (`c` key) via mpv `vf` filter strings without aspect distortion.
- Tuning network buffer caching (`cache-secs`) and demuxer memory limits (`demuxer-max-bytes`).
- Calibrating audio delay synchronization (`audio-delay`) and 10-band graphic equalizer curves with preamp gain.

## Quick Reference Table

| Target / Subsystem | mpv Property / Filter Command | Action / Expected Outcome |
| :--- | :--- | :--- |
| Volume Amplification | `volume-max: 300.0`, `volume` | Extends volume headroom to $300\%$ with 3-tier safety coloring |
| Frame Stepping | `frame-step` command | Advances exactly 1 video frame; auto-pauses playback if active |
| A-B Repeat Looper | `ABRepeatController` position loop | Cycles: Off $\rightarrow$ Mark A $\rightarrow$ Mark B & Loop $\rightarrow$ Clear |
| Aspect Crop Cycling | `vf` crop filter: `crop=w:h:x:y` | Cycles: `16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `Reset` |
| Network Buffer Cache | `cache-secs: 0.5..10.0` | Prevents underruns on unstable networks (default $1.0\text{s}$) |
| Demuxer Memory Cache| `demuxer-max-bytes: 16MB..128MB` | Sets memory buffer ceiling for high-bitrate $4\text{K}/8\text{K}$ streams |
| Audio Delay Sync | `audio-delay: -10.0..+10.0` | Real-time audio track time-alignment in $50\text{ms}$ increments |
| 10-Band EQ & Preamp | `af` equalizer / volume filter | 20 presets (11 canonical VLC) + $-20\text{dB}..+20\text{dB}$ preamp gain |

## Core Subsystems & Technical Specifications

### 1. Volume Over-Amplification & Safety Dynamics
In standard multimedia pipelines, volume is capped at $100\%$ (unity gain, $0\text{dB}$). E-Player achieves VLC parity by extending playback volume to $300\%$ ($+9.54\text{dB}$ gain):
- **Configuration**:
  ```dart
  await (player.platform as dynamic).setProperty('volume-max', '300.0');
  ```
- **Soft-Clipping DSP Protection**: At levels above $100\%$, aggressive digital clipping is mitigated via soft-saturation curves to preserve dynamic range and prevent acoustic distortion.
- **3-Color Safety Indication**:
  - `0%` to `100%`: Standard Unity Gain — **Green** (`#22C55E`, safe for continuous listening).
  - `101%` to `200%`: Software Preamp Boost — **Amber** (`#F59E0B`, moderate boost for quiet audio tracks).
  - `201%` to `300%`: High Over-Amplification — **Soft Red** (`#EF4444`, maximum boost warning for potential clipping).

### 2. Single-Frame Stepping Architecture
Precision frame stepping allows forensic video inspection and frame-accurate analysis:
- **Low-Level Command**: Sent via libmpv IPC: `frame-step`.
- **Auto-Pause Gating Logic**:
  ```dart
  if (player.state.playing) {
    await player.pause();
  }
  await (player.platform as dynamic).command(['frame-step']);
  ```
- **HUD & Keyboard Parity**: Activated via `LogicalKeyboardKey.keyE` or the dedicated frame-step action icon on the HUD bottom toolbar.
- **OSD Dispatch**: Emits "Frame Step" feedback pill with active frame timestamp.

### 3. 4-State A-B Repeat Looper (`ABRepeatController`)
The A-B repeat looper allows users to continuously loop an arbitrary video segment:
- **State Machine**:
  - **State 0 (`ABRepeatState.off`)**: Normal playback. No loop boundaries active.
  - **State 1 (`ABRepeatState.pointA`)**: Point A timestamp recorded ($T_A$). OSD displays "Point A: mm:ss".
  - **State 2 (`ABRepeatState.looping`)**: Point B timestamp recorded ($T_B$). Looping begins immediately between $T_A$ and $T_B$. OSD displays "Looping: mm:ss - mm:ss".
  - **State 3 (`ABRepeatState.clear`)**: Loop boundaries wiped. Controller resets to State 0.
- **Position Listener & Anti-Thrashing Guard**:
  ```dart
  void onPositionChanged(Duration position) {
    if (state == ABRepeatState.looping && pointA != null && pointB != null) {
      if (position >= pointB! || position < pointA!) {
        // Enforce 150ms debounce guard to prevent seek oscillation
        final now = DateTime.now();
        if (now.difference(_lastSeekTime).inMilliseconds > 150) {
          _lastSeekTime = now;
          player.seek(pointA!);
        }
      }
    }
  }
  ```
- **Boundary Validation**: $T_B$ must be strictly greater than $T_A + 500\text{ms}$. If user marks Point B earlier than Point A, Point A is updated to the earlier timestamp.

### 4. Non-Distorted Aspect Ratio Crop Cycling
VLC provides non-distorted cropping that trims outer borders rather than stretching pixels:
- **mpv Video Filter (`vf`) Pipeline**:
  Crop filters are dynamically computed based on source video dimensions ($W_s, H_s$):
  - **`16:9`**: `crop=w=min(iw\,ih*16/9):h=min(ih\,iw*9/16):x=(iw-ow)/2:y=(ih-oh)/2`
  - **`16:10`**: `crop=w=min(iw\,ih*16/10):h=min(ih\,iw*10/16):x=(iw-ow)/2:y=(ih-oh)/2`
  - **`4:3`**: `crop=w=min(iw\,ih*4/3):h=min(ih\,iw*3/4):x=(iw-ow)/2:y=(ih-oh)/2`
  - **`1.85:1`**: `crop=w=min(iw\,ih*1.85):h=min(ih\,iw/1.85):x=(iw-ow)/2:y=(ih-oh)/2`
  - **`2.35:1` (Cinemascope)**: `crop=w=min(iw\,ih*2.35):h=min(ih\,iw/2.35):x=(iw-ow)/2:y=(ih-oh)/2`
  - **`Reset`**: Removes all crop filters (`vf=""`), restoring original source framing.
- **Cycle Order**: Triggered via `c` key or HUD crop selector:
  `Reset` $\rightarrow$ `16:9` $\rightarrow$ `16:10` $\rightarrow$ `4:3` $\rightarrow$ `1.85:1` $\rightarrow$ `2.35:1` $\rightarrow$ `Reset`.

### 5. Network Caching & Demuxer Memory Buffering
Smooth playback over high-latency networks (SMB, NFS, HTTP, HLS) requires configurable cache headroom:
- **Network Caching (`cache-secs`)**:
  - Slider range: $500\text{ms}$ ($0.5\text{s}$) to $10,000\text{ms}$ ($10.0\text{s}$). Default: $1,000\text{ms}$ ($1.0\text{s}$).
  - Controls how many seconds of media are buffered ahead of current playback position.
- **Demuxer Cache Size (`demuxer-max-bytes`)**:
  - Selector tiers: $16\text{MB}$, $32\text{MB}$, $64\text{MB}$, $128\text{MB}$. Default: $32\text{MB}$ ($64\text{MB}$ for $4\text{K}$).
  - Bound via `(player.platform as dynamic).setProperty('demuxer-max-bytes', bytes.toString())`.

### 6. Audio Delay & 10-Band Graphic Equalizer Parity
- **Audio Delay Synchronization**:
  - Bounds: $-10.0\text{s}$ (audio leads video) to $+10.0\text{s}$ (audio lags video).
  - Fine adjustment step: $50\text{ms}$ nudges via `k` (advance $+50\text{ms}$) and `j` (delay $-50\text{ms}$).
  - Bound property: `audio-delay` in seconds (e.g. `0.05` for $+50\text{ms}$).
- **10-Band Equalizer & Preamp**:
  - Frequency Bands: $31.25\text{Hz}$, $62.5\text{Hz}$, $125\text{Hz}$, $250\text{Hz}$, $500\text{Hz}$, $1\text{kHz}$, $2\text{kHz}$, $4\text{kHz}$, $8\text{kHz}$, $16\text{kHz}$.
  - Gain range: $-20.0\text{dB}$ to $+20.0\text{dB}$ per band.
  - Global Pre-Amplification slider: $-20.0\text{dB}$ to $+20.0\text{dB}$ master trim to prevent digital clipping when applying positive band boosts.
  - 11 VLC Canonical Presets: `Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`.
  - Additional Modern Presets: `Acoustic`, `Classical`, `Club`, `Dance`, `Electronic`, `Pop`, `R&B`, `Rock`, `Vocal`.

## Operational Workflows

### Workflow 1: Brainstorming Pre-Flight Gate for libmpv Properties & Filters
Whenever configuring new mpv properties, commands, or audio/video filter graphs:

1. **Intent Discovery ("Look Before You Ask")**:
   - Inspect existing property bindings in `lib/features/player/ui/playback_enhancements.dart` and `audio_studio_sheet.dart`.
   - Confirm whether the property requires asynchronous IPC messaging or synchronous state persistence.
2. **Explore 2–3 Architectural Approaches with Tradeoffs**:
   - *Example: Aspect Ratio Cropping Mechanism*:
     - *Approach A (Flutter Widget Clipping)*: Wrap `Video` widget in `FittedBox` or `ClipRect`. Fast to code, but causes letterbox artifacts, breaks hardware overlay scaling, and wastes GPU memory decoding cropped pixels.
     - *Approach B (mpv `vf` crop Filter)*: Apply dynamic FFmpeg crop syntax (`crop=w:h:x:y`) directly to the decode pipeline. Native performance, zero distortion, zero wasted VRAM, and identical to VLC C architecture.
     - *Approach C (mpv `video-aspect-override` property)*: Modifies aspect ratio directly without cropping. Stretches and distorts geometry.
   - *Recommendation*: Approach B delivers true VLC parity and zero visual distortion.
3. **Structured Design Documentation**:
   - Record filter syntax, property keys, listener lifecycles, and test coverage plans.
4. **Builder Check & Self-Review**:
   - Verify error handling when mpv filter strings are rejected or media files lack video streams (audio-only).
5. **Hard Gate**:
   - Do NOT execute code edits until the design rationale and filter strings are validated.

### Workflow 2: Configuring Volume Over-Amplification to 300% & Soft-Clipping
1. During `PlayerScreen` initialization:
   ```dart
   final platform = player.platform as dynamic;
   await platform.setProperty('volume-max', '300.0');
   ```
2. In volume adjustment routines (`DesktopKeyboardHandler`, `CinematicGestureEngine`):
   ```dart
   double targetVolume = (currentVolume + delta).clamp(0.0, 300.0);
   await player.setVolume(targetVolume);
   ```
3. Update HUD and OSD indicators with the appropriate color from `VolumeSafetyColors`:
   ```dart
   final color = VolumeSafetyColors.getColorForVolume(targetVolume);
   ```
4. Run automated volume tests:
   ```bash
   flutter test test/unit/phase2_unit_test.dart --plain-name "Volume over-amplification"
   ```

### Workflow 3: Wiring Frame-by-Frame Stepping with Auto-Pause Guard
1. In `PlaybackEnhancements`:
   ```dart
   static Future<void> stepFrame(Player player) async {
     if (player.state.playing) {
       await player.pause();
     }
     await (player.platform as dynamic).command(['frame-step']);
   }
   ```
2. Bind to desktop key `'e'` in `DesktopKeyboardHandler`:
   ```dart
   if (event.logicalKey == LogicalKeyboardKey.keyE) {
     await PlaybackEnhancements.stepFrame(player);
     showOsd('Frame Step: ${formatDuration(player.state.position)}');
     return KeyEventResult.handled;
   }
   ```
3. Verify frame stepping test passes:
   ```bash
   flutter test test/unit/phase2_unit_test.dart --plain-name "Frame-by-frame stepping"
   ```

### Workflow 4: Implementing 4-State A-B Repeat Looping with Anti-Thrashing Guard
1. Initialize `ABRepeatController(player: player)`.
2. Connect controller state transition to the loop button:
   ```dart
   controller.toggleNextState(); // Off -> PointA -> Looping -> Clear
   ```
3. Wire player position listener to `controller.onPositionChanged(position)`:
   - Ensure the 150ms debounce guard prevents infinite seek loops near Point B.
4. Verify A-B loop test passes:
   ```bash
   flutter test test/unit/phase2_unit_test.dart --plain-name "A-B Repeat Looping"
   ```

### Workflow 5: Managing Aspect Ratio Crop Cycling via mpv `vf` Filters
1. In `AspectCropController`, maintain an enumerated list of presets:
   `[AspectCrop.reset, AspectCrop.ratio16_9, AspectCrop.ratio16_10, AspectCrop.ratio4_3, AspectCrop.ratio1_85, AspectCrop.ratio2_35]`.
2. On cycle trigger (`c` key or HUD tap):
   ```dart
   final nextCrop = controller.cycleNext();
   final filterString = nextCrop.toMpvFilter();
   await (player.platform as dynamic).setProperty('vf', filterString);
   ```
3. Verify aspect crop tests pass:
   ```bash
   flutter test test/unit/phase2_unit_test.dart --plain-name "Aspect ratio crop cycling"
   ```

## Common Mistakes & Prohibitions
- **Prohibited: Setting `volume` without `volume-max: 300.0`**: If `volume-max` is not explicitly set, libmpv clamps volume silently to $100.0$, causing volume boosts above $100\%$ to fail silently.
- **Prohibited: Missing Seek Debounce in A-B Looper**: Calling `player.seek(pointA)` on every single position frame at Point B causes an audio/video decode deadlock. Always enforce a minimum $150\text{ms}$ debounce guard.
- **Prohibited: Frame-Stepping while Actively Playing**: Sending `frame-step` without first pausing causes jerky playback glitches. Always pause before stepping.
- **Prohibited: Unescaped Commas in mpv Filter Strings**: Commas separate filter nodes in FFmpeg filter graphs. Parameter commas inside expressions must be escaped with `\,` (e.g., `crop=w=min(iw\,ih*16/9)`).
