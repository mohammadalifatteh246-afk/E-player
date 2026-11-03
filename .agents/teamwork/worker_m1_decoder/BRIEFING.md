# BRIEFING — 2026-10-22T11:23:45Z

## Mission
Implement Milestone 1 (Phase 1 Hardware / HW+ Decoders) for E-Player: models, pipeline service, player screen integration, and unit tests with 100% test pass and 0 analyze issues.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: d:\E-player\.agents\teamwork\worker_m1_decoder
- Original parent: 81e1945a-d6bd-4531-87f3-4a7caf8e5a5d
- Milestone: Milestone 1 (Phase 1 Hardware / HW+ Decoders)

## 🔒 Key Constraints
- No C: drive access: all development strictly in D:\E-player.
- Zero local compilation: do NOT run flutter build apk or flutter build windows.
- Strict offline invariant: 100% offline.
- Zero mocking / placeholders: production-grade strongly typed code only.
- Maintain progress.md with timestamps for liveness.
- Write ownership: app/lib/features/player/domain/decoder_*.dart, app/lib/features/player/ui/player_screen.dart (decoder integration only), and app/test/unit/decoder_pipeline_test.dart. Do NOT edit other modules.

## Current Parent
- Conversation ID: 81e1945a-d6bd-4531-87f3-4a7caf8e5a5d
- Updated: 2026-10-22T11:23:45Z

## Task Summary
- **What to build**:
  1. `app/lib/features/player/domain/decoder_models.dart`:
     - Strongly typed `DecoderMode` enum (`auto`, `hw`, `hwPlus`, `sw`)
     - `DecoderTelemetry` (`requestedMode`, `activeDecoder`, `codec`, `droppedFrames`, `fps`, `bitrate`, `width`, `height`, etc.)
     - `DecoderSwitchResult` (`success`, `activeMode`, `backend`, `fallbackReason`)
  2. `app/lib/features/player/domain/decoder_pipeline_service.dart`:
     - Binds to active `Player` and `libmpv` platform properties (`hwdec`: auto, yes, auto-copy, no)
     - Dynamic fallback cascade (HW -> HW+ -> SW)
     - Sliding 2000ms window drop-frame monitoring (>10 drops threshold)
     - Re-seek position preservation with tolerance <= 250ms
     - Hardware acceleration offload invariant (INV-HW-002)
     - Real-time `telemetryStream`
  3. `app/lib/features/player/ui/player_screen.dart`:
     - Connect `DecoderPipelineService` to player lifecycle, modal menu, and HUD overlay.
  4. `app/test/unit/decoder_pipeline_test.dart`:
     - 21 unit tests covering all modes, models, fallback cascades, drop windows, and re-seek tolerance.
- **Success criteria**:
  - `flutter analyze` 0 errors, 0 warnings on all owned files.
  - `flutter test` 100% pass across 87 tests (baseline 66 + 21 new decoder tests).

## Change Tracker
- **Files modified**:
  - `app/lib/features/player/domain/decoder_models.dart` (new model definitions)
  - `app/lib/features/player/domain/decoder_pipeline_service.dart` (new pipeline service)
  - `app/lib/features/player/ui/player_screen.dart` (integrated decoder pipeline, modal menu, telemetry HUD, disposal)
  - `app/test/unit/decoder_pipeline_test.dart` (21 comprehensive unit tests)
- **Build status**: PASS (87/87 tests passed)
- **Pending issues**: None

## Quality Status
- **Build/test result**: PASS (87 tests passed, 0 failures)
- **Lint status**: 0 errors, 0 warnings on owned files (`flutter analyze` clean)
- **Tests added/modified**: 21 new unit tests in `decoder_pipeline_test.dart`

## Loaded Skills
- None

## Key Decisions Made
- Offload hardware decoding directly to libmpv (`hwdec`: yes/auto-copy/no) without Flutter raster filtering, preserving INV-HW-002.
- Sliding 2000ms window prunes timestamps older than 2000ms and triggers automatic fallback when drop count delta > 10.
- Re-seek tolerance checked at <= 250ms and restored automatically on decoder mode switches.
- Lifecycle hygiene: stream subscriptions and timers cleanly cancelled on disposal.

## Artifact Index
- d:\E-player\.agents\teamwork\worker_m1_decoder\DISPATCH.md
- d:\E-player\.agents\teamwork\worker_m1_decoder\BRIEFING.md
- d:\E-player\.agents\teamwork\worker_m1_decoder\progress.md
- d:\E-player\.agents\teamwork\worker_m1_decoder\handoff.md
