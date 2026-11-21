# Phase 2 Feature 5: Video Watermark / Logo Overlay with Opacity & Positioning Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide full VLC-parity Video Watermark / Logo Overlay with complete control over opacity, positioning presets, X/Y offsets, scaling, image & text watermark modes, persistent state, and interactive UI access.

---

## Architecture Breakdown

1. **Configuration & Data Model (`video_effects_config.dart`, `watermark_models.dart`)**:
   - `VideoOverlayPosition`: 9-position anchor grid (`topLeft`, `topCenter`, `topRight`, `centerLeft`, `center`, `centerRight`, `bottomLeft`, `bottomCenter`, `bottomRight`).
   - Watermark properties: `logoEnabled`, `logoPath`, `logoText`, `logoPosition`, `logoOpacity` (0.0 to 1.0), `logoScale` (0.2 to 3.0), `logoOffsetX` (0 to 500 px), `logoOffsetY` (0 to 500 px).
2. **Video Overlay Surface (`video_overlay_widget.dart`)**:
   - Renders image watermark (PNG/JPG/WebP) or styled text watermark with smooth alpha blending over the video.
   - Computes anchor positioning with offsets.
3. **Dedicated Watermark Studio Sheet (`watermark_studio_sheet.dart`)**:
   - Quick-access Cyberpunk modal dialog for watermark control.
   - 3x3 interactive positioning grid buttons.
   - Live opacity slider (0% to 100%).
   - Scale slider (0.2x to 3.0x).
   - X & Y pixel offset steppers/sliders.
   - Browse image / enter text watermark.
4. **PlayerScreen Wiring (`player_screen.dart`)**:
   - Quick option entry in Quick Actions sheet (`hud_watermark_button`).
   - Live updates to `VideoOverlayWidget`.
5. **Unit & Widget Tests (`watermark_test.dart`, `watermark_widget_test.dart`)**:
   - Unit tests verifying model serialization, position alignments, and offset mathematics.
   - Widget tests verifying UI rendering, sliders, position changes, and image selection.

---

## Tasks

### Task 1: Enhance Watermark Model & Video Overlay Surface
- [x] In `app/lib/features/video_effects/models/video_overlay_models.dart`, ensure 9-point grid (`topCenter`, `bottomCenter`, `centerLeft`, `centerRight` if missing).
- [x] In `app/lib/features/video_effects/models/video_effects_config.dart`, add `logoText` support for text watermarks alongside image watermarks.
- [x] In `app/lib/features/video_effects/ui/video_overlay_widget.dart`, support both image logo and text watermark with opacity, scale, and 9-point position offsets.

### Task 2: Create Dedicated Watermark Studio Sheet
- [x] Create `app/lib/features/video_effects/ui/watermark_studio_sheet.dart`.
- [x] Implement 3x3 position matrix selector, opacity slider, scale slider, X/Y offset sliders, and image picker / text input.
- [x] In `app/lib/features/video_effects/ui/video_effects_sheet.dart`, add X/Y offset controls to the Overlay tab.

### Task 3: Wire into PlayerScreen
- [x] In `app/lib/features/player/ui/player_screen.dart`, add "Watermark & Logo Studio" quick action tile in the HUD quick settings menu.
- [x] Verify `VideoOverlayWidget` reflects watermark changes dynamically.

### Task 4: Unit & Widget Testing
- [x] Create `app/test/unit/watermark_test.dart` testing configuration, alignment calculations, and persistence.
- [x] Create `app/test/unit/watermark_widget_test.dart` testing `WatermarkStudioSheet` interactions and callbacks.
- [x] Verify all tests pass with `flutter test --no-pub`.

### Task 5: Static Analysis & Git Commit
- [x] Run `flutter analyze --no-pub` (MUST pass with 0 errors and 0 warnings).
- [x] Commit and push Phase 2 Feature 5 to `origin/main`.
