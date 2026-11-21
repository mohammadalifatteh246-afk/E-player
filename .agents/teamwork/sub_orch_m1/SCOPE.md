# Scope: Milestone 1 — Volume Amplification to 300% & 3-Color Safety Indicator (Phase 2)

## Objective
Implement Requirement R1: Volume Over-Amplification to 300% with smooth gesture physics, 5% desktop keyboard increments, and dynamic 3-color safety indicator (Green / Amber / Soft Red) across HUD, gesture overlay, and OSD pill in `d:\E-player\app`.

## Exclusive Write Ownership
The worker for this milestone owns and may modify ONLY these files:
- `lib/features/player/ui/cinematic_gesture_engine.dart` (Volume 0–300% physics, uniform extended gain K=150.0, zero jump discontinuity)
- `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` (Arrow Up/Down 0–300% in 5% increments, passing dynamic safety color to OSD)
- `lib/features/player/ui/player_screen.dart` (libmpv `volume-max: 300.0` initialization, VolumeSafetyColors class/integration, 3-color styling for gesture card, OSD pill, and HUD volume slider)
- `lib/features/player/ui/gesture_models.dart` (Documentation/ranges updated to 0.0–300.0 if applicable)
- `test/unit/volume_overamp_test.dart` (New unit test suite for volume scaling, boundary clamping, and safety colors)
- `test/unit/desktop_keyboard_handler_test.dart` (Update existing volume tests to cover 0–300% range and 5% steps)
- `test/unit/cinematic_gesture_engine_test.dart` (Update existing volume gesture tests for 0–300% range)

DO NOT modify:
- `lib/features/settings/*` (Owned by M3)
- `lib/features/video_effects/*` (Owned by M3)
- Test files owned by other milestones.

## Authoritative Inputs
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (lines 85–151, Requirement R1)
- `d:\E-player\PROJECT.md` (Milestone 1, Interface Contracts)
- `d:\E-player\.agents\teamwork\sub_orch_m1\DISPATCH.md`
- Survey Handoff (CYPHER): `d:\E-player\.agents\teamwork\explorer_survey_1\handoff.md`
- Survey Handoff (AURA): `d:\E-player\.agents\teamwork\explorer_survey_2\handoff.md`
- Survey Handoff (KRONOS/FORGE): `d:\E-player\.agents\teamwork\explorer_survey_3\handoff.md`

## Specifications to Implement

### 1. libmpv `volume-max` Configuration
In `lib/features/player/ui/player_screen.dart` (around line 220–225):
Immediately following `_player = Player(...)`:
```dart
try {
  (_player.platform as dynamic).setProperty('volume-max', '300.0');
} catch (e) {
  debugPrint('[PlayerScreen] Failed to set volume-max: $e');
}
```

### 2. CinematicGestureEngine Volume Scaling
In `lib/features/player/ui/cinematic_gesture_engine.dart`:
- Update `_volume = initialVolume.clamp(0.0, 300.0);` (line 179)
- Update `setExternalVolume(double value)`: `_volume = value.clamp(0.0, 300.0);` (line 200)
- In `_handleVolumeAdjust`:
  ```dart
  final effectiveHeight = viewportSize.height > 0 ? viewportSize.height : 600.0;
  // Uniform extended gain K = 150.0 enables 2 full 70% viewport swipes to cover 0% to 300%
  final delta = (-details.focalPointDelta.dy / (effectiveHeight * 0.7)) * 150.0;
  _volume = (_volume + delta).clamp(0.0, 300.0);
  onVolumeChanged?.call(_volume);
  ```
- Ensure zero jump discontinuities across the 100% boundary.

### 3. DesktopKeyboardHandler Volume Shortcuts
In `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`:
- Update `onShowOsd` callback signature to accept optional `Color? color`:
  `final Function(String message, IconData icon, [Color? color]) onShowOsd;`
- Update Arrow Up shortcut:
  ```dart
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
  ```
- Update Arrow Down shortcut:
  ```dart
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
  ```

### 4. 3-Color Safety Indicator (HUD & OSD)
Implement `VolumeSafetyColors`:
```dart
class VolumeSafetyColors {
  static const Color green = Color(0xFF22C55E);   // 0% - 100% (nominal unity gain)
  static const Color amber = Color(0xFFF59E0B);   // 101% - 200% (software pre-amp boost)
  static const Color softRed = Color(0xFFEF4444); // 201% - 300% (high over-amp warning)

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
  - LinearProgressIndicator value normalized to 300.0: `(event.value / 300.0).clamp(0.0, 1.0)`
  - Value color set to `VolumeSafetyColors.resolve(event.value)`
  - Icon and text styled with `safetyColor`
  - Container border tint: `VolumeSafetyColors.resolve(event.value).withValues(alpha: 0.8)`
- OSD feedback pill overlay:
  - Update `_showFeedbackMessage` or OSD pill to accept and display the dynamic `Color? color`
- HUD volume slider / controls:
  - If HUD has a volume slider or volume display, apply `VolumeSafetyColors.resolve(volume)` to active track and thumb.

### 5. Automated Unit Tests
Create `test/unit/volume_overamp_test.dart` and update existing tests:
- Test 0% to 300% volume adjustment in 5% increments
- Test boundary clamping at 0.0% and 300.0%
- Test `VolumeSafetyColors.resolve` threshold accuracy:
  - 0.0 -> Green
  - 100.0 -> Green
  - 100.1 -> Amber
  - 200.0 -> Amber
  - 200.1 -> Soft Red
  - 300.0 -> Soft Red
- Test `CinematicGestureEngine` volume calculation and clamping to 300.0
- Test DesktopKeyboardHandler Arrow Up/Down volume events

### 6. Static Analysis
`dart analyze` must pass with zero errors and zero warnings.

## Completion Criteria
- All 6 objectives above implemented without placeholders or TODOs.
- `dart analyze` passes with 0 errors and 0 warnings.
- `flutter test test/unit/volume_overamp_test.dart` passes.
- All existing tests in `test/unit/desktop_keyboard_handler_test.dart` and `test/unit/cinematic_gesture_engine_test.dart` pass.
- Forensic Auditor reports CLEAN.
