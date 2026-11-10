# E2E Test Infra: Phase 1 Deliverables

## Test Philosophy
- Opaque-box, requirement-driven. Derived from `ORIGINAL_REQUEST.md` (R1–R6) and user-facing specifications, not internal implementation code.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| 1 | Desktop Keyboard Shortcuts Infra (13 shortcuts) | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ |
| 2 | 4-Tier Multi-Tier Jump Physics (3s, 10s, 60s, 300s) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ |
| 3 | Audio Delay Synchronization UI Slider (-10s to +10s) | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ |
| 4 | Dedicated Audio Track Selector Modal | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ |
| 5 | Equalizer Parity (11 Presets + Preamp Slider) | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ |

## Test Architecture
- Test runner: `flutter test test/e2e/phase1_e2e_test.dart`
- Pass/fail semantics: All tests exit code 0, zero unhandled exceptions, zero widget overflow errors.
- Headless mock support: Uses `testWidgets` with isolated mock harnesses to avoid requiring external `mpv.dll` in headless CI environments.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Desktop Playback & 4-Tier Jump Navigation | Space, f, Shift+Right, Alt+Right, Ctrl+Right, Ctrl+Alt+Right, Arrow Up/Down | High |
| 2 | Out-of-Sync Audio Dialogue Correction Workflow | AudioStudioSheet, AudioDelaySyncCard, slider drag to +150ms, +50ms nudge, reset | Medium |
| 3 | Audio Track Stream Switching via Top Bar Modal | PlayerScreen HUD top bar, audiotrack icon, track selection, active stream checkmark | Medium |
| 4 | Concert / Hall Audio Equalization & Preamp Boost | AudioStudioSheet, 'Large Hall' preset selection, Preamp +4dB adjustment, filter graph | Medium |
| 5 | End-to-End Cinematic Media Consumption Experience | Full combination of shortcuts, delay sync, audio track switch, and EQ presets | High |

## Coverage Thresholds
- Tier 1: ≥5 per feature (Total ≥ 25)
- Tier 2: ≥5 per feature (Total ≥ 25)
- Tier 3: Pairwise coverage of major feature combinations (Total ≥ 10)
- Tier 4: ≥5 realistic application scenarios (Total ≥ 5)
- Total E2E test cases: ≥ 65 test cases.
