# Milestone 3 Investigation Report: Scrollable 5-Item History & Video-Only Media Library (R4 & R5)

**Agent**: AURA (teamwork_explorer)  
**Target Files**: `lib/features/home/ui/home_screen.dart`, `test/e2e/e2e_requirements_test.dart`  
**Reference Material**: UI Reference Image 1 (`media_1793791961445_d3e0263c.jpg`), UI Reference Image 2 (`media_1793791964373_fbec4386.jpg`)

---

## 1. Observation

### 1.1 Existing History Section UI & Physics (`home_screen.dart:585–925`)
In `lib/features/home/ui/home_screen.dart`:
- **Single Item Hardcoding in Flat Mode** (Lines 590, 726–922):
  ```dart
  final recent = provider.recentFiles.isNotEmpty ? provider.recentFiles.first : null;
  final bool hasRealRecent = recent != null;
  ```
  In flat mode (`provider.groupMode == GroupMode.none`), `_buildHistorySection` renders only a single `InkWell` containing one `Container` (lines 751–921) representing either `recent.first` or fallback demo metadata ('The Last Horizon (4K Remaster)'). It does not render a list or carousel of items, making it impossible to browse past the very first recent item.
- **Grouped Recent Limit Bug** (Line 717):
  ```dart
  if (provider.groupMode != GroupMode.none && provider.groupedRecentFiles.isNotEmpty) ...[
    ...provider.groupedRecentFiles.take(4).map((group) {
  ```
  In grouped mode, it explicitly caps at `take(4)` instead of the mandated 5 items.
- **Scroll Physics & Viewport Context**:
  The entire screen body is wrapped in a `SingleChildScrollView` (line 307) with `physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`. However, the History section in flat mode lacks its own horizontal scroll container.

### 1.2 Existing Media Library Section & Bento Grid (`home_screen.dart:1219–1507`)
- **4-Category Bento Grid Hardcoding** (Lines 1224–1255, 1365–1434):
  `_buildCompactMediaGrid` scans `provider.allFiles` and counts:
  ```dart
  int moviesCount = 0;
  int seriesCount = 0;
  int animeCount = 0;
  int musicCount = 0;
  ```
  With mock fallback counts: `displayMovies = moviesCount > 0 ? moviesCount : 24;`, `displaySeries = ... 12;`, `displayAnime = ... 18;`, `displayMusic = ... 32;`.
- **Bento Category Cards Rendering** (Lines 1365–1434):
  In flat mode (`provider.groupMode == GroupMode.none`), it renders `GridView.count` with 4 `_buildCompactCategoryCard` widgets for:
  - `Movies` (`$displayMovies items`)
  - `Series` (`$displaySeries items`)
  - `Anime` (`$displayAnime items`)
  - `Music` (`$displayMusic items`)
- **Helper Card Method** (Lines 1440–1507):
  `_buildCompactCategoryCard` renders the frosted Bento tiles with thumbnail overlays and subtitles like `18 items` and `12 items`.
- **Audio Category Leak** (Line 1220):
  ```dart
  if (_selectedCategory != 'All' && _selectedCategory != 'Videos' && _selectedCategory != 'Audio')
  ```
  Allows filtering by 'Audio', which violates video-only filtering.

### 1.3 Test Suite Expectations (`test/e2e/e2e_requirements_test.dart`)
- **Feature 9 (History Scrollable View)**:
  - `9.1`: History section renders inside a scrollable viewport (`find.byType(SingleChildScrollView)`).
  - `9.2`: History viewport responds smoothly to horizontal drag gestures (`await tester.drag(historySection, const Offset(-100, 0))`).
  - `9.3`: History scroll physics uses `BouncingScrollPhysics` or smooth physics (`s.physics is BouncingScrollPhysics || s.physics is AlwaysScrollableScrollPhysics`).
  - `9.5`: History items can be browsed smoothly (`await tester.drag(find.text('History'), const Offset(0, -150))`).
- **Feature 10 (History Strict 5-Item Cap)**:
  - `10.1`, `10.2`, `10.3`: When >5 items exist, strict cap of 5; when <=5, render exact count.
  - `10.4`: 0 recent files handled gracefully without crashing.
  - `10.5`: In grouped mode, `groupedRecentFiles` takes at most 5 items.
  - `Scenario 4`: 10 recent videos seeded; renders strictly 5 items with smooth horizontal drag.
- **Feature 11 & 12 (Video-Only Filter & Removal of Music/Series/Anime)**:
  - `11.1–11.4`: Audio extensions (`.mp3`, `.flac`, `.wav`, `.m4a`) and audio-only folders are excluded; only video files are counted.
  - `12.1`: Bento category cards (Movies, Series, Anime, Music) are removed (`expect(find.text('Music'), findsNothing); expect(find.text('Anime'), findsNothing); expect(find.text('Series'), findsNothing)`).
  - `12.2–12.4`: Text "Music", "Series", "Anime" category sections are not rendered as `InkWell`.
  - `12.5` & `Scenario 5`: Mock item counts (`18 items`, `12 items`) are completely eliminated.

---

## 2. Logic Chain

### 2.1 Requirement R4 — Scrollable History with 5-Item Cap
1. **Observation**: `_buildHistorySection` currently extracts only `provider.recentFiles.first` in flat mode and renders a single static card (lines 590, 751).
2. **Inference**: To allow browsing recent media items as mandated by R4 and verified in tests 9.2, 9.5, and Scenario 4, the flat mode must render a horizontal scrolling carousel (`ListView.separated` with `scrollDirection: Axis.horizontal` and `physics: const BouncingScrollPhysics()`).
3. **Observation**: In grouped mode, line 717 currently uses `take(4)`.
4. **Inference**: To enforce the 5-item cap across both flat and grouped modes (PROJECT.md Feature 11, test 10.5), both branches must enforce `.take(5)`:
   - Flat mode: `final cappedRecents = provider.recentFiles.take(5).toList();`
   - Grouped mode: `provider.groupedRecentFiles.take(5).map(...)`
5. **Observation**: When `provider.recentFiles.isEmpty`, tests 10.4 and 2.4 verify that the empty state does not throw any exceptions.
6. **Inference**: If `cappedRecents` is empty, render a graceful fallback demo card inside the horizontal container or single container, ensuring zero crashes while keeping the header `'History'` visible.

### 2.2 Requirement R5 — Video-Only Media Library & Removal of Bento Cards
1. **Observation**: Lines 1365–1434 render the 4-box Bento grid (`Movies`, `Series`, `Anime`, `Music`) with mock counts (`18 items`, `12 items`).
2. **Inference**: Feature 12 tests (`12.1` through `12.5`) and Scenario 5 fail directly because these Bento tiles and mock texts are present in `HomeScreen`.
3. **Inference**: Completely deleting the `GridView.count` Bento cards, deleting the counting loops (lines 1224–1255), and removing `_buildCompactCategoryCard` (lines 1440–1507) eliminates all forbidden texts and cards.
4. **Observation**: UI Reference Image 1 and Image 2 show the Media Library section displaying video collections and folders with `VideoGroupCard`s.
5. **Inference**: The Media Library section should:
   - Filter `provider.allFiles` using `MediaScannerService.isVideo(f.path)`.
   - Exclude audio files and audio-only folders.
   - When video items exist, group them using `provider.groupCustomItems(videoFiles, provider.groupMode == GroupMode.none ? GroupMode.byFolder : provider.groupMode)`.
   - Render each group as a `VideoGroupCard(key: ValueKey('home_all_group_${group.id}'), group: group, isGridView: isDesktop)`.
   - If no video files exist, display a clean empty state card (`"No video media indexed"`).

---

## 3. Concrete Code Replacement Proposals

### Proposal 1: History Section (`home_screen.dart:585–925`)
Replace `_buildHistorySection` and introduce `_buildHistoryCard` to provide horizontal scrollability with `BouncingScrollPhysics` and strict 5-item limit:

```dart
  // --- 2. HISTORY SECTION (SCROLLABLE 5-ITEM CAP - R4) ---
  Widget _buildHistorySection(BuildContext context, LibraryProvider provider, bool isDesktop) {
    if (_selectedCategory != 'All' && _selectedCategory != 'History' && _selectedCategory != 'Recent') {
      return const SizedBox.shrink();
    }

    final cappedRecents = provider.recentFiles.take(5).toList();
    final bool hasRealRecent = cappedRecents.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                EVectorIcon(name: 'history', size: 16, color: EDesign.primary),
                SizedBox(width: 8),
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EDesign.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (provider.recentFiles.isNotEmpty)
                  Text(
                    '${provider.recentFiles.length > 5 ? 5 : provider.recentFiles.length} recent',
                    style: const TextStyle(
                      fontSize: 12,
                      color: EDesign.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(width: 8),
                PopupMenuButton<GroupMode>(
                  tooltip: 'Group Recent Videos',
                  color: EDesign.elevatedSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(EDesign.r12),
                    side: const BorderSide(color: EDesign.border),
                  ),
                  onSelected: (mode) => provider.setGroupMode(mode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: provider.groupMode != GroupMode.none
                          ? EDesign.primary.withValues(alpha: 0.15)
                          : EDesign.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: provider.groupMode != GroupMode.none
                            ? EDesign.primary
                            : EDesign.border,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.groupMode == GroupMode.byFolder
                              ? Icons.folder_outlined
                              : provider.groupMode == GroupMode.byName
                                  ? Icons.auto_awesome_motion_outlined
                                  : Icons.workspaces_outlined,
                          size: 13,
                          color: provider.groupMode != GroupMode.none
                              ? EDesign.primary
                              : EDesign.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.groupMode == GroupMode.none ? 'Group' : provider.groupMode.label,
                          style: TextStyle(
                            color: provider.groupMode != GroupMode.none
                                ? EDesign.primary
                                : EDesign.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    for (final mode in GroupMode.values)
                      PopupMenuItem(
                        value: mode,
                        child: Row(
                          children: [
                            Icon(
                              mode.icon,
                              size: 16,
                              color: mode == provider.groupMode ? EDesign.primary : EDesign.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              mode.label,
                              style: TextStyle(
                                color: mode == provider.groupMode ? EDesign.primary : EDesign.textPrimary,
                                fontWeight: mode == provider.groupMode ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (mode == provider.groupMode) ...[
                              const Spacer(),
                              const Icon(Icons.check, size: 14, color: EDesign.primary),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (provider.groupMode != GroupMode.none && provider.groupedRecentFiles.isNotEmpty) ...[
          // Grouped mode: capped at 5 groups
          ...provider.groupedRecentFiles.take(5).map((group) {
            return VideoGroupCard(
              key: ValueKey('recent_group_${group.id}'),
              group: group,
              isGridView: false,
            );
          }),
        ] else ...[
          // Flat mode: Smooth horizontal scrolling carousel with 5-item cap
          SizedBox(
            height: isDesktop ? 130 : 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: hasRealRecent ? cappedRecents.length : 1,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = hasRealRecent ? cappedRecents[index] : null;
                return _buildHistoryCard(context, item, isDesktop, provider);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    MediaItem? item,
    bool isDesktop,
    LibraryProvider provider,
  ) {
    final bool hasRealRecent = item != null;
    final String title = hasRealRecent ? item.name : 'The Last Horizon (4K Remaster)';
    final int positionMs = hasRealRecent ? item.lastPositionMs : 5056000;
    final int durationMs = hasRealRecent && item.durationMs > 0 ? item.durationMs : 8130000;
    final double progressValue = (durationMs > 0) ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.62;
    final String timeLabel = '${_formatDuration(positionMs)} / ${_formatDuration(durationMs)}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onLongPress: null,
      onTap: () {
        if (hasRealRecent) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
          );
        } else if (provider.allFiles.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: provider.allFiles.first.path)),
          );
        } else {
          const demoPath = 'D:\\E-player\\test.mp4';
          if (File(demoPath).existsSync()) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayerScreen(mediaPath: demoPath)),
            );
          }
        }
      },
      child: Container(
        width: isDesktop ? 340 : 290,
        height: isDesktop ? 130 : 120,
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EDesign.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Image(
                    image: AssetImage('assets/thumbnails/demo_landscape.png'),
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EDesign.primary,
                        boxShadow: [
                          BoxShadow(
                            color: EDesign.primary.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '4K HDR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: EDesign.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: EDesign.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RESUME WATCHING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: EDesign.primary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                color: EDesign.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(progressValue * 100).toInt()}%',
                              style: const TextStyle(
                                color: EDesign.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

---

### Proposal 2: Media Library Section (`home_screen.dart:1219–1507`)
Replace `_buildCompactMediaGrid` and completely remove `_buildCompactCategoryCard`:

```dart
  // --- 5. MEDIA LIBRARY SECTION (VIDEO-ONLY & FOLDERS - R5) ---
  Widget _buildMediaLibrarySection(BuildContext context, LibraryProvider provider, bool isDesktop) {
    if (_selectedCategory != 'All' && _selectedCategory != 'Videos' && _selectedCategory != 'Folders') {
      return const SizedBox.shrink();
    }

    // Filter library items to video files only (Requirement R5)
    final videoFiles = provider.allFiles
        .where((f) => MediaScannerService.isVideo(f.path))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              provider.groupMode == GroupMode.none
                  ? 'Media Library'
                  : 'Media Library (${provider.groupMode.label})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: EDesign.textPrimary,
              ),
            ),
            PopupMenuButton<GroupMode>(
              tooltip: 'Group Media Library',
              color: EDesign.elevatedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EDesign.r12),
                side: const BorderSide(color: EDesign.border),
              ),
              onSelected: (mode) => provider.setGroupMode(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: provider.groupMode != GroupMode.none
                      ? EDesign.primary.withValues(alpha: 0.15)
                      : EDesign.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: provider.groupMode != GroupMode.none
                        ? EDesign.primary
                        : EDesign.border,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.groupMode == GroupMode.byFolder
                          ? Icons.folder_outlined
                          : provider.groupMode == GroupMode.byName
                              ? Icons.auto_awesome_motion_outlined
                              : Icons.workspaces_outlined,
                      size: 13,
                      color: provider.groupMode != GroupMode.none
                          ? EDesign.primary
                          : EDesign.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.groupMode == GroupMode.none ? 'Group' : provider.groupMode.label,
                      style: TextStyle(
                        color: provider.groupMode != GroupMode.none
                            ? EDesign.primary
                            : EDesign.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                for (final mode in GroupMode.values)
                  PopupMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(
                          mode.icon,
                          size: 16,
                          color: mode == provider.groupMode ? EDesign.primary : EDesign.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mode.label,
                          style: TextStyle(
                            color: mode == provider.groupMode ? EDesign.primary : EDesign.textPrimary,
                            fontWeight: mode == provider.groupMode ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (mode == provider.groupMode) ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 14, color: EDesign.primary),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (videoFiles.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: EDesign.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EDesign.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.video_library_outlined, size: 36, color: EDesign.textMuted),
                  SizedBox(height: 8),
                  Text('No video media indexed', style: TextStyle(color: EDesign.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          )
        else ...[
          // Grouped or default folder view for video collections
          ...() {
            final effectiveMode = provider.groupMode == GroupMode.none
                ? GroupMode.byFolder
                : provider.groupMode;
            final videoGroups = provider.groupCustomItems(videoFiles, effectiveMode);
            return videoGroups.map((group) {
              return VideoGroupCard(
                key: ValueKey('home_all_group_${group.id}'),
                group: group,
                isGridView: isDesktop,
              );
            });
          }(),
        ],
      ],
    );
  }
```

And in `build()` at line 341:
Change:
```dart
// 5. Section: Media Categories (Compact Bento Grid)
_buildCompactMediaGrid(context, provider, isDesktop),
```
to:
```dart
// 5. Section: Media Library (Video-Only & Folders - R5)
_buildMediaLibrarySection(context, provider, isDesktop),
```

---

## 4. Caveats
- No changes to `MediaGroupService` or `FolderDetailScreen` are required for Milestone 3; the scope is confined strictly to `HomeScreen` (`home_screen.dart`).
- When `recentFiles` is completely empty (e.g. fresh installation or tests with 0 items), rendering 1 fallback card inside the horizontal `ListView.separated` satisfies tests 10.4 and 2.4 while avoiding any null crashes or layout breaks.
- If an existing user directory contains only audio files, it will be cleanly hidden from the Media Library section on the Home screen as required by R5.

---

## 5. Conclusion
1. **Requirement R4** is achieved by replacing the static single-item History card with a horizontal `ListView.separated` using `BouncingScrollPhysics()` and bounding items via `provider.recentFiles.take(5).toList()`. In grouped mode, `take(4)` is corrected to `take(5)`.
2. **Requirement R5** is achieved by deleting the 4-box Bento category cards (`Movies`, `Series`, `Anime`, `Music`), eliminating the hardcoded mock counters (`18 items`, `12 items`), and populating the Media Library section exclusively with video items and video folders via `VideoGroupCard`.
3. All changes are strictly localized to `lib/features/home/ui/home_screen.dart` and preserve all Milestone 1 and Milestone 2 multi-select capabilities.

---

## 6. Verification Method

To independently verify the implementation after Worker M3 applies the changes:

1. **Static Analysis**:
   ```powershell
   cd d:\E-player\app
   dart analyze lib/features/home/ui/home_screen.dart test/e2e/e2e_requirements_test.dart
   ```
   *Expected*: `No issues found!` (0 errors, 0 warnings).

2. **Automated E2E Verification**:
   ```powershell
   cd d:\E-player\app
   flutter test test/e2e/e2e_requirements_test.dart --name "Feature 9"
   flutter test test/e2e/e2e_requirements_test.dart --name "Feature 10"
   flutter test test/e2e/e2e_requirements_test.dart --name "Feature 11"
   flutter test test/e2e/e2e_requirements_test.dart --name "Feature 12"
   flutter test test/e2e/e2e_requirements_test.dart --name "Scenario 4"
   flutter test test/e2e/e2e_requirements_test.dart --name "Scenario 5"
   ```

3. **Invalidation Conditions**:
   - If any widget with text `"Music"`, `"Anime"`, `"Series"`, `"18 items"`, or `"12 items"` appears on `HomeScreen`, R5 is violated.
   - If `HomeScreen` renders more than 5 history cards in flat or grouped mode, R4 is violated.
   - If the History section fails to respond to horizontal drag gestures or lacks `BouncingScrollPhysics`, R4 is violated.
