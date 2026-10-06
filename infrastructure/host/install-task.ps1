[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$CandidateDirectory, [switch]$Apply)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Manifest = Get-Content -LiteralPath (Join-Path $CandidateDirectory 'windows-files.json') -Raw | ConvertFrom-Json
if (-not $Apply) { $Manifest | ConvertTo-Json -Depth 4; return }
$Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $Admin) { throw 'One-time task installation requires Administrator PowerShell' }
$Owner = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$Dest = [string]$Manifest.destination
if ($Dest -notmatch '^C:\\ProgramData\\Sunmoon\\platform-kind-v1\\boot-[a-f0-9]{16}$') { throw 'Unexpected immutable publication directory' }
$OldTask = Get-ScheduledTask -TaskName 'sunmoon-data-mount' -TaskPath '\' -ErrorAction SilentlyContinue
if ($OldTask -and $OldTask.State -eq 'Running') { throw 'Existing attachment task is running' }
if ($OldTask) {
    $OldPrincipal = [string]$OldTask.Principal.UserId
    if ($OldPrincipal -match '^S-1-') { $OldSid = ([Security.Principal.SecurityIdentifier]$OldPrincipal).Value }
    else {
        if ($OldPrincipal -notmatch '[\\@]') { $OldPrincipal = $env:COMPUTERNAME + '\' + $OldPrincipal }
        $OldSid = ([Security.Principal.NTAccount]$OldPrincipal).Translate([Security.Principal.SecurityIdentifier]).Value
    }
    if ($OldSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'Use the existing Ubuntu owners administrator session' }
}
if (@($Manifest.files).Count -ne 3 -or @($Manifest.files.name | Sort-Object -Unique).Count -ne 3) { throw 'Incomplete or duplicated task input list' }
foreach ($File in $Manifest.files) {
    if ($File.name -notin @('attach-storage.ps1','run-storage-hidden.vbs','request-storage.ps1')) { throw 'Unexpected task input' }
    if ((Get-FileHash -LiteralPath (Join-Path $CandidateDirectory $File.name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $File.sha256) { throw 'Candidate digest differs' }
}
New-Item -ItemType Directory -Path $Dest -Force | Out-Null
# Only Administrators/SYSTEM may write; owner may execute but cannot replace task bytes.
$Acl = New-Object Security.AccessControl.DirectorySecurity
$Acl.SetAccessRuleProtection($true, $false)
foreach ($Sid in @('S-1-5-32-544','S-1-5-18')) {
    $Acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule(([Security.Principal.SecurityIdentifier]$Sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
}
$OwnerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$Acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($OwnerSid,'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow')))
$Acl.SetOwner(([Security.Principal.SecurityIdentifier]'S-1-5-32-544'))
# Protect ancestors too; an ordinary user must not replace an elevated task's path.
foreach ($Directory in @('C:\ProgramData\Sunmoon','C:\ProgramData\Sunmoon\platform-kind-v1',$Dest)) {
    if ((Test-Path -LiteralPath $Directory) -and ((Get-Item -LiteralPath $Directory).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Refuse a reparse point in the elevated task path' }
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    Set-Acl -LiteralPath $Directory -AclObject $Acl
}
foreach ($File in $Manifest.files) {
    $Path = Join-Path $Dest $File.name
    if (Test-Path -LiteralPath $Path) {
        if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $File.sha256) { throw 'Published bytes differ; refusing overwrite' }
    } else { Copy-Item -LiteralPath (Join-Path $CandidateDirectory $File.name) -Destination $Path }
    $FileAcl = Get-Acl -LiteralPath $Path
    $FileAcl.SetOwner(([Security.Principal.SecurityIdentifier]'S-1-5-32-544'))
    Set-Acl -LiteralPath $Path -AclObject $FileAcl
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $File.sha256) { throw 'Published digest differs' }
}
$Backup = Join-Path $CandidateDirectory 'previous-mount-task.xml'
if ($OldTask -and -not (Test-Path -LiteralPath $Backup)) { Export-ScheduledTask -TaskName 'sunmoon-data-mount' -TaskPath '\' | Set-Content -LiteralPath $Backup -Encoding UTF8 }
$Action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\wscript.exe') -Argument ('//B //Nologo "' + (Join-Path $Dest 'run-storage-hidden.vbs') + '"')
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $Owner
$Principal = New-ScheduledTaskPrincipal -UserId $Owner -LogonType Interactive -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'sunmoon-data-mount' -TaskPath '\' -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
Write-Output 'Attachment task installed; logon trigger only, no recurring check. Services were not restarted.'
