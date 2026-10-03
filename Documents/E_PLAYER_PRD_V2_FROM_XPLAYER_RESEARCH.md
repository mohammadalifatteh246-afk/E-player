# E-PLAYER PRD V2
## Completion & Expansion Product Requirements Document

**Version:** 2.0  
**Date:** 2026-10-01  
**Project:** E-Player — Offline AI-Enhanced Multimedia Player  
**Targets:** Android + iOS, with Windows retained as the reference/development platform

## 1. Purpose

This PRD is a continuation specification for the existing E-Player repository. It does not restart the project. It converts the current progress report plus the uploaded XPlayer/HD research into a concrete completion contract, while independently verifying platform and runtime decisions against current documentation.

Current reported state to preserve and verify:
- Flutter application exists.
- `media_kit` + libmpv playback is integrated.
- Custom `PlayerScreen` exists.
- Audio/subtitle track selection exists.
- Native subtitle/libass behavior is working.
- Enhancement Studio UI exists.
- C++ native engine + Dart FFI exists.
- Windows native build works.
- Enhancement processing is currently simulated DSP/filter behavior, not real neural inference.
- Android/iOS production integration and many parity features remain.

The reported completion percentages are treated as self-reported status. Antigravity must verify the repository before changing them.

## 2. Product Vision

E-Player combines:
1. Broad local multimedia playback.
2. Hardware-aware decoding.
3. Modern mobile gestures.
4. Advanced subtitle controls.
5. Audio EQ and enhancement.
6. Media-library indexing.
7. Encrypted private storage.
8. Trash/recovery.
9. Background playback.
10. Picture-in-Picture.
11. Network URL playback.
12. Chromecast/AirPlay-style casting where supported.
13. Real on-device video enhancement.
14. Real on-device audio enhancement.
15. Offline enhanced export.
16. Device-aware adaptive quality.

**Non-negotiable rule:** normal playback must remain usable when AI is unavailable.

## 3. Architecture Decisions

### 3.1 Production AI runtime: native/mobile, not Python

The current progress report proposes Chaquopy/Python for the Android AI backend. Do not make that the cross-platform production architecture. Chaquopy is an Android Python SDK, while E-Player also targets iOS. Current ONNX Runtime mobile guidance supports Android CPU/XNNPACK/NNAPI and iOS CPU/XNNPACK/CoreML; accelerator performance is device/model dependent.

**Production:** C/C++ native core where appropriate + ONNX Runtime Mobile + platform adapters.  
**Development:** Python for model research, conversion, validation, benchmarks and golden outputs.

### 3.2 Playback

Keep the current `media_kit`/libmpv foundation unless repository measurements demonstrate a compelling reason to replace it. `media_kit` currently advertises cross-platform video/audio playback, broad format support, hardware/GPU acceleration, subtitle/audio/video track selection and external tracks.

Do not introduce a second local decoder engine just for feature count. Add native services around the existing backend.

### 3.3 Native boundaries

Use stable interfaces:
- `IPlaybackBackend`
- `IEnhancementEngine`
- `IInferenceRuntime`
- `IAudioProcessor`
- `ISubtitleManager`
- `ILibraryIndexer`
- `IExportEngine`
- `IBackgroundPlayback`
- `IPictureInPicture`
- `ICastService`
- `IVaultService`
- `ITrashService`
- `IDeviceCapabilityService`
- `IThermalManager`

Flutter owns UI/application state. Native code owns heavy frame/audio processing and OS-specific services.

## 4. Compatibility Contract

Do not promise “every smartphone version.” The supported range must follow the actual Flutter toolchain and native dependencies.

Current Flutter documentation lists Android API 24+ among supported deployment platforms for Flutter 3.47. Final project minimums must be verified from the installed toolchain.

Required validation:
- lower supported Android device;
- mainstream Android device;
- high-performance Android device;
- supported iPhone/iPad generations;
- Android 13+ media permissions;
- Android 14+ foreground-service rules;
- Android 15 behavior restrictions;
- Android 16 / 16 KB page-size readiness.

## 5. Feature Requirements

### 5.1 Universal playback

Validate at least:
- Containers: MKV, MP4, AVI, MOV, M4V, 3GP, WebM, TS, VOB, OGV, FLV, WMV and formats exposed by the actual libmpv/FFmpeg build.
- Video: H.264/AVC, H.265/HEVC, VP8, VP9, AV1 when supported, plus validated legacy codecs.
- Audio: AAC, MP3, FLAC, WAV, Opus, Vorbis, AC3/EAC3 and DTS where supported by the packaged backend and license situation.
- Resolution: SD through 1080p, 1440p and 2160p/4K where device/backend capabilities permit.

Do not advertise a format solely because upstream FFmpeg lists it; test the shipped build.

### 5.2 Decoder modes

Add:
- Auto
- Hardware
- Hardware+ where an actual hybrid/copy path exists
- Software

Show actual decoder state and fallback reason.

“HW+” is a UX compatibility concept, not a fake label. Map it only to a real supported native/libmpv mode.

### 5.3 Speed and pitch

Support 0.25x through 8x with common steps. Add pitch-correction/voice-preservation toggle, default ON for speech/video.

### 5.4 Aspect-ratio/display modes

Add:
- Fit
- Fill
- Crop
- Stretch
- Original
- 16:9
- 4:3
- 21:9
- Pan & Scan

Handle display cutouts and edge-to-edge correctly.

### 5.5 Gestures

Implement configurable:
- right vertical swipe = volume;
- left vertical swipe = brightness where supported;
- center horizontal swipe = seek;
- right double tap = forward seek;
- left double tap = backward seek;
- center double tap = play/pause;
- pinch = zoom/pan;
- two-finger vertical = speed.

Gesture settings must allow disabling individual gestures and configuring seek interval/sensitivity. Accessibility and system-gesture conflicts must be handled.

### 5.6 Subtitles

Current functionality remains. Add:
- SRT/VTT/TXT/ASS/SSA controls;
- embedded/external track selection;
- subtitle delay;
- font size/color;
- outline color/thickness;
- shadow/background;
- position;
- encoding override;
- reset styles.

Optional online subtitle provider:
- explicit user action;
- OpenSubtitles.com or another licensed provider;
- secure API credentials;
- rate limiting;
- language selection;
- hash/metadata matching;
- offline caching.

Online subtitles must never be required for offline playback.

### 5.7 Audio suite

Add 5-band graphic EQ:
- 60 Hz
- 230 Hz
- 910 Hz
- 3.6 kHz
- 14 kHz

Presets:
Normal, Classical, Jazz, Pop, Rock, Hip Hop, Heavy, Movie, Dialogue, Custom.

Effects:
- Bass Boost
- Virtualizer/stereo widening where supported
- Dialogue Boost
- Night Mode
- Loudness normalization
- Limiter/gain
- Pitch correction

AI speech/noise enhancement is a separate optional processing stage. Do not apply a speech model aggressively to music by default.

### 5.8 Media library

Replace picker-only UX with a local indexed library.

Android:
- MediaStore where appropriate;
- Storage Access Framework for user-selected folders;
- granular media permissions when justified.

iOS:
- Document Picker;
- security-scoped bookmarks;
- app-owned imported library;
- Photos integration only where explicitly required.

Do not make `MANAGE_EXTERNAL_STORAGE` the default. Current Google Play policy treats it as high-risk broad access and recommends MediaStore/SAF alternatives; use it only if the core product genuinely qualifies and review requirements are met.

Index:
- URI/path reference;
- title;
- duration;
- size;
- modified date;
- dimensions;
- codec/container;
- FPS;
- HDR metadata when available;
- tracks;
- thumbnail;
- progress;
- favorite;
- folder;
- vault/trash state.

### 5.9 Library scanning

Required:
- first scan;
- incremental scan;
- cancellation;
- exclusions;
- duplicate detection;
- corruption flagging;
- thumbnails;
- search/filter/sort;
- recent/favorites/continue watching.

### 5.10 Private vault

Implement actual encryption, not `.nomedia`-only hiding.

Use:
- Android Keystore / iOS Keychain for encryption-key protection;
- BiometricPrompt / native biometric APIs where available;
- authenticated encryption such as AES-GCM using vetted platform/library implementations;
- chunked encryption for large media;
- encrypted vault metadata;
- auto-lock.

Never store plaintext PINs or plaintext vault keys in normal application preferences.

### 5.11 Trash/recovery

Implement:
- move to trash;
- restore;
- permanent delete;
- empty trash;
- retention policy;
- storage usage.

Where platform permissions do not permit safe move/delete on arbitrary external documents, clearly distinguish “remove from E-Player library” from actual deletion.

### 5.12 Background audio

Android:
- MediaSession/MediaSessionService or equivalent;
- media-playback foreground service;
- notification;
- audio focus;
- hardware media keys;
- playback resumption.

iOS:
- AVAudioSession playback category;
- background audio capability;
- interruption/route-change handling;
- lock-screen controls where supported.

### 5.13 Picture-in-Picture

Android: native system PiP; do not use overlay permission as a substitute. Detect feature support and manage lifecycle/UI visibility.

iOS: AVPictureInPictureController and appropriate AVKit integration.

### 5.14 Network playback

Add URL playback for backend-capable:
- HTTP/HTTPS;
- HLS;
- DASH where supported;
- RTSP where supported;
- other protocols only if reliably supported by the packaged backend.

Support headers, user-agent, authentication where required, buffering status, retry and diagnostics without logging credentials.

### 5.15 Casting

Implement a platform abstraction for:
- Google Cast;
- AirPlay where supported.

For local-file Chromecast casting, use a controlled LAN HTTP server:
- random short-lived session token;
- only currently authorized media;
- no directory listing;
- expiry;
- shutdown after cast session ends.

Add connect/disconnect, device discovery, play/pause/seek/volume and local/remote handoff.

### 5.16 AI enhancement

Ready-made presets:
- Original
- Auto / Best for Device
- 720p Enhance
- 1080p Enhance
- 1440p Enhance
- 2160p/4K Enhance
- Anime
- Low-Light
- Noisy Source
- Detail Recovery
- Mild
- Balanced
- Strong
- Smooth Motion
- Advanced 3D

Manual controls:
- target resolution;
- scale;
- model;
- strength;
- denoise;
- detail/sharpen;
- artifact reduction;
- output FPS;
- interpolation;
- audio enhancement.

### 5.17 AI architecture

```text
Source
 -> Probe
 -> Decode
 -> Bounded Native Frame Queue
 -> Preprocess
 -> ONNX Runtime Mobile
      -> Real-ESRGAN-derived spatial model
      -> RIFE-derived interpolation model
      -> Depth model
 -> Postprocess
 -> Encode
 -> Mux video/audio/subtitles
 -> Validate output
```

Do not transfer full 4K frames via Dart JSON/Base64/method calls. Heavy frame transport stays native.

### 5.18 Offline-first AI

Offline export is MVP priority. Live enhancement is capability-gated.

When live inference falls behind:
1. lower model complexity;
2. lower target resolution;
3. reduce interpolation;
4. reduce enhancement strength;
5. bypass AI;
6. preserve playback.

### 5.19 Model runtime

Preferred baseline:
- ONNX Runtime Mobile;
- CPU/XNNPACK first;
- Android NNAPI when validated;
- iOS CoreML when validated;
- native buffer/FFI orchestration.

Model registry must contain version, task, license, provider, precision, input shape, memory class, checksum and fallback.

### 5.20 Real-ESRGAN

Use a validated model appropriate to the target device and licensing constraints. Implement tiling/overlap, memory pooling, color correctness, cancellation and fallback scaling.

### 5.21 RIFE

Start with offline 2x interpolation and target 60 FPS. 120 FPS must be capability-gated. Add scene-cut handling, timestamp reconstruction and A/V sync.

### 5.22 Depth/3D

Advanced feature. A compact Depth Anything V2-family model is a candidate after model/license validation. The current Depth Anything V2 repository documents smaller model variants and Core ML integration, while model licenses vary; choose the exact artifact deliberately.

### 5.23 AI audio

Use deterministic DSP controls plus optional neural denoise/speech enhancement. Support live/offline modes and bypass/fallback.

### 5.24 Offline export

Flow:
- choose source;
- choose preset/manual settings;
- choose output;
- process;
- progress;
- cancel;
- validate;
- atomic finalization.

Do not introduce the retired original FFmpegKit package as a dependency. The upstream repository states FFmpegKit was retired in July 2026; any FFmpeg integration must use a currently maintained native strategy and an explicitly reviewed license/build path.

## 6. Performance / Thermal Requirements

Measure:
- startup time;
- playback FPS;
- dropped frames;
- inference latency;
- queue depth;
- RAM/native memory;
- CPU/GPU where available;
- thermal state;
- battery behavior;
- export throughput.

Priority:
1. playback stability;
2. resource bounds;
3. responsiveness;
4. quality.

## 7. Security Requirements

Never:
- use `.nomedia` as vault security;
- store raw PINs;
- log credentials;
- expose arbitrary local files to Cast receivers;
- execute unsanitized shell strings;
- trust unverified model artifacts.

Use secure key storage, authenticated encryption, safe URI/path handling, short-lived cast tokens and model checksums.

## 8. Data Model

Recommended entities:
`MediaItem`, `MediaTrack`, `SubtitleTrack`, `AudioTrack`, `LibrarySource`, `WatchProgress`, `PlaybackSession`, `UserPreference`, `EnhancementPreset`, `EnhancementJob`, `ModelArtifact`, `DeviceCapability`, `VaultItem`, `TrashItem`, `CastSession`, `SubtitleSearchResult`.

## 9. Release Definition

Release-ready means:
- Android build works;
- iOS build works;
- Windows reference build remains stable;
- existing playback has no regression;
- real AI offline export works;
- player parity features are complete or explicitly documented;
- background audio and PiP work where supported;
- library/vault/trash work;
- network/casting work or are capability-gated;
- offline tests pass;
- memory/performance tests pass;
- security tests pass;
- Android 16/16 KB page-size readiness is verified;
- licenses are documented;
- no release-blocking P0/P1 issues remain.

## 10. Research Evidence

The uploaded XPlayer analysis was used as a feature-benchmark source. It identifies HW/HW+/SW decoder choices, aspect-ratio modes, PiP/background audio, 5-band EQ, subtitle sync/encoding/style controls, touch gestures, private-folder behavior, library scanning, trash, Chromecast and URL streaming. fileciteturn1file0L113-L172 fileciteturn1file0L176-L215 fileciteturn1file0L233-L279 fileciteturn1file0L280-L335 fileciteturn1file0L336-L389 fileciteturn1file0L390-L481

The original E-Player research provides the deeper AI architecture and identifies the copy-back/zero-copy problem, Real-ESRGAN, RIFE, depth estimation, audio processing, ONNX/TensorRT and local packaging. fileciteturn0file0L69-L97 fileciteturn0file0L154-L220 fileciteturn0file0L221-L309 fileciteturn0file0L338-L425

## 11. Current Research-Verified Direction

- Flutter currently supports Android deployment beginning at API 24 for the cited Flutter release family. citeturn604608search1
- Flutter recommends modern `package_ffi`/build-hook workflows for native FFI since Flutter 3.38. citeturn604608search11turn607922search12
- Android background playback should use MediaSessionService/foreground media playback services, with current API-specific requirements. citeturn914238search3turn914238search1turn914238search5
- Android system PiP does not require treating `SYSTEM_ALERT_WINDOW` as the core PiP implementation. citeturn914238search2turn914238search6
- Android storage guidance favors SAF/MediaStore and Google Play restricts broad All Files Access. citeturn548267search0turn914238search8turn759415search0turn759415search2
- ONNX Runtime Mobile supports CPU/XNNPACK on Android/iOS, with NNAPI/CoreML as device/model-dependent options. citeturn403596search11turn403596search0turn403596search1turn403596search2
- Android 16 adds compatibility behavior for 4 KB-aligned apps but recommends 16 KB alignment for performance/reliability/stability. citeturn494748search14
- FFmpegKit was retired in July 2026; its repository points to FFmpegKitNext as the continuation. citeturn607922search2turn607922search3
- Apple supports AVAudioSession playback/background modes, AVPictureInPictureController, Keychain, CryptoKit AES, document picker and security-scoped file access for the corresponding platform features. citeturn895652search6turn895652search13turn895652search0turn895652search1turn895652search4turn494748search0turn494748search3
- Current Google Cast guidance provides discovery, media control and reconnection patterns for sender apps. citeturn865317search1turn865317search4
- Current libass documentation confirms ASS/SSA native subtitle rendering remains a valid native path. citeturn309473search1
- Current WebVTT and SRT references confirm the continued relevance of those subtitle formats. citeturn309473search0turn309473search2
