# Phase 3 Feature 11: Sleep Timer & Automatic System Shutdown / Suspend Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full VLC-parity for Sleep Timer & OS Power Management, allowing users to pause playback, quit the application, or put the OS to sleep/shutdown/hibernate after a preset time (15m, 30m, 45m, 60m, 90m, 120m, custom duration, or end of track), with smooth audio fade-out and live HUD countdown.

**Architecture:**
- Orchestration: Antigravity as Supreme Coordinator overseeing 43-Agent Enterprise (`APEX-OVERLORD`, `KODEX-COMMANDER`, `CYBER-FORGE`, `CRASH-TESTER`).
- Domain Model: `SleepTimerAction`, `SleepTimerConfig`, `SleepTimerState` in `app/lib/features/sleep_timer/models/sleep_timer_models.dart`.
- Controller & Service: `SleepTimerController` and `PlatformPowerExecutor` in `app/lib/features/sleep_timer/data/sleep_timer_controller.dart`.
- UI Studio: `SleepTimerSheet` in `app/lib/features/sleep_timer/ui/sleep_timer_sheet.dart`.
- HUD Integration: `hud_sleep_timer_button` quick option and live countdown badge in `PlayerScreen`.

**Tech Stack:** Flutter 3.x, Dart 3.x, `media_kit: ^1.2.6`, pure Dart FAT32 compliant.

---

### Task 1: Domain Models & Sleep Timer Controller
**Files:**
- Create: `app/lib/features/sleep_timer/models/sleep_timer_models.dart`
- Create: `app/lib/features/sleep_timer/data/sleep_timer_controller.dart`
- Test: `app/test/unit/sleep_timer_test.dart`

**Steps:**
- [x] Define `SleepTimerAction` (pausePlayback, stopAndExit, systemSleep, systemShutdown, systemHibernate) and `SleepTimerState`.
- [x] Implement `SleepTimerController` with 1-second ticker, countdown management, +5m/+10m extension, smooth fade-out calculation, end-of-track monitoring, and mockable `PlatformPowerExecutor`.
- [x] Write comprehensive unit tests in `app/test/unit/sleep_timer_test.dart` covering countdown, pause trigger, stop/exit trigger, OS power command generation, smooth volume attenuation, and track-end completion.
- [x] Run `flutter test --no-pub test/unit/sleep_timer_test.dart` and verify all tests pass.

---

### Task 2: Sleep Timer Sheet UI & PlayerScreen HUD Integration
**Files:**
- Create: `app/lib/features/sleep_timer/ui/sleep_timer_sheet.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/sleep_timer_widget_test.dart`

**Steps:**
- [x] Implement `SleepTimerSheet` with preset chips (15m, 30m, 45m, 60m, 90m, 120m, End of Track), custom duration picker, action selector, smooth fade-out switch, and active countdown controls (Cancel, +10m).
- [x] Wire `hud_sleep_timer_button` into `PlayerScreen` quick options menu.
- [x] Add live countdown indicator in HUD during active timer.
- [x] Write widget tests in `app/test/unit/sleep_timer_widget_test.dart` testing preset selection, countdown display, cancel action, and extend timer action.
- [x] Run `flutter test --no-pub test/unit/sleep_timer_widget_test.dart` and verify all tests pass.

---

### Task 3: Quality Gates, Static Analysis & Git Commit
**Files:**
- All modified/created files

**Steps:**
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Run `flutter test --no-pub test/e2e/phase2_e2e_test.dart`.
- [x] Commit and push Phase 3 Feature 11 to `origin/main`.
