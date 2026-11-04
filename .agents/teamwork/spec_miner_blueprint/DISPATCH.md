## 2026-11-03T10:05:45Z
You are spec_miner_blueprint, a clean-room systems architect adhering to the REA clean-room methodology.

Working directory: d:\E-player\.agents\teamwork\spec_miner_blueprint\
Original Request path: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
Evidence Dossier path: d:\E-player\.agents\teamwork\orchestrator_1\EVIDENCE_DOSSIER.md
CoVe Report path: d:\E-player\.agents\teamwork\cove_studio_critic\handoff.md
Please read these documents first.

Mission:
Execute Requirement R3: Stages 3 & 4 Clean-Room Architectural Blueprint & Pre-Mortem Guardrails.
Compile a comprehensive, production-ready Clean-Room Engineering Specification translating the verified VLC forensics and CoVe resolutions into the E-Player project architecture (`d:\E-player`).

Your specification MUST include:
1. Complete Module Structure & File Tree for E-Player:
   - Presentation Layer: `app/lib/features/browser/ui/file_browser_screen.dart`, widgets (breadcrumbs, folder item, media item details sheet).
   - Domain Layer: `app/lib/features/browser/domain/directory_watcher_service.dart`, `app/lib/features/library/domain/auto_rescan_coordinator.dart`, models.
   - Persistence Layer: `app/lib/core/db/media_library_database.dart` (SQLite schema, tables, triggers, migrations, pragmas), repository interfaces.
2. Complete Formal State Machines:
   - Discovery & Tree Navigation FSM.
   - Watcher Debouncing & Probing FSM.
   - Ingestion & Task Processing FSM.
   - Reconciliation & Presence Cascade FSM.
3. Stack Adaptation Matrix:
   - Detailed mapping from VLC (C++, libmedialibrary, Qt, Win32 APIs) -> E-Player (Flutter, Dart 3, sqflite/sqflite_common_ffi, Provider, Streams).
4. Three Explicit Reflexion Pre-Mortem Guardrails:
   - Guardrail 1: Algorithmic & Concurrency Traps (Two-phase exponential stability probing, lock backoff, deadlock prevention, batch transaction commits).
   - Guardrail 2: UX & Frame-Budget Traps (Cooperative microtask yielding, two-phase cursor pagination, zero main-isolate I/O, responsive breadcrumb navigation).
   - Guardrail 3: Stack Integration Traps (`sqflite` vs `sqflite_common_ffi` platform abstraction, Windows drive root discovery `C:\`, `D:\`, path separator normalization, EPlayerTestHarness integration).
5. Clean-Room Invariant: Zero open-source copy-paste; completely original architecture and implementation blueprints.

Write the specification to:
`d:\E-player\.agents\teamwork\spec_miner_blueprint\CLEAN_ROOM_SPECIFICATION.md`
and produce your handoff report in `d:\E-player\.agents\teamwork\spec_miner_blueprint\handoff.md`.
Notify the orchestrator when complete.
