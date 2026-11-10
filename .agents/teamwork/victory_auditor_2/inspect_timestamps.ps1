$files = @('d:\E-player\docs\vlc_gap_analysis.md', 'd:\E-player\vlc-help.txt')
Get-Item -Path $files -ErrorAction SilentlyContinue | Select-Object FullName, CreationTimeUtc, LastWriteTimeUtc, Length | Format-List

Get-ChildItem -Path 'd:\E-player\.agents\teamwork' -Directory | Where-Object { $_.Name -match 'explorer|orchestrator_5|worker_synthesis|m4' } | Select-Object Name, CreationTimeUtc, LastWriteTimeUtc | Sort-Object CreationTimeUtc | Format-Table -AutoSize
