$vlcDir = "C:\Program Files (x86)\VideoLAN\VLC"
if (-not (Test-Path $vlcDir)) {
    Write-Error "VLC directory not found at $vlcDir"
    exit 1
}

Write-Output "=== VLC Directory Found ==="
$vlcExe = Join-Path $vlcDir "vlc.exe"
if (Test-Path $vlcExe) {
    $versionInfo = (Get-Item $vlcExe).VersionInfo
    Write-Output "VLC Exe Version: $($versionInfo.FileVersion)"
    Write-Output "Product Version: $($versionInfo.ProductVersion)"
}

# Root Binaries
Write-Output "`n=== Root Binaries ==="
Get-ChildItem -Path $vlcDir -File | Where-Object { $_.Extension -match '\.exe|\.dll' } | Select-Object Name, Length, LastWriteTimeUtc | Format-Table -AutoSize

# Plugins scan
$pluginsDir = Join-Path $vlcDir "plugins"
if (Test-Path $pluginsDir) {
    $subDirs = Get-ChildItem -Path $pluginsDir -Directory
    $dlls = Get-ChildItem -Path $pluginsDir -Recurse -Filter "*.dll"
    $totalSize = ($dlls | Measure-Object -Property Length -Sum).Sum
    Write-Output "=== Plugins Inspection ==="
    Write-Output "Total Plugin Subdirectories: $($subDirs.Count)"
    Write-Output "Total Plugin DLLs: $($dlls.Count)"
    Write-Output "Total Plugin DLL Size (bytes): $totalSize"
    Write-Output "Total Plugin DLL Size (MB): $([math]::Round($totalSize / 1MB, 2))"
}

# libqt_plugin.dll inspection
$qtPlugin = Join-Path $pluginsDir "gui\libqt_plugin.dll"
if (Test-Path $qtPlugin) {
    $qtItem = Get-Item $qtPlugin
    Write-Output "`n=== libqt_plugin.dll ==="
    Write-Output "Path: $($qtItem.FullName)"
    Write-Output "Size (bytes): $($qtItem.Length)"
    Write-Output "Size (MB): $([math]::Round($qtItem.Length / 1MB, 2))"
}

# Lua Subsystem
$luaDir = Join-Path $vlcDir "lua"
if (Test-Path $luaDir) {
    $luaFiles = Get-ChildItem -Path $luaDir -Recurse -File
    Write-Output "`n=== Lua Subsystem ==="
    Write-Output "Total Lua Files: $($luaFiles.Count)"
    Get-ChildItem -Path $luaDir -Directory | Select-Object Name, @{Name="FileCount"; Expression={(Get-ChildItem -Path $_.FullName -Recurse -File).Count}} | Format-Table -AutoSize
}
