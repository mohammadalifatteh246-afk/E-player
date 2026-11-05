# Codebase Explorer Aura — UI/UX Architecture & Widget Investigation Report

**Working Directory**: `d:\E-player\.agents\teamwork\explorer_survey_aura`  
**Target Codebase**: `d:\E-player\app`  
**Timestamp**: `2026-11-04T12:25:00Z`  
**Status**: Investigation Complete — Ready for Implementation  

---

## 1. Observation

### 1.1 Reference Images Verification
- **Reference Image 1 (`media_1793791961445_d3e0263c.jpg`)**:
  - Displays the Home Screen top layout:
    - App Header: Logo with "E-Player PRO" badge, right action icons (`Filter` button, refresh, search, cast, settings).
    - Top Quick Action Cards: "Create Group" (showing "2 groups created" with cyan plus icon button) and "Videos" (showing "6 media indexed" with emerald plus icon button).
    - "My Groups & Playlists" Section: Header with right-aligned `+` action; horizontal card row featuring custom groups ("SERIES", "anime") with colored user icon, title, and "0 items".
    - "Media Library" Section: Header with right-aligned `Group` button. Currently renders 4 category cards: "Movies" (4 items), "Series" (12 items), "Anime" (18 items), and "Music" (2 items).
    - Bottom Navigation Bar: "Home" (active), "Library", "Enhance", "Casting", "Settings".
- **Reference Image 2 (`media_1793791964373_fbec4386.jpg`)**:
  - Category Pills Strip: `['All', 'History', 'Videos', 'Groups', 'Audio', 'Favorites']` with "All" actively selected.
  - History Section:
    - Header: History counter-clockwise clock icon, "History" title, right-side meta "6 recent", and `[folder icon] By Folder` dropdown.
    - Vertical list of recent items/folders:
      - Item 1: Folder artwork, `FOLDER`, `1 Video`, title `Downloads`, path `C:\Users\Admin\Downloads`, play button, chevron dropdown, `00:00 · 5.8 MB`.
      - Item 2: Folder artwork, `FOLDER`, `1 Video`, title `Music`, path `C:\Users\Admin\Music`, play button, chevron dropdown, `00:00 · 5.8 MB`.
      - Item 3: Folder artwork, `FOLDER`, `4 Videos`, title `Videos`, path `C:\Users\Admin\Videos`, play button, chevron dropdown, `00:00 · 33.9 MB`.

---

### 1.2 Baseline Verification
- **Static Analysis**:
  ```powershell
  cd d:\E-player\app; dart analyze
  ```
  Result:
  ```
  Analyzing app...
  No issues found!
  ```
- **Existing Group Service Unit Tests**:
  ```powershell
  cd d:\E-player\app; flutter test test/media_group_service_test.dart
  ```
  Result:
  ```
  00:00 +0: MediaGroupService Unit Tests Initializes with empty groups
  00:00 +1: MediaGroupService Unit Tests Creates new group and notifies listeners
  00:00 +2: MediaGroupService Unit Tests Adds and removes media paths from group
  00:00 +3: MediaGroupService Unit Tests Deletes group properly
  00:00 +4: All tests passed!
  ```

---

### 1.3 Key Source File Observations & Line Numbers

#### A. Home Screen (`d:\E-player\app\lib\features\home\ui\home_screen.dart`)
1. **Group Creation Triggers**:
   - Lines 716-717 in `_buildActionCardsRow`:
     ```dart
     onTap: () => _showCreateGroupDialog(context, groupService),
     onPlusTap: () => _showCreateGroupDialog(context, groupService),
     ```
   - Line 871 in `_buildCustomGroupsSection`:
     ```dart
     IconButton(
       icon: const EVectorIcon(name: 'plus', size: 16, color: EDesign.primary),
       tooltip: 'Create New Group',
       onPressed: () => _showCreateGroupDialog(context, groupService),
     ),
     ```
   - Lines 1536-1651: `_showCreateGroupDialog(BuildContext context, MediaGroupService groupService)` shows dialog and calls:
     ```dart
     await groupService.createGroup(
       title: name,
       color: selectedColor,
     );
     ```
2. **Defect in Empty Group Navigation**:
   - Lines 884-899 in `_buildCustomGroupsSection`:
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
     **Direct Finding**: Line 895 deliberately falls back to `provider.allFiles.take(8).toList()` when `groupItems` is empty. A freshly created group with zero items was therefore displaying 8 files instead of remaining empty inside!
3. **History Section Display Defect (R4)**:
   - Lines 354-685 in `_buildHistorySection`:
     - When `provider.groupMode == GroupMode.none`:
       ```dart
       final recent = provider.recentFiles.isNotEmpty ? provider.recentFiles.first : null;
       ...
       InkWell(
         height: isDesktop ? 130 : 120,
         ...
         // Single 16:9 card displaying only recent.name or 'The Last Horizon (4K Remaster)'
       ```
     - It only shows a single item (or mock) rather than a scrollable list of up to 5 items as required by R4 and shown in Reference Image 2.
4. **Media Library Bento Grid Defect (R5)**:
   - Lines 960-1178 in `_buildCompactMediaGrid`:
     - Hardcodes 4 categories in a `GridView.count`: "Movies", "Series", "Anime", "Music".
     - R5 explicitly requires: "Filter the Media Library on the Home screen so that it displays only videos and their containing folders from the Library. Remove the music, series, and anime category sections."
5. **Lack of Multi-Selection Gestures**:
   - Custom Group cards (`_buildCustomGroupsSection` lines 887-951) only have `onTap`. No `onLongPress`.
   - Media Library items have no `onLongPress` and no selection tracking.

---

#### B. Folder & Group Detail Screen (`d:\E-player\app\lib\features\library\ui\folder_detail_screen.dart`)
1. **Constructor & Group Awareness**:
   - Lines 13-21:
     ```dart
     class FolderDetailScreen extends StatefulWidget {
       final String folderName;
       final List<MediaItem> items;
       const FolderDetailScreen({super.key, required this.folderName, required this.items});
     ```
     **Direct Finding**: `FolderDetailScreen` does not receive `groupId` or `MediaGroup`. It treats custom groups identically to read-only disk folders and cannot add or remove items from `MediaGroupService`.
2. **Empty State & Missing Add Button**:
   - Lines 280-292:
     ```dart
     filtered.isEmpty
         ? SingleChildScrollView(
             physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
             child: SizedBox(
               height: 300,
               child: Center(
                 child: Text(
                   'No media files found in "${p.basename(widget.folderName)}".',
                   style: EDesign.secondaryStyle,
                 ),
               ),
             ),
           )
     ```
     **Direct Finding**: When empty, it only displays static muted text. There is NO Add button anywhere in the viewport, AppBar, or FAB.
3. **Lack of Multi-Select Gestures**:
   - Grid Card (`_buildGridCard` line 365): `InkWell(onTap: () { ... })` — No `onLongPress`.
   - List Card (`_buildListCard` line 440): `ListTile(onTap: () { ... })` — No `onLongPress`.
   - Item popup menu (`_buildItemPopupMenu` lines 486-517): Only offers "Move to Vault" and "Move to Trash". No multi-select, no "Move to Group", no "Select All".

---

#### C. Library Screen (`d:\E-player\app\lib\features\library\ui\library_screen.dart`)
1. **Rendering Modes & Widgets**:
   - Poster Grid (`_buildPosterCard` lines 858-1038): 16:9 poster card wrapped in `InkWell(onTap: ...)` (line 880). No `onLongPress`.
   - List Row (`_buildListRow` lines 1041-1137): `ListTile(onTap: ...)` (line 1128). No `onLongPress`.
   - Folders List (`_buildFolderTile` lines 1263-1301): `ListTile(onTap: ...)` (line 1291). No `onLongPress`.
   - Playlists View (`_buildPlaylistsView` lines 1304-1400): Displays 4 smart/curated playlists ("Favorite Media", "4K Ultra HD & HDR", "Recently Added Media", "Binge Watch Queue"). These are built-in features that must NOT be selectable or deletable.
2. **Context Menu Actions**:
   - Lines 1140-1259 (`_buildItemContextMenu`): Offers play, info, favorite, vault, trash. No move-to-group or batch operations.

---

#### D. Media Group Service (`d:\E-player\app\lib\features\home\domain\media_group_service.dart`)
1. **State & Storage**:
   - Backed by `SharedPreferences` key `'eplayer_custom_media_groups_v1'`.
   - `MediaGroup` model has: `id`, `title`, `description`, `colorValue`, `iconName`, `itemPaths`, `createdAt`.
2. **Existing Methods**:
   - `createGroup`: Inserts a new group with `itemPaths: initialPaths` (default empty `[]`).
   - `deleteGroup`: Removes group by id.
   - `addItemToGroup(String groupId, String path)`: Appends single path if not already present.
   - `removeItemFromGroup(String groupId, String path)`: Removes single path.
3. **Missing Batch Capabilities**:
   - Currently lacks `addItemsToGroup(String groupId, List<String> paths)` and `removeItemsFromGroup(String groupId, List<String> paths)`. Adding batch operations will prevent repeated `notifyListeners()` and disk I/O on large selections.

---

## 2. Logic Chain

```
[Observation: HomeScreen:895 falls back to provider.allFiles.take(8).toList()]
       │
       ▼
[Deduction 1: Newly created custom groups appeared non-empty because HomeScreen fed dummy items to FolderDetailScreen]
       │
       ▼
[Observation: FolderDetailScreen does not receive groupId; displays static text when filtered.isEmpty]
       │
       ▼
[Deduction 2: FolderDetailScreen needs groupId parameter to bind to MediaGroupService, and an empty state "Add" action button to populate it]
       │
       ▼
[Observation: HomeScreen, FolderDetailScreen, and LibraryScreen only bind onTap to PlayerScreen/Navigation; no onLongPress exists]
       │
       ▼
[Deduction 3: A unified MultiSelect state is needed across Home, FolderDetail, and Library to intercept tap/long-press gestures]
       │
       ▼
[Observation: Built-in features (Action Cards, Category Pills, Playlists, App Bars) coexist with custom groups and media items]
       │
       ▼
[Deduction 4: Gesture handlers must explicitly bind multi-select ONLY to user selectable targets (custom groups, media files, user folders), while built-in cards remain unselectable]
       │
       ▼
[Observation: R4 requires scrollable 5-item history list; HomeScreen currently renders single item or 4 groups]
       │
       ▼
[Deduction 5: History section must be refactored into a scrollable list view capped at take(5)]
       │
       ▼
[Observation: R5 requires video-only media library; HomeScreen currently renders 4-category grid including music, series, anime]
       │
       ▼
[Deduction 6: HomeScreen._buildCompactMediaGrid must filter to videos only, removing music, series, and anime cards]
```

---

## 3. Detailed UI/UX Architectural Blueprint

### 3.1 Requirement R1: Empty Group Creation with Add Button

#### Component Breakdown & Flow:
1. **Creation Trigger**:
   - User taps "+" on "Create Group" action card or "My Groups & Playlists" header.
   - `_showCreateGroupDialog` opens.
   - User types title (e.g. "Work Demos") and picks a color.
   - Group is created via `groupService.createGroup(title: name, color: selectedColor)`.
   - `newGroup.itemPaths` is initialized to `[]` (empty list).
2. **Navigation Fix in `HomeScreen._buildCustomGroupsSection`**:
   - Replace:
     ```dart
     FolderDetailScreen(
       folderName: group.title,
       items: groupItems.isNotEmpty ? groupItems : provider.allFiles.take(8).toList(),
     )
     ```
     With:
     ```dart
     FolderDetailScreen(
       folderName: group.title,
       items: groupItems, // Empty when newly created!
       groupId: group.id,
     )
     ```
3. **Empty State & "Add" Button in `FolderDetailScreen`**:
   - Add parameter `final String? groupId;` to `FolderDetailScreen`.
   - When `filtered.isEmpty`:
     - Render an empty state widget (`EEmptyState` or custom card):
       - Icon: `Icons.create_new_folder_outlined` / `Icons.video_library_outlined`
       - Title: `'This group is empty'`
       - Message: `'Add videos or folders to organize this group'`
       - Primary Action Button: `EPrimaryButton(label: 'Add Media / Folders', icon: Icons.add, expand: false, onPressed: () => _showAddMediaSheet(context))`
     - In the AppBar:
       - Include an Add button: `IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: EDesign.primary), tooltip: 'Add to Group', onPressed: () => _showAddMediaSheet(context))`
4. **"Add Media / Folders" Sheet Options**:
   - When "Add" is tapped, present a bottom modal sheet:
     - **Option 1: "Select from Media Library"**:
       Displays a dialog/sheet with all library videos (`provider.allFiles`) with checkboxes. Checking items and pressing "Add Selected" calls `groupService.addItemsToGroup(groupId, selectedPaths)`.
     - **Option 2: "Pick Video Files"**:
       Opens `FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true)` and adds the returned paths.
     - **Option 3: "Add Folder"**:
       Opens `FilePicker.platform.getDirectoryPath()`, finds video files within the folder, and adds them to the group.

---

### 3.2 Requirements R2 & R3: Long-Press Multi-Select, Select All, Delete, and Move

#### Unified Multi-Selection State Model:
Each screen (`HomeScreen`, `FolderDetailScreen`, `LibraryScreen`) tracks:
```dart
bool _isSelectionMode = false;
final Set<String> _selectedItemPaths = <String>{};
```
(On `HomeScreen`, custom groups track `final Set<String> _selectedGroupIds = <String>{};`).

#### Gesture Specification:
| State | Gesture on Target | Action |
|---|---|---|
| **Normal** (`_isSelectionMode == false`) | `onTap` | Normal operation: play video (`PlayerScreen`) or open folder/group (`FolderDetailScreen`). |
| **Normal** | `onLongPress` | Trigger `HapticFeedback.selectionClick()`, set `_isSelectionMode = true`, add target path/ID to selected set, call `setState()`. |
| **Selection Mode** (`_isSelectionMode == true`) | `onTap` | Toggle item in selected set. If selected set becomes empty, set `_isSelectionMode = false`. Normal navigation is intercepted. |
| **Selection Mode** | `onLongPress` | Toggle item in selected set. |

#### Visual Indicators for Selected Items:
1. **Cards & Tiles**:
   - Selected state adds a highlight border: `Border.all(color: EDesign.primary, width: 2.0)`.
   - Subtle cyan background tint: `EDesign.primary.withValues(alpha: 0.12)`.
   - Top-left badge: Circular cyan checkmark icon (`Icons.check_circle_rounded`, color `EDesign.primary`).
   - Unselected items in selection mode show a hollow circle (`Icons.radio_button_unchecked`, color `EDesign.textMuted`).

#### Contextual Action Bar (Replaces normal AppBar during selection):
When `_isSelectionMode == true`, the standard AppBar is replaced with a Contextual Action Bar:
- **Leading**: `IconButton(icon: Icon(Icons.close_rounded), tooltip: 'Cancel', onPressed: _exitSelectionMode)`
- **Title**: `Text('${_selectedItemPaths.length} Selected', style: TextStyle(fontWeight: FontWeight.bold, color: EDesign.textPrimary, fontSize: 16))`
- **Actions**:
  1. **"Select All"**:
     ```dart
     TextButton.icon(
       icon: Icon(_selectedItemPaths.length == allItems.length ? Icons.deselect : Icons.select_all_rounded, size: 18, color: EDesign.primary),
       label: Text(_selectedItemPaths.length == allItems.length ? 'Deselect All' : 'Select All', style: TextStyle(color: EDesign.primary, fontWeight: FontWeight.bold)),
       onPressed: () {
         setState(() {
           if (_selectedItemPaths.length == allItems.length) {
             _selectedItemPaths.clear();
             _isSelectionMode = false;
           } else {
             _selectedItemPaths.addAll(allItems.map((e) => e.path));
           }
         });
       },
     )
     ```
  2. **"Move to Group"**:
     ```dart
     IconButton(
       icon: const Icon(Icons.drive_file_move_outlined, color: EDesign.textPrimary),
       tooltip: 'Move to Group',
       onPressed: () => _showMoveToGroupSheet(context),
     )
     ```
     - **Move Sheet Design**:
       Opens modal bottom sheet listing all user groups from `groupService.groups`.
       Includes "+ Create New Group" tile.
       On picking a destination group:
       - Adds selected paths: `groupService.addItemsToGroup(targetGroup.id, _selectedItemPaths.toList())`.
       - If currently inside a source group (`widget.groupId != null`), removes them from source: `groupService.removeItemsFromGroup(widget.groupId!, _selectedItemPaths.toList())`.
       - Exits selection mode and displays `SnackBar(content: Text('Moved ${_selectedItemPaths.length} items to "${targetGroup.title}"'))`.
  3. **"Delete"**:
     ```dart
     IconButton(
       icon: const Icon(Icons.delete_outline_rounded, color: EDesign.danger),
       tooltip: 'Delete Selected',
       onPressed: () => _confirmDeleteSelected(context),
     )
     ```
     - **Delete Confirmation Dialog**:
       Shows an `AlertDialog`:
       - Title: `'Delete ${_selectedItemPaths.length} Selected Items?'`
       - Content: Text explanation ('Are you sure you want to delete these items? This action cannot be undone.').
       - Actions: "Cancel" (text) and "Delete" (`EDesign.danger`).
       - On confirm:
         - If inside a custom group: removes selected paths from group.
         - If in Library / Home: deletes items from `LibraryProvider` (`DatabaseHelper.instance.deleteItem`) or moves to `TrashService`.
         - If custom groups are selected on Home screen: deletes the selected groups (`groupService.deleteGroup(id)`).
         - Exits selection mode.

---

### 3.3 Built-in / Default Feature Protection (Exclusion Rules)
To satisfy R2 ("This selection behavior must not apply to built-in / default app features"):
1. **Home Screen Action Cards ("Create Group", "Videos")**:
   - Built-in navigational / ingest utilities.
   - Must have `onLongPress: null`.
   - In selection mode, taps on these cards do not participate in selection.
2. **Category Chips ("All", "History", "Videos", "Groups", "Audio", "Favorites")**:
   - Filter chips. Never selectable.
3. **Smart Curated Playlists in Library Screen ("Favorite Media", "4K Ultra HD & HDR", "Recently Added Media", "Binge Watch Queue")**:
   - Hardcoded smart queries.
   - Must have `onLongPress: null`. Never selectable, deletable, or movable.
4. **App Bar Controls & Bottom Navigation Bar**:
   - Standard app framework. Never selectable.

---

### 3.4 Requirement R4: Scrollable History with 5-Item Limit
- In `HomeScreen._buildHistorySection`:
  - Limit the displayed items using `provider.recentFiles.take(5).toList()`.
  - Replace the single 130px card with a scrollable list:
    ```dart
    final recentItems = provider.recentFiles.take(5).toList();
    ```
  - Display them in a smooth `ListView.separated` (or `SingleChildScrollView` row/column) matching the visual layout of Reference Image 2:
    - Thumbnail preview with folder/file badge.
    - Title, parent directory path.
    - Duration and file size badge.
    - Quick play button and dropdown chevron.
    - Capped strictly at `take(5)`.

---

### 3.5 Requirement R5: Media Library Video-Only Filtering
- In `HomeScreen._buildCompactMediaGrid`:
  - Completely remove the music, series, and anime categories and cards.
  - Filter `provider.allFiles` strictly for video files:
    ```dart
    final videoFiles = provider.allFiles.where((file) {
      final ext = p.extension(file.path).toLowerCase();
      return ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.wmv', '.m4v'].contains(ext);
    }).toList();
    ```
  - If in folder/grouped mode: display only folders containing video files.
  - If in flat mode: display video cards / folders, removing any music or audio files from the grid.

---

## 4. Caveats
1. **Platform File System Permissions on Android**: Adding files from arbitrary directories outside standard media storage on Android may require scoped storage or runtime permissions (`MediaScannerService.requestAndroidPermissions()`).
2. **File Deletion Semantics**: Requirement R2 mentions "deleted or moved to another group". When deleting files from within a custom group, the primary action is removing them from that group's `itemPaths`. When deleting from the general Library, the deletion removes the item record from the library database and/or disk. Both behaviors should be cleanly surfaced to the user.
3. **No Code Written**: Per the explorer archetype constraints, this survey is 100% read-only and no application source code was modified during this investigation.

---

## 5. Conclusion
1. **R1 (Empty Group Creation & Add Button)**:
   - Root cause identified: `HomeScreen:895` falsifies contents with `provider.allFiles.take(8).toList()` when empty.
   - Solution: Pass `items: groupItems` (empty list) and `groupId: group.id`. Inside `FolderDetailScreen`, render an empty state card with an "Add Media / Folders" button, plus an AppBar action button to add files or folders.
2. **R2 & R3 (Long-Press Multi-Select, Select All, Delete, Move across Home & Library)**:
   - Implement unified selection state (`_isSelectionMode`, `_selectedItemPaths`).
   - Add `onLongPress` to custom groups, media cards, and folder tiles.
   - Contextual Top App Bar with selected count, "Select All", "Move to Group" picker, and "Delete" with confirmation dialog.
   - Explicit exclusion of built-in cards (Create Group, Videos, Category Pills, Smart Playlists) protects system features.
3. **R4 (Scrollable History Capped at 5)**:
   - Refactor `_buildHistorySection` to render `provider.recentFiles.take(5)` in a smooth scrollable list matching Reference Image 2.
4. **R5 (Media Library Video-Only Filtering)**:
   - Refactor `_buildCompactMediaGrid` to filter only video files/folders and eliminate Music, Series, and Anime category cards.

---

## 6. Verification Method

To independently verify the architecture and downstream implementation:
1. **Static Analysis**:
   ```powershell
   cd d:\E-player\app
   dart analyze
   ```
   *Expected*: Zero errors, zero warnings.
2. **Unit & Service Tests**:
   ```powershell
   cd d:\E-player\app
   flutter test test/media_group_service_test.dart
   ```
   *Expected*: 4/4 passed.
3. **Manual / Widget Verification Steps**:
   - **R1 Verification**: Create a new group on Home screen -> tap to open it -> verify it shows 0 items (completely empty) and displays the "Add Media / Folders" button. Tap Add -> select video files -> verify they appear in the group.
   - **R2 & R3 Verification**: Long-press any item in Home or Library -> verify selection mode activates with cyan border and counter in Top App Bar. Tap "Select All" -> verify all items selected. Tap "Move to Group" -> select target group -> verify items moved. Tap "Delete" -> confirm dialog -> verify items removed. Verify long-pressing "Create Group", "Videos", or category chips does NOT trigger selection.
   - **R4 Verification**: Inspect Home Screen History -> verify it displays a scrollable list of recent items capped at 5.
   - **R5 Verification**: Inspect Home Screen Media Library -> verify music, series, and anime cards are gone, and only video items/folders are displayed.
