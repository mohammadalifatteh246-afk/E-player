# Dispatch: Explorer 3 (Test Strategy & Clean-Room Headless Harness)

## Objective
Analyze the test design and test harness requirements for `test/unit/desktop_keyboard_handler_test.dart`.

## Key Documents to Read
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- `d:\E-player\PROJECT.md`
- `d:\E-player\.agents\teamwork\sub_orch_m1\SCOPE.md`
- Existing test patterns: `d:\E-player\app\test\unit\decoder_pipeline_test.dart` and `d:\E-player\app\test\helpers\`
- Survey report: `d:\E-player\.agents\teamwork\explorer_shortcuts_player\handoff.md`

## Specific Questions to Answer
1. How to avoid headless Flutter test failures caused by native C-FFI `Player` initialization (i.e. missing `mpv.dll` in headless runner)?
2. How to design `DesktopKeyboardHandler` so that it can be tested in pure widget tests (e.g. using callback interfaces or a mock/fake player interface)?
3. How to simulate physical and logical key events and modifiers (`HardwareKeyboard`, `simulateKeyDownEvent`, `simulateKeyUpEvent`) in widget tests?
4. What are all the test cases needed to thoroughly verify:
   - 13 universal shortcuts (Space, f/F11, m, b, v, a, h/g, k/j, +/-, ]/[, =, arrowUp/arrowDown)
   - 4-tier seek physics (Shift=3s, Alt=10s, Ctrl/Cmd=60s, Ctrl+Alt=300s, Default=10s)
   - Edge cases: clamping at `Duration.zero` (prevent underflow), clamping at `duration` (prevent overflow), zero duration, modifier precedence.
5. What commands should be used to run the tests and verify static analysis?

## Deliverable
Write a structured handoff report to `d:\E-player\.agents\teamwork\explorer_m1_3\handoff.md` with:
- Observation
- Logic Chain
- Recommendations
- Caveats


## 2026-11-10T08:32:33Z
You are Explorer 3 for Milestone 1.
Your state folder: d:\E-player\.agents\teamwork\explorer_m1_3\
Read your task description in: d:\E-player\.agents\teamwork\explorer_m1_3\DISPATCH.md
Read the authoritative documents:
- d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
- d:\E-player\PROJECT.md
- d:\E-player\.agents\teamwork\sub_orch_m1\SCOPE.md
- Existing test patterns: d:\E-player\app\test\unit\decoder_pipeline_test.dart and d:\E-player\app\test\helpers\
- Survey report: d:\E-player\.agents\teamwork\explorer_shortcuts_player\handoff.md

Investigate the test design and test harness for test/unit/desktop_keyboard_handler_test.dart:
- How to ensure headless tests run cleanly without native C-FFI Player dependencies.
- How to structure testable callbacks or mock interfaces for DesktopKeyboardHandler.
- How to simulate key events and modifiers (HardwareKeyboard, simulateKeyDownEvent).
- Comprehensive test cases covering all 13 shortcuts and 4-tier jump physics, including edge cases.
DO NOT modify any code.
Write your structured handoff report to d:\E-player\.agents\teamwork\explorer_m1_3\handoff.md.
When finished, send a message to your orchestrator with a summary and link to your report.


## 2026-11-10T08:44:34Z
**Context**: Milestone 1 Exploration Status Query
**Content**: You appear to have gone idle after setting up progress.md. Please proceed immediately with your investigation per DISPATCH.md and write your handoff.md report.
**Action**: Execute your investigation, write handoff.md, and reply with send_message when complete.
