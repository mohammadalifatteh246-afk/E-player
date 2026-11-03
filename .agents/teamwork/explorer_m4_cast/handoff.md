# Milestone 4 Technical Analysis Report & Worker Implementation Blueprint
**Phase 11: Tokenized Wireless Casting & Local Streaming Daemon**

---

## 1. Observation

### 1.1 Existing Codebase State in `app/lib/features/casting/`
- Directory `app/lib/features/casting/domain/` contains:
  - `cast_service.dart` (462 lines): Defines `CastProtocol`, `CastTranscodeProfile`, `CastDevice`, `CastSession`, and `CastService extends ChangeNotifier`.
  - Missing: `app/lib/features/casting/domain/local_streaming_daemon.dart` (does not exist).
  - Missing: `app/lib/features/casting/domain/cast_models.dart` (does not exist; models are currently colocated inside `cast_service.dart`).
- Directory `app/lib/features/casting/ui/` contains:
  - `cast_sheet.dart` (1,006 lines): Contains `CastSheet extends StatefulWidget`, implementing a cyberpunk-styled bottom sheet with discovery radar, device bento cards, protocol filters, transcode tags, and playback dock.
  - `casting_screen.dart` (1,094 lines): Contains `NetworkStreamScreen` (alias `CastingScreen`) for manual URL streaming.

### 1.2 Integration in `app/lib/features/player/ui/player_screen.dart`
- Top action bar (lines 1307–1350):
  ```dart
  Consumer<CastService>(
    builder: (context, castService, _) {
      final isCasting = castService.connectedDevice != null;
      return IconButton(
        icon: Stack(...),
        tooltip: isCasting
            ? 'Casting to ${castService.connectedDevice!.name}'
            : 'Cast Media (Wireless Display)',
        onPressed: () {
          CastSheet.show(
            context,
            player: _player,
            mediaTitle: p.basename(widget.mediaPath),
          );
        },
      );
    },
  )
  ```
  `CastSheet.show(...)` is called inline directly from `onPressed`.
  There is currently no dedicated private method `_openCastSheet()`.
- Active Cast Banner (lines 1450–1552):
  A floating HUD banner displays active streaming sink status (`Streaming to ${connected.name}`, `ACTIVE SINK`, protocol label, transcode profile, ping ms, and `Disconnect` button).
- HUD Auto-Dismiss Coordination:
  In `player_screen.dart`, `_controlsTimer` manages the 2800ms auto-dismiss. Opening `CastSheet` currently does not explicitly pause `_controlsTimer`, which conflicts with Feature 10 / Test 3.11 requirement that modal interaction inhibits auto-dismiss.

### 1.3 Test Harness & Contracts in `app/test/helpers/eplayer_test_harness.dart`
- `EphemeralCastServer` (lines 23–45, 265–369):
  - Spawns live `HttpServer.bind(InternetAddress.loopbackIPv4, 0)`.
  - Validates session tokens: requires URL path `/cast/{sessionToken}/...`. Rejects invalid or missing tokens with `403 Forbidden`.
  - Rejects path traversal (`..`) with `400 Bad Request`.
  - WebVTT endpoint: `/cast/{sessionToken}/subtitles/{track_id}.vtt` returning `Content-Type: text/vtt; charset=utf-8` and `Cache-Control: no-cache`.
  - Stream endpoint: `/cast/{sessionToken}/stream` with HTTP 206 Partial Content Range parsing:
    - Parses `Range: bytes=start-end` and open-ended `bytes=start-`.
    - Returns `416 Requested Range Not Satisfiable` with `Content-Range: bytes */$totalSize` if `start > end || start >= totalSize || end >= totalSize`.
    - Delivers `206 Partial Content` with `Accept-Ranges: bytes`, `Content-Range: bytes $start-$end/$totalSize`, and exact `Content-Length: end - start + 1`.
    - Delivers `200 OK` on requests without Range header or with malformed range syntax.
- `OfflineSecurityValidator` (lines 528–549):
  - `isStrictlyOfflineUri(Uri uri)` validates that hosts are strictly `localhost`, `127.0.0.1`, `192.168.x.x`, `10.x.x.x`, or `172.16-31.x.x`. Rejects public WAN IPs (e.g. `8.8.8.8`) and cloud domains.
  - `isSessionTokenValid(String token)` validates `token.length == 32` matching `RegExp(r'^[a-zA-Z0-9_-]+$')`.

### 1.4 Test Suite Status
- Command: `cd d:\E-player\app; flutter test test/cast_service_test.dart`
  - Output: 5/5 tests passed (1s).
- Command: `cd d:\E-player\app; flutter analyze`
  - Output: `No issues found! (ran in 94.3s)`, 0 errors, 0 warnings.
- E2E Tests covering Features 16–21:
  - `tier1_feature_coverage_test.dart` (lines 700–975) covers Tests 16.1–21.5.
  - `tier2_boundary_corner_test.dart` (lines 640–865) covers Tests 16.1–21.5 boundary cases.
  - `tier3_cross_feature_test.dart` (Tests 3.3, 3.7, 3.11, 3.13, 3.15, 3.18, 3.25) validates cross-feature interactions.
  - `tier4_user_scenarios_test.dart` (Test 4.4, 4.10) validates full casting user journey.

---

## 2. Logic Chain

1. **Missing Production Daemon**:
   While `EphemeralCastServer` exists inside `app/test/helpers/eplayer_test_harness.dart` for test orchestration, there is no corresponding production runtime implementation in `app/lib/features/casting/domain/`.
   Per `PROJECT.md § Interface Contracts` and `ORIGINAL_REQUEST.md § R1`, the application requires a production-grade `LocalStreamingDaemon` in `app/lib/features/casting/domain/local_streaming_daemon.dart`.

2. **Domain Model Extraction and Parity**:
   Currently, `CastProtocol`, `CastTranscodeProfile`, `CastDevice`, and `CastSession` reside inside `cast_service.dart`.
   Creating `app/lib/features/casting/domain/cast_models.dart` to house all casting models (`CastProtocol`, `CastTranscodeProfile`, `CastDevice`, `CastPlaybackState`, `CastSessionState`, `CastSession`, `StreamingClientTelemetry`) modularizes the feature.
   To prevent breaking existing consumers (`main.dart`, `eplayer_test_harness.dart`, `cast_sheet.dart`, `casting_screen.dart`, all test suites), `cast_service.dart` must export `cast_models.dart`.

3. **Daemon Architectural Alignment**:
   `LocalStreamingDaemon` must mirror the security, RFC compliance, and range semantics proven in `EphemeralCastServer` and `OfflineSecurityValidator`:
   - Bind to private LAN interface (e.g., `192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`) or loopback (`127.0.0.1`) on port `0`.
   - Provide an optional `bindAddress` parameter for deterministic testing against loopback.
   - Generate cryptographically secure 32-character tokens (`Random.secure()` generating 16 bytes encoded as 32 hex chars), fully conforming to `OfflineSecurityValidator.isSessionTokenValid()`.
   - Strictly reject missing or mismatched tokens with HTTP 403 Forbidden.
   - Strictly reject canonical path traversals (`..`) with HTTP 400 Bad Request.
   - Parse HTTP 206 Range headers (`bytes=start-end`, `bytes=start-`), clamp start/end, return HTTP 416 for invalid bounds, and stream byte slices using `file.openRead(start, end + 1)`.
   - On-the-fly SubRip (.srt) to WebVTT (.vtt) conversion for sidecar subtitle delivery with `text/vtt; charset=utf-8` header and `Cache-Control: no-cache`.
   - Expose a broadcast `telemetryStream` emitting `StreamingClientTelemetry`.

4. **Service Integration**:
   `CastService` should instantiate and manage the lifecycle of `LocalStreamingDaemon`:
   - In `connect(device, {mediaTitle, mediaPath, subtitlePath})`: if `mediaPath` is provided and the file exists, start `LocalStreamingDaemon.startSession(...)`, assigning the resulting `streamUrl` and `subtitleUrl` to `CastSession`.
   - In `disconnect()`: terminate `LocalStreamingDaemon.stopSession()`.
   - In `dispose()`: ensure `LocalStreamingDaemon.dispose()` cleanly releases socket and file handles.

5. **Player Screen UI Refinement**:
   - Refactor `CastSheet.show(...)` into `Future<void> _openCastSheet() async`.
   - In `_openCastSheet()`, pause HUD auto-dismiss: `_controlsTimer?.cancel()`.
   - Await `CastSheet.show(...)`.
   - In `finally`, if `mounted`, resume HUD auto-dismiss: `_startControlsTimer()`.
   - Hook `_openCastSheet` to the top bar Cast button.

---

## 3. Caveats

- **Network Interface Binding on Host**: On systems with multiple virtual adapters (e.g. WSL, Docker, Hyper-V, VPN tunnels), `NetworkInterface.list()` may enumerate virtual adapters. `LocalStreamingDaemon` must inspect adapter subnets to select physical Wi-Fi/Ethernet addresses (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`) and fall back to `InternetAddress.loopbackIPv4` when no private LAN adapter is available.
- **SubRip (.srt) Conversion**: Assumes UTF-8 encoding for SRT subtitle files. If an SRT file contains non-UTF-8 characters, `utf8.decode(..., allowMalformed: true)` must be used to prevent unhandled exceptions.
- **Mock-Free Testing Invariant**: Per `PROJECT.md` and `TEST_INFRA.md`, tests must never use mockito/mocktail; all tests must instantiate real `LocalStreamingDaemon` instances bound to loopback sockets with genuine temp media fixtures.

---

## 4. Conclusion & Complete Implementation Plan for Worker

The worker should execute the following discrete, surgical steps:

### Step 1: Create `app/lib/features/casting/domain/cast_models.dart`
Define:
- `enum CastProtocol`: `chromecast`, `airplay`, `dlna`, `miracast` with labels, descriptions, and hex colors.
- `enum CastTranscodeProfile`: `directPassthrough`, `audioRemux`, `videoTranscode`, `fullRemux` with labels and descriptions.
- `enum CastSessionState`: `disconnected`, `discovering`, `connecting`, `connected`, `reconnecting`, `error`.
- `class CastDevice`: Fields `id`, `name`, `protocol`, `model`, `ipAddress`, `signalPercentage`, `resolutionCapability`, `isConnected`, `isConnecting`, `metadata`. Method `copyWith(...)`.
- `class CastPlaybackState`: Fields `isPlaying`, `position`, `duration`, `volume`, `isMuted`, `audioRoute`. Method `copyWith(...)`.
- `class CastSession`: Fields `device`, `mediaTitle`, `mediaPath`, `startedAt`, `transcodeProfile`, `streamUrl`, `subtitleUrl`, `position`, `duration`, `isPlaying`, `volume`, `isMuted`, `audioRoute`, `bitrateMbps`, `pingMs`, `connectionState`.
- `class StreamingClientTelemetry`: Fields `clientIp`, `path`, `statusCode`, `bytesTransferred`, `duration`, `timestamp`, `rangeHeader`.

### Step 2: Implement `app/lib/features/casting/domain/local_streaming_daemon.dart`
Implement `LocalStreamingDaemon`:
- Methods:
  - `Future<String> startSession({required String filePath, String? subtitlePath, InternetAddress? bindAddress, int port = 0})`:
    - Validates offline address using private subnet checks.
    - Generates 32-character hex session token via `Random.secure()`.
    - Converts `.srt` to `.vtt` if subtitle path is `.srt`, or reads `.vtt` directly.
    - Binds `HttpServer.bind(bindAddress ?? resolvedAddress, port)`.
    - Handles incoming HTTP requests:
      - 403 Forbidden on missing/invalid token (`segments.length < 2 || segments[0] != 'cast' || segments[1] != _sessionToken`).
      - 400 Bad Request on path traversal (`path.contains('..')`).
      - Subtitle endpoint: `/cast/{token}/subtitles/{track_id}.vtt` -> 200 OK with `text/vtt; charset=utf-8`.
      - Stream endpoint: `/cast/{token}/stream` -> HTTP 206 Partial Content Range parsing:
        - Sets `Accept-Ranges: bytes`.
        - Parses `Range: bytes=start-end` and `bytes=start-`.
        - Clamps bounds; returns 416 on `start > end || start >= totalSize || end >= totalSize`.
        - Delivers 206 with `Content-Range: bytes $start-$end/$totalSize`, `Content-Length`, `video/mp4` (or container mime type), streaming bytes via `file.openRead(start, end + 1)`.
        - Delivers 200 OK on full request or malformed range header.
      - Emits `StreamingClientTelemetry` to `_telemetryController`.
  - `Future<void> stopSession()`: Closes server with `force: true`, clears file references.
  - `void dispose()`: Invokes `stopSession()`, closes `_telemetryController`.
  - Helper functions: `isPrivateLanIp(String ip)`, `convertSrtToVtt(String srt)`.

### Step 3: Refactor `app/lib/features/casting/domain/cast_service.dart`
- Replace inline model definitions with `export 'cast_models.dart';` and `import 'cast_models.dart';`.
- Import `local_streaming_daemon.dart`.
- Add field: `LocalStreamingDaemon? _streamingDaemon`.
- Getter: `LocalStreamingDaemon get streamingDaemon => _streamingDaemon ??= LocalStreamingDaemon();`
- Update `connect(...)`:
  - When `mediaPath != null && mediaPath.isNotEmpty && File(mediaPath).existsSync()`, start `_streamingDaemon!.startSession(filePath: mediaPath, subtitlePath: subtitlePath)`.
  - Pass `streamUrl` and `subtitleUrl` to `CastSession`.
- Update `disconnect()`:
  - Await `_streamingDaemon?.stopSession()`.
- Update `dispose()`:
  - Dispose `_streamingDaemon`.

### Step 4: Refactor `app/lib/features/player/ui/player_screen.dart`
- In `_PlayerScreenState`:
  - Add method:
    ```dart
    Future<void> _openCastSheet() async {
      _controlsTimer?.cancel();
      try {
        await CastSheet.show(
          context,
          player: _player,
          mediaTitle: p.basename(widget.mediaPath),
        );
      } finally {
        if (mounted) {
          _startControlsTimer();
        }
      }
    }
    ```
  - In the Cast `IconButton` `onPressed`:
    Replace inline `CastSheet.show(...)` with `_openCastSheet`.

### Step 5: Create Unit Tests in `app/test/unit/local_streaming_daemon_test.dart`
Create a comprehensive test suite (13+ tests) verifying:
1. `startSession` binds ephemeral loopback port and generates valid 32-char hex token.
2. `streamUrl` and `subtitleUrl` conform to `/cast/{token}/stream` and `/cast/{token}/subtitles/...`.
3. Token validation: 403 Forbidden on invalid token.
4. Token validation: 403 Forbidden on missing token.
5. Path traversal: 400 Bad Request on `..` traversal attempt.
6. HTTP 206: range `bytes=0-1023` returns 206 with `Content-Range: bytes 0-1023/{total}` and 1024 bytes.
7. HTTP 206: open-ended `bytes=100-` delivers remaining content.
8. HTTP 206: boundary `bytes=0-0` and `bytes=last-last`.
9. HTTP 416: out-of-range `bytes=999999-999999` returns 416 with `Content-Range: bytes */{total}`.
10. Malformed range header: falls back to 200 OK full content.
11. WebVTT sidecar delivery: returns 200 OK with `text/vtt; charset=utf-8`.
12. On-the-fly SRT to WebVTT conversion: transforms comma timecodes `00:00:01,000` to period `00:00:01.000`.
13. Telemetry broadcast stream emits request duration and byte count.
14. `stopSession()` terminates HTTP server and releases port.

### Step 6: Expand `app/test/unit/cast_service_test.dart`
Retain existing 5 unit tests, and add:
- Multi-protocol sink discovery verification (Chromecast, AirPlay, DLNA, Miracast).
- Transcode profile resolution test for `.mp4`, `.mkv`, `.avi`.
- Real `LocalStreamingDaemon` session startup on `connect(...)` with temp video file.
- State synchronization: remote volume clamping, mute toggling, audio route switching ('tv' vs 'device').
- Background telemetry jitter timer test.
- Graceful disconnect and teardown.

---

## 5. Verification Method

To independently verify the implementation, execute the following commands from `D:\E-player\app`:

1. **Static Analysis Gate**:
   ```powershell
   flutter analyze
   ```
   *Expected Result*: `No issues found!`, 0 errors, 0 warnings.

2. **Dedicated Unit Tests**:
   ```powershell
   flutter test test/unit/local_streaming_daemon_test.dart
   flutter test test/unit/cast_service_test.dart
   ```
   *Expected Result*: 100% tests passing.

3. **E2E Feature Verification Gates (Features 16–21)**:
   ```powershell
   # Tier 1 Feature Coverage
   flutter test test/e2e/tier1_feature_coverage_test.dart --name "Feature 16|Feature 17|Feature 18|Feature 19|Feature 20|Feature 21"

   # Tier 2 Boundary & Corner Cases
   flutter test test/e2e/tier2_boundary_corner_test.dart --name "Feature 16|Feature 17|Feature 18|Feature 19|Feature 20|Feature 21"

   # Tier 3 Cross-Feature Combinations
   flutter test test/e2e/tier3_cross_feature_test.dart

   # Tier 4 Real-World Application Scenarios
   flutter test test/e2e/tier4_user_scenarios_test.dart
   ```
   *Expected Result*: 245/245 tests pass with zero failures.

4. **Invalidation Conditions**:
   - Any test using `mockito` or synthetic mock packages.
   - Any HTTP server listening on public interfaces or sending requests to WAN/cloud IPs.
   - Any session token with length other than 32 characters or invalid character set.
   - Any failure to return HTTP 416 for out-of-range byte requests.
   - Any failure to return HTTP 403 on missing or invalid session tokens.
   - Any failure to reject `..` path traversal.
