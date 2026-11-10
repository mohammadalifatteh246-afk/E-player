# Task Assignment: Audio Studio, Equalizer & Delay Exploration (Aura)

## Objective
Investigate the existing Audio Studio, Equalizer implementation, and mpv audio integration in `d:\E-player\app`.

## Authoritative Inputs
- Original Request: `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md`
- Working Directory: `d:\E-player\app`

## Scope & Investigation Tasks
1. **AudioStudioSheet Investigation**:
   - Locate `AudioStudioSheet` (likely in `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart` or similar).
   - What sections/cards currently exist in `AudioStudioSheet`?
   - How is the modal bottom sheet presented (glassmorphic styling, animations, dismiss)?
2. **Audio Delay Synchronization**:
   - How does `media_kit` / mpv manage audio delay in E-Player?
   - Does `Player` or `NativePlayer` expose property setting (e.g. `(player.platform as dynamic).setProperty('audio-delay', ...)` or via audio filter or official API)?
   - Verify how mpv property `audio-delay` behaves (units: seconds vs milliseconds, negative vs positive delay).
3. **Equalizer & Preamp Architecture**:
   - How is the Equalizer currently implemented in E-Player? Is it using mpv's `lavfi=[equalizer=...]` or `firequalizer` or media_kit built-in filters?
   - What frequency bands are currently configured?
   - What presets are already defined? Where are presets stored?
   - How is Pre-Amplification handled (e.g. `volume`, `af` filter with `volume=gain=...dB`)?
4. **Audio Track Selection Mechanism**:
   - How are audio tracks detected and listed in `_player.stream.tracks.audio`?
   - What properties exist on `AudioTrack` (id, title, language, channels, codec)?
   - How does `_player.setAudioTrack(track)` work?
5. **Existing Audio Tests**:
   - Identify existing tests for audio settings, equalizer, and media_kit integration in `d:\E-player\app\test\`.

## Deliverable
Write your findings and architectural analysis to:
`d:\E-player\.agents\teamwork\explorer_audio_studio\handoff.md`
Send a completion message when finished.


## 2026-11-10T08:09:22Z
[Message] sender=63171882-8b91-4476-8781-8908629f8b43 priority=MESSAGE_PRIORITY_HIGH
You are the Audio Studio & Equalizer Explorer (Aura).
Read your assignment in d:\E-player\.agents\teamwork\explorer_audio_studio\DISPATCH.md and the authoritative request in d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md.
Investigate d:\E-player\app: examine AudioStudioSheet, mpv audio delay property bindings, equalizer filters and frequency bands, preamp gain controls, and audio track selector mechanisms via _player.stream.tracks.audio.
Write your complete report to d:\E-player\.agents\teamwork\explorer_audio_studio\handoff.md.
When finished, send a message to the orchestrator.
