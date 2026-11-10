# Handoff Report: Test Strategy & Clean-Room Headless Test Harness for Desktop Keyboard Shortcuts

**Agent**: Explorer 3 (Test Strategy & Clean-Room Headless Harness)  
**Target Milestone**: Milestone 1 (Desktop Keyboard Shortcuts & 4-Tier Seek Physics)  
**Deliverable Scope**: `test/unit/desktop_keyboard_handler_test.dart` and `DesktopKeyboardHandler` testability design  
**Date**: 2026-11-10T08:55:00Z  
**Status**: Complete  

---

## 1. Observation

Direct forensic observations from inspecting the codebase, test suites, and framework packages:

### 1.1 Native C-FFI Player Dependency & Headless Failure Mechanism
- **Native Dependency in `media_kit`**: In `pubspec.yaml:43-45`, `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, and `media_kit_libs_video: ^1.0.7` are declared.
- **`Player` Instantiation**: In `media_kit/lib/src/player/player.dart` lines 101-120:
  ```dart
  Player({
    PlayerConfiguration configuration = const PlayerConfiguration(),
    PlatformPlayer? platformPlayer,
  }) {
    if (platformPlayer != null) {
      platform = platformPlayer;
    } else if (UniversalPlatform.isWindows) {
      platform = NativePlayer(configuration: configuration);
    ...
  ```
- **Failure Root Cause**: When `Player()` is instantiated without passing `platformPlayer`, it defaults to `NativePlayer`. `NativePlayer` calls `MediaKit.ensureInitialized()`, which invokes `dart:ffi` `DynamicLibrary.open('mpv-2.dll')` (on Windows), `libmpv.so` (on Linux), or `libmpv.dylib` (on macOS).
- In headless test execution (`flutter test`), the test process runs inside a standalone headless Dart VM (`flutter_tester.exe`). The runtime PATH does not contain the native build artifacts directory (`build/windows/runner/Debug/mpv-2.dll`).
- Attempting to instantiate a bare `Player()` in headless widget tests throws `Bad state: The [Player] from package:media_kit is not initialized.` or unhandled dynamic library loading errors, or spawns native OS threads with active C finalizers that hang headless runners.
- **Existing Precedent in `decoder_pipeline_test.dart`**:
  In `test/unit/decoder_pipeline_test.dart:148-150`:
  ```dart
  fakePlatform = FakeMpvPlatform();
  service = DecoderPipelineService();
  await service.initialize(null, fakePlatform);
  ```
  `DecoderPipelineService` tests completely bypass `Player()` by injecting `null` for `player` and passing `FakeMpvPlatform` as custom platform delegate. Running `flutter test test/unit/decoder_pipeline_test.dart` passed 21 out of 21 tests in 2 seconds.

### 1.2 `DesktopKeyboardHandler` Contract & Architecture
- In `d:\E-player\PROJECT.md:53-67` and `d:\E-player\.agents\teamwork\explorer_shortcuts_player\handoff.md:244-268`:
  The draft interface contract is:
  ```dart
  class DesktopKeyboardHandler extends StatefulWidget {
    final Player player;
    final Widget child;
    final VoidCallback onToggleFullscreen;
    final VoidCallback onCycleAspectRatio;
    final VoidCallback onCycleAudioTrack;
    final VoidCallback onCycleSubtitleTrack;
    final Function(int offsetMs) onNudgeAudioDelay;
    final Function(int offsetMs) onNudgeSubtitleDelay;
    final Function(String message, IconData icon) onShowOsd;
    final VoidCallback onUserActivity;
  }
  ```
- **Seeking Side Effects in `PlayerScreen`**:
  In `lib/features/player/ui/player_screen.dart:1724-1729, 1763-1768`:
  Every seek operation must invalidate the native AI frame processing queue:
  ```dart
  final newPos = _position + const Duration(seconds: 10);
  _aiEngine.invalidateQueue();
  _player.seek(newPos > _duration ? _duration : newPos);
  _showControls();
  ```
  If `DesktopKeyboardHandler` directly invokes `player.seek()` without notifying `PlayerScreen`, `_aiEngine.invalidateQueue()` is bypassed.

### 1.3 Hardware Keyboard Simulation in Flutter Tests
- In Flutter's test framework (`flutter_test`):
  - `tester.sendKeyEvent(LogicalKeyboardKey key)` sends a `KeyDownEvent` followed immediately by a `KeyUpEvent`.
  - `tester.sendKeyDownEvent(LogicalKeyboardKey key)` holds the key down, updating `HardwareKeyboard.instance` state (`isShiftPressed`, `isAltPressed`, `isControlPressed`, `isMetaPressed`).
  - `tester.sendKeyUpEvent(LogicalKeyboardKey key)` releases the held key.
  - To simulate modifier + key combinations, holding the modifier key across the primary key dispatch is required:
    ```dart
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    ```
- **Focus Requirement**: `Focus` widgets intercept key events only when their `FocusNode` has active keyboard focus (`hasFocus == true`). In `testWidgets`, `DesktopKeyboardHandler`'s autofocus requires `await tester.pumpAndSettle()` after widget tree mounting.

---

## 2. Logic Chain

From the direct observations, the following causal reasoning guides the test design and harness implementation:

1. **Clean-Room Headless Decoupling (Resolving Question 1)**:
   - *Observation 1.1*: `Player`'s constructor accepts an optional `PlatformPlayer? platformPlayer`. When provided, `NativePlayer` is never constructed and `DynamicLibrary.open` is never invoked.
   - *Logic*: By defining a `FakePlatformPlayer extends PlatformPlayer` in the test file or test helpers, a fully compliant `Player` instance can be instantiated in memory with zero C-FFI / DLL requirements:
     `final fakePlayer = Player(platformPlayer: FakePlatformPlayer());`
   - This satisfies the type requirement `final Player player` in `DesktopKeyboardHandler` without risking any missing DLL errors in headless environments (Windows, Linux, macOS CI).

2. **Testable Delegation Pattern (Resolving Question 2)**:
   - *Observation 1.2*: `PlayerScreen` needs to intercept seek events to run `_aiEngine.invalidateQueue()` and `_showControls()`. Furthermore, testing `DesktopKeyboardHandler` should ideally be possible both with a fake player and with direct test spies.
   - *Logic*: Structure `DesktopKeyboardHandler` with:
     ```dart
     final Player? player; // Optional or defaulted
     final void Function(Duration target, int jumpSeconds, String tierName)? onSeek;
     final VoidCallback? onPlayPause;
     final ValueChanged<double>? onVolumeChanged;
     final ValueChanged<double>? onRateChanged;
     ```
   - When callbacks are supplied, `DesktopKeyboardHandler` delegates directly to the callback. When omitted, it operates on `player`. This guarantees:
     1. In production: `PlayerScreen` supplies `onSeek`, ensuring `_aiEngine.invalidateQueue()` is called before `_player.seek(target)`.
     2. In tests: Tests can assert on callback parameters (`target`, `jumpSeconds`, `tierName`) directly, or supply `FakePlatformPlayer`.

3. **Key Event & Modifier Simulation Protocol (Resolving Question 3)**:
   - *Observation 1.3*: `HardwareKeyboard.instance` maintains a set of currently pressed keys.
   - *Logic*: In modern Flutter desktop applications, users may press `Ctrl` (Windows/Linux) or `Command/Meta` (macOS). The handler must evaluate:
     `final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;`
   - In widget tests, we verify both `controlLeft` and `metaLeft` produce the same 60s (Tier 3) and 300s (Tier 4) seek actions.
   - Sequence for test execution:
     1. Mount widget inside `MaterialApp` and `Scaffold`.
     2. Call `await tester.pumpAndSettle()` to let autofocus claim primary focus.
     3. Verify `FocusScope.of(context).hasFocus` is true.
     4. Dispatch key sequences using `tester.sendKeyDownEvent` / `tester.sendKeyEvent` / `tester.sendKeyUpEvent`.
     5. Call `await tester.pump()` to flush microtasks and setState.

4. **Modifier Precedence & Boundary Clamping (Resolving Question 4)**:
   - VLC Specification Cascade:
     - Tier 4: `Ctrl + Alt` (300 seconds) -> Scene jump. Must be evaluated first so holding `Ctrl + Alt` does not trigger Tier 3 (Ctrl only) or Tier 2 (Alt only).
     - Tier 3: `Ctrl` or `Meta` (60 seconds) -> Intro/recap skip.
     - Tier 2: `Alt` (10 seconds) -> Sentence skip.
     - Tier 1: `Shift` (3 seconds) -> Dialogue clarification.
     - Default: Bare `Arrow Left / Right` (10 seconds) -> Standard seek.
   - Clamping logic:
     - Underflow: `target < Duration.zero ? Duration.zero : target`.
     - Overflow: `duration > Duration.zero && target > duration ? duration : target`.
     - Zero Duration: When media has not loaded or is a live stream (`duration == Duration.zero`), forward seeks must not clamp to `Duration.zero`.

---

## 3. Comprehensive Test Specification Matrix

The following test suites must be authored in `test/unit/desktop_keyboard_handler_test.dart`:

### 3.1 Test Harness Definition (`FakePlatformPlayer`)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class FakePlatformPlayer extends PlatformPlayer {
  FakePlatformPlayer() : super(configuration: const PlayerConfiguration());

  final List<String> calls = [];
  bool isPlayingState = false;
  double volumeState = 100.0;
  double rateState = 1.0;
  Duration positionState = Duration.zero;
  Duration durationState = const Duration(minutes: 10);

  @override
  PlayerState get state => PlayerState(
        playing: isPlayingState,
        volume: volumeState,
        rate: rateState,
        position: positionState,
        duration: durationState,
      );

  @override
  Future<void> play() async {
    calls.add('play');
    isPlayingState = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    isPlayingState = false;
  }

  @override
  Future<void> playOrPause() async {
    calls.add('playOrPause');
    isPlayingState = !isPlayingState;
  }

  @override
  Future<void> seek(Duration target) async {
    calls.add('seek:$target');
    positionState = target;
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume:$volume');
    volumeState = volume;
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('setRate:$rate');
    rateState = rate;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

### 3.2 Detailed Test Case Catalog

#### Group 1: 4-Tier Seek Physics & Modifier Hierarchy (12 Tests)
1. **Tier 1 Forward**: `Shift + ArrowRight` -> seeks forward by exactly `+3 seconds` (`jumpSeconds == 3`, `tierName == 'Dialogue Jump (3s)'`).
2. **Tier 1 Backward**: `Shift + ArrowLeft` -> seeks backward by `-3 seconds`.
3. **Tier 2 Forward**: `Alt + ArrowRight` -> seeks forward by exactly `+10 seconds` (`jumpSeconds == 10`, `tierName == 'Short Jump (10s)'`).
4. **Tier 2 Backward**: `Alt + ArrowLeft` -> seeks backward by `-10 seconds`.
5. **Tier 3 Forward (Ctrl)**: `Ctrl + ArrowRight` -> seeks forward by exactly `+60 seconds` (`jumpSeconds == 60`, `tierName == 'Medium Jump (1m)'`).
6. **Tier 3 Backward (Ctrl)**: `Ctrl + ArrowLeft` -> seeks backward by `-60 seconds`.
7. **Tier 3 macOS Meta**: `Meta + ArrowRight` -> seeks forward by `+60 seconds` (verifies Mac Command key normalization).
8. **Tier 4 Forward (Ctrl + Alt)**: `Ctrl + Alt + ArrowRight` -> seeks forward by exactly `+300 seconds` (`jumpSeconds == 300`, `tierName == 'Long Jump (5m)'`).
9. **Tier 4 Backward (Ctrl + Alt)**: `Ctrl + Alt + ArrowLeft` -> seeks backward by `-300 seconds`.
10. **Default Arrow Seek**: Bare `ArrowRight` -> seeks forward by `+10 seconds`; bare `ArrowLeft` -> seeks backward by `-10 seconds`.
11. **Modifier Precedence Cascade (Ctrl + Alt + Shift)**: Holding `Ctrl + Alt + Shift + ArrowRight` triggers Tier 4 (300s), NOT Shift (3s).
12. **Modifier Precedence Cascade (Ctrl + Shift)**: Holding `Ctrl + Shift + ArrowRight` triggers Tier 3 (60s), NOT Shift (3s).

#### Group 2: Seek Boundary Clamping & Edge Cases (5 Tests)
13. **Underflow Clamping at Duration.zero**: When current position is `00:00:02`, `Shift + ArrowLeft` (-3s) or `Alt + ArrowLeft` (-10s) clamps strictly to `Duration.zero` (never negative).
14. **Large Jump Underflow**: When at `00:01:15`, `Ctrl + Alt + ArrowLeft` (-300s) clamps to `Duration.zero`.
15. **Overflow Clamping at EOF**: When video duration is `00:10:00` and current position is `00:09:40`, `Ctrl + ArrowRight` (+60s) clamps strictly to `00:10:00`.
16. **Zero Duration Video (Live Stream / Buffering Guard)**: When `durationState == Duration.zero`, forward seek calculates `position + delta` without clamping to `Duration.zero`.
17. **Repeated Boundary Seek**: Seeking backward while already at `Duration.zero` remains at `Duration.zero` without throwing exceptions.

#### Group 3: Transport & Playback Shortcuts (3 Tests)
18. **Space (Play/Pause Toggle)**: Pressing `Space` calls `playOrPause()` and triggers `onShowOsd` with 'Play' or 'Pause'.
19. **Space User Activity**: Pressing `Space` invokes `onUserActivity()`.
20. **Key 'e' (Frame Stepping)**: Pressing `e` steps forward one video frame and pauses if playing.

#### Group 4: Window & Display Shortcuts (3 Tests)
21. **Key 'f' (Fullscreen Toggle)**: Pressing `f` triggers `onToggleFullscreen` callback.
22. **Key 'F11' (Fullscreen Toggle)**: Pressing `F11` triggers `onToggleFullscreen` callback.
23. **Key 'a' (Aspect Ratio Cycling)**: Pressing `a` triggers `onCycleAspectRatio` callback.

#### Group 5: Track Selection Shortcuts (2 Tests)
24. **Key 'b' (Cycle Audio Track)**: Pressing `b` triggers `onCycleAudioTrack` callback.
25. **Key 'v' (Cycle Subtitle Track)**: Pressing `v` triggers `onCycleSubtitleTrack` callback.

#### Group 6: Delay Synchronization Nudges (4 Tests)
26. **Key 'h' (Subtitle Delay +50ms)**: Pressing `h` invokes `onNudgeSubtitleDelay(50)`.
27. **Key 'g' (Subtitle Delay -50ms)**: Pressing `g` invokes `onNudgeSubtitleDelay(-50)`.
28. **Key 'k' (Audio Delay +50ms)**: Pressing `k` invokes `onNudgeAudioDelay(50)`.
29. **Key 'j' (Audio Delay -50ms)**: Pressing `j` invokes `onNudgeAudioDelay(-50)`.

#### Group 7: Playback Speed Control (6 Tests)
30. **Coarse Speed Up ('+')**: Pressing `LogicalKeyboardKey.add` or `equal` with Shift increases rate by `+0.25x` / `+0.5x` clamped to `4.0x`.
31. **Coarse Speed Down ('-')**: Pressing `LogicalKeyboardKey.minus` decreases rate by `-0.25x` / `-0.5x` clamped to `0.25x`.
32. **Fine Speed Up (']')**: Pressing `LogicalKeyboardKey.bracketRight` increases rate by `+0.1x`.
33. **Fine Speed Down ('[')**: Pressing `LogicalKeyboardKey.bracketLeft` decreases rate by `-0.1x`.
34. **Speed Reset ('=')**: Pressing `LogicalKeyboardKey.equal` resets rate to exact `1.0x` and emits 'Speed: 1.0x (Normal)'.
35. **Speed Boundary Clamping**: Repeatedly pressing `]` at `4.0x` clamps at `4.0x`; repeatedly pressing `[` at `0.25x` clamps at `0.25x`.

#### Group 8: Volume & Mute Shortcuts (5 Tests)
36. **ArrowUp (Volume Up 5%)**: Pressing `ArrowUp` increments volume by `+5.0` (e.g. 50% -> 55%).
37. **ArrowDown (Volume Down 5%)**: Pressing `ArrowDown` decrements volume by `-5.0` (e.g. 50% -> 45%).
38. **Volume Upper Clamp**: Volume at 100% (or 150%) does not exceed boundary on `ArrowUp`.
39. **Volume Lower Clamp**: Volume at 0% does not drop below 0 on `ArrowDown`, and emits 'Mute' OSD.
40. **Key 'm' (Mute / Unmute Toggle)**: Pressing `m` when volume is 75% sets volume to 0.0; pressing `m` again restores 75%.

#### Group 9: Event Filtering & Focus Mechanics (4 Tests)
41. **KeyUpEvent Ignored**: Sending `KeyUpEvent` for `Space` or `ArrowRight` does not re-trigger actions.
42. **Unmapped Keys**: Pressing keys like `Tab`, `Escape`, `KeyQ`, `KeyZ` returns `KeyEventResult.ignored`.
43. **User Activity on All Shortcuts**: Every handled shortcut invokes `onUserActivity` to ensure HUD auto-hide timers are reset.
44. **Embedded Text Input Protection**: When a child `TextField` within the subtree is focused, typing letters does not trigger player shortcuts.

---

## 4. Caveats

1. **Autofocus Latency in Widget Tests**:
   - `Focus` widgets with `autofocus: true` do not acquire focus immediately synchronously. Widget tests must call `await tester.pumpAndSettle()` after calling `tester.pumpWidget(...)`. If tests send key events before focus settles, the events are dropped.
2. **Key Repeat Events**:
   - On desktop OSes, holding a key down fires `KeyRepeatEvent`. If `_handleKeyEvent` checks `if (event is! KeyDownEvent) return KeyEventResult.ignored;`, key repeat events will be ignored. For volume adjustments (`ArrowUp`/`ArrowDown`) or fast seeking, whether repeat events should be handled or ignored should be documented. The recommendation is to allow `KeyDownEvent` and optionally `KeyRepeatEvent` for volume and seek.
3. **No Caveats Beyond Above**: All other aspects of the test architecture, event dispatching, and boundary verification are fully verified.

---

## 5. Conclusion

1. **Native C-FFI Clean-Room Solution**:
   Use `Player(platformPlayer: FakePlatformPlayer())` or provide action callbacks (`onSeek`, `onPlayPause`, etc.) on `DesktopKeyboardHandler`. This completely bypasses `NativePlayer`, prevents missing `mpv.dll` errors, and allows pure, sub-second widget test execution in headless environments.
2. **`DesktopKeyboardHandler` Testability Structure**:
   `DesktopKeyboardHandler` should accept optional action callbacks (`onSeek`, `onPlayPause`, `onVolumeChanged`, `onRateChanged`) while retaining `final Player player` to satisfy the milestone contract. `PlayerScreen` supplies these callbacks to wire `_aiEngine.invalidateQueue()`, and unit tests use them to assert state transitions.
3. **Hardware Keyboard Simulation Protocol**:
   Use `tester.sendKeyDownEvent(modifier)` followed by `tester.sendKeyEvent(primaryKey)` and `tester.sendKeyUpEvent(modifier)`. Normalizing both `Ctrl` and `Meta` guarantees full cross-platform parity on Windows, Linux, and macOS.
4. **Authoritative Test Suite**:
   The catalog of 44 tests across 9 test groups provides 100% comprehensive coverage of all 13 shortcuts, the 4-tier seek physics hierarchy, modifier precedence cascades, and boundary clamping edge cases.

---

## 6. Verification Method

### 6.1 Verification Commands
Once the implementation is delivered by the worker agent:

1. **Run Desktop Keyboard Handler Unit Test Suite**:
   ```powershell
   cd d:\E-player\app
   flutter test test\unit\desktop_keyboard_handler_test.dart
   ```
   *Expected outcome*: All test groups pass (40+ assertions) with 0 failures and zero missing DLL errors.

2. **Run Full Test Suite Baseline**:
   ```powershell
   cd d:\E-player\app
   flutter test test\unit\
   ```
   *Expected outcome*: All unit test suites pass cleanly.

3. **Verify Static Analysis Cleanliness**:
   ```powershell
   cd d:\E-player\app
   dart analyze
   ```
   *Expected outcome*: `No issues found!` (0 errors, 0 warnings, 0 lints).

### 6.2 Invalidation Conditions
- Any test failure caused by `DynamicLibrary.open` or missing `mpv.dll`.
- Seeking backward underflowing past `Duration.zero`.
- Seeking forward past video `duration` causing demuxer stall rather than clamping at `duration`.
- `Ctrl + Alt + ArrowRight` resolving to Tier 3 (60s) or Tier 2 (10s) instead of Tier 4 (300s).
- macOS Command key (`Meta`) failing to trigger 60s/300s seek.
