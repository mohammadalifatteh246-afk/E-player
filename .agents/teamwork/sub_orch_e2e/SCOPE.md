# Scope: Milestone 4 (Phase 2 E2E Test Suite)

## Architecture
- Target: `d:\E-player\app\test\e2e\phase2_e2e_test.dart`
- Pattern: Headless Mock Harness via `FakePlatformPlayer extends PlatformPlayer` and `FakePlayer extends Fake implements Player` (replicated from `test/e2e/phase1_e2e_test.dart`)
- Test methodology: Category-Partition + Boundary Value Analysis + Pairwise Interactions + Real-World Workloads
- No dependency on `libmpv.dll` or native C-FFI runtime binaries

## Feature Inventory
| # | Feature | Requirement | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|-------------|:------:|:------:|:------:|:------:|
| 1 | Volume Over-Amplification to 300% | R1 | >=5 | >=5 | Pairwise | Scenario |
| 2 | 3-Color Safety Indicator | R1 | >=5 | >=5 | Pairwise | Scenario |
| 3 | Frame-by-Frame Stepping ('e' & HUD) | R2 | >=5 | >=5 | Pairwise | Scenario |
| 4 | A-B Repeat Looping 4-State Controller | R3 | >=5 | >=5 | Pairwise | Scenario |
| 5 | Aspect Ratio Crop Cycling ('c' & Reset) | R4 | >=5 | >=5 | Pairwise | Scenario |
| 6 | Network & Demuxer Caching Buffers | R5 | >=5 | >=5 | Pairwise | Scenario |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M4.1 | Headless Test Harness & Tier 1 Feature Tests (>=30 tests) | `test/e2e/phase2_e2e_test.dart` | none | IN_PROGRESS |
| M4.2 | Tier 2 Boundary & Corner Tests (>=30 tests) | `test/e2e/phase2_e2e_test.dart` | M4.1 | PLANNED |
| M4.3 | Tier 3 Cross-Feature Pairwise Tests (>=6 tests) | `test/e2e/phase2_e2e_test.dart` | M4.2 | PLANNED |
| M4.4 | Tier 4 Real-World Application Workflows (>=5 tests) | `test/e2e/phase2_e2e_test.dart` | M4.3 | PLANNED |
| M4.5 | Static Analysis, Review, Challenge & Forensic Audit | `dart analyze`, Gate verification | M4.4 | PLANNED |
| M4.6 | Test Readiness Sign-off & TEST_READY.md | `TEST_READY.md`, `handoff.md` | M4.5 | PLANNED |

## Interface Contracts & Mock Specifications
1. Volume 300% & 3-Color Safety Colors:
   - `VolumeSafetyColors.green` = `Color(0xFF22C55E)` (0%–100%)
   - `VolumeSafetyColors.amber` = `Color(0xFFF59E0B)` (101%–200%)
   - `VolumeSafetyColors.softRed` = `Color(0xFFEF4444)` (201%–300%)
   - Clamping: $[0.0, 300.0]$
2. Frame Stepping:
   - Hotkey `e` / HUD action button invokes mpv command `frame-step`
   - Pauses playback automatically if playing
3. A-B Repeat Controller:
   - States: `off` -> `pointA` -> `looping` -> `clear`
   - Real-time seek to `pointA` when position reaches `pointB`
   - Concurrency guard preventing multiple seek storms
4. Aspect Crop Presets:
   - Cycling: `16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `Reset`
5. Caching Buffers:
   - Network caching: 500ms .. 10,000ms -> `cache-secs`
   - Demuxer cache size: 16MB .. 128MB -> `demuxer-max-bytes`
