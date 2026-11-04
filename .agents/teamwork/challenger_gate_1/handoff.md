# Adversarial Concurrency & Stress Challenge Report (Gate 1)

**Verdict**: `APPROVE`  
**Agent**: `challenger_1` (Empirical Challenger: Concurrency, Race Conditions & Stress Testing)  
**Target Codebase**: `d:\E-player\app`  
**Date**: 2026-11-03T11:49:00Z  

---

## 1. Observation

### 1.1 Authored Adversarial Stress Harness
Authored and executed a dedicated 13-scenario adversarial stress suite in:
`d:\E-player\app\test\unit\clean_room_concurrency_stress_test.dart`

Verbatim test execution output:
```
00:00 +0: loading D:/E-player/app/test/unit/clean_room_concurrency_stress_test.dart
00:00 +0: (setUpAll)
00:00 +0: Adversarial Challenge 1: Filesystem Events & Sliding Debounce Stress 1.1 Sliding debounce window continuously resets on rapid writes within window
00:01 +1: Adversarial Challenge 1: Filesystem Events & Sliding Debounce Stress 1.2 Concurrent multi-file burst: creates, rapid modifies, and ephemeral deletes
00:01 +2: Adversarial Challenge 1: Filesystem Events & Sliding Debounce Stress 1.3 High-frequency burst triggers overflow recovery flag without crashing
00:02 +3: Adversarial Challenge 1: Filesystem Events & Sliding Debounce Stress 1.4 Disposing watcher with pending timers cancels all timers cleanly
00:03 +4: Adversarial Challenge 2: StabilityProbeService Stress 2.1 Actively locked file descriptor retries with backoff and fails if lock held
00:04 +5: Adversarial Challenge 2: StabilityProbeService Stress 2.2 File locked initially then released mid-probe successfully stabilizes
00:04 +6: Adversarial Challenge 2: StabilityProbeService Stress 2.3 Active streaming write (sequential size growth) delays stabilization until completion
00:05 +7: Adversarial Challenge 2: StabilityProbeService Stress 2.4 Unbounded size growth exceeds maxRetries and safely returns false
00:05 +8: Adversarial Challenge 2: StabilityProbeService Stress 2.5 File deleted during active probe returns false without unhandled exception
00:06 +9: Adversarial Challenge 3: SQLite Transaction Concurrency & WAL Mode 3.1 Concurrent reads during in-flight write transaction succeed without database lock
00:06 +10: Adversarial Challenge 3: SQLite Transaction Concurrency & WAL Mode 3.2 Interleaved high-concurrency read/write bombardment maintains ACID integrity
00:06 +11: Adversarial Challenge 3: SQLite Transaction Concurrency & WAL Mode 3.3 Transaction rollback under concurrent read contention leaves zero dirty reads
00:06 +12: Adversarial Challenge 3: SQLite Transaction Concurrency & WAL Mode 3.4 Device presence cascade triggers atomically toggle presence across hierarchy
00:07 +13: (tearDownAll)
00:07 +13: All tests passed!
```

### 1.2 Multi-Suite Dual-Challenger Verification
Executed both `clean_room_concurrency_stress_test.dart` and Challenger 2's `clean_room_adversarial_challenge_test.dart` concurrently:
```powershell
flutter test test/unit/clean_room_concurrency_stress_test.dart test/unit/clean_room_adversarial_challenge_test.dart
```
Verbatim result:
```
00:07 +28: All tests passed!
```
Total 28 adversarial tests passed in 7.0 seconds with zero failures.

### 1.3 Clean-Room Baseline Test Suite
Executed the worker's 7 clean-room test files:
```powershell
flutter test test/unit/media_library_database_test.dart test/unit/media_library_repository_test.dart test/unit/file_system_service_test.dart test/unit/stability_probe_service_test.dart test/unit/directory_watcher_service_test.dart test/unit/auto_rescan_coordinator_test.dart test/widgets/file_browser_screen_test.dart
```
Verbatim result:
```
00:31 +30: All tests passed!
```
Total 30/30 passed.

### 1.4 Static Analysis Baseline
Executed static analysis on the stress harness:
```powershell
dart analyze test/unit/clean_room_concurrency_stress_test.dart
```
Verbatim result:
```
Analyzing clean_room_concurrency_stress_test.dart...
No issues found!
```

### 1.5 Ephemeral Test Data Invariant
Inspected disk for leftover temporary directories and database files:
```powershell
Get-ChildItem -Path "d:\E-player\app" -Directory -Filter "*stress*" -Recurse
```
Verbatim result: 0 items returned.

---

## 2. Logic Chain

### 2.1 Filesystem Watcher Debouncing & Coalescing Under Stress
1. **Sliding vs. Fixed Debounce**:
   - `DirectoryWatcherService` (`app/lib/features/browser/domain/directory_watcher_service.dart`, line 130) executes `existing.timer?.cancel(); existing.timer = Timer(debounceDuration, () => _flushChange(path));` on every incoming event for an existing pending path.
   - In Test 1.1, writes occurred at t = 0ms, 100ms, 200ms, 300ms with a 300ms window. Under a fixed (non-sliding) timer, an event would have prematurely fired at t = 300ms. Empirically, zero events fired at t = 400ms. Only after writes ceased for > 300ms was exactly 1 coalesced event flushed at t = 750ms.
2. **Concurrent Multi-File Ingestion Burst**:
   - In Test 1.2, 10 persistent files (each receiving 3 rapid writes) and 10 ephemeral `.tmp` download files (created and deleted within 40ms) executed in parallel via `Future.wait`.
   - Lines 133–136 (`existing.type == WatcherChangeType.created && changeType == WatcherChangeType.deleted -> _pendingChanges.remove(path)`) cleanly pruned all 10 ephemeral files to NOOP (0 events emitted).
   - All 10 persistent files emitted exactly 1 `created` event.
3. **High-Frequency Rate Limiting & Teardown**:
   - Test 1.3 flooded 220 rapid modifications. The rate limiter (lines 88–98) verified that high I/O burst does not throw exceptions.
   - Test 1.4 generated 15 active pending timers and called `dispose()`. All timers cancelled cleanly with zero post-dispose event emissions or unhandled timer errors.

### 2.2 Stability Probing Under Active Locks & Sequential Size Growth
1. **Exclusive Lock Handling**:
   - `StabilityProbeService` (`app/lib/features/library/domain/services/stability_probe_service.dart`, lines 36–47) attempts `raf = await file.open(mode: FileMode.read); await raf.lock(FileLock.exclusive);`.
   - On Windows, when an external process holds an exclusive write lock, `FileSystemException` (sharing violation, Win32 error code 32) is caught and initiates exponential backoff: $T_{backoff}(n) = \min(2000, 200 \times 2^n)\text{ ms}$.
   - Test 2.1 held an exclusive lock; probe retried with backoff and returned `false`.
   - Test 2.2 held a lock for 120ms then released it in the background; probe encountered initial lock failures, backed off, successfully acquired the lock on retry, verified attribute invariance, and returned `true`.
2. **Active Streaming Write Growth**:
   - Lines 60–83 sample $(size_1, mtime_1)$, wait for `samplingDelay`, and sample $(size_2, mtime_2)$. If size or mtime differs, it resets and delays.
   - In Test 2.3, a simulated streaming downloader appended 4 consecutive chunks every 40ms. The probe refrained from declaring stability while writes continued, taking $\ge 140\text{ms}$ to return `true` only after writes fully settled.
   - Test 2.4 verified continuous unbounded streaming correctly hits `maxRetries` and safely returns `false`.
   - Test 2.5 verified deletion mid-probe returns `false` without unhandled exceptions.

### 2.3 SQLite Concurrency & WAL Mode
1. **WAL Snapshot Isolation Across Separate Handles**:
   - In SQLite WAL mode (`PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;`), concurrent readers do not block writers and writers do not block readers across separate connection handles.
   - In Test 3.1, a write transaction on connection 1 inserted 10 uncommitted media rows. An independent reader connection opened via `openDatabase(dbPath, readOnly: true, singleInstance: false)` executed 8 concurrent queries (`COUNT`, `SELECT LIKE`, `Folder`), successfully reading the pre-transaction baseline (20 rows) without experiencing database lock contention. Once committed, subsequent reads immediately saw 30 rows.
2. **Connection-Level Serialization on Shared Handle**:
   - On a shared `Database` instance (`singleInstance: true`), `sqflite` serializes operations via an internal Dart-level transaction lock. Test 3.2 verified that under high-concurrency interleaved bombardment (5 concurrent write transactions + 20 concurrent reader queries), all operations serialize safely without deadlocks, yielding exact expected counts (20 baseline + 25 new = 45 items).
3. **Rollback & Presence Cascade**:
   - Test 3.3 verified that aborted write transactions leave zero uncommitted dirty reads.
   - Test 3.4 verified that `trigger_device_presence_update` atomically toggles `is_present` on `Folder` and `Media` records when `Device.is_present` transitions between 0 and 1.

---

## 3. Caveats
1. **Single-Connection Dart Lock in sqflite**:
   - `sqflite` enforces a single-connection queue per `Database` object. If an application caller opens `db.transaction(...)` and within that same transaction invokes a method that queries `db` outside the transaction object (or awaits an external future dependent on an outside query), it will deadlock. The clean-room implementation avoids this by passing `Transaction txn` to repository internal executors (`_getExecutor([Transaction? txn])`).
   - For true non-blocking background crawler ingestion alongside active UI queries, background workers should either operate via `compute` / separate isolates with their own `openDatabase` connection or execute batch insertions in bounded cooperative slices.
2. **Platform FFI Native Assets**:
   - On Windows, running `flutter test` repeatedly while previous `flutter_tester.exe` instances are shutting down can result in `Access to sqlite3.dll is denied`. This is an operating system DLL lock artifact during Flutter build compilation, not an application code bug, and was resolved by terminating orphaned test processes.

---

## 4. Conclusion
The clean-room implementation demonstrates exceptional empirical robustness under severe adversarial stress testing. All concurrency, sliding debounce, stability probing, and SQLite transaction invariants hold true across 13 dedicated stress scenarios and 58+ full clean-room and adversarial tests.

**VERDICT**: `APPROVE`

---

## 5. Verification Method

To independently verify these findings:

1. **Run the Adversarial Concurrency Stress Suite**:
   ```powershell
   cd d:\E-player\app
   flutter test test/unit/clean_room_concurrency_stress_test.dart
   ```
   *Expected outcome*: 13/13 tests pass.

2. **Run Both Challenger Suites Simultaneously**:
   ```powershell
   cd d:\E-player\app
   flutter test test/unit/clean_room_concurrency_stress_test.dart test/unit/clean_room_adversarial_challenge_test.dart
   ```
   *Expected outcome*: 28/28 tests pass in ~7 seconds.

3. **Verify Static Analysis**:
   ```powershell
   cd d:\E-player\app
   dart analyze test/unit/clean_room_concurrency_stress_test.dart
   ```
   *Expected outcome*: `No issues found!`

4. **Verify Ephemeral Test Artifact Cleanup**:
   ```powershell
   Get-ChildItem -Path "d:\E-player\app" -Directory -Filter "*stress*" -Recurse
   ```
   *Expected outcome*: 0 items returned.
