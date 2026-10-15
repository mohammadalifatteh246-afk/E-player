param(
    [string]$WorkspaceRoot = "D:\E-player",
    [string]$ApkBuildRoot = "C:\E-player",
    [switch]$BuildApk = $false,
    [switch]$PushToGitHub = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== E-Player V3 Step 1 & Step 2 Workspace Updater ===" -ForegroundColor Cyan
Write-Host "Target Workspace: $WorkspaceRoot"

# Ensure target directories exist
$dirs = @(
    "$WorkspaceRoot\app\lib\ui\theme",
    "$WorkspaceRoot\app\lib\features\vault\ui",
    "$WorkspaceRoot\app\lib\features\vault\domain",
    "$WorkspaceRoot\app\lib\features\trash\ui",
    "$WorkspaceRoot\app\lib\features\export\ui",
    "$WorkspaceRoot\app\lib\features\export\domain",
    "$WorkspaceRoot\app\lib\features\library\ui",
    "$WorkspaceRoot\app\lib\features\library\domain",
    "$WorkspaceRoot\app\lib\features\home\ui",
    "$WorkspaceRoot\app\lib\features\player\ui",
    "$WorkspaceRoot\app\lib\features\enhancement\ui",
    "$WorkspaceRoot\app\lib\core\ffi",
    "$WorkspaceRoot\app\test",
    "$WorkspaceRoot\native\engine\include",
    "$WorkspaceRoot\native\engine\src"
)

foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

# File mapping table: FileName -> Relative Destination Path under $WorkspaceRoot
$fileMap = @{
    "e_design_tokens.dart"      = "app\lib\ui\theme\e_design_tokens.dart"
    "vault_screen.dart"         = "app\lib\features\vault\ui\vault_screen.dart"
    "trash_screen.dart"         = "app\lib\features\trash\ui\trash_screen.dart"
    "export_screen.dart"        = "app\lib\features\export\ui\export_screen.dart"
    "folder_detail_screen.dart" = "app\lib\features\library\ui\folder_detail_screen.dart"
    "home_screen.dart"          = "app\lib\features\home\ui\home_screen.dart"
    "library_screen.dart"       = "app\lib\features\library\ui\library_screen.dart"
    "library_provider.dart"     = "app\lib\features\library\domain\library_provider.dart"
    "player_screen.dart"        = "app\lib\features\player\ui\player_screen.dart"
    "enhance_screen.dart"       = "app\lib\features\enhancement\ui\enhance_screen.dart"
    "vault_service.dart"        = "app\lib\features\vault\domain\vault_service.dart"
    "export_service.dart"       = "app\lib\features\export\domain\export_service.dart"
    "engine_bindings.dart"      = "app\lib\core\ffi\engine_bindings.dart"
    "engine_orchestrator.dart"  = "app\lib\core\engine_orchestrator.dart"
    "model_registry.dart"       = "app\lib\core\model_registry.dart"
    "eplayer_engine.h"          = "native\engine\include\eplayer_engine.h"
    "eplayer_engine.cpp"        = "native\engine\src\eplayer_engine.cpp"
    "export_service_test.dart"  = "app\test\export_service_test.dart"
    "vault_service_test.dart"   = "app\test\vault_service_test.dart"
}

foreach ($entry in $fileMap.GetEnumerator()) {
    $fileName = $entry.Key
    $relDest = $entry.Value
    $destPath = Join-Path $WorkspaceRoot $relDest

    # Look in flat_files/ or current script directory
    $candidate1 = Join-Path $ScriptDir "flat_files\$fileName"
    $candidate2 = Join-Path $ScriptDir $fileName

    if (Test-Path $candidate1) {
        Copy-Item $candidate1 $destPath -Force
        Write-Host "[UPDATED] $relDest" -ForegroundColor Green
    } elseif (Test-Path $candidate2) {
        Copy-Item $candidate2 $destPath -Force
        Write-Host "[UPDATED] $relDest" -ForegroundColor Green
    } else {
        Write-Warning "Could not find source file: $fileName"
    }
}

Write-Host "`nAll 19 Step 1 & Step 2 files have been applied to $WorkspaceRoot!" -ForegroundColor Cyan

if ($BuildApk) {
    Write-Host "`nSyncing to $ApkBuildRoot for APK compilation (per E_PLAYER_APK_RULE.md)..." -ForegroundColor Yellow
    robocopy $WorkspaceRoot $ApkBuildRoot /MIR /XD .git build .dart_tool | Out-Null
    Push-Location "$ApkBuildRoot\app"
    flutter build apk --release
    Copy-Item "$ApkBuildRoot\app\build\app\outputs\flutter-apk\app-release.apk" "$WorkspaceRoot\app-release.apk" -Force
    Pop-Location
    Write-Host "[SUCCESS] Release APK copied to $WorkspaceRoot\app-release.apk" -ForegroundColor Green
}

if ($PushToGitHub) {
    Write-Host "`nCommitting and pushing changes to GitHub..." -ForegroundColor Yellow
    Push-Location $WorkspaceRoot
    git add .
    git commit -m "feat(v3): upgrade secondary screens to Stitch V3 and harden Phase 8 Vault & Phase 12-13 ONNX FFI export"
    git push origin main
    Pop-Location
    Write-Host "[SUCCESS] Pushed to GitHub origin/main!" -ForegroundColor Green
}
