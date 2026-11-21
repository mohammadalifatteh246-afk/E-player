## 2026-11-04T12:09:44Z

Use the team: FORGE, AURA, KRONOS, CYPHER. Deliver a production update to the E-Player Flutter application implementing empty group creation with an Add button, long-press selection with Select All and delete/move actions across Home and Library, a scrollable 5-item History, and video-only filtering for the Media Library as shown in the UI reference images.

Working directory: d:\E-player\app
Integrity mode: development

## Reference Material
- UI Reference Image 1 (Home Screen - Groups & Bento Grid): C:/Users/Admin/.gemini/antigravity/brain/02329fad-d9b2-497b-9221-ee4d8cf756ee/.user_uploaded/media_1793791961445_d3e0263c.jpg
- UI Reference Image 2 (Home Screen - History & Category Pills): C:/Users/Admin/.gemini/antigravity/brain/02329fad-d9b2-497b-9221-ee4d8cf756ee/.user_uploaded/media_1793791964373_fbec4386.jpg

## Requirements

### R1. Empty Group Creation with Add Button
When a new group is created, it must initialize completely empty inside. It must include an Add button enabling users to add new folders or files to that group.

### R2. Long-Press Multi-Select, Select All, Delete, and Move (Home Screen)
Implement a long-press gesture on groups, folders, and files to trigger item selection. Provide a "Select All" option that selects all selectable items in the current group or folder view. Selected items must support being deleted or moved to another group. This selection behavior must not apply to built-in / default app features.

### R3. Multi-Select and Batch Actions in Library Section
Apply the same long-press multi-selection, Select All option, deletion, and move-to-group capabilities to the Library section.

### R4. Scrollable History with 5-Item Limit
Enable scrolling in the History section so that items can be smoothly browsed. Limit the History list to display a maximum of 5 items.

### R5. Media Library Video-Only Filtering
Filter the Media Library on the Home screen so that it displays only videos and their containing folders from the Library. Remove the music, series, and anime category sections.

### R6. Workspace Scope
All modifications must be applied exclusively to the primary working copy at `d:\E-player\app`.

## Verification Resources
- Flutter static analysis: `dart analyze` in `d:\E-player\app`
- Flutter test suite: `flutter test` in `d:\E-player\app`

## Acceptance Criteria

### Group Creation
- [ ] Newly created groups initialize with zero items (completely empty inside).
- [ ] Newly created groups display an Add button that allows users to add new files or folders.

### Multi-Select & Batch Actions (Home & Library)
- [ ] Long-pressing any custom group, folder, or file enters multi-selection mode and marks the item selected.
- [ ] Tapping "Select All" selects all selectable items in the current container.
- [ ] Selected items can be deleted with changes reflected in state and UI.
- [ ] Selected items can be moved to another designated group.
- [ ] Built-in / default application features do not trigger multi-selection or allow deletion/moving.
- [ ] The Library section supports long-press selection, Select All, deletion, and moving to another group.

### History Section
- [ ] History list can be scrolled smoothly to browse entries.
- [ ] History list contains no more than 5 items at any time.

### Media Library Filtering
- [ ] Home screen Media Library displays only Library videos and video folders.
- [ ] Music, series, and anime categories/cards are completely removed from the Media Library section.

### Code Quality & Verification
- [ ] `dart analyze` passes with zero errors.
- [ ] Automated tests pass via `flutter test` verifying the group creation, selection/delete/move actions, history cap, and media library filtering.


## 2026-11-11T06:00:01Z

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
