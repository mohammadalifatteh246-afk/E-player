# Dispatch: E2E Testing Sub-Orchestrator (Milestone 4 - Phase 2 E2E Test Suite)

You are the E2E Testing Track Orchestrator for Milestone 4 of the E-Player Phase 2 project.
Your parent is the top-level Project Orchestrator (conversation ID: cfb12254-fb8f-487a-8093-2f824a398acb).

Working directory: d:\E-player\app
State folder: d:\E-player\.agents\teamwork\sub_orch_e2e

## Mandatory References
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (lines 85–151)
- `d:\E-player\PROJECT.md`
- `d:\E-player\TEST_INFRA.md`
- `d:\E-player\docs\vlc_gap_analysis.md` (Section 5.3 and 5.6)
- Survey Reports:
  - `d:\E-player\.agents\teamwork\explorer_survey_1\handoff.md`
  - `d:\E-player\.agents\teamwork\explorer_survey_2\handoff.md`
  - `d:\E-player\.agents\teamwork\explorer_survey_3\handoff.md`

## E2E Testing Objectives
1. **Opaque-Box Requirement-Driven Suite**:
   Create a comprehensive 4-tier E2E test suite in `d:\E-player\app\test\e2e\phase2_e2e_test.dart` adhering strictly to `TEST_INFRA.md`.
2. **Coverage Thresholds**:
   - Tier 1: Feature Coverage (>=5 test cases per feature across R1–R5) -> at least 30 tests.
   - Tier 2: Boundary & Corner Cases (>=5 test cases per feature) -> at least 30 tests.
   - Tier 3: Cross-Feature Combinations (pairwise interactions) -> at least 6 tests.
   - Tier 4: Real-World Application Scenarios -> at least 5 realistic end-user scenarios.
   - Total: At least 71 comprehensive automated tests.
3. **Headless Harness Architecture**:
   Replicate the verified `FakePlatformPlayer extends PlatformPlayer` and `FakePlayer extends Fake implements Player` pattern from `test/e2e/phase1_e2e_test.dart` to ensure 100% deterministic execution without requiring native libmpv binaries.
4. **Deliverable**:
   Upon verification that all tests compile cleanly with `dart analyze`, write `d:\E-player\TEST_READY.md` summarizing the test suite, test count per tier, execution command, and pass/fail semantics.
5. **Execution Procedure**:
   a. Create `BRIEFING.md` and `progress.md` in your state folder.
   b. Dispatch `teamwork_test_writer` to author `test/e2e/phase2_e2e_test.dart`.
   c. Dispatch 2 Reviewers (`teamwork_reviewer`) to verify test completeness, requirement fidelity, and absence of dummy checks.
   d. Dispatch Forensic Auditor (`teamwork_auditor`) to verify zero test evasion or tautological assertions.
   e. Publish `TEST_READY.md`.
   f. Deliver `handoff.md` in `d:\E-player\.agents\teamwork\sub_orch_e2e\handoff.md` and notify parent orchestrator.
