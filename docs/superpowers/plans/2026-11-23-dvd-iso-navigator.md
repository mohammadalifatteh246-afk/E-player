# Phase 4 Feature 13: DVD ISO & Virtual Video Folder Navigator Plan (4-Pillar REA Clean-Room Studio)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver complete VLC-parity for DVD playback (`dvdnav.c` / `dvdread.c`), enabling E-Player to auto-detect and parse `VIDEO_TS` folders and unencrypted `.iso` disc images, extract Titles, Chapters, Audio/Subtitle streams from `IFO` files, stitch sequential `VOB` files into gapless titles, and provide a Cyberpunk `DvdNavigatorSheet` with live chapter jumping, HUD badge, and hotkeys (`Ctrl+Shift+D`).

**Architecture:**
- **Pillar 1 (Domain Models)**: `DvdMediaInfo`, `DvdTitle`, `DvdChapter`, `DvdAudioTrackInfo`, `DvdSubtitleTrackInfo`, `DvdSourceType` in `app/lib/features/dvd/domain/dvd_models.dart`.
- **Pillar 2 (Pure Dart IFO & ISO Parser)**: `DvdNavigatorService` in `app/lib/features/dvd/data/dvd_navigator_service.dart`:
  - ISO 9660 Sector 16 Volume Descriptor parser (`CD001`) extracting disc volume label.
  - IFO parser for `VIDEO_TS.IFO` (VMG) and `VTS_xx_0.IFO` (VTS) with BCD duration calculation and PTT chapter tables.
  - VOB Title Set grouper stitching `VTS_01_1.VOB`..`VTS_01_N.VOB` into gapless seamless title sequences.
- **Pillar 3 (Cyberpunk DVD Navigator UI)**: `DvdNavigatorSheet` in `app/lib/features/dvd/ui/dvd_navigator_sheet.dart`:
  - Title selector dropdown / segmented chips.
  - Chapter grid/list with chapter numbers, timestamps, and 1-tap jump callback.
  - Audio stream & Subtitle stream badges.
- **Pillar 4 (Player HUD & Keyboard Integration)**:
  - Wire `Ctrl+Shift+D` in `desktop_keyboard_handler.dart`.
  - Add live DVD badge (`📀 DVD • Title 1 / Ch 3`) in `PlayerScreen` HUD when playing DVD/ISO sources.
  - Add quick option tile `hud_dvd_navigator_button`.
- **Pillar 5 (Hermetic TDD & Verification)**:
  - Unit tests in `dvd_models_and_service_test.dart`.
  - Widget tests in `dvd_navigator_widget_test.dart`.
  - Full static analysis `flutter analyze --no-pub`.
  - Regression test suite verification.

**Tech Stack:** Flutter 3.x, Dart 3.x, `media_kit: ^1.2.6`, pure Dart FAT32 compliant.

---

### Task 1: DVD Domain Models & Pure Dart IFO / ISO Parser Service
**Files:**
- Create: `app/lib/features/dvd/domain/dvd_models.dart`
- Create: `app/lib/features/dvd/data/dvd_navigator_service.dart`
- Test: `app/test/unit/dvd_models_and_service_test.dart`

**Steps:**
- [x] Define `DvdSourceType` (videoTsFolder, isoImage, vobSequence).
- [x] Define `DvdChapter`, `DvdTitle`, `DvdAudioTrackInfo`, `DvdSubtitleTrackInfo`, and `DvdMediaInfo`.
- [x] Implement `DvdNavigatorService`:
  - `isDvdSource(String path)` checking if path is `.iso` or contains `VIDEO_TS`.
  - `parseIsoVolumeLabel(File file)` reading Sector 16 (offset 32768) ISO 9660 descriptor.
  - `parseVideoTs(Directory dir)` or `parseDvd(String path)` reading `VIDEO_TS.IFO` and `VTS_xx_0.IFO` files.
  - Fallback smart VTS scanner grouping `VTS_xx_x.VOB` files by title index.
  - Chapter calculation and duration formatting.
- [x] Write unit tests in `app/test/unit/dvd_models_and_service_test.dart` testing ISO volume descriptor detection, IFO parsing, VOB grouping, chapter indexing, and title selection.
- [x] Run `flutter test --no-pub test/unit/dvd_models_and_service_test.dart` and verify all tests pass.

---

### Task 2: Create Cyberpunk DvdNavigatorSheet & HUD Integration
**Files:**
- Create: `app/lib/features/dvd/ui/dvd_navigator_sheet.dart`
- Modify: `app/lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/dvd_navigator_widget_test.dart`

**Steps:**
- [x] Implement `DvdNavigatorSheet` with:
  - Disc header (disc icon, volume label, total duration, source type badge).
  - Title selector dropdown / ChoiceChips for multi-title discs.
  - Chapter list / grid showing chapter numbers, start times, and active chapter indicator.
  - Audio and Subtitle stream chips.
- [x] Wire `Ctrl+Shift+D` shortcut in `desktop_keyboard_handler.dart` to open DVD Navigator.
- [x] Integrate into `PlayerScreen`:
  - Auto-detect DVD source on media open via `DvdNavigatorService.inspectSource()`.
  - Render glowing DVD badge `📀 DVD • Title X / Ch Y` in top HUD bar when DVD source is active.
  - Add `hud_dvd_navigator_button` in quick options menu.
- [x] Write widget tests in `app/test/unit/dvd_navigator_widget_test.dart` testing sheet rendering, title switching, chapter seeking callback, and stream display.
- [x] Run `flutter test --no-pub test/unit/dvd_navigator_widget_test.dart` and verify all tests pass.

---

### Task 3: Quality Gates, Static Analysis & Git Commit
**Files:**
- All modified/created files

**Steps:**
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Run full regression suite `flutter test --no-pub test/unit/dvd_models_and_service_test.dart test/unit/dvd_navigator_widget_test.dart test/e2e/phase2_e2e_test.dart test/e2e/phase4_e2e_test.dart`.
- [x] Commit and push Phase 4 Feature 13 to `origin/main`.
- [x] Confirm Feature 13 completion!
