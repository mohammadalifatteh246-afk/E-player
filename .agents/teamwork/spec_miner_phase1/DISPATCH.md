# Task Assignment: Phase 1 Specification Mining (Cypher)

## Objective
Thoroughly extract and synthesize all functional specifications, mathematical models, UI/UX designs, and constraints for Phase 1 deliverables from reference documents and user requirements.

## Authoritative Inputs
- Original Request: `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- Reference Gap Analysis & Implementation Blueprints: `d:\E-player\docs\vlc_gap_analysis.md`
  - Pay special attention to Section 5.2 "Phase 1: Immediate High-Impact Quick Wins"
  - Pay special attention to Section 5.6 "Technical Feasibility & Clean-Room Flutter Implementation Blueprints"

## Scope & Investigation Tasks
1. **R1 Desktop Keyboard Shortcuts**:
   - Detailed mapping of all 13 required shortcuts (`Space`, `f`/`F11`, `m`, `b`, `v`, `a`, `h`/`g`, `k`/`j`, `+`/`-`, `]`/`[`, `=`, `Arrow Left`/`Right`, `Arrow Up`/`Down`).
   - Cross-platform differences (Windows, macOS Command vs Ctrl, Linux).
   - OSD requirements (presentation duration, styling, animation, typography, icons).
2. **R2 4-Tier Seek Physics**:
   - Modifiers: Shift (3s), Alt (10s), Ctrl (60s), Ctrl+Alt (300s).
   - Interaction between modifiers and Arrow Left / Arrow Right.
   - Boundary checks, current position clamping (0 to duration), mpv seek flags (`relative`, `exact`).
3. **R3 Audio Delay Synchronization UI Slider**:
   - Slider range: `-10.0s` to `+10.0s` (-10000ms to +10000ms) with 50ms divisions.
   - Nudge buttons: `-100ms`, `-50ms`, `Reset 0ms`, `+50ms`, `+100ms`.
   - mpv property binding: `audio-delay` in seconds or milliseconds.
4. **R4 Dedicated Audio Track Selector Modal**:
   - Location on PlayerScreen HUD top bar.
   - Glassmorphic modal styling (backdrop blur, frosted glass container, selected track checkmark).
   - APIs: `_player.stream.tracks.audio`, `_player.setAudioTrack`.
5. **R5 Equalizer Parity with Preamp Slider**:
   - List of 11 presets: `Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`.
   - Exact frequency bands in E-Player vs VLC (e.g., 10-band or 18-band; VLC standard: 60Hz, 170Hz, 310Hz, 600Hz, 1kHz, 3kHz, 6kHz, 12kHz, 14kHz, 16kHz).
   - Pre-Amplification slider: `-20dB` to `+20dB`. mpv volume gain filter specification.

## Deliverable
Write a complete, structured specification report to:
`d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md`
Send a completion message when finished.


## 2026-11-10T08:09:04Z
[Message] timestamp=2026-11-10T08:09:04Z sender=63171882-8b91-4476-8781-8908629f8b43 priority=MESSAGE_PRIORITY_HIGH content=You are the Phase 1 Specification Miner (Cypher).
Read your assignment in d:\E-player\.agents\teamwork\spec_miner_phase1\DISPATCH.md and the authoritative request in d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md.
Mine d:\E-player\docs\vlc_gap_analysis.md (Sections 5.2 and 5.6) thoroughly.
Extract the exact technical blueprints, shortcuts, seek math, audio delay slider specs, track selector specifications, and all 11 EQ presets + preamp specifications.
Write your complete report to d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md.
When finished, send a message to the orchestrator.
