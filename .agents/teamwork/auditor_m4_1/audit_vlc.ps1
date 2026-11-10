$vlcDir = "C:\Program Files (x86)\VideoLAN\VLC"
Write-Output "=== VLC ROOT FILES ==="
Get-ChildItem $vlcDir -File | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String | Write-Output

Write-Output "=== PLUGINS DIRECTORY AUDIT ==="
$pluginDirs = Get-ChildItem "$vlcDir\plugins" -Directory
Write-Output "Plugin Directories Count: $($pluginDirs.Count)"

$allPluginDlls = Get-ChildItem "$vlcDir\plugins" -Recurse -Filter *.dll
Write-Output "Total Plugin DLLs: $($allPluginDlls.Count)"

Write-Output "=== PLUGINS.DAT AUDIT ==="
Get-ChildItem "$vlcDir\plugins\plugins.dat" | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String | Write-Output

Write-Output "=== PLUGINS PER DIRECTORY ==="
$pluginDirs | ForEach-Object {
    $dlls = Get-ChildItem $_.FullName -Filter *.dll
    [PSCustomObject]@{ Directory = $_.Name; DllCount = $dlls.Count }
} | Format-Table -AutoSize | Out-String | Write-Output
