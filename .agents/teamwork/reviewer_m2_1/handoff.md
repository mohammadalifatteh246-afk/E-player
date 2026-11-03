# Milestone 2 (Phase 3 Cinematic Gesture Engine) Review & Adversarial Challenge Report

## 1. Observation

Direct code examination and command executions yielded the following concrete observations:

1. **Static Analysis & Unit Test Execution:**
   - Command:
     ```powershell
     flutter analyze lib/features/player/ui/gesture_models.dart lib/features/player/ui/cinematic_gesture_engine.dart lib/features/player/ui/player_screen.dart test/unit/cinematic_gesture_engine_test.dart
     ```
     Result: `Analyzing 4 items... No issues found! (ran in 56.3s)` — Exit code 0.
   - Command:
     ```powershell
     flutter test test/unit/cinematic_gesture_engine_test.dart
     ```
     Result: `00:01 +28: All tests passed!` — Exit code 0 (28/28 passed).
   - Command:
     ```powershell
     flutter test test/unit/cinematic_gesture_engine_test.dart test/unit/decoder_pipeline_test.dart
     ```
     Result: `00:06 +49: All tests passed!` — Exit code 0 (49/49 passed, zero regression on M1 decoders).

2. **Code Inspection — Horizontal Scrub State Lifetime (`cinematic_gesture_engine.dart`):**
   - Line 164:
     ```dart
     Duration _initialPosition = Duration.zero;
     ```
   - Lines 428–437 (`_handleHorizontalScrub`):
     ```dart
     if (arbitrator.startPoint == null) return;

     if (_initialPosition == Duration.zero && currentPosition > Duration.zero) {
       _initialPosition = currentPosition;
     }

     final cumulativeDx = details.localFocalPoint.dx - arbitrator.startPoint!.dx;
     // 0.5s per pixel travel for precision scrubbing
     final deltaSeconds = (cumulativeDx * 0.5).round();
     final candidateTarget = _initialPosition + Duration(seconds: deltaSeconds);
     ```
   - Lines 235–243 (`handleScaleStart`):
     ```dart
     void handleScaleStart(ScaleStartDetails details, Size viewportSize) {
       _controlsInhibitedController.add(true);
       _initialScale = _scale;
       arbitrator.handleDown(
         details.localFocalPoint,
         details.pointerCount,
         viewportSize,
       );
     }
     ```
   - Lines 284–298 (`handleScaleEnd`):
     ```dart
     void handleScaleEnd(ScaleEndDetails details) {
       final mode = arbitrator.mode;

       if (mode == GestureMode.horizontalScrub) {
         onInvalidateAiQueue?.call();
         _seekCommitController.add(SeekCommitEvent(
           target: _scrubPreviewPosition,
           previewDuration: _lastTotalDuration,
         ));
         onSeek?.call(_scrubPreviewPosition);
       }

       arbitrator.reset();
       _controlsInhibitedController.add(false);
     }
     ```
   - Observation: `_initialPosition` is set once on line 431, and is NEVER cleared or reset in `handleScaleEnd`, `handleScaleStart`, or `arbitrator.reset()`.

3. **Code Inspection — Double Seek Dispatch (`player_screen.dart` & `cinematic_gesture_engine.dart`):**
   - In `cinematic_gesture_engine.dart`:
     - Line 289–293:
       ```dart
       _seekCommitController.add(SeekCommitEvent(
         target: _scrubPreviewPosition,
         previewDuration: _lastTotalDuration,
       ));
       onSeek?.call(_scrubPreviewPosition);
       ```
     - Lines 327–331 & 344–348 (wing double-tap): Both invoke `_seekCommitController.add(...)` AND `onSeek?.call(...)`.
   - In `player_screen.dart`:
     - Lines 229–232:
       ```dart
       onSeek: (target) {
         _aiEngine.invalidateQueue();
         _player.seek(target);
       },
       ```
     - Lines 272–275:
       ```dart
       _seekCommitSubscription = _gestureEngine.seekCommitEvents.listen((event) {
         _aiEngine.invalidateQueue();
         _player.seek(event.target);
       });
       ```
   - Observation: Every completed scrub or double-tap jump triggers `_player.seek(target)` and `_aiEngine.invalidateQueue()` twice in immediate succession.

4. **Code Inspection — Invariant Conformance:**
   - Dead-zone gating (`cinematic_gesture_engine.dart` lines 72–82): Enforces `primaryDelta >= 12.0` and `primaryDelta >= 1.5 * secondaryDelta`.
   - Spatial zones (`cinematic_gesture_engine.dart` lines 88–108): Left 35% brightness, Right 35% volume, Center 30% scrub.
   - Panning bounding formula (`cinematic_gesture_engine.dart` lines 206–217):
     ```dart
     final maxTx = (scale - 1.0) * viewportSize.width / 2.0;
     final maxTy = (scale - 1.0) * viewportSize.height / 2.0;
     ```
     Guarantees zero black void exposure at all scales $S \in [1.0, 4.0]$.
   - HUD auto-dismiss: Inhibit emitted via `controlsInhibited` stream on scale start; uninhibited on scale end; resets 2800ms timer with 800ms lingering feedback.
   - Resource disposal (`player_screen.dart` lines 306–323): Cancels all 3 gesture streams (`_gestureFeedbackSubscription`, `_seekCommitSubscription`, `_controlsInhibitedSubscription`), both timers (`_feedbackOverlayTimer`, `_wingRippleTimer`), and calls `_gestureEngine.dispose()`.

---

## 2. Logic Chain

1. **Deduction of the Multi-Scrub Timestamp Desynchronization Bug (Finding 1):**
   - *Premise 1:* In `cinematic_gesture_engine.dart`, `_initialPosition` starts at `Duration.zero` (line 164).
   - *Premise 2:* On the first horizontal scrub at `currentPosition = T1 > Duration.zero`, line 430 condition `(_initialPosition == Duration.zero && currentPosition > Duration.zero)` evaluates to `true`, setting `_initialPosition = T1`.
   - *Premise 3:* When the user releases the gesture (`handleScaleEnd`), `_initialPosition` is NOT reset to `Duration.zero` or `null`.
   - *Premise 4:* On any subsequent scrub at `currentPosition = T2` (where $T2 \ne T1$), line 430 condition is `false` because `_initialPosition` remains equal to $T1 \ne \text{Duration.zero}$.
   - *Conclusion:* Line 437 computes `candidateTarget = _initialPosition + Duration(seconds: deltaSeconds)` using $T1$ instead of $T2$. A user scrubbing forward at 45:00 after scrubbing at 05:00 will jump to $05:00 + \Delta$ rather than $45:00 + \Delta$, causing a catastrophic backwards seek regression of 40 minutes.
   - *Additional Edge Case:* If the first scrub occurs at media start where `currentPosition == Duration.zero`, `_initialPosition` remains `Duration.zero` because `currentPosition > Duration.zero` is false. If a later scrub occurs at 10:00, that later scrub locks `_initialPosition = 10:00` permanently for all subsequent scrubs.

2. **Deduction of Duplicate Seek Pipeline Churn (Finding 2):**
   - *Premise 1:* `cinematic_gesture_engine.dart` dispatches seek actions through two separate channels: calling `onSeek?.call(target)` and publishing `SeekCommitEvent(target)` to `_seekCommitController`.
   - *Premise 2:* In `player_screen.dart`, both channels are actively subscribed and both execute `_player.seek(target)` and `_aiEngine.invalidateQueue()`.
   - *Conclusion:* Seeking produces redundant IPC messages to `libmpv` and duplicate queue flushes on the AI engine for every gesture commit.

3. **Integrity Audit:**
   - Checked for hardcoded test results, facade stubs, or bypassed implementations: None found.
   - The underlying architecture, models, math formulas, and widget integration are genuine, well-designed, and production-grade.
   - However, the lack of state isolation across sequential scrubs is a functional failure that must be corrected before approval.

---

## 3. Caveats

- **No Caveats.** Static analysis, unit tests, and multi-file code inspection were fully executed against all touched and related targets.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES**

Milestone 2 implementation is well-architected and adheres strictly to the mathematical invariants for dead-zone gating, spatial zones, bounded pinch-to-zoom, and HUD auto-dismiss. However, it contains one **Critical functional defect** and one **Major performance defect**:
1. **Critical:** `_initialPosition` is not reset across gestures, corrupting all timeline scrubs after the first scrub.
2. **Major:** Duplicate `_player.seek()` and `_aiEngine.invalidateQueue()` calls occur on every seek commit.

---

## 5. Findings & Actionable Remediations

### Finding 1: [Critical] `_initialPosition` is never reset across scrub gestures, corrupting sequential timeline scrubs
- **Location**: `app/lib/features/player/ui/cinematic_gesture_engine.dart`, lines 164, 235–243, 284–298, 430–432.
- **Problem**: `_initialPosition` is only assigned when `_initialPosition == Duration.zero`, but is never cleared on gesture end or gesture start. All subsequent scrubs in a playback session re-use the timestamp from the first scrub.
- **Required Fix**:
  1. Declare `Duration? _initialPosition;` in `CinematicGestureEngine`.
  2. In `handleScaleStart` and/or `handleScaleEnd`, reset `_initialPosition = null;`.
  3. In `_handleHorizontalScrub`, assign `_initialPosition ??= currentPosition;`.
  4. In `cinematic_gesture_engine_test.dart`, add a test verifying sequential scrubs (e.g. scrub 1 at 60s -> release; scrub 2 at 300s -> drag +20px -> verify scrub preview and commit are relative to 300s).

### Finding 2: [Major] Duplicate seek dispatch on every gesture commit
- **Location**: `app/lib/features/player/ui/player_screen.dart` lines 229–232 & 272–275; `app/lib/features/player/ui/cinematic_gesture_engine.dart` lines 289–293, 327–331, 344–348.
- **Problem**: Seeking is executed twice in immediate succession (once via `onSeek` callback and once via `_seekCommitSubscription`).
- **Required Fix**: Remove `_player.seek()` and `_aiEngine.invalidateQueue()` from the `onSeek` callback in `player_screen.dart`, or rely solely on `_seekCommitSubscription` as specified in `PROJECT.md` interface contracts.

---

## 6. Adversarial Stress-Test Matrix

| # | Stress Scenario | Expected Behavior | Actual Behavior | Result |
|---|-----------------|-------------------|-----------------|--------|
| 1 | Sequential Scrub: 1st scrub at 60s (+20s), 2nd scrub at 300s (+10s) | 2nd scrub seeks to 310s | 2nd scrub seeks to 70s (jumps back to 1st scrub baseline) | **FAIL (Finding 1)** |
| 2 | Initial Scrub at 00:00 (Beginning of media) | Scrub forward seeks to $0 + \Delta$ | Sets baseline correctly, but fails to update on later scrubs | **FAIL (Finding 1)** |
| 3 | Seek Dispatch: Single scrub release | Single `_player.seek()` call | Two consecutive `_player.seek()` calls | **FAIL (Finding 2)** |
| 4 | Directional Crosstalk: Diagonal swipe (dx=14, dy=16) | Stays in `arbitrating` until dominant axis >= 1.5x | Remains in `arbitrating`, resolves to brightness when dy reaches 30px | **PASS** |
| 5 | Pan Clamping: 3.0x zoom dragged beyond viewport | Clamped to $|Tx| \le 1000$, $|Ty| \le 600$ (zero black void) | Exact clamp coordinates $(1000, -600)$ | **PASS** |
| 6 | Wing Double-Tap Underflow/Overflow | Clamped to `Duration.zero` and `totalDuration` | Clamped to `Duration.zero` and `totalDuration` | **PASS** |
| 7 | HUD Auto-Dismiss Coordination | Halts 2800ms timer during gesture; restarts with 800ms lingering | Emits `controlsInhibited = true/false` cleanly | **PASS** |
| 8 | Double-Tap Reset When Zoomed | Scale reset to 1.0x, pan offset reset to zero | Scales reset to 1.0x without seeking | **PASS** |
| 9 | Resource Disposal | Clean stream subscription and timer cancellation | All subscriptions, timers, and engine controllers disposed | **PASS** |

---

## 7. Verification Method

Independently reproducible commands from `d:\E-player\app`:

1. **Static Analysis:**
   ```powershell
   flutter analyze lib/features/player/ui/gesture_models.dart lib/features/player/ui/cinematic_gesture_engine.dart lib/features/player/ui/player_screen.dart test/unit/cinematic_gesture_engine_test.dart
   ```
2. **Milestone 2 Unit Tests:**
   ```powershell
   flutter test test/unit/cinematic_gesture_engine_test.dart
   ```
3. **Cross-Subsystem Regression Test:**
   ```powershell
   flutter test test/unit/cinematic_gesture_engine_test.dart test/unit/decoder_pipeline_test.dart
   ```
4. **Invalidation Condition:**
   Execution of sequential scrubs at different timestamps in `CinematicGestureEngine` must calculate targets relative to the active gesture's starting timestamp, not previous gestures.
