# Explorer Handoff Report: Milestone 2 Test Suite Alignment, Specifications & Edge Cases

**Explorer**: KRONOS (`teamwork_explorer` — Test Specifications & E2E Alignment)  
**Mission**: Milestone 2: "Long-Press Multi-Select, Select All, Delete, and Move (Home & Library)" covering requirements R2 and R3  
**Date**: 2026-11-05T05:30:00Z  
**Status**: COMPLETE (Read-Only Test Suite & Edge Case Deep Dive)  
**Working Directory**: `d:\E-player\.agents\teamwork\explorer_m2_kronos\`  

---

## 1. Observation

Direct inspection of `test/e2e/e2e_requirements_test.dart`, `app/lib/features/home/ui/home_screen.dart`, `app/lib/features/library/ui/library_screen.dart`, `app/lib/features/library/ui/folder_detail_screen.dart`, and execution of the automated test runner yielded the following verified facts:

### 1.1 Test Suite Structure & Requirements Mapping
The authoritative test suite is located at `test/e2e/e2e_requirements_test.dart` (1,824 lines, 84 test cases across 4 tiers):
- **Tier 1 (Feature Coverage F1–F12)**: 60 tests (5 tests per feature).
  - Feature 3: Long-Press Multi-Select on Home Screen (`R2`, tests 3.1–3.5, lines 310–432)
  - Feature 4: Select All & Deselect on Home Screen (`R2`, tests 4.1–4.5, lines 438–587)
  - Feature 5: Batch Delete on Home Screen (`R2`, tests 5.1–5.5, lines 593–694)
  - Feature 6: Batch Move on Home Screen (`R2`, tests 6.1–6.5, lines 700–800)
  - Feature 7: Built-in Feature Protection on Home Screen (`R2`, tests 7.1–7.5, lines 806–897)
  - Feature 8: Multi-Select & Batch Actions in Library Section (`R3`, tests 8.1–8.5, lines 903–999)
- **Tier 2 (Boundary & Corner Cases)**: 13 tests (lines 1324–1504).
  - Test 2.8: Multi-select with empty selection handles actions as safe no-op.
  - Test 2.9: Select All on empty container maintains 0 selected items.
  - Test 2.10: Adding non-existent file paths to group persists path strings safely.
  - Test 2.11: Adding duplicate paths to group enforces set uniqueness.
  - Test 2.12: Custom group title with special characters, unicode, emoji, and 500+ chars.
  - Test 2.13: Moving items to the same group is idempotent and does not duplicate.
- **Tier 3 (Cross-Feature Interactions)**: 6 tests (lines 1509–1628).
  - Test 3.1: Create group -> Multi-select items in Library -> Move to group -> Verify group count and persistence.
  - Test 3.2: Multi-select custom groups on Home -> Batch delete -> Verify Library items remain unaffected.
  - Test 3.4: Filter Media Library to video-only -> Select videos -> Move/add to custom group.
  - Test 3.5: Empty group created -> Add button media import -> Items selected -> Batch deleted -> Group returns to empty state.
  - Test 3.6: Delete multiple custom groups updates groups list and active selection state is cleared.
- **Tier 4 (Real-World Workload Scenarios)**: 5 tests (lines 1633–1822).
  - Scenario 2: User long-presses custom group, taps Select All, deselects 1, batch deletes remainder (lines 1675–1708).
  - Scenario 3: User attempts long-press on Create Group & Videos cards; verifies built-in protection (lines 1713–1740).

---

### 1.2 Exact Test Expectations: Widget Keys, Text Labels, Icons, and Semantics

The E2E tests interact with and assert on the following specific widgets, keys, labels, and icons:

| Test Reference | User Action / Trigger | Exact Widget / Finder Expected | Match Semantics | Target File & Lines in Implementation |
|---|---|---|---|---|
| **Test 3.1** | Long-press custom group card | `find.text('Custom Group Alpha')` | Exact Text | `home_screen.dart:1179` |
| **Test 3.1** | Verify selection active | Text containing `'Selected'` OR `Icons.check_circle` OR `Icons.checklist_rtl_rounded` | `find.byWidgetPredicate` | `home_screen.dart:237, 1203` |
| **Test 3.2** | Verify count on Home | `find.textContaining('1 Selected')` | String contains | `home_screen.dart:237` |
| **Test 3.3** | Tap 2nd group | `find.text('Group B')` -> `find.textContaining('2 Selected')` | String contains | `home_screen.dart:237, 1134` |
| **Test 3.4** | Deselect active group | `find.text('Solo Group')` -> `find.textContaining('1 Selected') findsNothing` | `findsNothing` | `home_screen.dart:64, 237` |
| **Test 3.5** | Exit selection via close | `find.byIcon(Icons.close)` | Icon finder | `home_screen.dart:232` |
| **Test 4.1** | Find "Select All" | `w is Text && (w.data == 'Select All' \|\| w.data == 'All')` OR `IconButton(tooltip: 'Select All')` | `find.byWidgetPredicate` | `home_screen.dart:245` |
| **Test 4.1** | Verify count after Select All | `find.textContaining('3 Selected')` | String contains | `home_screen.dart:237` |
| **Test 4.2** | Verify exact counter | `find.text('2 Selected')` | **Exact Text Match (`findsOneWidget`)** | `home_screen.dart:237` |
| **Test 4.3** | Toggle None | `w is Text && (w.data == 'None' \|\| w.data == 'Select All' \|\| w.data == 'All')` | `find.byWidgetPredicate` | `home_screen.dart:245` |
| **Test 4.4** | Deselect single item after All | `find.text('Item 2')` -> counter drops to `'2 Selected'` | String contains | `home_screen.dart:237` |
| **Test 4.5** | Find batch action buttons | `Icons.delete` or `Icons.delete_outline` or text containing `'delete'` | `find.byWidgetPredicate` | `home_screen.dart:255` |
| **Test 5.1** | Tap Delete button | `find.byIcon(Icons.delete)` -> `find.byType(AlertDialog)` | Widget Type | `home_screen.dart:110, 255` |
| **Test 5.3** | Deleted group removal | `find.text('Ghost Group') findsNothing` | Text absence | `home_screen.dart:648` |
| **Test 6.1** | Tap Move button | `find.byIcon(Icons.drive_file_move)` -> `find.byType(Dialog)` | Widget Type | `home_screen.dart:155, 250` |
| **Test 7.1** | Long-press "Create Group" | `find.text('Create Group')` -> `find.textContaining('Selected') findsNothing` | Protected feature | `home_screen.dart:998` |
| **Test 7.2** | Long-press "Videos" | `find.text('Videos')` -> `find.textContaining('Selected') findsNothing` | Protected feature | `home_screen.dart:998` |
| **Test 7.3** | Long-press Category chip | `find.text('All')` -> `find.textContaining('Selected') findsNothing` | Protected feature | `home_screen.dart:544` |
| **Test 7.4** | Long-press Header | `find.text('History')` -> `find.textContaining('Selected') findsNothing` | Protected feature | `home_screen.dart:612` |
| **Test 7.5** | Delete/Move built-in protection | `find.text('Create Group') findsOneWidget`, `find.text('Videos') findsOneWidget` | Retained visibility | `home_screen.dart:998` |
| **Test 8.1** | Long-press Library item | `find.text('lib_video_1.mp4')` -> `find.textContaining('Selected') findsWidgets` | String contains | `library_screen.dart:1122, 1224` |
| **Test 8.2** | Inactive Selection Bar | `find.textContaining('0 Selected') findsNothing` | Hidden when inactive | `library_screen.dart:224` |
| **Test 8.3** | Library Select All | `find.text('Select All')` | Exact Text | `library_screen.dart:233` |
| **Scenario 2**| Multi-Select & Batch Delete | `find.text('Collection A')`, `find.textContaining('1 Selected')` | Real-world flow | `home_screen.dart:1131` |
| **Scenario 3**| Built-in protection flow | Long-press on `'Create Group'`, `'Videos'`, `'All'` -> 0 selected | Real-world flow | `home_screen.dart:544, 998` |

---

### 1.3 Dialogs, Bottom Sheets & Modals Specification

The tests explicitly interact with and expect the following dialog signatures:

#### A. Delete Confirmation Dialog (`AlertDialog`)
- **HomeScreen** (`home_screen.dart:108–150`):
  - Component: `AlertDialog`
  - Title: `'Delete Selected Items?'`
  - Content: `'Are you sure you want to delete $count selected item(s)? Custom groups will be removed without deleting physical media files.'`
  - Actions:
    - `TextButton` labeled `'Cancel'`
    - `ElevatedButton` labeled `'Delete'` (background color: `EDesign.danger`)
  - Execution: Deletes groups from `groupService.deleteGroup(...)`; if any media paths were selected, invokes `DatabaseHelper.instance.deleteBatch(...)` and `provider.refreshLibrary()`. Exits selection mode upon completion.
- **LibraryScreen** (`library_screen.dart:95–139`):
  - Component: `AlertDialog`
  - Title: `'Delete Selected Items?'`
  - Content: `'Are you sure you want to permanently delete $count selected item(s) from your media library?'`
  - Actions: `'Cancel'` (`TextButton`) and `'Delete'` (`ElevatedButton`)
  - Execution: Expands folder paths to file items via `provider.groupedFolders`, executes `DatabaseHelper.instance.deleteBatch(...)`, and refreshes library.
- **FolderDetailScreen** (`folder_detail_screen.dart:88–133`):
  - Contextual Behavior:
    - If `widget.groupId != null` (inside a custom group): Title is `'Remove from Group?'`, content is `'Remove $count selected item(s) from this group?'`, action button is `'Remove'`. Invokes `groupService.removeItemsFromGroup(widget.groupId!, toDelete)`. **Does not touch SQLite DB or physical files**.
    - If `widget.groupId == null` (inside a regular library folder): Title is `'Delete Selected Items?'`, action button is `'Delete'`. Invokes `DatabaseHelper.instance.deleteBatch(toDelete)`.

#### B. Move to Group Dialog (`Dialog` / `AlertDialog`)
- Expected by test 6.1: `expect(find.byType(Dialog), findsOneWidget);`
- **HomeScreen** (`home_screen.dart:152–217`):
  - Component: `AlertDialog` (which builds a Flutter `Dialog` internally)
  - Title: `'Move to Group'`
  - Body:
    - If `groupService.groups.isEmpty`: Text `'No custom groups available. Create a group first.'`
    - If `groupService.groups.isNotEmpty`: `ListView.builder` listing `ListTile` items with `targetGroup.title` and `'${targetGroup.itemPaths.length} items'`.
  - Execution on tile tap:
    - Adds selected item paths to target group via `groupService.addItemsToGroup(targetGroup.id, ...)`.
    - If custom groups are selected, moves items from source groups to target group via `groupService.moveItemsBetweenGroups(...)`.
    - Exits selection mode and pops dialog.
- **LibraryScreen** (`library_screen.dart:142–199`):
  - Expands folder paths to constituent video items and calls `groupService.addItemsToGroup(targetGroup.id, allPathsToMove.toList())`.

---

### 1.4 Empirical Verification Results

Running the test commands directly in `d:\E-player\app`:

1. `dart analyze test/e2e/e2e_requirements_test.dart`:
   - **Command Output**: `Analyzing e2e_requirements_test.dart... No issues found!` (0 errors, 0 warnings).
2. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 3"`:
   - **Result**: **5/5 PASSED** (Tests 3.1, 3.2, 3.3, 3.4, 3.5).
3. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 4"`:
   - **Result**: **5/5 PASSED** (Tests 4.1, 4.2, 4.3, 4.4, 4.5).
4. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 5"`:
   - **Result**: **5/5 PASSED** (Tests 5.1, 5.2, 5.3, 5.4, 5.5).
5. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 6"`:
   - **Result**: **5/5 PASSED** (Tests 6.1, 6.2, 6.3, 6.4, 6.5).
6. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 7"`:
   - **Result**: **5/5 PASSED** (Tests 7.1, 7.2, 7.3, 7.4, 7.5).
7. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 8"`:
   - **Result**: **5/5 PASSED** (Tests 8.1, 8.2, 8.3, 8.4, 8.5).
8. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Tier 3"`:
   - **Result**: **6/6 PASSED** (Tests 3.1, 3.2, 3.3, 3.4, 3.5, 3.6).
9. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Scenario 2"`:
   - **Result**: **1/1 PASSED**.
10. `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Scenario 3"`:
    - **Result**: **1/1 PASSED**.

**Total Empirical Milestone 2 Test Pass Rate**: **38 of 38 executed tests PASSED (100% pass rate)**.

---

## 2. Logic Chain

1. **Selection Trigger Chain**:
   - In `home_screen.dart:1131`, `library_screen.dart:1122, 1324, 1557`, and `folder_detail_screen.dart:716, 825`, user gestures are captured by `InkWell(onLongPress: ...)` or `ListTile(onLongPress: ...)`.
   - Long press dispatches to `_toggleGroupSelection(group.id)` or `_togglePathSelection(path)`.
   - The method adds the identifier to `_selectedGroupIds` / `_selectedPaths` and sets `_isSelectionMode = true`.
   - *Direct Evidence*: Test 3.1 (`await tester.longPress(find.text('Custom Group Alpha'))`) and Test 8.1 (`await tester.longPress(itemFinder)`) observe `_isSelectionMode` active and find the selection indicator.

2. **Counter String Formatting Semantics**:
   - Test 4.2 specifically performs `expect(find.text('2 Selected'), findsOneWidget)`.
   - This proves that the selection bar title must format strictly as `'${count} Selected'` (capital 'S', space-separated), not `'Selected (2)'`, `'2 items selected'`, or `'2 selected'`.
   - *Direct Evidence*: `_buildSelectionAppBar` in both `home_screen.dart:237` and `library_screen.dart:225` specifies `'$_selectedCount Selected'` and `'${_selectedPaths.length} Selected'`. This exact string formatting satisfies both `find.text('2 Selected')` (Test 4.2) and `find.textContaining('1 Selected')` (Test 3.2).

3. **Select All & Deselect State Machine**:
   - Test 4.1 asserts finding `'Select All'` or `'All'`.
   - Test 4.3 asserts that after tapping `'Select All'` when all items are already selected, the button toggles to `'None'` (or acts as a toggle), and tapping it clears all selections, exiting selection mode.
   - In `home_screen.dart:88–99` and `library_screen.dart:81–90`:
     - When `isAllSelected` is true, button renders `child: Text('None')` and tapping it clears selection sets and sets `_isSelectionMode = false`.
     - When `isAllSelected` is false, button renders `child: Text('Select All')` and tapping it selects all items in the active container.
   - *Direct Evidence*: Test 4.3 successfully executed both transitions and passed without regression.

4. **Batch Deletion Scoping & Non-Destructive Protection**:
   - Requirement R2 mandates: "Selected items must support being deleted... This selection behavior must not apply to built-in / default app features."
   - Test 5.4 explicitly asserts:
     ```dart
     await groupService.deleteGroup(group.id);
     expect(video.existsSync(), isTrue);
     final dbItems = await DatabaseHelper.instance.getAllItems();
     expect(dbItems.any((i) => i.path == video.path), isTrue);
     ```
   - *Inference*: Group deletion removes custom user organizational mappings in `MediaGroupService`, but **never** deletes rows in `DatabaseHelper` table `media_items` or physical files on disk. Hard catalog deletion only occurs when deleting from the Library or standard folders.

5. **Batch Move Atomic State & Persistence**:
   - Test 6.4 and 6.5 assert that moving an item between groups removes it from the source group and appends it to the destination group, persisting immediately in `SharedPreferences` key `eplayer_custom_media_groups_v1`.
   - *Direct Evidence*: `MediaGroupService.moveItemsBetweenGroups` executes both group mutations synchronously in-memory, writes to `SharedPreferences`, and notifies listeners. Verified by tests 6.3, 6.4, and 6.5 passing.

6. **Built-in Feature Decoupling**:
   - In Tests 7.1–7.4 and Scenario 3, long-pressing "Create Group", "Videos", Category chips, and headers asserts `find.textContaining('Selected') findsNothing`.
   - *Direct Evidence*: In `home_screen.dart`, cards for "Create Group" (line 998), "Videos" (line 998), History (line 730), Category chips (line 544), and Bento cards (line 1451) explicitly assign `onLongPress: null`. Thus Flutter ignores long-press touch events on these widgets, ensuring zero false-positive selections.

---

## 3. Caveats & Edge Cases for Worker M2

### 3.1 Edge Cases That Worker M2 Must Keep Covered

1. **Empty Selection Safety (Test 2.8 & 2.9)**:
   - When no items are selected or a container is empty, calling batch actions or Select All must be a safe no-op.
   - `_toggleSelectAll` checks `if (allGroupIds.isNotEmpty)` to avoid dividing by zero or flipping into empty selection mode.
2. **Auto-Exit Mode on Zero Selections (Test 3.4)**:
   - When the user individually deselects the last selected item in a container, `_isSelectionMode` must immediately reset to `false`. Worker M2 must not leave the contextual AppBar visible with `0 Selected`.
3. **Hardware & Gesture Back Navigation (`PopScope`)**:
   - `HomeScreen` line 287 uses `PopScope(canPop: !_isSelectionMode, onPopInvokedWithResult: (didPop, _) { if (!didPop) _exitSelectionMode(); })`.
   - When selection mode is active, the system back button (or swipe back) must dismiss selection mode, **not** exit the app.
4. **Self-Move Idempotency (Test 2.13)**:
   - If a user opens the "Move to Group" dialog and selects the same group that already contains the items, `moveItemsBetweenGroups` must not duplicate items or crash. In `MediaGroupService:139–141`, `if (!updatedToPaths.contains(p))` ensures uniqueness.
5. **Unicode, Emoji & Long Titles (Test 2.12)**:
   - Custom group titles with emojis (`🎥`, `🔥`), symbols, and 500+ characters must not overflow the selection bar or group card. `HomeScreen:1186` uses `overflow: TextOverflow.ellipsis`.
6. **Smart Playlists Non-Selectability in Library**:
   - In `LibraryScreen:75–76`, when `_selectedTab == 'Playlists'`, `_toggleSelectAll` yields `visiblePaths = []`. Smart playlists are built-in features and must not be bulk-selected.

### 3.2 Discovered Implementation & Test Environment Quirks

1. **Windows File Lock on `sqlite3.dll`**:
   - Symptom: Running consecutive `flutter test` commands rapidly on Windows can fail with: `Flutter failed to delete file at "D:\E-player\app\build\native_assets\windows\sqlite3.dll". The flutter tool cannot access the file or directory.`
   - Cause: The native `flutter_tester` process holds a file handle to `sqlite3.dll` for 1–2 seconds after exiting.
   - Remedy for Worker M2: Run `Stop-Process -Name "flutter_tester" -Force -ErrorAction SilentlyContinue; Remove-Item -Force "D:\E-player\app\build\native_assets\windows\sqlite3.dll" -ErrorAction SilentlyContinue` before re-running test commands.
2. **`LibraryProvider.refreshLibrary()` in `testWidgets`**:
   - In widget tests where `LibraryProvider` is initialized, invoking `refreshLibrary()` directly before `pumpWidget` can cause sqflite async deadlock with `pumpAndSettle`.
   - Test 8.1 correctly wraps this in `await tester.runAsync(() => libProvider.refreshLibrary());`. Downstream workers writing new widget tests must follow this pattern.
3. **HitTest Warnings on Inactive Cards during Long-Press (Scenario 3)**:
   - Flutter's test runner emits hit-test warnings when attempting `longPress` on widgets whose hit-test rect is consumed by an inner widget or disabled listener. This is expected and confirms that long press is rejected by built-in cards.

---

## 4. Conclusion

1. **Test Alignment Status**:
   - All acceptance criteria for Milestone 2 (Requirements R2 and R3) are mapped to explicit, deterministic opaque-box tests in `test/e2e/e2e_requirements_test.dart`.
   - The test suite targets Features 3, 4, 5, 6, 7, 8, as well as boundary cases in Tier 2, cross-feature workflows in Tier 3, and real-world user scenarios in Tier 4.
2. **Implementation Conformance**:
   - `HomeScreen`, `LibraryScreen`, and `FolderDetailScreen` have already implemented the full state lifecycle, gesture recognizers, visual indicators, contextual AppBars, and batch action dialogs.
   - Static analysis (`dart analyze`) passes with **0 errors and 0 warnings**.
   - All 38 Milestone 2 automated test cases pass with a **100% success rate**.
3. **Worker M2 Guidance**:
   - Worker M2's implementation is already functionally complete and passing all requirements.
   - Any further enhancements should focus exclusively on non-breaking ergonomics (e.g. adding atomic `deleteGroups(Iterable<String> ids)` in `MediaGroupService`, and adding direct long-press selection on Home search results).

---

## 5. Verification Method

To independently verify the test suite alignment and test pass status:

### Step 1: Static Analysis
```powershell
cd d:\E-player\app
dart analyze test/e2e/e2e_requirements_test.dart lib/features/home/ui/home_screen.dart lib/features/library/ui/library_screen.dart lib/features/library/ui/folder_detail_screen.dart
```
*Expected Result*: `No issues found!`

### Step 2: Milestone 2 Feature-by-Feature Verification
```powershell
cd d:\E-player\app

# Ensure no locked native assets
Stop-Process -Name "flutter_tester" -Force -ErrorAction SilentlyContinue
Remove-Item -Force "D:\E-player\app\build\native_assets\windows\sqlite3.dll" -ErrorAction SilentlyContinue

# Feature 3: Long-Press Multi-Select on Home (5 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 3"

# Feature 4: Select All & Deselect on Home (5 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 4"

# Feature 5: Batch Delete on Home (5 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 5"

# Feature 6: Batch Move on Home (5 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 6"

# Feature 7: Built-in Feature Protection on Home (5 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 7"

# Feature 8: Multi-Select & Batch Actions in Library (5 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 8"

# Tier 3: Cross-Feature Interactions (6 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Tier 3"

# Tier 4: Real-World Scenarios 2 & 3 (2 tests)
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Scenario 2"
flutter test test/e2e/e2e_requirements_test.dart --plain-name "Scenario 3"
```
*Expected Result*: All 38 tests pass with 0 failures.

### Invalidation Conditions
This investigation report is invalidated if:
1. Any test in Features 3–8 fails or throws an uncaught exception.
2. The selection bar text deviates from `'${count} Selected'`.
3. Tapping `'Select All'` when all items are selected does not toggle to `'None'` or deselect.
4. Long-pressing "Create Group" or "Videos" activates selection mode.
5. Deleting a custom group causes records in SQLite table `media_items` or physical files to be deleted.
