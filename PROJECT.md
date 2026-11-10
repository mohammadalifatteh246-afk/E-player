# Project: E-Player Phase 1 Production Deliverables

## Architecture
- **Framework**: Flutter Desktop (Windows, macOS, Linux) with Provider and MediaKit.
- **Core Player & UI Modules**:
  - `PlayerScreen` (`lib/features/player/ui/player_screen.dart`): Primary playback orchestrator, video surface, HUD overlay controls, and on-screen display (OSD) notification pill.
  - `DesktopKeyboardHandler` (`lib/features/player/ui/widgets/desktop_keyboard_handler.dart`): Dedicated autofocusing keyboard focus widget intercepting desktop `KeyEvent`s, normalizing modifiers (Ctrl/Cmd, Alt, Shift), dispatching 13 universal shortcut actions, and executing 4-tier precision seek physics.
  - `AudioStudioSheet` (`lib/features/player/ui/audio_studio_sheet.dart`): Glassmorphic bottom sheet containing:
    - Master Equalizer switch and preset picker with 20 presets (including 11 VLC presets).
    - Global Pre-Amplification slider (-20dB to +20dB).
    - 10-Band Graphic Equalizer Scale (60Hz–16kHz, ±20dB range).
    - Audio Delay Synchronization card (-10.0s to +10.0s with 50ms divisions and 5 discrete nudge buttons: -100ms, -50ms, Reset, +50ms, +100ms).
  - `AudioConfig` (`lib/features/player/ui/audio_studio_sheet.dart`): Single source of truth for audio DSP settings, compiling mpv `af` filter graph (`volume=volume=+XdB:precision=fixed`, `equalizer=...`, `bass=...`, etc.) and mpv `audio-delay` property.
  - Top Bar Audio Track Selector (`player_screen.dart`): HUD icon button opening glassmorphic stream picker modal, listing detected audio streams from `_player.stream.tracks.audio` and switching active stream via `_player.setAudioTrack`.

## Code Layout
- `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` — Desktop keyboard shortcut listener and 4-tier seek physics engine.
- `lib/features/player/ui/player_screen.dart` — Player screen integration, OSD visual pill feedback, top bar audio track selector button, and modal track switcher sheet.
- `lib/features/player/ui/audio_studio_sheet.dart` — `AudioConfig` with 11 VLC presets + preamp filter string generation + `AudioStudioSheet` with Preamp slider and `AudioDelaySyncCard`.
- `test/unit/desktop_keyboard_handler_test.dart` — Unit & widget tests verifying all 13 shortcuts and 4-tier seek physics with modifiers.
- `test/features/audio_studio_test.dart` — Unit tests verifying all 20 EQ presets, preamp filter synthesis, and audio delay conversions.
- `test/e2e/phase1_e2e_test.dart` — Comprehensive 4-tier opaque-box test suite covering requirements R1–R5 (2,075 lines, 68 tests).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Desktop Keyboard Shortcuts Infra | Universal cross-platform shortcuts (Space, f/F11, m, b, v, a, h/g, k/j, +/-, ]/[, =, Arrow Left/Right, Arrow Up/Down) | M1 | R1 |
| 2 | 4-Tier Precision Seek Physics | Modifier-based precision seek jumps: Shift (3s), Alt (10s), Ctrl (60s), Ctrl+Alt (300s) with boundary clamping | M1 | R2 |
| 3 | OSD Visual Feedback Pill | Glassmorphic floating HUD overlay providing instant visual feedback for track cycles, nudges, speed changes, and seeks | M1 | R1, R2 |
| 4 | Equalizer 11 VLC Presets Parity | 11 canonical VLC presets (Full Bass, Full Bass & Treble, Full Treble, Headphones, Large Hall, Live, Party, Reggae, Ska, Soft, Soft Rock) | M2 | R5 |
| 5 | Global Pre-Amplification Slider | -20dB to +20dB preamp slider mapped to mpv audio filter `volume=volume=+XdB:precision=fixed` | M2 | R5 |
| 6 | 10-Band Gain Scale Expansion | Expands EQ band slider scale to ±20dB to match VLC professional equalizer headroom | M2 | R5 |
| 7 | Audio Delay Synchronization Slider | -10.0s to +10.0s slider with 50ms divisions bound to mpv `audio-delay` | M3 | R3 |
| 8 | Audio Delay Nudge Buttons | 5 dedicated nudge buttons (-100ms, -50ms, Reset 0ms, +50ms, +100ms) for fine lip-sync adjustment | M3 | R3 |
| 9 | Dedicated Audio Track HUD Button | Audio track icon button in PlayerScreen HUD top bar between AI Studio and Subtitles | M3 | R4 |
| 10 | Glassmorphic Audio Track Modal | Modal bottom sheet listing detected streams from `_player.stream.tracks.audio` with active checkmark and instant switching | M3 | R4 |
| 11 | Audio Track Cycling via Hotkey 'b' | Hotkey 'b' cycles active audio track sequentially with OSD feedback | M1, M3 | R1, R4 |
| 12 | Opaque-Box E2E Test Suite | Comprehensive 4-tier test suite covering feature coverage, boundaries, combinations, and real-world scenarios | M4 | R6, Dual Track |
| 13 | Static Analysis & Zero Warning Invariant | `dart analyze` passes with 0 errors and 0 warnings | M5 | R6 |
| 14 | Adversarial Hardening & Forensic Audit | Tier 5 challenger coverage hardening + independent forensic integrity audit | M5 | R6 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Desktop Keyboard Shortcuts & 4-Tier Seek Physics | `desktop_keyboard_handler.dart`, `player_screen.dart` | none | DONE |
| M2 | Equalizer Parity & Pre-Amplification | `audio_studio_sheet.dart` (`AudioConfig`, `AudioStudioSheet`) | none | DONE |
| M3 | Audio Delay Synchronization & Track Selector Modal | `audio_studio_sheet.dart`, `player_screen.dart` | M1, M2 | IN_PROGRESS |
| M4 | E2E Testing Suite (Dual Track) | `test/e2e/phase1_e2e_test.dart`, `TEST_READY.md` | none | DONE |
| M5 | Final Verification, Hardening & Forensic Audit | `flutter test`, `dart analyze`, Challenger, Auditor | M1, M2, M3, M4 | PLANNED |

## Interface Contracts

### DesktopKeyboardHandler ↔ PlayerScreen
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

### AudioConfig ↔ mpv Engine
```dart
class AudioConfig {
  List<double> eq; // 10 bands [-20.0, 20.0]
  double preamp;   // [-20.0, 20.0] dB
  double audioDelay; // [-10000.0, 10000.0] ms

  void apply(Player? player);
  // Compiles: volume=volume=+X.XdB:precision=fixed,bass=...,equalizer=...
  // Sets: (player.platform as dynamic).setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3))
}
```

### PlayerScreen ↔ Audio Track Streams
```dart
// Stream listeners in PlayerScreenState:
_player.stream.tracks.listen((tracks) {
  _audioTracks = tracks.audio;
});
_player.stream.track.listen((track) {
  _selectedAudioTrack = track.audio;
});
// Action:
_player.setAudioTrack(track);
```
