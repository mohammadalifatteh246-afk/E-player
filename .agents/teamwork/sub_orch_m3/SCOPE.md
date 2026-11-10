# Scope: Milestone 3 — Audio Delay Synchronization UI Slider & Dedicated Audio Track Selector Modal (R3, R4)

## Objective
Implement Phase 1 deliverables R3 and R4 in `d:\E-player\app`:
1. **R3 Audio Delay Synchronization UI Slider**:
   - Add `AudioDelaySyncCard` to `AudioStudioSheet` (`lib/features/player/ui/audio_studio_sheet.dart`).
   - A continuous slider covering `-10.0s` to `+10.0s` with 50ms divisions (400 divisions).
   - Dedicated nudge buttons: `-100ms`, `-50ms`, `Reset 0ms`, `+50ms`, and `+100ms`.
   - Bound directly to mpv property `audio-delay` via `(player.platform as dynamic).setProperty('audio-delay', (delayMs / 1000.0).toStringAsFixed(3))`.
2. **R4 Dedicated Audio Track Selector Modal**:
   - Add Audio Track quick selector icon/button (`IconButton(icon: Icon(Icons.audiotrack_outlined), tooltip: 'Audio Tracks', onPressed: _showAudioTrackMenu)`) to `PlayerScreen` HUD top bar (`lib/features/player/ui/player_screen.dart`) between AI Enhancement and Subtitles.
   - Opens a glassmorphic bottom sheet / modal listing all detected audio streams retrieved via `_player.stream.tracks.audio`.
   - Displays track title, language, channels/codec, and checkmark for `_selectedAudioTrack == track`.
   - Supports instant track selection and switching via `_player.setAudioTrack`.

## Exclusive Write Ownership
- `lib/features/player/ui/audio_studio_sheet.dart` (for AudioDelaySyncCard and AudioConfig.audioDelay)
- `lib/features/player/ui/player_screen.dart` (for top bar Audio Track button, `_showAudioTrackMenu()`, and audio track stream listeners)
- `test/features/audio_studio_test.dart` and/or `test/unit/audio_track_test.dart` (for automated unit/widget verification)

## Authoritative Inputs
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (R3, R4)
- `d:\E-player\PROJECT.md`
- Survey Handoff (Aura): `d:\E-player\.agents\teamwork\explorer_audio_studio\handoff.md`
- Specification Handoff (Cypher): `d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md`

## Specifications to Implement
1. **Audio Delay Synchronization**:
   - In `AudioConfig`, add `double audioDelay = 0.0; // in milliseconds`.
   - In `AudioConfig.apply(Player? player)` or dedicated method:
     `try { (player.platform as dynamic).setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3)); } catch (e) { ... }`
   - In `AudioStudioSheet`:
     - Render `_buildAudioDelaySyncCard()`:
       - Frosted surface container `EDesign.surface`, `EDesign.border`, `EDesign.primary`.
       - Title "Audio Synchronization" with `Icons.sync` or `Icons.av_timer`.
       - Live badge: `${audioDelay >= 0 ? "+" : ""}${audioDelay.toStringAsFixed(0)} ms`.
       - Continuous Slider: `min: -10000.0`, `max: 10000.0`, `divisions: 400`, `value: audioDelay.clamp(-10000.0, 10000.0)`.
       - 5 Nudge Buttons row:
         - `-100ms`: `audioDelay = (audioDelay - 100).clamp(-10000.0, 10000.0)`
         - `-50ms`: `audioDelay = (audioDelay - 50).clamp(-10000.0, 10000.0)`
         - `Reset 0ms`: `audioDelay = 0.0`
         - `+50ms`: `audioDelay = (audioDelay + 50).clamp(-10000.0, 10000.0)`
         - `+100ms`: `audioDelay = (audioDelay + 100).clamp(-10000.0, 10000.0)`
       - Triggers debounced apply to mpv property `audio-delay`.
2. **Audio Track Selector Modal**:
   - In `PlayerScreen`:
     - State: `List<AudioTrack> _audioTracks = [];`, `AudioTrack _selectedAudioTrack = AudioTrack.auto();`
     - Subscriptions: `_player.stream.tracks` -> `_audioTracks = tracks.audio;`, `_player.stream.track` -> `_selectedAudioTrack = track.audio;`.
     - In HUD top bar (`player_screen.dart` between AI Studio and Subtitles):
       ```dart
       IconButton(
         icon: const Icon(Icons.audiotrack_outlined, color: Colors.white70, size: 20),
         tooltip: 'Audio Tracks',
         onPressed: _showAudioTrackMenu,
       ),
       ```
     - Method `_showAudioTrackMenu()`:
       - Opens glassmorphic bottom sheet (`EDesign.surface`).
       - Header "Audio Tracks" with close button.
       - If `_audioTracks.isEmpty`: renders "No audio tracks found" with subtitle icon/text.
       - If not empty: renders `ListTile` for each `AudioTrack` with leading icon, title/language, channel count, and trailing checkmark if selected.
       - On tap: calls `_player.setAudioTrack(track)`, pops context, shows feedback OSD message `_showFeedbackMessage("Audio: ${track.title ?? track.language ?? track.id}", Icons.audiotrack)`.
       - On dismiss (`.then((_))`), re-requests focus `_keyboardFocusNode.requestFocus()`.

## Completion Criteria
- `AudioStudioSheet` contains working -10.0s to +10.0s slider (50ms divisions) and 5 nudge buttons controlling mpv `audio-delay`.
- `PlayerScreen` HUD top bar has audio track button opening glassmorphic sheet displaying available audio tracks from `_player.stream.tracks.audio` and switching tracks with `_player.setAudioTrack`.
- Static analysis (`dart analyze`) passes cleanly with 0 errors and 0 warnings.
- Unit and E2E tests pass without failure.
- Forensic Auditor reports CLEAN.
