#requires -Version 5.1
#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$TaskName = 'Sunmoon-ProdVm-Forwarding'
$InstallDir = 'C:\ProgramData\Sunmoon\prod-vm'
$SourceScript = Join-Path $PSScriptRoot 'Enable-SunmoonForwarding.ps1'
$InstalledScript = Join-Path $InstallDir 'Enable-SunmoonForwarding.ps1'

if (-not (Test-Path -LiteralPath $SourceScript -PathType Leaf)) {
    throw "Forwarding script not found: $SourceScript"
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -LiteralPath $SourceScript -Destination $InstalledScript -Force

$powerShellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$service = New-Object -ComObject 'Schedule.Service'
$service.Connect()
$definition = $service.NewTask(0)
$definition.RegistrationInfo.Description = 'Enable IPv4 forwarding only on VMware VMnet8 and the WSL vEthernet interface.'
$definition.Principal.UserId = 'SYSTEM'
$definition.Principal.LogonType = 5 # TASK_LOGON_SERVICE_ACCOUNT
$definition.Principal.RunLevel = 1 # TASK_RUNLEVEL_HIGHEST
$definition.Settings.Enabled = $true
$definition.Settings.StartWhenAvailable = $true
$definition.Settings.MultipleInstances = 2 # TASK_INSTANCES_IGNORE_NEW
$definition.Settings.ExecutionTimeLimit = 'PT21M'
$definition.Settings.DisallowStartIfOnBatteries = $false

$trigger = $definition.Triggers.Create(8) # TASK_TRIGGER_BOOT
$trigger.Enabled = $true
$trigger.Repetition.Interval = 'PT10M'
$trigger.Repetition.Duration = 'P1D'
$trigger.Repetition.StopAtDurationEnd = $false

$action = $definition.Actions.Create(0) # TASK_ACTION_EXEC
$action.Path = $powerShellExe
$action.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $InstalledScript

$rootFolder = $service.GetFolder('\')
$null = $rootFolder.RegisterTaskDefinition($TaskName, $definition, 6, 'SYSTEM', $null, 5, $null)

Import-Module ScheduledTasks
$logPath = Join-Path $InstallDir 'forwarding.log'
$logLineCount = if (Test-Path -LiteralPath $logPath) { [System.IO.File]::ReadAllLines($logPath).Length } else { 0 }
Start-ScheduledTask -TaskName $TaskName
$deadline = (Get-Date).AddSeconds(90)
$newLogLines = @()
do {
    Start-Sleep -Seconds 2
    $info = Get-ScheduledTaskInfo -TaskName $TaskName
    $task = Get-ScheduledTask -TaskName $TaskName
    if (Test-Path -LiteralPath $logPath) {
        $newLogLines = @([System.IO.File]::ReadAllLines($logPath) | Select-Object -Skip $logLineCount)
    }
    $vmnetLogged = @($newLogLines | Where-Object { $_ -like '*interface=VMware Network Adapter VMnet8;*after=Enabled' }).Count -gt 0
    $wslLogged = @($newLogLines | Where-Object { $_ -like '*interface=vEthernet (WSL*;*after=Enabled' }).Count -gt 0
    if ($task.State -eq 'Ready' -and $info.LastTaskResult -eq 0 -and $vmnetLogged -and $wslLogged) { break }
} while ((Get-Date) -lt $deadline)

$info = Get-ScheduledTaskInfo -TaskName $TaskName
$task = Get-ScheduledTask -TaskName $TaskName
$storedXml = $rootFolder.GetTask($TaskName).Xml
if ($storedXml -notmatch '<BootTrigger>' -or $storedXml -notmatch '<Interval>PT10M</Interval>' -or $storedXml -notmatch '<Duration>P1D</Duration>') {
    throw 'Registered task does not contain the expected boot trigger and one-day, ten-minute repetition.'
}
$task | Select-Object TaskName, State
$info | Select-Object LastRunTime, LastTaskResult
if ($task.State -ne 'Ready' -or $info.LastTaskResult -ne 0 -or -not $vmnetLogged -or -not $wslLogged) {
    throw ('Task did not complete successfully; state={0}; last result={1}; vmnet_log={2}; wsl_log={3}' -f $task.State, $info.LastTaskResult, $vmnetLogged, $wslLogged)
}
