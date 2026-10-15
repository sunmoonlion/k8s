# R5 Windows hosts (k8s/docs/rename.md R5.2): add the four renamed domains.
# knowfeed names go on the line that already has info.sunmoonai.com (same address);
# knowbase names go on the line that already has knowledge.sunmoonai.com. If both old names share a line, all four go there.
# Only missing names are appended; old names stay until R6. A backup hosts.bak-rename-<time> is written first.
# Needs admin: Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',<this file>
# Result goes to %TEMP%\rename-hosts-result.txt (the admin window closes at once).
# ASCII only on purpose: Windows PowerShell 5.1 reads a BOM-less script in the ANSI code page.
$ErrorActionPreference = 'Stop'
# Rehearsal only: RENAME_HOSTS_FILE / RENAME_HOSTS_OUT redirect the files. Leave unset for the real run.
$hosts = if ($env:RENAME_HOSTS_FILE) { $env:RENAME_HOSTS_FILE } else { Join-Path $env:SystemRoot 'System32\drivers\etc\hosts' }
$out = if ($env:RENAME_HOSTS_OUT) { $env:RENAME_HOSTS_OUT } else { Join-Path $env:TEMP 'rename-hosts-result.txt' }
$groups = @(
    @{ old = 'info.sunmoonai.com'; new = @('knowfeed.sunmoonai.com', 'knowfeed-admin.sunmoonai.com') },
    @{ old = 'knowledge.sunmoonai.com'; new = @('knowbase.sunmoonai.com', 'knowbase-admin.sunmoonai.com') }
)
function Find-Line($lines, $name) {
    $pat = '(\s)' + [regex]::Escape($name) + '(\s|$)'
    $hit = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^\s*#' -and $lines[$i] -match $pat) { $hit += $i }
    }
    return , $hit
}
try {
    $lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($hosts))
    $plan = @()
    foreach ($g in $groups) {
        $hit = Find-Line $lines $g.old
        if ($hit.Count -ne 1) { "STOP: $($hit.Count) active lines contain $($g.old) (expected 1); nothing changed" | Set-Content $out; exit 3 }
        $plan += @{ line = $hit[0]; new = $g.new }
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $hosts "$hosts.bak-rename-$stamp"
    $report = @("OK backup $hosts.bak-rename-$stamp")
    foreach ($p in $plan) {
        $have = @(($lines[$p.line] -split '\s+') | Where-Object { $_ })
        $add = @($p.new | Where-Object { $have -notcontains $_ })
        if ($add.Count -gt 0) { $lines[$p.line] = $lines[$p.line].TrimEnd() + ' ' + ($add -join ' ') }
        $report += "line $($p.line + 1) added: $($add -join ' ')"
    }
    [System.IO.File]::WriteAllLines($hosts, $lines, (New-Object System.Text.UTF8Encoding($false)))
    $report += 'active sunmoonai lines now:'
    $report += @($lines | Where-Object { $_ -match 'sunmoonai' -and $_ -notmatch '^\s*#' })
    $report | Set-Content $out
    if (-not $env:RENAME_HOSTS_FILE) { ipconfig /flushdns | Out-Null }
    exit 0
} catch {
    "STOP: $($_.Exception.Message)" | Set-Content $out
    exit 1
}
