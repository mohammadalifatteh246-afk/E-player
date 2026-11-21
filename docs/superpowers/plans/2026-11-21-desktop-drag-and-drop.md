# Desktop Drag-and-Drop Ingestion (VLC Signature UX) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VLC 1:1 Desktop Drag-and-Drop Ingestion allowing users to drag and drop video/audio files to play instantly and subtitle files (`.srt`, `.vtt`, `.ass`, etc.) to attach dynamically without interrupting video playback.

**Architecture:** Pure Dart FFI Win32 bridge to `shell32.dll` (`DragAcceptFiles`, `DragQueryFileW`, `DragFinish`) and `user32.dll` (`SetWindowLongPtrW`, `CallWindowProcW`) hooking `WM_DROPFILES (0x0233)`. Exposes a clean, cross-platform `DesktopDragDropService` with a broadcast stream of typed `DroppedMediaEvent` items, fully integrated into `PlayerScreen` and `HomeScreen`.

**Tech Stack:** Dart 3.x, Flutter Desktop, `dart:ffi`, `package:ffi`, MediaKit libmpv.

**Spec:** VLC Media Player 3.0.24 drag & drop behavior (`dragdrop.cpp`, `main_interface.cpp`).

## Global Constraints

- Pure Dart FFI only (no third-party Flutter plugin symlinks, supporting FAT32 D: drive).
- Zero memory leaks: ensure `DragFinish`, UTF-16 buffer `calloc.free`, and `NativeCallable.close()` are always called.
- Headless test safety: non-Windows platforms and unit tests must run without errors via simulation hooks.
- 0 errors, 0 warnings in `flutter analyze`.
- 100% automated test coverage.

## Review Focus

1. Subtitle drop on active video: must attach subtitle without pausing or seeking.
2. Video drop on active video: replaces playback and updates watch history.
3. Multiple file drop: plays first video, classifies remaining items.
4. Non-media / unsupported file drop: gracefully shows feedback toast without crashing.
5. Service disposal: restores original WndProc pointer cleanly.

---

### Task 1: Desktop Drag & Drop Data Models & FFI Service

**Files:**
- Create: `app/lib/features/player/services/desktop_drag_drop_service.dart`
- Test: `app/test/unit/desktop_drag_drop_test.dart`

- [ ] Define `DroppedItemType` (`videoAudio`, `subtitle`, `folder`, `unsupported`).
- [ ] Implement `DroppedItem` with extension-based classification for all VLC media and subtitle formats.
- [ ] Implement `DroppedMediaEvent` with convenience getters (`hasVideoAudio`, `hasSubtitle`, `videoAudioItems`, `subtitleItems`).
- [ ] Implement `DesktopDragDropService` with Win32 FFI bindings and simulation capability for unit tests.
- [ ] Write unit tests verifying file classification, event generation, and stream subscriptions.
- [ ] Run unit tests and confirm passing.

---

### Task 2: PlayerScreen & HomeScreen Drag-and-Drop Integration

**Files:**
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Modify: `app/lib/features/home/ui/home_screen.dart`
- Test: `app/test/unit/desktop_drag_drop_widget_test.dart`

- [ ] Wire `DesktopDragDropService.instance` in `PlayerScreen.initState` and clean up in `dispose`.
- [ ] Handle subtitle drop: attach via `_player.setSubtitleTrack(SubtitleTrack.uri(path))` and display OSD toast.
- [ ] Handle video drop: load media into `_player.open(Media(path))` and display playback toast.
- [ ] Wire `DesktopDragDropService.instance` in `HomeScreen` to launch `PlayerScreen` on dropped video files.
- [ ] Write widget tests verifying that simulated subtitle drop triggers subtitle track attachment and simulated video drop triggers media playback.
- [ ] Run widget tests and confirm passing.

---

### Task 3: Full Verification, Static Analysis & Git Commit

- [ ] Run `flutter analyze` and ensure 0 issues found.
- [ ] Run all unit and widget tests (`flutter test`).
- [ ] Commit changes with message `feat(player): implement VLC desktop drag-and-drop ingestion parity`.
- [ ] Push to `origin/main`.
