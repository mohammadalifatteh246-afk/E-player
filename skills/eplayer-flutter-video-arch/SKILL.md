---
name: eplayer-flutter-video-arch
description: "Orchestrate Flutter video player architecture, gesture physics, HUD controls, and reactive UI components."
version: "1.0.0"
author: "Hermes Agent"
license: "MIT"
platforms: ["windows", "linux", "macos", "android", "ios"]
metadata:
  hermes:
    tags: ["eplayer", "flutter", "dart", "media-kit", "ui-architecture", "gestures"]
---

# E-Player Flutter Video Architecture & UI Operations

## When to Use
- Designing, modifying, or debugging the primary video presentation surface in `lib/features/player/ui/player_screen.dart`.
- Tuning touch, swipe, or drag gesture physics within `CinematicGestureEngine` (`lib/features/player/ui/cinematic_gesture_engine.dart`).
- Updating or expanding cross-platform desktop keyboard navigation and modifier seek physics in `DesktopKeyboardHandler` (`lib/features/player/ui/widgets/desktop_keyboard_handler.dart`).
- Constructing or refining glassmorphic modal overlays (e.g., `AudioStudioSheet`, `VideoEffectsSheet`, `SubtitleSettingsSheet`).
- Managing reactive state propagation through `provider` (`SettingsProvider`, `LibraryProvider`, `MediaGroupService`) while preventing wasteful UI re-renders.
- Ensuring zero-placeholder, zero-TODO UI compliance with clean static analysis (`flutter analyze`).

## Quick Reference Table

| Target / Subsystem | Action / Tool Command | Expected Outcome |
| :--- | :--- | :--- |
| `PlayerScreen` Lifecycle | Inspect `lib/features/player/ui/player_screen.dart` | Confirms `Player` controller initialization with `libass: true` and `volume-max: 300.0` |
| Volume Over-Amplification | Tune `CinematicGestureEngine.dart` ($K=150.0$) | Smooth swipe scaling 0%–300% without gain discontinuities |
| Safety Color Indicator | Verify `VolumeSafetyColors` in `gesture_models.dart` | Green (`#22C55E` 0–100%), Amber (`#F59E0B` 101–200%), Soft Red (`#EF4444` 201–300%) |
| Desktop Shortcuts | Update `desktop_keyboard_handler.dart` | Maps universal shortcuts (`Space`, `f`/`F11`, `m`, `b`, `v`, `a`, `c`, `e`, `h`/`g`, `k`/`j`, `+`/`-`, `[`/`]`, `=`, Arrows) |
| 4-Tier Seek Physics | Modifier jumps in `desktop_keyboard_handler.dart` | Shift (3s), Alt (10s), Ctrl (60s), Ctrl+Alt (300s) |
| Static Analysis Check | `flutter analyze lib/features/player/` | Zero errors, zero warnings across all player UI components |
| Automated UI Tests | `flutter test test/unit/phase1_shortcuts_test.dart` | 100% test pass rate covering HUD, shortcuts, and gestures |

## Core Subsystems & Technical Specifications

### 1. PlayerScreen Lifecycle & Presentation Surface
`PlayerScreen` serves as the primary rendering and interaction hub. It integrates `media_kit: ^1.2.6` and `media_kit_video: ^2.0.1`:
- **Controller Initialization**: Instantiates `Player(configuration: const PlayerConfiguration(libass: true, bufferSize: 32 * 1024 * 1024))`.
- **Property Binding**: Immediately configures libmpv `volume-max` to `300.0` to permit high-gain amplification while configuring soft-clipping safety guards.
- **HUD Auto-Hide Lifecycle**: A non-blocking 3-second inactivity decay timer monitors cursor movement and gesture interactions. Any user activity resets the timer; timeout initiates an animated opacity fade ($300\text{ms}$ curve `Curves.easeInOut`).
- **OSD Notification Pill**: A floating glassmorphic container positioned at the top-center of the viewport provides real-time feedback for track changes, delay adjustments, volume levels, and playback speed.

### 2. CinematicGestureEngine Physics & Extended Volume Scaling
Touch and pointer gestures are processed through `CinematicGestureEngine` with distinct screen partition zones:
- **Left Vertical Zone (0.0 <= X < 0.35)**: Brightness scaling from `0.0` to `1.0` via screen brightness bridge.
- **Center Zone (0.35 <= X <= 0.65)**: Single-tap toggles HUD visibility; double-tap executes play/pause toggle.
- **Right Vertical Zone (0.65 < X <= 1.0)**: Smooth volume over-amplification across `0%` to `300%`.
  - The volume update formula uses a normalized sensitivity constant $K = 150.0$:
    $$\Delta V = -\frac{\Delta Y}{\text{ScreenHeight}} \times K$$
    $$V_{\text{new}} = \text{clamp}(V_{\text{current}} + \Delta V, 0.0, 300.0)$$
  - This continuous formulation prevents step-discontinuities at the unity gain threshold ($100\%$).
- **Horizontal Swipe Zone**: Scrubbing physics with dynamic friction damping:
  $$\Delta T = \text{sign}(\Delta X) \times \left(\frac{|\Delta X|}{\text{ScreenWidth}}\right)^{1.2} \times T_{\text{duration}} \times 0.25$$
- **Volume Safety Threshold Colors**:
  - `0%` to `100%`: Standard Unity Gain — Neon Green (`Color(0xFF22C55E)`).
  - `101%` to `200%`: Software Preamp Boost — Amber Gold (`Color(0xFFF59E0B)`).
  - `201%` to `300%`: High Over-Amplification Warning — Crimson Red (`Color(0xFFEF4444)`).

### 3. DesktopKeyboardHandler & 4-Tier Seek Physics
Universal desktop keyboard navigation intercepts raw hardware key events before OS defaults:
- **Transport & Display**:
  - `LogicalKeyboardKey.space` $\rightarrow$ Play / Pause toggle.
  - `LogicalKeyboardKey.keyF` / `LogicalKeyboardKey.f11` $\rightarrow$ Fullscreen toggle.
  - `LogicalKeyboardKey.keyM` $\rightarrow$ Mute / Unmute toggle.
  - `LogicalKeyboardKey.keyB` $\rightarrow$ Cycle audio streams with OSD feedback.
  - `LogicalKeyboardKey.keyV` $\rightarrow$ Cycle subtitle streams with OSD feedback.
  - `LogicalKeyboardKey.keyA` $\rightarrow$ Cycle video aspect ratios (`16:9`, `4:3`, `Fill`, `Fit`).
  - `LogicalKeyboardKey.keyC` $\rightarrow$ Cycle aspect crops (`16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `Reset`).
  - `LogicalKeyboardKey.keyE` $\rightarrow$ Single-frame stepping via libmpv `frame-step`.
- **Delay & Speed Nudging**:
  - `LogicalKeyboardKey.keyH` / `keyG` $\rightarrow$ Subtitle delay nudge ($\pm 50\text{ms}$).
  - `LogicalKeyboardKey.keyK` / `keyJ` $\rightarrow$ Audio delay nudge ($\pm 50\text{ms}$).
  - `+` / `-` $\rightarrow$ Coarse speed adjustment ($\pm 0.25\text{x}$).
  - `]` / `[` $\rightarrow$ Fine speed adjustment ($\pm 0.1\text{x}$).
  - `=` $\rightarrow$ Reset speed to unity ($1.0\text{x}$).
- **4-Tier Precision Jump Intervals (Seek Physics)**:
  - `Shift + ArrowLeft / ArrowRight`: **$3\text{s}$ Jump** (Dialogue clarification).
  - `Alt + ArrowLeft / ArrowRight`: **$10\text{s}$ Jump** (Sentence skip).
  - `Control + ArrowLeft / ArrowRight`: **$60\text{s}$ Jump** (Intro / recap skip).
  - `Control + Alt + ArrowLeft / ArrowRight`: **$300\text{s}$ Jump** ($5\text{ min}$ scene skip).
  - Standard `ArrowLeft / ArrowRight` (no modifiers): **$10\text{s}$ Jump**.
  - `ArrowUp / ArrowDown`: Volume adjustment in $5\%$ steps across $0\%$ to $300\%$.

### 4. Glassmorphic Modal Architecture
All secondary controls reside in frosted glassmorphic bottom sheets using `BackdropFilter` with `ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0)` and dark acrylic surface tints (`Color(0xCC1E1E2E)`):
- **`AudioStudioSheet`**:
  - 10-Band Graphic Equalizer ($31\text{Hz}$, $62\text{Hz}$, $125\text{Hz}$, $250\text{Hz}$, $500\text{Hz}$, $1\text{kHz}$, $2\text{kHz}$, $4\text{kHz}$, $8\text{kHz}$, $16\text{kHz}$).
  - 20 Presets (including all 11 VLC canonical presets: Full Bass, Full Bass & Treble, Full Treble, Headphones, Large Hall, Live, Party, Reggae, Ska, Soft, Soft Rock).
  - Pre-Amplification slider ($-20\text{dB}$ to $+20\text{dB}$) mapped to software gain.
  - Audio Synchronization continuous slider ($-10.0\text{s}$ to $+10.0\text{s}$ in $50\text{ms}$ increments) with discrete nudge buttons ($-100\text{ms}$, $-50\text{ms}$, Reset, $+50\text{ms}$, $+100\text{ms}$).
- **`VideoEffectsSheet`**: Controls contrast, brightness, saturation, gamma, deinterlacing, and hardware rotation.
- **`SubtitleSettingsSheet`**: Subtitle track selection, font size, text encoding, subtitle delay slider, and secondary subtitle rendering.

### 5. Provider Reactive State Architecture
- Avoid monolithic state rebuilds by decoupling playback engine primitives from widget tree rebuilds.
- Utilize `context.select<T, R>()` or narrow `Selector<T, R>` widgets to subscribe only to specific state properties (e.g., subscribing to `isBuffering` rather than the entire `PlayerState`).
- Keep heavy compute and persistent state outside the build methods by delegating to `SettingsProvider` and `LibraryProvider`.

## Operational Workflows

### Workflow 1: Brainstorming Pre-Flight Gate for Video UI Modifications
Before writing any code or modifying existing Flutter UI components, the agent MUST execute the 5-step brainstorming process:

1. **Intent Discovery ("Look Before You Ask")**:
   - Inspect existing UI contracts in `lib/features/player/ui/` and test expectations in `test/unit/` or `test/e2e/`.
   - Identify whether the requirement impacts desktop shortcut handling, touch gestures, HUD overlay composition, or reactive state subscriptions.
2. **Explore 2–3 Architectural Approaches with Tradeoffs**:
   - *Example: Implementing Frame-Stepping Trigger*:
     - *Approach A (Direct UI Controller Call)*: Wire HUD button directly to `player.platform.command(['frame-step'])`. Fast, but risks out-of-sync UI pause state.
     - *Approach B (Centralized Playback Controller)*: Route via `PlaybackEnhancements.stepFrame(player)` which automatically checks `player.state.playing`, pauses first if needed, invokes `frame-step`, and broadcasts OSD. Decoupled, robust, and handles race conditions.
     - *Approach C (Keyboard-Only Binding)*: Bind strictly within `DesktopKeyboardHandler`. Fails mobile and mouse-only usability.
   - *Recommendation*: Approach B provides complete behavioral parity with VLC while maintaining cross-platform UX integrity.
3. **Structured Design Documentation**:
   - Document the selected approach, affected files, widget hierarchy changes, and state models.
4. **Builder Check & Self-Review**:
   - Review widget tree depth, verify absence of hardcoded values, and ensure contrast ratios satisfy WCAG AA.
5. **Hard Gate**:
   - Do NOT edit any Dart files until the design rationale is recorded and verified.

### Workflow 2: Implementing or Modifying PlayerScreen HUD & OSD Controls
1. Open `lib/features/player/ui/player_screen.dart` and locate the HUD stack layout.
2. Ensure HUD widgets are wrapped in an `AnimatedOpacity` driven by `_isHudVisible` state.
3. Position the OSD notification pill using `Align(alignment: Alignment.topCenter)` wrapped in `IgnorePointer` to prevent blocking tap events.
4. Bind action triggers to the dedicated controllers (`ABRepeatController`, `AspectCropController`, etc.).
5. Verify that tap handlers reset the 3-second inactivity auto-hide timer.
6. Run `flutter analyze lib/features/player/ui/player_screen.dart` to verify zero warnings.

### Workflow 3: Tuning Cinematic Gesture Engine Physics
1. Open `lib/features/player/ui/cinematic_gesture_engine.dart`.
2. Inspect horizontal split ratios (`leftBound = width * 0.35`, `rightBound = width * 0.65`).
3. For volume swipe gestures, verify the gain factor $K = 150.0$ and clamp range `[0.0, 300.0]`.
4. Check that `VolumeSafetyColors.getColorForVolume(volume)` correctly returns Green (`0..100`), Amber (`101..200`), or Soft Red (`201..300`).
5. Run the gesture unit test:
   ```bash
   flutter test test/unit/phase2_unit_test.dart --plain-name "Volume over-amplification gesture physics"
   ```

### Workflow 4: Extending Desktop Keyboard Handler & Modifiers
1. Open `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`.
2. Inspect the `KeyEvent` dispatcher method `handleKeyEvent(KeyEvent event)`.
3. Check modifier states via `HardwareKeyboard.instance.isShiftPressed`, `isAltPressed`, and `isControlPressed`.
4. Route key events to their respective actions and trigger OSD notifications for visual confirmation.
5. Verify that consumed events return `KeyEventResult.handled` to prevent bubbling to parent OS listeners.
6. Execute shortcut verification tests:
   ```bash
   flutter test test/unit/phase1_shortcuts_test.dart
   ```

### Workflow 5: Adding Glassmorphic Bottom Sheets with Reactive Providers
1. Create or open the target sheet component in `lib/features/player/ui/`.
2. Wrap the root container in `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(20)))`.
3. Apply `BackdropFilter` with `ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0)`.
4. Use `Consumer<SettingsProvider>` to read and mutate persistent preferences.
5. Provide dedicated close buttons and backdrop tap dismiss gestures.
6. Verify smooth frame rates (60fps) during sheet entrance and exit animations.

## Common Mistakes & Prohibitions
- **Prohibited: Calling `setState()` at the Root of `PlayerScreen` on Every Position Update**: Position updates fire every $20\text{ms}$–$50\text{ms}$. Rebuilding the entire tree causes catastrophic frame drops. Use localized `StreamBuilder` or narrow `Selector` on playback position.
- **Prohibited: Monolithic Touch Targets**: Never place gesture detectors that swallow all taps across the entire screen without passing pointer events to HUD controls.
- **Prohibited: Hardcoding Volume Colors**: Always use `VolumeSafetyColors` constants. Never hardcode ad-hoc hex values in UI widgets.
- **Prohibited: Unhandled Key Event Bubbling**: Forgetting to return `KeyEventResult.handled` causes shortcuts like `Space` or `ArrowDown` to trigger unintended scroll behavior in underlying scrollable views.
- **Prohibited: Dummy Mock Implementations**: Every HUD button, slider, and shortcut must bind to genuine `Player` properties or real database helpers. Zero placeholders permitted.
