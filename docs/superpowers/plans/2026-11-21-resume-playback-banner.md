# Resume Playback Prompt Banner (VLC Parity) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VLC 1:1 Resume Playback Prompt Banner that prompts users with an interactive, auto-dismissing banner when opening a partially watched video (`"Continue playback from MM:SS? [Resume] [Restart]"`).

**Architecture:** Database lookup via `DatabaseHelper.getItemByPath()` on media open. If `lastPositionMs >= 5000` and not finished, display an animated glassmorphic banner at top of `PlayerScreen` with Resume, Restart, and Close actions, backed by an 8-second auto-dismiss timer.

**Tech Stack:** Flutter, Dart 3.x, SQLite `DatabaseHelper`, `EDesign` design tokens.

**Spec:** VLC Media Player 3.0.24 `--qt-continue=1` continue playback notification banner (`resume_dialog.cpp`).

## Global Constraints

- Minimum threshold for resume prompt: 5 seconds (`>= 5000 ms`).
- Do not prompt if media is essentially complete (`lastPositionMs >= durationMs - 15000 ms`).
- Auto-dismiss countdown: 8 seconds of user inactivity.
- Tapping "Resume" seeks player to `lastPositionMs`.
- Tapping "Restart" seeks player to `Duration.zero` and resets progress.
- 0 errors, 0 warnings in `flutter analyze`.
- 100% automated test coverage.

## Review Focus

1. Initial video load with saved progress (e.g. 02:45): prompt banner must render with accurate timestamp.
2. Fresh video (progress = 0 or < 5s): prompt banner must NOT render.
3. Completed video: prompt banner must NOT render.
4. Auto-dismiss timer: banner closes after 8 seconds without disturbing ongoing playback.
5. Action execution: "Resume" seeks to saved position, "Restart" seeks to zero.

---

### Task 1: Database Helper Query & Resume Banner Widget

**Files:**
- Modify: `app/lib/core/db/database_helper.dart`
- Create: `app/lib/features/player/ui/widgets/resume_playback_banner_widget.dart`
- Test: `app/test/unit/resume_playback_banner_test.dart`

- [ ] Add `getItemByPath(String path)` to `DatabaseHelper`.
- [ ] Create `ResumePlaybackBannerWidget` with glassmorphic styling, countdown progress/auto-dismiss, Resume, Restart, and Close actions.
- [ ] Write unit tests verifying widget rendering, formatted time display, and action callbacks.
- [ ] Run unit tests and confirm passing.

---

### Task 2: PlayerScreen Integration & Lifecycle Wiring

**Files:**
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/resume_playback_widget_test.dart`

- [ ] Check saved progress on media load in `PlayerScreen`.
- [ ] Mount `ResumePlaybackBannerWidget` in `PlayerScreen` stack overlay with slide/fade transition.
- [ ] Wire actions: "Resume" (`_player.seek(resumePos)`), "Restart" (`_player.seek(Duration.zero)`), "Dismiss".
- [ ] Write widget tests verifying the full flow inside `PlayerScreen`.
- [ ] Run widget tests and confirm passing.

---

### Task 3: Full Verification, Static Analysis & Git Commit

- [ ] Run `flutter analyze --no-pub` and ensure 0 issues found.
- [ ] Run all unit and widget tests (`flutter test --no-pub`).
- [ ] Commit changes with message `feat(player): implement VLC resume playback prompt banner parity`.
- [ ] Push to `origin/main`.
