# E-PLAYER ANTIGRAVITY RESUME HANDOFF

## Start From The Existing Repository — Do Not Restart

Current reported state:
- Flutter app exists.
- media_kit/libmpv playback exists.
- PlayerScreen/custom controls exist.
- audio/subtitle track UI exists.
- libass/native complex subtitle path exists.
- EnhancementStudioSheet exists.
- C++ engine exists.
- Dart FFI exists.
- Windows CMake/native build works.
- enhancement behavior is currently simulated DSP/filter behavior.

Missing/unfinished:
- Android/iOS production builds;
- decoder modes;
- aspect ratio controls;
- gestures;
- subtitle delay/style/encoding;
- graphic EQ/effects;
- library indexer;
- vault;
- trash;
- background audio;
- PiP;
- network streams;
- Chromecast/AirPlay;
- real ONNX AI;
- offline enhanced export;
- RIFE;
- AI audio;
- depth/3D;
- final performance/security/release hardening.

## First 12 Actions

1. Inspect repository.
2. Build Windows.
3. Run tests.
4. Locate PlayerScreen.
5. Locate EnhancementStudioSheet.
6. Locate C++ FFI API.
7. Locate simulated DSP code.
8. Locate media_kit/libmpv configuration.
9. Locate subtitle/libass configuration.
10. Build Android.
11. Build iOS if available.
12. Generate a REAL/PARTIAL/MOCK/MISSING feature matrix.

## Do Not Restart

Do not replace working playback without evidence.
Do not rebuild the current player UI.
Do not delete the C++ engine.
Do not delete the current subtitle path.
Do not claim simulated DSP is AI.

## Architecture Rules

### Production AI
Use native/mobile ONNX Runtime. Use Python for research/model tooling only. Do not make Chaquopy the cross-platform production inference architecture.

### Playback
Keep media_kit/libmpv as the primary local playback engine unless measured evidence demands change.

### Storage
Prefer MediaStore/SAF on Android. Use Document Picker/security-scoped access on iOS. Do not make MANAGE_EXTERNAL_STORAGE mandatory merely to simplify scanning.

### Vault
Use actual authenticated encryption and Android Keystore/iOS Keychain. Do not use `.nomedia` as security.

### FFmpeg
Do not introduce the retired original FFmpegKit package without a current maintenance/license decision.

### PiP
Use native system PiP. Do not substitute overlay permission for PiP.

### AI
Start with offline export:
`decode -> native frame buffer -> ONNX -> encode -> mux -> validate`

Only after this is correct should live AI be optimized.

## Priority Order

1. Platform foundation.
2. Playback parity.
3. Gestures/subtitles/audio.
4. Library/privacy.
5. Background/PiP.
6. Network/casting.
7. Real AI export.
8. RIFE/AI audio/3D.
9. adaptive quality.
10. final hardening/regression.

## Definition of Done

Do not report the application complete until Android, iOS and the Windows reference build are stable; real AI export works; missing player features are implemented; offline mode passes; background/PiP/library/vault/trash work; network/casting are functional or correctly capability-gated; performance/memory/security tests pass; and final clean-install regression passes.
