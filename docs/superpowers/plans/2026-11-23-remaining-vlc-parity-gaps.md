# Remaining VLC Parity Gaps Implementation Plan: Jump to Time (Ctrl+T) & SMB LAN Share Authenticator

## Objective
Implement the final two modern multimedia features to achieve 100% complete parity with VLC Media Player:
1. **Jump to Specific Time Dialog (`Ctrl+T` / `goto_time.cpp` Parity)**:
   - Dedicated modal dialog for instantaneous precision seeking.
   - Smart parser supporting `HH:MM:SS`, `MM:SS`, plain seconds, percentages (`50%`), and relative offsets (`+10m`, `-5m`).
   - Interactive quick jump chips and reference position display.
   - Bound to `Ctrl+T` desktop hotkey and HUD menu.

2. **SMB / Windows Network Share Authenticator & Ingestion (`smb2.c` / `dsm` Parity)**:
   - SMB MRL generator (`smb://[user[:password]@]host[:port]/share/file`) with credentials masking.
   - TCP port 445 ping / connectivity check.
   - Persisted 5-item FIFO history of recently connected network shares.
   - Dedicated Cyberpunk modal sheet `SmbShareBrowserSheet`.
   - Bound to `Ctrl+Shift+M` and HUD menu.

---

## 4-Pillar Architecture Breakdown

### Pillar 1: Jump to Time (Ctrl+T)
- **Domain**: `app/lib/features/player/domain/jump_to_time_models.dart`
  - Parser function `parseTimestampString(String input, Duration totalDuration)`.
- **UI**: `app/lib/features/player/ui/jump_to_time_dialog.dart`
  - Dialog with current/duration reference, monospace input, quick pills, and Jump action.
- **Integration**:
  - `desktop_keyboard_handler.dart` (`Ctrl+T`).
  - `player_screen.dart` (`_openJumpToTimeDialog`, HUD button `hud_jump_to_time_button`).
- **Tests**:
  - `app/test/unit/jump_to_time_test.dart`
  - `app/test/unit/jump_to_time_widget_test.dart`

---

### Pillar 2: SMB / Windows Network Share Authenticator
- **Domain**: `app/lib/features/network_stream/domain/smb_models.dart`
  - `SmbShareConfig` and `SmbRecentShare`.
- **Service**: `app/lib/features/network_stream/data/smb_service.dart`
  - History management via `SharedPreferences`, TCP port 445 connectivity probe.
- **UI**: `app/lib/features/network_stream/ui/smb_share_browser_sheet.dart`
  - Form fields (Host, Share, File, Username, Password, Domain), quick history chips, Connect button.
- **Integration**:
  - `desktop_keyboard_handler.dart` (`Ctrl+Shift+M`).
  - `player_screen.dart` (`_openSmbShareSheet`, HUD button `hud_smb_share_button`).
- **Tests**:
  - `app/test/unit/smb_models_and_service_test.dart`
  - `app/test/unit/smb_browser_widget_test.dart`

---

## Verification Plan
1. `flutter test --no-pub test/unit/jump_to_time_test.dart test/unit/jump_to_time_widget_test.dart`
2. `flutter test --no-pub test/unit/smb_models_and_service_test.dart test/unit/smb_browser_widget_test.dart`
3. Full Phase 4 regression test suite execution.
4. `flutter analyze --no-pub` with 0 errors and 0 warnings.
