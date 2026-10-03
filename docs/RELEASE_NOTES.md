# E-Player v1.0.0 Release Notes

Welcome to the official 1.0.0 release of **E-Player**! We have successfully completed all 10 architectural phases. E-Player is now a fully offline, hardware-accelerated media player featuring AI-powered video, audio, and depth enhancement.

## Core Features (Phase 1-4)
- **Zero-Network Architecture:** Everything runs natively on your device.
- **Hardware-Accelerated Playback:** Seamless playback via `media_kit` (FFmpeg-backed).
- **Native AI Pipeline:** Custom C++ FFI integration bridging Dart to ONNX Runtime.
- **Background Offline Export:** AI enhancement exports run in a dedicated Dart Isolate with zero UI frame drops.

## AI & Enhancements (Phase 5-8)
- **Temporal Enhancement (RIFE):** 30fps to 60fps/120fps offline interpolation with A/V sync.
- **Spatial Upscaling (Real-ESRGAN):** Crisp 1080p, 1440p, and 4K upscaling.
- **Audio DSP & AI Isolation:** Built-in Compressor, Loudness Normalization, Night Mode, and RNNoise background dialogue isolation.
- **3D Stereoscopic Conversion:** Real-time Depth Anything V2 SBS conversion.
- **Offline ASR:** Subtitle generation via Whisper-mobile C++.
- **Thermal Gating:** Intelligent NPU load distribution and thermal throttling checks.

## Compatibility & Reliability (Phase 9-10)
- Verified crash-free isolated execution on Android (API 24+) and iOS (15+).
- Strict A11y Semantics for accessibility and screen reader support.
- Fully offline privacy compliance with zero telemetry.

Enjoy your ultimate offline viewing experience!
