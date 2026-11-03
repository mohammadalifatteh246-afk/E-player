# Scope: E-Player Generation 2 Orchestration Roadmap

## Architecture
- Presentation Layer: PlayerScreen, CinematicGestureEngine, PipService UI integration, Casting UI
- Domain Layer: DecoderPipelineService, PipService, LocalStreamingDaemon, CastService
- Hardware / Platform Layer: MethodChannel ('com.example.app/pip', 'com.example.app/system_brightness'), libmpv native FFI

## Feature Inventory
| # | Feature | Description | Milestone | Status |
|---|---------|-------------|-----------|--------|
| 1 | Decoder Mode Selection | Manual selection Auto/HW/HW+/SW via libmpv | M1 | DONE |
| 2 | Dynamic Fallback Pipeline | Sliding window frame drops (>10 in 2s) cascade | M1 | DONE |
| 3 | HW Acceleration Invariant | Native libmpv filtering without Flutter raster filter | M1 | DONE |
| 4 | Decoder Telemetry HUD | Real-time diagnostic HUD for decoder/codec/drops | M1 | DONE |
| 5 | Horizontal Precision Scrub | Center drag timeline scrub with seek preview | M2 | DONE |
| 6 | Split Brightness/Volume | Left/right vertical drag adjustments | M2 | DONE |
| 7 | Double-Tap Wing Jump | Left/right 33% double tap +/-10s seek | M2 | DONE |
| 8 | Pinch-to-Zoom & Pan Bounds | 1.0x-4.0x zoom with zero-void pan clamping | M2 | DONE |
| 9 | Gesture Dead-Zone Arbitration | 12px & 1.5x dominant axis gating | M2 | DONE |
| 10 | HUD Auto-Dismiss Coordination | Pauses during gesture, 2800ms / 800ms lingering | M2 | DONE |
| 11 | Android AutoEnterPiP | Automatically transitions full-screen video to system PiP on Home swipe (API 31+) | M3 | DONE |
| 12 | Aspect Ratio Preservation in PiP | Sets PiP rational aspect ratio matching video stream native dimensions, clamped to [1/2.39, 2.39/1] | M3 | DONE |
| 13 | PiP Remote Media Controls | RemoteAction intents for Play, Pause, Seek +/-10s in system PiP window | M3 | DONE |
| 14 | HUD Auto-Dismiss on PiP Enter | Immediately clears Flutter UI sheets, controls, overlays on PiP entry for clean video surface | M3 | DONE |
| 15 | Desktop Overlay Window Mode | Floating borderless always-on-top window on Windows/macOS with aspect-ratio locked resize and coordinate restoration | M3 | DONE |
| 16 | Multi-Protocol Sink Discovery | Local LAN discovery of Chromecast, DLNA, Miracast, AirPlay renderers via mDNS/SSDP | M4 | DONE |
| 17 | Tokenized Local Streaming Server | Ephemeral LAN HTTP server serving local media via `/cast/{session_token}/{media_id}/stream` | M4 | DONE |
| 18 | HTTP 206 Partial Content Range | Supports seeking on remote TV receiver via HTTP Range byte requests | M4 | DONE |
| 19 | Tokenized Subtitle Sidecar | Converted WebVTT subtitle stream delivered to remote sink | M4 | DONE |
| 20 | Bi-Directional State Sync | Synchronizes Play/Pause, Seek, Volume between mobile app and remote receiver with heartbeat monitoring | M4 | DONE |
| 21 | Strict Offline Invariant | Zero WAN/cloud communication during casting or local playback; strictly offline local protocols | M4 | DONE |
| 22 | 100% E2E Test Suite | All 245+ tests across Tiers 1-4 passing cleanly | M5 | PLANNED |
| 23 | Meta-ACH Mutation Hardening | Semantic mutants killed by regression suite | M5 | PLANNED |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Phase 1 Hardware/HW+ Decoders | DecoderPipelineService, dynamic fallback, telemetry | none | DONE |
| M2 | Phase 3 Cinematic Gesture Engine | CinematicGestureEngine, GestureArbitrator, remediation | none | DONE |
| M3 | Phase 6 Native Picture-in-Picture | PipService, Android AutoEnterPiP, aspect ratio, desktop overlay | M1, M2 | DONE |
| M4 | Phase 11 Tokenized Wireless Casting | LocalStreamingDaemon, HTTP 206, WebVTT sidecar, CastService | none | DONE |
| M5 | Final: 100% E2E Pass & Meta-ACH Hardening | All E2E tests, mutation hardening, clean git tree | E2E, M1-M4 | PLANNED |
