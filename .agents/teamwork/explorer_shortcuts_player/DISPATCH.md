# Task Assignment: Player Architecture & Shortcuts Exploration (Kronos)

## Objective
Investigate the existing Flutter codebase in `d:\E-player\app` to map how playback, user input (keyboard/mouse), shortcuts, OSD notifications, and HUD controls are currently implemented and structured.

## Authoritative Inputs
- Original Request: `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- Working Directory: `d:\E-player\app`

## Scope & Investigation Tasks
1. **Player Screen Architecture**:
   - Locate `PlayerScreen` and associated widgets in `d:\E-player\app\lib\features\player\`.
   - How does the player obtain input focus on desktop? Is there an existing `FocusNode`, `Shortcuts`, `Actions`, or `RawKeyboardListener`/`HardwareKeyboard` listener?
   - How are playback actions triggered (Play/Pause, Fullscreen, Mute, Seek, Volume, Speed)?
2. **Shortcuts & Seek Mechanics**:
   - Are there existing keyboard shortcuts in the app? Where are they defined?
   - How is seeking currently executed on the player instance (`_player.seek`)? Does it use `Duration`, and how is it clamped?
   - How do modifiers (`Shift`, `Alt`, `Control`, `Meta`) get detected or handled in Flutter desktop?
3. **On-Screen Display (OSD)**:
   - Does E-Player already have an OSD overlay system (e.g. volume HUD, speed badge, seek indicator, track change alert)?
   - If yes, what widget and state manager drive it? If not, how are visual cues rendered?
4. **HUD Top Bar Layout**:
   - Inspect the top bar of `PlayerScreen`. What actions/icons currently exist (back, title, audio, subtitle, settings, etc.)?
   - Where can the new dedicated Audio Track selector button be integrated cleanly?
5. **Existing Test Suite**:
   - Examine `d:\E-player\app\test\` for player, shortcut, and controller tests.
   - What test harness or mocks exist for `Player` / `media_kit`?

## Deliverable
Write your findings and architectural analysis to:
`d:\E-player\.agents\teamwork\explorer_shortcuts_player\handoff.md`
Send a completion message when finished.


## 2026-11-10T08:09:10Z
[Message] timestamp=2026-11-10T08:09:10Z sender=63171882-8b91-4476-8781-8908629f8b43 priority=MESSAGE_PRIORITY_HIGH content=You are the Shortcuts and Player Architecture Explorer (Kronos).
Read your assignment in d:\E-player\.agents\teamwork\explorer_shortcuts_player\DISPATCH.md and the authoritative request in d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md.
Investigate d:\E-player\app: examine PlayerScreen, focus management, keyboard listener/shortcut architectures, seeking mechanics, OSD feedback, and top bar HUD structure.
Write your complete report to d:\E-player\.agents\teamwork\explorer_shortcuts_player\handoff.md.
When finished, send a message to the orchestrator.
