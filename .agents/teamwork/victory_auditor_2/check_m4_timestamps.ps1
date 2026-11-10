Get-ChildItem -Path 'd:\E-player\.agents\teamwork' -Directory | Where-Object { $_.Name -match 'm4|orchestrator_5|worker_synthesis' } | ForEach-Object {
    $briefing = Join-Path $_.FullName 'BRIEFING.md'
    $handoff = Join-Path $_.FullName 'handoff.md'
    [PSCustomObject]@{
        Directory = $_.Name
        BriefingLastWrite = if (Test-Path $briefing) { (Get-Item $briefing).LastWriteTimeUtc } else { $null }
        HandoffLastWrite = if (Test-Path $handoff) { (Get-Item $handoff).LastWriteTimeUtc } else { $null }
    }
} | Sort-Object HandoffLastWrite | Format-Table -AutoSize
