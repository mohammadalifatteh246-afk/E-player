# Milestone 2 Test Engineering & Equalizer Parity Handoff Report

**Agent**: Explorer 2 (`explorer_m2_r1_2`)  
**Milestone**: Milestone 2 — Equalizer Parity & Pre-Amplification (R5)  
**Target Files**:
- `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart` (Implementation)
- `d:\E-player\app\test\features\audio_studio_test.dart` (Automated Test Suite)  
**Authoritative References**:
- `d:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md` (Requirement R5)
- `d:\E-player\PROJECT.md`
- `d:\E-player\.agents\teamwork\sub_orch_m2\SCOPE.md`
- `d:\E-player\.agents\teamwork\explorer_audio_studio\handoff.md`
- `d:\E-player\.agents\teamwork\spec_miner_phase1\handoff.md`
- PE32 Binary Dump: `C:\Program Files (x86)\VideoLAN\VLC\plugins\audio_filter\libequalizer_plugin.dll`

---

## 1. Observation

### 1.1 Existing AudioConfig Implementation
- **File**: `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart:6-98`
- `AudioConfig` currently defines:
  ```dart
  static const List<int> freqs = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];
  static const List<String> freqLabels = ['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'];
  ```
- Current presets table (`audio_studio_sheet.dart:23-33`) holds **only 9 presets**:
  `Flat`, `Rock`, `Pop`, `Jazz`, `Classical`, `Bass Boost`, `Vocal Boost`, `Techno`, `Club`.
  The 11 requested VLC presets (`Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`) are currently **absent**.
- Pre-amplification field (`preamp`) is completely missing from `AudioConfig`.
- Sliders in `_build10BandSlider` (`audio_studio_sheet.dart:588-590`) and header labels (`lines 403, 443`) are clamped to `[-12.0, 12.0] dB`, whereas VLC standard requires `[-20.0, 20.0] dB`.
- Direct platform invocation in `AudioConfig.apply(Player? player)` (`audio_studio_sheet.dart:42-85`):
  ```dart
  final dynamic platform = player.platform;
  if (!enabled) {
    platform.setProperty('af', '');
    return;
  }
  // filter accumulation...
  final afString = filters.join(',');
  platform.setProperty('af', afString);
  ```

### 1.2 Existing Testing Patterns in Codebase
- **Video Effects Test (`app/test/features/video_effects_test.dart:98-128`)**:
  `VideoEffectsConfig` exposes `buildMpvVfString()`, allowing completely synchronous, pure unit tests of filter chain generation (`unsharp=...`, `gradfun=...`, `hflip`, etc.) without requiring native mpv binaries.
- **Decoder Pipeline Test (`app/test/unit/decoder_pipeline_test.dart:6-20`)**:
  Defines `FakeMpvPlatform` directly in the test file with in-memory `properties` map:
  ```dart
  class FakeMpvPlatform {
    final Map<String, String> properties = {};
    final List<String> setPropertyCalls = [];
    Future<void> setProperty(String property, String value) async {
      properties[property] = value;
      setPropertyCalls.add('$property=$value');
    }
    Future<dynamic> getProperty(String property) async => properties[property];
  }
  ```
- **MediaKit Player Definition (`media_kit-1.2.6/lib/src/player/player.dart:101-125`)**:
  `Player` accepts an optional `PlatformPlayer? platformPlayer` constructor argument, and exposes `PlatformPlayer? platform`.
  Because `Player` is a standard Dart class, test suites can use `Fake implements Player` from `package:flutter_test/flutter_test.dart` to mock `player.platform` with zero native dependencies.

### 1.3 Authoritative VLC Binary Forensics Verification
Execution of `d:\E-player\.agents\teamwork\spec_miner_phase1\dump_presets_clean.py` against `C:\Program Files (x86)\VideoLAN\VLC\plugins\audio_filter\libequalizer_plugin.dll` extracted the canonical IEEE 754 float values for all 18 VLC presets:
- `Preset 04: fullbass`: Preamp: `+5.0 dB`, Bands: `[-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]`
- `Preset 05: fullbasstreble`: Preamp: `+4.0 dB`, Bands: `[7.2, 5.6, -0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]`
- `Preset 06: fulltreble`: Preamp: `+3.0 dB`, Bands: `[-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]`
- `Preset 07: headphones`: Preamp: `+4.0 dB`, Bands: `[4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]`
- `Preset 08: largehall`: Preamp: `+5.0 dB`, Bands: `[10.4, 10.4, 5.6, 5.6, -0.0, -4.8, -4.8, -4.8, -0.0, -0.0]`
- `Preset 09: live`: Preamp: `+7.0 dB`, Bands: `[-4.8, -0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]`
- `Preset 10: party`: Preamp: `+6.0 dB`, Bands: `[7.2, 7.2, -0.0, -0.0, -0.0, -0.0, -0.0, -0.0, 7.2, 7.2]`
- `Preset 12: reggae`: Preamp: `+8.0 dB`, Bands: `[-0.0, -0.0, -0.0, -5.6, -0.0, 6.4, 6.4, -0.0, -0.0, -0.0]`
- `Preset 14: ska`: Preamp: `+6.0 dB`, Bands: `[-2.4, -4.8, -4.0, -0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]`
- `Preset 15: soft`: Preamp: `+5.0 dB`, Bands: `[4.8, 1.6, -0.0, -2.4, -0.0, 4.0, 8.0, 9.6, 11.2, 12.0]`
- `Preset 16: softrock`: Preamp: `+7.0 dB`, Bands: `[4.0, 4.0, 2.4, -0.0, -4.0, -5.6, -3.2, -0.0, 2.4, 8.8]`

---

## 2. Logic Chain

1. **Eliminating Native mpv / MediaKit Dependencies in Unit Tests**:
   - Running tests that instantiate native `Player()` on machines without native `libmpv-2.dll` or on headless test runners causes platform initialization failures.
   - By creating a lightweight `FakePlayerPlatform` and a `FakePlayer extends Fake implements Player`, `AudioConfig.apply(player)` can be invoked directly in unit tests.
   - `player.platform.setProperty('af', ...)` captures the filter string into a simple Dart `Map<String, String>`, validating end-to-end platform dispatch without any native binaries.
   - In addition, exposing `String buildMpvAfString()` in `AudioConfig` provides architectural parity with `VideoEffectsConfig.buildMpvVfString()` and enables fast, pure logical unit tests.

2. **20 Preset Matrix Verification**:
   - The original 9 presets (`Flat`, `Rock`, `Pop`, `Jazz`, `Classical`, `Bass Boost`, `Vocal Boost`, `Techno`, `Club`) must remain intact to preserve backwards compatibility.
   - Adding the 11 VLC presets brings the total presets count to exactly **20**.
   - `AudioConfig.presets` maps name to `List<double>` (10 bands).
   - Adding a companion `static const Map<String, double> presetPreamps` enables `applyPreset(name)` to update both `eq` and `preamp`.
   - The test suite must assert:
     - `AudioConfig.presets.length == 20`
     - Each of the 20 presets has `length == 10`
     - For each of the 11 VLC presets, all 10 band decibel values match the binary extraction within `±0.001 dB` tolerance
     - Each preset's default `preamp` is correctly set.

3. **Pre-Amplification Filter String Formatting & Pass-Through**:
   - mpv expects volume filter syntax: `volume=volume=+X.XdB:precision=fixed` (positive) or `volume=volume=-X.XdB:precision=fixed` (negative).
   - Bit-perfect pass-through requirement: when `preamp.abs() <= 0.05` (e.g. `0.0 dB`), the `volume` filter must be **omitted** from the `af` string.
   - When `preamp.abs() > 0.05`, the volume filter must be **prepended** at index 0 of the filter cascade before any EQ or enhancement filters.
   - The test suite must test positive, negative, zero, boundary (`+0.04`, `+0.06`, `-0.05`, `-0.06`), and extreme (`+20.0`, `-20.0`) values.

4. **Range Expansion & Bounds Checking**:
   - VLC graphic equalizer headroom is `±20.0 dB`.
   - The 10 vertical sliders and preamp slider in `AudioStudioSheet` must allow the full `[-20.0, 20.0]` range.
   - The test suite must verify that band values and preamp values outside `[-20.0, 20.0]` clamp properly and that extreme values (`+20.0dB`, `-20.0dB`) generate valid mpv filter strings.

---

## 3. Caveats

1. **No Alteration of Milestone 1 Files**:
   - Milestone 1 owns `desktop_keyboard_handler.dart` and `player_screen.dart`. This test suite focuses strictly on `AudioConfig` and `AudioStudioSheet` in `test/features/audio_studio_test.dart`.
2. **Audio Delay Synchronization**:
   - While `audioDelay` is planned for Milestone 3, `AudioConfig` can safely have `double audioDelay = 0.0;` if needed. However, the tests in Milestone 2 focus specifically on Requirement R5 (20 EQ presets, preamp slider, and ±20dB scale expansion).
3. **Floating Point Negative Zero in PE Dump**:
   - In the binary PE dump, some bands have `-0.0`. In Dart, `0.0 == -0.0` is `true`. All assertions should use `closeTo(expected, 0.001)` or `equals(0.0)`.

---

## 4. Conclusion & Concrete Test Design

### 4.1 Mock Architecture (Zero-Dependency)
```dart
/// In-memory mock platform simulating libmpv platform property store.
class FakePlayerPlatform {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }
}

/// Lightweight mock Player satisfying Player interface via Fake.
class FakePlayer extends Fake implements Player {
  @override
  final dynamic platform;

  FakePlayer([dynamic platform]) : platform = platform ?? FakePlayerPlatform();
}
```

### 4.2 Exact 20-Preset Truth Table & Assertions

```dart
final Map<String, ({double preamp, List<double> bands})> expectedPresets = {
  // Baseline 9 Presets
  'Flat': (preamp: 0.0, bands: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
  'Rock': (preamp: 0.0, bands: [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5]),
  'Pop': (preamp: 0.0, bands: [-1.5, -1.0, 1.0, 2.5, 4.0, 3.5, 1.5, -1.0, -1.5, -2.0]),
  'Jazz': (preamp: 0.0, bands: [3.0, 2.0, 1.0, 1.5, -1.5, -1.5, 0.0, 1.5, 3.0, 3.5]),
  'Classical': (preamp: 0.0, bands: [4.0, 3.0, 2.5, 2.0, -1.5, -1.5, 0.0, 2.5, 3.5, 4.0]),
  'Bass Boost': (preamp: 0.0, bands: [8.0, 7.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
  'Vocal Boost': (preamp: 0.0, bands: [-2.0, -2.5, -1.0, 2.0, 5.0, 5.0, 3.5, 1.5, 0.0, -1.5]),
  'Techno': (preamp: 0.0, bands: [6.0, 5.0, 0.0, -3.0, -2.5, 0.0, 4.0, 6.0, 6.5, 6.5]),
  'Club': (preamp: 0.0, bands: [0.0, 0.0, 2.0, 3.5, 3.5, 3.5, 2.0, 0.0, 0.0, 0.0]),

  // 11 New VLC Presets (Extracted from libequalizer_plugin.dll)
  'Full Bass': (preamp: 5.0, bands: [-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]),
  'Full Bass & Treble': (preamp: 4.0, bands: [7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]),
  'Full Treble': (preamp: 3.0, bands: [-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]),
  'Headphones': (preamp: 4.0, bands: [4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]),
  'Large Hall': (preamp: 5.0, bands: [10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0]),
  'Live': (preamp: 7.0, bands: [-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]),
  'Party': (preamp: 6.0, bands: [7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2]),
  'Reggae': (preamp: 8.0, bands: [0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0]),
  'Ska': (preamp: 6.0, bands: [-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]),
  'Soft': (preamp: 5.0, bands: [4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0]),
  'Soft Rock': (preamp: 7.0, bands: [4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8]),
};
```

### 4.3 Proposed Implementation Updates in `audio_studio_sheet.dart`
The worker will apply the following targeted modifications:
1. **Preamp & 20 Presets in `AudioConfig`**:
   ```dart
   double preamp = 0.0; // [-20.0, +20.0] dB
   ```
   Add the 11 presets to `static const Map<String, List<double>> presets`.
   Add `static const Map<String, double> presetPreamps` mapping all 20 presets to their preamp gain.
   Update `applyPreset(name)`:
   ```dart
   void applyPreset(String name) {
     if (presets.containsKey(name)) {
       preset = name;
       eq = List<double>.from(presets[name]!);
       preamp = presetPreamps[name] ?? 0.0;
     }
   }
   ```
2. **`buildMpvAfString()` Method**:
   Extract filter construction into `String buildMpvAfString()`:
   ```dart
   String buildMpvAfString() {
     if (!enabled) return '';
     final List<String> filters = [];

     // Preamp prepended at index 0
     if (preamp.abs() > 0.05) {
       final sign = preamp >= 0 ? '+' : '';
       filters.add('volume=volume=$sign${preamp.toStringAsFixed(1)}dB:precision=fixed');
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
   ```
3. **`apply(Player? player)`**:
   ```dart
   void apply(Player? player) {
     if (player == null) return;
     try {
       final dynamic platform = player.platform;
       final afString = buildMpvAfString();
       platform.setProperty('af', afString);
     } catch (e) {
       debugPrint('[Audio Studio] mpv af error: $e');
     }
   }
   ```
4. **Preamp Slider in `AudioStudioSheet`**:
   Render Pre-Amplification Slider Card directly above the 10-band slider stack with range `min: -20.0, max: 20.0`.
5. **Scale Labels & Clamping**:
   Update `+12dB` and `-12dB` to `+20dB` and `-20dB` in `audio_studio_sheet.dart:403, 443`, and vertical sliders `value.clamp(-20.0, 20.0), min: -20.0, max: 20.0`.

### 4.4 Complete Test Suite Blueprint (`test/features/audio_studio_test.dart`)
The worker / test writer should author `test/features/audio_studio_test.dart` containing these 6 test groups:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';

class FakePlayerPlatform {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }
}

class FakePlayer extends Fake implements Player {
  @override
  final dynamic platform;

  FakePlayer([dynamic platform]) : platform = platform ?? FakePlayerPlatform();
}

void main() {
  group('AudioConfig Default State & Presets Registry', () {
    test('Default configuration initializes with correct defaults', () {
      final config = AudioConfig();
      expect(config.enabled, isTrue);
      expect(config.preset, equals('Rock'));
      expect(config.preamp, equals(0.0));
      expect(config.eq.length, equals(10));
      expect(AudioConfig.freqs, equals([60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]));
      expect(AudioConfig.freqLabels, equals(['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K']));
    });

    test('Registry contains exactly 20 presets', () {
      expect(AudioConfig.presets.length, equals(20));
      expect(AudioConfig.presetPreamps.length, equals(20));
    });

    test('Every preset has exactly 10 bands', () {
      for (final entry in AudioConfig.presets.entries) {
        expect(entry.value.length, equals(10), reason: 'Preset ${entry.key} must have 10 bands');
      }
    });

    test('Unknown preset name is a safe no-op in applyPreset', () {
      final config = AudioConfig();
      final initialBands = List<double>.from(config.eq);
      config.applyPreset('NonExistentPresetXYZ');
      expect(config.preset, equals('Rock'));
      expect(config.eq, equals(initialBands));
    });
  });

  group('20 Presets Parity & Preamp Verification', () {
    // 11 Target VLC Presets
    test('Full Bass preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Full Bass');
      expect(config.preamp, equals(5.0));
      expect(config.eq, equals([-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]));
    });

    test('Full Bass & Treble preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Full Bass & Treble');
      expect(config.preamp, equals(4.0));
      expect(config.eq, equals([7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]));
    });

    test('Full Treble preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Full Treble');
      expect(config.preamp, equals(3.0));
      expect(config.eq, equals([-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]));
    });

    test('Headphones preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Headphones');
      expect(config.preamp, equals(4.0));
      expect(config.eq, equals([4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]));
    });

    test('Large Hall preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Large Hall');
      expect(config.preamp, equals(5.0));
      expect(config.eq, equals([10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0]));
    });

    test('Live preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Live');
      expect(config.preamp, equals(7.0));
      expect(config.eq, equals([-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]));
    });

    test('Party preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Party');
      expect(config.preamp, equals(6.0));
      expect(config.eq, equals([7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2]));
    });

    test('Reggae preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Reggae');
      expect(config.preamp, equals(8.0));
      expect(config.eq, equals([0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0]));
    });

    test('Ska preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Ska');
      expect(config.preamp, equals(6.0));
      expect(config.eq, equals([-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]));
    });

    test('Soft preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Soft');
      expect(config.preamp, equals(5.0));
      expect(config.eq, equals([4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0]));
    });

    test('Soft Rock preset matches authoritative VLC specification', () {
      final config = AudioConfig()..applyPreset('Soft Rock');
      expect(config.preamp, equals(7.0));
      expect(config.eq, equals([4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8]));
    });

    // Baseline 9 Presets Retention
    test('Baseline presets remain intact', () {
      final expectedBaseline = ['Flat', 'Rock', 'Pop', 'Jazz', 'Classical', 'Bass Boost', 'Vocal Boost', 'Techno', 'Club'];
      for (final p in expectedBaseline) {
        expect(AudioConfig.presets.containsKey(p), isTrue, reason: 'Preset $p must exist');
      }
    });
  });

  group('Pre-Amplification Filter String Generation', () {
    test('Positive preamp formats as volume=volume=+X.XdB:precision=fixed', () {
      final config = AudioConfig();
      config.preamp = 5.0;
      final af = config.buildMpvAfString();
      expect(af, contains('volume=volume=+5.0dB:precision=fixed'));
    });

    test('Negative preamp formats as volume=volume=-X.XdB:precision=fixed', () {
      final config = AudioConfig();
      config.preamp = -12.5;
      final af = config.buildMpvAfString();
      expect(af, contains('volume=volume=-12.5dB:precision=fixed'));
    });

    test('Preamp is omitted when exactly 0.0 dB (bit-perfect pass-through)', () {
      final config = AudioConfig();
      config.preamp = 0.0;
      final af = config.buildMpvAfString();
      expect(af.contains('volume='), isFalse);
    });

    test('Preamp deadzone: omitted when preamp.abs() <= 0.05', () {
      final config = AudioConfig();
      config.preamp = 0.04;
      expect(config.buildMpvAfString().contains('volume='), isFalse);

      config.preamp = -0.05;
      expect(config.buildMpvAfString().contains('volume='), isFalse);

      config.preamp = 0.06;
      expect(config.buildMpvAfString(), contains('volume=volume=+0.1dB:precision=fixed'));

      config.preamp = -0.06;
      expect(config.buildMpvAfString(), contains('volume=volume=-0.1dB:precision=fixed'));
    });

    test('Preamp is prepended before equalizer bands', () {
      final config = AudioConfig();
      config.preamp = 6.0;
      config.eq = [2.0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      final af = config.buildMpvAfString();
      expect(af.startsWith('volume=volume=+6.0dB:precision=fixed'), isTrue);
    });

    test('Preamp boundary extremes (+20.0dB and -20.0dB)', () {
      final config = AudioConfig();
      config.preamp = 20.0;
      expect(config.buildMpvAfString(), contains('volume=volume=+20.0dB:precision=fixed'));

      config.preamp = -20.0;
      expect(config.buildMpvAfString(), contains('volume=volume=-20.0dB:precision=fixed'));
    });
  });

  group('Equalizer Band Gain Scale & Filter Synthesis', () {
    test('Builds equalizer filter tokens for active bands', () {
      final config = AudioConfig();
      config.eq = [3.0, -4.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final af = config.buildMpvAfString();
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=3.0'));
      expect(af, contains('equalizer=f=170:width_type=q:width=1.2:g=-4.5'));
      expect(af.contains('equalizer=f=310'), isFalse);
    });

    test('Full ±20.0dB band headroom limits format correctly', () {
      final config = AudioConfig();
      config.eq[0] = 20.0;
      config.eq[9] = -20.0;
      final af = config.buildMpvAfString();
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=20.0'));
      expect(af, contains('equalizer=f=16000:width_type=q:width=1.2:g=-20.0'));
    });

    test('Neutral bands (|g| <= 0.05) are omitted', () {
      final config = AudioConfig();
      config.eq = [0.02, -0.04, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final af = config.buildMpvAfString();
      expect(af.contains('equalizer='), isFalse);
    });

    test('Reset restores Flat defaults and resets preamp to 0.0', () {
      final config = AudioConfig();
      config.applyPreset('Full Bass');
      expect(config.preamp, equals(5.0));

      final fakePlatform = FakePlayerPlatform();
      final player = FakePlayer(fakePlatform);

      config.reset(player);

      expect(config.preset, equals('Flat'));
      expect(config.preamp, equals(0.0));
      expect(config.eq.every((g) => g == 0.0), isTrue);
      expect(config.bassBoost, equals(0.0));
      expect(config.bassBoostEnabled, isFalse);
      expect(config.virtualizer, isFalse);
      expect(config.threeDAudio, isFalse);
      expect(config.nightMode, isFalse);
      expect(fakePlatform.properties['af'], equals(''));
    });
  });

  group('Player Platform Dispatch & Mock Verification', () {
    test('apply() sets af property on player.platform', () {
      final fakePlatform = FakePlayerPlatform();
      final player = FakePlayer(fakePlatform);
      final config = AudioConfig()..applyPreset('Full Bass');

      config.apply(player);

      expect(fakePlatform.properties['af'], isNotNull);
      expect(fakePlatform.properties['af'], equals(config.buildMpvAfString()));
    });

    test('apply() sets empty af string when enabled is false', () {
      final fakePlatform = FakePlayerPlatform();
      final player = FakePlayer(fakePlatform);
      final config = AudioConfig()
        ..applyPreset('Full Bass')
        ..enabled = false;

      config.apply(player);

      expect(fakePlatform.properties['af'], equals(''));
    });

    test('apply(null) safely no-ops without exception', () {
      final config = AudioConfig();
      expect(() => config.apply(null), returnsNormally);
    });

    test('apply() safely handles platform exceptions', () {
      final config = AudioConfig();
      // An object whose platform throws on setProperty
      final throwingPlayer = FakePlayer(Object());
      expect(() => config.apply(throwingPlayer), returnsNormally);
    });
  });
}
```

---

## 5. Verification Method

### 5.1 Verification Commands
Once Worker implements the changes in `lib/features/player/ui/audio_studio_sheet.dart` and authors `test/features/audio_studio_test.dart`:
```powershell
# 1. Run unit test suite
flutter test test/features/audio_studio_test.dart

# 2. Run static analysis across the entire project
dart analyze
```

### 5.2 Files to Inspect
- `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart`:
  - Check `AudioConfig.presets.length == 20`
  - Check `AudioConfig.presetPreamps`
  - Check `buildMpvAfString()` and preamp filter prepend
  - Check `_build10BandSlider` slider bounds: `min: -20.0, max: 20.0`
  - Check Preamp slider in `AudioStudioSheet`
- `d:\E-player\app\test\features\audio_studio_test.dart`:
  - Check that all test groups compile and execute cleanly with 0 failures

### 5.3 Invalidation Conditions
This test specification is invalidated if:
- Any band in the 11 VLC presets deviates from the extracted IEEE 754 float values from `libequalizer_plugin.dll`.
- Preamp volume filter uses a different syntax rejected by mpv's FFmpeg audio filter cascade.
- Unit tests fail to execute in headless environments due to missing native mpv binaries (prevented by `FakePlayerPlatform` / `FakePlayer`).
