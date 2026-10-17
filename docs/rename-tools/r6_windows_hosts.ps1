# R6 Windows hosts (k8s/docs/rename.md R6, 0028): remove the old investment domains added before the rename.
# Removes exactly investment.sunmoonai.com, investment-admin.sunmoonai.com, investment-api.sunmoonai.com and
# investment-admin-api.sunmoonai.com from active (non-comment) lines. The matching new name must already be on
# some active line (R5.2 added knowbench.sunmoonai.com and knowbench-admin.sunmoonai.com on a line of their own);
# otherwise nothing is changed. A line left with only its address is dropped. A backup hosts.bak-r6-<time> is written first.
# Needs admin: Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',<this file>
# Result goes to %TEMP%\rename-hosts-r6-result.txt (the admin window closes at once).
# ASCII only on purpose: Windows PowerShell 5.1 reads a BOM-less script in the ANSI code page.
$ErrorActionPreference = 'Stop'
# Rehearsal only: RENAME_HOSTS_FILE / RENAME_HOSTS_OUT redirect the files. Leave unset for the real run.
$hosts = if ($env:RENAME_HOSTS_FILE) { $env:RENAME_HOSTS_FILE } else { Join-Path $env:SystemRoot 'System32\drivers\etc\hosts' }
$out = if ($env:RENAME_HOSTS_OUT) { $env:RENAME_HOSTS_OUT } else { Join-Path $env:TEMP 'rename-hosts-r6-result.txt' }
$pairs = @{
    'investment.sunmoonai.com' = 'knowbench.sunmoonai.com'
    'investment-admin.sunmoonai.com' = 'knowbench-admin.sunmoonai.com'
    'investment-api.sunmoonai.com' = 'knowbench.sunmoonai.com'
    'investment-admin-api.sunmoonai.com' = 'knowbench-admin.sunmoonai.com'
}
try {
    $lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($hosts))
    $active = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*#') { continue }
        $active += @(($lines[$i] -split '\s+') | Where-Object { $_ })
    }
    $report = @()
    $changed = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*#') { continue }
        $tokens = @(($lines[$i] -split '\s+') | Where-Object { $_ })
        $old = @($tokens | Where-Object { $pairs.ContainsKey($_) })
        if ($old.Count -eq 0) { continue }
        foreach ($o in $old) {
            if ($active -notcontains $pairs[$o]) { "STOP: line $($i + 1) has $o but no active line has $($pairs[$o]); nothing changed" | Set-Content $out; exit 3 }
        }
        $keep = @($tokens | Where-Object { -not $pairs.ContainsKey($_) })
        $changed[$i] = if ($keep.Count -le 1) { $null } else { $keep -join ' ' }
        $report += "line $($i + 1) removed: $($old -join ' ')"
    }
    if ($changed.Count -eq 0) { @('OK nothing to remove') | Set-Content $out; exit 0 }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $hosts "$hosts.bak-r6-$stamp"
    $result = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($changed.ContainsKey($i)) { if ($null -ne $changed[$i]) { $result.Add($changed[$i]) } }
        else { $result.Add($lines[$i]) }
    }
    [System.IO.File]::WriteAllLines($hosts, $result, (New-Object System.Text.UTF8Encoding($false)))
    $report = @("OK backup $hosts.bak-r6-$stamp") + $report
    $report += 'active sunmoonai lines now:'
    $report += @($result | Where-Object { $_ -match 'sunmoonai' -and $_ -notmatch '^\s*#' })
    $report | Set-Content $out
    if (-not $env:RENAME_HOSTS_FILE) { ipconfig /flushdns | Out-Null }
    exit 0
} catch {
    "STOP: $($_.Exception.Message)" | Set-Content $out
    exit 1
}
