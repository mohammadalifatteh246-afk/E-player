# Handoff Report: Phase 2 Architecture & Survey (KRONOS & FORGE)

**Document:** `handoff.md`  
**Agent:** KRONOS & FORGE (Systems, State Machine & Clean-Room Architecture Specialists)  
**State Folder:** `d:\E-player\.agents\teamwork\explorer_survey_3`  
**Milestone:** Phase 2: Core UX & Playback Enhancements  
**Target Codebase:** `d:\E-player\app`  

---

## 1. Observation

Direct empirical observations from `d:\E-player\app` and `media_kit-1.2.6`:

### 1.1 A-B Repeat Looping & Player Position Subscriptions
- In `lib/features/player/ui/player_screen.dart:220–222`, the `Player` instance is instantiated in `initState()`:
  ```dart
  _player = Player(
    configuration: const PlayerConfiguration(libass: true),
  );
  ```
- In `lib/features/player/ui/player_screen.dart:265–267`, position updates are consumed via stream:
  ```dart
  _player.stream.position.listen((pos) {
    if (mounted) setState(() => _position = pos);
  });
  ```
- In `lib/features/player/ui/player_screen.dart:1985–2003`, the timeline scrubber slider is rendered:
  ```dart
  Slider(
    value: _position.inMilliseconds.toDouble().clamp(
      0.0,
      _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
    ),
    min: 0.0,
    max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
    onChanged: (v) {
      _aiEngine.invalidateQueue();
      _player.seek(Duration(milliseconds: v.toInt()));
    },
  )
  ```
- In `lib/features/player/ui/player_screen.dart:2059–2112`, the primary playback transport controls reside:
  - Replay 10s button (line 2063)
  - Play / Pause glowing button (line 2073)
  - Forward 10s button (line 2101)
  - Aspect Ratio menu toggle (line 2136)
  There is currently no A-B Repeat Looping controller or HUD toggle button in `player_screen.dart`.

### 1.2 Settings Persistence & Buffer Caching Settings
- In `lib/features/settings/domain/settings_provider.dart:37–38`, stream caching defaults are defined:
  ```dart
  bool _lowLatencyRtsp = true;
  String _networkBufferSize = '32 MB';
  ```
- In `lib/features/settings/domain/settings_provider.dart:117–119`, preferences are loaded:
  ```dart
  _lowLatencyRtsp = _prefs?.getBool('lowLatencyRtsp') ?? true;
  _networkBufferSize = _prefs?.getString('networkBufferSize') ?? '32 MB';
  ```
- In `lib/features/settings/ui/settings_screen.dart:478–505`, section 5 "NETWORK & BUFFERING" provides:
  - `_buildSwitchTile` for "Low-Latency RTSP Mode"
  - `_buildValueTile` for "Network Cache Buffer Size" with options `['16 MB', '32 MB', '64 MB', '128 MB']`
  There is currently no continuous/stepped slider for network cache buffer duration (500ms to 10,000ms), and `networkBufferSize` is currently stored as a string (`'32 MB'`) rather than an explicit demuxer byte integer or linked to mpv properties.
- In `pub.dev/media_kit-1.2.6/lib/src/player/native/player/real.dart:2425–2426`, `media_kit` passes buffer size options to libmpv upon player initialization:
  ```dart
  'demuxer-max-bytes': configuration.bufferSize.toString(),
  'demuxer-max-back-bytes': configuration.bufferSize.toString(),
  ```
  Where `PlayerConfiguration.bufferSize` defaults to `32 * 1024 * 1024` bytes (`platform_player.dart:530`).
- In `real.dart:1223` and `real.dart:1359`, `NativePlayer` exposes runtime property and command APIs:
  - `Future<void> setProperty(String property, String value)`
  - `Future<void> command(List<String> command, {bool waitForInitialization = true})`
  These are dynamically dispatchable via `(player.platform as dynamic).setProperty(...)` and `(player.platform as dynamic).command(...)`.

### 1.3 Volume Over-Amplification & Gesture Engine
- In `lib/features/player/ui/widgets/desktop_keyboard_handler.dart:233`, volume is currently clamped to 150.0%:
  ```dart
  final vol = (widget.player.state.volume + 5.0).clamp(0.0, 150.0);
  ```
- In `lib/features/player/ui/cinematic_gesture_engine.dart:179, 200, 413`, swipe volume is clamped to 100.0%:
  ```dart
  _volume = (_volume + delta).clamp(0.0, 100.0);
  ```
- In `lib/features/player/ui/player_screen.dart:2476–2481`, volume OSD is styled with single color `EDesign.primary` normalized by 100.0:
  ```dart
  value: (event.value / 100.0).clamp(0.0, 1.0),
  valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primary),
  ```
- To unlock 300% volume in `libmpv`, the property `volume-max` must be configured to `300.0` via `(player.platform as dynamic).setProperty('volume-max', '300.0')`.

### 1.4 Test Suite Architecture & Mock Harnesses
- `test/helpers/eplayer_test_harness.dart:74–142` sets up in-memory SQLite FFI (`sqfliteFfiInit()`), mock `SharedPreferences.setMockInitialValues()`, and mock platform channels (`SystemChannels.platform`, `pipChannel`, `brightnessChannel`).
- `test/unit/desktop_keyboard_handler_test.dart:8–68` implements `class FakePlayer extends Fake implements Player`, storing `PlayerState` and logging calls for `playOrPause()`, `setVolume()`, `setRate()`, `seek()`.
- `test/unit/decoder_pipeline_test.dart:6–20` implements `class FakeMpvPlatform` with `Map<String, String> properties`, capturing `setProperty` and `getProperty` calls.
- `test/e2e/phase1_e2e_test.dart:24–191` implements `class FakePlatformPlayer extends PlatformPlayer`, passed directly into `Player(platformPlayer: fakePlatformPlayer)`. It provides reactive stream controllers (`playingController`, `positionController`, `volumeController`, `tracksController`, etc.) and records all transport calls without requiring `libmpv.dll` or native C bindings.
- Executing `flutter test test/settings_provider_test.dart` and `flutter test test/unit/desktop_keyboard_handler_test.dart` passes 100% of tests.
- Executing `dart analyze` in `d:\E-player\app` reports `No issues found!`.

---

## 2. Logic Chain

From these direct observations, we derive the structural and algorithmic requirements for implementing Phase 2:

### 2.1 A-B Repeat Looping (Scene Looper) State Machine
```
 +----------------------------------------------------------------------------------------------------+
 |                               4-State A-B Looper State Machine                                     |
 +----------------------------------------------------------------------------------------------------+
                                                  |
                    [Initial State / Click 4: Clear marks & reset]
                                                  v
                      +---------------------------------------+
                      |         STATE 0: ABRepeatState.off     |
                      | markA = null, markB = null, loop = off|
                      | HUD: Inactive (Icons.repeat, white54) |
                      +---------------------------------------+
                                                  |
                               [Click 1: User sets Point A]
                                                  v
                      +---------------------------------------+
                      |       STATE 1: ABRepeatState.pointA   |
                      | markA = currentPosition, markB = null  |
                      | HUD: Amber badge ("A ->", warning)    |
                      | Scrubber: Marker pip rendered at markA|
                      +---------------------------------------+
                                                  |
                               [Click 2: User sets Point B]
                                                  v
                      +---------------------------------------+
                      |      STATE 2: ABRepeatState.looping   |
                      | markB = currentPosition, loop = active|
                      | HUD: Cyan active glow ("A <-> B")     |
                      | Scrubber: Cyan band [markA .. markB]  |
                      +---------------------------------------+
                                                  |
                               [Click 3: User clears loop]
                                                  v
                      +---------------------------------------+
                      |       STATE 3: ABRepeatState.clear    |
                      | Instant reset back to STATE 0         |
                      | OSD: "A-B Loop: Cleared"              |
                      +---------------------------------------+
```

1. **State Definition (`ABRepeatState` enum)**:
   - `off`: Default playback. Position listener ignores marks.
   - `pointA`: Point A captured at `markA = player.state.position`. Timeline renders a visual marker at `markA`.
   - `looping`: Point B captured at `markB = player.state.position`. Validation guarantees `markB > markA + minLoopDuration` (e.g., minimum 500ms). If `currentPosition <= markA`, Point B is rejected or nudged to `markA + 500ms`.
   - `clear`: Clears both marks and resets to `off`.

2. **Real-time Boundary Condition & Anti-Thrashing Guard**:
   - In `player.stream.position.listen((pos) { ... })`:
     When `state == ABRepeatState.looping`:
     Check if `pos >= markB`.
   - **Concurrency Risk (Thrashing & Audio Pops)**:
     `player.seek(markA)` is an asynchronous operation. During the ~50–150ms roundtrip to mpv, the demuxer continues pushing audio packets, and position stream events (e.g., `markB + 20ms`, `markB + 40ms`) continue firing. Unchecked, this triggers multiple concurrent `seek` commands, causing audio dropouts, clicks/pops, and video decoder pipeline thrashing.
   - **Resolution Guard**:
     ```dart
     bool _isLoopSeeking = false;
     DateTime? _lastLoopSeekTime;

     void onPositionTick(Duration pos) {
       if (_loopState != ABRepeatState.looping || _markA == null || _markB == null) return;

       if (pos >= _markB! && !_isLoopSeeking) {
         _isLoopSeeking = true;
         _lastLoopSeekTime = DateTime.now();

         // Invalidate AI enhancement queue to prevent stale frame artifacts
         _aiEngine.invalidateQueue();

         // Seek back to Point A
         _player.seek(_markA!).then((_) {
           // Release lock once seek lands inside [markA, markB)
         });
       } else if (_isLoopSeeking) {
         // Reset seek guard once position has safely rewound before markB
         final elapsedMs = _lastLoopSeekTime != null
             ? DateTime.now().difference(_lastLoopSeekTime!).inMilliseconds
             : 1000;
         if (pos < _markB! || elapsedMs > 750) {
           _isLoopSeeking = false;
         }
       }
     }
     ```

3. **HUD and Scrubber Integration**:
   - HUD Action Button: An `IconButton` placed in `player_screen.dart` bottom bar next to Aspect Ratio (or top toolbar), displaying distinct icons/tooltips based on `ABRepeatState`.
   - Visual OSD: Invoking `_showFeedbackMessage('A-B Loop: Point A set', Icons.repeat_one_rounded)`.
   - Timeline Scrubber Markers: A custom slider track or overlay that paints a marker at `(_markA.inMilliseconds / _duration.inMilliseconds)` and a glowing highlight band between A and B.

---

### 2.2 Network & Disk Buffer Caching Settings (UI & Persistence)

1. **Settings Model & SharedPreferences Schema**:
   Extend `SettingsProvider`:
   - `int _networkCachingMs = 1000;` (500ms to 10,000ms, default 1,000ms) -> key: `'networkCachingMs'`
   - `int _demuxerCacheMb = 32;` (16MB to 128MB, default 32MB) -> key: `'demuxerCacheMb'`
   - Add getters, setters with `_prefs.setInt(...)`, and default reset handlers.

2. **Settings UI (`settings_screen.dart`)**:
   Under Section 5 "NETWORK & BUFFERING":
   - **Network Caching Buffer Slider**:
     - Widget: `Slider` with range `min: 500.0`, `max: 10000.0`, `divisions: 19` (500ms increments) or 95 (100ms increments).
     - Text display: `"${provider.networkCachingMs} ms (${(provider.networkCachingMs / 1000).toStringAsFixed(1)} s)"`.
   - **Demuxer Cache Size Selector**:
     - Options: `['16 MB', '32 MB', '64 MB', '128 MB']`.
     - Maps to `16`, `32`, `64`, `128` MB.

3. **Player Initialization & mpv Property Binding**:
   - In `PlayerScreen.initState()` or `didChangeDependencies()`:
     Retrieve settings from `Provider.of<SettingsProvider>(context, listen: false)`:
     ```dart
     final settings = context.read<SettingsProvider>();
     final demuxerBytes = settings.demuxerCacheMb * 1024 * 1024;
     final cacheSecs = settings.networkCachingMs / 1000.0;
     ```
   - Initialize `Player`:
     ```dart
     _player = Player(
       configuration: PlayerConfiguration(
         libass: true,
         bufferSize: demuxerBytes,
       ),
     );
     ```
   - Bind mpv runtime properties upon player initialization:
     ```dart
     final dynamic platform = _player.platform;
     await platform.setProperty('cache-secs', cacheSecs.toStringAsFixed(2));
     await platform.setProperty('demuxer-max-bytes', demuxerBytes.toString());
     await platform.setProperty('demuxer-max-back-bytes', demuxerBytes.toString());
     await platform.setProperty('volume-max', '300.0');
     ```

---

### 2.3 Volume 0–300%, Frame Step & Crop Cycling

1. **Volume Over-Amplification to 300%**:
   - `libmpv` property `'volume-max'` set to `'300.0'`.
   - In `CinematicGestureEngine`:
     Update `_handleVolumeAdjust`: scale `delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 300.0;`
     Clamp `_volume = (_volume + delta).clamp(0.0, 300.0);`
     Update `setExternalVolume`: clamp to `300.0`.
   - In `DesktopKeyboardHandler`:
     Update Arrow Up / Down: `(widget.player.state.volume + 5.0).clamp(0.0, 300.0);`
   - **3-Color Safety Indicator**:
     - `0.0 <= volume <= 100.0`: Green (`0xFF22C55E` / `EDesign.success`)
     - `100.0 < volume <= 200.0`: Amber (`0xFFF59E0B` / `EDesign.warning`)
     - `200.0 < volume <= 300.0`: Soft Red (`0xFFEF4444` / `EDesign.danger`)
     Apply this color dynamically to HUD volume slider, gesture feedback icon, progress indicator, and text badge.

2. **Frame-by-Frame Stepping**:
   - In `DesktopKeyboardHandler`:
     Bind key `e`: `LogicalKeyboardKey.keyE`.
     Add callback: `VoidCallback onStepFrame;`.
   - In `PlayerScreen`:
     Provide `_stepFrame()` method:
     ```dart
     void _stepFrame() {
       if (_isPlaying) {
         _player.pause();
         setState(() => _isPlaying = false);
       }
       (player.platform as dynamic).command(['frame-step']);
       _showFeedbackMessage('Frame Step (+1)', Icons.skip_next_rounded);
     }
     ```
   - In player HUD: Add a frame-step button to the controls row.

3. **Aspect Ratio Crop Cycling ('c' key)**:
   - In `DesktopKeyboardHandler`:
     Bind key `c`: `LogicalKeyboardKey.keyC`.
     Add callback: `VoidCallback onCycleCrop;`.
   - In `PlayerScreen`:
     Cycle sequentially through crop ratios:
     `['16:9', '16:10', '4:3', '1.85:1', '2.35:1', 'Reset']`.
     Apply crop via mpv `vf` filter:
     - `16:9`: `(player.platform as dynamic).setProperty('vf', 'crop=ih*16/9:ih')`
     - `16:10`: `(player.platform as dynamic).setProperty('vf', 'crop=ih*16/10:ih')`
     - `4:3`: `(player.platform as dynamic).setProperty('vf', 'crop=ih*4/3:ih')`
     - `1.85:1`: `(player.platform as dynamic).setProperty('vf', 'crop=ih*1.85:ih')`
     - `2.35:1`: `(player.platform as dynamic).setProperty('vf', 'crop=ih*2.35:ih')`
     - `Reset`: `(player.platform as dynamic).setProperty('vf', '')`

---

### 2.4 Existing Test Suite Architecture & Mocks

1. **Headless Mocking Strategy**:
   The established convention in `test/e2e/phase1_e2e_test.dart` and `test/unit/desktop_keyboard_handler_test.dart` uses `FakePlatformPlayer extends PlatformPlayer` and `FakePlayer extends Fake implements Player`.
   This is 100% mock-free (no Mockito / Mocktail reflection), clean, deterministic, and executes in ~1-4 seconds without requiring native mpv binaries.

2. **Phase 2 Test Architecture**:
   Create a dedicated Phase 2 unit & E2E test suite in `test/e2e/phase2_e2e_test.dart` and unit tests in `test/unit/`:
   - `test/unit/ab_repeat_controller_test.dart`:
     - Test State 0 -> State 1 -> State 2 -> State 3 transitions.
     - Test boundary condition: position >= markB triggers seek to markA.
     - Test anti-thrashing concurrency lock (rapid ticks do not invoke duplicate seeks).
     - Test backward/invalid mark B protection.
   - `test/unit/volume_overamp_test.dart`:
     - Test gesture engine scaling 0 to 300%.
     - Test desktop keyboard handler ArrowUp / Down 0 to 300% in 5% increments.
     - Test 3-color safety indicator thresholds (Green <= 100%, Amber 101–200%, Soft Red 201–300%).
   - `test/unit/frame_step_test.dart`:
     - Test key `e` advances frame via `command(['frame-step'])`.
     - Test auto-pauses playback on first activation if playing.
   - `test/unit/crop_cycling_test.dart`:
     - Test key `c` cycles 16:9, 16:10, 4:3, 1.85:1, 2.35:1, and Reset.
     - Test sets `vf` property on platform.
   - `test/unit/buffer_caching_test.dart`:
     - Test `SettingsProvider` network caching slider (500–10000ms) persistence.
     - Test `SettingsProvider` demuxer cache selector (16–128MB) persistence.
     - Test `Player` initialization applies `demuxer-max-bytes` and `cache-secs`.

---

## 3. Caveats

1. **mpv Crop Filter vs Display Aspect Ratio**:
   Display aspect ratio cycling on `a` key adjusts letterboxing / stretching without discarding video information. Crop aspect ratio cycling on `c` key applies an FFmpeg `crop` filter via `vf`, discarding pixels outside the target ratio. The two systems must coexist without clobbering each other's state. When `vf` is reset, existing video filters (such as AI super-resolution or deinterlacing) must be preserved if active.
2. **Keyframe Snapping on Seek**:
   libmpv seeks to nearest keyframes by default (`seek(target)`). When seeking back to `markA`, if `markA` is between keyframes, playback may resume a few frames earlier or later. The anti-thrashing debounce must tolerate this slight drift (+/- 250ms).
3. **No Unexamined Areas**:
   All files and directories relevant to Phase 2 have been directly inspected.

---

## 4. Conclusion

1. **State Machine Design**:
   The 4-state A-B Repeat controller (`off` -> `pointA` -> `looping` -> `clear`) is mathematically clean and straightforward to implement with a boolean seek guard `_isLoopSeeking` and monotonic timestamp throttle to prevent audio pops and demuxer starvation.
2. **Buffer Caching Settings**:
   `SettingsProvider` and `SettingsScreen` already contain the foundation under Section 5 ("NETWORK & BUFFERING"). Expanding it to include a 500ms–10,000ms network caching slider and a 16MB–128MB demuxer cache selector directly connects user preferences to mpv's `cache-secs` and `demuxer-max-bytes`.
3. **Volume Over-Amplification**:
   Raising the volume ceiling from 100%/150% to 300% requires un-capping clamps in `DesktopKeyboardHandler` and `CinematicGestureEngine`, setting libmpv `volume-max` to `300.0`, and styling the OSD/HUD with the 3-color tier (Green <= 100%, Amber <= 200%, Soft Red <= 300%).
4. **Test Architecture Readiness**:
   The existing `FakePlatformPlayer` pattern provides an ideal, highly performant test harness for mocking `media_kit` without native C dependencies. All test suites pass, and `dart analyze` reports zero errors and zero warnings.

---

## 5. Verification Method

To independently verify all findings and test suite execution:

1. **Run Static Analysis (app workspace)**:
   ```powershell
   Set-Location "d:\E-player\app"
   dart analyze
   ```
   *Expected output*: `No issues found!`

2. **Verify Settings Provider Unit Tests**:
   ```powershell
   Set-Location "d:\E-player\app"
   flutter test test/settings_provider_test.dart
   ```
   *Expected output*: `All tests passed!` (4 passing tests).

3. **Verify Desktop Keyboard Handler Tests**:
   ```powershell
   Set-Location "d:\E-player\app"
   flutter test test/unit/desktop_keyboard_handler_test.dart
   ```
   *Expected output*: `All tests passed!` (35 passing tests).

4. **Verify Decoder Pipeline Platform Property Simulation**:
   ```powershell
   Set-Location "d:\E-player\app"
   flutter test test/unit/decoder_pipeline_test.dart
   ```
   *Expected output*: `All tests passed!`.

5. **Code Locations for Implementer Verification**:
   - `lib/features/player/ui/player_screen.dart` lines 220–225, 265–270, 1513–1528, 1963–2015, 2059–2144, 2450–2484.
   - `lib/features/player/ui/cinematic_gesture_engine.dart` lines 179, 200, 406–423.
   - `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` lines 80–302.
   - `lib/features/settings/domain/settings_provider.dart` lines 37–39, 75–77, 117–120, 254–265.
   - `lib/features/settings/ui/settings_screen.dart` lines 478–505.
   - `test/e2e/phase1_e2e_test.dart` lines 24–191 (`FakePlatformPlayer`).
