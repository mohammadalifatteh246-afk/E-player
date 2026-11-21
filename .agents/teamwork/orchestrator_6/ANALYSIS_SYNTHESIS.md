# Comprehensive Architectural & Context Synthesis Report

**Project**: E-Player (`D:\E-player`)  
**Orchestrator**: `orchestrator_6`  
**Date**: November 12, 2026  
**Sources**: Workspace Transcripts, `conversation_summaries.db`, Antigravity Brain (`HERMES_AGENT_MEMORY.md`), `docs/vlc_gap_analysis.md`, `native/engine/`, `app/lib/`, `app/test/`, and Hermes Agent Environment (`C:\Users\Admin\AppData\Local\hermes`).

---

## 1. Executive Summary

A comprehensive, multi-agent survey across Antigravity brain memory, conversation databases (196 workspace records), historical teamwork archives (Orchestrators 1–5, remediation, victory audits), the E-Player codebase, and the local Hermes CLI environment was executed by three specialized agents (`spec_miner_m1_architecture_gap`, `explorer_m1_survey_brain`, and `explorer_m1_hermes_skills`).

The survey established three central empirical realities:
1. **Flutter Video Player & Native Media Engine Architecture**: E-Player is an advanced cross-platform media player powered by Flutter 3.13.4, `media_kit: ^1.2.6` (libmpv), a dual SQLite database (WAL mode + FTS5 full-text search), and a native C++17 neural AI engine (`eplayer_engine.dll` featuring bounded memory pooling, tiled Real-ESRGAN super-resolution, and RIFE 60fps frame interpolation bound via Dart FFI).
2. **VLC Gap Parity State**: Phase 1 (Keyboard Shortcuts, 4-Tier Seek Physics, Audio Delay Sync Slider, Track Selector Modal, 11 EQ Presets + Preamp) and Phase 2 (300% Volume Boost with 3-Color Safety Indicator, Frame Stepping `e`, 4-State A-B Repeat Looper, Aspect Crop Cycling `c`, and Buffer Caching Sliders) are 100% complete, committed (Commits `4674180` and `27d80ef`), and verified by 213 passing automated tests and clean `flutter analyze`.
3. **Hermes Agent & Distribution Topology**: Hermes runs via `C:\Users\Admin\AppData\Local\hermes\bin\hermes.exe` with 38 profiles, 62 enabled skills, and strict free-tier and drive isolation constraints on `D:`. Four specialized Hermes skills have been designed using brainstorming principles.

---

## 2. Flutter/Dart Video Player Architecture

### 2.1 Technology Stack
- **Framework**: Flutter Desktop (Windows, macOS, Linux) and Mobile (Android, iOS), Dart SDK `^3.13.4`.
- **Media Engine Core**: `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7` bundling libmpv, FFmpeg, and libass.
- **State Management**: Reactive UI driven by `provider: ^6.1.5+1`.
- **Database & Storage**: Dual SQLite architecture:
  - `DatabaseHelper`: Watch history, resume points, user preferences.
  - `MediaLibraryDatabase`: Clean-room reverse-engineered VLC `medialibrary` in WAL mode with FTS5 virtual tables (`media_fts`, `artists_fts`, `albums_fts`).
- **Native FFI Bridge**: `dart:ffi` typed bindings (`lib/core/ffi/engine_bindings.dart`) to native C++ shared library.

### 2.2 Core Interaction & Playback Subsystems
- **`PlayerScreen`** (`lib/features/player/ui/player_screen.dart`): Primary presentation surface initializing `Player` with `libass: true`, binding `volume-max: 300.0`, managing HUD bottom toolbar, OSD notification pill, and position listeners.
- **`CinematicGestureEngine`** (`lib/features/player/ui/cinematic_gesture_engine.dart`): Gesture physics scaling right-edge vertical swipe smoothly between 0% and 300% volume with uniform extended gain ($K=150.0$) and no discontinuities.
- **`VolumeSafetyColors`** (`lib/features/player/ui/models/gesture_models.dart`):
  - 0% – 100%: Green (`#22C55E` / standard unity gain)
  - 101% – 200%: Amber (`#F59E0B` / software pre-amp boost)
  - 201% – 300%: Soft Red (`#EF4444` / high over-amplification warning)
- **`DesktopKeyboardHandler`** (`lib/features/player/ui/widgets/desktop_keyboard_handler.dart`): Universal cross-platform desktop shortcut router handling playback transport, speed, audio/subtitle track toggling, audio delay nudge, volume (0–300%), frame stepping (`e`), aspect crop cycling (`c`), and 4-tier modifier jump physics:
  - `Shift + Left/Right`: 3s jump (dialogue clarification)
  - `Alt + Left/Right`: 10s jump (sentence skip)
  - `Ctrl + Left/Right`: 60s jump (intro/recap skip)
  - `Ctrl + Alt + Left/Right`: 300s jump (scene skip)
- **`AudioStudioSheet`** (`lib/features/player/ui/audio_studio_sheet.dart`): 10-band Graphic Equalizer with 20 total presets (including 11 VLC canonical presets: Full Bass, Full Bass & Treble, Full Treble, Headphones, Large Hall, Live, Party, Reggae, Ska, Soft, Soft Rock), Preamp slider (`-20dB` to `+20dB`), and Audio Synchronization slider (`-10.0s` to `+10.0s` in 50ms steps).
- **`PlaybackEnhancements`** (`lib/features/player/ui/playback_enhancements.dart`):
  - `ABRepeatController`: 4-state loop controller (`off` -> `pointA` -> `looping` -> `clear`) with anti-thrashing debounce guard.
  - `AspectCropController`: 6 centered non-distorted aspect crop presets (`16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `Reset`) mapped to mpv `vf` crop filter.
  - `BufferCachingSettingsController`: Network buffer slider (`500ms`–`10,000ms`, default `1,000ms`) mapped to `cache-secs` and demuxer cache size (`16MB`–`128MB`) mapped to `demuxer-max-bytes`.

---

## 3. Native C++ Media Engine Architecture

### 3.1 Location & Build Integration
- Located at `D:\E-player\native\engine`.
- Compiles via modern CMake (`CMakeLists.txt`, C++17) directly into the Windows runtime bundle via `add_subdirectory` in `app/windows/CMakeLists.txt` and exports `eplayer_engine.dll`.

### 3.2 Key Technical Capabilities
1. **Bounded Memory Pool & Frame Lifecycle**:
   - Manages up to 16 static `EPFrameBuffer` instances with a strict queue depth clamp (`kMaxQueueDepth = 8`), completely eliminating VRAM runaway leaks during real-time video playback.
2. **Tiled Real-ESRGAN Super-Resolution**:
   - `eplayer_frame_submit_tiled` implements spatial super-resolution inference broken into overlapping tiles with edge feathering and Laplacian detail enhancement kernels.
3. **RIFE Bidirectional Frame Interpolation**:
   - Smooths 24fps/30fps content to 60fps/120fps with real-time motion vector analysis, scene cut detection, and automatic queue invalidation (`eplayer_queue_invalidate`) upon seek events.
4. **Typed Dart FFI Bridge**:
   - `EPlayerEngineBindings` in `lib/core/ffi/engine_bindings.dart` dynamically loads symbols and maps C memory safely to Dart structs.

---

## 4. VLC Gap Analysis & Roadmap Status

From `docs/vlc_gap_analysis.md` (53 categorized items):
- **Phase 1: Immediate High-Impact Quick Wins**: **100% COMPLETE** (Commit `4674180`).
- **Phase 2: Core UX & Playback Enhancements**: **100% COMPLETE** (Commit `27d80ef`, 213/213 automated tests passed).
- **Phase 3: Advanced Media & Network Integration (Identified Remaining Tasks)**:
  1. *In-App OpenSubtitles REST Client & Hash Search* (VLSub pure Dart implementation for automatic subtitle matching via video byte size and hash).
  2. *Local Network SMB/CIFS & UPnP/DLNA Directory Browsing* (Service and repository architecture for streaming media over LAN).
  3. *Wireless Casting mDNS Device Discovery* (Network service discovery for Chromecast and DLNA rendering endpoints).
- **Phase 4: Long-Term Enterprise Capabilities**:
  - Chapter bookmarking on timeline (`MediaLibraryDatabase`), desktop system tray daemon, and FFT audio visualizer.

---

## 5. Hermes Agent Skill Architecture & Brainstorming Integration

### 5.1 Hermes Agent Environment
- Binary path: `C:\Users\Admin\AppData\Local\hermes\bin\hermes.exe`
- Active directory: `C:\Users\Admin\AppData\Local\hermes\`
- 38 agent profiles including `coder`, `architect`, `qa`, `verifier`.
- Profile `coder` configuration: Custom provider pointing to `http://localhost:20128/v1` with model `hermes-pro`, fallback to Gemini 2.5 Flash free tier.

### 5.2 Four Specialized E-Player Skills Designed
1. **`eplayer-flutter-video-arch`**:
   - *Domain*: Flutter/Dart UI, `PlayerScreen`, `CinematicGestureEngine`, HUD controls, and `DesktopKeyboardHandler`.
   - *Brainstorming Principles*: Intent discovery, exploring layout/gesture alternatives, design documentation before UI mutations.
2. **`eplayer-mpv-vlc-parity`**:
   - *Domain*: libmpv property bindings, 4-tier seek physics, graphic equalizer curves, aspect crop filters, and A-B repeat looping.
   - *Brainstorming Principles*: Comparing VLC C implementation vs mpv properties, evaluating filter latency tradeoffs.
3. **`eplayer-native-neural-ffi`**:
   - *Domain*: C++17 neural AI engine (`native/engine`), CMake targets, bounded frame queues, Real-ESRGAN, RIFE 60fps interpolation, and Dart FFI bindings.
   - *Brainstorming Principles*: Memory safety analysis, CPU/GPU compute tradeoffs, tile size benchmarking.
4. **`eplayer-verification-guardrail`**:
   - *Domain*: Static analysis (`flutter analyze`), automated test suites (`test/unit`, `test/e2e`), cryptographic SHA256 parity verification, and non-interactive Hermes execution.
   - *Brainstorming Principles*: Rigorous verification before claims, zero-placeholder validation, and multi-path mirroring enforcement.

### 5.3 Distribution & Mirroring Topology
- Primary workspace: `D:\E-player`
- Destination 1: `D:\Agents workespaces` (Sectors: `Core Coding & Architecture Sector`, `Research & Synthesis Sector`, `QA, Testing & Verification Sector`, `skills/`, `daily-spark-intel/`)
- Destination 2: `D:\overload` (`skills/`, `daily-spark-intel/`)
- Destination 3: Hermes runtime (`C:\Users\Admin\AppData\Local\hermes\skills/`)
- Cryptographic Verification: Strict SHA256 hash matching required across all destinations.
