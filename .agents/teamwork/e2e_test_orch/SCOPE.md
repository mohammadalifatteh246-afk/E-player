# Scope: Milestone 4 — Opaque-Box E2E Test Suite (Dual Track)

## Objective
Author the comprehensive opaque-box E2E test suite for Phase 1 Deliverables covering requirements R1–R5, and publish `TEST_READY.md`.

## Exclusive Write Ownership
The worker for this milestone owns and may modify ONLY these files:
- `test/e2e/phase1_e2e_test.dart`
- `TEST_READY.md` (at project root)

DO NOT modify implementation files in `lib/`.

## Authoritative Inputs
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- `d:\E-player\PROJECT.md`
- `d:\E-player\TEST_INFRA.md`
- Survey Handoffs:
  - `d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md`
  - `d:\E-player\.agents\teamwork\explorer_shortcuts_player\handoff.md`
  - `d:\E-player\.agents\teamwork\explorer_audio_studio\handoff.md`

## Specifications to Implement
1. **Tier 1 - Feature Coverage (≥5 per feature, ≥25 tests)**:
   - Shortcuts: Space (play/pause), f (fullscreen), m (mute), b (audio cycle), v (subtitle cycle), a (aspect ratio), h/g (sub delay), k/j (audio delay), +/-/]/[/= (speed), Arrow Up/Down (volume).
   - 4-Tier Jump Physics: Shift+Left/Right (3s), Alt+Left/Right (10s), Ctrl+Left/Right (60s), Ctrl+Alt+Left/Right (300s).
   - Audio Delay Slider: -10s to +10s range, 50ms steps, 5 nudge buttons (-100ms, -50ms, Reset, +50ms, +100ms).
   - Dedicated Track Modal: HUD icon presence, modal open, stream listing, selection, checkmark.
   - Equalizer Parity: 11 presets (Full Bass, Full Bass & Treble, Full Treble, Headphones, Large Hall, Live, Party, Reggae, Ska, Soft, Soft Rock), preamp slider (-20dB to +20dB).
2. **Tier 2 - Boundary & Corner Cases (≥5 per feature, ≥25 tests)**:
   - Position clamping at 0 and duration.
   - Audio delay clamping at -10000ms and +10000ms.
   - Preamp clamping at -20dB and +20dB.
   - Empty audio tracks list gracefully handled.
   - Rapid sequential nudge presses.
3. **Tier 3 - Cross-Feature Combinations (≥10 tests)**:
   - Hotkey 'b' cycling audio tracks while modal is open or closed.
   - Delay nudge while playing at 2.0x speed.
   - Equalizer preset change combined with preamp boost.
   - 4-tier jump during active volume adjustment.
4. **Tier 4 - Real-World Application Scenarios (≥5 tests)**:
   - Scenario 1: Desktop Playback & 4-Tier Jump Navigation.
   - Scenario 2: Out-of-Sync Audio Dialogue Correction Workflow.
   - Scenario 3: Audio Track Stream Switching via Top Bar Modal.
   - Scenario 4: Concert / Hall Audio Equalization & Preamp Boost.
   - Scenario 5: End-to-End Cinematic Media Consumption Experience.
5. **Publish TEST_READY.md**:
   Publish `TEST_READY.md` containing test runner command, coverage table, and feature checklist.

## Completion Criteria
- Test file `test/e2e/phase1_e2e_test.dart` cleanly authored with zero compile errors and zero static analysis warnings.
- `TEST_READY.md` published at project root.
