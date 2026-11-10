# Scope: Milestone 2 — Equalizer Parity & Pre-Amplification (R5)

## Objective
Expand `AudioStudioSheet` and `AudioConfig` to achieve 100% equalizer parity with VLC: 11 missing presets with exact IEEE 754 decibel gains, global Pre-Amplification slider (-20dB to +20dB), and 10-band slider gain scale expansion to ±20dB.

## Exclusive Write Ownership
The worker for this milestone owns and may modify ONLY these files:
- `lib/features/player/ui/audio_studio_sheet.dart` (`AudioConfig` and `AudioStudioSheet`)
- `test/features/audio_studio_test.dart` (new unit test suite)

DO NOT modify `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` or `lib/features/player/ui/player_screen.dart` (owned by M1).

## Authoritative Inputs
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- `d:\E-player\PROJECT.md`
- Survey Handoff (Aura): `d:\E-player\.agents\teamwork\explorer_audio_studio\handoff.md`
- Specification Handoff (Cypher): `d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md`

## Specifications to Implement
1. **11 Target VLC Presets in `AudioConfig.presets`**:
   Bands: `[60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]`
   - `Full Bass`: `[-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]` (Preamp: `+5.0dB`)
   - `Full Bass & Treble`: `[7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]` (Preamp: `+4.0dB`)
   - `Full Treble`: `[-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]` (Preamp: `+3.0dB`)
   - `Headphones`: `[4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]` (Preamp: `+4.0dB`)
   - `Large Hall`: `[10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0]` (Preamp: `+5.0dB`)
   - `Live`: `[-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]` (Preamp: `+7.0dB`)
   - `Party`: `[7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2]` (Preamp: `+6.0dB`)
   - `Reggae`: `[0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0]` (Preamp: `+8.0dB`)
   - `Ska`: `[-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]` (Preamp: `+6.0dB`)
   - `Soft`: `[4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0]` (Preamp: `+5.0dB`)
   - `Soft Rock`: `[4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8]` (Preamp: `+7.0dB`)
2. **Global Pre-Amplification**:
   - Add `double preamp = 0.0;` to `AudioConfig`.
   - In `AudioConfig.apply(Player? player)`, prepend preamp filter:
     `if (preamp.abs() > 0.05) filters.add('volume=volume=${preamp >= 0 ? "+" : ""}${preamp.toStringAsFixed(1)}dB:precision=fixed');`
   - Render Preamp Gain slider (`-20.0dB` to `+20.0dB`, step 0.5dB) in `AudioStudioSheet` directly above the 10-band sliders.
3. **Gain Scale Expansion**:
   - Expand graphic equalizer vertical sliders to `min: -20.0, max: 20.0`.
4. **Automated Verification**:
   - Author `test/features/audio_studio_test.dart` verifying all 11 presets load correct band values, preamp updates correctly, and `apply` generates correct mpv `af` filter strings.
   - Run `flutter test test/features/audio_studio_test.dart` and `dart analyze`.

## Completion Criteria
- Static analysis (`dart analyze`) passes with 0 errors and 0 warnings.
- `flutter test test/features/audio_studio_test.dart` passes.
- Forensic Auditor reports CLEAN.


## Milestone Status: DONE
- **Date Completed**: 2026-11-10T10:25:00Z
- **Implementation Worker**: `worker_m2_r1_1` (`f0dc92de-4c18-49fd-a4ec-d7fefb30d101`)
- **Reviewers**: `reviewer_m2_r1_1` (APPROVE), `reviewer_m2_r1_2` (APPROVE)
- **Challengers**: `challenger_m2_r1_1` (CONFIRM_CORRECTNESS), `challenger_m2_r1_2` (CONFIRM_CORRECTNESS)
- **Forensic Auditor**: `auditor_m2_r1_1` (CLEAN)
- **Gate Result**: PASS
- **Outputs**:
  - `lib/features/player/ui/audio_studio_sheet.dart`: 20 presets in `AudioConfig`, `preamp` (-20dB..+20dB), `presetPreamps`, `buildMpvAfString()` with volume filter at index 0, `_buildPreampCard()`, ±20dB scale labels and slider range.
  - `test/features/audio_studio_test.dart`: 34 unit tests passed.
  - `test/features/audio_studio_empirical_stress_test.dart`: 16 empirical stress tests passed.
  - Static analysis: 0 errors, 0 warnings.
