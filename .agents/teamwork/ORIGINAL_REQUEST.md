# Original User Request

## 2026-10-22T10:41:35Z

The 4-Pillar Autonomous E-Player & AADB Engineering Studio (Vanguard, Oracle, Scholar, Artisan)

Autonomous execution of the E-Player cross-platform offline media player roadmap and AI-Assisted Advanced Bug Debugging (AADB) framework using an adversarial 4-character multi-agent studio (Vanguard, Oracle, Scholar, Artisan). The team executes the full looping workflow to advance the remaining core phases (Phase 1 Hardware/HW+ Decoders, Phase 3 Advanced Gestures, Phase 6 Native PiP, Phase 11 Tokenized Casting) while enforcing 5-phase semantic scanning, sandbox reproduction gates, 50+ source technical research, and Meta-ACH mutation-guided compliance hardening.

Working directory: D:\E-player
Integrity mode: development

## Constraints & Environment Guardrails
- **No C: Drive Access / Duplication:** Never copy, mirror, or write project files to `C:` drive under any circumstances. All development stays strictly inside `D:\E-player`.
- **No Local Compilation of Binaries:** Do NOT run `flutter build apk` or `flutter build windows` (Windows cross-drive symlink limitation). Verification is performed strictly via `flutter test`, `flutter analyze`, and targeted unit/integration suites.
- **Strict Offline Invariant:** 100% offline capability. No cloud processing, remote API dependencies, or external telemetry sinks.
- **Continuous Version Control:** All verified features, fixes, and tests must be committed and pushed to GitHub `origin/main`.
- **Zero Mocking / Placeholders:** Production-grade, strongly typed implementations only. No `// TODO`, mock stubs, or placeholder shortcuts.

## Requirements

### R1. Autonomous Roadmap Advancement (Phase 1, 3, 6, 11)
Implement and harden the remaining E-Player core subsystems:
1. **Phase 1 (Hardware / HW+ Decoders):** Dynamic fallback pipeline across Hardware, HW+, and Software decoders via `media_kit`/`libmpv` with zero stutter on 4K/HEVC/AV1 streams.
2. **Phase 3 (Cinematic Gesture Engine):** Multi-touch gesture handling (horizontal scrub with high-precision timestamp seek, vertical split brightness/volume sliders, double-tap jump, pinch-to-zoom).
3. **Phase 6 (Native Picture-in-Picture):** Android `AutoEnterPiP` / Desktop overlay window mode with HUD auto-dismiss and aspect-ratio preservation.
4. **Phase 11 (Tokenized Wireless Casting):** Real-time streaming sink negotiation (Chromecast, DLNA, Miracast, AirPlay) with subtitle muxing and synchronized seek/volume controls.

### R2. 5-Phase Semantic Scan & Invariant Mapping (Vanguard)
Execute automated repository intake, cataloging, weighted scan scheduling, and domain invariant extraction across every active subsystem. Map explicit and inferred domain invariants (`SOURCE_TYPE = INFERRED`) to proactively detect semantic defects, A/V sync drift, and frame-queue memory leaks.

### R3. Deterministic Sandbox Reproduction & Multi-Modal Testing (Oracle)
Validate all candidate issues in an isolated sandbox before code modification. Synthesize and execute tests across the 7 E-Player test layers (Static, Unit, Integration, E2E, Stress, Offline, Regression) and AADB advanced testing (Property-Based Testing, Metamorphic Relations, Differential Testing). Enforce reproduction at least twice with captured telemetry before logging into the Problem Ledger (`EP-[CAT]-[NUM]`).

### R4. 50+ Primary Source Technical Research Gate (Scholar)
For every non-trivial P0/P1/P2 issue, conduct deep research across 50+ distinct, authoritative primary sources (official Flutter/Dart, libmpv, FFmpeg, ONNX Runtime, platform SDKs, CVEs, and vendor hardware specs). Filter out SEO spam, duplicate mirrors, and AI content farms. Log findings with authoritative citations and structured root-cause analysis.

### R5. Minimal Safe APR Patching & Meta-ACH Mutation Hardening (Artisan)
Apply minimal safe code modifications (`1. one-file minimal change -> 2. minimal multi-file change -> 3. structural change only if necessary`). Implement Meta-ACH mutation-guided compliance hardening by synthesizing meaningful business-logic mutants, verifying they alter behavior, and proving the regression test kills the mutant. Run clean-room verification against all 18 release gates.

## Acceptance Criteria

### Test & Static Analysis Verification
- [ ] `flutter test` passes 100% with zero failing or skipped tests (baseline: 67/67 passing).
- [ ] `flutter analyze` reports 0 errors and 0 warnings across the entire repository.
- [ ] Every bug fix and newly implemented phase feature includes automated unit/widget/integration tests.
- [ ] At least one non-equivalent mutant per bug fix is killed by the test suite.

### Architecture & System Invariants
- [ ] Zero execution of `flutter build apk` or `flutter build windows` on `D:` drive.
- [ ] Zero files modified or copied outside `D:\E-player`.
- [ ] Video color adjustments and geometric transforms remain hardware-accelerated inside `libmpv` without redundant Flutter raster filtering.
- [ ] Background threads, timers, and streaming subscriptions cleanly cancel upon widget/sheet disposal.
- [ ] All changes committed and pushed to `origin/main` with clean working tree.


## 2026-10-22T10:58:01Z

This is a single self-contained fix; keep it small and focused.

Reverse engineer the "Group videos" feature (with Group by Name and Group by Folder) from VLC Media Player (`C:\Program Files (x86)\VideoLAN\VLC`) and implement a production-grade automated media grouping engine in E-Player (`d:\E-player\app`).

Working directory: d:\E-player\app
Integrity mode: development

## Requirements

### R1. Automated Video Grouping Service
Implement an in-memory grouping engine supporting three distinct modes:
- `GroupMode.none`: Standard flat media list.
- `GroupMode.byFolder`: Groups discovered videos by parent directory name/path, displaying folder cards with item count, total duration, and thumbnail preview.
- `GroupMode.byName`: Smart title and prefix clustering that automatically detects common series stems, episode patterns (e.g. S01E01, Ep 01, Part 1), and franchise names when 2 or more videos share a common root.

### R2. Global UI Grouping Controls
Integrate video grouping selectors and collapsible group views across all primary media browsing screens:
- Library Screen (library_screen.dart): Top-bar grouping selector with smooth animated grid transitions.
- Home Screen (home_screen.dart): Grouping options for recent and indexed videos.
- Folder Browser Screen: Directory-aware grouping hierarchy.

### R3. Preferences Persistence & Memory Efficiency
- Persist the user's active grouping mode via SharedPreferences.
- Perform grouping transformations in-memory with sub-16ms latency without re-triggering filesystem scans.

### R4. Dual-Workspace Parity
Ensure all code edits are strictly synchronized between d:\E-player\app and C:\E-player\app.

## Acceptance Criteria

### Functional Accuracy
- [ ] Folder grouping correctly groups videos by parent folder without path truncation or collisions.
- [ ] Name grouping clusters related multi-part videos and TV show episodes into dedicated collections with individual items accessible upon expansion.
- [ ] Toggling between None, By Folder, and By Name updates the UI instantly without flickering or re-reading files from disk.
- [ ] Selected grouping mode persists across app restarts.

### Code Quality & Stability
- [ ] Zero static analysis errors (`flutter analyze --no-pub` passes with 0 issues).
- [ ] Zero placeholders or `// TODO` comments; full error handling for empty directories or single-file groups.
- [ ] Both d:\E-player\app and C:\E-player\app remain 100% synchronized and buildable.


## 2026-11-03T04:11:46Z

System server has restarted. Please resume sentinel monitoring and execution:
1. Verify Gen 2 Orchestrator (29f627ce-3157-4f8d-bf56-5c2402ce649c) and subagents (such as worker_m3_pip). If any subagents were halted by the restart, revive or relaunch them as needed.
2. Reschedule your monitoring and liveness crons.
3. Continue driving Milestone 3 (Native Picture-in-Picture), Milestone 4 (Tokenized Wireless Casting), and Milestone 5 (100% E2E Verification & Meta-ACH Hardening) to full completion under the existing strict guardrails (100% offline, strictly within D:\E-player, zero binary builds).
