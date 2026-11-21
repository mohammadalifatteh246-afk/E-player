# Playlist M3U / M3U8 / XSPF Exporter & Importer Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full VLC-parity playlist serialization and parsing for `.m3u`, `.m3u8`, and `.xspf` formats, allowing users to export queues, import saved playlists, and drag-and-drop playlists directly onto the player.

**Architecture:**
1. **Serialization Core:** `PlaylistSerializer` with pure Dart parsing and generation of Extended M3U/M3U8 and XSPF XML.
2. **Controller Integration:** `PlaylistController.importPlaylist()` and `PlaylistController.exportPlaylist()`.
3. **UI & Drag-Drop Integration:** Import/Export buttons in `UndockedPlaylistPanelWidget` and drag-drop support in `DesktopDragDropService` / `PlayerScreen`.

**Tech Stack:** Flutter 3.x, Dart 3.x (`dart:io`, `dart:convert`, pure Dart, FAT32 safe).

---

## Tasks

### Task 1: Create PlaylistSerializer & Unit Tests
- [x] Create `app/lib/features/player/services/playlist_serializer.dart`.
- [x] Implement `serializeM3u8`, `serializeXspf`, `parseM3u`, `parseXspf`, `loadFromFile`, and `saveToFile`.
- [x] Write unit test `app/test/unit/playlist_serializer_test.dart` verifying round-trip serialization and edge cases.

### Task 2: Enhance PlaylistController with Import/Export
- [x] In `app/lib/features/player/services/playlist_controller.dart`, add `importPlaylist` and `exportPlaylist`.
- [x] Update `app/test/unit/playlist_controller_test.dart` to verify import and export methods.

### Task 3: UI Buttons in Undocked Playlist Panel & Drag-and-Drop
- [x] In `app/lib/features/player/ui/widgets/undocked_playlist_panel_widget.dart`, add Import and Export icon buttons with tooltips.
- [x] In `app/lib/features/player/services/desktop_drag_drop_service.dart`, add `DroppedItemType.playlist` for `m3u`, `m3u8`, and `xspf`.
- [x] In `app/lib/features/player/ui/player_screen.dart`, handle dropped playlist by importing items and starting playback.

### Task 4: Verification & Git Commit
- [x] Run `flutter test --no-pub test/unit/playlist_serializer_test.dart test/unit/playlist_controller_test.dart`.
- [x] Run `flutter analyze --no-pub`.
- [x] Commit and push to `origin/main`.
