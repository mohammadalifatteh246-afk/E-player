# Handoff Report — CYPHER: Forensic Telemetry & Binary Artifact / Core Engine Specialist

**Scope**: Phase 2 — Core UX & Playback Enhancements (libmpv engine, volume amplification to 300%, frame-stepping, aspect ratio crop cycling, network & demuxer caching buffers)  
**Date**: 2026-11-11  
**Author**: CYPHER (explorer_survey_1)  
**Target Recipient**: Orchestrator (cfb12254-fb8f-487a-8093-2f824a398acb) & Implementation Team (FORGE, AURA, KRONOS)

---

## 1. Observation

### 1.1 Volume Initialization, libmpv Property Interop & Clamping
- **Player Instantiation**:
  In `d:\E-player\app\lib\features\player\ui\player_screen.dart:220–222`:
  ```dart
  _player = Player(
    configuration: const PlayerConfiguration(libass: true),
  );
  ```
  This is the single production location where `Player` is instantiated in `app/lib`.
- **`PlayerConfiguration` Parameters in `media_kit-1.2.6`**:
  In `C:\Users\Admin\AppData\Local\Pub\Cache\hosted\pub.dev\media_kit-1.2.6\lib\src\player\platform_player.dart:518–543`:
  ```dart
  const PlayerConfiguration({
    this.vo = 'null',
    this.osc = false,
    this.pitch = false,
    this.title = 'package:media_kit',
    this.ready,
    this.muted = false,
    this.async = true,
    this.libass = false,
    this.libassAndroidFont,
    this.libassAndroidFontName,
    this.logLevel = MPVLogLevel.error,
    this.bufferSize = 32 * 1024 * 1024,
    this.protocolWhitelist = const [ ... ],
  });
  ```
  `PlayerConfiguration` has **no `volumeMax`** parameter.
- **`NativePlayer` Property Manipulation API**:
  In `C:\Users\Admin\AppData\Local\Pub\Cache\hosted\pub.dev\media_kit-1.2.6\lib\src\player\native\player\real.dart:1223–1246`:
  ```dart
  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    ...
    mpv.mpv_set_property_string(ctx, name.cast(), data.cast());
  }
  ```
  `NativePlayer` directly provides `setProperty(String property, String value)` and `getProperty(String property)`.
- **`Player.setVolume()` Internal Dispatch**:
  In `real.dart:781–797`:
  ```dart
  @override
  Future<void> setVolume(double volume, {bool synchronized = true}) {
    ...
    await _setPropertyDouble('volume', volume);
  }
  ```
  `media_kit` does not clamp `volume` on the Dart side. Clamping is performed by libmpv based on the `volume-max` property (which defaults to `130.0` in mpv).
- **Current Volume Clamping in `CinematicGestureEngine`**:
  In `d:\E-player\app\lib\features\player\ui\cinematic_gesture_engine.dart`:
  - Line 179:
    ```dart
    _volume = initialVolume.clamp(0.0, 100.0);
    ```
  - Line 200:
    ```dart
    void setExternalVolume(double value) {
      _volume = value.clamp(0.0, 100.0);
    }
    ```
  - Lines 410–422 (`_handleVolumeAdjust`):
    ```dart
    final effectiveHeight = viewportSize.height > 0 ? viewportSize.height : 600.0;
    // Dragging upwards (negative dy) increases volume
    final delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 100.0;
    _volume = (_volume + delta).clamp(0.0, 100.0);
    onVolumeChanged?.call(_volume);
    ```
  - `d:\E-player\app\lib\features\player\ui\gesture_models.dart:41`:
    ```dart
    /// - Volume: 0.0 to 100.0
    ```
- **Current Volume Clamping in `DesktopKeyboardHandler`**:
  In `d:\E-player\app\lib\features\player\ui\widgets\desktop_keyboard_handler.dart`:
  - Lines 233–234:
    ```dart
    final vol = (widget.player.state.volume + 5.0).clamp(0.0, 150.0);
    widget.player.setVolume(vol);
    ```
  - Lines 243–244:
    ```dart
    final vol = (widget.player.state.volume - 5.0).clamp(0.0, 150.0);
    widget.player.setVolume(vol);
    ```
- **Current Volume Feedback & HUD Overlay**:
  In `d:\E-player\app\lib\features\player\ui\player_screen.dart:2450–2484`:
  ```dart
  case GestureFeedbackType.volume:
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          event.value == 0
              ? Icons.volume_off
              : (event.value < 50 ? Icons.volume_down : Icons.volume_up),
          color: EDesign.primary,
          size: 22,
        ),
        const SizedBox(width: 8),
        Text('Volume: ${event.label}', ...),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (event.value / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primary),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  ```
  Progress indicator is clamped to `100.0` and hardcoded to single color `EDesign.primary` (cyan).

---

### 1.2 libmpv `frame-step` Command
- **Command Dispatch in `media_kit`**:
  In `real.dart:1359–1373`:
  ```dart
  Future<void> command(
    List<String> command, {
    bool waitForInitialization = true,
  }) async {
    ...
    await _command(command);
  }
  ```
  Calling `(player.platform as dynamic).command(['frame-step'])` invokes `mpv.mpv_command_async` with argument `frame-step`.
- **Keyboard Shortcut Coverage**:
  In `desktop_keyboard_handler.dart`:
  `LogicalKeyboardKey.keyE` is **unhandled** (no listener or callback exists).
- **HUD Action Toolbar**:
  In `player_screen.dart:2059–2112`:
  Toolbar currently contains Replay 10s (`replay_10_rounded`), Play/Pause, Forward 10s (`forward_10_rounded`), Equalizer, and Aspect Ratio. There is **no HUD action button** for 1-frame stepping.
- **Headless Unit Test Harness**:
  In `test/e2e/phase1_e2e_test.dart:24–84`:
  `FakePlatformPlayer` does not yet have a `command(List<String> command)` method stub.

---

### 1.3 Aspect Ratio Crop Cycling with mpv Video Filters (`vf`)
- **Current Aspect Ratio Handling**:
  In `player_screen.dart:625–631, 1198–1226`:
  `_aspectRatio` is cycled through `['Fit', 'Crop', '16:9', '4:3', 'Fill', 'Original']` via `_cycleAspectRatio()`, but only affects Flutter layout widgets (`BoxFit.contain`, `BoxFit.cover`, `AspectRatio(aspectRatio: 16/9)`). This produces geometric distortion or black pillarboxing/letterboxing rather than genuine video cropping.
- **Existing Video Filter Graph (`vf`) Architecture**:
  In `d:\E-player\app\lib\features\video_effects\domain\video_effects_service.dart:56–67` and `models\video_effects_config.dart:201–250`:
  `VideoEffectsService` applies ffmpeg filters to mpv via:
  ```dart
  platform.setProperty('vf', vfString);
  ```
  `VideoEffectsConfig.buildMpvVfString()` joins filters (`unsharp`, `gradfun`, `hflip`, `vflip`, `negate`, `colorchannelmixer`) into a comma-delimited string.
- **Hotkeys in `desktop_keyboard_handler.dart`**:
  `LogicalKeyboardKey.keyA` invokes `onCycleAspectRatio` (UI layout aspect ratio).
  `LogicalKeyboardKey.keyC` is **unhandled**.

---

### 1.4 Network & Demuxer Caching Buffers
- **`media_kit` Native Initialization of Buffer Properties**:
  In `real.dart:2425–2426`:
  ```dart
  'demuxer-max-bytes': configuration.bufferSize.toString(),
  'demuxer-max-back-bytes': configuration.bufferSize.toString(),
  ```
  `configuration.bufferSize` defaults to `32 * 1024 * 1024` (32MB).
  libmpv also accepts runtime modification via `setProperty('demuxer-max-bytes', bytes)` and `setProperty('cache-secs', seconds)`.
- **Existing Settings Architecture**:
  In `d:\E-player\app\lib\features\settings\domain\settings_provider.dart`:
  - Lines 37–39:
    ```dart
    bool _lowLatencyRtsp = true;
    String _networkBufferSize = '32 MB';
    ```
  - Lines 117–119:
    ```dart
    _lowLatencyRtsp = _prefs?.getBool('lowLatencyRtsp') ?? true;
    _networkBufferSize = _prefs?.getString('networkBufferSize') ?? '32 MB';
    ```
  - Stored as string `'32 MB'`. There is no `networkCachingMs` slider setting (`500ms`–`10,000ms`, default `1,000ms`).
- **Existing Settings UI**:
  In `d:\E-player\app\lib\features\settings\ui\settings_screen.dart:480–505`:
  Shows a selection sheet with `'16 MB', '32 MB', '64 MB', '128 MB'` under title "Network Cache Buffer Size", but does not provide a Network Caching slider in milliseconds, nor does it connect to the active `Player` instance via `cache-secs` or `demuxer-max-bytes`.

---

## 2. Logic Chain

```
[Requirement R1: volume-max 300%]
  │
  ├─► media_kit PlayerConfiguration lacks volumeMax (Obs 1.1)
  │     └─► (player.platform as dynamic).setProperty('volume-max', '300.0') is valid & supported in libmpv C API
  │
  ├─► CinematicGestureEngine clamps volume to 100.0 at lines 179, 200, 413 (Obs 1.1)
  │     └─► Must update clamp to [0.0, 300.0] and swipe delta multiplier from 100.0 to 300.0 for full-travel scaling
  │
  ├─► DesktopKeyboardHandler clamps Arrow Up/Down to 150.0 at lines 233, 243 (Obs 1.1)
  │     └─► Must update clamp to [0.0, 300.0] in 5.0 increments
  │
  └─► PlayerScreen feedback card hardcodes 100.0 and cyan color (Obs 1.1)
        └─► Must introduce 3-color safety indicator:
              0–100%: Green (#22C55E)
              101–200%: Amber (#F59E0B)
              201–300%: Soft Red (#EF4444)

[Requirement R2: frame-step on 'e' and HUD button]
  │
  ├─► media_kit exposes command(['frame-step']) via NativePlayer (Obs 1.2)
  │
  ├─► libmpv frame-step requires/expects paused state (Obs 1.2)
  │     └─► Controller must check if player.state.playing == true; if so, await player.pause() before stepping
  │
  └─► DesktopKeyboardHandler lacks keyE & PlayerScreen HUD lacks button (Obs 1.2)
        └─► Bind keyE to onStepFrame and insert HUD button adjacent to forward_10_rounded

[Requirement R4: Aspect Ratio Crop Cycling on 'c' via mpv crop filters]
  │
  ├─► Existing aspect ratio logic alters Flutter BoxFit, causing geometric distortion (Obs 1.3)
  │
  ├─► Non-distorted centered crop in FFmpeg/mpv uses:
  │     crop=w:h (e.g. crop=w='min(iw\,ih*R)':h='min(ih\,iw/R)') or pixel-computed crop=W:H
  │
  └─► VideoEffectsService already owns the mpv 'vf' property pipeline (Obs 1.3)
        └─► Add cropAspectRatio to VideoEffectsConfig to compose crop filter cleanly with active effects on hotkey 'c'

[Requirement R5: Network & Demuxer Caching Settings]
  │
  ├─► SettingsProvider stores string '32 MB', lacks networkCachingMs (Obs 1.4)
  │     └─► Add networkCachingMs (500–10,000ms, default 1,000ms) and demuxerCacheMb (16, 32, 64, 128 MB)
  │
  ├─► SettingsScreen requires slider for network caching & selector for demuxer (Obs 1.4)
  │     └─► Add Slider for 500ms..10,000ms (mapped to cache-secs = ms / 1000.0)
  │
  └─► Player initialization must apply these values to PlayerConfiguration and mpv (Obs 1.1, 1.4)
        └─► PlayerConfiguration(bufferSize: demuxerCacheMb * 1024 * 1024)
            setProperty('cache-secs', (networkCachingMs / 1000.0).toStringAsFixed(1))
            setProperty('demuxer-max-bytes', (demuxerCacheMb * 1024 * 1024).toString())
```

---

## 3. Caveats

1. **Web Platform (`WebPlayer`)**:
   `media_kit` WebPlayer does not use libmpv (uses HTML5 `<video>`). Setting mpv properties via `(player.platform as dynamic).setProperty` is guarded with `try/catch` or platform checks. On Windows, macOS, Linux, Android, and iOS, `NativePlayer` is active and supports all mpv properties and commands.
2. **FFmpeg Crop Filter Sub-Pixel Even Dimension Invariant**:
   For YUV420p video codecs (H.264, HEVC, VP9, AV1), odd width/height dimensions in crop filters can trigger FFmpeg decoder assertions (`width not divisible by 2`). When generating numeric `crop=W:H`, `W` and `H` must be made even numbers (`cropW -= (cropW % 2)`).
3. **`FakePlatformPlayer` in Test Suites**:
   Existing unit and widget tests use `FakePlayer` or `FakePlatformPlayer`. Adding `command(List<String> command)` and supporting `volume-max`, `cache-secs`, and `crop` properties in test fakes is required so tests pass without FFI runtime dependencies.
4. **No Other Caveats**: All 4 areas investigated directly against codebase sources and `media_kit-1.2.6` package files.

---

## 4. Conclusion & Concrete Implementation Blueprints

### Recommendation 1: Volume Over-Amplification to 300% (R1)
1. **Initialize `volume-max`**:
   In `d:\E-player\app\lib\features\player\ui\player_screen.dart:223`:
   Immediately following `_player = Player(...)`:
   ```dart
   try {
     (_player.platform as dynamic).setProperty('volume-max', '300.0');
   } catch (_) {}
   ```
2. **Update `CinematicGestureEngine`**:
   In `cinematic_gesture_engine.dart`:
   - Change line 179: `_volume = initialVolume.clamp(0.0, 300.0);`
   - Change line 200: `_volume = value.clamp(0.0, 300.0);`
   - Change line 412–413:
     ```dart
     final delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 300.0;
     _volume = (_volume + delta).clamp(0.0, 300.0);
     ```
3. **Update `DesktopKeyboardHandler`**:
   In `desktop_keyboard_handler.dart`:
   - Line 233: `final vol = (widget.player.state.volume + 5.0).clamp(0.0, 300.0);`
   - Line 243: `final vol = (widget.player.state.volume - 5.0).clamp(0.0, 300.0);`
4. **Implement 3-Color Safety Indicator**:
   In `player_screen.dart` and gesture OSD:
   ```dart
   static Color getVolumeSafetyColor(double volume) {
     if (volume <= 100.0) return const Color(0xFF22C55E); // Green (unity gain)
     if (volume <= 200.0) return const Color(0xFFF59E0B); // Amber (software preamp boost)
     return const Color(0xFFEF4444); // Soft Red (high boost warning)
   }
   ```
   In `_buildFeedbackCard`:
   - Progress bar `value: (event.value / 300.0).clamp(0.0, 1.0)`
   - Progress color: `AlwaysStoppedAnimation<Color>(getVolumeSafetyColor(event.value))`
   - Icon color: `getVolumeSafetyColor(event.value)`

---

### Recommendation 2: libmpv Frame-by-Frame Stepping (R2)
1. **Controller Method in `PlayerScreen`**:
   ```dart
   Future<void> _stepFrame() async {
     try {
       if (_isPlaying) {
         await _player.pause();
       }
       await (_player.platform as dynamic).command(['frame-step']);
       _showFeedbackMessage('Frame Step', Icons.skip_next_rounded);
     } catch (e) {
       debugPrint('[PlayerScreen] frame-step error: $e');
     }
   }
   ```
2. **Desktop Keyboard Hotkey (`e`)**:
   Add `final VoidCallback onStepFrame;` to `DesktopKeyboardHandler`.
   In `_handleKeyEvent`:
   ```dart
   if (event.logicalKey == LogicalKeyboardKey.keyE) {
     widget.onUserActivity();
     widget.onStepFrame();
     return KeyEventResult.handled;
   }
   ```
3. **HUD Action Button**:
   In `player_screen.dart` lines 2100–2112, add:
   ```dart
   IconButton(
     icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
     tooltip: 'Step 1 Frame (e)',
     onPressed: () {
       _showControls();
       _stepFrame();
     },
   ),
   ```

---

### Recommendation 3: Aspect Ratio Crop Cycling via mpv filters (R4)
1. **Crop Aspect Ratios Sequence**:
   `['Reset', '16:9', '16:10', '4:3', '1.85:1', '2.35:1']`
2. **Crop Filter Definition in `VideoEffectsConfig`**:
   Add property `String? cropRatio;` to `VideoEffectsConfig`.
   In `buildMpvVfString()`:
   ```dart
   if (cropRatio != null && cropRatio != 'Reset') {
     switch (cropRatio) {
       case '16:9':
         filters.add("crop=w='min(iw\\,ih*16/9)':h='min(ih\\,iw*9/16)'");
         break;
       case '16:10':
         filters.add("crop=w='min(iw\\,ih*16/10)':h='min(ih\\,iw*10/16)'");
         break;
       case '4:3':
         filters.add("crop=w='min(iw\\,ih*4/3)':h='min(ih\\,iw*3/4)'");
         break;
       case '1.85:1':
         filters.add("crop=w='min(iw\\,ih*1.85)':h='min(ih\\,iw/1.85)'");
         break;
       case '2.35:1':
         filters.add("crop=w='min(iw\\,ih*2.35)':h='min(ih\\,iw/2.35)'");
         break;
     }
   }
   ```
3. **Hotkey `c` in `DesktopKeyboardHandler`**:
   Add `final VoidCallback onCycleCropAspectRatio;`
   ```dart
   if (event.logicalKey == LogicalKeyboardKey.keyC) {
     widget.onUserActivity();
     widget.onCycleCropAspectRatio();
     return KeyEventResult.handled;
   }
   ```
4. **Handler in `PlayerScreen`**:
   ```dart
   void _cycleCropAspectRatio() {
     const ratios = ['16:9', '16:10', '4:3', '1.85:1', '2.35:1', 'Reset'];
     final current = _videoEffectsConfig.cropRatio ?? 'Reset';
     final nextIdx = (ratios.indexOf(current) + 1) % ratios.length;
     final nextRatio = ratios[nextIdx];

     setState(() {
       _videoEffectsConfig = _videoEffectsConfig.copyWith(
         cropRatio: nextRatio == 'Reset' ? null : nextRatio,
       );
     });
     _videoEffectsService.apply(_player, _videoEffectsConfig, immediateVf: true);
     _showFeedbackMessage('Crop: $nextRatio', Icons.crop_rounded);
   }
   ```

---

### Recommendation 4: Network & Disk Buffer Caching Settings (R5)
1. **Extend `SettingsProvider`**:
   - Fields:
     ```dart
     int _networkCachingMs = 1000; // 500..10000 ms
     int _demuxerCacheMb = 32;     // 16, 32, 64, 128 MB
     ```
   - Getters & Setters:
     ```dart
     int get networkCachingMs => _networkCachingMs;
     int get demuxerCacheMb => _demuxerCacheMb;

     Future<void> setNetworkCachingMs(int ms) async {
       _networkCachingMs = ms.clamp(500, 10000);
       await _prefs?.setInt('network_caching_ms', _networkCachingMs);
       notifyListeners();
     }

     Future<void> setDemuxerCacheMb(int mb) async {
       _demuxerCacheMb = mb;
       await _prefs?.setInt('demuxer_cache_mb', mb);
       notifyListeners();
     }
     ```
2. **Update `SettingsScreen` UI**:
   Under `NETWORK & BUFFERING`:
   - Slider for Network Caching: `500 ms` to `10,000 ms`, step `500 ms`, mapped to `setNetworkCachingMs`.
   - Selector for Demuxer Cache: `'16 MB', '32 MB', '64 MB', '128 MB'`, mapped to `setDemuxerCacheMb`.
3. **Apply to Player**:
   When `Player` is initialized in `PlayerScreen`:
   ```dart
   final settings = Provider.of<SettingsProvider>(context, listen: false);
   _player = Player(
     configuration: PlayerConfiguration(
       libass: true,
       bufferSize: settings.demuxerCacheMb * 1024 * 1024,
     ),
   );
   final cacheSecs = (settings.networkCachingMs / 1000.0).toStringAsFixed(1);
   (_player.platform as dynamic).setProperty('cache-secs', cacheSecs);
   (_player.platform as dynamic).setProperty(
     'demuxer-max-bytes',
     (settings.demuxerCacheMb * 1024 * 1024).toString(),
   );
   (_player.platform as dynamic).setProperty(
     'demuxer-max-back-bytes',
     (settings.demuxerCacheMb * 1024 * 1024).toString(),
   );
   ```

---

## 5. Verification Method

To independently verify all findings and test proposals:

1. **Verify Unit Tests for Gesture Engine**:
   ```powershell
   cd d:\E-player\app
   flutter test test/unit/cinematic_gesture_engine_test.dart
   ```
2. **Verify Desktop Keyboard Handler Tests**:
   ```powershell
   cd d:\E-player\app
   flutter test test/unit/desktop_keyboard_handler_test.dart
   ```
3. **Verify Video Effects Pipeline Tests**:
   ```powershell
   cd d:\E-player\app
   flutter test test/features/video_effects_test.dart
   ```
4. **Verify Settings Provider Tests**:
   ```powershell
   cd d:\E-player\app
   flutter test test/settings_provider_test.dart
   ```
5. **Static Analysis Invariant Verification**:
   ```powershell
   cd d:\E-player\app
   dart analyze
   ```
   Must pass with 0 errors and 0 warnings.
6. **Invalidation Conditions**:
   - If `(player.platform as dynamic).setProperty('volume-max', '300.0')` throws an unhandled exception on Android/iOS, verify the platform check.
   - If ffmpeg crop expressions with commas fail mpv filter graph parsing, use escaped commas (`\\,`) or computed integer dimensions `crop=$cropW:$cropH`.
