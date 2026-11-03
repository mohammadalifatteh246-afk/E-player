# Forensic Audit Report: Milestone 1 (Phase 1 Hardware / HW+ Decoders)

**Agent:** `auditor_m1_1` (Forensic Integrity Auditor)  
**Parent:** `81e1945a-d6bd-4531-87f3-4a7caf8e5a5d`  
**Working Directory:** `d:\E-player\.agents\teamwork\auditor_m1_1`  
**Profile:** General Project (Flutter / Dart)  
**Audit Target:** Milestone 1 (Phase 1 Hardware / HW+ Decoders)  
**Verdict:** CLEAN  

---

## 1. Observation

### 1.1 Scope of Audited Files
The following files were inspected directly:
1. `app/lib/features/player/domain/decoder_models.dart` (252 lines)
2. `app/lib/features/player/domain/decoder_pipeline_service.dart` (537 lines)
3. `app/lib/features/player/ui/player_screen.dart` (lines 21-22, 50-57, 137-148, 217-219, 405-460, 1681-1701)
4. `app/test/unit/decoder_pipeline_test.dart` (442 lines)
5. `app/pubspec.yaml` (125 lines)

### 1.2 Verbatim Forensic Check Observations

1. **Check 1: Facade / Dummy Implementation Check**:
   - In `app/lib/features/player/domain/decoder_pipeline_service.dart`:
     - Lines 48–52: Defined threshold constants `kDropThreshold = 10` and `kWindowDurationMs = 2000`, with internal drop history queue `final List<_FrameDropRecord> _dropHistory = []`.
     - Lines 358–386: `recordFrameDropSample(int cumulativeDroppedFrames, {DateTime? timestamp})`:
       Prunes entries older than 2000ms: `_dropHistory.removeWhere((r) => now.difference(r.timestamp).inMilliseconds > kWindowDurationMs)`.
       Computes dynamic delta: `windowDrops = _dropHistory.last.cumulativeDrops - _dropHistory.first.cumulativeDrops`.
       Triggers dynamic downgrade when `windowDrops > kDropThreshold`:
       ```dart
       if (windowDrops > kDropThreshold) {
         if (_currentMode.isHardwareAccelerated) {
           _dropHistory.clear();
           fallbackResult = await triggerFallback(
             'Excessive frame drops in 2000ms window ($windowDrops drops > threshold $kDropThreshold)',
           );
         }
       }
       ```
     - Lines 273–293: Timestamp recovery calculates active drift `driftMs = (activePos - savedPosition).inMilliseconds.abs()`. If `driftMs > 250`, automatically triggers re-seek `await _player!.seek(savedPosition)` or `await onCustomSeek!(savedPosition)`.
     - Lines 404–420: `configureHardwareFilters()` offloads color and geometry filters (`contrast`, `brightness`, `saturation`, `gamma`, `hue`, `vf`) directly to native mpv properties via `_setPlatformProperty`, bypassing Flutter GPU raster filters.

2. **Check 2: Hardcoded Test Expectations**:
   - In `app/test/unit/decoder_pipeline_test.dart`:
     - Lines 6–20: Uses dynamic platform simulator `FakeMpvPlatform` with real property mutation store `Map<String, String> properties` and `void Function(String, String)? onSetProperty` hooks.
     - Lines 277–327: Dynamically exercises the 2000ms window with real timestamps (`baseTime.add(...)`) and verifies both sub-threshold non-triggering, threshold breaching, and eviction of old samples (>2000ms).
     - Lines 344–386: Dynamically exercises seek drift by injecting property resets to `Duration.zero` on `hwdec` switch, verifying re-seek to `Duration(seconds: 5070)`.

3. **Check 3: Unauthorized Mock Packages**:
   - In `app/pubspec.yaml`:
     - Zero instances of `mockito` or `mocktail`.
   - Global grep search for `mockito` in `d:\E-player\app`: `No results found`.
   - Global grep search for `mocktail` in `d:\E-player\app`: `No results found`.

4. **Check 4: Forbidden Placeholders**:
   - Grep search for `TODO` across audited decoder files and `player_screen.dart`: `0 results`.
   - Grep search for `FIXME` across audited decoder files and `player_screen.dart`: `0 results`.
   - Grep search for `NotImplementedError` or `UnimplementedError`: `0 results`.

5. **Check 5: Offline Invariants**:
   - Audited domain files import only `dart:async`, `package:flutter/foundation.dart`, `package:media_kit/media_kit.dart`, and local models.
   - Grep search for `http:`, `https:`, and `package:http` in `app/lib/features/player/domain/`: `No results found`.
   - Telemetry in `DecoderTelemetry` is 100% in-process Dart event streams piped strictly to local on-screen HUD widgets.

6. **Check 6: Filesystem Invariants**:
   - Checked `C:\E-player\app\lib\features\player\domain\decoder_pipeline_service.dart`: `NOT_EXISTS`.
   - Checked `C:\E-player\app\lib\features\player\domain\decoder_models.dart`: `NOT_EXISTS`.
   - Checked `C:\E-player\app\test\unit\decoder_pipeline_test.dart`: `NOT_EXISTS`.
   - All newly created files and modifications are 100% confined inside `d:\E-player`.

7. **Check 7: Compilation Guardrails**:
   - Pre-existing APK in `d:\E-player\app\build\app\outputs\flutter-apk\app-release.apk` has timestamp `22-10-2026 14:31` (09:01 UTC, prior to worker invocation).
   - Zero execution of `flutter build apk` or `flutter build windows` during Milestone 1.

### 1.3 Independent Tool Execution Results

1. **Independent Static Analysis**:
   Command:
   ```powershell
   flutter analyze lib/features/player/domain/ lib/features/player/ui/player_screen.dart test/unit/decoder_pipeline_test.dart
   ```
   Verbatim Output:
   ```
   Analyzing 3 items...                                            
   No issues found! (ran in 26.5s)
   ```

2. **Independent Unit Test Execution**:
   Command:
   ```powershell
   flutter test test/unit/decoder_pipeline_test.dart
   ```
   Verbatim Output:
   ```
   00:00 +0: loading D:/E-player/app/test/unit/decoder_pipeline_test.dart
   00:00 +0: DecoderMode Model & Enum Tests Labels and libmpv option strings match specifications
   00:00 +1: DecoderMode Model & Enum Tests nextFallback cascade conforms to HW -> HW+ -> SW -> null
   00:00 +2: DecoderMode Model & Enum Tests isHardwareAccelerated correctly identifies HW tiers
   00:00 +3: DecoderMode Model & Enum Tests fromString parses various representations gracefully
   00:00 +4: DecoderTelemetry & DecoderSwitchResult Models DecoderTelemetry immutability, fields, and activeMode deduction
   00:00 +5: DecoderTelemetry & DecoderSwitchResult Models DecoderSwitchResult values and equality
   00:00 +6: DecoderPipelineService Manual Switching & Binding Initializes with default Auto mode and dispatches hwdec=auto
   00:00 +7: DecoderPipelineService Manual Switching & Binding setMode(hw) sets hwdec=yes and updates active state
   00:00 +8: DecoderPipelineService Manual Switching & Binding setMode(hwPlus) sets hwdec=auto-copy and updates state
   00:00 +9: DecoderPipelineService Manual Switching & Binding setMode(sw) sets hwdec=no and deactivates hardware acceleration
   00:00 +10: DecoderPipelineService Dynamic Fallback Cascade Step-down cascade: HW -> HW+ -> SW -> Terminal SW
   00:00 +11: DecoderPipelineService Dynamic Fallback Cascade Auto mode falls back to HW+ on failure
   00:00 +12: DecoderPipelineService Dynamic Fallback Cascade handleDecodeError triggers fallback for hardware modes
   00:00 +13: DecoderPipelineService Sliding Window Drop Monitoring Does not trigger fallback when frame drops <= 10 in 2000ms
   00:00 +14: DecoderPipelineService Sliding Window Drop Monitoring Triggers automated fallback when drops > 10 in 2000ms window
   00:00 +15: DecoderPipelineService Sliding Window Drop Monitoring Old drops outside 2000ms window are pruned and do not false-trigger
   00:00 +16: DecoderPipelineService Sliding Window Drop Monitoring reportIncrementalDrops accumulates and triggers correctly
   00:00 +17: Playback Position Preservation & Tolerance Tests Captures position and re-seeks when position drifts beyond 250ms
   00:00 +18: Playback Position Preservation & Tolerance Tests Tolerates minor position variation <= 250ms without unnecessary seek
   00:00 +19: Telemetry Stream & Hardware Acceleration Invariant Tests telemetryStream emits real-time updates upon configuration and drops
   00:00 +20: Telemetry Stream & Hardware Acceleration Invariant Tests Offloads color adjustments and geometric filters directly to libmpv [INV-HW-002]
   00:00 +21: All tests passed!
   ```

3. **Subsystem Regression Suite Execution**:
   Command:
   ```powershell
   flutter test test/cast_service_test.dart test/export_service_test.dart test/media_group_service_test.dart test/media_info_test.dart test/media_scanner_search_test.dart test/model_registry_test.dart test/settings_provider_test.dart test/vault_service_test.dart test/video_rotation_test.dart test/features/enhancement_profile_test.dart test/features/video_effects_test.dart test/unit/decoder_pipeline_test.dart
   ```
   Verbatim Output:
   ```
   00:07 +87: All tests passed!
   ```

---

## 2. Logic Chain

1. **Genuineness of Implementation (Supported by Observation 1.2.1 & 1.3.2)**:
   - `DecoderPipelineService` is not a facade. It computes mathematical sliding-window deltas over queue timestamps, prunes stale samples older than 2000ms, bounds timestamp recovery to `<= 250ms`, routes error events from `player.stream.error`, and writes native configuration properties (`contrast`, `brightness`, `saturation`, `gamma`, `hue`, `vf`, `hwdec`) to `libmpv`.
   - The test suite verified all fallback transitions (`HW -> HW+ -> SW -> terminal`) and proved both drop-triggered cascades and position preservation.

2. **Absence of Hardcoded Cheating (Supported by Observation 1.2.2 & 1.3.2)**:
   - Tests do not assert against static stub constants. They invoke real state mutations against `FakeMpvPlatform` and evaluate timing math and boundary conditions.

3. **Strict Compliance with Environmental Guardrails (Supported by Observation 1.2.3, 1.2.4, 1.2.5, 1.2.6, 1.2.7)**:
   - Zero unauthorized mock dependencies (`mockito`/`mocktail`).
   - Zero forbidden `// TODO`, `// FIXME`, or `NotImplementedError` placeholders.
   - 100% offline invariant respected (zero network I/O, zero remote telemetry endpoints).
   - Zero files touched or written outside `D:\E-player` (no `C:` drive leakage).
   - Zero local binary builds (`flutter build apk` or `flutter build windows`).

---

## 3. Caveats

- **libmpv Headless FFI in Windows Test Environment**: Headless Windows `flutter test` execution runs without GPU drivers and native `mpv-2.dll` window surfaces. The testing harness uses `FakeMpvPlatform` to simulate platform properties and verifies real service logic. Live platform rendering on Android / Windows desktop hardware will be verified in the full E2E opaque-box suite.
- No other caveats.

---

## 4. Conclusion

Milestone 1 (Phase 1 Hardware / HW+ Decoders) work products comply with all architectural specifications, environmental guardrails, and forensic integrity invariants.

### Phase Results
- Check 1 (Dummy/Facade Implementation): **PASS**
- Check 2 (Hardcoded Test Expectations): **PASS**
- Check 3 (Unauthorized Mock Packages): **PASS**
- Check 4 (Forbidden Placeholders): **PASS**
- Check 5 (Strict Offline Invariants): **PASS**
- Check 6 (Filesystem Invariants): **PASS**
- Check 7 (Compilation Guardrails): **PASS**
- Independent Test Execution: **PASS** (21/21 unit tests passed, 87/87 subsystem tests passed, 0 analyze errors/warnings)

### Final Verdict: **CLEAN**

---

## 5. Verification Method

To independently reproduce the forensic verification:

1. **Verify Static Analysis**:
   ```powershell
   cd d:\E-player\app
   flutter analyze lib/features/player/domain/ lib/features/player/ui/player_screen.dart test/unit/decoder_pipeline_test.dart
   ```
   *Expected:* `No issues found!`.

2. **Execute Decoder Pipeline Unit Tests**:
   ```powershell
   cd d:\E-player\app
   flutter test test/unit/decoder_pipeline_test.dart
   ```
   *Expected:* `00:00 +21: All tests passed!`.

3. **Execute Full Subsystem Suite**:
   ```powershell
   cd d:\E-player\app
   flutter test test/cast_service_test.dart test/export_service_test.dart test/media_group_service_test.dart test/media_info_test.dart test/media_scanner_search_test.dart test/model_registry_test.dart test/settings_provider_test.dart test/vault_service_test.dart test/video_rotation_test.dart test/features/enhancement_profile_test.dart test/features/video_effects_test.dart test/unit/decoder_pipeline_test.dart
   ```
   *Expected:* `00:07 +87: All tests passed!`.
