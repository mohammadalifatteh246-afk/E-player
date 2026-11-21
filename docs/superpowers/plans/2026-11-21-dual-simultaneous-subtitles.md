# Dual Simultaneous Subtitles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement dual simultaneous subtitle playback (primary at bottom, secondary at top) with independent track selection, delay offset, and 1-tap track swap, fully integrated with `media_kit`/`libmpv` and E-Player HUD.

**Architecture:**
1. **Controller Layer:** `DualSubtitleController` managing primary/secondary `SubtitleTrack`, secondary visibility, position (`secondary-sub-pos`), delay (`secondary-sub-delay`), and track swap.
2. **UI Layer:** `DualSubtitleSheet` bottom sheet with cyber toggles, track selectors, delay sliders, and swap action.
3. **Player Integration:** Connect `DualSubtitleController` to `PlayerScreen` and Subtitles HUD button.

**Tech Stack:** Flutter 3.x, Dart 3.x, `media_kit: ^1.2.6` (Pure Dart + libmpv FFI properties, zero native C++ plugins, FAT32 safe).

---

## Tasks

### Task 1: Create DualSubtitleController
- [x] Create `app/lib/features/subtitles/domain/dual_subtitle_controller.dart`.
- [x] Implement `attachPlayer(Player player)`, `setPrimaryTrack(SubtitleTrack track)`, `setSecondaryTrack(SubtitleTrack track)`, `toggleDualSubtitles(bool enabled)`, `swapTracks()`, `setSecondaryDelay(double delay)`, and `setSecondaryPosition(double position)`.
- [x] Write unit test `app/test/unit/dual_subtitle_test.dart` verifying state updates and libmpv property dispatch.

### Task 2: Create DualSubtitleSheet UI
- [x] Create `app/lib/features/subtitles/ui/dual_subtitle_sheet.dart`.
- [x] Include dual toggle, primary dropdown, secondary dropdown, 1-tap swap button, delay stepper (-0.5s, -0.1s, +0.1s, +0.5s), and position presets (Top: 10%, Center: 50%, Upper-Third: 25%).

### Task 3: Integrate with PlayerScreen HUD
- [x] In `app/lib/features/player/ui/player_screen.dart`, instantiate `DualSubtitleController`.
- [x] Add "Dual Subtitles (Secondary Track)..." item in `_showSubtitleMenu`.
- [x] When dual subtitles are active, render HUD indicator badge (e.g., `DUAL SUB: [EN] ↓ · [HI] ↑`).

### Task 4: Verification & Git Commit
- [x] Run `flutter test --no-pub test/unit/dual_subtitle_test.dart`.
- [x] Run `flutter analyze --no-pub`.
- [x] Commit and push to `origin/main`.
