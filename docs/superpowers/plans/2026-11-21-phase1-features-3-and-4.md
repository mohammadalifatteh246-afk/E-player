# Phase 1: Features 3 & 4 Implementation Plan
# Feature 3: HTTP Web Remote Control (Mobile Wi-Fi Browser Remote with QR Code)
# Feature 4: Direct In-Archive Streaming (.zip / .tar uncompressed media playback)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the remaining two features of Phase 1 with strict VLC parity, pure Dart cross-platform architecture (FAT32 safe), full test coverage, and 0 lint warnings.

---

## Architecture Breakdown

### Feature 3: HTTP Web Remote Control
1. **QR Code Generation Core (`qr_code_generator.dart`)**:
   - Pure Dart QR matrix encoder (ISO/IEC 18004 Model 2, Version 1-4, byte mode, Reed-Solomon error correction).
   - `QrCodePainter` (`CustomPainter`) for glowing Cyberpunk neon rendering on dark cards.
2. **Web Remote Server (`web_remote_service.dart`)**:
   - Lightweight `HttpServer` (`dart:io`) binding to `anyIPv4` on configurable port (default: 8080).
   - Local IP discovery (`NetworkInterface.list()`).
   - Serves embedded Cyberpunk mobile web application (`GET /`).
   - REST API endpoints for player control (`play-pause`, `seek`, `volume` 0-300%, `crop`, `step-frame`, `ab-repeat`, `next`, `previous`, `subtitles/cycle`, `audio/cycle`).
3. **Web Remote Sheet (`web_remote_sheet.dart`)**:
   - Modal UI displaying Server status, Wi-Fi URL, QR Code, Copy URL button, Port toggle, and camera scan instructions.
4. **Player Screen Integration (`player_screen.dart`)**:
   - Web Remote button on PlayerScreen top bar.
   - Wires playback state, volume, track info, and actions to `WebRemoteService`.

### Feature 4: Direct In-Archive Streaming
1. **Archive Media Service (`archive_media_service.dart`)**:
   - Supports `.zip`, `.tar`, `.tar.gz`, `.tgz` using `package:archive`.
   - `listMediaInArchive`: Lists media files inside archive without full extraction.
   - `extractMedia`: Extracts targeted media file to managed system temp directory for instant playback.
   - `cleanupCache`: Cleans temp files on exit.
2. **Drag-Drop & Ingestion (`desktop_drag_drop_service.dart`)**:
   - Classifies `.zip`, `.tar` as `DroppedItemType.archive`.
   - `DroppedMediaEvent.hasArchive` and `archiveItems`.
3. **Player Screen Integration (`player_screen.dart`)**:
   - Dropping or opening an archive extracts and plays media or imports all archive media into `PlaylistController`.

---

## Tasks

### Task 1: Feature 3 - Pure Dart QR Code Generator & Unit Test
- [x] Create `app/lib/features/web_remote/data/qr_code_generator.dart` with ISO 18004 matrix generator and `QrCodePainter`.
- [x] Create unit test `app/test/unit/qr_code_test.dart` verifying matrix generation, URL encoding, and CustomPainter layout.
- [x] Verify test passes with `cd app; flutter test --no-pub test/unit/qr_code_test.dart`.

### Task 2: Feature 3 - Web Remote Service & HTTP Server
- [x] Create `app/lib/features/web_remote/data/web_remote_service.dart`.
- [x] Implement local IP detection, embedded Cyberpunk web app serving, and REST API handlers.
- [x] Create unit test `app/test/unit/web_remote_service_test.dart` testing API endpoints and HTML serving.
- [x] Verify test passes with `cd app; flutter test --no-pub test/unit/web_remote_service_test.dart`.

### Task 3: Feature 3 - Web Remote Sheet UI & PlayerScreen Wiring
- [x] Create `app/lib/features/web_remote/ui/web_remote_sheet.dart` with QR code, URL, and start/stop controls.
- [x] Integrate Web Remote button and service lifecycle into `app/lib/features/player/ui/player_screen.dart`.
- [x] Create widget test `app/test/unit/web_remote_widget_test.dart`.
- [x] Run `flutter analyze --no-pub` and verify zero issues.

### Task 4: Feature 4 - Archive Media Service & Unit Test
- [x] Create `app/lib/features/archive/services/archive_media_service.dart`.
- [x] Implement archive inspection, targeted extraction to temp cache, and cache cleanup.
- [x] Create unit test `app/test/unit/archive_media_service_test.dart` testing `.zip` and `.tar` media extraction.
- [x] Verify test passes with `cd app; flutter test --no-pub test/unit/archive_media_service_test.dart`.

### Task 5: Feature 4 - Drag-and-Drop & PlayerScreen Ingestion
- [x] Update `app/lib/features/player/services/desktop_drag_drop_service.dart` to support `DroppedItemType.archive`.
- [x] Wire archive dropped handler in `app/lib/features/player/ui/player_screen.dart`.
- [x] Update `app/test/unit/desktop_drag_drop_test.dart` for archive classification.

### Task 6: Comprehensive Verification & Git Commit
- [x] Run full test suite for Features 3 & 4.
- [x] Run `flutter analyze --no-pub` (MUST be 0 errors, 0 warnings).
- [x] Commit and push Phase 1 Features 3 & 4 to `origin/main`.
