# VLC Media Player 3.0.24 (Win32/x86) — Exhaustive Forensic Telemetry & Binary Artifact Inventory

**Investigator:** CYPHER (The Evaluator - Forensic Telemetry & Artifact Hunter)  
**Target Environment:** `C:\Program Files (x86)\VideoLAN\VLC`  
**VLC Shipped Version:** 3.0.24 Vetinari (32-bit PE32 x86, GCC 6.4.0, Qt 5.6.3 static)  
**Timestamp:** 2026-11-09T09:45:00Z  
**Methodology:** Reverse-Engineer-Anything (REA) Static & Metadata Forensic Extraction  

---

## Executive Summary

This document establishes the comprehensive forensic telemetry and binary artifact inventory of VLC Media Player 3.0.24 (x86). VLC's architecture represents a modular dynamic plugin microkernel (`libvlccore.dll`) exposing a standardized high-level API (`libvlc.dll`) orchestrating 360 dynamic modules across 29 functional categories, controlled via an extensive Qt 5 interface (`plugins\gui\libqt_plugin.dll`), a legacy XML/Winamp skins engine (`skins2`), a rich Lua scripting ecosystem, 1,615 CLI options, and a comprehensive 111-action hotkey system.

### High-Level Statistics Matrix
| Dimension | Observed Count / Metric | Details |
|---|---|---|
| **Core Binaries** | 6 root executables & DLLs | `vlc.exe`, `vlc-cache-gen.exe`, `uninstall.exe`, `libvlc.dll`, `libvlccore.dll`, `axvlc.dll` |
| **Total Plugin DLLs** | 360 dynamic plugins | Distributed across 29 subdirectories under `plugins/` |
| **Total Plugins Disk Size** | ~130.04 MB | Largest category: `codec` (38.56 MB), `access` (22.01 MB), `gui` (18.68 MB) |
| **Plugin ABI Contract** | Version `3_0_0f` | All modules export `vlc_entry__3_0_0f`, `vlc_entry_copyright__3_0_0f`, `vlc_entry_license__3_0_0f` |
| **LibVLC API Exports** | 316 exported C functions | Complete high-level media playback, list, library, audio, video, equalizer, chromecast API |
| **LibVLCcore Core Exports**| 764 exported C functions | Internal microkernel engine (object tree, vars, input, aout, vout, sout, spu, blocks) |
| **CLI Option Flags** | 1,615 unique CLI parameters | 9 major operational categories (audio, video, sout, demux, qt, hotkeys, codecs) |
| **Keyboard Hotkeys** | 111 actions (222 local + global) | Full keyboard shortcut mapping covering navigation, jumps, audio, video, subs, bookmarks |
| **Qt UI Subsystem** | 257 UI classes, 30 Qt options | Embedded Qt 5.6.3 static build, 6 toolbar layout profiles, floating HUD, extended effects |
| **Lua Ecosystem** | 7 functional domains, 48+ files | VLSub subtitle fetcher, full HTTP REST daemon, Telnet server, 15 playlist parsers, 4 art scrapers |
| **Localization & Spatial** | 104 languages, SOFA HRTF | 104 `.mo` catalogs in `locale/`, 3D binaural headphone audio profile (`hrtfs/`) |

---

## 1. Binary Layout & Core Executables / Dynamic Libraries

VLC's root directory contains the core execution pipeline. The player separates the GUI launcher (`vlc.exe`) from the public API (`libvlc.dll`) and the underlying playback engine (`libvlccore.dll`).

### Root Binary Directory Inventory
| Binary Name | Size (Bytes) | SHA-256 Digest | PE Format | Machine | Exports | Primary Role |
|---|---|---|---|---|---|---|
| `vlc.exe` | 1,037,760 | `499d578564d27529bc08ef9ccb4c5043e25a49d21d2d41fb2176cc3563e8f0d7` | PE32 | x86 (0x14c) | 1 | Win32 GUI Host & Launcher (subsystem: Windows GUI) |
| `vlc-cache-gen.exe` | 142,272 | `9f371eb0914f17d685e8ee53bf58794cf794a68a86b1da2a2929360fc57053f2` | PE32 | x86 (0x14c) | 0 | Plugin Symbol Scanner & Cache Generator (`plugins.dat`) |
| `libvlc.dll` | 184,768 | `0eac5ccd4c57a52318d4872d54921a226bb1ec2663edbfe20a0fb4c930bd9444` | PE32 | x86 (0x14c) | 316 | Public LibVLC High-Level C Library (external consumers) |
| `libvlccore.dll` | 3,133,896 | `92fee94eaef57ed6ae806d213963eb78c911f37ba689cbb1a90ca4a0123ca5e1` | PE32 | x86 (0x14c) | 764 | Private VLC Core Microkernel Engine (threads, objects, I/O) |
| `axvlc.dll` | 1,351,616 | `07abbc2c7fd613602b98aa9b4d9060846fc9d917bd529531d79443d8f3f9226c` | PE32 | x86 (0x14c) | 5 | ActiveX / COM Control for Internet Explorer & Windows Script Host |
| `uninstall.exe` | 265,014 | `27d7b97800f34851d6fae6e3fcc4d3c09fdb50801c99d3b2ea09bf7d698a1938` | PE32 | x86 (0x14c) | 0 | NSIS Nullsoft Installer System Uninstaller |

### Detailed Analysis of Core Executables & Dynamic Libraries

#### 1. `vlc.exe`
- **Format & Subsystem**: PE32 x86, Subsystem 2 (Windows GUI). Compiled with GCC for MinGW-w64.
- **Size**: 1,037,760 bytes | **SHA-256**: `499d578564d27529bc08ef9ccb4c5043e25a49d21d2d41fb2176cc3563e8f0d7`
- **Export**: Single exported symbol `WinMain@16`.
- **Import Dependencies**: Links dynamically to `libvlccore.dll` (`libvlc_InternalCreate`, `libvlc_InternalInit`, `libvlc_InternalRun`, `libvlc_InternalCleanup`, `libvlc_InternalDestroy`) and `KERNEL32.dll`.
- **Resource Section (`.rsrc`)**: Embedded manifest with Windows 10/8.1/8/7 DPI awareness, RT_GROUP_ICON containing 6 icon dimensions (16x16 8-bit, 32x32 8-bit, 16x16 32-bit, 32x32 32-bit, 48x48 32-bit, and 256x256 PNG-compressed icon).

#### 2. `vlc-cache-gen.exe`
- **Format**: PE32 x86, Subsystem 3 (Windows Console).
- **Size**: 142,272 bytes | **Role**: Executes during installation or post-update to scan all DLLs in `plugins/`, load their `vlc_entry__3_0_0f` descriptor, and serialize them into `plugins\plugins.dat`. This eliminates the need to execute hundreds of `LoadLibrary` calls during application startup.

#### 3. `libvlc.dll` (Public High-Level API)
- **Size**: 184,768 bytes | **Exports**: 316 functions.
- **Architecture**: Facade layer over `libvlccore.dll`. Exposes opaque pointers (`libvlc_instance_t`, `libvlc_media_t`, `libvlc_media_player_t`, `libvlc_event_manager_t`).
- **Export Domain Breakdown**:
  - **Media Player Control (54)**: `libvlc_media_player_new`, `_play`, `_pause`, `_stop`, `_is_playing`, `_set_time`, `_get_time`, `_set_position`, `_get_position`, `_set_rate`, `_set_hwnd`, `_add_slave`, `_next_frame`, `_navigate`
  - **Video Controls & Processing (46)**: `libvlc_video_get_size`, `_set_aspect_ratio`, `_set_crop_geometry`, `_set_scale`, `_set_deinterlace`, `_take_snapshot`, `_set_spu`, `_set_subtitle_file`, `_set_marquee_*`, `_set_logo_*`, `_set_adjust_*`, `_viewpoint_*`
  - **Media Descriptor & Parsing (38)**: `libvlc_media_new_location`, `_new_path`, `_parse_with_options`, `_get_meta`, `_get_tracks_info`, `_tracks_get`, `_get_stats`, `_slaves_get`
  - **Media List & List Player (34)**: `libvlc_media_list_new`, `_add_media`, `_insert_media`, `_remove_index`, `_media_list_player_play_item_at_index`, `_set_playback_mode`
  - **Audio Controls (31)**: `libvlc_audio_get_volume`, `_set_volume`, `_toggle_mute`, `_get_delay`, `_set_delay`, `_get_track`, `_set_track`, `_get_channel`, `_set_channel`, `_filter_list_get`
  - **Core & Lifecycle (26)**: `libvlc_new`, `_release`, `_retain`, `_add_intf`, `_set_user_agent`, `_get_version`, `_get_compiler`, `_get_changeset`
  - **VLM (VideoLAN Manager) (21)**: `libvlc_vlm_add_broadcast`, `_add_vod`, `_play_media`, `_stop_media`, `_change_media`
  - **Renderer / Chromecast (13)**: `libvlc_renderer_discoverer_new`, `_start`, `_stop`, `_item_name`, `_item_type`, `_item_flags`
  - **Logging Engine (13)**: `libvlc_log_open`, `_close`, `_set`, `_unset`, `_set_file`
  - **Audio Equalizer (11)**: `libvlc_audio_equalizer_new`, `_new_from_preset`, `_get_preset_count`, `_get_preset_name`, `_get_band_count`, `_get_band_frequency`, `_get_amp_at_index`, `_set_amp_at_index`, `_set_preamp`
  - **Dialog Integration (6)**: `libvlc_dialog_set_callbacks`, `_dismiss`, `_post_login`, `_post_action`
  - **Media Library (5)**: `libvlc_media_library_new`, `_load`, `_media_list`
  - **Event Management (3)**: `libvlc_event_attach`, `_detach`, `_type_name`

#### 4. `libvlccore.dll` (Engine Microkernel)
- **Size**: 3,133,896 bytes | **Exports**: 764 functions.
- **Key Subsystems**:
  - **Object Model (`vlc_object_*`, 311 functions)**: Hierarchical C object model with refcounting, thread-safe variable attachment, parent-child tree inheritance.
  - **Input Engine (`input_*`, 57 functions)**: Multi-threaded input pipeline (`input_thread_t`), parsing MRLs, demuxer selection, ES (Elementary Stream) discovery, slave input synchronization.
  - **Playlist Subsystem (`playlist_*`, 39 functions)**: Tree-based hierarchical playlist, node grouping, shuffle/random algorithms, repeat one/all, media item retention.
  - **Picture / Video Frame Engine (`picture_*`, 29 functions)**: Frame memory pools, zero-copy buffer handoff, chroma conversion (`picture_Copy`, `picture_Blend`, `picture_pool_New`).
  - **Audio Output Pipeline (`aout_*`, 26 functions)**: Audio format negotiation, float32 audio mixing, software volume amplification, channel remixing (stereo, 5.1, 7.1).
  - **Reactive Variable System (`var_*`, 18 functions)**: Typed publish-subscribe variable bus (`var_Create`, `var_Set`, `var_Get`, `var_AddCallback`). UI widgets bind directly to core variables.
  - **Memory Block FIFO (`block_*`, 16 functions)**: Streaming buffer blocks holding raw PTS/DTS packets, zero-copy chain concatenation, refcounted allocators.
  - **Stream Output Pipeline (`sout_*`, 18 functions)**: Duplication, transcoding, streaming (RTP/RTSP/HTTP/HLS), mosaic mixing.

#### 5. `axvlc.dll` (ActiveX Control)
- **Size**: 1,351,616 bytes | **Exports**: 5 COM registration exports (`DllCanUnloadNow`, `DllGetClassObject`, `DllMain`, `DllRegisterServer`, `DllUnregisterServer`).
- **Role**: Embeds VLC inside COM-aware Windows applications (WPF WindowsFormsHost, MS Office, VB6, Internet Explorer legacy controls).

---

## 2. Plugins Directory Hierarchy & Ecosystem

VLC's capability modularity is achieved entirely through dynamic libraries located in `plugins/`. Each plugin is a self-contained PE32 dynamic library implementing one or more VLC modules.

### Plugin Categories Breakdown (29 Categories, 360 DLLs)
| Category Directory | Plugin Count | Total Size (MB) | Architectural Purpose |
|---|---|---|---|
| `access` | 35 |  22.01 MB | Input source protocols (filesystem, HTTP, RTSP, SMB, Bluray, DVD, screen capture) |
| `access_output` | 8 |   8.37 MB | Stream export transport sinks (File, HTTP, HLS/livehttp, SRT, RIST, Icecast/Shoutcast, UDP) |
| `audio_filter` | 25 |   3.75 MB | Audio DSP processing (Equalizer, Spatializer, Volume normalizer, Pitch/scaletempo, Resamplers) |
| `audio_mixer` | 2 |   0.08 MB | Software audio mixing pipelines (Float32 mixer, Integer mixer) |
| `audio_output` | 7 |   0.36 MB | Hardware audio rendering backends (WASAPI, DirectSound, WaveOut, MMDevice, Memory buffer) |
| `codec` | 56 |  38.56 MB | Audio/Video/Subtitle decoders & encoders (FFmpeg avcodec, x264, x265, dav1d AV1, libass, FAAD) |
| `control` | 8 |   0.45 MB | Input automation & external control (Mouse gestures, Global hotkeys, NetSync, NT service) |
| `d3d11` | 1 |   0.19 MB | Direct3D 11 hardware video post-processing and rendering filters |
| `d3d9` | 1 |   0.14 MB | Direct3D 9 / DXVA video post-processing and rendering filters |
| `demux` | 47 |  10.64 MB | Container parsers (MKV, MP4, AVI, TS, Ogg, FLAC, HLS/DASH adaptive, Demuxers) |
| `gui` | 2 |  18.68 MB | User interface implementations (Qt 5 interface plugin, Skins2 skinning engine) |
| `keystore` | 2 |   0.11 MB | Credential and password storage backends (Memory keystore, File keystore) |
| `logger` | 2 |   0.12 MB | Diagnostic logging backends (Console logger, File logger) |
| `lua` | 1 |   0.37 MB | Lua scripting engine bridge (loads Lua 5.1 runtime into libvlccore) |
| `meta_engine` | 2 |   1.63 MB | Media metadata extraction engines (TagLib ID3/Vorbis parser, Folder artwork engine) |
| `misc` | 10 |   3.47 MB | Utility and cryptographic support (GnuTLS TLS/SSL provider, XML parser, Addon repository, Stats) |
| `mux` | 9 |   0.87 MB | Container multiplexers for recording and streaming (TS, MP4, OGG, AVI, PS, WAV) |
| `packetizer` | 14 |   0.91 MB | Elementary stream packet framing (H.264, HEVC, AV1, MPEG-4, AAC, AC3, DTS, FLAC) |
| `services_discovery` | 6 |   1.38 MB | LAN and cloud media discovery (UPnP/DLNA, mDNS/Bonjour/Chromecast, Podcasts, SAP) |
| `spu` | 7 |   1.24 MB | SubPicture Unit visual overlays (Watermark Logo, Marquee text, RSS ticker, Mosaic, Subsdelay) |
| `stream_extractor` | 1 |   0.51 MB | Archive stream extractor (reads video/audio directly inside ZIP/RAR/7z archives) |
| `stream_filter` | 9 |   0.45 MB | Stream preprocessing filters (Prefetch buffer, Block caching, HDS, Stream recording) |
| `stream_out` | 20 |   4.50 MB | Transcoding & distribution pipeline (Chromecast streaming, Transcode, Duplicate, Mosaic bridge) |
| `text_renderer` | 3 |   3.09 MB | Vector font rendering engines (FreeType font rasterizer, SAPI Speech synthesizer) |
| `video_chroma` | 19 |   2.29 MB | Color space and pixel format converters (YUV to RGB, SSE2/MMX optimized chromas, SwScale) |
| `video_filter` | 41 |   2.62 MB | Video DSP effects (Adjust, Deinterlace, Sharpen, Blur, Transform, Rotate, Puzzle, VHS, Magnify) |
| `video_output` | 15 |   3.39 MB | Hardware display sinks (Direct3D 11, Direct3D 9, OpenGL Win32, DirectDraw, GDI, CACA) |
| `video_splitter` | 3 |   0.18 MB | Multi-monitor and video wall splitters (Clone, Wall, Panoramix) |
| `visualization` | 4 |   2.02 MB | Music visualizers (ProjectM Milkdrop engine, Goom, Spectrum analyzer, GL Spectrum) |

### Complete Catalog of All 360 Plugin Modules

#### Category: `plugins/access` (35 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libaccess_concat_plugin.dll` | 41 KB | `access_concat` | VLC module in category `access` |
| `libaccess_imem_plugin.dll` | 72 KB | `access_imem` | VLC module in category `access` |
| `libaccess_mms_plugin.dll` | 103 KB | `access_mms` | VLC module in category `access` |
| `libaccess_srt_plugin.dll` | 4,250 KB | `access_srt` | VLC module in category `access` |
| `libaccess_wasapi_plugin.dll` | 58 KB | `access_wasapi` | VLC module in category `access` |
| `libattachment_plugin.dll` | 38 KB | `attachment` | VLC module in category `access` |
| `libcdda_plugin.dll` | 1,066 KB | `cdda` | VLC module in category `access` |
| `libdcp_plugin.dll` | 2,833 KB | `dcp` | VLC module in category `access` |
| `libdshow_plugin.dll` | 903 KB | `dshow` | VLC module in category `access` |
| `libdtv_plugin.dll` | 880 KB | `dtv` | VLC module in category `access` |
| `libdvdnav_plugin.dll` | 278 KB | `dvdnav` | VLC module in category `access` |
| `libdvdread_plugin.dll` | 215 KB | `dvdread` | VLC module in category `access` |
| `libfilesystem_plugin.dll` | 66 KB | `filesystem` | VLC module in category `access` |
| `libftp_plugin.dll` | 125 KB | `ftp` | VLC module in category `access` |
| `libhttp_plugin.dll` | 74 KB | `http` | VLC module in category `access` |
| `libhttps_plugin.dll` | 153 KB | `https` | VLC module in category `access` |
| `libidummy_plugin.dll` | 39 KB | `idummy` | VLC module in category `access` |
| `libimem_plugin.dll` | 39 KB | `imem` | VLC module in category `access` |
| `liblibbluray_plugin.dll` | 1,366 KB | `bluray` | VLC module in category `access` |
| `liblive555_plugin.dll` | 561 KB | `live555` | VLC module in category `access` |
| `libnfs_plugin.dll` | 296 KB | `nfs` | VLC module in category `access` |
| `librist_plugin.dll` | 2,770 KB | `rist` | VLC module in category `access` |
| `librtp_plugin.dll` | 953 KB | `rtp` | VLC module in category `access` |
| `libsatip_plugin.dll` | 72 KB | `satip` | VLC module in category `access` |
| `libscreen_plugin.dll` | 46 KB | `screen` | VLC module in category `access` |
| `libsdp_plugin.dll` | 38 KB | `sdp` | VLC module in category `access` |
| `libsftp_plugin.dll` | 1,095 KB | `sftp` | VLC module in category `access` |
| `libshm_plugin.dll` | 41 KB | `shm` | VLC module in category `access` |
| `libsmb_plugin.dll` | 66 KB | `smb` | VLC module in category `access` |
| `libtcp_plugin.dll` | 38 KB | `tcp` | VLC module in category `access` |
| `libtimecode_plugin.dll` | 64 KB | `timecode` | VLC module in category `access` |
| `libudp_plugin.dll` | 41 KB | `udp` | VLC module in category `access` |
| `libvcd_plugin.dll` | 107 KB | `vcd` | VLC module in category `access` |
| `libvdr_plugin.dll` | 105 KB | `vdr` | VLC module in category `access` |
| `libvnc_plugin.dll` | 3,627 KB | `vnc` | VLC module in category `access` |

#### Category: `plugins/access_output` (8 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libaccess_output_dummy_plugin.dll` | 37 KB | `access_output_dummy` | VLC module in category `access_output` |
| `libaccess_output_file_plugin.dll` | 41 KB | `access_output_file` | VLC module in category `access_output` |
| `libaccess_output_http_plugin.dll` | 43 KB | `access_output_http` | VLC module in category `access_output` |
| `libaccess_output_livehttp_plugin.dll` | 937 KB | `access_output_livehttp` | VLC module in category `access_output` |
| `libaccess_output_rist_plugin.dll` | 2,769 KB | `access_output_rist` | VLC module in category `access_output` |
| `libaccess_output_shout_plugin.dll` | 447 KB | `access_output_shout` | VLC module in category `access_output` |
| `libaccess_output_srt_plugin.dll` | 4,250 KB | `access_output_srt` | VLC module in category `access_output` |
| `libaccess_output_udp_plugin.dll` | 43 KB | `access_output_udp` | VLC module in category `access_output` |

#### Category: `plugins/audio_filter` (25 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libaudio_format_plugin.dll` | 50 KB | `audio_format` | VLC module in category `audio_filter` |
| `libaudiobargraph_a_plugin.dll` | 68 KB | `audiobargraph_a` | VLC module in category `audio_filter` |
| `libchorus_flanger_plugin.dll` | 44 KB | `chorus_flanger` | VLC module in category `audio_filter` |
| `libcompressor_plugin.dll` | 49 KB | `compressor` | VLC module in category `audio_filter` |
| `libdolby_surround_decoder_plugin.dll` | 39 KB | `dolby_surround_decoder` | VLC module in category `audio_filter` |
| `libequalizer_plugin.dll` | 74 KB | `equalizer` | VLC module in category `audio_filter` |
| `libgain_plugin.dll` | 39 KB | `gain` | VLC module in category `audio_filter` |
| `libheadphone_channel_mixer_plugin.dll` | 45 KB | `headphone_channel_mixer` | VLC module in category `audio_filter` |
| `libkaraoke_plugin.dll` | 38 KB | `karaoke` | VLC module in category `audio_filter` |
| `libmad_plugin.dll` | 169 KB | `mad` | VLC module in category `audio_filter` |
| `libmono_plugin.dll` | 47 KB | `mono` | VLC module in category `audio_filter` |
| `libnormvol_plugin.dll` | 41 KB | `normvol` | VLC module in category `audio_filter` |
| `libparam_eq_plugin.dll` | 46 KB | `param_eq` | VLC module in category `audio_filter` |
| `libremap_plugin.dll` | 45 KB | `remap` | VLC module in category `audio_filter` |
| `libsamplerate_plugin.dll` | 1,481 KB | `samplerate` | VLC module in category `audio_filter` |
| `libscaletempo_pitch_plugin.dll` | 48 KB | `scaletempo_pitch` | VLC module in category `audio_filter` |
| `libscaletempo_plugin.dll` | 43 KB | `scaletempo` | VLC module in category `audio_filter` |
| `libsimple_channel_mixer_plugin.dll` | 43 KB | `simple_channel_mixer` | VLC module in category `audio_filter` |
| `libspatialaudio_plugin.dll` | 1,065 KB | `spatialaudio` | VLC module in category `audio_filter` |
| `libspatializer_plugin.dll` | 131 KB | `spatializer` | VLC module in category `audio_filter` |
| `libspeex_resampler_plugin.dll` | 49 KB | `speex_resampler` | VLC module in category `audio_filter` |
| `libstereo_widen_plugin.dll` | 42 KB | `stereo_widen` | VLC module in category `audio_filter` |
| `libtospdif_plugin.dll` | 51 KB | `tospdif` | VLC module in category `audio_filter` |
| `libtrivial_channel_mixer_plugin.dll` | 42 KB | `trivial_channel_mixer` | VLC module in category `audio_filter` |
| `libugly_resampler_plugin.dll` | 38 KB | `ugly_resampler` | VLC module in category `audio_filter` |

#### Category: `plugins/audio_mixer` (2 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libfloat_mixer_plugin.dll` | 37 KB | `float_mixer` | VLC module in category `audio_mixer` |
| `libinteger_mixer_plugin.dll` | 39 KB | `integer_mixer` | VLC module in category `audio_mixer` |

#### Category: `plugins/audio_output` (7 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libadummy_plugin.dll` | 37 KB | `adummy` | VLC module in category `audio_output` |
| `libafile_plugin.dll` | 41 KB | `afile` | VLC module in category `audio_output` |
| `libamem_plugin.dll` | 40 KB | `amem` | VLC module in category `audio_output` |
| `libdirectsound_plugin.dll` | 60 KB | `directsound` | VLC module in category `audio_output` |
| `libmmdevice_plugin.dll` | 67 KB | `mmdevice` | VLC module in category `audio_output` |
| `libwasapi_plugin.dll` | 60 KB | `wasapi` | VLC module in category `audio_output` |
| `libwaveout_plugin.dll` | 58 KB | `waveout` | VLC module in category `audio_output` |

#### Category: `plugins/codec` (56 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libadpcm_plugin.dll` | 48 KB | `adpcm` | VLC module in category `codec` |
| `libaes3_plugin.dll` | 41 KB | `aes3` | VLC module in category `codec` |
| `libaom_plugin.dll` | 1,241 KB | `aom` | VLC module in category `codec` |
| `libaraw_plugin.dll` | 53 KB | `araw` | VLC module in category `codec` |
| `libaribsub_plugin.dll` | 327 KB | `aribsub` | VLC module in category `codec` |
| `libavcodec_plugin.dll` | 17,766 KB | `avcodec` | VLC module in category `codec` |
| `libcc_plugin.dll` | 72 KB | `cc` | VLC module in category `codec` |
| `libcdg_plugin.dll` | 43 KB | `cdg` | VLC module in category `codec` |
| `libcrystalhd_plugin.dll` | 97 KB | `crystalhd` | VLC module in category `codec` |
| `libcvdsub_plugin.dll` | 44 KB | `cvdsub` | VLC module in category `codec` |
| `libd3d11va_plugin.dll` | 265 KB | `d3d11va` | VLC module in category `codec` |
| `libdav1d_plugin.dll` | 1,092 KB | `dav1d` | VLC module in category `codec` |
| `libddummy_plugin.dll` | 63 KB | `ddummy` | VLC module in category `codec` |
| `libdmo_plugin.dll` | 64 KB | `dmo` | VLC module in category `codec` |
| `libdvbsub_plugin.dll` | 112 KB | `dvbsub` | VLC module in category `codec` |
| `libdxva2_plugin.dll` | 292 KB | `dxva2` | VLC module in category `codec` |
| `libedummy_plugin.dll` | 37 KB | `edummy` | VLC module in category `codec` |
| `libfaad_plugin.dll` | 338 KB | `faad` | VLC module in category `codec` |
| `libflac_plugin.dll` | 275 KB | `flac` | VLC module in category `codec` |
| `libfluidsynth_plugin.dll` | 337 KB | `fluidsynth` | VLC module in category `codec` |
| `libg711_plugin.dll` | 51 KB | `g711` | VLC module in category `codec` |
| `libjpeg_plugin.dll` | 278 KB | `jpeg` | VLC module in category `codec` |
| `libkate_plugin.dll` | 112 KB | `kate` | VLC module in category `codec` |
| `liblibass_plugin.dll` | 3,418 KB | `ass` | VLC module in category `codec` |
| `liblpcm_plugin.dll` | 48 KB | `lpcm` | VLC module in category `codec` |
| `libmft_plugin.dll` | 114 KB | `mft` | VLC module in category `codec` |
| `libmpg123_plugin.dll` | 349 KB | `mpg123` | VLC module in category `codec` |
| `liboggspots_plugin.dll` | 42 KB | `oggspots` | VLC module in category `codec` |
| `libopus_plugin.dll` | 426 KB | `opus` | VLC module in category `codec` |
| `libpng_plugin.dll` | 267 KB | `png` | VLC module in category `codec` |
| `libqsv_plugin.dll` | 1,041 KB | `qsv` | VLC module in category `codec` |
| `librawvideo_plugin.dll` | 41 KB | `rawvideo` | VLC module in category `codec` |
| `librtpvideo_plugin.dll` | 38 KB | `rtpvideo` | VLC module in category `codec` |
| `libscte18_plugin.dll` | 43 KB | `scte18` | VLC module in category `codec` |
| `libscte27_plugin.dll` | 52 KB | `scte27` | VLC module in category `codec` |
| `libspdif_plugin.dll` | 37 KB | `spdif` | VLC module in category `codec` |
| `libspeex_plugin.dll` | 151 KB | `speex` | VLC module in category `codec` |
| `libspudec_plugin.dll` | 49 KB | `spudec` | VLC module in category `codec` |
| `libstl_plugin.dll` | 44 KB | `stl` | VLC module in category `codec` |
| `libsubsdec_plugin.dll` | 75 KB | `subsdec` | VLC module in category `codec` |
| `libsubstx3g_plugin.dll` | 43 KB | `substx3g` | VLC module in category `codec` |
| `libsubsusf_plugin.dll` | 51 KB | `subsusf` | VLC module in category `codec` |
| `libsvcdsub_plugin.dll` | 43 KB | `svcdsub` | VLC module in category `codec` |
| `libt140_plugin.dll` | 38 KB | `t140` | VLC module in category `codec` |
| `libtextst_plugin.dll` | 42 KB | `textst` | VLC module in category `codec` |
| `libtheora_plugin.dll` | 345 KB | `theora` | VLC module in category `codec` |
| `libttml_plugin.dll` | 124 KB | `ttml` | VLC module in category `codec` |
| `libtwolame_plugin.dll` | 174 KB | `twolame` | VLC module in category `codec` |
| `libuleaddvaudio_plugin.dll` | 39 KB | `uleaddvaudio` | VLC module in category `codec` |
| `libvorbis_plugin.dll` | 727 KB | `vorbis` | VLC module in category `codec` |
| `libvpx_plugin.dll` | 63 KB | `vpx` | VLC module in category `codec` |
| `libwebvtt_plugin.dll` | 186 KB | `webvtt` | VLC module in category `codec` |
| `libx26410b_plugin.dll` | 1,891 KB | `x26410b` | VLC module in category `codec` |
| `libx264_plugin.dll` | 1,891 KB | `x264` | VLC module in category `codec` |
| `libx265_plugin.dll` | 3,110 KB | `x265` | VLC module in category `codec` |
| `libzvbi_plugin.dll` | 1,401 KB | `zvbi` | VLC module in category `codec` |

#### Category: `plugins/control` (8 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libdummy_plugin.dll` | 37 KB | `dummy` | VLC module in category `control` |
| `libgestures_plugin.dll` | 44 KB | `gestures` | VLC module in category `control` |
| `libhotkeys_plugin.dll` | 87 KB | `hotkeys` | VLC module in category `control` |
| `libnetsync_plugin.dll` | 43 KB | `netsync` | VLC module in category `control` |
| `libntservice_plugin.dll` | 66 KB | `ntservice` | VLC module in category `control` |
| `liboldrc_plugin.dll` | 93 KB | `oldrc` | VLC module in category `control` |
| `libwin_hotkeys_plugin.dll` | 41 KB | `win_hotkeys` | VLC module in category `control` |
| `libwin_msg_plugin.dll` | 40 KB | `win_msg` | VLC module in category `control` |

#### Category: `plugins/d3d11` (1 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libdirect3d11_filters_plugin.dll` | 196 KB | `direct3d11_filters` | VLC module in category `d3d11` |

#### Category: `plugins/d3d9` (1 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libdirect3d9_filters_plugin.dll` | 145 KB | `direct3d9_filters` | VLC module in category `d3d9` |

#### Category: `plugins/demux` (47 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libadaptive_plugin.dll` | 2,665 KB | `adaptive` | VLC module in category `demux` |
| `libaiff_plugin.dll` | 42 KB | `aiff` | VLC module in category `demux` |
| `libasf_plugin.dll` | 118 KB | `asf` | VLC module in category `demux` |
| `libau_plugin.dll` | 40 KB | `au` | VLC module in category `demux` |
| `libavi_plugin.dll` | 145 KB | `avi` | VLC module in category `demux` |
| `libcaf_plugin.dll` | 53 KB | `caf` | VLC module in category `demux` |
| `libdemux_cdg_plugin.dll` | 39 KB | `demux_cdg` | VLC module in category `demux` |
| `libdemux_chromecast_plugin.dll` | 127 KB | `demux_chromecast` | VLC module in category `demux` |
| `libdemux_stl_plugin.dll` | 43 KB | `demux_stl` | VLC module in category `demux` |
| `libdemuxdump_plugin.dll` | 40 KB | `demuxdump` | VLC module in category `demux` |
| `libdiracsys_plugin.dll` | 39 KB | `diracsys` | VLC module in category `demux` |
| `libdirectory_demux_plugin.dll` | 38 KB | `directory_demux` | VLC module in category `demux` |
| `libdmxmus_plugin.dll` | 41 KB | `dmxmus` | VLC module in category `demux` |
| `libes_plugin.dll` | 68 KB | `es` | VLC module in category `demux` |
| `libflacsys_plugin.dll` | 114 KB | `flacsys` | VLC module in category `demux` |
| `libgme_plugin.dll` | 1,063 KB | `gme` | VLC module in category `demux` |
| `libh26x_plugin.dll` | 120 KB | `h26x` | VLC module in category `demux` |
| `libimage_plugin.dll` | 52 KB | `image` | VLC module in category `demux` |
| `libmjpeg_plugin.dll` | 44 KB | `mjpeg` | VLC module in category `demux` |
| `libmkv_plugin.dll` | 1,713 KB | `mkv` | VLC module in category `demux` |
| `libmod_plugin.dll` | 418 KB | `mod` | VLC module in category `demux` |
| `libmp4_plugin.dll` | 348 KB | `mp4` | VLC module in category `demux` |
| `libmpc_plugin.dll` | 120 KB | `mpc` | VLC module in category `demux` |
| `libmpgv_plugin.dll` | 39 KB | `mpgv` | VLC module in category `demux` |
| `libnoseek_plugin.dll` | 38 KB | `noseek` | VLC module in category `demux` |
| `libnsc_plugin.dll` | 77 KB | `nsc` | VLC module in category `demux` |
| `libnsv_plugin.dll` | 44 KB | `nsv` | VLC module in category `demux` |
| `libnuv_plugin.dll` | 47 KB | `nuv` | VLC module in category `demux` |
| `libogg_plugin.dll` | 340 KB | `ogg` | VLC module in category `demux` |
| `libplaylist_plugin.dll` | 164 KB | `playlist` | VLC module in category `demux` |
| `libps_plugin.dll` | 72 KB | `ps` | VLC module in category `demux` |
| `libpva_plugin.dll` | 45 KB | `pva` | VLC module in category `demux` |
| `librawaud_plugin.dll` | 41 KB | `rawaud` | VLC module in category `demux` |
| `librawdv_plugin.dll` | 41 KB | `rawdv` | VLC module in category `demux` |
| `librawvid_plugin.dll` | 44 KB | `rawvid` | VLC module in category `demux` |
| `libreal_plugin.dll` | 64 KB | `real` | VLC module in category `demux` |
| `libsid_plugin.dll` | 1,205 KB | `sid` | VLC module in category `demux` |
| `libsmf_plugin.dll` | 48 KB | `smf` | VLC module in category `demux` |
| `libsubtitle_plugin.dll` | 119 KB | `subtitle` | VLC module in category `demux` |
| `libts_plugin.dll` | 577 KB | `ts` | VLC module in category `demux` |
| `libtta_plugin.dll` | 41 KB | `tta` | VLC module in category `demux` |
| `libty_plugin.dll` | 61 KB | `ty` | VLC module in category `demux` |
| `libvc1_plugin.dll` | 40 KB | `vc1` | VLC module in category `demux` |
| `libvobsub_plugin.dll` | 103 KB | `vobsub` | VLC module in category `demux` |
| `libvoc_plugin.dll` | 43 KB | `voc` | VLC module in category `demux` |
| `libwav_plugin.dll` | 48 KB | `wav` | VLC module in category `demux` |
| `libxa_plugin.dll` | 39 KB | `xa` | VLC module in category `demux` |

#### Category: `plugins/gui` (2 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libqt_plugin.dll` | 16,850 KB | `qt` | VLC module in category `gui` |
| `libskins2_plugin.dll` | 2,275 KB | `skins2` | VLC module in category `gui` |

#### Category: `plugins/keystore` (2 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libfile_keystore_plugin.dll` | 68 KB | `file_keystore` | VLC module in category `keystore` |
| `libmemory_keystore_plugin.dll` | 40 KB | `memory_keystore` | VLC module in category `keystore` |

#### Category: `plugins/logger` (2 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libconsole_logger_plugin.dll` | 61 KB | `console_logger` | VLC module in category `logger` |
| `libfile_logger_plugin.dll` | 64 KB | `file_logger` | VLC module in category `logger` |

#### Category: `plugins/lua` (1 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `liblua_plugin.dll` | 373 KB | `lua` | VLC module in category `lua` |

#### Category: `plugins/meta_engine` (2 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libfolder_plugin.dll` | 61 KB | `folder` | VLC module in category `meta_engine` |
| `libtaglib_plugin.dll` | 1,611 KB | `tag` | VLC module in category `meta_engine` |

#### Category: `plugins/misc` (10 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libaddonsfsstorage_plugin.dll` | 105 KB | `addonsfsstorage` | VLC module in category `misc` |
| `libaddonsvorepository_plugin.dll` | 99 KB | `addonsvorepository` | VLC module in category `misc` |
| `libaudioscrobbler_plugin.dll` | 74 KB | `audioscrobbler` | VLC module in category `misc` |
| `libexport_plugin.dll` | 70 KB | `export` | VLC module in category `misc` |
| `libfingerprinter_plugin.dll` | 80 KB | `fingerprinter` | VLC module in category `misc` |
| `libgnutls_plugin.dll` | 2,453 KB | `gnutls` | VLC module in category `misc` |
| `liblogger_plugin.dll` | 38 KB | `logger` | VLC module in category `misc` |
| `libstats_plugin.dll` | 42 KB | `stats` | VLC module in category `misc` |
| `libvod_rtsp_plugin.dll` | 126 KB | `vod_rtsp` | VLC module in category `misc` |
| `libxml_plugin.dll` | 463 KB | `xml` | VLC module in category `misc` |

#### Category: `plugins/mux` (9 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libmux_asf_plugin.dll` | 68 KB | `mux_asf` | VLC module in category `mux` |
| `libmux_avi_plugin.dll` | 55 KB | `mux_avi` | VLC module in category `mux` |
| `libmux_dummy_plugin.dll` | 39 KB | `mux_dummy` | VLC module in category `mux` |
| `libmux_mp4_plugin.dll` | 243 KB | `mux_mp4` | VLC module in category `mux` |
| `libmux_mpjpeg_plugin.dll` | 61 KB | `mux_mpjpeg` | VLC module in category `mux` |
| `libmux_ogg_plugin.dll` | 101 KB | `mux_ogg` | VLC module in category `mux` |
| `libmux_ps_plugin.dll` | 89 KB | `mux_ps` | VLC module in category `mux` |
| `libmux_ts_plugin.dll` | 184 KB | `mux_ts` | VLC module in category `mux` |
| `libmux_wav_plugin.dll` | 42 KB | `mux_wav` | VLC module in category `mux` |

#### Category: `plugins/packetizer` (14 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libpacketizer_a52_plugin.dll` | 46 KB | `packetizer_a52` | VLC module in category `packetizer` |
| `libpacketizer_av1_plugin.dll` | 63 KB | `packetizer_av1` | VLC module in category `packetizer` |
| `libpacketizer_copy_plugin.dll` | 39 KB | `packetizer_copy` | VLC module in category `packetizer` |
| `libpacketizer_dirac_plugin.dll` | 55 KB | `packetizer_dirac` | VLC module in category `packetizer` |
| `libpacketizer_dts_plugin.dll` | 49 KB | `packetizer_dts` | VLC module in category `packetizer` |
| `libpacketizer_flac_plugin.dll` | 48 KB | `packetizer_flac` | VLC module in category `packetizer` |
| `libpacketizer_h264_plugin.dll` | 146 KB | `packetizer_h264` | VLC module in category `packetizer` |
| `libpacketizer_hevc_plugin.dll` | 143 KB | `packetizer_hevc` | VLC module in category `packetizer` |
| `libpacketizer_mlp_plugin.dll` | 53 KB | `packetizer_mlp` | VLC module in category `packetizer` |
| `libpacketizer_mpeg4audio_plugin.dll` | 65 KB | `packetizer_mpeg4audio` | VLC module in category `packetizer` |
| `libpacketizer_mpeg4video_plugin.dll` | 55 KB | `packetizer_mpeg4video` | VLC module in category `packetizer` |
| `libpacketizer_mpegaudio_plugin.dll` | 44 KB | `packetizer_mpegaudio` | VLC module in category `packetizer` |
| `libpacketizer_mpegvideo_plugin.dll` | 54 KB | `packetizer_mpegvideo` | VLC module in category `packetizer` |
| `libpacketizer_vc1_plugin.dll` | 63 KB | `packetizer_vc1` | VLC module in category `packetizer` |

#### Category: `plugins/services_discovery` (6 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libmediadirs_plugin.dll` | 43 KB | `mediadirs` | VLC module in category `services_discovery` |
| `libmicrodns_plugin.dll` | 115 KB | `microdns` | VLC module in category `services_discovery` |
| `libpodcast_plugin.dll` | 46 KB | `podcast` | VLC module in category `services_discovery` |
| `libsap_plugin.dll` | 149 KB | `sap` | VLC module in category `services_discovery` |
| `libupnp_plugin.dll` | 1,015 KB | `upnp` | VLC module in category `services_discovery` |
| `libwindrive_plugin.dll` | 40 KB | `windrive` | VLC module in category `services_discovery` |

#### Category: `plugins/spu` (7 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libaudiobargraph_v_plugin.dll` | 47 KB | `audiobargraph_v` | VLC module in category `spu` |
| `liblogo_plugin.dll` | 47 KB | `logo` | VLC module in category `spu` |
| `libmarq_plugin.dll` | 46 KB | `marq` | VLC module in category `spu` |
| `libmosaic_plugin.dll` | 55 KB | `mosaic` | VLC module in category `spu` |
| `libremoteosd_plugin.dll` | 942 KB | `remoteosd` | VLC module in category `spu` |
| `librss_plugin.dll` | 73 KB | `rss` | VLC module in category `spu` |
| `libsubsdelay_plugin.dll` | 51 KB | `subsdelay` | VLC module in category `spu` |

#### Category: `plugins/stream_extractor` (1 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libarchive_plugin.dll` | 523 KB | `archive` | VLC module in category `stream_extractor` |

#### Category: `plugins/stream_filter` (9 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libadf_plugin.dll` | 38 KB | `adf` | VLC module in category `stream_filter` |
| `libaribcam_plugin.dll` | 64 KB | `aribcam` | VLC module in category `stream_filter` |
| `libcache_block_plugin.dll` | 42 KB | `cache_block` | VLC module in category `stream_filter` |
| `libcache_read_plugin.dll` | 43 KB | `cache_read` | VLC module in category `stream_filter` |
| `libhds_plugin.dll` | 80 KB | `hds` | VLC module in category `stream_filter` |
| `libinflate_plugin.dll` | 65 KB | `inflate` | VLC module in category `stream_filter` |
| `libprefetch_plugin.dll` | 43 KB | `prefetch` | VLC module in category `stream_filter` |
| `librecord_plugin.dll` | 39 KB | `record` | VLC module in category `stream_filter` |
| `libskiptags_plugin.dll` | 39 KB | `skiptags` | VLC module in category `stream_filter` |

#### Category: `plugins/stream_out` (20 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libstream_out_autodel_plugin.dll` | 39 KB | `stream_out_autodel` | VLC module in category `stream_out` |
| `libstream_out_bridge_plugin.dll` | 69 KB | `stream_out_bridge` | VLC module in category `stream_out` |
| `libstream_out_chromaprint_plugin.dll` | 1,409 KB | `stream_out_chromaprint` | VLC module in category `stream_out` |
| `libstream_out_chromecast_plugin.dll` | 1,241 KB | `stream_out_chromecast` | VLC module in category `stream_out` |
| `libstream_out_cycle_plugin.dll` | 41 KB | `stream_out_cycle` | VLC module in category `stream_out` |
| `libstream_out_delay_plugin.dll` | 39 KB | `stream_out_delay` | VLC module in category `stream_out` |
| `libstream_out_description_plugin.dll` | 38 KB | `stream_out_description` | VLC module in category `stream_out` |
| `libstream_out_display_plugin.dll` | 39 KB | `stream_out_display` | VLC module in category `stream_out` |
| `libstream_out_dummy_plugin.dll` | 37 KB | `stream_out_dummy` | VLC module in category `stream_out` |
| `libstream_out_duplicate_plugin.dll` | 95 KB | `stream_out_duplicate` | VLC module in category `stream_out` |
| `libstream_out_es_plugin.dll` | 43 KB | `stream_out_es` | VLC module in category `stream_out` |
| `libstream_out_gather_plugin.dll` | 40 KB | `stream_out_gather` | VLC module in category `stream_out` |
| `libstream_out_mosaic_bridge_plugin.dll` | 47 KB | `stream_out_mosaic_bridge` | VLC module in category `stream_out` |
| `libstream_out_record_plugin.dll` | 73 KB | `stream_out_record` | VLC module in category `stream_out` |
| `libstream_out_rtp_plugin.dll` | 1,060 KB | `stream_out_rtp` | VLC module in category `stream_out` |
| `libstream_out_setid_plugin.dll` | 41 KB | `stream_out_setid` | VLC module in category `stream_out` |
| `libstream_out_smem_plugin.dll` | 43 KB | `stream_out_smem` | VLC module in category `stream_out` |
| `libstream_out_standard_plugin.dll` | 70 KB | `stream_out_standard` | VLC module in category `stream_out` |
| `libstream_out_stats_plugin.dll` | 64 KB | `stream_out_stats` | VLC module in category `stream_out` |
| `libstream_out_transcode_plugin.dll` | 69 KB | `stream_out_transcode` | VLC module in category `stream_out` |

#### Category: `plugins/text_renderer` (3 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libfreetype_plugin.dll` | 3,080 KB | `freetype` | VLC module in category `text_renderer` |
| `libsapi_plugin.dll` | 46 KB | `sapi` | VLC module in category `text_renderer` |
| `libtdummy_plugin.dll` | 37 KB | `tdummy` | VLC module in category `text_renderer` |

#### Category: `plugins/video_chroma` (19 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libchain_plugin.dll` | 66 KB | `chain` | VLC module in category `video_chroma` |
| `libgrey_yuv_plugin.dll` | 41 KB | `grey_yuv` | VLC module in category `video_chroma` |
| `libi420_10_p010_plugin.dll` | 108 KB | `i420_10_p010` | VLC module in category `video_chroma` |
| `libi420_nv12_plugin.dll` | 110 KB | `i420_nv12` | VLC module in category `video_chroma` |
| `libi420_rgb_mmx_plugin.dll` | 80 KB | `i420_rgb_mmx` | VLC module in category `video_chroma` |
| `libi420_rgb_plugin.dll` | 54 KB | `i420_rgb` | VLC module in category `video_chroma` |
| `libi420_rgb_sse2_plugin.dll` | 139 KB | `i420_rgb_sse2` | VLC module in category `video_chroma` |
| `libi420_yuy2_mmx_plugin.dll` | 43 KB | `i420_yuy2_mmx` | VLC module in category `video_chroma` |
| `libi420_yuy2_plugin.dll` | 42 KB | `i420_yuy2` | VLC module in category `video_chroma` |
| `libi420_yuy2_sse2_plugin.dll` | 47 KB | `i420_yuy2_sse2` | VLC module in category `video_chroma` |
| `libi422_i420_plugin.dll` | 40 KB | `i422_i420` | VLC module in category `video_chroma` |
| `libi422_yuy2_mmx_plugin.dll` | 42 KB | `i422_yuy2_mmx` | VLC module in category `video_chroma` |
| `libi422_yuy2_plugin.dll` | 42 KB | `i422_yuy2` | VLC module in category `video_chroma` |
| `libi422_yuy2_sse2_plugin.dll` | 47 KB | `i422_yuy2_sse2` | VLC module in category `video_chroma` |
| `librv32_plugin.dll` | 38 KB | `rv32` | VLC module in category `video_chroma` |
| `libswscale_plugin.dll` | 1,265 KB | `swscale` | VLC module in category `video_chroma` |
| `libyuvp_plugin.dll` | 39 KB | `yuvp` | VLC module in category `video_chroma` |
| `libyuy2_i420_plugin.dll` | 43 KB | `yuy2_i420` | VLC module in category `video_chroma` |
| `libyuy2_i422_plugin.dll` | 41 KB | `yuy2_i422` | VLC module in category `video_chroma` |

#### Category: `plugins/video_filter` (41 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libadjust_plugin.dll` | 65 KB | `adjust` | VLC module in category `video_filter` |
| `libalphamask_plugin.dll` | 40 KB | `alphamask` | VLC module in category `video_filter` |
| `libanaglyph_plugin.dll` | 43 KB | `anaglyph` | VLC module in category `video_filter` |
| `libantiflicker_plugin.dll` | 42 KB | `antiflicker` | VLC module in category `video_filter` |
| `libball_plugin.dll` | 53 KB | `ball` | VLC module in category `video_filter` |
| `libblend_plugin.dll` | 202 KB | `blend` | VLC module in category `video_filter` |
| `libblendbench_plugin.dll` | 42 KB | `blendbench` | VLC module in category `video_filter` |
| `libbluescreen_plugin.dll` | 42 KB | `bluescreen` | VLC module in category `video_filter` |
| `libcanvas_plugin.dll` | 65 KB | `canvas` | VLC module in category `video_filter` |
| `libcolorthres_plugin.dll` | 42 KB | `colorthres` | VLC module in category `video_filter` |
| `libcroppadd_plugin.dll` | 45 KB | `croppadd` | VLC module in category `video_filter` |
| `libdeinterlace_plugin.dll` | 180 KB | `deinterlace` | VLC module in category `video_filter` |
| `libedgedetection_plugin.dll` | 39 KB | `edgedetection` | VLC module in category `video_filter` |
| `liberase_plugin.dll` | 45 KB | `erase` | VLC module in category `video_filter` |
| `libextract_plugin.dll` | 43 KB | `extract` | VLC module in category `video_filter` |
| `libfps_plugin.dll` | 40 KB | `fps` | VLC module in category `video_filter` |
| `libfreeze_plugin.dll` | 43 KB | `freeze` | VLC module in category `video_filter` |
| `libgaussianblur_plugin.dll` | 42 KB | `gaussianblur` | VLC module in category `video_filter` |
| `libgradfun_plugin.dll` | 48 KB | `gradfun` | VLC module in category `video_filter` |
| `libgradient_plugin.dll` | 50 KB | `gradient` | VLC module in category `video_filter` |
| `libgrain_plugin.dll` | 45 KB | `grain` | VLC module in category `video_filter` |
| `libhqdn3d_plugin.dll` | 50 KB | `hqdn3d` | VLC module in category `video_filter` |
| `libinvert_plugin.dll` | 39 KB | `invert` | VLC module in category `video_filter` |
| `libmagnify_plugin.dll` | 43 KB | `magnify` | VLC module in category `video_filter` |
| `libmirror_plugin.dll` | 43 KB | `mirror` | VLC module in category `video_filter` |
| `libmotionblur_plugin.dll` | 40 KB | `motionblur` | VLC module in category `video_filter` |
| `libmotiondetect_plugin.dll` | 44 KB | `motiondetect` | VLC module in category `video_filter` |
| `liboldmovie_plugin.dll` | 50 KB | `oldmovie` | VLC module in category `video_filter` |
| `libposterize_plugin.dll` | 43 KB | `posterize` | VLC module in category `video_filter` |
| `libpostproc_plugin.dll` | 459 KB | `postproc` | VLC module in category `video_filter` |
| `libpsychedelic_plugin.dll` | 40 KB | `psychedelic` | VLC module in category `video_filter` |
| `libpuzzle_plugin.dll` | 101 KB | `puzzle` | VLC module in category `video_filter` |
| `libripple_plugin.dll` | 40 KB | `ripple` | VLC module in category `video_filter` |
| `librotate_plugin.dll` | 82 KB | `rotate` | VLC module in category `video_filter` |
| `libscale_plugin.dll` | 39 KB | `scale` | VLC module in category `video_filter` |
| `libscene_plugin.dll` | 65 KB | `scene` | VLC module in category `video_filter` |
| `libsepia_plugin.dll` | 43 KB | `sepia` | VLC module in category `video_filter` |
| `libsharpen_plugin.dll` | 41 KB | `sharpen` | VLC module in category `video_filter` |
| `libtransform_plugin.dll` | 52 KB | `transform` | VLC module in category `video_filter` |
| `libvhs_plugin.dll` | 44 KB | `vhs` | VLC module in category `video_filter` |
| `libwave_plugin.dll` | 39 KB | `wave` | VLC module in category `video_filter` |

#### Category: `plugins/video_output` (15 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libcaca_plugin.dll` | 839 KB | `caca` | VLC module in category `video_output` |
| `libdirect3d11_plugin.dll` | 399 KB | `direct3d11` | VLC module in category `video_output` |
| `libdirect3d9_plugin.dll` | 317 KB | `direct3d9` | VLC module in category `video_output` |
| `libdirectdraw_plugin.dll` | 299 KB | `directdraw` | VLC module in category `video_output` |
| `libdrawable_plugin.dll` | 39 KB | `drawable` | VLC module in category `video_output` |
| `libflaschen_plugin.dll` | 64 KB | `flaschen` | VLC module in category `video_output` |
| `libgl_plugin.dll` | 232 KB | `gl` | VLC module in category `video_output` |
| `libglinterop_dxva2_plugin.dll` | 122 KB | `glinterop_dxva2` | VLC module in category `video_output` |
| `libglwin32_plugin.dll` | 451 KB | `glwin32` | VLC module in category `video_output` |
| `libvdummy_plugin.dll` | 40 KB | `vdummy` | VLC module in category `video_output` |
| `libvmem_plugin.dll` | 41 KB | `vmem` | VLC module in category `video_output` |
| `libwgl_plugin.dll` | 230 KB | `wgl` | VLC module in category `video_output` |
| `libwingdi_plugin.dll` | 284 KB | `wingdi` | VLC module in category `video_output` |
| `libwinhibit_plugin.dll` | 39 KB | `winhibit` | VLC module in category `video_output` |
| `libyuv_plugin.dll` | 64 KB | `yuv` | VLC module in category `video_output` |

#### Category: `plugins/video_splitter` (3 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libclone_plugin.dll` | 40 KB | `clone` | VLC module in category `video_splitter` |
| `libpanoramix_plugin.dll` | 65 KB | `panoramix` | VLC module in category `video_splitter` |
| `libwall_plugin.dll` | 80 KB | `wall` | VLC module in category `video_splitter` |

#### Category: `plugins/visualization` (4 plugins)
| File Name | Size (KB) | Inferred Subsystem / Codec / Protocol | Description / Capabilities |
|---|---|---|---|
| `libglspectrum_plugin.dll` | 49 KB | `glspectrum` | VLC module in category `visualization` |
| `libgoom_plugin.dll` | 236 KB | `goom` | VLC module in category `visualization` |
| `libprojectm_plugin.dll` | 1,714 KB | `projectm` | VLC module in category `visualization` |
| `libvisual_plugin.dll` | 66 KB | `visual` | VLC module in category `visualization` |

---

## 3. Qt Interface Architecture & UI Component Catalog

VLC's primary graphical user interface on desktop platforms is implemented by `plugins\gui\libqt_plugin.dll` (17.25 MB). Forensic reverse engineering reveals this binary embeds a static build of **Qt 5.6.3** (`i386-little_endian-ilp32 static release build; by GCC 6.4.0`).

### 1. Primary Dialog Inventory (25+ Core Windows)
Static symbol extraction reveals 257 Qt classes. The primary dialog hierarchy consists of:
| Dialog Class | User-Facing Window Title | Functionality & Features |
|---|---|---|
| `OpenDialog` | Open Media | Multi-tab media loader: File (single/multi), Disc (DVD/Blu-ray/VCD/CDDA), Network (HTTP/RTSP/RTMP/HLS), Capture Device (Webcam, Desktop/Screen, DirectShow) |
| `PrefsDialog` (`SPrefsPanel` & `AdvPrefsPanel`) | Preferences | Dual-mode preferences: Simple Preferences (Audio, Video, Subtitles, Input/Codecs, Hotkeys, Interface) and Advanced Preferences (hierarchical tree of 1,615 parameters) |
| `ExtendedDialog` (`Epanel`) | Adjustments and Effects | Audio Equalizer (10 bands + preamp), Spatializer, Compressor, Video Effects (Color Adjust, Sharpen, Crop, Rotate, Puzzle, Watermark, Logo), Synchronization (AV & Sub sync) |
| `BookmarksDialog` | Edit Bookmarks | Media timestamp bookmarks list (timestamp, title, extractable). Supports 10 hotkey-accessible quick bookmarks |
| `MessagesDialog` | Messages / Logger | Diagnostic debug log console with severity filtering (0: Info, 1: Error, 2: Warning, 3: Debug). Supports live log dump and save-to-file |
| `PluginDialog` | Plugins and Extensions | Extensions manager, skin catalog browser, Lua plugin updater, addons repository installer |
| `VLMDialog` (`VLMAWidget`) | VLM Configurator | VideoLAN Manager GUI for creating multi-stream broadcast channels, video-on-demand (VoD) instances, and schedule inputs |
| `ConvertDialog` / `SoutDialog` | Convert / Stream | Stream output wizard: source MRL, destination (File, HTTP, MS-WMSP, RTSP, RTP, UDP, Icecast), Transcode profiles (H.264+MP3, VP8+Vorbis, TS, WebM) |
| `TrackPickerDialog` | Track Selection | Multi-track selector for complex media with multiple audio, video, and subtitle streams |
| `GotoTimeDialog` | Go to Time | Precision time jump dialog (Hours:Minutes:Seconds) with live preview |
| `MediaInfoDialog` | Media Information | Current media metadata (Title, Artist, Album, Year, Track, Genre), Codec Details (stream 0/1 codec, sample rate, bit depth), Statistics (read bytes, demux bytes, lost frames) |
| `UpdateDialog` | Check for Updates | Cryptographically signed update checking mechanism contacting VideoLAN servers |
| `AboutDialog` | About VLC media player | Authors, license (GPLv2+), compiler specifications, and acknowledgments |

### 2. Custom Player Controls & Widgets
- **`PlayButton`, `LoopButton`, `AtoB_Button`**: Play/Pause toggle, loop mode cycle (No loop -> Loop playlist -> Repeat single item), and A-to-B interval repeating (press once to set marker A, press again to set marker B, loops between A and B indefinitely).
- **`SeekSlider`**: High-precision timeline scrubber with elapsed time, remaining time toggle (`ShowRemainingTime`), chapter ticks, and mouse hover preview.
- **`SoundSlider` & `SoundWidget`**: Volume slider supporting over-amplification up to 125% (or configurable up to 300% via `--qt-max-volume`). Color coded via `--qt-slider-colours`.
- **`SyncWidget`**: Visual interactive synchronization slider for microsecond-level audio-to-video and subtitle-to-video offset alignment.
- **`PicFlowView`**: 3D CoverFlow album art visualizer for music and video collections.
- **`PlListView`, `PlTreeView`, `PlIconView`**: Three distinct layout modes for playlist items: detailed tabular list, nested hierarchical folder tree, and thumbnail grid icon view.

### 3. Toolbar Layout Profiles & Toolbar Customizer
VLC includes a visual drag-and-drop toolbar editor that saves layout definitions in `%APPDATA%\vlc\vlc-qt-interface.ini`. Six pre-configured profiles are defined:
1. **VLC 2.x.x Style**: Standard modern layout with dual-line controls (timeline slider on top, transport buttons, volume, and extended settings button on bottom).
2. **VLC 1.1.x Style**: Classic dual-line layout with record, snapshot, and loop buttons integrated into the bottom bar.
3. **VLC 0.8.x Style**: Compact single-line transport bar with separate stop and disc navigation buttons.
4. **Minimalist Style**: Ultra-thin bar displaying only play/pause, volume, timeline, and fullscreen button.
5. **One-Liner Style**: Compact interface placing timeline and playback controls on a single horizontal row to maximize video display height.
6. **Simplest Style**: Bare-bones controls containing only play, volume, and seekbar.

### 4. Qt Interface Configuration Options (`--qt-*`)
All 30 Qt options extracted from VLC CLI options:
| CLI Option Flag | Default Value | Technical Purpose |
|---|---|---|
| `--qt-minimal-view` | `disabled` | Launches VLC without menu bar or window decorations |
| `--qt-system-tray` | `enabled` | Displays persistent notification tray icon in Windows Taskbar |
| `--qt-notification` | `1` (When minimized) | Toast notification on track change (0: Never, 1: Minimized, 2: Always) |
| `--qt-start-minimized` | `disabled` | Starts player minimized directly to system tray |
| `--qt-pause-minimized` | `disabled` | Automatically pauses video playback when main window is minimized |
| `--qt-opacity` | `1.0` (range 0.1-1.0) | Window alpha transparency for main interface and extended panels |
| `--qt-fs-opacity` | `1.0` (range 0.1-1.0) | Floating fullscreen controller alpha transparency |
| `--qt-video-autoresize`| `enabled` | Auto-resizes player window to match native video resolution |
| `--qt-name-in-title` | `enabled` | Displays current media title in operating system window title bar |
| `--qt-fs-controller` | `enabled` | Shows floating auto-hiding HUD controller in fullscreen mode |
| `--qt-recentplay` | `enabled` | Records recently played media items in Media menu |
| `--qt-recentplay-filter`| `(empty)` | Regular expression to exclude matching file paths from recents |
| `--qt-continue` | `1` (Ask) | Resume playback prompt: 0: Never, 1: Ask user, 2: Always resume |
| `--qt-dark-palette` | `disabled` | Forces Qt dark theme color palette across all dialogs |
| `--qt-updates-notif` | `enabled` | Automatically polls for newer VLC releases bi-weekly |
| `--qt-updates-days` | `14` days | Check interval for software updates |
| `--qt-disable-volume-keys`| `enabled` | Passes multimedia volume keys to Windows OS when enabled |
| `--qt-embedded-open` | `disabled` | Embeds mini file browser directly inside Open Media dialog |
| `--qt-advanced-pref` | `disabled` | Opens Advanced tree preferences by default instead of Simple |
| `--qt-error-dialogs` | `enabled` | Suppresses or reveals non-fatal error dialog popups |
| `--qt-slider-colours`| `255;255;255;...` | 12-value semicolon-delimited RGB color gradient for volume slider |
| `--qt-privacy-ask` | `disabled` | Prompts user on first launch for network metadata policy approval |
| `--qt-fullscreen-screennumber`| `-1` (Current) | Specifies monitor index for fullscreen video display |
| `--qt-autoload-extensions`| `enabled` | Automatically loads extensions from `lua/extensions/` at launch |
| `--qt-bgcone` | `enabled` | Displays iconic orange cone background when no video is loaded |
| `--qt-bgcone-expands`| `disabled` | Expands background cone or album art to fill window dimensions |
| `--qt-icon-change` | `enabled` | Allows dynamic window icon modification on events |
| `--qt-max-volume` | `125` (range 60-300)| Maximum volume limit displayed on slider |
| `--qt-fs-sensitivity`| `3` | Mouse movement sensitivity threshold to trigger fullscreen HUD |
| `--qt-auto-raise` | `0` (Never) | Auto-raises player window above other windows on playback start |

### 5. Skins2 Skinning Engine (`libskins2_plugin.dll` & `skins/`)
- **Skins Engine**: `plugins\gui\libskins2_plugin.dll` allows complete UI replacement using XML/bitmap skins.
- **Default Skin**: `skins\default.vlt` (163,618 bytes gzipped archive containing XML layout and PNG slices).
- **Winamp 2 Skin Support**: `skins\winamp2.xml` (32,210 bytes) maps Winamp 2.x classic skins (`.wsz`) directly into VLC's skins2 architecture, supporting Winamp main window, equalizer window, and playlist editor.

---

## 4. CLI Options, Configuration & Hotkey System

VLC incorporates one of the most comprehensive parameterization systems in media software. All engine modules register typed variables into the central configuration registry.

### 1. CLI Syntax Specification
- `--option`: Global option active for program execution duration (e.g. `--fullscreen`, `--no-audio`).
- `-option`: Single-letter abbreviation for global flags (e.g. `-f`, `-v`, `-q`).
- `:option=value`: MRL-specific option applying strictly to the input immediately preceding it (e.g. `vlc file.mkv :start-time=30 :stop-time=120 :audio-track=2`).

### 2. High-Impact Operational Configuration Parameters
#### Playback Caching & Buffer Latencies
| Parameter Flag | Default Value | Latency Range | Purpose |
|---|---|---|---|
| `--file-caching` | `1000` ms | 0 .. 60000 ms | Local disk read cache. Prevents stutter during slow disk access |
| `--network-caching` | `1000` ms | 0 .. 60000 ms | Network stream buffer (HTTP, RTSP, SMB, NFS). Absorbs network jitter |
| `--disc-caching` | `300` ms | 0 .. 60000 ms | Optical drive spin buffer (DVD, Blu-ray, Audio CD) |
| `--live-caching` | `300` ms | 0 .. 60000 ms | Low-latency live capture buffer (Webcam, TV tuners, Desktop) |
| `--sout-mux-caching` | `1500` ms | 0 .. 60000 ms | Stream output multiplexer buffer before transmission |

#### Hardware Decoding & Video Rendering
| Parameter Flag | Valid Values | Operational Behavior |
|---|---|---|
| `--avcodec-hw` | `any`, `d3d11va`, `dxva2`, `none` | Hardware decoding acceleration engine. Defaults to `any` (tries D3D11VA -> DXVA2 -> software fallback) |
| `--vout` | `any`, `direct3d11`, `direct3d9`, `glwin32`, `gl`, `directdraw`, `wingdi`, `caca` | Video display output module. Direct3D 11 is primary on Windows 10/11 |
| `--deinterlace` | `-1` (Auto), `0` (Off), `1` (On) | Controls video deinterlacing engine |
| `--deinterlace-mode`| `auto`, `discard`, `blend`, `mean`, `bob`, `linear`, `x`, `yadif`, `yadif2x`, `phosphor`, `ivtc` | Algorithmic deinterlacing filter. `yadif` / `yadif2x` provides motion-adaptive deinterlacing |

#### Audio Equalizer Specification
- **Bands (10 Bands)**: `60 Hz`, `170 Hz`, `310 Hz`, `600 Hz`, `1 kHz`, `3 kHz`, `6 kHz`, `12 kHz`, `14 kHz`, `16 kHz`.
- **Gain Range**: `-20.0 dB` to `+20.0 dB` per band; Preamp `-20.0 dB` to `+20.0 dB`.
- **18 Shipped Presets**: `flat`, `classical`, `club`, `dance`, `fullbass`, `fullbasstreble`, `fulltreble`, `headphones`, `largehall`, `live`, `party`, `pop`, `reggae`, `rock`, `ska`, `soft`, `softrock`, `techno`.

### 3. Exhaustive Hotkey Mapping Table (111 Actions)
VLC provides 111 configurable keyboard actions, duplicated as 111 global hotkeys (`--global-key-*`). Below is the verified default key map extracted from `%APPDATA%\vlc\vlcrc`:

| Action Identifier | Description | Default Keyboard Shortcut | Global Key Equivalent |
|---|---|---|---|
| `key-toggle-fullscreen` | Toggle Fullscreen | `f` | `--global-key-toggle-fullscreen` |
| `key-leave-fullscreen` | Leave Fullscreen | `Esc` | `--global-key-leave-fullscreen` |
| `key-play-pause` | Play Pause | `Space` | `--global-key-play-pause` |
| `key-pause` | Pause | `Browser Stop` | `--global-key-pause` |
| `key-play` | Play | `Browser Refresh` | `--global-key-play` |
| `key-faster` | Faster | `+` | `--global-key-faster` |
| `key-slower` | Slower | `-` | `--global-key-slower` |
| `key-rate-normal` | Rate Normal | `=` | `--global-key-rate-normal` |
| `key-rate-faster-fine` | Rate Faster Fine | `]` | `--global-key-rate-faster-fine` |
| `key-rate-slower-fine` | Rate Slower Fine | `[` | `--global-key-rate-slower-fine` |
| `key-next` | Next | `n` | `--global-key-next` |
| `key-prev` | Prev | `p` | `--global-key-prev` |
| `key-stop` | Stop | `s` | `--global-key-stop` |
| `key-position` | Position | `t` | `--global-key-position` |
| `key-jump-extrashort` | Jump Extrashort | `Shift+Left` | `--global-key-jump-extrashort` |
| `key-jump+extrashort` | Jump+Extrashort | `Shift+Right` | `--global-key-jump+extrashort` |
| `key-jump-short` | Jump Short | `Alt+Left` | `--global-key-jump-short` |
| `key-jump+short` | Jump+Short | `Alt+Right` | `--global-key-jump+short` |
| `key-jump-medium` | Jump Medium | `Ctrl+Left` | `--global-key-jump-medium` |
| `key-jump+medium` | Jump+Medium | `Ctrl+Right` | `--global-key-jump+medium` |
| `key-jump-long` | Jump Long | `Ctrl+Alt+Left` | `--global-key-jump-long` |
| `key-jump+long` | Jump+Long | `Ctrl+Alt+Right` | `--global-key-jump+long` |
| `key-frame-next` | Frame Next | `e` | `--global-key-frame-next` |
| `key-nav-activate` | Nav Activate | `Enter` | `--global-key-nav-activate` |
| `key-nav-up` | Nav Up | `Up` | `--global-key-nav-up` |
| `key-nav-down` | Nav Down | `Down` | `--global-key-nav-down` |
| `key-nav-left` | Nav Left | `Left` | `--global-key-nav-left` |
| `key-nav-right` | Nav Right | `Right` | `--global-key-nav-right` |
| `key-disc-menu` | Disc Menu | `Shift+m` | `--global-key-disc-menu` |
| `key-title-prev` | Title Prev | `Shift+o` | `--global-key-title-prev` |
| `key-title-next` | Title Next | `Shift+b` | `--global-key-title-next` |
| `key-chapter-prev` | Chapter Prev | `Shift+p` | `--global-key-chapter-prev` |
| `key-chapter-next` | Chapter Next | `Shift+n` | `--global-key-chapter-next` |
| `key-quit` | Quit | `Ctrl+q` | `--global-key-quit` |
| `key-vol-up` | Vol Up | `Ctrl+Up` | `--global-key-vol-up` |
| `key-vol-down` | Vol Down | `Ctrl+Down` | `--global-key-vol-down` |
| `key-vol-mute` | Vol Mute | `m` | `--global-key-vol-mute` |
| `key-subdelay-up` | Subdelay Up | `h` | `--global-key-subdelay-up` |
| `key-subdelay-down` | Subdelay Down | `g` | `--global-key-subdelay-down` |
| `key-subsync-markaudio` | Subsync Markaudio | `Shift+h` | `--global-key-subsync-markaudio` |
| `key-subsync-marksub` | Subsync Marksub | `Shift+j` | `--global-key-subsync-marksub` |
| `key-subsync-apply` | Subsync Apply | `Shift+k` | `--global-key-subsync-apply` |
| `key-subsync-reset` | Subsync Reset | `Ctrl+Shift+k` | `--global-key-subsync-reset` |
| `key-subpos-up` | Subpos Up | *Unassigned* | `--global-key-subpos-up` |
| `key-subpos-down` | Subpos Down | *Unassigned* | `--global-key-subpos-down` |
| `key-audiodelay-up` | Audiodelay Up | `k` | `--global-key-audiodelay-up` |
| `key-audiodelay-down` | Audiodelay Down | `j` | `--global-key-audiodelay-down` |
| `key-audio-track` | Audio Track | `b` | `--global-key-audio-track` |
| `key-audiodevice-cycle` | Audiodevice Cycle | `Shift+a` | `--global-key-audiodevice-cycle` |
| `key-subtitle-revtrack` | Subtitle Revtrack | `Alt+v` | `--global-key-subtitle-revtrack` |
| `key-subtitle-track` | Subtitle Track | `v` | `--global-key-subtitle-track` |
| `key-subtitle-toggle` | Subtitle Toggle | `Shift+v` | `--global-key-subtitle-toggle` |
| `key-program-sid-next` | Program Sid Next | `x` | `--global-key-program-sid-next` |
| `key-program-sid-prev` | Program Sid Prev | `Shift+x` | `--global-key-program-sid-prev` |
| `key-aspect-ratio` | Aspect Ratio | `a` | `--global-key-aspect-ratio` |
| `key-crop` | Crop | `c` | `--global-key-crop` |
| `key-toggle-autoscale` | Toggle Autoscale | `o` | `--global-key-toggle-autoscale` |
| `key-incr-scalefactor` | Incr Scalefactor | `Alt+o` | `--global-key-incr-scalefactor` |
| `key-decr-scalefactor` | Decr Scalefactor | `Alt+Shift+o` | `--global-key-decr-scalefactor` |
| `key-deinterlace` | Deinterlace | `d` | `--global-key-deinterlace` |
| `key-deinterlace-mode` | Deinterlace Mode | `Shift+d` | `--global-key-deinterlace-mode` |
| `key-intf-show` | Intf Show | `i` | `--global-key-intf-show` |
| `key-intf-boss` | Intf Boss | *Unassigned* | `--global-key-intf-boss` |
| `key-intf-popup-menu` | Intf Popup Menu | `Menu` | `--global-key-intf-popup-menu` |
| `key-snapshot` | Snapshot | `Shift+s` | `--global-key-snapshot` |
| `key-record` | Record | `Shift+r` | `--global-key-record` |
| `key-zoom` | Zoom | `z` | `--global-key-zoom` |
| `key-unzoom` | Unzoom | `Shift+z` | `--global-key-unzoom` |
| `key-wallpaper` | Wallpaper | `w` | `--global-key-wallpaper` |
| `key-crop-top` | Crop Top | `Alt+r` | `--global-key-crop-top` |
| `key-uncrop-top` | Uncrop Top | `Alt+Shift+r` | `--global-key-uncrop-top` |
| `key-crop-left` | Crop Left | `Alt+d` | `--global-key-crop-left` |
| `key-uncrop-left` | Uncrop Left | `Alt+Shift+d` | `--global-key-uncrop-left` |
| `key-crop-bottom` | Crop Bottom | `Alt+c` | `--global-key-crop-bottom` |
| `key-uncrop-bottom` | Uncrop Bottom | `Alt+Shift+c` | `--global-key-uncrop-bottom` |
| `key-crop-right` | Crop Right | `Alt+f` | `--global-key-crop-right` |
| `key-uncrop-right` | Uncrop Right | `Alt+Shift+f` | `--global-key-uncrop-right` |
| `key-random` | Random | `r` | `--global-key-random` |
| `key-loop` | Loop | `l` | `--global-key-loop` |
| `key-viewpoint-fov-in` | Viewpoint Fov In | `Page Up` | `--global-key-viewpoint-fov-in` |
| `key-viewpoint-fov-out` | Viewpoint Fov Out | `Page Down` | `--global-key-viewpoint-fov-out` |
| `key-viewpoint-roll-clock` | Viewpoint Roll Clock | *Unassigned* | `--global-key-viewpoint-roll-clock` |
| `key-viewpoint-roll-anticlock` | Viewpoint Roll Anticlock | *Unassigned* | `--global-key-viewpoint-roll-anticlock` |
| `key-zoom-quarter` | Zoom Quarter | `Alt+1` | `--global-key-zoom-quarter` |
| `key-zoom-half` | Zoom Half | `Alt+2` | `--global-key-zoom-half` |
| `key-zoom-original` | Zoom Original | `Alt+3` | `--global-key-zoom-original` |
| `key-zoom-double` | Zoom Double | `Alt+4` | `--global-key-zoom-double` |
| `key-set-bookmark1` | Set Bookmark1 | `Ctrl+F1` | `--global-key-set-bookmark1` |
| `key-set-bookmark2` | Set Bookmark2 | `Ctrl+F2` | `--global-key-set-bookmark2` |
| `key-set-bookmark3` | Set Bookmark3 | `Ctrl+F3` | `--global-key-set-bookmark3` |
| `key-set-bookmark4` | Set Bookmark4 | `Ctrl+F4` | `--global-key-set-bookmark4` |
| `key-set-bookmark5` | Set Bookmark5 | `Ctrl+F5` | `--global-key-set-bookmark5` |
| `key-set-bookmark6` | Set Bookmark6 | `Ctrl+F6` | `--global-key-set-bookmark6` |
| `key-set-bookmark7` | Set Bookmark7 | `Ctrl+F7` | `--global-key-set-bookmark7` |
| `key-set-bookmark8` | Set Bookmark8 | `Ctrl+F8` | `--global-key-set-bookmark8` |
| `key-set-bookmark9` | Set Bookmark9 | `Ctrl+F9` | `--global-key-set-bookmark9` |
| `key-set-bookmark10` | Set Bookmark10 | `Ctrl+F10` | `--global-key-set-bookmark10` |
| `key-play-bookmark1` | Play Bookmark1 | `F1` | `--global-key-play-bookmark1` |
| `key-play-bookmark2` | Play Bookmark2 | `F2` | `--global-key-play-bookmark2` |
| `key-play-bookmark3` | Play Bookmark3 | `F3` | `--global-key-play-bookmark3` |
| `key-play-bookmark4` | Play Bookmark4 | `F4` | `--global-key-play-bookmark4` |
| `key-play-bookmark5` | Play Bookmark5 | `F5` | `--global-key-play-bookmark5` |
| `key-play-bookmark6` | Play Bookmark6 | `F6` | `--global-key-play-bookmark6` |
| `key-play-bookmark7` | Play Bookmark7 | `F7` | `--global-key-play-bookmark7` |
| `key-play-bookmark8` | Play Bookmark8 | `F8` | `--global-key-play-bookmark8` |
| `key-play-bookmark9` | Play Bookmark9 | `F9` | `--global-key-play-bookmark9` |
| `key-play-bookmark10` | Play Bookmark10 | `F10` | `--global-key-play-bookmark10` |
| `key-clear-playlist` | Clear Playlist | `Ctrl+w` | `--global-key-clear-playlist` |
| `key-subtitle-text-scale-normal` | Subtitle Text Scale Normal | `Ctrl+0` | `--global-key-subtitle-text-scale-normal` |
| `key-subtitle-text-scale-up` | Subtitle Text Scale Up | `Ctrl+Mouse Wheel Up` | `--global-key-subtitle-text-scale-up` |
| `key-subtitle-text-scale-down` | Subtitle Text Scale Down | `Ctrl+Mouse Wheel Down` | `--global-key-subtitle-text-scale-down` |

---

## 5. Lua Scripts Ecosystem (`lua/` Hierarchy)

VLC embeds a full Lua 5.1 runtime managed by `plugins\lua\liblua_plugin.dll` (377 KB). The Lua subsystem provides extensions, metadata scrapers, online playlist stream extractors, and remote control servers.

### Directory Structure & Functional Matrix
| Subdirectory | Files Count | Core Functionality | Key Modules / Scripts |
|---|---|---|---|
| `extensions/` | 1 | GUI extensions loaded into View menu | `VLSub.luac` (OpenSubtitles downloader) |
| `http/` | 40+ files | Embedded HTTP Web Server & AJAX Remote | `index.html`, `mobile.html`, `requests/*.json`, CSS/JS |
| `intf/` | 8 | Remote interfaces & CLI | `cli.luac` (Console), `telnet.luac` (Telnet port 4212), `http.luac` |
| `meta/art/` | 4 | Online album art scrapers | `00_musicbrainz.luac`, `01_googleimage.luac`, `02_frenchtv.luac`, `03_lastfm.luac` |
| `meta/reader/` | 1 | Filename metadata parser | `filename.luac` (extracts artist/title from filename heuristics) |
| `modules/` | 4 | Reusable Lua libraries | `common.luac`, `dkjson.luac` (JSON parser), `sandbox.luac`, `simplexml.luac` |
| `playlist/` | 15 | Online video/audio stream extractors | `dailymotion`, `soundcloud`, `twitch`, `vimeo`, `appletrailers`, `cue`, etc. |
| `sd/` | 2 | Services Discovery scripts | `icecast.luac` (Icecast radio directory), `jamendo.luac` (Jamendo music) |

### Deep-Dive: Key Lua Modules
#### 1. `VLSub.luac` (OpenSubtitles Integration)
- **Workflow**: Calculates file byte size and a 64-bit checksum over the first and last 64 KB of the media file (`MovieHash`).
- **Search**: Queries OpenSubtitles XML-RPC / REST API using the hash (exact sync match) or falls back to video title search.
- **Download**: Fetches `.srt` or `.sub` payload, decompresses gzip, writes file adjacent to video file, and calls `vlc.item:add_subtitle()`.

#### 2. Embedded HTTP Server & REST API (`http/`)
- **Web Interfaces**: Includes desktop HTML5 web player (`index.html`) and responsive mobile web app (`mobile.html`).
- **REST-Like Endpoints**:
  - `/requests/status.json`: Complete playback telemetry (state: playing/paused/stopped, time, position, volume, rate, audio/video track indices, metadata).
  - `/requests/playlist.json`: Full playlist hierarchy tree with IDs, durations, and URIs.
  - `/requests/browse.json?dir=<path>`: Remote filesystem directory browser.
  - `/art`: Fetches current media album art binary.
- **Commands Supported**: `in_play`, `in_enqueue`, `pl_pause`, `pl_stop`, `pl_next`, `pl_previous`, `volume`, `seek`, `rate`, `aspectratio`, `audiodelay`, `subdelay`, `equalizer`, `preamp`, `enableeq`, `setpreset`.

#### 3. Telnet Server (`intf/telnet.luac`)
- Listens on TCP port `4212` by default. Accepts password authentication and provides command-line control of the player and VLM streaming broadcasts.

---

## 6. Forensic Synthesis & Architectural Takeaways for E-Player

VLC's 30-year evolutionary architecture provides concrete, field-tested design patterns that directly guide E-Player's Flutter development roadmap:

1. **Two-Tier Separation (Microkernel vs Presentation)**: VLC isolates audio/video decoding and clock synchronization inside `libvlccore` and `libvlc`, ensuring UI crashes or latency never stutter audio/video rendering. E-Player must maintain strict isolation between Flutter UI widgets and background playback isolates/media players.
2. **Resilience Through Multi-Stage Hardware Fallback**: VLC never crashes on unsupported hardware; it attempts Direct3D 11 (`d3d11va`), falls back to DirectX 9 (`dxva2`), and gracefully degrades to multi-threaded software FFmpeg (`avcodec`). E-Player's video player backend must implement equivalent progressive fallback cascades.
3. **Precision Navigation & Jump Granularity**: VLC's four-tier jump system (3s, 10s, 1m, 5m) provides optimal control across both short clips and multi-hour feature films. E-Player should adopt this multi-tiered seeking model.
4. **Real-Time Offset Sync Engine**: Audio/video sync and subtitle sync in VLC operate on runtime PTS/DTS offsets without modifying or re-encoding media files. E-Player needs runtime delay offset controls (+/- 50ms steps).
5. **State & Geometry Persistence**: VLC preserves resume playback timestamps (`times` in `vlc-qt-interface.ini`) and window geometry across sessions. E-Player's History and Library features must persist playback progress reliably.

---
**Report Compiled By:** CYPHER (Forensic Telemetry Specialist)  
**Verification Status:** Complete and verified directly against `C:\Program Files (x86)\VideoLAN\VLC`  