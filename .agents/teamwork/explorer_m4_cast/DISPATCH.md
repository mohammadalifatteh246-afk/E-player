## 2026-11-03T04:41:17Z
You are explorer_m4_cast.
Working directory: d:\E-player\.agents\teamwork\explorer_m4_cast
Project root: d:\E-player
App directory: d:\E-player\app

MANDATORY INSTRUCTIONS:
1. Read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md.
2. Read d:\E-player\PROJECT.md (especially § Feature Inventory (features 16-21), § Interface Contracts (LocalStreamingDaemon & CastService), and § Code Layout).
3. Read d:\E-player\TEST_INFRA.md and d:\E-player\TEST_READY.md.
4. Read d:\E-player\app\test\helpers\eplayer_test_harness.dart (see EphemeralCastServer, RealLoopbackHttpOverrides, and OfflineSecurityValidator) and d:\E-player\app\test\e2e\tier1_feature_coverage_test.dart (Features 17-21).

TASK:
Explore the codebase and technical specifications for Milestone 4 (Phase 11 Tokenized Wireless Casting):
1. Check what currently exists in `app/lib/features/casting/` (if anything exists or needs creation).
2. Check `app/lib/features/player/ui/player_screen.dart` for Cast button and cast sheet integration (`_openCastSheet`).
3. Check `LocalStreamingDaemon` architecture:
   - Ephemeral LAN HTTP server (`HttpServer.bind(InternetAddress.anyIPv4, 0)` or loopback for testing)
   - 32-byte secure cryptographically random session token generation (`/cast/{session_token}/...`)
   - Strict token validation on incoming requests (403 Forbidden on missing/invalid token)
   - Canonical path traversal prevention (`..` rejection)
   - HTTP 206 Partial Content Range parsing (`Range: bytes=start-end`, `bytes=start-`, returning 416 on invalid bounds, sending `Accept-Ranges: bytes`, `Content-Range`, `Content-Length`)
   - WebVTT subtitle sidecar conversion/serving endpoint (`/cast/{session_token}/subtitles/track_1.vtt`)
   - Strict offline IP validation (127.0.0.1, 10.x.x.x, 172.16-31.x.x, 192.168.x.x)
4. Check `CastService` architecture:
   - Multi-protocol sink discovery data models (`CastDevice`, `CastProtocol` [chromecast, dlna, miracast, airplay], `CastSessionState`, `CastPlaybackState`)
   - Bi-directional state synchronization (Play, Pause, Seek, Volume)
   - Heartbeat and connection management
5. Provide a complete, structured technical specification and file-by-file implementation plan for the Worker:
   - `app/lib/features/casting/domain/cast_models.dart`
   - `app/lib/features/casting/domain/local_streaming_daemon.dart`
   - `app/lib/features/casting/domain/cast_service.dart`
   - `app/lib/features/casting/ui/cast_sheet.dart` (or verify existing)
   - Integration into `app/lib/features/player/ui/player_screen.dart`
   - Mock-free unit tests in `app/test/unit/local_streaming_daemon_test.dart` and `app/test/unit/cast_service_test.dart`
6. Write your complete analysis report to `d:\E-player\.agents\teamwork\explorer_m4_cast\handoff.md` and notify orchestrator via send_message. Explorer is read-only: do NOT modify source code files.
