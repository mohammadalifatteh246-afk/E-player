# Worker Dispatch: Milestone 1 — Volume Amplification to 300% & 3-Color Safety Indicator

You are the Worker (`teamwork_worker`) for Milestone 1 of the E-Player Phase 2 project.
Your state folder: `d:\E-player\.agents\teamwork\worker_m1_1`
Working directory: `d:\E-player\app`
Parent Sub-Orchestrator conversation ID: 64e09fc9-3d69-4af4-a53c-50f335bc9ff5

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Mandatory Inputs to Read
1. `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (Lines 85–151, Requirement R1)
2. `d:\E-player\PROJECT.md` (Milestone 1, Interface Contracts)
3. `d:\E-player\.agents\teamwork\sub_orch_m1\SCOPE.md`
4. Survey Reports:
   - `d:\E-player\.agents\teamwork\explorer_survey_1\handoff.md` (CYPHER: mpv property interop & volume-max)
   - `d:\E-player\.agents\teamwork\explorer_survey_2\handoff.md` (AURA: gesture physics, 3-color indicator, keyboard handler)
   - `d:\E-player\.agents\teamwork\explorer_survey_3\handoff.md` (KRONOS/FORGE: mock patterns & test harness)

## Exclusive File Ownership
You own and may modify ONLY these files:
- `lib/features/player/ui/cinematic_gesture_engine.dart`
- `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
- `lib/features/player/ui/player_screen.dart`
- `lib/features/player/ui/gesture_models.dart`
- `test/unit/volume_overamp_test.dart`
- `test/unit/desktop_keyboard_handler_test.dart`
- `test/unit/cinematic_gesture_engine_test.dart`

DO NOT touch any files under `lib/features/settings/` or `lib/features/video_effects/`.

## Objectives & Detailed Requirements

### 1. libmpv `volume-max` Configuration
In `lib/features/player/ui/player_screen.dart` (around line 220):
Immediately following `_player = Player(configuration: const PlayerConfiguration(libass: true));`:
```dart
try {
  (_player.platform as dynamic).setProperty('volume-max', '300.0');
} catch (e) {
  debugPrint('[PlayerScreen] Failed to set volume-max: $e');
}
```

### 2. CinematicGestureEngine Volume Scaling
In `lib/features/player/ui/cinematic_gesture_engine.dart`:
- Change line 179: `_volume = initialVolume.clamp(0.0, 300.0);`
- Change line 200: `void setExternalVolume(double value) { _volume = value.clamp(0.0, 300.0); }`
- Update lines 406–423 (`_handleVolumeAdjust`):
  Use the uniform extended gain model ($K = 150.0$) ensuring 2 full 70% viewport swipes cover 0% to 300% smoothly with zero jump discontinuities:
  ```dart
  final effectiveHeight = viewportSize.height > 0 ? viewportSize.height : 600.0;
  final delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 150.0;
  _volume = (_volume + delta).clamp(0.0, 300.0);
  onVolumeChanged?.call(_volume);
  ```
- In `lib/features/player/ui/gesture_models.dart`:
  Update volume documentation from `0.0 to 100.0` to `0.0 to 300.0`.

### 3. DesktopKeyboardHandler Volume Shortcuts
In `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`:
- Update `onShowOsd` callback signature to accept optional `Color? color`:
  `final Function(String message, IconData icon, [Color? color]) onShowOsd;`
- Update Arrow Up:
  ```dart
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
  ```
- Update Arrow Down:
  ```dart
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

### 4. 3-Color Safety Indicator (HUD & OSD)
Implement `VolumeSafetyColors` class (place in `lib/features/player/ui/player_screen.dart` or export cleanly):
```dart
class VolumeSafetyColors {
  /// Zone 1: Nominal Unity Gain (0% – 100%)
  static const Color green = Color(0xFF22C55E); // #22C55E
  /// Zone 2: Software Pre-Amp Boost (101% – 200%)
  static const Color amber = Color(0xFFF59E0B); // #F59E0B
  /// Zone 3: High Over-Amplification Warning (201% – 300%)
  static const Color softRed = Color(0xFFEF4444); // #EF4444

  static Color resolve(double volume) {
    if (volume <= 100.0) return green;
    if (volume <= 200.0) return amber;
    return softRed;
  }

  static Color resolveGlow(double volume) {
    return resolve(volume).withValues(alpha: 0.4);
  }
}
```
Apply dynamically:
- Gesture overlay card in `player_screen.dart` (`_buildGestureFeedbackContent`):
  - LinearProgressIndicator normalized over 300%:
    `value: (event.value / 300.0).clamp(0.0, 1.0)`
  - ValueColor: `AlwaysStoppedAnimation<Color>(VolumeSafetyColors.resolve(event.value))`
  - Icon color & Text color: `VolumeSafetyColors.resolve(event.value)`
  - Card border color: `VolumeSafetyColors.resolve(event.value).withValues(alpha: 0.8)`
- OSD Feedback Pill Overlay (`_showFeedbackMessage` or glassmorphic pill):
  - Support the passed dynamic `Color? color` for icon and border/glow tint when volume changes.
- HUD Volume Slider:
  - If a volume slider exists in HUD or player screen, ensure max is 300.0 and active color uses `VolumeSafetyColors.resolve(volume)`.

### 5. Automated Unit Tests
Create `test/unit/volume_overamp_test.dart` and update existing tests in `test/unit/desktop_keyboard_handler_test.dart` and `test/unit/cinematic_gesture_engine_test.dart`:
- Test volume scaling across 0% to 300%
- Test boundary clamping at 0.0% and 300.0%
- Test 5% increments
- Test 3-color safety indicator thresholds:
  - volume <= 100.0 -> Green (#22C55E)
  - 100.0 < volume <= 200.0 -> Amber (#F59E0B)
  - 200.0 < volume <= 300.0 -> Soft Red (#EF4444)
- Test `CinematicGestureEngine` volume gesture calculations and clamping
- Test `DesktopKeyboardHandler` Arrow Up/Down events with FakePlayer

### 6. Verification
Run:
```powershell
flutter test test/unit/volume_overamp_test.dart
flutter test test/unit/desktop_keyboard_handler_test.dart
flutter test test/unit/cinematic_gesture_engine_test.dart
dart analyze
```
All tests must pass and `dart analyze` must show 0 errors and 0 warnings.

## Output
Write your full report to `d:\E-player\.agents\teamwork\worker_m1_1\handoff.md` and message the parent sub-orchestrator.


## 2026-11-11T06:26:49Z
Notification received from parent Sub-Orchestrator (64e09fc9-3d69-4af4-a53c-50f335bc9ff5):
You are the Worker for Milestone 1 (Volume Amplification to 300% & 3-Color Safety Indicator) of E-Player Phase 2.
State folder: d:\E-player\.agents\teamwork\worker_m1_1
Working directory: d:\E-player\app
Your parent Sub-Orchestrator conversation ID: 64e09fc9-3d69-4af4-a53c-50f335bc9ff5
MANDATORY INTEGRITY WARNING: DO NOT CHEAT.
