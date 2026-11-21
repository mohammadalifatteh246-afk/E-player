Use the 4-Pillar REA Specialists: FORGE, AURA, KRONOS, CYPHER to implement Phase 2: Core UX & Playback Enhancements for the E-Player Flutter application.

Working directory: d:\E-player\app
Integrity mode: development

Reference: `d:\E-player\docs\vlc_gap_analysis.md` (Section 5.3 "Phase 2: Core UX & Playback Enhancements")

## Requirements

### R1. Volume Over-Amplification to 300%
- Configure libmpv `volume-max` to 300.0.
- In `CinematicGestureEngine`, extend mobile right-edge vertical swipe gesture to scale smoothly across 0% to 300% volume.
- In `DesktopKeyboardHandler`, allow `Arrow Up / Down` to adjust volume across 0% to 300% in 5% increments.
- Implement 3-color safety indicator on HUD and gesture OSD:
  - 0% – 100%: Green (standard unity gain)
  - 101% – 200%: Amber (software pre-amp boost)
  - 201% – 300%: Soft Red (high over-amplification warning)

### R2. Frame-by-Frame Stepping
- Advance playback by exactly 1 video frame per keypress (`e` key) or HUD action button tap using libmpv `frame-step`.
- Automatically pause playback upon first activation if currently playing.

### R3. A-B Repeat Looping (Scene Looper)
- Implement 4-state loop controller: State 0 (Off) -> State 1 (Mark Point A) -> State 2 (Mark Point B & start looping) -> State 3 (Clear & return to normal).
- Implement real-time position listener that seeks back to Point A when Point B is reached.

### R4. Aspect Ratio Crop Cycling
- Cycle through non-distorted crop aspect ratios (`16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `Reset`) using `c` key via mpv crop filters.

### R5. Network & Disk Buffer Caching Settings
- Expose Network Caching buffer slider (500ms to 10,000ms, default 1,000ms) and Demuxer Cache size selector (16MB to 128MB) in settings/player mapped to mpv properties `cache-secs` and `demuxer-max-bytes`.

### R6. Quality and Verification Standards
- Zero placeholders and zero TODOs in the implementation.
- Clean static analysis (`flutter analyze` / `dart analyze`).
- Comprehensive automated test suite in `app/test` verifying all Phase 2 capabilities.

## Acceptance Criteria

### Volume Amplification
- [ ] libmpv volume-max is configured to 300.0.
- [ ] Mobile right-edge vertical swipe gesture scales volume smoothly between 0% and 300%.
- [ ] Desktop Arrow Up / Down shortcuts adjust volume across 0% to 300% in 5% increments.
- [ ] Volume HUD and gesture OSD display Green for 0%–100%, Amber for 101%–200%, and Soft Red for 201%–300%.

### Frame-by-Frame Stepping
- [ ] Pressing `e` key advances video playback by 1 frame via libmpv `frame-step`.
- [ ] Tapping HUD action button advances video playback by 1 frame via libmpv `frame-step`.
- [ ] Playback pauses automatically upon first frame-step activation if currently playing.

### A-B Repeat Looping
- [ ] 4-state loop controller transitions through State 0 (Off) -> State 1 (Mark Point A) -> State 2 (Mark Point B & start looping) -> State 3 (Clear & return to normal).
- [ ] Playback automatically seeks back to Point A upon reaching Point B during looping.

### Aspect Ratio Crop Cycling
- [ ] Pressing `c` key cycles sequentially through aspect ratios 16:9, 16:10, 4:3, 1.85:1, 2.35:1, and Reset without distortion using mpv crop filters.

### Buffer Caching Settings
- [ ] Settings UI provides Network Caching buffer slider (500ms to 10,000ms, default 1,000ms) mapped to `cache-secs`.
- [ ] Settings UI provides Demuxer Cache size selector (16MB to 128MB) mapped to `demuxer-max-bytes`.

### Code Quality & Static Analysis
- [ ] Zero placeholders or TODO comments remain in the codebase.
- [ ] `flutter analyze` passes with zero errors and zero warnings.
- [ ] Automated tests in `app/test` execute and pass, verifying each Phase 2 capability.
