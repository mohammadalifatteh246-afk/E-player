# Project: E-Player Production Update (Empty Groups, Multi-Select, 5-Item History, Video-Only Filtering)

## Architecture
- **Framework**: Flutter with Provider state management (`MultiProvider` at root).
- **Core State Providers**:
  - `LibraryProvider` (`lib/features/library/domain/library_provider.dart`): Media library catalog, recents, file indexing, SQLite backing.
  - `MediaGroupService` (`lib/features/home/domain/media_group_service.dart`): Custom user groups persistence (`SharedPreferences`), group CRUD, item mapping.
  - `DatabaseHelper` (`lib/core/db/database_helper.dart`): SQLite database `media_library.db`, table `media_items`.
  - `TrashService` (`lib/features/trash/domain/trash_service.dart`): Soft deletion and recycle bin management.
- **Key UI Screens**:
  - `HomeScreen` (`lib/features/home/ui/home_screen.dart`): Action cards, custom groups horizontal rail, Media Library section, History section.
  - `LibraryScreen` (`lib/features/library/ui/library_screen.dart`): Complete media library view (posters, list, folders, smart playlists).
  - `FolderDetailScreen` (`lib/features/library/ui/folder_detail_screen.dart`): Folder contents and group detail view.

## Code Layout
- `lib/features/home/domain/media_group_service.dart` — Custom media group state, CRUD, batch add/remove.
- `lib/features/home/ui/home_screen.dart` — Home view, custom groups rail, History section, Media Library section, long-press selection.
- `lib/features/library/ui/folder_detail_screen.dart` — Group/folder detail view, empty group state with Add button, multi-select.
- `lib/features/library/ui/library_screen.dart` — Library view, long-press multi-select, Select All, delete/move.
- `test/e2e/` — Opaque-box E2E test suites covering requirements R1–R5.
- `test/unit/` & `test/widgets/` — Targeted unit and widget tests.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Empty Group Initialization | Newly created groups initialize with 0 items; eliminate fallback `take(8)` bug in `HomeScreen` | M1 | Survey R1 |
| 2 | Group Add Button & Import | `FolderDetailScreen` renders Add button in empty state and AppBar, enabling file/folder import | M1 | Survey R1 |
| 3 | MediaGroupService Batch APIs | Batch methods `addItemsToGroup` and `removeItemsFromGroup` for atomic updates | M1 | Survey R1 |
| 4 | Home Multi-Select Activation | Long-press on custom groups, folders, or files activates multi-select mode | M2 | Survey R2 |
| 5 | Home Select All Toggle | Contextual action bar option to select all selectable items in active view | M2 | Survey R2 |
| 6 | Home Batch Delete Action | Selected custom groups or media items can be deleted with confirmation | M2 | Survey R2 |
| 7 | Home Batch Move Action | Selected media items can be moved to another designated custom group | M2 | Survey R2 |
| 8 | Built-in Feature Protection | Built-in features (Create Group card, Videos card, Category pills, App Bars, Smart Playlists) ignore selection | M2 | Survey R2 |
| 9 | Library Multi-Select & Batch Actions | Apply long-press selection, Select All, delete, and move-to-group to Library section | M2 | Survey R3 |
| 10 | Scrollable History View | Smooth horizontal scrolling carousel with `BouncingScrollPhysics` for browsing recent history | M3 | Survey R4 |
| 11 | History 5-Item Limit | Strict maximum cap of 5 items displayed in History across both flat and grouped modes | M3 | Survey R4 |
| 12 | Video-Only Media Library | Filter Home Media Library to only display Library videos and video folders | M3 | Survey R5 |
| 13 | Remove Music/Series/Anime Cards | Completely remove the 4-box Bento category cards (Music, Series, Anime, Movies) | M3 | Survey R5 |
| 14 | E2E Test Track Suite | Comprehensive 4-tier opaque-box test suite verifying all acceptance criteria | M4 | Dual Track |
| 15 | Adversarial Hardening & Victory Audit | Tier 5 white-box coverage hardening and forensic integrity audit | M5 | Dual Track |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Empty Group Creation & Add Button | `media_group_service.dart`, `home_screen.dart`, `folder_detail_screen.dart` | none | DONE |
| M2 | Long-Press Multi-Select & Batch Actions | `home_screen.dart`, `library_screen.dart`, `folder_detail_screen.dart` | M1 | DONE |
| M3 | Scrollable 5-Item History & Video-Only Filtering | `home_screen.dart` | M1 | IN_PROGRESS |
| M4 | E2E Test Suite (Dual Track) | `test/e2e/e2e_requirements_test.dart`, `TEST_READY.md` | none | DONE |
| M5 | Final E2E Pass, Hardening & Victory Audit | Full verification, `flutter test`, `dart analyze`, forensic audit | M1, M2, M3, M4 | PLANNED |

## Interface Contracts
### MediaGroupService
- `Future<void> addItemsToGroup(String groupId, List<String> paths)`: Atomically appends paths to `group.itemPaths`, saves to `SharedPreferences`, notifies listeners.
- `Future<void> removeItemsFromGroup(String groupId, List<String> paths)`: Atomically removes paths from `group.itemPaths`, saves, notifies listeners.
- `Future<void> moveItemsBetweenGroups({required String fromGroupId, required String toGroupId, required List<String> paths})`: Atomic move.

### FolderDetailScreen
- Parameter: `final String? groupId;`
- When `groupId != null`:
  - Items are bound to `MediaGroupService.groups.firstWhere((g) => g.id == groupId).itemPaths`.
  - Empty state displays "This group is empty" with an "Add Media / Folders" action button.
  - AppBar includes Add button.
