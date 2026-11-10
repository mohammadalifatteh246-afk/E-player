# Dispatch: Worker 1 (Milestone 1 Implementation)

## Objective
Implement `DesktopKeyboardHandler` in `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`, integrate with `PlayerScreen` (`lib/features/player/ui/player_screen.dart`), and author unit tests in `test/unit/desktop_keyboard_handler_test.dart`.

## Exclusive Write Ownership
You own and may modify ONLY these 3 files:
1. `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` (new component)
2. `lib/features/player/ui/player_screen.dart` (integration, focus, OSD pill, callbacks)
3. `test/unit/desktop_keyboard_handler_test.dart` (new unit/widget test suite)

DO NOT modify `lib/features/player/ui/audio_studio_sheet.dart` under any circumstances!

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Authoritative Inputs to Read
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- `d:\E-player\PROJECT.md`
- `d:\E-player\.agents\teamwork\sub_orch_m1\SCOPE.md`
- Explorer 1 Report: `d:\E-player\.agents\teamwork\explorer_m1_1\handoff.md`
- Explorer 2 Report: `d:\E-player\.agents\teamwork\explorer_m1_2\handoff.md`
- Explorer 3 Report: `d:\E-player\.agents\teamwork\explorer_m1_3\handoff.md`

## Detailed Implementation Requirements

### 1. `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
- Implement `DesktopKeyboardHandler extends StatefulWidget`.
- Accepts:
  - `final Player player;`
  - `final Widget child;`
  - `final VoidCallback onToggleFullscreen;`
  - `final VoidCallback onCycleAspectRatio;`
  - `final VoidCallback onCycleAudioTrack;`
  - `final VoidCallback onCycleSubtitleTrack;`
  - `final Function(int offsetMs) onNudgeAudioDelay;`
  - `final Function(int offsetMs) onNudgeSubtitleDelay;`
  - `final Function(String message, IconData icon) onShowOsd;`
  - `final VoidCallback onUserActivity;`
  - `final VoidCallback? onBeforeSeek;` (or `void Function(Duration target)? onSeek`)
  - `final FocusNode? focusNode;`
- Handles `KeyDownEvent` from `Focus(onKeyEvent: ...)`. Ignores non-KeyDown events.
- Normalizes modifiers:
  ```dart
  final isShift = HardwareKeyboard.instance.isShiftPressed;
  final isAlt = HardwareKeyboard.instance.isAltPressed;
  final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
  ```
- Implements 13 universal shortcuts:
  - `Space`: play/pause toggle + OSD
  - `f` / `F11`: fullscreen toggle
  - `m`: mute toggle + OSD (restores cached `_lastVolume` or 100%)
  - `b`: cycle audio track + OSD
  - `v`: cycle subtitle track + OSD
  - `a`: cycle aspect ratio + OSD
  - `h` / `g`: subtitle delay nudge (±50ms) + OSD
  - `k` / `j`: audio delay nudge (±50ms) + OSD
  - `+` / `-` / `Shift + =`: coarse speed adjustment (±0.25x, clamped 0.25 - 4.0) + OSD
  - `]` / `[`: fine speed adjustment (±0.1x, clamped 0.25 - 4.0) + OSD
  - `=`: reset speed to 1.0x + OSD
  - `Arrow Up` / `Arrow Down`: volume adjustment (5% steps, clamped 0 - 150) + OSD
  - `Arrow Left` / `Arrow Right`: 4-tier seek physics:
    - Ctrl + Alt: 300s
    - Ctrl: 60s
    - Alt: 10s
    - Shift: 3s
    - None: 10s
    - Clamped: `target < Duration.zero ? Duration.zero : (duration > Duration.zero && target > duration ? duration : target)`
    - Calls `onBeforeSeek?.call()` to invalidate AI queue, then seeks player.
    - Emits OSD pill feedback.

### 2. `lib/features/player/ui/player_screen.dart`
- Wrap body in `DesktopKeyboardHandler`.
- Provide `_focusNode`, request focus on mount in post-frame callback.
- Re-activate OSD feedback: Render glassmorphic pill overlay at `top: 90` with icon and text in root `Stack` when `_showFeedback` is true.
- Add audio track selector icon (`Icons.audiotrack_outlined`) in HUD top bar between AI Studio and Subtitles.
- Implement `_showAudioTrackMenu()` modal bottom sheet and `_cycleAudioTrack()`.
- Listen to `_player.stream.tracks` (`tracks.audio`) and `_player.stream.track` (`track.audio`).
- Attach `.then((_) { if (mounted) _focusNode.requestFocus(); })` to all bottom sheets and dialogs so focus is restored upon closing.

### 3. `test/unit/desktop_keyboard_handler_test.dart`
- Pure headless test suite using `FakePlayer` implementing `Player` (avoiding missing `mpv.dll` C-FFI errors).
- Thoroughly test:
  - Play/pause toggle (`Space`)
  - Fullscreen toggle (`f`, `F11`)
  - Mute toggle (`m`)
  - Volume up/down (`arrowUp`, `arrowDown`)
  - Speed adjustments (`+`, `-`, `]`, `[`, `=`)
  - Track cycling callbacks (`b`, `v`, `a`)
  - Delay nudges (`k`/`j`, `h`/`g`)
  - 4-tier seek jumps (Shift 3s, Alt 10s, Ctrl 60s, Ctrl+Alt 300s, Default 10s)
  - Modifier precedence (Ctrl+Alt beats Ctrl, Ctrl beats Shift)
  - Clamping at 0 and at duration
  - Callback invocations (`onBeforeSeek`, `onShowOsd`, `onUserActivity`)

## Verification Commands to Execute
Run and document results:
1. `dart analyze` in `d:\E-player\app` (MUST pass with 0 errors and 0 warnings)
2. `flutter test test/unit/desktop_keyboard_handler_test.dart` (MUST pass 100%)
3. `flutter test test/unit/decoder_pipeline_test.dart` (MUST pass 100% regression check)

## Completion Deliverable
Write your completion report to `d:\E-player\.agents\teamwork\worker_m1_1\handoff.md` with:
- Observation (files modified, commands executed, exact test outputs)
- Logic Chain
- Verification Method and Results
- Confirmation that `audio_studio_sheet.dart` was not modified
When finished, send a message to the orchestrator.


## 2026-11-10T08:54:43Z
You are Worker 1 for Milestone 1: Desktop Keyboard Shortcuts & 4-Tier Seek Physics.
Working directory: d:\E-player\app
Your state folder: d:\E-player\.agents\teamwork\worker_m1_1\
Read your task description in: d:\E-player\.agents\teamwork\worker_m1_1\DISPATCH.md
Read the authoritative documents:
- d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
- d:\E-player\PROJECT.md
- d:\E-player\.agents\teamwork\sub_orch_m1\SCOPE.md
- Explorer 1 Report: d:\E-player\.agents\teamwork\explorer_m1_1\handoff.md
- Explorer 2 Report: d:\E-player\.agents\teamwork\explorer_m1_2\handoff.md
- Explorer 3 Report: d:\E-player\.agents\teamwork\explorer_m1_3\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Exclusive file ownership:
- lib/features/player/ui/widgets/desktop_keyboard_handler.dart (new component)
- lib/features/player/ui/player_screen.dart (integration, focus, OSD pill, callbacks)
- test/unit/desktop_keyboard_handler_test.dart (new unit/widget test suite)

DO NOT modify lib/features/player/ui/audio_studio_sheet.dart under any circumstances.

Implement DesktopKeyboardHandler, integrate with PlayerScreen, and author unit tests in test/unit/desktop_keyboard_handler_test.dart.
Run `dart analyze` (must pass with 0 errors and 0 warnings) and `flutter test` (must pass 100%).
Write your completion handoff report to d:\E-player\.agents\teamwork\worker_m1_1\handoff.md.
When finished, send a message to the orchestrator with your results.
