# E-Player Engineering Directives & Rules
# Project: E-Player Phase 2 Core UX & Playback Enhancements (Flutter Desktop + Mobile + MediaKit)

## Project Stack & Architecture
- **Framework**: Flutter 3.x+ (Windows, Android, macOS, Linux, iOS) with Dart 3.x.
- **State Management**: Provider (`SettingsProvider`, etc.).
- **Playback Core**: libmpv via `media_kit: ^1.2.6` (HUD, OSD, volume boost 0-300%, frame-stepping, A-B repeat loop, aspect ratio crop).
- **Video Surface**: `PlayerScreen` (`lib/features/player/ui/player_screen.dart`), `CinematicGestureEngine`, `DesktopKeyboardHandler`.
- **Testing Suites**:
  - Unit tests: `app/test/unit/` (`phase2_unit_test.dart`)
  - E2E tests: `app/test/e2e/` (`phase2_e2e_test.dart`)

## Mandatory Coding, Testing, and Debugging Workflow for E-Player

### 1. Coding & Architecture Standards
- Activate skill: `flutter-expert` for any Flutter widget composition, gesture physics, libmpv bindings, and platform-specific desktop/mobile code.
- Activate skill: `coding-standards` to maintain clean Dart architecture, SOLID principles, and type safety.
- Activate skill: `incremental-implementation` to ensure changes are made in small, self-contained, testable diffs.
- Avoid over-engineering; keep gestures, state updates, and stream subscriptions leak-free.

### 2. Testing & Verification Pipeline
- Before claiming ANY task complete, run the complete verification loop:
  1. `cd D:\E-player\app`
  2. `flutter analyze` -> MUST pass with 0 errors and 0 warnings.
  3. `flutter test` -> MUST pass 100% of unit and integration tests.
- Activate skill: `test-driven-development` and `tdd-workflow` when implementing new features or fixing regressions.
- Activate skill: `e2e-testing-patterns` for maintaining Phase 2 opaque-box E2E test suites.

### 3. Debugging Protocols
- **Stop-The-Line**: If any test fails or runtime error occurs in libmpv / Flutter:
  1. Immediately stop modifying code.
  2. Activate skill: `debugging-and-error-recovery` or `debugging-strategies`.
  3. Reproduce the exact issue with minimum reproduction steps or unit test.
  4. Perform root cause analysis.
  5. Apply minimal surgical fix.
  6. Re-run `flutter test` and `flutter analyze` to verify.

## Available Workspace Skills (in `D:\E-player\.agents\skills` & `D:\E-player\skills`)
- `flutter-expert`
- `debugging-and-error-recovery`
- `debugging-strategies`
- `parallel-debugging`
- `test-driven-development`
- `tdd-workflow`
- `test-fixing`
- `testing-patterns`
- `verification-loop`
- `e2e-testing-patterns`
- `coding-standards`
- `code-review-and-quality`
- `code-simplification`
- `performance-optimization`
- `error-handling-patterns`
- `before-you-build`
- `lint-and-validate`
