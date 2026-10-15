# E-PLAYER PRD V3 — ADVANCED MEDIA ENGINE & FEATURE HARDENING

## 1. Objective
Upgrade the current mid-process E-Player into a production-grade cross-platform media application while preserving working playback, subtitle rendering, C++ FFI and Enhancement Studio UI.

## 2. Product requirements
### P0 playback reliability
- universal practical local playback based on the shipped codec/container matrix;
- Auto/Hardware/Hybrid/Software capability modes;
- hardware/software fallback without crashes;
- accurate A/V sync;
- lifecycle-safe pause/resume/seek/orientation;
- high-resolution playback;
- diagnostics for actual decoder/provider.

### P0 player UX
- 0.25x–8x speed;
- pitch preservation where backend supports it;
- fit/fill/crop/stretch/original/aspect presets;
- configurable gestures;
- pinch-to-zoom/pan;
- player information overlay;
- lock controls.

### P0 subtitles
- existing libass path retained;
- SRT/VTT/ASS/SSA/embedded/image subtitle support as actually supported by backend;
- delay;
- font size/color;
- outline;
- background opacity;
- encoding override;
- provider abstraction for optional subtitle download.

### P1 audio
- 5-band EQ;
- curated presets;
- Bass Boost;
- limiter;
- preamp;
- dialogue boost;
- night mode;
- optional virtualizer;
- pitch-preserving speed.

### P1 background + PiP
- Android MediaSession/background service;
- Android system PiP;
- iOS AVAudioSession background playback;
- iOS PiP where supported;
- lock-screen/headset controls.

### P1 library
- local indexing;
- MediaStore/SAF-based Android paths;
- iOS document-picker/security-scoped access;
- incremental scanning;
- exclusions;
- search/sort/filter;
- watch state;
- thumbnails.

### P1 privacy
- encrypted vault;
- biometric/PIN unlock;
- platform secure key storage;
- encrypted metadata;
- trash/recovery;
- TTL cleanup;
- tamper/error handling.

### P1 network
- HTTP/HTTPS;
- HLS;
- DASH where verified;
- RTSP where verified;
- later SMB/NAS;
- safe URL/credential handling.

### P1 casting
- Google Cast;
- AirPlay where selected;
- local-file casting through a tokenized local HTTP server;
- no directory listing;
- automatic server shutdown.

### P0 AI readiness
- real model registry;
- native/mobile ONNX runtime interface;
- offline export pipeline;
- no fake AI labels;
- bounded frame queues;
- cancellation;
- model/version/checksum metadata.

### P1 AI enhancement
- Real-ESRGAN-derived model;
- RIFE-derived model;
- audio denoise/enhancement;
- depth/3D as capability-gated advanced feature.

## 3. Quality requirements
- no P0/P1 crash/blocker;
- no unbounded memory growth;
- no permanent A/V drift;
- no false AI state;
- offline core playback;
- secure vault;
- clean cancel/failure of export.

## 4. Platform principles
- Android and iOS require native lifecycle integrations for background playback/PiP/security.
- Flutter remains UI/orchestration.
- C++/FFI remains the performance boundary.
- media_kit/libmpv remains the primary playback backend unless evidence requires a fallback adapter.
