# Scope: VLC Media Player Reverse-Engineering & E-Player Gap Analysis

## Architecture
- Target Binary: VLC Media Player installed at `C:\Program Files (x86)\VideoLAN\VLC`
- Current Codebase: E-Player Flutter Project at `d:\E-player\app`
- Deliverable: Comprehensive Gap Analysis Matrix & Prioritized Adoption Roadmap at `d:\E-player\docs\vlc_gap_analysis.md`

## 4 Analytical Domains
1. **CYPHER (Forensic Telemetry & Artifact Hunter)**:
   - Binary layout, modules, plugins (`plugins/` tree, .dll files), libvlc exported functions.
   - Qt interface strings and layout definitions, hotkeys/shortcuts system.
   - CLI flags, configuration parameters, and Lua extension/scripts framework.
2. **KRONOS (Systems & Edge-Case Adversary)**:
   - Playback pipeline, demuxing, video/audio decoders, hardware acceleration cascades (Direct3D, DXVA2, Media Foundation).
   - Codec support matrix (video, audio, subtitle formats).
   - Network/streaming protocols (RTSP, RTMP, HLS, HTTP/HTTPS, SMB, UPnP/DLNA, UDP/RTP multicast).
   - Caching, buffering, clock sync, subtitle synchronization, audio pitch shifting.
   - Audio & video filters (equalizer, spatializer, crop, deinterlace, rotate, postproc).
3. **AURA (Interaction Physics & UX Micro-Mechanic Analyst)**:
   - UI layout (minimal view, fullscreen HUD, compact mode, dockable panels).
   - Playlist mechanics (drag-and-drop, sorting, search, shuffle, repeat, group).
   - Media library management, metadata extraction, album art caching, history.
   - Gesture & keyboard controls, timeline scrubbing physics, seek precision, frame-stepping.
   - Track selection UX (audio tracks, subtitle tracks, aspect ratio toggling).
4. **FORGE (Clean-Room Builder & Flutter Codebase Inspector)**:
   - Complete architectural audit of `d:\E-player\app`.
   - Identification of all implemented features, media playback plugins (e.g. media_kit, video_player, just_audio, etc.), UI components, state management, storage, settings.
   - Mapping features against VLC inventory to classify as Adopted, Partially Adopted, or Missing.
   - Synthesis of comprehensive gap analysis matrix and prioritized adoption roadmap.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Multi-Domain REA Scan & Inspection | Parallel dispatch of CYPHER, KRONOS, AURA, and FORGE | none | DONE |
| M2 | Gap Analysis Synthesis | Aggregate findings into full comparative matrix (Adopted, Partially Adopted, Missing) | M1 | DONE |
| M3 | Deliverable Creation & Documentation | Author comprehensive report at `d:\E-player\docs\vlc_gap_analysis.md` | M2 | DONE |
| M4 | Review, Verification & Forensic Audit | Reviewer & Auditor sign-off ensuring accuracy, exhaustive coverage, and zero app code mutation | M3 | DONE |
