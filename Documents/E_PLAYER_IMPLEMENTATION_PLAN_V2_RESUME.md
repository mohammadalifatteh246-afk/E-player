# E-PLAYER IMPLEMENTATION PLAN V2
## Resume-from-Current-State Roadmap for Antigravity

**Purpose:** Continue exactly where the existing repository stopped. Do not restart completed work.

## 0. Current Stop Point

Preserve and verify:
- Flutter UI/app structure.
- media_kit/libmpv playback.
- PlayerScreen/custom controls.
- audio/subtitle track UI.
- libass/native subtitle behavior.
- EnhancementStudioSheet.
- C++ native engine.
- Dart FFI.
- Windows CMake/native build.
- current simulated DSP fallback.

Reported missing:
- true ONNX AI;
- offline AI export;
- Android/iOS build integration;
- decoder mode menu;
- gestures;
- aspect ratio controls;
- subtitle sync/style/encoding tools;
- 5-band EQ/effects;
- background audio;
- PiP;
- library scanner/index;
- vault;
- trash;
- network URLs;
- Chromecast/AirPlay;
- final performance/security/release hardening.

The progress percentages supplied by the project team must be treated as provisional until Phase 0 verifies the repository.

---

# PHASE 0 — FORENSIC AUDIT

### Part A — Build inventory
Inspect all source, native, FFI, model, plugin, Gradle, iOS, CMake and test directories.

### Part B — Reality matrix
Mark every feature:
`REAL / PARTIAL / MOCK / MISSING / PLATFORM-SPECIFIC`

### Part C — Dependency/license inventory
Record exact versions and licenses for media_kit, libmpv, FFmpeg, ONNX Runtime, model files, subtitle components, native libraries and plugins.

### Part D — Baseline
Build Windows, run app, run tests, capture warnings/errors. Build Android and iOS if toolchains are available.

**Exit:** actual repository state documented.

---

# PHASE 1 — ANDROID + IOS FOUNDATION

### Part 1.1 Android
- align Gradle/AGP/NDK;
- package arm64 and other required ABIs;
- fix native `.so` packaging;
- verify Android 13+ permissions;
- verify Android 14+ FGS requirements;
- test Android 15 restrictions;
- verify Android 16 / 16 KB alignment.

### Part 1.2 iOS
- build native C++ framework/plugin;
- verify FFI;
- add required capabilities;
- verify document picker path;
- prepare ONNX Runtime packaging.

### Part 1.3 Native bridge
Create stable C ABI and platform adapters so Flutter remains independent of platform details.

**Exit:** Windows still works + Android build works + iOS build works.

---

# PHASE 2 — PLAYBACK PARITY

### Part 2.1 Decoder modes
Add Auto / Hardware / Hardware+ / Software, but only expose HW+ if the backend has a real hybrid/copy path.

### Part 2.2 Decoder telemetry
Show actual decoder/backend/codec/fallback state.

### Part 2.3 Aspect ratio
Fit / Fill / Crop / Stretch / Original / 16:9 / 4:3 / 21:9 / Pan & Scan.

### Part 2.4 Speed
0.25x–8x + pitch correction.

### Part 2.5 Metadata overlay
Show resolution/FPS/codec/audio/HDR/decoder state when detectable.

**Exit:** existing playback regressions = none.

---

# PHASE 3 — GESTURE ENGINE

### Parts
1. Gesture state machine.
2. Left brightness.
3. Right volume.
4. Center seek.
5. Double-tap seek/play.
6. Pinch zoom + pan.
7. Two-finger speed.
8. Gesture settings.
9. Visual feedback.
10. Accessibility/system gesture conflict tests.

**Exit:** gesture matrix passes on real devices.

---

# PHASE 4 — SUBTITLE PRO

### Parts
1. Delay control.
2. Font size/color.
3. Outline/shadow/background.
4. Position.
5. Encoding override.
6. Reset style.
7. Subtitle provider abstraction.
8. OpenSubtitles.com adapter.
9. Secure credentials/rate limiting.

Keep all existing libass/PGS/VOBSUB behavior intact.

**Exit:** SRT/VTT/ASS/SSA + existing complex subtitle tests pass.

---

# PHASE 5 — AUDIO SUITE

### Parts
1. 5-band EQ.
2. EQ presets.
3. Bass Boost.
4. Virtualizer/stereo widening where supported.
5. Dialogue Boost.
6. Night Mode.
7. Loudness normalization.
8. Limiter/gain.
9. Pitch correction.
10. Unit/integration tests for every control.

**Exit:** controls affect real audio processing and can be bypassed.

---

# PHASE 6 — LIBRARY INDEXER

### Parts
1. Local DB.
2. Android MediaStore.
3. Android SAF selected folders.
4. iOS Document Picker.
5. Security-scoped bookmarks.
6. Incremental scanning.
7. Cancel/resume.
8. Folder exclusions.
9. Duplicate detection.
10. Metadata extraction.
11. Thumbnail generation.
12. Search/filter/sort.
13. Recent/favorites/progress.

Do not make MANAGE_EXTERNAL_STORAGE mandatory for convenience.

**Exit:** library replaces picker-only operation without breaking direct file open.

---

# PHASE 7 — VAULT + TRASH

### Vault
1. Per-vault random key.
2. Android Keystore / iOS Keychain protection.
3. Biometric unlock.
4. Authenticated encryption.
5. Chunked large-file encryption.
6. Encrypted metadata.
7. Vault playback.
8. Auto-lock.
9. Tamper/corruption tests.

### Trash
1. Move.
2. Restore.
3. Permanent delete.
4. Empty all.
5. Retention policy.
6. Storage accounting.

**Exit:** vault is cryptographic protection, not hidden files.

---

# PHASE 8 — BACKGROUND + PIP

### Android
- MediaSession.
- MediaSessionService.
- media playback foreground service.
- notification.
- audio focus.
- media buttons.
- playback resumption.
- native PiP.

### iOS
- AVAudioSession playback category.
- background audio capability.
- interruption/route changes.
- AVPictureInPictureController.

**Exit:** background/pip tests pass on supported devices.

---

# PHASE 9 — NETWORK STREAMING

### Parts
1. URL input.
2. HTTP/HTTPS.
3. HLS/DASH where backend supports.
4. RTSP where supported.
5. Headers/auth.
6. buffering state.
7. reconnect.
8. credential-safe logs.

**Exit:** network features do not regress local playback.

---

# PHASE 10 — CASTING

### Parts
1. `ICastService`.
2. Google Cast Android.
3. Google Cast iOS where supported.
4. AirPlay if selected.
5. Discovery.
6. Session lifecycle.
7. Play/pause/seek/volume.
8. Local-to-remote handoff.
9. Remote-to-local handoff.
10. LAN local-file proxy with random short-lived token.
11. No directory listing.
12. Session expiry/shutdown.

**Exit:** real local video can be cast safely to a compatible receiver.

---

# PHASE 11 — PYTHON MODEL TOOLCHAIN

Python remains development/reference tooling.

### Parts
1. Model registry.
2. Exact model version pinning.
3. License audit.
4. PyTorch reference inference.
5. ONNX export.
6. ONNX graph validation.
7. Golden outputs.
8. Quantization tests.
9. Checksum generation.
10. Benchmark scripts.
11. Quality regression suite.

Models:
- Real-ESRGAN-derived spatial model.
- RIFE-derived temporal model.
- compact depth model.
- audio denoise/enhancement model.

**Exit:** one real mobile-compatible ONNX model validated end-to-end.

---

# PHASE 12 — REAL AI OFFLINE EXPORT

This is the biggest remaining milestone.

### Pipeline
```text
input
 -> probe
 -> native decode
 -> bounded frame queue
 -> preprocess
 -> ONNX Runtime Mobile
 -> postprocess
 -> native encode
 -> mux original/enhanced audio
 -> validate
 -> final file
```

### Parts
1. Native decode interface.
2. Native frame pool.
3. Bounded ring buffer.
4. Preprocessing.
5. ONNX session lifecycle.
6. CPU/XNNPACK baseline.
7. Android NNAPI experiment.
8. iOS CoreML experiment.
9. tiled Real-ESRGAN inference.
10. output reconstruction.
11. encoder integration.
12. muxing.
13. A/V sync validation.
14. output validation.
15. failure cleanup.

Do not transfer 4K frames through Dart.

Do not report simulated DSP as AI.

**Exit:** a real source clip produces a real neural-enhanced output.

---

# PHASE 13 — EXPORT JOB ENGINE

State machine:
`Queued -> Preparing -> Decoding -> Enhancing -> Encoding -> Muxing -> Validating -> Completed`

Failure states:
`Cancelled / Failed`

### Parts
- progress;
- cancellation;
- foreground/background behavior;
- crash-safe temp output;
- atomic finalize;
- cleanup;
- resume strategy where feasible;
- one heavy AI job at a time by default.

**Exit:** long export does not freeze UI or corrupt files.

---

# PHASE 14 — RIFE

### Parts
1. Reference validation.
2. 2x interpolation.
3. 60 FPS target.
4. scene-cut detection.
5. timestamp reconstruction.
6. audio-clock integration.
7. 120 FPS capability gate.

**Exit:** no persistent A/V drift and bounded queue.

---

# PHASE 15 — AI AUDIO

### Parts
1. DSP baseline.
2. mobile neural denoise.
3. live capability mode.
4. offline export mode.
5. bypass/fallback.
6. speech-vs-music policy.

**Exit:** real enhancement, measurable output, safe fallback.

---

# PHASE 16 — DEPTH / 3D

### Parts
- model validation;
- temporal/depth smoothing;
- parallax;
- left/right generation;
- output display modes;
- capability gate.

This is not allowed to block normal playback or the main AI release.

---

# PHASE 17 — DEVICE CAPABILITY + ADAPTIVE QUALITY

Measure:
- CPU/GPU class;
- RAM;
- decoder capability;
- provider availability;
- inference latency;
- queue depth;
- thermal state;
- storage.

Adaptive policy:
1. Auto.
2. lower model complexity.
3. lower output resolution.
4. disable interpolation.
5. lower enhancement strength.
6. bypass AI.

Stable playback always wins.

---

# PHASE 18 — NATIVE HARDENING / 16 KB

Audit every native `.so`/framework:
- C++ engine;
- FFmpeg;
- libmpv;
- ONNX Runtime;
- other native plugins.

Verify Android 16 16 KB readiness in release packaging.

**Exit:** no native dependency prevents current Android builds.

---

# PHASE 19 — PERFORMANCE + MEMORY

Stress tests:
- 30 min playback;
- 2 hour playback;
- repeated seek;
- 50 media opens;
- repeated model switching;
- repeated export cancellation;
- repeated background/foreground;
- repeated orientation change.

Capture:
- RAM;
- native memory;
- queue depth;
- dropped frames;
- inference latency;
- thermal behavior;
- battery trend.

**Exit:** no unbounded resource trend.

---

# PHASE 20 — SECURITY / PRIVACY

Test:
- vault wrong PIN;
- biometric denial;
- vault restart/reboot;
- corrupted encrypted chunk;
- tampered metadata;
- local cast token expiration;
- subtitle/provider credentials;
- malformed media/subtitles;
- path traversal;
- model checksum failures;
- logs for secret leakage.

**Exit:** no unresolved high-risk issue.

---

# PHASE 21 — FULL REGRESSION

Run all:
- playback;
- decoder modes;
- gestures;
- aspect ratio;
- subtitles;
- audio;
- library;
- vault;
- trash;
- background;
- PiP;
- network streams;
- casting;
- AI upscaling;
- RIFE;
- AI audio;
- 3D;
- export;
- offline mode.

Every existing feature must be revalidated after AI/native changes.

---

# PHASE 22 — CLEAN INSTALL / RELEASE CANDIDATE

### Android
Fresh install, permissions, offline mode, background, low storage, release build, 16 KB environment where available.

### iOS
Fresh install, document access, background audio, PiP, local-network permission when needed.

### Windows
Fresh install/reference build and existing media test corpus.

---

# PHASE 23 — ANTIGRAVITY STARTUP INSTRUCTIONS

When Antigravity opens the repository:

1. Inspect the repository.
2. Build Windows.
3. Run tests.
4. Locate `PlayerScreen`.
5. Locate `EnhancementStudioSheet`.
6. Locate C++ FFI API.
7. Locate simulated DSP code.
8. Locate media_kit/libmpv setup.
9. Locate subtitle/libass configuration.
10. Build Android.
11. Build iOS if available.
12. Create a REAL/PARTIAL/MOCK/MISSING table.
13. Start Phase 1 using the existing architecture.

Do not rewrite completed working modules without a measured reason.

---

# CRITICAL DECISIONS

1. Python/Chaquopy is not the cross-platform production inference runtime.
2. Current simulated DSP must not be marketed as AI.
3. `MANAGE_EXTERNAL_STORAGE` is not the default library strategy.
4. Original FFmpegKit is retired; do not adopt it blindly.
5. System PiP is preferred over overlay-permission hacks.
6. Vault security must be encryption + secure key storage.
7. HW+ is allowed only when backed by a real native mode.
8. No unbounded native frame queue.
9. No 4K frame transport through Dart serialization.
10. Offline export comes before aggressive live 4K AI.

# PHASE COMPLETION FORMAT

For every phase Antigravity must report:

```text
Phase:
Parts completed:
Files/modules changed:
Build status:
Tests added:
Tests passed:
Device(s) tested:
Performance observations:
Known limitations:
Regression result:
Next phase:
```

Never declare a phase complete if the implementation is only a mock or UI stub.

---

# APPENDIX A — 50+ RESEARCH SOURCES USED

The external research pass covered more than 50 current source pages. The most decision-relevant sources are indexed below.

1. https://developer.android.com/design/ui/mobile/guides/layout-and-content/edge-to-edge
2. https://developer.android.com/develop/background-work/services/fgs/declare
3. https://developer.android.com/develop/ui/views/picture-in-picture
4. https://developer.android.com/media/media3/session/background-playback
5. https://developer.android.com/about/versions/14/changes/fgs-types-required
6. https://developer.android.com/design/ui/mobile/guides/home-screen/picture-in-picture
7. https://developer.android.com/develop/background-work/services/fgs/service-types
8. https://developer.android.com/training/data-storage/manage-all-files
9. https://developer.android.com/develop/background-work/services/fgs/launch
10. https://developer.android.com/training/data-storage/shared/documents-files
11. https://developer.android.com/reference/android/content/Intent
12. https://developer.android.com/media/media3/transformer/composition
13. https://developer.android.com/media/media3/transformer/supported-formats
14. https://developer.android.com/media/media3/ui/playerview
15. https://developer.android.com/media/media3/transformer/getting-started
16. https://developer.android.com/media/optimize/audio-focus
17. https://developer.android.com/media/media3/session/control-playback
18. https://developer.android.com/training/data-storage/app-specific
19. https://developer.android.com/training/data-storage/use-cases
20. https://developer.android.com/media/media3/transformer/transformations
21. https://developer.android.com/media/media3/session/player
22. https://developer.android.com/distribute/aep/aep-req-media-3
23. https://developer.android.com/media/media3/exoplayer/downloading-media
24. https://developer.android.com/about/versions/13/behavior-changes-13
25. https://developer.android.com/about/versions/15/behavior-changes-15
26. https://developer.android.com/about/versions/16/behavior-changes-all
27. https://docs.flutter.dev/reference/supported-platforms
28. https://docs.flutter.dev/platform-integration/platform-channels
29. https://docs.flutter.dev/platform-integration/bind-native-code
30. https://docs.flutter.dev/platform-integration/legacy-ffi-plugin
31. https://docs.flutter.dev/packages-and-plugins/background-processes
32. https://docs.flutter.dev/add-to-app
33. https://docs.flutter.dev/add-to-app/ios/project-setup
34. https://docs.flutter.dev/platform-integration/ios
35. https://pub.dev/documentation/media_kit/latest/
36. https://pub.dev/packages/media_kit
37. https://pub.dev/packages/media_kit_video
38. https://pub.dev/packages/media_kit_video/example
39. https://github.com/media-kit
40. https://mpv.io/manual/stable/
41. https://mpv.io/manual/master/
42. https://ffmpeg.org/general.html
43. https://onnxruntime.ai/docs/tutorials/mobile/
44. https://onnxruntime.ai/docs/execution-providers/
45. https://onnxruntime.ai/docs/execution-providers/NNAPI-ExecutionProvider.html
46. https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html
47. https://onnxruntime.ai/docs/execution-providers/Xnnpack-ExecutionProvider.html
48. https://onnxruntime.ai/docs/performance/model-optimizations/quantization.html
49. https://onnxruntime.ai/docs/build/ios.html
50. https://github.com/DepthAnything/Depth-Anything-V2
51. https://github.com/DepthAnything
52. https://developers.google.com/cast/docs/android_sender/integrate
53. https://developers.google.com/cast/docs/android_sender/output_switcher
54. https://pub.dev/documentation/cast/latest/
55. https://pub.dev/packages/dart_cast
56. https://pub.dev/packages/flutter_chrome_cast
57. https://developer.android.com/identity/sign-in/biometric-auth
58. https://support.google.com/googleplay/android-developer/answer/16909972
59. https://support.google.com/googleplay/android-developer/answer/16558241
60. https://support.google.com/googleplay/android-developer/answer/10467955
61. https://support.google.com/googleplay/android-developer/answer/15800983
62. https://support.google.com/googleplay/android-developer/answer/14115180
63. https://developer.apple.com/documentation/AVKit/AVPictureInPictureController
64. https://developer.apple.com/documentation/security/keychain-services/
65. https://developer.apple.com/documentation/MetalPerformanceShaders
66. https://developer.apple.com/documentation/cryptokit/aes
67. https://developer.apple.com/documentation/avfoundation/avassetexportsession
68. https://developer.apple.com/documentation/avfaudio/avaudiosession
69. https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
70. https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller
71. https://developer.apple.com/documentation/foundation/nsurl/startaccessingsecurityscopedresource()
72. https://developer.apple.com/documentation/security/storing-keys-in-the-keychain
73. https://chaquo.com/chaquopy/documentation/
74. https://github.com/arthenica/ffmpeg-kit
75. https://github.com/arthenica/ffmpeg-kit/blob/main/README.md
76. https://github.com/libass/libass
77. https://www.w3.org/TR/webvtt/all/
78. https://www.loc.gov/preservation/digital/formats/fdd/fdd000569.shtml
79. https://github.com/xiph/rnnoise
80. https://github.com/m-bain/whisperx
81. https://github.com/vankasteelj/opensubtitles.com
82. https://github.com/opensubtitles/mcp.opensubtitles.com
83. https://github.com/xinntao/Real-ESRGAN
84. https://github.com/xinntao/Real-ESRGAN/releases
85. https://github.com/xinntao/Real-ESRGAN/issues
86. https://github.com/hzwer/ECCV2022-RIFE
87. https://pub.dev/packages/cast_plus
88. https://pub.dev/documentation/video_cast/latest/
89. https://pub.dev/documentation/video_kit/latest/
90. https://pub.dev/documentation/googlecast/latest/

## Research interpretation rule

These sources were used to derive implementation constraints, platform behavior, library capabilities, security boundaries, and feature directions. The XPlayer document was treated as a feature/UX benchmark rather than authoritative platform documentation. Where the uploaded research and current official documentation differ, the current official documentation controls implementation details.
