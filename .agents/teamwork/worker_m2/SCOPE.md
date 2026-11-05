# Scope: Milestone 2 — Long-Press Multi-Select, Select All, Delete, and Move (Home & Library)

## Requirements Covered
- **R2**: Long-press multi-select, Select All, delete, and move on Home screen. Exclusion of built-in features.
- **R3**: Apply the same multi-select, Select All, deletion, and move-to-group to Library section.

## File Boundaries Owned Exclusively by Worker M2
- `lib/features/home/ui/home_screen.dart`
- `lib/features/library/ui/library_screen.dart`
- `lib/features/library/ui/folder_detail_screen.dart`

## Key Capabilities to Implement
1. **Multi-Select State**:
   - `_isMultiSelectMode`, `_selectedPaths` (and `_selectedGroupIds` on Home).
2. **Gestures**:
   - `onLongPress`: Enters selection mode and selects target item (for custom groups, folders, files).
   - `onTap`: In selection mode, toggles selection. In normal mode, plays or navigates.
3. **Built-in Feature Protection**:
   - Ensure "Create Group", "Videos" action cards, category filter chips, and smart playlists have `onLongPress: null` and are NEVER selectable or deletable/movable.
4. **Contextual Action Bar / Controls**:
   - Displays count of selected items.
   - "Select All" / "Deselect All" button.
   - "Move to Group" button: presents modal sheet listing custom groups, moves selected items via `groupService.addItemsToGroup` / `moveItemsBetweenGroups`.
   - "Delete" button: displays confirmation dialog, deletes groups from `MediaGroupService` or removes items from group/library.
   - Close / Cancel button: exits selection mode.
5. **Visual Selection Feedback**:
   - Highlight border (`Border.all(color: EDesign.primary, width: 2)`), checkmark badge on selected items.
6. **Tests**:
   - Run `test/e2e/e2e_requirements_test.dart` for Feature 3 to Feature 8.
   - Add/update widget tests.
   - Verify `dart analyze` passes with 0 issues.
