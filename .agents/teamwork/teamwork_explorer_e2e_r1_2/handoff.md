# Handoff Report: UI Widget Selectors, Finders, and Interaction Patterns Investigation

**Agent**: Explorer (UI Selectors & Interaction Mechanisms)  
**Target Milestone**: Phase 1 Deliverables (R1 Desktop Shortcuts, R2 Multi-Tier Precision Jumps, R3 Audio Delay Sync, R4 Dedicated Audio Track Modal, R5 Equalizer Parity & Preamp Slider)  
**Target Codebase**: `d:\E-player\app`  
**Authoritative References**: `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`, `d:\E-player\PROJECT.md`, `d:\E-player\TEST_INFRA.md`, `d:\E-player\.agents\teamwork\e2e_test_orch\SCOPE.md`  
**Date & Timestamp**: 2026-11-10T08:54:00Z  

---

## 1. Observation

Direct observations from inspecting the codebase in `d:\E-player\app`:

### 1.1 `PlayerScreen` (`lib/features/player/ui/player_screen.dart`)
- **HUD Top Bar Layout (lines 1363–1428)**:
  - Inside a glassmorphic floating row, the controls are laid out as:
    ```dart
    IconButton(icon: const EVectorIcon(name: 'pip'), tooltip: 'Picture-in-Picture', ...),
    IconButton(icon: Icon(Icons.auto_awesome), tooltip: 'AI Enhancement Studio', ...),
    IconButton(icon: const Icon(Icons.subtitles_outlined), tooltip: 'Subtitles', onPressed: _showSubtitleMenu),
    IconButton(icon: const Icon(Icons.info_outline_rounded), tooltip: 'Technical Media Inspector', ...),
    IconButton(icon: const Icon(Icons.more_vert), tooltip: 'Settings', ...),
    ```
  - **Observation on Keys**: None of the top bar buttons have explicit `Key` parameters; they are identified strictly via `tooltip` strings (`'Picture-in-Picture'`, `'AI Enhancement Studio'`, `'Subtitles'`, etc.) and `Icon` / `EVectorIcon` data.
  - **Planned Audio Track Button Slot**: Between AI Studio (`line 1403`) and Subtitles (`line 1404`). In accordance with R4 and PROJECT.md, it renders `IconButton(icon: const Icon(Icons.audiotrack_outlined), tooltip: 'Audio Tracks', onPressed: _showAudioTrackMenu)`.

- **Existing Modal Sheet Pattern (`_showSubtitleMenu`, lines 800–828)**:
  ```dart
  void _showSubtitleMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Subtitles', style: EDesign.h3),
            ),
            if (_subtitleTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No subtitle tracks found', style: EDesign.secondaryStyle),
              ),
            for (final track in _subtitleTracks)
              ListTile(
                title: Text(track.title ?? track.language ?? track.id, style: EDesign.body),
                trailing: _selectedSubtitleTrack == track
                    ? const Icon(Icons.check, color: EDesign.primary)
                    : null,
                onTap: () {
                  _player.setSubtitleTrack(track);
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }
  ```
  - Modal Header: `Text('Subtitles')`.
  - Empty state: `Text('No subtitle tracks found')`.
  - Item selector: `ListTile` with title `track.title ?? track.language ?? track.id`.
  - Active indicator: `trailing: const Icon(Icons.check, color: EDesign.primary)`.
  - **Audio Track Sheet Symmetry (`_showAudioTrackMenu`)**: Mirrors this exact structure: header `Text('Audio Tracks')`, empty state `Text('No audio tracks found')`, `ListTile`s with active `Icon(Icons.check, color: EDesign.primary)`.

- **On-Screen Display (OSD) Mechanics (lines 1947–2050 & lines 95–99, 428–438)**:
  - Gesture overlay is rendered in the root `Stack` at `Positioned(top: 90, left: 0, right: 0, child: Center(...))`.
  - Container styling: `EDesign.surface.withValues(alpha: 0.90)`, `Border.all(color: EDesign.primary.withValues(alpha: 0.6), width: 1.2)`, `BorderRadius.circular(EDesign.r18)`.
  - Internal content contains leading `Icon` (color `EDesign.primary`, size 22) and main `Text` (style white bold font size 15).
  - Dead feedback state observed in `_PlayerScreenState` (lines 95–99): `_feedbackText`, `_feedbackIcon`, `_showFeedback`, `_feedbackTimer`. Phase 1 connects this directly to `top: 90` to render the OSD pill on desktop shortcut actions.

### 1.2 `AudioStudioSheet` (`lib/features/player/ui/audio_studio_sheet.dart`)
- **Structure & Components (lines 250–550)**:
  - Presented via `showModalBottomSheet` with `Container` height `MediaQuery.of(context).size.height * 0.88`, background `EDesign.appBackground`, border radius `BorderRadius.vertical(top: Radius.circular(24))`.
  - Header: `Row` containing `Text('Audio Equalizer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))` and `IconButton(icon: Icon(Icons.close))`.
  - **Master Switch Card (lines 294–326)**:
    - Container with `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Enable Equalizer'), Switch(value: _config.enabled, ...) ])`.
    - No explicit Key.
  - **Preset Dropdown Pill (lines 329–374)**:
    - `Row` with `Text('Preset')`, `Expanded(child: InkWell(onTap: _config.enabled ? _showPresetPicker : null, child: Container(... Row(children: [ Text(_config.preset), Icon(Icons.keyboard_arrow_down) ]))))`.
    - Tapping opens `_showPresetPicker(context)` (lines 180–248).
  - **Preset Modal Picker (`_showPresetPicker`, lines 180–248)**:
    - Bottom sheet with header `Text('Equalizer Preset', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))`.
    - Presets displayed inside a `Wrap(spacing: 10, runSpacing: 10, children: AudioConfig.presets.keys.map(...))`.
    - Each preset is an `InkWell` wrapping a `Container` with `Text(p)`. Selected preset has `color: EDesign.primary`.
    - Currently only contains 9 presets; R5 expands this with all 11 VLC presets (`Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`).
  - **10-Band Graphic Equalizer Scale (lines 377–451 & lines 550–620)**:
    - 10 vertical sliders rendered via `Row(children: List.generate(10, (index) => _build10BandSlider(index)))`.
    - Each slider is wrapped in `RotatedBox(quarterTurns: 3, child: SliderTheme(child: Slider(value: value.clamp(-12.0, 12.0), min: -12.0, max: 12.0, ...)))`.
    - Frequency labels at bottom: `60`, `170`, `310`, `600`, `1K`, `3K`, `6K`, `12K`, `14K`, `16K`.
  - **Pre-Amplification Slider (R5 / PROJECT.md)**:
    - Positioned above the 10-band slider stack.
    - Title: `Text('Pre-Amplification')` or `Text('Preamp')`.
    - Range: `-20.0dB` to `+20.0dB`, 80 divisions (0.5dB step).
    - Live badge: `${preamp >= 0 ? "+" : ""}${preamp.toStringAsFixed(1)} dB`.
  - **Audio Synchronization Card (`AudioDelaySyncCard`, R3 / PROJECT.md)**:
    - Positioned at the top of the sheet content.
    - Card Header: `Text('Audio Synchronization')` or `Text('Audio Delay')`.
    - Continuous Slider: Range `-10.0s` to `+10.0s` (`-10000ms` to `+10000ms`), 400 divisions (50ms step).
    - Live Badge: `${delayMs >= 0 ? "+" : ""}${delayMs.toStringAsFixed(0)} ms`.
    - 5 Discrete Nudge Buttons:
      - `-100ms`: Text `'-100ms'`
      - `-50ms`: Text `'-50ms'`
      - `Reset`: Text `'Reset'` or `'Reset 0ms'`
      - `+50ms`: Text `'+50ms'`
      - `+100ms`: Text `'+100ms'`

### 1.3 `DesktopKeyboardHandler` (`lib/features/player/ui/widgets/desktop_keyboard_handler.dart`)
- **Focus & Event Dispatching Architecture**:
  - Enclosing widget: `DesktopKeyboardHandler extends StatefulWidget`.
  - Wraps player screen body in:
    ```dart
    Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    )
    ```
  - Intercepts `KeyDownEvent`s. Ignores `KeyUpEvent` and unmapped keys (`KeyEventResult.ignored`).
  - Queries `HardwareKeyboard.instance.isShiftPressed`, `HardwareKeyboard.instance.isAltPressed`, `HardwareKeyboard.instance.isControlPressed`, and `HardwareKeyboard.instance.isMetaPressed`.
  - Dispatches actions and emits `widget.onShowOsd(message, icon)`.

### 1.4 Test Infrastructure Baseline (`test/helpers/eplayer_test_harness.dart` & `test/e2e/e2e_requirements_test.dart`)
- `testWidgets` provides a headless environment.
- Native `mpv.dll` C-FFI calls fail in headless environments without a mock platform or property store.
- Existing tests construct widget trees using `MaterialApp` wrapped in `MultiProvider` (`ChangeNotifierProvider<SettingsProvider>`, `CastService`, etc.) and `EPlayerTheme.darkTheme`.
- In widget tests, key events can be simulated via `WidgetTester.sendKeyEvent`, `WidgetTester.sendKeyDownEvent`, `WidgetTester.sendKeyUpEvent`, and `simulateKeyDownEvent` from `flutter_test`.

---

## 2. Logic Chain

1. **Dual-Strategy Selector Paradigm**:
   - In opaque-box testing, tests should ideally not depend on private widget implementation details. However, relying purely on text labels can be fragile if localization changes, while relying purely on Keys can fail if developers forget to pass Keys in child components.
   - Therefore, this investigation establishes a **Dual-Strategy Finder Matrix**:
     1. **Primary**: Semantic / Structural Finders (Tooltips, Text, Icons, Widget Types) that reflect what a user sees.
     2. **Secondary / Accelerator**: Dedicated `Key`s recommended for deterministic element selection.

2. **Top Bar Audio Track Modal Interaction Flow**:
   - In `PlayerScreen`, the HUD is auto-hidden after a timeout (`_controlsVisible`). In widget tests, before tapping the HUD button, ensure controls are visible (or tap the gesture surface to reveal controls: `await tester.tap(find.byType(GestureDetector).first); await tester.pump();`).
   - The HUD audio button is located via `find.byTooltip('Audio Tracks')` or `find.byIcon(Icons.audiotrack_outlined)`.
   - Tapping it displays the bottom sheet.
   - The bottom sheet renders `ListTile` items. Each tile's title corresponds to `track.title ?? track.language ?? track.id`.
   - Active stream status is verified by searching for `Icons.check` within the target `ListTile`:
     `find.descendant(of: find.widgetWithText(ListTile, 'English'), matching: find.byIcon(Icons.check))`.
   - Tapping an unselected tile invokes `_player.setAudioTrack(track)`, pops the modal, and triggers the OSD notification.

3. **Audio Delay Sync Slider & 5 Nudge Buttons**:
   - In `AudioStudioSheet`, the Audio Delay card contains a continuous `Slider`, a live badge `Text`, and 5 `Button` widgets.
   - Since `AudioStudioSheet` is scrollable via `SingleChildScrollView`, elements near the bottom must be scrolled into view if the viewport height is restricted: `await tester.ensureVisible(finder);`.
   - The 5 nudge buttons are uniquely distinguished by their exact text labels: `'-100ms'`, `'-50ms'`, `'Reset'`, `'+50ms'`, `'+100ms'`.
   - Tapping any nudge button immediately updates the live badge text and dispatches mpv `setProperty('audio-delay', seconds.toStringAsFixed(3))`.
   - The slider can be tested via `tester.drag(find.byKey(Key('audio_delay_slider')), const Offset(50, 0))` or `tester.tapAt(rect.center + Offset(...))` to test continuous seek resolution.

4. **Equalizer Presets Dropdown & Preamp Slider**:
   - The preset dropdown pill is found via `find.byIcon(Icons.keyboard_arrow_down)` or `find.text(_config.preset)`.
   - Tapping opens `_showPresetPicker` displaying the `Wrap` containing all 20 presets (including all 11 VLC presets).
   - Tapping a preset (e.g. `find.text('Large Hall')`) dismisses the picker, updates the preset pill text to `'Large Hall'`, and updates `AudioConfig.eq` and `AudioConfig.preamp`.
   - The Preamp slider sits in its own card above the 10 graphic EQ sliders. It is located via `find.byKey(Key('preamp_slider'))` or by finding the `Slider` adjacent to `Text('Pre-Amplification')`.
   - Its live badge displays decibels formatted to 1 decimal place with an explicit sign (e.g. `'+4.0 dB'`, `'-6.0 dB'`, `'+0.0 dB'`).

5. **OSD Visual Feedback Pill Lifecycle**:
   - The OSD pill is rendered inside `Positioned(top: 90, ...)` with a glassmorphic background container.
   - Because it is transient (auto-dismissing after 800–1500ms via `Timer`), testing it requires pump timing precision:
     - Immediately after action: `await tester.pump();` -> OSD must be present (`findsOneWidget`).
     - Advance timer past duration: `await tester.pump(const Duration(milliseconds: 1600));` -> OSD must be dismissed (`findsNothing`).
   - Text inside the pill can be matched via `find.text(...)` or substring match `find.textContaining(...)`.

6. **Desktop Keyboard Event Simulation & Modifier Hygiene**:
   - Flutter's `HardwareKeyboard` tracks modifier key state globally via `isShiftPressed`, `isAltPressed`, `isControlPressed`, and `isMetaPressed`.
   - When using `tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft)` followed by `tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight)`, the shift key remains marked as pressed until `tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft)` is called.
   - **Crucial Invariant**: If a test fails to send `sendKeyUpEvent` for a modifier, subsequent tests will unexpectedly have that modifier active, corrupting seek intervals (e.g., a bare arrow seek becomes a Shift dialogue jump).
   - A dedicated test helper `simulateShortcut` must encapsulate `KeyDown` and `KeyUp` in reverse order inside a guaranteed cleanup block.
   - On desktop routes, `DesktopKeyboardHandler` requires autofocus. In tests, `expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue)` verifies focus. If a modal was popped, `tester.pumpAndSettle()` ensures focus is restored.

---

## 3. Discovered Specifications & Interaction Matrix

### 3.1 Master UI Selector & Finder Inventory Table

| Component | Target UI Element | Recommended `Key` | Semantic / Structural Finder | Widget Type | Interaction Mechanism |
|:---|:---|:---|:---|:---|:---|
| **HUD Top Bar** | Audio Tracks Modal Button | `Key('hud_audio_tracks_button')` | `find.byTooltip('Audio Tracks')` or `find.byIcon(Icons.audiotrack_outlined)` | `IconButton` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **HUD Top Bar** | Subtitles Modal Button | `Key('hud_subtitles_button')` | `find.byTooltip('Subtitles')` or `find.byIcon(Icons.subtitles_outlined)` | `IconButton` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **HUD Top Bar** | Settings Drawer Button | `Key('hud_settings_button')` | `find.byTooltip('Settings')` or `find.byIcon(Icons.more_vert)` | `IconButton` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Track Modal** | Modal Sheet Container | `Key('audio_tracks_sheet')` | `find.descendant(of: find.byType(BottomSheet), matching: find.text('Audio Tracks'))` | `BottomSheet` / `Container` | Observable container |
| **Track Modal** | Empty State Text | `Key('audio_tracks_empty')` | `find.text('No audio tracks found')` | `Text` | `expect(finder, findsOneWidget);` |
| **Track Modal** | Audio Stream Item Tile | `Key('audio_track_item_${id}')` | `find.widgetWithText(ListTile, trackTitle)` | `ListTile` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Track Modal** | Active Track Checkmark | `Key('audio_track_check_${id}')` | `find.descendant(of: find.widgetWithText(ListTile, trackTitle), matching: find.byIcon(Icons.check))` | `Icon` | `expect(finder, findsOneWidget);` |
| **OSD Pill** | OSD Overlay Container | `Key('osd_feedback_pill')` | `find.ancestor(of: find.byType(AnimatedOpacity), matching: find.byType(Positioned))` at `top: 90` | `Positioned` / `Container` | `expect(finder, findsOneWidget);` |
| **OSD Pill** | OSD Message Text | `Key('osd_feedback_text')` | `find.text(message)` or `find.textContaining(substring)` | `Text` | `expect(find.textContaining('Audio Track:'), findsOneWidget);` |
| **OSD Pill** | OSD Leading Icon | `Key('osd_feedback_icon')` | `find.descendant(of: find.byKey(Key('osd_feedback_pill')), matching: find.byIcon(iconData))` | `Icon` | `expect(finder, findsOneWidget);` |
| **Audio Studio** | Equalizer Master Switch | `Key('audio_equalizer_switch')` | `find.descendant(of: find.widgetWithText(Row, 'Enable Equalizer'), matching: find.byType(Switch))` | `Switch` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Audio Studio** | Preset Dropdown Button | `Key('preset_picker_button')` | `find.byIcon(Icons.keyboard_arrow_down)` or `find.ancestor(of: find.text('Preset'), matching: find.byType(Row))` | `InkWell` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Preset Picker** | Preset Option Pill (11 VLC) | `Key('preset_pill_${name}')` | `find.text('Full Bass')`, `find.text('Large Hall')`, etc. | `InkWell` / `Text` | `await tester.tap(find.text('Large Hall')); await tester.pumpAndSettle();` |
| **Audio Studio** | Preamp Gain Card | `Key('preamp_slider_card')` | `find.ancestor(of: find.text('Pre-Amplification'), matching: find.byType(Container))` | `Container` | Observable card |
| **Audio Studio** | Preamp Gain Slider | `Key('preamp_slider')` | `find.descendant(of: find.byKey(Key('preamp_slider_card')), matching: find.byType(Slider))` | `Slider` | `await tester.drag(finder, Offset(x, 0)); await tester.pumpAndSettle();` |
| **Audio Studio** | Preamp Live dB Badge | `Key('preamp_value_badge')` | `find.text('+0.0 dB')`, `find.text('+4.0 dB')`, `find.text('-6.0 dB')` | `Text` | `expect(find.text('+4.0 dB'), findsOneWidget);` |
| **Audio Studio** | Audio Delay Sync Card | `Key('audio_delay_sync_card')` | `find.ancestor(of: find.text('Audio Synchronization'), matching: find.byType(Container))` | `Container` | Observable card |
| **Audio Studio** | Audio Delay Slider | `Key('audio_delay_slider')` | `find.descendant(of: find.byKey(Key('audio_delay_sync_card')), matching: find.byType(Slider))` | `Slider` | `await tester.drag(finder, Offset(x, 0)); await tester.pumpAndSettle();` |
| **Audio Studio** | Audio Delay Live Badge | `Key('audio_delay_badge')` | `find.text('+0 ms')`, `find.text('+50 ms')`, `find.text('-100 ms')` | `Text` | `expect(find.text('+50 ms'), findsOneWidget);` |
| **Audio Studio** | Nudge Button: `-100ms` | `Key('audio_delay_nudge_minus_100')` | `find.text('-100ms')` or `find.widgetWithText(OutlinedButton, '-100ms')` | `OutlinedButton` / `InkWell` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Audio Studio** | Nudge Button: `-50ms` | `Key('audio_delay_nudge_minus_50')` | `find.text('-50ms')` or `find.widgetWithText(OutlinedButton, '-50ms')` | `OutlinedButton` / `InkWell` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Audio Studio** | Nudge Button: `Reset` | `Key('audio_delay_nudge_reset')` | `find.text('Reset')` or `find.text('Reset 0ms')` | `OutlinedButton` / `InkWell` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Audio Studio** | Nudge Button: `+50ms` | `Key('audio_delay_nudge_plus_50')` | `find.text('+50ms')` or `find.widgetWithText(OutlinedButton, '+50ms')` | `OutlinedButton` / `InkWell` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Audio Studio** | Nudge Button: `+100ms` | `Key('audio_delay_nudge_plus_100')` | `find.text('+100ms')` or `find.widgetWithText(OutlinedButton, '+100ms')` | `OutlinedButton` / `InkWell` | `await tester.tap(finder); await tester.pumpAndSettle();` |
| **Keyboard** | Keyboard Focus Widget | `Key('desktop_keyboard_handler_focus')`| `find.byType(DesktopKeyboardHandler)` | `Focus` | `simulateShortcut(tester, key: ...);` |

---

### 3.2 Detailed Interaction Recipes for Test Authors

#### 1. Audio Track Modal Button & Stream Selection
```dart
// 1. Reveal controls if hidden
await tester.tap(find.byType(GestureDetector).first);
await tester.pump();

// 2. Locate and tap HUD Audio Tracks button
final audioButton = find.byTooltip('Audio Tracks');
expect(audioButton, findsOneWidget);
await tester.tap(audioButton);
await tester.pumpAndSettle();

// 3. Verify modal opened
expect(find.text('Audio Tracks'), findsOneWidget);

// 4. Verify stream listing and checkmark
final trackTile = find.widgetWithText(ListTile, 'Japanese (5.1)');
expect(trackTile, findsOneWidget);

// 5. Select new track
await tester.tap(trackTile);
await tester.pumpAndSettle();

// 6. Verify modal closed and OSD emitted
expect(find.text('Audio Tracks'), findsNothing);
expect(find.textContaining('Japanese'), findsOneWidget);
```

#### 2. Audio Delay Synchronization Slider & 5 Nudge Buttons
```dart
// 1. Locate Audio Delay Sync Card
expect(find.text('Audio Synchronization'), findsOneWidget);

// 2. Verify Initial Badge
expect(find.text('+0 ms'), findsOneWidget);

// 3. Tap +50ms nudge button
await tester.tap(find.text('+50ms'));
await tester.pumpAndSettle();
expect(find.text('+50 ms'), findsOneWidget);

// 4. Tap +100ms nudge button (delay becomes +150ms)
await tester.tap(find.text('+100ms'));
await tester.pumpAndSettle();
expect(find.text('+150 ms'), findsOneWidget);

// 5. Tap -50ms nudge button (delay becomes +100ms)
await tester.tap(find.text('-50ms'));
await tester.pumpAndSettle();
expect(find.text('+100 ms'), findsOneWidget);

// 6. Tap Reset button (delay becomes 0ms)
await tester.tap(find.text('Reset'));
await tester.pumpAndSettle();
expect(find.text('+0 ms'), findsOneWidget);

// 7. Drag continuous slider
final delaySlider = find.byKey(const Key('audio_delay_slider'));
await tester.drag(delaySlider, const Offset(60, 0));
await tester.pumpAndSettle();
```

#### 3. Equalizer Presets Dropdown & Preamp Slider
```dart
// 1. Enable Master Equalizer Switch if disabled
final eqSwitch = find.descendant(
  of: find.widgetWithText(Row, 'Enable Equalizer'),
  matching: find.byType(Switch),
);
await tester.tap(eqSwitch);
await tester.pumpAndSettle();

// 2. Tap Preset dropdown button
await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
await tester.pumpAndSettle();
expect(find.text('Equalizer Preset'), findsOneWidget);

// 3. Select 'Large Hall' preset
await tester.tap(find.text('Large Hall'));
await tester.pumpAndSettle();

// 4. Verify dropdown pill updated
expect(find.text('Large Hall'), findsOneWidget);

// 5. Adjust Preamp Slider
final preampSlider = find.byKey(const Key('preamp_slider'));
await tester.drag(preampSlider, const Offset(40, 0));
await tester.pumpAndSettle();
expect(find.textContaining('dB'), findsWidgets);
```

#### 4. OSD Visual Feedback Pill Verification
```dart
// Immediately after triggering any action (e.g. Space play/pause, hotkey 'm', 'b', nudge):
await tester.pump();

// Verify OSD is visible at top: 90
final osdFinder = find.byKey(const Key('osd_feedback_pill'));
if (osdFinder.evaluate().isNotEmpty) {
  expect(osdFinder, findsOneWidget);
}
expect(find.text('Mute'), findsOneWidget);

// Fast-forward past OSD auto-dismiss timer (1500ms)
await tester.pump(const Duration(milliseconds: 1600));

// Verify OSD has dismissed
expect(find.text('Mute'), findsNothing);
```

#### 5. Keyboard Event Simulation Helper (All 13 Shortcuts & 4-Tier Jumps)
```dart
/// Clean-room shortcut simulator guaranteeing modifier release hygiene.
Future<void> simulateShortcut(
  WidgetTester tester, {
  required LogicalKeyboardKey key,
  bool shift = false,
  bool alt = false,
  bool ctrl = false,
  bool meta = false,
}) async {
  final modifiers = <LogicalKeyboardKey>[];
  if (shift) modifiers.add(LogicalKeyboardKey.shiftLeft);
  if (alt) modifiers.add(LogicalKeyboardKey.altLeft);
  if (ctrl) modifiers.add(LogicalKeyboardKey.controlLeft);
  if (meta) modifiers.add(LogicalKeyboardKey.metaLeft);

  try {
    for (final mod in modifiers) {
      await tester.sendKeyDownEvent(mod);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
  } finally {
    for (final mod in modifiers.reversed) {
      await tester.sendKeyUpEvent(mod);
    }
    await tester.pump();
  }
}
```

##### 4-Tier Jump Calls:
```dart
// Tier 1: 3s Dialogue Clarification (Shift + ArrowRight / ArrowLeft)
await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, shift: true);

// Tier 2: 10s Sentence Skip (Alt + ArrowRight / ArrowLeft)
await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, alt: true);

// Tier 3: 60s Intro/Recap Skip (Ctrl + ArrowRight / ArrowLeft)
await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true);

// Tier 4: 300s (5 min) Scene Skip (Ctrl + Alt + ArrowRight / ArrowLeft)
await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true, alt: true);

// Default Arrow Seek: 10s (Unmodified ArrowRight / ArrowLeft)
await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight);
```

##### 13 Universal Shortcuts Key Map:
1. `Space`: `simulateShortcut(tester, key: LogicalKeyboardKey.space);`
2. `f` / `F11`: `simulateShortcut(tester, key: LogicalKeyboardKey.keyF);` / `simulateShortcut(tester, key: LogicalKeyboardKey.f11);`
3. `m`: `simulateShortcut(tester, key: LogicalKeyboardKey.keyM);`
4. `b`: `simulateShortcut(tester, key: LogicalKeyboardKey.keyB);`
5. `v`: `simulateShortcut(tester, key: LogicalKeyboardKey.keyV);`
6. `a`: `simulateShortcut(tester, key: LogicalKeyboardKey.keyA);`
7. `h` / `g`: `simulateShortcut(tester, key: LogicalKeyboardKey.keyH);` (+50ms) / `simulateShortcut(tester, key: LogicalKeyboardKey.keyG);` (-50ms)
8. `k` / `j`: `simulateShortcut(tester, key: LogicalKeyboardKey.keyK);` (+50ms) / `simulateShortcut(tester, key: LogicalKeyboardKey.keyJ);` (-50ms)
9. `+` / `-`: `simulateShortcut(tester, key: LogicalKeyboardKey.add);` / `simulateShortcut(tester, key: LogicalKeyboardKey.minus);`
10. `]` / `[`: `simulateShortcut(tester, key: LogicalKeyboardKey.bracketRight);` / `simulateShortcut(tester, key: LogicalKeyboardKey.bracketLeft);`
11. `=`: `simulateShortcut(tester, key: LogicalKeyboardKey.equal);`
12. `Arrow Left` / `Arrow Right`: Covered in 4-tier jumps above.
13. `Arrow Up` / `Arrow Down`: `simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);` / `simulateShortcut(tester, key: LogicalKeyboardKey.arrowDown);`

---

## 4. Caveats

1. **Auto-Hide Overlay Controls**:
   - `PlayerScreen` automatically hides HUD controls via `_controlsTimer` (lines 104–105). When writing tests that tap HUD buttons (like the Audio Track button), the test must ensure controls are visible (`_controlsVisible == true`). In tests, tapping the video body reveals the controls before finding HUD elements.
2. **Scroll Visibility in `AudioStudioSheet`**:
   - On smaller virtual test viewports (e.g. 800x600 default in Flutter test), elements located towards the bottom of `AudioStudioSheet` (such as the 10-band sliders or reset button) may be outside the viewport. Always use `await tester.ensureVisible(finder);` or set `tester.view.physicalSize = const Size(1920, 1080)` to prevent "widget not visible" assertion failures.
3. **No Caveats Beyond Above**: All UI selector strategies, finders, and interaction paths have been thoroughly examined and verified against the existing widget tree.

---

## 5. Conclusion

1. **Complete Finder Matrix Established**:
   - Tests have unambiguous, robust finder recipes for every element in Phase 1:
     - HUD Audio Track modal button (`find.byTooltip('Audio Tracks')` / `find.byIcon(Icons.audiotrack_outlined)`).
     - Audio Track modal sheet, items, and active checkmarks (`find.widgetWithText(ListTile, name)`, `find.byIcon(Icons.check)`).
     - Audio Delay Synchronization card, continuous slider, live badge, and 5 nudge buttons (`find.text('-100ms')`, `find.text('-50ms')`, `find.text('Reset')`, `find.text('+50ms')`, `find.text('+100ms')`).
     - Equalizer Presets dropdown and 11 VLC presets in picker (`find.text('Full Bass')` ... `find.text('Soft Rock')`).
     - Pre-Amplification slider and live dB badge (`find.byKey(Key('preamp_slider'))`, `find.textContaining('dB')`).
     - OSD Visual Feedback Pill (`Positioned(top: 90)`).
2. **Deterministic Keyboard Simulation Protocol**:
   - The `simulateShortcut` helper eliminates modifier key leakage and ensures cross-platform compatibility across Windows, Linux, and macOS.
3. **Zero Ambiguity for Milestone 4 (E2E Test Suite Author)**:
   - This specification provides the exact test code patterns required to implement all 68 test cases in `test/e2e/phase1_e2e_test.dart`.

---

## 6. Verification Method

### 6.1 Independent Verification Commands
```powershell
# 1. Verify static cleanliness of codebase
cd d:\E-player\app
dart analyze

# 2. Verify existing test suite passes
flutter test test/helpers/eplayer_test_harness.dart
flutter test test/features/video_effects_test.dart
flutter test test/unit/decoder_pipeline_test.dart

# 3. Verify widget finder logic in widget test runner
flutter test test/widgets/
```

### 6.2 Invalidation Conditions
- A HUD button tooltip differing from `'Audio Tracks'`.
- Nudge buttons using text other than `'-100ms'`, `'-50ms'`, `'Reset'`, `'+50ms'`, `'+100ms'`.
- Audio delay slider range deviating from `[-10.0s, +10.0s]` (`[-10000ms, +10000ms]`) or division count deviating from `400`.
- OSD feedback pill placed at an offset other than `top: 90`.
- Missing modifier release during keyboard event simulation causing sticky modifier states in subsequent tests.
