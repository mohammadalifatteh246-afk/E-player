# E-Player Codebase Architecture Survey Report

## 1. Observation

### 1.1 Repository Structure & Git Status
- **Repository Root**: `D:\E-player`
  - Flutter Application Directory: `D:\E-player\app`
  - Native C++ Engine Directory: `D:\E-player\native\engine`
  - Specifications & Blueprints: `D:\E-player\Documents`
- **Git Status**:
  - Command: `git status` in `D:\E-player`
  - Branch: `main` (up to date with `origin/main`)
  - Working tree: Clean, with only untracked `.agents/` directory present.
  - Recent commit: `dff8c8a fix(core): timestamp collision in MediaGroupService, casting telemetry sink overlay, and static analysis lints`.
- **Static Analysis & Test Verification**:
  - `flutter analyze` in `D:\E-player\app`: `No issues found! (ran in 24.9s)`. Zero errors, zero warnings.
  - `flutter test` in `D:\E-player\app`: `00:13 +67: All tests passed!`. Baseline 67/67 passing tests across 12 test suites.

### 1.2 Dependencies & Media Engine Bindings
- **`app/pubspec.yaml`**:
  - SDK: `^3.13.4`
  - Playback Engine: `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7`
  - State Management: `provider: ^6.1.5+1`
  - Native FFI: `ffi: ^2.2.0`
  - Local Storage & Database: `sqflite: ^2.4.4`, `sqflite_common_ffi: ^2.4.3`, `shared_preferences: ^2.5.5`, `path_provider: ^2.1.6`
  - Cryptography: `crypto: ^3.0.7`, `encrypt: ^5.0.3`
  - Platform/Device: `device_info_plus: ^13.2.0`
- **Player & `libmpv` Integration**:
  - Initialized in `app/lib/main.dart` lines 26–30:
    ```dart
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint('[E-Player] MediaKit init failed: $e');
    }
    ```
  - Player instance instantiated in `app/lib/features/player/ui/player_screen.dart` lines 124–127:
    ```dart
    _player = Player(
      configuration: const PlayerConfiguration(libass: true),
    );
    _controller = VideoController(_player);
    ```
  - `libmpv` property dispatch via `_player.platform.setProperty(key, value)`:
    - Decoder: `setProperty('hwdec', hwdecValue)` in `player_screen.dart:400`
    - Video Filters: `setProperty('vf', vfString)` in `video_effects_service.dart:62`
    - Audio Filters: `setProperty('af', afString)` in `audio_studio_sheet.dart:81`
    - Color Grading: `setProperty('contrast'/'brightness'/'saturation'/'gamma'/'hue', val)` in `video_effects_service.dart:50-54`

### 1.3 State of Phase 1: Hardware / HW+ / Software Decoders
- In `app/lib/features/player/ui/player_screen.dart` lines 388–434:
  - Mode selection is implemented as a manual modal sheet menu with options `['Auto', 'HW', 'HW+', 'SW']`.
  - Property mapping:
    - `'HW'` -> `'yes'`
    - `'HW+'` -> `'auto-copy'`
    - `'SW'` -> `'no'`
    - `'Auto'` -> `'auto'`
  - Telemetry HUD (`player_screen.dart:1647`):
    ```dart
    'Decoder: $_decoderMode\n'
    ```
    This prints only the local Dart string state `_decoderMode`, NOT the active decoder reported by `libmpv` (`hwdec-current` / `video-codec`).
  - In `app/lib/features/settings/domain/settings_provider.dart` lines 8–15:
    - Contains defaults: `_hwAcceleration = true`, `_decodingMode = 'HW+'`, `_zeroCopyGpu = true`, `_dynamicResSwitching = true`.
  - **Absence**: There is NO automated dynamic fallback pipeline. If hardware decoding crashes, encounters corrupt frames, or fails to decode 4K/HEVC/AV1 streams, there is no stream error listener or automatic step-down from `HW (yes)` -> `HW+ (auto-copy)` -> `SW (no)`.

### 1.4 State of Phase 3: Cinematic Gesture Engine
- In `app/lib/features/player/ui/player_screen.dart` lines 232–340 & 987–993:
  - All gestures are processed within a single `GestureDetector` attached to the entire screen.
  - Multi-touch handling:
    - `onDoubleTapDown` (lines 232–256): Left 33% rewinds 10s, right 33% fast-forwards 10s, center toggles play/pause.
    - `onScaleStart` / `onScaleUpdate` / `onScaleEnd` (lines 258–340):
      - Single-pointer:
        - X < 30% width: `_brightness = (_brightness - (dy * 0.005)).clamp(0.0, 1.0)`.
        - X > 70% width: `_volume = (_volume - (dy * 0.5)).clamp(0.0, 100.0); _player.setVolume(_volume);`.
        - Center 40%: `_player.seek(_seekStartPos + Duration(seconds: (dx * 0.5).toInt()));`.
      - Two-pointer:
        - Pinch zoom: `_scale = (_baseScale * details.scale).clamp(1.0, 4.0)` with pan offset `_offset`.
        - Swipe rate: adjusts playback rate if vertical drag > 30px without scale change.
  - **Absence**:
    - Brightness adjustments are strictly mock: only alters an in-memory double `_brightness` and displays a transient HUD overlay; no platform channel or system screen brightness API is called.
    - Scrub seek does not provide high-precision timestamp previewing, scrub velocity scaling, or fine-grained scrubbing bar.
    - Gesture conflicts exist between 1-finger drag, 2-finger scale, single tap, and double tap.
    - No modular gesture engine or state machine exists outside of `player_screen.dart`.

### 1.5 State of Phase 6: Native Picture-in-Picture
- In `app/android/app/src/main/AndroidManifest.xml` line 21:
  - `<activity ... android:supportsPictureInPicture="true" ... android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode">` is declared.
- In `app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`:
  - Only one `MethodChannel` exists: `"com.example.app/media_scanner"`.
  - Methods supported: `"checkAndRequestPermissions"`, `"queryMediaStore"`.
  - No `enterPictureInPictureMode()` call, no `PictureInPictureParams.Builder`, no `AutoEnterPiP` callback handling.
- In `app/lib/features/player/ui/player_screen.dart`:
  - Zero PiP action buttons or triggers in the HUD or settings drawer.
  - No Desktop overlay floating window mode.
  - No HUD auto-dismiss on window mode transitions.

### 1.6 State of Phase 11: Tokenized Wireless Casting
- In `app/lib/features/casting/domain/cast_service.dart`:
  - Class `CastService extends ChangeNotifier`:
    - Contains 5 hardcoded `CastDevice` objects in `_devices` (Living Room Chromecast, Studio Apple TV, Sony Bravia, Samsung QLED, Shield TV) (lines 139–185).
    - `startScan()` simulates radar scanning via a 12-second `Timer` (lines 274–283).
    - `connect()` simulates network connection via `await Future.delayed(Duration(milliseconds: 650))` (line 328).
    - `_telemetryTimer` periodically injects synthetic jitter into `pingMs` and `bitrateMbps` (lines 358–365).
    - Player binding: Can attach an active `Player` instance and proxy seek, play/pause, volume, and track position (lines 208–256).
  - UI components:
    - `CastSheet` (`app/lib/features/casting/ui/cast_sheet.dart`): Animated radar dial, protocol filters, bento device cards, remote dock.
    - `CastingScreen` (`app/lib/features/casting/ui/casting_screen.dart`): Standalone navigation tab in `MainScaffold`.
    - HUD banner in `PlayerScreen` (lines 1269–1371): Displays active cast sink banner over video controls.
  - **Absence**:
    - No real tokenized one-media LAN HTTP server (required by Architecture Spec V3 to stream local files to Chromecast/DLNA).
    - No real socket-level mDNS/SSDP service discovery.
    - No actual protocol handshake implementation (Google Cast V2 TLS protobuf, DLNA UPnP SOAP AVTransport, AirPlay RAOP).
    - No subtitle muxing/serving pipeline for casting sinks.

### 1.7 Existing Architecture Components & Providers
- **State Management Architecture (`Provider`)**:
  - `LibraryProvider`: Local media database loading, favorites, search/filter/sort pipeline.
  - `ExportService`: Background offline AI video export queue with 7-stage state machine (`ExportPipelineStage`).
  - `VaultService`: AES-256 encrypted storage, decoy PIN support, SQLite indexing.
  - `TrashService`: 30-day soft-delete lifecycle and restore.
  - `SettingsProvider`: Persistent user preferences via `SharedPreferences`.
  - `CastService`: Wireless casting state machine and player proxy.
  - `MediaGroupService`: Aggregates media files into categorized folder groups for the Home screen.
- **Native C++ Engine (`native/engine/`)**:
  - `include/eplayer_engine.h` & `src/eplayer_engine.cpp`:
    - C exports (`eplayer_engine_create`, `eplayer_model_load`, `eplayer_frame_submit_tiled`, `eplayer_export_process_chunk`, `eplayer_validate_export_container`, `eplayer_set_rife_config`, `eplayer_set_audio_dsp_config`, `eplayer_can_enable_pipeline`).
    - Wrapped in Dart via `app/lib/core/engine_orchestrator.dart` and `app/lib/core/ffi/engine_bindings.dart`.

### 1.8 Existing Test Coverage (67 Passing Tests)
1. `cast_service_test.dart` (5 tests): Device initialization, connection, disconnection, remote volume, audio routing.
2. `export_service_test.dart` (2 tests): Job queue addition/purging, duration/frame/ETA calculations.
3. `features/enhancement_profile_test.dart` (11 tests): Preset profiles and config mapping.
4. `features/video_effects_test.dart` (6 tests): Neutral defaults, mutation detection, reset, MPV `vf` string compilation, 4x5 color matrix generation.
5. `media_group_service_test.dart` (4 tests): Folder grouping and empty states.
6. `media_info_test.dart` (6 tests): Container parsing, bitrate, track extraction.
7. `media_scanner_search_test.dart` (8 tests): Extension whitelist/blacklist, sidecar subtitle discovery, multi-token search, category filters, sorting.
8. `model_registry_test.dart` (6 tests): AI manifest parsing, checksum validation, capability tiers.
9. `settings_provider_test.dart` (4 tests): Default values, setters, cache clears, reset.
10. `vault_service_test.dart` (4 tests): Encryption lifecycle, PIN verification, decoy mode.
11. `video_rotation_test.dart` (10 tests): Orientation cycling, quarter turns, degrees, portrait aspect ratio detection, platform channel orientations.
12. `widget_test.dart` (1 test): App smoke load test.

---

## 2. Logic Chain

1. **Decoder Architecture (Phase 1)**:
   - Direct inspection of `player_screen.dart` lines 388–404 shows `_setDecoderMode()` strictly sets `player.platform.setProperty('hwdec', ...)`.
   - In `_player.stream.error` or playback failure hooks, there is no recovery mechanism or automatic fallback to lower tiers when hardware decoding fails or stutters on 4K/HEVC/AV1.
   - Therefore, while the manual UI toggle for HW/HW+/SW exists, the automated dynamic fallback pipeline with capability detection is missing.

2. **Cinematic Gesture Engine (Phase 3)**:
   - Direct inspection of `player_screen.dart` lines 258–340 shows gesture logic is implemented directly within widget state callbacks using a raw `GestureDetector`.
   - Brightness updates only adjust a local double `_brightness` and do not communicate with the platform via `MethodChannel` or window APIs.
   - Seek updates do not produce high-precision seek preview timestamps or adaptive velocity curves.
   - Therefore, the gesture subsystem is currently an unseparated, partially simulated UI handler rather than a production-grade gesture engine.

3. **Native Picture-in-Picture (Phase 6)**:
   - Direct inspection of `AndroidManifest.xml` confirms `android:supportsPictureInPicture="true"` is declared.
   - However, inspection of `MainActivity.kt` reveals only `com.example.app/media_scanner` is registered, with no PiP method handlers or `AutoEnterPiP` hooks.
   - Inspection of `player_screen.dart` confirms there is neither a PiP button nor any call to enter PiP or overlay window mode.
   - Therefore, Native Picture-in-Picture is completely un-implemented in Dart and Kotlin despite manifest support.

4. **Tokenized Wireless Casting (Phase 11)**:
   - Direct inspection of `cast_service.dart` lines 139–185 reveals a static hardcoded array of 5 devices and artificial `Future.delayed(650ms)` network delays.
   - Architecture Spec V3 requires local file streaming to be backed by a tokenized, single-media local HTTP server with automatic shutdown.
   - No HTTP server, mDNS resolver, SSDP listener, or socket client exists in `cast_service.dart` or any other Dart file.
   - Therefore, wireless casting currently exists as an interactive UI/domain simulation mockup and requires implementation of the real local tokenized server and network discovery protocol bindings.

---

## 3. Caveats

- **Native Binary Execution**: Local compilation of binaries (`flutter build apk` or `flutter build windows`) was avoided per environment constraints. Tests were executed strictly via `flutter test` and `flutter analyze`.
- **C++ Native DLL**: In Windows unit tests, `eplayer_engine.dll` is not compiled/linked into the test executable runner path, causing `NativeEngineOrchestrator` to log a benign module lookup warning (code 126) and fall back gracefully to CPU stubs as intended by design.
- **Physical Device Channels**: Device-specific features (such as hardware screen brightness and Android `AutoEnterPiP`) require physical Android/iOS hardware to observe OS-level window transitions, but their platform channel signatures and logic can be deterministically tested with `MethodChannel` mocks in `flutter test`.

---

## 4. Conclusion

1. **Repository Health**: The repository is clean, healthy, and up to date on `origin/main`. `flutter analyze` reports 0 errors and 0 warnings, and `flutter test` passes 100% (67/67 tests).
2. **Phase 1 (Decoders)**: Core `media_kit`/`libmpv` property binding works via `setProperty('hwdec', ...)`, but requires a dedicated `DecoderPipelineService` that probes codec capabilities, monitors mpv playback errors / frame drops, and dynamically cascades: `Hardware (yes) -> HW+ (auto-copy) -> Software (no)`.
3. **Phase 3 (Cinematic Gestures)**: Requires extraction of gesture logic from `player_screen.dart` into a modular `CinematicGestureEngine` with dead-zone filtering, high-precision timestamp scrub velocity, real platform screen brightness channel integration, and zoom/pan stabilization.
4. **Phase 6 (Picture-in-Picture)**: Requires implementing a `PipService` / `PipChannel` across Dart and `MainActivity.kt` (`enterPictureInPictureMode`, aspect ratio calculation, `AutoEnterPiP` on Android 12+, HUD auto-dismiss, and Desktop floating window mode).
5. **Phase 11 (Tokenized Wireless Casting)**: Requires implementing a local tokenized single-media HTTP server (using `dart:io` `HttpServer`), SSDP/mDNS network discovery, and protocol negotiation for DLNA/Chromecast sinks.

---

## 5. Verification Method

To independently reproduce and verify this survey:
1. **Check Git Status**:
   ```powershell
   git status
   ```
   Expect: `On branch main`, `Your branch is up to date with 'origin/main'`.
2. **Execute Static Analysis**:
   ```powershell
   cd d:\E-player\app
   flutter analyze
   ```
   Expect: `No issues found!`.
3. **Execute Unit & Integration Test Suite**:
   ```powershell
   cd d:\E-player\app
   flutter test
   ```
   Expect: `All tests passed!` (67 passing tests).
4. **Inspect Source Locations**:
   - Decoders: `d:\E-player\app\lib\features\player\ui\player_screen.dart` lines 388–434.
   - Gestures: `d:\E-player\app\lib\features\player\ui\player_screen.dart` lines 232–340.
   - PiP: `d:\E-player\app\android\app\src\main\AndroidManifest.xml` line 21 vs `MainActivity.kt`.
   - Casting: `d:\E-player\app\lib\features\casting\domain\cast_service.dart` lines 139–185.
