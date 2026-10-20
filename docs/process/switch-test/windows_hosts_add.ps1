# Add host names to the Windows hosts file, pointing at 127.0.0.1 (one new line). Names are the script arguments
# (an elevated Start-Process does not inherit the caller's environment, so they cannot come from a variable).
# Names already present on any active (non-comment) line are skipped; if all are present nothing changes.
# A backup hosts.bak-add-<time> is written before any change.
# Needs admin: Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',<this file>,<name>,<name>...
# Result goes to %TEMP%\hosts-add-result.txt (the admin window closes at once).
# Rehearsal only: HOSTS_FILE / HOSTS_OUT redirect the files. Leave unset for the real run.
# ASCII only on purpose: Windows PowerShell 5.1 reads a BOM-less script in the ANSI code page.
$ErrorActionPreference = 'Stop'
$hosts = if ($env:HOSTS_FILE) { $env:HOSTS_FILE } else { Join-Path $env:SystemRoot 'System32\drivers\etc\hosts' }
$out = if ($env:HOSTS_OUT) { $env:HOSTS_OUT } else { Join-Path $env:TEMP 'hosts-add-result.txt' }
try {
    $want = @($args | Where-Object { $_ })
    if ($want.Count -eq 0) { 'STOP: no names given' | Set-Content $out; exit 3 }
    foreach ($n in $want) { if ($n -notmatch '^[a-z0-9.-]+\.sunmoonai\.com$') { "STOP: refusing name $n" | Set-Content $out; exit 3 } }
    $lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($hosts))
    $present = @{}
    foreach ($l in $lines) {
        if ($l -match '^\s*#') { continue }
        foreach ($t in @(($l -split '\s+') | Where-Object { $_ })) { $present[$t] = $true }
    }
    $add = @($want | Where-Object { -not $present.ContainsKey($_) })
    if ($add.Count -eq 0) { @('OK nothing to add') | Set-Content $out; exit 0 }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $hosts "$hosts.bak-add-$stamp"
    $lines.Add('127.0.0.1 ' + ($add -join ' '))
    [System.IO.File]::WriteAllLines($hosts, $lines, (New-Object System.Text.UTF8Encoding($false)))
    $report = @("OK backup $hosts.bak-add-$stamp", "added: $($add -join ' ')", 'active sunmoonai lines now:')
    $report += @($lines | Where-Object { $_ -match 'sunmoonai' -and $_ -notmatch '^\s*#' })
    $report | Set-Content $out
    if (-not $env:HOSTS_FILE) { ipconfig /flushdns | Out-Null }
    exit 0
} catch {
    "STOP: $($_.Exception.Message)" | Set-Content $out
    exit 1
}
