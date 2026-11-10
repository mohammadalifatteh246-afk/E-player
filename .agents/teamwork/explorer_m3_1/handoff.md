# Milestone 3 Handoff Report: Audio Delay Synchronization UI Slider & Audio Track Selector Modal

**Author**: Explorer M3-1 (`explorer_m3_1`)  
**Target Milestone**: Milestone 3 (Requirements R3 & R4)  
**Target Codebase**: `d:\E-player\app`  
**State Folder**: `d:\E-player\.agents\teamwork\explorer_m3_1`  
**Date & Timestamp**: 2026-11-10T09:48:00Z  

---

## 1. Observation

### 1.1 AudioStudioSheet & AudioConfig Current State
- **File**: `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart`
- **Class `AudioConfig` (lines 6–142)**:
  - Currently stores:
    - `bool enabled = true;` (line 7)
    - `String preset = 'Rock';` (line 8)
    - `double preamp = 0.0;` (line 9)
    - `List<double> eq = [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5];` (line 16)
    - `double bassBoost = 6.0;` (line 18)
    - `bool bassBoostEnabled = true;` (line 19)
    - `bool virtualizer = true;` (line 20)
    - `bool threeDAudio = true;` (line 21)
    - `bool nightMode = false;` (line 22)
    - 20 presets in `presets` (lines 24–46) and matching preamps in `presetPreamps` (lines 48–69)
  - `buildMpvAfString()` (lines 79–118) compiles mpv `'af'` filter graph with `volume=volume=+X.XdB:precision=fixed`, bass, dynaudnorm, extrastereo, stereowiden, and equalizer bands.
  - `apply(Player? player)` (lines 120–128):
    ```dart
    void apply(Player? player) {
      if (player == null) return;
      try {
        final dynamic platform = player.platform;
        platform.setProperty('af', buildMpvAfString());
      } catch (e) {
        debugPrint('[Audio Studio] mpv af error: $e');
      }
    }
    ```
  - `reset(Player? player)` (lines 130–141) sets `preset = 'Flat'`, zeros `eq` and `preamp`, resets boost flags, and calls `apply(player)`.
  - **Deficit**: `AudioConfig` has **no** `audioDelay` field and does not set mpv `audio-delay` in `apply` or `reset`.
- **Class `_AudioStudioSheetState` (lines 199–897)**:
  - Structure in `build(BuildContext context)` (lines 296–597):
    1. Drag handle & Header ("Audio Equalizer" + Close button)
    2. Master Switch Card ("Enable Equalizer", lines 339–371)
    3. Preset Selector Dropdown Pill (lines 374–420)
    4. Pre-Amplification Slider Card (`_buildPreampCard()`, lines 422–424, implemented at lines 599–719)
    5. 10-Band Graphic Equalizer Scale (lines 426–500, implemented at lines 721–792)
    6. Audio Boost Switches & Controls (lines 503–563)
    7. Reset to Defaults button (lines 566–579)
  - **Deficit**: `_buildAudioDelaySyncCard()` is completely absent from `AudioStudioSheet`.

### 1.2 mpv `audio-delay` Binding & Units
- In `mpv` / `media_kit`:
  - Property name: `'audio-delay'`
  - Value type: Floating point representation in **seconds** (e.g. `0.050` = +50ms, `-0.100` = -100ms, `0.000` = reset).
  - Writing property: `(player.platform as dynamic).setProperty('audio-delay', (audioDelayMs / 1000.0).toStringAsFixed(3))`
  - Reading property: `await (player.platform as dynamic).getProperty('audio-delay')` -> string like `'0.050'` -> `double.tryParse(val) * 1000.0`.
  - Delay semantics: Positive value delays audio relative to video; negative value advances audio relative to video.
  - Property nature: `audio-delay` is a native mpv player property affecting demuxer/PTS timing, **not** an FFmpeg audio filter (`af`). Setting it does not rebuild or interrupt the audio filter graph.

### 1.3 PlayerScreen & Audio Track State
- **File**: `d:\E-player\app\lib\features\player\ui\player_screen.dart`
- Player audio state variables:
  - Line 54: `final AudioConfig _audioConfig = AudioConfig();`
  - Line 76: `List<AudioTrack> _audioTracks = [];`
  - Line 77: `AudioTrack _selectedAudioTrack = AudioTrack.no();`
  - Line 78: `double _audioDelayMs = 0.0;`
- Subscriptions in `_initPlayer()`:
  - Line 278: `_audioTracks = tracks.audio;`
  - Line 286: `_selectedAudioTrack = track.audio;`
- Keyboard shortcuts handler in `PlayerScreen`:
  - Lines 1338 & 1340: `onCycleAudioTrack: _cycleAudioTrack`, `onNudgeAudioDelay: _nudgeAudioDelay`.
- Audio delay nudge method (lines 749–759):
  ```dart
  void _nudgeAudioDelay(int offsetMs) {
    _audioDelayMs = (_audioDelayMs + offsetMs).clamp(-10000.0, 10000.0);
    try {
      final platform = _player.platform as dynamic;
      platform.setProperty('audio-delay', (_audioDelayMs / 1000.0).toStringAsFixed(3));
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to set audio-delay: $e');
    }
    final sign = _audioDelayMs >= 0 ? '+' : '';
    _showFeedbackMessage('Audio Delay: $sign${_audioDelayMs.round()}ms', Icons.audiotrack);
  }
  ```
- Top Bar HUD Button (lines 1586–1590):
  ```dart
  IconButton(
    icon: const Icon(Icons.audiotrack_outlined, color: Colors.white70, size: 20),
    tooltip: 'Audio Tracks',
    onPressed: _showAudioTrackMenu,
  ),
  ```
- Current `_showAudioTrackMenu()` (lines 682–717):
  ```dart
  void _showAudioTrackMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Audio Tracks', style: EDesign.h3),
            ),
            if (_audioTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No audio tracks found', style: EDesign.secondaryStyle),
              ),
            for (final track in _audioTracks)
              ListTile(
                title: Text(track.title ?? track.language ?? track.id, style: EDesign.body),
                trailing: _selectedAudioTrack == track
                    ? const Icon(Icons.check, color: EDesign.primary)
                    : null,
                onTap: () {
                  _player.setAudioTrack(track);
                  setState(() => _selectedAudioTrack = track);
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }
  ```
- **Observed Gaps in `PlayerScreen`**:
  1. `_showAudioTrackMenu()` does not display on-screen feedback (`_showFeedbackMessage`) upon track selection.
  2. Track matching uses reference equality `_selectedAudioTrack == track` instead of `_selectedAudioTrack.id == track.id`.
  3. Missing widget keys (`hud_audio_tracks_button`, `audio_tracks_sheet`, `audio_tracks_empty`, `audio_track_item_${track.id}`, `active_track_check`) specified by E2E tests (`test/e2e/phase1_e2e_test.dart:532-551, 635`).
  4. Two-way synchronization between `_audioDelayMs` in `PlayerScreen` and `_audioConfig.audioDelay` is currently missing when opening and closing `AudioStudioSheet`.

### 1.4 E2E Test Suite Contracts
- **File**: `d:\E-player\app\test\e2e\phase1_e2e_test.dart`
- Lines 258–409 define the test harness contract for `AudioDelaySyncCard`:
  - Widget key: `key: const Key('audio_delay_sync_card')`
  - Title: Text `'Audio Synchronization'`
  - Icon: `Icons.sync` (or `Icons.av_timer`)
  - Badge key: `key: const Key('audio_delay_badge')`, text formatted as `${delayMs >= 0 ? "+" : ""}${delayMs.toStringAsFixed(0)} ms`
  - Slider key: `key: const Key('audio_delay_slider')`, `min: -10.0`, `max: 10.0`, `divisions: 400`
  - 5 Nudge Buttons:
    - `audio_delay_nudge_minus_100`: `-100ms`
    - `audio_delay_nudge_minus_50`: `-50ms`
    - `audio_delay_nudge_reset`: `Reset` (or `Reset 0ms`)
    - `audio_delay_nudge_plus_50`: `+50ms`
    - `audio_delay_nudge_plus_100`: `+100ms`
- Tests T1.3.1 through T1.3.5, T2.3.1 through T2.3.5, and T3.2, T3.9, T4.3 verify:
  - Slider drag to +1500ms sets `properties['audio-delay'] == '1.500'`
  - Nudge +50ms sets `properties['audio-delay'] == '0.050'` (or increments by 50ms)
  - Nudge -100ms decrements delay by 100ms
  - Reset sets delay to `0.000`
  - Boundary clamps at `+10.000` and `-10.000`

---

## 2. Logic Chain

1. **AudioConfig Single Source of Truth**:
   - `AudioConfig` must own `double audioDelay = 0.0;` (stored in milliseconds).
   - In `AudioConfig.apply(Player? player)`, in addition to setting the `'af'` filter string, it must set:
     `platform.setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3));`
   - To avoid unnecessary audio filter cascade recalculation when adjusting delay alone, `AudioConfig` should also expose `applyAudioDelay(Player? player)` which strictly sets `'audio-delay'`.
   - In `AudioConfig.reset(Player? player)`, `audioDelay` must be reset to `0.0` and applied to the player.

2. **Independence from Equalizer Switch**:
   - Equalizer enablement (`_config.enabled`) controls audio filters (`af`), such as preamp, EQ bands, and bass boost.
   - Lip-sync audio synchronization (`audio-delay`) is a fundamental playback timing control that must function **independently** of whether EQ filters are active.
   - Therefore, `_buildAudioDelaySyncCard()` in `AudioStudioSheet` must NOT be wrapped in `AnimatedOpacity` gated by `_config.enabled`, and `applyAudioDelay` must always execute regardless of `_config.enabled`.

3. **Slider & Nudge Physics**:
   - The slider range is `-10.0s` to `+10.0s` (`-10000.0ms` to `+10000.0ms`).
   - With `divisions: 400`, the slider step resolution is `20.0s / 400 = 0.05s = 50ms`.
   - On slider `onChanged(v)`: value in seconds `v` is converted to milliseconds and rounded to 50ms intervals:
     `final ms = ((v * 1000.0) / 50.0).round() * 50.0;`
     `_config.audioDelay = ms.clamp(-10000.0, 10000.0);`
   - A short debounce (`50ms`) on slider drag prevents excessive IPC calls during rapid drag motions.
   - For nudge button taps (`-100ms`, `-50ms`, `Reset`, `+50ms`, `+100ms`), application must be **immediate** (synchronous `applyAudioDelay`), ensuring both snappy tactile response and immediate assertion pass in unit tests.

4. **Visual Layout and Styling of `AudioDelaySyncCard`**:
   - In `AudioStudioSheet`, `_buildAudioDelaySyncCard()` should be placed near the top of the scrollable column (above `_buildPreampCard()`), giving users immediate access to AV sync.
   - Container styling:
     - Background: `EDesign.surface`
     - Border radius: `BorderRadius.circular(EDesign.r16)`
     - Border: `Border.all(color: EDesign.border)`
     - Padding: `const EdgeInsets.all(16)`
   - Header:
     - Left: Leading `Icon(Icons.sync, color: EDesign.primary, size: 20)` + Title `'Audio Synchronization'` (`EDesign.textPrimary`, 15sp, bold).
     - Right: Live badge pill in `EDesign.elevatedSurface` displaying `${_config.audioDelay >= 0 ? "+" : ""}${_config.audioDelay.toStringAsFixed(0)} ms` in `EDesign.primary`.
   - Slider Row:
     - Labels `-10.0s` and `+10.0s` flanking an `Expanded(Slider(...))`.
     - SliderTheme styled with `EDesign.primary` active track and thumb, `Colors.white12` inactive track.
   - Nudge Row:
     - 5 `OutlinedButton`s evenly spaced (`-100ms`, `-50ms`, `Reset`, `+50ms`, `+100ms`).

5. **Audio Track Selector Modal Polish in `PlayerScreen`**:
   - In `_showAudioTrackMenu()`:
     - Wrap sheet in `Container(key: const Key('audio_tracks_sheet'), ...)` with `EDesign.surface` and top rounded corners (24px).
     - Header row with `'Audio Tracks'` (`EDesign.h3`) and close icon.
     - Empty state: `Text('No audio tracks found', key: const Key('audio_tracks_empty'))`.
     - Stream tiles: `ListTile(key: Key('audio_track_item_${track.id}'), ...)` with leading `Icons.audiotrack`, title, subtitle (language/codec/channels), and trailing checkmark `Icon(Icons.check, key: const Key('active_track_check'))` when `_selectedAudioTrack.id == track.id`.
     - On tap: set track, update `_selectedAudioTrack`, trigger `_showFeedbackMessage('Audio: ${track.title ?? track.language ?? track.id}', Icons.audiotrack)`, dismiss modal, and re-request keyboard focus.
   - In HUD Top Bar:
     - Ensure `IconButton` has `key: const Key('hud_audio_tracks_button')` and `tooltip: 'Audio Tracks'`.
   - Two-Way Audio Delay Sync:
     - In `_nudgeAudioDelay`: keep `_audioConfig.audioDelay = _audioDelayMs`.
     - When opening `AudioStudioSheet`: pass `_audioConfig` with current delay.
     - On sheet dismiss: `_audioDelayMs = _audioConfig.audioDelay`.

---

## 3. Discovered Specifications & Concrete Code Snippets

### 3.1 `AudioConfig` Implementation (`audio_studio_sheet.dart`)

```dart
class AudioConfig {
  bool enabled = true;
  String preset = 'Rock';
  double preamp = 0.0;
  double audioDelay = 0.0; // in milliseconds [-10000.0, 10000.0]

  // ... [freqs, presets, presetPreamps remain as verified in Milestone 2] ...

  /// Builds the mpv 'af' audio filter chain.
  String buildMpvAfString() {
    if (!enabled) return '';
    // ... [Preamp, Bass Boost, Night Mode, Virtualizer, 3D Audio, 10-Band EQ] ...
  }

  /// Sets only the audio-delay property in mpv without re-pushing the 'af' filter chain.
  void applyAudioDelay(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      platform.setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3));
    } catch (e) {
      debugPrint('[Audio Studio] mpv audio-delay error: $e');
    }
  }

  /// Applies both 'af' filter chain and 'audio-delay' property to mpv.
  void apply(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      platform.setProperty('af', buildMpvAfString());
      platform.setProperty('audio-delay', (audioDelay / 1000.0).toStringAsFixed(3));
    } catch (e) {
      debugPrint('[Audio Studio] mpv af/delay error: $e');
    }
  }

  /// Resets all audio settings to default flat unity values.
  void reset(Player? player) {
    enabled = true;
    preset = 'Flat';
    eq = List<double>.filled(10, 0.0);
    preamp = 0.0;
    audioDelay = 0.0;
    bassBoost = 0.0;
    bassBoostEnabled = false;
    virtualizer = false;
    threeDAudio = false;
    nightMode = false;
    apply(player);
  }
}
```

### 3.2 `_buildAudioDelaySyncCard()` in `_AudioStudioSheetState` (`audio_studio_sheet.dart`)

```dart
  Timer? _delayDebounce;

  void _debouncedApplyAudioDelay() {
    if (_delayDebounce?.isActive ?? false) _delayDebounce!.cancel();
    _delayDebounce = Timer(const Duration(milliseconds: 50), () {
      _config.applyAudioDelay(widget.player);
    });
  }

  void _nudgeAudioDelay(double deltaMs) {
    _config.audioDelay = (_config.audioDelay + deltaMs).clamp(-10000.0, 10000.0);
    _config.applyAudioDelay(widget.player);
    setState(() {});
  }

  void _resetAudioDelay() {
    _config.audioDelay = 0.0;
    _config.applyAudioDelay(widget.player);
    setState(() {});
  }

  Widget _buildAudioDelaySyncCard() {
    final delayVal = _config.audioDelay;
    return Container(
      key: const Key('audio_delay_sync_card'),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync, color: EDesign.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio Synchronization',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('audio_delay_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EDesign.elevatedSurface,
                  borderRadius: BorderRadius.circular(EDesign.r8),
                  border: Border.all(color: EDesign.border),
                ),
                child: Text(
                  '${delayVal >= 0 ? "+" : ""}${delayVal.toStringAsFixed(0)} ms',
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '-10.0s',
                style: TextStyle(
                  color: EDesign.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: EDesign.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: EDesign.primary,
                    overlayColor: EDesign.primary.withValues(alpha: 0.25),
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                  ),
                  child: Slider(
                    key: const Key('audio_delay_slider'),
                    value: (delayVal / 1000.0).clamp(-10.0, 10.0),
                    min: -10.0,
                    max: 10.0,
                    divisions: 400,
                    onChanged: (v) {
                      final ms = ((v * 1000.0) / 50.0).round() * 50.0;
                      _config.audioDelay = ms.clamp(-10000.0, 10000.0);
                      _debouncedApplyAudioDelay();
                      setState(() {});
                    },
                  ),
                ),
              ),
              const Text(
                '+10.0s',
                style: TextStyle(
                  color: EDesign.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNudgeButton('-100ms', const Key('audio_delay_nudge_minus_100'), () => _nudgeAudioDelay(-100)),
              _buildNudgeButton('-50ms', const Key('audio_delay_nudge_minus_50'), () => _nudgeAudioDelay(-50)),
              _buildNudgeButton('Reset', const Key('audio_delay_nudge_reset'), _resetAudioDelay),
              _buildNudgeButton('+50ms', const Key('audio_delay_nudge_plus_50'), () => _nudgeAudioDelay(50)),
              _buildNudgeButton('+100ms', const Key('audio_delay_nudge_plus_100'), () => _nudgeAudioDelay(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeButton(String label, Key key, VoidCallback onTap) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: EDesign.textPrimary,
        side: const BorderSide(color: EDesign.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(54, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
```

### 3.3 Standalone `AudioDelaySyncCard` Component (`audio_studio_sheet.dart`)

```dart
/// Standalone Audio Delay Synchronization Card conforming to R3 specification.
class AudioDelaySyncCard extends StatefulWidget {
  final Player? player;
  final double initialDelayMs;
  final ValueChanged<double>? onDelayChanged;

  const AudioDelaySyncCard({
    super.key,
    required this.player,
    this.initialDelayMs = 0.0,
    this.onDelayChanged,
  });

  @override
  State<AudioDelaySyncCard> createState() => AudioDelaySyncCardState();
}

class AudioDelaySyncCardState extends State<AudioDelaySyncCard> {
  late double _delayMs;

  @override
  void initState() {
    super.initState();
    _delayMs = widget.initialDelayMs;
  }

  void updateDelay(double ms) {
    final clamped = ms.clamp(-10000.0, 10000.0);
    setState(() {
      _delayMs = clamped;
    });
    if (widget.player != null) {
      try {
        final dynamic platform = widget.player!.platform;
        platform.setProperty('audio-delay', (_delayMs / 1000.0).toStringAsFixed(3));
      } catch (_) {}
    }
    widget.onDelayChanged?.call(_delayMs);
  }

  void nudge(double deltaMs) {
    updateDelay(_delayMs + deltaMs);
  }

  void reset() {
    updateDelay(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('audio_delay_sync_card'),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync, color: EDesign.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio Synchronization',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('audio_delay_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EDesign.elevatedSurface,
                  borderRadius: BorderRadius.circular(EDesign.r8),
                  border: Border.all(color: EDesign.border),
                ),
                child: Text(
                  '${_delayMs >= 0 ? "+" : ""}${_delayMs.toStringAsFixed(0)} ms',
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('-10.0s', style: TextStyle(color: EDesign.textMuted, fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: EDesign.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: EDesign.primary,
                    overlayColor: EDesign.primary.withValues(alpha: 0.25),
                  ),
                  child: Slider(
                    key: const Key('audio_delay_slider'),
                    value: (_delayMs / 1000.0).clamp(-10.0, 10.0),
                    min: -10.0,
                    max: 10.0,
                    divisions: 400,
                    onChanged: (v) {
                      updateDelay((v * 1000.0 * 2).round() / 2.0);
                    },
                  ),
                ),
              ),
              const Text('+10.0s', style: TextStyle(color: EDesign.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNudgeButton('-100ms', const Key('audio_delay_nudge_minus_100'), () => nudge(-100)),
              _buildNudgeButton('-50ms', const Key('audio_delay_nudge_minus_50'), () => nudge(-50)),
              _buildNudgeButton('Reset', const Key('audio_delay_nudge_reset'), reset),
              _buildNudgeButton('+50ms', const Key('audio_delay_nudge_plus_50'), () => nudge(50)),
              _buildNudgeButton('+100ms', const Key('audio_delay_nudge_plus_100'), () => nudge(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeButton(String label, Key key, VoidCallback onTap) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: EDesign.textPrimary,
        side: const BorderSide(color: EDesign.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(54, 32),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
```

### 3.4 `PlayerScreen` Audio Track Modal & HUD Key Enhancements (`player_screen.dart`)

```dart
  // In PlayerScreen._showAudioTrackMenu():
  void _showAudioTrackMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          key: const Key('audio_tracks_sheet'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: EDesign.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Audio Tracks', style: EDesign.h3),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (_audioTracks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: Text(
                            'No audio tracks found',
                            key: Key('audio_tracks_empty'),
                            style: EDesign.secondaryStyle,
                          ),
                        ),
                      ),
                    for (final track in _audioTracks)
                      ListTile(
                        key: Key('audio_track_item_${track.id}'),
                        leading: Icon(
                          Icons.audiotrack,
                          color: _selectedAudioTrack.id == track.id
                              ? EDesign.primary
                              : Colors.white70,
                          size: 20,
                        ),
                        title: Text(
                          track.title ?? track.language ?? track.id,
                          style: EDesign.body,
                        ),
                        subtitle: track.language != null
                            ? Text(
                                [
                                  track.language,
                                  if (track.channels != null) '${track.channels} ch',
                                  if (track.codec != null) track.codec,
                                ].whereType<String>().join(' • '),
                                style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                              )
                            : null,
                        trailing: _selectedAudioTrack.id == track.id
                            ? const Icon(
                                Icons.check,
                                color: EDesign.primary,
                                key: Key('active_track_check'),
                              )
                            : null,
                        onTap: () {
                          _player.setAudioTrack(track);
                          setState(() => _selectedAudioTrack = track);
                          final label = track.title ?? track.language ?? track.id;
                          _showFeedbackMessage('Audio: $label', Icons.audiotrack);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  // In HUD Top Bar IconButton:
  IconButton(
    key: const Key('hud_audio_tracks_button'),
    icon: const Icon(Icons.audiotrack_outlined, color: Colors.white70, size: 20),
    tooltip: 'Audio Tracks',
    onPressed: _showAudioTrackMenu,
  ),

  // Two-way sync when opening AudioStudioSheet:
  // In _nudgeAudioDelay:
  void _nudgeAudioDelay(int offsetMs) {
    _audioDelayMs = (_audioDelayMs + offsetMs).clamp(-10000.0, 10000.0);
    _audioConfig.audioDelay = _audioDelayMs;
    // ...
  }
  // When showing AudioStudioSheet:
  _audioConfig.audioDelay = _audioDelayMs;
  showModalBottomSheet(
    // ...
  ).then((_) {
    _audioDelayMs = _audioConfig.audioDelay;
    if (mounted) _keyboardFocusNode.requestFocus();
  });
```

---

## 4. Caveats & Potential Pitfalls

1. **Avoid Gating Audio Delay by `_config.enabled`**:
   - Equalizer enablement (`_config.enabled`) only controls the mpv `'af'` filter graph.
   - If a user turns off EQ (`_config.enabled = false`), their video and audio streams must still remain synchronized.
   - In `AudioConfig.apply(Player? player)`, `platform.setProperty('audio-delay', ...)` must execute unconditionally.
   - `_buildAudioDelaySyncCard()` must NOT be wrapped inside `AnimatedOpacity(opacity: _config.enabled ? 1.0 : 0.4)`.

2. **Immediate vs. Debounced Property Updates**:
   - Continuous slider dragging should be lightly debounced (`50ms`) to avoid overwhelming the IPC channel.
   - Nudge button taps (`-100ms`, `-50ms`, `Reset`, `+50ms`, `+100ms`) MUST dispatch immediately via `applyAudioDelay(player)`. Automated widget tests assert `fake.properties['audio-delay']` immediately after tapping without pumping timer durations.

3. **In-File Stub Shadowing in `test/e2e/phase1_e2e_test.dart`**:
   - `test/e2e/phase1_e2e_test.dart` defines its own local `class AudioDelaySyncCard`.
   - Dart's lexical scoping ensures that local class declarations shadow imported class declarations within the same file without syntax errors.
   - Implementing `AudioDelaySyncCard` in `audio_studio_sheet.dart` with matching parameters (`player`, `initialDelayMs`, `onDelayChanged`) guarantees full compatibility.

4. **Audio Track ID Comparison**:
   - Never rely on reference equality (`_selectedAudioTrack == track`) because stream emissions from `_player.stream.tracks` may produce distinct object instances for identical tracks.
   - Always check `_selectedAudioTrack.id == track.id`.

5. **Unit Test Headless Safety**:
   - In unit/widget test environments, `player.platform` might throw if unhandled or be null.
   - Always wrap platform calls in `try-catch` blocks and null-check `player`.

---

## 5. Conclusion

1. **Milestone 3 Architecture is Fully Mapped**:
   - `AudioConfig` requires `double audioDelay = 0.0;`, `applyAudioDelay(Player? player)`, and updates to `apply()` and `reset()`.
   - `AudioStudioSheet` requires `_buildAudioDelaySyncCard()` placed above `_buildPreampCard()`, bound to `_config.audioDelay`, featuring the 50ms-division continuous slider and 5 discrete nudge buttons.
   - A standalone `AudioDelaySyncCard` widget exported from `audio_studio_sheet.dart` provides full modularity and test parity.
   - `PlayerScreen` requires minor key additions (`hud_audio_tracks_button`, `audio_tracks_sheet`, `audio_tracks_empty`, `audio_track_item_${track.id}`, `active_track_check`), feedback pill invocation on track selection, and two-way delay synchronization.

2. **Ready for Clean Implementation**:
   - The implementer can apply these exact code structures to `audio_studio_sheet.dart` and `player_screen.dart`.
   - Dedicated unit tests verifying `audioDelay` conversion, clamping, and dispatching should be added to `test/features/audio_studio_test.dart`.

---

## 6. Verification Method

### 6.1 Independent Code Inspection
- Inspect `lib/features/player/ui/audio_studio_sheet.dart` to verify `audioDelay`, `applyAudioDelay`, and `_buildAudioDelaySyncCard()`.
- Inspect `lib/features/player/ui/player_screen.dart` to verify `_showAudioTrackMenu()` keys, HUD button key, and two-way delay sync.

### 6.2 Recommended Automated Unit Tests (`test/features/audio_studio_test.dart`)
Add the following test group to `test/features/audio_studio_test.dart`:
```dart
group('Group 7: Audio Delay Synchronization & mpv Binding', () {
  test('AudioConfig initializes with audioDelay = 0.0 ms', () {
    final config = AudioConfig();
    expect(config.audioDelay, equals(0.0));
  });

  test('audioDelay formats correctly as mpv audio-delay seconds', () {
    final fakePlatform = FakePlayerPlatform();
    final player = FakePlayer(fakePlatform);
    final config = AudioConfig();

    config.audioDelay = 50.0;
    config.applyAudioDelay(player);
    expect(fakePlatform.properties['audio-delay'], equals('0.050'));

    config.audioDelay = 150.0;
    config.applyAudioDelay(player);
    expect(fakePlatform.properties['audio-delay'], equals('0.150'));

    config.audioDelay = -100.0;
    config.applyAudioDelay(player);
    expect(fakePlatform.properties['audio-delay'], equals('-0.100'));

    config.audioDelay = 0.0;
    config.applyAudioDelay(player);
    expect(fakePlatform.properties['audio-delay'], equals('0.000'));
  });

  test('audioDelay applies even when EQ enabled is false', () {
    final fakePlatform = FakePlayerPlatform();
    final player = FakePlayer(fakePlatform);
    final config = AudioConfig()
      ..enabled = false
      ..audioDelay = 250.0;

    config.apply(player);
    expect(fakePlatform.properties['af'], equals(''));
    expect(fakePlatform.properties['audio-delay'], equals('0.250'));
  });

  test('reset restores audioDelay to 0.0 and applies 0.000 to platform', () {
    final fakePlatform = FakePlayerPlatform();
    final player = FakePlayer(fakePlatform);
    final config = AudioConfig()..audioDelay = 500.0;

    config.reset(player);
    expect(config.audioDelay, equals(0.0));
    expect(fakePlatform.properties['audio-delay'], equals('0.000'));
  });
});
```

### 6.3 Verification Commands
Run in `d:\E-player\app`:
```powershell
# 1. Run unit test suite
flutter test test/features/audio_studio_test.dart

# 2. Run E2E test suite
flutter test test/e2e/phase1_e2e_test.dart

# 3. Static analysis verification
dart analyze
```

### 6.4 Invalidation Conditions
This analysis is invalidated if:
- mpv property `'audio-delay'` expects milliseconds instead of seconds (verified: mpv documentation and tests require seconds).
- `AudioStudioSheet` requires an external audio controller instead of using `AudioConfig` as the single source of truth.
