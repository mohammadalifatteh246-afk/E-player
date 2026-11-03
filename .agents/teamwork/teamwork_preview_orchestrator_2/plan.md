# Step-by-Step Orchestration Plan — Generation 2

## Objective
Drive autonomous execution of E-Player roadmap across remaining milestones: M2 remediation & gate pass, M3 (Native PiP), M4 (Tokenized Wireless Casting), and M5 (100% E2E verification, Meta-ACH hardening, git commit/push to origin/main).

---

### Step 1: Milestone 2 Remediation & Gate Certification
1. Dispatch `worker_m2_remediate`:
   - Fix `_initialPosition` reset across scrubs in `CinematicGestureEngine` (lines 164, 235–243, 284–298, 430–432).
   - Fix duplicate seek in `player_screen.dart` (rely on `seekCommitEvents` stream subscription or remove redundant call).
   - Add unit test for sequential scrubbing relative to current position.
   - Run `flutter analyze` and `flutter test test/unit/cinematic_gesture_engine_test.dart test/unit/decoder_pipeline_test.dart`.
2. Dispatch Gate Verification for Milestone 2:
   - `reviewer_m2_gate`: Review fixes, verify static analysis and tests.
   - `challenger_m2_gate`: Run consecutive scrub stress tests.
   - `auditor_m2_gate`: Verify zero mock, offline invariants, authentic implementation.
3. Record Gate Result **PASS** in `GATE_STATUS.md`.

---

### Step 2: Milestone 3 — Phase 6 Native Picture-in-Picture
1. Dispatch `explorer_m3_pip`:
   - Analyze Android AutoEnterPiP requirements (API 31+ `setPictureInPictureParams`), `MainActivity.kt` MethodChannel (`com.example.app/pip`).
   - Analyze aspect ratio clamping logic (`[1/2.39, 2.39/1]`).
   - Analyze HUD auto-dismiss on PiP enter (`onPipEntered` / `onPipExited`).
   - Analyze Desktop overlay window mode for Windows/macOS.
   - Specify file modifications and interface contracts matching `PROJECT.md`.
2. Dispatch `worker_m3_pip`:
   - Implement `app/lib/features/pip/domain/pip_service.dart`.
   - Implement `app/lib/features/pip/data/pip_platform_bridge.dart`.
   - Update `app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`.
   - Integrate PiP enter/exit hooks into `app/lib/features/player/ui/player_screen.dart`.
   - Write comprehensive unit tests in `app/test/unit/pip_service_test.dart`.
   - Run `flutter analyze` and tests.
3. Dispatch 5-agent Gate for Milestone 3 (Reviewers x2, Challengers x2, Forensic Auditor).
4. Record Gate Result **PASS** in `GATE_STATUS.md`.

---

### Step 3: Milestone 4 — Phase 11 Tokenized Wireless Casting
1. Dispatch `explorer_m4_cast`:
   - Analyze `LocalStreamingDaemon` requirements: ephemeral LAN `HttpServer`, 32-byte session token validation, HTTP 206 Partial Content Range streaming.
   - Analyze WebVTT subtitle sidecar delivery endpoint (`/cast/{session_token}/subtitles/...`).
   - Analyze `CastService` discovery (mDNS / SSDP multi-protocol negotiation for Chromecast, DLNA, Miracast, AirPlay) and bi-directional state sync.
   - Analyze strict offline LAN invariant.
2. Dispatch `worker_m4_cast`:
   - Implement `app/lib/features/casting/domain/local_streaming_daemon.dart`.
   - Implement `app/lib/features/casting/domain/cast_service.dart`.
   - Implement casting UI sheets / controls if specified.
   - Write unit tests in `app/test/unit/local_streaming_daemon_test.dart` and `cast_service_test.dart`.
   - Run `flutter analyze` and tests.
3. Dispatch 5-agent Gate for Milestone 4 (Reviewers x2, Challengers x2, Forensic Auditor).
4. Record Gate Result **PASS** in `GATE_STATUS.md`.

---

### Step 4: Milestone 5 — 100% E2E Verification & Meta-ACH Hardening
1. Dispatch `worker_m5_e2e_verify`:
   - Execute complete E2E test suite (`flutter test test/e2e/`).
   - Execute combined regression suite across all unit and integration tests.
   - Execute Meta-ACH mutation verification (synthesize non-equivalent mutants, verify tests kill them).
   - Verify `flutter analyze` reports 0 errors and 0 warnings.
2. Dispatch Gate Verification for Milestone 5:
   - Reviewer, Challenger, and Forensic Auditor verification.
3. Record Gate Result **PASS** in `GATE_STATUS.md`.

---

### Step 5: Version Control & Final Reporting
1. Dispatch worker to perform git status check, stage verified changes, commit with clean semantic messages, and push to `origin/main`.
2. Synthesize results, update `PROJECT.md` milestone statuses to DONE.
3. Notify Sentinel / Parent caller with comprehensive victory report.
