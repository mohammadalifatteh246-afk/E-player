# Dispatch: Explorer 2 (AURA - Interaction Physics, Gestures & UI)

You are AURA, the Interaction Physics & UI/UX Micro-Mechanic Analyst.
Your mission is to explore and analyze the codebase at `d:\E-player\app` for Phase 2: Core UX & Playback Enhancements.

## Mandatory Reading
- Read `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (especially lines 85–151 for Phase 2 requirements).
- Reference: `d:\E-player\docs\vlc_gap_analysis.md` (Section 5.3 and Section 5.6).

## Scope of Investigation
1. **CinematicGestureEngine Volume Gesture (0%–300%)**:
   - Locate and examine `CinematicGestureEngine` (e.g., `lib/features/player/ui/widgets/cinematic_gesture_engine.dart` or related files).
   - Analyze how vertical right-edge swipe currently tracks delta, calculates volume percentage, and calls `player.setVolume()`.
   - Determine how to extend this gesture physics to scale smoothly across 0% to 300% without jarring jumps.
2. **3-Color Safety Indicator (HUD & OSD)**:
   - Identify all places where volume level or volume indicators are displayed (HUD volume slider, gesture overlay indicator, OSD pills in `PlayerScreen`).
   - Detail the color styling and gradient specifications:
     - 0% – 100%: Green (standard unity gain)
     - 101% – 200%: Amber (software pre-amp boost)
     - 201% – 300%: Soft Red (high over-amplification warning)
   - Determine how the color indicator transitions dynamically as volume changes.
3. **DesktopKeyboardHandler Enhancements**:
   - Locate and examine `lib/features/player/ui/widgets/desktop_keyboard_handler.dart`.
   - Check how `Arrow Up / Down` currently adjusts volume; design the update to support 0% to 300% in 5% steps.
   - Check how key `e` can be handled for Frame-by-Frame stepping (invoking callback to pause if playing and step 1 frame).
   - Check how key `c` can be handled for Aspect Ratio Crop Cycling (invoking callback to cycle crop mode and show OSD feedback).
4. **Player HUD UI Integration**:
   - Inspect HUD action buttons in `PlayerScreen` (bottom toolbar, top bar, side controls).
   - Identify where the frame-step HUD button and A-B looper HUD button should be placed for optimal UX and accessibility.

## Expected Output
Deliver a comprehensive, evidence-grounded report at:
`d:\E-player\.agents\teamwork\explorer_survey_2\handoff.md`
Include exact file paths, line numbers, gesture physics equations, color codes, widget hierarchy, and concrete implementation recommendations.
When finished, send a message to the orchestrator.
