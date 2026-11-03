## 2026-11-03T04:50:01Z
You are worker_m4_cast.
Working directory: d:\E-player\.agents\teamwork\worker_m4_cast
Project root: d:\E-player
App directory: d:\E-player\app

MANDATORY INSTRUCTIONS:
1. Read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md before starting any work.
2. Read d:\E-player\PROJECT.md.
3. Read the complete technical specification in d:\E-player\.agents\teamwork\explorer_m4_cast\handoff.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

CONSTRAINTS:
- No C: drive access / duplication: all work stays inside D:\E-player.
- No local compilation of binaries: do NOT run flutter build apk or flutter build windows.
- Verification is performed strictly via flutter test and flutter analyze from d:\E-player\app.
- Strict offline invariant: 100% offline capability. Zero WAN/cloud network communication.
- Zero mocking / placeholders: production-grade strongly typed implementations only. No mockito, mocktail, dummy stubs, or // TODO.

TASK:
Implement Milestone 4 (Phase 11 Tokenized Wireless Casting & Local Streaming Daemon) per the exact specifications in explorer_m4_cast/handoff.md:
1. Create `app/lib/features/casting/domain/cast_models.dart`:
   - `CastProtocol`, `CastTranscodeProfile`, `CastSessionState`, `CastDevice`, `CastPlaybackState`, `CastSession`, `StreamingClientTelemetry`.
2. Implement `app/lib/features/casting/domain/local_streaming_daemon.dart`:
   - `LocalStreamingDaemon` with `startSession`, `stopSession`, `dispose`, and `telemetryStream`.
   - 32-char hex session token generation (`Random.secure()`).
   - Token authentication (403 Forbidden on invalid/missing token).
   - Canonical path traversal prevention (400 Bad Request on `..`).
   - HTTP 206 Partial Content Range parsing (`Range: bytes=start-end`, `bytes=start-`, 416 on out of bounds, 206 with `Accept-Ranges: bytes`, `Content-Range`, `Content-Length`, 200 on no Range header).
   - Subtitle sidecar endpoint: `/cast/{token}/subtitles/{track_id}.vtt` serving converted `.srt` to `.vtt` with `Content-Type: text/vtt; charset=utf-8` and `Cache-Control: no-cache`.
   - Strict offline LAN IP binding (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`, or loopback).
3. Refactor `app/lib/features/casting/domain/cast_service.dart`:
   - Export and import `cast_models.dart`.
   - Manage `LocalStreamingDaemon` lifecycle in `connect(...)`, `disconnect()`, and `dispose()`.
4. Refactor `app/lib/features/player/ui/player_screen.dart`:
   - Add `_openCastSheet()` method that pauses `_controlsTimer` during sheet presentation and restores it in `finally`.
   - Wire `_openCastSheet()` to the Cast top bar button.
5. Create unit tests in `app/test/unit/local_streaming_daemon_test.dart` (>=14 tests covering loopback binding, token validation, 403, 400, 206 range slices, 416, WebVTT conversion, and telemetry).
6. Expand `app/test/unit/cast_service_test.dart` to cover multi-protocol sink discovery, transcode profiles, state sync, and daemon session integration.
7. Run verification commands in `d:\E-player\app`:
   - `flutter analyze`
   - `flutter test test/unit/local_streaming_daemon_test.dart`
   - `flutter test test/unit/cast_service_test.dart`
   - `flutter test test/e2e/tier1_feature_coverage_test.dart`
   - `flutter test test/e2e/tier2_boundary_corner_test.dart`
   - `flutter test test/e2e/tier3_cross_feature_test.dart`
   - `flutter test test/e2e/tier4_user_scenarios_test.dart`
8. Write your complete handoff report to `d:\E-player\.agents\teamwork\worker_m4_cast\handoff.md` and notify orchestrator via send_message.
