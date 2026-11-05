# Technical Investigation Report: State Management, Models, Persistence, and Group/Media Architecture

**Author**: Codebase Explorer Forge  
**Working Directory**: `d:\E-player\.agents\teamwork\explorer_survey_forge`  
**Target Codebase**: `d:\E-player\app`  
**Date**: 2026-11-04  

---

## 1. Observation

### 1.1 State Management Architecture
- **Framework**: Package `provider: ^6.1.5+1` declared in `d:\E-player\app\pubspec.yaml:42`.
- **Root Provider Tree**: Initialized in `d:\E-player\app\lib\main.dart` (lines 47–57) via `MultiProvider`:
  ```dart
  ChangeNotifierProvider(create: (_) => LibraryProvider()),
  ChangeNotifierProvider(create: (_) => ExportService()),
  ChangeNotifierProvider(create: (_) => VaultService()),
  ChangeNotifierProvider(create: (_) => TrashService()),
  ChangeNotifierProvider(create: (_) => SettingsProvider()),
  ChangeNotifierProvider(create: (_) => CastService()),
  ChangeNotifierProvider(create: (_) => MediaGroupService()),
  ChangeNotifierProvider(create: (_) => VideoGroupingService()),
  ```
- **Consumer Hierarchy**:
  - `d:\E-player\app\lib\features\home\ui\home_screen.dart` (lines 64–65) uses `Consumer2<LibraryProvider, MediaGroupService>`.
  - `d:\E-player\app\lib\features\library\ui\library_screen.dart` (lines 135–136) uses `Consumer<LibraryProvider>`.
  - `d:\E-player\app\lib\features\library\ui\folder_detail_screen.dart` (line 62) uses `context.watch<LibraryProvider>()`.

### 1.2 Domain Models
- **`MediaItem`** (`d:\E-player\app\lib\core\models\media_item.dart`, lines 3–22):
  ```dart
  class MediaItem {
    final String path;
    final String name;
    final String parentFolder;
    final int sizeBytes;
    final int durationMs;
    final int lastPositionMs;
    final bool isFavorite;
    final DateTime lastPlayed;
  ```
  Implements `copyWith`, `toMap`, `fromMap`, `toJson`, and `fromJson`.
- **`MediaGroup`** (`d:\E-player\app\lib\features\home\domain\media_group_service.dart`, lines 6–23):
  ```dart
  class MediaGroup {
    final String id;
    final String title;
    final String description;
    final int colorValue;
    final String iconName;
    final List<String> itemPaths;
    final DateTime createdAt;
  ```
  Implements `toJson`, `fromJson`, `copyWith`. `colorValue` converted to/from Flutter `Color`.
- **`VideoGroup`** (`d:\E-player\app\lib\features\library\domain\video_grouping_service.dart`, lines 47–68):
  - In-memory automated grouping model matching VLC grouping: `id`, `title`, `subtitle`, `folderPath`, `mode` (`GroupMode.none`, `GroupMode.byFolder`, `GroupMode.byName`), `items: List<MediaItem>`, `totalDurationMs`, `totalSizeBytes`, `latestDate`.
- **Relational Records** (`d:\E-player\app\lib\core\models\media_library_models.dart`):
  - `DeviceRecord`, `FolderRecord`, `MediaRecord`, `FileRecord`, `VideoTrackRecord`, `AudioTrackRecord`, `TaskRecord`.

### 1.3 Database & State Persistence
- **SQLite Engine**:
  - `sqflite: ^2.4.4` and `sqflite_common_ffi: ^2.4.3` (`pubspec.yaml:47–49`).
  - Desktop FFI initialized in `main.dart` (lines 21–24):
    ```dart
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    ```
- **Active Database Provider**:
  - `DatabaseHelper` (`d:\E-player\app\lib\core\db\database_helper.dart`, lines 6–169):
    - SQLite database `media_library.db`, table `media_items` (columns: `_id`, `path` UNIQUE, `name`, `parentFolder`, `sizeBytes`, `durationMs`, `lastPositionMs`, `lastPlayed`, `isFavorite`).
    - Methods: `insertOrUpdateItem(MediaItem)`, `insertBatch(List<MediaItem>)`, `getAllItems()`, `getItemsByFolder(String)`, `deleteItem(String)`, `deleteBatch(List<String>)`, `pruneMissingItems()`.
  - `LibraryProvider` (`d:\E-player\app\lib\features\library\domain\library_provider.dart`, lines 107–125) reads from `DatabaseHelper.instance.getAllItems()`.
  - Secondary Relational Schema in `MediaLibraryDatabase` (`d:\E-player\app\lib\core\db\media_library_database.dart`) defines tables `Device`, `Folder`, `Media`, `File`, `VideoTrack`, `AudioTrack`, `Task`, `MediaFts` in `eplayer_media_library.db`. Currently `LibraryProvider` operates against `DatabaseHelper`'s `media_items` table.
- **`SharedPreferences` Persistence**:
  - `MediaGroupService` (`d:\E-player\app\lib\features\home\domain\media_group_service.dart`, lines 68, 81–103):
    - Key: `'eplayer_custom_media_groups_v1'`. Stores JSON encoded array of `MediaGroup` maps.
  - `VideoGroupingService` (`d:\E-player\app\lib\features\library\domain\video_grouping_service.dart`, line 710):
    - Key: `'eplayer_video_grouping_mode'`. Stores enum string name (`'none'`, `'byFolder'`, `'byName'`).
  - `TrashService` (`d:\E-player\app\lib\features\trash\domain\trash_service.dart`, lines 51, 64):
    - Key: `'trash_items'`. Stores JSON encoded list of `TrashItem` objects.

### 1.4 Group Definition, Creation, and the Empty Group Bug
- **Group Creation Logic**:
  - In `MediaGroupService.createGroup` (`media_group_service.dart:108–130`):
    ```dart
    Future<MediaGroup> createGroup({
      required String title,
      Color color = const Color(0xFF00E5FF),
      String description = '',
      String iconName = 'group',
      List<String> initialPaths = const [],
    }) async { ... }
    ```
    Creates a new `MediaGroup` with `itemPaths: initialPaths` (defaults to `const []`).
  - In `HomeScreen._showCreateGroupDialog` (`home_screen.dart:1636–1640`), it calls `groupService.createGroup(title: name, color: selectedColor)`.
  - At creation time, the group object is stored with `itemPaths: []` (0 items).
- **The Sample Items Root Cause**:
  - In `HomeScreen._buildCustomGroupsSection` (`home_screen.dart:884–899`):
    ```dart
    final group = groupService.groups[index];
    final groupItems = provider.allFiles.where((f) => group.itemPaths.contains(f.path)).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FolderDetailScreen(
              folderName: group.title,
              items: groupItems.isNotEmpty ? groupItems : provider.allFiles.take(8).toList(),
            ),
          ),
        );
      },
    ```
    **Line 896 explicitly specifies**:
    `items: groupItems.isNotEmpty ? groupItems : provider.allFiles.take(8).toList()`
    When a newly created group has 0 items (`groupItems.isEmpty`), it actively falls back to injecting 8 sample files from `provider.allFiles`!
- **Absence of Add Button in Group Detail**:
  - `FolderDetailScreen` (`d:\E-player\app\lib\features\library\ui\folder_detail_screen.dart:280–292`) only receives `folderName` and `items`. When `filtered.isEmpty`, it shows a static text: `"No media files found in \"...\""`. It has no `groupId` reference and no "Add" button to add files or folders to the group.

### 1.5 Folder and File Management in Groups
- **Distinguishing Built-in Features vs Custom Groups/Folders/Files**:
  - Built-in App Features on Home:
    - Quick Category Chips: `['All', 'History', 'Videos', 'Groups', 'Audio', 'Favorites']` (`home_screen.dart:293`)
    - History Section: resume card / grouped recent items (`home_screen.dart:349`)
    - Action Cards: "Create Group (+)" and "Videos (+)" (`home_screen.dart:708–743`)
    - Media Library section (`home_screen.dart:960`)
    - Favorites Rail (`home_screen.dart:1250`)
    - App bar controls (PRO badge, Filter, Refresh, Search, Cast, Settings)
  - Built-in App Features on Library:
    - Filter Tabs strip: `['All', 'Videos', 'Audio', 'Playlists', 'Folders']` (`library_screen.dart:38`)
    - Curated Smart Playlists (`library_screen.dart:1312–1350`)
    - App bar actions and floating scan button
  - Selectable Custom Entities:
    - Custom Groups in "My Groups & Playlists" (`home_screen.dart:881`)
    - Folders in Media Library or Library screen (`library_screen.dart:1263`)
    - Video files in Media Library, Library screen, or inside Folder/Group Detail screens.
- **Item Deletion**:
  - From custom group: `MediaGroupService.removeItemFromGroup(groupId, path)` (`media_group_service.dart:156–167`). Only removes path from `group.itemPaths`; does not delete physical file.
  - From Library/Disk: `DatabaseHelper.instance.deleteItem(path)` / `deleteBatch(paths)` and `TrashService.moveToTrash(item)`.
- **Item Moving**:
  - No existing move-to-group operation exists in `FolderDetailScreen`, `HomeScreen`, or `LibraryScreen`.
  - `MediaGroupService` only has single `addItemToGroup` (`media_group_service.dart:140–153`). It lacks batch addition, batch removal, and atomic inter-group transfer.

### 1.6 History Section Behavior (R4)
- In `HomeScreen._buildHistorySection` (`home_screen.dart:354–363`):
  - In flat mode (`GroupMode.none`), it displays exactly **one** item (`provider.recentFiles.first`).
  - In grouped mode (`GroupMode.byFolder` / `byName`), it maps `groupedRecentFiles.take(4)` with non-scrollable column layout.
  - `LibraryProvider._loadFromDB` (`library_provider.dart:122`) loads 50 recents (`take(50)`).
  - R4 requires smooth scrolling with an explicit 5-item limit.

### 1.7 Media Library Filtering (R5)
- In `HomeScreen._buildCompactMediaGrid` (`home_screen.dart:965–1176`):
  - Hardcodes 4 categories: `Movies`, `Series`, `Anime`, `Music` with dummy fallback counts (24, 12, 18, 32).
  - R5 requires completely removing music, series, and anime categories/cards, and displaying only videos and video folders from the Library.

---

## 2. Logic Chain

1. **Empty Group Initialization (R1)**:
   - *Premise 1*: `MediaGroupService.createGroup()` already initializes `itemPaths: []` (`media_group_service.dart:122`).
   - *Premise 2*: `HomeScreen` lines 885–896 computes `groupItems = provider.allFiles.where(...)` and opens `FolderDetailScreen` with `items: groupItems.isNotEmpty ? groupItems : provider.allFiles.take(8).toList()`.
   - *Inference*: The display of sample items is not caused by the model or service, but by the conditional ternary operator in `home_screen.dart:896`. Changing `items:` to `groupItems` (or passing `groupId` and resolving items strictly from `group.itemPaths`) guarantees that newly created groups open with zero items.

2. **Add Button Integration (R1)**:
   - *Premise 1*: When `FolderDetailScreen` is opened for a `MediaGroup`, the user needs to add files or folders into that group.
   - *Premise 2*: `FolderDetailScreen` currently only accepts `folderName` and `items`, lacking `groupId` context.
   - *Inference*: Expanding `FolderDetailScreen` to accept optional `String? groupId` allows it to distinguish a custom group from a physical directory. When `groupId != null`:
     - Render an "Add" button in empty state (`items.isEmpty`) and in the AppBar / bottom bar.
     - Tapping "Add" presents options to pick video files (`FilePicker.pickFiles`) or pick folders (`FilePicker.getDirectoryPath()`) or select from indexed Library items.
     - On selection, add the paths to `MediaGroupService` via `addItemToGroup` / `addItemsToGroup` and update the view.

3. **Multi-Select and Batch Actions Architecture (R2 & R3)**:
   - *Premise 1*: Multi-selection already has a reference pattern in `TrashScreen` (`d:\E-player\app\lib\features\trash\ui\trash_screen.dart:287–316`) using `_isMultiSelectMode`, `_selectedTrashPaths = <String>{}`, `onLongPress: () => _toggleSelection(id)`, and an action bar with "Select All", "Delete", and "Restore".
   - *Premise 2*: Requirement R2 and R3 demand applying long-press multi-selection, "Select All", delete, and move-to-group to custom groups, folders, and files across Home and Library screens, while strictly excluding built-in features.
   - *Inference*: A reusable selection state controller or state mixin can be implemented for `HomeScreen`, `LibraryScreen`, and `FolderDetailScreen`:
     - Tracks `Set<String> selectedIds` (paths or group IDs) and `bool isMultiSelect`.
     - `onLongPress` on custom group card, folder card, or file card triggers selection mode and adds item.
     - "Select All" toggles selection of all selectable items in the active container.
     - Delete action:
       - If items are in a custom group: calls `groupService.removeItemsFromGroup(groupId, selectedPaths)`.
       - If items are custom groups on Home: calls `groupService.deleteGroup(id)`.
       - If items are files/folders in Library: calls `trashService.moveToTrash(item)` and `DatabaseHelper.instance.deleteBatch(paths)`.
     - Move action:
       - Displays `MoveToGroupDialog` showing available groups in `MediaGroupService.groups`.
       - Transfers items into chosen group and updates persistent storage.

4. **History Scrolling & 5-Item Limit (R4)**:
   - *Premise 1*: `HomeScreen._buildHistorySection` currently shows either 1 item (flat) or 4 items (grouped) without smooth horizontal scrolling.
   - *Premise 2*: Requirement R4 mandates smooth browsing with a strict maximum of 5 items.
   - *Inference*: In `HomeScreen`, restrict `recentFiles` / `groupedRecentFiles` with `.take(5).toList()` and wrap the cards inside a `ListView.separated` or `SingleChildScrollView` with horizontal scroll physics (`BouncingScrollPhysics`), matching UI Reference Image 2.

5. **Media Library Video-Only Filtering (R5)**:
   - *Premise 1*: The Home screen Media Library currently shows a 4-category Bento grid (Movies, Series, Anime, Music).
   - *Premise 2*: Requirement R5 requires removing music, series, and anime categories, and displaying only videos and their containing folders from the Library.
   - *Inference*: Replace `_buildCompactMediaGrid` with a video-only view:
     - Filter `provider.allFiles` for video extensions (`.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, etc.).
     - Group videos by their parent folder (`provider.groupedFolders` filtered to video files).
     - Render video folder cards and/or video cards with multi-select support.

---

## 3. Caveats

1. **Dual SQLite Implementations in Codebase**:
   - `d:\E-player\app\lib\core\db\database_helper.dart` (flat `media_items` table) is the active persistence layer used by `LibraryProvider`.
   - `d:\E-player\app\lib\core\db\media_library_database.dart` (relational VLC WAL schema) exists with complete migration logic, but `LibraryProvider` currently queries `DatabaseHelper`. Any implementation should operate against `DatabaseHelper` (and `MediaGroupService` for groups) to ensure consistency with existing tests and runtime providers.
2. **`MediaGroup` Structure**:
   - Currently `MediaGroup` contains `itemPaths: List<String>`. When a folder is added to a group, we can store the individual media file paths inside that folder, or store the folder path and resolve its contents dynamically. Storing media paths ensures deterministic file counts and immediate playback compatibility.
3. **External Platform Permissions**:
   - On Windows desktop, file access is direct. On Android, runtime permissions are handled via `MediaScannerService.requestAndroidPermissions()`.

---

## 4. Conclusion

1. **Groups Storage & Creation**:
   - Groups are managed by `MediaGroupService` and persisted as JSON in `SharedPreferences` under key `'eplayer_custom_media_groups_v1'`.
   - `MediaGroupService.createGroup()` initializes groups completely empty (`itemPaths: []`).
   - The appearance of sample items is due entirely to `home_screen.dart:896` (`provider.allFiles.take(8).toList()`). Removing this fallback and passing `groupId` to `FolderDetailScreen` ensures new groups open completely empty.
2. **Add Button in Empty Group**:
   - `FolderDetailScreen` must accept `String? groupId`. When `groupId != null`, an Add button should be rendered both in the empty state and in the AppBar, allowing users to pick files or folders to add to the group.
3. **Multi-Select and Batch Actions**:
   - Add multi-selection to `HomeScreen`, `LibraryScreen`, and `FolderDetailScreen`, mirroring the pattern in `TrashScreen`.
   - Built-in features (category pills, quick action cards, app bar, navigation) do not handle `onLongPress`.
   - Selected items can be deleted (removed from group or library) or moved to another group via `MediaGroupService`.
4. **History & Media Library Filtering**:
   - Cap `HomeScreen` History to `provider.recentFiles.take(5)` inside a scrollable container.
   - Replace the 4-box Bento grid in Home Media Library with video-only folders and files, completely eliminating music, series, and anime categories.

---

## 5. Verification Method

### 5.1 Static Analysis
Execute static analysis from the app root:
```powershell
cd d:\E-player\app
dart analyze
```
Expected: `No issues found!` (0 errors, 0 warnings).

### 5.2 Unit and Service Tests
Execute the Flutter test suite:
```powershell
cd d:\E-player\app
flutter test test/media_group_service_test.dart
flutter test
```
Expected: All tests pass.

### 5.3 Verification of Code Locations
1. Verify `home_screen.dart:885–899` contains the `provider.allFiles.take(8)` bug.
2. Verify `media_group_service.dart:108–130` creates `MediaGroup` with `itemPaths: []`.
3. Verify `database_helper.dart:36–47` defines table `media_items` and contains `deleteBatch`.
4. Verify `trash_screen.dart:287–316` contains the canonical multi-selection reference implementation.
