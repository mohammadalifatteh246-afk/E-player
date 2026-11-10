# Progress — Explorer M2 R1 3 (Spec Miner 3)

Last visited: 2026-11-10T08:56:00Z

## Status
- [x] Initialized DISPATCH.md and BRIEFING.md
- [x] Read authoritative files:
  - [x] ORIGINAL_REQUEST.md
  - [x] PROJECT.md
  - [x] sub_orch_m2/SCOPE.md
  - [x] explorer_audio_studio/handoff.md
  - [x] spec_miner_phase1/handoff.md
  - [x] lib/features/player/ui/audio_studio_sheet.dart (AudioConfig, AudioStudioSheet)
- [x] Cross-verify 11 VLC presets (frequencies, gains, preamp) against VLC binary and source
  - Discovered and corrected two discrepancies in `explorer_audio_studio/handoff.md`:
    1. Full Bass: Band 0 is `-8.0 dB` (NOT `+9.6 dB`)
    2. Live: Bands 5-9 are `[5.6, 4.0, 2.4, 2.4, 2.4]` (NOT `[3.2, 0.0, -2.4, -4.8, -4.8]`)
- [x] Verify 10 frequency band centers in AudioConfig.freqs: `[60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]`
- [x] Verify preamp values and preset switching interaction:
  - Selecting preset loads default preamp (`presetPreamps[name]`)
  - User can subsequently adjust preamp freely across `[-20.0, +20.0]` dB
  - Moving band slider shifts preset to 'Custom' while maintaining preamp
- [x] Verify mpv af filter specs:
  - Syntax: `volume=volume=${preamp >= 0 ? '+' : ''}${preamp.toStringAsFixed(1)}dB:precision=fixed`
  - Filter ordering: volume filter (preamp) MUST precede equalizer bands and DSP
  - Tolerance threshold: `if (preamp.abs() > 0.05)` (omitted at 0.0dB)
- [x] Tabulate presets in Dart map format ready for copy-paste
- [x] Complete handoff.md report and notify orchestrator
