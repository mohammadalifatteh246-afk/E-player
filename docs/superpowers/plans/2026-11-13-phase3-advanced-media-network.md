# Phase 3: Advanced Media & Network Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver complete VLC-parity for Phase 3 by integrating In-App Subtitle Search & Download (OpenSubtitles/VLSub), Local Network Storage Browsing (SMB/CIFS & UPnP/DLNA) with a 3rd "Network" tab in LibraryScreen, and live mDNS Google Cast auto-discovery.

**Architecture:** 
1. Subtitles: Connect the existing `OpenSubtitlesService` and `MovieHash` engine to a new glassmorphic `OnlineSubtitlesSheet` modal invoked from `PlayerScreen` and `SubtitleSettingsSheet`. When a user selects a subtitle, it downloads `.srt` to app cache and dynamically attaches via `player.setSubtitleTrack(SubtitleTrack.uri(...))`.
2. Network Streaming: Embed a dedicated 3rd tab "Network" in `LibraryScreen` (Tabs: `['Videos', 'Folders', 'Network', 'Audio', 'Playlists', 'All']`) displaying configured/discovered SMB shares and UPnP/DLNA servers via `NetworkMediaService`, with an "Add Share / Stream" bottom sheet and instant media launching into `PlayerScreen`.
3. Cast Discovery: Bridge `CastDiscoveryService` (RFC 6762/6763 mDNS binary discovery) into `CastService` and `CastSheet` to replace static device lists with real-time mDNS discovery of `_googlecast._tcp` and `_airplay._tcp` receivers on the local subnet.

**Tech Stack:** Flutter / Dart, `media_kit`, `http`, `crypto`, `xml`, RawDatagramSocket / mDNS (RFC 6762/6763).

**Spec:** `d:\E-player\docs\vlc_gap_analysis.md`, Section 5.4 ("Phase 3: Advanced Media & Network Integration").

## Global Constraints

- Must achieve 100% clean static analysis (`flutter analyze` with 0 errors, 0 warnings).
- Zero placeholders, zero TODOs, zero dummy mocks in production code.
- Responsive, glassmorphic UI adhering strictly to `EDesign` design tokens.
- All network operations must be asynchronous, non-blocking, and safely handled with timeouts and graceful error boundaries.
- Offline and error resilience: Network errors, failed mDNS binds, or API limits must show clear inline toast/snack feedback without crashing the app.

## Review Focus

1. Subtitle Search with Missing/Unmatched Hash: Falls back seamlessly to search by title query when MovieHash produces zero results or file is non-local stream.
2. Network Stream Playback: Media URLs (`http://`, `smb://`, `rtsp://`) passed into `PlayerScreen` correctly populate `MediaItem`, configure mpv network caching, and stream smoothly.
3. Network Share Authentication: SMB shares with password credentials safely encode into URI without credential leakage or malformed URL exceptions.
4. mDNS Multicast Socket Conflicts: When socket port 5353 is blocked or permission denied on cellular/restricted Wi-Fi, gracefully degrade without crashing or locking the UI radar.
5. Tab Switch State Preservation: Switching between "Videos", "Folders", and "Network" tabs in `LibraryScreen` preserves scroll position and active search filter.

---

### Task 1: In-App Subtitle Search & Download UI (VLSub Parity)

**Files:**
- Create: `app/lib/features/subtitles/ui/online_subtitles_sheet.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/online_subtitles_ui_test.dart`

**Interfaces:**
- Consumes: `OpenSubtitlesService`, `SubtitleResult`, `MovieHashResult` from `features/subtitles/`
- Produces: `OnlineSubtitlesSheet.show(BuildContext context, {required Player player, required File videoFile, String? title})`

- [ ] **Step 1: Write unit tests for `OnlineSubtitlesSheet` logic and subtitle download attach flow**
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/unit/online_subtitles_ui_test.dart`
  Expected: FAIL (file/class not found)
- [ ] **Step 3: Implement `OnlineSubtitlesSheet` in `app/lib/features/subtitles/ui/online_subtitles_sheet.dart`**
  - Search bar initialized with movie title or file basename.
  - Automatic MovieHash calculation on file open.
  - Search results list with language tag, user rating badge, download count, and hearing impaired icon.
  - 1-tap download that downloads `.srt` to `getTemporaryDirectory()`, attaches via `player.setSubtitleTrack(SubtitleTrack.uri(file.uri.toString()))`, and displays confirmation toast.
- [ ] **Step 4: Wire `OnlineSubtitlesSheet` into `PlayerScreen._showSubtitleMenu()`**
  - Add "Search Online Subtitles (VLSub)..." tile with `Icons.cloud_download_outlined`.
- [ ] **Step 5: Run tests and ensure they pass**
  Run: `flutter test test/unit/online_subtitles_ui_test.dart`
  Expected: PASS
- [ ] **Step 6: Commit**
  `git add app/lib/features/subtitles/ui/online_subtitles_sheet.dart app/lib/features/player/ui/player_screen.dart app/test/unit/online_subtitles_ui_test.dart`
  `git commit -m "feat(subtitles): add in-app OpenSubtitles search and 1-tap download sheet"`

---

### Task 2: Dedicated "Network" 3rd Tab & Storage Browser in `LibraryScreen`

**Files:**
- Create: `app/lib/features/network_stream/ui/network_browser_view.dart`
- Create: `app/lib/features/network_stream/ui/add_network_share_sheet.dart`
- Modify: `app/lib/features/library/ui/library_screen.dart`
- Test: `app/test/unit/network_browser_view_test.dart`

**Interfaces:**
- Consumes: `NetworkMediaService`, `NetworkShare`, `NetworkFileItem` from `features/network_stream/`
- Produces: `NetworkBrowserView` widget displaying shares, servers, and streams.

- [ ] **Step 1: Write unit tests for `NetworkBrowserView` and share management**
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/unit/network_browser_view_test.dart`
  Expected: FAIL
- [ ] **Step 3: Implement `NetworkBrowserView` and `AddNetworkShareSheet`**
  - List configured SMB shares, UPnP/DLNA media servers, and custom network streams.
  - Breadcrumb folder navigation inside shares with video/audio badges.
  - Floating Action Button (+) or header action to add SMB share (IP, Share Name, User, Pass) or direct Stream URL (RTSP/HTTP/HLS).
  - Tapping a playable stream launches `PlayerScreen` directly with streaming URL.
- [ ] **Step 4: Update `LibraryScreen` tab suite to make "Network" the 3rd tab**
  - Set `_tabs = ['Videos', 'Folders', 'Network', 'Audio', 'Playlists', 'All']`.
  - In `_buildContent()`, handle `case 'Network'` by rendering `NetworkBrowserView`.
- [ ] **Step 5: Run tests and verify passing**
  Run: `flutter test test/unit/network_browser_view_test.dart`
  Expected: PASS
- [ ] **Step 6: Commit**
  `git add app/lib/features/network_stream/ui/ app/lib/features/library/ui/library_screen.dart app/test/unit/network_browser_view_test.dart`
  `git commit -m "feat(network): add dedicated Network tab and storage browser in LibraryScreen"`

---

### Task 3: Real mDNS Google Cast Auto-Discovery Integration

**Files:**
- Modify: `app/lib/features/casting/domain/cast_service.dart`
- Modify: `app/lib/features/casting/ui/cast_sheet.dart`
- Test: `app/test/unit/cast_service_mdns_integration_test.dart`

**Interfaces:**
- Consumes: `CastDiscoveryService`, `CastDevice` from `features/cast/`
- Produces: Live updated `CastService.devices` populated from real mDNS query responses.

- [ ] **Step 1: Write unit tests for `CastService` mDNS integration**
- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/unit/cast_service_mdns_integration_test.dart`
  Expected: FAIL
- [ ] **Step 3: Connect `CastDiscoveryService` into `CastService`**
  - Initialize `CastDiscoveryService` during `CastService` startup.
  - On `startScan()`, invoke `CastDiscoveryService.discoverDevices()` and merge discovered devices into `_devices`.
  - Handle protocol tagging (`CastProtocol.chromecast` for Google Cast, `CastProtocol.dlna` for DLNA/UPnP, `CastProtocol.airplay` for AirPlay).
  - Update radar scanning state reactively.
- [ ] **Step 4: Run tests and verify passing**
  Run: `flutter test test/unit/cast_service_mdns_integration_test.dart`
  Expected: PASS
- [ ] **Step 5: Commit**
  `git add app/lib/features/casting/domain/cast_service.dart app/lib/features/casting/ui/cast_sheet.dart app/test/unit/cast_service_mdns_integration_test.dart`
  `git commit -m "feat(cast): integrate real-time mDNS discovery into CastService and CastSheet"`

---

### Task 4: Full Test Suite Verification, Static Analysis & Git Push

**Files:**
- Test: `app/test/e2e/phase3_e2e_test.dart`
- Test: `app/test/unit/phase3_subtitles_network_cast_test.dart`
- Test: `app/test/unit/phase3_adversarial_stress_test.dart`

- [ ] **Step 1: Run comprehensive Phase 3 E2E and Unit test suites**
  Run: `flutter test test/e2e/phase3_e2e_test.dart test/unit/phase3_subtitles_network_cast_test.dart test/unit/phase3_adversarial_stress_test.dart test/unit/online_subtitles_ui_test.dart test/unit/network_browser_view_test.dart test/unit/cast_service_mdns_integration_test.dart`
  Expected: All tests pass (100% pass rate).
- [ ] **Step 2: Run static analysis across entire project**
  Run: `flutter analyze`
  Expected: `No issues found!` (0 errors, 0 warnings).
- [ ] **Step 3: Commit and push Phase 3 implementation to origin/main**
  Run: `git push origin main`
  Expected: Everything up-to-date and clean.
