# E2E Test Infra: E-Player Phase 2

## Test Philosophy
- Opaque-box, requirement-driven, derived directly from `ORIGINAL_REQUEST.md` (Phase 2) and `docs/vlc_gap_analysis.md` (Section 5.3).
- No dependency on private implementation details.
- Uses `FakePlatformPlayer extends PlatformPlayer` and `FakePlayer extends Fake implements Player` pattern established in `test/e2e/phase1_e2e_test.dart` for deterministic, cross-platform headless execution without native DLL dependencies.

## Feature Inventory & Test Matrix
| # | Feature | Requirement | Tier 1 (Equivalence) | Tier 2 (Boundary & Corner) | Tier 3 (Cross-Feature) | Tier 4 (Real-World) |
|---|---------|-------------|:--------------------:|:--------------------------:|:----------------------:|:-------------------:|
| 1 | Volume Over-Amplification to 300% | R1 | >=5 | >=5 | Pairwise | Scenario |
| 2 | 3-Color Safety Indicator | R1 | >=5 | >=5 | Pairwise | Scenario |
| 3 | Frame-by-Frame Stepping ('e' & HUD) | R2 | >=5 | >=5 | Pairwise | Scenario |
| 4 | A-B Repeat Looping Controller | R3 | >=5 | >=5 | Pairwise | Scenario |
| 5 | Aspect Ratio Crop Cycling ('c') | R4 | >=5 | >=5 | Pairwise | Scenario |
| 6 | Network & Demuxer Caching Buffers | R5 | >=5 | >=5 | Pairwise | Scenario |

## Test Architecture
- Test Suite Location: `d:\E-player\app\test/e2e/phase2_e2e_test.dart`
- Test Runner: `flutter test test/e2e/phase2_e2e_test.dart`
- Expected: All tests pass with exit code 0.

## Tier Breakdown & Coverage Goals
- **Tier 1: Feature Coverage (>=5 per feature)**
  - T1.1: libmpv `volume-max` set to 300.0.
  - T1.2: Vertical swipe gesture scales volume across 0% to 300%.
  - T1.3: Arrow Up / Down keys step volume by 5% in 0% to 300% range.
  - T1.4: 3-color safety indicator returns Green (0–100%), Amber (101–200%), Soft Red (201–300%).
  - T1.5: Hotkey `e` triggers `frame-step`.
  - T1.6: HUD action button triggers `frame-step`.
  - T1.7: Frame stepping auto-pauses playback if currently playing.
  - T1.8: A-B loop 4-state cycle: Off -> Point A -> Point B & Loop -> Clear.
  - T1.9: A-B loop real-time position listener seeks back to Point A when Point B reached.
  - T1.10: Hotkey `c` cycles crop presets: 16:9, 16:10, 4:3, 1.85:1, 2.35:1, Reset.
  - T1.11: Settings UI network caching slider (500–10,000ms) mapped to `cache-secs`.
  - T1.12: Settings UI demuxer cache selector (16–128MB) mapped to `demuxer-max-bytes`.
- **Tier 2: Boundary & Corner Cases (>=5 per feature)**
  - T2.1: Volume clamp at 0.0% (cannot go negative on ArrowDown or downward swipe).
  - T2.2: Volume clamp at 300.0% (cannot exceed 300% on ArrowUp or upward swipe).
  - T2.3: Boundary threshold transitions: 100.0% (Green) vs 100.1% (Amber), 200.0% (Amber) vs 200.1% (Soft Red).
  - T2.4: Stepping frame when already paused stays paused and advances exactly 1 frame.
  - T2.5: Stepping frame at end-of-file handles EOF gracefully without crash.
  - T2.6: A-B loop Point B <= Point A rejection (Point B cannot be earlier than Point A).
  - T2.7: A-B loop anti-thrashing debounce: rapid consecutive ticks past Point B do not trigger multiple seek storms.
  - T2.8: Crop filter cycling wraps around cleanly from Reset back to 16:9.
  - T2.9: Network caching slider clamps at 500ms and 10,000ms boundaries.
  - T2.10: Demuxer cache handles rapid switching between 16MB and 128MB.
- **Tier 3: Cross-Feature Combinations (Pairwise Interaction)**
  - T3.1: Volume amplification (250% Soft Red) active while stepping frames with `e`.
  - T3.2: A-B repeat looping active during aspect ratio crop changes.
  - T3.3: Frame stepping during active A-B looping respects loop boundaries.
  - T3.4: Network caching and demuxer buffer adjustments applied dynamically to active playback.
  - T3.5: Keyboard shortcut `c` (crop) and `a` (aspect ratio) coexisting without filter collisions.
- **Tier 4: Real-World Application Scenarios**
  - T4.1: Dialog clarification workflow: quiet video boosted to 220% (Soft Red), A-B loop marked across dialogue scene, frame stepped to inspect lip sync.
  - T4.2: Sports replay analysis: 60fps video frame-stepped across goal line, looped across 3-second critical replay window.
  - T4.3: Cinema crop workflow: 2.35:1 anamorphic crop applied, volume adjusted via right-edge swipe, seeking through chapters.
  - T4.4: Weak network cellular streaming: network caching set to 8,000ms, demuxer buffer set to 128MB, smooth continuous playback.
