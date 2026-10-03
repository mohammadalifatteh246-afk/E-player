# E-Player — Product Requirements Document (PRD) + Phased Implementation Plan

**Product:** E-Player — Cross-Platform, Offline, AI-Enhanced Multimedia Player
**Document status:** Product/engineering master specification
**Research basis:** `E-Player Offline App Architecture & Features Research.pdf` (13 pages)
**External verification:** current Flutter, media_kit, ONNX Runtime, Apple, TensorFlow Lite, Real-ESRGAN, RNNoise/DeepFilterNet documentation checked in September 2026.

---

## 1. Executive Summary

E-Player is an offline-first multimedia player that combines universal local media playback with optional real-time and offline AI enhancement. The research document defines a high-performance Flutter/Dart presentation layer, a native/media decoding layer using media_kit/libmpv/FFmpeg, and a separate high-throughput AI pipeline. Its core enhancement technologies are Real-ESRGAN for spatial restoration/upscaling, RIFE for frame interpolation, Depth Anything V2/Marigold-class models for depth/3D conversion, FFmpeg-based audio processing, and offline speech/subtitle generation.

The research is technically ambitious but is principally designed around desktop-style execution: embedded Python, TensorRT, D3D11/CUDA interoperability, a Windows Inno Setup installer, and Python multiprocessing. That design cannot simply be copied to a smartphone application. The mobile PRD therefore preserves the product goals and model capabilities while changing the runtime boundary:

- **Flutter/Dart remains the presentation and orchestration layer.**
- **Native media playback remains hardware accelerated and local.**
- **On-device AI uses mobile-compatible native inference such as ONNX Runtime Mobile, XNNPACK and platform accelerators (Core ML/NNAPI or vendor-specific paths when available).**
- **C++/Rust/native FFI becomes the performance-critical enhancement bridge instead of requiring an embedded Python runtime on phones.**
- **Python is retained as an optional model-development/offline tooling environment, not a mobile runtime dependency.**
- **Every supported device gets a capability-aware experience: playback is broadly available; live AI enhancement is enabled only when the device can sustain it; offline export can run at a lower tier on weaker hardware.**

The product must be fully functional without a network connection after installation. No media file, AI frame, audio sample, or subtitle content is uploaded to a server for processing.

---

## 2. Evidence and Research-to-Requirement Mapping

### 2.1 What the supplied research explicitly contains

The source specification states:

- Flutter/Dart frontend + Python computational backend and a clean separation between presentation and ML operations. It proposes zero-copy shared memory and GPU surface sharing because 4K/60 FPS raw frames can require roughly 1.5 GB/s of frame bandwidth. [Source PDF, pp. 1–4]
- media_kit/libmpv/FFmpeg as the universal media playback foundation, including modern codecs such as HEVC/H.265, AV1 and VP9, with hardware decoding. [Source PDF, pp. 1–2]
- D3D11/NVDEC on Windows, VAAPI/VDPAU on Linux, and VideoToolbox on macOS for hardware acceleration. [Source PDF, pp. 2–4]
- libass for accurate ASS/SSA subtitle rendering plus runtime subtitle-track selection. [Source PDF, p. 3]
- Real-ESRGAN for spatial restoration/upscaling, including configurable scale factors. [Source PDF, pp. 5–6]
- RIFE 4.25-style frame interpolation for 30→60/120 FPS and related motion processing. [Source PDF, p. 6]
- Depth Anything V2/Marigold-class depth estimation and stereoscopic 3D generation. [Source PDF, pp. 6–7]
- audio extraction/processing through FFmpeg, offline subtitle generation with WhisperX-class tooling, and A/V synchronization management. [Source PDF, p. 7]
- TensorRT for NVIDIA, ONNX Runtime execution providers for cross-hardware fallback, FP16/INT8 quantization, concurrency using Dart Isolates and Python multiprocessing/ring buffers, and embedded Python packaging for desktop distribution. [Source PDF, pp. 7–10]

The research is therefore a strong foundation for the feature vision and performance philosophy. The missing items are the smartphone compatibility contract, mobile-native AI runtime strategy, mobile power/thermal behavior, user-facing presets and manual controls, adaptive quality tiers, and a concrete mobile QA/device matrix.

### 2.2 External research findings incorporated into this PRD

1. Current Flutter deployment support is version-bounded rather than “every smartphone version.” Flutter 3.47 currently lists Android API 24–37 and iOS 15–27 as supported deployment targets; Android 23 and earlier and iOS 14 and earlier are unsupported by that toolchain. [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms)
2. media_kit currently documents Android and iOS video/audio support, with Android 5.0+ and iOS 9+ for the package itself, but the application must still obey the Flutter toolchain's supported deployment range. [media_kit documentation](https://pub.dev/documentation/media_kit/latest/)
3. ONNX Runtime officially documents mobile deployment on Android and iOS, with CPU, XNNPACK, and platform-specific accelerators such as NNAPI and CoreML available depending on device/model. It also stresses that models must fit device storage and memory. [ONNX Runtime Mobile](https://onnxruntime.ai/docs/tutorials/mobile/)
4. TensorFlow Lite documentation confirms GPU acceleration paths for Android and iOS and notes that NNAPI is available on Android 8.1/API 27+, making accelerator availability device-dependent. [TensorFlow Lite GPU/Delegates](https://android.googlesource.com/platform/external/tensorflow/+/852c7a17161/tensorflow/lite/g3doc/performance/delegates.md)
5. Real-ESRGAN has mobile/community implementations and a smaller `realesr-general-x4v3` direction, but the upstream project does not guarantee real-time 4K inference on arbitrary phones. The app must therefore use adaptive quality rather than promise universal real-time 4K AI. [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN)
6. RNNoise is an offline recurrent-neural-network noise-suppression library; DeepFilterNet is a low-complexity full-band speech-enhancement framework with a real-time orientation. These are suitable references for mobile offline speech/noise enhancement rather than treating FFmpeg alone as “AI audio enhancement.” [RNNoise](https://github.com/xiph/rnnoise) [DeepFilterNet](https://github.com/Rikorose/DeepFilterNet)

---

# 3. Product Vision

**Vision:** Give users a private, offline media player that can make local video and audio look and sound better without forcing uploads, subscriptions, or cloud processing.

**Core promise:** “Play locally. Enhance locally. Keep your media private.”

**Primary experience modes:**

1. **Player Mode** — fast, battery-aware playback with subtitles, tracks, gestures and normal video/audio controls.
2. **Live Enhance Mode** — enhancement is applied while the video plays, subject to device capability.
3. **Offline Enhance/Export Mode** — a selected video is processed into an enhanced output file, allowing heavier models and higher targets than live playback.
4. **3D Mode** — optional 2D→3D depth/parallax output for compatible display formats.
5. **Audio Enhance Mode** — real-time DSP and optional offline/on-device AI speech/noise enhancement.

---

# 4. Compatibility Contract

## 4.1 Critical clarification: “every version of smartphones”

A software product cannot truthfully guarantee support for every historical smartphone OS/build/chipset. The PRD therefore defines a **supported compatibility envelope** and a **graceful-degradation policy**.

### Guaranteed application deployment baseline

- **Android:** API 24+ (Android 7.0+), using current Flutter support as the formal baseline.
- **iOS:** iOS 15+.
- **Architectures:** Android ARM32/ARM64/x64 where supported by the chosen release artifacts; iOS arm64.
- **Playback compatibility:** determined by the media engine and device decoder capabilities.
- **AI compatibility:** determined independently by device RAM, GPU/NPU/accelerator support, model operator support, thermal state, and sustained performance.

This is deliberately stricter than media_kit's own older minimums because the application runtime is governed by Flutter and the AI stack, not by media_kit alone.

## 4.2 Device capability tiers

### Tier A — Legacy/low-power

- Guaranteed: local playback, audio, subtitles, seek, playback speed, basic visual controls.
- Enhancement: lightweight scaling, sharpening, denoise, EQ/normalization when performance permits.
- Frame interpolation and heavy neural upscaling: disabled or offline-only.

### Tier B — Mainstream modern

- Guaranteed: all Tier A features.
- Enhancement: mobile-optimized AI upscaling, moderate denoise, selected frame interpolation, audio AI, offline export.
- Live target examples: 720p/1080p with adaptive model complexity.

### Tier C — High-performance

- Guaranteed: all Tier A/B features.
- Enhancement: larger AI models, higher target resolution, stronger temporal processing, optional 3D, more advanced export.
- Live 4K enhancement is **capability-based, never guaranteed merely because a device has a 4K screen**.

---

# 5. Target Users

### Persona A — Local media viewer
Wants a reliable offline player for downloaded movies, anime, TV shows and personal videos.

### Persona B — Quality-focused viewer
Wants to make old 360p/480p/720p footage look cleaner and sharper on a modern display.

### Persona C — Video enhancer
Wants to export an improved file at 720p, 1080p, 1440p or 2160p/4K.

### Persona D — Dialogue-focused listener
Wants clearer speech, reduced background noise and stable loudness when watching in noisy environments or using small phone speakers/headphones.

### Persona E — Power user
Wants manual control over resolution, enhancement strength, frame rate, interpolation, subtitles, audio processing and export parameters.

---

# 6. Functional Scope

## 6.1 Media Library

- Scan/import local videos and audio.
- Browse by folders, recent files, favorites and user-created collections.
- Remember last playback position.
- Show metadata: filename, duration, resolution, codec/container when available, FPS, audio tracks, subtitle tracks and file size.
- Sort/filter by name, date, duration, resolution and favorites.
- Support Android storage permissions and iOS document/file-picking rules without requiring cloud storage.

## 6.2 Universal Playback

- Hardware-accelerated decoding when available.
- Software fallback when necessary.
- Play/pause, seek, next/previous, repeat, shuffle for playlists.
- Variable playback speed.
- Volume and mute.
- Audio-track switching.
- Subtitle-track switching.
- Aspect ratio / fit / crop / stretch modes.
- Picture-in-picture where platform policy and implementation permit.
- Background audio where allowed and appropriate for audio content.
- Orientation lock and immersive/fullscreen playback.
- Gesture controls for seek, volume and brightness where platform permits.

## 6.3 Format and Codec Strategy

The media engine should be based on the research direction of media_kit/libmpv/FFmpeg and native hardware decoding paths. The app should support, where the selected platform build allows:

- H.264/AVC
- H.265/HEVC
- VP8/VP9
- AV1 where device/platform decoder support is available
- Common containers such as MP4, MKV, WebM, MOV and others supported by the packaged media stack.

The UI must **never** present “supported” as a guarantee before the runtime probes the local file/decoder.

## 6.4 Subtitle System

- SRT, ASS/SSA and other parser formats supported by the packaged engine.
- Embedded subtitle tracks.
- External subtitle files.
- Enable/disable subtitles.
- Font scaling.
- Subtitle position where supported.
- Track language labels.
- Accurate ASS/SSA rendering through native subtitle rendering where possible.
- Optional on-device speech-to-text subtitle generation as a later phase.

## 6.5 Video Enhancement — Presets

The product must expose **ready-made enhancement presets**. Resolution labels are treated as **target-resolution presets**, not image filters.

Required presets:

- Original / No Enhancement
- 480p Restore (optional for lower-tier devices)
- **720p Enhance**
- **1080p Enhance**
- **1440p Enhance**
- **2160p / 4K Enhance**
- Auto / Best for Device
- Animation/Anime
- Low-Light / Noisy Source
- Detail Recovery
- Mild / Balanced / Strong enhancement variants

The exact model behind each preset is selected at runtime through the model registry and device capability manager.

## 6.6 Video Enhancement — Manual Mode

Manual controls:

- Target resolution: Original, 720p, 1080p, 1440p, 2160p/4K or Auto.
- Enhancement strength: 0–100.
- Denoising: 0–100.
- Sharpen/detail: 0–100.
- Artifact reduction: 0–100.
- Face/detail protection: On/Off or adaptive.
- Color enhancement: 0–100.
- Contrast/saturation/brightness controls.
- Optional deblocking/debanding where implementation supports it.
- Output FPS: Original, 24, 30, 48, 60, 120 where hardware/model supports it.
- Frame interpolation: Off, 2×, selected target FPS.
- Processing mode: Live Preview or Export.

The app must explain that enhancement is not magic: aggressive neural settings can invent texture or amplify artifacts. A before/after preview and instant reset must be available.

## 6.7 Frame Interpolation

Research direction: RIFE-style optical-flow frame synthesis.

Required UX:

- Off.
- Auto.
- 2× frame interpolation.
- Target 60 FPS.
- Target 120 FPS where device and content permit.
- Motion/scene-change safeguards.
- Instant bypass if inference falls behind.

The app must never create an ever-growing queue when playback is ahead of the enhancement pipeline. On seek/scrub, stale inference frames are flushed.

## 6.8 Audio Enhancement

The supplied research includes audio extraction/processing but does not define a complete user-facing audio-enhancement feature set. This PRD therefore adds it as a first-class module.

### Real-time DSP controls

- Volume gain.
- Loudness normalization.
- 3/5/10-band EQ, depending on platform UI target.
- Bass and treble.
- Dynamic compression / limiter.
- Dialogue boost.
- Stereo/mono controls where appropriate.
- Night mode / reduced dynamic range.

### AI/noise enhancement

- Speech noise suppression: RNNoise/DeepFilterNet-class offline model, or another validated mobile model.
- Strength: Off/Low/Medium/High.
- Voice clarity mode.
- Optional speech-focused dereverberation if a validated mobile model is available.

Important: speech enhancement and music enhancement are not the same task. The app must label speech-focused AI clearly and must not promise lossless restoration of missing musical detail.

## 6.9 Audio-Video Synchronization

- Maintain A/V sync through all playback and export modes.
- When temporal interpolation changes presentation timing, preserve or recompute timestamps rather than simply speeding up audio.
- Track and display sync offset when diagnostics are enabled.
- Exported media must use timestamp-safe muxing.

## 6.10 Offline AI Subtitle Generation

Later-stage feature:

- Detect speech.
- Generate transcript locally.
- Produce SRT/ASS output.
- Word-level timing when supported.
- Optional speaker labels where a sufficiently small offline model is available.
- No cloud API dependency.

The source research references WhisperX. On mobile the implementation should select a mobile-compatible runtime/model, because the desktop Python execution path is not a requirement for the phone build.

## 6.11 2D→3D Mode

Later-stage advanced feature:

- Depth estimation using a mobile-compatible model such as Depth Anything V2 Small or equivalent.
- SBS, top/bottom or anaglyph output.
- Depth strength.
- Parallax strength.
- Comfort/safety limit to avoid extreme depth.
- Processing may be export-only on many devices.

The source architecture says that spatial, temporal and depth pipelines can be chained; the mobile product must make this combination conditional on device capability to avoid thermal overload.

## 6.12 Offline Export

- Export original or enhanced media to a user-selected folder.
- Target resolution presets: 720p/1080p/1440p/2160p(4K).
- Codec/container selection only where the packaged encoder supports it.
- Audio preserve / enhanced.
- Subtitle preserve / generated.
- Frame rate preserve / interpolated.
- Background export where platform permits; otherwise foreground service/task with visible progress.
- Pause/cancel/resume where technically safe.
- Temporary-file cleanup after success/failure.
- Never overwrite the original by default.

---

# 7. AI Preset Design

| Preset | Primary purpose | Typical behavior | Live | Export |
|---|---|---|---|---|
| Original | No enhancement | Decode only | Yes | Yes |
| Auto | Best balance | Device-aware model + scaling | Yes | Yes |
| 720p Enhance | Low/medium source | Restore + scale to 720p | Yes | Yes |
| 1080p Enhance | Main target | Restore + scale to 1080p | Yes* | Yes |
| 1440p Enhance | High-quality | Stronger model if supported | Limited | Yes |
| 2160p/4K Enhance | Maximum target | Heaviest compatible pipeline | High-end only | Yes |
| Anime | Line/art protection | Anime-tuned model | Limited | Yes |
| Low-Light | Noisy footage | Denoise + conservative sharpening | Limited | Yes |
| Smooth Motion | Motion clarity | RIFE-style interpolation | High-end | Yes |
| 3D | Immersion | Depth + reprojection | High-end/preview | Yes |

`*` Live 1080p enhancement remains device-dependent.

---

# 8. UI/UX Requirements

## 8.1 Home

- Continue Watching.
- Recent Files.
- Favorites.
- Open File.
- Enhancement shortcut.
- Settings.
- Clear, dark-friendly media-player visual language.

## 8.2 Now Playing

Primary visual priority: the video itself.

Controls:

- Back.
- Play/pause.
- Seek bar.
- Previous/next.
- Volume.
- Subtitle.
- Audio track.
- Speed.
- Enhance.
- More.
- Fullscreen/rotate.

Enhance drawer:

- Preset row.
- Before/after toggle.
- Auto vs Manual.
- Performance indicator.
- FPS and processing state.
- Device-capability explanation when a feature is unavailable.

## 8.3 Enhancement Studio

A dedicated screen for deeper controls:

- Source preview.
- Enhanced preview.
- Split-screen or swipe comparison.
- Presets.
- Manual controls.
- Audio enhancement panel.
- Frame interpolation panel.
- Export panel.
- Estimated storage requirement.
- Estimated processing tier: Fast / Balanced / High Quality.

The UI must never imply that “4K” means guaranteed 4K-quality AI reconstruction on every phone.

---

# 9. System Architecture

## 9.1 High-level architecture

```text
Flutter UI / Dart
        |
        v
Playback + App Orchestrator
        |
  +-----+---------------------------+
  |                                 |
  v                                 v
Native Media Layer             Enhancement Engine
(media_kit/libmpv/FFmpeg)      (C++/Rust FFI)
  |                                 |
  v                                 +-------------------------+
Hardware decode / textures            |          |             |
                                       v          v             v
                                    ONNX RT     DSP      Platform EPs
                                    Mobile     / Audio   CoreML/NNAPI/etc.
                                       |
                                       v
                                  Model Registry
                              Real-ESRGAN/RIFE/etc.
                                       |
                                       v
                                Ring Buffers / Queues

Optional development tooling:
Python model conversion / benchmarking / training utilities
(not required by mobile runtime)
```

## 9.2 Why the mobile architecture differs from the source desktop architecture

The source document's Python + TensorRT + D3D11/CUDA + embedded Python design is retained as a conceptual performance reference, but it is not the default phone runtime. The mobile stack needs a native, embeddable inference runtime and platform-native graphics/audio surfaces.

### Mobile zero-copy strategy

Use the closest safe platform equivalent to zero-copy rather than promising a single implementation across all devices:

- Android: MediaCodec/Surface/HardwareBuffer or equivalent native texture path where practical.
- iOS: CVPixelBuffer/Metal texture interoperability where practical.
- FFI bridge between Flutter and native engine.
- Reusable frame pools.
- Avoid JSON/Base64 for frame data.
- Use small control messages and shared native buffers for large data.

A first production milestone may use one additional copy on unsupported devices; correctness and stability take priority over premature zero-copy optimization.

## 9.3 Inference runtime

Recommended abstraction:

```text
InferenceEngine
  -> ModelSession
  -> ExecutionProviderSelector
  -> MemoryManager
  -> FrameConverter
  -> Scheduler
```

Execution order preference:

1. Platform/vendor accelerator proven stable for the specific model/device.
2. GPU/NNAPI/CoreML path where supported.
3. XNNPACK.
4. CPU fallback.

Never assume a provider is faster simply because it exists. Benchmark at runtime or via validated device profiles.

## 9.4 Model Registry

Each model must have metadata:

- id
- version
- purpose
- input size/range
- output scale
- supported providers
- quantization
- expected memory
- minimum capability tier
- legal/license metadata
- checksum
- enabled features

The application must refuse to load a model if the package checksum or metadata is invalid.

---

# 10. Performance and Resource Management

## 10.1 Adaptive pipeline

A device-capability engine must evaluate:

- OS/API level.
- CPU architecture.
- RAM.
- Available storage.
- GPU/API capability.
- NPU/accelerator availability where detectable.
- Current thermal state.
- Battery/charging state where accessible and appropriate.
- Current output resolution/FPS.

It returns a policy such as:

```json
{
  "liveEnhance": true,
  "videoModel": "realesr-general-mobile",
  "scale": 2,
  "maxOutputWidth": 1920,
  "targetFps": 30,
  "interpolation": false,
  "audioAi": true,
  "allow3D": false
}
```

## 10.2 Backpressure and queue rules

- Decoder must never outrun the consumer indefinitely.
- Maintain bounded input/output ring buffers.
- Drop stale enhancement frames rather than stalling playback.
- On seek: cancel or invalidate pending inference jobs.
- On pause: allow the pipeline to drain or stop according to power policy.
- On app background: release GPU-heavy live enhancement resources unless the platform permits a safe continuation.

## 10.3 Thermal throttling

When sustained device temperature/thermal state rises:

1. Reduce enhancement strength.
2. Reduce output resolution.
3. Disable interpolation.
4. Switch to lighter model.
5. Fall back to ordinary playback.

The UI must explain the automatic reduction without suggesting a fault.

---

# 11. Storage, Model Packaging and Offline Rules

### Strict privacy rule

The app must work after installation without network access for its core functions.

### Model distribution options

- Core lightweight models bundled with the app.
- Optional heavier models bundled in split packages/app bundles or imported locally where platform distribution allows.
- No runtime requirement to download a model from a cloud API.

### Storage safeguards

- Model disk usage is shown before enabling large packs.
- Temporary export storage is checked before work begins.
- Partial outputs are cleaned safely.
- User media is never silently duplicated more than necessary.

---

# 12. Security and Privacy

- No media upload by default.
- No remote inference.
- No API key dependency.
- No telemetry that contains media contents, frames, transcripts or filenames by default.
- Permissions requested just in time.
- User-selectable local media access.
- Model integrity checks.
- Safe temporary-file handling.
- Crash logs, if implemented, must exclude media contents and personal filenames by default.

---

# 13. Accessibility and Localization

- Screen-reader labels for player controls.
- Touch targets sized for mobile use.
- High-contrast UI.
- Captions/subtitles support.
- Large text support without breaking the player.
- Localizable strings with no hard-coded UI text.
- RTL-ready layout.

---

# 14. Analytics and Diagnostics

No cloud analytics are required for MVP.

Local diagnostics screen for power users:

- Decoder.
- Video codec.
- Resolution/FPS.
- Current enhancement model.
- Execution provider.
- Live FPS vs source FPS.
- Dropped frames.
- Queue depth.
- Memory pressure.
- Processing latency.
- Thermal state if platform allows.
- A/V offset.

---

# 15. Non-Functional Requirements

### Performance

- Ordinary playback must remain responsive even when AI is unavailable.
- UI thread must not perform heavy inference.
- AI work must be cancellable.
- Frame queues must be bounded.
- Release builds must be used for performance validation.

### Reliability

- A failed model must fall back to normal playback rather than crash the player.
- An unsupported codec must show a useful compatibility message.
- Export failure must not corrupt the input file.
- App restart must recover the last stable playback state.

### Offline

- Core playback and core enhancement operate without internet.
- No cloud fallback is silently introduced.

### Maintainability

- Feature modules decoupled from platform adapters.
- Model registry independent of UI.
- Native inference behind a stable FFI contract.
- Automated tests for every high-risk native interface.

---

# 16. Requirements Traceability

| ID | Requirement | Priority | Source / rationale |
|---|---|---:|---|
| PL-001 | Local/offline playback | P0 | Research |
| PL-002 | Cross-platform mobile app | P0 | User requirement + current Flutter support |
| PL-003 | Universal codec strategy | P0 | Research/media_kit |
| EN-001 | Video enhancement | P0 | Research |
| EN-002 | Ready presets | P0 | User requirement |
| EN-003 | 720p/1080p/1440p/2160p targets | P0 | User requirement |
| EN-004 | Manual enhancement controls | P0 | User requirement |
| EN-005 | RIFE frame interpolation | P1 | Research |
| AU-001 | Audio enhancement | P0 | User requirement; gap filled by PRD |
| AU-002 | Offline speech/noise enhancement | P1 | Research + external research |
| SUB-001 | SRT/ASS/SSA | P0 | Research |
| SUB-002 | Offline generated subtitles | P2 | Research |
| D3D-001 | 2D→3D | P2 | Research |
| EXP-001 | Offline export | P0 | Research intent + necessary product workflow |
| PERF-001 | Hardware acceleration | P0 | Research |
| PERF-002 | Adaptive quality | P0 | Mobile feasibility requirement |
| PERF-003 | Bounded ring buffer/backpressure | P0 | Research |
| PRIV-001 | No cloud media processing | P0 | Offline/privacy requirement |
| COMP-001 | API24+/iOS15+ deployment contract | P0 | Current Flutter support |
| COMP-002 | Graceful fallback for older/weak devices | P0 | Mobile feasibility requirement |

---

# 17. Acceptance Criteria

A release candidate is acceptable only when all of the following are true:

1. A supported Android device can open and play common local H.264 content without network access.
2. A supported iPhone/iPad can open and play common local H.264 content without network access.
3. The app offers 720p, 1080p and 2160p/4K enhancement target presets where device/model constraints permit; unavailable presets explain why rather than silently failing.
4. Manual enhancement controls work and have a visible reset-to-default action.
5. At least one offline video enhancement model is integrated and produces a verifiable changed output.
6. At least one offline audio noise/speech enhancement path is integrated and produces a verifiable changed output.
7. Normal playback continues when AI enhancement fails.
8. Scrubbing invalidates stale enhancement work.
9. No media frames are serialized as JSON/Base64 between Flutter and native inference.
10. Offline export preserves or intentionally transforms timestamps with verified A/V sync.
11. The app functions with network disabled after installation.
12. A device-capability policy prevents unsupported AI models from being loaded.
13. Large model/storage requirements are shown before processing.
14. Thermal/power safeguards can reduce enhancement quality without crashing playback.
15. Crash recovery does not lose the original media or leave unbounded temporary files.

---

# 18. Phased Implementation Plan

## Phase 0 — Product and Feasibility Foundation

### Part 0A — Repository and architecture
- Create monorepo or clearly separated Flutter + native engine modules.
- Set up CI for Android and iOS.
- Establish coding standards.
- Create `core`, `player`, `enhancement`, `audio`, `subtitles`, `export`, `settings`, `diagnostics`, and platform adapter modules.

### Part 0B — Device capability discovery
- Detect OS/API, architecture, RAM, storage and basic graphics capabilities.
- Implement `DeviceCapabilityProfile`.
- Implement capability tiers A/B/C.

### Part 0C — Model registry design
- Define model metadata schema.
- Add checksum validation.
- Create placeholder registry entries.

**Exit criteria:** app launches, capability profile is displayed in diagnostics, CI builds both mobile targets.

---

## Phase 1 — Core Offline Player

### Part 1A — Media library
- File/folder selection.
- Recent list.
- Favorites.
- Continue playback.

### Part 1B — Playback engine
- media_kit/libmpv integration.
- Hardware acceleration where available.
- Audio/video tracks.
- Seeking/speed/fullscreen.

### Part 1C — Subtitle foundation
- Embedded + external SRT/ASS/SSA.
- Track selector.
- Subtitle rendering.

**Exit criteria:** ordinary local playback is stable on the minimum supported OS versions with network disabled.

---

## Phase 2 — Mobile Native Inference Core

### Part 2A — FFI contract
Define native methods for:

- engine init/shutdown
- model load/unload
- frame submit
- frame result
- job cancel
- queue state
- error reporting

### Part 2B — ONNX Runtime Mobile integration
- Android runtime.
- iOS runtime.
- XNNPACK baseline.
- optional NNAPI/CoreML execution provider selection.

### Part 2C — Native memory pools
- Reusable frame buffers.
- Bounded queues.
- Reference counting.
- No per-frame allocation when avoidable.

### Part 2D — Benchmark harness
- Synthetic frames.
- Real sample clips.
- Per-device benchmark records.

**Exit criteria:** one small validated model can run locally on both mobile platforms through the FFI boundary.

---

## Phase 3 — Video Enhancement MVP

### Part 3A — Real-ESRGAN mobile model path
- Start with the smallest validated model.
- Convert/optimize to ONNX or another supported mobile representation.
- Validate output quality.

### Part 3B — Preset system
Implement:
- 720p
- 1080p
- 1440p
- 2160p/4K
- Auto
- Anime
- Low-Light

### Part 3C — Manual controls
- Strength.
- Denoise.
- Detail.
- Color.
- Target resolution.

### Part 3D — Before/after UI
- Split preview.
- Toggle.
- Reset.

**Exit criteria:** enhancement is real, offline, cancellable and not a mock filter.

---

## Phase 4 — Live Enhancement Pipeline

### Part 4A — Frame scheduler
- Decoder timestamp handling.
- Bounded ring buffer.
- Stale-frame dropping.

### Part 4B — Texture/interoperability path
- Android native surface/texture bridge.
- iOS CVPixelBuffer/Metal bridge.
- Flutter texture rendering.

### Part 4C — Live policy manager
- Detect model cost.
- Adapt resolution/FPS.
- Thermal downshift.
- Disable AI safely when needed.

**Exit criteria:** live enhancement can run on selected Tier B/C devices while normal playback never hard-locks.

---

## Phase 5 — RIFE Frame Interpolation

### Part 5A
- Integrate mobile-compatible RIFE model.
- 2× mode.
- 60 FPS target.

### Part 5B
- Motion artifact safeguards.
- Scene-cut handling.
- Queue invalidation on seek.

### Part 5C
- Audio timestamp preservation.

**Exit criteria:** validated clips can move from 30→60 FPS without visible A/V desynchronization beyond the defined test threshold.

---

## Phase 6 — Audio Enhancement

### Part 6A — DSP
- EQ.
- Loudness normalization.
- Compressor/limiter.
- Dialogue boost.
- Night mode.

### Part 6B — AI speech/noise
- RNNoise or DeepFilterNet-class mobile path.
- Device-aware model choice.
- Strength control.

### Part 6C — Validation
- Speech/noise benchmark set.
- Music safety tests.

**Exit criteria:** audio enhancement works offline and can be bypassed instantly.

---

## Phase 7 — Offline Export Engine

### Part 7A
- Job queue.
- Progress.
- Cancel.
- Temporary-file management.

### Part 7B
- Video enhancement export.
- Audio enhancement export.
- Subtitle preservation/generation.
- Interpolation.

### Part 7C
- Container/muxing tests.
- A/V sync tests.
- Large-file recovery tests.

**Exit criteria:** exported files play correctly in the app and in at least two independent reference players.

---

## Phase 8 — Advanced Features

### Part 8A — Generated subtitles
- Mobile ASR runtime.
- SRT/ASS export.
- Word timing.

### Part 8B — 2D→3D
- Depth Anything V2 Small or validated equivalent.
- SBS/anaglyph.
- Comfort controls.

### Part 8C — Combined pipelines
- Spatial + temporal.
- Spatial + audio.
- Spatial + temporal + audio.
- Spatial + depth only where resource policy allows.

**Exit criteria:** every combined feature has an explicit device capability gate and cannot trigger uncontrolled thermal/memory load.

---

## Phase 9 — Compatibility, Accessibility and Hardening

### Part 9A — Compatibility matrix
Test representative devices across:

- Android API 24, 27, 29, 31, 33/34, 35+, current release.
- ARM32 where the build supports it.
- ARM64 low/mid/high tiers.
- iOS 15, 17, 18, 26 and current supported release.

### Part 9B — Accessibility
- Screen reader labels.
- Dynamic text.
- Contrast.
- Touch sizes.
- Localization.

### Part 9C — Reliability
- Crash/failure injection.
- Corrupt media.
- Model load failure.
- Memory pressure.
- Thermal stress.

**Exit criteria:** no P0/P1 stability issues on supported release matrix.

---

## Phase 10 — Release Engineering

- Signed Android release builds.
- iOS App Store/TestFlight builds.
- Crash-free startup validation.
- Model checksum validation.
- Privacy review.
- License review for all bundled models/libraries.
- Release notes.
- Upgrade/migration tests.
- Offline regression suite.

---

# 19. Suggested Project Structure

```text
/e-player
  /app
    /lib
      /core
      /features
        /library
        /player
        /enhancement
        /audio
        /subtitles
        /export
        /settings
        /diagnostics
      /ui
      /state
  /native
    /engine
      /ffi
      /video
      /audio
      /inference
      /memory
      /scheduler
    /android
    /ios
  /models
    /registry
    /metadata
    /manifests
  /tools
    /model_conversion
    /benchmarks
    /media_fixtures
  /test
    /unit
    /integration
    /golden
    /performance
  /docs
    /architecture
    /device-matrix
    /release
```

---

# 20. Priority Model

### P0 — MVP

Offline local playback, library, subtitles, hardware acceleration, video enhancement presets, manual enhancement, audio DSP, at least one offline AI enhancement path, offline export, capability detection, robust fallbacks, privacy/offline behavior.

### P1 — Advanced quality

Live AI enhancement, RIFE 60 FPS, AI audio denoise, device-specific acceleration profiles, deeper diagnostics.

### P2 — Advanced/experimental

120 FPS interpolation, generated subtitles, 2D→3D, combined multi-model pipelines, aggressive high-end models.

---

# 21. Product Guardrails

1. Never fake an AI feature with a CSS-style visual effect or simple sharpen filter while labeling it as AI.
2. Never promise real-time 4K AI on every phone.
3. Never require cloud processing for core features.
4. Never let AI enhancement freeze or crash normal playback.
5. Never silently destroy or overwrite the original media.
6. Never ship a model without license/redistribution verification.
7. Never serialize raw video frames through JSON/Base64.
8. Never let queues grow without a hard upper bound.
9. Always provide a fallback path.
10. Always show the user when a preset is unavailable because of device capability.

---

# 22. Research Sources

- Supplied research PDF: `E-Player Offline App Architecture & Features Research.pdf`
- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- media_kit documentation: https://pub.dev/documentation/media_kit/latest/
- ONNX Runtime Mobile: https://onnxruntime.ai/docs/tutorials/mobile/
- ONNX Runtime Mobile: https://onnxruntime.ai/docs/get-started/with-mobile.html
- TensorFlow Lite delegates: https://android.googlesource.com/platform/external/tensorflow/+/852c7a17161/tensorflow/lite/g3doc/performance/delegates.md
- Real-ESRGAN: https://github.com/xinntao/Real-ESRGAN
- RNNoise: https://github.com/xiph/rnnoise
- DeepFilterNet: https://github.com/Rikorose/DeepFilterNet
- Apple Xcode system requirements: https://developer.apple.com/xcode/system-requirements/

---

# 23. Final Product Decision

The source research is accepted as the foundation for playback, AI enhancement concepts, performance principles and offline privacy. The following changes are mandatory for the smartphone product:

**A.** Replace the source's mobile-infeasible embedded-Python assumption with a native mobile inference engine abstraction.

**B.** Define supported OS versions rather than claiming “every smartphone version.” Current deployment target: Android API 24+ and iOS 15+.

**C.** Add explicit 720p/1080p/1440p/2160p presets and Manual Expert Mode.

**D.** Add audio enhancement as a real feature, including DSP and an optional offline speech/noise model.

**E.** Make live AI adaptive, with offline export as the path for heavier 4K-quality processing.

**F.** Preserve the source's zero-copy goal as an optimization direction, not a universal prerequisite for first release.

This is the baseline PRD that the implementation prompt must follow.
