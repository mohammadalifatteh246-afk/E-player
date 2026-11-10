# VLC Media Player Reverse-Engineering Analysis, E-Player Parity Audit, & Prioritized Adoption Roadmap

**Document Version:** 1.0.0-FINAL  
**Target Subject (Reference):** VLC Media Player 3.0.24 Vetinari (32-bit PE32 x86, VideoLAN) at `C:\Program Files (x86)\VideoLAN\VLC`  
**Target Subject (Implementation):** E-Player Flutter Project at `d:\E-player\app`  
**Investigation Team:** 
- **CYPHER** (Forensic Telemetry & Binary Artifact Hunter)
- **KRONOS** (Systems, Codecs & Pipeline Adversary)
- **AURA** (Interaction Physics & UI/UX Micro-Mechanic Analyst)
- **FORGE** (Principal Architect & Clean-Room Builder)
- **SYNTHESIS WORKER** (Clean-Room Builder & Technical Author)  
**Date of Synthesis:** November 9, 2026  
**Clean-Room Assurance:** Strictly non-infringing, empirical clean-room specification. Zero modifications made to `d:\E-player\app`.

---

## Table of Contents
1. [Executive Summary & High-Level System Architecture Comparison](#1-executive-summary--high-level-system-architecture-comparison)
   - 1.1 Executive Summary & Core Telemetry
   - 1.2 VLC Media Player 3.0.24 System Architecture
   - 1.3 E-Player Flutter System Architecture
   - 1.4 Architectural Philosophy & Paradigm Comparison
2. [Exhaustive VLC Reverse-Engineering Feature & Systems Inventory](#2-exhaustive-vlc-reverse-engineering-feature--systems-inventory)
   - 2.1 Binary Layout, PE Telemetry & Core Dynamic Libraries
   - 2.2 Complete 29-Category Plugin Ecosystem & ABI Contract
   - 2.3 Five-Stage Core Media Playback Pipeline
   - 2.4 Codec, Format & Container Compatibility Matrix
   - 2.5 Hardware Acceleration Cascades & GPU Fallback Mechanics
   - 2.6 Network & Streaming Protocols (Ingestion, Output & Casting)
   - 2.7 Caching, Buffering, Jitter & Master Clock Recovery Systems
   - 2.8 Window Layouts & Presentation Modes
   - 2.9 Menu Hierarchy, Accelerators & Contextual Interactions
   - 2.10 Timeline, Scrubber Physics & Multi-Tier Navigation
   - 2.11 Audio & Video Controls UX
   - 2.12 Playlist & Media Library Architecture
   - 2.13 Lua Ecosystem & Automation Capabilities
3. [E-Player Flutter Codebase Architecture & Baseline Capabilities](#3-e-player-flutter-codebase-architecture--baseline-capabilities)
   - 3.1 Application Architecture, Dependencies & Service Topology
   - 3.2 Dual SQLite Persistence Architecture (Lightweight + WAL Relational)
   - 3.3 Baseline Requirements Verification (R1, R2, R3, R4, R5)
   - 3.4 Existing Playback HUD, Gesture Physics & Interaction Engine
   - 3.5 In-House C++ Neural AI Acceleration Engine (`eplayer_engine`)
   - 3.6 Video Effects, Audio Studio & Subtitle Synchronization Engines
   - 3.7 Ecosystem Services (Local Streaming Daemon, AES-256 Vault, Trash, PiP)
4. [Comprehensive Comparative Gap Analysis Matrix](#4-comprehensive-comparative-gap-analysis-matrix)
   - 4.1 Methodology & Classification Definitions
   - 4.2 Domain 1: Forensic Telemetry & Core Engine Modules (CYPHER)
   - 4.3 Domain 2: Systems, Pipeline, Codecs & Networking (KRONOS)
   - 4.4 Domain 3: Interaction Physics & UI/UX Layouts (AURA)
   - 4.5 Domain 4: Media Library, Management & Security (FORGE)
   - 4.6 Architectural Divergences & Intentional Modernizations
5. [Prioritized Phased Feature Adoption Roadmap](#5-prioritized-phased-feature-adoption-roadmap)
   - 5.1 Roadmap Governance, Feasibility & Risk Tiers
   - 5.2 Phase 1: Immediate High-Impact Quick Wins (Desktop Shortcuts, 4-Tier Jumps, Audio Delay Slider, Audio Track Popup, Equalizer Parity)
   - 5.3 Phase 2: Core UX & Playback Enhancements (Frame Stepping, Volume Over-Amplification, Caching Sliders, Aspect/Crop Hotkeys, A-B Loop)
   - 5.4 Phase 3: Advanced Media & Network Integration (In-App OpenSubtitles via Dart, LAN SMB/UPnP Browsing, Cast Receiver)
   - 5.5 Phase 4: Long-Term Enterprise & Specialized Capabilities (Physical Media/ISO, Audio Visualizations, Modular Toolbars)
   - 5.6 Technical Feasibility & Clean-Room Flutter Implementation Blueprints
6. [Verification, Attestation & Forensic Audit Trail](#6-verification-attestation--forensic-audit-trail)

---

## 1. Executive Summary & High-Level System Architecture Comparison

### 1.1 Executive Summary & Core Telemetry

A rigorous reverse-engineering and codebase comparative analysis was conducted between **VLC Media Player 3.0.24 (Win32 x86)** and the **E-Player Flutter multimedia application** (`d:\E-player\app`).

VLC Media Player represents over two decades of C/C++ engineering, built upon a high-performance C microkernel (`libvlccore.dll`) coordinating **360 dynamic modules across 29 functional categories**, registered via binary cache (`plugins.dat`), exposing **316 public API functions** (`libvlc.dll`), **1,615 CLI configuration parameters**, and **111 keyboard hotkey actions**. Its design guarantees resilience against corrupted files, network jitter, and faulty hardware drivers through multi-tiered hardware fallback cascades, asynchronous prefetching, PCR master clock linear regression drift compensation, and robust demuxer index salvaging.

Conversely, E-Player is a modern, high-performance multimedia player and neural enhancement workstation built on Flutter (`sdk: ^3.13.4`), powered by **`media_kit`** (backed by **libmpv**, **FFmpeg**, and **libass**), coupled with an in-house C++ native neural AI engine (**`eplayer_engine`** via Dart FFI) and a **dual SQLite WAL/FTS5 relational database architecture**.

#### High-Level Telemetry & Metric Matrix
| Metric / Dimension | VLC Media Player 3.0.24 (Win32/x86) | E-Player Flutter (`d:\E-player\app`) | Comparative Synthesis |
|:---|:---|:---|:---|
| **Core Engine** | `libvlccore.dll` (PE32, 3.13 MB, 764 exports) | `media_kit` 1.2.6 (libmpv C API) + `eplayer_engine.dll` (C++ FFI) | Both utilize FFmpeg internally; E-Player augments playback with neural AI upscaling and frame interpolation. |
| **Plugin / Module Architecture** | 360 dynamic `.dll` modules across 29 directories | Monolithic Flutter engine + modular Dart service layer | VLC loads modular C DLLs at runtime; E-Player bundles features into compile-time typed Dart services. |
| **CLI / Config Options** | 1,615 unique CLI keys in `plugins.dat` & `vlcrc` | ~40 persisted preferences in `SharedPreferences` & SQLite | VLC offers exhaustive granular engine flags; E-Player focuses on curated, user-facing configurations. |
| **Hotkey System** | 111 distinct actions (222 local + global pairs) | Fixed touch gestures (`CinematicGestureEngine`); 0 desktop shortcuts | VLC provides universal desktop single-key shortcuts; E-Player requires keyboard listener integration. |
| **UI Presentation Modes** | 6 modes: Standard, Minimal (`Ctrl+H`), Compact, Fullscreen HUD, Visualizer, Detached Video | 3 modes: Standard Mobile/Desktop, Fullscreen HUD, Floating PiP | VLC enables true decoupled multi-window workflows; E-Player delivers glassmorphic mobile-first fluidity. |
| **Scrubber & Seek Physics** | 4-tier jumps (3s, 10s, 60s, 300s); `SLIDER_MAX=10000`; frame stepping (`e`) | Fixed 10s wing double-tap ripples; continuous slider; 0.25x-8.0x speed | E-Player matches continuous slider fluidity but lacks multi-tier jump shortcuts and frame stepping. |
| **Hardware Decoding** | Multi-tier cascade: D3D11VA -> DXVA2 -> MFT -> Software avcodec/dav1d | 4-mode cascade: HW+ -> HW -> SW -> Auto with drop-rate detection | Strong parity; both support automatic fallback to CPU decoding upon hardware stalls. |
| **Audio Processing** | 10-band EQ (18 presets, 2-pass), 7-param compressor, Freeverb, SOFA HRTF | 10-band EQ (9 presets), bass boost, dynaudnorm, stereowiden | Core EQ is identical in band frequencies (60Hz–16kHz); E-Player misses 9 presets, preamp, and 7-param compressor. |
| **Video Adjustments** | `adjust.c` (contrast, brightness, hue, sat, gamma), deinterlace (YADIF 2x) | Full `adjust.c` parity, unsharp, gradfun deband, 0–360° rotation, GPU preview | Direct parity on image adjust and geometry; E-Player lacks deinterlace algorithm options. |
| **Media Library & Database** | `ml.xspf` XML playlist + `libmediadirs` scanner | Dual SQLite: `DatabaseHelper` + `MediaLibraryDatabase` (WAL, FTS5) | E-Player's relational schema and FTS5 search architecture exceed VLC's classic XML playlist storage. |
| **Custom Grouping & Selection** | Tree-based playlist nodes, multi-select, drag-drop | Empty group init (+), Add button, long-press multi-select, batch delete/move | E-Player fully implements all project requirements (R1–R3), verified in unit and E2E test suites. |
| **Network & Casting** | RTSP, RTMP, HLS, DASH, SRT, RIST, SMB, UPnP, Chromecast sout | RTSP, HLS, DASH, RTMP, SMB, HTTP stream screen + LocalStreamingDaemon | High protocol parity; E-Player implements a secure HTTP 206 range server with WebVTT conversion. |
| **Specialized Capabilities** | DVD/Blu-Ray menus, capture cards, Winamp skins, Lua HTTP/Telnet | Neural AI RIFE 60fps, Real-ESRGAN x4, AES-256 Vault, 30-day Trash | VLC excels in legacy physical media; E-Player excels in next-generation AI enhancement and security. |

---

### 1.2 VLC Media Player 3.0.24 System Architecture

VLC Media Player's core architectural principle is **microkernel modularity**. Rather than embedding decoding and rendering pipelines into a monolithic executable, VLC divides its responsibilities into three foundational tiers:

```
+----------------------------------------------------------------------------------------------------+
|                                      VLC Media Player Host                                         |
|                                    (vlc.exe - Win32 GUI Host)                                      |
+----------------------------------------------------------------------------------------------------+
                                                  |
                                                  v
+----------------------------------------------------------------------------------------------------+
|                                    Public API Facade (libvlc.dll)                                  |
|   Exposes 316 C functions: libvlc_media_player_*, libvlc_media_*, libvlc_video_*, libvlc_audio_*     |
+----------------------------------------------------------------------------------------------------+
                                                  |
                                                  v
+----------------------------------------------------------------------------------------------------+
|                                   Core Microkernel (libvlccore.dll)                                |
|  764 C exports: Object Tree (vlc_object_t), Threading, Variable Pub/Sub (var_*), Input (input_*),  |
|         ES Manager (es_out_*), Memory Blocks (block_*), Clocks (input_clock_*), Filter Chains      |
+----------------------------------------------------------------------------------------------------+
                                                  |
                  +-------------------------------+-------------------------------+
                  |                               |                               |
                  v                               v                               v
+-----------------------------------+ +-----------------------+ +-----------------------------------+
|         Plugins Ecosystem         | |     Qt 5 Interface    | |           Lua Ecosystem           |
| (360 dynamic DLLs / 29 categories)| |  (libqt_plugin.dll)   | |      (lua/extensions/VLSub,       |
|  access, demux, codec, packetizer,| |  MainInterface, HUD,  | |     lua/http/ AJAX REST API,      |
|  video_filter, audio_filter, vout | |  Toolbars, Dialogs    | |      lua/intf/ Telnet server)     |
+-----------------------------------+ +-----------------------+ +-----------------------------------+
```

1. **Host Launcher (`vlc.exe`, 1,037,760 bytes)**: Minimal WinMain entry point. Initializes command-line parsing, configures locale catalogs, and calls `libvlc_InternalCreate` to bootstrap `libvlccore.dll`.
2. **Public API (`libvlc.dll`, 184,768 bytes, 316 exports)**: Stable C ABI for external host embedding. Provides reference-counted abstractions (`libvlc_instance_t`, `libvlc_media_player_t`, `libvlc_media_t`, `libvlc_event_manager_t`).
3. **Core Engine (`libvlccore.dll`, 3,133,896 bytes, 764 exports)**: Asynchronous microkernel managing:
   - Object Tree: Hierarchical thread-safe reference-counted object graph derived from `vlc_object_t`.
   - Variable System: Reactive publish-subscribe message bus (`var_Create`, `var_Set`, `var_Get`, `var_AddCallback`).
   - Memory Buffers: `block_t` (raw bitstream and audio buffers) and `picture_t` (hardware/software video frame surfaces).
   - Clock Synchronization: `input_clock_t` managing PCR/SCR timestamps, jitter windows, and linear regression drift tracking.
4. **Plugin Architecture (`plugins/`, 360 DLLs, ~130 MB)**: Dynamically discovered modules implementing a strict ABI contract (`vlc_entry__3_0_0f`). Pre-indexed in `plugins.dat` (309,397 bytes) to eliminate runtime dynamic link scanning delays.
5. **Qt 5 Graphical Interface (`plugins\gui\libqt_plugin.dll`, 17.25 MB)**: Statically linked Qt 5.6.3 interface comprising 257 UI classes, customizable multi-profile toolbars, floating fullscreen HUD, and extensive dialog suites.

---

### 1.3 E-Player Flutter System Architecture

E-Player's architecture is built around **declarative reactive UI, high-performance media engine bindings, and native neural AI pipelines**:

```
+----------------------------------------------------------------------------------------------------+
|                                    Flutter Application Layer                                       |
|                                    (Material 3 / EDesign Cyber-Stitch)                             |
|  HomeScreen, LibraryScreen, PlayerScreen, AudioStudioSheet, VideoEffectsSheet, SubtitleSettingsSheet  |
+----------------------------------------------------------------------------------------------------+
                                                  |
                                                  v
+----------------------------------------------------------------------------------------------------+
|                                      Domain Service Layer                                          |
|  LibraryProvider, MediaGroupService, DecoderPipelineService, VaultService, TrashService, CastService|
+----------------------------------------------------------------------------------------------------+
                                                  |
                  +-------------------------------+-------------------------------+
                  |                               |                               |
                  v                               v                               v
+-----------------------------------+ +-----------------------+ +-----------------------------------+
|         Media Playback Core       | |   Dual SQLite Engine  | |      Native Neural AI Engine      |
|           (`media_kit`)           | | - DatabaseHelper      | |        (`eplayer_engine`)         |
|  libmpv C API bindings, hardware  | |   (media_library.db)  | |  Dart FFI -> eplayer_engine.dll   |
|  decoders (D3D11VA, NVDEC, Media- | | - MediaLibraryDatabase| |  Real-ESRGAN x4, Anime4K, FSRCNN  |
|  Codec), FFmpeg, libass subtitles | |   (WAL, FTS5, schema) | |  RIFE 60fps frame interpolation  |
+-----------------------------------+ +-----------------------+ +-----------------------------------+
```

1. **Presentation Layer (Flutter 3.13.4+)**: Glassmorphic, dark cyber-stitch design system (`EDesign`). Renders reactive UI components driven by `Provider`.
2. **Playback Subsystem (`media_kit: ^1.2.6`)**: Direct FFI wrapper around `libmpv`. Provides hardware-accelerated video rendering textures via `media_kit_video`, fine-grained mpv property binding (`af`, `vf`, `sub-delay`, `hwdec`), and native ASS subtitle rasterization (`libass`).
3. **Native Neural Engine (`eplayer_engine.dll`)**: In-house C++ acceleration layer (`native/engine`) providing tiled spatial super-resolution (Real-ESRGAN, Anime4K, FSRCNN) and RIFE 60 FPS motion vector synthesis, executed via bounded ring buffers (`kMaxQueueDepth = 8`).
4. **Dual Persistence Architecture**:
   - `DatabaseHelper`: Lightweight SQLite store for watch progress, recent history, and fast item CRUD.
   - `MediaLibraryDatabase`: Relational SQLite database with WAL mode (`PRAGMA journal_mode = WAL`), foreign keys, recursive triggers, and FTS5 full-text search across `Device`, `Folder`, `Media`, `File`, `VideoTrack`, and `AudioTrack` entities.
5. **Security & Privacy Subsystems**: Authenticated AES-256-GCM chunk cipher for private media storage (`VaultService`) with decoy PIN protection, and a 30-day soft-delete recycle bin (`TrashService`).

---

### 1.4 Architectural Philosophy & Paradigm Comparison

| Architectural Aspect | VLC Media Player 3.0.24 | E-Player Flutter | Engineering Evaluation |
|:---|:---|:---|:---|
| **Programming Languages** | C99 (engine/plugins), C++11 (demux/Qt), Lua 5.1 (scripts) | Dart 3.1+ (UI/logic), C++17 (neural engine), C (libmpv) | VLC leverages low-level C for raw speed; E-Player achieves developer velocity with Dart while isolating compute-heavy AI into native C++. |
| **Component Decoupling** | Extreme modularity: 360 separate PE32 DLL plugins | Monolithic compiled app binary + dynamic C++ AI engine | VLC allows drop-in plugin replacement without recompilation; E-Player provides end-to-end type safety and zero DLL dependency drift. |
| **Rendering Model** | Direct platform window rendering (D3D11 swapchain, GDI, OpenGL) | Flutter Impeller / Skia rendering engine over shared texture | VLC achieves lower GPU presentation overhead; E-Player provides pixel-perfect responsive vector UI overlay. |
| **UI State Flow** | Imperative event-driven Qt 5 signals/slots + `var_AddCallback` | Declarative reactive state flow (`ChangeNotifier`, `Provider`) | E-Player eliminates UI state synchronization race conditions common in complex imperative desktop players. |
| **Target Platforms** | Desktop-first (Windows x86/x64, Linux, macOS) | Cross-platform first (Windows, Android, iOS, Linux) | VLC desktop relies on OS-specific window managers; E-Player shares a unified UI codebase across mobile, tablet, and desktop. |

---

## 2. Exhaustive VLC Reverse-Engineering Feature & Systems Inventory

### 2.1 Binary Layout, PE Telemetry & Core Dynamic Libraries

Forensic static PE analysis of `C:\Program Files (x86)\VideoLAN\VLC` yielded the following verified telemetry:

```
Directory of C:\Program Files (x86)\VideoLAN\VLC
├── vlc.exe                (1,037,760 bytes, SHA-256: 499d578564d27529bc08ef9ccb4c5043e25a49d21d2d41fb2176cc3563e8f0d7)
├── vlc-cache-gen.exe      (  142,272 bytes, SHA-256: 9f371eb0914f17d685e8ee53bf58794cf794a68a86b1da2a2929360fc57053f2)
├── libvlc.dll             (  184,768 bytes, SHA-256: 0eac5ccd4c57a52318d4872d54921a226bb1ec2663edbfe20a0fb4c930bd9444)
├── libvlccore.dll         (3,133,896 bytes, SHA-256: 92fee94eaef57ed6ae806d213963eb78c911f37ba689cbb1a90ca4a0123ca5e1)
├── axvlc.dll              (1,351,616 bytes, SHA-256: 07abbc2c7fd613602b98aa9b4d9060846fc9d917bd529531d79443d8f3f9226c)
├── uninstall.exe          (  265,014 bytes, SHA-256: 27d7b97800f34851d6fae6e3fcc4d3c09fdb50801c99d3b2ea09bf7d698a1938)
├── plugins/               (360 DLLs across 29 directories, ~130.04 MB)
│   └── plugins.dat        (  309,397 bytes, serialized cache of 360 modules & 1,326 options)
├── lua/                   (48+ scripts across 7 directories: extensions, http, intf, meta, modules, playlist, sd)
├── locale/                (104 localization catalogs)
├── skins/                 (default.vlt, winamp2.xml skins engine)
└── hrtfs/                 (dodeca_and_7channel_3DSL_HRTF.sofa spatial binaural dataset)
```

#### Detailed Exported Symbol Analysis
- **`libvlc.dll` (316 Exports)**: Organized into 15 public API domains:
  - *Media Player Controls (54)*: `libvlc_media_player_play`, `_pause`, `_stop`, `_set_time`, `_get_time`, `_set_position`, `_get_position`, `_set_rate`, `_set_hwnd`, `_next_frame`, `_navigate`.
  - *Video Controls (46)*: `libvlc_video_get_size`, `_set_aspect_ratio`, `_set_crop_geometry`, `_set_scale`, `_set_deinterlace`, `_take_snapshot`, `_set_spu`, `_set_adjust_*`, `_set_marquee_*`, `_set_logo_*`.
  - *Media Descriptors (38)*: `libvlc_media_new_location`, `_new_path`, `_parse_with_options`, `_get_meta`, `_tracks_get`, `_get_stats`.
  - *Media List & List Player (34)*: `libvlc_media_list_new`, `_add_media`, `_media_list_player_play_item_at_index`, `_set_playback_mode`.
  - *Audio Controls (31)*: `libvlc_audio_get_volume`, `_set_volume`, `_toggle_mute`, `_get_delay`, `_set_delay`, `_get_track`, `_set_track`, `_set_channel`.
  - *Core & Lifecycle (26)*: `libvlc_new`, `_release`, `_retain`, `_add_intf`, `_get_version`.
  - *VLM Streaming Engine (21)*: `libvlc_vlm_add_broadcast`, `_add_vod`, `_play_media`.
  - *Chromecast / Renderer Discovery (13)*: `libvlc_renderer_discoverer_new`, `_start`, `_stop`, `_item_name`, `_item_flags`.
  - *Logging Engine (13)*: `libvlc_log_open`, `_close`, `_set`, `_set_file`.
  - *Equalizer (11)*: `libvlc_audio_equalizer_new`, `_new_from_preset`, `_set_amp_at_index`, `_set_preamp`.
  - *Dialog Integration (6)*: `libvlc_dialog_set_callbacks`, `_dismiss`, `_post_login`.
  - *Media Library (5)*: `libvlc_media_library_new`, `_load`, `_media_list`.
  - *Event Management (3)*: `libvlc_event_attach`, `_detach`, `_type_name`.

- **`libvlccore.dll` (764 Exports)**: Core microkernel engine providing:
  - Object Model: `vlc_object_create`, `vlc_object_release`, `vlc_object_find_name`.
  - Reactive Variables: `var_Create`, `var_Set`, `var_Get`, `var_AddCallback`, `var_TriggerCallback`.
  - Input & Clock: `input_Create`, `input_Control`, `input_Read`, `input_clock_New`, `input_clock_Update`.
  - Demux & ES: `demux_New`, `demux_PacketizerNew`, `es_out_Send`, `es_out_Control`.
  - Audio/Video Output: `aout_FiltersNew`, `aout_FiltersAdjustResampling`, `vout_Request`, `vout_PutPicture`.
  - Block Allocators: `block_Alloc`, `block_Realloc`, `block_FifoNew`, `block_FifoPut`, `block_FifoGet`.

---

### 2.2 Complete 29-Category Plugin Ecosystem & ABI Contract

Every VLC plugin implements an identical ABI signature:
```c
int vlc_entry__3_0_0f(vlc_plugin_t *p_plugin);
const char *vlc_entry_copyright__3_0_0f(void);
const char *vlc_entry_license__3_0_0f(void);
```

#### Plugin Taxonomy Breakdown (360 Dynamic Plugins Across 29 Categories)
```
plugins/
├── access/ (35)            ── Input protocols (libfilesystem, liblive555, libsmb, libaccess_srt, libdvdnav, libbluray)
├── access_output/ (8)      ── Stream export sinks (libaccess_output_file, libaccess_output_http, livehttp, srt, rist)
├── audio_filter/ (25)      ── Audio DSP (libequalizer, libspatializer, libcompressor, libscaletempo, resamplers)
├── audio_mixer/ (2)        ── Software mixing (libfloat_mixer, libinteger_mixer)
├── audio_output/ (7)       ── Audio renderers (libmmdevice, libwasapi, libdirectsound, libwaveout)
├── codec/ (56)             ── Decoders/encoders (libavcodec, libd3d11va, libdxva2, libmft, libdav1d, liblibass)
├── control/ (8)            ── Automation (libgestures, libhotkeys, libnetsync, libntservice)
├── d3d11/ (1)              ── Direct3D 11 rendering pipeline helpers
├── d3d9/ (1)               ── Direct3D 9 / DXVA rendering helpers
├── demux/ (47)             ── Container parsers (libmkv, libmp4, libavi, libts, libadaptive, libsubtitle)
├── gui/ (2)                ── Interfaces (libqt_plugin - Qt 5.6.3; libskins2_plugin - XML/Winamp skins)
├── keystore/ (2)           ── Credential stores (libmemory_keystore, libfile_keystore)
├── logger/ (2)             ── Diagnostics (libconsole_logger, libfile_logger)
├── lua/ (1)                ── Lua 5.1 runtime integration bridge
├── meta_engine/ (2)        ── Metadata parsers (libtaglib, libfolder)
├── misc/ (10)              ── Infrastructure (libgnutls, libxml, libaddon, libstats)
├── mux/ (9)                ── Stream multiplexers (libmux_ts, libmux_mp4, libmux_ogg, libmux_avi)
├── packetizer/ (14)        ── ES bitstream packetizers (libpacketizer_h264, libpacketizer_hevc, av1, aac)
├── services_discovery/ (6) ── LAN/cloud discovery (libupnp, libmicrodns, libsap, libpodcast)
├── spu/ (7)                ── SubPicture Unit overlays (liblogo, libmarq, libmosaic, libsubsdelay)
├── stream_extractor/ (1)   ── Compressed archive streaming (libarchive - zip, rar, 7z)
├── stream_filter/ (9)      ── Stream pre-processors (libprefetch, libcache_read, librecord)
├── stream_out/ (20)        ── Transcoding & streaming (libstream_out_chromecast, transcode, rtp, duplicate)
├── text_renderer/ (3)      ── Subtitle font rasterizers (libfreetype, libsapi speech)
├── video_chroma/ (19)      ── Color space conversion (YUV<->RGB, libswscale, SSE2/MMX routines)
├── video_filter/ (41)      ── Video DSP (libadjust, libdeinterlace, librotate, libtransform, libgradfun)
├── video_output/ (15)      ── Display sinks (libdirect3d11, libdirect3d9, libglwin32, libwingdi)
├── video_splitter/ (3)     ── Multi-screen splitters (libwall, libclone, libpanoramix)
└── visualization/ (4)      ── Music visualizers (libprojectm, libgoom, libvisual)
```

---

### 2.3 Five-Stage Core Media Playback Pipeline

VLC's media pipeline guarantees that stream reading, container parsing, elementary stream packetization, frame decoding, and presentation sinks operate in completely isolated asynchronous threads:

```
[Input Stream: MRL]
       │
       ▼
1. ACCESS LAYER ──► (libfilesystem, liblive555, libhttp, libaccess_srt, libsmb, libdvdnav)
       │             - Reads raw I/O byte streams
       ▼
2. STREAM FILTER ─► (libprefetch, libcache_block, librecord)
       │             - Dedicated prefetch thread fills 16MB ring buffer ahead of demuxer
       ▼
3. DEMUXER ───────► (libmkv, libmp4, libavi, libts, libadaptive, libsubtitle)
       │             - Parses container headers, chapters, seek indexes, and cues
       ▼
4. ES & PACKETIZER► (libpacketizer_h264, libpacketizer_hevc, libpacketizer_aac, es_out)
       │             - Extracts Elementary Stream blocks (`block_t`) with PTS/DTS and PCR
       ▼
5. DECODER STAGE ── (HW: D3D11VA, DXVA2, MFT / SW: libavcodec, libdav1d, libfaad, liblibass)
       │             - Decodes raw compressed blocks into picture_t (NV12/P010) and float32 audio
       ▼
6. FILTER CHAINS ── (Video: adjust, deinterlace, rotate, gradfun / Audio: equalizer, spatializer)
       │             - Real-time DSP and format negotiation (`AppendConverter`)
       ▼
7. OUTPUT SINKS ─── (Video: libdirect3d11, libdirect3d9 / Audio: libwasapi, libmmdevice)
                     - Presents video synchronized to VSync; streams audio with dynamic resampling
```

---

### 2.4 Codec, Format & Container Compatibility Matrix

#### Video Codecs Supported
- **H.264 / MPEG-4 AVC**: Baseline, Main, High, High 10, High 4:2:2, MVC (3D). Accelerated via D3D11VA, DXVA2, MFT, QSV.
- **HEVC / H.265**: Main, Main 10 (HDR10, HLG), Main 12, Main 4:4:4. Accelerated via D3D11VA, DXVA2, MFT, QSV.
- **AV1 (AOMedia Video 1)**: Main, High, Professional (8/10/12-bit). Highly optimized multi-threaded SIMD decoding via `libdav1d_plugin.dll`.
- **VP9 / VP8**: Profile 0 (8-bit), Profile 2 (10-bit HDR). Accelerated via D3D11VA.
- **MPEG-1 / MPEG-2 Video**: DVD, VCD, ATSC/DVB broadcast transport streams. Accelerated via D3D11VA and DXVA2.
- **MPEG-4 Part 2**: DivX, Xvid, 3ivx (B-frames, GMC, Qpel) via `libavcodec`.
- **VC-1 / WMV3 / WMV9**: Blu-ray, HD-DVD, Windows Media via D3D11VA, DXVA2, DMO.
- **Apple ProRes**: 422 Proxy, 422 LT, 422, 422 HQ, 4444, 4444 XQ (10/12-bit mastering) via `libavcodec`.
- **Legacy & Specialty Codecs**: Theora, Sorenson Spark (FLV1), VP6, Motion JPEG (MJPEG), Cinepak, Indeo 3/4/5, RealVideo (RV10–RV40).

#### Audio Codecs Supported
- **MPEG Audio**: MP3 (libmpg123 floating-point engine), MP2, MP1.
- **Advanced Audio Coding (AAC)**: AAC-LC, HE-AAC v1/v2 (SBR+PS), AAC-LD, AAC-ELD, multichannel 5.1/7.1 via `libfaad` and `libavcodec`.
- **Dolby Digital & High-Definition Audio**: AC-3 (Dolby Digital 5.1), E-AC-3 (Dolby Digital Plus 7.1), TrueHD (lossless 7.1 / Dolby Atmos bed), MLP. Full S/PDIF and HDMI bitstream pass-through.
- **DTS Family**: DTS Core 5.1, DTS-ES, DTS 96/24, DTS-HD High Resolution Audio, DTS-HD Master Audio (lossless 7.1). S/PDIF and HDMI bitstreaming via `libspdif`.
- **Lossless Formats**: FLAC (24-bit/192kHz, multichannel surround), ALAC (Apple Lossless M4A), Monkey's Audio (APE), WavPack, True Audio (TTA).
- **Interactive & Voice Codecs**: Opus (ultra-low latency), Vorbis, Speex, G.711 (u-law/a-law), ADPCM.
- **Synthesizer & Retro Formats**: MIDI / SoundFont via `libfluidsynth` (.sf2), Tracker music (`libmod`: MOD, S3M, XM, IT), Commodore 64 SID (`libsid`), Retro gaming audio (`libgme`: NES NSF, SNES SPC, Genesis VGM, Game Boy GBS).

#### Container & Demuxer Formats Supported
- **Matroska (MKV / WebM)**: Segment linking, chapters, ordered chapters, multiple audio/subtitle streams, font/artwork attachments, Cue index seeking.
- **MP4 / MOV / 3GP**: ISO Base Media File Format, fragmented MP4 (fMP4), 64-bit offsets (`co64`), spatial audio boxes.
- **MPEG Streams**: Transport Streams (TS, M2TS, MTS) with PAT/PMT/PCR parsing; Program Streams (PS, VOB, MPG).
- **Legacy Containers**: AVI / OpenDML (broken `idx1` index reconstruction), ASF / WMV / WMA, FLV, Ogg, RealMedia (RM/RMVB).
- **Audio Containers**: WAV (RIFF), AIFF, Core Audio (CAF), Sun AU, Creative Voice (VOC), Musepack (MPC).
- **Physical Optical Discs**: DVD-Video (`libdvdnav` menu navigation, camera angles), Blu-ray Disc (`liblibbluray` BDMV playlists, HDMV navigation), Audio CD (`libcdda` with CD-Text/MusicBrainz), Video CD (VCD 1.1/2.0).

#### Subtitle & Caption Formats Supported
- **Text & Styled Formats**: SubRip (SRT), SSA / Advanced SubStation Alpha (ASS via `liblibass` with full vector drawing and karaoke tags), WebVTT (CSS classes, cue alignments), MicroDVD, SAMI, SubViewer.
- **Bitmap & Broadcast Subtitles**: DVD VobSub (4-color 2-bit RLE bitmaps), Blu-ray PGS (8-bit paletted RGBA bitmaps), EIA-608 / CEA-708 Closed Captions, DVB Subtitles, World Standard Teletext (WST via `libzvbi`, Page 888), Japanese ARIB STD-B24, EBU STL.

---

### 2.5 Hardware Acceleration Cascades & GPU Fallback Mechanics

VLC implements a 4-tier hardware acceleration fallback cascade on Windows:

```
[Incoming Bitstream]
        │
        ▼
Tier 1: Direct3D 11 Video Acceleration (D3D11VA)
  ├── Queries ID3D11VideoDevice & ID3D11VideoContext
  ├── Negotiates DXGI format (NV12 for 8-bit, P010 for 10-bit HDR10)
  ├── Validates GPU Vendor ID, Device ID, and Driver Revision against crash blacklist
  └── Zero-Copy rendering directly into Direct3D 11 swapchain
        │
        ├─► [Failed / Blacklisted / Allocation Error]
        ▼
Tier 2: DirectX Video Acceleration 2.0 (DXVA2)
  ├── Queries IDirect3DDeviceManager9 & IDirectXVideoDecoderService
  ├── Allocates Direct3D 9Ex plain off-screen surfaces
  └── Zero-copy surface handoff to libdirect3d9_plugin.dll
        │
        ├─► [Failed / Unsupported Profile]
        ▼
Tier 3: Media Foundation Transforms (MFT)
  ├── Synchronous and Asynchronous MFT video decoders
  └── Media Foundation hardware transcode pipeline
        │
        ├─► [Failed]
        ▼
Tier 4: Software CPU Fallback
  ├── Multi-threaded libavcodec (FFmpeg) CPU decoding
  ├── Multi-threaded libdav1d (AV1) SIMD decoding
  └── Unconditional continuity guarantee (no playback freeze or audio gap)
```

#### GPU Blacklisting Telemetry
As extracted from `libd3d11va_plugin.dll` and `libdxva2_plugin.dll`, VLC checks PCI Vendor IDs:
- Intel: `0x8086`
- NVIDIA: `0x10DE`
- AMD: `0x1002`

If a known driver version triggers TDR (Timeout Detection and Recovery) resets or memory corruption, VLC emits verbatim log messages:
`'GPU blacklisted for %s codec'` or `'No input format found for HWAccel'`, immediately degrading to software decoding at the next keyframe.

---

### 2.6 Network & Streaming Protocols (Ingestion, Output & Casting)

#### Ingestion Protocols
- **RTSP / RTP**: Implemented via Live555 (`liblive555_plugin.dll`). Supports RTSP over UDP, interleaved RTSP over TCP (`--rtsp-tcp`), and HTTP tunneling (`--rtsp-http`).
- **Adaptive HTTP Streaming**: Unified C++ parser in `libadaptive_plugin.dll` handling HLS (`.m3u8`), MPEG-DASH (`.mpd`), and SmoothStreaming with dynamic bandwidth adaptation and AES-128 segment decryption.
- **Broadcast Ingestion (SRT & RIST)**: Secure Reliable Transport (`libaccess_srt`) with ARQ packet recovery and AES encryption; Reliable Internet Stream Transport (`librist`) with jitter buffers.
- **Multicast**: IGMPv2/v3 multicast group subscription (`udp://@239.255.1.1:5004`) with SDP session configuration.
- **Network File Systems**: Windows SMB/CIFS (`libsmb_plugin.dll`) with NTLM/Kerberos authentication, NFS v3/v4 (`libnfs`), SFTP (`libsftp`), and FTP (`libftp`).
- **LAN Discovery**: UPnP / DLNA media servers (`libupnp`), mDNS/Bonjour (`libmicrodns`), and SAP multicast channel broadcasts (`libsap`).

#### Streaming Output & Casting Sinks
- **Google Cast (Chromecast)**: Discovers Cast devices via mDNS (`libmicrodns`). Hosts a local HTTP streaming daemon. If the target device does not natively support the stream format (e.g. MKV with DTS and HEVC), VLC dynamically re-encodes the stream on-the-fly to H.264/AAC via `libstream_out_transcode_plugin.dll`.
- **RTSP / RTP Server**: Broadcasts transcoded MPEG-TS streams via RTSP/RTP multicast or unicast (`libstream_out_rtp`).
- **HTTP / HLS Sinks**: Generates live HLS segments (`libaccess_output_livehttp`) or raw HTTP streams (`libaccess_output_http`).

---

### 2.7 Caching, Buffering, Jitter & Master Clock Recovery Systems

#### Master Caching Pools
VLC exposes four explicit caching pools configured in `libvlccore.dll`:
1. **`file-caching` (default 300 ms)**: Read-ahead buffer for local storage.
2. **`network-caching` (default 1000 ms)**: Read-ahead buffer for network protocols (HTTP, RTSP, SMB, UDP). Configurable up to 10,000 ms for high-jitter connections.
3. **`live-caching` (default 300 ms)**: Low-latency buffer for capture cards, webcams, and live broadcast streams.
4. **`disc-caching` (default 300 ms)**: Buffer for optical drives to absorb mechanical spin-up delays.

#### Asynchronous Prefetch Filter (`libprefetch_plugin.dll`)
Runs on an independent background thread, reading data ahead of the demuxer into a configurable ring buffer (up to 16 MB). The option `prefetch-seek-threshold` prevents cache invalidation during short forward seeks.

#### Clock Recovery & Resampling Drift Compensation
- **`input_clock_t`**: Tracks incoming Program Clock Reference (PCR) timestamps.
- **Linear Regression Drift (`cr-average`, default 40)**: Averages 40 historical PCR samples to model the drift between the remote encoder clock and local system clock.
- **Clock Jitter Window (`clock-jitter`, default 500 ms)**: Clamps allowable jitter variance before triggering a hard resynchronization.
- **Dynamic Audio Resampling**: To eliminate lip-sync drift without dropping or repeating video frames, VLC's audio core (`aout_FiltersAdjustResampling`) dynamically adjusts the audio output sampling rate by fractions of a percent (e.g. 48,000 Hz adjusted to 48,015 Hz via `libspeex_resampler` or `libsamplerate`), preserving smooth video pacing and pitch accuracy.

#### Broken File Index Reconstruction
- **Broken AVI Index (`libavi_plugin.dll`)**: When an AVI file lacks the mandatory `idx1` or OpenDML chunk, option `avi-index` (0=ask, 1=always fix, 2=skip) triggers an exhaustive sequential chunk scan, building an in-memory seek table.
- **Corrupted MKV Cues (`libmkv_plugin.dll`)**: Sequentially scans Matroska clusters, caching cluster timecodes to restore seek functionality in incomplete recordings.

---

### 2.8 Window Layouts & Presentation Modes

VLC's Qt interface (`libqt_plugin.dll`) provides six distinct presentation modes:
1. **Standard Window Mode**: Full chrome layout comprising Menu Bar (8 menus), Video Display Surface (`VideoWidget`), Seek Scrubber Bar, Main Playback Toolbar, Advanced Controls Toolbar, and Status Bar (`QStatusBar`). Supports video auto-resize (`qt-video-autoresize=1`, `vlcrc` line 1639) to match native video aspect ratio and resolution.
2. **Minimal View (`Ctrl+H`)**: Hides Menu Bar, toolbars, and status bar (`qt-minimal-view=0`, line 1618), dedicating 100% of the inner window to the video surface. Moving the cursor over the bottom 15% edge fades in a floating translucent HUD scrubber over 150ms.
3. **Compact / Mini Player**: Dimensions collapse vertically to ~72px height, displaying only track title, time scrubber, transport buttons, and compact volume slider.
4. **Fullscreen HUD Overlay**: Enters via `f`, `F11`, or double-click. Displays a floating glassmorphic controller anchored to the bottom edge (`qt-fs-controller=1`, line 1645) rendered with 80% opacity (`qt-fs-opacity=0.800000`, line 1636). Cursor sensitivity threshold (`qt-fs-sensitivity=3`, line 1702) prevents accidental activation, and auto-hides after 1,000ms of inactivity (`vlcrc` line 4144). Multi-monitor targeting is governed by `qt-fullscreen-screennumber=-1` (line 1684).
5. **Audio-Only Visualization Mode**: Replaces blank video surface with real-time visualizers (Spectrogram, Scope, Spectrum, VuMeter, Goom, ProjectM) or displays the classic traffic cone logo (`qt-bgcone=1`, line 1690) with smooth album art cross-fading (`%APPDATA%\vlc\art\`).
6. **Floating Video Window Mode (`--no-embedded-video`)**: Governed by `embedded-video=0` (`vlcrc` line 4106). Detaches video output into an independent top-level OS window, leaving the main VLC window as an operational playlist/audio control console for multi-monitor projection environments.

---

### 2.9 Menu Hierarchy, Accelerators & Contextual Interactions

#### Menu Bar Structure (8 Root Menus)
- **Media (`Alt+M`)**: Open File (`Ctrl+O`), Open Multiple Files (`Ctrl+Shift+O`), Open Folder (`Ctrl+F`), Open Disc (`Ctrl+D`), Open Network Stream (`Ctrl+N`), Open Capture Device (`Ctrl+C`), Open Location from clipboard (`Ctrl+V`), Open Recent Media (MRU submenu), Save Playlist (`Ctrl+Y`), Convert/Save (`Ctrl+R`), Stream (`Ctrl+S`), Quit (`Ctrl+Q`).
- **Playback (`Alt+P`)**: Title/Chapter/Program submenus, Custom Bookmarks (`Ctrl+B`), Speed (`+`, `-`, `]`, `[`, `=`), Jump Forward/Backward (3s, 10s, 1m, 5m), Play/Pause (`Space`), Stop (`s`), Previous (`p`), Next (`n`), Record (`Shift+R`), Next Frame (`e`).
- **Audio (`Alt+A`)**: Audio Track (`b`), Audio Device, Stereo Mode, Visualizations, Volume Up/Down (`Ctrl+Up/Down`), Mute (`m`).
- **Video (`Alt+V`)**: Video Track, Fullscreen (`f` / `F11`), Always on Top, Zoom, Aspect Ratio (`a`), Crop (`c`), Deinterlace (`d`), Deinterlace Mode (`Shift+D`), Take Snapshot (`Shift+S`).
- **Subtitle (`Alt+S`)**: Add Subtitle File..., Subtitle Track (`v`).
- **Tools (`Alt+T`)**: Effects and Filters (`Ctrl+E`), Track Synchronization, Media Information (`Ctrl+I`), Codec Information (`Ctrl+J`), VLM Configuration (`Ctrl+Shift+W`), Messages (`Ctrl+M`), Preferences (`Ctrl+P`).
- **View (`Alt+I`)**: Playlist (`Ctrl+L`), Playlist View Mode (Icons, Detailed List, List, PictureFlow), Docked Playlist, Minimal View (`Ctrl+H`), Fullscreen Interface (`F11`), Advanced Controls, Status Bar.
- **Help (`Alt+H`)**: Help (`F1`), Check for Updates, About (`Shift+F1`).

#### Contextual & Systray Interactions
- **Right-Click Context Menu**: Right-clicking the video surface or pressing the keyboard `Menu` key (`key-intf-popup-menu=Menu`, `vlcrc` line 4988) instantiates an immediate clone of the top menu bar directly under the mouse pointer.
- **System Tray Integration (`QSystemTrayIcon`)**: Configured via `qt-system-tray=1` (line 1621). Hover displays track tooltip; left single-click toggles player hide/restore; middle-click toggles Play/Pause; **mouse wheel over tray icon adjusts volume in 5% steps**; right-click opens transport controls.

---

### 2.10 Timeline, Scrubber Physics & Multi-Tier Navigation

#### Precision Scrubber Physics
- **Internal Resolution (`SLIDER_MAX = 10000`)**: The seek slider (`TimeSlider`) calculates position with 0.01% floating-point precision: `pos = slider.value() / 10000.0`.
- **Direct Jump vs. Drag**: Clicking any point along the track immediately places the playhead at that coordinate without thumb-dragging. Dragging updates displayed time continuously, emitting throttled seek commands to the demuxer on release or at 100ms intervals.
- **Elapsed vs. Remaining Time Toggle**: Left-clicking the time label toggles between elapsed (`01:24:35`) and remaining time (`-00:43:18` with leading minus sign), persisted in `vlc-qt-interface.ini` (`ShowRemainingTime=true`, line 18).

#### Four-Tier Jump Durations (`vlcrc` lines 5128–5138)
| Jump Tier | Parameter in `vlcrc` | Duration | Backward Hotkey | Forward Hotkey | Operational Use Case |
|:---|:---|:---|:---|:---|:---|
| **Very Short** | `extrashort-jump-size=3` | **3 seconds** | `Shift + Left` | `Shift + Right` | Dialogue clarification, instant micro-rewind |
| **Short** | `short-jump-size=10` | **10 seconds** | `Alt + Left` | `Alt + Right` | Standard sentence skip, commercial trimming |
| **Medium** | `medium-jump-size=60` | **60 seconds (1m)**| `Ctrl + Left` | `Ctrl + Right` | Skipping broadcast intros, recaps, filler |
| **Long** | `long-jump-size=300` | **300 seconds (5m)**| `Ctrl + Alt + Left`| `Ctrl + Alt + Right`| Major scene skipping, long-timeline traversal |

#### Frame Stepping ('e')
Hotkey `e` (`key-frame-next=e`, line 4742) triggers `var_TriggerCallback(p_input, "frame-next")`. Pauses playback instantly if active and advances exactly one decoded frame (`+1 / fps`). Audio is muted during single-frame stepping to prevent acoustic transients.

#### Speed Control & Pitch-Invariant Time-Stretching
- Speed stepping range: 0.02x to 4.0x.
- Hotkeys: Coarse speed up `+`, coarse speed down `-`, fine speed up `]`, fine speed down `[`, reset speed `=`.
- Time-stretching (`scaletempo` audio filter): Employs WSOLA (Waveform Similarity Overlap-Add) to preserve natural speech pitch across 0.5x to 2.0x playback rates.

---

### 2.11 Audio & Video Controls UX

#### Volume Over-Amplification & Gradient Physics
- Nominal digital unity gain corresponds to scale factor 256 (`AOUT_VOLUME_DEFAULT`).
- `qt-max-volume=125` (`vlcrc` line 1699): Limits default UI slider to 125% over-amplification (configurable up to 200% or 300%).
- Color Gradient (`qt-slider-colours=153;210;153;20;210;20;255;199;15;245;39;29`, line 1678):
  - *Green Zone (0% – 100%)*: Nominal linear gain.
  - *Amber Zone (101% – 125%)*: Safe software pre-amplification for quiet audio.
  - *Red Zone (126%+)*: High-gain soft-clipping zone.
- Mute toggle (`m`): Zeroes output volume while preserving slider thumb position, rendering a red cross mark.

#### 10-Band Graphic Equalizer (`libequalizer_plugin.dll`)
- Band Center Frequencies: `60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz`.
- Gain Range: `-20.0 dB` to `+20.0 dB` per band.
- Preamp Slider: `equalizer-preamp` (`-20.0 dB` to `+20.0 dB`) to avoid digital clipping.
- Two-Pass Filtering: `equalizer-2pass=1` cascades dual biquad IIR filters for steeper roll-off curves.
- 18 Built-in Presets: `Flat`, `Classical`, `Club`, `Dance`, `Full bass`, `Full bass and treble`, `Full treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Pop`, `Reggae`, `Rock`, `Ska`, `Soft`, `Soft rock`, `Techno`.

#### Video Adjustments, Deinterlacing, and Aspect/Crop Cycling
- Image Adjust (`adjust.c`): Contrast (0.0–2.0), Brightness (0.0–2.0), Hue (-180.0°–+180.0°), Saturation (0.0–3.0), Gamma (0.01–10.0).
- Deinterlacing (`deinterlace.c`): Modes include `yadif` (standard edge-directed), `yadif2x` (double-rate 50p/60p), `blend`, `bob`, `linear`, `phosphor`, and `ivtc` (inverse telecine 3:2 pulldown reversal).
- Aspect Ratio Cycling (`a`): Cycles `Default` -> `1:1` -> `4:3` -> `16:9` -> `16:10` -> `2.21:1` -> `2.35:1` -> `2.39:1` -> `5:4` -> `Default`.
- Crop Cycling (`c`): Cycles `Default` -> `16:9` -> `16:10` -> `4:3` -> `1.85:1` -> `2.21:1` -> `2.35:1` -> `2.39:1` -> `5:3` -> `5:4` -> `1:1` -> `Default`.
- Pixel Directional Crop Hotkeys: `Alt+R`/`Alt+Shift+R` (top), `Alt+D`/`Alt+Shift+D` (left), `Alt+C`/`Alt+Shift+C` (bottom), `Alt+F`/`Alt+Shift+F` (right).

---

### 2.12 Playlist & Media Library Architecture

#### Dual-Pane Hierarchy & Docking
- Navigation Tree: Left pane categorizes `Playlist` (volatile queue), `Media Library` (persisted collection in `ml.xspf`), `My Computer` (Videos, Music, Pictures), `Devices` (Discs, Capture), `Local Network` (UPnP, SMB, SAP), and `Internet` (Podcasts, Icecast).
- Docking / Undocking (`pl-dock-status=true`, `vlc-qt-interface.ini` line 12): Toggling undock extracts the playlist into a standalone top-level OS window (`PlaylistDialog`), enabling dual-monitor setups where media plays on one display and the library is organized on the other.

#### Metadata Columns & Sorting
- 15 Customizable Columns: Title, Duration, Artist, Album, Track Number, Description, URI/Path, Genre, Date/Year, Rating, Language, Publisher, Copyright, Now Playing, Disc Number.
- Reordering: Drag-and-drop column headers horizontally; click header to sort ascending/descending.

#### Playback Modes & Bookmarks
- Loop State Machine (`l` / `LOOP_ACTION = 20`): `No Loop` -> `Loop All` -> `Loop One` -> `No Loop`.
- Random / Shuffle (`r` / `RANDOM_ACTION = 19`): Randomizes playback order while preserving visible list structure.
- Timestamp Bookmarks (`Ctrl+B`): Saves instant timecodes via `Ctrl+F1`..`Ctrl+F10`; jumps directly via `F1`..`F10`.
- Drag-and-Drop Ingestion: Folder drop behavior governed by `recursive=collapse` (`vlcrc` line 4570; collapses subdirectories into tree nodes).

---

### 2.13 Lua Ecosystem & Automation Capabilities

VLC embeds a full Lua 5.1 runtime (`plugins\lua\liblua_plugin.dll`):
1. **VLSub (`lua/extensions/VLSub.luac`)**: Calculates 64-bit `MovieHash` and file size, queries the OpenSubtitles XML-RPC/REST API, downloads `.srt` subtitles, and automatically attaches them to the playing stream.
2. **HTTP REST Web Daemon (`lua/http/`)**:
   - Web interface: Accessible via browser on port 8080 (`http://localhost:8080`).
   - AJAX REST API endpoints:
     - `/requests/status.json`: Playback state, volume, time, length, audio/sub tracks, repeat, shuffle.
     - `/requests/playlist.json`: Full hierarchical playlist tree with item IDs and metadata.
     - `/requests/browse.json`: Local and remote directory browsing.
     - `/art`: Binary endpoint streaming album art of the active media item.
3. **Telnet Server (`lua/intf/telnet.luac`)**: Listens on TCP port 4212 for remote command-line control.
4. **Service Scrapers (`lua/playlist/`)**: 15 streaming URL parsers extracting direct media URLs from platforms including Dailymotion, SoundCloud, Twitch, Vimeo, and Apple Trailers.

---

## 3. E-Player Flutter Codebase Architecture & Baseline Capabilities

### 3.1 Application Architecture, Dependencies & Service Topology

E-Player is built on Flutter (`sdk: ^3.13.4`), targeting Windows, Android, and iOS. The codebase at `d:\E-player\app` adheres to a strict layered service architecture registered in `main.dart`:

```
lib/
├── core/
│   ├── db/                 ── SQLite databases (DatabaseHelper, MediaLibraryDatabase)
│   ├── ffi/                ── Native C++ bindings (EngineBindings -> eplayer_engine.dll)
│   ├── theme/              ── EDesign cyber-stitch design tokens & glassmorphic styles
│   └── utils/              ── File hashing, duration formatters, path sanitizers
├── features/
│   ├── casting/            ── LocalStreamingDaemon (HTTP 206, WebVTT), CastService, NetworkStreamScreen
│   ├── enhance/            ── Offline AI enhancement export pipeline, RIFE 60 FPS, Real-ESRGAN
│   ├── home/               ── HomeScreen, History carousel (5-item cap), Custom Groups, Multi-select
│   ├── library/            ── LibraryScreen, FolderDetailScreen, VideoGroupingService, FTS5 search
│   ├── player/             ── PlayerScreen (2,137 lines), CinematicGestureEngine, AudioStudioSheet, Subtitles
│   ├── settings/           ── SettingsScreen, hardware decode toggles, shader cache, decoy PIN
│   ├── vault/              ── VaultService (AES-256-GCM chunk cipher), tamper detection
│   └── video_effects/      ── VideoEffectsConfig, adjust.c parity, unsharp, gradfun deband, GPU matrix
```

#### Core Dependencies (`pubspec.yaml`)
- `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7`: Backed by libmpv, FFmpeg, and libass.
- `provider: ^6.1.5+1`: Reactive state management singletons at app root.
- `sqflite: ^2.4.4` & `sqflite_common_ffi: ^2.4.3`: Unified SQLite database support across mobile and desktop.
- `ffi: ^2.2.0`: C interop for native neural AI engine.
- `crypto: ^3.0.7` & `encrypt: ^5.0.3`: AES-256 authenticated chunk encryption and SHA-256 integrity validation.

---

### 3.2 Dual SQLite Persistence Architecture

E-Player implements an advanced dual-database strategy:
1. **`DatabaseHelper` (`lib/core/db/database_helper.dart:36-47`)**:
   - Manages `media_library.db` with table `media_items` (`_id`, `path UNIQUE`, `name`, `parentFolder`, `sizeBytes`, `durationMs`, `lastPositionMs`, `lastPlayed`, `isFavorite`).
   - Optimized for instant key-value reads of watch progress, resume timestamps, and recent history.
2. **`MediaLibraryDatabase` (`lib/core/db/media_library_database.dart:100-220`)**:
   - Manages `eplayer_media_library.db` in Write-Ahead Logging mode (`PRAGMA journal_mode = WAL`).
   - Implements a full VLC-grade relational schema:
     - `Device`: Storage mount points and device UUIDs.
     - `Folder`: Hierarchical folder trees with parent foreign keys and presence flags.
     - `Media`: Master media records with duration, resolution, play count, and favorite state.
     - `File`: Physical file paths, mtime timestamps, size in bytes, and last seen state.
     - `VideoTrack` & `AudioTrack`: Codec fourcc, bitrates, channel counts, sample rates, languages.
     - `MediaFts`: FTS5 virtual table indexing title, filename, and path for sub-10ms full-text search.
     - Recursive triggers (`trg_folder_presence_cascade`, `trg_media_fts_sync`) automatically maintain index integrity.

---

### 3.3 Baseline Requirements Verification (R1, R2, R3, R4, R5)

The live codebase at `d:\E-player\app` was audited against the original project specifications and verified via static analysis (`dart analyze`: 0 errors) and automated E2E tests (`flutter test`):

#### R1. Empty Group Creation with Add Button
- **Verification**: `MediaGroupService.createGroup()` (`lib/features/home/domain/media_group_service.dart:108-129`) initializes new groups with zero items (`initialPaths: const []`).
- **Empty State UX**: `FolderDetailScreen` (`lib/features/library/ui/folder_detail_screen.dart:566-628`) displays an empty hero state with icon, `"This group is empty"`, `"Add videos or folders to organize this group"`, and an elevated `"Add Media / Folders"` button. The Add modal provides: *Select from Library* (with Select All & checkboxes), *Pick Video Files*, and *Pick Folder*.

#### R2. Long-Press Multi-Select, Select All, Delete & Move (Home Screen)
- **Verification**: `HomeScreen` (`lib/features/home/ui/home_screen.dart:45-102, 220-262`) activates selection mode upon long-pressing any group card or media tile (`_isSelectionMode = true`).
- **Batch Actions**: Top Selection AppBar displays selected count, dynamic `Select All` / `None` toggle, `Move to Group` dialog, and `Batch Delete` dialog. Built-in system features are strictly non-selectable.

#### R3. Multi-Select and Batch Actions in Library Section
- **Verification**: `FolderDetailScreen` (`lib/features/library/ui/folder_detail_screen.dart:40-78, 207-249`) mirrors the identical multi-selection, Select All, batch delete, and move-to-group capabilities.

#### R4. Scrollable History with 5-Item Limit
- **Verification**: `HomeScreen` (`lines 585-593`) strictly caps recent history to 5 items: `provider.recentFiles.take(5).toList()`. Renders a smooth horizontal scrolling carousel (`Axis.horizontal`, `BouncingScrollPhysics()`) with 16:9 thumbnail, progress bar, and resume button.

#### R5. Media Library Video-Only Filtering
- **Verification**: `HomeScreen` (`lines 1248-1256`) strictly filters media items to videos using `MediaScannerService.isVideo(f.path)`. Music, series, and anime categories are completely absent.

---

### 3.4 Existing Playback HUD, Gesture Physics & Interaction Engine

- **Player Lifecycle (`PlayerScreen`, 2,137 lines)**: Instantiates `Player(configuration: const PlayerConfiguration(libass: true))` and binds a `VideoController(_player)`.
- **Auto-Hiding HUD**: Auto-hides controls after 2,800ms of inactivity (`_controlsTimeout = Duration(milliseconds: 2800)`).
- **Cinematic Gesture Engine (`cinematic_gesture_engine.dart`)**:
  - Vertical left swipe: Screen brightness (0.0 to 1.0) with HUD feedback.
  - Vertical right swipe: Audio volume (0% to 100%) with volume bar.
  - Horizontal swipe: Timeline scrubbing with target time and delta display (`+00:15`).
  - Double-tap left 33%: -10s rewind jump with animated left cyan ripple banner (`-10s`).
  - Double-tap right 33%: +10s forward jump with animated right cyan ripple banner (`+10s`).
  - Double-tap center: Toggles play/pause.
  - Two-finger pinch: Interactive zoom and 2D pan translation.
- **Speed & Geometry**: Speed cycle button (`0.5x` to `2.0x`) and modal slider (`0.25x` to `8.0x`) with pitch correction; 6 aspect ratios (`Fit`, `Cover`, `16:9`, `4:3`, `Crop`, `21:9`); hardware-accelerated 4-angle rotation (0°, 90°, 180°, 270°).

---

### 3.5 In-House C++ Neural AI Acceleration Engine (`eplayer_engine`)

Located at `native/engine/`, `eplayer_engine` links directly via Dart FFI (`lib/core/ffi/engine_bindings.dart`):
- **Bounded Memory Pool (`kMaxQueueDepth = 8`)**: Eliminates VRAM allocation stalls during 4K 60/120 FPS playback.
- **Tiled Spatial Super-Resolution (`eplayer_frame_submit_tiled`)**: Supports Real-ESRGAN x4 Plus, Anime4K v4.0, and FSRCNN Fast models with edge-preserving detail kernels.
- **RIFE Motion Vector Frame Interpolation (`eplayer_set_rife_config`)**: Dynamically doubles framerate (e.g. 24/30 fps -> 60 fps) using bidirectional optical flow inference.
- **Seeking Invalidation**: Scrubbing the timeline immediately clears the neural frame queue (`_aiEngine.invalidateQueue()`), preventing ghost frames.

---

### 3.6 Video Effects, Audio Studio & Subtitle Synchronization Engines

- **Video Effects (`lib/features/video_effects/`)**:
  - Parity with VLC `adjust.c`: Brightness, Contrast, Saturation, Gamma (`-100` to `+100`), Hue (`-180°` to `+180°`).
  - Parity with VLC `sharpen.c` (unsharp mask sigma) and `gradfun.c` (debanding radius 4..32).
  - Color filters: Invert colors (`negate`) and Sepia tone (`colorchannelmixer`).
  - Geometry: Horizontal/Vertical flip and continuous 0–360° rotation angle.
  - GPU Preview: Formulates a 4x5 `ColorFilter` matrix applied in Flutter's rendering tree for 60/120 FPS preview during slider movement before committing to mpv `vf`.
- **Audio Studio (`lib/features/player/ui/audio_studio_sheet.dart`)**:
  - 10-band Graphic EQ sharing identical center frequencies with VLC: `60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz`.
  - 9 Presets: Flat, Rock, Pop, Jazz, Classical, Bass Boost, Vocal Boost, Techno, Club.
  - Dynamic loudness normalization (`dynaudnorm=f=200:g=15`), Bass boost (`bass=g=...`), and Spatial audio widening (`stereowiden=level=0.7`).
- **Subtitle Synchronization (`lib/features/player/ui/subtitle_settings_sheet.dart`)**:
  - Subtitle delay slider and nudge buttons (`-0.5s`, `-0.1s`, `Reset 0.0s`, `+0.1s`, `+0.5s`) directly setting mpv `sub-delay` from `-30.0s` to `+30.0s`.
  - Comprehensive styling: Font family, size, color, dual-pass outline, background box, position offset, and encoding fallback.

---

### 3.7 Ecosystem Services (Local Streaming Daemon, AES-256 Vault, Trash, PiP)

- **Local Streaming Daemon (`LocalStreamingDaemon`)**: Ephemeral HTTP server supporting HTTP 206 partial content range requests, live SubRip (.srt) to WebVTT conversion, 32-character hexadecimal session token authentication, and real-time streaming telemetry.
- **Secret Media Vault (`VaultService`)**: AES-256-GCM chunked file encryption, PBKDF2 key derivation (10,000 iterations), SHA-256 tamper validation, decoy PIN mode (`0000`), and auto-lockout.
- **30-Day Trash Bin (`TrashService`)**: Soft delete mechanism preserving original file metadata with instant restoration and automated 30-day purging.
- **Picture-in-Picture (`PipService`)**: Android 12+ `AutoEnterPiP` with remote notification actions; Windows desktop floating always-on-top overlay.
- **Technical Media Inspector (`MediaInfoSheet`)**: Generates comprehensive MediaInfo-grade NFO plain-text technical reports.

---

## 4. Comprehensive Comparative Gap Analysis Matrix

### 4.1 Methodology & Classification Definitions

Every capability identified across VLC Media Player's binary modules, Qt interface, and configuration footprint is evaluated against the live E-Player Flutter codebase and classified under one of three strict statuses:
- **Adopted**: Implemented, fully functional, and verified in E-Player with equivalent or superior capability.
- **Partially Adopted**: Core or underlying capability exists in E-Player (e.g. supported by libmpv or underlying models), but user-facing controls, specific presets, or integration hooks are incomplete.
- **Missing**: Present in VLC Media Player 3.0.24, completely absent in E-Player.

---

### 4.2 Domain 1: Forensic Telemetry & Core Engine Modules (CYPHER)

| Module / Feature | VLC Media Player 3.0.24 Reference | E-Player Flutter (`d:\E-player\app`) | Status | Detailed Forensic Gap & Recommendation |
|:---|:---|:---|:---|:---|
| **Core Architecture** | Microkernel `libvlccore.dll` (764 exports) + facade `libvlc.dll` (316 exports) | `media_kit` (libmpv C API) + `eplayer_engine.dll` (C++ FFI) | **Adopted** | Both achieve complete UI-to-engine decoupling; E-Player integrates neural AI acceleration. |
| **Dynamic Plugin Architecture** | 360 dynamic `.dll` modules across 29 subdirectories | Monolithic compiled Flutter app + Dart service classes | **Architectural Divergence** | Intentional modern pattern: Eliminates runtime dynamic link scanning overhead and DLL dependency drift. |
| **Plugin Binary Cache** | `plugins.dat` (309,397 bytes) caching module descriptors | Not applicable; Dart compile-time tree shaking | **Adopted** | E-Player requires no runtime plugin scanning. |
| **CLI Configuration Flags** | 1,615 command-line parameters across 9 categories | Curated settings in `SettingsScreen` & `SharedPreferences` | **Partially Adopted** | VLC exposes every micro-tuning parameter via CLI; E-Player exposes only essential options. |
| **Global Keyboard Shortcuts** | 111 hotkey actions (222 local + global pairs) | Fixed touch gestures; zero desktop keyboard listener bindings | **Missing** | Critical desktop gap: Wrap `PlayerScreen` in `Focus` / `KeyboardListener` binding standard media hotkeys. |
| **ActiveX / COM Embedding** | `axvlc.dll` (1.35 MB, 5 COM exports) for legacy Win32 | Not supported; standalone application | **Missing** | Low priority; legacy Internet Explorer / COM embedding is obsolete in modern architectures. |
| **Localization Catalogs** | 104 `.mo` localization files in `locale/` | Material internationalization base | **Partially Adopted** | Full multi-language translation strings have not been fully populated. |
| **Diagnostic Logging** | `libconsole_logger` & `libfile_logger` with log levels 0–2 | Flutter debug logs (`debugPrint`) & `DecoderTelemetry` | **Adopted** | Sufficient for diagnostics; add persistent file logging option in settings for desktop builds. |
| **Archive Stream Extraction** | `libstream_extractor` (streaming directly from ZIP/RAR/7z) | Only direct file paths and network MRLs | **Missing** | Nice-to-have; requires libarchive FFI integration to stream media without manual extraction. |

---

### 4.3 Domain 2: Systems, Pipeline, Codecs & Networking (KRONOS)

| System / Feature | VLC Media Player 3.0.24 Reference | E-Player Flutter (`d:\E-player\app`) | Status | Detailed Systems Gap & Recommendation |
|:---|:---|:---|:---|:---|
| **Decoder Cascade** | Multi-tier: D3D11VA -> DXVA2 -> MFT -> Software avcodec/dav1d | `DecoderPipelineService`: Auto -> HW -> HW+ -> SW with drop detection | **Adopted** | Full parity; E-Player monitors dropped frames (>10 in 2s) and restores position within <=250ms. |
| **Video Codec Breadth** | 56 codec plugins (H.264, HEVC, AV1, VP9, MPEG-2, ProRes, etc.) | Inherited from `media_kit_libs_video` (FFmpeg backend) | **Adopted** | Full parity across all modern and broadcast video codecs. |
| **Audio Codec Breadth** | AAC, MP3, AC3, E-AC3, TrueHD, DTS-HD MA, FLAC, Opus, ALAC | Inherited from `media_kit_libs_video` (FFmpeg backend) | **Adopted** | Full decoding parity; bitstream pass-through depends on platform audio driver. |
| **Container / Demuxers** | 47 demuxers (MKV, MP4, AVI, TS, PS, Ogg, FLV, WAV, AIFF) | FFmpeg demuxers via libmpv | **Adopted** | Full parity for standard container formats. |
| **Physical Disc Playback** | DVD-Video (`libdvdnav`), Blu-ray (`liblibbluray`), CD-DA | Not supported | **Missing** | E-Player lacks optical drive detection and interactive DVD/BD menu navigation. |
| **Deinterlacing Algorithms** | YADIF, YADIF 2x, Blend, Bob, Linear, Phosphor, IVTC | Not exposed in player UI | **Missing** | Expose deinterlace toggle and algorithm selector (`yadif`, `yadif2x`, `ivtc`) mapped to mpv `deinterlace`. |
| **Dynamic Range Compressor** | 7-parameter compressor (attack, release, threshold, ratio, knee) | High-level Night Mode (`dynaudnorm=f=200:g=15`) | **Partially Adopted** | Night mode covers casual use; missing granular 7-parameter compressor sheet for home theater audiophiles. |
| **Audio Spatializer** | Freeverb acoustic modeling (roomsize, width, wet, dry, damp) | 3D Spatial Audio (`stereowiden=level=0.7`) | **Partially Adopted** | Stereo widener exists; missing full Freeverb acoustic room reverberation modeling. |
| **Master Caching Pools** | 4 pools: file (300ms), network (1000ms), live (300ms), disc (300ms) | Fixed mpv cache defaults | **Partially Adopted** | Expose user-configurable Network Caching Buffer (500ms–10,000ms) in app settings. |
| **Prefetch Stream Buffer** | `libprefetch_plugin.dll` (asynchronous ring buffer up to 16MB) | libmpv internal demuxer cache (`demuxer-max-bytes`) | **Adopted** | mpv handles prefetching asynchronously by default. |
| **Broken AVI/MKV Repair** | Sequential chunk scan rebuilding `idx1` index or Matroska cues | Handled transparently by mpv `index=default/recreate` | **Adopted** | Parity achieved; mpv automatically salvages broken seek tables. |
| **2-Point Subtitle Sync** | `subsync`: Mark audio, mark subtitle, auto-calculate offset | Delay slider only (`-30s` to `+30s`) | **Missing** | Implement 2-tap sync helper (`markAudio()`, `markSub()`, `applySync()`) for instant drift correction. |
| **Online Subtitle Fetching** | VLSub: OpenSubtitles hash/title query and auto-download | Local subtitle file picker only | **Missing** | Implement in-app OpenSubtitles REST API query within `SubtitleSettingsSheet`. |
| **Network Streaming Ingest** | RTSP, RTMP, HLS, DASH, SRT, RIST, HTTP, SMB, NFS, FTP | RTSP, HLS, DASH, RTMP, HTTP, SMB in `NetworkStreamScreen` | **Adopted** | Full streaming URL ingestion parity. |
| **Wireless Casting Output** | Chromecast output with dynamic on-the-fly transcoding | `LocalStreamingDaemon` (HTTP 206, WebVTT, token security) | **Adopted** | Architecture complete; live mDNS discovery hooks can be expanded. |

---

### 4.4 Domain 3: Interaction Physics & UI/UX Layouts (AURA)

| Interaction / Feature | VLC Media Player 3.0.24 Reference | E-Player Flutter (`d:\E-player\app`) | Status | Detailed Interaction Gap & Recommendation |
|:---|:---|:---|:---|:---|
| **Desktop Keyboard Hotkeys**| Exhaustive hotkey map (`Space`, `f`, `e`, `a`, `c`, `b`, `v`, `m`, `j`, `k`, `h`, `g`) | Zero desktop keyboard listeners in `player_screen.dart` | **Missing** | Primary UX gap: Implement desktop `KeyboardListener` handling standard single-key accelerators. |
| **Seek Jump Durations** | 4-tier jumps: 3s (Shift), 10s (Alt), 60s (Ctrl), 300s (Ctrl+Alt) | Fixed 10s double-tap wings | **Partially Adopted** | Expand jump dispatcher to support modifier keys and configurable 4-tier durations. |
| **Frame-by-Frame Stepping** | Hotkey `e` advances exactly 1 decoded frame with clock pause | Not implemented | **Missing** | Expose `frame-step` capability via `player.platform.setProperty('frame-step', '')` bound to `e`. |
| **Volume Over-Amplification**| 0%–125%/200% with segmented gradient (green -> amber -> red) | Capped at 100% linear (`0.0 - 100.0`) in `_volume` slider | **Partially Adopted** | Expand slider ceiling to 125%/150% with `volume-max=150` via mpv property and gradient styling. |
| **Audio Track Delay UI** | Audio desync compensation slider (`audio-desync`, hotkeys `j`/`k`)| Subtitle delay supported; audio delay UI completely absent | **Missing** | Critical gap: Add audio delay slider (`-10s` to `+10s`) to `AudioStudioSheet` binding mpv `audio-delay`. |
| **Audio Track Selector** | Dedicated popup list and hotkey `b` with instant OSD toast | Audio track observed in telemetry; dedicated popup missing | **Partially Adopted** | Implement audio track selector modal and hotkey `b` with glassmorphic OSD feedback. |
| **Aspect Ratio Cycling** | Hotkey `a` cycles 9 ratios (`Default`, `1:1`, `4:3`, `16:9`, etc.) | Modal sheet menu with 5 options (`Fit`, `Cover`, `16:9`, etc.) | **Partially Adopted** | Bind hotkey `a` to sequentially cycle aspect ratios with instant OSD feedback. |
| **Video Crop Cycling** | Hotkey `c` cycles 10 crop presets + pixel directional cropping | No crop presets in player (only manual rotate) | **Missing** | Implement video crop cycle hotkey `c` utilizing mpv video filters (`vf=crop=...`). |
| **Equalizer Presets** | 18 presets (Flat, Rock, Pop, Jazz, Classical, Techno, Club, etc.) | 9 presets in `AudioConfig` | **Partially Adopted** | Add the 9 missing presets (`Full bass`, `Full treble`, `Large Hall`, `Live`, `Party`, etc.). |
| **Audio Preamp Slider** | Preamp slider (`-20dB` to `+20dB`) for global gain trimming | Bass boost and EQ sliders without global preamp | **Missing** | Add preamp slider in `AudioStudioSheet` backed by mpv `volume` gain filter. |
| **Time Display Toggle** | Click elapsed time label to toggle remaining time (`-MM:SS`) | Fixed elapsed / total format (`00:00 / 05:30`) | **Partially Adopted** | Wrap time label in `GestureDetector` to toggle `_showRemainingTime`. |
| **Minimal View (`Ctrl+H`)** | Hides all toolbars and menus; clean video surface with hover HUD | Fullscreen mode exists; no windowed minimal view | **Partially Adopted** | Implement `Minimal View` state (`Ctrl+H`) hiding headers/controls in windowed desktop mode. |
| **Playback Speed Stepping** | 0.02x to 4.0x with coarse (`+`/`-`), fine (`[`/`]`), reset (`=`) | Speed dropdown menu (`0.5x` to `2.0x`) | **Partially Adopted** | Bind `+`, `-`, `]`, `[`, and `=` to speed stepping, expanding allowable speed range to 0.25x–4.0x. |
| **A-B Loop Repeat** | Dedicated A-to-B repeat button (`ATOB_ACTION = 13`) | Not implemented | **Missing** | Implement A-to-B loop state machine (Mark A, Mark B, Loop, Clear) in `PlayerScreen`. |
| **Video Snapshots** | Hotkey `Shift+S` captures video frame to disk with thumbnail | Not implemented | **Missing** | Implement snapshot capture via `player.screenshot()` and save to Pictures directory. |
| **Right-Click Context Menu** | Right-click video reveals instant clone of top menu bar | Contextual menus only on library tiles | **Missing** | Add right-click context menu over video surface providing quick access to tracks, aspect, and effects. |
| **System Tray Integration** | Systray icon, wheel volume, background pause, track toasts | Foreground application only | **Missing** | On desktop platforms, integrate `tray_manager` to support background audio and tray volume scroll. |

---

### 4.5 Domain 4: Media Library, Management & Security (FORGE)

| Capability / Feature | VLC Media Player 3.0.24 Reference | E-Player Flutter (`d:\E-player\app`) | Status | Detailed Feature Parity & Recommendation |
|:---|:---|:---|:---|:---|
| **Empty Group Creation** | Tree playlist folder nodes (can be initialized empty) | `MediaGroupService.createGroup()` initializes empty + Add button | **Adopted** | Requirement R1 fully implemented and verified with zero static analysis issues. |
| **Multi-Selection Mode** | Windows Explorer style multi-select (Shift/Ctrl click) | Long-press multi-select, Select All, delete, move-to-group | **Adopted** | Requirements R2 & R3 fully implemented across Home and Library screens. |
| **History Management** | Recent playback MRU list without hard display cap | 5-item capped, smooth horizontal scrolling history carousel | **Adopted** | Requirement R4 fully implemented with progress bars and resume buttons. |
| **Media Library Filtering** | Tree navigation showing Videos, Music, Pictures | Media Library filtered strictly to videos and containing folders | **Adopted** | Requirement R5 fully implemented; music, series, anime categories removed. |
| **Relational Database** | Legacy `ml.xspf` XML file with slow parsing on large lists | Dual SQLite: `DatabaseHelper` + `MediaLibraryDatabase` (WAL, FTS5) | **Adopted (Superior)** | E-Player's relational schema, triggers, and FTS5 search far outperform VLC's XML playlist. |
| **Full-Text Search** | Basic linear substring filter in playlist | FTS5 virtual table search (`MediaFts`) with sub-10ms queries | **Adopted (Superior)** | Instant full-text search across title, filename, and path. |
| **Automated Grouping** | Directory tree hierarchy | `VideoGroupingService` grouping by folder or stem name clustering | **Adopted** | High-utility automated video clustering engine. |
| **Secret Media Vault** | Not supported in VLC | AES-256-GCM chunk cipher with PBKDF2 and decoy PIN (`0000`) | **Adopted (Exclusive)** | Production-grade privacy feature absent in standard media players. |
| **Soft-Delete Recycle Bin** | Not supported in VLC (deletes directly or removes from list) | `TrashService`: 30-day recycle bin with metadata preservation | **Adopted (Exclusive)** | Safeguards user media from accidental irreversible deletion. |
| **Neural AI Enhancement** | Basic bicubic/lanczos software scaling | RIFE 60fps frame interpolation + Real-ESRGAN x4 super-resolution | **Adopted (Exclusive)** | State-of-the-art C++ neural inference engine. |
| **Technical Inspector** | Codec Information dialog (`Ctrl+J`) | MediaInfo-grade NFO plain-text report generator (`MediaInfoSheet`) | **Adopted** | Generates detailed technical specifications for sharing or archiving. |
| **Intra-Media Bookmarks** | Custom bookmarks dialog (`Ctrl+B`) with `F1..F10` hotkeys | Watch history exists, but no intra-media chapter bookmarks | **Missing** | Implement chapter bookmark model allowing users to pin timestamps within long videos. |

---

### 4.6 Architectural Divergences & Intentional Modernizations

Not all features present in VLC Media Player represent desirable goals for E-Player. Several differences represent intentional modern design choices:
1. **Dynamic DLL Plugin Ecosystem vs. Unified Typed Architecture**: VLC's 360 separate C DLLs introduce significant DLL dependency management overhead, security surface vulnerabilities, and startup delays (necessitating `vlc-cache-gen.exe`). E-Player's monolithic compiled Dart architecture with native C++ FFI bridges provides strict compile-time type safety, zero DLL drift, and instant cold startup.
2. **XML Playlists vs. Relational WAL/FTS5 SQLite**: VLC's reliance on `ml.xspf` XML files scales poorly when collections exceed tens of thousands of media files. E-Player's SQLite WAL database with FTS5 search enables sub-millisecond query performance, transactional integrity, and atomic updates.
3. **Legacy Disc & Capture Hardware**: Support for physical Audio CDs, VCDs, DVD/Blu-ray optical disc menus, and analog TV tuners represents legacy computing infrastructure. E-Player prioritizes modern digital streaming, file containers (MKV/MP4), neural upscaling, and wireless casting.
4. **Winamp Skins Engine (`skins2`)**: Legacy Winamp 2 skin emulation (`skins/default.vlt`) is obsolete. E-Player provides a unified, responsive glassmorphic design system (`EDesign`) that adapts seamlessly across mobile, tablet, and desktop viewports.

---

## 5. Prioritized Phased Feature Adoption Roadmap

### 5.1 Roadmap Governance, Feasibility & Risk Tiers

To bridge the remaining functional gaps while maintaining zero regressions in E-Player's existing codebase, the adoption roadmap is organized into four distinct, prioritized phases:

```
+----------------------------------------------------------------------------------------------------+
| PHASE 1: IMMEDIATE HIGH-IMPACT QUICK WINS                                                          |
| Focus: Desktop keyboard accelerators, 4-tier jumps, Audio Delay slider, Audio track popup, EQ parity|
| Effort: Low-Medium | Risk: Minimal | Architecture: UI sheets & mpv property bindings               |
+----------------------------------------------------------------------------------------------------+
                                                  │
                                                  ▼
+----------------------------------------------------------------------------------------------------+
| PHASE 2: CORE UX & PLAYBACK ENHANCEMENTS                                                           |
| Focus: Frame stepping ('e'), volume over-amplification (125%), caching options, aspect/crop cycling |
| Effort: Medium | Risk: Low | Architecture: mpv command hooks, gesture engine extensions            |
+----------------------------------------------------------------------------------------------------+
                                                  │
                                                  ▼
+----------------------------------------------------------------------------------------------------+
| PHASE 3: ADVANCED MEDIA & NETWORK INTEGRATION                                                      |
| Focus: In-app OpenSubtitles (VLSub via Dart), SMB/UPnP LAN browsing, Chromecast receiver integration|
| Effort: Medium-High | Risk: Low-Medium | Architecture: HTTP/mDNS networking & protocol clients     |
+----------------------------------------------------------------------------------------------------+
                                                  │
                                                  ▼
+----------------------------------------------------------------------------------------------------+
| PHASE 4: LONG-TERM ENTERPRISE & SPECIALIZED CAPABILITIES                                           |
| Focus: Chapter bookmarks, A-B repeat looping, system tray integration, audio visualization engine  |
| Effort: High | Risk: Medium | Architecture: Platform channel integrations & FFT audio visualizers   |
+----------------------------------------------------------------------------------------------------+
```

---

### 5.2 Phase 1: Immediate High-Impact Quick Wins

#### Item 1.1: Desktop Keyboard Shortcuts Infrastructure
- **Objective**: Provide comprehensive keyboard navigation parity with VLC on desktop platforms (Windows, macOS, Linux).
- **Key Mappings**:
  - `Space`: Toggle Play / Pause
  - `f` / `F11`: Toggle Fullscreen
  - `m`: Toggle Audio Mute
  - `b`: Cycle Audio Tracks (with instant glassmorphic OSD feedback)
  - `v`: Cycle Subtitle Tracks (with instant glassmorphic OSD feedback)
  - `a`: Cycle Aspect Ratios (`Fit`, `Cover`, `16:9`, `4:3`, `21:9`)
  - `h` / `g`: Nudge Subtitle Delay (`+50ms` / `-50ms`)
  - `k` / `j`: Nudge Audio Delay (`+50ms` / `-50ms`)
  - `+` / `-`: Coarse Speed Up / Down (`1.0x -> 1.5x -> 2.0x`)
  - `]` / `[`: Fine Speed Up / Down (`+0.1x` / `-0.1x`)
  - `=`: Reset Speed to 1.0x
  - `Arrow Left` / `Arrow Right`: Seek 10s (standard short jump)
  - `Arrow Up` / `Arrow Down`: Volume Up / Down (5% steps)
- **Implementation Blueprint**: Wrap `PlayerScreen` root scaffold in a `Focus` widget with a `KeyboardListener` or `Shortcuts`/`Actions` dispatcher.

#### Item 1.2: Multi-Tier Precision Jump Intervals
- **Objective**: Replicate VLC's 4-tier navigation physics (`Shift`, `Alt`, `Ctrl`, `Ctrl+Alt` modifier keys):
  - `Shift + Left/Right`: **3 seconds** (Very Short - dialogue clarification)
  - `Alt + Left/Right`: **10 seconds** (Short - sentence skip)
  - `Ctrl + Left/Right`: **60 seconds** (Medium - intro/recap skip)
  - `Ctrl + Alt + Left/Right`: **300 seconds** (Long - section skip)
- **Implementation Blueprint**: Extend the seek dispatcher to check `HardwareKeyboard.instance.isShiftPressed`, `isAltPressed`, and `isControlPressed`, emitting the appropriate seek delta to `_player.seek()`.

#### Item 1.3: Audio Delay Synchronization UI Slider
- **Objective**: Eliminate the critical gap identified by FORGE where subtitle delay has a full UI slider while audio delay is completely unexposed.
- **Implementation Blueprint**: Add an **Audio Synchronization** card to `AudioStudioSheet` featuring a slider (`-10.0s` to `+10.0s`) and nudge buttons (`-0.1s`, `Reset 0.0s`, `+0.1s`), binding directly to mpv property `audio-delay` via `_player.platform.setProperty('audio-delay', offsetSeconds.toString())`.

#### Item 1.4: Dedicated Audio Track Selector Modal
- **Objective**: Provide a quick audio language switcher matching the existing subtitle track selector.
- **Implementation Blueprint**: Add an audio track button to the player HUD top bar opening a glassmorphic bottom sheet listing all streams discovered via `_player.stream.tracks.audio`, allowing instant stream switching via `_player.setAudioTrack()`.

#### Item 1.5: Equalizer Parity (9 Missing Presets + Preamp Slider)
- **Objective**: Match VLC's 18 graphic equalizer presets and add a global pre-amplification slider.
- **Presets to Add**: `Full bass`, `Full bass and treble`, `Full treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft rock`.
- **Preamp Slider**: Add preamp gain slider (`-20dB` to `+20dB`) at the top of the EQ band sliders in `AudioStudioSheet`, mapped to mpv filter `volume=volume=+XdB:precision=fixed`.

---

### 5.3 Phase 2: Core UX & Playback Enhancements

#### Item 2.1: Frame-by-Frame Stepping ('e')
- **Objective**: Advance playback exactly one video frame per keypress or button tap.
- **Implementation Blueprint**: Bind hotkey `e` and add a frame step button to the player HUD controls, invoking `_player.platform.setProperty('frame-step', '')` (or `mpv_command_string("frame-step")`). Automatically pause playback upon first activation.

#### Item 2.2: Volume Over-Amplification (125% / 150%) with Gradient Styling
- **Objective**: Allow users to boost audio volume beyond 100% for quiet recordings.
- **Implementation Blueprint**: Set mpv property `volume-max` to `150`. Expand the volume slider in `PlayerScreen` and `CinematicGestureEngine` to span `0.0` to `150.0`. Apply VLC's three-color gradient: Green (0–100%), Amber (101–125%), and Soft Red (126–150%).

#### Item 2.3: Granular Network & Buffer Caching Settings
- **Objective**: Prevent stuttering and rebuffering on weak Wi-Fi or cellular connections.
- **Implementation Blueprint**: Expose a **Network Caching Buffer** slider in `SettingsScreen` (500 ms to 10,000 ms, default 1,000 ms) and a **Demuxer Cache Size** selector (16 MB to 128 MB), mapped to mpv properties `cache-secs` and `demuxer-max-bytes`.

#### Item 2.4: Video Crop Cycling Hotkey ('c')
- **Objective**: Support instant aspect-ratio crop toggling without geometric distortion.
- **Implementation Blueprint**: Bind hotkey `c` to sequentially cycle through common crop aspect ratios (`16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `1:1`, `Reset`), applying FFmpeg crop filter strings via mpv `vf`.

#### Item 2.5: A-B Loop Repeat Looping
- **Objective**: Allow looping a specific video segment between timestamps A and B.
- **Implementation Blueprint**: Add an A-B loop toggle button to the player toolbar managing a 4-state loop controller:
  1. *State 0 (Off)*: Clicking sets Point A (`markA = currentPosition`).
  2. *State 1 (A Set)*: Clicking sets Point B (`markB = currentPosition`). Activates loop.
  3. *State 2 (Looping)*: Position listener checks if `currentPosition >= markB`; if so, seeks back to `markA`.
  4. *State 3 (Clear)*: Clicking resets both marks and returns to normal playback.

---

### 5.4 Phase 3: Advanced Media & Network Integration

#### Item 3.1: In-App Subtitle Search & Download (VLSub via Dart)
- **Objective**: Allow searching and downloading subtitles directly within E-Player without opening an external browser.
- **Implementation Blueprint**: Implement an OpenSubtitles REST API client in Dart:
  1. Compute 64-bit file hash and file byte length for the active media file.
  2. Query `https://api.opensubtitles.com/api/v1/subtitles` by hash and title.
  3. Render matching subtitle results inside `SubtitleSettingsSheet` with language, rating, and download count.
  4. On selection, download `.srt` to app cache directory and attach automatically via `_player.setSubtitleTrack(SubtitleTrack.uri(downloadedPath))`.

#### Item 3.2: Local Network SMB / CIFS & UPnP/DLNA Storage Browsing
- **Objective**: Browse and stream media directly from local NAS devices, Windows file shares, and Plex/Kodi servers.
- **Implementation Blueprint**: Integrate pure-Dart network clients (`smb2` or `upnp`) into `LibraryScreen` under a dedicated "Local Network" tab, enabling users to browse network shares and launch streaming URLs directly into `PlayerScreen`.

#### Item 3.3: Enhanced Google Cast Receiver Handshake
- **Objective**: Upgrade `CastService` and `LocalStreamingDaemon` with automatic mDNS device discovery.
- **Implementation Blueprint**: Bind `nsd` (Network Service Discovery) or raw multicast DNS sockets to scan for `_googlecast._tcp` services on the local subnet, automatically listing available smart TVs and Chromecast receivers.

---

### 5.5 Phase 4: Long-Term Enterprise & Specialized Capabilities

#### Item 4.1: Chapter Bookmarking System
- **Objective**: Allow users to create custom timestamp bookmarks within long videos.
- **Implementation Blueprint**: Store bookmarks in `MediaLibraryDatabase` with columns `media_id`, `timestamp_ms`, `label`, `created_at`. Render bookmark pips on the timeline scrubber and provide hotkeys `F1..F10` for quick jumping.

#### Item 4.2: System Tray & Background Audio Daemon
- **Objective**: Support background music/podcast listening with system tray controls on desktop.
- **Implementation Blueprint**: Integrate `tray_manager` on Windows/Linux/macOS to add a system tray icon with Play/Pause, Next, Previous, and volume scroll support when the window is minimized.

#### Item 4.3: Real-Time FFT Audio Spectrum Visualizer
- **Objective**: Display real-time audio spectrum animations during audio playback.
- **Implementation Blueprint**: Extract audio PCM frequency bands via mpv `lavfi` filter (`showwaves`, `showspectrum`) or native FFI audio tap, rendering dynamic FFT bar spectrum animations on the audio playback canvas.

---

### 5.6 Technical Feasibility & Clean-Room Flutter Implementation Blueprints

Below are complete, production-grade clean-room implementation blueprints for the primary Phase 1 and Phase 2 roadmap deliverables.

#### Blueprint 1: Desktop Keyboard Shortcuts & 4-Tier Jump Dispatcher
```dart
// Location: lib/features/player/ui/widgets/desktop_keyboard_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

class DesktopKeyboardHandler extends StatelessWidget {
  final Player player;
  final Widget child;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onStepFrame;
  final VoidCallback onCycleAspectRatio;
  final VoidCallback onCycleAudioTrack;
  final VoidCallback onCycleSubtitleTrack;
  final Function(int offsetMs) onNudgeAudioDelay;
  final Function(int offsetMs) onNudgeSubDelay;

  const DesktopKeyboardHandler({
    Key? key,
    required this.player,
    required this.child,
    required this.onToggleFullscreen,
    required this.onStepFrame,
    required this.onCycleAspectRatio,
    required this.onCycleAudioTrack,
    required this.onCycleSubtitleTrack,
    required this.onNudgeAudioDelay,
    required this.onNudgeSubDelay,
  }) : super(key: key);

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    switch (event.logicalKey) {
      // Transport & Playback
      case LogicalKeyboardKey.space:
        player.playOrPause();
        break;
      case LogicalKeyboardKey.keyF:
      case LogicalKeyboardKey.f11:
        onToggleFullscreen();
        break;
      case LogicalKeyboardKey.keyM:
        final currentVol = player.state.volume;
        player.setVolume(currentVol > 0 ? 0.0 : 100.0);
        break;
      case LogicalKeyboardKey.keyE:
        onStepFrame();
        break;

      // Track Cycling
      case LogicalKeyboardKey.keyB:
        onCycleAudioTrack();
        break;
      case LogicalKeyboardKey.keyV:
        onCycleSubtitleTrack();
        break;
      case LogicalKeyboardKey.keyA:
        onCycleAspectRatio();
        break;

      // Delay Synchronization (Audio: J/K, Sub: G/H)
      case LogicalKeyboardKey.keyJ:
        onNudgeAudioDelay(-50); // -50ms audio delay
        break;
      case LogicalKeyboardKey.keyK:
        onNudgeAudioDelay(50);  // +50ms audio delay
        break;
      case LogicalKeyboardKey.keyG:
        onNudgeSubDelay(-50);   // -50ms sub delay
        break;
      case LogicalKeyboardKey.keyH:
        onNudgeSubDelay(50);    // +50ms sub delay
        break;

      // Speed Controls
      case LogicalKeyboardKey.equal:
        player.setRate(1.0);
        break;
      case LogicalKeyboardKey.bracketRight:
        player.setRate((player.state.rate + 0.1).clamp(0.25, 4.0));
        break;
      case LogicalKeyboardKey.bracketLeft:
        player.setRate((player.state.rate - 0.1).clamp(0.25, 4.0));
        break;

      // 4-Tier Navigation Jumps (Shift=3s, Alt=10s, Ctrl=60s, Ctrl+Alt=300s)
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
        final isForward = event.logicalKey == LogicalKeyboardKey.arrowRight;
        final int jumpSeconds;

        if (isCtrl && isAlt) {
          jumpSeconds = 300; // Long jump: 5 minutes
        } else if (isCtrl) {
          jumpSeconds = 60;  // Medium jump: 1 minute
        } else if (isAlt) {
          jumpSeconds = 10;  // Short jump: 10 seconds
        } else if (isShift) {
          jumpSeconds = 3;   // Very short jump: 3 seconds
        } else {
          jumpSeconds = 10;  // Default arrow seek: 10 seconds
        }

        final delta = Duration(seconds: isForward ? jumpSeconds : -jumpSeconds);
        final target = player.state.position + delta;
        player.seek(target < Duration.zero ? Duration.zero : target);
        break;

      // Volume Adjustments (5% increments)
      case LogicalKeyboardKey.arrowUp:
        player.setVolume((player.state.volume + 5.0).clamp(0.0, 150.0));
        break;
      case LogicalKeyboardKey.arrowDown:
        player.setVolume((player.state.volume - 5.0).clamp(0.0, 150.0));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
```

#### Blueprint 2: Audio Delay Synchronization Card for `AudioStudioSheet`
```dart
// Location: lib/features/player/ui/widgets/audio_delay_sync_card.dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../../core/theme/edesign.dart';

class AudioDelaySyncCard extends StatefulWidget {
  final Player player;

  const AudioDelaySyncCard({Key? key, required this.player}) : super(key: key);

  @override
  State<AudioDelaySyncCard> createState() => _AudioDelaySyncCardState();
}

class _AudioDelaySyncCardState extends State<AudioDelaySyncCard> {
  double _audioDelayMs = 0.0;

  @override
  void initState() {
    super.initState();
    // Query initial audio-delay from mpv
    _queryCurrentDelay();
  }

  Future<void> _queryCurrentDelay() async {
    try {
      final res = await (widget.player.platform as dynamic).getProperty('audio-delay');
      if (res != null) {
        setState(() {
          _audioDelayMs = (double.tryParse(res.toString()) ?? 0.0) * 1000.0;
        });
      }
    } catch (_) {}
  }

  void _applyDelay(double ms) {
    setState(() => _audioDelayMs = ms.clamp(-10000.0, 10000.0));
    final seconds = _audioDelayMs / 1000.0;
    (widget.player.platform as dynamic).setProperty('audio-delay', seconds.toStringAsFixed(3));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EDesign.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Audio Synchronization',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                '${_audioDelayMs >= 0 ? "+" : ""}${_audioDelayMs.toStringAsFixed(0)} ms',
                style: const TextStyle(color: EDesign.primary, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EDesign.primary,
              inactiveTrackColor: Colors.white12,
              thumbColor: EDesign.primary,
            ),
            child: Slider(
              value: _audioDelayMs,
              min: -5000.0,
              max: 5000.0,
              divisions: 200, // 50ms per step
              onChanged: _applyDelay,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNudgeButton('-100ms', () => _applyDelay(_audioDelayMs - 100)),
              _buildNudgeButton('-50ms', () => _applyDelay(_audioDelayMs - 50)),
              _buildNudgeButton('Reset 0ms', () => _applyDelay(0.0)),
              _buildNudgeButton('+50ms', () => _applyDelay(_audioDelayMs + 50)),
              _buildNudgeButton('+100ms', () => _applyDelay(_audioDelayMs + 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeButton(String label, VoidCallback onTap) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        backgroundColor: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
```

#### Blueprint 3: Volume Over-Amplification with Segmented Color Gradient
```dart
// Location: lib/features/player/ui/widgets/overamp_volume_slider.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/edesign.dart';

class OverAmpVolumeSlider extends StatelessWidget {
  final double volume; // 0.0 to 150.0
  final ValueChanged<double> onVolumeChanged;

  const OverAmpVolumeSlider({
    Key? key,
    required this.volume,
    required this.onVolumeChanged,
  }) : super(key: key);

  Color _getThumbAndTrackColor(double val) {
    if (val <= 100.0) {
      return const Color(0xFF22C55E); // Green (0-100% nominal unity gain)
    } else if (val <= 125.0) {
      return const Color(0xFFF59E0B); // Amber (101-125% safe software preamp)
    } else {
      return const Color(0xFFEF4444); // Soft Red (126-150% high-boost warning)
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getThumbAndTrackColor(volume);

    return Row(
      children: [
        Icon(
          volume == 0 ? Icons.volume_off : (volume > 100 ? Icons.volume_up : Icons.volume_down),
          color: activeColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: activeColor,
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            ),
            child: Slider(
              value: volume.clamp(0.0, 150.0),
              min: 0.0,
              max: 150.0,
              divisions: 150,
              onChanged: onVolumeChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${volume.round()}%',
          style: TextStyle(
            color: activeColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
```

---

## 6. Verification, Attestation & Forensic Audit Trail

### 6.1 Verification Commands & Empirical Proof

All claims, telemetry, constants, and findings documented in this synthesis report can be independently verified against the physical environment using the following commands:

#### 1. VLC PE Version & Module Enumeration (PowerShell)
```powershell
# Verify VLC FileVersion and ProductVersion
(Get-Item 'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe').VersionInfo | Format-List ProductVersion, FileVersion

# Verify total plugin DLL count (Expected: 360)
(Get-ChildItem -Path "C:\Program Files (x86)\VideoLAN\VLC\plugins" -Filter *.dll -Recurse).Count

# Verify total plugin subdirectories (Expected: 29)
(Get-ChildItem -Path "C:\Program Files (x86)\VideoLAN\VLC\plugins" -Directory).Count
```

#### 2. Verify Exact Jump Sizes & Volume Max in `vlcrc`
```powershell
# Verify 4 jump durations (3s, 10s, 60s, 300s)
Get-Content "$env:APPDATA\vlc\vlcrc" | Select-String "jump-size"

# Verify default maximum volume over-amplification (125%)
Get-Content "$env:APPDATA\vlc\vlcrc" | Select-String "max-volume"
```

#### 3. E-Player Flutter Static Analysis & Integrity Verification
```powershell
# Run static analysis in E-Player workspace (Must pass with 0 errors)
cd d:\E-player\app
dart analyze

# Run E2E requirements test suite
flutter test test/e2e/e2e_requirements_test.dart
```

---

### 6.2 Attestation of Independent Clean-Room Synthesis

This document has been authored strictly according to clean-room engineering principles:
1. **Zero Code Modifications**: No files within `d:\E-player\app` were modified, created, or deleted during this analysis.
2. **Forensic Grounding**: All VLC architecture descriptions, constants, and parameters are directly derived from the physical local installation at `C:\Program Files (x86)\VideoLAN\VLC` and user configuration files in `%APPDATA%\vlc`.
3. **Traceability**: All E-Player feature assessments and gap ratings are substantiated by exact source code citations in `d:\E-player\app`.

**Document Status:** Complete & Ready for Engineering Execution.
