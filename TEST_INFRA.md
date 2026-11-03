# E-Player Test Infrastructure & Quality Gates Specification

## 1. Overview & Verification Philosophy
E-Player is a cross-platform offline media player and AI-Assisted Advanced Bug Debugging (AADB) framework. To ensure zero-stutter playback, rock-solid gesture arbitration, robust Picture-in-Picture (PiP), tokenized offline casting, and strict data integrity, the verification architecture enforces an **opaque-box, mock-free, requirement-derived testing strategy**.

### Core Quality Tenets
1. **Zero Mocking Packages**: No synthetic mock frameworks (`mockito`, `mocktail`). All tests utilize Flutter's native test bindings (`TestDefaultBinaryMessengerBinding`), in-memory SQLite FFI (`sqflite_common_ffi`), real OS temporary files, and live local loopback network servers.
2. **Deterministic Opaque-Box Derivation**: Tests exercise public APIs, widget interactions, protocol streams, and system contracts derived strictly from requirements in `PROJECT.md` and `ORIGINAL_REQUEST.md`.
3. **Strict Offline Invariant**: Zero WAN/cloud communication. Local casting, playback, and metadata operations are validated strictly within local loopback (`127.0.0.1`) and LAN subnets.
4. **Meta-ACH Mutation Hardening**: Critical business logic invariants are subjected to semantic mutant synthesis to guarantee that tests actively detect and kill behavioral regressions.

---

## 2. The 7 E-Player Test Layers
The testing architecture is organized into 7 distinct layers covering the full spectrum of verification:

```
┌────────────────────────────────────────────────────────────────────────┐
│ Layer 7: Full Regression & Metamorphic Testing                         │
│ - Problem Ledger bug reproduction (EP-[CAT]-[NUM])                     │
│ - Metamorphic relations (filter pipeline idempotency, dual-pass parity)│
├────────────────────────────────────────────────────────────────────────┤
│ Layer 6: Offline Invariant Testing                                     │
│ - Zero WAN/cloud network traffic enforcement                           │
│ - Air-gap operation for playback, DSP, vault encryption, and export    │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 5: Stress & Boundary Testing                                     │
│ - Rapid scrub stress (100 rapid seeks/sec), memory leak detection      │
│ - Extreme timeline offsets, large library indexing (10,000 items)      │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 4: End-to-End (E2E) Flow Testing (Tiers 1 - 4)                   │
│ - Tier 1: Feature Coverage (>= 5 tests/feature across 21 core features)│
│ - Tier 2: Boundary & Corner Cases (limits, zeroes, overflows)          │
│ - Tier 3: Cross-Feature Combinations (pairwise interactions)           │
│ - Tier 4: Real-World Application Scenarios (end-to-end user journeys)  │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 3: Service & Integration Testing                                 │
│ - SQLite FFI in-memory transactions, SharedPreferences persistence     │
│ - OS temp filesystem scanning, vault PBKDF2/AES-GCM encryption         │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 2: Unit Testing                                                  │
│ - Pure domain models, color matrices, geometry math, preset algorithms │
├────────────────────────────────────────────────────────────────────────┤
│ Layer 1: Static Analysis & Verification                                │
│ - flutter analyze (0 errors, 0 warnings), flutter_lints compliance     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. The 4 Operational Execution Tiers

To support fast CI/CD feedback as well as comprehensive release qualification, tests are structured into 4 operational tiers:

### Tier 1: Feature Coverage Gate
- **Requirement**: >= 5 distinct, opaque-box test cases for each of the 21 core features defined in `PROJECT.md § Feature Inventory` (minimum 105 tests).
- **Scope**:
  - **Features 1–4 (Hardware Decoders)**: Mode selection (`Auto`, `HW`, `HW+`, `SW`), fallback state machine, hardware acceleration invariant, telemetry HUD stream.
  - **Features 5–10 (Cinematic Gestures)**: Horizontal precision scrub, split vertical brightness/volume sliders, double-tap wing jump (+/-10s), pinch-to-zoom (1.0x–4.0x) and pan clamping, gesture dead-zone arbitration (12px, 1.5x ratio), HUD auto-dismiss coordination (2800ms timer, 800ms linger).
  - **Features 11–15 (Picture-in-Picture)**: Android `AutoEnterPiP` (API 31+), aspect-ratio preservation `[1/2.39, 2.39/1]`, PiP remote media controls (Play/Pause, Seek +/-10s), HUD auto-dismiss on PiP enter, desktop overlay window mode.
  - **Features 16–21 (Tokenized Wireless Casting)**: Multi-protocol sink discovery (Chromecast, DLNA, Miracast, AirPlay), tokenized ephemeral HTTP streaming server, HTTP 206 Partial Content range seeking, tokenized WebVTT subtitle sidecar, bi-directional state sync (seek/volume/play/pause), strict offline LAN invariant.
- **Execution Target**: `flutter test test/e2e/tier1_feature_coverage_test.dart`

### Tier 2: Boundary & Corner Cases Gate
- **Requirement**: >= 5 distinct boundary, limit, and corner test cases for each of the 21 core features (minimum 105 tests).
- **Scope**:
  - Zero, negative, and extreme seek durations (e.g., seek past media end, seek before zero).
  - Viewport edge touch coordinates (0, 0), boundary lines (0.33, 0.35, 0.65, 0.66, 1.0).
  - Maximum zoom scale clamping (4.0x) and minimum clamp (1.0x); panning boundary enforcement at viewport edges with zero black void.
  - Subtitle file parsing with empty cues, malformed timestamps, or 100,000+ characters.
  - HTTP Range boundary requests (`bytes=0-0`, `bytes=last-100`, out-of-range `bytes=999999-999999` returning 416).
  - Invalid, expired, or tampered casting session tokens returning HTTP 403 Forbidden.
  - Extreme aspect ratios (e.g., ultra-wide 32:9 or vertical 9:21) clamped to rational limits `[0.4184, 2.39]`.
- **Execution Target**: `flutter test test/e2e/tier2_boundary_corner_test.dart`

### Tier 3: Cross-Feature Combinations Gate
- **Requirement**: Verification of pairwise subsystem interactions and concurrent states.
- **Scope**:
  - Decoder mode switch during active horizontal timeline scrubbing.
  - Gesture interaction during active Picture-in-Picture or desktop overlay mode.
  - Wireless casting session with concurrent WebVTT subtitle track switching and remote seek.
  - Pinch-to-zoom scaling combined with video rotation (0°, 90°, 180°, 270°).
  - Rapid play/pause toggling while switching audio routes ('tv' vs 'device' private listening).
  - Dynamic fallback triggered during high-framerate scrub.
- **Execution Target**: `flutter test test/e2e/tier3_cross_feature_test.dart`

### Tier 4: Real-World Application Scenarios Gate
- **Requirement**: End-to-end user journeys replicating real-world multi-step workflows.
- **Scope**:
  - **Journey 1: Library Discovery to Playback**: Scanner indexes media and subtitle files -> LibraryProvider updates -> Tap item -> Player mounts -> HUD renders.
  - **Journey 2: Cinematic Playback & Gestures**: Video plays -> Center scrub with timestamp preview -> Wing double-tap jump -> Left/right slider drag -> Pinch-to-zoom and pan.
  - **Journey 3: Picture-in-Picture Seamless Transition**: Playback active -> Home swipe/PiP trigger -> HUD auto-dismiss -> Remote PiP play/pause and seek -> Restore full screen.
  - **Journey 4: Wireless Casting Experience**: Playback active -> Cast button tapped -> Device discovered and selected -> Tokenized server starts -> HTTP 206 range stream initiated -> Remote seek and volume sync -> Disconnect and local resume.
  - **Journey 5: Multi-Format Media Inspection & Video Effects**: 4K HDR MKV media loaded -> Technical NFO generated -> Decoder mode evaluated -> VLC-parity color grading presets applied without raster filtering.
- **Execution Target**: `flutter test test/e2e/tier4_user_scenarios_test.dart`

---

## 4. Shared Mock-Free Test Harness (`EPlayerTestHarness`)
Located at `app/test/helpers/eplayer_test_harness.dart`, the harness provides a cohesive test foundation:

### 4.1 In-Memory SQLite FFI
- Initializes `sqfliteFfiInit()` and configures `databaseFactory = databaseFactoryFfi`.
- Spawns in-memory SQLite databases for library metadata, watch history, media groups, and vault items without touching physical disk files.

### 4.2 Isolated OS Temporary Fixtures
- Creates self-contained temporary directories in `Directory.systemTemp` per test run.
- Generates compliant media binary containers (MP4 `ftypisom`, MKV EBML headers, TS packets).
- Generates companion SubRip (`.srt`) and WebVTT (`.vtt`) subtitle files with standard timecodes.
- Guarantees clean directory deletion upon test completion.

### 4.3 Native Platform Channel Interception
- Intercepts platform channels via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger`:
  - `SystemChannels.platform`: Records `SystemChrome.setPreferredOrientations`, clipboard, and haptic feedback.
  - `com.example.app/system_brightness`: Intercepts and simulates device screen brightness.
  - `com.example.app/pip`: Handles `isPipSupported`, `enterPictureInPictureMode`, `setAutoEnterEnabled`, and allows dispatching simulated platform events (`onPipEntered`, `onPipExited`, `onPipAction`).
  - `com.example.app/media_scanner`: Simulates platform file scanning.
- Keeps an auditable chronological log of all method invocations for assertions.

### 4.4 Real Local HTTP Range Streaming Server
- Binds an ephemeral `HttpServer` to `InternetAddress.loopbackIPv4` (`127.0.0.1`) on an OS-assigned random port.
- Enforces 32-byte cryptographically secure session token validation.
- Serves byte-level HTTP 206 Partial Content range requests (`bytes=start-end`) with `Accept-Ranges: bytes` and `Content-Range`.
- Serves on-the-fly WebVTT subtitle sidecars.

### 4.5 Domain Rule Validators
- `GestureArbitratorValidator`: Verifies 12px dead zone, 1.5x primary/secondary ratio, zone bounds, and panning clamping formulas.
- `PipAspectRatioValidator`: Validates rational aspect ratio clamping `[1/2.39, 2.39/1]`.
- `DecoderModeValidator`: Validates mpv `hwdec` mode translations (`auto`, `yes`, `auto-copy`, `no`) and sliding window stutter fallback logic.
- `OfflineNetworkValidator`: Verifies strict offline constraints (rejection of non-loopback/non-LAN traffic).

---

## 5. Zero-Mocking Invariant & Anti-Cheat Safeguards
1. **No External Mock Libraries**: The project `pubspec.yaml` contains neither `mockito` nor `mocktail`.
2. **Real Business Logic**: Tests execute actual calculation methods, real state machines, real SQLite queries, real HTTP servers, and genuine Flutter widget trees.
3. **Audit Trail**: All test runs are tracked via `progress.md` and summarized in `TEST_READY.md`.

---

## 6. Meta-ACH Mutation Hardening Strategy
Per the AADB specification, tests must be sensitive enough to kill non-equivalent semantic mutants:
1. **Relational Boundary Mutants**: Inverting `>=` to `>`, altering clamp limits (e.g. volume clamp `0.0` to `1.0` mutated to `2.0`), or removing dead-zone 12px thresholds.
2. **Security & Authorization Mutants**: Removing session token checks from casting HTTP handlers or bypassing path traversal checks.
3. **State & Resource Cleanup Mutants**: Removing timer cancellation, failing to close HTTP sockets on disconnect, or omitting queue invalidation on seek.
4. **Color & Geometry Transform Mutants**: Bypassing libmpv native property application and substituting software raster filters.

---

## 7. Verification Commands
To execute the complete quality suite from `D:\E-player\app`:

```powershell
# 1. Static Analysis Gate (must report 0 errors, 0 warnings)
flutter analyze

# 2. Complete Test Suite Execution (100% pass)
flutter test

# 3. Targeted Tier Executions
flutter test test/e2e/tier1_feature_coverage_test.dart
flutter test test/e2e/tier2_boundary_corner_test.dart
flutter test test/e2e/tier3_cross_feature_test.dart
flutter test test/e2e/tier4_user_scenarios_test.dart

# 4. Baseline Unit & Service Tests
flutter test test/cast_service_test.dart
flutter test test/video_rotation_test.dart
flutter test test/media_scanner_search_test.dart
flutter test test/features/video_effects_test.dart
```
