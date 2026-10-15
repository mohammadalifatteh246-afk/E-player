# E-PLAYER STITCH MCP → ANTIGRAVITY UI/UX IMPLEMENTATION HANDOFF

## Objective
Use Google Stitch MCP as the visual design authority and Antigravity as the implementation engineer. Transform approved Stitch screens into the existing Flutter E-Player app without breaking current playback, subtitle or Enhancement Studio functionality.

## Required context
Read:
- `.stitch/DESIGN.md`
- `.stitch/SITE.md`
- `.stitch/next-prompt.md`
- `E_PLAYER_UIUX_SCREEN_SPEC.md`
- `E_PLAYER_STITCH_PROMPTS.md`
- E-Player PRD V2
- E-Player Implementation Plan V2
- E-Player AI Skill
- E-Player Python Skill

## Stitch process
1. Inspect Stitch project.
2. Inspect existing screens.
3. Retrieve screenshots/HTML where available.
4. Establish/apply the design system.
5. Generate anchor screens.
6. Review visually.
7. Implement in Flutter.
8. Connect real application state.
9. Run the app.
10. Compare screenshots.
11. Correct visual differences.
12. Continue to remaining screens.

## Anchor order
Home → Player → Enhancement Studio → Library → Settings → remaining screens.

## Implementation rule
Stitch is the visual source; the real Flutter app is the functional source. Do not replace working backend/player functionality just to match a mockup.

## Reusable Flutter components
EAppBar, EBottomNav, EMediaCard, EMediaBadge, ESettingRow, ESectionHeader, EPrimaryButton, EIconButton, EBottomSheet, ESlider, ESegmentedControl, EPlayerControls, EGestureFeedback, EStateBadge, EEmptyState, EErrorState, ESkeleton.

## Centralize tokens
Implement colors, typography, radii, spacing, shadows, sizes and component metrics centrally in the Flutter theme/design tokens. Do not hardcode separate visual styles per screen.

## Functional rule
Every visible control must connect to real state or be explicitly marked unavailable. Examples: Decoder UI → actual decoder setting; Aspect Ratio → actual player mode; AI resolution → enhancement configuration; EQ → audio processor; Subtitle delay → subtitle state; Vault → encrypted-storage service; Cast → cast session.

## Responsive
Verify phone portrait, phone landscape, tablet and desktop/reference build. Keep one consistent visual identity.

## Visual QA
Compare spacing, hierarchy, typography, colors, iconography, radius, media crop, touch targets, safe areas and states against Stitch reference screens.

## Safety
Do not rewrite media_kit/libmpv, delete C++ FFI, remove libass support, remove Enhancement Studio, replace real data with mock content, or create fake functionality to match a visual mockup.

## Completion
UI is complete only when approved screens are implemented, primary navigation works, responsive states are verified, controls are connected to real functionality, visual regression passes, and current playback remains stable.
