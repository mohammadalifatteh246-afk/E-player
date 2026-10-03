---
name: e-player-video-player-engineering
version: 1.0.0
project: E-Player
purpose: Build a cross-platform offline multimedia player with real on-device video/audio enhancement.
applies_to: Any AI coding agent, autonomous software engineer, coding assistant, or multi-agent development system.
primary_runtime: Flutter/Dart + native mobile multimedia/AI engine
required_companion_skill: E_PLAYER_PYTHON_SKILL.md
source_of_truth: E-Player PRD + Phased Implementation Plan
---

# E-Player AI Engineering Skill

## 0. ROLE

You are the engineering agent responsible for designing, implementing, testing, debugging, optimizing, and documenting **E-Player**.

E-Player is an offline-first smartphone multimedia player with:
- local video/audio playback;
- subtitles;
- ready-made and manual enhancement controls;
- on-device video enhancement;
- on-device audio enhancement;
- frame interpolation;
- optional 2D-to-3D processing;
- offline enhanced export;
- privacy-preserving local processing.

This skill is deliberately tool-agnostic so it can be loaded into any AI coding environment.

---

# 1. SOURCE-OF-TRUTH ORDER

When multiple instructions exist, use this order:

1. Explicit user requirement.
2. E-Player PRD and implementation plan.
3. This skill.
4. Project architecture and existing code.
5. External technical documentation.
6. General engineering knowledge.

Never silently invent product requirements.

When a requested feature conflicts with platform reality, preserve the user-facing goal and redesign the implementation safely rather than making a false support claim.

---

# 2. PRODUCT CONTRACT

## 2.1 Core promise

“Play locally. Enhance locally. Keep media private.”

Core functionality must continue without a network connection after installation.

The application must not require uploading user media, frames, audio, subtitles, or metadata to a cloud service for core playback or enhancement.

## 2.2 Compatibility contract

Do not claim support for every historical smartphone version.

The product baseline is:

- Android API 24+.
- iOS 15+.
- Android/iOS architectures supported by the selected Flutter/native toolchain.
- Playback availability and AI-enhancement availability are separate capability decisions.

Older or weaker devices must degrade gracefully instead of crashing or exposing unavailable controls.

## 2.3 Capability tiers

### Tier A — Legacy / low-power
Provide:
- reliable local playback;
- audio;
- subtitles;
- seeking;
- playback speed;
- basic video controls;
- lightweight enhancement when sustainable.

Heavy neural live enhancement and frame interpolation may be disabled or export-only.

### Tier B — Mainstream modern
Provide:
- Tier A;
- mobile AI upscaling;
- moderate denoise;
- selected frame interpolation;
- offline audio enhancement;
- enhanced export.

### Tier C — High-performance
Provide:
- Tier A/B;
- stronger AI models;
- higher target resolutions;
- advanced interpolation;
- optional 2D-to-3D;
- combined pipelines where benchmarks permit.

Never infer AI capability solely from display resolution.

---

# 3. PRODUCT MODES

The app has five primary modes:

1. Player Mode
2. Live Enhance Mode
3. Offline Enhance / Export Mode
4. Audio Enhance Mode
5. Advanced 3D Mode

Normal playback must remain usable if all AI systems fail.

---

# 4. REQUIRED USER FEATURES

## 4.1 Media library

Implement:
- local file browsing/import;
- recent files;
- continue watching;
- favorites;
- search;
- sort/filter;
- playback-position persistence;
- file metadata;
- folders and media locations supported by platform permissions.

## 4.2 Universal playback

Use a native hardware-aware multimedia foundation.

Preferred architecture:
- Flutter/Dart UI and orchestration;
- native media engine;
- FFmpeg/libmpv/media_kit or an equivalent properly licensed/native solution;
- hardware decoding when available;
- software fallback when required.

Support a broad practical set of containers/codecs and probe actual device/decoder support rather than falsely guaranteeing every codec.

## 4.3 Player controls

Required:
- play/pause;
- seek;
- previous/next;
- playback speed;
- volume;
- mute;
- subtitles;
- audio tracks;
- fullscreen;
- orientation;
- aspect-ratio/fit controls;
- enhancement toggle;
- picture controls.

Seeking must invalidate stale enhancement work.

---

# 5. VIDEO ENHANCEMENT

## 5.1 Required ready-made presets

The app must expose real presets:

- Original / No Enhancement
- Auto / Best for Device
- 480p Restore where supported
- 720p Enhance
- 1080p Enhance
- 1440p Enhance
- 2160p / 4K Enhance
- Animation / Anime
- Low-Light / Noisy Source
- Detail Recovery
- Mild
- Balanced
- Strong
- Smooth Motion when supported
- 3D Preview as an advanced conditional mode

Important:
720p, 1080p, 1440p and 2160p/4K are target-resolution presets, not fake visual filters.

Every preset must map to actual processing parameters/model configuration.

## 5.2 Manual controls

Implement real controls:
- target resolution;
- enhancement strength;
- denoise;
- sharpening/detail;
- artifact reduction;
- optional face/detail protection if supported;
- brightness;
- contrast;
- saturation;
- color enhancement;
- output FPS;
- frame interpolation.

Do not ship decorative sliders that are disconnected from the processing engine.

## 5.3 Spatial enhancement

Use a mobile-compatible Real-ESRGAN-derived model or equivalent model with appropriate licensing.

Required engineering:
- tiled inference for large frames;
- reusable memory buffers;
- scale selection;
- model registry;
- adaptive precision;
- device-aware model selection;
- safe fallback to non-AI scaling;
- color-space preservation;
- cancellation support.

Never tell the user that AI recovered exact missing source pixels. Use wording such as “enhances perceived detail” or “restores visual detail.”

---

# 6. TEMPORAL ENHANCEMENT

Use a mobile-compatible RIFE-derived or equivalent frame-interpolation model.

Supported modes:
- Off;
- Auto;
- 2x;
- target 60 FPS;
- target 120 FPS only when validated.

Required engineering:
- bounded queues;
- optical-flow/intermediate-frame inference;
- scene-change safeguards;
- occlusion/artifact protection;
- timestamp correctness;
- seek cancellation;
- audio synchronization;
- automatic bypass when inference cannot keep up.

Never let a backlog grow without bounds.

---

# 7. AUDIO ENHANCEMENT

Audio enhancement is a first-class feature.

## 7.1 Real-time DSP

At minimum:
- gain;
- loudness normalization;
- EQ;
- bass;
- treble;
- compressor/limiter;
- dialogue boost;
- night mode.

## 7.2 Offline/on-device AI audio

Use a validated mobile-compatible noise/speech enhancement model such as an RNNoise/DeepFilterNet-class approach, subject to licensing and runtime constraints.

Required behavior:
- model loading/fallback;
- low-latency streaming where practical;
- offline export;
- sample-rate handling;
- channel handling;
- clipping protection;
- A/V synchronization.

---

# 8. SUBTITLES

Support:
- SRT;
- ASS/SSA;
- embedded subtitles;
- external subtitle files;
- subtitle track selection;
- enable/disable;
- font scaling;
- positioning where supported.

ASS/SSA should use a native-capable renderer when exact styling is required.

Optional advanced feature:
- offline speech-to-text subtitle generation.

---

# 9. 2D -> 3D

Treat 2D-to-3D as an advanced capability.

Use a compact depth-estimation model when device capability permits.

Pipeline:
1. decode frame;
2. estimate depth;
3. build parallax/displacement;
4. generate left/right views;
5. apply safety limits;
6. render in a supported 3D presentation mode.

Do not block the MVP on this feature.

---

# 10. OFFLINE EXPORT

The app must support enhanced-file export.

User selects:
- source;
- target resolution;
- enhancement preset/manual parameters;
- FPS;
- audio treatment;
- subtitles;
- output format/codec supported by the implementation.

Export must:
- run locally;
- survive temporary UI navigation;
- expose progress;
- expose cancel;
- avoid corrupt partial output;
- validate output after completion;
- preserve synchronization.

Use atomic temp-file -> final-file replacement.

---

# 11. ARCHITECTURE

Use this logical architecture:

Flutter UI / Dart
    |
    +--> Application State & Playback Orchestrator
    |
    +--> Media Adapter
    |
    +--> Enhancement Controller
             |
             +--> Native FFI Bridge
             |
             +--> Native Video Engine
             |      +--> ONNX Runtime Mobile
             |      +--> XNNPACK
             |      +--> CoreML / NNAPI / validated accelerators
             |
             +--> Native Audio Engine
             |
             +--> Export Engine
             |
             +--> Capability & Thermal Manager

Python is NOT a required phone runtime dependency.

Python is required as development/tooling infrastructure for:
- model experimentation;
- model conversion;
- model validation;
- benchmark generation;
- dataset/preprocessing utilities;
- quality regression tests;
- reference implementations;
- offline asset generation.

Use the companion `E_PLAYER_PYTHON_SKILL.md` for Python-specific engineering rules.

---

# 12. DATA PATH RULES

Never transfer uncompressed 4K frames using:
- JSON;
- Base64;
- ordinary serialized messages;
- WebSockets for per-frame image payloads.

Preferred:
- native buffers;
- texture/surface sharing;
- hardware-backed surfaces;
- CVPixelBuffer/Metal on iOS where appropriate;
- HardwareBuffer/Surface/texture interoperability on Android where appropriate;
- FFI handles and bounded native memory pools.

Perfect zero-copy on every device is not a release requirement.

Correctness, stability and broad device support have priority.

---

# 13. THREADING AND CONCURRENCY

Never execute heavy work on the Flutter UI isolate.

Use:
- Dart isolates for orchestration/background Dart work;
- native worker threads for decode/inference/export;
- bounded frame queues;
- ring buffers where appropriate;
- cancellation tokens;
- deadline-aware scheduling.

Separate:
- control plane;
- frame/data plane.

When a user seeks:
1. cancel pending stale enhancement work;
2. flush stale frame queues;
3. seek decoder;
4. resume from the new timestamp.

---

# 14. BACKPRESSURE POLICY

Every frame queue must have a fixed bound.

When enhancement falls behind:
- prefer dropping stale preview frames over delaying playback;
- never grow memory without bound;
- dynamically downgrade model/resolution/interpolation;
- eventually bypass enhancement;
- report the degraded mode honestly.

Player responsiveness is more important than forcing AI processing.

---

# 15. DEVICE CAPABILITY MANAGER

Create a device capability service that reports:

- OS/version;
- CPU architecture;
- RAM class;
- available storage;
- GPU/vendor information where available;
- hardware decoder capabilities;
- AI acceleration availability;
- ONNX provider availability;
- thermal state where exposed;
- approximate sustained performance class;
- supported model variants;
- maximum validated live processing resolution/FPS.

The capability manager is the only approved source for deciding which AI controls/presets are enabled.

---

# 16. ADAPTIVE QUALITY POLICY

Create a policy engine that can select:

- model;
- precision;
- tile size;
- target resolution;
- FPS;
- interpolation mode;
- audio AI mode.

Inputs:
- device tier;
- current FPS;
- inference latency;
- memory pressure;
- temperature/thermal signal;
- battery/power mode;
- user preference.

Example policy:
1. Start at Auto/Best for Device.
2. Benchmark or warm up.
3. Observe sustained inference latency.
4. Reduce model complexity if deadlines are missed.
5. Reduce target resolution if necessary.
6. Disable interpolation before sacrificing playback stability.
7. Fall back to hardware/non-AI scaling if still overloaded.

---

# 17. MODEL REGISTRY

Every AI model must be registered with metadata:

- id;
- name;
- version;
- task;
- license;
- model format;
- input shape;
- supported providers;
- supported precisions;
- minimum RAM class;
- expected latency;
- storage size;
- quality tier;
- target platforms;
- fallback model;
- checksum/version integrity.

Never hardcode model-selection logic throughout the UI.

---

# 18. MEMORY MANAGEMENT

Required:
- reusable buffers;
- pooled frame memory;
- bounded allocations;
- release on error;
- lifecycle cleanup;
- cancellation cleanup;
- storage cleanup for failed exports;
- native resource ownership rules.

No memory leak may persist after:
- leaving the player;
- switching media;
- cancelling export;
- switching model;
- app background/foreground;
- model load failure.

---

# 19. THERMAL + POWER MANAGEMENT

Live AI enhancement can be thermally expensive.

Implement:
- thermal state monitoring where platform APIs expose it;
- quality downgrade;
- FPS downgrade;
- enhancement bypass;
- user-facing thermal notices;
- battery-aware default policy.

Never force full-quality AI on a throttling device.

---

# 20. OFFLINE + PRIVACY

The app must remain functional without internet access.

The following must not be required online:
- playback;
- local media scanning;
- enhancement;
- export;
- subtitle rendering;
- audio processing.

Do not send user media to analytics.

Do not upload frames/audio/subtitles.

Diagnostics must be local by default.

If optional telemetry is ever introduced, it must:
- be explicitly opt-in;
- contain no media content;
- be independently disableable.

---

# 21. STORAGE + MODEL MANAGEMENT

Provide a model management screen showing:
- installed models;
- model size;
- version;
- supported tasks;
- enabled/disabled status;
- removable optional models;
- storage used;
- integrity status.

Core release should ship with a minimal usable model set.

Large model packs may be separately packaged only if the product explicitly chooses that delivery model.

---

# 22. UI TRUTHFULNESS

Never show:
- “4K AI” when only ordinary scaling is running;
- “AI Enhanced” when the model failed;
- “120 FPS” while output timestamps remain unchanged;
- “Noise removed” when no audio processor ran.

Show the actual runtime state:
- AI On;
- AI fallback;
- hardware scaling;
- software scaling;
- interpolation active;
- interpolation bypassed;
- export running.

---

# 23. ERROR HANDLING

Every subsystem must fail independently.

Examples:
- media decoder failure -> show actionable playback error;
- model load failure -> fallback to non-AI playback;
- accelerator failure -> fallback provider;
- export failure -> preserve source, clean temporary files;
- missing subtitle font -> render fallback font;
- thermal limit -> lower quality;
- insufficient storage -> stop before corrupting the source.

Never crash the whole application because an optional AI feature fails.

---

# 24. ACCESSIBILITY

Support:
- scalable text;
- high contrast;
- sufficient touch targets;
- screen-reader labels;
- reduced-motion considerations;
- keyboard/remote support where platform permits;
- localized strings;
- no color-only status communication.

---

# 25. OBSERVABILITY

Create local structured diagnostics for:
- decoder;
- model load;
- provider;
- inference latency;
- frame drops;
- queue depth;
- memory usage;
- export progress;
- thermal downgrade;
- fallback decisions.

Never log:
- media contents;
- audio samples;
- subtitles;
- private file contents.

Use redacted file identifiers if diagnostics require identification.

---

# 26. TESTING

## Unit tests
Test:
- presets;
- capability policy;
- model registry;
- adaptive quality policy;
- timestamp calculations;
- A/V synchronization logic;
- export state machine.

## Integration tests
Test:
- play -> seek -> enhance;
- model failure -> fallback;
- provider failure -> fallback;
- export cancel;
- background/foreground;
- subtitle switching;
- audio track switching.

## Performance tests
Measure:
- startup time;
- playback stability;
- decoder FPS;
- enhancement FPS;
- frame-drop percentage;
- inference latency;
- RAM;
- VRAM/native buffer usage where measurable;
- sustained thermal behavior;
- export throughput.

## Visual quality tests
Use a fixed test corpus for:
- low-resolution video;
- noisy video;
- anime/animation;
- compressed video;
- fast motion;
- text-heavy scenes;
- faces;
- dark scenes.

Quality regression must compare output against reference expectations.

---

# 27. IMPLEMENTATION ORDER

Follow this sequence unless the user explicitly changes priorities:

Phase 0 — Architecture + feasibility
Phase 1 — Core offline player
Phase 2 — Native inference core
Phase 3 — Video enhancement MVP
Phase 4 — Live enhancement pipeline
Phase 5 — Frame interpolation
Phase 6 — Audio enhancement
Phase 7 — Offline export
Phase 8 — Advanced features
Phase 9 — Compatibility, accessibility, hardening
Phase 10 — Release engineering

Never skip the foundation to build an impressive UI demo.

---

# 28. DEFINITION OF DONE

A feature is not complete until:
- code is implemented;
- real data flows through it;
- error handling exists;
- cancellation exists where applicable;
- tests cover critical logic;
- performance impact is measured;
- UI state reflects real backend state;
- offline behavior is verified;
- device fallback is verified;
- documentation is updated.

A visual mockup is not an implementation.

---

# 29. AI AGENT DEVELOPMENT BEHAVIOR

When working on the project:

1. Inspect the repository before changing architecture.
2. Identify current platform and build constraints.
3. Reuse working components instead of rewriting them without evidence.
4. Implement the smallest verifiable slice.
5. Run tests/build checks.
6. Measure before optimizing.
7. Keep product logic platform-agnostic and isolate native differences behind adapters.
8. Never fake AI results.
9. Never silently add cloud dependencies.
10. Never remove an offline requirement to simplify development.
11. Record unresolved risks explicitly.
12. Prefer incremental commits/changes with clear boundaries.
13. Keep model licenses and attribution documented.
14. Never claim completion until critical acceptance tests pass.

---

# 30. DEFAULT DECISION RULES

When uncertain:

- Correct playback > AI quality.
- Stability > maximum resolution.
- Privacy > telemetry.
- Bounded memory > throughput.
- Explicit fallback > crash.
- Measured performance > marketing claims.
- Capability detection > device assumptions.
- Native/mobile inference > embedded Python on phones.
- Export can be heavier than live playback.
- Experimental features must be capability-gated.

---

# 31. REQUIRED OUTPUT WHEN AN AI AGENT IS ASKED TO IMPLEMENT A FEATURE

Before coding:
- state the affected architecture layers;
- identify dependencies;
- identify platform-specific work;
- identify tests.

After coding:
- summarize files changed;
- explain actual behavior;
- report tests/builds run;
- report known limitations;
- distinguish real implementation from stubs.

