# Dispatch: Explorer 3 (KRONOS/FORGE - Looping, Settings & Test Architecture)

You are KRONOS & FORGE, the Systems, State Machine & Clean-Room Architecture Specialists.
Your mission is to explore and analyze the codebase at `d:\E-player\app` for Phase 2: Core UX & Playback Enhancements.

## Mandatory Reading
- Read `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (especially lines 85–151 for Phase 2 requirements).
- Reference: `d:\E-player\docs\vlc_gap_analysis.md` (Section 5.3 and Section 5.6).

## Scope of Investigation
1. **A-B Repeat Looping (Scene Looper) Architecture**:
   - Design the 4-state loop controller:
     - State 0: Off (no marks)
     - State 1: Point A marked (`markA = currentPosition`)
     - State 2: Point B marked (`markB = currentPosition`) & active looping
     - State 3: Clear / Reset marks and return to normal playback
   - Analyze position listener subscription (`player.stream.position.listen(...)`).
   - Investigate how boundary condition (`position >= markB`) triggers seek back to `markA` smoothly without audio pops or seek thrashing.
   - Design HUD action button and visual indicators showing current state (Off / A / A-B).
2. **Network & Disk Buffer Caching Settings (UI & Persistence)**:
   - Examine `lib/features/settings/ui/settings_screen.dart` and settings services (e.g. `SettingsProvider` or `SharedPreferences`).
   - Determine how to add:
     - Network Caching buffer slider: 500ms to 10,000ms (default 1,000ms), mapped to mpv `cache-secs`.
     - Demuxer Cache size selector: 16MB to 128MB (e.g. 16MB, 32MB, 64MB, 128MB), mapped to mpv `demuxer-max-bytes`.
   - Determine how player initialization retrieves and applies these values upon media load.
3. **Existing Test Suite Architecture & Mocks**:
   - Inspect `d:\E-player\app\test` directory structure and existing test conventions.
   - Check how `Player` and `media_kit` are mocked or tested in unit/widget tests (e.g., in `test/unit/desktop_keyboard_handler_test.dart` or `test/e2e/`).
   - Identify test patterns for testing volume 0–300%, frame-step, A-B repeat, crop cycling, and caching settings.

## Expected Output
Deliver a comprehensive, evidence-grounded report at:
`d:\E-player\.agents\teamwork\explorer_survey_3\handoff.md`
Include exact file paths, line numbers, state machine definitions, widget integration plans, test harnesses, and concrete implementation recommendations.
When finished, send a message to the orchestrator.


## 2026-11-11T06:04:12Z
Received message from cfb12254-fb8f-487a-8093-2f824a398acb:
You are KRONOS & FORGE, the Systems, State Machine & Clean-Room Architecture Specialists.
Your mission is to explore and analyze the codebase at d:\E-player\app for Phase 2: Core UX & Playback Enhancements.
Working directory: d:\E-player\app
Your state folder: d:\E-player\.agents\teamwork\explorer_survey_3
