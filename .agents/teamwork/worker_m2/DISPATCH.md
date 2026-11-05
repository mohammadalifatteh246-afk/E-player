## 2026-11-04T13:15:00Z
You are Worker Milestone 2 on the E-Player project.
Your working directory is: d:\E-player\.agents\teamwork\worker_m2
Workspace root: d:\E-player\app

MANDATORY FIRST STEPS:
1. Read ORIGINAL_REQUEST.md at: d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
2. Read PROJECT.md at: d:\E-player\PROJECT.md
3. Read SCOPE.md at: d:\E-player\.agents\teamwork\worker_m2\SCOPE.md
4. Read TEST_READY.md at: d:\E-player\TEST_READY.md
5. Inspect `d:\E-player\app\lib\features\trash\ui\trash_screen.dart` for the reference multi-select implementation.

FILE OWNERSHIP (Exclusive to this task):
- `d:\E-player\app\lib\features\home\ui\home_screen.dart`
- `d:\E-player\app\lib\features\library\ui\library_screen.dart`
- `d:\E-player\app\lib\features\library\ui\folder_detail_screen.dart`

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

IMPLEMENTATION REQUIREMENTS (R2 & R3):
1. **Multi-Selection Gestures & State**:
   - In `HomeScreen`, `LibraryScreen`, and `FolderDetailScreen`:
     - Maintain selection state (`bool _isSelectionMode = false`, `Set<String> _selectedPaths = {}`, and `Set<String> _selectedGroupIds = {}` on Home).
     - `onLongPress` on custom groups, folders, and files activates selection mode and selects the item.
     - `onTap` in selection mode toggles selection (if selection becomes empty, exit selection mode). In normal mode, performs default action (navigation/playback).
2. **Built-in Feature Protection (R2)**:
   - Built-in / default app features MUST NOT trigger multi-selection or allow deletion/moving:
     - Home Quick Action cards ("Create Group", "Videos")
     - Home Category chips ("All", "History", "Videos", "Groups", "Audio", "Favorites")
     - Home App Bar controls & Bottom Navigation
     - Library Smart Curated Playlists ("Favorite Media", "4K Ultra HD & HDR", "Recently Added Media", "Binge Watch Queue")
     - Set `onLongPress: null` on these built-in widgets and ignore them during selection.
3. **Contextual Action Bar / App Bar**:
   - When selection mode is active, display a contextual bar showing:
     - Close/Cancel button (`onPressed: _exitSelectionMode`)
     - Title: `'${selectedCount} Selected'`
     - "Select All" / "Deselect All" button: selects all selectable items in active container/view.
     - "Move to Group" button: opens a bottom sheet listing custom groups from `groupService.groups`, moves selected items to target group via `MediaGroupService.addItemsToGroup` / `moveItemsBetweenGroups`.
     - "Delete" button: displays confirmation dialog, deletes selected custom groups from `MediaGroupService` or removes selected items from group / library.
4. **Visual Selection Feedback**:
   - Highlight border (`Border.all(color: EDesign.primary, width: 2)`)
   - Checkmark badge (`Icons.check_circle_rounded`, color: `EDesign.primary`) on selected items; hollow radio indicator on unselected items in selection mode.
5. **Testing & Verification**:
   - Run `dart analyze` in `d:\E-player\app` (must be 0 errors).
   - Run E2E tests:
     `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 3:"`
     `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 4:"`
     `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 5:"`
     `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 6:"`
     `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 7:"`
     `flutter test test/e2e/e2e_requirements_test.dart --plain-name "Feature 8:"`

Write your complete changes, test outputs, and findings to `d:\E-player\.agents\teamwork\worker_m2\handoff.md`.
Send a completion message to the caller when done.


## 2026-11-04T13:36:39Z
**Context**: Milestone 2 Implementation (worker_m2)
**Content**: Checking your progress. Your progress.md was last updated at 13:16:30Z. What step are you currently on (HomeScreen, LibraryScreen, FolderDetailScreen)? Please update your progress.md and let me know if you need any assistance.
**Action**: Reply with your current implementation status and update your progress.md.
