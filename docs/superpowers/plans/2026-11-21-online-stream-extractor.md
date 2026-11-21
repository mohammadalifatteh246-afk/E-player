# Phase 3 Feature 10: YouTube / Online Stream Extractor & Video Title Fetcher Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide full VLC-parity for Online Network Streams (`Ctrl+N` / `youtube.lua`), including direct YouTube link parsing, video title/channel/thumbnail fetching, format resolution (1080p, 720p, 480p, 360p, Audio Only), generic HLS (.m3u8) / MP4 ingestion, and a lightweight 5-item recent stream history.

**Architecture:**
- Domain model: `OnlineStreamInfo`, `StreamFormat`, and `RecentStreamEntry` in `online_stream_models.dart`.
- Domain service: `OnlineStreamService` with pure Dart regex parser, oEmbed metadata fetcher, direct stream resolution, and SharedPreferences-backed 5-entry LRU history.
- UI Hub: `OnlineStreamSheet` modal dialog with clipboard paste, auto-extract live preview card, quality selector, and quick replay.
- Player integration: `Ctrl+N` keyboard shortcut in `DesktopKeyboardHandler` and HUD quick option `hud_online_stream_button` in `PlayerScreen`.

**Tech Stack:** Flutter 3.x, Dart 3.x, `media_kit: ^1.2.6`, `shared_preferences`.

## Global Constraints
- Pure Dart implementation (Drive `D:\` FAT32 compatible, no native C++ packages or Python binaries).
- Always use `--no-pub` flag for `flutter test` and `flutter analyze`.
- History strictly limited to maximum 5 items (`kMaxHistory = 5`) to prevent memory/app lag.

---

### Task 1: Create Online Stream Domain Models & Service
**Files:**
- Create: `app/lib/features/network_stream/models/online_stream_models.dart`
- Create: `app/lib/features/network_stream/data/online_stream_service.dart`
- Test: `app/test/unit/online_stream_service_test.dart`

**Steps:**
- [x] Define `StreamFormat`, `OnlineStreamInfo`, and `RecentStreamEntry` models with JSON serialization.
- [x] Implement `OnlineStreamService` with:
  - `extractYouTubeVideoId(String url)` supporting `watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`, `/live/`.
  - `fetchMetadata(String url)` using pure Dart HTTP transport to YouTube oEmbed API and generic link headers.
  - `resolveStream(String url, {String? preferredQuality})`.
  - `addRecentStream(RecentStreamEntry entry)` strictly clamped to 5 max items.
  - `clearRecentHistory()` and `loadRecentStreams()`.
- [x] Write unit tests in `app/test/unit/online_stream_service_test.dart` testing regex extraction, metadata parsing, format selection, and 5-item history limit eviction.
- [x] Run `flutter test --no-pub test/unit/online_stream_service_test.dart` and verify all tests pass.

---

### Task 2: Create Open Network Stream Sheet UI & Wire into PlayerScreen
**Files:**
- Create: `app/lib/features/network_stream/ui/online_stream_sheet.dart`
- Modify: `app/lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/online_stream_widget_test.dart`

**Steps:**
- [x] Create `OnlineStreamSheet` with:
  - URL TextField with paste from clipboard button.
  - Extract/Analyze trigger on URL change or submit.
  - Live video preview card (thumbnail, title, author, duration, quality dropdown).
  - "Play Stream" and "Enqueue in Playlist" action buttons.
  - Recent Streams section showing up to 5 items with "Clear History" button.
- [x] Wire `Ctrl+N` / `Cmd+N` keyboard shortcut in `desktop_keyboard_handler.dart` to open `_openOnlineStreamSheet`.
- [x] Add `hud_online_stream_button` tile in `PlayerScreen` quick options menu.
- [x] Wire Play action to `_player.open(Media(streamUrl))` and Enqueue to `_playlistController.addTrack(...)`.
- [x] Write widget tests in `app/test/unit/online_stream_widget_test.dart` testing sheet rendering, URL extraction, live preview, quality selector, play callback, and recent history.
- [x] Run `flutter test --no-pub test/unit/online_stream_widget_test.dart` and verify all tests pass.

---

### Task 3: Static Analysis, Regression & Git Commit
**Files:**
- All modified/created files

**Steps:**
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Run `flutter test --no-pub test/e2e/phase2_e2e_test.dart`.
- [x] Commit and push Phase 3 Feature 10 to `origin/main`.
