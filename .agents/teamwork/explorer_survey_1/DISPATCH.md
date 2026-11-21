# Dispatch: Explorer 1 (CYPHER - mpv Engine & Properties)

You are CYPHER, the Forensic Telemetry & Binary Artifact / Core Engine Specialist.
Your mission is to explore and analyze the codebase at `d:\E-player\app` for Phase 2: Core UX & Playback Enhancements.

## Mandatory Reading
- Read `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (especially lines 85–151 for Phase 2 requirements).
- Reference: `d:\E-player\docs\vlc_gap_analysis.md` (Section 5.3 and Section 5.6).

## Scope of Investigation
1. **libmpv volume-max & volume scaling**:
   - Locate where `Player` or `PlayerConfiguration` is initialized in `d:\E-player\app`.
   - Determine how `volume-max` can be configured to 300.0 (via `PlayerConfiguration`, mpv property `volume-max`, or `(player.platform as dynamic).setProperty`).
   - Check how volume is currently clamped and read/written in `Player` and `CinematicGestureEngine` and `PlayerScreen`.
2. **libmpv frame-step command**:
   - Investigate how `media_kit` exposes mpv commands or properties for frame stepping (`frame-step`).
   - Determine the exact call syntax (e.g., `(player.platform as dynamic).command(['frame-step'])` or `setProperty` or `media_kit` API).
   - Investigate how playback state (`player.state.playing`) is checked and paused before/during frame step.
3. **Aspect ratio crop cycling with mpv filters**:
   - Examine how video filters or aspect ratios are currently handled in `d:\E-player\app` (check `lib/features/video_effects`, `player_screen.dart`, etc.).
   - Determine how mpv crop filters (`vf` or `crop` or `video-aspect-override`) work in `media_kit` to achieve non-distorted crop aspect ratios: `16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, and `Reset`.
4. **Network & Disk Buffer Caching mpv properties**:
   - Investigate `cache-secs` and `demuxer-max-bytes` in libmpv / `media_kit`.
   - Check existing settings storage in `d:\E-player\app` (e.g. `SharedPreferences`, `SettingsScreen`, `DecoderPipelineService`).
   - Determine how Network Caching buffer (500ms–10,000ms, default 1,000ms -> seconds conversion for `cache-secs`) and Demuxer Cache size (16MB–128MB -> bytes conversion for `demuxer-max-bytes`) should be persisted and applied to the player.

## Expected Output
Deliver a comprehensive, evidence-grounded report at:
`d:\E-player\.agents\teamwork\explorer_survey_1\handoff.md`
Include exact file paths, line numbers, code snippets, mpv property/command signatures, and concrete implementation recommendations.
When finished, send a message to the orchestrator.


## 2026-11-11T06:03:53Z
You are CYPHER, the Forensic Telemetry & Binary Artifact / Core Engine Specialist.
Your mission is to explore and analyze the codebase at d:\E-player\app for Phase 2: Core UX & Playback Enhancements.

Working directory: d:\E-player\app
Your state folder: d:\E-player\.agents\teamwork\explorer_survey_1

MANDATORY FIRST STEPS:
1. Read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md (especially lines 85–151 for Phase 2 requirements).
2. Read d:\E-player\.agents\teamwork\explorer_survey_1\DISPATCH.md for detailed investigation checklist.
3. Reference: d:\E-player\docs\vlc_gap_analysis.md (Section 5.3 and Section 5.6).

SCOPE OF INVESTIGATION:
1. libmpv volume-max & volume scaling:
   - Locate where Player or PlayerConfiguration is initialized in d:\E-player\app.
   - Determine how volume-max can be configured to 300.0 (via PlayerConfiguration, mpv property volume-max, or (player.platform as dynamic).setProperty).
   - Check how volume is currently clamped and read/written in Player, CinematicGestureEngine, and PlayerScreen.
2. libmpv frame-step command:
   - Investigate how media_kit exposes mpv commands or properties for frame stepping (frame-step).
   - Determine exact call syntax (e.g., (player.platform as dynamic).command(['frame-step']) or setProperty).
   - Check how playback state (player.state.playing) is paused before/during frame step.
3. Aspect ratio crop cycling with mpv filters:
   - Examine how video filters or aspect ratios are currently handled in d:\E-player\app.
   - Determine how mpv crop filters (vf or crop or video-aspect-override) work in media_kit to achieve non-distorted crop aspect ratios: 16:9, 16:10, 4:3, 1.85:1, 2.35:1, and Reset.
4. Network & Disk Buffer Caching mpv properties:
   - Investigate cache-secs and demuxer-max-bytes in libmpv / media_kit.
   - Check existing settings storage in d:\E-player\app (SharedPreferences, SettingsScreen, DecoderPipelineService).
   - Determine how Network Caching buffer (500ms–10,000ms, default 1,000ms) and Demuxer Cache size (16MB–128MB) should be persisted and applied to the player.
