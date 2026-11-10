# Dispatch: worker_m3_r2_1

## Task Assignment
Execute Milestone 3 Iteration 2 Remediation:
1. Fix Material assertion crash in `lib/features/player/ui/audio_studio_sheet.dart:1045-1052` by removing `borderRadius` from `Material(...)` in `_buildBoostSwitchTile`.
2. Polish `_showAudioTrackMenu` in `lib/features/player/ui/player_screen.dart:694-712` by replacing the outer `Container(decoration: ...)` with `ConstrainedBox(child: Material(key: const Key('audio_tracks_sheet'), color: EDesign.surface, elevation: 8, shadowColor: Colors.black.withValues(alpha: 0.5), clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(...), child: Column(...)))`. Also polish item Material at line 822.
3. Enhance `test/features/audio_studio_test.dart` by adding `setAudioTrack` to FakePlayerPlatform/FakePlayer, and adding Group 8 (AudioStudioSheet Full Widget Mounting & Structural Integrity - 7 tests) and Group 9 (Audio Track Selector Modal Architecture & Interaction Fixture - 2 tests).
4. Update `test/features/audio_studio_adversarial_test.dart:69-75` so Challenge 1 asserts `expect(tester.takeException(), isNull)` now that the bug is resolved.
5. Verify `flutter test test/features/audio_studio_test.dart`, `flutter test test/features/audio_studio_adversarial_test.dart`, `flutter test test/e2e/phase1_e2e_test.dart --name "T1.5.1"`, and `dart analyze`. All must pass cleanly with 0 errors and 0 warnings.


## 2026-11-10T11:02:39Z
You are the Worker for Milestone 3 Iteration 2 Remediation (AudioStudioSheet Material Assertion Crash & Test Suite Blindspot Elimination).

Working directory: d:\E-player\app
Your state folder: d:\E-player\.agents\teamwork\worker_m3_r2_1\
Original user request path: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
Scope document: d:\E-player\.agents\teamwork\sub_orch_m3\SCOPE.md
Investigation handoffs to read:
- d:\E-player\.agents\teamwork\spec_miner_m3_r2_1\handoff.md (detailed code changes and complete test code for Groups 8 & 9)
- d:\E-player\.agents\teamwork\explorer_m3_r2_1\handoff.md
- d:\E-player\.agents\teamwork\explorer_m3_r2_2\handoff.md
- d:\E-player\.agents\teamwork\challenger_m3_2\handoff.md

Exclusive file write ownership:
- lib/features/player/ui/audio_studio_sheet.dart
- lib/features/player/ui/player_screen.dart
- test/features/audio_studio_test.dart
- test/features/audio_studio_adversarial_test.dart

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Tasks:
1. Fix Material assertion crash in lib/features/player/ui/audio_studio_sheet.dart:1045-1052:
   In _buildBoostSwitchTile, remove `borderRadius: BorderRadius.circular(EDesign.r14),` from Material(...) so that only `shape: RoundedRectangleBorder(...)` is provided, satisfying Flutter's `assert(!(shape != null && borderRadius != null))`.

2. Polish modal container in lib/features/player/ui/player_screen.dart:694-712:
   In _showAudioTrackMenu, replace the outer `Container(decoration: BoxDecoration(...))` with:
   ```dart
   return ConstrainedBox(
     constraints: BoxConstraints(
       maxHeight: MediaQuery.of(context).size.height * 0.65,
     ),
     child: Material(
       key: const Key('audio_tracks_sheet'),
       color: EDesign.surface,
       elevation: 8,
       shadowColor: Colors.black.withValues(alpha: 0.5),
       clipBehavior: Clip.antiAlias,
       shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(
           top: Radius.circular(EDesign.r24),
         ),
         side: BorderSide(color: EDesign.border, width: 1.0),
       ),
       child: Column(...),
     ),
   );
   ```
   And in player_screen.dart:822-837, update the item Material to include `clipBehavior: Clip.antiAlias` and `shape: RoundedRectangleBorder(...)` without `borderRadius`.

3. Enhance test/features/audio_studio_test.dart per spec_miner_m3_r2_1/handoff.md:
   - Add setAudioTrack to FakePlayerPlatform and FakePlayer.
   - Add Group 8: AudioStudioSheet Full Widget Mounting & Structural Integrity (7 testWidgets).
   - Add Group 9: Audio Track Selector Modal Architecture & Interaction Fixture (2 testWidgets).

4. Update test/features/audio_studio_adversarial_test.dart:69-75:
   In Challenge 1 (AudioStudioSheet Runtime Assertion Integrity), update the assertion now that the bug is fixed:
   ```dart
   final error = tester.takeException();
   expect(error, isNull, reason: 'AudioStudioSheet must mount cleanly without Material assertion error');
   ```

5. Verification:
   Run the following commands in d:\E-player\app:
   - flutter test test/features/audio_studio_test.dart
   - flutter test test/features/audio_studio_adversarial_test.dart
   - flutter test test/e2e/phase1_e2e_test.dart --name "T1.5.1"
   - dart analyze
   Ensure all tests pass with 0 failures and dart analyze reports 0 issues/warnings.

6. Report:
   Write handoff.md in your state folder (d:\E-player\.agents\teamwork\worker_m3_r2_1\handoff.md) with Observation, Logic Chain, Caveats, Conclusion, and Verification Method (including verbatim test & analysis outputs). Send a completion message when done.
