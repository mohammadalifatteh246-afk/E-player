# Milestone 4 Review & Adversarial Stress-Test Report
**Phase 11: Tokenized Wireless Casting & Local Streaming Daemon**

---

## 1. Observation

### 1.1 Source Code Inspection
The following artifacts delivered by `worker_m4_cast` were inspected in detail:
1. **`app/lib/features/casting/domain/cast_models.dart`** (214 lines):
   - Strongly typed domain entities: `CastProtocol` (Chromecast V2, AirPlay 2, DLNA / UPnP, Miracast Direct), `CastTranscodeProfile` (directPassthrough, audioRemux, videoTranscode, fullRemux), `CastSessionState`, `CastDevice`, `CastPlaybackState`, `CastSession`, and `StreamingClientTelemetry`.
   - Zero hardcoded mock bypasses or dummy stubs; complete `copyWith` and immutable value semantics.
2. **`app/lib/features/casting/domain/local_streaming_daemon.dart`** (386 lines):
   - Token validation: `generateSessionToken()` generates 16 bytes via `Random.secure()` formatted as 32 lowercase hex characters (`^[a-f0-9]{32}$`).
   - Path traversal prevention: Lines 226–237 check `path.contains('..') || decodedPath.contains('..') || request.requestedUri.toString().contains('..')` returning `HttpStatus.badRequest` (400).
   - Ephemeral token gate: Lines 240–251 enforce `segments.length >= 2 && segments[0] == 'cast' && segments[1] == _sessionToken`, returning `HttpStatus.forbidden` (403) on invalid or missing token.
   - HTTP 206 Partial Content Range serving: Lines 290–334 set `Accept-Ranges: bytes`, parse `Range: bytes=start-end` and `bytes=start-`, validate boundaries returning 416 with `bytes */totalSize` on out-of-range bounds, and stream byte slices using `file.openRead(start, end + 1)` with `Content-Range: bytes $start-$end/$totalSize` and `Content-Length: end - start + 1`.
   - Subtitle sidecar endpoint: Lines 254–267 handle `/cast/{token}/subtitles/{track_id}.vtt` returning 200 OK with `Content-Type: text/vtt; charset=utf-8` and `Cache-Control: no-cache`. Includes `convertSrtToVtt(...)` on-the-fly SubRip to WebVTT cue conversion with timestamp normalization.
   - Offline IP validation: `isPrivateLanIp(ip)` strictly accepts `127.0.0.1`, `localhost`, `::1`, `192.168.x.x`, `10.x.x.x`, and `172.16-31.x.x`, and rejects public WAN IPs.
   - Telemetry streaming: Emits `StreamingClientTelemetry` on a broadcast stream for every handled request.
3. **`app/lib/features/casting/domain/cast_service.dart`** (386 lines):
   - Lifecycle management: Binds `LocalStreamingDaemon` upon `connect()` when `mediaPath` is provided and exists, injecting generated `streamUrl` and `subtitleUrl` into `CastSession`.
   - Teardown: Safely closes daemon sessions on `disconnect()` and disposes server instances on `dispose()`.
   - Bi-directional sync: Attaches player listeners for position, duration, and play/pause state; provides remote volume clamping `[0.0, 1.0]`, mute toggling, audio route toggling, and seek propagation.
4. **`app/lib/features/player/ui/player_screen.dart`** (lines 1060–1073 & 1359):
   - Auto-dismiss coordination: `_openCastSheet()` cancels `_controlsTimer` before presenting `CastSheet.show(...)` and restores it in a `finally` block when `mounted`, ensuring modal interactions inhibit HUD auto-dismissal.

### 1.2 Verbatim Test & Static Analysis Execution Results
Commands executed directly inside `d:\E-player\app`:

1. `cd app; flutter analyze`
   ```
   Analyzing app...
   No issues found! (ran in 9.3s)
   ```
   Exit code: 0.

2. `cd app; flutter test test/unit/local_streaming_daemon_test.dart`
   ```
   00:00 +0: loading D:/E-player/app/test/unit/local_streaming_daemon_test.dart
   00:00 +1: LocalStreamingDaemon Unit Tests 1. Binds loopback ephemeral port and generates valid 32-char hex session token
   00:00 +2: LocalStreamingDaemon Unit Tests 2. Constructs valid streamUrl and subtitleUrl endpoints matching spec
   00:00 +3: LocalStreamingDaemon Unit Tests 3. Delivers 200 OK full content when valid session token is provided without range
   00:00 +4: LocalStreamingDaemon Unit Tests 4. Rejects request with 403 Forbidden when session token is invalid
   00:00 +5: LocalStreamingDaemon Unit Tests 5. Rejects request with 403 Forbidden when session token is missing
   00:00 +6: LocalStreamingDaemon Unit Tests 6. Rejects path traversal attack with 400 Bad Request
   00:00 +7: LocalStreamingDaemon Unit Tests 7. Handles HTTP 206 Partial Content range bytes=0-1023
   00:00 +8: LocalStreamingDaemon Unit Tests 8. Handles open-ended HTTP 206 range bytes=1000-
   00:00 +9: LocalStreamingDaemon Unit Tests 9. Handles boundary range slices bytes=0-0 and bytes=last-last
   00:00 +10: LocalStreamingDaemon Unit Tests 10. Returns 416 Requested Range Not Satisfiable for out-of-bounds byte range
   00:00 +11: LocalStreamingDaemon Unit Tests 11. Gracefully falls back to 200 OK on malformed or non-bytes Range headers
   00:00 +12: LocalStreamingDaemon Unit Tests 12. Delivers converted WebVTT sidecar with text/vtt and no-cache header
   00:00 +13: LocalStreamingDaemon Unit Tests 13. convertSrtToVtt transforms comma timecodes to period decimal notation
   00:00 +14: LocalStreamingDaemon Unit Tests 14. Subtitle request with invalid session token is rejected with 403 Forbidden
   00:00 +15: LocalStreamingDaemon Unit Tests 15. Emits real-time StreamingClientTelemetry events during requests
   00:00 +15: LocalStreamingDaemon Unit Tests 16. stopSession terminates HTTP server and releases bound port
   00:02 +16: LocalStreamingDaemon Unit Tests 17. Offline IP validation correctly validates LAN and rejects public WAN
   00:02 +17: All tests passed!
   ```
   Exit code: 0.

3. `cd app; flutter test test/unit/cast_service_test.dart`
   ```
   00:00 +0: loading D:/E-player/app/test/unit/cast_service_test.dart
   00:00 +0: CastService Subsystem & Unit Tests 1. Initializes with default devices and starts scanning
   00:00 +1: CastService Subsystem & Unit Tests 2. Discovers multi-protocol sinks (Chromecast, AirPlay, DLNA, Miracast)
   00:00 +2: CastService Subsystem & Unit Tests 3. Resolves correct transcode profiles based on container and protocol
   00:00 +3: CastService Subsystem & Unit Tests 4. Connects to target device and updates connection state
   00:00 +4: CastService Subsystem & Unit Tests 5. Spawns LocalStreamingDaemon session when connecting with existing media file
   00:01 +5: CastService Subsystem & Unit Tests 6. Disconnects active session and terminates LocalStreamingDaemon gracefully
   00:02 +6: CastService Subsystem & Unit Tests 7. Remote volume clamping and mute toggling
   00:02 +7: CastService Subsystem & Unit Tests 8. Audio route selection and remote play/pause
   00:02 +8: CastService Subsystem & Unit Tests 9. Seek updates active session position
   00:02 +9: CastService Subsystem & Unit Tests 10. Switching target device automatically tears down previous session
   00:04 +10: All tests passed!
   ```
   Exit code: 0.

4. `cd app; flutter test test/cast_service_test.dart`
   - 10/10 passed (delegated to unit suite). Exit code: 0.

5. Pre-existing E2E Regression Suites:
   - `test/e2e/tier1_feature_coverage_test.dart`: 105/105 passed. Exit code: 0.
   - `test/e2e/tier2_boundary_corner_test.dart`: 105/105 passed. Exit code: 0.
   - `test/e2e/tier3_cross_feature_test.dart`: 25/25 passed. Exit code: 0.
   - `test/e2e/tier4_user_scenarios_test.dart`: 10/10 passed. Exit code: 0.

---

## 2. Logic Chain

1. **Contract Adherence (Observation 1.1)**:
   The implementation in `local_streaming_daemon.dart` satisfies all requirements laid out in `PROJECT.md § LocalStreamingDaemon & CastService`:
   - Cryptographically random 32-character hexadecimal token validation returning 403 on missing or invalid tokens.
   - Path traversal prevention explicitly returning 400 on `..` across raw and decoded paths.
   - Full HTTP 206 Partial Content Range parsing with `Accept-Ranges: bytes`, `Content-Range: bytes start-end/total`, `Content-Length`, and 416 on out-of-range bounds.
   - Dedicated Subtitle sidecar endpoint returning `Content-Type: text/vtt; charset=utf-8` and `Cache-Control: no-cache`.
   - Strict offline IP validation allowing only private LAN and loopback subnets.
2. **Subsystem Integration & State Synchronization (Observation 1.1.3 & 1.1.4)**:
   `CastService` automatically binds and unbinds `LocalStreamingDaemon` during casting sessions. In `player_screen.dart`, `_openCastSheet()` coordinates with the HUD auto-dismiss timer via a `try`/`finally` block, satisfying Feature 10.
3. **Adversarial Resilience & Integrity (Observation 1.1 & 1.2)**:
   - No hardcoded test responses or facade bypasses exist in the source code; the HTTP server is a real `dart:io` server serving real file streams.
   - Arbitrary file disclosure is prevented at the architectural level: the URL path does not allow arbitrary filesystem lookups; the daemon only reads the `_filePath` bound securely at session start.
   - Both unit tests and all 4 tiers of E2E tests pass with zero failures and zero static analysis warnings.

---

## 3. Caveats

- **Network Interface Availability**: In air-gapped test environments or headless CI containers lacking physical Wi-Fi/Ethernet interfaces, `resolveBindAddress` falls back to `InternetAddress.loopbackIPv4` (`127.0.0.1`), which remains completely offline and functional for testing.
- No other caveats.

---

## 4. Conclusion

**Verdict: APPROVE**

Milestone 4 (Phase 11 Tokenized Wireless Casting & Local Streaming Daemon) has met and exceeded all functional, architectural, security, and quality requirements. The codebase exhibits zero integrity violations, passes all 27 unit tests and 245 E2E regression tests, and produces 0 static analysis errors/warnings.

---

## 5. Verification Method

To independently reproduce the complete verification suite, run the following commands in PowerShell from `d:\E-player\app`:

```powershell
# 1. Static Analysis
cd d:\E-player\app
flutter analyze

# 2. Local Streaming Daemon Unit Tests (17 tests)
flutter test test/unit/local_streaming_daemon_test.dart

# 3. Cast Service Unit Tests (10 tests)
flutter test test/unit/cast_service_test.dart

# 4. Root Test Delegation Check (10 tests)
flutter test test/cast_service_test.dart

# 5. Full E2E Test Suite (245 tests)
flutter test test/e2e/tier1_feature_coverage_test.dart
flutter test test/e2e/tier2_boundary_corner_test.dart
flutter test test/e2e/tier3_cross_feature_test.dart
flutter test test/e2e/tier4_user_scenarios_test.dart
```

### Invalidation Conditions
- Any static analysis error or warning from `flutter analyze`.
- Any test failure in `test/unit/local_streaming_daemon_test.dart` or `test/unit/cast_service_test.dart`.
- Any session token generated with characters outside `[a-f0-9]` or length != 32.
- Any HTTP request with invalid token returning anything other than 403 Forbidden.
- Any path traversal request returning anything other than 400 Bad Request.
- Any out-of-range byte request returning anything other than 416 Requested Range Not Satisfiable.
