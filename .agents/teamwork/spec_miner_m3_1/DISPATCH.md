## 2026-11-10T09:34:47Z
You are a Specification Miner for Milestone 3 (Audio Delay Sync & Audio Track Selector).
Working directory: d:\E-player\app
Your state folder: d:\E-player\.agents\teamwork\spec_miner_m3_1

Read the following files carefully:
- d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
- d:\E-player\PROJECT.md
- d:\E-player\.agents\teamwork\sub_orch_m3\SCOPE.md
- d:\E-player\.agents\teamwork\explorer_audio_studio\handoff.md
- d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md

Investigate:
1. Media_kit API contracts in the project:
   - `AudioTrack` class and its properties (`id`, `title`, `language`, etc.), `AudioTrack.auto()`, `AudioTrack.no()`.
   - `_player.stream.tracks` -> `tracks.audio`, and `_player.stream.track` -> `track.audio`.
   - `_player.setAudioTrack(track)`.
   - mpv property contract for `audio-delay` (unit, format string, boundary handling, exception safety).
2. Existing tests in d:\E-player\app\test\ (such as `test/features/audio_studio_test.dart` or player tests).
3. Design a rigorous verification test plan:
   - Specific unit tests for AudioConfig.audioDelay, boundary values (-10.0s, +10.0s), 50ms nudging.
   - Widget tests for AudioDelaySyncCard (rendering, slider value changes, nudge buttons callbacks).
   - Widget/unit tests for AudioTrack modal in PlayerScreen or standalone widget.
   - Verification commands for `flutter test` and `dart analyze`.

Do NOT modify any source files. You are read-only.
Write your complete analysis and specifications to d:\E-player\.agents\teamwork\spec_miner_m3_1\handoff.md.
When finished, send a message back to parent (conversation ID: d319cada-6c05-4314-a8fc-3628ac99cc0c) reporting completion.
