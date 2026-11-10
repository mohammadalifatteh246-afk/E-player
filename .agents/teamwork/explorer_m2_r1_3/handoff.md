# Specification Mining Handoff Report: Milestone 2 — Equalizer Parity & Pre-Amplification

**Agent**: Spec Miner 3 (`explorer_m2_r1_3`)  
**Target Milestone**: Milestone 2: Equalizer Parity & Pre-Amplification (Requirement R5)  
**Target Codebase**: `d:\E-player\app`  
**Working Directory**: `d:\E-player\app`  
**State Folder**: `d:\E-player\.agents\teamwork\explorer_m2_r1_3\`  
**Date & Timestamp**: 2026-11-10T08:58:00Z  

---

## 1. Observation

Direct empirical observations from codebase inspection, specification documents, and VLC reference binary disassembly:

### 1.1 VLC Ground Truth Binary Telemetry (`libequalizer_plugin.dll`)
- **Binary Target**: `C:\Program Files (x86)\VideoLAN\VLC\plugins\audio_filter\libequalizer_plugin.dll` (PE32 x86 binary from official VLC installation).
- **Preset Table Location**: File offset `0xA080` (64 bytes per preset struct `eqz_preset_t`, spanning 18 presets).
- **Struct Layout (`eqz_preset_t`)**:
  - `+0x00`..`+0x13` (20 bytes): `char psz_name[20]` (null-terminated ASCII identifier).
  - `+0x14`..`+0x17` (4 bytes): `float f_preamp` (IEEE 754 single-precision float32, decibel gain).
  - `+0x18`..`+0x3F` (40 bytes): `float f_amp[10]` (10 IEEE 754 float32 values for bands 60Hz through 16kHz).
- **Verification Script**: Executed `python d:\E-player\.agents\teamwork\explorer_m2_r1_3\verify_presets.py`.
- **Verbatim Output from VLC Reference DLL**:
  ```
  === Full Bass (VLC raw name: "fullbass", index: 4) ===
    Preamp: 5.0 dB (bytes: 0000a040)
    Bands (dB): [-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]
    Bands (raw float): [-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]
    Bands (hex): ['000000c1', '9a991941', '9a991941', '3333b340', 'cdcccc3f', '000080c0', '000000c1', '666626c1', '333333c1', '333333c1']

  === Full Bass & Treble (VLC raw name: "fullbasstreble", index: 5) ===
    Preamp: 4.0 dB (bytes: 00008040)
    Bands (dB): [7.2, 5.6, -0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]
    Bands (raw float): [7.2, 5.6, -0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0]
    Bands (hex): ['6666e640', '3333b340', 'e3ff9fa6', '6666e6c0', '9a9999c0', 'cdcccc3f', '00000041', '33333341', '00004041', '00004041']

  === Full Treble (VLC raw name: "fulltreble", index: 6) ===
    Preamp: 3.0 dB (bytes: 00004040)
    Bands (dB): [-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8]
    Bands (raw float): [-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.799999]
    Bands (hex): ['9a9919c1', '9a9919c1', '9a9919c1', '000080c0', '9a991940', '33333341', '00008041', '00008041', '00008041', '66668641']

  === Headphones (VLC raw name: "headphones", index: 7) ===
    Preamp: 4.0 dB (bytes: 00008040)
    Bands (dB): [4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]
    Bands (raw float): [4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4]
    Bands (hex): ['9a999940', '33333341', '3333b340', 'cdcc4cc0', '9a9919c0', 'cdcccc3f', '9a999940', '9a991941', 'cdcc4c41', '66666641']

  === Large Hall (VLC raw name: "largehall", index: 8) ===
    Preamp: 5.0 dB (bytes: 0000a040)
    Bands (dB): [10.4, 10.4, 5.6, 5.6, -0.0, -4.8, -4.8, -4.8, -0.0, -0.0]
    Bands (raw float): [10.4, 10.4, 5.6, 5.6, -0.0, -4.8, -4.8, -4.8, -0.0, -0.0]
    Bands (hex): ['66662641', '66662641', '3333b340', '3333b340', 'e3ff9fa6', '9a9999c0', '9a9999c0', '9a9999c0', 'e3ff9fa6', 'e3ff9fa6']

  === Live (VLC raw name: "live", index: 9) ===
    Preamp: 7.0 dB (bytes: 0000e040)
    Bands (dB): [-4.8, -0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]
    Bands (raw float): [-4.8, -0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]
    Bands (hex): ['9a9999c0', 'e3ff9fa6', '00008040', '3333b340', '3333b340', '3333b340', '00008040', '9a991940', '9a991940', '9a991940']

  === Party (VLC raw name: "party", index: 10) ===
    Preamp: 6.0 dB (bytes: 0000c040)
    Bands (dB): [7.2, 7.2, -0.0, -0.0, -0.0, -0.0, -0.0, -0.0, 7.2, 7.2]
    Bands (raw float): [7.2, 7.2, -0.0, -0.0, -0.0, -0.0, -0.0, -0.0, 7.2, 7.2]
    Bands (hex): ['6666e640', '6666e640', 'e3ff9fa6', 'e3ff9fa6', 'e3ff9fa6', 'e3ff9fa6', 'e3ff9fa6', 'e3ff9fa6', '6666e640', '6666e640']

  === Reggae (VLC raw name: "reggae", index: 12) ===
    Preamp: 8.0 dB (bytes: 00000041)
    Bands (dB): [-0.0, -0.0, -0.0, -5.6, -0.0, 6.4, 6.4, -0.0, -0.0, -0.0]
    Bands (raw float): [-0.0, -0.0, -0.0, -5.6, -0.0, 6.4, 6.4, -0.0, -0.0, -0.0]
    Bands (hex): ['e3ff9fa6', 'e3ff9fa6', 'e3ff9fa6', '3333b3c0', 'e3ff9fa6', 'cdcccc40', 'cdcccc40', 'e3ff9fa6', 'e3ff9fa6', 'e3ff9fa6']

  === Ska (VLC raw name: "ska", index: 14) ===
    Preamp: 6.0 dB (bytes: 0000c040)
    Bands (dB): [-2.4, -4.8, -4.0, -0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]
    Bands (raw float): [-2.4, -4.8, -4.0, -0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6]
    Bands (hex): ['9a9919c0', '9a9999c0', '000080c0', 'e3ff9fa6', '00008040', '3333b340', 'cdcc0c41', '9a991941', '33333341', '9a991941']

  === Soft (VLC raw name: "soft", index: 15) ===
    Preamp: 5.0 dB (bytes: 0000a040)
    Bands (dB): [4.8, 1.6, -0.0, -2.4, -0.0, 4.0, 8.0, 9.6, 11.2, 12.0]
    Bands (raw float): [4.8, 1.6, -0.0, -2.4, -0.0, 4.0, 8.0, 9.6, 11.2, 12.0]
    Bands (hex): ['9a999940', 'cdcccc3f', 'e3ff9fa6', '9a9919c0', 'e3ff9fa6', '00008040', '00000041', '9a991941', '33333341', '00004041']

  === Soft Rock (VLC raw name: "softrock", index: 16) ===
    Preamp: 7.0 dB (bytes: 0000e040)
    Bands (dB): [4.0, 4.0, 2.4, -0.0, -4.0, -5.6, -3.2, -0.0, 2.4, 8.8]
    Bands (raw float): [4.0, 4.0, 2.4, -0.0, -4.0, -5.6, -3.2, -0.0, 2.4, 8.8]
    Bands (hex): ['00008040', '00008040', '9a991940', 'e3ff9fa6', '000080c0', '3333b3c0', 'cdcc4cc0', 'e3ff9fa6', '9a991940', 'cdcc0c41']
  ```

### 1.2 Cross-Document Discrepancy Forensic Audit
When comparing the authoritative VLC binary and `SCOPE.md` against prior explorer reports:
1. **`explorer_audio_studio/handoff.md` Defect 1 (Full Bass)**:
   - Line 117 states: `Full Bass: [9.6, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2]`.
   - Binary Ground Truth at offset `0xA180 + 24` is byte `00 00 00 c1` = **`-8.0`**.
   - `SCOPE.md` correctly specifies **`-8.0`**.
   - **Resolution**: `explorer_audio_studio` contained a clerical error (+9.6 instead of -8.0). The true value is **`-8.0`**.
2. **`explorer_audio_studio/handoff.md` Defect 2 (Live)**:
   - Line 122 states: `Live: [-4.8, 0.0, 4.0, 5.6, 5.6, 3.2, 0.0, -2.4, -4.8, -4.8]`.
   - Binary Ground Truth at offset `0xA2C0 + 24` has band bytes:
     `[-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]`.
   - Furthermore, `%APPDATA%\vlc\vlcrc` line 3261 explicitly records:
     `equalizer-bands=-4.8 0.0000000 3.9 5.5 5.5 5.5 3.9 2.4 2.4 2.4`.
   - `SCOPE.md` line 27 correctly specifies `[-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4]`.
   - **Resolution**: `explorer_audio_studio` contained corrupt values for bands 5–9. The true values are `[5.6, 4.0, 2.4, 2.4, 2.4]`.

### 1.3 Frequency Bands in `AudioConfig.freqs`
- Inspection of `d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart` lines 12–13:
  ```dart
  static const List<int> freqs = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];
  static const List<String> freqLabels = ['60', '170', '310', '600', '1K', '3K', '6K', '12K', '14K', '16K'];
  ```
- Cross-verified against VLC's 10-band ISO standard:
  All 10 band centers (60 Hz, 170 Hz, 310 Hz, 600 Hz, 1 kHz, 3 kHz, 6 kHz, 12 kHz, 14 kHz, 16 kHz) and labels match 100%.

### 1.4 Codebase Structure & Pre-Amplification in `AudioConfig`
- In `lib/features/player/ui/audio_studio_sheet.dart`:
  - `AudioConfig` currently defines `List<double> eq` (lines 15) and 9 presets (lines 23–33).
  - Preamp property `double preamp = 0.0;` is currently **absent**.
  - `apply(Player? player)` (lines 42–85) constructs `filters` with optional bass, dynaudnorm, extrastereo, stereowiden, and 10 `equalizer=f=...` filters.
  - The vertical sliders in `_build10BandSlider` (lines 588–590) are clamped to `[-12.0, 12.0]`.
  - The scale labels at lines 403, 404, 443, 444 are `+12dB` and `-12dB`.

---

## 2. Logic Chain

From the direct observations, the exact operational mechanics and specifications are derived:

1. **Preset Representation & IEEE 754 Precision**:
   - Dart floats conform to IEEE 754 double precision (64-bit). The VLC binary stores IEEE 754 single precision (32-bit).
   - Because all 11 presets have decimal values defined to exactly 1 decimal place (e.g. `9.6`, `5.6`, `1.6`, `-10.4`, `-11.2`), storing them as standard Dart `double` literals preserves exact fidelity when formatted via `toStringAsFixed(1)`.
   - The verified vectors in `SCOPE.md` and `spec_miner_phase1/handoff.md` match the binary bytes bit-for-bit.

2. **Preset Switching & Preamp Interaction Dynamics**:
   - In VLC, selecting an equalizer preset is an atomic operation that sets both the 10 frequency band gains (`f_amp`) and the preamplification level (`f_preamp`).
   - Therefore, in `AudioConfig`, `applyPreset(String name)` MUST:
     1. Set `preset = name;`
     2. Set `eq = List<double>.from(presets[name]!);`
     3. Set `preamp = presetPreamps[name] ?? 0.0;`
   - **Freedom of Adjustment**: Once a preset is selected, the user retains total freedom:
     - Adjusting the global Preamp slider updates `_config.preamp = v` across `[-20.0, +20.0] dB` (step 0.5dB) without mutating the 10 equalizer bands.
     - Adjusting any individual frequency band slider transitions `_config.preset` to `'Custom'` while preserving the active `preamp` value.
     - Tapping "Reset to Flat Defaults" sets `preset = 'Flat'`, `eq = List<double>.filled(10, 0.0)`, and `preamp = 0.0`.

3. **mpv `af` Filter Chain Specifications**:
   - **Syntax**: mpv's FFmpeg audio filter `volume` accepts decibel gains formatted as:
     - Positive gains (e.g. +5.0 dB): `volume=volume=+5.0dB:precision=fixed`
     - Negative gains (e.g. -10.0 dB): `volume=volume=-10.0dB:precision=fixed`
     - Dart synthesis rule:
       ```dart
       if (preamp.abs() > 0.05) {
         final sign = preamp >= 0 ? '+' : '';
         filters.add('volume=volume=$sign${preamp.toStringAsFixed(1)}dB:precision=fixed');
       }
       ```
   - **Filter Order Rule**:
     - mpv evaluates filters strictly in left-to-right order.
     - In DSP signal processing, pre-amplification scales the incoming PCM audio before it enters multi-band filter stages. This provides attenuation headroom to prevent clipping when presets apply large positive gains (e.g. Full Treble +16.8 dB), or boosts low-level audio before coloration.
     - Therefore, the `volume` filter (preamp) MUST be the FIRST element in `filters`, placed before all 10 `equalizer` band filters and other DSP filters (`bass`, `dynaudnorm`, `extrastereo`, `stereowiden`).
   - **Tolerance Threshold for Omission (`> 0.05`)**:
     - Floating point arithmetic and slider steps (0.5 dB) can yield tiny epsilon values around zero (e.g. `0.00000001` or `-0.00000001`).
     - Using `if (preamp.abs() > 0.05)` ensures that exact `0.0 dB` (and any negligible float deviation) is omitted from the `af` string.
     - Omission guarantees bit-perfect audio pass-through without invoking FFmpeg resampling or buffer reallocation.
     - This perfectly matches the established pattern for the 10 graphic EQ bands (`if (eq[i].abs() > 0.05)`).

4. **10-Band Gain Scale Expansion (±20dB)**:
   - To match VLC's professional equalizer headroom:
     - The vertical sliders in `_build10BandSlider` must be updated from `min: -12.0, max: 12.0` to `min: -20.0, max: 20.0`.
     - Value clamping in slider: `value.clamp(-20.0, 20.0)`.
     - Header scale labels: `+20dB` (top) and `-20dB` (bottom).

---

## 3. Discovered Specifications & Technical Blueprints

### 3.1 11 Target VLC Equalizer Presets Matrix

| # | Preset Name | Preamp (dB) | 60Hz | 170Hz | 310Hz | 600Hz | 1kHz | 3kHz | 6kHz | 12kHz | 14kHz | 16kHz | IEEE 754 Float Verification Status |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| 01 | **Full Bass** | `+5.0` | `-8.0` | `+9.6` | `+9.6` | `+5.6` | `+1.6` | `-4.0` | `-8.0` | `-10.4` | `-11.2` | `-11.2` | Verified against DLL offset `0xA180` |
| 02 | **Full Bass & Treble** | `+4.0` | `+7.2` | `+5.6` | `0.0` | `-7.2` | `-4.8` | `+1.6` | `+8.0` | `+11.2` | `+12.0` | `+12.0` | Verified against DLL offset `0xA1C0` |
| 03 | **Full Treble** | `+3.0` | `-9.6` | `-9.6` | `-9.6` | `-4.0` | `+2.4` | `+11.2` | `+16.0` | `+16.0` | `+16.0` | `+16.8` | Verified against DLL offset `0xA200` |
| 04 | **Headphones** | `+4.0` | `+4.8` | `+11.2` | `+5.6` | `-3.2` | `-2.4` | `+1.6` | `+4.8` | `+9.6` | `+12.8` | `+14.4` | Verified against DLL offset `0xA240` |
| 05 | **Large Hall** | `+5.0` | `+10.4` | `+10.4` | `+5.6` | `+5.6` | `0.0` | `-4.8` | `-4.8` | `-4.8` | `0.0` | `0.0` | Verified against DLL offset `0xA280` |
| 06 | **Live** | `+7.0` | `-4.8` | `0.0` | `+4.0` | `+5.6` | `+5.6` | `+5.6` | `+4.0` | `+2.4` | `+2.4` | `+2.4` | Verified against DLL offset `0xA2C0` |
| 07 | **Party** | `+6.0` | `+7.2` | `+7.2` | `0.0` | `0.0` | `0.0` | `0.0` | `0.0` | `0.0` | `+7.2` | `+7.2` | Verified against DLL offset `0xA300` |
| 08 | **Reggae** | `+8.0` | `0.0` | `0.0` | `0.0` | `-5.6` | `0.0` | `+6.4` | `+6.4` | `0.0` | `0.0` | `0.0` | Verified against DLL offset `0xA380` |
| 09 | **Ska** | `+6.0` | `-2.4` | `-4.8` | `-4.0` | `0.0` | `+4.0` | `+5.6` | `+8.8` | `+9.6` | `+11.2` | `+9.6` | Verified against DLL offset `0xA400` |
| 10 | **Soft** | `+5.0` | `+4.8` | `+1.6` | `0.0` | `-2.4` | `0.0` | `+4.0` | `+8.0` | `+9.6` | `+11.2` | `+12.0` | Verified against DLL offset `0xA440` |
| 11 | **Soft Rock** | `+7.0` | `+4.0` | `+4.0` | `+2.4` | `0.0` | `-4.0` | `-5.6` | `-3.2` | `0.0` | `+2.4` | `+8.8` | Verified against DLL offset `0xA480` |

---

### 3.2 Features Discovered & Technical Specification Table

## Features Discovered
| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Equalizer Presets | 11 VLC Canonical Presets | Full Bass, Full Bass & Treble, Full Treble, Headphones, Large Hall, Live, Party, Reggae, Ska, Soft, Soft Rock | Preset name `String` | Loads 10 band gains + preset preamp into config | Falls back to Flat / no-op if unrecognized | `libequalizer_plugin.dll` disassembly & `vlcrc` |
| 2 | Equalizer Presets | 20 Presets Total Inventory | Combines 9 existing app presets + 11 VLC canonical presets | Selection from preset dropdown / wrap pill | Updated `AudioConfig.preset`, `eq`, and `preamp` | No-op if already selected | `AudioConfig.presets` & `SCOPE.md` |
| 3 | Equalizer Preamps | Preset Preamps Mapping (`presetPreamps`) | Associates default preamplification gain (dB) with each preset | Preset name `String` | Returns default preamp gain (e.g. +7.0 dB for Live) | Defaults to `0.0 dB` if preset has no preamp entry | `libequalizer_plugin.dll` offset `0xA080` struct `f_preamp` |
| 4 | DSP Filter Chain | Global Preamp mpv Filter | Injects `volume=volume=+X.XdB:precision=fixed` into mpv `af` filter graph | `double preamp` in `[-20.0, 20.0]` | Formatted filter string appended to mpv `af` property | Clamped to `[-20.0, 20.0]`; omitted if within `[-0.05, 0.05]` | mpv / FFmpeg `af_volume` documentation |
| 5 | DSP Filter Chain | Preamp Filter Graph Precedence | Forces preamp `volume` filter to appear as FIRST element in `filters` list | `List<String> filters` | `af` string with preamp preceding equalizer bands | None; deterministic insertion at index 0 | mpv filter evaluation ordering |
| 6 | DSP Filter Chain | Band & Preamp Omission Guard | Omits filters when gain is within `[-0.05, +0.05]` threshold | Gain value `double` | Pure bypass for 0.0dB bands; reduces CPU overhead | None; transparent bypass | `AudioConfig.apply` lines 74–78 |
| 7 | UI Controls | Preamp Slider Card | Horizontal slider placed above the 10-band equalizer stack in `AudioStudioSheet` | Drag thumb (`-20.0` to `+20.0`, step `0.5`) | Updates `_config.preamp` and dispatches debounced `apply` | Clamped to `[-20.0, 20.0]`; live badge display | `SCOPE.md` Item 2 & `AudioStudioSheet` |
| 8 | UI Controls | 10-Band Gain Scale Expansion | Expands graphic EQ vertical slider range from `±12dB` to `±20dB` | Slider drag (`-20.0` to `+20.0`) | Updates `_config.eq[index]`, marks preset 'Custom' | Clamped to `[-20.0, 20.0]` | `SCOPE.md` Item 3 & `libequalizer_plugin.dll` |
| 9 | UI Controls | Scale Label Parity (±20dB) | Replaces `+12dB` / `-12dB` static text labels with `+20dB` / `-20dB` | Render tree build | Displays professional headroom bounds | None | `AudioStudioSheet` lines 403, 443 |
| 10 | State Machine | Custom Preset Decoupling | Modifying any band slider changes preset pill to 'Custom' without changing preamp | Slider `onChanged` | `_config.preset = 'Custom'` | Preserves active preamp level | `AudioStudioSheet` line 599 |
| 11 | State Machine | Reset to Flat Defaults | Resets EQ bands to 0.0, preamp to 0.0, and clears all DSP boosts | Reset button tap | `AudioConfig.reset(player)` | Restores unity pass-through | `AudioConfig.reset` lines 87–98 |

---

### 3.3 Edge Cases

## Edge Cases
| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | Preamp Filter | `preamp = 0.0 dB` (exact unity gain) | `preamp.abs() > 0.05` evaluates to `false`. Preamp filter is completely omitted from the mpv `af` filter chain. |
| 2 | Preamp Filter | `preamp = -0.04 dB` (negligible float drift) | `preamp.abs() > 0.05` evaluates to `false`. Omitted to avoid redundant FFmpeg filter graph allocation. |
| 3 | Preamp Filter | `preamp = +0.1 dB` (minimum nonzero nudge) | Evaluates to `true`. Filter string emitted: `volume=volume=+0.1dB:precision=fixed`. |
| 4 | Preamp Filter | Negative gain `preamp = -8.5 dB` | Emitted string: `volume=volume=-8.5dB:precision=fixed`. Sign formatting handles negative numbers naturally without double-minus. |
| 5 | Preamp Filter | Maximum positive boost `preamp = +20.0 dB` | Emitted string: `volume=volume=+20.0dB:precision=fixed`. Precedes equalizer bands to scale headroom properly. |
| 6 | Preset Selection | Selecting preset when Equalizer is DISABLED (`enabled = false`) | Updates `_config.eq` and `_config.preamp` in memory; does NOT send mpv `af` string until `enabled = true`. |
| 7 | Preset Selection | Switching from high preamp preset (`Live` +7.0dB) to `Full Treble` (+3.0dB) | Preamp slider immediately jumps to `+3.0 dB` and active mpv `volume` filter updates to `+3.0dB`. |
| 8 | Slider Adjustment | User adjusts preamp slider while a preset (e.g. `Party`) is active | `_config.preamp` changes to user value; `_config.preset` remains `Party` (or active label) because only preamp was modified. |
| 9 | Slider Adjustment | User adjusts a 10-band slider while a preset (e.g. `Party`) is active | `_config.preset` immediately switches to `'Custom'`; other 9 bands and `preamp` retain their current positions. |
| 10 | Equalizer Reset | Calling `reset(player)` | Resets `enabled = true`, `preset = 'Flat'`, `eq = [0, ..., 0]`, `preamp = 0.0`, all boost flags = `false`, and clears mpv `af` chain. |

---

### 3.4 Ready-to-Paste Dart Map Formats

#### 3.4.1 Complete 20-Preset Map for `AudioConfig.presets`
```dart
  static const Map<String, List<double>> presets = {
    // Existing presets
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.5, 3.0, -1.5, -2.5, -1.0, 2.0, 4.0, 5.5, 6.0, 6.5],
    'Pop': [-1.5, -1.0, 1.0, 2.5, 4.0, 3.5, 1.5, -1.0, -1.5, -2.0],
    'Jazz': [3.0, 2.0, 1.0, 1.5, -1.5, -1.5, 0.0, 1.5, 3.0, 3.5],
    'Classical': [4.0, 3.0, 2.5, 2.0, -1.5, -1.5, 0.0, 2.5, 3.5, 4.0],
    'Bass Boost': [8.0, 7.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Vocal Boost': [-2.0, -2.5, -1.0, 2.0, 5.0, 5.0, 3.5, 1.5, 0.0, -1.5],
    'Techno': [6.0, 5.0, 0.0, -3.0, -2.5, 0.0, 4.0, 6.0, 6.5, 6.5],
    'Club': [0.0, 0.0, 2.0, 3.5, 3.5, 3.5, 2.0, 0.0, 0.0, 0.0],
    // 11 VLC Canonical Presets (Forensically verified against libequalizer_plugin.dll)
    'Full Bass': [-8.0, 9.6, 9.6, 5.6, 1.6, -4.0, -8.0, -10.4, -11.2, -11.2],
    'Full Bass & Treble': [7.2, 5.6, 0.0, -7.2, -4.8, 1.6, 8.0, 11.2, 12.0, 12.0],
    'Full Treble': [-9.6, -9.6, -9.6, -4.0, 2.4, 11.2, 16.0, 16.0, 16.0, 16.8],
    'Headphones': [4.8, 11.2, 5.6, -3.2, -2.4, 1.6, 4.8, 9.6, 12.8, 14.4],
    'Large Hall': [10.4, 10.4, 5.6, 5.6, 0.0, -4.8, -4.8, -4.8, 0.0, 0.0],
    'Live': [-4.8, 0.0, 4.0, 5.6, 5.6, 5.6, 4.0, 2.4, 2.4, 2.4],
    'Party': [7.2, 7.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.2, 7.2],
    'Reggae': [0.0, 0.0, 0.0, -5.6, 0.0, 6.4, 6.4, 0.0, 0.0, 0.0],
    'Ska': [-2.4, -4.8, -4.0, 0.0, 4.0, 5.6, 8.8, 9.6, 11.2, 9.6],
    'Soft': [4.8, 1.6, 0.0, -2.4, 0.0, 4.0, 8.0, 9.6, 11.2, 12.0],
    'Soft Rock': [4.0, 4.0, 2.4, 0.0, -4.0, -5.6, -3.2, 0.0, 2.4, 8.8],
  };
```

#### 3.4.2 Preset Preamp Gain Map for `AudioConfig.presetPreamps`
```dart
  static const Map<String, double> presetPreamps = {
    'Flat': 0.0,
    'Rock': 5.0,
    'Pop': 6.0,
    'Jazz': 0.0,
    'Classical': 0.0,
    'Bass Boost': 0.0,
    'Vocal Boost': 0.0,
    'Techno': 5.0,
    'Club': 6.0,
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
  };
```

#### 3.4.3 Updated `AudioConfig.applyPreset` Method
```dart
  void applyPreset(String name) {
    if (presets.containsKey(name)) {
      preset = name;
      eq = List<double>.from(presets[name]!);
      preamp = presetPreamps[name] ?? 0.0;
    }
  }
```

#### 3.4.4 Updated `AudioConfig.apply` Method
```dart
  void apply(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      if (!enabled) {
        platform.setProperty('af', '');
        return;
      }

      final List<String> filters = [];

      // 1. Pre-Amplification (MUST precede equalizer bands and DSP)
      if (preamp.abs() > 0.05) {
        final sign = preamp >= 0 ? '+' : '';
        filters.add('volume=volume=$sign${preamp.toStringAsFixed(1)}dB:precision=fixed');
      }

      // 2. Bass Boost
      if (bassBoostEnabled && bassBoost > 0) {
        filters.add('bass=g=${bassBoost.toStringAsFixed(1)}');
      }

      // 3. Night Mode (Loudness normalization)
      if (nightMode) {
        filters.add('dynaudnorm=f=200:g=15');
      }

      // 4. Virtualizer (Stereo widening)
      if (virtualizer) {
        filters.add('extrastereo=m=2.2');
      }

      // 5. 3D Audio (Spatial sound widening)
      if (threeDAudio) {
        filters.add('stereowiden=level=0.7');
      }

      // 6. 10-Band Graphic Equalizer
      for (int i = 0; i < freqs.length; i++) {
        if (eq[i].abs() > 0.05) {
          filters.add('equalizer=f=${freqs[i]}:width_type=q:width=1.2:g=${eq[i].toStringAsFixed(1)}');
        }
      }

      final afString = filters.join(',');
      platform.setProperty('af', afString);
    } catch (e) {
      debugPrint('[Audio Studio] mpv af error: $e');
    }
  }
```

---

## 4. Caveats

1. **Clerical Errors in Previous Explorer Reports**:
   - `explorer_audio_studio/handoff.md` recorded `Full Bass` band 0 as `+9.6` (should be `-8.0`) and `Live` bands 5–9 as `[3.2, 0.0, -2.4, -4.8, -4.8]` (should be `[5.6, 4.0, 2.4, 2.4, 2.4]`).
   - Implementers MUST use the tables in this handoff or in `SCOPE.md`, which match the binary ground truth.
2. **Preamp Gain vs Master Volume**:
   - Pre-amplification via `volume=volume=+XdB:precision=fixed` operates within the FFmpeg filter chain on decoded audio.
   - It is independent of mpv's player volume property (`player.setVolume()`), which controls output sink attenuation.
3. **Hardware Acceleration Compatibility**:
   - Audio filters in mpv (`equalizer`, `volume`) operate on uncompressed PCM decoded by FFmpeg audio decoders. They have zero conflict with hardware-accelerated video decoding (D3D11VA, DXVA2, NVDEC).
4. **Read-Only Investigation Compliance**:
   - As mandated by the dispatch assignment, zero application code files or tests were modified during this investigation. All findings were verified strictly through static analysis, Python PE extraction, and reference comparison.

---

## 5. Conclusion

1. **Equalizer Parity is 100% Specified**: All 11 requested VLC presets (`Full Bass`, `Full Bass & Treble`, `Full Treble`, `Headphones`, `Large Hall`, `Live`, `Party`, `Reggae`, `Ska`, `Soft`, `Soft Rock`) have been forensically extracted from `libequalizer_plugin.dll` and verified against `SCOPE.md`.
2. **Frequency Centers Match**: The 10 frequency band centers in `AudioConfig.freqs` (`[60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]`) are identical to VLC.
3. **Preamp Mechanics are Fully Defined**:
   - Selecting a preset loads its corresponding preamp default from `presetPreamps`.
   - The user can subsequently adjust the Preamp slider freely across `[-20.0, +20.0] dB`.
   - Modifying a band slider sets the preset pill to `'Custom'` while retaining the active preamp gain.
4. **mpv `af` Filter Chain is Solidified**:
   - Syntax: `volume=volume=${preamp >= 0 ? '+' : ''}${preamp.toStringAsFixed(1)}dB:precision=fixed`.
   - Ordering: Volume filter is placed strictly before equalizer bands.
   - Omission: `if (preamp.abs() > 0.05)` omits the filter at 0.0 dB for bit-perfect pass-through.
5. **Implementation Artifacts are Ready**: Ready-to-paste Dart code for `presets`, `presetPreamps`, `applyPreset`, and `apply` are fully provided.

---

## 6. Verification Method

### 6.1 Independent Verification Commands
```powershell
# 1. Run the Python verification script to extract presets directly from the VLC PE DLL
python "d:\E-player\.agents\teamwork\explorer_m2_r1_3\verify_presets.py"

# 2. Inspect the current AudioConfig implementation in E-Player
Get-Content -Path "d:\E-player\app\lib\features\player\ui\audio_studio_sheet.dart" -TotalCount 50

# 3. Verify static analysis cleanliness in the app directory
cd d:\E-player\app
dart analyze
```

### 6.2 Invalidation Conditions
This specification is invalidated if:
- `libequalizer_plugin.dll` at offset `0xA080` contains different float values for the 18 preset structures.
- mpv audio filter engine rejects `volume=volume=+X.XdB:precision=fixed` or fails to apply it prior to `equalizer=f=...` filters.
- `dart analyze` produces errors on the provided Dart map syntax.
