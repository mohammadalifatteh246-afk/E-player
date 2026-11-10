# Milestone 2 Review & Adversarial Challenge Report: Equalizer Parity & Pre-Amplification (R5)

**Reviewer**: Reviewer 1 (`reviewer_m2_r1_1`)  
**Roles**: Reviewer (Quality & Architecture) & Adversarial Critic  
**Target Milestone**: Milestone 2: Equalizer Parity & Pre-Amplification (Requirement R5)  
**Codebase**: `d:\E-player\app`  
**Working Directory**: `d:\E-player\app`  
**State Folder**: `d:\E-player\.agents\teamwork\reviewer_m2_r1_1\`  
**Date & Timestamp**: 2026-11-10T10:15:00Z  
**Verdict**: **APPROVE**

---

## 1. Observation

### 1.1 Exclusive File Ownership Compliance
- Inspected git status and git diff.
- Worker 2 (`worker_m2_r1_1`) modified strictly the files within its assigned scope:
  - `app/lib/features/player/ui/audio_studio_sheet.dart`
  - `app/test/features/audio_studio_test.dart`
- Milestone 1 files (`desktop_keyboard_handler.dart` and `player_screen.dart`) were **NOT** touched or modified by Milestone 2 worker.

### 1.2 Verbatim Implementation Observations in `lib/features/player/ui/audio_studio_sheet.dart`
1. **AudioConfig State Expansion**:
   - Lines 8–9: `double preamp = 0.0;`
   - Lines 34–46: 11 VLC canonical presets in `AudioConfig.presets` (`Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`), bringing total presets to 20.
   - Lines 48–70: `static const Map<String, double> presetPreamps` registering all 20 presets with their canonical preamp defaults (`Full Bass`: 5.0, `Live`: 7.0, `Reggae`: 8.0, etc.).
   - Lines 72–78: `applyPreset(String name)` updates both `eq = List<double>.from(presets[name]!)` and `preamp = presetPreamps[name] ?? 0.0;`.
   - Lines 80–119: `buildMpvAfString()` synthesizes the mpv audio filter string:
     - Lines 85–89: Pre-amplification prepended at index 0 before EQ bands and DSP:
       ```dart
       if (preamp.abs() > 0.05) {
         final sign = preamp >= 0 ? '+' : '';
         filters.add('volume=volume=$sign${preamp.toStringAsFixed(1)}dB:precision=fixed');
       }
       ```
     - Lines 111–117: Loops over 10 equalizer bands, formatting `equalizer=f=${freqs[i]}:width_type=q:width=1.2:g=${eq[i].toStringAsFixed(1)}` for active bands (`|g| > 0.05`).
   - Lines 132–141: `apply(Player? player)` calls `platform.setProperty('af', buildMpvAfString())` with null/exception safety.
   - Lines 143–155: `reset(Player? player)` resets `preset = 'Flat'`, `eq = 10x 0.0`, `preamp = 0.0`, all boosts disabled, and clears filter graph.

2. **AudioStudioSheet UI Enhancements**:
   - Lines 423–424: `_buildPreampCard()` placed directly above the 10-band slider stack in `SingleChildScrollView`.
   - Lines 599–718: `_buildPreampCard()` implements:
     - `AnimatedOpacity` based on `_config.enabled`
     - Styled with `EDesign.surface`, `EDesign.border`, and `EDesign.primary`
     - Live pill badge displaying `${preampVal >= 0 ? "+" : ""}${preampVal.toStringAsFixed(1)} dB`
     - Instant reset `IconButton` resetting preamp to `0.0 dB` with disabled state when already 0.0 dB
     - Continuous horizontal slider covering `-20.0` to `+20.0` with 80 divisions (step `0.5 dB`)
     - Labeling: `-20dB` on left and `+20dB` on right
   - Lines 446–456, 486–496: Scale labels updated to `+20dB` (top) and `-20dB` (bottom).
   - Lines 759–762: Vertical sliders clamped to `min: -20.0, max: 20.0`.

### 1.3 Verbatim Verification Test & Static Analysis Results
1. **Audio Studio Test Suite (`test/features/audio_studio_test.dart`)**:
   - Command: `cd app; flutter test test/features/audio_studio_test.dart`
   - Result: **34 passed, 0 failed** in 21 seconds.
   - Verifies 6 comprehensive test groups: default state, 20 presets parity with VLC IEEE 754 values, preamp filter string formatting, headroom limits, player platform dispatch, and boundary scaling.
2. **Static Analysis (`dart analyze`)**:
   - Command: `cd app; dart analyze lib/features/player/ui/audio_studio_sheet.dart test/features/audio_studio_test.dart`
   - Result: **0 errors, 0 warnings** ("No issues found!").
3. **Regression Test 1 (`video_effects_test.dart`)**:
   - Command: `cd app; flutter test test/features/video_effects_test.dart`
   - Result: **11 passed, 0 failed**.
4. **Regression Test 2 (`decoder_pipeline_test.dart`)**:
   - Command: `cd app; flutter test test/unit/decoder_pipeline_test.dart`
   - Result: **21 passed, 0 failed**.

---

## 2. Logic Chain

1. **VLC Parity & Precision Verification (Observation 1.2 Item 1 -> Conclusion)**:
   - Comparing all 11 presets against `d:\E-player\.agents\teamwork\sub_orch_m2\SCOPE.md` and the mined disassembly from `libequalizer_plugin.dll`:
     - `Full Bass`: `[-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]`, Preamp `+5.0dB`
     - `Full Bass & Treble`: `[7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]`, Preamp `+4.0dB`
     - `Full Treble`: `[-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]`, Preamp `+3.0dB`
     - `Headphones`: `[4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]`, Preamp `+4.0dB`
     - `Large Hall`: `[10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0]`, Preamp `+5.0dB`
     - `Live`: `[-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]`, Preamp `+7.0dB`
     - `Party`: `[7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2]`, Preamp `+6.0dB`
     - `Reggae`: `[0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0]`, Preamp `+8.0dB`
     - `Ska`: `[-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]`, Preamp `+6.0dB`
     - `Soft`: `[4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0]`, Preamp `+5.0dB`
     - `Soft Rock`: `[4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8]`, Preamp `+7.0dB`
   - Every single band gain and preamp value is 100% bit-perfect with the authoritative specification.

2. **DSP Pipeline Order & Clipping Prevention (Observation 1.2 Item 1 -> Conclusion)**:
   - Pre-amplification scales the PCM audio signal before band equalization. Placing `volume=volume=+X.XdB:precision=fixed` at index 0 guarantees that attenuation prevents clipping from positive band gains, adhering to digital audio signal processing standards.
   - The threshold guard `preamp.abs() > 0.05` ensures that when preamp is at 0.0 dB (unity gain), no redundant volume filter node is instantiated, preserving bit-perfect pass-through.

3. **Slider Range Geometry & Midpoint Centering (Observation 1.2 Item 2 -> Conclusion)**:
   - Expanding vertical sliders to `min: -20.0, max: 20.0` matches VLC's 20dB range.
   - Because `(-20.0 + 20.0) / 2 = 0.0`, the midpoint corresponds exactly to 0.0 dB. The center 0dB horizontal datum line placed at 50% container height aligns perfectly with the slider thumb at 0.0 dB without layout distortion.

4. **Zero-Dependency Headless Architecture (Observation 1.3 Item 1 -> Conclusion)**:
   - `test/features/audio_studio_test.dart` uses `FakePlayer` and `FakePlayerPlatform` to intercept and test `af` property updates without invoking native `libmpv-2.dll`.
   - The suite runs completely headlessly on CI/CD in 21 seconds with zero external platform dependencies.

5. **Integrity & Anti-Cheat Audit (Observations 1.1, 1.2, 1.3 -> Conclusion)**:
   - No hardcoded test outputs or string constants were embedded into source code to satisfy tests.
   - Logic in `buildMpvAfString()` and UI slider interactions is dynamic, reactive, and robust.
   - All tests execute real assertions against model calculations and property dispatches.

---

## 3. Adversarial Challenges & Stress-Testing

### Challenge 1: Float Near-Zero and Sign Formatting Edge Cases
- **Attack Scenario**: Setting preamp to small non-zero values such as `+0.04`, `-0.04`, `-0.0`, or `-0.1`. Could this generate invalid mpv filter strings like `volume=volume=+-0.0dB` or unintended attenuation?
- **Stress-Test Analysis**:
  - `preamp.abs() > 0.05` filters out any micro-jitter `|x| <= 0.05`, meaning `-0.0` or `0.04` produces no volume filter.
  - When `preamp = -0.1`, `sign` evaluates to `''` because `preamp < 0`, and `preamp.toStringAsFixed(1)` produces `"-0.1"`, yielding `volume=volume=-0.1dB:precision=fixed`.
  - When `preamp = +0.1`, `sign` evaluates to `'+'`, yielding `volume=volume=+0.1dB:precision=fixed`.
- **Verdict**: PASS.

### Challenge 2: Headroom Attenuation Under Extreme EQ Peaks
- **Attack Scenario**: Applying `Full Treble` (+16.8 dB on 16kHz) with positive preamp. Could digital clipping occur?
- **Stress-Test Analysis**:
  - VLC's canonical preamp for `Full Treble` is `+3.0 dB`. In low-gain audio sources this lifts clarity, but in high-amplitude sources the user can adjust the preamp slider down to `-20.0 dB`.
  - Because `volume=volume=...` is applied at index 0 before `equalizer=...`, attenuating the master signal in mpv provides 20 dB of headroom prior to band amplification.
- **Verdict**: PASS.

### Challenge 3: Preset Selector Modal Dynamic Population
- **Attack Scenario**: The modal bottom sheet in `_showPresetPicker()` renders buttons using `AudioConfig.presets.keys.map(...)`. Does expanding presets from 9 to 20 overflow or cause rendering exceptions?
- **Stress-Test Analysis**:
  - `_showPresetPicker()` uses `Wrap(spacing: 10, runSpacing: 10, children: ...)` inside a scrollable modal container with fixed padding.
  - All 20 preset pills wrap cleanly into rows without horizontal overflow or pixel clipping.
- **Verdict**: PASS.

### Challenge 4: Platform Dispatch Resilience
- **Attack Scenario**: Calling `apply(null)` or invoking `apply()` when the native player backend throws an asynchronous exception.
- **Stress-Test Analysis**:
  - `if (player == null) return;` safely aborts with no-op.
  - `try { platform.setProperty('af', ...); } catch (e) { debugPrint(...); }` catches simulated platform failures without crashing the Flutter UI thread. Tested and verified in Group 5.
- **Verdict**: PASS.

---

## 4. Caveats

- **Milestone 3 Audio Delay Coexistence**: During testing, it was observed that Milestone 3 (Audio Delay Synchronization Slider) also touches `audio_studio_sheet.dart` to add `applyAudioDelay`. Milestone 2's implementation of `apply()`, `reset()`, and `AudioConfig` cleanly accommodated `applyAudioDelay` without regression or API signature divergence.

---

## 5. Conclusion

Milestone 2 (Equalizer Parity & Pre-Amplification - Requirement R5) meets all architectural, functional, performance, and forensic requirements:
- All 11 VLC presets are present with exact IEEE 754 single-precision float gains and canonical preamp defaults (20 presets total).
- Global Pre-Amplification slider is fully integrated in `AudioStudioSheet` (-20dB to +20dB with 0.5dB step, live badge, and reset button).
- 10-band slider gain scale is expanded to `[-20.0, 20.0]` with +20dB/-20dB labels and perfect center datum alignment.
- Zero-dependency headless test suite (`audio_studio_test.dart`) passes 34/34 tests.
- Static analysis is 100% clean (0 errors, 0 warnings).
- Regression test suites pass with zero regressions.
- Exclusive file ownership was strictly preserved.

**Definitive Verdict**: **APPROVE**

---

## 6. Verification Method

To independently reproduce this verification:

```powershell
# In d:\E-player\app:

# 1. Run Audio Studio test suite
cd d:\E-player\app
flutter test test/features/audio_studio_test.dart

# 2. Run static analysis on M2 modified files
dart analyze lib/features/player/ui/audio_studio_sheet.dart test/features/audio_studio_test.dart

# 3. Run regression suites
flutter test test/features/video_effects_test.dart
flutter test test/unit/decoder_pipeline_test.dart
```

### Invalidation Conditions
- Any band in the 11 VLC presets deviates from the verified IEEE 754 floats in `SCOPE.md`.
- `buildMpvAfString()` places the `volume` filter after equalizer bands or includes it when `preamp == 0.0`.
- The 10-band equalizer sliders clamp values to `[-12.0, 12.0]` rather than `[-20.0, 20.0]`.
- Static analysis emits any error or warning.
