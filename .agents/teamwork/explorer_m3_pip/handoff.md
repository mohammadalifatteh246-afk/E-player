# Handoff Report: Milestone 3 (Phase 6 Native Picture-in-Picture)

**Author**: `explorer_m3_pip`  
**Date**: 2026-10-22  
**Target Milestone**: Milestone 3 (Phase 6 Native Picture-in-Picture)  
**Status**: Ready for Worker Implementation  

---

## 1. Observation

Direct code observations from the workspace (`d:\E-player` and `d:\E-player\app`):

1. **`app/lib/features/pip/` State**:
   - `list_dir` on `d:\E-player\app\lib\features` confirms that `pip` directory does not currently exist.
   - Vector asset `app/assets/icons/pip.svg` already exists: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" role="img" aria-label="pip"><rect x="3" y="4" width="18" height="16" rx="2"/><rect x="12" y="11" width="7" height="6" rx="1"/></svg>`.

2. **Android Configuration & `MainActivity.kt` (`app/android/app/src/main/`)**:
   - `AndroidManifest.xml` (line 21): `android:supportsPictureInPicture="true"` is declared on `.MainActivity`.
   - `AndroidManifest.xml` (line 23): `android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"` is declared, preventing activity restarts during PiP entry/exit.
   - `MainActivity.kt` (lines 15-36): Currently registers only `com.example.app/media_scanner` via `MethodChannel`. No handlers or channels exist for PiP (`com.example.app/pip`), no `PictureInPictureParams.Builder`, no `AutoEnterPiP` configuration, no `RemoteAction` intents or BroadcastReceiver, and no `onPictureInPictureModeChanged` override.

3. **`PlayerScreen` (`app/lib/features/player/ui/player_screen.dart`)**:
   - Lines 39-106: Manages playback state (`_player`, `_isPlaying`, `_position`, `_duration`), gestures (`_gestureEngine`, `_scale`, `_offset`), and auto-dismiss HUD timer (`_controlsVisible`, `_controlsTimer`, `_controlsTimeout` = 2800ms).
   - Lines 1100-1303: Top bar controls render Back button, filename, resolution badge, decoder badge, Cast button, AI enhancement button, Subtitles button, Technical Inspector button, and Settings menu. There is currently no PiP trigger button.
   - Lines 1056-1074: Video layer wrapped in `Transform.scale`, `Transform.rotate`, `RotatedBox`.
   - Lines 1075-1856: HUD overlays, gradient bars, bottom progress scrubber, gesture feedback cards, and wing ripples render conditionally based on `_controlsVisible`, `_showFeedbackOverlay`, `_leftWingRipple`, etc.
   - Currently, there is no listener for PiP lifecycle changes to immediately collapse HUD overlays or reset gesture zoom to neutral 1.0x when entering PiP.

4. **Testing Contracts & Specifications (`app/test/helpers/eplayer_test_harness.dart` & `app/test/e2e/`)**:
   - `eplayer_test_harness.dart` lines 68 & 119-136 define the exact platform channel contract:
     - Channel name: `static const MethodChannel pipChannel = MethodChannel('com.example.app/pip');`
     - Methods intercepted:
       - `'isPipSupported'` -> returns `bool`
       - `'enterPictureInPictureMode'` -> sets `isInPipMode = true`, returns `true`
       - `'setAutoEnterEnabled'` -> arguments `{'enabled': bool, 'videoWidth': int?, 'videoHeight': int?}`
       - `'toggleDesktopOverlay'` -> arguments `{'enabled': bool, 'width': int?, 'height': int?}`
   - `eplayer_test_harness.dart` lines 477-490 define `PipMath`:
     - `minAspectRatio = 1.0 / 2.39` (~0.41841)
     - `maxAspectRatio = 2.39 / 1.0` (2.39)
     - `calculateAspectRatio(int width, int height)`: clamps between min and max; returns `16.0 / 9.0` for `<= 0` dimensions.
     - `canAutoEnter(bool isPlaying)`: returns `isPlaying`.
   - `tier1_feature_coverage_test.dart` lines 491-688 test:
     - Feature 11: Android AutoEnterPiP (active playback enables, paused disarms; invokes `setAutoEnterEnabled` and `enterPictureInPictureMode`).
     - Feature 12: Aspect Ratio Preservation (16:9, 21:9, clamped ultra-wide, clamped ultra-tall, 0x0 fallback).
     - Feature 13: PiP Remote Media Controls (receives `play`, `pause`, `seek_forward_10`, `seek_rewind_10`; unknown action discarded safely).
     - Feature 14: HUD Auto-Dismiss on PiP Enter (instantly hides controls, cancels feedback overlays, restores controls on exit).
     - Feature 15: Desktop Overlay Window Mode (invokes `toggleDesktopOverlay`, maintains aspect-ratio frame, restores normal window geometry on disable).
   - `tier3_cross_feature_test.dart` lines 93-106 (Test 3.4): Entering PiP while pinch-to-zoom is active MUST reset zoom to neutral `1.0x` and pan offset to `Offset.zero`.
   - `tier4_user_scenarios_test.dart` lines 185-240 (Journey 3): PiP transition -> HUD auto-dismiss -> Remote PiP actions (`pause`, `fast_forward` / `seek_forward_10`, `rewind` / `seek_rewind_10`, `play`) -> return to full screen.

5. **Repository Baseline**:
   - `flutter analyze` runs clean with **0 errors, 0 warnings**.
   - `flutter test` executes 399 tests with 398 passed (the only known non-blocking failure is the 16ms CPU benchmark in `video_grouping_service_test.dart` under concurrent test load, documented in `TEST_READY.md`).

---

## 2. Logic Chain

1. **Requirement Derivation**:
   - From `PROJECT.md` § Interface Contracts: `PipService` must extend `ChangeNotifier`, communicate over `MethodChannel('com.example.app/pip')`, provide methods `isPipSupported()`, `enterPip(...)`, `setAutoEnterEnabled(...)`, and `toggleDesktopOverlay(...)`, and receive incoming channel events `onPipEntered`, `onPipExited`, and `onPipAction(String action)`.
   - From `PROJECT.md` § Code Layout:
     - `app/lib/features/pip/domain/pip_service.dart`
     - `app/lib/features/pip/data/pip_platform_bridge.dart`
     - `app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`
     - `app/lib/features/pip/domain/pip_models.dart` (recommended domain math and data structures)
     - `app/lib/features/player/ui/player_screen.dart` (HUD auto-dismiss and PiP trigger button)
     - `app/test/unit/pip_service_test.dart` (unit tests for models, bridge, and service)

2. **Platform Separation & Channel Binding**:
   - `PipPlatformBridge` encapsulates direct `MethodChannel` invocations and listens to incoming platform method calls (`onPipEntered`, `onPipExited`, `onPipAction`).
   - Using typed streams on `PipPlatformBridge` decouples domain logic (`PipService`) from platform binary messaging details, making `PipService` fully testable without mock frameworks.

3. **Android Native Implementation in `MainActivity.kt`**:
   - In Android 8.0+ (API 26+), `enterPictureInPictureMode(PictureInPictureParams)` is supported.
   - In Android 12+ (API 31+), `PictureInPictureParams.Builder.setAutoEnterEnabled(true)` enables seamless transition to PiP when the user swipes home.
   - Android enforces rational aspect ratios strictly within `[1/2.39, 2.39/1]`. Any value outside throws an `IllegalArgumentException`. Clamping in Kotlin using `.coerceIn(1.0 / 2.39, 2.39)` guarantees system stability.
   - Remote actions require creating `RemoteAction` instances with `PendingIntent`s registered to broadcast actions (`com.example.app.ACTION_PIP_PLAY`, `ACTION_PIP_PAUSE`, `ACTION_PIP_FORWARD`, `ACTION_PIP_REWIND`).
   - The BroadcastReceiver catches these intents and dispatches them back into Flutter via `MethodChannel.invokeMethod("onPipAction", actionString)`.
   - `onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration)` invokes `onPipEntered` or `onPipExited` on Flutter's Dart channel.

4. **PlayerScreen UI Cleanliness (Feature 14 & Tier 3 Invariant)**:
   - When `PipService.isInPip` becomes `true`:
     - Dismiss all HUD overlays (`_controlsVisible = false`, cancel `_controlsTimer`).
     - Dismiss feedback overlays (`_showFeedbackOverlay = false`, `_showFeedback = false`).
     - Reset gesture zoom/pan to `1.0x` and `Offset.zero` (fulfilling Cross-Feature Test 3.4).
     - Dismiss any open modal bottom sheets (Subtitles, Audio Studio, Settings, Video Effects).
     - Build method renders ONLY the video surface (`videoWidget`) inside a clean black scaffold, eliminating all UI overlays.
   - When `PipService.isInPip` becomes `false`:
     - Restore `_controlsVisible = true` and restart auto-dismiss timer.

5. **Desktop Overlay Mode (Feature 15)**:
   - On Windows/macOS/Linux, `toggleDesktopOverlay` is invoked.
   - `PipService` tracks `_isDesktopOverlay` and calculates compact aspect-ratio geometry (e.g. 480x270 for 16:9, 480x360 for 4:3, 480x203 for 21:9).

---

## 3. Caveats

1. **No Local Binary Compilation Rule**: Per `ORIGINAL_REQUEST.md` constraints, `flutter build apk` or `flutter build windows` must NOT be run on the `D:` drive. Android Kotlin changes in `MainActivity.kt` must be validated via code correctness inspection, static lint review, and Dart platform channel integration tests in `flutter test`.
2. **Desktop Window Manager**: The repository does not include external window manipulation packages (e.g., `window_manager` or `bitsdojo_window`) in `pubspec.yaml`. Desktop overlay mode is modeled via platform channel calls and responsive Flutter viewport presentation.
3. **No Placeholders / Zero-Mock**: Worker must write complete, production-grade files without `// TODO`, fake mocks, or synthetic stubs.

---

## 4. Conclusion & Technical Specification

The technical design for Milestone 3 (Phase 6 Native Picture-in-Picture) is divided into 6 deliverables:

### Deliverable 1: `app/lib/features/pip/domain/pip_models.dart`
Pure domain data structures, enums, and mathematical algorithms:
- `enum PipStatus { stopped, entering, active, exiting }`
- `enum PipAction { play, pause, seekForward10, seekRewind10, unknown }`
  - Parser `PipAction.fromString(String raw)` supporting:
    - `'play'` -> `PipAction.play`
    - `'pause'` -> `PipAction.pause`
    - `'seek_forward_10'`, `'fast_forward'` -> `PipAction.seekForward10`
    - `'seek_rewind_10'`, `'rewind'` -> `PipAction.seekRewind10`
    - default -> `PipAction.unknown`
- `class PipDimensions`:
  - Fields: `final int width`, `final int height`, `final double aspectRatio`.
  - Factory `PipDimensions.fromSize(int width, int height)`.
- `class PipMath`:
  - `static const double minAspectRatio = 1.0 / 2.39;` (~0.41841)
  - `static const double maxAspectRatio = 2.39 / 1.0;` (2.39)
  - `static double calculateAspectRatio(int width, int height)`:
    - If `width <= 0 || height <= 0`, return `16.0 / 9.0`.
    - Returns `(width / height).clamp(minAspectRatio, maxAspectRatio)`.
  - `static bool canAutoEnter(bool isPlaying) => isPlaying;`
  - `static Size calculateOverlaySize({required int width, required int height, double baseWidth = 480.0})`:
    - `final ratio = calculateAspectRatio(width, height);`
    - `return Size(baseWidth, (baseWidth / ratio).roundToDouble());`

### Deliverable 2: `app/lib/features/pip/data/pip_platform_bridge.dart`
Platform channel communication layer:
- `class PipPlatformBridge`:
  - Channel: `MethodChannel('com.example.app/pip')` (supports constructor injection for tests).
  - StreamControllers:
    - `_pipEnteredController = StreamController<void>.broadcast()`
    - `_pipExitedController = StreamController<void>.broadcast()`
    - `_pipActionController = StreamController<String>.broadcast()`
  - Streams:
    - `Stream<void> get onPipEntered`
    - `Stream<void> get onPipExited`
    - `Stream<String> get onPipAction`
  - Internal `_handleMethodCall(MethodCall call)`:
    - `'onPipEntered'` -> emits on `_pipEnteredController`.
    - `'onPipExited'` -> emits on `_pipExitedController`.
    - `'onPipAction'` -> extracts String from `call.arguments` (direct string or map `{'action': ...}`) and emits on `_pipActionController`.
  - Invocation methods:
    - `Future<bool> isPipSupported()`: invokes `'isPipSupported'`, defaults to `false` on error.
    - `Future<bool> enterPictureInPictureMode({required int videoWidth, required int videoHeight, required bool isPlaying})`:
      invokes `'enterPictureInPictureMode'` with `{'videoWidth': videoWidth, 'videoHeight': videoHeight, 'isPlaying': isPlaying}`.
    - `Future<void> setAutoEnterEnabled(bool enabled, {int? videoWidth, int? videoHeight})`:
      invokes `'setAutoEnterEnabled'` with `{'enabled': enabled, 'videoWidth': videoWidth, 'videoHeight': videoHeight}`.
    - `Future<bool> toggleDesktopOverlay({required bool enable, Size? initialSize})`:
      invokes `'toggleDesktopOverlay'` with `{'enabled': enable, if (initialSize != null) ...{'width': initialSize.width.toInt(), 'height': initialSize.height.toInt()}}`.
  - `void dispose()`: closes all stream controllers.

### Deliverable 3: `app/lib/features/pip/domain/pip_service.dart`
State coordinator extending `ChangeNotifier`:
- `class PipService extends ChangeNotifier`:
  - Fields:
    - `bool _isInPip = false;`
    - `bool _isDesktopOverlay = false;`
    - `bool _autoEnterEnabled = false;`
    - `bool _isSupported = false;`
    - `Size? _desktopOverlaySize;`
    - `final PipPlatformBridge _bridge;`
    - `final StreamController<PipAction> _actionController = StreamController<PipAction>.broadcast();`
  - Lifecycle:
    - Subscribes to `_bridge.onPipEntered`: sets `_isInPip = true`, notifies listeners.
    - Subscribes to `_bridge.onPipExited`: sets `_isInPip = false`, notifies listeners.
    - Subscribes to `_bridge.onPipAction`: parses `PipAction.fromString` and emits on `_actionController`.
  - Methods:
    - `Future<bool> isPipSupported()`: queries bridge, caches `_isSupported`.
    - `Future<bool> enterPip({required int videoWidth, required int videoHeight, required bool isPlaying})`:
      checks `isPipSupported()`; delegates to `_bridge.enterPictureInPictureMode(...)`. If successful, sets `_isInPip = true` and notifies.
    - `Future<void> setAutoEnterEnabled(bool enabled, {int? videoWidth, int? videoHeight})`:
      delegates to `_bridge.setAutoEnterEnabled(...)`; updates `_autoEnterEnabled` and notifies.
    - `Future<bool> toggleDesktopOverlay({required bool enable, Size? initialSize})`:
      delegates to `_bridge.toggleDesktopOverlay(...)`; updates `_isDesktopOverlay` and `_desktopOverlaySize` and notifies.
    - `void updatePlaybackState({required bool isPlaying, int? videoWidth, int? videoHeight})`:
      syncs auto-enter state (`PipMath.canAutoEnter(isPlaying)`).
    - `Stream<PipAction> get actionStream => _actionController.stream;`
    - `void dispose()`: cancels subscriptions, closes stream controller, disposes bridge.

### Deliverable 4: `app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`
Native Android PiP, AutoEnter, and RemoteAction integration:
- Channel: `com.example.app/pip`.
- Supported features:
  - `isPipSupported`: `Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)`.
  - `enterPictureInPictureMode`: builds `PictureInPictureParams` with clamped aspect ratio `Rational`, sets remote action buttons, and enters PiP.
  - `setAutoEnterEnabled`: for API 31+ (`Build.VERSION_CODES.S`), sets `builder.setAutoEnterEnabled(enabled)` and calls `setPictureInPictureParams()`.
  - Remote actions:
    - Rewind 10s: `android.R.drawable.ic_media_rew` -> `com.example.app.ACTION_PIP_REWIND`.
    - Play / Pause toggle: `android.R.drawable.ic_media_pause` (if playing) or `android.R.drawable.ic_media_play` (if paused) -> `ACTION_PIP_PAUSE` / `ACTION_PIP_PLAY`.
    - Forward 10s: `android.R.drawable.ic_media_ff` -> `com.example.app.ACTION_PIP_FORWARD`.
  - BroadcastReceiver:
    - Catches action broadcasts and invokes `pipMethodChannel?.invokeMethod("onPipAction", action)`.
    - Registered in `onCreate` (with `RECEIVER_NOT_EXPORTED` on Android 13+) and unregistered in `onDestroy`.
  - Callback `onPictureInPictureModeChanged`:
    - Invokes `onPipEntered` or `onPipExited` on Dart platform channel.

### Deliverable 5: `app/lib/features/player/ui/player_screen.dart`
Integration into playback viewport and HUD:
- Instantiate `_pipService = PipService();` in `initState()` and dispose in `dispose()`.
- Listen to `_pipService.addListener`:
  - When `_pipService.isInPip == true`:
    - Immediately hide HUD: `_controlsVisible = false; _controlsTimer?.cancel();`
    - Hide feedback overlays: `_showFeedbackOverlay = false; _showFeedback = false;`
    - Cancel feedback timers.
    - Reset zoom and pan: `_scale = 1.0; _offset = Offset.zero;` (fulfills Cross-Feature test 3.4).
    - Close any active modal sheet.
  - When `_pipService.isInPip == false`:
    - Restore controls: `_controlsVisible = true; _startControlsTimer();`
- Listen to `_pipService.actionStream`:
  - `PipAction.play`: `_player.play();`
  - `PipAction.pause`: `_player.pause();`
  - `PipAction.seekForward10`: `_player.seek(_position + const Duration(seconds: 10));`
  - `PipAction.seekRewind10`: `_player.seek(_position - const Duration(seconds: 10));`
- Synchronize AutoEnterPiP:
  - In `_player.stream.playing.listen`: update `_pipService.updatePlaybackState(isPlaying: playing, ...)`.
- Add PiP trigger button in top bar:
  - Place next to Cast / AI Enhancement buttons.
  - Uses `EVectorIcon(name: 'pip', size: 19, color: Colors.white)` with tooltip `'Picture-in-Picture'`.
  - When tapped: on desktop calls `toggleDesktopOverlay`; on mobile calls `enterPip`.
- Clean surface rendering in `build()`:
  - If `_pipService.isInPip`: render ONLY the clean video surface inside a black Scaffold, suppressing all overlays and gesture feedback cards.

### Deliverable 6: `app/test/unit/pip_service_test.dart`
Mock-free unit test suite:
- Minimum 25 unit tests covering:
  - Aspect ratio clamping (16:9, 21:9, ultra-wide 3.55 -> 2.39, vertical 0.36 -> 0.4184, 0x0 fallback to 16:9).
  - Overlay size calculation for desktop (16:9, 4:3, 21:9).
  - Action string parsing and unknown action discarding.
  - Platform bridge method calls via simulated BinaryMessenger.
  - Inbound platform events (`onPipEntered`, `onPipExited`, `onPipAction`).
  - `PipService` state machine transitions, playback sync, and disposal.

---

## 5. Verification Method

To independently verify the implementation after Worker code modifications:

1. **Static Analysis Gate**:
   ```powershell
   flutter analyze
   ```
   *Requirement*: 0 errors, 0 warnings across `app/lib/` and `app/test/`.

2. **Milestone 3 Unit Tests Execution**:
   ```powershell
   flutter test test/unit/pip_service_test.dart
   ```
   *Requirement*: 100% pass across all PiP unit test cases.

3. **Core E2E Feature Coverage Tests (Tiers 1 to 4)**:
   ```powershell
   flutter test test/e2e/tier1_feature_coverage_test.dart
   flutter test test/e2e/tier2_boundary_corner_test.dart
   flutter test test/e2e/tier3_cross_feature_test.dart
   flutter test test/e2e/tier4_user_scenarios_test.dart
   ```
   *Requirement*: All 245 E2E tests pass (specifically Feature 11, 12, 13, 14, 15, Test 3.4, and Journey 3).

4. **Invalidation Conditions**:
   - Aspect ratio not clamped to `[1/2.39, 2.39/1]` throwing `IllegalArgumentException` on Android.
   - Any synthetic mock package (`mockito` / `mocktail`) introduced in `pubspec.yaml` or tests.
   - Any remaining `// TODO` or placeholder comments.
   - HUD controls or overlays lingering on screen during PiP mode.
   - Zoom scale not reset to 1.0x when entering PiP.
