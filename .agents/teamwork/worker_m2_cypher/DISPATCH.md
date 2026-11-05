## 2026-11-05T05:28:37Z
You are CYPHER, the Implementation Worker for Milestone 2: Long-Press Multi-Select, Select All, Delete, and Move (Home & Library, Requirements R2 & R3).
Your identity: teamwork_worker
Your working directory: d:\E-player\.agents\teamwork\worker_m2_cypher\
Orchestrator Conversation ID: 2a2bca73-ae34-478c-a09c-664f8f640ae5

MANDATORY FIRST STEP:
Read d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md before starting work.
Also read d:\E-player\PROJECT.md and d:\E-player\TEST_READY.md.

EXPLORER FINDINGS TO REVIEW:
- Forge (State Architecture): d:\E-player\.agents\teamwork\explorer_m2_forge\handoff.md
- Aura (UI & Gestures): d:\E-player\.agents\teamwork\explorer_m2_aura\handoff.md
- Kronos (Test Specifications & Keys): d:\E-player\.agents\teamwork\explorer_m2_kronos\handoff.md

FILE OWNERSHIP (EXCLUSIVE):
You exclusively own and may edit:
- `lib/features/home/domain/media_group_service.dart`
- `lib/features/home/ui/home_screen.dart`
- `lib/features/library/ui/library_screen.dart`
- `lib/features/library/ui/folder_detail_screen.dart`

YOUR MISSION:
1. Review the existing implementations and incorporate the recommended quality enhancements from the Explorers:
   - Add atomic `deleteGroups(Iterable<String> ids)` in `MediaGroupService` to optimize batch group deletions into a single persistence write and notification. Use it in `HomeScreen._confirmDeleteSelected`.
   - In `FolderDetailScreen._showMoveToGroupDialog`, filter out `widget.groupId` from destination groups to avoid confusing self-moves.
   - Ensure all edge cases noted by Kronos are preserved: empty selection safety, auto-exit mode when count drops to zero, PopScope hardware back handling, self-move idempotency in service, and strict built-in feature protection (`onLongPress: null` on Create Group, Videos, category chips, headers, and smart playlists).
2. Verification:
   - Run `dart analyze` in `d:\E-player\app` and ensure 0 errors and 0 warnings.
   - Run `flutter test test/e2e/e2e_requirements_test.dart` for Features 3, 4, 5, 6, 7, 8 and Scenarios 2 & 3. Ensure all tests pass.
   - If any other test suite fails, investigate and fix.
3. Write a comprehensive handoff report to `d:\E-player\.agents\teamwork\worker_m2_cypher\handoff.md` following the Handoff Protocol (Observation, Logic Chain, Caveats, Conclusion, Verification Method).
4. Send a completion message to the Orchestrator (Conversation ID: 2a2bca73-ae34-478c-a09c-664f8f640ae5) when done.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
