# Existing data VHDX only; 100 -> 230 GiB. Default plan, owner-admin -Apply.
# Requires Luna's durable unmounted/backup release. No WSL shutdown or formatting.
[CmdletBinding()]
param([string]$ManifestSha256 = '', [switch]$Apply)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Published = 'C:\wsl-disks\scripts\storage-20260928-v3'
$LinuxPublished = '/opt/sunmoon/admin/storage/storage-20260928-v3'
$Vhd = 'C:\wsl-disks\sunmoon-data.vhdx'
$Uuid = 'a28de356-4ba1-4a21-93f5-744b9b9d8be0'
$Marker = 'C:\wsl-disks\sunmoon-data.maintenance'
$TaskName = 'sunmoon-data-mount'
$OldLauncher = 'C:\wsl-disks\scripts\storage-automation-20260928-v2\run-sunmoon-data-hidden.vbs'
$Launcher = "$Published\run-sunmoon-data-hidden.vbs"
$HostExe = Join-Path $env:SystemRoot 'System32\wscript.exe'
$Arguments = '//B //Nologo "' + $Launcher + '"'
if (-not $Apply) {
    [pscustomobject]@{DryRun=$true;Vhd=$Vhd;OldGiB=100;NewGiB=230;Formats=$false;StartsServices=$false;ShutsDownWsl=$false;TaskAfter='updated but disabled; maintenance marker retained'} | ConvertTo-Json
    return
}
$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$Identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as the elevated Ubuntu owner' }
if ($PSScriptRoot -cne $Published) { throw 'Run only the fixed published copy' }
$ManifestFile = "$Published\manifest.json"
if ($ManifestSha256 -notmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $ManifestFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ManifestSha256) { throw 'Manifest digest differs' }
$Manifest = Get-Content -LiteralPath $ManifestFile -Raw | ConvertFrom-Json
if ($Manifest.maximum_gib -ne 230 -or $Manifest.uuid -cne $Uuid) { throw 'Bundle identity differs' }
foreach ($Property in $Manifest.files.PSObject.Properties) {
    $Name = $Property.Name
    if ($Name -notmatch '^[a-zA-Z0-9._-]+$') { throw 'Invalid bundle member' }
    if ((Get-FileHash -LiteralPath "$Published\$Name" -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Property.Value) { throw "Bundle file changed: $Name" }
}
foreach ($Name in @('resize_data.py','sunmoon-data-storage.py','check-storage-mounts.sh')) {
    $Actual = @(wsl.exe -d Ubuntu -u root -- sha256sum "$LinuxPublished/$Name")
    if ($LASTEXITCODE -ne 0 -or $Actual.Count -ne 1 -or $Actual[0].Split()[0] -ne $Manifest.files.$Name) { throw "Linux publication differs: $Name" }
}
if (-not (Test-Path -LiteralPath $Marker) -or (Get-Content -LiteralPath 'C:\wsl-disks\sunmoon-data.uuid' -Raw).Trim() -cne $Uuid) { throw 'Maintenance marker/UUID receipt differs' }
$Task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\'
$PrincipalId = [string]$Task.Principal.UserId
if ($PrincipalId -match '^S-1-') { $Sid = ([Security.Principal.SecurityIdentifier]$PrincipalId).Value }
else {
    if ($PrincipalId -notmatch '[\\@]') { $PrincipalId = $env:COMPUTERNAME+'\'+$PrincipalId }
    $Sid = ([Security.Principal.NTAccount]$PrincipalId).Translate([Security.Principal.SecurityIdentifier]).Value
}
if ($Sid -ne $Identity.User.Value -or $Task.Principal.LogonType -ne 'Interactive' -or $Task.Principal.RunLevel -ne 'Highest') { throw 'Task principal differs' }
if ($Task.Settings.Enabled -or $Task.State -eq 'Running' -or @($Task.Actions).Count -ne 1 -or $Task.Actions[0].Execute -ne $HostExe -or $Task.Actions[0].Arguments -ne ('//B //Nologo "'+$OldLauncher+'"')) { throw 'Expected disabled original hidden task' }
if (@($Task.Triggers).Count -ne 1 -or $Task.Triggers[0].CimClass.CimClassName -ne 'MSFT_TaskLogonTrigger' -or $Task.Triggers[0].Repetition.Interval) { throw 'Task must have only the existing non-repeating logon trigger' }
$Scheduler = New-Object -ComObject 'Schedule.Service'
$Scheduler.Connect()
if ($Scheduler.GetFolder('\').GetTask($TaskName).GetInstances(0).Count -ne 0) { throw 'Existing task instance still running' }
$Capacity = & "$Published\windows-capacity.ps1" | ConvertFrom-Json
if ($Capacity.TargetGiB -ne 230 -or -not $Capacity.PhysicalAllocationVerified -or $Capacity.ProjectedWith22GiBMargin -lt 50GB) { throw 'Fresh physical C reserve insufficient' }
& wsl.exe -d Ubuntu -u root -- nsenter --target 1 --mount -- python3 "$LinuxPublished/resize_data.py" ready --apply
if ($LASTEXITCODE -ne 0) { throw 'Luna has not released the stopped/unmounted disk; no VHD change' }

$Stamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
$Receipt = "C:\wsl-disks\expand-230-$Stamp"
$Capacity | ConvertTo-Json | Set-Content -LiteralPath "$Receipt.before.json" -Encoding UTF8
Export-ScheduledTask -TaskName $TaskName -TaskPath '\' | Set-Content -LiteralPath "$Receipt.task.xml" -Encoding UTF8
& wsl.exe --unmount $Vhd
if ($LASTEXITCODE -ne 0) { throw 'Data disk detach failed; do not force detach' }
$Image = Get-DiskImage -ImagePath $Vhd
if ($Image.Attached) { throw 'VHD still attached; expansion refused' }
@(('select vdisk file="{0}"' -f $Vhd),'expand vdisk maximum=235520','exit') | Set-Content -LiteralPath "$Receipt.diskpart.txt" -Encoding Ascii
& diskpart.exe /s "$Receipt.diskpart.txt" | Tee-Object -FilePath "$Receipt.diskpart.log"
if ($LASTEXITCODE -ne 0) { throw 'DiskPart reported failure; inspect logs; do not rerun blindly' }
& wsl.exe --mount --vhd $Vhd --bare
if ($LASTEXITCODE -ne 0) { throw 'Expanded VHD retained; bare attach failed, inspect before retry' }
# Independently checks original UUID, whole-disk layout, exactly 230 GiB and no
# mounts in any Linux process namespace before e2fsck and resize2fs.
& wsl.exe -d Ubuntu -u root -- nsenter --target 1 --mount -- python3 "$LinuxPublished/resize_data.py" grow --apply
if ($LASTEXITCODE -ne 0) { throw 'Filesystem growth incomplete; retain maintenance state and hand back to Luna' }
& "$Published\attach-vhds.ps1" -Mode SunmoonData -Distro Ubuntu -ExpectedUuid $Uuid -CheckScript "$LinuxPublished/check-storage-mounts.sh" -Apply
if (-not $?) { throw 'Expanded disk mount guard failed' }

# Change the known action only. Preserve principal, settings and logon trigger;
# keep disabled until Luna verifies all file digests and original services.
$Action = New-ScheduledTaskAction -Execute $HostExe -Argument $Arguments
Set-ScheduledTask -TaskName $TaskName -TaskPath '\' -Action $Action | Out-Null
Disable-ScheduledTask -TaskName $TaskName -TaskPath '\' | Out-Null
$After = Get-ScheduledTask -TaskName $TaskName -TaskPath '\'
if ($After.Settings.Enabled -or $After.Actions[0].Arguments -ne $Arguments) { throw 'Task update readback differs' }
[pscustomobject]@{ExpandedGiB=230;Uuid=$Uuid;Mounted=$true;TaskEnabled=$false;MaintenanceRetained=$true;ServicesStarted=$false;Receipt=$Receipt} | ConvertTo-Json | Tee-Object -FilePath "$Receipt.after.json"
