# E-PLAYER DESIGN SYSTEM
## Stitch Source of Truth

E-Player is a premium, dark-first, cinematic, offline-first multimedia player with on-device AI enhancement.

## Brand
- Name: E-Player
- Tagline: Play. Enhance. Experience.
- Supporting line: Your Media. Your Control.
- Logo concept: geometric E + Play mark, cyan→blue→purple→magenta gradient.

## Visual direction
- Dark navy/black base.
- Electric cyan/blue primary.
- Purple/magenta reserved for advanced AI states.
- Premium cinematic media imagery.
- Rounded cards, restrained glass surfaces, subtle glow.
- Clean, modern, high-information hierarchy.
- Not a generic SaaS dashboard and not an over-decorated gaming UI.
- Use the approved E-Player reference image as the visual anchor.

## Colors
- App background: #050B16
- Elevated background: #091222
- Surface: #0D1728
- Elevated surface: #12213A
- Border: #1B3556
- Primary: #19BFFF
- Primary strong: #1468FF
- Secondary: #7B42FF
- AI accent: #E741FF
- Success: #21D79A
- Warning: #FFB547
- Danger: #FF5C72
- Primary text: #F5F8FF
- Secondary text: #A7B5CA
- Muted text: #6E7E95
- Disabled: #45546A

## Typography
- Prefer Inter/system sans.
- Display 32/700, H1 26/700, H2 21/700, H3 18/600, Body 15/400, Secondary 13/400, Caption 11/500.
- Use at most three weights per screen unless necessary.

## Shape and spacing
- Radius: 6 / 10 / 14 / 18 / 24px.
- Base spacing unit: 4px.
- Common spacing: 4/8/12/16/20/24/32.
- Mobile horizontal padding: 16–20px.
- Touch targets: 44–48px.

## Navigation
Mobile bottom navigation:
Home / Library / Enhance / Cast / Settings

Secondary screens use a top app bar with back, title and contextual action.

## Player design
The video is the visual hero. Controls are minimal and auto-hide friendly.
- top-left back
- top-right cast/more
- center play/pause
- bottom seek bar + core controls
- temporary gesture feedback only when needed

## AI design language
AI must look advanced but trustworthy.
- Blue/cyan for primary AI states.
- Purple/magenta for advanced features.
- Explicit states: AI Ready / AI Processing / AI Preview / AI Fallback / AI Unavailable.
- Never show AI decoration as proof of AI execution.

## Settings pattern
Icon + title + short description/value + control/chevron.

## Media
- Default 16:9 thumbnails.
- 12–16px radius.
- Compact badges: 4K / HDR / HEVC / AI / NEW / PENDING.
- Use strong imagery with subtle gradient overlays for text.

## Components
ELogo, EAppBar, EBottomNav, EPrimaryButton, ESecondaryButton, EIconButton, ESettingRow, ESectionHeader, EMediaCard, EMediaHeroCard, EMediaBadge, EProgressBar, EBottomSheet, ESlider, ESegmentedControl, EChip, EPlayerOverlay, EGestureFeedback, EAudioSlider, ESubtitlePreview, EModelCard, EStatCard, EEmptyState, EErrorState, ESkeleton, EDialog, EPermissionCard.

## Accessibility
- No critical action should be gesture-only.
- Support text scaling, semantic labels, focus states and high contrast.
- Do not use color alone to communicate status.

## Stitch rules
- Always apply this design system.
- Do not invent a second palette or typography system.
- Use realistic E-Player content, not lorem ipsum.
- Generate anchor screens first: Home, Player, Enhancement Studio, Library, Settings.
- Generate one screen at a time for high fidelity, then apply the same design system to remaining screens.
