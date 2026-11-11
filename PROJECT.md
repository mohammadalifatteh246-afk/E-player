# Project: E-Player Phase 2 Core UX & Playback Enhancements

## Architecture
- **Framework**: Flutter Desktop (Windows, macOS, Linux) and Mobile (Android, iOS) with Provider and MediaKit (`media_kit: ^1.2.6`).
- **Core Playback & Interaction Modules**:
  - `PlayerScreen` (`lib/features/player/ui/player_screen.dart`): Primary video surface, playback lifecycle orchestrator, HUD bottom toolbar with Center Transport and Right Utility groups, OSD notification pill, and real-time position stream listener.
  - `CinematicGestureEngine` (`lib/features/player/ui/cinematic_gesture_engine.dart`): Smooth multi-touch gesture engine; right-edge vertical swipe physics scaled across 0% to 300% volume with uniform extended gain ($K=150.0$), zero jump discontinuities, and boundary clamping $[0.0, 300.0]$.
  - `VolumeSafetyColors`: 3-color safety indicator:
    - 0% – 100%: Green (`#22C55E` / standard unity gain)
    - 101% – 200%: Amber (`#F59E0B` / software pre-amp boost)
    - 201% – 300%: Soft Red (`#EF4444` / high over-amplification warning)
  - `DesktopKeyboardHandler` (`lib/features/player/ui/widgets/desktop_keyboard_handler.dart`): Universal keyboard listener handling:
    - `Arrow Up / Down`: Volume adjustment across 0% to 300% in 5% increments with safety color OSD feedback.
    - `e`: Frame-by-frame stepping via libmpv `frame-step` command (auto-pauses if playing).
    - `c`: Aspect ratio crop cycling via mpv `vf` crop filter.
  - `ABRepeatController`: 4-state loop controller (`off` -> `pointA` -> `looping` -> `clear`) with concurrency-safe position listener and anti-thrashing debounce guard.
  - `VideoEffectsService` & `VideoEffectsConfig` (`lib/features/video_effects/`): Manages mpv `vf` filter graph, concatenating centered non-distorted crop filters (`16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `Reset`).
  - `SettingsProvider` (`lib/features/settings/domain/settings_provider.dart`) & `SettingsScreen` (`lib/features/settings/ui/settings_screen.dart`): Persists `networkCachingMs` (500–10,000ms, default 1,000ms) and `demuxerCacheMb` (16–128MB, default 32MB), bound to mpv properties `cache-secs`, `demuxer-max-bytes`, and `demuxer-max-back-bytes`.

## Code Layout
- `lib/features/player/ui/cinematic_gesture_engine.dart` — 0%–300% volume swipe gesture physics and clamping.
- `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` — Arrow Up/Down (0–300%), key `e` (frame-step), key `c` (aspect crop cycling).
- `lib/features/player/ui/player_screen.dart` — libmpv `volume-max: 300.0` initialization, 3-color safety indicator for HUD/OSD, frame-step HUD button, A-B loop HUD button & 4-state controller, crop cycling handler.
- `lib/features/video_effects/models/video_effects_config.dart` — Crop aspect ratio presets and mpv `vf` crop filter generation.
- `lib/features/settings/domain/settings_provider.dart` — `networkCachingMs` and `demuxerCacheMb` persistence.
- `lib/features/settings/ui/settings_screen.dart` — Network caching slider (500–10,000ms) and demuxer cache size selector (16–128MB).
- `test/unit/phase2_unit_test.dart` — Unit tests for volume 0–300%, frame-step, A-B repeat loop controller, crop filters, and caching settings.
- `test/e2e/phase2_e2e_test.dart` — Comprehensive 4-tier opaque-box E2E test suite for all Phase 2 capabilities.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | libmpv volume-max 300% | Configure libmpv `volume-max` to 300.0 on player init | M1 | R1 |
| 2 | Gesture Volume 0–300% | Smooth right-edge vertical swipe scaling 0% to 300% in CinematicGestureEngine | M1 | R1 |
| 3 | Desktop Volume 0–300% | Arrow Up/Down volume adjustment in 5% increments across 0% to 300% in DesktopKeyboardHandler | M1 | R1 |
| 4 | 3-Color Safety Indicator | Green (0–100%), Amber (101–200%), Soft Red (201–300%) in HUD and OSD | M1 | R1 |
| 5 | Frame Stepping on 'e' Key | Hotkey 'e' advances playback by 1 frame via mpv `frame-step` | M2 | R2 |
| 6 | Frame Stepping HUD Button | HUD action button advances playback by 1 frame | M2 | R2 |
| 7 | Frame Stepping Auto-Pause | Automatically pause playback upon first activation if currently playing | M2 | R2 |
| 8 | 4-State A-B Loop Controller | Controller states: Off -> Mark Point A -> Mark Point B & Loop -> Clear | M2 | R3 |
| 9 | A-B Real-Time Position Seeker | Position listener seeks back to Point A when Point B is reached with anti-thrashing guard | M2 | R3 |
| 10 | A-B Loop HUD Action Button | Dedicated HUD button with dynamic icon, tooltip, and state transitions | M2 | R3 |
| 11 | Aspect Ratio Crop Cycling on 'c' | Hotkey 'c' cycles non-distorted crop ratios: 16:9, 16:10, 4:3, 1.85:1, 2.35:1, Reset | M3 | R4 |
| 12 | mpv Crop Video Filter (`vf`) | Apply non-distorted centered crop filter strings via mpv `vf` | M3 | R4 |
| 13 | Network Caching Buffer Slider | Slider (500ms to 10,000ms, default 1,000ms) mapped to mpv `cache-secs` | M3 | R5 |
| 14 | Demuxer Cache Size Selector | Selector (16MB to 128MB) mapped to mpv `demuxer-max-bytes` and `bufferSize` | M3 | R5 |
| 15 | Settings UI & Persistence | Persist network caching and demuxer cache size in SettingsProvider and SettingsScreen | M3 | R5 |
| 16 | Phase 2 Opaque-Box E2E Test Suite | Comprehensive 4-tier automated test suite in `app/test` | M4 | R6, Dual Track |
| 17 | Static Analysis Cleanliness | `flutter analyze` / `dart analyze` passes with zero errors and zero warnings | M5 | R6 |
| 18 | Adversarial Hardening & Audit | Tier 5 challenger adversarial tests + independent forensic integrity audit | M5 | R6 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Volume Amplification to 300% & 3-Color Safety Indicator | `player_screen.dart`, `cinematic_gesture_engine.dart`, `desktop_keyboard_handler.dart` | none | IN_PROGRESS |
| M2 | Frame-by-Frame Stepping & A-B Repeat Looper | `desktop_keyboard_handler.dart`, `player_screen.dart` | M1 | PLANNED |
| M3 | Aspect Ratio Crop Cycling & Buffer Caching Settings | `desktop_keyboard_handler.dart`, `player_screen.dart`, `video_effects_config.dart`, `settings_provider.dart`, `settings_screen.dart` | none | PLANNED |
| M4 | Phase 2 E2E Test Suite (Dual Track) | `test/e2e/phase2_e2e_test.dart`, `TEST_READY.md` | none | IN_PROGRESS |
| M5 | Final Verification, Adversarial Hardening & Forensic Audit | Full test execution, `dart analyze`, Challenger, Auditor | M1, M2, M3, M4 | PLANNED |

## Interface Contracts

### 1. Volume 300% & 3-Color Safety Indicator
```dart
class VolumeSafetyColors {
  static const Color green = Color(0xFF22C55E);   // 0% - 100%
  static const Color amber = Color(0xFFF59E0B);   // 101% - 200%
  static const Color softRed = Color(0xFFEF4444); // 201% - 300%

  static Color resolve(double volume);
  static Color resolveGlow(double volume);
}
```

### 2. DesktopKeyboardHandler Phase 2 Callbacks
```dart
class DesktopKeyboardHandler extends StatefulWidget {
  // Existing Phase 1 callbacks...
  final VoidCallback? onStepFrame; // Key 'e'
  final VoidCallback? onCycleCrop; // Key 'c'
  final Function(String message, IconData icon, [Color? color]) onShowOsd;
}
```

### 3. A-B Repeat Controller Contract
```dart
enum ABRepeatState { off, pointA, looping, clear }

class ABRepeatController {
  ABRepeatState get state;
  Duration? get pointA;
  Duration? get pointB;

  void cycle(Duration currentPosition, {required VoidCallback onUpdate});
  void checkPosition(Duration currentPosition, {required Future<void> Function(Duration target) onSeek});
  void reset();
}
```

### 4. Buffer Caching Settings Contract
```dart
abstract class SettingsProviderInterface {
  int get networkCachingMs; // 500..10000 ms (default 1000)
  int get demuxerCacheMb;   // 16, 32, 64, 128 MB (default 32)
  Future<void> setNetworkCachingMs(int ms);
  Future<void> setDemuxerCacheMb(int mb);
}
```
