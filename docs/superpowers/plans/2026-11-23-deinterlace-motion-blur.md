# Phase 3 Feature 12: Frame-by-Frame Motion Blur & Interlacing Deinterlacer Modes Plan (4-Pillar REA Clean-Room Studio)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full VLC-parity for Deinterlacing (`deinterlace.c`) & Frame-by-Frame Motion Blur (`motionblur.c`), supporting Yadif, Yadif (2x 60fps), BWDIF (Bob Weaver), Bob, Blend, Linear, and IVTC (Film Pulldown) with field parity dominance (Auto, TFF, BFF), plus cinematic motion blur with presets ("Subtle Anti-Judder", "Cinematic 24p Shutter", "Sports Action Smoothing", "Dreamy Trail") and custom temporal frame mixing (2 to 7 frames).

**Architecture:**
- **Pillar 1 (Domain Models & Formulas)**: `MotionBlurPreset`, `MotionBlurConfig`, `DeinterlaceFieldOrder`, and updated `DeinterlaceAlgorithm` in `app/lib/features/video_effects/models/deinterlace_models.dart`.
- **Pillar 2 (libmpv Filter Pipeline)**: Update `VideoEffectsConfig.buildMpvVfString()` to generate optimal `tmix=frames=N:weights="..."` binomial kernels and parity-aware `yadif`/`bwdif` filter strings.
- **Pillar 3 (Cyberpunk Studio UI)**: `DeinterlaceMotionStudioSheet` in `app/lib/features/video_effects/ui/deinterlace_motion_studio_sheet.dart` with 1-tap presets, custom slider, algorithm chips, and live OSD status.
- **Pillar 4 (Hermetic TDD & Verification)**: Unit tests in `deinterlace_motion_test.dart`, widget tests in `deinterlace_motion_widget_test.dart`, `flutter analyze --no-pub`, and `phase2_e2e_test.dart` regression gate.

**Tech Stack:** Flutter 3.x, Dart 3.x, `media_kit: ^1.2.6`, pure Dart FAT32 compliant.

---

### Task 1: Domain Models, Motion Blur Presets & Filter Graph Generation
**Files:**
- Modify: `app/lib/features/video_effects/models/deinterlace_models.dart`
- Modify: `app/lib/features/video_effects/models/video_effects_config.dart`
- Test: `app/test/unit/deinterlace_motion_test.dart`

**Steps:**
- [x] Define `DeinterlaceFieldOrder` (auto, tff, bff) with FFmpeg parity strings.
- [x] Define `MotionBlurPreset` (off, subtle, cinematic, sports, dreamy, custom) with target frames and binomial weights.
- [x] Add `motionBlurEnabled`, `motionBlurPreset`, `motionBlurFrames`, and `deinterlaceFieldOrder` fields to `VideoEffectsConfig`.
- [x] Update `buildMpvVfString()` to generate binomial `tmix` filter strings and inject parity into `yadif`/`bwdif`.
- [x] Write unit tests in `app/test/unit/deinterlace_motion_test.dart` testing binomial weight computation, filter graph generation for all deinterlace algorithms, field orders, and motion blur presets.
- [x] Run `flutter test --no-pub test/unit/deinterlace_motion_test.dart` and verify all tests pass.

---

### Task 2: Create Deinterlace & Motion Blur Studio Sheet & HUD Integration
**Files:**
- Create: `app/lib/features/video_effects/ui/deinterlace_motion_studio_sheet.dart`
- Modify: `app/lib/features/player/ui/widgets/desktop_keyboard_handler.dart`
- Modify: `app/lib/features/player/ui/player_screen.dart`
- Test: `app/test/unit/deinterlace_motion_widget_test.dart`

**Steps:**
- [x] Implement `DeinterlaceMotionStudioSheet` with:
  - Deinterlace Mode SegmentedButton (Off, Auto, On).
  - Deinterlacing Algorithm ChoiceChips (YADIF, YADIF 2x, BWDIF, Bob, Blend, Linear, IVTC).
  - Field Parity Dominance ChoiceChips (Auto, Top Field First, Bottom Field First).
  - Motion Blur Switch & Preset ChoiceChips (Subtle, Cinematic, Sports, Dreamy, Custom).
  - Custom Frame Span Slider (2 to 7 frames).
  - Reset to Defaults button.
- [x] Wire `Shift+D` keyboard shortcut in `desktop_keyboard_handler.dart` to open `_openDeinterlaceMotionStudio()`.
- [x] Add `hud_deinterlace_motion_button` in `PlayerScreen` quick options menu.
- [x] Write widget tests in `app/test/unit/deinterlace_motion_widget_test.dart` testing preset selection, algorithm changes, field order toggles, and live config updates.
- [x] Run `flutter test --no-pub test/unit/deinterlace_motion_widget_test.dart` and verify all tests pass.

---

### Task 3: Quality Gates, Static Analysis & Git Commit
**Files:**
- All modified/created files

**Steps:**
- [x] Run `flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
- [x] Run `flutter test --no-pub test/e2e/phase2_e2e_test.dart`.
- [x] Commit and push Phase 3 Feature 12 to `origin/main`.
- [x] Verify Phase 3 is 100% complete!
