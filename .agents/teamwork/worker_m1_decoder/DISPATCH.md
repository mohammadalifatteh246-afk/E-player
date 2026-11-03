## 2026-10-22T10:56:03Z
[Message] timestamp=2026-10-22T10:56:03Z sender=81e1945a-d6bd-4531-87f3-4a7caf8e5a5d priority=MESSAGE_PRIORITY_HIGH content=You are the Hardware Decoder Pipeline Worker for the E-Player project.
Working Directory: d:\E-player\.agents\teamwork\worker_m1_decoder
Original Request Path: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
Project Path: d:\E-player\PROJECT.md

You MUST read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md first.
Also read d:\E-player\PROJECT.md, d:\E-player\.agents\teamwork\spec_miner_survey_features\handoff.md, and d:\E-player\.agents\teamwork\explorer_survey_codebase\handoff.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your mission:
Implement Milestone 1 (Phase 1 Hardware / HW+ Decoders):
1. Create app/lib/features/player/domain/decoder_models.dart:
   - Strongly typed `DecoderMode` enum (auto, hw, hwPlus, sw).
   - `DecoderTelemetry` (requestedMode, activeDecoder, codec, droppedFrames, fps, bitrate).
   - `DecoderSwitchResult` (success, activeMode, backend, fallbackReason).
2. Create app/lib/features/player/domain/decoder_pipeline_service.dart:
   - Bind to active `Player` and `libmpv` platform properties (`hwdec`: auto, yes, auto-copy, no).
   - Dynamic fallback cascade: detects decode failure or excessive frame drops (>10 drops in sliding 2000ms window), dynamically stepping down HW -> HW+ -> SW.
   - Preserve playback position across decoder switches/fallbacks (re-seek with tolerance <= 250ms).
   - Ensure hardware acceleration invariant: keep color grading and geometric transforms offloaded inside libmpv without Flutter raster filters.
   - Expose real-time `telemetryStream` with `hwdec-current`, `video-codec`, `vo-drop-frame-count`, fps.
3. Integrate with app/lib/features/player/ui/player_screen.dart:
   - Connect `DecoderPipelineService` to player lifecycle and modal decoder menu.
   - Update Telemetry HUD to display active hardware decoder and dropped frames from `telemetryStream`.
4. Implement unit tests in app/test/unit/decoder_pipeline_test.dart:
   - Verify manual mode selection, automated fallback transitions, position preservation, and telemetry emission.
5. Run verification from D:\E-player\app:
   - Run flutter analyze (must be 0 errors, 0 warnings).
   - Run flutter test (baseline 67 tests + new decoder tests must all pass 100%).
6. Write handoff report to d:\E-player\.agents\teamwork\worker_m1_decoder\handoff.md and send completion message to orchestrator.

Write Ownership:
- Owns app/lib/features/player/domain/decoder_*.dart, app/lib/features/player/ui/player_screen.dart (decoder integration only), and app/test/unit/decoder_pipeline_test.dart.
- Do NOT edit other modules.

Constraints:
- No C: drive access: all development strictly in D:\E-player.
- Zero local compilation: do NOT run flutter build apk or flutter build windows.
- Strict offline invariant: 100% offline.
- Zero mocking / placeholders: production-grade strongly typed code only.
- Maintain progress.md with timestamps for liveness.
