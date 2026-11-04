# Project: E-Player Clean-Room Media Library, Directory Watcher & File Browser

## Architecture
The Clean-Room implementation translates reverse-engineered VLC mechanics (VLC 3.0 XSPF, VLC 4.0 / libmedialibrary SQLite relational engine, Win32 `ReadDirectoryChangesW`, Qt directory navigation) into an authentic 4-layer Dart 3/Flutter architecture in `d:\E-player\app`:
1. **Models Layer (`app/lib/core/models/`)**:
   - `DeviceRecord`, `FolderRecord`, `MediaRecord`, `FileRecord`, `VideoTrackRecord`, `AudioTrackRecord`, `TaskRecord`, `FileSystemNode`, `WatcherEvent`.
2. **Persistence Layer (`app/lib/core/db/`)**:
   - `MediaLibraryDatabase`: Embedded SQLite with Write-Ahead Logging (`PRAGMA journal_mode = WAL;`), `PRAGMA foreign_keys = ON;`, `PRAGMA recursive_triggers = ON;`, `PRAGMA synchronous = NORMAL;`.
   - Relational Tables: `Device`, `Folder`, `Media`, `File`, `VideoTrack`, `AudioTrack`, `Task`.
   - Reactive Triggers: `trigger_device_presence_update` cascading `is_present` on device dismount/remount without metadata loss.
   - Virtual Tables: `MediaFts` (FTS5) with synchronous insert/update/delete triggers.
   - Performance Indexes: `idx_file_folder`, `idx_file_mrl`, `idx_media_type_present`, `idx_folder_path`, `idx_task_step`.
   - Repositories: `SqliteMediaLibraryRepository` (cursor pagination, path normalization, search, presence) and `SqliteTaskQueueRepository` (FSM queue).
3. **Domain Layer (`app/lib/features/*/domain/`)**:
   - `FileSystemService`: Platform drive discovery, breadcrumb parsing, `.nomedia` exclusion, hidden file filtering, extended-length path normalization (`\\?\`).
   - `StabilityProbeService`: Two-phase file stability prober (exclusive write-lock testing + exponential attribute invariance sampling).
   - `DirectoryWatcherService`: Multi-folder recursive watcher (`Directory.watch()`), sliding 500ms debounce window, event coalescing, kernel buffer overflow catch-up.
   - `DifferentialReconciler`: Fast in-memory set algebra reconciler ($Added = Disk \setminus DB$, $Removed = DB \setminus Disk$, $Modified = Disk \cap DB$).
   - `AutoRescanCoordinator`: Central FSM coordinator, device presence handler, task worker queue processor, periodic rescan.
4. **Presentation Layer (`app/lib/features/browser/ui/`)**:
   - `FileBrowserScreen`: Responsive 60/120 FPS file browser with root drive chip selector, interactive breadcrumbs, debounced search, grid/list view toggle, folder monitoring toggle, and media details inspection bottom sheet.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source | Status |
|---|---------|-------------|-----------|--------|--------|
| 1 | Forensic Evidence Extraction | Extraction of VLC 3.0/4.0 exhibits (schemas, watcher, discovery, UX) | M1 | REA Stage 1 | DONE |
| 2 | CoVe Adversarial Cross-Examination | Multi-turn Q&A across Cypher, Kronos, Aura, Forge resolving 4 failure points | M2 | REA Stage 2 | DONE |
| 3 | Clean-Room Blueprint & Guardrails | Master architectural blueprint, state machines, stack matrix, 3 Reflexion guardrails | M3 | REA Stages 3-4 | DONE |
| 4 | Clean-Room Production Implementation | 4-layer production implementation without placeholders, TODOs, or code clones | M4 | REA Stage 5 | DONE |
| 5 | Test Verification & REA Ledger | Automated verification with EPlayerTestHarness, zero test leaks, Master REA Ledger | M5 | REA Stage 6 | DONE |
| 6 | Quality Gate & Forensic Integrity Audit | Multi-reviewer, dual-challenger, and forensic auditor gate certification | M6 | Gate Iteration 2 | DONE (PASS) |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Forensic Evidence Extraction (R1) | Deconstruct VLC file browser, auto-rescan, and medialibrary; produce Exhibits A, B, C | none | DONE |
| M2 | CoVe Adversarial Cross-Examination (R2) | Multi-turn Q&A across 4 personas resolving concurrency, buffer overflow, scaling, paths | M1 | DONE |
| M3 | Clean-Room Blueprint & Guardrails (R3) | Complete file tree, state machines, stack adaptation matrix, 3 Reflexion guardrails | M2 | DONE |
| M4 | Production Clean-Room Implementation (R4) | Implementation in E-Player (Models, DB, Domain, UI), zero TODOs, 0 analyze issues | M3 | DONE |
| M5 | Test Lifecycle & REA Ledger (R5) | Verification with EPlayerTestHarness, cleanup invariant, Persistent REA Ledger | M4 | DONE |
| M6 | Quality Gate & Forensic Integrity Audit | Reviewers (APPROVE), Challengers (APPROVE), Forensic Auditor (CLEAN) | M5 | DONE (PASS) |
