# Operational Plan: E-Player Roadmap & AADB Studio

## Overview
Autonomous orchestrator execution across 4 target core player phases (Phase 1, 3, 6, 11) and AADB testing/verification gates under strict project constraints.

## Phases & Milestones

### Phase 0: Survey & Full Scope Discovery
- Dispatch 3 parallel Explorers:
  1. `explorer_survey_codebase`: Map existing architecture, pubspec dependencies, libmpv/media_kit integrations, decoders, gestures, pip, casting structures, and existing test suites (baseline passing tests).
  2. `explorer_survey_requirements`: Extract domain invariants, technical specifications, and error conditions across Phases 1, 3, 6, 11 from requirements and authoritative docs.
  3. `explorer_survey_test_infra`: Audit test infrastructure, `flutter test`, `flutter analyze` baselines, mutation testing / Meta-ACH setup, and AADB test layers.
- Synthesize findings into `PROJECT.md` (Feature Inventory, Architecture, Interface Contracts, Milestones).

### Phase 1: Dual Track Initialization
- Track A (E2E Testing Track): Spawn E2E Testing Orchestrator / Test Writer to establish test infrastructure, test harnesses, and Tiers 1-4 opaque-box tests covering all inventoried features, publishing `TEST_READY.md`.
- Track B (Implementation Track):
  - Milestone 1: Phase 1 Hardware / HW+ Decoders (dynamic fallback pipeline across HW, HW+, SW via `media_kit`/`libmpv`).
  - Milestone 2: Phase 3 Cinematic Gesture Engine (scrub, timestamp seek, split brightness/volume, double-tap jump, pinch-to-zoom).
  - Milestone 3: Phase 6 Native Picture-in-Picture (AutoEnterPiP, desktop overlay, HUD auto-dismiss, aspect-ratio preservation).
  - Milestone 4: Phase 11 Tokenized Wireless Casting (sink negotiation Chromecast, DLNA, Miracast, AirPlay, subtitle muxing, sync controls).
  - Milestone 5: 100% E2E Test Pass (Tiers 1-4) & Tier 5 Adversarial Coverage Hardening (Meta-ACH mutation killing).

### Phase 2: Final Verification & Git Delivery
- Full verification: `flutter test` 100% pass, `flutter analyze` 0 errors/0 warnings, all mutants killed, clean offline invariants.
- Commit and push to `origin/main`.
- Report completion to Sentinel.
