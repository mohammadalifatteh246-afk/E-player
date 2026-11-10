## 2026-11-03T09:40:04Z

Operate as an elite 4-Character Clean-Room Engineering Studio (SPP + CoVe + Reflexion + MCP) to reverse-engineer how the File Browser, Auto-rescan, and Media Library / Media Library Folders work in VLC (path: C:\Program Files (x86)\VideoLAN\VLC), gather live empirical evidence, and build a production-grade clean-room equivalent for the E-Player project adhering to the 6-stage REA operational pipeline.

Working directory: d:\E-player
Integrity mode: demo
The team must NOT: copy code from existing open-source projects for core logic

## Requirements

### R1. Forensic Evidence Extraction & Deconstruction (Stage 1)
Inspect and deconstruct how the File Browser, Auto-rescan, and Media Library / Media Library Folders work in VLC by examining both the local installation at `C:\Program Files (x86)\VideoLAN\VLC` and VLC's open-source architecture/code. Produce a structured Evidence Dossier with concrete exhibits for:
- Exhibit A — Data & State Architecture (schemas, state trees, data flow)
- Exhibit B — Execution Lifecycle & Algorithms (file discovery, directory watcher, auto-rescan triggers, library indexing)
- Exhibit C — Performance & UX mechanics
Explicitly label every exhibit as `[Verified via MCP/Source Inspection]` or `[Inferred via Behavioral/Architectural Pattern]`.

### R2. Chain-of-Verification (CoVe) Adversarial Cross-Examination (Stage 2)
Conduct a multi-turn adversarial Q&A across the 4 specialist personas (Cypher, Kronos, Aura, Forge) to interrogate at least 3 critical failure points (concurrency, state desynchronization, memory scaling, edge-case user inputs) until a watertight architecture is established.

### R3. Clean-Room Architectural Blueprint & Pre-Mortem Guardrails (Stages 3 & 4)
Compile a Clean-Room Engineering Specification translating verified mechanics into the E-Player project architecture (module structure, state machines, stack adaptation matrix). Establish 3 explicit Reflexion pre-mortem guardrails covering algorithmic/concurrency traps, UX/frame-budget traps, and stack integration traps before implementing.

### R4. Production Clean-Room Implementation in E-Player (Stage 5)
Implement a production-grade File Browser, Auto-rescan (directory watcher), and Media Library feature directly integrated into the E-Player project codebase (`d:\E-player`). Deliverables must include the presentation layer (File Browser UI), domain services (directory watcher, auto-rescan coordination), and data persistence (media library indexing with SQLite), with full error handling, lifecycle teardown, and zero placeholder or `// TODO` comments.

### R5. Test Data Lifecycle & Automated Verification (Stage 6)
Verify the implementation using the project's existing test harness (`EPlayerTestHarness`, `app/test/`) across unit, integration, and edge-case scenarios. All demo or test data created during testing must be strictly temporary and completely removed after testing. Conclude with the Persistent REA Ledger detailing deconstructed mechanics, implemented files/interfaces, and a Reflexion self-correction rule.

## Acceptance Criteria

### Forensic Evidence & Clean-Room Architecture
- [ ] Evidence Dossier details VLC's file browser, directory watcher / auto-rescan mechanisms, and media library storage with concrete exhibits labeled as verified or inferred.
- [ ] CoVe adversarial Q&A resolves at least 3 critical failure points with evidence-backed architectural adaptations for E-Player.
- [ ] Clean-room engineering specification provides complete file tree, state machine, and stack adaptation matrix without copying open-source core logic.

### Feature Deliverables & Code Quality
- [ ] File Browser UI allows interactive file system navigation, directory selection, and media file inspection in E-Player.
- [ ] Auto-rescan service monitors configured media library folders, reacts to file additions, modifications, and deletions, and updates library state.
- [ ] Media Library state and indexed metadata persist across restarts in local SQLite storage.
- [ ] Codebase passes static analysis (`dart analyze`) with zero errors and zero warnings.
- [ ] Implementation contains zero `// TODO` comments or dummy placeholders.

### Verification & Test Data Invariant
- [ ] Automated tests in `app/test/` pass and verify file browsing, auto-rescan detection, and SQLite media library indexing using `EPlayerTestHarness`.
- [ ] No temporary demo files, test folders, or test media artifacts remain on disk or in the repository after testing completes.
- [ ] Persistent REA Ledger records verified mechanics, implemented files, and the Reflexion self-correction rule.

---
### Agent Identity & Working Instructions
- Your role: teamwork_orchestrator
- Working directory: .agents/teamwork/orchestrator_1/
- Original Request path: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
- Project root: d:\E-player
- Maintain progress.md and BRIEFING.md in your working directory.
- Dispatch specialists (e.g. explorer, researcher, implementer, reviewer) to systematically execute the 6 stages. Report completion when done.


## 2026-11-10T08:06:20Z

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

---
### Coordination Instructions:
Working directory: d:\E-player\app
Teamwork state folder: .agents/teamwork/orchestrator_1/
Original request file: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
Parent Sentinel Conversation ID: me
