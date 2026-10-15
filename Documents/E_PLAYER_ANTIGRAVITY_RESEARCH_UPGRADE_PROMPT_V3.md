# E-PLAYER ANTIGRAVITY V3 — RESEARCH-DRIVEN FEATURE IMPROVEMENT MASTER PROMPT

You are taking over a mid-process E-Player repository. You have the E-Player PRD/implementation documents, UI/UX Stitch package, current progress report, and the 11-page Advanced Media Player Blueprint.

## RULE 0 — DO NOT RESTART
Inspect first. Preserve working media_kit/libmpv, C++ FFI, PlayerScreen, subtitle/libass and Enhancement Studio. Refactor only when evidence requires it.

## RULE 1 — RESEARCH CORRECTIONS
Treat the new blueprint as a high-value engineering source, not as absolute truth. Do not turn its risky claims into hard requirements. In particular:
- HW+ must be capability/backend based, not assumed universal.
- codec/container support must be tested from shipped binaries.
- proprietary codec licensing must be audited.
- native OS PiP is the default; overlay permission is not the default PiP path.
- player pooling is only for multi-video feeds.
- benchmark numbers are targets, not guarantees.
- Python is development/model tooling, not the mandatory production runtime on both mobile platforms.

## RULE 2 — START WITH A FORENSIC AUDIT
Inspect repository, dependencies, platform code, native binaries, media_kit versions, C++ FFI, AI simulation code, tests, Android/iOS projects. Produce a feature matrix: REAL/PARTIAL/MOCK/MISSING.

## RULE 3 — IMPLEMENT IN THIS ORDER
1. playback hardening
2. decoder capability modes
3. speed/pitch/aspect/gestures
4. subtitle controls
5. audio DSP
6. background/PiP
7. media library
8. vault/trash
9. network playback
10. NAS
11. casting
12. real ONNX AI export
13. RIFE
14. AI audio
15. 2D→3D
16. adaptive quality
17. security/compliance
18. full regression

## RULE 4 — REAL FUNCTIONALITY
Every new UI control must connect to real state. Do not create decorative toggles. Remove/clearly label simulated AI once real inference replaces it.

## RULE 5 — PLAYBACK
Implement capability-aware Auto/Hardware/Hybrid/Software modes. Record actual decoder/provider and fallback reason. Test lifecycle edge cases: first surface, first seek, orientation, background/foreground, track changes.

## RULE 6 — SUBTITLES
Preserve libass. Add delay, style, outline, encoding and provider abstraction. Online subtitles are optional and user-initiated.

## RULE 7 — AUDIO
Implement 5-band EQ, presets, Bass Boost, limiter/preamp, dialogue/night mode and optional virtualizer. Measure clipping and CPU cost.

## RULE 8 — PRIVACY
Never use .nomedia or hidden folders as “encryption.” Use platform secure key storage + authenticated encryption + encrypted metadata + recovery/trash.

## RULE 9 — CAST
For local files, use a short-lived tokenized LAN server with no directory listing and one authorized media resource.

## RULE 10 — AI
Start with offline export. Required proof:
video → native decode → bounded frame buffer → real ONNX model → encode → original/enhanced audio → mux → validate.
No fake AI filters.

## RULE 11 — PERFORMANCE
Measure before optimizing. Keep UI responsive. Keep queues bounded. Seek/cancel must invalidate stale AI work.

## RULE 12 — TEST EVERYTHING
Unit + integration + real-device + stress + offline + memory + thermal + A/V sync + visual regression.

## LOOP
INSPECT → BUILD → RUN → TEST → FIND FAILURE → REPRODUCE → ROOT-CAUSE → IMPLEMENT → TEST → REGRESSION → RUN AGAIN.

For non-trivial problems use the project's looping research protocol: deeply research the specific problem, compare authoritative approaches, choose an E-Player-specific solution, then prove it with regression tests.

## DONE
Only declare completion when:
- existing playback remains stable;
- major feature gaps are closed;
- real AI export works;
- no false feature states remain;
- security tests pass;
- supported-device matrix passes or limitations are documented;
- clean-install/offline regression passes.
