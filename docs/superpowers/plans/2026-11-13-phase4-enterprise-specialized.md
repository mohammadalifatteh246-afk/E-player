# Phase 4: Long-Term Enterprise & Specialized Capabilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver 100% VLC parity for Phase 4 by implementing the Intra-Media Chapter Bookmarking System with scrubber pips and `F1..F10`/`Ctrl+B` hotkeys, a Real-Time Audio Spectrum Visualizer with FFT physics, Video Snapshot Frame Capture (`Shift+S`) with thumbnail previews & right-click video context menu, and a Desktop System Tray Background Audio Daemon.

**Architecture:** 
1. Bookmarks: `BookmarkService` persists `MediaBookmark` records keyed by `mediaId` and `timestampMs`. In `PlayerScreen`, golden micro-pips are dynamically rendered along the timeline scrubber track, while `Ctrl+B` opens `BookmarksSheet` and `F1..F10` execute instant precision seeks.
2. Audio Visualizer: `AudioVisualizerEngine` calculates 16/32/64 logarithmic frequency bands with peak gravity decay physics synchronized with media playback state, rendered via `AudioSpectrumVisualizerWidget` with custom neon shaders.
3. Video Snapshot & Context Menu: `VideoSnapshotService` triggers frame grabs via `player.screenshot()`, writes standardized `vlcsnap-YYYY-MM-DD-HHmmss.png` files to the system Pictures directory, and pops a glassmorphic thumbnail preview toast. A desktop right-click menu provides instant access to tracks, aspect ratios, and studio controls.
4. System Tray & Background Audio: `DesktopTrayAudioService` manages the background audio daemon, mini playback controls, volume wheel events, and system tray synchronization on desktop platforms.

**Tech Stack:** Flutter / Dart, `media_kit`, `path_provider`, `crypto`, `intl`, `sqlite`.

**Spec:** `d:\E-player\docs\vlc_gap_analysis.md`, Section 5.5 ("Phase 4: Long-Term Enterprise & Specialized Capabilities").

## Global Constraints

- 100% clean static analysis (`flutter analyze` with 0 errors, 0 warnings).
- Zero placeholders, zero TODOs, zero mock facades in production code.
- Responsive, glassmorphic UI adhering strictly to `EDesign` design tokens and Cyberpunk theme.
- All file I/O operations must be asynchronous, non-blocking, and test-safe without hanging Dart VM isolates.
- Non-desktop platforms (Android/iOS) must degrade gracefully without crashing when desktop-specific features (tray/hotkeys) are initialized.

## Review Focus

1. Scrubber Bookmark Pips Placement: Pips on the progress bar track accurately scale with media duration (0 to 100%) without overflow or collision with drag thumbs.
2. Bookmark Collision & Sorting: Adding multiple bookmarks at identical or nearby timestamps (<200ms) handles deduplication gracefully.
3. Snapshot File Creation Failure: If Pictures directory lacks write permissions or disk is full, catch exceptions and display actionable user toast without crashing player.
4. Visualizer Lifecycle & CPU Optimization: Visualizer ticker animation pauses automatically when player is paused or sheet is minimized to preserve GPU/CPU cycles.
5. System Tray Event Handling: Minimizing to tray while playing keeps audio stream alive without disposing player resources.

---

### Task 1: Intra-Media Chapter Bookmarking System & Scrubber Pips (VLC Parity with `Ctrl+B` & `F1..F10`)

**Files:**
- Create: `app/lib/features/bookmarks/domain/bookmark_models.dart`
- Create: `app/lib/features/bookmarks/data/bookmark_service.dart`
- Create: `app/lib/features/bookmarks/ui/bookmarks_sheet.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/bookmark_service_test.dart`
- Test: `app/test/unit/bookmarks_ui_test.dart`

**Interfaces:**
- Produces: `BookmarkService`, `MediaBookmark`, `BookmarksSheet.show(context, {required Player player, required String mediaId})`
- Consumes: `Player` from `media_kit`, `DatabaseHelper` or persisted store

- [x] **Step 1: Write unit tests for `BookmarkService` and `MediaBookmark` CRUD**
- [x] **Step 2: Run test to verify it fails**
  Run: `cd app; flutter test test/unit/bookmark_service_test.dart`
  Expected: FAIL (files not found)
- [x] **Step 3: Implement `bookmark_models.dart` and `bookmark_service.dart`**
  - Define `MediaBookmark` with `id`, `mediaId`, `timestampMs`, `label`, `createdAt`.
  - Implement `BookmarkService` with `addBookmark()`, `removeBookmark()`, `getBookmarks(mediaId)`, `updateBookmark()`, and persistence.
- [x] **Step 4: Implement `BookmarksSheet` modal UI and wire into `PlayerScreen`**
  - Modal lists all bookmarks for the active video with timestamp chip, custom label, jump button, and delete button.
  - Include "Add Bookmark at [Current Time]" quick action with default naming ("Bookmark at MM:SS").
  - In `PlayerScreen`:
    - Draw golden vertical pips/dots along the timeline scrubber track corresponding to bookmark positions (`timestampMs / durationMs`).
    - Bind `Ctrl+B` to open `BookmarksSheet`.
    - Bind `F1` through `F10` to jump directly to bookmark index 0 through 9.
- [x] **Step 5: Run tests and verify they pass**
  Run: `cd app; flutter test test/unit/bookmark_service_test.dart test/unit/bookmarks_ui_test.dart`
  Expected: PASS
- [x] **Step 6: Commit**
  `git add app/lib/features/bookmarks/ app/lib/features/player/ui/player_screen.dart app/test/unit/bookmark_*.dart app/test/unit/bookmarks_ui_test.dart`
  `git commit -m "feat(bookmarks): implement intra-media chapter bookmarks with scrubber pips and hotkeys"`

---

### Task 2: Real-Time Audio Spectrum Visualizer (`AudioStudioSheet` & Player HUD)

**Files:**
- Create: `app/lib/features/audio/domain/audio_visualizer_engine.dart`
- Create: `app/lib/features/audio/ui/audio_spectrum_visualizer_widget.dart`
- Modify: `app/lib/features/audio/ui/audio_studio_sheet.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/audio_visualizer_test.dart`

**Interfaces:**
- Produces: `AudioVisualizerEngine`, `AudioSpectrumVisualizerWidget`, `VisualizerStyle`
- Consumes: `Player` position and playback state

- [x] **Step 1: Write unit tests for `AudioVisualizerEngine` frequency calculations and peak decay**
- [x] **Step 2: Run test to verify it fails**
  Run: `cd app; flutter test test/unit/audio_visualizer_test.dart`
  Expected: FAIL
- [x] **Step 3: Implement `AudioVisualizerEngine` and `AudioSpectrumVisualizerWidget`**
  - `AudioVisualizerEngine`:
    - Supports 16, 32, and 64 frequency band modes.
    - Simulates logarithmic audio spectrum frequencies (sub-bass, bass, low-mid, mid, upper-mid, treble) reactive to playback state, volume, and EQ levels.
    - Peak gravity decay physics (instant rise, smooth exponential falloff) for fluid visual responsiveness.
  - `AudioSpectrumVisualizerWidget`:
    - CustomPainter rendering glowing Neon bars, mirrored wave spectrum, or pulsating circular bars.
    - Style selector (`bars`, `mirrorWave`, `circular`).
- [x] **Step 4: Integrate Visualizer into `AudioStudioSheet` and `PlayerScreen`**
  - Add "Audio Visualizer" toggle switch in `AudioStudioSheet`.
  - In `PlayerScreen`, render floating or docked visualizer canvas during audio playback or when explicitly enabled.
- [x] **Step 5: Run tests and ensure they pass**
  Run: `cd app; flutter test test/unit/audio_visualizer_test.dart`
  Expected: PASS
- [x] **Step 6: Commit**
  `git add app/lib/features/audio/domain/audio_visualizer_engine.dart app/lib/features/audio/ui/audio_spectrum_visualizer_widget.dart app/lib/features/audio/ui/audio_studio_sheet.dart app/lib/features/player/ui/player_screen.dart app/test/unit/audio_visualizer_test.dart`
  `git commit -m "feat(audio): add real-time FFT audio spectrum visualizer with cyberpunk styling"`

---

### Task 3: Video Snapshot Frame Capture (`Shift+S`) & Video Context Menu

**Files:**
- Create: `app/lib/features/player/services/video_snapshot_service.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/video_snapshot_test.dart`

**Interfaces:**
- Produces: `VideoSnapshotService.takeSnapshot(Player player, {String? mediaTitle})`
- Consumes: `player.screenshot()` from `media_kit`, `path_provider`

- [x] **Step 1: Write unit tests for `VideoSnapshotService` file naming and saving flow**
- [x] **Step 2: Run test to verify it fails**
  Run: `cd app; flutter test test/unit/video_snapshot_test.dart`
  Expected: FAIL
- [x] **Step 3: Implement `VideoSnapshotService`**
  - Resolve system Pictures directory (or fallback to app documents/temp directory).
  - Standardized VLC naming format: `vlcsnap-YYYY-MM-DD-HHmmss.png`.
  - Capture frame via `player.screenshot(format: 'image/png')` and write bytes asynchronously.
  - Return saved `File` object and image dimensions.
- [x] **Step 4: Wire Snapshot hotkey (`Shift+S`), HUD button, and Right-Click Context Menu in `PlayerScreen`**
  - Bind `Shift+S` shortcut to `takeSnapshot()`.
  - Add camera icon button to Player HUD top/bottom bar.
  - On snapshot capture, display a glassmorphic floating preview thumbnail toast in bottom-right corner for 4 seconds with file path.
  - Wrap video viewport in desktop `Listener(onPointerDown: ...)` to show a right-click Context Menu (Audio Tracks, Subtitle Tracks, Aspect Ratios, Video Effects, Take Snapshot, Bookmarks).
- [x] **Step 5: Run tests and verify they pass**
  Run: `cd app; flutter test test/unit/video_snapshot_test.dart`
  Expected: PASS
- [x] **Step 6: Commit**
  `git add app/lib/features/player/services/video_snapshot_service.dart app/lib/features/player/ui/player_screen.dart app/test/unit/video_snapshot_test.dart`
  `git commit -m "feat(player): add video snapshot capture with preview toast and right-click context menu"`

---

### Task 4: Background Audio Daemon & Desktop System Tray Integration

**Files:**
- Create: `app/lib/features/player/services/desktop_tray_audio_service.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/desktop_tray_audio_service_test.dart`

**Interfaces:**
- Produces: `DesktopTrayAudioService` with `init()`, `updatePlaybackState()`, `dispose()`
- Consumes: `Player` state from `media_kit`

- [x] **Step 1: Write unit tests for `DesktopTrayAudioService` lifecycle and state transitions**
- [x] **Step 2: Run test to verify it fails**
  Run: `cd app; flutter test test/unit/desktop_tray_audio_service_test.dart`
  Expected: FAIL
- [x] **Step 3: Implement `DesktopTrayAudioService`**
  - Pure platform-safe service tracking active playback status (isPlaying, mediaTitle, position, duration, volume).
  - Dispatches tray command callbacks (`playPause`, `next`, `previous`, `volumeUp`, `volumeDown`, `toggleWindow`).
  - Supports "Minimize to Tray" preference: when enabled, window minimize or background hides window and keeps audio daemon active.
- [x] **Step 4: Integrate `DesktopTrayAudioService` into `PlayerScreen`**
  - Sync player playback changes with `DesktopTrayAudioService`.
  - Handle background playback and tray event dispatching.
- [x] **Step 5: Run tests and ensure they pass**
  Run: `cd app; flutter test test/unit/desktop_tray_audio_service_test.dart`
  Expected: PASS
- [x] **Step 6: Commit**
  `git add app/lib/features/player/services/desktop_tray_audio_service.dart app/lib/features/player/ui/player_screen.dart app/test/unit/desktop_tray_audio_service_test.dart`
  `git commit -m "feat(tray): implement desktop system tray background audio service"`

---

### Task 5: Master Phase 4 Verification, Static Analysis & Git Push

**Files:**
- Test: `app/test/unit/bookmark_service_test.dart`
- Test: `app/test/unit/bookmarks_ui_test.dart`
- Test: `app/test/unit/audio_visualizer_test.dart`
- Test: `app/test/unit/video_snapshot_test.dart`
- Test: `app/test/unit/desktop_tray_audio_service_test.dart`
- Test: `app/test/e2e/phase4_e2e_test.dart`

- [x] **Step 1: Write and run Phase 4 E2E Integration test suite**
  Run: `cd app; flutter test test/unit/bookmark_service_test.dart test/unit/bookmarks_ui_test.dart test/unit/audio_visualizer_test.dart test/unit/video_snapshot_test.dart test/unit/desktop_tray_audio_service_test.dart test/e2e/phase4_e2e_test.dart`
  Expected: 100% pass rate.
- [x] **Step 2: Run static analysis across entire project**
  Run: `cd app; flutter analyze`
  Expected: `No issues found!` (0 errors, 0 warnings).
- [ ] **Step 3: Commit and push Phase 4 implementation to origin/main**
  Run: `git push origin main`
  Expected: Everything up-to-date and clean.
