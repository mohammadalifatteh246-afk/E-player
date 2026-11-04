Operate as an elite 4-Character Clean-Room Engineering Studio (SPP + CoVe + Reflexion + MCP) to reverse-engineer how the File Browser, Auto-rescan, and Media Library / Media Library Folders work in VLC (path: C:\Program Files (x86)\VideoLAN\VLC), gather live empirical evidence, and build a production-grade clean-room equivalent for the E-Player project adhering to the 6-stage REA operational pipeline.

Working directory: d:\E-player
Integrity mode: demo
The team must NOT: copy code from existing open-source projects for core logic

## Requirements

### R1. Forensic Evidence Extraction & Deconstruction (Stage 1)
Inspect and deconstruct how the File Browser, Auto-rescan, and Media Library / Media Library Folders work in VLC by examining both the local installation at `C:\Program Files (x86)\VideoLAN\VLC` and VLC's open-source architecture/code. Produce a structured Evidence Dossier with concrete exhibits for:
- Exhibit A — Data & State Architecture (schemas, state trees, data flow)
- Exhibit B — Execution Lifecycle & Algorithms (file discovery, directory watcher, auto-rescan triggers, library indexing)
- Exhibit C — Performance & UX mechanics
Explicitly label every exhibit as `[Verified via MCP/Source Inspection]` or `[Inferred via Behavioral/Architectural Pattern]`.

### R2. Chain-of-Verification (CoVe) Adversarial Cross-Examination (Stage 2)
Conduct a multi-turn adversarial Q&A across the 4 specialist personas (Cypher, Kronos, Aura, Forge) to interrogate at least 3 critical failure points (concurrency, state desynchronization, memory scaling, edge-case user inputs) until a watertight architecture is established.

### R3. Clean-Room Architectural Blueprint & Pre-Mortem Guardrails (Stages 3 & 4)
Compile a Clean-Room Engineering Specification translating verified mechanics into the E-Player project architecture (module structure, state machines, stack adaptation matrix). Establish 3 explicit Reflexion pre-mortem guardrails covering algorithmic/concurrency traps, UX/frame-budget traps, and stack integration traps before implementing.

### R4. Production Clean-Room Implementation in E-Player (Stage 5)
Implement a production-grade File Browser, Auto-rescan (directory watcher), and Media Library feature directly integrated into the E-Player project codebase (`d:\E-player`). Deliverables must include the presentation layer (File Browser UI), domain services (directory watcher, auto-rescan coordination), and data persistence (media library indexing with SQLite), with full error handling, lifecycle teardown, and zero placeholder or `// TODO` comments.

### R5. Test Data Lifecycle & Automated Verification (Stage 6)
Verify the implementation using the project's existing test harness (`EPlayerTestHarness`, `app/test/`) across unit, integration, and edge-case scenarios. All demo or test data created during testing must be strictly temporary and completely removed after testing. Conclude with the Persistent REA Ledger detailing deconstructed mechanics, implemented files/interfaces, and a Reflexion self-correction rule.

## Acceptance Criteria

### Forensic Evidence & Clean-Room Architecture
- [ ] Evidence Dossier details VLC's file browser, directory watcher / auto-rescan mechanisms, and media library storage with concrete exhibits labeled as verified or inferred.
- [ ] CoVe adversarial Q&A resolves at least 3 critical failure points with evidence-backed architectural adaptations for E-Player.
- [ ] Clean-room engineering specification provides complete file tree, state machine, and stack adaptation matrix without copying open-source core logic.

### Feature Deliverables & Code Quality
- [ ] File Browser UI allows interactive file system navigation, directory selection, and media file inspection in E-Player.
- [ ] Auto-rescan service monitors configured media library folders, reacts to file additions, modifications, and deletions, and updates library state.
- [ ] Media Library state and indexed metadata persist across restarts in local SQLite storage.
- [ ] Codebase passes static analysis (`dart analyze`) with zero errors and zero warnings.
- [ ] Implementation contains zero `// TODO` comments or dummy placeholders.

### Verification & Test Data Invariant
- [ ] Automated tests in `app/test/` pass and verify file browsing, auto-rescan detection, and SQLite media library indexing using `EPlayerTestHarness`.
- [ ] No temporary demo files, test folders, or test media artifacts remain on disk or in the repository after testing completes.
- [ ] Persistent REA Ledger records verified mechanics, implemented files, and the Reflexion self-correction rule.
