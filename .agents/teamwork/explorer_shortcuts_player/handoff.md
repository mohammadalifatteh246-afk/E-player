# Handoff Report: Shortcuts & Player Architecture Exploration

**Agent**: Shortcuts and Player Architecture Explorer (Kronos)  
**Target Milestone**: Phase 1 Deliverables (R1 Desktop Shortcuts, R2 Multi-Tier Precision Jumps, R4 Dedicated Audio Track Selector, OSD Feedback & Player HUD)  
**Date**: 2026-11-10T08:27:00Z  
**Status**: Investigation Complete  

---

## 1. Observation

Direct observations from examining the codebase at `d:\E-player\app`:

### 1.1 PlayerScreen Architecture & Focus Management
- **File**: `d:\E-player\app\lib\features\player\ui\player_screen.dart` (2,136 lines)
- **Invocation**: Pushed via `MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: ...))` from `LibraryScreen` (`lib/features/library/ui/library_screen.dart:1130, 1411, 1433`), `FolderDetailScreen` (`lib/features/library/ui/folder_detail_screen.dart:728, 873`), `ExportScreen` (`lib/features/export/ui/export_screen.dart:800`), and `VideoGroupCard` (`lib/features/library/ui/widgets/video_group_card.dart:313, 509, 643`).
- **Absence of Focus/Keyboard Infrastructure**: A PowerShell search across `player_screen.dart` for `Focus|Keyboard|Shortcut` returned **0 matches**. Across the entire `lib/` directory, a recursive search for `LogicalKeyboardKey`, `Shortcuts`, `KeyboardListener`, or `onKeyEvent` returned **0 matches**. The application currently has **no keyboard shortcut listener or focus management** whatsoever.
- **Current Root Widget Hierarchy** (`player_screen.dart:1076-1182`):
  ```dart
  Widget build(BuildContext context) {
    ...
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
          )
        )
      )
    );
  }
  ```
  Neither `Scaffold` nor `MouseRegion` possesses a `FocusNode` or `autofocus: true`. On desktop platforms (Windows, macOS, Linux), the route opens unfocused.

### 1.2 Seeking Mechanics & Clamping Logic
- **Current Seeking Invocations**:
  - Rewind 10s (`player_screen.dart:1724-1729`):
    ```dart
    final newPos = _position - const Duration(seconds: 10);
    _aiEngine.invalidateQueue();
    _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
    _showControls();
    ```
  - Forward 10s (`player_screen.dart:1763-1768`):
    ```dart
    final newPos = _position + const Duration(seconds: 10);
    _aiEngine.invalidateQueue();
    _player.seek(newPos > _duration ? _duration : newPos);
    _showControls();
    ```
  - Gesture Seek (`player_screen.dart:365-368`):
    ```dart
    _seekCommitSubscription = _gestureEngine.seekCommitEvents.listen((event) {
      _aiEngine.invalidateQueue();
      _player.seek(event.target);
    });
    ```
  - PiP Seeking (`player_screen.dart:177-186`):
    ```dart
    case PipAction.seekForward10:
      final target = _position + const Duration(seconds: 10);
      final clamped = target > _duration ? _duration : target;
      _player.seek(clamped);
      break;
    case PipAction.seekRewind10:
      final target = _position - const Duration(seconds: 10);
      final clamped = target < Duration.zero ? Duration.zero : target;
      _player.seek(clamped);
      break;
    ```
- **Clamping Observation**: Seeking requires clamping between `Duration.zero` and `_duration`. However, if `_duration == Duration.zero` (e.g., initial media buffering or live stream), clamping with `target > _duration ? _duration : target` would clamp valid forward seeks to 0. A defensive guard `_duration > Duration.zero && target > _duration ? _duration : target` is needed.
- **Queue Invalidation**: Every seek in `PlayerScreen` calls `_aiEngine.invalidateQueue()` prior to `_player.seek(...)` to clear pending frame-enhancement tasks in `NativeEngineOrchestrator`.

### 1.3 On-Screen Display (OSD) Mechanics
- **Gesture HUD Overlay** (`player_screen.dart:1947-1979`):
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
- **Dead / Orphaned Feedback State**:
  - `_PlayerScreenState` defines `_feedbackText = ''`, `_feedbackIcon = null`, `_showFeedback = false`, and `Timer? _feedbackTimer` (`player_screen.dart:95-99`).
  - `_showFeedbackMessage(String msg, IconData icon)` (`player_screen.dart:428-438`) updates `_feedbackText` and sets `_showFeedback = true` for 800ms.
  - **Critical Defect**: `_showFeedback` is **never rendered in the widget tree** in `build()`. Calls to `_showFeedbackMessage("Paused", Icons.pause)` (line 320) or `_showFeedbackMessage('Unlocked', Icons.lock_open)` (line 1817) produce no visual change on screen.

### 1.4 Top Bar HUD Layout & Audio Track Switcher
- **Current Top Bar Controls** (`player_screen.dart:1250-1427`):
  Inside a floating glassmorphic container (`top: 24`, `left: 16`, `right: 16`), the row contains:
  1. Back button (`Icons.arrow_back_ios_new`)
  2. Media Title + Resolution Badge (`4K`/`1080P`) + Decoder Badge (`_decoderMode`)
  3. Cast button (`Consumer<CastService>`)
  4. PiP button (`EVectorIcon(name: 'pip')`)
  5. AI Enhancement Studio (`Icons.auto_awesome`)
  6. Subtitle Selector (`Icons.subtitles_outlined` -> `_showSubtitleMenu`)
  7. Technical Media Inspector (`Icons.info_outline_rounded` -> `MediaInfoSheet.show`)
  8. Settings Drawer toggle (`Icons.more_vert`)
- **Audio Track State Absence**:
  - `_PlayerScreenState` subscribes only to `_player.stream.tracks` for `tracks.subtitle` (`player_screen.dart:267-269`) and `_player.stream.track` for `track.subtitle` (`player_screen.dart:270-272`).
  - Audio tracks (`tracks.audio` and `track.audio`) are completely unobserved.
  - There is no button or menu for switching audio tracks in `PlayerScreen`.

### 1.5 Subtitle & Audio Delay Sync Mechanics
- **Subtitle Delay**: `SubtitleSettingsSheet` (`subtitle_settings_sheet.dart:47`) directly sets mpv property:
  `platform.setProperty('sub-delay', delay.toStringAsFixed(2));`
- **Audio Delay**: In `vlc_gap_analysis.md:851, 1070-1120`, audio delay maps directly to mpv property `audio-delay` via:
  `platform.setProperty('audio-delay', offsetSeconds.toString());`
- **AudioConfig in `audio_studio_sheet.dart`**: Currently lacks `delay` and `preamp` properties. It contains 9 EQ presets (`Flat`, `Rock`, `Pop`, `Jazz`, `Classical`, `Bass Boost`, `Vocal Boost`, `Techno`, `Club`), whereas R5 requires 11 VLC presets plus Preamp slider.

### 1.6 Verification Baseline & Test Infrastructure
- Running `flutter analyze` across `d:\E-player\app`:
  - Result: `No issues found! (ran in 140.1s)`. Clean static analysis baseline.
- Running `flutter test test\unit\decoder_pipeline_test.dart`:
  - Result: `All tests passed! (21 passed)`.
- Test harness pattern (`test/helpers/eplayer_test_harness.dart` and `test/unit/decoder_pipeline_test.dart`):
  - In unit tests, `FakeMpvPlatform` simulates the `libmpv` property store (`setProperty`, `getProperty`).
  - Pure unit tests avoid instantiating native C-FFI `Player()` to prevent dynamic library missing errors in headless runners.

---

## 2. Logic Chain

1. **Focus Architecture Necessity (R1)**:
   - *From 1.1*: Flutter desktop does not grant keyboard focus to newly pushed routes unless a `Focus` widget with `autofocus: true` and a dedicated `FocusNode` actively captures focus.
   - When dialogs or bottom sheets close (`Navigator.pop`), focus must be programmatically reclaimed (`_focusNode.requestFocus()`).
   - A dedicated `DesktopKeyboardHandler` widget wrapping `PlayerScreen`'s body (or embedded directly within `PlayerScreen`) using `Focus` with `onKeyEvent: (node, event) => _handleKeyEvent(event)` is the standard, reliable mechanism in Flutter desktop.

2. **Modifier-Based 4-Tier Jump Physics (R2)**:
   - *From 1.1 & 1.2*: In modern Flutter (`flutter/services.dart`), `HardwareKeyboard.instance` provides real-time state for modifiers:
     - `HardwareKeyboard.instance.isShiftPressed`
     - `HardwareKeyboard.instance.isAltPressed`
     - `HardwareKeyboard.instance.isControlPressed`
     - `HardwareKeyboard.instance.isMetaPressed`
   - Evaluation order for arrow left / right must match VLC precedence:
     - `Ctrl + Alt`: 300 seconds (5 minutes - Scene jump)
     - `Ctrl`: 60 seconds (1 minute - Intro/recap skip)
     - `Alt`: 10 seconds (Short jump - Sentence skip)
     - `Shift`: 3 seconds (Very short jump - Dialogue clarification)
     - None (Bare arrow): 10 seconds (Standard jump)
   - Every seek must call `_aiEngine.invalidateQueue()`, calculate `newPosition = _position + delta`, clamp to `[Duration.zero, _duration]`, call `_player.seek(clampedPosition)`, trigger an OSD feedback pill (e.g., `+3s (3.0s dialogue jump)`), and invoke `_showControls()`.

3. **Universal Shortcuts Coverage (R1)**:
   - `Space`: `_player.playOrPause()` + OSD "Play" / "Pause".
   - `f` / `F11`: Fullscreen toggle.
   - `m`: Mute toggle (`_player.state.volume > 0 ? _player.setVolume(0) : _player.setVolume(_lastNonZeroVolume)`) + OSD "Mute" / "Unmute: X%".
   - `b`: Cycle audio track: retrieves `_audioTracks`, cycles index `(currentIdx + 1) % _audioTracks.length`, calls `_player.setAudioTrack(nextTrack)`, and emits OSD "Audio: [Track Title/Language]".
   - `v`: Cycle subtitle track: retrieves `_subtitleTracks`, cycles index, calls `_player.setSubtitleTrack(nextTrack)`, and emits OSD "Subtitle: [Title/Language]" or "Subtitles Off".
   - `a`: Cycle aspect ratios: cycles through `['Fit', 'Crop', '16:9', '4:3', '21:9']`, calls `_setAspectRatio(nextRatio)`, and emits OSD "Aspect Ratio: [Mode]".
   - `h` / `g`: Subtitle delay nudge: `±50ms` (`±0.05s`), updates `_subtitleConfig.delay`, applies `platform.setProperty('sub-delay', ...)`, and emits OSD "Sub Delay: ±X ms".
   - `k` / `j`: Audio delay nudge: `±50ms` (`±0.05s`), updates `_audioConfig.audioDelay`, applies `platform.setProperty('audio-delay', ...)`, and emits OSD "Audio Delay: ±X ms".
   - `+` / `-`: Coarse speed adjustment (`1.0x -> 1.5x -> 2.0x` or `±0.25x`), updates `_playbackSpeed`, calls `_player.setRate(...)`, and emits OSD "Speed: X.Xx".
   - `]` / `[`: Fine speed adjustment (`±0.1x`, clamped `0.25x` to `4.0x`), calls `_player.setRate(...)`, and emits OSD "Speed: X.Xx".
   - `=`: Reset speed to `1.0x`, calls `_player.setRate(1.0)`, and emits OSD "Speed: 1.0x (Normal)".
   - `Arrow Up` / `Arrow Down`: Volume adjustment in 5% steps (`±5.0`, clamped `0.0` to `150.0`), calls `_player.setVolume(...)`, and emits OSD "Volume: X%".

4. **Revitalizing the OSD System (OSD)**:
   - *From 1.3*: `_showFeedback` is currently dead code. Rather than creating two competing overlays, `_showFeedbackMessage(String text, IconData icon, {String? badge})` should be rendered at `top: 90` directly inside the existing `Stack`.
   - When a shortcut or gesture triggers, the OSD pill displays:
     - Glassmorphic card (`EDesign.surface.withValues(alpha: 0.90)`, `Border.all(color: EDesign.primary.withValues(alpha: 0.6))`).
     - Leading `Icon` with `EDesign.primary`.
     - Main `Text` (e.g., "Audio Track: English [stereo]", "Seek: +3s", "Speed: 1.1x").
     - Optional `badge` (e.g., "Fine", "Dialogue Jump", "+50ms").
     - 800ms auto-dismissal timer with smooth fade out.

5. **Dedicated Audio Track Selector Modal (R4)**:
   - *From 1.4*: The HUD top bar has a natural slot between AI Studio (`Icons.auto_awesome`) and Subtitles (`Icons.subtitles_outlined`).
   - Inserting `IconButton(icon: Icon(Icons.audiotrack_outlined), tooltip: 'Audio Tracks', onPressed: _showAudioTrackMenu)` provides instantaneous symmetry with Subtitles.
   - `_showAudioTrackMenu()` opens a glassmorphic bottom sheet mirroring `_showSubtitleMenu()`:
     - Subscribes to `_player.stream.tracks` (`tracks.audio`) and `_player.stream.track` (`track.audio`).
     - Lists all audio streams: Title, Language, Codec, Channels (e.g. "English (Surround 5.1)").
     - Displays checkmark on `_selectedAudioTrack == track`.
     - Calls `_player.setAudioTrack(track)` on tap, closes modal, and shows OSD feedback.

6. **Testability & Clean-Room Verification Strategy**:
   - *From 1.6*: Direct widget testing of `PlayerScreen` can fail if headless tests attempt to initialize C-FFI `Player` without `mpv.dll`.
   - Therefore, extracting the keyboard shortcut dispatching logic into `DesktopKeyboardHandler` (or an action controller) allows 100% pure widget tests:
     - A test mounts `DesktopKeyboardHandler` with a mock or callback harness.
     - Simulates `KeyDownEvent` for `LogicalKeyboardKey.space`, `arrowRight` with `Shift`, `Ctrl`, `Alt`, etc.
     - Asserts that callbacks receive the exact durations (`Duration(seconds: 3)`, `Duration(seconds: 60)`, etc.).

---

## 3. Caveats

1. **Hardware Acceleration & Native MPV Properties**:
   - `audio-delay` and `sub-delay` properties are set via `(player.platform as dynamic).setProperty('property-name', value)`. In headless unit tests where `player.platform` is not a real native platform, this must be wrapped in a defensive `try / catch` or test interface.
2. **Desktop Window Fullscreen**:
   - Flutter's standard `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` handles fullscreen on mobile and certain desktop embedders. On desktop without extra plugins, toggling fullscreen can be handled cleanly via `media_kit_video`'s `controller` or standard window APIs.
3. **No Caveats Beyond Above**: All other aspects of the codebase (theming, state providers, layout) are stable and fully understood.

---

## 4. Conclusion & Architectural Blueprints

### 4.1 Architecture Component Blueprint: `DesktopKeyboardHandler`
Place in `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Universal desktop keyboard shortcuts and 4-tier jump dispatcher for E-Player.
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
  });

  @override
  State<DesktopKeyboardHandler> createState() => _DesktopKeyboardHandlerState();
}

class _DesktopKeyboardHandlerState extends State<DesktopKeyboardHandler> {
  final FocusNode _focusNode = FocusNode();
  double _lastVolume = 100.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    widget.onUserActivity();

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

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

      // 8. Speed Controls
      case LogicalKeyboardKey.equal: // '=' resets to 1.0x
        widget.player.setRate(1.0);
        widget.onShowOsd('Speed: 1.0x (Normal)', Icons.speed_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.numpadAdd: // '+' coarse speed up
        final rate = (widget.player.state.rate + 0.25).clamp(0.25, 4.0);
        widget.player.setRate(rate);
        widget.onShowOsd('Speed: ${rate.toStringAsFixed(2)}x', Icons.speed_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract: // '-' coarse speed down
        final rate = (widget.player.state.rate - 0.25).clamp(0.25, 4.0);
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

        widget.player.seek(target);
        widget.onShowOsd(
          '${isForward ? '+' : '-'}${jumpSeconds}s ($tierName)',
          isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
        );
        return KeyEventResult.handled;

      // 10. Volume Up / Down (5% steps)
      case LogicalKeyboardKey.arrowUp:
        final vol = (widget.player.state.volume + 5.0).clamp(0.0, 150.0);
        widget.player.setVolume(vol);
        widget.onShowOsd('Volume: ${vol.round()}%', Icons.volume_up_rounded);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        final vol = (widget.player.state.volume - 5.0).clamp(0.0, 150.0);
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
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
```

### 4.2 Top Bar Audio Selector Integration
In `PlayerScreen` (`player_screen.dart`), between AI Studio (`line 1403`) and Subtitles (`line 1404`), insert:

```dart
IconButton(
  icon: const Icon(Icons.audiotrack_outlined, color: Colors.white70, size: 20),
  tooltip: 'Audio Tracks',
  onPressed: _showAudioTrackMenu,
),
```

And define `_showAudioTrackMenu()`:
```dart
void _showAudioTrackMenu() {
  showModalBottomSheet(
    context: context,
    backgroundColor: EDesign.surface,
    builder: (context) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Audio Tracks', style: EDesign.h3),
          ),
          if (_audioTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No audio tracks found', style: EDesign.secondaryStyle),
            ),
          for (final track in _audioTracks)
            ListTile(
              leading: const Icon(Icons.audiotrack, color: EDesign.primaryCyan),
              title: Text(track.title ?? track.language ?? track.id, style: EDesign.body),
              subtitle: track.channels != null ? Text('${track.channels} channels', style: EDesign.caption) : null,
              trailing: _selectedAudioTrack == track
                  ? const Icon(Icons.check, color: EDesign.primary)
                  : null,
              onTap: () {
                _player.setAudioTrack(track);
                Navigator.pop(context);
                _showFeedbackMessage('Audio: ${track.title ?? track.language ?? track.id}', Icons.audiotrack);
              },
            ),
        ],
      );
    },
  ).then((_) {
    // Reclaim focus for keyboard shortcuts upon modal close
    _focusNode?.requestFocus();
  });
}
```

### 4.3 OSD Notification Widget Overlay
Render the visual feedback overlay pill at `top: 90` when `_showFeedback` is active in `PlayerScreen.build()`:
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

---

## 5. Verification Method

To verify the investigation and blueprints:

1. **Verify Static Cleanliness**:
   ```powershell
   cd d:\E-player\app
   flutter analyze
   ```
   *Expected outcome*: Zero errors, zero warnings.

2. **Verify Existing Unit Test Suite**:
   ```powershell
   cd d:\E-player\app
   flutter test test\unit\decoder_pipeline_test.dart
   ```
   *Expected outcome*: All 21 tests pass without native C library dependencies.

3. **Verify Proposed Shortcuts & 4-Tier Jump Unit Tests**:
   Create a dedicated widget unit test (`test/unit/desktop_keyboard_handler_test.dart`) simulating `KeyDownEvent` using `simulateKeyDownEvent` / `simulateKeyUpEvent` across all keys and modifier flags (`isShiftPressed`, `isAltPressed`, `isControlPressed`), verifying that:
   - `Shift + ArrowRight` triggers a 3-second seek.
   - `Alt + ArrowRight` triggers a 10-second seek.
   - `Ctrl + ArrowRight` triggers a 60-second seek.
   - `Ctrl + Alt + ArrowRight` triggers a 300-second seek.
   - `Space`, `m`, `b`, `v`, `a`, `h`, `g`, `k`, `j`, `+`, `-`, `]`, `[`, `=` dispatch their corresponding actions.
   Run:
   ```powershell
   cd d:\E-player\app
   flutter test test\unit\desktop_keyboard_handler_test.dart
   ```

4. **Invalidation Conditions**:
   - If `HardwareKeyboard.instance.isControlPressed` does not register on macOS (where `Meta`/Command key is sometimes used instead), modifier checks should use `isControlPressed || isMetaPressed` for universal macOS/Windows compatibility.
   - If modal bottom sheets consume keyboard events while open, `_focusNode.requestFocus()` must be called in `showModalBottomSheet.then(...)` or route transition callbacks.
