# E-Player — Master Prompt for Antigravity AI

You are the principal software architect, senior Flutter engineer, mobile native/FFI engineer, multimedia systems engineer, ML inference engineer, UI/UX engineer, performance engineer and QA lead responsible for building **E-Player** as a production-grade mobile application.

You must use the attached/associated product specification **“E-Player — Product Requirements Document (PRD) + Phased Implementation Plan”** as the source of truth. Do not omit requirements, replace real functionality with fake UI, or silently weaken the offline/privacy rules.

## 1. Mission

Build a cross-platform smartphone multimedia player that:

- plays local video/audio offline;
- supports a broad codec/container set through a packaged native media engine;
- enhances video and audio locally on the device;
- provides both ready-made enhancement presets and manual controls;
- provides target presets for **720p, 1080p, 1440p and 2160p/4K**;
- supports optional AI spatial enhancement, temporal enhancement and audio enhancement;
- supports subtitles including SRT and ASS/SSA;
- can export enhanced files completely offline;
- protects user media by never requiring cloud upload for core processing;
- works across the defined supported mobile OS range with graceful fallbacks.

## 2. Non-negotiable truthfulness rule

Do not claim that every historical smartphone OS is supported. Implement the product for the PRD compatibility contract:

- Android API 24+.
- iOS 15+.

The app must have a capability detector. Playback support and AI enhancement support are separate decisions.

Never display “AI 4K supported” merely because the phone has a 4K screen. Use actual device/model/runtime capability checks.

## 3. Required architecture

Use a layered architecture:

```text
Flutter UI / Dart
   -> App/Playback Orchestrator
      -> Native Media Layer
      -> Native Enhancement Engine via FFI
         -> ONNX Runtime Mobile / XNNPACK / CoreML / NNAPI / validated platform provider
         -> Native DSP/audio pipeline
      -> Export Engine
```

Important: **do not make Python a runtime dependency of the mobile app.**

The supplied research uses Python + TensorRT as a desktop-oriented architecture. Preserve Python only as optional offline developer tooling for model conversion, benchmarking or experiments. The phone runtime must use an embeddable native/mobile inference path.

## 4. Technology policy

Preferred stack:

- Flutter + Dart for UI/application orchestration.
- media_kit/libmpv/FFmpeg or the selected equivalent native player foundation.
- C++ or Rust for the high-performance native engine.
- Dart FFI for the stable bridge.
- ONNX Runtime Mobile for cross-platform ML baseline.
- XNNPACK as a mobile CPU optimization path.
- CoreML and NNAPI or validated vendor accelerators when supported by the exact model/device.
- Native audio DSP plus a validated offline speech/noise model such as RNNoise/DeepFilterNet-class technology where licensing and mobile packaging permit.
- Real-ESRGAN-derived mobile-appropriate models for spatial restoration.
- RIFE-derived mobile-appropriate models for interpolation.
- Depth Anything V2 Small or another license-compatible mobile depth model for 3D as an advanced feature.

Do not introduce a cloud inference API.

## 5. Architecture constraints

### 5.1 UI thread
Never run heavy decoding, inference, export or file hashing on the Flutter UI isolate.

Use isolates/background workers and native worker threads as appropriate.

### 5.2 Frame transfer
Never send raw 4K frames through JSON, Base64 or ordinary serialized IPC.

Use native buffers, reusable memory pools, textures, CVPixelBuffer/Metal paths on iOS, and appropriate Android surface/HardwareBuffer/texture paths where supported.

An additional copy is acceptable on unsupported devices if it improves correctness and stability. Do not block the entire project waiting for perfect zero-copy on every GPU.

### 5.3 Backpressure
Every frame queue must be bounded.

When inference falls behind:

- drop stale enhancement work;
- keep playback responsive;
- preserve current timestamps;
- flush stale frames on seek;
- never allow an unbounded queue.

### 5.4 Failure behavior
If an AI model fails to load, the app must continue normal playback.

If an AI execution provider fails, fall back to the next validated provider.

If AI is too expensive for the current device/thermal state, reduce quality or disable AI with a clear user-facing explanation.

## 6. Required user-facing screens

Implement at minimum:

1. Home / Media Library
2. Now Playing
3. Enhancement Studio
4. Export Job / Progress
5. Settings
6. Model/Storage Management
7. Diagnostics / Performance (power-user accessible)

## 7. Home screen

Include:

- Continue Watching
- Recent Files
- Favorites
- Open File
- Settings
- search/filter/sort

Persist last playback position locally.

## 8. Player screen

Controls:

- play/pause
- seek
- previous/next
- playback speed
- volume
- subtitles
- audio track
- enhancement
- fullscreen/orientation
- aspect ratio / fit / crop

The video is always the primary visual area.

## 9. Enhancement Studio

This is a critical product screen.

Provide:

- original/enhanced preview;
- split-screen or swipe comparison;
- ready-made presets;
- Manual/Expert mode;
- video controls;
- audio enhancement controls;
- interpolation controls;
- export target controls;
- live capability indicator;
- storage estimate before export;
- reset-to-default action.

## 10. Required ready-made video presets

Implement:

- Original / No Enhancement
- Auto / Best for Device
- 720p Enhance
- 1080p Enhance
- 1440p Enhance
- 2160p / 4K Enhance
- Anime
- Low-Light / Noisy Source
- Mild
- Balanced
- Strong
- Smooth Motion (when supported)
- 3D Preview (advanced/conditional)

Treat 720p/1080p/1440p/2160p as target-resolution presets, not as fake visual filters.

## 11. Required Manual video controls

Implement real controls and connect them to real processing parameters:

- target resolution
- enhancement strength
- denoise
- sharpening/detail
- artifact reduction
- face/detail protection if supported by the chosen model
- brightness
- contrast
- saturation
- color enhancement
- output FPS
- frame interpolation

Do not render sliders that do nothing.

## 12. Spatial AI enhancement

Use a validated mobile-compatible Real-ESRGAN-derived model or equivalent.

Start with the smallest practical mobile model. Create the model abstraction so larger models can be added later.

Required behavior:

- image/video frame input;
- tiled processing for large frames when needed;
- configurable scale;
- safe memory reuse;
- configurable strength;
- output color-space correctness;
- deterministic fallback when model cannot run.

The app must not claim that AI recovered exact original detail. UI text should say it “enhances/restores perceived detail” rather than promising lossless recovery.

## 13. Temporal enhancement

Integrate a mobile-compatible RIFE-derived interpolation path.

Modes:

- Off
- Auto
- 2×
- Target 60 FPS
- Target 120 FPS only when validated

Implement:

- optical-flow/intermediate-frame processing;
- scene-change safeguards;
- occlusion/artifact handling through the selected model;
- bounded queues;
- seek cancellation;
- timestamp-correct audio synchronization.

## 14. Audio enhancement

This feature is mandatory.

### Real-time DSP

Implement:

- gain
- loudness normalization
- EQ
- bass/treble
- compressor/limiter
- dialogue boost
- night mode

### Offline AI speech/noise enhancement

Integrate a validated mobile-capable RNNoise/DeepFilterNet-class model or equivalent.

Add:

- off
- low
- medium
- high
- voice clarity mode

Do not label a generic EQ as AI.

Do not promise music restoration when using a speech-focused denoiser.

## 15. Audio/video sync

Preserve A/V sync through:

- normal playback;
- AI enhancement;
- frame interpolation;
- offline export.

When frame rate changes, use timestamp-aware processing. Do not simply stretch or speed up audio to hide timing mistakes.

## 16. Subtitles

Support:

- embedded tracks
- SRT
- ASS/SSA
- enable/disable
- track switching
- styling/scale settings supported by the native renderer

Use native subtitle rendering where possible for ASS/SSA fidelity.

Add offline subtitle generation as a later module with a mobile-compatible ASR engine. Keep the API model-agnostic so WhisperX-class processing can be used in desktop tooling while a lighter mobile model is used on phones.

## 17. 2D→3D

Implement only as an advanced, capability-gated feature.

Use a mobile-compatible depth model such as Depth Anything V2 Small or equivalent.

Support:

- SBS
- top/bottom
- anaglyph
- depth strength
- parallax strength
- comfortable depth limits

Prefer export or preview modes depending on device performance.

## 18. Offline export

Export must support, where codecs/encoders are available:

- original
- enhanced
- enhanced + audio processing
- enhanced + interpolation
- preserved subtitles
- generated subtitles
- 720p / 1080p / 1440p / 2160p targets

Implement:

- job queue
- progress
- current stage
- pause/cancel if safe
- retry from clean state
- temporary-file cleanup
- success notification
- output location

Never overwrite the original by default.

## 19. Device capability manager

Create an explicit capability API:

```text
DeviceCapabilityProfile
  osVersion
  apiLevel
  architecture
  ramBytes
  storageBytes
  gpuFeatures
  neuralAcceleration
  codecSupport
  thermalStatus
  maxRecommendedLiveResolution
  maxRecommendedLiveFps
  supportedModels[]
  supportedExecutionProviders[]
```

Create tiers:

- Tier A: playback-first
- Tier B: mainstream AI
- Tier C: high-performance AI

The policy manager chooses model, scale, frame rate, interpolation and audio mode.

## 20. Adaptive quality policy

At runtime:

1. Detect device.
2. Select best validated execution provider.
3. Estimate model cost.
4. Select output target.
5. Start with conservative settings.
6. Monitor FPS, queue depth and thermal state.
7. Downshift if needed.
8. Restore quality only when safe.

Quality degradation order:

1. Disable interpolation.
2. Reduce output resolution.
3. Reduce enhancement strength.
4. Switch to a smaller model.
5. Disable live AI and return to normal playback.

Never let playback become unusable just to keep AI enabled.

## 21. Model registry

Build a model registry with metadata:

- model ID
- version
- task
- license
- file checksum
- size
- input shape
- output shape
- scale
- quantization
- required provider
- minimum RAM
- recommended tier
- mobile/live/export support

Validate checksums before loading.

Never silently download a model from an unknown URL.

## 22. Offline-first privacy

The app must remain useful with airplane mode enabled.

Do not require:

- login
- cloud account
- API key
- remote media processing
- online subtitle service
- online AI inference

Do not upload user files, frames, audio or transcripts.

## 23. File handling and permissions

Use platform-appropriate scoped/local file access.

Do not request broad storage permissions unless technically necessary and permitted.

Do not scan private user content without an explicit product setting/permission.

## 24. Memory and performance

Use:

- buffer pools
- object reuse
- bounded frame queues
- native worker threads
- asynchronous jobs
- release builds for benchmarks

Avoid:

- per-frame object churn in Dart
- synchronous FFI from UI isolate
- unbounded caches
- copying full-resolution frames between layers repeatedly

## 25. Logging

Create structured local logs.

Log:

- model loaded
- provider selected
- frame timing
- dropped frames
- queue overflow prevention
- fallback reason
- export state

Do not log:

- raw media frames
- audio samples
- transcript contents
- full personal filenames unless a local debug mode explicitly permits it

## 26. UI truthfulness

Every unavailable AI feature must explain why, for example:

“4K live enhancement is unavailable on this device. Use Offline Enhance to create a 4K output.”

Do not use vague “premium” or “AI magic” language as a substitute for technical state.

## 27. Testing strategy

Create:

### Unit tests
- model selection
- capability policy
- queue logic
- timestamp math
- subtitle parsing
- export configuration

### Integration tests
- playback start/stop
- seek while AI is running
- model failover
- provider failover
- audio/video sync
- export cancellation

### Golden/UI tests
- home
- player
- enhancement studio
- error states
- unavailable-feature state

### Performance tests
- 720p/1080p/4K sample clips
- 24/30/60 FPS
- low/high motion
- noise and compression artifacts
- speech/noise audio

### Device matrix
Use representative Android API 24, 27, 29, 31, 33/34, 35+ and current; representative ARM32/ARM64 where build-supported; and iOS 15, 17, 18, 26 and current supported release.

## 28. Implementation sequence

Follow the PRD phases in order:

1. Foundation/capability layer
2. Core player/library
3. Native inference bridge
4. Video enhancement MVP
5. Live enhancement scheduler
6. RIFE interpolation
7. Audio enhancement
8. Offline export
9. Generated subtitles + 3D
10. Compatibility/accessibility/hardening
11. Release engineering

Do not attempt advanced 3D before the stable player and enhancement pipeline work.

## 29. Deliverables

Produce a working repository containing:

- Flutter application
- native Android integration
- native iOS integration
- native inference engine
- model registry
- media engine integration
- audio enhancement engine
- export pipeline
- automated tests
- CI configuration
- documentation
- device capability diagnostics
- sample fixture/test assets metadata

## 30. Development behavior for Antigravity

Work like a senior engineering team, not like a code snippet generator.

Before implementing each phase:

1. Read the relevant PRD section.
2. Inspect the current repository.
3. Identify dependencies and platform constraints.
4. Make an implementation checklist.
5. Implement the smallest complete vertical slice.
6. Run tests/build checks.
7. Fix errors.
8. Document architectural decisions.

Do not stop after creating UI mockups.

Do not produce placeholder buttons for core features unless the current phase explicitly requires a stub. When a feature is stubbed, mark it internally as TODO and keep the API boundary real so the next phase can implement it without redesigning the application.

## 31. Engineering quality bar

Code must be:

- typed;
- modular;
- documented at native boundaries;
- testable;
- cancellation-safe;
- memory-conscious;
- platform-aware;
- license-aware;
- failure-tolerant.

Every public FFI interface must document ownership/lifetime of pointers/buffers.

Every asynchronous processing job must have a cancellation/error path.

## 32. Critical acceptance tests before claiming completion

Do not claim “complete” until all applicable P0 acceptance criteria pass, including:

- offline playback on Android and iOS;
- working video enhancement;
- working 720p/1080p/2160p target presets where capability allows;
- working Manual controls;
- working audio enhancement;
- normal playback fallback when AI fails;
- bounded queues;
- stale-frame flushing on seek;
- offline export;
- verified A/V synchronization;
- model checksum validation;
- no cloud processing requirement;
- capability-aware 4K handling;
- no corruption of original files;
- release-mode performance tests.

## 33. Final rule

Build the actual E-Player product described here.

Do not replace the architecture with a web app.
Do not create a demo pretending to be the finished application.
Do not use cloud AI.
Do not hard-code fake FPS/quality numbers.
Do not label ordinary image sharpening as AI.
Do not promise universal 4K live enhancement.
Do not make normal playback depend on AI.

When a platform cannot support a particular optimization, preserve the user-visible feature through a safe lower-performance fallback whenever technically possible.

The finished product must feel like a professional offline media player first, and an AI enhancement application second: playback must remain stable, private, responsive and honest about device capability.
