# Dispatch: spec_miner_survey_features
Task: Extract full requirements, domain invariants, and specification details for Phase 1, Phase 3, Phase 6, Phase 11.
Working Directory: d:\E-player\.agents\teamwork\spec_miner_survey_features
Original Request Path: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
## 2026-10-22T10:44:57Z

You are the Player Requirements Spec Miner for the E-Player project.
Working Directory: d:\E-player\.agents\teamwork\spec_miner_survey_features
Original Request Path: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md

You MUST read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md first.

Your mission:
Extract complete, rigorous specifications, domain invariants, and functional contracts for:
1. Phase 1 (Hardware / HW+ Decoders):
   - Dynamic fallback pipeline across Hardware, HW+, and Software decoders via media_kit/libmpv.
   - Zero stutter on 4K/HEVC/AV1 streams, hardware acceleration invariant inside libmpv without redundant Flutter raster filtering.
   - Error detection, fallback triggers, and decoder switching lifecycle.
2. Phase 3 (Cinematic Gesture Engine):
   - Horizontal scrub with high-precision timestamp seek.
   - Vertical split brightness (left side) and volume (right side) sliders with visual HUD.
   - Double-tap jump (rewind/forward 10s or configured interval) with animation.
   - Pinch-to-zoom (scaling, aspect ratio preservation, panning bounds).
   - HUD auto-dismiss coordination and gesture arbitration (conflict resolution between scrub, tap, drag, zoom).
3. Phase 6 (Native Picture-in-Picture):
   - Android AutoEnterPiP and Desktop overlay window mode.
   - HUD auto-dismiss on PiP enter, aspect ratio preservation, playback control synchronization in PiP mode, lifecycle cleanup.
4. Phase 11 (Tokenized Wireless Casting):
   - Real-time streaming sink negotiation: Chromecast, DLNA, Miracast, AirPlay.
   - Local offline streaming server / tokenized sink handoff.
   - Subtitle muxing/transmitting and synchronized seek/volume controls.
   - Offline invariant: strictly offline local network protocols, zero external telemetry or cloud dependencies.

Document all state machines, invariant rules (SOURCE_TYPE = EXPLICIT / INFERRED), method signatures, and error boundaries.

Constraints:
- Read-only specification extraction! Do NOT modify any code.
- Write ONLY to your working directory: d:\E-player\.agents\teamwork\spec_miner_survey_features/
- Maintain progress.md with timestamps.
- Write your comprehensive findings to d:\E-player\.agents\teamwork\spec_miner_survey_features\handoff.md.
- Send a completion message via send_message to the orchestrator when finished.
