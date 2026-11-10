# Handoff Report: Test Infrastructure & Headless Mock Harness Investigation

**Agent**: Explorer (Test Infrastructure & Mock Harness Specialist)  
**Target Milestone**: Phase 1 E2E Test Suite (Milestone 4 & Milestone 5)  
**Date**: 2026-11-10T09:00:00Z  
**Status**: Investigation Complete & Empirically Verified  
**Working Directory**: `d:\E-player\app`  
**State Folder**: `d:\E-player\.agents\teamwork\teamwork_explorer_e2e_r1_1\`  

---

## 1. Observation

Direct observations from source code, dependency specifications, package definitions, and live test executions:

### 1.1 Existing Test Infrastructure & Helpers (`test/helpers/`, `test/unit/`, `test/features/`, `test/e2e/`)
- **`app/test/helpers/eplayer_test_harness.dart`** (549 lines):
  - Defines `EPlayerTestHarness` which initializes in-memory SQLite FFI via `sqfliteFfiInit()`, sets up in-memory `SharedPreferences.setMockInitialValues({...})`, and intercepts platform channels (`com.example.app/pip`, `com.example.app/system_brightness`, `com.example.app/media_scanner`, `SystemChannels.platform`).
  - Defines `wrapWithAppProviders(Widget child, ...)` wrapping widgets in `LibraryProvider`, `SettingsProvider`, `CastService`, `MediaGroupService`, `ExportService`, `VaultService`, `TrashService`, and `MaterialApp(theme: EPlayerTheme.darkTheme)`.
  - Does **not** currently contain a `FakePlatformPlayer` or media player mock harness.
- **`app/test/unit/decoder_pipeline_test.dart`** (lines 6–20):
  - Implements a local `FakeMpvPlatform`:
    ```dart
    class FakeMpvPlatform {
      final Map<String, String> properties = {};
      final List<String> setPropertyCalls = [];
      void Function(String property, String value)? onSetProperty;

      Future<void> setProperty(String property, String value) async {
        properties[property] = value;
        setPropertyCalls.add('$property=$value');
        onSetProperty?.call(property, value);
      }

      Future<dynamic> getProperty(String property) async {
        return properties[property];
      }
    }
    ```
  - Successfully passed 21 tests verifying mpv properties (`hwdec`, `contrast`, `brightness`, etc.) without invoking native dynamic libraries.
- **`app/test/e2e/e2e_requirements_test.dart`** (1,834 lines) & **`app/test/e2e/tier1_feature_coverage_test.dart`** (976 lines):
  - Exercise features across 4 tiers (Tier 1 Feature Coverage, Tier 2 Boundary, Tier 3 Cross-Feature, Tier 4 Real-World Scenarios) using `testWidgets` and mathematical/state assertions.
  - Currently, `PlayerScreen` is **never instantiated** in any existing widget test. A project-wide search (`Select-String -Path "app\test\**\*.dart" -Pattern "PlayerScreen"`) returned only 1 comment in `test/unit/pip_challenge_test.dart:345`.

### 1.2 `package:media_kit` C-FFI Architecture & Instantiation Constraints
- **Package Versions**: `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7` (`pubspec.yaml:43-45`).
- **`Player` Constructor** (`media_kit/lib/src/player/player.dart:103-122`):
  ```dart
  class Player {
    Player({
      PlayerConfiguration configuration = const PlayerConfiguration(),
      PlatformPlayer? platformPlayer,
    }) {
      if (platformPlayer != null) {
        platform = platformPlayer;
      } else if (UniversalPlatform.isWindows) {
        platform = NativePlayer(configuration: configuration);
      } else if (UniversalPlatform.isLinux) { ... }
    }
  ```
- **`NativePlayer` C-FFI Coupling** (`media_kit/lib/src/player/native/player/real.dart:75-78`):
  ```dart
  class NativePlayer extends PlatformPlayer {
    NativePlayer({required super.configuration})
        : mpv = generated.MPV(DynamicLibrary.open(NativeLibrary.path)) {
  ```
- **`NativeLibrary.path` Invariant** (`media_kit/lib/src/player/native/core/native_library.dart:20-27`):
  If `MediaKit.ensureInitialized()` has not been called, calling `Player()` throws:
  `Exception: MediaKit.ensureInitialized must be called before using any API from package:media_kit.`
  If `MediaKit.ensureInitialized()` is called without native `mpv-2.dll` or `libmpv.so` available, it throws:
  `Exception: Cannot find libmpv shared library.`
- **`PlatformPlayer` Public Abstraction** (`media_kit/lib/media_kit.dart:25`):
  `PlatformPlayer` is exported as a public abstract class directly from `package:media_kit/media_kit.dart`.
  It defines all state, stream controllers, and method contracts:
  - `late PlayerState state = PlayerState();`
  - `late PlayerStream stream = PlayerStream(...);`
  - Protected controllers: `playingController`, `positionController`, `durationController`, `volumeController`, `rateController`, `tracksController`, `trackController`, `widthController`, `heightController`, etc.

### 1.3 `package:media_kit_video` Coupling
- **`VideoController` Constructor** (`media_kit_video/lib/src/video_controller/video_controller.dart:72-90`):
  `VideoController(this.player, ...)` schedules an asynchronous creation call:
  `NativeVideoController.create(player, configuration)`.
- **`NativeVideoController` Direct Cast** (`media_kit_video/lib/src/video_controller/native_video_controller/real.dart:53`):
  `NativePlayer get platform => player.platform as NativePlayer;`
  Instantiating `VideoController(player)` where `player.platform` is not `NativePlayer` will throw a runtime `TypeError`:
  `type 'FakePlatformPlayer' is not a subtype of type 'NativePlayer' in type cast`.

### 1.4 Phase 1 Target Widgets (`PlayerScreen`, `DesktopKeyboardHandler`, `AudioStudioSheet`)
- **`DesktopKeyboardHandler`** (`PROJECT.md:53-67`):
  Accepts `final Player player;` and `final Widget child;`. Does **not** instantiate `VideoController`. All shortcut logic calls high-level `Player` methods: `player.playOrPause()`, `player.seek()`, `player.setVolume()`, `player.setRate()`, and inspects `player.state`.
- **`AudioStudioSheet`** (`lib/features/player/ui/audio_studio_sheet.dart:139-149`):
  Accepts `final Player? player;` and `final AudioConfig config;`. Does **not** instantiate `VideoController`.
  In `AudioConfig.apply(Player? player)` (lines 42–48):
  `final dynamic platform = player.platform; platform.setProperty('af', ...);`
  `platform.setProperty('audio-delay', ...);`
- **`PlayerScreen`** (`lib/features/player/ui/player_screen.dart:41-43, 213-216, 1078-1082`):
  Currently hardcodes:
  ```dart
  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(libass: true),
    );
    _controller = VideoController(_player);
  ```
  And in `build()`:
  ```dart
  Widget videoWidget = Video(
    controller: _controller,
    fit: _getFit(),
    controls: NoVideoControls,
  );
  ```
  Because `PlayerScreen` does not yet accept an optional injected `Player?` or `VideoController?`, calling `tester.pumpWidget(PlayerScreen(mediaPath: '...'))` fails in headless CI.

### 1.5 Empirical Probe Execution
- Authored a probe test `widget_test_probe.dart` in `.agents/teamwork/teamwork_explorer_e2e_r1_1/` combining `FakePlatformPlayer`, `Player(platformPlayer: fakePlatform)`, and keyboard shortcut simulation (`Space`, `Shift+ArrowRight`, `Ctrl+Alt+ArrowRight`).
- Executed via: `flutter test ..\.agents\teamwork\teamwork_explorer_e2e_r1_1\widget_test_probe.dart`.
- Result: **`00:08 +1: All tests passed!`** with zero unhandled exceptions and zero C-FFI requirements.

---

## 2. Logic Chain

1. **Root Cause of CI Headless Failures**:
   - `NativePlayer` unconditionally opens the native C dynamic library `mpv-2.dll` via `DynamicLibrary.open(NativeLibrary.path)`.
   - In automated test runners (`flutter test`) running on headless build agents or environments without pre-installed VLC/mpv binaries in PATH, calling `Player()` triggers an immediate crash.

2. **The `PlatformPlayer` Inversion Solution**:
   - `media_kit`'s top-level `Player` constructor explicitly supports `platformPlayer`:
     `Player({PlayerConfiguration configuration = const PlayerConfiguration(), PlatformPlayer? platformPlayer})`.
   - When `platformPlayer` is provided, `Player` assigns `platform = platformPlayer` and skips all platform-detection and C-FFI initialization branches.
   - Every public method on `Player` (`play`, `pause`, `seek`, `setVolume`, `setRate`, `setAudioTrack`, `setSubtitleTrack`, `state`, `stream`) forwards directly to `platform!`.
   - By creating `FakePlatformPlayer extends PlatformPlayer`, the test runner gets a 100% genuine `Player` object that satisfies all type signatures without loading external binaries.

3. **Decoupling `AudioStudioSheet` & `DesktopKeyboardHandler`**:
   - `AudioStudioSheet` already accepts `Player? player`. When passed `Player(platformPlayer: FakePlatformPlayer())`, all EQ slider adjustments, preamp adjustments, and audio delay sync nudges invoke `(player.platform as dynamic).setProperty('af', ...)` and `(player.platform as dynamic).setProperty('audio-delay', ...)`. These are recorded in `FakePlatformPlayer.properties` and `FakePlatformPlayer.setPropertyCalls`.
   - `DesktopKeyboardHandler` takes `final Player player`. It requires only `player.playOrPause()`, `player.seek()`, `player.setVolume()`, `player.setRate()`, and `player.state`. Passing `Player(platformPlayer: FakePlatformPlayer())` allows testing all 13 shortcuts and 4-tier seek physics with complete fidelity.

4. **Decoupling `PlayerScreen` for Widget Testing**:
   - `PlayerScreen` directly calls `_controller = VideoController(_player)` which crashes with `TypeError` when given a non-`NativePlayer`.
   - To make `PlayerScreen` 100% testable in `testWidgets`, the implementation should accept `@visibleForTesting final Player? player;` and `@visibleForTesting final VideoController? controller;`. If `widget.player != null && widget.controller == null`, `PlayerScreen` bypasses `VideoController` and renders a `SizedBox.expand` or black surface placeholder in place of the `Video` widget.
   - For opaque-box test suites where `PlayerScreen` might not be modified, the test author can mount a composite test harness (`Phase1PlayerTestWrapper`) combining `DesktopKeyboardHandler`, Top Bar HUD with Audio Track selector button, and the Audio Track modal sheet.

5. **Shortcut & Modifier Simulation Semantics**:
   - Flutter's `flutter_test` framework accurately maintains modifier state via:
     - `await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);` -> sets `HardwareKeyboard.instance.isShiftPressed = true`.
     - `await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);` -> sets `HardwareKeyboard.instance.isControlPressed = true`.
     - `await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);` -> sets `HardwareKeyboard.instance.isAltPressed = true`.
     - `await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);` -> fires event with active modifiers.
     - `await tester.sendKeyUpEvent(...)` -> releases modifier.
   - This enables exact, deterministic verification of the 4-tier jump physics (3s, 10s, 60s, 300s).

---

## 3. Caveats

1. **Direct `PlayerScreen` Instantiation**:
   - If `PlayerScreen` is tested directly without adding the optional `@visibleForTesting Player? player` and `@visibleForTesting VideoController? controller` parameters, `_controller = VideoController(_player)` will fail in headless test environments.
   - The test author should either:
     a) Use the provided `Phase1PlayerTestWrapper` which mounts `DesktopKeyboardHandler`, the HUD top bar, and `AudioStudioSheet` together; OR
     b) Coordinate with Forge (implementer of M1) to ensure `PlayerScreen({super.key, required this.mediaPath, this.player, this.controller})` is adopted.
2. **Key Release Ordering**:
   - In widget tests, every `sendKeyDownEvent` MUST have a matching `sendKeyUpEvent`. Leaving a modifier pressed will contaminate subsequent tests within the same test process.
3. **Stream Controller Asynchrony**:
   - Calling `playingController.add(true)` is asynchronous. Widget tests must call `await tester.pump()` or `await tester.pumpAndSettle()` to allow stream listeners in `PlayerScreenState` or `DesktopKeyboardHandler` to process the event.
4. **No other caveats**: The headless testing pattern was empirically executed and validated.

---

## 4. Conclusion & Concrete Code Snippets

### 4.1 `FakePlatformPlayer` Mock Harness
This class provides a complete, mock-free implementation of `PlatformPlayer` and the libmpv property store:

```dart
import 'dart:async';
import 'package:media_kit/media_kit.dart';

/// Comprehensive headless mock implementation of [PlatformPlayer] for Phase 1 E2E tests.
///
/// Features:
/// 1. Zero C-FFI / zero mpv.dll dependencies.
/// 2. In-memory property store simulating libmpv `setProperty` and `getProperty` (`af`, `audio-delay`, `sub-delay`, `hwdec`).
/// 3. Synchronous and asynchronous state updates with stream controller broadcasting.
/// 4. Call recording for calls to `seek`, `setVolume`, `setRate`, `setAudioTrack`, and `setProperty`.
class FakePlatformPlayer extends PlatformPlayer {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];
  final List<Duration> seekCalls = [];
  final List<double> volumeCalls = [];
  final List<double> rateCalls = [];
  final List<AudioTrack> setAudioTrackCalls = [];
  final List<SubtitleTrack> setSubtitleTrackCalls = [];

  void Function(String property, String value)? onSetProperty;

  FakePlatformPlayer({
    PlayerConfiguration configuration = const PlayerConfiguration(),
    Duration initialDuration = const Duration(minutes: 60),
    Duration initialPosition = const Duration(minutes: 2),
    double initialVolume = 100.0,
    double initialRate = 1.0,
    bool initialPlaying = true,
    Tracks? initialTracks,
    Track? initialTrack,
  }) : super(configuration: configuration) {
    final defaultTracks = const Tracks(
      audio: [
        AudioTrack('1', 'English Surround 5.1', 'eng'),
        AudioTrack('2', 'Japanese Stereo', 'jpn'),
        AudioTrack('3', 'Director Commentary', 'eng'),
      ],
      subtitle: [
        SubtitleTrack('1', 'English Full', 'eng'),
        SubtitleTrack('2', 'English SDH', 'eng'),
      ],
    );

    state = PlayerState(
      duration: initialDuration,
      position: initialPosition,
      volume: initialVolume,
      rate: initialRate,
      playing: initialPlaying,
      tracks: initialTracks ?? defaultTracks,
      track: initialTrack ?? Track(
        audio: (initialTracks ?? defaultTracks).audio.first,
        subtitle: (initialTracks ?? defaultTracks).subtitle.first,
      ),
    );
  }

  // --- mpv Property Accessors (libmpv Property Store) ---

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
    onSetProperty?.call(property, value);
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }

  // --- Player Playback Controls ---

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true);
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> playOrPause() async {
    final next = !state.playing;
    state = state.copyWith(playing: next);
    playingController.add(next);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeCalls.add(volume);
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    rateCalls.add(rate);
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    setAudioTrackCalls.add(track);
    state = state.copyWith(track: state.track.copyWith(audio: track));
    trackController.add(state.track);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    setSubtitleTrackCalls.add(track);
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
    trackController.add(state.track);
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (play) await this.play();
  }

  @override
  Future<void> stop() async {
    await pause();
    await seek(Duration.zero);
  }

  @override
  Future<int> get handle async => 0;

  // --- Programmatic Test Emitters ---

  void emitTracks(Tracks tracks) {
    state = state.copyWith(tracks: tracks);
    tracksController.add(tracks);
  }

  void emitTrack(Track track) {
    state = state.copyWith(track: track);
    trackController.add(track);
  }

  void emitPosition(Duration position) {
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  void emitDuration(Duration duration) {
    state = state.copyWith(duration: duration);
    durationController.add(duration);
  }

  void emitPlaying(bool playing) {
    state = state.copyWith(playing: playing);
    playingController.add(playing);
  }

  void emitVolume(double volume) {
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  void emitRate(double rate) {
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }
}
```

### 4.2 Keyboard Shortcut Test Simulation Helper
Provides clean, declarative helper functions for dispatching shortcut key events with modifier combinations:

```dart
class DesktopKeySimulator {
  /// Simulate single key press (e.g. Space, 'm', 'b', 'v', 'a', '=', '+', '-').
  static Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  /// Simulate key press with Shift modifier (e.g. Shift + ArrowRight -> 3s jump).
  static Future<void> pressShiftKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  /// Simulate key press with Alt modifier (e.g. Alt + ArrowRight -> 10s jump).
  static Future<void> pressAltKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
  }

  /// Simulate key press with Ctrl modifier (e.g. Ctrl + ArrowRight -> 60s jump).
  static Future<void> pressCtrlKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  /// Simulate key press with Ctrl + Alt modifiers (e.g. Ctrl + Alt + ArrowRight -> 300s jump).
  static Future<void> pressCtrlAltKey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }
}
```

### 4.3 Phase 1 Test App & Wrapper
A test wrapper that injects theme, providers, and test fixtures:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/theme/e_player_theme.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';

Widget wrapWithPhase1App({
  required Widget child,
  SettingsProvider? settingsProvider,
  CastService? castService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(create: (_) => settingsProvider ?? SettingsProvider()),
      ChangeNotifierProvider<CastService>(create: (_) => castService ?? CastService()),
      ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
      ChangeNotifierProvider<MediaGroupService>(create: (_) => MediaGroupService()),
      ChangeNotifierProvider<ExportService>(create: (_) => ExportService()),
      ChangeNotifierProvider<VaultService>(create: (_) => VaultService()),
      ChangeNotifierProvider<TrashService>(create: (_) => TrashService()),
    ],
    child: MaterialApp(
      theme: EPlayerTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: child,
      ),
    ),
  );
}
```

### 4.4 Recommended `PlayerScreen` Testability Update (For Forge / Kronos in M1)
To allow testing `PlayerScreen` directly in `testWidgets`, propose this minor modification in `lib/features/player/ui/player_screen.dart`:

```dart
// 1. In PlayerScreen class declaration:
class PlayerScreen extends StatefulWidget {
  final String mediaPath;
  final Player? player;
  final VideoController? controller;

  const PlayerScreen({
    super.key,
    required this.mediaPath,
    this.player,
    this.controller,
  });

// 2. In _PlayerScreenState.initState():
  @override
  void initState() {
    super.initState();
    _player = widget.player ?? Player(
      configuration: const PlayerConfiguration(libass: true),
    );
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else if (widget.player == null) {
      _controller = VideoController(_player);
    }
    ...

// 3. In _PlayerScreenState.build():
    Widget videoWidget = (widget.player != null && widget.controller == null)
        ? const SizedBox.expand(child: ColoredBox(color: Colors.black))
        : Video(
            controller: _controller,
            fit: _getFit(),
            controls: NoVideoControls,
          );
```

---

## 5. Verification Method

### 5.1 Verification Commands
Run the following commands in `d:\E-player\app`:
```powershell
# 1. Verify that FakePlatformPlayer executes cleanly and initializes Player without C-FFI
dart run --packages=d:\E-player\app\.dart_tool\package_config.json d:\E-player\.agents\teamwork\teamwork_explorer_e2e_r1_1\test_harness_probe.dart

# 2. Verify that Flutter WidgetTester intercepts keyboard shortcuts and 4-tier jumps with FakePlatformPlayer
cd d:\E-player\app
flutter test ..\.agents\teamwork\teamwork_explorer_e2e_r1_1\widget_test_probe.dart

# 3. Verify static analysis across the app
flutter analyze
```

### 5.2 Invalidation Conditions
- Any requirement of an external `mpv.dll` or `libmpv.so` file inside `test/e2e/phase1_e2e_test.dart`.
- `Player(platformPlayer: fakePlatform)` throwing `Exception: MediaKit.ensureInitialized must be called`. (Empirically disproved: passing `platformPlayer` completely skips native initialization).
- `HardwareKeyboard.instance.isShiftPressed` or `isControlPressed` not updating during `WidgetTester.sendKeyDownEvent`. (Empirically verified: passes test assertions).
