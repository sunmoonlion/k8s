# Local Windows repair: hide the task action and remove minute polling; retain owner logon.
# No disk initialization, service operations, maintenance-marker changes or WSL shutdown.
[CmdletBinding()]
param([string]$LauncherSha256 = '', [switch]$Apply)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$TaskName = 'sunmoon-data-mount'
$Launcher = 'C:\wsl-disks\scripts\storage-automation-20260928-v2\run-sunmoon-data-hidden.vbs'
$Runner = 'C:\wsl-disks\scripts\storage-automation-20260928-v1\ensure-sunmoon-data.ps1'
$RunnerSha = '70ca2d6693881940231bdd39acaad9b2853f96d0c7ddbf5e9d523747e0a4c2bd'
$HostExe = Join-Path $env:SystemRoot 'System32\wscript.exe'
$Arguments = '//B //Nologo "' + $Launcher + '"'
if (-not $Apply) {
    [pscustomobject]@{DryRun=$true;Task=$TaskName;Execute=$HostExe;Arguments=$Arguments;Trigger='owner logon only';RunnerUnchanged=$true;ServicesChanged=$false} | ConvertTo-Json
    return
}
$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$Identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as the elevated Ubuntu owner' }
if ($LauncherSha256 -notmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath $Launcher -Algorithm SHA256).Hash.ToLowerInvariant() -ne $LauncherSha256) { throw 'Published launcher digest differs' }
if ((Get-FileHash -LiteralPath $Runner -Algorithm SHA256).Hash.ToLowerInvariant() -ne $RunnerSha) { throw 'Published runner digest differs' }
if (-not (Test-Path -LiteralPath $HostExe)) { throw 'Windows Script Host unavailable; task unchanged' }
if (Test-Path -LiteralPath 'C:\wsl-disks\sunmoon-data.maintenance') { throw 'Maintenance active; do not enable or change the task' }
$Task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\'
$PrincipalId = [string]$Task.Principal.UserId
if ($PrincipalId -match '^S-1-') {
    $PrincipalSid = ([Security.Principal.SecurityIdentifier]$PrincipalId).Value
} else {
    # Task Scheduler can return a local SAM name without the machine qualifier.
    if ($PrincipalId -notmatch '[\\@]') { $PrincipalId = $env:COMPUTERNAME + '\' + $PrincipalId }
    $PrincipalSid = ([Security.Principal.NTAccount]$PrincipalId).Translate([Security.Principal.SecurityIdentifier]).Value
}
if ($PrincipalSid -ne $Identity.User.Value -or $Task.Principal.LogonType -ne 'Interactive' -or $Task.Principal.RunLevel -ne 'Highest') { throw 'Unexpected task owner or privileges' }
if (-not $Task.Settings.Enabled -or @($Task.Actions).Count -ne 1) { throw 'Unexpected disabled task or action count' }
$OldCommand = "if ((Get-FileHash -LiteralPath '$Runner' -Algorithm SHA256).Hash.ToLowerInvariant() -ne '$RunnerSha') { exit 3 }; & '$Runner' -Apply"
$OldArguments = '-NoProfile -NonInteractive -Command "' + $OldCommand + '"'
$Logon = @($Task.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' })
if ($Logon.Count -ne 1) { throw 'Expected exactly one existing owner-logon trigger' }
if ($Task.Actions[0].Execute -eq $HostExe -and $Task.Actions[0].Arguments -eq $Arguments -and @($Task.Triggers).Count -eq 1) {
    [pscustomobject]@{Task=$TaskName;Result='already-hidden-logon-only';Changed=$false} | ConvertTo-Json
    return
}
if ($Task.Actions[0].Execute -ne 'powershell.exe' -or $Task.Actions[0].Arguments -ne $OldArguments) { throw 'Task action drifted; inspect before replacement' }
$Backup = 'C:\wsl-disks\sunmoon-data-task-before-hidden-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.xml'
Export-ScheduledTask -TaskName $TaskName -TaskPath '\' | Set-Content -LiteralPath $Backup -Encoding UTF8
$Changed = $false
Disable-ScheduledTask -TaskName $TaskName -TaskPath '\' | Out-Null
try {
    # Let an in-flight attach finish; never terminate it mid-mount.
    $Scheduler = New-Object -ComObject 'Schedule.Service'
    $Scheduler.Connect()
    $RegisteredTask = $Scheduler.GetFolder('\').GetTask($TaskName)
    $Deadline = (Get-Date).AddSeconds(45)
    do {
        if ($RegisteredTask.GetInstances(0).Count -eq 0) { break }
        if ((Get-Date) -ge $Deadline) { throw 'Existing task is still running; no action replacement' }
        Start-Sleep -Seconds 1
    } while ($true)
    $Action = New-ScheduledTaskAction -Execute $HostExe -Argument $Arguments
    Set-ScheduledTask -TaskName $TaskName -TaskPath '\' -Action $Action -Trigger $Logon | Out-Null
    $Changed = $true
} finally {
    Enable-ScheduledTask -TaskName $TaskName -TaskPath '\' | Out-Null
}
$After = Get-ScheduledTask -TaskName $TaskName -TaskPath '\'
if ($After.Actions[0].Execute -ne $HostExe -or $After.Actions[0].Arguments -ne $Arguments) { throw 'Task action readback differs' }
if (@($After.Triggers).Count -ne 1 -or $After.Triggers[0].CimClass.CimClassName -ne 'MSFT_TaskLogonTrigger') { throw 'Periodic trigger was not removed' }
$StartedAfter = (Get-Date).AddSeconds(-2)
Start-ScheduledTask -TaskName $TaskName -TaskPath '\'
$Deadline = (Get-Date).AddSeconds(45)
do {
    Start-Sleep -Seconds 1
    $Info = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath '\'
    $Current = Get-ScheduledTask -TaskName $TaskName -TaskPath '\'
    if ($Info.LastRunTime -ge $StartedAfter -and $Current.State -ne 'Running') { break }
} while ((Get-Date) -lt $Deadline)
$Receipt = [pscustomobject]@{Task=$TaskName;Changed=$Changed;Execute=$After.Actions[0].Execute;Arguments=$After.Actions[0].Arguments;Trigger='owner logon only';PeriodicTriggerRemoved=$true;Backup=$Backup;LauncherSha256=$LauncherSha256;RunnerSha256=$RunnerSha;State=[string]$Current.State;LastRunTime=$Info.LastRunTime.ToString('o');LastTaskResult=$Info.LastTaskResult;ServicesChanged=$false}
$Receipt | ConvertTo-Json | Set-Content -LiteralPath 'C:\wsl-disks\sunmoon-data-task-hidden.json' -Encoding UTF8
if ($Info.LastRunTime -lt $StartedAfter -or $Current.State -eq 'Running' -or $Info.LastTaskResult -ne 0) { throw 'Hidden action installed but first run failed; inspect receipt, do not rebuild disk' }
$Receipt | ConvertTo-Json
