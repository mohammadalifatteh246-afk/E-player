# Phase 4 Feature 14: Audio CD / Digital Track Ripper & Metadata Extractor Plan (4-Pillar REA Clean-Room Studio)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver 100% VLC parity for Audio CD ripping (`cdda.c` / `transcode.c`), enabling E-Player to parse CUE sheets and Red Book CDDA tracks (`mm:ss:ff` at 75 fps), extract metadata (Performer, Title, Album, Date, Genre), batch-extract selected audio tracks into FLAC, MP3, AAC, WAV, and Opus with embedded metadata tags, and provide a Cyberpunk `AudioCdRipperSheet` with live progress and keyboard shortcut (`Ctrl+Shift+R`).

**Architecture:**
- **Pillar 1 (Domain Models)**: `AudioRipFormat`, `AudioRipQuality`, `CdTrackInfo`, `AudioCdDiscInfo`, `CdRipProgress`, and `CdRipStatus` in `app/lib/features/cdda/domain/cdda_models.dart`.
- **Pillar 2 (Pure Dart CUE Sheet & Red Book Parser)**: `CueSheetParser` in `app/lib/features/cdda/data/cue_sheet_parser.dart`:
  - Parses CUE sheets (`PERFORMER`, `TITLE`, `FILE`, `TRACK xx AUDIO`, `INDEX 01 mm:ss:ff`).
  - Converts Red Book 75 fps sector frames to exact `Duration`.
  - Estimates track durations by calculating intervals between sequential indices.
- **Pillar 3 (Audio CD Ripper Service)**: `AudioCdRipperService` in `app/lib/features/cdda/data/audio_cd_ripper_service.dart`:
  - Builds FFmpeg extraction and metadata arguments (`-ss`, `-to`, `-metadata title=...`, `-metadata artist=...`).
  - Executes batch ripping with mockable `CdRipExecutor` for hermetic testing.
  - Emits real-time progress, speed, ETA, and per-track completion.
- **Pillar 4 (Cyberpunk CD Ripper Studio Sheet)**: `AudioCdRipperSheet` in `app/lib/features/cdda/ui/audio_cd_ripper_sheet.dart`:
  - Disc header (vinyl badge, album title, artist, year, genre, total duration).
  - Select all / Deselect all toggle + individual track checkboxes.
  - Output format ChoiceChips (FLAC Lossless, MP3 320k, AAC, WAV, Opus).
  - Animated glowing progress bar with active track indicator and Cancel button.
- **Pillar 5 (Player HUD & Keyboard Integration)**:
  - Wire `Ctrl+Shift+R` in `desktop_keyboard_handler.dart`.
  - Add quick option tile `hud_cd_ripper_button` in `PlayerScreen`.
- **Pillar 6 (Hermetic TDD & Verification)**:
  - Unit tests in `cdda_models_and_service_test.dart`.
  - Widget tests in `cdda_ripper_widget_test.dart`.
  - Static analysis `flutter analyze --no-pub`.
  - Regression suite verification.

**Tech Stack:** Flutter 3.x, Dart 3.x, pure Dart FAT32 compliant.

---

### Task 1: CDDA Domain Models & Pure Dart CUE Sheet Parser
**Files:**
- Create: `app/lib/features/cdda/domain/cdda_models.dart`
- Create: `app/lib/features/cdda/data/cue_sheet_parser.dart`
- Test: `app/test/unit/cdda_models_and_service_test.dart`

**Steps:**
- [ ] Define `AudioRipFormat` (flac, mp3, aac, wav, opus) with codec names, extensions, and default bitrates.
- [ ] Define `CdTrackInfo`, `AudioCdDiscInfo`, `CdRipProgress`, and `CdRipStatus`.
- [ ] Implement `CueSheetParser`:
  - Parse Red Book frame string `mm:ss:ff` to `Duration` (`framesToDuration`).
  - Parse full CUE sheet string into `AudioCdDiscInfo` and `List<CdTrackInfo>`.
  - Calculate track durations from index intervals and file duration.
- [ ] Write unit tests in `app/test/unit/cdda_models_and_service_test.dart` testing frame-to-duration math, CUE sheet parsing, and model serialization.
- [ ] Run `flutter test --no-pub test/unit/cdda_models_and_service_test.dart` and verify all tests pass.

---

### Task 2: Audio CD Ripper Service & Batch Transcoding Engine
**Files:**
- Create: `app/lib/features/cdda/data/audio_cd_ripper_service.dart`
- Modify: `app/test/unit/cdda_models_and_service_test.dart`

**Steps:**
- [ ] Implement `AudioCdRipperService`:
  - Command builder: `buildRipArguments()` injecting time boundaries and `-metadata` tags (title, artist, album, track, date, genre).
  - Batch ripper: `ripSelectedTracks()` iterating over selected tracks, tracking overall and per-track progress.
  - Cancellation support via `cancelRip()`.
  - Pluggable `CdRipExecutor` for testability without external processes.
- [ ] Add unit tests in `app/test/unit/cdda_models_and_service_test.dart` verifying argument building, metadata tag injection, progress emission, and cancellation.
- [ ] Run `flutter test --no-pub test/unit/cdda_models_and_service_test.dart` and verify all tests pass.

---

### Task 3: Cyberpunk AudioCdRipperSheet & Player HUD Integration
**Files:**
- Create: `app/lib/features/cdda/ui/audio_cd_ripper_sheet.dart`
- Modify: `app/lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/cdda_ripper_widget_test.dart`

**Steps:**
- [ ] Implement `AudioCdRipperSheet`:
  - Disc header (album title, artist, year, genre, total duration).
  - Select all / deselect all toggle and track list with checkboxes and durations.
  - Output format ChoiceChips (FLAC, MP3, AAC, WAV, Opus).
  - Start Rip button and animated progress bar with cancel button.
- [x] Wire `Ctrl+Shift+R` in `desktop_keyboard_handler.dart`.
- [x] Add `hud_cd_ripper_button` in `PlayerScreen` quick options menu.
- [x] Write widget tests in `app/test/unit/cdda_ripper_widget_test.dart` testing track selection, format switching, and rip progress state.
- [x] Run `flutter test --no-pub test/unit/cdda_ripper_widget_test.dart` and verify all tests pass.

---

### Task 4: Quality Gates, Static Analysis & Git Commit
**Files:**
- All modified/created files

**Steps:**
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Run full regression suite `flutter test --no-pub test/unit/cdda_models_and_service_test.dart test/unit/cdda_ripper_widget_test.dart test/unit/dvd_models_and_service_test.dart`.
- [x] Commit and push Phase 4 Feature 14 to `origin/main`.
- [x] Confirm Feature 14 completion!
