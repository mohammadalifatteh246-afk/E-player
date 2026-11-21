# Investigation & Architecture Report: Interaction Physics & UI/UX Micro-Mechanics (Phase 2)

**Agent**: AURA (Interaction Physics & UI/UX Micro-Mechanic Analyst)  
**State Folder**: `d:\E-player\.agents\teamwork\explorer_survey_2`  
**Target Codebase**: `d:\E-player\app`  
**Scope**: Phase 2 Core UX & Playback Enhancements (Volume 0–300%, 3-Color Safety Indicator, Desktop Shortcuts, HUD UI Integration)  
**Date**: 2026-11-11  

---

## 1. Observation

Direct, empirical source code inspection and analysis across `d:\E-player\app` yielded the following concrete observations:

### 1.1 CinematicGestureEngine & Gesture Models
- **File**: `lib/features/player/ui/cinematic_gesture_engine.dart`
  - **Volume State Clamping**:
    - Line 179: `_volume = initialVolume.clamp(0.0, 100.0);`
    - Line 200: `void setExternalVolume(double value) { _volume = value.clamp(0.0, 100.0); }`
  - **Volume Gesture Physics**:
    - Lines 406–423 (`_handleVolumeAdjust`):
      ```dart
      void _handleVolumeAdjust(
        ScaleUpdateDetails details,
        Size viewportSize,
      ) {
        final effectiveHeight = viewportSize.height > 0 ? viewportSize.height : 600.0;
        // Dragging upwards (negative dy) increases volume
        final delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 100.0;
        _volume = (_volume + delta).clamp(0.0, 100.0);
        onVolumeChanged?.call(_volume);

        _feedbackController.add(GestureFeedbackEvent(
          type: GestureFeedbackType.volume,
          value: _volume,
          label: '${_volume.round()}%',
          deltaFormatted: '${_volume.round()}%',
        ));
      }
      ```
    - The active vertical track height is computed as `effectiveHeight * 0.7` (70% of screen height).
    - Sensitivity multiplier is strictly `100.0`.
- **File**: `lib/features/player/ui/gesture_models.dart`
  - Lines 40–41: Documented as `/// - Volume: 0.0 to 100.0`.
  - Line 17: `volumeAdjust` enum in `GestureMode`.

### 1.2 DesktopKeyboardHandler
- **File**: `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
  - **Volume Adjustments (Arrow Up / Down)**:
    - Lines 231–250:
      ```dart
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.onUserActivity();
        final vol = (widget.player.state.volume + 5.0).clamp(0.0, 150.0);
        widget.player.setVolume(vol);
        widget.onShowOsd(
          'Volume: ${vol.round()}%',
          vol > 100 ? Icons.volume_up_rounded : Icons.volume_down_rounded,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.onUserActivity();
        final vol = (widget.player.state.volume - 5.0).clamp(0.0, 150.0);
        widget.player.setVolume(vol);
        widget.onShowOsd(
          vol == 0 ? 'Mute' : 'Volume: ${vol.round()}%',
          vol == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
        );
        return KeyEventResult.handled;
      }
      ```
    - Current ceiling is hard-clamped to `150.0`, failing Phase 2's 300% requirement.
    - `widget.onShowOsd` signature only accepts `(String message, IconData icon)`.
  - **Missing Phase 2 Shortcuts**:
    - `LogicalKeyboardKey.keyE` (Frame-by-Frame stepping) is completely absent.
    - `LogicalKeyboardKey.keyC` (Aspect Ratio Crop cycling) is completely absent (only `keyA` exists at line 132 for `onCycleAspectRatio`).

### 1.3 PlayerScreen & libmpv Integration
- **File**: `lib/features/player/ui/player_screen.dart`
  - **Player Initialization & Volume Max**:
    - Lines 220–222:
      ```dart
      _player = Player(
        configuration: const PlayerConfiguration(libass: true),
      );
      ```
    - Libmpv property `volume-max` is not explicitly set; libmpv defaults to `130.0` or `100.0`, which causes libmpv to silently clamp audio output if `setVolume()` is called with values $> 130.0$.
  - **Gesture Engine Wiring**:
    - Lines 330–339:
      ```dart
      _gestureEngine = CinematicGestureEngine(
        initialBrightness: _brightness,
        initialVolume: _volume,
        onInvalidateAiQueue: _aiEngine.invalidateQueue,
        onBrightnessChanged: (b) => setState(() => _brightness = b),
        onVolumeChanged: (v) {
          _player.setVolume(v);
          if (mounted) setState(() => _volume = v);
        },
      );
      ```
  - **Volume Feedback Overlay Rendering**:
    - Lines 2450–2480:
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
            Text(
              'Volume: ${event.label}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
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
    - The `LinearProgressIndicator` clamps the value to `(event.value / 100.0).clamp(0.0, 1.0)`. Any volume $> 100\%$ is clipped to 100% visually!
    - The icon and progress bar color are statically hardcoded to `EDesign.primary` (Cyan `0xFF19BFFF`), with zero 3-color safety indicator differentiation.
  - **OSD Pill Overlay**:
    - Lines 2327–2375: Glassmorphic pill uses fixed `EDesign.primary` for icon and border.
  - **HUD Controls Layout**:
    - Top bar: Lines 1588–1801 (Back, filename, resolution badge, decoder pill, cast, pip, ai, audio tracks, subtitles, inspector, settings).
    - Bottom scrubber: Lines 1963–2015 (`SliderTheme` with `Slider`, elapsed time, remaining time).
    - Bottom controls row: Lines 2018–2145:
      - Left group: Lock button (`Icons.lock_open_outlined`), Speed pill (`${_playbackSpeed}x`).
      - Center transport: Replay 10s (`Icons.replay_10_rounded`), glowing Play/Pause (`Icons.play_arrow_rounded`), Forward 10s (`Icons.forward_10_rounded`).
      - Right group: Audio EQ (`Icons.equalizer`), Aspect Ratio (`Icons.aspect_ratio_rounded`).
    - Position stream listener: Lines 265–267 (`_player.stream.position.listen`).
  - **Native mpv Command Dispatch**:
    - In `media_kit: ^1.2.6` (`lib/src/player/native/player/real.dart:1359–1373`), `(player.platform as dynamic).command(List<String> command)` is a public asynchronous method invoking `mpv_command_async`.
    - `(player.platform as dynamic).setProperty(String property, String value)` is a public asynchronous method invoking `mpv_set_property_string`.

---

## 2. Logic Chain

From these direct observations, we construct the step-by-step logic chain informing our architectural decisions:

```
[Observation 1.3: mpv volume-max defaults to <=130] 
  ──> (Step 1) Player initialization must explicitly execute:
      (_player.platform as dynamic).setProperty('volume-max', '300.0')
      Otherwise, calls to _player.setVolume(>130) will be rejected or clamped by mpv.

[Observation 1.1: CinematicGestureEngine clamps to 100.0]
  ──> (Step 2) _volume state and setters in CinematicGestureEngine must clamp to 300.0:
      _volume = (_volume + delta).clamp(0.0, 300.0)

[Observation 1.1: Gesture physics delta = (-dy / (H * 0.7)) * 100.0]
  ──> (Step 3) How to scale across 0% to 300% without jarring jumps?
      Let H_eff = viewportHeight * 0.7.
      Under current formula, dy = -H_eff gives delta = +100.
      If delta multiplier is switched to 300 linearly:
      Delta = (-dy / H_eff) * 300.0.
      This triples sensitivity across the entire touch range, degrading 1% precision in 0–100%.
      ALTERNATIVE (Piecewise-smooth dual sensitivity):
      In unity zone (volume <= 100%): 100% volume requires full sweep of H_eff (linear, scale factor 1.0).
      In boost zone (volume > 100%): 200% additional volume requires full sweep of H_eff (linear, scale factor 2.0).
      To guarantee ZERO jarring jumps ($C^0$ and $C^1$ continuity):
      We use a continuous progressive velocity/attenuation function or uniform continuous sensitivity:
      Physics Equation:
      delta = (-dy / H_eff) * k_vol
      Where k_vol = 150.0 (2 full vertical sweeps span 0% to 300%), or
      Continuous Dynamic Gain:
      sensitivity(V) = 100.0 + (V / 300.0) * 50.0
      At V=0: k=100.0 (high precision for low volumes).
      At V=100: k=116.7 (smooth transition).
      At V=300: k=150.0 (responsive over-amplification).
      Because sensitivity(V) is a smooth polynomial of degree 1 with positive derivative everywhere,
      the gesture response is strictly monotonic and exhibits C^inf smoothness with zero jump discontinuities.

[Observation 1.3: Progress indicator hardcoded to event.value / 100.0]
  ──> (Step 4) In PlayerScreen._buildGestureFeedbackContent:
      Progress fraction must be normalized over 300%:
      progress = (event.value / 300.0).clamp(0.0, 1.0)
      
[Observation 1.3: Fixed primary cyan color in HUD & OSD]
  ──> (Step 5) Dynamic 3-Color Safety Indicator specification:
      Define getVolumeSafetyColor(double volume):
      - 0.0 <= volume <= 100.0: Green (const Color(0xFF22C55E), VLC / Tailwind Emerald)
      - 100.0 < volume <= 200.0: Amber (const Color(0xFFF59E0B), Warning / Pre-amp Boost)
      - 200.0 < volume <= 300.0: Soft Red (const Color(0xFFEF4444), Danger / High Over-Amp)
      Apply this color dynamically to:
      1. Icon, Text, and LinearProgressIndicator valueColor in GestureFeedbackType.volume
      2. Gesture Card Border: color.withValues(alpha: 0.6)
      3. OSD pill icon and border when volume is adjusted via keyboard
      4. OverAmpVolumeSlider thumb and active track

[Observation 1.2: DesktopKeyboardHandler volume clamp is 150.0]
  ──> (Step 6) In DesktopKeyboardHandler:
      Arrow Up: (currentVol + 5.0).clamp(0.0, 300.0)
      Arrow Down: (currentVol - 5.0).clamp(0.0, 300.0)
      Pass the safety color into onShowOsd callback:
      widget.onShowOsd('Volume: ${vol.round()}%', icon, safetyColor)

[Observation 1.2: DesktopKeyboardHandler lacks keyE and keyC]
  ──> (Step 7) Add callbacks and handlers:
      keyE -> onStepFrame() -> if (player.state.playing) player.pause(); platform.command(['frame-step']);
      keyC -> onCycleCrop() -> cycle through ['16:9', '16:10', '4:3', '1.85:1', '2.35:1', 'Reset']
      mpv crop filter string: crop='min(iw,ih*R)':'min(ih,iw/R)'
      Reset -> clear crop filter string.

[Observation 1.3: PlayerScreen Bottom Controls Layout]
  ──> (Step 8) Ergonomic Button Placement:
      - Frame-Step Button: Place in Center Transport group, immediately following '+10s' button.
        Reasoning: Frame-by-frame stepping is a temporal playback control. Grouping it with Replay, Play, Forward creates a unified transport cluster.
      - A-B Looper Button: Place in Right Utility group, immediately preceding Audio EQ button.
        Reasoning: A-B looping is a playback mode/filter, ergonomically matched with Audio EQ and Aspect Ratio.
      - 4-State Controller State Machine:
        State 0 (Off) -> State 1 (Mark A) -> State 2 (Mark B & Loop) -> State 3/0 (Clear)
        Position Stream listener checks if (state == 2 && pos >= pointB) player.seek(pointA).
```

---

## 3. Detailed Technical Architecture & Blueprints

### 3.1 CinematicGestureEngine Volume Physics (0%–300%)

#### Physics Equation Formulation
To allow the user to navigate the entire 0% to 300% volume spectrum with natural tactile physics:

$$\Delta V = \left( -\frac{\Delta y}{H_{\text{eff}}} \right) \cdot K(V)$$

Where:
- $\Delta y = \text{details.focalPointDelta.dy}$ (positive downwards, negative upwards).
- $H_{\text{eff}} = \max(\text{viewportSize.height} \cdot 0.7,\, 400.0)$.
- $K(V)$ is the gain function.

**Two implementation models evaluated**:

1. **Uniform Extended Gain Model ($K = 150.0$)**:
   - Exactly 2 full swipes of $70\%$ viewport height span the entire $0\% \to 300\%$ range.
   - High precision: each $10\text{px}$ movement on a $700\text{px}$ viewport yields $\approx 3\%$ volume change.
   - **Zero discontinuity ($C^\infty$)**: Gain is constant; user feels identical touch resistance throughout the range.

2. **Continuous Progressive Gain Model**:
   $$K(V) = 100.0 + 50.0 \cdot \left(\frac{V}{300.0}\right)$$
   - At $V = 0\%$: $K = 100.0$ (highest resolution for quiet listening).
   - At $V = 100\%$: $K = 116.67$.
   - At $V = 300\%$: $K = 150.0$.
   - First derivative $\frac{dK}{dV} = \frac{50}{300} = \frac{1}{6} > 0$ is constant and smooth, guaranteeing zero acceleration jerks.

**Recommended Solution**:
Uniform Extended Gain ($K = 150.0$) with continuous clamping:
```dart
void _handleVolumeAdjust(
  ScaleUpdateDetails details,
  Size viewportSize,
) {
  final effectiveHeight = viewportSize.height > 0 ? viewportSize.height : 600.0;
  // Dragging upwards (negative dy) increases volume smoothly across 0..300%
  // 150.0 factor enables 2 full 70% viewport swipes to cover 0% to 300%
  final delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 150.0;
  _volume = (_volume + delta).clamp(0.0, 300.0);
  onVolumeChanged?.call(_volume);

  _feedbackController.add(GestureFeedbackEvent(
    type: GestureFeedbackType.volume,
    value: _volume,
    label: '${_volume.round()}%',
    deltaFormatted: '${_volume.round()}%',
  ));
}
```

#### libmpv Configuration Contract
In `PlayerScreen.initState()`:
```dart
_player = Player(
  configuration: const PlayerConfiguration(libass: true),
);
// CRITICAL: Configure libmpv volume-max to 300.0 to enable over-amplification
try {
  final platform = _player.platform as dynamic;
  platform.setProperty('volume-max', '300.0');
} catch (e) {
  debugPrint('[PlayerScreen] Failed to set volume-max: $e');
}
```

---

### 3.2 3-Color Safety Indicator Specifications (HUD & OSD)

#### Exact Color Palette Specification
```dart
class VolumeSafetyColors {
  /// Zone 1: Nominal Unity Gain (0% – 100%)
  /// Safe linear digital amplification.
  static const Color green = Color(0xFF22C55E); // VLC / Tailwind Green-500
  static const Color greenGlow = Color(0x6622C55E);

  /// Zone 2: Software Pre-Amp Boost (101% – 200%)
  /// Safe software boost for quiet recordings.
  static const Color amber = Color(0xFFF59E0B); // Amber-500
  static const Color amberGlow = Color(0x66F59E0B);

  /// Zone 3: High Over-Amplification Warning (201% – 300%)
  /// Soft red warning for potential clipping and speaker distortion.
  static const Color softRed = Color(0xFFEF4444); // Red-500
  static const Color softRedGlow = Color(0x66EF4444);

  /// Resolves the exact safety color for any volume value in [0.0, 300.0].
  static Color resolve(double volume) {
    if (volume <= 100.0) {
      return green;
    } else if (volume <= 200.0) {
      return amber;
    } else {
      return softRed;
    }
  }

  /// Resolves the subtle border / glow tint for card backgrounds.
  static Color resolveGlow(double volume) {
    if (volume <= 100.0) {
      return greenGlow;
    } else if (volume <= 200.0) {
      return amberGlow;
    } else {
      return softRedGlow;
    }
  }
}
```

#### Gesture Feedback Card Dynamic Styling (`PlayerScreen`)
Inside `_buildGestureFeedbackContent(GestureFeedbackEvent event)`:
```dart
case GestureFeedbackType.volume:
  final safetyColor = VolumeSafetyColors.resolve(event.value);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        event.value == 0
            ? Icons.volume_off_rounded
            : (event.value <= 100
                ? (event.value < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded)
                : (event.value <= 200 ? Icons.volume_up_rounded : Icons.warning_amber_rounded)),
        color: safetyColor,
        size: 22,
      ),
      const SizedBox(width: 8),
      Text(
        'Volume: ${event.label}',
        style: TextStyle(
          color: safetyColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 80,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (event.value / 300.0).clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(safetyColor),
            minHeight: 6,
          ),
        ),
      ),
    ],
  );
```
And the parent feedback container border in line 2307:
```dart
border: Border.all(
  color: (_activeFeedbackEvent?.type == GestureFeedbackType.volume)
      ? VolumeSafetyColors.resolve(_activeFeedbackEvent!.value).withValues(alpha: 0.8)
      : EDesign.primary.withValues(alpha: 0.6),
  width: 1.2,
),
```

---

### 3.3 DesktopKeyboardHandler Enhancements

#### File: `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`

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
  final Function(String message, IconData icon, [Color? color]) onShowOsd;
  final VoidCallback onUserActivity;
  final VoidCallback? onBeforeSeek;
  final void Function(Duration target)? onSeek;
  final VoidCallback? onStepFrame; // Phase 2: Frame-by-Frame Stepping ('e')
  final VoidCallback? onCycleCrop; // Phase 2: Aspect Ratio Crop Cycling ('c')
  final FocusNode? focusNode;
  final bool autofocus;
...
```

#### Key Event Dispatch Updates:

1. **Arrow Up / Arrow Down (0%–300% in 5% Steps)**:
```dart
// 9. Volume Adjustments (Arrow Up / Arrow Down in 5% steps across 0% to 300%)
if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
  widget.onUserActivity();
  final currentVol = widget.player.state.volume;
  final targetVol = ((currentVol + 5.0) / 5.0).round() * 5.0;
  final vol = targetVol.clamp(0.0, 300.0);
  widget.player.setVolume(vol);
  final color = VolumeSafetyColors.resolve(vol);
  widget.onShowOsd(
    'Volume: ${vol.round()}%',
    vol > 200 ? Icons.warning_amber_rounded : Icons.volume_up_rounded,
    color,
  );
  return KeyEventResult.handled;
}
if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
  widget.onUserActivity();
  final currentVol = widget.player.state.volume;
  final targetVol = ((currentVol - 5.0) / 5.0).round() * 5.0;
  final vol = targetVol.clamp(0.0, 300.0);
  widget.player.setVolume(vol);
  final color = VolumeSafetyColors.resolve(vol);
  widget.onShowOsd(
    vol == 0 ? 'Mute' : 'Volume: ${vol.round()}%',
    vol == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
    color,
  );
  return KeyEventResult.handled;
}
```

2. **Key 'e' (Frame-by-Frame Stepping)**:
```dart
// 11. Frame-by-Frame Stepping ('e')
if (event.logicalKey == LogicalKeyboardKey.keyE) {
  widget.onUserActivity();
  widget.onStepFrame?.call();
  return KeyEventResult.handled;
}
```

3. **Key 'c' (Aspect Ratio Crop Cycling)**:
```dart
// 12. Aspect Ratio Crop Cycling ('c')
if (event.logicalKey == LogicalKeyboardKey.keyC) {
  widget.onUserActivity();
  widget.onCycleCrop?.call();
  return KeyEventResult.handled;
}
```

---

### 3.4 Frame-by-Frame & Aspect Ratio Crop Implementation in `PlayerScreen`

#### Frame-Step Implementation
```dart
Future<void> _stepFrame() async {
  widget.onUserActivity?.call();
  // 1. Automatically pause playback upon first activation if currently playing
  if (_player.state.playing) {
    await _player.pause();
    if (mounted) setState(() => _isPlaying = false);
  }

  // 2. Advance by exactly 1 video frame via libmpv 'frame-step' command
  try {
    final platform = _player.platform as dynamic;
    await platform.command(['frame-step']);
  } catch (e) {
    debugPrint('[PlayerScreen] Failed to frame-step: $e');
  }

  // 3. Render feedback
  _showFeedbackMessage('Next Frame', Icons.skip_next_rounded);
  _showControls();
}
```

#### Aspect Ratio Crop Cycling Implementation
Crop cycling must crop the viewport **without geometrical stretching or aspect distortion**, matching VLC `crop` behavior.

```dart
class CropRatioPreset {
  final String label;
  final String vfString;

  const CropRatioPreset({required this.label, required this.vfString});
}

final List<CropRatioPreset> _cropPresets = const [
  CropRatioPreset(label: '16:9', vfString: "crop='min(iw,ih*16/9)':'min(ih,iw*9/16)'"),
  CropRatioPreset(label: '16:10', vfString: "crop='min(iw,ih*16/10)':'min(ih,iw*10/16)'"),
  CropRatioPreset(label: '4:3', vfString: "crop='min(iw,ih*4/3)':'min(ih,iw*3/4)'"),
  CropRatioPreset(label: '1.85:1', vfString: "crop='min(iw,ih*1.85)':'min(ih,iw/1.85)'"),
  CropRatioPreset(label: '2.35:1', vfString: "crop='min(iw,ih*2.35)':'min(ih,iw/2.35)'"),
  CropRatioPreset(label: 'Reset', vfString: ''),
];

int _currentCropIndex = 5; // Default: Reset (Off)

void _cycleCrop() {
  _currentCropIndex = (_currentCropIndex + 1) % _cropPresets.length;
  final preset = _cropPresets[_currentCropIndex];

  try {
    final platform = _player.platform as dynamic;
    // Set or clear the crop filter in mpv
    platform.setProperty('vf', preset.vfString);
  } catch (e) {
    debugPrint('[PlayerScreen] Failed to set crop filter: $e');
  }

  _showFeedbackMessage(
    preset.label == 'Reset' ? 'Crop: Reset (Off)' : 'Crop: ${preset.label}',
    Icons.crop,
  );
  _showControls();
}
```

---

### 3.5 Player HUD UI Integration: Frame-Step and A-B Looper Buttons

#### Layout Schematic in `PlayerScreen` Bottom Controls Row:
```
+--------------------------------------------------------------------------------------------------------+
|                                  [01:24:35] =======o============== [-00:43:18]                         |
+--------------------------------------------------------------------------------------------------------+
| [Lock] [Speed 1.0x]   |   [-10s]  ( PLAY / PAUSE )  [+10s]  [Frame Step]   |   [A-B]  [EQ]  [Aspect]   |
|     (Left Group)      |               (Center Transport Group)             |       (Right Group)       |
+--------------------------------------------------------------------------------------------------------+
```

#### Detailed Placement Specifications

1. **Frame-Step HUD Button (Center Transport Group)**:
   - **Location**: `lib/features/player/ui/player_screen.dart`, lines 2060–2112.
   - Place immediately following the `+10s` forward button (`line 2110`).
   - **Widget Code**:
     ```dart
     const SizedBox(width: 4),
     IconButton(
       key: const Key('hud_frame_step_button'),
       icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
       tooltip: 'Step Frame (e)',
       onPressed: _stepFrame,
     ),
     ```
   - **UX Rationale**: Frame stepping is an atomic seek operation. Placing it next to `+10s` and `Play/Pause` maintains cognitive continuity with temporal playback controls.

2. **A-B Looper HUD Button (Right Utility Group)**:
   - **Location**: `lib/features/player/ui/player_screen.dart`, lines 2114–2143.
   - Place immediately preceding the `Audio Equalizer` button (`line 2117`).
   - **Widget Code**:
     ```dart
     IconButton(
       key: const Key('hud_ab_loop_button'),
       icon: Icon(
         _abLoopState == 0
             ? Icons.repeat_rounded
             : (_abLoopState == 1 ? Icons.repeat_one_rounded : Icons.repeat_on_rounded),
         color: _abLoopState == 0
             ? Colors.white70
             : (_abLoopState == 1 ? EDesign.warning : EDesign.primaryCyan),
         size: 20,
       ),
       tooltip: _getAbLoopTooltip(),
       onPressed: _cycleAbLoop,
     ),
     ```
   - **UX Rationale**: Grouped with secondary player modes (Equalizer, Aspect Ratio). Does not clutter the central scrubbing zone.

#### 4-State A-B Looper Controller Architecture
```dart
int _abLoopState = 0; // 0: Off, 1: Point A Set, 2: Point B Set & Looping
Duration? _loopPointA;
Duration? _loopPointB;

String _getAbLoopTooltip() {
  switch (_abLoopState) {
    case 0:
      return 'A-B Loop: Set Point A';
    case 1:
      return 'A-B Loop: Set Point B';
    case 2:
      return 'A-B Loop: Active (${_formatDuration(_loopPointA!)} - ${_formatDuration(_loopPointB!)}) · Tap to Clear';
    default:
      return 'A-B Loop';
  }
}

void _cycleAbLoop() {
  setState(() {
    if (_abLoopState == 0) {
      // State 0 -> 1: Mark Point A
      _abLoopState = 1;
      _loopPointA = _position;
      _loopPointB = null;
      _showFeedbackMessage('Loop Point A: ${_formatDuration(_loopPointA!)}', Icons.repeat_one_rounded);
    } else if (_abLoopState == 1) {
      // State 1 -> 2: Mark Point B and engage loop
      if (_position > _loopPointA!) {
        _loopPointB = _position;
        _abLoopState = 2;
        _showFeedbackMessage(
          'Looping A-B (${_formatDuration(_loopPointA!)} - ${_formatDuration(_loopPointB!)})',
          Icons.repeat_on_rounded,
        );
      } else {
        // Edge case: Point B must be after Point A
        _showFeedbackMessage('Point B must be after Point A', Icons.error_outline_rounded);
      }
    } else {
      // State 2 -> 0: Clear & return to normal
      _abLoopState = 0;
      _loopPointA = null;
      _loopPointB = null;
      _showFeedbackMessage('Loop Cleared', Icons.repeat_rounded);
    }
  });
  _showControls();
}
```

In `_player.stream.position.listen` (`player_screen.dart:265`):
```dart
_player.stream.position.listen((pos) {
  if (mounted) {
    setState(() => _position = pos);
    // Real-time A-B loop check
    if (_abLoopState == 2 && _loopPointA != null && _loopPointB != null) {
      if (pos >= _loopPointB!) {
        _player.seek(_loopPointA!);
      }
    }
  }
});
```

---

## 4. Caveats

1. **mpv Video Filter Dynamic Concatenation**: When setting `vf` for aspect ratio crop cycling (`platform.setProperty('vf', ...)`), if the user also enables video effects (such as sharpen `unsharp` or banding removal `gradfun` from `VideoEffectsService`), applying `vf` for crop could overwrite `lastAppliedVf`. To prevent conflict, the implementer should coordinate `VideoEffectsService.buildMpvVfString()` with the active crop filter string so they are chained with a comma (e.g. `"unsharp=...,crop=..."`).
2. **Platform Dependency of `platform.command(['frame-step'])`**: The `command` method exists on `NativePlayer` in `media_kit` for Windows, macOS, Linux, and Android. In automated tests using headless or mocked players (`FakePlayer`), `command` must be implemented or stubbed on the fake platform.
3. **Volume 300% Audio Hardware Safety**: Digital amplification above 100% can introduce digital clipping/saturation for high dynamic range audio. The 3-color safety indicator (amber at 101–200%, soft red at 201–300%) is critical to visually warn the user.

---

## 5. Conclusion

1. **Volume Over-Amplification to 300%**:
   - `CinematicGestureEngine`: Extend vertical right-edge swipe delta using uniform extended gain ($K = 150.0$), allowing 2 full vertical swipes to traverse 0% to 300% smoothly with zero jump discontinuities and boundary clamp $[0.0, 300.0]$.
   - `PlayerScreen`: Set `volume-max` to `300.0` on libmpv via `platform.setProperty('volume-max', '300.0')`.
   - `DesktopKeyboardHandler`: Update Arrow Up / Down volume clamping from `150.0` to `300.0` in 5% increments.
2. **3-Color Safety Indicator**:
   - Implement `VolumeSafetyColors`: Green (`0xFF22C55E`) for 0–100%, Amber (`0xFFF59E0B`) for 101–200%, Soft Red (`0xFFEF4444`) for 201–300%.
   - Apply dynamically to `GestureFeedbackType.volume` (overlay card icon, text, and `LinearProgressIndicator` normalized to 300%), OSD feedback pill overlay, and the HUD volume slider.
3. **Desktop Shortcuts**:
   - Bind `LogicalKeyboardKey.keyE` to trigger frame-step (pausing if playing, dispatching `platform.command(['frame-step'])`).
   - Bind `LogicalKeyboardKey.keyC` to trigger non-distorted aspect ratio crop cycling via mpv `vf` crop filter.
4. **HUD Ergonomics**:
   - Add Frame-Step button to Center Transport group (`+10s` adjacent).
   - Add 4-state A-B Looper button to Right Utility group (`Audio EQ` adjacent), wired to real-time position listener.

---

## 6. Verification Method

To verify these findings and any subsequent Phase 2 implementation independently:

### 6.1 Static Analysis
```powershell
cd d:\E-player\app
dart analyze
```
*Expected Result*: 0 errors, 0 warnings.

### 6.2 Unit & Interaction Tests
Run the unit test suite verifying gesture physics, volume boundaries, and keyboard shortcuts:
```powershell
cd d:\E-player\app
flutter test test/unit/cinematic_gesture_engine_test.dart
flutter test test/unit/desktop_keyboard_handler_test.dart
```

### 6.3 E2E Integration Suite
```powershell
cd d:\E-player\app
flutter test test/e2e/phase1_e2e_test.dart
```

### 6.4 Phase 2 Invalidation Conditions
The design is invalidated if:
1. `_player.setVolume(250.0)` is clamped by libmpv to $\le 130.0$ because `volume-max` was omitted.
2. Gesture swipe causes a discontinuous step or jarring volume jump at the 100% boundary.
3. LinearProgressIndicator in volume gesture feedback saturates at 100% instead of scaling to 300%.
4. Pressing `e` while playing continues playback instead of automatically pausing on the first frame step.
5. Pressing `c` introduces geometric stretch distortion rather than aspect cropping.
