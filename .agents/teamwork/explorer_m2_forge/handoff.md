# Milestone 2 Architectural Investigation & Handoff Report: Data Models, State Management & Service Layer

**Agent**: FORGE (`teamwork_explorer`)  
**Mission**: Milestone 2 Investigation ("Long-Press Multi-Select, Select All, Delete, and Move across Home & Library", Requirements R2 & R3)  
**Date**: 2026-11-05T05:20:00Z  
**Status**: Comprehensive Read-Only Architectural Synthesis Complete  

---

## 1. Observation

Direct investigation of the codebase and test harness yielded the following concrete observations:

### 1.1 Multi-Selection State Management Across Screens

#### A. Home Screen (`lib/features/home/ui/home_screen.dart`)
- **State Definition (lines 44–49)**:
  ```dart
  bool _isSelectionMode = false;
  final Set<String> _selectedGroupIds = {};
  final Set<String> _selectedItemPaths = {};

  int get _selectedCount => _selectedGroupIds.length + _selectedItemPaths.length;
  ```
- **Selection Lifecycle (lines 51–100)**:
  - `_exitSelectionMode()`: clears both `_selectedGroupIds` and `_selectedItemPaths`, sets `_isSelectionMode = false`.
  - `_toggleGroupSelection(String groupId)`: toggles membership in `_selectedGroupIds`; if `_selectedCount == 0`, auto-exits selection mode; if adding, ensures `_isSelectionMode = true`.
  - `_toggleItemSelection(String path)`: toggles membership in `_selectedItemPaths`; exits mode if count drops to zero.
  - `_toggleSelectAll(MediaGroupService groupService)`: compares `_selectedGroupIds.length` against `groupService.groups.length`; if all are selected, clears all selections and exits; otherwise adds all IDs to `_selectedGroupIds` and enables selection mode.
- **Contextual Action Bar (lines 220–261)**:
  - `_buildSelectionAppBar`: Renders close icon (`Icons.close`), title `'$_selectedCount Selected'`, `'Select All'` / `'None'` toggle button, Move icon button (`Icons.drive_file_move`), and Delete icon button (`Icons.delete`).
- **Back Navigation Guard (lines 287–291)**:
  - Wrapped in `PopScope(canPop: !_isSelectionMode, onPopInvokedWithResult: (didPop, _) { if (!didPop) _exitSelectionMode(); })` ensuring Android system back gesture cancels multi-selection without popping the screen.
- **Custom Group Cards (lines 1129–1211)**:
  - `InkWell`: `onLongPress: () => _toggleGroupSelection(group.id)`.
  - `onTap`: when `_isSelectionMode` is true, toggles group selection; when false, navigates to `FolderDetailScreen`.
  - Checkbox indicator: displays `Icons.check_circle` (selected) vs `Icons.radio_button_unchecked` (unselected).

#### B. Library Screen (`lib/features/library/ui/library_screen.dart`)
- **State Definition (lines 46–49)**:
  ```dart
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};
  ```
- **Selection Lifecycle (lines 50–91)**:
  - `_exitSelectionMode()`: resets mode and clears set.
  - `_togglePathSelection(String path)`: toggles path; if empty, sets `_isSelectionMode = false`.
  - `_toggleSelectAll(LibraryProvider provider)`: dynamically inspects `_selectedTab`:
    - Tab `'Folders'`: queries `provider.groupedFolders.keys.toList()`.
    - Tab `'Playlists'`: returns empty list `[]` (built-in playlists are non-selectable).
    - Other tabs (`'All'`, `'Videos'`, `'Audio'`): queries `provider.searchResults.map((i) => i.path).toList()`.
- **Contextual Action Bar (lines 201–250)**:
  - `_buildSelectionAppBar`: Displays `'${_selectedPaths.length} Selected'`, `'Select All'` / `'None'` toggle, Move icon (`Icons.drive_file_move`), Delete icon (`Icons.delete`), and exit button (`Icons.close`).
- **Floating Action Button & Strip Suppression (lines 358, 366–369)**:
  - FAB (`_buildFloatingScanButton`) and filter tabs strip are suppressed when `_isSelectionMode == true`.
- **Poster Cards & Folder Tiles (lines 1121–1134, 1557–1593)**:
  - Posters and folder rows provide `onLongPress: () => _togglePathSelection(...)`.
  - Tap toggles selection when `_isSelectionMode == true`, else opens player/folder.
  - Displays selection overlay tint and `Icons.check_circle` / `Icons.radio_button_unchecked`.

#### C. Folder Detail Screen (`lib/features/library/ui/folder_detail_screen.dart`)
- **State Definition (lines 40–43)**:
  ```dart
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};
  ```
- **Selection Lifecycle & Actions (lines 44–77, 203–245)**:
  - Manages `_selectedPaths` across grid and list items.
  - `_buildSelectionAppBar` renders counter, `'Select All'` / `'None'`, Move button, and Delete / Remove button.
  - Contextual adaptivity: if `widget.groupId != null`, delete action prompts "Remove from Group?", unlinking items without deleting from the library database. If `widget.groupId == null`, prompts "Delete Selected Items?" and removes from database.

---

### 1.2 Batch Deletion Architecture

#### A. Custom Groups Batch Deletion (`HomeScreen:102–150`)
- `_confirmDeleteSelected`:
  ```dart
  final groupsToDelete = List<String>.from(_selectedGroupIds);
  for (final id in groupsToDelete) {
    await groupService.deleteGroup(id);
  }
  ```
- When custom groups are deleted, `groupService.deleteGroup(id)` removes the group entry from `MediaGroupService._groups` and updates `SharedPreferences` (`_saveToPrefs()`).
- **Physical Media & SQLite Isolation**: Physical video files on disk and SQLite catalog rows in `DatabaseHelper` table `media_items` remain completely untouched (verified by E2E test 5.4).

#### B. Media Items Removal from Custom Group (`FolderDetailScreen:79–134`)
- When `widget.groupId != null`:
  ```dart
  await groupService.removeItemsFromGroup(widget.groupId!, toDelete);
  ```
- Unlinks paths from `group.itemPaths` in `MediaGroupService` in a single atomic memory and preferences transaction. Disk files and database rows are unaffected.

#### C. Media Items Batch Deletion from Library (`LibraryScreen:93–140` & `DatabaseHelper:94–106`)
- `_confirmDeleteSelected` in `LibraryScreen`:
  ```dart
  final Set<String> allFilePathsToDelete = {};
  for (final p in _selectedPaths) {
    allFilePathsToDelete.add(p);
    if (provider.groupedFolders.containsKey(p)) {
      for (final item in provider.groupedFolders[p]!) {
        allFilePathsToDelete.add(item.path);
      }
    }
  }
  await DatabaseHelper.instance.deleteBatch(allFilePathsToDelete.toList());
  await provider.refreshLibrary();
  ```
- `DatabaseHelper.deleteBatch` executes within an atomic SQLite transaction via `db.batch()`:
  ```dart
  Future<void> deleteBatch(List<String> paths) async {
    if (paths.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (var path in paths) {
      batch.delete('media_items', where: 'path = ?', whereArgs: [path]);
    }
    await batch.commit(noResult: true);
  }
  ```

---

### 1.3 Batch Move Architecture

#### A. Moving Media Items Between Custom Groups (`MediaGroupService:185–210`)
- `MediaGroupService.moveItemsBetweenGroups({required String fromGroupId, required String toGroupId, required List<String> paths})`:
  ```dart
  final fromIdx = _groups.indexWhere((g) => g.id == fromGroupId);
  final toIdx = _groups.indexWhere((g) => g.id == toGroupId);
  if (fromIdx != -1 && toIdx != -1 && paths.isNotEmpty) {
    final fromGroup = _groups[fromIdx];
    final toGroup = _groups[toIdx];
    final toRemove = paths.toSet();

    final updatedFromPaths = fromGroup.itemPaths.where((p) => !toRemove.contains(p)).toList();
    final updatedToPaths = List<String>.from(toGroup.itemPaths);
    for (final p in paths) {
      if (!updatedToPaths.contains(p)) {
        updatedToPaths.add(p);
      }
    }

    _groups[fromIdx] = fromGroup.copyWith(itemPaths: updatedFromPaths);
    _groups[toIdx] = toGroup.copyWith(itemPaths: updatedToPaths);
    await _saveToPrefs();
    notifyListeners();
  }
  ```
- **Atomicity**: Changes to both source and target groups are staged in-memory, committed to `SharedPreferences` in one JSON payload, and broadcast to listeners with a single `notifyListeners()`.
- **Deduplication**: Destination group only appends paths not already present (`if (!updatedToPaths.contains(p))`).

#### B. Adding Media Items to Custom Group (`MediaGroupService:144–162`)
- `addItemsToGroup(String groupId, List<String> paths)`:
  - Deduplicates incoming paths against existing `group.itemPaths`.
  - Atomically updates state and persists.

#### C. Move Dialog Interaction (`HomeScreen:152–218`, `LibraryScreen:142–200`, `FolderDetailScreen:136–201`)
- Opens an `AlertDialog` (`find.byType(Dialog)`) displaying all user custom groups from `groupService.groups`.
- If no groups exist, displays fallback notice: "No custom groups available. Create a group first."

---

### 1.4 Built-In Feature Protection Architecture

Built-in features are systematically protected through two complementary barriers:

1. **Gesture Layer Barrier (`onLongPress: null`)**:
   - `HomeScreen`:
     - "Create Group" Action Card (`line 998`): `onLongPress: null`
     - Tactical Plus Button (`line 1036`): `onLongPress: null`
     - "Videos" Action Card (`line 998`): `onLongPress: null`
     - History Container (`line 730`): `onLongPress: null`
     - Bento Category Cards (Movies, Series, Anime, Music) (`line 1451`): `onLongPress: null`
   - `LibraryScreen`:
     - Smart Playlists ("Favorite Media", "4K Ultra HD & HDR", "Recently Added Media", "Binge Watch Queue") (`line 1664`): `onLongPress: null, // Protected built-in smart playlist`
     - Category filter tabs (`lines 875–949`): use standard `onTap` with no long-press handler.
   - App Bars & Headers across all screens: Standard `AppBar` and text headers do not attach long-press detectors.

2. **State & Data Layer Barrier (Domain Whitelisting)**:
   - Selection sets exclusively accept identifiers that exist in managed domain collections:
     - `_selectedGroupIds`: only accepts IDs from `MediaGroupService.groups` (`grp_...`).
     - `_selectedItemPaths` / `_selectedPaths`: only accepts file/folder paths matching actual media entities.
   - Built-in features (Create Group card, Videos card, Smart Playlists) have no representation in `MediaGroupService.groups` or `DatabaseHelper`.
   - "Select All" algorithms strictly iterate only domain entities:
     - `groupService.groups.map((g) => g.id)` on Home.
     - `provider.searchResults.map((i) => i.path)` or `groupedFolders.keys` on Library.
     - On Library 'Playlists' tab, `visiblePaths = []` preventing any playlist selection.
   - Even under adversarial tampering, delete and move handlers only dispatch commands targeting `_selectedGroupIds` and `_selectedPaths`. Built-in features cannot be selected, deleted, or moved.

---

### 1.5 Service Layer Code Review & Verification Status

1. **Static Analysis**:
   - `dart analyze` across `d:\E-player\app`:
     - **Result: 0 Errors, 0 Warnings (`No issues found!`)**.
2. **Automated Test Suite Verification**:
   - All Milestone 2 requirements verified via `test/e2e/e2e_requirements_test.dart`:
     - `Feature 3: Long-Press Multi-Select on Home Screen (R2)`: **5/5 PASSED**
     - `Feature 4: Select All & Deselect on Home Screen (R2)`: **5/5 PASSED**
     - `Feature 5: Batch Delete on Home Screen (R2)`: **5/5 PASSED**
     - `Feature 6: Batch Move on Home Screen (R2)`: **5/5 PASSED**
     - `Feature 7: Built-in Feature Protection on Home Screen (R2)`: **5/5 PASSED**
     - `Feature 8: Multi-Select & Batch Actions in Library Section (R3)`: **5/5 PASSED**
     - `Scenario 2: Multi-Select -> Select All -> Batch Delete Flow`: **1/1 PASSED**
     - `Scenario 3: Built-in Feature Protection Against Selection`: **1/1 PASSED**
   - **Total Verified Tests for Milestone 2**: **32 of 32 tests PASSED (100% pass rate)**.

---

## 2. Logic Chain

1. **Observation 1.1** proves that multi-selection is managed as screen-scoped ephemeral state (`StatefulWidget` with `Set<String>`) in `HomeScreen`, `LibraryScreen`, and `FolderDetailScreen`.
   - *Inference*: Screen-local state aligns with Flutter's official ephemeral vs app state paradigm, avoids memory leaks across route transitions, and fulfills all contract expectations in `test/e2e/e2e_requirements_test.dart`. Introducing a global selection provider is not required and would introduce route-leakage risk without architectural benefit.

2. **Observation 1.2** proves that batch deletion has three distinct operational scopes:
   - Scope A (Custom Groups on Home): unlinks and deletes groups in `MediaGroupService` while leaving disk files and SQLite database rows untouched.
   - Scope B (Custom Groups in FolderDetail): unlinks paths from `MediaGroup` via `removeItemsFromGroup`.
   - Scope C (Library Catalog): executes SQLite batch deletion via `DatabaseHelper.instance.deleteBatch` and calls `provider.refreshLibrary()`.
   - *Inference*: The separation of custom collections (`MediaGroupService`) from physical/catalog storage (`DatabaseHelper`) is cleanly maintained. Deleting custom groups does not cause destructive data loss.

3. **Observation 1.3** proves that batch move between custom groups is implemented atomically via `moveItemsBetweenGroups` and `addItemsToGroup` in `MediaGroupService`.
   - *Inference*: Media paths are deduplicated, updates are staged in-memory, written in a single `SharedPreferences` write, and broadcast via `notifyListeners()`. Self-move is handled safely.

4. **Observation 1.4** demonstrates that built-in features are protected at both the gesture layer (`onLongPress: null`) and the domain state layer (whitelisted enumeration in `Select All` and batch actions).
   - *Inference*: Built-in cards and playlists are completely decoupled from selectable entities, fulfilling requirement R2 and passing Tier 1 Feature 7 tests and Tier 4 Scenario 3 tests.

5. **Observation 1.5** demonstrates that all 32 targeted tests for R2 and R3 in `test/e2e/e2e_requirements_test.dart` pass with 100% success and `dart analyze` reports zero issues.
   - *Inference*: The state models, service layer contracts, and UI components for Milestone 2 are already implemented and conform to the project specifications.

---

## 3. Caveats

1. **Windows Native Asset File Lock during rapid test re-runs**:
   - When executing `flutter test` repeatedly on Windows with `sqflite_common_ffi`, the background process takes 1–2 seconds to release the file handle on `D:\E-player\app\build\native_assets\windows\sqlite3.dll`.
   - Running subsequent `flutter test` commands without waiting can trigger: `Flutter failed to delete file at ... sqlite3.dll`.
   - *Workaround / Mitigation*: Include a brief pause (`Start-Sleep -Seconds 2`) or execute full test suites together rather than rapidly firing concurrent test runs.
2. **Soft Deletion (`TrashService`) vs Hard Database Delete (`DatabaseHelper`)**:
   - `TrashService` handles moving files to `.eplayer_trash/` for single-item context menus.
   - For batch deletion in Library (Requirement R3), the test suite verifies deletion from `DatabaseHelper` catalog (`DatabaseHelper.instance.deleteBatch`), not moving physical files to trash directory. This distinction is deliberate to match acceptance criteria.
3. **Sequential `deleteGroup` in loop**:
   - `HomeScreen:133–135` currently deletes multiple groups in a loop:
     ```dart
     for (final id in groupsToDelete) {
       await groupService.deleteGroup(id);
     }
     ```
   - While functionally correct and verified by tests, each call writes to `SharedPreferences`. Adding a batch `deleteGroups(Iterable<String> ids)` in `MediaGroupService` would optimize I/O efficiency.

---

## 4. Conclusion & Recommendations

### Architecture Verdict
Milestone 2 ("Long-Press Multi-Select, Select All, Delete, and Move across Home & Library") data models, state management, and service layer architecture are **fully designed, structurally sound, and 100% verified by automated E2E tests and static analysis**.

### Recommended Minor Enhancements (Non-breaking Quality Polish)

1. **`MediaGroupService` Batch Group Deletion (`lib/features/home/domain/media_group_service.dart`)**:
   Add an atomic batch deletion method:
   ```dart
   /// Removes multiple groups atomically in a single persistence write
   Future<void> deleteGroups(Iterable<String> ids) async {
     final toRemove = ids.toSet();
     if (toRemove.isEmpty) return;
     _groups.removeWhere((g) => toRemove.contains(g.id));
     await _saveToPrefs();
     notifyListeners();
   }
   ```

2. **`MediaGroupService` Self-Move Early Exit Guard**:
   In `moveItemsBetweenGroups`, add an explicit guard:
   ```dart
   if (fromGroupId == toGroupId) return;
   ```

3. **`LibraryProvider` Batch Removal Helper (`lib/features/library/domain/library_provider.dart`)**:
   Provide a first-class batch removal API on the provider:
   ```dart
   /// Atomically removes multiple media items from library database and refreshes catalog
   Future<void> removeItemsFromLibrary(Iterable<String> paths) async {
     final list = paths.toList();
     if (list.isEmpty) return;
     try {
       await DatabaseHelper.instance.deleteBatch(list);
     } catch (_) {}
     await _loadFromDB();
   }
   ```

---

## 5. Verification Method

To independently reproduce and verify this investigation:

1. **Static Analysis**:
   ```powershell
   cd d:\E-player\app
   dart analyze
   ```
   *Expected Result*: `No issues found!`

2. **Milestone 2 Automated Test Suite Verification**:
   Execute the individual feature suites from `d:\E-player\app`:
   ```powershell
   # Feature 3: Long-Press Multi-Select (Home)
   flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 3"

   # Feature 4: Select All & Deselect (Home)
   flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 4"

   # Feature 5: Batch Delete (Home)
   flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 5"

   # Feature 6: Batch Move (Home)
   flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 6"

   # Feature 7: Built-in Feature Protection (Home)
   flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 7"

   # Feature 8: Multi-Select & Batch Actions (Library)
   flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 8"

   # Real-World Workload Scenarios 2 & 3
   flutter test test/e2e/e2e_requirements_test.dart --name "Scenario [2-3]"
   ```
   *Expected Result*: All tests pass with 0 failures across all 32 test cases.

3. **Invalidation Conditions**:
   - Any test failure in Features 3–8.
   - Long-press on "Create Group" or "Videos" triggering `_isSelectionMode = true`.
   - Group deletion removing rows from `DatabaseHelper` table `media_items` or files from disk.
