## 2026-11-05T06:39:40Z
Sender: 7022b6e7-26be-4f91-aa82-00b50e6332c7
Priority: MESSAGE_PRIORITY_HIGH

You are CYPHER, a teamwork_worker.
Your working directory is: d:\E-player\.agents\teamwork\worker_m3_cypher
Your exclusive write ownership is: d:\E-player\app\lib\features\home\ui\home_screen.dart

DO NOT modify other files unless strictly necessary for integration.
MANDATORY: Read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md before starting work.
Also read the project architecture at d:\E-player\PROJECT.md.
Also read Explorer Aura's comprehensive investigation report at d:\E-player\.agents\teamwork\explorer_m3_aura\handoff.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Objective: Implement Milestone 3 (R4 & R5) in HomeScreen (lib/features/home/ui/home_screen.dart)

1. Requirement R4: Scrollable History with 5-Item Limit
   - Replace the single static history card in flat mode with a smooth horizontal scrolling carousel (ListView.separated with scrollDirection: Axis.horizontal and physics: const BouncingScrollPhysics()).
   - Bound recent items strictly to a maximum of 5 items:
     - Flat mode: cappedRecents = provider.recentFiles.take(5).toList()
     - Grouped mode: provider.groupedRecentFiles.take(5).map(...) (fix the existing take(4) bug to take(5)).
   - Graceful fallback: If recentFiles is empty, render 1 fallback card so the UI does not crash and handles 0 items gracefully.
   - History section must respond smoothly to horizontal drag gestures and display up to 5 recent items.

2. Requirement R5: Media Library Video-Only Filtering
   - Completely eliminate the hardcoded 4-box Bento Grid (Movies, Series, Anime, Music), mock counters ("18 items", "12 items"), and helper _buildCompactCategoryCard.
   - Ensure "Music", "Series", "Anime" category sections and Bento cards are NOT rendered.
   - Implement _buildMediaLibrarySection:
     - Filter provider.allFiles using MediaScannerService.isVideo(f.path).
     - Exclude all audio files (.mp3, .flac, .wav, .m4a) and audio-only folders from the Home Media Library.
     - Group video items via provider.groupCustomItems(videoFiles, provider.groupMode == GroupMode.none ? GroupMode.byFolder : provider.groupMode) and render each via VideoGroupCard(key: ValueKey('home_all_group_${group.id}'), group: group, isGridView: isDesktop).
     - If no videos are indexed, render a clean empty container ("No video media indexed").
   - Update HomeScreen.build() line 341 to call _buildMediaLibrarySection(context, provider, isDesktop).

3. Critical Invariants:
   - Preserve all Milestone 1 and Milestone 2 features already in HomeScreen (empty group creation, Add button, long-press selection, Select All, batch delete, batch move, PopScope, etc.). Do not regress any M1/M2 code!

4. Verification Requirements:
   - Run static analysis: `dart analyze` in d:\E-player\app. Must have 0 errors and 0 issues.
   - Run tests: `flutter test test/e2e/e2e_requirements_test.dart` in d:\E-player\app. Verify Feature 9, 10, 11, 12, Scenario 4, and Scenario 5 pass cleanly.

5. Deliverables:
   - Update progress.md in your directory as you make progress.
   - Write your complete handoff report to `d:\E-player\.agents\teamwork\worker_m3_cypher\handoff.md` with Observation, Logic Chain, Caveats, Conclusion, Verification Method, and exact test/analyzer outputs.
   - Send a message to orchestrator when complete.
