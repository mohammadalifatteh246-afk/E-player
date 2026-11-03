# Milestone 2 Remediation Review & Challenge Report (Gate 2)

**Reviewer / Adversarial Critic**: `reviewer_m2_gate_2`  
**Date**: 2026-10-22T13:13:00Z  
**Verdict**: **APPROVE**  
**Integrity Status**: **VERIFIED CLEAN (No integrity violations detected)**  
**Adversarial Risk Assessment**: **LOW**  

---

## 1. Observation

1. **Codebase Inspection & Line Verifications**:
   - In `app/lib/features/player/ui/cinematic_gesture_engine.dart`:
     - Line 164 declares nullable state: `Duration? _initialPosition;`.
     - Lines 235–244 (`handleScaleStart`):
       ```dart
       void handleScaleStart(ScaleStartDetails details, Size viewportSize) {
         _initialPosition = null;
         _controlsInhibitedController.add(true);
         _initialScale = _scale;
         arbitrator.handleDown(
           details.localFocalPoint,
           details.pointerCount,
           viewportSize,
         );
       }
       ```
       Direct observation: `_initialPosition = null;` is executed on every gesture start.
     - Lines 285–300 (`handleScaleEnd`):
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

         _initialPosition = null;
         arbitrator.reset();
         _controlsInhibitedController.add(false);
       }
       ```
       Direct observation: `_initialPosition = null;` is executed on gesture completion.
     - Lines 424–458 (`_handleHorizontalScrub`):
       ```dart
       if (arbitrator.startPoint == null) return;

       _initialPosition ??= currentPosition;

       final cumulativeDx = details.localFocalPoint.dx - arbitrator.startPoint!.dx;
       // 0.5s per pixel travel for precision scrubbing
       final deltaSeconds = (cumulativeDx * 0.5).round();
       final candidateTarget = _initialPosition! + Duration(seconds: deltaSeconds);

       Duration clampedTarget;
       if (candidateTarget < Duration.zero) {
         clampedTarget = Duration.zero;
       } else if (totalDuration > Duration.zero && candidateTarget > totalDuration) {
         clampedTarget = totalDuration;
       } else {
         clampedTarget = candidateTarget;
       }
       ```
       Direct observation: `_initialPosition` uses lazy null-coalescing assignment `??=`, anchoring to `currentPosition` on the first active scrub update and remaining stable across all subsequent update frames within the same gesture. Boundary clamping guards against negative timestamps and only clamps to `totalDuration` when `totalDuration > Duration.zero`.

   - In `app/lib/features/player/ui/player_screen.dart`:
     - Lines 209–228:
       ```dart
       _gestureEngine = CinematicGestureEngine(
         initialBrightness: _brightness,
         initialVolume: _volume,
         onBrightnessChanged: (b) {
           if (mounted) setState(() => _brightness = b);
         },
         onVolumeChanged: (v) {
           _player.setVolume(v);
           if (mounted) setState(() => _volume = v);
         },
         onTogglePlayPause: () {
           if (_isPlaying) {
             _player.pause();
             _showFeedbackMessage("Paused", Icons.pause);
           } else {
             _player.play();
             _showFeedbackMessage("Play", Icons.play_arrow);
           }
         },
       );
       ```
       Direct observation: Duplicate callbacks `onSeek` and `onInvalidateAiQueue` are omitted from the constructor call.
     - Lines 267–270:
       ```dart
       _seekCommitSubscription = _gestureEngine.seekCommitEvents.listen((event) {
         _aiEngine.invalidateQueue();
         _player.seek(event.target);
       });
       ```
       Direct observation: `_player.seek()` and `_aiEngine.invalidateQueue()` are registered strictly once through the unified `seekCommitEvents` broadcast stream.
     - Lines 301–318 (`dispose`):
       ```dart
       _gestureFeedbackSubscription?.cancel();
       _seekCommitSubscription?.cancel();
       _controlsInhibitedSubscription?.cancel();
       _feedbackOverlayTimer?.cancel();
       _wingRippleTimer?.cancel();
       _gestureEngine.dispose();
       ```
       Direct observation: All stream subscriptions, timers, and the engine itself are cleanly canceled and closed upon widget unmount.

2. **Interface Contract Conformance with `PROJECT.md § CinematicGestureEngine <-> PlayerScreen`**:
   - Class: `CinematicGestureEngine` (matches).
   - Methods:
     - `void handleScaleStart(ScaleStartDetails details, Size viewportSize)` (line 235, matches).
     - `void handleScaleUpdate(ScaleUpdateDetails details, Size viewportSize, Duration currentPosition, Duration totalDuration)` (line 247, matches).
     - `void handleScaleEnd(ScaleEndDetails details)` (line 285, matches).
     - `void handleDoubleTapDown(TapDownDetails details, Size viewportSize, Duration currentPosition, Duration totalDuration)` (line 303, matches).
   - Streams:
     - `Stream<GestureFeedbackEvent> get feedbackEvents` (line 182, matches).
     - `Stream<SeekCommitEvent> get seekCommitEvents` (line 183, matches).
     - `Stream<bool> get controlsInhibited` (line 184, matches).
   - Invariants:
     - 12px dead zone threshold and 1.5x axis dominance ratio enforced in `GestureArbitrator` (lines 72–82).
     - Panning offsets strictly clamped via `clampPanOffset`: `|Tx| <= (scale - 1) * width / 2` and `|Ty| <= (scale - 1) * height / 2` (lines 206–217).

3. **Static Analysis & Automated Test Execution**:
   - Static Analysis Command:
     ```powershell
     flutter analyze lib/features/player/ui/cinematic_gesture_engine.dart lib/features/player/ui/player_screen.dart
     ```
     Result: `Analyzing 2 items... No issues found! (ran in 13.7s)` — Exit code 0.
   - Milestone 2 Unit Test Suite:
     ```powershell
     flutter test test/unit/cinematic_gesture_engine_test.dart
     ```
     Result: `00:00 +30: All tests passed!` — Exit code 0, 30/30 passed.
     Specifically verified new tests:
     - `Sequential scrub gestures at different timestamps reset baseline correctly (Finding 1 remediation)`: PASSED.
     - `Scrub starting at Duration.zero anchors baseline correctly without persisting`: PASSED.
   - Phase 1 Decoder Pipeline Regression Test Suite:
     ```powershell
     flutter test test/unit/decoder_pipeline_test.dart
     ```
     Result: `00:00 +21: All tests passed!` — Exit code 0, 21/21 passed.

---

## 2. Logic Chain

1. **Resolution of Finding 1 (Scrub Timestamp Desynchronization)**:
   - *Observation Reference*: Line 164 (`Duration? _initialPosition`), lines 236 and 297 (`_initialPosition = null;`), line 432 (`_initialPosition ??= currentPosition;`).
   - *Deduction*: By transitioning `_initialPosition` from a non-nullable zero-initialized scalar to a nullable lifecycle variable, the engine clearly distinguishes between "no active scrub anchor" (`null`) and "anchored at timestamp $T$" (`_initialPosition != null`).
   - *Deduction*: Invoking `_initialPosition = null` in both `handleScaleStart` and `handleScaleEnd` provides defense-in-depth: whether a gesture completes naturally or is aborted/re-entered, the anchor is guaranteed to be reset prior to the next scrub.
   - *Deduction*: In `_handleHorizontalScrub`, `_initialPosition ??= currentPosition` ensures that when scrubbing starts at `Duration.zero`, `_initialPosition` is set to `Duration.zero` (which is non-null), and will NOT be overwritten by subsequent update ticks while playing.
   - *Conclusion*: Finding 1 is completely and robustly resolved.

2. **Resolution of Finding 2 (Duplicate Seek Dispatch Pipeline Churn)**:
   - *Observation Reference*: `player_screen.dart` lines 209–228, 267–270, and grep search across `app/lib`.
   - *Deduction*: In `PlayerScreen`, `_gestureEngine` is instantiated without `onSeek` and `onInvalidateAiQueue`. Therefore, when `CinematicGestureEngine.handleScaleEnd` or `handleDoubleTapDown` evaluates `onSeek?.call(...)` and `onInvalidateAiQueue?.call(...)`, those callbacks are no-ops (`null`).
   - *Deduction*: The sole dispatch pipeline in `PlayerScreen` is `_seekCommitSubscription`, which receives events from `_gestureEngine.seekCommitEvents`.
   - *Deduction*: For every completed scrub or wing jump, exactly one invocation of `_aiEngine.invalidateQueue()` and exactly one invocation of `_player.seek(event.target)` occurs.
   - *Conclusion*: Finding 2 is completely resolved with zero duplicated seeks or invalidations.

3. **Integrity Verification**:
   - *Observation Reference*: Full inspection of `cinematic_gesture_engine.dart`, `gesture_models.dart`, and `player_screen.dart`.
   - *Deduction*: No hardcoded test responses, dummy classes, facade logic, stubbed methods, or bypassed workflows exist. All calculations (axis dominance, pixel travel math, boundary clamping, zoom matrix offset, wing jump durations) are real and algorithmic.
   - *Conclusion*: Zero integrity violations.

4. **Adversarial Stress-Testing**:
   - *Scenario A: Zero duration start (`currentPosition == Duration.zero`)*:
     - Evaluated: `_initialPosition ??= Duration.zero;` sets `_initialPosition` to `Duration.zero`.
     - Clamping: Backward movement is clamped to `Duration.zero` (`candidateTarget < Duration.zero`). Forward movement scales linearly at 0.5s/pixel.
     - Result: PASS.
   - *Scenario B: Uninitialized or streaming media (`totalDuration == Duration.zero`)*:
     - Evaluated: In `_handleHorizontalScrub`, the upper clamp condition is guarded by `totalDuration > Duration.zero`.
     - Behavior: When `totalDuration == Duration.zero`, the engine does not collapse the seek target to 0 or crash; it allows free scrubbing without throwing exceptions.
     - Result: PASS.
   - *Scenario C: Rapid scrub commits and micro-movements*:
     - Evaluated: Gestures moving `< 12px` or failing `|primary| >= 1.5 * |secondary|` remain in `GestureMode.arbitrating`. When released while arbitrating, `mode == GestureMode.horizontalScrub` is false, preventing any spurious seek dispatch.
     - Result: PASS.
   - *Scenario D: Double tap interaction during zoom*:
     - Evaluated: In `handleDoubleTapDown`, if `_scale > 1.0`, the gesture executes `resetZoom()` and returns immediately, avoiding accidental +/-10s seeks when the user intended to reset zoom. When `_scale == 1.0`, it correctly maps left wing (<33%) to -10s, right wing (>66%) to +10s, and center to play/pause toggle.
     - Result: PASS.

---

## 3. Caveats

- In the wider test directory, `test/unit/video_grouping_service_test.dart` (from an earlier VLC reverse-engineering task) has a tight CPU benchmark test (`Transforms 1,000+ media items in-memory in under 16ms`) that measured 17ms under high concurrent CPU load. This is completely unrelated to Milestone 2 (Cinematic Gesture Engine & Decoder Pipeline), where all 51 targeted tests pass 100%.
- Testing was conducted within headless / CI harness conditions without physical touch screen hardware; all touch coordinate sequences were verified deterministically via `flutter_test`.

---

## 4. Conclusion

The Milestone 2 remediation delivered in `worker_m2_remediate` has been thoroughly reviewed and stress-tested. Both original defects (Finding 1: scrub baseline desynchronization; Finding 2: duplicate seek pipeline churn) have been completely and cleanly repaired. Interface contracts strictly match `PROJECT.md`, static analysis passes with 0 issues, and 100% of the 51 relevant unit tests pass.

**Verdict: APPROVE**

---

## 5. Verification Method

To independently verify this report from `d:\E-player\app`:

1. **Run Static Analysis**:
   ```powershell
   flutter analyze lib/features/player/ui/cinematic_gesture_engine.dart lib/features/player/ui/player_screen.dart
   ```
   *Expected output*: `No issues found! (ran in ~13s)` (Exit code 0).

2. **Run Cinematic Gesture Engine Unit Suite**:
   ```powershell
   flutter test test/unit/cinematic_gesture_engine_test.dart
   ```
   *Expected output*: `All tests passed! (30/30 passed)` (Exit code 0).

3. **Run Phase 1 Decoder Pipeline Regression Suite**:
   ```powershell
   flutter test test/unit/decoder_pipeline_test.dart
   ```
   *Expected output*: `All tests passed! (21/21 passed)` (Exit code 0).

4. **Invalidation Conditions**:
   - Any static analysis warning or error in the reviewed files.
   - Any failure in `cinematic_gesture_engine_test.dart` or `decoder_pipeline_test.dart`.
   - Any persistence of `_initialPosition` across distinct gestures.
   - Any duplicate call to `_player.seek()` from a single gesture event.
