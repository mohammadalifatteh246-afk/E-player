# Time Label Click Toggle - Elapsed vs Total vs Remaining (VLC Parity) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VLC 1:1 Time Label Click Toggle allowing users to click or tap the timeline duration label to toggle between Total Duration (`10:00`) and Remaining Time (`-07:15`), with visual OSD feedback and `SharedPreferences` persistence.

**Architecture:** Wrap the right duration label in `PlayerScreen` in an interactive `GestureDetector` / `InkResponse` bound to `_showRemainingTime`. Provide instant state toggle, OSD feedback toast, persistent preference storage, and test coverage.

**Tech Stack:** Flutter, Dart 3.x, `SharedPreferences`, `EDesign` design tokens.

**Spec:** VLC Media Player 3.0.24 `TimeLabel::mousePressEvent` in `src/gui/qt/components/interface_widgets.cpp`.

## Global Constraints

- Mode 1: Remaining duration format (`- 07:15` or `- 1:15:30`).
- Mode 2: Total duration format (`10:00` or `1:25:30`).
- Interactive hit target: minimum 44px touch/click target for easy tapping on desktop and mobile.
- Persistence: saved to `SharedPreferences` (`player_show_remaining_time`).
- 0 errors, 0 warnings in `flutter analyze`.
- 100% automated test coverage.

## Review Focus

1. Initial state: respects persisted preference or defaults gracefully.
2. Clicking right time label: toggles from Remaining to Total and back.
3. Formatted display: shows `- MM:SS` for Remaining and `MM:SS` for Total.
4. OSD feedback toast: displays "Time: Remaining" / "Time: Total Duration".
5. Touch ergonomics: padding ensures easy mouse click and thumb tap.

---

### Task 1: Time Display Mode State & Persistence in PlayerScreen

**Files:**
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/time_label_toggle_test.dart`

- [ ] Add `bool _showRemainingTime` state variable (default true for current UI consistency).
- [ ] Load and persist `_showRemainingTime` via `SharedPreferences`.
- [ ] Wrap right timestamp in an interactive `InkWell` / `GestureDetector` with key `'timeline_duration_toggle'`.
- [ ] Implement toggle handler `_toggleTimeDisplayMode()` with OSD toast feedback.
- [ ] Write unit/widget tests verifying toggle state transitions and format changes.
- [ ] Run tests and confirm passing.

---

### Task 2: Full Verification, Static Analysis & Git Commit

- [ ] Run `flutter analyze --no-pub` and ensure 0 issues found.
- [ ] Run all unit and widget tests (`flutter test --no-pub`).
- [ ] Commit changes with message `feat(player): implement VLC time label click toggle parity`.
- [ ] Push to `origin/main`.
