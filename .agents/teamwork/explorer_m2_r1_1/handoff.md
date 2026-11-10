# Milestone 2 Investigation Handoff Report: Equalizer Parity & Pre-Amplification (R5)

**Agent**: Explorer 1 (`explorer_m2_r1_1`)  
**Target Codebase**: `d:\E-player\app`  
**Working Directory**: `d:\E-player\app`  
**State Folder**: `d:\E-player\.agents\teamwork\explorer_m2_r1_1\`  
**Milestone**: Milestone 2: Equalizer Parity & Pre-Amplification  
**Target Files Owned**:
- `lib/features/player/ui/audio_studio_sheet.dart`
- `test/features/audio_studio_test.dart`  
**Date**: 2026-11-10T08:52:00Z  

---

## 1. Observation

Direct code and artifact observations from `d:\E-player\app` and authoritative project documents:

### 1.1 AudioConfig Analysis (`lib/features/player/ui/audio_studio_sheet.dart:6-98`)
1. **Class Definition & State**:
   ```dart
   class AudioConfig {
     bool enabled = true;
     String preset = 'Rock';
     static const List<int> freqs = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];
     static const List<String> freqLabels = ['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'];
     List<double> eq = [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5]; // Default Rock
     double bassBoost = 6.0; // 0 to 12 dB
     bool bassBoostEnabled = true;
     bool virtualizer = true;
     bool threeDAudio = true;
     bool nightMode = false;
   ```
2. **Current Presets**:
   Lines 23–33 define only 9 presets (`Flat`, `Rock`, `Pop`, `Jazz`, `Classical`, `Bass Boost`, `Vocal Boost`, `Techno`, `Club`).
   Missing all 11 canonical VLC presets: `Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`.
3. **Filter Graph Synthesis in `apply(Player? player)` (lines 42–85)**:
   ```dart
   final List<String> filters = [];
   if (bassBoostEnabled && bassBoost > 0) {
     filters.add('bass=g=${bassBoost.toStringAsFixed(1)}');
   }
   if (nightMode) {
     filters.add('dynaudnorm=f=200:g=15');
   }
   if (virtualizer) {
     filters.add('extrastereo=m=2.2');
   }
   if (threeDAudio) {
     filters.add('stereowiden=level=0.7');
   }
   for (int i = 0; i < freqs.length; i++) {
     if (eq[i].abs() > 0.05) {
       filters.add('equalizer=f=${freqs[i]}:width_type=q:width=1.2:g=${eq[i].toStringAsFixed(1)}');
     }
   }
   final afString = filters.join(',');
   platform.setProperty('af', afString);
   ```
   **Observation**: Currently, `filters` has NO entry for pre-amplification (`volume=volume=...`).
4. **Preset Application & Reset Logic**:
   - `applyPreset(String name)` (lines 35–40) currently sets `preset = name; eq = List<double>.from(presets[name]!);`. It does not handle pre-amplification.
   - `reset(Player? player)` (lines 87–97) resets `enabled`, `preset = 'Flat'`, `eq`, `bassBoost`, `virtualizer`, `threeDAudio`, `nightMode`, but lacks a reset for `preamp`.

### 1.2 AudioStudioSheet UI Architecture (`lib/features/player/ui/audio_studio_sheet.dart:139-725`)
1. **Layout Structure in `build(BuildContext context)` (lines 252–533)**:
   A `SingleChildScrollView` containing:
   - Lines 261–291: Sheet handle and Header Row (`'Audio Equalizer'`, Close button).
   - Lines 294–326: Master Switch Card (`'Enable Equalizer'`, active switch toggling `_config.enabled`).
   - Lines 329–374: Preset Selector Dropdown Pill (`_showPresetPicker()` bottom sheet).
   - Lines 377–451: 10-Band Graphic Equalizer Scale (`AnimatedOpacity`, `Container` with ±12dB scale labels, 160px height stack with center 0dB line, 10 rotated sliders).
   - Lines 454–514: Boost Controls (Bass Boost card, Virtualizer tile, 3D Audio tile, Night Mode tile).
   - Lines 517–529: "Reset to Flat Defaults" button.
2. **Current 10-Band Slider Stack (`lines 398–448` & `lines 550–620`)**:
   - Top scale labels: `+12dB` (line 403, 404).
   - Bottom scale labels: `-12dB` (line 443, 444).
   - Center 0dB Reference Line: `Positioned(left: 12, right: 12, child: Container(height: 1, color: Colors.white.withValues(alpha: 0.12)))` inside a `Stack(alignment: Alignment.center)`.
   - Vertical slider configuration:
     ```dart
     Slider(
       value: value.clamp(-12.0, 12.0),
       min: -12.0,
       max: 12.0,
       ...
     )
     ```
   - Frequency labels: `'60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'`.
   - Live value badge above slider:
     ```dart
     Text(
       '${value > 0 ? "+" : ""}${value.toStringAsFixed(1)}',
       style: TextStyle(
         color: isFocused ? EDesign.primary : Colors.white70,
         fontSize: 9,
         fontWeight: FontWeight.w800,
       ),
     )
     ```

### 1.3 Design System Tokens (`lib/ui/theme/e_design_tokens.dart`)
- `EDesign.surface`: `Color(0xFF0D1728)`
- `EDesign.elevatedSurface`: `Color(0xFF12213A)`
- `EDesign.border`: `Color(0xFF1B3556)`
- `EDesign.primary`: `Color(0xFF19BFFF)`
- `EDesign.textPrimary`: `Color(0xFFF5F8FF)`
- `EDesign.textSecondary`: `Color(0xFFA7B5CA)`
- `EDesign.textMuted`: `Color(0xFF6E7E95)`
- `EDesign.r8`: `8.0`, `EDesign.r14`: `14.0`, `EDesign.r16`: `16.0`, `EDesign.r18`: `18.0`

### 1.4 Test Suite & Static Analysis Status
- Command `Get-ChildItem -Path test -Recurse -Filter "*.dart" | Select-String -Pattern "AudioConfig"` returned 0 matches across the entire test directory.
- `test/features/audio_studio_test.dart` does not currently exist.
- Command `cd d:\E-player\app; dart analyze` executed and completed with exit code 0:
  ```
  Analyzing app...
  No issues found!
  ```
  Confirming clean baseline static analysis with 0 errors and 0 warnings.

---

## 2. Logic Chain

### 2.1 AudioConfig Preamp Implementation & mpv Filter Placement
1. **State Addition**:
   - Adding `double preamp = 0.0;` to `AudioConfig` tracks global pre-amplification gain in decibels across `[-20.0, +20.0]`.
   - Initialized to `0.0 dB` (unity gain).
   - In `reset(Player? player)`, resetting `preamp = 0.0;` ensures the player returns to clean flat defaults.
2. **Filter Graph Pipeline Ordering**:
   - In digital audio DSP, pre-amplification scales the input signal before frequency band filtering (`equalizer`), non-linear dynamics (`bass`), and spatial stereo expansion (`extrastereo`, `stereowiden`).
   - Therefore, the preamp filter **must be prepended** at index 0 of `filters` before any tone or equalization filters.
   - Filter format requirement:
     `volume=volume=${preamp >= 0 ? "+" : ""}${preamp.toStringAsFixed(1)}dB:precision=fixed`
     - When `preamp = 5.0` -> `volume=volume=+5.0dB:precision=fixed`
     - When `preamp = -10.5` -> `volume=volume=-10.5dB:precision=fixed`
   - Omission threshold:
     `if (preamp.abs() > 0.05)` guarantees that when `preamp == 0.0 dB`, the volume filter is omitted, preserving bit-perfect audio pass-through without unnecessary FFmpeg filtering overhead.
3. **Preset Preamp Synchronization**:
   - VLC presets associate a specific pre-amplification value with each 10-band curve (e.g. `Full Bass` has `+5.0dB`, `Reggae` has `+8.0dB`).
   - Maintaining `presets` as `Map<String, List<double>>` and introducing `presetPreamps` as `Map<String, double>` preserves 100% backward compatibility for all callers accessing `AudioConfig.presets`.
   - In `applyPreset(String name)`:
     ```dart
     void applyPreset(String name) {
       if (presets.containsKey(name)) {
         preset = name;
         eq = List<double>.from(presets[name]!);
         preamp = presetPreamps[name] ?? 0.0;
       }
     }
     ```
   - When any preset is selected from the picker, both the 10 bands and the preamp slider update simultaneously to the canonical VLC values.
4. **Testability & Filter String Extraction**:
   - Extracting `String buildMpvAfString()` from `apply(Player? player)` allows pure unit tests without requiring a native libmpv binary runtime, exactly mirroring `VideoEffectsConfig.buildMpvVfString()` in `test/features/video_effects_test.dart`.

### 2.2 11 Canonical VLC Presets Table
Synthesizing the authoritative IEEE 754 float values from `SCOPE.md` and `spec_miner_phase1/handoff.md`:

| Preset Name | Preamp | 60Hz | 170Hz | 310Hz | 600Hz | 1kHz | 3kHz | 6kHz | 12kHz | 14kHz | 16kHz |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Full Bass** | `+5.0` | `-8.0` | `+9.6` | `+9.6` | `+5.6` | `+1.6` | `-4.0` | `-8.0` | `-10.4` | `-11.2` | `-11.2` |
| **Full Bass & Treble** | `+4.0` | `+7.2` | `+5.6` | `0.0` | `-7.2` | `-4.8` | `+1.6` | `+8.0` | `+11.2` | `+12.0` | `+12.0` |
| **Full Treble** | `+3.0` | `-9.6` | `-9.6` | `-9.6` | `-4.0` | `+2.4` | `+11.2` | `+16.0` | `+16.0` | `+16.0` | `+16.8` |
| **Headphones** | `+4.0` | `+4.8` | `+11.2` | `+5.6` | `-3.2` | `-2.4` | `+1.6` | `+4.8` | `+9.6` | `+12.8` | `+14.4` |
| **Large Hall** | `+5.0` | `+10.4` | `+10.4` | `+5.6` | `+5.6` | `0.0` | `-4.8` | `-4.8` | `-4.8` | `0.0` | `0.0` |
| **Live** | `+7.0` | `-4.8` | `0.0` | `+4.0` | `+5.6` | `+5.6` | `+5.6` | `+4.0` | `+2.4` | `+2.4` | `+2.4` |
| **Party** | `+6.0` | `+7.2` | `+7.2` | `0.0` | `0.0` | `0.0` | `0.0` | `0.0` | `0.0` | `+7.2` | `+7.2` |
| **Reggae** | `+8.0` | `0.0` | `0.0` | `0.0` | `-5.6` | `0.0` | `+6.4` | `+6.4` | `0.0` | `0.0` | `0.0` |
| **Ska** | `+6.0` | `-2.4` | `-4.8` | `-4.0` | `0.0` | `+4.0` | `+5.6` | `+8.8` | `+9.6` | `+11.2` | `+9.6` |
| **Soft** | `+5.0` | `+4.8` | `+1.6` | `0.0` | `-2.4` | `0.0` | `+4.0` | `+8.0` | `+9.6` | `+11.2` | `+12.0` |
| **Soft Rock** | `+7.0` | `+4.0` | `+4.0` | `+2.4` | `0.0` | `-4.0` | `-5.6` | `-3.2` | `0.0` | `+2.4` | `+8.8` |

Combined with the 9 existing presets (`Flat`, `Rock`, `Pop`, `Jazz`, `Classical`, `Bass Boost`, `Vocal Boost`, `Techno`, `Club`), this produces exactly 20 presets in total.

### 2.3 AudioStudioSheet Pre-Amplification Slider Architecture
1. **Visual Placement**:
   - Located directly above the 10-Band Graphic Equalizer Scale (between line 375 and line 378).
   - Wrapped in `AnimatedOpacity(opacity: _config.enabled ? 1.0 : 0.4)` so it cleanly respects the master equalizer enable/disable state.
2. **Container & Token Styling**:
   - Background: `EDesign.surface`
   - Radius: `BorderRadius.circular(EDesign.r16)`
   - Border: `Border.all(color: EDesign.border)`
   - Padding: `const EdgeInsets.symmetric(horizontal: 16, vertical: 12)`
3. **Card Header**:
   - Leading icon: `Icon(Icons.tune, color: EDesign.primary, size: 20)`
   - Title: `Text('Pre-Amplification', style: TextStyle(color: EDesign.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))`
   - Live dB Badge:
     - Pill container: `EDesign.elevatedSurface` background with `EDesign.border`
     - Formatted string: `${_config.preamp >= 0 ? "+" : ""}${_config.preamp.toStringAsFixed(1)} dB`
     - Typography: `TextStyle(color: EDesign.primary, fontSize: 12, fontWeight: FontWeight.w700)`
   - Reset Button:
     - `IconButton(icon: const Icon(Icons.refresh, size: 18), tooltip: 'Reset Preamp to 0.0 dB', ...)`
     - Active only when `_config.enabled && _config.preamp != 0.0`
     - On tap: sets `_config.preamp = 0.0;`, calls `_debouncedApply()`, calls `setState(() {})`.
4. **Slider Geometry**:
   - Min: `-20.0`
   - Max: `+20.0`
   - Divisions: `80` (yielding exact `0.5 dB` steps)
   - Value: `_config.preamp.clamp(-20.0, 20.0)`
   - Left label: `-20dB` (`EDesign.textMuted`, font size 10)
   - Right label: `+20dB` (`EDesign.textMuted`, font size 10)
   - OnChanged callback:
     ```dart
     onChanged: _config.enabled
         ? (v) {
             _config.preamp = (v * 2).round() / 2.0; // snap to 0.5dB
             _debouncedApply();
           }
         : null,
     ```

### 2.4 10-Band Graphic Equalizer Scale Expansion (-20.0dB to +20.0dB)
1. **Vertical Slider Parameters**:
   - In `_build10BandSlider(int index)`:
     - Change `value.clamp(-12.0, 12.0)` -> `value.clamp(-20.0, 20.0)`
     - Change `min: -12.0` -> `min: -20.0`
     - Change `max: 12.0` -> `max: 20.0`
2. **Datum Line & Symmetry Invariant**:
   - In Flutter, a slider with `min: A` and `max: B` maps a value `V` to normalized position `t = (V - A) / (B - A)`.
   - For `[-12.0, 12.0]`: `t(0.0) = (0.0 - (-12.0)) / 24.0 = 12.0 / 24.0 = 0.5`.
   - For `[-20.0, 20.0]`: `t(0.0) = (0.0 - (-20.0)) / 40.0 = 20.0 / 40.0 = 0.5`.
   - Because the slider remains symmetric around 0.0, the slider thumb at 0.0dB aligns exactly with the horizontal center line rendered by `Positioned(child: Container(height: 1, ...))` inside `Stack(alignment: Alignment.center)`.
   - The visual 0dB datum line requires zero spatial or offset adjustments!
3. **Scale Labels**:
   - Replace top scale labels `+12dB` -> `+20dB` at lines 403, 404.
   - Replace bottom scale labels `-12dB` -> `-20dB` at lines 443, 444.
4. **Live Badge & Frequency Labels**:
   - The thumb badge formatting `${value > 0 ? "+" : ""}${value.toStringAsFixed(1)}` naturally accommodates double values up to `+20.0` and down to `-20.0`.
   - Frequency labels `AudioConfig.freqLabels` ('60' through '16K') remain untouched.

### 2.5 Exclusive Ownership & Scope Boundary Invariant
- Files modified in Milestone 2:
  - `lib/features/player/ui/audio_studio_sheet.dart` (Implementation)
  - `test/features/audio_studio_test.dart` (Automated verification)
- Files strictly untouched:
  - `lib/features/player/ui/widgets/desktop_keyboard_handler.dart` (Owned by M1)
  - `lib/features/player/ui/player_screen.dart` (Owned by M1)
- Contract stability:
  - `AudioConfig` constructors and existing public properties are untouched.
  - `AudioStudioSheet` constructor is untouched.
  - `apply(Player? player)` retains its exact signature and exception-safe try/catch block.
  - Zero breaking changes to `PlayerScreen` or external callers.

---

## 3. Caveats

1. **Unity Gain Pass-Through**:
   mpv `volume` audio filter should only be inserted when `preamp.abs() > 0.05`. At `0.0 dB`, adding `volume=volume=+0.0dB:precision=fixed` unnecessarily inserts an FFmpeg audio filter node. Omitting it at unity gain preserves zero DSP overhead.
2. **Audio Delay (M3 Scope)**:
   While `PROJECT.md` mentions `audioDelay`, Milestone 2 scope is strictly limited to R5 (Equalizer Parity & Preamp). Audio Delay slider and track selection UI belong to Milestone 3. `AudioConfig` can include a default `double audioDelay = 0.0;` if helpful, but full UI integration belongs to M3.
3. **Dynamic Custom Preset Transition**:
   When the user moves any of the 10 band sliders or the preamp slider, `_config.preset` transitions to `'Custom'`, correctly communicating to the user that the EQ is in manual tuning mode.

---

## 4. Conclusion

1. **AudioConfig**:
   - Add `double preamp = 0.0;` to `AudioConfig`.
   - Add 11 canonical VLC presets to `presets` and their respective preamp gains to `presetPreamps` (total 20 presets).
   - In `apply(Player? player)`, prepend `volume=volume=${preamp >= 0 ? "+" : ""}${preamp.toStringAsFixed(1)}dB:precision=fixed` to `filters` when `preamp.abs() > 0.05`.
   - Extract `String buildMpvAfString()` to enable clean, mock-free unit testing.
   - Update `reset(Player? player)` to clear `preamp = 0.0;`.
2. **AudioStudioSheet**:
   - Render `_buildPreampCard()` directly above the 10-band slider stack.
   - Style with `EDesign.surface`, `EDesign.border`, and `EDesign.primary`.
   - Implement continuous slider from `-20.0dB` to `+20.0dB` with `0.5dB` step resolution (80 divisions).
   - Add live dB badge `${_config.preamp >= 0 ? "+" : ""}${_config.preamp.toStringAsFixed(1)} dB`.
   - Add dedicated reset button restoring preamp to `0.0dB`.
3. **10-Band Graphic Equalizer Scale**:
   - Expand slider min/max from `[-12.0, 12.0]` to `[-20.0, 20.0]`.
   - Update top and bottom scale labels to `+20dB` and `-20dB`.
   - Maintain 0dB datum line alignment via symmetric range.
4. **Verification & Ownership**:
   - Only `lib/features/player/ui/audio_studio_sheet.dart` and `test/features/audio_studio_test.dart` will be modified.
   - Comprehensive unit test suite in `test/features/audio_studio_test.dart` will verify all 20 presets, preamp filter synthesis, 0dB omission, band gain bounds, and reset defaults.

---

## 5. Verification Method

### 5.1 Verification Commands
Once the implementation is authored by the worker, the following verification commands must be executed in `d:\E-player\app`:
```powershell
# 1. Run the new Audio Studio unit test suite
flutter test test/features/audio_studio_test.dart

# 2. Run static analysis across the entire project
dart analyze

# 3. Verify regression integrity against existing test suites
flutter test test/features/video_effects_test.dart
flutter test test/unit/decoder_pipeline_test.dart
```

### 5.2 Concrete Implementation Blueprint for Implementer

#### Diff Sketch for `lib/features/player/ui/audio_studio_sheet.dart`
```dart
// 1. AudioConfig additions:
class AudioConfig {
  bool enabled = true;
  String preset = 'Rock';
  double preamp = 0.0; // [-20.0, +20.0] dB

  static const Map<String, double> presetPreamps = {
    'Full Bass': 5.0,
    'Full Bass & Treble': 4.0,
    'Full Treble': 3.0,
    'Headphones': 4.0,
    'Large Hall': 5.0,
    'Live': 7.0,
    'Party': 6.0,
    'Reggae': 8.0,
    'Ska': 6.0,
    'Soft': 5.0,
    'Soft Rock': 7.0,
    'Flat': 0.0,
    'Rock': 0.0,
    'Pop': 0.0,
    'Jazz': 0.0,
    'Classical': 0.0,
    'Bass Boost': 0.0,
    'Vocal Boost': 0.0,
    'Techno': 0.0,
    'Club': 0.0,
  };

  // Add the 11 VLC presets to presets Map:
  // 'Full Bass': [-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2],
  // ...

  String buildMpvAfString() {
    if (!enabled) return '';
    final List<String> filters = [];
    if (preamp.abs() > 0.05) {
      filters.add('volume=volume=${preamp >= 0 ? "+" : ""}${preamp.toStringAsFixed(1)}dB:precision=fixed');
    }
    if (bassBoostEnabled && bassBoost > 0) {
      filters.add('bass=g=${bassBoost.toStringAsFixed(1)}');
    }
    if (nightMode) {
      filters.add('dynaudnorm=f=200:g=15');
    }
    if (virtualizer) {
      filters.add('extrastereo=m=2.2');
    }
    if (threeDAudio) {
      filters.add('stereowiden=level=0.7');
    }
    for (int i = 0; i < freqs.length; i++) {
      if (eq[i].abs() > 0.05) {
        filters.add('equalizer=f=${freqs[i]}:width_type=q:width=1.2:g=${eq[i].toStringAsFixed(1)}');
      }
    }
    return filters.join(',');
  }

  void apply(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      platform.setProperty('af', buildMpvAfString());
    } catch (e) {
      debugPrint('[Audio Studio] mpv af error: $e');
    }
  }

  void applyPreset(String name) {
    if (presets.containsKey(name)) {
      preset = name;
      eq = List<double>.from(presets[name]!);
      preamp = presetPreamps[name] ?? 0.0;
    }
  }

  void reset(Player? player) {
    enabled = true;
    preset = 'Flat';
    eq = List<double>.filled(10, 0.0);
    preamp = 0.0;
    bassBoost = 0.0;
    bassBoostEnabled = false;
    virtualizer = false;
    threeDAudio = false;
    nightMode = false;
    apply(player);
  }
}
```

### 5.3 Invalidation Conditions
This investigation is invalidated if:
1. mpv fails to parse `volume=volume=+5.0dB:precision=fixed` as a valid audio filter.
2. Setting slider range to `[-20.0, 20.0]` skews the 0dB datum line off-center (disproven: mathematically centered at `t=0.5`).
3. VLC canonical preset definitions differ from the IEEE 754 float values mined from `libequalizer_plugin.dll`.
