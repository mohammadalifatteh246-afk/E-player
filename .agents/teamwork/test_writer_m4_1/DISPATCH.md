## 2026-11-11T06:26:49Z
The Data Agent Kit plugin needs to be configured.
Do this right away as critical functionality will either be missing or not work correctly if the plugin is not configured.
The following is a <SYSTEM_MESSAGE> not actually sent by the user. It is provided by the system as important information to pay attention to.

<SYSTEM_MESSAGE>
[Message] timestamp=2026-11-11T06:26:49Z sender=8aa2ab80-d824-4917-a9ed-90f211789bd2 priority=MESSAGE_PRIORITY_HIGH content=You are test_writer_1 for Milestone 4 (Phase 2 E2E Test Suite) of the E-Player project.
Working directory: d:\E-player\app
State folder: d:\E-player\.agents\teamwork\test_writer_m4_1

MANDATORY FIRST STEPS:
1. Read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md (lines 85–151).
2. Read d:\E-player\PROJECT.md.
3. Read d:\E-player\TEST_INFRA.md.
4. Read d:\E-player\app\test\e2e\phase1_e2e_test.dart (specifically examine Section 1 FakePlatformPlayer and headless mock harness pattern).
5. Read d:\E-player\.agents\teamwork\explorer_survey_3\handoff.md.

YOUR ASSIGNMENT:
Author the complete, comprehensive, 4-tier opaque-box E2E test suite in `d:\E-player\app\test\e2e\phase2_e2e_test.dart`.

EXCLUSIVE WRITE OWNERSHIP:
You own `d:\E-player\app\test\e2e\phase2_e2e_test.dart`. Do NOT modify any other production files.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

TEST SUITE REQUIREMENTS (from TEST_INFRA.md):
1. Headless Architecture:
   - Replicate the FakePlatformPlayer / FakePlayer mock harness pattern from phase1_e2e_test.dart so all tests run completely deterministically without requiring native libmpv.dll / C-FFI runtime binaries.
   - Include mock support for:
     * mpv property store (`volume-max`, `volume`, `cache-secs`, `demuxer-max-bytes`, `demuxer-max-back-bytes`, `vf`)
     * mpv commands (`frame-step`)
     * position streams, playing streams, volume streams
     * SharedPreferences initial mock values for `networkCachingMs` and `demuxerCacheMb`
     * VolumeSafetyColors logic verification (Green 0-100%, Amber 101-200%, Soft Red 201-300%)
     * ABRepeatController 4-state state transitions (Off, Point A, Looping, Clear) and real-time seek back logic
2. Strict Test Count Thresholds (at least 71 tests total):
   - Tier 1: Feature Coverage (>=5 test cases per feature across all 6 features -> at least 30 tests):
     * T1.1: libmpv volume-max set to 300.0 (5 tests covering init, setProperty, persistence, default)
     * T1.2: Volume scaling 0% to 300% via swipe physics & keyboard step (5 tests)
     * T1.3: 3-color safety indicator (Green, Amber, Soft Red) (5 tests)
     * T1.4: Frame stepping on 'e' key and HUD button (5 tests)
     * T1.5: Frame stepping auto-pause behavior (5 tests)
     * T1.6: A-B repeat loop 4-state transitions & real-time seek back (5 tests)
     * T1.7: Aspect ratio crop cycling ('c' key and mpv crop presets: 16:9, 16:10, 4:3, 1.85:1, 2.35:1, Reset) (5 tests)
     * T1.8: Network caching buffer slider (500-10000ms -> cache-secs) and demuxer cache selector (16-128MB -> demuxer-max-bytes) (5 tests)
   - Tier 2: Boundary & Corner Cases (>=5 test cases per feature -> at least 30 tests):
     * T2.1: Volume clamp at 0.0% and 300.0% extremes (5 tests)
     * T2.2: Color transition boundaries: 100.0% (Green) vs 100.1% (Amber), 200.0% (Amber) vs 200.1% (Soft Red) (5 tests)
     * T2.3: Frame step when already paused, and frame step at EOF (5 tests)
     * T2.4: A-B repeat invalid state prevention (Point B <= Point A rejection, anti-thrashing debounce) (5 tests)
     * T2.5: Crop cycling wraparound from Reset back to 16:9 (5 tests)
     * T2.6: Caching slider boundaries at 500ms and 10,000ms, and demuxer rapid switching (5 tests)
   - Tier 3: Cross-Feature Combinations (Pairwise interactions -> at least 6 tests):
     * T3.1: High volume boost (250% Soft Red) active while stepping frames
     * T3.2: A-B repeat looping active while crop aspect ratio changes
     * T3.3: Frame stepping during active A-B looping respecting loop boundaries
     * T3.4: Dynamic network caching adjustment during active playback
     * T3.5: Key 'c' (crop) and key 'a' (aspect ratio) non-collision
     * T3.6: Concurrent volume swipe and HUD frame-step
   - Tier 4: Real-World Application Workflows (Realistic scenarios -> at least 5 tests):
     * T4.1: Dialog clarification workflow: quiet video boosted to 220% (Soft Red), A-B loop across dialogue, frame step for lip sync
     * T4.2: Sports replay analysis: 60fps video frame stepped to goal line, 3s critical replay looped
     * T4.3: Cinema crop workflow: 2.35:1 anamorphic crop, right-edge volume swipe, chapter navigation
     * T4.4: Weak network cellular streaming: caching set to 8000ms, demuxer buffer 128MB, continuous playback
     * T4.5: Master end-to-end multi-feature playback workflow
3. Verification:
   - Run `dart analyze test/e2e/phase2_e2e_test.dart` to verify zero errors and zero warnings.
   - Run `flutter test test/e2e/phase2_e2e_test.dart` to verify that all tests execute and pass cleanly.
4. Output:
   - Write a complete handoff report to `d:\E-player\.agents\teamwork\test_writer_m4_1\handoff.md`.
   - Update your `progress.md`.
   - Send completion message to parent when done.
</SYSTEM_MESSAGE>
