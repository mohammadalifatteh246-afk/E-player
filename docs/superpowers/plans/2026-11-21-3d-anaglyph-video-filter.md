# Phase 2 Feature 6: 3D Anaglyph Video Shader Filter (Red-Cyan Stereoscopic 3D) Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide full VLC-parity 3D Anaglyph Video Filter (`anaglyph.c` & FFmpeg `stereo3d` / `rgbashift` parity) with support for real 3D Stereoscopic video (SBS Half/Full, Top-Bottom Half/Full) as well as 2D Synthetic Depth Parallax, multiple color matrices (Dubois Red-Cyan, Color Red-Cyan, Green-Magenta Trioscopic, Amber-Blue ColorCode), disparity slider, left/right eye swapping, dedicated Cyberpunk Studio UI, and empirical tests.

---

## Architecture Breakdown

1. **Model & Enums (`anaglyph_models.dart`)**:
   - `AnaglyphSourceMode`:
     - `synthetic2D`: Monoscopic 2D video rendered with synthetic chromatic parallax separation.
     - `sideBySideHalf`: Half SBS (`sbs2l`/`sbs2r`).
     - `sideBySideFull`: Full SBS (`sbsl`/`sbsr`).
     - `topAndBottomHalf`: Half Over-Under (`ab2l`/`ab2r`).
     - `topAndBottomFull`: Full Over-Under (`abl`/`abr`).
   - `AnaglyphColorMatrix`:
     - `redCyanDubois`: Least eye strain, optimal spectral reproduction (`arrc`).
     - `redCyanColor`: Vibrant full color (`arcc`).
     - `redCyanHalfColor`: Classic half color (`arch`).
     - `greenMagenta`: Trioscopic 3D (`agmd`).
     - `amberBlue`: ColorCode 3D (`aybd`).

2. **Configuration & Filter Generation (`video_effects_config.dart`)**:
   - Fields: `anaglyphEnabled`, `anaglyphSource`, `anaglyphMatrix`, `anaglyphParallax`, `anaglyphSwapEyes`.
   - Filter generation in `buildMpvVfString()`:
     - If stereoscopic: `stereo3d=in=${source.getMpvIn(swapEyes)}:out=${matrix.mpvOut}`
     - If synthetic 2D: `rgbashift` with horizontal channel disparity according to selected matrix.
   - Serialization (`toJson`, `fromJson`), `copyWith`, `resetAnaglyph()`.

3. **Dedicated 3D Studio Sheet (`anaglyph_studio_sheet.dart`)**:
   - Modern Cyberpunk modal bottom sheet with 3D glasses branding.
   - Master Enable toggle (`key: Key('anaglyph_enable_switch')`).
   - Source format selector chips (`synthetic2D`, `sideBySideHalf`, `topAndBottomHalf`).
   - Glasses color matrix selector chips (`redCyanDubois`, `redCyanColor`, `greenMagenta`, `amberBlue`).
   - Convergence/Parallax slider (-30.0 to +30.0 px).
   - Left/Right eye swap toggle (`key: Key('anaglyph_swap_eyes_switch')`).
   - Reset button.

4. **Integration into `PlayerScreen` & `VideoEffectsSheet`**:
   - In `PlayerScreen` quick actions sheet: Add "3D Anaglyph Filter" button (`hud_anaglyph_studio_button`).
   - In `VideoEffectsSheet` Colors tab: Add Anaglyph 3D toggle & studio trigger.

5. **Unit & Widget Testing**:
   - `app/test/unit/anaglyph_test.dart`: Configuration defaults, MPV filter string generation for all modes, serialization roundtrip, reset.
   - `app/test/unit/anaglyph_widget_test.dart`: `AnaglyphStudioSheet` rendering, toggle enable, source change, color matrix change, slider update, and eye swap.

---

## Tasks

### Task 1: Create Anaglyph Model & Extend VideoEffectsConfig
- [x] Create `app/lib/features/video_effects/models/anaglyph_models.dart` with `AnaglyphSourceMode` and `AnaglyphColorMatrix`.
- [x] In `app/lib/features/video_effects/models/video_effects_config.dart`:
  - Add `anaglyphEnabled`, `anaglyphSource`, `anaglyphMatrix`, `anaglyphParallax`, `anaglyphSwapEyes`.
  - Add `resetAnaglyph()`.
  - Update `buildMpvVfString()` to generate `stereo3d` or `rgbashift` filters.
  - Update constructor, `copyWith`, `toJson`, `fromJson`, `isNeutral`, `resetAll`.

### Task 2: Create Dedicated Anaglyph Studio Sheet
- [x] Create `app/lib/features/video_effects/ui/anaglyph_studio_sheet.dart`.
- [x] Implement master switch, source format chips, color matrix chips, parallax slider, and swap eyes switch.
- [x] In `app/lib/features/video_effects/ui/video_effects_sheet.dart`, add 3D Anaglyph section in the Colors tab.

### Task 3: Wire into PlayerScreen Quick Settings
- [x] In `app/lib/features/player/ui/player_screen.dart`, add "3D Anaglyph Mode" quick action tile in the HUD quick options menu.
- [x] Connect it to `AnaglyphStudioSheet.show` and `_videoEffectsService.apply`.

### Task 4: Unit & Widget Testing
- [x] Create `app/test/unit/anaglyph_test.dart` for filter string generation, serialization, and reset.
- [x] Create `app/test/unit/anaglyph_widget_test.dart` for UI interactions and state emission.
- [x] Verify with `flutter test --no-pub`.

### Task 5: Static Analysis & Git Commit
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Stage, commit, and push Phase 2 Feature 6 to `origin/main`.
