# Task Assignment: Phase 1 Opaque-Box E2E Test Suite Authoring

## Working Directory
`d:\E-player\app`

## Your State Folder
`d:\E-player\.agents\teamwork\teamwork_test_writer_e2e_r1_1\`

## Exclusive Write Ownership
You own and may modify ONLY these two files:
- `d:\E-player\app\test\e2e\phase1_e2e_test.dart`
- `d:\E-player\TEST_READY.md` (at project root)
DO NOT modify any implementation files in `lib/`.

## Mandatory Authoritative Inputs
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (MUST read first)
- `d:\E-player\PROJECT.md`
- `d:\E-player\TEST_INFRA.md`
- `d:\E-player\.agents\teamwork\e2e_test_orch\SCOPE.md`

## Explorer Investigation Handoffs (Read and Follow Exact Blueprints)
1. `d:\E-player\.agents\teamwork\teamwork_explorer_e2e_r1_1\handoff.md` (Headless `FakePlatformPlayer` mock harness and test wrapper)
2. `d:\E-player\.agents\teamwork\teamwork_explorer_e2e_r1_2\handoff.md` (Master UI selector table, finder recipes, and `simulateShortcut` helper)
3. `d:\E-player\.agents\teamwork\teamwork_spec_miner_e2e_r1_3\handoff.md` (Exhaustive 68-test case matrix across 4 tiers)

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Detailed Objectives
1. Author `d:\E-player\app\test\e2e\phase1_e2e_test.dart`:
   - Incorporate `FakePlatformPlayer` (subclassing `PlatformPlayer` from `package:media_kit/media_kit.dart`) with zero external `mpv.dll` dependencies.
   - Implement the test wrapper `wrapWithPhase1App` and the `simulateShortcut` helper ensuring modifier cleanup hygiene.
   - Implement all 68 test cases specified in `teamwork_spec_miner_e2e_r1_3\handoff.md`:
     - Tier 1: Feature Coverage (27 tests: T1.1.1 to T1.5.5)
     - Tier 2: Boundary & Corner Cases (26 tests: T2.1.1 to T2.5.6)
     - Tier 3: Cross-Feature Interactions (10 tests: T3.1 to T3.10)
     - Tier 4: Real-World Scenarios (5 tests: T4.1 to T4.5)
   - Verify every test has genuine assertions checking widget presence, text, state changes, OSD feedback, and mpv property/filter calls.
   - Ensure the test suite compiles cleanly with zero static analysis warnings (`dart analyze test/e2e/phase1_e2e_test.dart`).

2. Author and Publish `d:\E-player\TEST_READY.md` at project root:
   - Follow the template in `PROJECT.md` and `TEST_INFRA.md`.
   - Document test runner command: `flutter test test/e2e/phase1_e2e_test.dart`.
   - Document coverage table (Tier 1: 27, Tier 2: 26, Tier 3: 10, Tier 4: 5, Total: 68).
   - Document feature checklist mapping features to tiers.

3. Run Verification:
   - Run `dart analyze test/e2e/phase1_e2e_test.dart` and `flutter test test/e2e/phase1_e2e_test.dart`.
   - Document all verification commands and outcomes in `handoff.md`.

Write your handoff report to `handoff.md` in your state folder and notify your parent when complete.


## 2026-11-10T09:00:52Z
Read your task assignment at d:\E-player\.agents\teamwork\teamwork_test_writer_e2e_r1_1\DISPATCH.md.
MANDATORY: Read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md first before starting work.
Also read d:\E-player\PROJECT.md, d:\E-player\TEST_INFRA.md, and d:\E-player\.agents\teamwork\e2e_test_orch\SCOPE.md.
Follow the exact blueprints in:
- d:\E-player\.agents\teamwork\teamwork_explorer_e2e_r1_1\handoff.md (FakePlatformPlayer mock harness)
- d:\E-player\.agents\teamwork\teamwork_explorer_e2e_r1_2\handoff.md (UI finders, selectors, simulateShortcut helper)
- d:\E-player\.agents\teamwork\teamwork_spec_miner_e2e_r1_3\handoff.md (Full 68-test case matrix across 4 tiers)

Your exclusive write ownership:
- test/e2e/phase1_e2e_test.dart
- TEST_READY.md (at project root)
DO NOT modify any implementation files in lib/.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Author the test suite with all 68 tests, run dart analyze and flutter test on test/e2e/phase1_e2e_test.dart, publish TEST_READY.md, write your handoff report to handoff.md in your state folder, and notify your parent when complete.
