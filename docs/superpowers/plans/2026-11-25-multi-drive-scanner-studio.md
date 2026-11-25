# Multi-Drive & Storage Scanner Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable simultaneous multi-drive discovery, unscanned-drive detection, safe root-level crawling, and batch scanning via a Cyberpunk Multi-Drive Scanner Studio UI on Windows (`.exe`) and cross-platform targets.

**Architecture:**
1. **Domain & Safe Crawler (`drive_scanner_models.dart`, `media_scanner_service.dart`):** Immutable `DriveVolumeInfo` model tracking drive root, label, indexed file count, and last-scanned timestamp. Replace `Directory.list(recursive: true)` with an iterative BFS directory queue wrapped in per-directory `try/catch` + Windows/OS protected-folder skip rules so scanning `C:\` or `D:\` never aborts on `PathAccessException` (`System Volume Information`, `$Recycle.Bin`).
2. **State & Persistence (`library_provider.dart`):** Track per-drive scan timestamps in `SharedPreferences`, compute live indexed file counts per drive from `_allFiles`, and expose `discoverDrives()`, `scanDrives(List<String>)`, `scanUnscannedDrives()`, and `scanAllDrives()`.
3. **Studio UI & Wiring (`drive_scanner_studio_sheet.dart`, `library_screen.dart`, `home_screen.dart`):** Cyberpunk Modal Sheet displaying detected drives with `Scanned (N files)` vs `Not Scanned Yet` badges, checkboxes, "Select Unscanned", "Select All", "Add Custom Folder...", OS-folder skip toggles, and live multi-drive progress feedback.

**Tech Stack:** Flutter 3.x+, Dart 3.x (`dart:io`, `dart:collection`), `provider`, `shared_preferences`, `file_picker`, `sqflite_common_ffi` (tests). Pure Dart only (FAT32 workspace, no native C++ plugins).

## Global Constraints
- Pure Dart only in `app/pubspec.yaml` (no new native plugins; workspace drive D:\ is FAT32).
- Always run Flutter commands with `--no-pub` (`cd app; flutter test --no-pub ...`, `cd app; flutter analyze --no-pub`).
- Preserve existing `MediaScannerService` and `LibraryProvider` method signatures so existing tests continue passing.

## Review Focus
1. **Protected OS directory access denied (`PathAccessException`):** Scanning `C:\` or `D:\` root hits `System Volume Information` or `$Recycle.Bin`; per-directory iterative traversal must skip/catch without aborting the drive scan.
2. **Windows drive case sensitivity (`C:\` vs `c:\`):** File paths in SQLite vs drive prefixes on Windows can differ in letter case; drive attribution must normalize/compare case-insensitively on Windows.
3. **Rescanning one drive must NOT break or delete nothing? Wait — `pruneMissingItems` on unplugged removable drives:** If a drive (`E:\`) is not currently mounted, `pruneMissingItems` should handle missing items cleanly, and scanning specific selected drives should index new files cleanly via `insertBatch`.
4. **Duplicate directory/drive selection:** Selecting both `D:\` and `D:\Movies` or duplicate paths must deduplicate or avoid crashing SQLite unique path constraints (`ConflictAlgorithm.replace` already handles upsert cleanly).
5. **Cancellation mid-scan across multiple drives:** Cancelling while scanning drive 1 of 3 must halt immediately and NOT start drive 2 or 3, leaving UI `isScanning == false`.

---

### Task 1: Drive Volume Models & Safe Multi-Drive Discovery/Crawler
- Create `app/lib/features/library/domain/drive_scanner_models.dart`
- Modify `app/lib/features/library/domain/media_scanner_service.dart`
- Test: `app/test/unit/multi_drive_scanner_test.dart`

### Task 2: LibraryProvider Multi-Drive Tracking & Batch Execution
- Modify `app/lib/features/library/domain/library_provider.dart`
- Test: `app/test/unit/multi_drive_scanner_test.dart`

### Task 3: Cyberpunk DriveScannerStudioSheet UI & Screen Wiring
- Create `app/lib/features/library/ui/drive_scanner_studio_sheet.dart`
- Modify `app/lib/features/library/ui/library_screen.dart`
- Modify `app/lib/features/home/ui/home_screen.dart`
- Test: `app/test/unit/drive_scanner_studio_widget_test.dart`

### Task 4: Full Verification Loop
- Run `flutter analyze --no-pub` (0 errors, 0 warnings)
- Run new tests + existing `test/media_scanner_search_test.dart`
- Commit to `main` (and report clearly).
