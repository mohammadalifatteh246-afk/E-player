# Original User Request

## Initial Request — 2026-11-10T08:05:00Z

Implement Phase 1 deliverables (Desktop Keyboard Shortcuts, Multi-Tier Precision Jump Intervals, Audio Delay Synchronization UI Slider, Dedicated Audio Track Selector Modal, and Equalizer Parity with Preamp Slider) for production in the cross-platform E-Player Flutter desktop application (Windows, macOS, Linux). 4-Pillar REA Specialists: FORGE, AURA, KRONOS, CYPHER.

Working directory: d:\E-player\app
Integrity mode: development

Reference material: d:\E-player\docs\vlc_gap_analysis.md (Section 5.2 "Phase 1: Immediate High-Impact Quick Wins" and Section 5.6 "Technical Feasibility & Clean-Room Flutter Implementation Blueprints")

## Requirements

### R1. Desktop Keyboard Shortcuts Infrastructure
Implement universal cross-platform desktop shortcuts (Windows, macOS, Linux) in `d:\E-player\app`:
- `Space`: Play/Pause toggle
- `f` / `F11`: Fullscreen toggle
- `m`: Mute toggle
- `b`: Cycle audio tracks with on-screen display (OSD) feedback
- `v`: Cycle subtitle tracks with on-screen display (OSD) feedback
- `a`: Cycle aspect ratios
- `h` / `g`: Subtitle delay nudge (±50ms)
- `k` / `j`: Audio delay nudge (±50ms)
- `+` / `-`: Coarse playback speed adjustment
- `]` / `[`: Fine playback speed adjustment (±0.1x)
- `=`: Reset playback speed to 1.0x
- `Arrow Left` / `Arrow Right`: 10-second seek backward / forward
- `Arrow Up` / `Arrow Down`: Volume adjustment in 5% steps

### R2. Multi-Tier Precision Jump Intervals (4-Tier Seek Physics)
Implement modifier-based precision jump intervals for desktop navigation:
- `Shift + Left/Right`: 3s jump (Very Short - dialogue clarification)
- `Alt + Left/Right`: 10s jump (Short - sentence skip)
- `Ctrl + Left/Right`: 60s jump (Medium - intro/recap skip)
- `Ctrl + Alt + Left/Right`: 300s (5 min) jump (Long - scene skip)

### R3. Audio Delay Synchronization UI Slider
Add an Audio Synchronization card to `AudioStudioSheet`:
- A continuous slider covering `-10.0s` to `+10.0s` with 50ms divisions.
- Dedicated nudge buttons: `-100ms`, `-50ms`, `Reset 0ms`, `+50ms`, and `+100ms`.
- Bound directly to the mpv property `audio-delay`.

### R4. Dedicated Audio Track Selector Modal
Add an Audio Track quick selector icon/button to the `PlayerScreen` HUD top bar:
- Opens a glassmorphic bottom sheet / modal listing all detected audio streams retrieved via `_player.stream.tracks.audio`.
- Supports instant track selection and switching via `_player.setAudioTrack`.

### R5. Equalizer Parity (11 Presets + Preamp Slider)
Expand `AudioStudioSheet` EQ presets and controls to achieve parity with VLC:
- Include presets: `Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, and `Soft Rock`.
- Add a global Pre-Amplification slider (`-20dB` to `+20dB`) mapped to mpv filter volume gain.

### R6. Production Quality & Verification
- Deliver production-grade, cleanly formatted code with zero placeholders and zero TODOs.
- Ensure static analysis (`flutter analyze` / `dart analyze`) passes cleanly with zero errors and zero warnings.
- Author and maintain automated tests in `d:\E-player\app\test` verifying all Phase 1 capabilities using `flutter test`.

## Verification Resources
- Test suite location: `d:\E-player\app\test`
- Verification commands:
  - `flutter analyze`
  - `flutter test`

## Acceptance Criteria

### Desktop Shortcuts & Seek Physics
- [ ] Universal desktop shortcuts respond to key presses across desktop platforms: Space (Play/Pause), f/F11 (Fullscreen), m (Mute), b (Cycle Audio Tracks with OSD), v (Cycle Subtitle Tracks with OSD), a (Cycle Aspect Ratios), h/g (Subtitle delay ±50ms), k/j (Audio delay ±50ms), +/- (Coarse Speed), ]/[ (Fine Speed ±0.1x), = (Reset Speed 1.0x), Arrow Left/Right (10s seek), Arrow Up/Down (Volume 5%).
- [ ] 4-tier seek physics respond accurately to modifier combinations: Shift+Left/Right (3s), Alt+Left/Right (10s), Ctrl+Left/Right (60s), Ctrl+Alt+Left/Right (300s).

### Audio Studio & Track Selection UI
- [ ] AudioStudioSheet contains an Audio Synchronization card with a working -10.0s to +10.0s slider (50ms increments) and nudge buttons (-100ms, -50ms, Reset, +50ms, +100ms) controlling mpv `audio-delay`.
- [ ] PlayerScreen HUD top bar has an audio track button that opens a glassmorphic sheet displaying available audio tracks from `_player.stream.tracks.audio` and switching tracks with `_player.setAudioTrack`.
- [ ] AudioStudioSheet EQ presets list includes all 11 specified presets (`Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`).
- [ ] AudioStudioSheet includes a global Pre-Amplification slider (-20dB to +20dB) adjusting mpv filter volume gain.

### Quality & Test Execution
- [ ] Static analysis passes cleanly (`flutter analyze`) with zero errors and zero warnings in modified and added files.
- [ ] Automated tests run via `flutter test` and pass without failures, covering shortcuts, seek jumps, audio sync, track selector, and equalizer presets.

## Follow-up — 2026-11-10T08:36:26Z

Resume execution from where you stopped. Continue implementing Phase 1 milestones.
