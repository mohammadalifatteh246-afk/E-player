# Handoff Report: PlayerScreen Integration & OSD Architecture (Milestone 1, Explorer 2)

**Agent**: Explorer 2 (Milestone 1)  
**Target Milestone**: Milestone 1 — Desktop Keyboard Shortcuts & 4-Tier Seek Physics  
**Target Codebase**: `d:\E-player\app`  
**Target File Investigated**: `lib/features/player/ui/player_screen.dart` (2,136 lines)  
**Date**: 2026-11-10T08:53:00Z  
**Status**: Investigation Complete  

---

## 1. Observation

Direct forensic observations from inspecting `d:\E-player\app\lib\features\player\ui\player_screen.dart`, `audio_studio_sheet.dart`, and `subtitle_settings_sheet.dart`:

### 1.1 Existing Feedback State & Methods in `_PlayerScreenState`
- **State Variables** (`player_screen.dart:95-99`):
  ```dart
  // Visual feedback overlay
  String _feedbackText = '';
  IconData? _feedbackIcon;
  bool _showFeedback = false;
  Timer? _feedbackTimer;
  ```
- **Feedback Dispatcher Method** (`player_screen.dart:428-438`):
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
- **Lifecycle Cleanup**:
  - `dispose()` (`line 413`): `_feedbackTimer?.cancel();`
  - PiP transition (`line 152, 157`): `_showFeedback = false; _feedbackTimer?.cancel();`
- **10 Existing Call Sites of `_showFeedbackMessage`**:
  1. `line 320`: `_showFeedbackMessage("Paused", Icons.pause);`
  2. `line 323`: `_showFeedbackMessage("Play", Icons.play_arrow);`
  3. `line 614`: `_showFeedbackMessage('Speed: ${nextSpeed}x', Icons.speed);`
  4. `line 682`: `_showFeedbackMessage('Aspect: ${r['title']}', r['icon'] as IconData);`
  5. `line 920`: `_showFeedbackMessage('Orientation: ...', ...);`
  6. `line 930`: `_showFeedbackMessage('Orientation: ...', ...);`
  7. `line 988`: `_showFeedbackMessage('Orientation: ...', ...);`
  8. `line 1028`: `_showFeedbackMessage("Video: $degrees°", Icons.rotate_right);`
  9. `line 1689`: `_showFeedbackMessage('Controls Locked', Icons.lock);`
  10. `line 1817`: `_showFeedbackMessage('Unlocked', Icons.lock_open);`

### 1.2 The Existing Legacy Center Feedback Box vs Top: 90 OSD Overlay
- **Legacy Center Feedback Container** (`player_screen.dart:1563-1590`):
  ```dart
  // Visual Feedback Overlay
  if (_showFeedback)
    Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: EDesign.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EDesign.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_feedbackIcon != null)
              Icon(_feedbackIcon, color: EDesign.primary, size: 48),
            if (_feedbackIcon != null) const SizedBox(height: 8),
            Text(
              _feedbackText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  ```
  **Critical Defect Analysis of Existing Implementation**:
  - Rendered dead center with huge 48px icon and 22px text, blocking central video view.
  - Lacks `IgnorePointer`, so during the 800ms display it intercepts and swallows all user clicks and gesture taps.
  - Placed at lines 1564-1590, *before* Bottom Controls (1593), Floating Unlock Button (1808), Telemetry Overlay (1826), and Ripple Indicators (1857-1944). Bottom controls render *over* it.
- **Cinematic Gesture Feedback Overlay at `top: 90`** (`player_screen.dart:1947-1979`):
  ```dart
  if (_showFeedbackOverlay && _activeFeedbackEvent != null)
    Positioned(
      top: 90,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _showFeedbackOverlay ? 1.0 : 0.0,
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
              child: _buildGestureFeedbackContent(_activeFeedbackEvent!),
            ),
          ),
        ),
      ),
    ),
  ```
  This proves `top: 90` is already the established standard OSD position for player feedback pills in the app.

### 1.3 Widget Tree Root Structure in `PlayerScreen.build()`
- `player_screen.dart:1076-1185`:
  ```dart
  if (_pipService.isInPip) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: videoWidget),
    );
  }

  return Scaffold(
    backgroundColor: Colors.black,
    endDrawer: Drawer(...),
    body: MouseRegion(
      cursor: _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
      onHover: (_) => _showControls(),
      onEnter: (_) => _showControls(),
      child: GestureDetector(
        onTap: _toggleControls,
        onDoubleTapDown: _onDoubleTapDown,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [ ... ]
        ),
      ),
    ),
  );
  ```

### 1.4 Seek Queue Invalidation & Clamping Pattern
- Existing seeking call sites in `PlayerScreen`:
  - Scrubbing slider (`lines 1658-1659`):
    ```dart
    _aiEngine.invalidateQueue();
    _player.seek(Duration(milliseconds: v.toInt()));
    ```
  - Rewind 10s button (`lines 1724-1729`):
    ```dart
    final newPos = _position - const Duration(seconds: 10);
    _aiEngine.invalidateQueue();
    _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
    _showControls();
    ```
  - Forward 10s button (`lines 1763-1768`):
    ```dart
    final newPos = _position + const Duration(seconds: 10);
    _aiEngine.invalidateQueue();
    _player.seek(newPos > _duration ? _duration : newPos);
    _showControls();
    ```
  - Gesture Seek commit (`lines 365-368`):
    ```dart
    _seekCommitSubscription = _gestureEngine.seekCommitEvents.listen((event) {
      _aiEngine.invalidateQueue();
      _player.seek(event.target);
    });
    ```
- All seeks without exception call `_aiEngine.invalidateQueue()` immediately prior to `_player.seek(...)`.

### 1.5 Modals & Bottom Sheets in `PlayerScreen`
- Search across `player_screen.dart` revealed 10 modal bottom sheet invocations:
  - `line 557`: `_showDecoderMenu()`
  - `line 619`: `_showAspectRatioMenu()`
  - `line 732`: `_showSpeedMenu()`
  - `line 801`: `_showSubtitleMenu()`
  - `line 834`: `SubtitleSettingsSheet`
  - `line 950`: `_showOrientationMenu()`
  - `line 1003`: `_showVideoRotationMenu()`
  - `line 1040`: `_showVideoEffectsSheet()`
  - `line 1380`: `_showEnhancementStudio()`
  - `line 1780`: `AudioStudioSheet`
- Settings Drawer (`line 1423`): `Scaffold.of(ctx).openEndDrawer();`
- Technical Media Inspector (`line 1413`): `MediaInfoSheet.show(...)`
- None of these callers currently attach `.then((_) { ... })` to reclaim focus.

### 1.6 Verification of Strict Boundary: `audio_studio_sheet.dart`
- Examined `lib/features/player/ui/audio_studio_sheet.dart:1-60`:
  - `AudioConfig` contains: `enabled`, `preset`, `eq` (10 bands), `bassBoost`, `virtualizer`, `threeDAudio`, `nightMode`.
  - It does NOT have `audioDelay` or `preamp` yet (these belong to M2 and M3).
  - `PlayerScreen` imports `audio_studio_sheet.dart` (`line 22`) and instantiates `final AudioConfig _audioConfig = AudioConfig();` (`line 53`).
  - Strict requirement: `audio_studio_sheet.dart` is owned by M2/M3 and **MUST NOT be modified in Milestone 1**.

---

## 2. Logic Chain

From the direct observations, the step-by-step architectural deduction is synthesized:

### 2.1 Question 1: Where & How `DesktopKeyboardHandler` Wraps the Hierarchy
1. *From 1.3*: In `PlayerScreen.build()`, `Scaffold.body` directly hosts `MouseRegion -> GestureDetector -> Stack`.
2. Wrapping `Scaffold.body` with `DesktopKeyboardHandler` is the cleanest, most standard pattern:
   ```dart
   return Scaffold(
     backgroundColor: Colors.black,
     onEndDrawerChanged: (isOpen) {
       if (!isOpen && mounted) {
         _focusNode.requestFocus();
       }
     },
     endDrawer: Drawer(...),
     body: DesktopKeyboardHandler(
       player: _player,
       focusNode: _focusNode,
       onToggleFullscreen: _toggleFullscreen,
       onCycleAspectRatio: _cycleAspectRatio,
       onCycleAudioTrack: _cycleAudioTrack,
       onCycleSubtitleTrack: _cycleSubtitleTrack,
       onNudgeAudioDelay: _nudgeAudioDelay,
       onNudgeSubtitleDelay: _nudgeSubtitleDelay,
       onShowOsd: (msg, icon) => _showFeedbackMessage(msg, icon),
       onUserActivity: _showControls,
       onBeforeSeek: () {
         _aiEngine.invalidateQueue();
         _showControls();
       },
       child: MouseRegion( ... ),
     ),
   );
   ```
3. This guarantees:
   - `Focus` widget inside `DesktopKeyboardHandler` is active whenever the player view is mounted.
   - Mouse gestures, hovering, double tap, and scale updates inside `MouseRegion` and `GestureDetector` remain 100% operational as child widgets.
   - Keystrokes bubble directly to `DesktopKeyboardHandler` before being unhandled.

### 2.2 Question 2: Existing State Variables and Methods
1. *From 1.1*: `_feedbackText`, `_feedbackIcon`, `_showFeedback`, `_feedbackTimer`, and `_showFeedbackMessage(String msg, IconData icon)` already exist and are maintained cleanly.
2. In `PlayerScreen`, we must add:
   - `final FocusNode _focusNode = FocusNode();`
   - `List<AudioTrack> _audioTracks = [];`
   - `AudioTrack _selectedAudioTrack = AudioTrack.no();`
   - `double _audioDelayMs = 0.0;`
   - `bool _isFullscreen = false;`
3. In `initState()`:
   - Subscribe to audio tracks:
     ```dart
     _player.stream.tracks.listen((tracks) {
       if (mounted) setState(() {
         _subtitleTracks = tracks.subtitle;
         _audioTracks = tracks.audio;
       });
     });
     _player.stream.track.listen((track) {
       if (mounted) setState(() {
         _selectedSubtitleTrack = track.subtitle;
         _selectedAudioTrack = track.audio;
       });
     });
     ```
   - Request initial autofocus:
     ```dart
     WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted && !_focusNode.hasFocus) {
         _focusNode.requestFocus();
       }
     });
     ```
4. In `dispose()`:
   - `_focusNode.dispose();`

### 2.3 Question 3: OSD Feedback Pill Overlay at `top: 90`
1. *From 1.2*: The existing center box at lines 1564-1590 is legacy code that blocks touch events and renders in the wrong place with the wrong z-index.
2. Replacing lines 1564-1590 with a Positioned pill placed after line 1979 (at the top of the Stack) resolves all issues:
   ```dart
   // Glassmorphic OSD Feedback Pill Overlay (Shortcuts & Player Feedback)
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
3. Benefits:
   - Identical geometry and glassmorphic aesthetics to the `CinematicGestureFeedbackCard`.
   - Never overlaps subtitles (rendered at `bottom: 92%`).
   - Never overlaps bottom controls (rendered at `bottom: 24`).
   - `IgnorePointer` ensures uninterrupted playback interaction during pill visibility.
   - Activates all 10 existing `_showFeedbackMessage` call sites in `PlayerScreen` instantly.

### 2.4 Question 4: Complete Focus Recovery Strategy
1. *From 1.5*: Bottom sheets and dialogs in Flutter take focus onto their modal routes. When dismissed, focus drops to the root navigator unless reclaimed.
2. 4-Pillar Focus Recovery:
   - **Vector 1 (Route Entry)**: `WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && !_focusNode.hasFocus) _focusNode.requestFocus(); });`
   - **Vector 2 (Video Tap)**: In `GestureDetector.onTap`: `_toggleControls(); _focusNode.requestFocus();`
   - **Vector 3 (Modal Sheet Pop)**: Append `.then((_) { if (mounted) _focusNode.requestFocus(); })` to:
     - `_showAudioTrackMenu()`
     - `_showSubtitleMenu()`
     - `_showAspectRatioMenu()`
     - `_showSpeedMenu()`
     - `_showDecoderMenu()`
     - `_showOrientationMenu()`
     - `_showVideoRotationMenu()`
     - `_showVideoEffectsSheet()`
     - `_showEnhancementStudio()`
     - `AudioStudioSheet` opener
     - `MediaInfoSheet.show(...)`
   - **Vector 4 (Settings Drawer Close)**: In `Scaffold`:
     `onEndDrawerChanged: (isOpen) { if (!isOpen && mounted) _focusNode.requestFocus(); }`

### 2.5 Question 5: Seek Physics Integration with `_aiEngine.invalidateQueue()`
1. *From 1.4*: Every seek in `PlayerScreen` must call `_aiEngine.invalidateQueue()`.
2. Decoupling is essential: `DesktopKeyboardHandler` must NOT import or instantiate `NativeEngineOrchestrator` (`_aiEngine`), because headless unit tests (`test/unit/desktop_keyboard_handler_test.dart`) cannot load native ONNX/C-FFI libraries.
3. Solution: Add `final VoidCallback? onBeforeSeek;` to `DesktopKeyboardHandler`:
   ```dart
   final delta = Duration(seconds: isForward ? jumpSeconds : -jumpSeconds);
   final current = widget.player.state.position;
   final duration = widget.player.state.duration;
   var target = current + delta;
   if (target < Duration.zero) target = Duration.zero;
   if (duration > Duration.zero && target > duration) target = duration;

   widget.onBeforeSeek?.call();
   widget.player.seek(target);
   ```
4. In `PlayerScreen`:
   ```dart
   onBeforeSeek: () {
     _aiEngine.invalidateQueue();
     _showControls();
   },
   ```
5. Clamping logic:
   - Lower bound: `if (target < Duration.zero) target = Duration.zero;`
   - Upper bound guard: `if (duration > Duration.zero && target > duration) target = duration;`
   - If `duration == Duration.zero` (e.g. initial buffering), upper clamping is bypassed so forward seeks are not improperly truncated to 0.

### 2.6 Question 6: Strict Boundary on `audio_studio_sheet.dart`
1. *From 1.6*: `audio_studio_sheet.dart` is owned exclusively by M2/M3.
2. In Milestone 1, `_nudgeAudioDelay(int offsetMs)` in `_PlayerScreenState` maintains a local `double _audioDelayMs = 0.0;` and sets mpv property directly:
   ```dart
   void _nudgeAudioDelay(int offsetMs) {
     _audioDelayMs = (_audioDelayMs + offsetMs).clamp(-10000.0, 10000.0);
     try {
       final platform = _player.platform as dynamic;
       platform.setProperty('audio-delay', (_audioDelayMs / 1000.0).toStringAsFixed(3));
     } catch (e) {
       debugPrint('[PlayerScreen] Failed to set audio-delay: $e');
     }
     final sign = _audioDelayMs >= 0 ? '+' : '';
     _showFeedbackMessage('Audio Delay: $sign${_audioDelayMs.round()}ms', Icons.audiotrack);
   }
   ```
3. `audio_studio_sheet.dart` requires **zero modifications** in Milestone 1.

---

## 3. Caveats

1. **macOS Modifier Key Normalization**:
   - On macOS, users frequently use the `Command` (`Meta`) key instead of `Ctrl`.
   - Normalization in `DesktopKeyboardHandler`:
     `final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;`
2. **Headless MPV C-FFI Safety**:
   - In unit tests where `player.platform` does not run a real native mpv backend, `(player.platform as dynamic).setProperty(...)` should be guarded in a `try / catch (e) { ... }` block to avoid breaking test suites.
3. **No Caveats Beyond Above**: All other aspects of the codebase (theming, state providers, layout) are stable and fully understood.

---

## 4. Conclusion & Actionable Blueprints

All 6 dispatch questions are conclusively resolved. Here are the ready-to-implement code blueprints:

### 4.1 Interface Contract: `DesktopKeyboardHandler`
File: `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

class DesktopKeyboardHandler extends StatefulWidget {
  final Player player;
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onCycleAspectRatio;
  final VoidCallback onCycleAudioTrack;
  final VoidCallback onCycleSubtitleTrack;
  final Function(int offsetMs) onNudgeAudioDelay;
  final Function(int offsetMs) onNudgeSubtitleDelay;
  final Function(String message, IconData icon) onShowOsd;
  final VoidCallback onUserActivity;
  final VoidCallback? onBeforeSeek;

  const DesktopKeyboardHandler({
    super.key,
    required this.player,
    required this.child,
    this.focusNode,
    required this.onToggleFullscreen,
    required this.onCycleAspectRatio,
    required this.onCycleAudioTrack,
    required this.onCycleSubtitleTrack,
    required this.onNudgeAudioDelay,
    required this.onNudgeSubtitleDelay,
    required this.onShowOsd,
    required this.onUserActivity,
    this.onBeforeSeek,
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

    widget.onUserActivity();

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    switch (event.logicalKey) {
      // 1. Play / Pause Toggle
      case LogicalKeyboardKey.space:
        widget.player.playOrPause();
        final isPlaying = widget.player.state.playing;
        widget.onShowOsd(
          isPlaying ? 'Pause' : 'Play',
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        );
        return KeyEventResult.handled;

      // 2. Fullscreen Toggle
      case LogicalKeyboardKey.keyF:
      case LogicalKeyboardKey.f11:
        widget.onToggleFullscreen();
        return KeyEventResult.handled;

      // 3. Mute Toggle
      case LogicalKeyboardKey.keyM:
        final currentVol = widget.player.state.volume;
        if (currentVol > 0.0) {
          _lastVolume = currentVol;
          widget.player.setVolume(0.0);
          widget.onShowOsd('Mute', Icons.volume_off_rounded);
        } else {
          final target = _lastVolume > 0 ? _lastVolume : 100.0;
          widget.player.setVolume(target);
          widget.onShowOsd('Volume: ${target.round()}%', Icons.volume_up_rounded);
        }
        return KeyEventResult.handled;

      // 4. Track Cycling (Audio: b, Subtitle: v)
      case LogicalKeyboardKey.keyB:
        widget.onCycleAudioTrack();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyV:
        widget.onCycleSubtitleTrack();
        return KeyEventResult.handled;

      // 5. Aspect Ratio Cycling (a)
      case LogicalKeyboardKey.keyA:
        widget.onCycleAspectRatio();
        return KeyEventResult.handled;

      // 6. Subtitle Delay (h = +50ms, g = -50ms)
      case LogicalKeyboardKey.keyH:
        widget.onNudgeSubtitleDelay(50);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyG:
        widget.onNudgeSubtitleDelay(-50);
        return KeyEventResult.handled;

      // 7. Audio Delay (k = +50ms, j = -50ms)
      case LogicalKeyboardKey.keyK:
        widget.onNudgeAudioDelay(50);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyJ:
        widget.onNudgeAudioDelay(-50);
        return KeyEventResult.handled;

      // 8. Playback Speed Controls
      case LogicalKeyboardKey.equal: // '=' resets to 1.0x
        widget.player.setRate(1.0);
        widget.onShowOsd('Speed: 1.0x (Normal)', Icons.speed_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.numpadAdd: // '+' coarse speed up (+0.5x)
        final rate = (widget.player.state.rate + 0.5).clamp(0.25, 4.0);
        widget.player.setRate(rate);
        widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract: // '-' coarse speed down (-0.5x)
        final rate = (widget.player.state.rate - 0.5).clamp(0.25, 4.0);
        widget.player.setRate(rate);
        widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.bracketRight: // ']' fine speed up (+0.1x)
        final rate = (widget.player.state.rate + 0.1).clamp(0.25, 4.0);
        widget.player.setRate(rate);
        widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.bracketLeft: // '[' fine speed down (-0.1x)
        final rate = (widget.player.state.rate - 0.1).clamp(0.25, 4.0);
        widget.player.setRate(rate);
        widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
        return KeyEventResult.handled;

      // 9. 4-Tier Navigation Jumps (Shift=3s, Alt=10s, Ctrl=60s, Ctrl+Alt=300s)
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
        final isForward = event.logicalKey == LogicalKeyboardKey.arrowRight;
        final int jumpSeconds;
        final String tierName;

        if (isCtrl && isAlt) {
          jumpSeconds = 300; // 5 minutes
          tierName = 'Long Jump (5m)';
        } else if (isCtrl) {
          jumpSeconds = 60;  // 1 minute
          tierName = 'Medium Jump (1m)';
        } else if (isAlt) {
          jumpSeconds = 10;  // 10 seconds
          tierName = 'Short Jump (10s)';
        } else if (isShift) {
          jumpSeconds = 3;   // 3 seconds
          tierName = 'Dialogue Jump (3s)';
        } else {
          jumpSeconds = 10;  // Default arrow seek
          tierName = 'Seek (10s)';
        }

        final delta = Duration(seconds: isForward ? jumpSeconds : -jumpSeconds);
        final current = widget.player.state.position;
        final duration = widget.player.state.duration;
        var target = current + delta;
        if (target < Duration.zero) target = Duration.zero;
        if (duration > Duration.zero && target > duration) target = duration;

        widget.onBeforeSeek?.call();
        widget.player.seek(target);
        widget.onShowOsd(
          '${isForward ? '+' : '-'}${jumpSeconds}s ($tierName)',
          isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
        );
        return KeyEventResult.handled;

      // 10. Volume Up / Down (5% steps, 0-100% or 150%)
      case LogicalKeyboardKey.arrowUp:
        final vol = (widget.player.state.volume + 5.0).clamp(0.0, 100.0);
        widget.player.setVolume(vol);
        widget.onShowOsd('Volume: ${vol.round()}%', Icons.volume_up_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        final vol = (widget.player.state.volume - 5.0).clamp(0.0, 100.0);
        widget.player.setVolume(vol);
        widget.onShowOsd(
          vol == 0 ? 'Mute' : 'Volume: ${vol.round()}%',
          vol == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
        );
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
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

### 4.2 Helper Methods to Add to `_PlayerScreenState`
File: `lib/features/player/ui/player_screen.dart`
```dart
  final FocusNode _focusNode = FocusNode();
  List<AudioTrack> _audioTracks = [];
  AudioTrack _selectedAudioTrack = AudioTrack.no();
  double _audioDelayMs = 0.0;
  bool _isFullscreen = false;

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (Platform.isAndroid || Platform.isIOS) {
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    _showFeedbackMessage(
      _isFullscreen ? 'Fullscreen' : 'Windowed',
      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
    );
  }

  void _cycleAspectRatio() {
    const ratios = ['Fit', 'Crop', '16:9', '4:3', 'Fill', 'Original'];
    final currentIndex = ratios.indexOf(_aspectRatio);
    final nextIndex = (currentIndex + 1) % ratios.length;
    final nextRatio = ratios[nextIndex];
    _setAspectRatio(nextRatio);
    _showFeedbackMessage('Aspect: $nextRatio', Icons.aspect_ratio);
  }

  void _cycleAudioTrack() {
    if (_audioTracks.isEmpty) {
      _showFeedbackMessage('No Audio Tracks', Icons.audiotrack);
      return;
    }
    final currentIndex = _audioTracks.indexOf(_selectedAudioTrack);
    final nextIndex = (currentIndex + 1) % _audioTracks.length;
    final nextTrack = _audioTracks[nextIndex];
    _player.setAudioTrack(nextTrack);
    setState(() => _selectedAudioTrack = nextTrack);
    final label = nextTrack.title ?? nextTrack.language ?? nextTrack.id;
    _showFeedbackMessage('Audio Track: $label', Icons.audiotrack);
  }

  void _cycleSubtitleTrack() {
    if (_subtitleTracks.isEmpty) {
      _showFeedbackMessage('No Subtitle Tracks', Icons.subtitles);
      return;
    }
    final currentIndex = _subtitleTracks.indexOf(_selectedSubtitleTrack);
    final nextIndex = (currentIndex + 1) % _subtitleTracks.length;
    final nextTrack = _subtitleTracks[nextIndex];
    _player.setSubtitleTrack(nextTrack);
    setState(() => _selectedSubtitleTrack = nextTrack);
    final label = nextTrack.title ?? nextTrack.language ?? (nextTrack == SubtitleTrack.no() ? 'Off' : nextTrack.id);
    _showFeedbackMessage('Subtitle: $label', Icons.subtitles);
  }

  void _nudgeSubtitleDelay(int offsetMs) {
    _subtitleConfig.delay += (offsetMs / 1000.0);
    try {
      final platform = _player.platform as dynamic;
      platform.setProperty('sub-delay', _subtitleConfig.delay.toStringAsFixed(2));
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to set sub-delay: $e');
    }
    final sign = _subtitleConfig.delay >= 0 ? '+' : '';
    final ms = (_subtitleConfig.delay * 1000).round();
    _showFeedbackMessage('Sub Delay: $sign${ms}ms', Icons.subtitles);
  }

  void _nudgeAudioDelay(int offsetMs) {
    _audioDelayMs = (_audioDelayMs + offsetMs).clamp(-10000.0, 10000.0);
    try {
      final platform = _player.platform as dynamic;
      platform.setProperty('audio-delay', (_audioDelayMs / 1000.0).toStringAsFixed(3));
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to set audio-delay: $e');
    }
    final sign = _audioDelayMs >= 0 ? '+' : '';
    _showFeedbackMessage('Audio Delay: $sign${_audioDelayMs.round()}ms', Icons.audiotrack);
  }
```

---

## 5. Verification Method

To independently verify the architecture and blueprints:

1. **Verify Static Code Cleanliness**:
   ```powershell
   cd d:\E-player\app
   dart analyze
   ```
   *Expected outcome*: Zero errors, zero warnings.

2. **Verify DesktopKeyboardHandler Unit Test Suite**:
   Create and execute `test/unit/desktop_keyboard_handler_test.dart` verifying all 13 shortcuts and 4-tier modifier combinations using Flutter's `simulateKeyDownEvent` / `simulateKeyUpEvent`:
   ```powershell
   cd d:\E-player\app
   flutter test test/unit/desktop_keyboard_handler_test.dart
   ```
   *Expected outcome*: All unit and widget tests pass with zero C-FFI runtime crashes.

3. **Verify Zero Modification Boundary**:
   ```powershell
   cd d:\E-player\app
   git status --porcelain lib/features/player/ui/audio_studio_sheet.dart
   ```
   *Expected outcome*: Clean output (no changes to `audio_studio_sheet.dart`).

4. **Invalidation Conditions**:
   - Calling `_aiEngine.invalidateQueue()` inside `DesktopKeyboardHandler` instead of via `onBeforeSeek`, which would cause headless unit tests to fail on missing AI native libraries.
   - Modifying `audio_studio_sheet.dart` during Milestone 1.
   - Forgetting `.then((_) => _focusNode.requestFocus())` on modal bottom sheets, causing keyboard shortcuts to stop responding after opening any menu.
