# E-PLAYER IMPLEMENTATION PLAN V3 — RESUME AND HARDEN

## Phase 0 — Repository truth
### Parts
0.1 Inventory all current files.
0.2 Map current PlayerScreen, EnhancementStudio, C++ FFI, subtitle/libass and media_kit.
0.3 Mark every existing feature REAL / PARTIAL / MOCK / MISSING.
0.4 Capture baseline build/test/performance.

**Exit:** no architectural unknowns.

## Phase 1 — Playback hardening
### Parts
1.1 Decoder capability service.
1.2 Auto/Hardware/Hybrid/Software modes only where supported.
1.3 Runtime decoder/provider diagnostics.
1.4 First-frame and first-seek race handling.
1.5 Orientation/surface lifecycle handling.
1.6 Track switching regression.
1.7 high-resolution/10-bit/HDR capability matrix.

**Exit:** stable playback matrix on representative Android/iOS/Windows devices.

## Phase 2 — Player controls
### Parts
2.1 speed 0.25x–8x.
2.2 pitch correction.
2.3 aspect ratio modes.
2.4 lock controls.
2.5 player diagnostics overlay.

## Phase 3 — Gestures
### Parts
3.1 gesture state machine.
3.2 left brightness/right volume.
3.3 center horizontal seek.
3.4 double-tap seek/play.
3.5 pinch zoom/pan.
3.6 two-finger speed.
3.7 thresholds/dead zones/accessibility.

## Phase 4 — Subtitle Pro
4.1 delay.
4.2 styling.
4.3 encoding override.
4.4 provider interface.
4.5 online subtitle search.
4.6 cache/offline use.

## Phase 5 — Audio DSP
5.1 5-band EQ.
5.2 presets.
5.3 Bass Boost.
5.4 preamp + limiter.
5.5 dialogue/night.
5.6 optional virtualizer.
5.7 pitch-preserving speed.

## Phase 6 — Background and PiP
6.1 Android MediaSessionService/native service.
6.2 notification and media controls.
6.3 audio focus/interruption.
6.4 Android system PiP.
6.5 iOS AVAudioSession/background mode.
6.6 iOS PiP.

## Phase 7 — Library
7.1 local database schema.
7.2 MediaStore/SAF scanner.
7.3 iOS document sources.
7.4 incremental scan.
7.5 exclusions.
7.6 thumbnails.
7.7 search/sort/filter.
7.8 watch progress/favorites.

## Phase 8 — Vault and trash
8.1 key generation/storage.
8.2 authenticated encryption.
8.3 encrypted metadata.
8.4 secure streaming decryption.
8.5 biometric/PIN.
8.6 trash/TTL/recovery.
8.7 corruption/tamper recovery.

## Phase 9 — Network playback
9.1 HTTP/HTTPS.
9.2 HLS.
9.3 DASH.
9.4 RTSP if verified.
9.5 authentication/headers.
9.6 reconnect/buffering diagnostics.

## Phase 10 — NAS
10.1 SMB.
10.2 UPnP/DLNA discovery.
10.3 credential vaulting.
10.4 remote metadata cache.
10.5 streaming large-file tests.

## Phase 11 — Casting
11.1 Cast abstraction.
11.2 Google Cast.
11.3 AirPlay where selected.
11.4 local-file token server.
11.5 remote timeline/volume sync.
11.6 cast cleanup/security.

## Phase 12 — Real AI model pipeline
12.1 Python reference model.
12.2 ONNX conversion.
12.3 model manifest/checksum.
12.4 native/mobile inference interface.
12.5 tiled preprocessing.
12.6 Real-ESRGAN inference.
12.7 encode/mux.
12.8 output validation.

## Phase 13 — AI export job engine
States: Queued → Preparing → Decoding → Enhancing → Encoding → Muxing → Validating → Completed/Cancelled/Failed.
Parts: cancellation, progress, bounded buffers, crash recovery, cleanup.

## Phase 14 — RIFE
14.1 reference. 14.2 2x. 14.3 60fps. 14.4 scene cuts. 14.5 timestamps. 14.6 A/V sync. 14.7 120fps capability gate.

## Phase 15 — AI audio
15.1 reference. 15.2 denoise model. 15.3 streaming mode. 15.4 export mode. 15.5 fallback.

## Phase 16 — 2D→3D
Capability-gated only. Depth → smoothing → parallax → left/right output → preview/export.

## Phase 17 — Adaptive quality
Device tier, memory, thermal state, queue depth, inference latency, battery state.
Policy order: keep playback → reduce model → reduce resolution → disable interpolation → bypass AI.

## Phase 18 — Security + compliance
Permissions, secure storage, vault, model provenance, codec/license inventory, cast server hardening, privacy review, native binary/page-size readiness.

## Phase 19 — Performance
Long playback, repeated seek, orientation, model switching, 10 export cancels, background/foreground, low storage, thermal stress.

## Phase 20 — Release regression
Clean install, offline, representative media corpus, device matrix, accessibility, visual regression, crash review, license inventory.

### Resume instruction
Antigravity must start at Phase 0 and skip only a part proven complete by repository inspection and tests. It must never restart working playback or UI from scratch.
