# Explorer Handoff Report: Milestone 2 UI/UX, Gestures & Contextual Interactions (AURA)

**Explorer**: AURA (`teamwork_explorer`)  
**Mission**: Milestone 2: Long-Press Multi-Select, Select All, Delete, and Move across Home & Library (Requirements R2 and R3)  
**Date**: 2026-11-05T05:25:00Z  
**Status**: COMPLETE (Read-Only Investigation)  

---

## 1. Observation

### 1.1 Codebase Inspection & Line References

#### A. `lib/features/home/ui/home_screen.dart`
- **Multi-Selection State & Mode Toggle** (lines 45–85):
  - Line 45: `bool _isSelectionMode = false;`
  - Lines 46–47: `final Set<String> _selectedGroupIds = {}; final Set<String> _selectedItemPaths = {};`
  - Lines 51–57: `_exitSelectionMode()` resets `_isSelectionMode = false` and clears both selection sets.
  - Lines 59–84: `_toggleGroupSelection(String groupId)` and `_toggleItemSelection(String path)` toggle set inclusion and automatically reset `_isSelectionMode = false` when `_selectedCount == 0`.
  - Lines 87–100: `_toggleSelectAll(MediaGroupService groupService)` toggles between selecting all custom groups in `groupService.groups` and clearing selection.
- **Contextual Selection AppBar** (lines 220–261, 371–373):
  - Line 371–373: In `_buildAppBar`, when `_isSelectionMode` is true, replaces standard app bar with `_buildSelectionAppBar(context, groupService, provider)`.
  - Line 231–235: Leading button `IconButton(icon: Icon(Icons.close), tooltip: 'Exit Selection', onPressed: _exitSelectionMode)`.
  - Line 236–239: Title `Text('$_selectedCount Selected', style: EDesign.h2)`.
  - Lines 242–248: `TextButton` toggling `'Select All'` / `'None'`.
  - Lines 249–253: `IconButton(icon: Icon(Icons.drive_file_move), tooltip: 'Move to Group', onPressed: () => _showMoveToGroupDialog(...))`.
  - Lines 254–258: `IconButton(icon: Icon(Icons.delete), tooltip: 'Delete Selected', onPressed: () => _confirmDeleteSelected(...))`.
- **Gesture Recognizers on Custom Groups** (lines 1129–1147):
  - Line 1131: `InkWell(onLongPress: () => _toggleGroupSelection(group.id), onTap: () { if (_isSelectionMode) _toggleGroupSelection(group.id); else Navigator.push(...FolderDetailScreen...); })`.
- **Selection Visual Feedback** (lines 1150–1208):
  - Line 1152: `color: isSelected ? EDesign.elevatedSurface : EDesign.surface`.
  - Lines 1154–1157: `border: Border.all(color: isSelected ? EDesign.primary : group.color.withValues(alpha: 0.4), width: isSelected ? 2.0 : 1.0)`.
  - Lines 1199–1207: Trailing indicator `Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: isSelected ? EDesign.primary : EDesign.textMuted)`.
- **Built-in Feature Protection** (lines 544, 730, 998, 1036, 1451):
  - Category Chips: Line 544 `onLongPress: null`. Also hidden during selection mode (line 318: `if (!_isSelectionMode)`).
  - Compact History: Line 730 `onLongPress: null`.
  - Action Card "Create Group": Line 998 `onLongPress: null`, tactical `+` button line 1036 `onLongPress: null`.
  - Action Card "Videos": Line 998 `onLongPress: null`, tactical `+` button line 1036 `onLongPress: null`.
  - Bento Category Cards (Movies, Series, Anime, Music): Line 1451 `onLongPress: null`.
- **System Back Navigation Interception** (lines 287–291):
  - `PopScope(canPop: !_isSelectionMode, onPopInvokedWithResult: (didPop, _) { if (!didPop) _exitSelectionMode(); })`.

#### B. `lib/features/library/ui/library_screen.dart`
- **Multi-Selection State & Mode Toggle** (lines 47–91):
  - Line 47: `bool _isSelectionMode = false;`
  - Line 48: `final Set<String> _selectedPaths = {};`
  - Lines 57–69: `_togglePathSelection(String path)` toggles membership and resets `_isSelectionMode = false` when `_selectedPaths.isEmpty`.
  - Lines 71–91: `_toggleSelectAll(LibraryProvider provider)` maps visible paths depending on tab:
    - If `_selectedTab == 'Folders'`: `provider.groupedFolders.keys.toList()`.
    - If `_selectedTab == 'Playlists'`: `[]` (empty list; smart playlists excluded!).
    - Otherwise: `provider.searchResults.map((i) => i.path).toList()`.
- **Selection Visual Feedback & Badges**:
  - Grid View (lines 1111–1153, 1208–1220):
    - Border: `border: isSelected ? Border.all(color: EDesign.primary, width: 2.0) : Border.all(color: EDesign.border, width: 0.8)`.
    - Overlay: `if (isSelected) Container(color: EDesign.primary.withValues(alpha: 0.15))`.
    - Badge: `Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? EDesign.primary : Colors.white70, size: 22)`.
  - List View (lines 1309–1313, 1390–1395):
    - Border: 2.0px `EDesign.primary`.
    - Trailing: `Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? EDesign.primary : Colors.white70, size: 20)`.
  - Folders View (lines 1551–1553, 1574–1579):
    - Border: 2.0px `EDesign.primary`.
    - Trailing: `Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? EDesign.primary : Colors.white70, size: 20)`.
- **Built-in Feature Exclusion**:
  - Smart Playlists (lines 1664): `ListTile(..., onLongPress: null, // Protected built-in smart playlist)`.
  - Filter Tabs (line 366): Hidden during selection mode via `if (!_isSelectionMode)`.
  - Floating Scan Button (line 358): Hidden during selection mode via `_isSelectionMode ? null : _buildFloatingScanButton(provider)`.
- **Contextual Selection AppBar** (lines 201–250, 389–391):
  - Full parity with HomeScreen: Close icon, count label `'${_selectedPaths.length} Selected'`, `'Select All'` / `'None'` toggle, `'Move to Group'` action, and `'Delete Selected'` action.
- **Batch Actions Implementation**:
  - Batch Delete (lines 93–140): Shows `AlertDialog`. Expands any selected folder paths into all constituent files in `provider.groupedFolders`, invokes `DatabaseHelper.instance.deleteBatch(...)`, and calls `provider.refreshLibrary()`.
  - Batch Move (lines 142–199): Shows `AlertDialog` with destination group picker, expands folder paths, and invokes `groupService.addItemsToGroup(targetGroup.id, allPathsToMove.toList())`.

#### C. `lib/features/library/ui/folder_detail_screen.dart`
- **Multi-Selection State & Mode Toggle** (lines 40–77):
  - Lines 41–42: `bool _isSelectionMode = false; final Set<String> _selectedPaths = {};`
  - Lines 65–76: `_toggleSelectAll(List<MediaItem> visibleItems)` toggles all visible items.
- **Contextual Selection AppBar** (lines 203–245, 344–346):
  - Replaces standard AppBar with `_buildSelectionAppBar`: Exit Selection button, count `'${_selectedPaths.length} Selected'`, `'Select All'` / `'None'` toggle, Move button, Delete button.
- **Group vs. Library Delete Semantics** (lines 79–133):
  - When `widget.groupId != null` (Custom Group):
    - Title: `"Remove from Group?"`
    - Action: `groupService.removeItemsFromGroup(widget.groupId!, toDelete)` (removes from group only; DB and disk files untouched!).
  - When `widget.groupId == null` (Normal folder):
    - Title: `"Delete Selected Items?"`
    - Action: `DatabaseHelper.instance.deleteBatch(toDelete)` and `provider.refreshLibrary()`.
- **Move to Group Semantics** (lines 136–200):
  - When `widget.groupId != null`: `groupService.moveItemsBetweenGroups(fromGroupId: widget.groupId!, toGroupId: targetGroup.id, paths: pathsToMove)`.
  - When `widget.groupId == null`: `groupService.addItemsToGroup(targetGroup.id, pathsToMove)`.
- **Defect Resolution Verified**:
  - Line 1152 uses `await FilePicker.pickFiles(type: FileType.video);` (the `FilePicker.platform` compilation defect noted in TEST_READY.md was previously resolved).

#### D. Reference Pattern in `lib/features/trash/ui/trash_screen.dart`
- State: `bool _isMultiSelectMode = false; final Set<String> _selectedTrashPaths = {};`
- Gesture: `onLongPress: () => _toggleSelection(item.trashPath)`, `onTap: _isMultiSelectMode ? () => _toggleSelection(item.trashPath) : null`.
- Visuals: `Checkbox` in `ListTile.leading`, `borderColor: isSelected ? EDesign.primary : EDesign.border`.
- AppBar: Displays `'${_selectedTrashPaths.length} Selected'`, Select All / None toggle, Close icon (`Icons.close`).
- Bottom Bar: Renders Restore and Delete elevated buttons when `_isMultiSelectMode && _selectedTrashPaths.isNotEmpty`.

### 1.2 Empirical Test Execution Results
Executed test commands via `run_command` in `d:\E-player\app`:

1. `dart analyze`:
   ```
   Analyzing app...
   No issues found!
   ```
   **Result**: 0 errors, 0 warnings.

2. `flutter test test/e2e/e2e_requirements_test.dart --name "R2"`:
   - 3.1: Long-pressing a custom group card enters multi-selection mode: **PASSED**
   - 3.2: Multi-select mode activates contextual selection bar showing selection count: **PASSED**
   - 3.3: Tapping another custom group while in selection mode toggles its selected state: **PASSED**
   - 3.4: Deselecting all selected items exits multi-selection mode: **PASSED**
   - 3.5: Close or cancel action button clears selection and exits selection mode: **PASSED**
   - 4.1: Tapping "Select All" selects all custom groups in view: **PASSED**
   - 4.2: Tapping "Select All" updates AppBar counter to total selectable count: **PASSED**
   - 4.3: Tapping "None" or toggling Select All when all selected deselects all items: **PASSED**
   - 4.4: Selection state accurately reflects individual items added or removed after Select All: **PASSED**
   - 4.5: Selection bar displays batch action buttons (Delete, Move) when >= 1 item is selected: **PASSED**
   - 5.1: Tapping Delete with selected groups shows confirmation dialog: **PASSED**
   - 5.2: Confirming delete removes selected groups from MediaGroupService: **PASSED**
   - 5.3: Deleted groups no longer appear in HomeScreen custom groups section: **PASSED**
   - 5.4: Deleting a group does not delete physical media files from library database: **PASSED**
   - 5.5: Batch deleting multiple selected groups removes all selected groups simultaneously: **PASSED**
   - 6.1: Tapping Move with selected media items opens destination group dialog: **PASSED**
   - 6.2: Group selection dialog lists all available destination custom groups: **PASSED**
   - 6.3: Selecting target group moves selected media items to that group: **PASSED**
   - 6.4: Moved items are removed from source group and appended to destination group: **PASSED**
   - 6.5: Moving items between groups persists changes in SharedPreferences: **PASSED**
   - 7.1: Long-pressing "Create Group" action card does NOT activate multi-selection mode: **PASSED**
   - 7.2: Long-pressing "Videos" action card does NOT activate multi-selection mode: **PASSED**
   - 7.3: Long-pressing category chips (All, History, Videos, etc.) does NOT activate multi-selection: **PASSED**
   - 7.4: Long-pressing AppBar icons or section headers does NOT trigger selection mode: **PASSED**
   - 7.5: Built-in default features are protected from deletion and moving: **PASSED**
   **Result**: 25/25 tests PASSED (100% pass rate for R2).

3. `flutter test test/e2e/e2e_requirements_test.dart --name "R3"`:
   - 8.1: Long-pressing a media item or folder in LibraryScreen activates multi-selection mode: **PASSED**
   - 8.2: Selection bar displays count of selected library items: **PASSED**
   - 8.3: "Select All" in Library selects all visible library items: **PASSED**
   - 8.4: Batch Delete in Library removes items from library and updates DatabaseHelper: **PASSED**
   - 8.5: Batch Move in Library assigns selected media paths to custom group: **PASSED**
   **Result**: 5/5 tests PASSED (100% pass rate for R3).

---

## 2. Logic Chain

1. **Long-Press Gesture Activation**:
   - Observations 1.1A (`home_screen.dart:1131`), 1.1B (`library_screen.dart:1122, 1324, 1557`), and 1.1C (`folder_detail_screen.dart:716, 825`) show that `onLongPress` callbacks are bound directly to `_toggleGroupSelection` and `_togglePathSelection`.
   - When triggered, these functions insert the tapped identifier into the screen's selection set (`_selectedGroupIds` or `_selectedPaths`) and flip `_isSelectionMode = true`.
   - Once in selection mode, normal taps (`onTap`) intercept navigation and route to `_toggle...Selection` to allow rapid multi-item selection.
   - When the user deselects the last remaining item, the selection set becomes empty, and the callback immediately resets `_isSelectionMode = false`, restoring standard navigation behavior without requiring a manual cancel click.
   - This logic is verified by tests 3.1, 3.3, 3.4, and 8.1 passing.

2. **Visual Feedback Coherence**:
   - Across `home_screen.dart`, `library_screen.dart`, and `folder_detail_screen.dart`, selected cards receive a 2.0px `EDesign.primary` border (cyan highlight) and an elevated container surface (`EDesign.elevatedSurface`).
   - For poster cards in `library_screen.dart`, a subtle primary tint overlay (`EDesign.primary.withValues(alpha: 0.15)`) is rendered over the artwork.
   - For both grid and list views, a circular selection badge (`Icons.check_circle` for selected, `Icons.radio_button_unchecked` for unselected) is positioned at the top-right corner of cards or as the trailing tile element.
   - Compared to `trash_screen.dart` which uses `Checkbox`, the circular badge style provides superior ergonomics and visual balance for media poster artwork while retaining standard checkbox semantics.

3. **Contextual Action Bar Architecture**:
   - In `MainScaffold` (`lib/ui/main_scaffold.dart`), a persistent bottom navigation bar is present across Home, Library, Enhance, Casting, and Settings tabs.
   - Placing selection actions in a bottom bar would clash with `MainScaffold`'s bottom navigation bar or force awkward z-indexing.
   - Replacing `Scaffold.appBar` with `_buildSelectionAppBar` during selection mode provides a clean, unified top action bar containing:
     1. Dismiss button (`Icons.close`, tooltip: `'Exit Selection'`).
     2. Selected count label (`'$_selectedCount Selected'`).
     3. Select All toggle (`TextButton` switching between `'Select All'` and `'None'`).
     4. Move to Group button (`Icons.drive_file_move`, tooltip: `'Move to Group'`).
     5. Delete button (`Icons.delete`, tooltip: `'Delete Selected'`).
   - PopScope integration ensures that Android hardware/gesture back and desktop back buttons smoothly dismiss selection mode first before any route pop.

4. **Built-in Feature Exclusion**:
   - "Create Group" action card (`home_screen.dart:998`): `onLongPress: null`.
   - "Videos" action card (`home_screen.dart:998`): `onLongPress: null`.
   - Category chips (`home_screen.dart:544`): `onLongPress: null`, and hidden in selection mode (`if (!_isSelectionMode)`).
   - Smart playlists (`library_screen.dart:1664`): `onLongPress: null`, and mapped to `visiblePaths = []` in `_toggleSelectAll`.
   - Category Bento cards (`home_screen.dart:1451`): `onLongPress: null`.
   - History card (`home_screen.dart:730`): `onLongPress: null`.
   - Because none of these components define an `onLongPress` recognizer, long-pressing them yields no gesture event, completely preventing selection mode activation. This is verified by tests 7.1, 7.2, 7.3, 7.4, and 7.5 passing.

5. **Identified UI Recommendations & Edge-Case Refinements**:
   - **Self-Move in `folder_detail_screen.dart`**: In `_showMoveToGroupDialog`, `groupService.groups` currently lists all groups including the current group (`widget.groupId`). Although `MediaGroupService.moveItemsBetweenGroups` safely handles self-move without data loss, filtering out `widget.groupId` (`groupService.groups.where((g) => g.id != widget.groupId)`) or displaying a "(Current Group)" disabled tile prevents user confusion.
   - **Home Search Results Selection**: In `home_screen.dart:1663–1696`, search result list items currently do not bind `onLongPress: () => _toggleItemSelection(item.path)`. Adding this enables long-press selection directly from Home search results.
   - **Empty Group Dialog CTA**: In `_showMoveToGroupDialog` (across Library and FolderDetail), when no custom groups exist, a message states "No custom groups available. Create a group from Home first." Adding a direct "Create Group" button in this modal would streamline the user workflow.

---

## 3. Caveats

1. **Milestone Scope**: This investigation focused exclusively on Milestone 2 UI/UX, gestures, and contextual actions (R2 and R3). Milestone 3 requirements (5-item History cap & scroll physics, and Video-only Media Library filtering) were not evaluated for UI completion as they belong to Milestone 3.
2. **SQLite Test Concurrency**: When running multiple test files simultaneously in the test suite without isolated database names, Windows SQLite file locking (`database is locked, code 5`) can occur. This is a known test harness isolation property (addressed via per-test temp directories in `eplayer_test_harness.dart`), not an application runtime UI defect.
3. **Desktop Pointer Hover**: On desktop environments (Windows / macOS / Linux), selection state is primarily gesture-driven (long-press or right-click / selection toggle button). The presence of `Icons.checklist_rtl_rounded` in `LibraryScreen`'s AppBar provides an accessible non-touch entry point for desktop pointer users.

---

## 4. Conclusion

The core UI architecture, gesture recognizers, visual indicators, contextual AppBars, and built-in feature protections for **Milestone 2 (Requirements R2 and R3)** are fully established, fully consistent, and empirically verified with a 100% test pass rate across all 30 dedicated test cases:
1. Long-press activation correctly enters selection mode (`_isSelectionMode = true`).
2. Single-tap toggles items while in selection mode and exits when count reaches 0.
3. Contextual selection AppBars (`_buildSelectionAppBar`) display count, Select All / None toggle, Move to Group modal, and Delete confirmation dialog.
4. Visual feedback incorporates 2.0px `EDesign.primary` borders, background tinting, and `Icons.check_circle` / `Icons.radio_button_unchecked` badges.
5. Built-in features ("Create Group", "Videos", Category Chips, Smart Playlists, Bento Grid) are strictly protected with `onLongPress: null`.
6. Specific non-breaking polish opportunities (self-move destination filtering, Home search result selection) are documented for downstream workers.

---

## 5. Verification Method

### 5.1 Static Analysis
Verify that all files are clean of compilation or lint errors:
```powershell
cd d:\E-player\app
dart analyze lib/features/home/ui/home_screen.dart lib/features/library/ui/library_screen.dart lib/features/library/ui/folder_detail_screen.dart
```
*Expected output*: `No issues found!`

### 5.2 Automated Test Execution
Run the full Milestone 2 test suites (R2 Home Multi-Select and R3 Library Multi-Select):
```powershell
cd d:\E-player\app
flutter test test/e2e/e2e_requirements_test.dart --name "R2"
flutter test test/e2e/e2e_requirements_test.dart --name "R3"
```
*Expected output*:
- All 25 tests for R2 pass (`Tier 1: Feature Coverage (R1 to R5) Feature 3, 4, 5, 6, 7`).
- All 5 tests for R3 pass (`Tier 1: Feature Coverage (R1 to R5) Feature 8`).

### 5.3 Invalidation Conditions
This handoff report is invalidated if:
1. Any `onLongPress` recognizer is added to "Create Group", "Videos", category chips, or smart playlists.
2. The selection counter fails to format as `'${count} Selected'`.
3. Selecting "Select All" fails to toggle to `'None'` on a second tap.
4. Deleting items inside a custom group deletes physical files rather than only removing group references.
