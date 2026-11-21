# Phase 3 Feature 9: DLNA / UPnP Media Server Ingestion & Stream Ingestion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide full VLC-parity for Universal Plug'n'Play (UPnP) and DLNA Media Server Discovery, ContentDirectory Hierarchical Browsing, and Direct Ingestion / Playback of remote media streams in E-Player.

---

## Architecture Breakdown

1. **Domain Models (`app/lib/features/network_stream/models/dlna_models.dart`)**:
   - `DlnaMediaServer`:
     - id, friendlyName, host, port, locationUrl, contentDirectoryControlUrl, manufacturer, modelName, iconUrl, isOnline.
   - `DlnaBrowseResult`:
     - containerId, items (`List<NetworkMediaItem>`), totalMatches, numberReturned.
2. **Domain Service (`app/lib/features/network_stream/data/dlna_service.dart`)**:
   - SSDP Multicast Scanner specifically targeting `urn:schemas-upnp-org:device:MediaServer:1` and `ssdp:all`.
   - UPnP XML Device Descriptor Parser resolving `<controlURL>` for `urn:schemas-upnp-org:service:ContentDirectory:1`.
   - SOAP `BrowseDirectChildren` HTTP Client sending RFC-compliant UPnP SOAP envelopes and parsing DIDL-Lite `<container>` folders and `<item>` media files.
   - Direct manual connection by URL or IP/port.
   - Mock transport support for clean-room hermetic testing on FAT32/Windows.
3. **Dedicated UI Hub (`app/lib/features/network_stream/ui/dlna_server_browser_sheet.dart`)**:
   - Cyberpunk DLNA & UPnP Media Browser modal sheet.
   - Server discovery list showing active media servers on LAN.
   - Breadcrumb navigation for nested folders.
   - Media item rows showing duration, resolution, size, and Play / Enqueue actions.
   - Manual server entry dialog.
4. **Integration into `PlayerScreen`**:
   - Quick option in HUD: `hud_dlna_browser_button`.
   - Direct stream playback via `_player.open(Media(item.streamUrl))` and playlist enqueue via `_playlistController.addTrack(...)`.
5. **Unit & Widget Testing**:
   - `app/test/unit/dlna_service_test.dart`: SSDP M-SEARCH generation for MediaServer:1, Device descriptor ContentDirectory URL resolution, SOAP Browse envelope formatting, and DIDL-Lite stream ingestion parsing.
   - `app/test/unit/dlna_widget_test.dart`: UI rendering, server list, folder drilldown, stream play callback, and manual connection.

---

## Tasks

### Task 1: Create DLNA Domain Models & Service
- [x] Create `app/lib/features/network_stream/models/dlna_models.dart`.
- [x] Create `app/lib/features/network_stream/data/dlna_service.dart`.
- [x] Create `app/test/unit/dlna_service_test.dart` and verify.

### Task 2: Create DLNA Server Browser Sheet & Wire into PlayerScreen
- [x] Create `app/lib/features/network_stream/ui/dlna_server_browser_sheet.dart`.
- [x] Wire `hud_dlna_browser_button` into `player_screen.dart` quick settings menu.
- [x] Connect Play & Enqueue actions to player engine and playlist.
- [x] Create `app/test/unit/dlna_widget_test.dart` and verify.

### Task 3: Static Analysis & Regression Gates
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Run `phase2_e2e_test.dart` regression verification.
- [x] Commit and push Phase 3 Feature 9 to `origin/main`.
