# Scope: Milestone 1 — Empty Group Creation & Add Button

## Architecture & Objective
Ensure that when a new custom media group is created, it initializes completely empty inside (0 items). Provide an Add button enabling users to add new files or folders to that group. Implement batch addition/removal APIs in `MediaGroupService`.

## Features Assigned
1. **F1: Empty Group Initialization**:
   - In `lib/features/home/ui/home_screen.dart` (around line 895), remove the artificial fallback `provider.allFiles.take(8).toList()` and pass `items: groupItems` and `groupId: group.id` to `FolderDetailScreen`.
2. **F2: Group Add Button in FolderDetailScreen**:
   - Update `FolderDetailScreen` (`lib/features/library/ui/folder_detail_screen.dart`) to accept `String? groupId`.
   - When viewing a group (`groupId != null`), render an empty state card with an "Add Media / Folders" button when items are empty.
   - Add an AppBar action button to add files/folders.
   - Support adding files (`FilePicker.platform.pickFiles`) or folders (`FilePicker.platform.getDirectoryPath`) or existing library items, calling `MediaGroupService.addItemToGroup` / `addItemsToGroup`.
3. **F3: Batch Methods in MediaGroupService**:
   - In `lib/features/home/domain/media_group_service.dart`, implement `addItemsToGroup(String groupId, List<String> paths)` and `removeItemsFromGroup(String groupId, List<String> paths)`.

## Code Layout Ownership
- `lib/features/home/domain/media_group_service.dart`
- `lib/features/home/ui/home_screen.dart` (custom groups section & navigation)
- `lib/features/library/ui/folder_detail_screen.dart` (group binding & Add button)

## Verification
- Unit & widget tests in `test/media_group_service_test.dart` and `test/widgets/folder_detail_screen_test.dart`
- `dart analyze` passes with 0 issues.
