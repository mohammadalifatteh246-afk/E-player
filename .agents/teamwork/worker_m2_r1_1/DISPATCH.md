## 2026-11-10T08:57:56Z

You are Worker 1 for Milestone 2: Equalizer Parity & Pre-Amplification.
Working directory: d:\E-player\app
Your state folder: d:\E-player\.agents\teamwork\worker_m2_r1_1\

Read authoritative documents:
- ORIGINAL_REQUEST: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
- PROJECT.md: d:\E-player\PROJECT.md
- SCOPE.md: d:\E-player\.agents\teamwork\sub_orch_m2\SCOPE.md
- Explorer 1 (UI/State) handoff: d:\E-player\.agents\teamwork\explorer_m2_r1_1\handoff.md
- Explorer 2 (Test Design) handoff: d:\E-player\.agents\teamwork\explorer_m2_r1_2\handoff.md
- Spec Miner 3 (Preset Vectors & mpv filter spec) handoff: d:\E-player\.agents\teamwork\explorer_m2_r1_3\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

EXCLUSIVE FILE OWNERSHIP:
You own and may modify ONLY these two files:
- d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart
- d:\E-player\app\test\features\audio_studio_test.dart
DO NOT modify d:\E-player\app\lib\features\player\ui\widgets\desktop_keyboard_handler.dart or d:\E-player\app\lib\features\player\ui\player_screen.dart under any circumstances!

Tasks to implement:
1. In `lib/features/player/ui/audio_studio_sheet.dart` (`AudioConfig`):
   - Add `double preamp = 0.0;`
   - Add the 11 VLC presets to `static const Map<String, List<double>> presets` (total 20 presets) using the exact verified IEEE 754 float values from `SCOPE.md` / `explorer_m2_r1_3/handoff.md` (Full Bass 60Hz is -8.0dB; Live bands are [-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]).
   - Add `static const Map<String, double> presetPreamps` mapping all 20 presets to their default preamp gains.
   - Extract and implement `String buildMpvAfString()`:
     - Preamp volume filter MUST be prepended at index 0 before equalizer bands.
     - Syntax: `if (preamp.abs() > 0.05) filters.add('volume=volume=${preamp >= 0 ? "+" : ""}${preamp.toStringAsFixed(1)}dB:precision=fixed');`
     - Retain bass, dynaudnorm, extrastereo, stereowiden, and 10 equalizer bands (`equalizer=f=...:width_type=q:width=1.2:g=...`).
   - Update `apply(Player? player)` to set `platform.setProperty('af', buildMpvAfString())`.
   - Update `applyPreset(String name)` to set `preset = name`, `eq = List<double>.from(presets[name]!)`, and `preamp = presetPreamps[name] ?? 0.0`.
   - Update `reset(Player? player)` to reset `preset = 'Flat'`, `eq = List<double>.filled(10, 0.0)`, `preamp = 0.0`, all boost flags to false, and clear `af`.

2. In `lib/features/player/ui/audio_studio_sheet.dart` (`AudioStudioSheet` UI):
   - Build and render `_buildPreampCard()` directly above the 10-band slider stack in `SingleChildScrollView`.
   - Style with `EDesign.surface`, `EDesign.border`, and `EDesign.primary`. Wrap in `AnimatedOpacity(opacity: _config.enabled ? 1.0 : 0.4)`.
   - Slider range: `-20.0` to `+20.0`, 80 divisions (step `0.5dB`), live dB badge `${_config.preamp >= 0 ? "+" : ""}${_config.preamp.toStringAsFixed(1)} dB`, and dedicated reset button to `0.0dB`.
   - In `_build10BandSlider(int index)`, expand vertical slider to `min: -20.0, max: 20.0, value: value.clamp(-20.0, 20.0)`.
   - Update top and bottom scale labels from `±12dB` to `+20dB` and `-20dB`.

3. Author `test/features/audio_studio_test.dart`:
   - Implement the zero-dependency mock architecture (`FakePlayerPlatform` and `FakePlayer extends Fake implements Player`) and the 6 test groups designed in `explorer_m2_r1_2/handoff.md`:
     - Group 1: AudioConfig Default State & Presets Registry (20 presets, 10 bands each, default Rock, unknown preset safe no-op)
     - Group 2: 20 Presets Parity & Preamp Verification (asserting all 11 VLC presets and 9 baseline presets)
     - Group 3: Pre-Amplification Filter String Generation (positive, negative, zero omission, deadzone <= 0.05, prepended before EQ bands, extreme ±20dB)
     - Group 4: Equalizer Band Gain Scale & Filter Synthesis (active bands, ±20dB headroom limits, neutral band omission, reset)
     - Group 5: Player Platform Dispatch & Mock Verification (setProperty 'af', empty af when disabled, apply(null) safe no-op, platform error handling)
     - Group 6: Boundary & Scale Tests

4. Verify your work:
   - Run `flutter test test/features/audio_studio_test.dart`
   - Run `dart analyze` (must be 0 errors, 0 warnings)
   - Run existing regression tests: `flutter test test/features/video_effects_test.dart` and `flutter test test/unit/decoder_pipeline_test.dart`

5. Write a complete handoff report to `d:\E-player\.agents\teamwork\worker_m2_r1_1\handoff.md` with:
   - Changes implemented
   - Exact build/test output commands and logs
   - Static analysis output
   - Code layout compliance check
When finished, notify the orchestrator with send_message.


## 2026-11-10T09:13:02Z
**Context**: Milestone 2 Implementation Status Check
**Content**: Please report your current progress. Have you completed editing `audio_studio_sheet.dart` and `audio_studio_test.dart`? Are tests passing?
**Action**: Provide status and complete your handoff.md report.
