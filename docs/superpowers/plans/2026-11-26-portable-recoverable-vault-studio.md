# Portable Multi-Storage & Recoverable Vault Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable E-Player Private Vault across internal storage AND external drives (`D:\`, `E:\`, USB, Android SD cards) with self-contained dual-slot cryptographic recovery (`vault_keystore.json`) so encrypted vaults survive app uninstalls, device changes, and forgotten PINs.

**Architecture:**
1. **Cryptographic Dual-Slot Key Envelope (`vault_keystore.dart`):**
   - Generate 256-bit random DEK (`_masterKey`). Store wrapped copies inside `<vaultDir>/vault_keystore.json`:
     - **Slot 1 (PIN Key-Wrap):** `PBKDF2-HMAC-SHA256(pin, salt, 10000)` -> AES-256-GCM wraps DEK. Allows full vault recovery after uninstall/reinstall or PC/phone migration simply by mounting the folder and entering the original PIN.
     - **Slot 2 (Recovery Key-Wrap):** 128-bit formatted recovery key (`EPLY-XXXX-...`) -> `PBKDF2-HMAC-SHA256` + AES-256-GCM wraps the same DEK independently, allowing PIN reset without re-encrypting GBs of 4K `.enc` files.
2. **Multi-Location Vault Engine (`vault_service.dart`):**
   - Support internal vault (`getApplicationDocumentsDirectory()/.eplayer_vault`) + any detected external drive (`D:\.eplayer_vault`, Android SD card `/storage/<UUID>/.eplayer_vault`) + custom mounted directories.
   - Store active & registered vault directories in `SharedPreferences`. Automatically discover mounted portable vaults containing `vault_keystore.json` or `.enc` files.
   - Decrypt 4K temporary playback cache onto `<activeVaultDir>/.tmp_play` when `decryptCacheOnVaultDrive` is enabled (preventing internal/`C:` disk exhaustion) and shred cleanly on `cleanupTempFiles()` / startup.
   - Auto-migrate legacy vaults cleanly upon unlock/PIN initialization.
3. **Vault Storage & Recovery Studio UI (`vault_storage_recovery_studio_sheet.dart`, `vault_screen.dart`):**
   - Accessible from BOTH Locked PIN Screen (essential for fresh reinstall / new device mount & recovery) AND Unlocked Vault Screen.
   - Switch locations (`Internal`, `D:\`, `SD Card`, `Custom Folder...`), create/mount vaults, display Recovery Key + export `.epvkey` backup, recover vault with Recovery Key + new PIN, and toggle on-drive 4K staging cache.

**Tech Stack:** Flutter 3.x+, Dart 3.x, `crypto`, `encrypt`, `path_provider`, `file_picker`, `shared_preferences`. Pure Dart (FAT32 workspace, zero new native packages).

## Review Focus
1. **Fresh Reinstall Recovery (Zero Local Prefs):** Wipe `SharedPreferences` completely (`{}`), point `VaultService` at existing `D:\.eplayer_vault` folder -> `verifyPin(oldPin)` MUST unwrap `_masterKey` from `vault_keystore.json` and decrypt original files cleanly.
2. **Recovery Key Forgotten-PIN Reset:** With empty `SharedPreferences`, call `recoverWithRecoveryKey(recoveryKey, newPin: ...)` -> must unwrap DEK via Slot 2, re-wrap Slot 1 with new PIN, and unlock vault files without data loss.
3. **4K Staging Temp Cleanup:** `decryptToTemp` inside `<vaultDir>/.tmp_play` must NEVER appear in `getVaultItems()` (`*.enc` only) and MUST be deleted cleanly on `cleanupTempFiles()` and startup.
4. **Legacy Compatibility:** Existing `VaultService()`, `deriveKeyFromPin`, `VaultItemMetadata`, `verifyPin`, `setPin`, `moveToVault`, `restoreFromVault`, and existing `test/vault_service_test.dart` MUST remain 100% compatible.
5. **PIN Verification When No Keystore & No Hash Exist:** Entering wrong PIN or random PIN when uninitialized must return `false`, never authenticate.
