# E2E Test Infra: E-Player Production Update

## Test Philosophy
- Opaque-box, requirement-driven, derived directly from `ORIGINAL_REQUEST.md`.
- Zero dependency on internal implementation private methods; exercises public UI widgets and domain providers.
- Systematic 4-tier coverage:
  - Tier 1: Feature Coverage (≥5 tests per requirement R1–R5)
  - Tier 2: Boundary & Corner Cases (empty groups, duplicate paths, max limits, special chars)
  - Tier 3: Cross-Feature Combinations (group creation + multi-select + delete/move + history interaction)
  - Tier 4: Real-World Workload Scenarios (end-user workflow simulations)

## Feature Inventory & Test Mapping
| # | Feature | Requirement | Tier 1 | Tier 2 | Tier 3 |
|---|---------|-------------|:------:|:------:|:------:|
| 1 | Empty Group Creation & Zero Items | R1 | 5 | 5 | ✓ |
| 2 | Add Button & Media Import | R1 | 5 | 5 | ✓ |
| 3 | Long-Press Multi-Select (Home) | R2 | 5 | 5 | ✓ |
| 4 | Select All & Deselect (Home) | R2 | 5 | 5 | ✓ |
| 5 | Batch Delete (Home) | R2 | 5 | 5 | ✓ |
| 6 | Batch Move (Home) | R2 | 5 | 5 | ✓ |
| 7 | Built-in Feature Protection | R2 | 5 | 5 | ✓ |
| 8 | Multi-Select & Batch Actions (Library) | R3 | 5 | 5 | ✓ |
| 9 | History Scrollable View | R4 | 5 | 5 | ✓ |
| 10 | History Strict 5-Item Cap | R4 | 5 | 5 | ✓ |
| 11 | Video-Only Media Library Filter | R5 | 5 | 5 | ✓ |
| 12 | Complete Removal of Music/Series/Anime | R5 | 5 | 5 | ✓ |

## Test Architecture
- Test Runner: `flutter test test/e2e/e2e_requirements_test.dart`
- Test Harness: `test/helpers/eplayer_test_harness.dart` (`EPlayerTestHarness` with in-memory SQLite FFI and providers)
- Location: `d:\E-player\app\test\e2e\`

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised |
|---|----------|--------------------|
| 1 | Create new group, verify empty, add video files, verify count | F1, F2 |
| 2 | Long-press select 3 items, tap Select All, move to another group | F4, F5, F7, F9 |
| 3 | Attempt long-press on "Create Group" & "Videos" cards, verify no selection | F8 |
| 4 | Seed 10 recent items, verify only 5 rendered, scroll to 5th item | F10, F11 |
| 5 | Seed audio (.mp3) and video (.mp4) files, verify Media Library displays only video folders | F12, F13 |

## Signal
Upon test suite completion, `d:\E-player\TEST_READY.md` will be published at the project root.
