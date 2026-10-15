# E-Player V3 — Step 1 & Step 2 Antigravity Workspace Update Guide

## 1. Are Step 1 and Step 2 Automatically in GitHub?
**No.** Because this cloud session runs in an isolated sandbox without your GitHub credentials or direct access to your local `D:\E-player` drive, the Step 1 and Step 2 code files are packaged here for you to drop directly into your local **Antigravity Workspace (`D:\E-player`)** and push to GitHub.

---

## 2. Complete File Inventory & Exact Destination Paths in Antigravity Workspace

Every file created or updated across **Step 1 (V3 Stitch Secondary Sub-Screens & String-Interpolation Bug Fixes)** and **Step 2 (Phase 8 Vault Hardening & Phase 12–13 Native C++ FFI Offline Export Engine)** is listed below with its exact target path inside `D:\E-player`:

| # | File Name | Step / Phase | Action | Exact Destination Path in Antigravity Workspace (`D:\E-player`) |
| :- | :--- | :--- | :--- | :--- |
| 1 | `e_design_tokens.dart` | Step 1 (Design System) | **Create New** | `D:\E-player\app\lib\ui\theme\e_design_tokens.dart` |
| 2 | `vault_screen.dart` | Step 1 (V3 Sub-Screen) | **Replace** | `D:\E-player\app\lib\features\vault\ui\vault_screen.dart` |
| 3 | `trash_screen.dart` | Step 1 (V3 Sub-Screen) | **Replace** | `D:\E-player\app\lib\features\trash\ui\trash_screen.dart` |
| 4 | `export_screen.dart` | Step 1 & 2 (V3 Sub-Screen) | **Replace** | `D:\E-player\app\lib\features\export\ui\export_screen.dart` |
| 5 | `folder_detail_screen.dart` | Step 1 (V3 Sub-Screen) | **Replace** | `D:\E-player\app\lib\features\library\ui\folder_detail_screen.dart` |
| 6 | `home_screen.dart` | Step 1 (Bug Fix + V3) | **Replace** | `D:\E-player\app\lib\features\home\ui\home_screen.dart` |
| 7 | `library_screen.dart` | Step 1 (Bug Fix + V3) | **Replace** | `D:\E-player\app\lib\features\library\ui\library_screen.dart` |
| 8 | `library_provider.dart` | Step 1 (DB & Progress) | **Replace** | `D:\E-player\app\lib\features\library\domain\library_provider.dart` |
| 9 | `player_screen.dart` | Step 1 (HUD/Speed/Lock Fix) | **Replace** | `D:\E-player\app\lib\features\player\ui\player_screen.dart` |
| 10 | `enhance_screen.dart` | Step 1 (Export Queue Wire) | **Replace** | `D:\E-player\app\lib\features\enhancement\ui\enhance_screen.dart` |
| 11 | `vault_service.dart` | Step 2 (Phase 8 Security) | **Replace** | `D:\E-player\app\lib\features\vault\domain\vault_service.dart` |
| 12 | `export_service.dart` | Step 2 (Phase 12–13 Export) | **Replace** | `D:\E-player\app\lib\features\export\domain\export_service.dart` |
| 13 | `engine_bindings.dart` | Step 2 (Phase 12 FFI) | **Replace** | `D:\E-player\app\lib\core\ffi\engine_bindings.dart` |
| 14 | `engine_orchestrator.dart` | Step 2 (Phase 12 FFI) | **Replace** | `D:\E-player\app\lib\core\engine_orchestrator.dart` |
| 15 | `model_registry.dart` | Step 2 (Phase 12.3 ONNX) | **Replace** | `D:\E-player\app\lib\core\model_registry.dart` |
| 16 | `eplayer_engine.h` | Step 2 (Phase 12 C++ API) | **Replace** | `D:\E-player\native\engine\include\eplayer_engine.h` |
| 17 | `eplayer_engine.cpp` | Step 2 (Phase 12 C++ Core) | **Replace** | `D:\E-player\native\engine\src\eplayer_engine.cpp` |
| 18 | `export_service_test.dart` | Step 2 (Phase 13 Tests) | **Replace** | `D:\E-player\app\test\export_service_test.dart` |
| 19 | `vault_service_test.dart` | Step 2 (Phase 8 Tests) | **Create New** | `D:\E-player\app\test\vault_service_test.dart` |

---

## 3. How to Apply the Folder Package (`E_PLAYER_V3_STEP1_AND_STEP2_PACKAGE.zip`)

The attached ZIP archive `E_PLAYER_V3_STEP1_AND_STEP2_PACKAGE.zip` contains two folders so you can update your workspace either automatically or file-by-file:

1. **`workspace_tree/` (Recommended 1-Step Extract):**
   - Contains the exact directory structure (`app/lib/...`, `app/test/...`, `native/engine/...`).
   - Copy the contents of `workspace_tree/` directly into `D:\E-player\` and click **Replace the files in the destination**.
2. **`flat_files/` (All 19 Files by Name + Automated Installer):**
   - Contains all 19 code files in a single flat folder along with `apply_v3_updates.ps1`.
   - Run `.\apply_v3_updates.ps1 -WorkspaceRoot "D:\E-player"` in PowerShell and it will automatically create `app\lib\ui\theme` and copy all 19 files into their exact paths.

---

## 4. PowerShell Commands to Test, Build APK on `C:\E-player`, and Push to GitHub

After copying the files into `D:\E-player` (or running `apply_v3_updates.ps1`), run these commands in PowerShell (or ask Antigravity to run them):

```powershell
# 1. Verify Dart analysis and unit tests in D:\E-player
cd D:\E-player\app
flutter pub get
flutter test

# 2. Follow Documents\E_PLAYER_APK_RULE.md:
#    Mirror updated code to C:\E-player and build the release APK from C: drive
robocopy D:\E-player C:\E-player /MIR /XD .git build .dart_tool
cd C:\E-player\app
flutter build apk --release
Copy-Item C:\E-player\app\build\app\outputs\flutter-apk\app-release.apk D:\E-player\app-release.apk -Force

# 3. Stage, commit, and push all Step 1 & Step 2 files to GitHub
cd D:\E-player
git status
git add .
git commit -m "feat(v3): upgrade secondary screens to Stitch V3 and harden Phase 8 Vault & Phase 12-13 ONNX FFI export"
git push origin main
```

---

## 5. Master Prompt to Paste into Local Antigravity Agent

If you are using the **Antigravity** agent directly inside `D:\E-player`, paste this prompt into Antigravity after extracting `E_PLAYER_V3_STEP1_AND_STEP2_PACKAGE.zip`:

> **PROMPT FOR ANTIGRAVITY:**
> "I have placed the Step 1 & Step 2 V3 update package in this workspace. Please verify that all 19 updated files (`app/lib/ui/theme/e_design_tokens.dart`, `vault_screen.dart`, `trash_screen.dart`, `export_screen.dart`, `folder_detail_screen.dart`, `home_screen.dart`, `library_screen.dart`, `library_provider.dart`, `player_screen.dart`, `enhance_screen.dart`, `vault_service.dart`, `export_service.dart`, `engine_bindings.dart`, `engine_orchestrator.dart`, `model_registry.dart`, `native/engine/include/eplayer_engine.h`, `native/engine/src/eplayer_engine.cpp`, `app/test/export_service_test.dart`, and `app/test/vault_service_test.dart`) are in their target locations under `D:\E-player`. Run `flutter test` in `D:\E-player\app`, sync the updated code to `C:\E-player` to build `app-release.apk` per `Documents/E_PLAYER_APK_RULE.md`, copy the built APK back to `D:\E-player\app-release.apk`, and commit and push all changes to the `main` branch on GitHub."
