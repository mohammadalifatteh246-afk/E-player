# Dispatch: Sub-Orchestrator Milestone 1 (Volume Amplification to 300% & 3-Color Safety Indicator)

You are the Sub-Orchestrator for Milestone 1 of the E-Player Phase 2 project.
Your parent is the top-level Project Orchestrator (conversation ID: cfb12254-fb8f-487a-8093-2f824a398acb).

Working directory: d:\E-player\app
State folder: d:\E-player\.agents\teamwork\sub_orch_m1

## Mandatory References
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (lines 85–151)
- `d:\E-player\PROJECT.md`
- `d:\E-player\docs\vlc_gap_analysis.md` (Section 5.3 and 5.6)
- Survey Reports:
  - `d:\E-player\.agents\teamwork\explorer_survey_1\handoff.md` (CYPHER: mpv property interop & volume-max)
  - `d:\E-player\.agents\teamwork\explorer_survey_2\handoff.md` (AURA: gesture physics, 3-color indicator, keyboard handler)
  - `d:\E-player\.agents\teamwork\explorer_survey_3\handoff.md` (KRONOS/FORGE: mock patterns & test harness)

## Milestone 1 Objectives
Implement Requirement R1:
1. **libmpv volume-max configuration**:
   Configure libmpv `volume-max` to `300.0` in `PlayerScreen` (`lib/features/player/ui/player_screen.dart`) immediately following `Player` initialization via `(player.platform as dynamic).setProperty('volume-max', '300.0')`.
2. **CinematicGestureEngine volume scaling**:
   In `lib/features/player/ui/cinematic_gesture_engine.dart`, extend the mobile right-edge vertical swipe gesture to scale smoothly across 0% to 300% volume using uniform extended gain ($K=150.0$), zero jump discontinuities, and boundary clamp $[0.0, 300.0]$ (update lines 179, 200, 406–423).
3. **DesktopKeyboardHandler volume shortcuts**:
   In `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`, update `Arrow Up` and `Arrow Down` shortcuts to adjust volume across 0% to 300% in 5% increments, passing dynamic safety color to OSD.
4. **3-Color Safety Indicator (HUD & OSD)**:
   Create / integrate `VolumeSafetyColors`:
   - 0% – 100%: Green (`#22C55E` / nominal unity gain)
   - 101% – 200%: Amber (`#F59E0B` / software pre-amp boost)
   - 201% – 300%: Soft Red (`#EF4444` / high over-amplification warning)
   Apply dynamically to gesture feedback card (`LinearProgressIndicator` normalized to 300%), OSD feedback pill overlay, and HUD volume slider.
5. **Quality & Test Standards**:
   Zero placeholders, zero TODOs.
   `dart analyze` passes with 0 errors and 0 warnings.
   Automated unit tests in `test/unit/` verifying volume scaling 0–300%, boundary clamping at 0% and 300%, 5% increments, and 3-color threshold transitions.

## Sub-Orchestrator Execution Procedure
1. Create `BRIEFING.md` and `progress.md` in your state folder.
2. Run the Iteration Loop (Direct 2B):
   a. Dispatch Worker (`teamwork_worker`) armed with survey findings to implement changes and unit tests.
      *MANDATORY INTEGRITY WARNING must be included in Worker prompt.*
   b. Dispatch 2 Reviewers (`teamwork_reviewer`) in parallel to review code, UX, and test results.
   c. Dispatch 2 Challengers (`teamwork_challenger`) in parallel to stress-test volume bounds, rapid gesture updates, and threshold edge cases.
   d. Dispatch Forensic Auditor (`teamwork_auditor`) to verify zero cheating, zero fake stubs.
   e. Gate evaluation: If all pass, mark Milestone 1 DONE.
3. Write `handoff.md` in `d:\E-player\.agents\teamwork\sub_orch_m1\handoff.md` and send completion message to parent orchestrator.
