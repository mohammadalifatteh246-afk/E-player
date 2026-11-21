# Undocked / Detached Multi-Window Playlist Panel (VLC Parity) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VLC 1:1 Undocked / Detached Multi-Window Playlist Panel (`--pl-dock-status=0`, `Ctrl+L`) allowing users to detach the playlist into a movable, resizable, floating glassmorphic window over the video surface with search, track switching, queue management, and re-docking.

**Architecture:** `PlaylistController` managing playback queue, current item index, search filter, dock state (`isUndocked`), window position, and minimized state. `UndockedPlaylistPanelWidget` with drag-and-drop header, track list, playing indicator, search bar, and dock/undock toggle. Integrated with `PlayerScreen` and `DesktopKeyboardHandler` (`Ctrl+L`).

**Tech Stack:** Flutter, Dart 3.x, `EDesign` design tokens, `LibraryProvider`.

**Spec:** VLC Media Player 3.0.24 `pl-dock-status=false` (`src/gui/qt/components/playlist/playlist.cpp`, `PlaylistDialog`).

## Global Constraints

- Hotkey `Ctrl+L` toggles playlist visibility.
- Undocked floating window is draggable anywhere on the screen via pan gestures.
- Tapping a track in the playlist changes playing video without closing or dismissing the undocked window.
- Dock toggle transitions seamlessly between docked bottom sheet and detached floating panel.
- Minimize toggle collapses panel into a compact title bar.
- 0 errors, 0 warnings in `flutter analyze`.
- 100% automated test coverage.

## Review Focus

1. Floating drag ergonomics: dragging header moves window smoothly within screen boundaries.
2. Track switching: clicking non-playing track triggers `_player.open(Media(path))` and highlights the new item.
3. Search filtering: typing in search box filters playlist items in real time.
4. Dock/Undock toggle: switches between docked and floating mode while retaining queue state.
5. Hotkey `Ctrl+L`: opens and closes playlist panel with OSD feedback.

---

### Task 1: Playlist State Controller & Undocked Panel Widget

**Files:**
- Create: `app/lib/features/player/services/playlist_controller.dart`
- Create: `app/lib/features/player/ui/widgets/undocked_playlist_panel_widget.dart`
- Test: `app/test/unit/playlist_controller_test.dart`

- [ ] Implement `PlaylistController` managing playlist items, current index, search query, dock state, position, and minimized state.
- [ ] Build `UndockedPlaylistPanelWidget` with draggable header, search bar, re-dock button, minimize button, and interactive track list.
- [ ] Write unit tests verifying controller operations (next, previous, jump, search, dock toggle, position clamp).
- [ ] Run unit tests and confirm passing.

---

### Task 2: PlayerScreen & Keyboard Handler Integration

**Files:**
- Modify: `app/lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/undocked_playlist_widget_test.dart`

- [ ] Add `Ctrl+L` hotkey binding to `DesktopKeyboardHandler`.
- [ ] Wire `PlaylistController` in `PlayerScreen` with library provider items.
- [ ] Add Playlist button to player HUD top bar.
- [ ] Mount `UndockedPlaylistPanelWidget` when undocked or bottom sheet when docked.
- [ ] Write widget tests verifying dragging, track selection, search filtering, and hotkey toggle.
- [ ] Run widget tests and confirm passing.

---

### Task 3: Full Verification, Static Analysis & Git Commit

- [ ] Run `flutter analyze --no-pub` and ensure 0 issues found.
- [ ] Run all unit and widget tests (`flutter test --no-pub`).
- [ ] Commit changes with message `feat(player): implement VLC undocked playlist multi-window panel parity`.
- [ ] Push to `origin/main`.
