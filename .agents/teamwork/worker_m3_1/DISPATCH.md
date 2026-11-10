## 2026-11-10T09:50:56Z
You are the Worker for Milestone 3: Audio Delay Synchronization UI Slider & Dedicated Audio Track Selector Modal (R3, R4).
Working directory: d:\E-player\app
Your state folder: d:\E-player\.agents\teamwork\worker_m3_1

Read the following files carefully:
- d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md
- d:\E-player\PROJECT.md
- d:\E-player\.agents\teamwork\sub_orch_m3\SCOPE.md
- d:\E-player\.agents\teamwork\explorer_m3_1\handoff.md
- d:\E-player\.agents\teamwork\explorer_m3_2\handoff.md
- d:\E-player\.agents\teamwork\spec_miner_m3_1\handoff.md

EXCLUSIVE FILE WRITE OWNERSHIP:
You have exclusive write ownership of ONLY the following files:
1. lib/features/player/ui/audio_studio_sheet.dart
2. lib/features/player/ui/player_screen.dart
3. test/features/audio_studio_test.dart
Do NOT modify any other files.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

IMPLEMENTATION INSTRUCTIONS:
Follow the exact blueprints and code designs established in explorer_m3_1, explorer_m3_2, and spec_miner_m3_1 handoff reports:
1. `lib/features/player/ui/audio_studio_sheet.dart`:
   - In `AudioConfig`:
     - Add `double audioDelay = 0.0; // in milliseconds [-10000.0, 10000.0]`
     - Add `void applyAudioDelay(Player? player)` which formats `(audioDelay / 1000.0).toStringAsFixed(3)` and sets mpv property `'audio-delay'` via `(player.platform as dynamic).setProperty('audio-delay', ...)` protected by `try-catch`.
     - In `AudioConfig.apply(Player? player)`, call `applyAudioDelay(player)` alongside `buildMpvAfString()`. Note: `audio-delay` must be applied unconditionally regardless of `enabled`.
     - In `AudioConfig.reset(Player? player)`, set `audioDelay = 0.0;` and apply to player.
   - In `_AudioStudioSheetState`:
     - Add `_buildAudioDelaySyncCard()` placed above `_buildPreampCard()`.
     - Implement continuous slider (-10.0s to +10.0s, 400 divisions for 50ms resolution) with debounced apply (50ms), key `Key('audio_delay_slider')`.
     - Implement live badge pill with key `Key('audio_delay_badge')` formatted as `${delayVal >= 0 ? "+" : ""}${delayVal.toStringAsFixed(0)} ms`.
     - Implement 5 nudge buttons with immediate apply: `-100ms` (`Key('audio_delay_nudge_minus_100')`), `-50ms` (`Key('audio_delay_nudge_minus_50')`), `Reset` (`Key('audio_delay_nudge_reset')`), `+50ms` (`Key('audio_delay_nudge_plus_50')`), `+100ms` (`Key('audio_delay_nudge_plus_100')`).
     - Outer container key `Key('audio_delay_sync_card')`, styled with `EDesign.surface`, `EDesign.border`, `EDesign.r16`.
   - Also export standalone `AudioDelaySyncCard` widget conforming to `explorer_m3_1\handoff.md:437-593` for full modularity.
2. `lib/features/player/ui/player_screen.dart`:
   - Ensure the HUD top bar Audio Track button has `key: const Key('hud_audio_tracks_button')`, `tooltip: 'Audio Tracks'`, and `onPressed: _showAudioTrackMenu`.
   - Polish `_showAudioTrackMenu()` per `explorer_m3_2\handoff.md:220-431`:
     - `showModalBottomSheet` with `backgroundColor: Colors.transparent`, `isScrollControlled: true`.
     - Root container `Key('audio_tracks_sheet')` with `EDesign.surface`, top border radius 24, drag handle pill (`40x4`), header with title "Audio Tracks" and dismiss icon (`Icons.close`).
     - Empty state with `Key('audio_tracks_empty')` displaying "No audio tracks found".
     - Stream list items with `Key('audio_track_item_${track.id}')`, rich metadata subtitle, checkmark `Key('active_track_check')` when `_selectedAudioTrack.id == track.id`.
     - Wrap items in `Material(color: Colors.transparent, child: ListTile(...))` to prevent Flutter framework occlusion exceptions.
     - On tap: call `_player.setAudioTrack(track)`, update state, show OSD message `_showFeedbackMessage('Audio: $label', Icons.audiotrack)`, dismiss modal, and safely restore focus via `_keyboardFocusNode.requestFocus()`.
   - In `_nudgeAudioDelay()` and when opening `AudioStudioSheet`: maintain two-way synchronization between `_audioDelayMs` and `_audioConfig.audioDelay`.
3. `test/features/audio_studio_test.dart`:
   - Add unit tests for `AudioConfig.audioDelay`, boundary clamping (-10.0s, +10.0s), 50ms nudging, reset behavior, and platform property dispatch.
4. Verification:
   - Run `flutter test test/features/audio_studio_test.dart`
   - Run `flutter test test/e2e/phase1_e2e_test.dart`
   - Run `dart analyze`
   - Ensure zero errors and zero warnings.

When complete, write your comprehensive report to `d:\E-player\.agents\teamwork\worker_m3_1\handoff.md`.
Send a completion message back to parent orchestrator (conversation ID: d319cada-6c05-4314-a8fc-3628ac99cc0c).
