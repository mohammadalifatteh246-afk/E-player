# E-Player Flutter Codebase Exhaustive Architecture & Feature Audit Report

**Auditor**: FORGE (The Actor & Principal Architect - Clean-Room Builder)  
**Date**: 2026-11-09  
**Target Codebase**: `d:\E-player\app`  
**Methodology**: Reverse-Engineer-Anything (REA) Codebase Telemetry & Static Inspection (Read-Only)

---

## 1. Executive Summary & Architectural Overview

The **E-Player** Flutter application at `d:\E-player\app` is an advanced, high-performance multimedia player and neural workstation targeting Windows, Android, and iOS. The codebase synthesizes standard desktop/mobile media playback capabilities (leveraging **media_kit** / **libmpv**) with an in-house C++ native neural AI engine (**eplayer_engine** via Dart FFI), custom SQLite WAL relational database architectures, and a modern glassmorphic Cyber-Stitch user experience.

### Architectural Breakdown
- **UI Framework**: Flutter SDK (`sdk: ^3.13.4`), Material Design 3 base with custom `EDesign` cyber-stitch dark design tokens.
- **State Management**: `provider: ^6.1.5+1` utilizing `MultiProvider` at the application root (`main.dart`).
- **Media Playback Engine**: `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7` (backed by libmpv and libass).
- **Native Acceleration Layer**: Custom C++ engine at `d:\E-player\native\engine` dynamically linked as `eplayer_engine.dll` (Windows) / `libeplayer_engine.so` (Android/Linux).
- **Persistence Architecture**: Dual-database approach:
  1. `DatabaseHelper`: Lightweight SQLite database (`media_library.db`) for rapid watch-progress, CRUD operations, and item pruning.
  2. `MediaLibraryDatabase`: Full relational SQLite database (`eplayer_media_library.db`) implementing VLC-grade entity schemas (`Device`, `Folder`, `Media`, `File`, `VideoTrack`, `AudioTrack`, `Task`) with Write-Ahead Logging (WAL), recursive triggers, and FTS5 full-text search.
- **Hardware Ecosystem Support**: Desktop Windows (Direct3D11VA, D3D9, software fallbacks), Android (SurfaceTexture, NDK FFI, AutoEnterPiP), iOS (Metal, Process FFI).

---

## 2. Core Architecture & Dependency Matrix

### 2.1 Dependencies (`pubspec.yaml`)
| Dependency | Version | Architectural Responsibility |
|---|---|---|
| `media_kit` | `^1.2.6` | Core player lifecycle, mpv property bindings, track streams |
| `media_kit_video` | `^2.0.1` | Native hardware texture rendering for video surfaces |
| `media_kit_libs_video`| `^1.0.7` | Pre-built libmpv, FFmpeg, and libass binaries for target platforms |
| `provider` | `^6.1.5+1` | Reactive application state and domain service injection |
| `sqflite` | `^2.4.4` | Mobile SQLite plugin wrapper |
| `sqflite_common_ffi` | `^2.4.3` | Desktop SQLite engine via FFI (Windows/Linux/macOS) |
| `ffi` | `^2.2.0` | C interop for `eplayer_engine` native symbols |
| `file_picker` | `^13.1.0` | Native OS file & directory selection |
| `shared_preferences` | `^2.5.5` | Key-value settings, effects presets, group persistence |
| `crypto` | `^3.0.7` | SHA-256 hashing for vault tamper validation and file deduplication |
| `encrypt` | `^5.0.3` | AES-256 authenticated chunk cipher for secret vault |
| `device_info_plus` | `^13.2.0` | Capability detection (SDK level, ABI architecture, memory profiling) |
| `flutter_svg` | `^2.0.10+1` | Scalable vector icons (`EVectorIcon` component library) |

### 2.2 Entry Point & Service Registration (`lib/main.dart`)
At startup, `main.dart` configures platform specifics before rendering the widget tree:
1. Platform detection: On Windows and Linux, calls `sqfliteFfiInit()` and assigns `databaseFactory = databaseFactoryFfi`.
2. Playback backend initialization: `MediaKit.ensureInitialized()` is wrapped in a protective try-catch.
3. MultiProvider tree establishes singletons for:
   - `LibraryProvider`: Ingests media items, manages scan triggers, sort fields, and video grouping.
   - `ExportService`: Background offline AI enhancement and transcode pipeline.
   - `VaultService`: AES-256-GCM secure storage and decoy mode PIN handler.
   - `TrashService`: 30-day soft-delete recycle bin with automatic purging.
   - `SettingsProvider`: Global hardware decoding, shader cache, audio presets, and network buffer configurations.
   - `CastService`: Wireless casting discovery radar and local streaming daemon manager.
   - `MediaGroupService`: User-curated custom collections and playlists.
   - `VideoGroupingService`: Automatic folder-based and stem/name-based video clustering engine.
4. UI Scaffold: Root `MainScaffold` manages 5 primary bottom navigation destinations: `HomeScreen`, `LibraryScreen`, `EnhanceScreen`, `CastingScreen`, and `SettingsScreen`.

### 2.3 Native In-House C++ Engine (`d:\E-player\native\engine`)
- **Headers & Implementation**: `eplayer_engine.h` and `eplayer_engine.cpp` define an engine handle (`EPlayerEngine`), model handle (`EPlayerModel`), and frame handle (`EPFrameBuffer`).
- **Memory Pool**: Bounded reusable frame buffer pool (`kMaxQueueDepth = 8`) preventing allocation churn during live 60/120 FPS playback.
- **Inference Pipeline**: Tiled spatial super-resolution (`eplayer_frame_submit_tiled`) with edge-preserving bilinear + unsharp detail kernels, fallback tensor kernels, and ONNX Runtime wrapper hooks.
- **Audio & RIFE**: C API functions for `eplayer_set_rife_config`, `eplayer_set_audio_timestamp_offset`, `eplayer_set_audio_dsp_config`, and `eplayer_set_audio_ai_config` (RNNoise).

---

## 3. Existing Playback Pipeline & Interaction Mechanics

### 3.1 Controller & Rendering Lifecycle
- **Initialization**: `PlayerScreen` (`lib/features/player/ui/player_screen.dart`, 2,137 lines) instantiates `Player(configuration: const PlayerConfiguration(libass: true))` and binds a `VideoController(_player)`.
- **Hardware Acceleration**: Managed by `DecoderPipelineService` (`lib/features/player/domain/decoder_pipeline_service.dart`). Supports modes:
  - `HW+`: Direct hardware decoding with CPU copy-back if required.
  - `HW`: Zero-copy direct GPU decoding (`d3d11va`, `nvdec`, `vaapi`, `mediacodec`).
  - `SW`: Software decoding via FFmpeg CPU pipeline.
  - `Auto`: Automatic hardware probe with dynamic fallback tracking via `DecoderTelemetry`.

### 3.2 Glassmorphic Player UI HUD
- **Top Glassmorphic Action Bar**: Floating rounded card (`EDesign.surface`, 0.82 alpha) featuring:
  - Back navigation button
  - Truncated media title with resolution badge (4K, 1080P) and decoder indicator (`Auto`, `HW+`, `SW`)
  - Wireless Display / Cast sheet trigger button
  - Picture-in-Picture trigger
  - AI Enhancement Studio quick-toggle button
  - Subtitle menu button
  - Technical Media Inspector sheet button
  - Settings Drawer trigger
- **Auto-Hiding Engine**: Auto-hides controls after 2,800ms of inactivity (`_controlsTimeout = Duration(milliseconds: 2800)`). Inhibited during active touch gestures or user dragging.
- **Top & Bottom Gradient Overlays**: Animated opacity transitions (250ms easeInOut) ensure high text contrast over bright scenes.

### 3.3 Scrubber / Timeline Mechanics
- Custom `SliderTheme` with 4.0px track height, 6.5px thumb radius, and 16.0px hover overlay.
- Real-time timestamp indicators: `_position` formatted as `HH:MM:SS` or `MM:SS` vs `_duration`.
- Seeking interaction immediately invalidates the native AI inference frame buffer queue (`_aiEngine.invalidateQueue()`) to prevent stale frame artifacts.

### 3.4 Gesture Controls (`CinematicGestureEngine`)
The application implements an interaction physics engine (`cinematic_gesture_engine.dart`):
1. **Vertical Left-Wing Swipe**: Adjusts screen display brightness (0.0 to 1.0) with lingering HUD card feedback.
2. **Vertical Right-Wing Swipe**: Adjusts audio volume (0% to 100%) with volume bar feedback.
3. **Horizontal Swipe**: Smooth timeline scrubbing showing target timestamp and delta (`+00:15` or `-00:30`).
4. **Double-Tap Wings**:
   - Double-tap left 33% of screen: Triggers -10s rewind jump with animated left cyan ripple banner (`-10s`).
   - Double-tap right 33% of screen: Triggers +10s forward jump with animated right cyan ripple banner (`+10s`).
   - Double-tap center: Toggles play/pause with visual icon feedback.
5. **Two-Finger Pinch / Scale**: Real-time video surface zoom (`_scale`) and 2D pan translation (`_offset`).

### 3.5 Playback Speed & Pitch Correction
- Quick speed cycling button: Cycles through `[0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x]`.
- Long-press speed sheet: Fine slider from `0.25x` to `8.0x` (31 divisions) with a **Pitch Correction** toggle controlling mpv pitch preserving scalers.

### 3.6 Aspect Ratio & Geometric Orientation
- **Aspect Ratios**: Original (Auto), 16:9 (Widescreen), 4:3 (Standard), Fill (Stretch), Fit (Best fit), Crop (Zoom fill), and 21:9 (Ultrawide cinema).
- **Auto-Rotation**: Detects video stream width/height upon header load. Automatically switches screen orientation (`ScreenOrientationMode.matchVideo`, `sensor`, `landscape`, `portrait`).
- **Video Stream Rotation**: Hardware-accelerated `RotatedBox` supporting 0°, 90°, 180°, and 270° transform angles (parity with VLC `transform.c`).

### 3.7 Track Selection & Subtitle Synchronization
- **Subtitle Tracks**: Discovered dynamically via `_player.stream.tracks.subtitle`. Users can switch embedded tracks or load external subtitle files (`.srt`, `.ass`, `.vtt`) via file picker.
- **Subtitle Synchronization**: `SubtitleSettingsSheet` includes a real-time subtitle delay slider and nudge buttons (`-0.5s`, `-0.1s`, `Reset 0.0s`, `+0.1s`, `+0.5s`) that directly bind to mpv property `sub-delay` over a range of `-30.0s` to `+30.0s`.

---

## 4. Media Library, Grouping, & Playlist Management

### 4.1 Home Screen Structure (`lib/features/home/ui/home_screen.dart`)
1. **Top Bar**: Search bar with instant debounced queries and a dedicated filter sheet trigger button.
2. **Quick Category Chips**: `All`, `History`, `Groups`, `Videos`, `Folders`, `Favorites`.
3. **History Section (Requirement R4)**:
   - Strictly capped at a maximum of 5 items (`provider.recentFiles.take(5).toList()`).
   - Smooth horizontal scrolling carousel (`Axis.horizontal`, `BouncingScrollPhysics()`).
   - Detailed history card showing 16:9 thumbnail, 4K HDR resolution badge, watch progress bar, elapsed/total duration, and percentage complete.
4. **Action Cards Row**:
   - `Create Group (+)`: Quick action triggering group initialization dialog.
   - `Videos (+)`: Ingest action triggering video addition or folder detail navigation.
5. **Custom User Groups Carousel**: Displays user-created playlists and custom groupings with custom accent colors, icon names, and item counts.
6. **Media Library Section (Requirement R5)**:
   - Filtered exclusively to video files and containing folders via `MediaScannerService.isVideo(f.path)`.
   - Music, series, and anime categories are completely excised from the Media Library view.
   - Supports automated grouping modes (`By Folder` and `By Name` stem clustering).
7. **Favorites Rail**: Horizontal rail of starred media items with instant playback launching.

### 4.2 Custom Group Creation & Empty State (Requirement R1)
- **Initialization**: `MediaGroupService.createGroup()` initializes new groups completely empty (`initialPaths: const []`).
- **Empty State UX**: When opening an empty group in `FolderDetailScreen`:
  - Renders a prominent empty hero state with a circular folder icon, header `"This group is empty"`, and caption `"Add videos or folders to organize this group"`.
  - Displays an elevated **`Add Media / Folders`** button.
  - The AppBar also provides an `add_rounded` action button.
- **Add Modal**: Tapping the Add button presents three paths:
  1. *Select from Library*: Multi-select modal dialog with search, individual checkboxes, and Select All.
  2. *Pick Video Files*: Native file picker filtering for `.mp4`, `.mkv`, etc.
  3. *Pick Folder*: Recursive directory scanner adding all child videos to the group.

### 4.3 Multi-Selection Mode & Batch Operations (Requirements R2 & R3)
Implemented uniformly across both `HomeScreen` and `FolderDetailScreen` / `LibraryScreen`:
- **Activation**: Long-pressing any custom group card or media file tile enters multi-selection mode (`_isSelectionMode = true`).
- **Visual Feedback**: Cards and tiles display glowing borders and cyan checkmark badges (`Icons.check_circle`).
- **Selection AppBar**: Replaces standard AppBar with selected item counter (`X Selected`), an `Exit` (X) button, a dynamic `Select All` / `None` toggle button, a `Move to Group` action, and a `Delete Selected` action.
- **Move to Group**: Opens a dialog listing available custom groups. Moves selected items atomically and updates UI state.
- **Batch Delete**: Confirms deletion via modal dialog. Deletes database records and updates reactive UI across all screens.
- **Protected Built-Ins**: Default app navigation, built-in system filters, and fixed folders are non-selectable and cannot be deleted or moved.

---

## 5. Settings, Audio/Video Filters, and Advanced Capabilities

### 5.1 Settings Screen (`lib/features/settings/ui/settings_screen.dart`)
1. **Video & Hardware Acceleration**:
   - Hardware Acceleration toggle (`hwAcceleration`)
   - Decoding Engine Mode selector (`HW+`, `HW`, `SW`)
   - Zero-Copy Direct Presentation toggle (`zeroCopyGpu`)
   - Dynamic Display Rate Sync toggle (`dynamicResSwitching`)
   - Default Aspect Ratio & Initial Playback Speed preferences
2. **AI Enhancement & Frame Interpolation**:
   - Default AI Super-Resolution Model (`Real-ESRGAN x4 Plus`, `Anime4K v4.0`, `FSRCNN Fast`, `RealESR-AnimeVideoV3`)
   - Auto-Enable RIFE 60 FPS toggle
   - Tensor Compute Precision (`FP16 Compute`, `INT8 Low-Power`, `FP32 Full Precision`)
   - VRAM Allocation Safety Limit (`2.0 GB`, `4.0 GB`, `6.0 GB`, `Unlimited`)
3. **Audio Studio & DSP Engine**:
   - 10-Band Graphic Equalizer Studio navigation
   - Speech Clarity Normalization toggle (neural dialogue leveling)
   - 3D Spatial Audio Virtualizer toggle (binaural acoustic space)
   - Audio Output Channel Layout selector (`Stereo 2.0`, `Surround 5.1`, `Spatial Binaural`)
4. **Subtitles & Typography Studio**:
   - Subtitle Customization Studio navigation
   - Preferred Subtitle Language selector
   - Auto Encoding Detection (UTF-8, Shift-JIS, Windows-1252)
   - Dual-Pass Outline & Shadow toggle
5. **Network & Buffering**:
   - Low-Latency RTSP Mode toggle
   - Network Cache Buffer Size (`16 MB`, `32 MB`, `64 MB`, `128 MB`)
6. **Privacy & Secret Vault**:
   - Decoy Safe PIN Mode toggle (PIN `0000` unlocks decoy storage)
   - Auto-Lock on Background toggle
   - Biometric Fast Unlock toggle (Windows Hello / Fingerprint)
7. **Storage & Cache Diagnostics**:
   - MPV Shader Compilation Cache purge action
   - AI Temporary Render Cache purge action
   - Reset to Defaults action

### 5.2 Video Effects Studio (`lib/features/video_effects/`)
Direct architectural parity with VLC's video filter plugins:
- **Essential Color Adjustments (VLC `adjust.c`)**:
  - Brightness (`-100.0` to `+100.0`)
  - Contrast (`-100.0` to `+100.0`)
  - Saturation (`-100.0` to `+100.0`)
  - Gamma (`-100.0` to `+100.0`)
  - Hue rotation (`-180.0°` to `+180.0°`)
- **Detail & Banding (VLC `sharpen.c` & `gradfun.c`)**:
  - Sharpening with adjustable sigma via FFmpeg `unsharp` filter
  - Banding removal with radius 4..32 via FFmpeg `gradfun` filter
- **Color Filters (VLC `sepia.c` & negate)**:
  - Invert / Negate colors (`negate` filter)
  - Sepia tone with adjustable intensity via `colorchannelmixer` filter
- **Geometry & Transforms (VLC `transform.c` & `rotate.c`)**:
  - Horizontal Flip (`hflip`) and Vertical Flip (`vflip`)
  - Arbitrary angle rotation (0 to 360 degrees)
- **Presets**: Normal, Vibrant, Cinema Warm, Monochrome Noir, Night Comfort, Crisp Detail.
- **Real-Time GPU Preview**: Formulates a 4x5 `ColorFilter` matrix applied in Flutter's rendering pipeline for instant 60/120 FPS feedback during slider manipulation before committing to mpv `vf`.

### 5.3 Audio Studio & Equalizer (`lib/features/player/ui/audio_studio_sheet.dart`)
- **10-Band Graphic Equalizer**: Center frequencies at `60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz` with `-12.0 dB` to `+12.0 dB` gain range.
- **Acoustic Presets**: Flat, Rock, Pop, Jazz, Classical, Bass Boost, Vocal Boost, Techno, Club.
- **DSP Enhancements**:
  - Bass Boost (`bass=g=...`)
  - Night Mode / Dynamic Loudness Normalization (`dynaudnorm=f=200:g=15`)
  - Stereo Virtualizer (`extrastereo=m=2.2`)
  - 3D Spatial Audio Widening (`stereowiden=level=0.7`)
- **Audio Delay Gap Analysis**:
  - **FINDING**: While subtitle delay is fully supported with a dedicated slider and nudge buttons (`sub-delay`), **audio track delay synchronization** (VLC's audio delay `-`/`+` track synchronization or mpv's `audio-delay` property) is currently **missing from the user interface**. Although the native C++ engine exposes `eplayer_set_audio_timestamp_offset(int64_t)`, there is no UI control in `AudioStudioSheet` or `PlayerScreen` to synchronize out-of-sync audio tracks.

### 5.4 Network Streaming & Wireless Casting
- **Casting & Local Streaming Daemon (`LocalStreamingDaemon`)**:
  - Ephemeral HTTP server binding to LAN/loopback interfaces.
  - Implements HTTP 206 Partial Content Range streaming for remote seekability.
  - On-the-fly SubRip (.srt) to WebVTT conversion (`convertSrtToVtt`).
  - Cryptographically secure 32-character hexadecimal token session authentication.
  - Real-time streaming client telemetry (transferred bytes, connection state).
- **Network Stream URL Player (`NetworkStreamScreen`)**:
  - Auto-detection for protocols: `HTTP/HTTPS`, `HLS (.m3u8)`, `RTSP`, `MPEG-DASH (.mpd)`, `RTMP`, `FTP`, `SMB`.
  - Built-in ping latency diagnostics and recent stream history.
  - Direct handoff of remote network URLs into `PlayerScreen` via `_player.open(Media(url))`.

### 5.5 Advanced Ecosystem Features
- **Picture-in-Picture (`PipService`)**: Full Android 12+ `AutoEnterPiP` with aspect-ratio preservation and remote notification actions (`play`, `pause`, `seekForward10`, `seekRewind10`). On desktop (Windows), activates a floating always-on-top frameless overlay.
- **Secret Media Vault (`VaultService`)**: AES-256-GCM chunked file encryption, PBKDF2 key derivation (10,000 iterations), tamper detection with SHA-256 integrity validation, decoy PIN mode (PIN `0000`), and auto-lockout after 5 failed attempts.
- **30-Day Trash / Recycle Bin (`TrashService`)**: Soft delete mechanism preserving original file metadata with restore functionality and 30-day automated purge.
- **Technical Media Inspector (`MediaInfoSheet`)**: Generates comprehensive MediaInfo-grade NFO plain-text reports covering container format, video codec profile, HDR specs, audio channel layouts, and subtitle streams.
- **Offline AI Export Studio (`ExportService` & `EnhanceScreen`)**: Multi-stage export pipeline (Queued -> Preparing -> Decoding -> Enhancing -> Encoding -> Muxing -> Validating -> Completed) with ETA calculation and container validation.

---

## 6. Comprehensive VLC vs. E-Player Gap Analysis Matrix

The table below catalogs core features of VLC Media Player (`C:\Program Files (x86)\VideoLAN\VLC`) against the current implementation in E-Player (`d:\E-player\app`).

| Domain | VLC Capability / Plugin Module | E-Player Status | Implementation Details in E-Player |
|---|---|---|---|
| **Core Playback** | LibVLC / FFmpeg playback pipeline | **Adopted** | Powered by `media_kit` (libmpv) supporting all major containers (MKV, MP4, AVI, WebM, MOV, TS, FLV) |
| **Hardware Decode** | DXVA2, D3D11VA, NVDEC, MediaCodec | **Adopted** | `DecoderPipelineService` manages HW+, HW (Zero-Copy), SW, and Auto fallback |
| **Framerate / Interp** | Motion compensation deinterlace | **Adopted (Advanced)** | In-house RIFE 60 FPS motion vector synthesis and neural frame interpolation |
| **Super-Resolution** | Basic bicubic / lanczos scalers | **Adopted (Advanced)** | Real-ESRGAN x4 Plus, Anime4K, FSRCNN neural upscaling via C++ ONNX engine |
| **Playback Speed** | 0.25x - 8.0x with scaletempo pitch preservation | **Adopted** | Slider & cycle buttons with explicit Pitch Correction toggle (`_pitchCorrection`) |
| **Subtitle Engine** | Libass embedded + external SRT/ASS/VTT | **Adopted** | Embedded track selector, external file picker, font styling & dual-pass outline |
| **Subtitle Sync** | Track sync delay (`sub-delay`, hotkeys `g`/`h`) | **Adopted** | Subtitle delay slider (`-30.0s` to `+30.0s`) with `+/-0.1s` and `+/-0.5s` nudges |
| **Audio Track Delay** | Audio track sync (`audio-delay`, hotkeys `j`/`k`) | **Missing** | mpv `audio-delay` property not wired to any UI slider or nudge buttons in player |
| **Audio Track Select** | Multiple audio track switching popup | **Partially Adopted** | Track observed in telemetry; direct popup menu for switching audio tracks missing |
| **Equalizer** | 10-band Graphic EQ with presets | **Adopted** | 10-band EQ (60Hz - 16kHz), 9 presets, bass boost, dynamic audio normalization |
| **Audio Filters** | Spatializer, headphone virtualizer, night mode | **Adopted** | Integrated via mpv `af` (`dynaudnorm`, `extrastereo`, `stereowiden`) |
| **Video Adjustments** | `adjust.c` (brightness, contrast, hue, sat, gamma) | **Adopted** | Full range controls in `VideoEffectsSheet` with instant 60/120fps GPU preview |
| **Video Transforms** | `transform.c` (rotate 90/180/270, hflip, vflip) | **Adopted** | `RotatedBox` quarter-turns (0/90/180/270°) and FFmpeg `hflip`/`vflip` |
| **Video Filters** | `sharpen.c` (unsharp) & `gradfun.c` (deband) | **Adopted** | Unsharp mask sigma control and gradfun debanding radius slider |
| **Aspect Ratio Framing** | 16:9, 4:3, 21:9, Fit, Fill, Crop | **Adopted** | Full aspect ratio modal with custom aspect math and fit transformations |
| **Touch Gestures** | VLC Mobile swipes (brightness, volume, seek) | **Adopted** | `CinematicGestureEngine`: volume/brightness swipe, seek swipe, double-tap wings |
| **Zoom & Pan** | Interactive video magnification | **Adopted** | Interactive 2-finger pinch zoom and pan translation in player surface |
| **Keyboard Shortcuts** | Full desktop hotkey map (Space, F, M, Arrows) | **Missing** | Currently lacks a dedicated desktop `Shortcuts`/`Actions` keyboard listener |
| **History Management** | Recent playback list with resume | **Adopted** | 5-item capped, smooth horizontal scrolling history with resume timestamp tracking |
| **Media Grouping** | Playlist & collection organization | **Adopted** | Custom group creation (initializes empty), Add button, folder & name stem grouping |
| **Multi-Selection** | Batch select, move, delete | **Adopted** | Long-press selection, Select All, Move to Group, Batch Delete across Home & Library |
| **Network Streaming** | RTSP, HTTP, HLS, DASH, RTMP, FTP, SMB input | **Adopted** | `NetworkStreamScreen` with protocol detection, ping diagnostics, and URL launch |
| **Casting / Output** | Chromecast, AirPlay, DLNA, HTTP sout | **Adopted** | `LocalStreamingDaemon` with HTTP 206 range serving, WebVTT conversion, tokens |
| **Picture-in-Picture** | Native mobile PiP & desktop float | **Adopted** | Android `AutoEnterPiP` with remote action stream; desktop floating overlay |
| **Media Inspection** | Codec & container technical inspector | **Adopted** | MediaInfo-grade NFO plain-text technical generator (`MediaInfoSheet`) |
| **Physical Media** | DVD, Blu-Ray, Audio CD, VCD playback | **Missing** | No optical drive detection, disc menu navigation, or ISO mounting |
| **Capture Devices** | Webcam, TV tuner, DirectShow screen grab | **Missing** | No hardware capture device input pipeline |
| **A-B Loop** | Continuous loop between two timestamps | **Missing** | No A-B repeat markers in timeline scrubber |
| **Audio Visualization**| Goom, projectM, spectrum analyzer | **Missing** | No real-time FFT spectrum visualization during audio playback |
| **Modular Plugins** | 300+ C dynamic modules (`plugins/`) | **Architectural Divergence** | E-Player utilizes unified Dart + C++ FFI rather than dynamic `.dll`/`.so` plugins |

---

## 7. Baseline Inventory & Technical Boundaries Summary

### 7.1 Implemented & Functional Baseline
1. **Core Architecture**: Flutter 3 + MediaKit 1.2.6 (libmpv/FFmpeg/libass) + Native C++ FFI AI Engine.
2. **Database Integrity**: Dual SQLite architecture (`DatabaseHelper` for watch progress; `MediaLibraryDatabase` for WAL relational schema with FTS5 virtual tables and presence cascading).
3. **Playback & UX**: Glassmorphic player controls with auto-hiding (2800ms), `CinematicGestureEngine` (volume/brightness swipes, scrub, wing double-taps, pinch-zoom), 0.25x-8.0x speed with pitch correction, 6 aspect ratios, 4 video rotation angles, and auto-orient matching video geometry.
4. **Video Effects**: Full VLC adjust, sharpen, gradfun deband, invert, and sepia filter chain with GPU matrix preview.
5. **Audio Studio**: 10-band Graphic EQ with 9 presets, bass boost, dynamic loudness normalization, and 3D spatializer.
6. **Subtitles**: Embedded track selection, external file loading, typography styling, and delay synchronization (`-30s` to `+30s`).
7. **Media Library & Grouping**: Video-only filtering in Home Media Library (R5), 5-item capped scrollable History (R4), empty group initialization with `Add Media / Folders` dialog (R1), multi-selection mode (long-press, Select All, delete, move-to-group) across Home and Library (R2, R3).
8. **Ecosystem & Security**: Wireless casting daemon (HTTP 206, WebVTT, tokenized security), Android PiP / Desktop overlay, AES-256-GCM Secret Vault with decoy PIN, 30-day Trash bin, and offline AI Export Studio.

### 7.2 Key Technical Gaps for Future Adoption
1. **Audio Delay Synchronization UI**: Need to wire mpv `audio-delay` property to a user-facing slider and nudge buttons in `AudioStudioSheet` or player controls (matching the existing subtitle delay implementation).
2. **Dedicated Audio Track Switcher**: Need a dedicated popup selector for switching audio languages/tracks (similar to the subtitle menu).
3. **Desktop Keyboard Shortcuts**: Need a `Shortcuts` / `Actions` / `KeyboardListener` widget hierarchy in `PlayerScreen` for standard media player hotkeys (Space = pause, F = fullscreen, M = mute, Left/Right = seek 10s, Up/Down = volume, J/K = audio delay sync, G/H = sub delay sync).
4. **A-B Repeat Looping**: Timeline marker mechanism for looping segment A-B.
5. **Physical Media & Hardware Capture**: DVD/Blu-Ray playback and webcam/capture card inputs.
