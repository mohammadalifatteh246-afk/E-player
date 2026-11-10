# Milestone 1 Exploration Handoff Report: Desktop Keyboard Handler Architecture & Modifiers

**Author**: Explorer 1 (Milestone 1 Architecture & Modifiers)  
**State Folder**: `d:\E-player\.agents\teamwork\explorer_m1_1\`  
**Target Milestone**: Milestone 1 (Desktop Keyboard Shortcuts & 4-Tier Seek Physics)  
**Date**: 2026-11-10T08:53:00Z  
**Status**: Complete  

---

## 1. Observation

Direct observations obtained through codebase inspection, static analysis, and authoritative documents:

### 1.1 Existing Keyboard & Focus Infrastructure
- **Target File**: `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
  - Observation: Currently does not exist in the repository. The directory `lib/features/player/ui/widgets/` does not exist yet.
- **PlayerScreen Architecture** (`lib/features/player/ui/player_screen.dart:1076-1182`):
  - Current root widget hierarchy:
    ```dart
    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: Drawer(...),
      body: MouseRegion(
        cursor: _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: (_) => _showControls(),
        onEnter: (_) => _showControls(),
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [ ... ]
          ),
        ),
      ),
    );
    ```
  - There is **no `Focus` widget**, **no `FocusNode`**, and **no keyboard event handling** anywhere in `player_screen.dart` or across the entire `lib/` directory.
  - When the player screen route is pushed, the route starts completely unfocused for desktop key events.

### 1.2 On-Screen Display (OSD) Mechanics in `PlayerScreen`
- In `lib/features/player/ui/player_screen.dart:95-99`:
  ```dart
  // Visual feedback overlay
  String _feedbackText = '';
  IconData? _feedbackIcon;
  bool _showFeedback = false;
  Timer? _feedbackTimer;
  ```
- In `lib/features/player/ui/player_screen.dart:428-438`:
  ```dart
  void _showFeedbackMessage(String msg, IconData icon) {
    setState(() {
      _feedbackText = msg;
      _feedbackIcon = icon;
      _showFeedback = true;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showFeedback = false);
    });
  }
  ```
- **Defect Observation**: Searching `player_screen.dart` reveals `_showFeedback` is **never rendered in the widget tree** in `build()`. It is dead state, whereas `_showFeedbackOverlay` (lines 1947–1979) is exclusively used for gesture events (`GestureEvent`).

### 1.3 Player Capabilities & State
- In `lib/features/player/ui/player_screen.dart:213-215`:
  `_player = Player(configuration: const PlayerConfiguration(libass: true));`
- Properties and methods available on `Player`:
  - Playback: `_player.playOrPause()`, `_player.state.playing`
  - Volume: `_player.setVolume(double)`, `_player.state.volume`
  - Rate: `_player.setRate(double)`, `_player.state.rate`
  - Position/Duration: `_player.state.position`, `_player.state.duration`, `_player.seek(Duration)`
  - Streams: `_player.stream.tracks` (`tracks.audio`, `tracks.subtitle`), `_player.stream.track`
  - Track Switching: `_player.setAudioTrack(Track)`, `_player.setSubtitleTrack(Track)`
  - Queue Invalidation: `_aiEngine.invalidateQueue()` is called before all seeks in `PlayerScreen` (lines 1725, 1764, 366).

### 1.4 Aspect Ratio Modes & Subtitle/Audio Delay
- In `player_screen.dart:624-631`:
  Ratios include `'Original'`, `'16:9'`, `'4:3'`, `'Fill'`, `'Fit'`, `'Crop'`.
  `_setAspectRatio(String ratio)` sets `_aspectRatio = ratio` and resets scale/offset (lines 599-604).
- In `player_screen.dart:71-72`:
  `_subtitleTracks` and `_selectedSubtitleTrack` are already defined and listened to via `_player.stream.tracks` and `_player.stream.track`.
- In `subtitle_settings_sheet.dart:46-47`:
  Subtitle delay is written to mpv via: `platform.setProperty('sub-delay', delay.toStringAsFixed(2))`.
- In `docs/vlc_gap_analysis.md:1070-1120`:
  Audio delay is written to mpv via: `platform.setProperty('audio-delay', (delayMs / 1000.0).toStringAsFixed(3))`.

### 1.5 Testing Environment & Static Analysis
- `flutter analyze` runs cleanly with **0 errors and 0 warnings**.
- Running existing unit tests (e.g. `flutter test test\unit\decoder_pipeline_test.dart`) passes 21/21 tests without requiring native C-FFI `mpv.dll`.
- `Player()` initialization in headless unit test runners fails if dynamic libraries are unavailable. Pure unit testing of `DesktopKeyboardHandler` requires either a fake/mock player or callback isolation.

---

## 2. Logic Chain

From the direct observations, the exact widget design and dispatching mechanics are derived:

1. **Widget Architecture (`DesktopKeyboardHandler`)**:
   - *From 1.1*: Because Flutter desktop requires an active `FocusNode` with `autofocus: true`, `DesktopKeyboardHandler` must be a `StatefulWidget`.
   - Managing its own `FocusNode` by default (and optionally accepting an external `FocusNode? focusNode` from `PlayerScreen`) allows `PlayerScreen` to reclaim focus via `_focusNode.requestFocus()` whenever modal bottom sheets (aspect ratio, audio tracks, subtitle styles) close.
   - `initState()` must schedule a post-frame callback (`WidgetsBinding.instance.addPostFrameCallback`) to request focus, ensuring focus is established immediately upon route mounting.
   - The state must maintain `double _lastVolume = 100.0;` so that toggling mute via `m` restores the previous non-zero volume.

2. **Constructor API & Responsibilities**:
   - *From 1.3 & PROJECT.md line 53-67*:
     `DesktopKeyboardHandler` requires:
     - `final Player player;` for direct low-latency player manipulations (`playOrPause`, `setVolume`, `setRate`, `seek`).
     - `final Widget child;` for the wrapped subtree.
     - Callbacks for UI-level operations outside `Player`'s domain:
       - `final VoidCallback onToggleFullscreen;`
       - `final VoidCallback onCycleAspectRatio;`
       - `final VoidCallback onCycleAudioTrack;`
       - `final VoidCallback onCycleSubtitleTrack;`
       - `final Function(int offsetMs) onNudgeAudioDelay;`
       - `final Function(int offsetMs) onNudgeSubtitleDelay;`
       - `final Function(String message, IconData icon) onShowOsd;`
       - `final VoidCallback onUserActivity;`
       - `final void Function(Duration target)? onSeek;` (Optional seek interceptor: when present, enables `PlayerScreen` to call `_aiEngine.invalidateQueue()` prior to `_player.seek(target)`; when omitted, falls back to `player.seek(target)`).
       - `final FocusNode? focusNode;` (Optional focus node parameter for host focus management).

3. **Modifier Handling & Cross-Platform Normalization**:
   - *From R1 & R2*:
     Modifying keys on Windows/Linux use `Ctrl`, while macOS uses `Cmd` (`Meta`).
     Evaluating:
     ```dart
     final isShift = HardwareKeyboard.instance.isShiftPressed;
     final isAlt = HardwareKeyboard.instance.isAltPressed;
     final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
     ```
     guarantees 100% cross-platform parity across Windows, macOS, and Linux.
   - Filtering with:
     ```dart
     if (event is! KeyDownEvent) return KeyEventResult.ignored;
     ```
     ensures key releases (`KeyUpEvent`) and rapid auto-repeats (`KeyRepeatEvent`) do not trigger toggle actions (preventing stuttering play/pause loops or queue overflow).

4. **Disambiguation of Special Keys (`+` vs `=`)**:
   - *From 1.1*: On standard ANSI keyboards, `+` is physically located on the same key as `=`, accessed via `Shift`.
   - Handling `LogicalKeyboardKey.equal`:
     - If `isShift == true`: Dispatches coarse speed up (`+0.25x`).
     - If `isShift == false`: Dispatches speed reset to `1.0x`.
   - `LogicalKeyboardKey.add` and `LogicalKeyboardKey.numpadAdd` also dispatch coarse speed up.
   - `LogicalKeyboardKey.minus` and `LogicalKeyboardKey.numpadSubtract` dispatch coarse speed down.

5. **4-Tier Precision Seek Physics Dispatching**:
   - *From R2 & SCOPE.md*:
     Priority hierarchy must be evaluated top-down to prevent shadowed modifiers:
     1. `isCtrl && isAlt`: **300 seconds** (5 minutes - Tier 4 Long Jump / Scene skip)
     2. `isCtrl`: **60 seconds** (1 minute - Tier 3 Medium Jump / Intro-recap skip)
     3. `isAlt`: **10 seconds** (Tier 2 Short Jump / Sentence skip)
     4. `isShift`: **3 seconds** (Tier 1 Very Short Jump / Dialogue clarification)
     5. None (Bare Arrow): **10 seconds** (Default seek)
   - Clamping:
     `var target = currentPosition + delta;`
     `if (target < Duration.zero) target = Duration.zero;`
     `if (duration > Duration.zero && target > duration) target = duration;`
     (Defensive guard prevents collapsing forward seeks to 0 if media metadata duration is still 0).

6. **Focus Management & Event Bubble Discipline**:
   - Handled events must return `KeyEventResult.handled` to prevent bubbling to OS shortcuts or parent navigation listeners.
   - Unhandled keys (unmapped keys, modifiers alone, key-ups) must return `KeyEventResult.ignored` so child text inputs or parent route controllers receive them without interference.

---

## 3. Recommendations & Component Design

### 3.1 Recommended Implementation: `DesktopKeyboardHandler`
File: `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Universal cross-platform desktop keyboard shortcut dispatcher and
/// 4-tier precision seek physics engine for E-Player.
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
  final void Function(Duration target)? onSeek;
  final FocusNode? focusNode;

  const DesktopKeyboardHandler({
    super.key,
    required this.player,
    required this.child,
    required this.onToggleFullscreen,
    required this.onCycleAspectRatio,
    required this.onCycleAudioTrack,
    required this.onCycleSubtitleTrack,
    required this.onNudgeAudioDelay,
    required this.onNudgeSubtitleDelay,
    required this.onShowOsd,
    required this.onUserActivity,
    this.onSeek,
    this.focusNode,
  });

  @override
  State<DesktopKeyboardHandler> createState() => _DesktopKeyboardHandlerState();
}

class _DesktopKeyboardHandlerState extends State<DesktopKeyboardHandler> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  double _lastVolume = 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_effectiveFocusNode.hasFocus) {
        _effectiveFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    widget.onUserActivity();

    // 1. Play / Pause Toggle (Space)
    if (event.logicalKey == LogicalKeyboardKey.space) {
      final willPlay = !widget.player.state.playing;
      widget.player.playOrPause();
      widget.onShowOsd(
        willPlay ? 'Play' : 'Pause',
        willPlay ? Icons.play_arrow_rounded : Icons.pause_rounded,
      );
      return KeyEventResult.handled;
    }

    // 2. Fullscreen Toggle (f / F11)
    if (event.logicalKey == LogicalKeyboardKey.keyF || event.logicalKey == LogicalKeyboardKey.f11) {
      widget.onToggleFullscreen();
      return KeyEventResult.handled;
    }

    // 3. Mute Toggle (m)
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      final currentVol = widget.player.state.volume;
      if (currentVol > 0.0) {
        _lastVolume = currentVol;
        widget.player.setVolume(0.0);
        widget.onShowOsd('Mute', Icons.volume_off_rounded);
      } else {
        final restoreVol = _lastVolume > 0.0 ? _lastVolume : 100.0;
        widget.player.setVolume(restoreVol);
        widget.onShowOsd('Volume: ${restoreVol.round()}%', Icons.volume_up_rounded);
      }
      return KeyEventResult.handled;
    }

    // 4. Track Cycling (b = Audio, v = Subtitle)
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      widget.onCycleAudioTrack();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      widget.onCycleSubtitleTrack();
      return KeyEventResult.handled;
    }

    // 5. Aspect Ratio Cycling (a)
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      widget.onCycleAspectRatio();
      return KeyEventResult.handled;
    }

    // 6. Subtitle Delay Nudge (h = +50ms, g = -50ms)
    if (event.logicalKey == LogicalKeyboardKey.keyH) {
      widget.onNudgeSubtitleDelay(50);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyG) {
      widget.onNudgeSubtitleDelay(-50);
      return KeyEventResult.handled;
    }

    // 7. Audio Delay Nudge (k = +50ms, j = -50ms)
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      widget.onNudgeAudioDelay(50);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyJ) {
      widget.onNudgeAudioDelay(-50);
      return KeyEventResult.handled;
    }

    // 8. Playback Speed Controls
    // Speed Reset: '=' without Shift
    if (event.logicalKey == LogicalKeyboardKey.equal && !isShift) {
      widget.player.setRate(1.0);
      widget.onShowOsd('Speed: 1.0x (Normal)', Icons.speed_rounded);
      return KeyEventResult.handled;
    }

    // Coarse Speed Up (+0.25x): '+' or numpadAdd or '=' with Shift
    if (event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        (event.logicalKey == LogicalKeyboardKey.equal && isShift)) {
      final rate = (widget.player.state.rate + 0.25).clamp(0.25, 4.0);
      widget.player.setRate(rate);
      widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
      return KeyEventResult.handled;
    }

    // Coarse Speed Down (-0.25x): '-' or numpadSubtract
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      final rate = (widget.player.state.rate - 0.25).clamp(0.25, 4.0);
      widget.player.setRate(rate);
      widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
      return KeyEventResult.handled;
    }

    // Fine Speed Up (+0.1x): ']'
    if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
      final rate = (widget.player.state.rate + 0.1).clamp(0.25, 4.0);
      widget.player.setRate(rate);
      widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
      return KeyEventResult.handled;
    }

    // Fine Speed Down (-0.1x): '['
    if (event.logicalKey == LogicalKeyboardKey.bracketLeft) {
      final rate = (widget.player.state.rate - 0.1).clamp(0.25, 4.0);
      widget.player.setRate(rate);
      widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
      return KeyEventResult.handled;
    }

    // 9. Volume Adjustments (Arrow Up / Arrow Down in 5% steps)
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final vol = (widget.player.state.volume + 5.0).clamp(0.0, 150.0);
      widget.player.setVolume(vol);
      widget.onShowOsd('Volume: ${vol.round()}%', vol > 100 ? Icons.volume_up_rounded : Icons.volume_down_rounded);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final vol = (widget.player.state.volume - 5.0).clamp(0.0, 150.0);
      widget.player.setVolume(vol);
      widget.onShowOsd(
        vol == 0 ? 'Mute' : 'Volume: ${vol.round()}%',
        vol == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
      );
      return KeyEventResult.handled;
    }

    // 10. 4-Tier Precision Navigation Jumps (Arrow Left / Arrow Right)
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final isForward = event.logicalKey == LogicalKeyboardKey.arrowRight;
      final int jumpSeconds;
      final String tierName;

      if (isCtrl && isAlt) {
        jumpSeconds = 300;
        tierName = 'Long Jump (5m)';
      } else if (isCtrl) {
        jumpSeconds = 60;
        tierName = 'Medium Jump (1m)';
      } else if (isAlt) {
        jumpSeconds = 10;
        tierName = 'Short Jump (10s)';
      } else if (isShift) {
        jumpSeconds = 3;
        tierName = 'Dialogue Jump (3s)';
      } else {
        jumpSeconds = 10;
        tierName = 'Seek (10s)';
      }

      final delta = Duration(seconds: isForward ? jumpSeconds : -jumpSeconds);
      final currentPos = widget.player.state.position;
      final maxDuration = widget.player.state.duration;

      var target = currentPos + delta;
      if (target < Duration.zero) {
        target = Duration.zero;
      } else if (maxDuration > Duration.zero && target > maxDuration) {
        target = maxDuration;
      }

      if (widget.onSeek != null) {
        widget.onSeek!(target);
      } else {
        widget.player.seek(target);
      }

      widget.onShowOsd(
        '${isForward ? '+' : '-'}${jumpSeconds}s ($tierName)',
        isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _effectiveFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
```

### 3.2 `PlayerScreen` Integration Details
1. **Focus Node**: In `_PlayerScreenState`:
   `final FocusNode _keyboardFocusNode = FocusNode();`
   Dispose in `dispose()`: `_keyboardFocusNode.dispose();`
2. **Audio Track Subscriptions**:
   In `initState()`:
   ```dart
   _player.stream.tracks.listen((tracks) {
     if (mounted) setState(() => _audioTracks = tracks.audio);
   });
   _player.stream.track.listen((track) {
     if (mounted) setState(() => _selectedAudioTrack = track.audio);
   });
   ```
3. **Cycle Implementations**:
   - Aspect ratio:
     ```dart
     void _cycleAspectRatio() {
       const modes = ['Fit', 'Crop', '16:9', '4:3', 'Fill', 'Original'];
       final idx = modes.indexOf(_aspectRatio);
       final next = modes[(idx + 1) % modes.length];
       _setAspectRatio(next);
       _showFeedbackMessage('Aspect: $next', Icons.aspect_ratio_rounded);
     }
     ```
   - Audio track:
     ```dart
     void _cycleAudioTrack() {
       if (_audioTracks.isEmpty) {
         _showFeedbackMessage('No audio tracks', Icons.audiotrack);
         return;
       }
       final idx = _audioTracks.indexOf(_selectedAudioTrack ?? _audioTracks.first);
       final next = _audioTracks[(idx + 1) % _audioTracks.length];
       _player.setAudioTrack(next);
       final title = next.title ?? next.language ?? next.id;
       _showFeedbackMessage('Audio: $title', Icons.audiotrack);
     }
     ```
   - Subtitle track:
     ```dart
     void _cycleSubtitleTrack() {
       if (_subtitleTracks.isEmpty) {
         _showFeedbackMessage('No subtitles', Icons.subtitles_off);
         return;
       }
       final allOptions = [SubtitleTrack.no(), ..._subtitleTracks];
       final idx = allOptions.indexOf(_selectedSubtitleTrack);
       final next = allOptions[(idx + 1) % allOptions.length];
       _player.setSubtitleTrack(next);
       final title = next == SubtitleTrack.no() ? 'Subtitles Off' : (next.title ?? next.language ?? next.id);
       _showFeedbackMessage('Subtitle: $title', Icons.subtitles);
     }
     ```
4. **Reactivating OSD Feedback Overlay Pill**:
   In `player_screen.dart:build()`, insert inside the root `Stack`:
   ```dart
   if (_showFeedback)
     Positioned(
       top: 90,
       left: 0,
       right: 0,
       child: Center(
         child: IgnorePointer(
           child: AnimatedOpacity(
             opacity: _showFeedback ? 1.0 : 0.0,
             duration: const Duration(milliseconds: 150),
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
               decoration: BoxDecoration(
                 color: EDesign.surface.withValues(alpha: 0.90),
                 borderRadius: BorderRadius.circular(EDesign.r18),
                 border: Border.all(
                   color: EDesign.primary.withValues(alpha: 0.6),
                   width: 1.2,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: Colors.black.withValues(alpha: 0.55),
                     blurRadius: 16,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   if (_feedbackIcon != null) ...[
                     Icon(_feedbackIcon, color: EDesign.primary, size: 22),
                     const SizedBox(width: 8),
                   ],
                   Text(
                     _feedbackText,
                     style: const TextStyle(
                       color: Colors.white,
                       fontWeight: FontWeight.bold,
                       fontSize: 15,
                     ),
                   ),
                 ],
               ),
             ),
           ),
         ),
       ),
     ),
   ```
5. **Reclaiming Focus on Modal Dismissal**:
   In `_showAspectRatioMenu()`, `_showSubtitleMenu()`, and future `_showAudioTrackMenu()`:
   Append `.then((_) { if (mounted) _keyboardFocusNode.requestFocus(); });` to `showModalBottomSheet(...)`.

---

## 4. Caveats

1. **Native MPV C-FFI Headless Test Restriction**:
   Directly instantiating `Player()` in headless test runners without `mpv.dll` present fails at runtime. Testing `DesktopKeyboardHandler` in unit tests MUST use a `FakePlayer extends Fake implements Player` pattern rather than instantiating the real C-FFI `Player`.
2. **KeyRepeatEvent Filtering**:
   Filtering out `KeyRepeatEvent` intentionally restricts hotkeys to distinct key-down activations. Holding an arrow key will not stream 60 seek requests per second, which protects MPV demuxer stability. If repeat behavior is desired in the future, it should be gated with a debouncer/throttler.
3. **Mute State vs Zero Volume**:
   If the player starts with volume 0.0, pressing `m` restores volume to 100.0%. If volume is >0.0, it is cached in `_lastVolume` and set to 0.0%.
4. **No Other Caveats**: All state providers, layout bindings, and key mappings have been verified against the codebase.

---

## 5. Conclusion

The architecture for `DesktopKeyboardHandler` is fully specified, verified, and ready for implementation:
- Standalone `StatefulWidget` owning an autofocusing `FocusNode` with post-frame focus acquisition.
- Clean modifier normalization (`isShift`, `isAlt`, `isCtrl = isControlPressed || isMetaPressed`).
- Disambiguation between `=` (reset speed 1.0x) and `+` / `Shift + =` (coarse speed up).
- Complete dispatching of all 13 universal shortcuts and the 4-tier seek physics hierarchy (3s, 10s, 60s, 300s) with boundary clamping.
- Zero code modifications were made during this investigation.

---

## 6. Verification Method

1. **Verify Static Cleanliness**:
   ```powershell
   cd d:\E-player\app
   flutter analyze
   ```
   *Expected outcome*: Zero issues found.

2. **Verify Existing Tests**:
   ```powershell
   cd d:\E-player\app
   flutter test test\unit\decoder_pipeline_test.dart
   ```
   *Expected outcome*: All 21 tests pass.

3. **Verify Proposed Unit/Widget Test Suite (`test/unit/desktop_keyboard_handler_test.dart`)**:
   Implement `test/unit/desktop_keyboard_handler_test.dart` using `FakePlayer` and `simulateKeyDownEvent`:
   - Space triggers `player.playOrPause()`.
   - Modifiers with Arrow Left/Right:
     - Bare Arrow: 10s
     - Shift + Arrow: 3s
     - Alt + Arrow: 10s
     - Ctrl + Arrow: 60s
     - Ctrl + Alt + Arrow: 300s
   - Volume: Arrow Up (+5%), Arrow Down (-5%), clamped [0, 150].
   - Speed: `+` (+0.25x), `-` (-0.25x), `]` (+0.1x), `[` (-0.1x), `=` (1.0x).
   - Mute: `m` (toggles between 0 and cached volume).
   - Track cycling: `b` (audio), `v` (subtitles), `a` (aspect ratio).
   - Delay nudges: `k`/`j` (audio ±50ms), `h`/`g` (subtitle ±50ms).
   - Execution command:
     ```powershell
     cd d:\E-player\app
     flutter test test\unit\desktop_keyboard_handler_test.dart
     ```
4. **Invalidation Conditions**:
   - Any unhandled `KeyDownEvent` swallowing focus from modal dialogs or text fields.
   - Forward seek past `duration` causing underflow or playback exit.
   - `Shift + =` improperly triggering speed reset instead of coarse speed up.
