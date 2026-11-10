# Scope: Milestone 1 — Desktop Keyboard Shortcuts & 4-Tier Seek Physics

## Objective
Implement universal cross-platform desktop keyboard shortcuts and 4-tier precision jump intervals in `d:\E-player\app`.

## Exclusive Write Ownership
The worker for this milestone owns and may modify ONLY these files:
- `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` (new component)
- `lib/features/player/ui/player_screen.dart` (integration, focus, callbacks, OSD overlay)
- `test/unit/desktop_keyboard_handler_test.dart` (new unit/widget test suite)

DO NOT modify `lib/features/player/ui/audio_studio_sheet.dart` (owned by M2/M3).

## Authoritative Inputs
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- `d:\E-player\PROJECT.md`
- Survey Handoff (Kronos): `d:\E-player\.agents\teamwork\explorer_shortcuts_player\handoff.md`
- Specification Handoff (Cypher): `d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md`

## Specifications to Implement
1. **DesktopKeyboardHandler**:
   - FocusNode with autofocus, handling `KeyDownEvent` from `HardwareKeyboard.instance`.
   - Modifiers: `isShift`, `isAlt`, `isCtrl = isControlPressed || isMetaPressed`.
   - 13 Universal Shortcuts:
     - `Space`: play/pause toggle + OSD
     - `f` / `F11`: fullscreen toggle
     - `m`: mute toggle + OSD
     - `b`: cycle audio track + OSD
     - `v`: cycle subtitle track + OSD
     - `a`: cycle aspect ratio + OSD
     - `h` / `g`: subtitle delay nudge (±50ms) + OSD
     - `k` / `j`: audio delay nudge (±50ms) + OSD
     - `+` / `-`: coarse speed adjustment (±0.25x or ±0.5x) + OSD
     - `]` / `[`: fine speed adjustment (±0.1x) + OSD
     - `=`: reset speed to 1.0x + OSD
     - `Arrow Up` / `Arrow Down`: volume adjustment (5% steps, 0-150%) + OSD
     - `Arrow Left` / `Arrow Right`: 4-tier seek physics:
       - Shift: 3s (Dialogue jump)
       - Alt: 10s (Short jump)
       - Ctrl / Cmd: 60s (Medium jump)
       - Ctrl + Alt: 300s (Long jump)
       - None: 10s (Default seek)
       - Clamped between `Duration.zero` and `duration`. Calls `_aiEngine.invalidateQueue()`.
2. **PlayerScreen Integration**:
   - Wrap body in `DesktopKeyboardHandler`.
   - Re-activate OSD feedback: Render `_showFeedback` glassmorphic pill overlay at `top: 90` with icon and text.
   - Refocus `_focusNode.requestFocus()` when bottom sheets/modals close.
3. **Automated Verification**:
   - Author `test/unit/desktop_keyboard_handler_test.dart` verifying all 13 shortcuts and 4-tier modifier combinations.
   - Run `flutter test test/unit/desktop_keyboard_handler_test.dart` and `dart analyze`.

## Completion Criteria
- Static analysis (`dart analyze`) passes with 0 errors and 0 warnings.
- `flutter test test/unit/desktop_keyboard_handler_test.dart` passes.
- Forensic Auditor reports CLEAN.
