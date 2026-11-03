# Project: E-Player Cross-Platform Offline Media Player & AADB Framework

## Architecture
E-Player is built on Flutter (`app/`) backed by `media_kit`/`libmpv` for high-performance offline media playback and a native C++ engine (`native/engine/`) for AI-assisted image enhancement and frame interpolation. State is managed via `provider`, with local persistence in SQLite (`sqflite` with `sqflite_common_ffi` for tests) and `shared_preferences`.

### Core Architectural Layers:
1. **Presentation Layer (`app/lib/features/*/ui/`)**:
   - `PlayerScreen`: Unified video playback viewport, HUD controls, gestures, and telemetry overlays.
   - `CinematicGestureEngine`: Modular gesture arbitration layer with directional dead-zone gating, high-precision seek scrub, split brightness/volume sliders, and clamped pinch-to-zoom.
   - `CastSheet` & `CastingScreen`: Wireless sink selection radar, remote playback dock, and transcode mode controls.
2. **Domain & Services Layer (`app/lib/features/*/domain/`)**:
   - `DecoderPipelineService`: Capability detection, mpv property bindings (`hwdec`, `hwdec-current`), drop-frame monitoring (`vo-drop-frame-count`), and dynamic fallback pipeline (`HW` -> `HW+` -> `SW`).
   - `PipService`: Picture-in-Picture lifecycle, `AutoEnterPiP` coordination, aspect-ratio calculation, and desktop overlay mode.
   - `CastService`: Sink discovery (mDNS/SSDP), protocol negotiation (Chromecast, DLNA, Miracast, AirPlay), and bidirectional state synchronization.
   - `LocalStreamingDaemon`: Tokenized ephemeral LAN HTTP streaming server supporting HTTP 206 Range requests and WebVTT subtitle sidecars.
3. **Hardware & Native Integration (`app/lib/core/` & `app/android/`)**:
   - `MethodChannel` (`com.example.app/pip` & `com.example.app/system_brightness`): Native platform bindings for Android `enterPictureInPictureMode`, `AutoEnterPiP`, and screen brightness.
   - `libmpv` Native FFI: Direct hardware acceleration inside mpv without redundant Flutter raster filtering.
4. **Testing & Quality Assurance Architecture (`app/test/`)**:
   - 7 Test Layers: Static, Unit, Integration, E2E, Stress, Offline, Regression.
   - `EPlayerTestHarness`: Mock-free testing infrastructure with in-memory SQLite FFI and simulated platform channels.
   - Meta-ACH Mutation Hardening: Mutation-guided compliance verification to kill non-equivalent mutants per bug fix.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Decoder Mode Selection | Manual selection between Auto, HW, HW+, and SW via libmpv `hwdec` | M1 | Survey |
| 2 | Dynamic Fallback Pipeline | Automated fallback from HW -> HW+ -> SW on decode error or excessive frame drops (>10 in 2s) | M1 | Survey |
| 3 | Hardware Acceleration Invariant | Color grading and geometric transforms remain hardware-accelerated inside libmpv without Flutter raster filtering | M1 | Survey |
| 4 | Decoder Telemetry HUD | Real-time diagnostic HUD displaying active decoder (`hwdec-current`), video codec, drop frame counter, and bitrate | M1 | Survey |
| 5 | Horizontal Precision Scrub | Center horizontal drag scrubs timeline with high-precision timestamp seek preview and AI queue invalidation | M2 | Survey |
| 6 | Split Brightness/Volume Sliders | Vertical drag on left 35% adjusts brightness; right 35% adjusts volume with visual HUD feedback | M2 | Survey |
| 7 | Double-Tap Wing Jump | Left 33% double tap seeks -10s; right 33% seeks +10s with ripple animations and boundary clamping | M2 | Survey |
| 8 | Pinch-to-Zoom & Pan Bounds | Two-finger pinch scales 1.0x-4.0x with focal-point tracking; panning strictly clamped to avoid black voids | M2 | Survey |
| 9 | Gesture Dead-Zone Arbitration | Directional dead-zone (12px, 1.5x primary/secondary ratio) preventing diagonal swipe crosstalk | M2 | Survey |
| 10 | HUD Auto-Dismiss Coordination | Pauses auto-dismiss timer during active gesture; resets to 2800ms with 800ms feedback lingering | M2 | Survey |
| 11 | Android AutoEnterPiP | Automatically transitions full-screen video to system PiP on Home swipe when `isPlaying == true` (API 31+) | M3 | Survey |
| 12 | Aspect Ratio Preservation in PiP | Sets PiP rational aspect ratio matching video stream native dimensions, clamped to [1/2.39, 2.39/1] | M3 | Survey |
| 13 | PiP Remote Media Controls | RemoteAction intents for Play, Pause, Seek +/-10s in system PiP window | M3 | Survey |
| 14 | HUD Auto-Dismiss on PiP Enter | Immediately clears Flutter UI sheets, controls, overlays on PiP entry for clean video surface | M3 | Survey |
| 15 | Desktop Overlay Window Mode | Floating borderless always-on-top window on Windows/macOS with aspect-ratio locked resize and coordinate restoration | M3 | Survey |
| 16 | Multi-Protocol Sink Discovery | Local LAN discovery of Chromecast, DLNA, Miracast, AirPlay renderers via mDNS/SSDP | M4 | Survey |
| 17 | Tokenized Local Streaming Server | Ephemeral LAN HTTP server serving local media via `/cast/{session_token}/{media_id}/stream` | M4 | Survey |
| 18 | HTTP 206 Partial Content Range | Supports seeking on remote TV receiver via HTTP Range byte requests | M4 | Survey |
| 19 | Tokenized Subtitle Sidecar | Converted WebVTT subtitle stream delivered to remote sink | M4 | Survey |
| 20 | Bi-Directional State Sync | Synchronizes Play/Pause, Seek, Volume between mobile app and remote receiver with heartbeat monitoring | M4 | Survey |
| 21 | Strict Offline Invariant | Zero WAN/cloud communication during casting or local playback; strictly offline local protocols | M4 | Survey |
| 22 | 100% E2E Test Suite (Tiers 1-4) | Comprehensive opaque-box test suite verifying all 21 features with >= 5 tests per feature and boundary/combination tests | M5 | Survey |
| 23 | Meta-ACH Mutation Hardening | Semantic business-logic mutant synthesis and verification (mutants killed by regression tests) | M5 | Survey |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| E2E | E2E Testing Track | Test harness (`EPlayerTestHarness`), test infrastructure (`TEST_INFRA.md`), and Tiers 1-4 opaque-box test suite covering all 21 features; publish `TEST_READY.md` | none | DONE (TEST_INFRA.md, TEST_READY.md, 245/245 tests passed, 0 analyze issues) |
| M1 | Phase 1 Hardware/HW+ Decoders | `DecoderPipelineService`, dynamic fallback cascade (HW -> HW+ -> SW), mpv property monitoring (`hwdec-current`, `vo-drop-frame-count`), zero-stutter playback, hardware acceleration invariant | none | DONE (DecoderPipelineService, decoder_models.dart, 21 unit tests, 87 subsystem tests, 5-agent gate passed) |
| M2 | Phase 3 Cinematic Gesture Engine | `CinematicGestureEngine`, `GestureArbitrator` state machine (12px dead zone), high-precision scrub with seek preview, split brightness/volume sliders, double-tap wing jump, bounded pinch-to-zoom | none | DONE (gate passed) |
| M3 | Phase 6 Native Picture-in-Picture | `PipService`, Android `AutoEnterPiP` (API 31+), `MainActivity.kt` PiP channel, aspect-ratio preservation [1/2.39, 2.39/1], PiP remote actions, Desktop overlay mode, HUD auto-dismiss | M1, M2 | DONE (gate passed) |
| M4 | Phase 11 Tokenized Wireless Casting | `LocalStreamingDaemon` (LAN HTTP server, session token authentication, HTTP 206 Range requests), WebVTT subtitle muxing, mDNS/SSDP discovery, bi-directional state sync, strict offline invariant | none | DONE (gate passed) |
| M5 | Final Milestone: 100% E2E Pass & Meta-ACH Hardening | Pass 100% of E2E tests (Tiers 1-4) upon `TEST_READY.md`, Tier 5 adversarial coverage hardening, Meta-ACH mutation killing, clean git status | E2E, M1, M2, M3, M4 | DONE (245/245 E2E passed, 218/218 unit passed, 0 analyze issues, 4 Meta-ACH mutants killed) |

---

## Interface Contracts

### `DecoderPipelineService` ↔ `PlayerScreen` & `libmpv`
- **Class**: `DecoderPipelineService extends ChangeNotifier`
- **Methods**:
  - `Future<void> initialize(Player player)`: Attaches to active player, listens to `player.stream.error` and `player.stream.videoParams`.
  - `Future<DecoderSwitchResult> setMode(DecoderMode mode)`: Applies mode (`auto`, `hw`, `hwPlus`, `sw`) to `libmpv` property `hwdec` (`auto`, `yes`, `auto-copy`, `no`).
  - `Stream<DecoderTelemetry> get telemetryStream`: Emits `{ requestedMode, activeDecoder, codec, droppedFrames, fps, bitrate }`.
  - `void triggerFallback(String reason)`: Gracefully downgrades decoder tier while preserving playback timestamp (`tolerance <= 250ms`).
- **Data Types**:
  - `enum DecoderMode { auto, hw, hwPlus, sw }`
  - `class DecoderTelemetry { final DecoderMode requestedMode; final String activeDecoder; final String codec; final int droppedFrames; final double fps; }`
  - `class DecoderSwitchResult { final bool success; final DecoderMode activeMode; final String backend; final String? fallbackReason; }`

### `CinematicGestureEngine` ↔ `PlayerScreen`
- **Class**: `CinematicGestureEngine`
- **Methods**:
  - `void handleScaleStart(ScaleStartDetails details, Size viewportSize)`
  - `void handleScaleUpdate(ScaleUpdateDetails details, Size viewportSize, Duration currentPosition, Duration totalDuration)`
  - `void handleScaleEnd(ScaleEndDetails details)`
  - `void handleDoubleTapDown(TapDownDetails details, Size viewportSize, Duration currentPosition, Duration totalDuration)`
- **Streams / Callbacks**:
  - `Stream<GestureFeedbackEvent> get feedbackEvents`: Emits `{ type: scrub|brightness|volume|zoom|jump, value: double, label: String, position: Duration? }`.
  - `Stream<SeekCommitEvent> get seekCommitEvents`: Emits target seek `Duration` to execute on player.
  - `Stream<bool> get controlsInhibited`: Emits whether HUD auto-dismiss timer should be paused.
- **Invariants**:
  - 12px dead-zone threshold and `|primary| >= 1.5 * |secondary|` required to commit.
  - Panning offsets strictly clamped: `|Tx| <= (scale - 1) * width / 2`, `|Ty| <= (scale - 1) * height / 2`.

### `PipService` ↔ `PlayerScreen` & `MainActivity.kt`
- **Class**: `PipService extends ChangeNotifier`
- **Platform Channel**: `MethodChannel('com.example.app/pip')`
- **Methods**:
  - `Future<bool> isPipSupported()`
  - `Future<bool> enterPip({required int videoWidth, required int videoHeight, required bool isPlaying})`
  - `Future<void> setAutoEnterEnabled(bool enabled, {int? videoWidth, int? videoHeight})`
  - `Future<void> toggleDesktopOverlay({required bool enable, Size? initialSize})`
- **Events (from Platform Channel)**:
  - `onPipEntered`: Triggers instant dismissal of HUD overlays and dialogs.
  - `onPipExited`: Restores standard full-screen UI controls.
  - `onPipAction(String action)`: Receives `'play'`, `'pause'`, `'seek_forward_10'`, `'seek_rewind_10'`.

### `LocalStreamingDaemon` & `CastService`
- **Class**: `LocalStreamingDaemon`
- **Methods**:
  - `Future<String> startSession({required String filePath, String? subtitlePath})`: Binds `HttpServer` to local Wi-Fi interface, generates 32-byte secure session token, returns base URL: `http://{local_ip}:{port}/cast/{session_token}/`.
  - `Future<void> stopSession()`: Terminates HTTP server, closes file streams.
  - `Stream<StreamingClientTelemetry> get telemetry`: Emits active client requests, bytes transferred, response status codes.
- **Security Invariants**:
  - Strictly offline LAN IP binding (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`, `127.0.0.1`).
  - Strict token validation on every HTTP request; 403 Forbidden on invalid or missing tokens.
  - Canonical file path validation; rejection of path traversal (`..`).
  - Full HTTP 206 Partial Content support with `Accept-Ranges: bytes`, `Content-Range`, and `Content-Length`.

---

## Code Layout
- `app/lib/features/player/domain/decoder_pipeline_service.dart`: Phase 1 Hardware/HW+ dynamic fallback service.
- `app/lib/features/player/domain/decoder_models.dart`: Decoder enums, telemetry data classes, switch results.
- `app/lib/features/player/ui/cinematic_gesture_engine.dart`: Phase 3 gesture arbitration, touch velocity gating, bounded zoom.
- `app/lib/features/player/ui/gesture_models.dart`: Gesture state, feedback events, dead-zone math.
- `app/lib/features/pip/domain/pip_service.dart`: Phase 6 Picture-in-Picture coordinator.
- `app/lib/features/pip/data/pip_platform_bridge.dart`: Phase 6 method channel bindings.
- `app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`: Android native `enterPictureInPictureMode`, `AutoEnterPiP`, RemoteActions.
- `app/lib/features/casting/domain/local_streaming_daemon.dart`: Phase 11 tokenized HTTP streaming server.
- `app/lib/features/casting/domain/cast_service.dart`: Phase 11 multi-protocol casting service.
- `app/test/helpers/eplayer_test_harness.dart`: Shared mock-free test harness.
- `app/test/e2e/`: End-to-end tests across Tiers 1-4.
- `app/test/unit/`: Subsystem unit tests.
- `app/test/stress/`: Rapid seek, boundary, and memory leak tests.
- `app/test/offline/`: 100% offline invariant verification tests.
