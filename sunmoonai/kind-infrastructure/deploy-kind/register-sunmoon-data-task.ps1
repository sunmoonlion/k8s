# Local Windows only. Default plan; no legacy task changes or distro shutdown.
# The owner account's highest Interactive token is required; never use SYSTEM.
[CmdletBinding()]
param(
    [string]$RunnerSha256 = '',
    [string]$LauncherSha256 = '',
    [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$TaskName = 'sunmoon-data-mount'
$Runner = 'C:\wsl-disks\scripts\storage-automation-20260928-v1\ensure-sunmoon-data.ps1'
$Launcher = 'C:\wsl-disks\scripts\storage-automation-20260928-v2\run-sunmoon-data-hidden.vbs'
$HostExe = Join-Path $env:SystemRoot 'System32\wscript.exe'
if (-not $Apply) {
    [pscustomobject]@{DryRun=$true;Task=$TaskName;Runner=$Runner;Launcher=$Launcher;Triggers='owner logon only';StartsStoppedUbuntu=$false;ExistingTaskPolicy='refuse overwrite; use hide-sunmoon-data-task.ps1 for the known old action';OldTasksModified=$false} | ConvertTo-Json
    return
}
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) { throw 'Run registration in an elevated PowerShell for the Ubuntu owner' }
if ($RunnerSha256 -notmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath $Runner -Algorithm SHA256).Hash.ToLowerInvariant() -ne $RunnerSha256) { throw 'Explicit published runner digest required' }
if ($RunnerSha256 -ne '70ca2d6693881940231bdd39acaad9b2853f96d0c7ddbf5e9d523747e0a4c2bd') { throw 'Launcher is pinned to the v1 runner; revise publication as one unit' }
if ($LauncherSha256 -notmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath $Launcher -Algorithm SHA256).Hash.ToLowerInvariant() -ne $LauncherSha256) { throw 'Explicit published launcher digest required' }
if (-not (Test-Path -LiteralPath $HostExe)) { throw 'Windows Script Host unavailable' }
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { throw 'Task exists; inspect rather than overwrite it' }
$Owner = [Security.Principal.WindowsIdentity]::GetCurrent().Name
# The task verifies the published bytes on EVERY run; no worktree dependency.
$Action = New-ScheduledTaskAction -Execute $HostExe -Argument ('//B //Nologo "' + $Launcher + '"')
$Logon = New-ScheduledTaskTrigger -AtLogOn -User $Owner
$Principal = New-ScheduledTaskPrincipal -UserId $Owner -LogonType Interactive -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Logon -Principal $Principal -Settings $Settings -Description 'Check existing Sunmoon data disk at owner logon without a console; no periodic polling or service startup' | Out-Null
$StartedAfter = (Get-Date).AddSeconds(-2)
Start-ScheduledTask -TaskName $TaskName
$Deadline = (Get-Date).AddSeconds(45)
do {
    Start-Sleep -Seconds 1
    $Info = Get-ScheduledTaskInfo -TaskName $TaskName
    $Task = Get-ScheduledTask -TaskName $TaskName
    if ($Info.LastRunTime -ge $StartedAfter -and $Task.State -ne 'Running') { break }
} while ((Get-Date) -lt $Deadline)
$Receipt = [pscustomobject]@{Registered=$true;Task=$TaskName;Owner=$Owner;Runner=$Runner;RunnerSha256=$RunnerSha256;State=[string]$Task.State;LastRunTime=$Info.LastRunTime.ToString('o');LastTaskResult=$Info.LastTaskResult;ObservedAt=(Get-Date).ToString('o')}
$Receipt | ConvertTo-Json | Set-Content -LiteralPath 'C:\wsl-disks\sunmoon-data-task-registration.json' -Encoding UTF8
if ($Info.LastRunTime -lt $StartedAfter -or $Task.State -eq 'Running' -or $Info.LastTaskResult -ne 0) { throw 'Task registered but initial run did not pass; inspect the retained receipt and task status' }
$Receipt | ConvertTo-Json
