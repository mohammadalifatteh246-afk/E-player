$vlcDir = "C:\Program Files (x86)\VideoLAN\VLC"
$allDlls = Get-ChildItem $vlcDir -Recurse -Filter *.dll
Write-Output "Total DLLs under VLC root: $($allDlls.Count)"
$pluginsDlls = Get-ChildItem "$vlcDir\plugins" -Recurse -Filter *.dll
Write-Output "Total DLLs under plugins: $($pluginsDlls.Count)"
$rootDlls = Get-ChildItem $vlcDir -File -Filter *.dll
Write-Output "Root DLLs: $($rootDlls.Count)"
$rootDlls | Select-Object Name, Length | Format-Table -AutoSize | Out-String | Write-Output

# Let's inspect Lua scripts
$luaFiles = Get-ChildItem "$vlcDir\lua" -Recurse -File
Write-Output "Total Lua files: $($luaFiles.Count)"
$luaDirs = Get-ChildItem "$vlcDir\lua" -Directory
Write-Output "Lua directories: $($luaDirs.Count)"
$luaDirs | Select-Object Name | Format-Table -AutoSize | Out-String | Write-Output
