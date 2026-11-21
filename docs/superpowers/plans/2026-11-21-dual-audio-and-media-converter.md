# Phase 2 Features 7 & 8: Dual Audio Output Dubbing & Quick Media Transcoder Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full VLC-parity for:
1. **Feature 7**: Dual Audio Output Dubbing (Multi-Device Sound Card / Bluetooth Output with sync delay and track dubbing).
2. **Feature 8**: Quick GUI Media Converter & Audio Extractor (VLC `sout transcode` parity with audio extraction, video transcoding, preset profiles, and real-time progress).

---

## Architecture Breakdown

### Part A: Feature 7 - Dual Audio Output Dubbing
1. **Domain Models (`app/lib/features/audio/domain/dual_audio_models.dart`)**:
   - `AudioDeviceEndpoint`: id, name, description, isDefault, isBluetooth, isUsb.
   - `DualAudioRoutingMode`: `mirrorDuplicate` (same track to 2 devices) vs `dualTrackDubbing` (Track A on device 1, Track B on device 2).
   - `DualAudioConfig`: enabled, primaryDevice, secondaryDevice, routingMode, primaryVolume (0-200%), secondaryVolume (0-200%), secondaryDelayMs (-1000 to +1000 ms), isSecondaryMuted.
2. **Domain Service (`app/lib/features/audio/domain/dual_audio_service.dart`)**:
   - Audio device enumeration.
   - Secondary audio output routing & latency compensation.
   - Persistence in `SharedPreferences`.
3. **UI Sheet (`app/lib/features/audio/ui/dual_audio_sheet.dart`)**:
   - Cyberpunk dual device modal sheet.
   - Primary & secondary device selectors, volume sliders, mute switches, Bluetooth latency slider, routing mode chips.
4. **PlayerScreen Wiring**:
   - Quick option in HUD: `hud_dual_audio_button`.
   - Also integrated into `AudioStudioSheet`.

### Part B: Feature 8 - Quick GUI Media Converter & Audio Extractor
1. **Domain Models (`app/lib/features/export/domain/media_converter_models.dart`)**:
   - `TranscodeFormat`: `mp4`, `mp3`, `m4a`, `wav`, `flac`, `webm`, `mkv`.
   - `TranscodePreset`: name, format, videoCodec, audioCodec, defaultBitrate, isAudioOnly, fileExtension.
   - `TranscodeTask`: id, sourcePath, outputPath, preset, status, progress, speed, elapsed, eta, error.
2. **Domain Service (`app/lib/features/export/domain/media_converter_service.dart`)**:
   - Pure Dart process execution engine (supports ffmpeg CLI and built-in pure Dart fallback/test mock).
   - Real-time progress parsing (time/frame/bitrate/speed).
   - Cancellation and resource cleanup.
3. **UI Sheet (`app/lib/features/export/ui/media_converter_sheet.dart`)**:
   - Source & output path pickers (auto-prefilled from currently playing media).
   - Preset chips (MP3, M4A, MP4, WebM, FLAC, MKV).
   - Audio-only toggle, bitrate selector, time range trim inputs.
   - Live progress indicator, speed readout, ETA, Start/Cancel buttons.
4. **PlayerScreen Wiring**:
   - Quick option in HUD: `hud_media_converter_button`.

---

## Tasks

### Task 1: Feature 7 - Dual Audio Domain Models & Service
- [x] Create `app/lib/features/audio/domain/dual_audio_models.dart`.
- [x] Create `app/lib/features/audio/domain/dual_audio_service.dart`.
- [x] Create `app/test/unit/dual_audio_test.dart` and verify.

### Task 2: Feature 7 - Dual Audio UI Sheet & PlayerScreen Integration
- [x] Create `app/lib/features/audio/ui/dual_audio_sheet.dart`.
- [x] Wire `hud_dual_audio_button` into `player_screen.dart` quick settings and `audio_studio_sheet.dart`.
- [x] Create `app/test/unit/dual_audio_widget_test.dart` and verify.

### Task 3: Feature 8 - Media Converter Domain Models & Service
- [x] Create `app/lib/features/export/domain/media_converter_models.dart`.
- [x] Create `app/lib/features/export/domain/media_converter_service.dart`.
- [x] Create `app/test/unit/media_converter_test.dart` and verify.

### Task 4: Feature 8 - Media Converter UI Sheet & PlayerScreen Integration
- [x] Create `app/lib/features/export/ui/media_converter_sheet.dart`.
- [x] Wire `hud_media_converter_button` into `player_screen.dart` quick settings.
- [x] Create `app/test/unit/media_converter_widget_test.dart` and verify.

### Task 5: Verification & Quality Gates
- [x] Run `flutter test --no-pub` for all newly added test suites.
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Run `phase2_e2e_test.dart` regression verification.
- [x] Commit and push to `origin/main`.
