# Comprehensive Specification Mining Report: Phase 1, Phase 3, Phase 6, Phase 11

**Agent:** `spec_miner_survey_features` (Player Requirements Spec Miner)  
**Target Subsystems:**
- Phase 1: Hardware / HW+ Decoders & Dynamic Fallback Pipeline
- Phase 3: Cinematic Gesture Engine & Multi-Touch Arbitration
- Phase 6: Native Picture-in-Picture (Android AutoEnterPiP & Desktop Overlay)
- Phase 11: Tokenized Wireless Casting & Offline Streaming Daemon

---

## 1. Observation

### 1.1 Existing Codebase & Architecture Assets
Direct inspection of repository files yielded the following concrete observations:

1. **Decoder Implementation (`app/lib/features/player/ui/player_screen.dart`, Lines 388–404):**
   ```dart
   void _setDecoderMode(String mode) async {
     setState(() => _decoderMode = mode);
     final dynamic platform = _player.platform;
     try {
       String hwdecValue = 'auto';
       if (mode == 'HW') {
         hwdecValue = 'yes';
       } else if (mode == 'HW+') {
         hwdecValue = 'auto-copy';
       } else if (mode == 'SW') {
         hwdecValue = 'no';
       }
       await platform.setProperty('hwdec', hwdecValue);
     } catch (e) {
       debugPrint("hwdec err: $e");
     }
   }
   ```
   *Observation:* Decoder mode selection simply calls `platform.setProperty('hwdec', ...)`. There is no automated error detection, no telemetry logging of `hwdec-current`, no drop-frame monitoring (`vo-drop-frame-count`), and zero automated fallback across HW -> HW+ -> SW if hardware decoding fails or stutters on high-bitrate 4K streams.

2. **Hardware Acceleration Invariant vs Flutter Raster Filtering:**
   - In `app/lib/features/video_effects/domain/video_effects_service.dart` (Lines 48–55), color adjustments (`contrast`, `brightness`, `saturation`, `gamma`, `hue`) are offloaded to `libmpv` native properties via `platform.setProperty()`.
   - In `player_screen.dart` (Lines 1000–1009), the video widget is wrapped in `Transform.rotate` and `RotatedBox` on the Flutter compositing tree, risking redundant raster filtering when combined with high-resolution 4K/60fps playback.
   - Authoritative rule in `ORIGINAL_REQUEST.md` (Line 51): *"Video color adjustments and geometric transforms remain hardware-accelerated inside libmpv without redundant Flutter raster filtering."*

3. **Current Gestures (`player_screen.dart`, Lines 232–339 & 987–993):**
   ```dart
   GestureDetector(
     onTap: _toggleControls,
     onDoubleTapDown: _onDoubleTapDown,
     onScaleStart: _onScaleStart,
     onScaleUpdate: _onScaleUpdate,
     onScaleEnd: _onScaleEnd,
     behavior: HitTestBehavior.opaque,
     child: Stack(...)
   )
   ```
   *Observation:* Multi-touch handling uses a single `GestureDetector` that routes taps, double-taps, single-finger swipes, and two-finger pinches without a formal arbitration state machine or dead-zone velocity gating. Vertical drags on the edges (left 30% for brightness, right 30% for volume) lack directional dead zones, resulting in accidental seeks when swiping slightly diagonally. Panning during pinch-to-zoom is unbounded, allowing the video surface to be dragged entirely off-screen.

4. **Picture-in-Picture Baseline:**
   - Android Manifest (`app/android/app/src/main/AndroidManifest.xml`, Line 21):
     `android:supportsPictureInPicture="true"` is declared.
   - `MainActivity.kt` (`app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`): MethodChannel only implements `com.example.app/media_scanner`. There is no MethodChannel handling PiP requests, no `enterPictureInPictureMode`, no `PictureInPictureParams.Builder.setAutoEnterEnabled(true)`, and no BroadcastReceiver for remote PiP actions (`ACTION_PLAY_PAUSE`, `ACTION_SEEK`).
   - `player_screen.dart`: Contains no PiP button, no lifecycle listener for `onPictureInPictureModeChanged`, and no HUD auto-dismiss hook when entering PiP.

5. **Casting Baseline (`app/lib/features/casting/domain/cast_service.dart`):**
   - Contains a rich domain model with `CastProtocol` (`chromecast`, `airplay`, `dlna`, `miracast`) and `CastTranscodeProfile` (`directPassthrough`, `audioRemux`, `videoTranscode`, `fullRemux`).
   - Device discovery currently seeds 5 mock devices (`chromecast_living_room`, `appletv_studio`, `sony_bravia_theater`, `samsung_bedroom`, `shield_guest`).
   - Connection simulation uses `await Future.delayed(Duration(milliseconds: 650))`.
   - Missing: Actual local tokenized HTTP streaming server (`HttpServer` bound to LAN interface) to hand off local offline media files and converted WebVTT subtitles to external renderers, and no native socket discovery for mDNS/SSDP.

6. **Test Baseline:**
   - Execution of `flutter test` completed with exit code 0: `67/67 tests passing`. Baseline integrity is 100% verified.

---

## 2. Logic Chain

1. **Hardware / HW+ Decoders (Phase 1):**
   - *Premise 1:* Modern media playback on resource-constrained mobile devices and varied desktop GPUs encounters hardware decoder failures on specific codecs (e.g. 10-bit HEVC, AV1 profile 0 vs 2, high-tier 4K at 60/120fps).
   - *Premise 2:* In `libmpv`, setting `hwdec=yes` requests pure zero-copy hardware decoding. If the hardware decoder cannot initialize or drops excessive frames, `hwdec-current` evaluates to `'no'` or excessive frame drops occur.
   - *Deduction 1:* An automated `IDecoderCapabilityService` must run an active state machine: probing media metadata -> attempting `HW` (`yes`) -> evaluating runtime health (`hwdec-current`, frame drops) -> automatically falling back to `HW+` (`auto-copy`) -> falling back to `SW` (`no`) if stutter persists, all while preserving the playback position.
   - *Deduction 2:* Redundant Flutter raster filtering (applying `ImageFilter`, `BackdropFilter`, or widget transforms) forces the GPU compositor to read back video textures, destroying zero-copy throughput. Thus, transforms and adjustments must be strictly passed to `libmpv` (`contrast`, `brightness`, `saturation`, `gamma`, `hue`, `vf="hflip"`, `vf="vflip"`).

2. **Cinematic Gesture Engine (Phase 3):**
   - *Premise 1:* A single `GestureDetector` mixing `onTap`, `onDoubleTapDown`, and `onScaleUpdate` creates gesture ambiguity in Flutter's gesture arena.
   - *Premise 2:* Users swipe diagonally or rest fingers near screen bezels; without a directional dead-zone threshold (12px) and aspect-ratio locked panning, gestures false-trigger.
   - *Deduction 1:* A dedicated `GestureArbitrator` must maintain an explicit state machine: `Idle` -> `Down` -> `Evaluating` (dead-zone filter) -> commit to either `HorizontalScrub`, `BrightnessSlider` (left 35%), `VolumeSlider` (right 35%), or `PinchZoom`.
   - *Deduction 2:* To avoid HUD clashing, while any drag/scrub is active, the controls timer must be inhibited. On release, the HUD displays a lingering feedback card (800ms) before fading.
   - *Deduction 3:* Panning during zoom must strictly clamp translation offsets: `|Tx| <= (Scale - 1) * Width / 2` and `|Ty| <= (Scale - 1) * Height / 2` to prevent black viewport gaps.

3. **Native Picture-in-Picture (Phase 6):**
   - *Premise 1:* Android 12+ (API 31+) mandates `PictureInPictureParams.Builder.setAutoEnterEnabled(true)` for seamless swipe-to-home transitions without jarring app pauses.
   - *Premise 2:* The PiP window must present ONLY the video surface. If Flutter HUD controls, overlays, or bottom sheets remain visible, the mini-window becomes unusable.
   - *Deduction 1:* On Android, a platform channel must register `AutoEnterPiP` whenever `isPlaying == true`, configure `setAspectRatio(Rational(videoWidth, videoHeight))` (clamped to [1:2.39, 2.39:1]), and declare `RemoteAction` controls (Play/Pause, Seek +/- 10s).
   - *Deduction 2:* On Desktop, overlay mode must set `HWND_TOPMOST`, remove standard window chrome, resize to a compact aspect-ratio locked frame, and restore window coordinates upon exit.
   - *Deduction 3:* When PiP enters (`onPictureInPictureModeChanged(true)`), Flutter must dismiss all open sheets and hide controls instantly (`controlsVisible = false`).

4. **Tokenized Wireless Casting (Phase 11):**
   - *Premise 1:* E-Player is 100% offline. Remote cast receivers (Chromecast, DLNA TV, AirPlay) cannot access local device filesystem paths (`/data/user/...` or `D:\...`).
   - *Premise 2:* Exposing an unauthenticated, broad HTTP server on the LAN creates severe security risks (directory traversal, data leakage).
   - *Deduction 1:* E-Player must run an ephemeral `LocalStreamingDaemon` listening on the local network interface only.
   - *Deduction 2:* Media URLs must be tokenized: `/cast/{session_token}/{media_id}/stream`, where `session_token` is a 32-byte cryptographically secure random token valid only for that single session.
   - *Deduction 3:* The server must support HTTP 206 Partial Content (`Accept-Ranges: bytes`) to allow remote seek, serve on-the-fly converted WebVTT subtitles, and shut down automatically upon session termination.

---

## 3. Caveats

1. **Hardware-Specific Decoder Blocks:**
   - Older Android hardware (pre-2020) and legacy GPUs may lack hardware AV1 or 10-bit HEVC decoding blocks. In these environments, the fallback pipeline will legitimately settle on `SW` (software decode), which may cause CPU thermal throttling on 4K content.
2. **Platform Channel Isolation in Unit Tests:**
   - Android `PictureInPictureParams` and native Win32 window APIs require platform-specific binaries and cannot run inside generic headless `flutter test` without mocking or host integration tests. Interface contracts must decouple platform invocation via an abstract bridge (`IPictureInPictureBridge`).
3. **LAN Socket Discovery Permissions:**
   - On Android 13+ and iOS 14+, local network discovery (mDNS / SSDP) requires `NEARBY_WIFI_DEVICES` or `NSLocalNetworkUsageDescription` permissions. In strict offline airplane mode with Wi-Fi disabled, casting discovery must report `NetworkUnavailable` without crashing.

---

## 4. Conclusion & Complete Subsystem Specifications

### 4.1 Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Decoder | Decoder Mode Selector | Manual selection between Auto, HW, HW+, and SW | `mode: 'Auto' \| 'HW' \| 'HW+' \| 'SW'` | `hwdec` set on libmpv platform | Logs error to debugPrint; fails silently | Codebase: `player_screen.dart:388` |
| 2 | Decoder | Dynamic Fallback Pipeline | Automated degradation from HW -> HW+ -> SW upon decode error or frame drop | Codec, bit depth, error events, drop counts | Reconfigured `hwdec`, updated diagnostic telemetry | Emits `FallbackEvent`; surfaces user toast if SW fails | Spec: `ARCHITECTURE_SPEC_V3:42` |
| 3 | Decoder | Zero-Stutter Native Effects | Offloading contrast, brightness, gamma, hue, and flip to libmpv | Slider values (-100..100), rotation angle | Native mpv properties & `vf` filter string | Master bypass disables all filters | Codebase: `video_effects_service.dart:24` |
| 4 | Decoder | Telemetry HUD | Overlay displaying runtime decoder, fps, dropped frames, bitrate | mpv property streams | Formatted diagnostics UI | Hides if property unavailable | Spec: `ARCHITECTURE_SPEC_V3:110` |
| 5 | Gestures | Left Vertical Brightness Slider | Vertical drag on left 35% of viewport adjusts app brightness | `dy: double` delta | Window brightness `0.0..1.0`, HUD slider | Clamped to bounds `[0.0, 1.0]` | Codebase: `player_screen.dart:320` |
| 6 | Gestures | Right Vertical Volume Slider | Vertical drag on right 35% of viewport adjusts media volume | `dy: double` delta | Volume `0..100%`, HUD slider | Clamped to bounds `[0.0, 100.0]` | Codebase: `player_screen.dart:314` |
| 7 | Gestures | Horizontal Precision Scrub | Center horizontal drag scrubs media timeline with delta badge | `dx: double` delta | Target seek `Duration`, scrub HUD overlay | Clamped to `[0, duration]`; invalidates AI queue | Codebase: `player_screen.dart:323` |
| 8 | Gestures | Double-Tap Wing Jump | Double tap left 33% (-10s) or right 33% (+10s) with ripple | `TapDownDetails` | Player seek, animated ripple HUD | Clamped to timeline bounds | Codebase: `player_screen.dart:232` |
| 9 | Gestures | Pinch-to-Zoom & Panning Bounds | Two-finger pinch scales 1.0x-4.0x; pan clamped to viewport bounds | Scale factor, focal delta | Viewport scale & translation offset | Clamped bounds; double-tap resets to 1.0x | Codebase: `player_screen.dart:285` |
| 10 | Gestures | Gesture Dead-Zone Arbitration | Prevents diagonal swipe crosstalk between seek, volume, brightness | Raw pointer movement vector | Dispatched discrete gesture event | Ignored if within dead-zone (12px) | Spec: `GAP_ANALYSIS_V3:71` |
| 11 | Gestures | HUD Auto-Dismiss Coordination | Holds HUD visible during interaction; auto-dismisses after 2800ms | Interaction events, timer ticks | `controlsVisible: bool` | Paused during active swipe/scrub | Codebase: `player_screen.dart:88` |
| 12 | PiP | Android AutoEnterPiP | Automatically transitions full-screen video to system PiP on Home | System Home swipe / minimize | Native PiP window | Ignored if `isPlaying == false` | Spec: `PRD_V2:295` & Android API 31 |
| 13 | PiP | Aspect Ratio Preservation in PiP | Sets PiP window aspect ratio matching video native aspect ratio | `videoWidth`, `videoHeight` | `PictureInPictureParams.setAspectRatio` | Clamped to `[1/2.39, 2.39]` | Spec: `ORIGINAL_REQUEST.md:25` |
| 14 | PiP | PiP Remote Media Controls | System notification / PiP actions for Play, Pause, Seek +/-10s | `RemoteAction` intents | MethodChannel event -> `_player` sync | Dropped if player disposed | Spec: `PRD_V2:284` |
| 15 | PiP | Desktop Overlay Window Mode | Floating borderless always-on-top window on Windows/macOS | User toggle / minimize | `SetWindowPos(HWND_TOPMOST)` overlay | Restores previous geometry on exit | Spec: `ORIGINAL_REQUEST.md:25` |
| 16 | PiP | HUD Auto-Dismiss on PiP Enter | Immediately clears Flutter UI sheets, controls, overlays in PiP | `onPictureInPictureModeChanged` | Clean video-only surface | Re-evaluates controls on exit | Spec: `ORIGINAL_REQUEST.md:25` |
| 17 | Casting | Multi-Protocol Sink Discovery | Discovers Chromecast, DLNA, Miracast, AirPlay renderers on LAN | mDNS / SSDP broadcast packets | Discovered `CastDevice` list | Handles network timeout / no devices | Codebase: `cast_service.dart:7` |
| 18 | Casting | Transcode Profile Negotiation | Resolves direct passthrough, audio remux, or video transcode | Target protocol, source video codec | `CastTranscodeProfile` selection | Fallback to `videoTranscode` if codec unhandled | Codebase: `cast_service.dart:291` |
| 19 | Casting | Tokenized Local Streaming Server | Ephemeral LAN HTTP server serving local media to receiver | Local file path, session request | Tokenized URL `http://ip:port/cast/...` | Returns 403 on invalid token; 404 on missing file | Spec: `PRD_V2:316` |
| 20 | Casting | HTTP Range Request Support | Enables seeking on remote TV receiver via `Range: bytes=X-Y` | HTTP `Range` request header | HTTP 206 Partial Content + byte stream | Returns 416 Range Not Satisfiable on overflow | Spec: `PRD_V2:323` |
| 21 | Casting | Tokenized Subtitle Sidecar | Converted WebVTT subtitle stream delivered to remote sink | Local SRT/ASS subtitle track | Tokenized WebVTT URL & Cast MediaTrack | Empty track if subtitle conversion fails | Spec: `ORIGINAL_REQUEST.md:26` |
| 22 | Casting | Bi-Directional State Sync | Synchronizes Play/Pause, Seek, Volume between phone and TV | Player streams, receiver events | Mirrored state on phone & TV | Reconnects or disconnects on ping timeout | Codebase: `cast_service.dart:208` |
| 23 | Casting | Strict Offline Invariant | Zero WAN/cloud communication during local casting | Local LAN discovery & HTTP only | Pure local packet transmission | Hard drop if external URL requested | Spec: `ORIGINAL_REQUEST.md:15` |

---

### 4.2 Edge Cases

| # | Feature | Input | Observed / Specified Behavior |
|---|---------|-------|-------------------------------|
| 1 | Decoder Fallback | Corrupted 4K 10-bit HEVC stream triggers `MPV_ERROR` in HW mode | Fallback pipeline catches error, logs diagnostic reason, switches to `HW+` (`auto-copy`). If error repeats within 500ms, switches to `SW` (`no`) and restores timestamp. |
| 2 | Decoder Stutter | 4K 60fps AV1 stream causes 15 dropped frames in 1.8 seconds on legacy GPU | Drop counter (`vo-drop-frame-count`) threshold exceeded (>10 in 2s); triggers automated downgrade to `HW+` / `SW` without user intervention. |
| 3 | Decoder Switching | User switches decoder mode manually while paused at 01:24:30 | Position is captured, player re-applies `hwdec`, re-opens media if necessary, and seeks back to 01:24:30 in paused state without auto-playing. |
| 4 | Gesture Arbitration | User initiates diagonal swipe starting at (X: 100, Y: 200) with dx=14px, dy=16px | Neither axis exceeds the 1.5x dominant ratio; gesture remains in `Arbitrating`. Once dy reaches 30px with dx=16px, locks strictly into `BrightnessDragging`. |
| 5 | Gesture Zoom Bounds | User zooms to 3.0x and rapidly drags video toward top-right corner | Translation offset is clamped at `(Scale - 1.0) * Width / 2` and `(Scale - 1.0) * Height / 2`. Video edge snaps to viewport edge; zero black void is exposed. |
| 6 | Gesture Double-Tap | User rapidly taps 3 times in right wing within 300ms | First 2 taps trigger +10s jump with ripple animation; 3rd tap starts a new tap window without triggering a false play/pause toggle. |
| 7 | PiP AutoEnter | User swipes up to Home while video is paused | `autoEnterEnabled` is explicitly `false` when paused; activity minimizes normally without opening a frozen PiP window. |
| 8 | PiP Aspect Ratio | User plays ultra-wide 21:9 (2.39:1) or vertical 9:16 (0.562:1) video in PiP | Aspect ratio is calculated as `width / height` and clamped to `[1/2.39, 2.39/1]` before passing to `PictureInPictureParams.Builder.setAspectRatio()`. |
| 9 | PiP Lifecycle Kill | User taps "X" close button on Android PiP window | Activity triggers `onDestroy`; player instantly pauses, watch progress is written to SQLite database, audio focus is abandoned, and native engine shuts down. |
| 10 | Cast Token Expiry | External client requests `http://192.168.1.100:8899/cast/fake_token/stream` | Server validates token against active session; token mismatch returns HTTP 403 Forbidden with zero file metadata exposed. |
| 11 | Cast Subtitle Range | Receiver requests WebVTT subtitle file with `Accept-Encoding: gzip` | Server streams UTF-8 WebVTT file with `Content-Type: text/vtt; charset=utf-8` and disables chunked compression for renderer compatibility. |
| 12 | Cast Network Loss | Wi-Fi disconnects mid-cast while phone is in private listening mode | Heartbeat timer fails (ping timeout > 10s); CastService dispatches `disconnect()`, halts local HTTP daemon, and restores local device audio/video playback. |

---

### 4.3 Domain Invariants

```
================================================================================
DOMAIN INVARIANT SPECIFICATION: PHASES 1, 3, 6, 11
================================================================================

[INV-HW-001] (SOURCE_TYPE = EXPLICIT)
Every decoder mode change (manual or fallback) must return and record:
`requestedMode`, `actualMode`, `backend`, and `fallbackReason`.
Reference: Documents/E_PLAYER_ARCHITECTURE_HARDENING_SPEC_V3.md:45

[INV-HW-002] (SOURCE_TYPE = EXPLICIT)
Video color grading (contrast, brightness, saturation, gamma, hue) and geometric
transforms (rotation, flips) MUST remain hardware-accelerated inside libmpv
without redundant Flutter raster filtering.
Reference: ORIGINAL_REQUEST.md:51

[INV-HW-003] (SOURCE_TYPE = INFERRED)
In `HW` mode, libmpv must operate with zero-copy direct texture rendering. If
`hwdec-current` returns 'no' when `hwdec=yes`, an instant fallback trigger is
generated.

[INV-HW-004] (SOURCE_TYPE = INFERRED)
A decoder transition must never reset playback timeline position. The current
playback position (`Duration`) must be captured and restored across decoder
restarts with error tolerance <= 250ms.

[INV-HW-005] (SOURCE_TYPE = EXPLICIT)
"HW+" is defined as hybrid hardware decoding with software copy-back (`auto-copy`)
enabling CPU-side filter/subtitle pipelines while preserving HW decode energy
savings. It must not be presented as a generic OS decoder.
Reference: Documents/E_PLAYER_PRD_V2_FROM_XPLAYER_RESEARCH.md:122

[INV-HW-006] (SOURCE_TYPE = INFERRED)
Zero-Stutter Performance Threshold: If video output drops > 10 frames within
any sliding 2000ms window, the dynamic fallback pipeline must trigger an
automatic downgrade to the next viable tier (HW -> HW+ -> SW).

--------------------------------------------------------------------------------

[INV-GEST-001] (SOURCE_TYPE = EXPLICIT)
Gesture controls must be fully configurable and toggleable, allowing users
to enable/disable gestures and configure seek interval and sensitivity.
Reference: Documents/E_PLAYER_PRD_V2_FROM_XPLAYER_RESEARCH.md:155

[INV-GEST-002] (SOURCE_TYPE = EXPLICIT)
Spatial Gesture Mapping:
- Left Vertical Zone (0.0 <= X <= 0.35 * Width): Brightness adjustment.
- Right Vertical Zone (0.65 * Width <= X <= 1.0 * Width): Volume adjustment.
- Center Zone (0.35 * Width < X < 0.65 * Width): Horizontal scrub seek.
- Left Wing Double Tap (X < 0.33 * Width): Backward jump (default -10s).
- Right Wing Double Tap (X > 0.66 * Width): Forward jump (default +10s).
- Center Double Tap: Play / Pause toggle.
- Two-Finger Pinch: Zoom (1.0x - 4.0x) with focal-point centered scaling.
- Two-Finger Vertical Drag: Playback speed (0.25x - 8.0x).
Reference: Documents/E_PLAYER_PRD_V2_FROM_XPLAYER_RESEARCH.md:145-154

[INV-GEST-003] (SOURCE_TYPE = INFERRED)
Directional Dead-Zone Invariant: A swipe gesture must travel >= 12 physical
pixels and satisfy `|primaryAxisDelta| >= 1.5 * |secondaryAxisDelta|` before
committing to a gesture state. Diagonal swipes failing this rule are ignored.

[INV-GEST-004] (SOURCE_TYPE = INFERRED)
Panning Clamping Invariant: When zoom scale S > 1.0, translation offset (Tx, Ty)
is strictly bounded by `|Tx| <= (S - 1.0) * ScreenWidth / 2` and
`|Ty| <= (S - 1.0) * ScreenHeight / 2`. No black border or void may appear.

[INV-GEST-005] (SOURCE_TYPE = INFERRED)
HUD Arbitration Invariant: During any active swipe, scrub, or pinch gesture,
the controls auto-dismiss timer must remain paused. Upon gesture end, the timer
resets to 2800ms, and gesture feedback lingers for 800ms before fading.

[INV-GEST-006] (SOURCE_TYPE = INFERRED)
Seek Queue Invalidation Invariant: Any seek gesture (scrub commit or double-tap
jump) must immediately invoke `_aiEngine.invalidateQueue()` to clear stale
asynchronous processing frames.

--------------------------------------------------------------------------------

[INV-PIP-001] (SOURCE_TYPE = EXPLICIT)
Android Picture-in-Picture must use the native system PiP API
(`Activity.enterPictureInPictureMode`). It must NOT require or substitute
`SYSTEM_ALERT_WINDOW` overlay permissions.
Reference: Documents/E_PLAYER_PRD_V2_FROM_XPLAYER_RESEARCH.md:295

[INV-PIP-002] (SOURCE_TYPE = EXPLICIT)
PiP Aspect Ratio Invariant: The PiP window aspect ratio must preserve the video
stream's native aspect ratio, clamped strictly within Android's supported
rational bounds `[1 / 2.39, 2.39 / 1]`.
Reference: ORIGINAL_REQUEST.md:25; Android CDD API 26+

[INV-PIP-003] (SOURCE_TYPE = EXPLICIT)
HUD Auto-Dismiss Invariant: Upon entering PiP mode (`isInPictureInPictureMode = true`),
all Flutter UI controls, drawer menus, modal bottom sheets, and gesture overlays
MUST be dismissed and hidden immediately. Only the clean video surface renders.
Reference: ORIGINAL_REQUEST.md:25

[INV-PIP-004] (SOURCE_TYPE = INFERRED)
AutoEnterPiP Invariant: `setAutoEnterEnabled(true)` must be enabled IF AND ONLY IF
media playback is active (`isPlaying == true`). If paused, stopped, or error,
auto-enter PiP must be disarmed (`setAutoEnterEnabled(false)`).

[INV-PIP-005] (SOURCE_TYPE = INFERRED)
Desktop Overlay Invariant: Desktop overlay window must set `HWND_TOPMOST`, remove
standard window frames, resize to a compact aspect-ratio locked frame (e.g. 480x270),
and restore previous window size/position on exit.

[INV-PIP-006] (SOURCE_TYPE = INFERRED)
Lifecycle Sync Invariant: Closing or terminating the PiP window must immediately
pause the player, commit current watch progress to the SQLite database, and release
native audio focus.

--------------------------------------------------------------------------------

[INV-CAST-001] (SOURCE_TYPE = EXPLICIT)
Strict Offline Invariant: Wireless casting discovery, negotiation, and media
streaming must operate 100% within the local area network. Zero external cloud
APIs, remote licensing handshakes, or telemetry sinks are permitted.
Reference: ORIGINAL_REQUEST.md:15

[INV-CAST-002] (SOURCE_TYPE = EXPLICIT)
Tokenized Local Server Invariant: Local files cast to network receivers must be
served via an internal HTTP server bound strictly to the LAN interface, using
a cryptographically secure per-session token.
Reference: Documents/E_PLAYER_PRD_V2_FROM_XPLAYER_RESEARCH.md:316-321

[INV-CAST-003] (SOURCE_TYPE = EXPLICIT)
No Directory Listing: The local cast HTTP server must prohibit directory
browsing, enforce canonical path validation, and reject directory traversal (`..`).
Reference: Documents/E_PLAYER_ARCHITECTURE_HARDENING_SPEC_V3.md:83

[INV-CAST-004] (SOURCE_TYPE = INFERRED)
HTTP Range Request Invariant: The local cast daemon must support HTTP 206 Partial
Content with `Accept-Ranges: bytes` to enable remote seek operations.

[INV-CAST-005] (SOURCE_TYPE = INFERRED)
Subtitle Streaming Invariant: Subtitle tracks selected during casting must be
transcoded on-the-fly to WebVTT and served via a tokenized sub-endpoint
`/cast/{token}/subtitles/{id}.vtt`.

[INV-CAST-006] (SOURCE_TYPE = INFERRED)
Automatic Daemon Teardown Invariant: The local HTTP streaming server and telemetry
timers must immediately close their server sockets when the casting session
disconnects or when the player widget is disposed.
================================================================================
```

---

### 4.4 State Machines

#### 4.4.1 Decoder Fallback Pipeline State Machine
```
[Uninitialized]
       |
  (Open Media)
       v
   [Probing] -----------> [DecideMode]
                                |
        +-----------------------+-----------------------+
        | (Mode = Auto/HW)      | (Mode = HW+)          | (Mode = SW)
        v                       v                       v
   [AttemptHW]             [AttemptHWPlus]          [AttemptSW]
        |                       |                       |
(hwdec='yes')           (hwdec='auto-copy')      (hwdec='no')
        |                       |                       |
        v                       v                       v
    [ActiveHW]             [ActiveHWPlus]           [ActiveSW]
        |                       |                       |
 (Stutter / Error)       (Stutter / Error)        (Codec Error)
        |                       |                       |
        +-------> [FallbackTriggered]                   v
                        |                           [Failed]
                        v                     (Surface Dialog)
                 (Downgrade Tier)
```

#### 4.4.2 Cinematic Gesture Engine State Machine
```
                      +-------------------+
                      |       Idle        |
                      +-------------------+
                                |
                           (PointerDown)
                                v
                      +-------------------+
                      |    Arbitrating    |
                      +-------------------+
                                |
     +--------------------------+--------------------------+
     | (dy > 12px, X < 0.35W)   | (dy > 12px, X > 0.65W)   | (dx > 12px, Center)
     v                          v                          v
[BrightnessDrag]           [VolumeDrag]             [HorizontalScrub]
     |                          |                          |
(PointerUp)                (PointerUp)                (PointerUp)
     v                          v                          v
[LingerHUD (800ms)]        [LingerHUD (800ms)]      [ExecuteSeek]
     |                          |                          |
     +--------------------------+--------------------------+
                                |
                                v
                      +-------------------+
                      |       Idle        |
                      +-------------------+
```

#### 4.4.3 Picture-in-Picture State Machine
```
[FullPlayerUI]
      |
  (Play Starts) -> [ArmAutoEnterPiP (setAutoEnterEnabled=true)]
      |
  (User Home Swipe / Explicit PiP Tap)
      v
 [EnteringPiP] -> (Dismiss Sheets, Hide Controls)
      v
  [ActivePiP] <==============================+
      |                                      |
      +---> (PiP RemoteAction: Play/Pause) ->+ (Sync Player)
      |
      +---> (User Expands PiP) -> [ExitingPiP] -> [RestoreFullPlayerUI]
      |
      +---> (User Closes PiP Window) -> [PiPTerminated]
                                              |
                                     (Pause, Persist DB, Dispose)
```

#### 4.4.4 Tokenized Wireless Casting State Machine
```
[LocalPlayback]
      |
  (Open Cast Sheet) -> [ScanningNetwork (mDNS / SSDP)]
      |
  (Select Device)
      v
[NegotiatingProfile] (Inspect Codec -> Direct / Remux / Transcode)
      v
[StartingLocalDaemon] (Bind LAN IP:port, Generate 32-Byte Token)
      v
 [ConnectingSink] (Handshake with Receiver over Cast V2 / DLNA / AirPlay)
      v
  [ActiveCasting] <==============================+
      |                                          |
      +---> (Local Scrub / Volume) ------------->+ (Send Remote Command)
      |                                          |
      +---> (Remote CEC / Event) --------------->+ (Sync Local State)
      |
  (Disconnect / Network Drop)
      v
[StoppingLocalDaemon] (Close Sockets, Invalidate Token)
      v
[RestoreLocalPlayback]
```

---

### 4.5 Method Signatures & Data Contracts

#### Interface 1: `IDecoderCapabilityService`
```dart
abstract class IDecoderCapabilityService {
  /// Returns the current active decoder telemetry
  Stream<DecoderTelemetry> get telemetryStream;

  /// Current configured decoder mode
  DecoderMode get currentMode;

  /// Evaluate media file and probe codec/pixel format capabilities
  Future<DecoderDecision> evaluateMedia(String mediaPath);

  /// Apply requested decoder mode with automated fallback monitoring
  Future<void> setDecoderMode(Player player, DecoderMode mode);

  /// Force a fallback downgrade to the next viable tier
  Future<bool> triggerFallback(Player player, String reason);

  /// Dispose listeners and monitoring timers
  void dispose();
}

enum DecoderMode { auto, hardware, hardwarePlus, software }

class DecoderTelemetry {
  final DecoderMode requestedMode;
  final DecoderMode actualMode;
  final String backend;
  final String videoCodec;
  final int width;
  final int height;
  final int droppedFrames;
  final double fps;
  final String? fallbackReason;

  const DecoderTelemetry({
    required this.requestedMode,
    required this.actualMode,
    required this.backend,
    required this.videoCodec,
    required this.width,
    required this.height,
    required this.droppedFrames,
    required this.fps,
    this.fallbackReason,
  });
}
```

#### Interface 2: `ICinematicGestureEngine`
```dart
abstract class ICinematicGestureEngine {
  /// Process raw scale/drag start from Flutter gesture arena
  GestureState onGestureStart(ScaleStartDetails details, Size viewportSize);

  /// Process continuous gesture updates with dead-zone arbitration
  GestureUpdateResult onGestureUpdate(ScaleUpdateDetails details, Size viewportSize);

  /// Finalize gesture and produce commit actions (seek, brightness, volume, linger)
  GestureCommitAction onGestureEnd(ScaleEndDetails details);

  /// Handle double-tap wing jump calculations
  DoubleTapJumpAction onDoubleTap(TapDownDetails details, Size viewportSize, Duration currentPos, Duration duration);

  /// Reset zoom and pan to 1.0x neutral viewport
  void resetZoom();
}

enum GestureState { idle, arbitrating, horizontalScrub, brightnessDrag, volumeDrag, pinchZoom, speedSwipe }

class GestureUpdateResult {
  final GestureState activeState;
  final double? brightnessValue;
  final double? volumeValue;
  final Duration? seekTarget;
  final double? zoomScale;
  final Offset? panOffset;
  final double? playbackRate;

  const GestureUpdateResult({
    required this.activeState,
    this.brightnessValue,
    this.volumeValue,
    this.seekTarget,
    this.zoomScale,
    this.panOffset,
    this.playbackRate,
  });
}
```

#### Interface 3: `IPictureInPictureService`
```dart
abstract class IPictureInPictureService {
  /// Stream of PiP mode state changes (true = in PiP, false = standard window)
  Stream<bool> get pipModeStream;

  /// Check whether PiP is supported on the current device
  Future<bool> isPipSupported();

  /// Arm or disarm automatic PiP on Home gesture (Android 12+ setAutoEnterEnabled)
  Future<void> setAutoEnterEnabled(bool enabled, {required int videoWidth, required int videoHeight});

  /// Explicitly enter Picture-in-Picture mode
  Future<bool> enterPip({required int videoWidth, required int videoHeight});

  /// Enter Desktop overlay mode (Windows / macOS)
  Future<bool> enterDesktopOverlay({required int videoWidth, required int videoHeight});

  /// Exit Desktop overlay mode and restore normal window
  Future<bool> exitDesktopOverlay();

  /// Handle incoming remote playback action from PiP window (Play, Pause, Seek)
  void handleRemoteAction(String action, Player player);

  /// Clean up PiP resources upon player disposal
  void dispose();
}
```

#### Interface 4: `ICastService` & `ILocalStreamingDaemon`
```dart
abstract class ILocalStreamingDaemon {
  /// Start the local HTTP streaming server bound to the local LAN IP
  Future<String> startServer(String mediaFilePath, {String? subtitleFilePath});

  /// Generate or retrieve the active session token
  String get activeToken;

  /// The active streaming URL for external renderers
  String? get streamUrl;

  /// The active WebVTT subtitle URL for external renderers
  String? get subtitleUrl;

  /// Stop server and close all listening sockets
  Future<void> stopServer();
}

abstract class ICastService {
  /// Discovered cast targets
  List<CastDevice> get devices;

  /// Active casting session
  CastSession? get activeSession;

  /// Start mDNS and SSDP discovery scan
  Future<void> startScan();

  /// Stop active scan
  void stopScan();

  /// Connect to device, launch local daemon if needed, and negotiate sink
  Future<bool> connect(CastDevice device, {required String mediaPath, String? mediaTitle});

  /// Disconnect session and stop local daemon
  Future<void> disconnect();

  /// Remote timeline seek
  void seek(Duration position);

  /// Remote volume adjustment
  void setRemoteVolume(double volume);

  /// Toggle remote play / pause
  void toggleRemotePlayPause();

  /// Route audio: 'tv' (standard) or 'device' (private listening mode)
  void setAudioRoute(String route);
}
```

---

## 5. Verification Method

To independently verify all observations, specifications, and test baselines:

1. **Verify Baseline Test Integrity:**
   ```powershell
   cd d:\E-player\app
   flutter test
   ```
   *Expected Result:* 67 passing tests, 0 failures, 0 skipped.

2. **Verify Static Code Analysis:**
   ```powershell
   cd d:\E-player\app
   flutter analyze
   ```
   *Expected Result:* 0 errors, 0 warnings.

3. **Verify PiP Manifest Configuration:**
   Inspect `d:\E-player\app\android\app\src\main\AndroidManifest.xml` (Line 21) to confirm `android:supportsPictureInPicture="true"`.

4. **Verify Hardware Offloading Implementation:**
   Inspect `d:\E-player\app\lib\features\video_effects\domain\video_effects_service.dart` (Lines 48–70) to confirm native property application (`contrast`, `brightness`, `saturation`, `gamma`, `hue`, `vf`) and zero-latency hardware path.

5. **Invalidation Conditions:**
   - If `flutter test` reports failing or skipped tests.
   - If any change writes outside `d:\E-player`.
   - If local compilation commands (`flutter build apk` or `flutter build windows`) are executed on the `D:` drive.
   - If external cloud URLs or telemetry endpoints are introduced into casting or decoding logic.
