# SUNMOON_DATA_LAYOUT_V1 - local Windows automation, existing disk only.
# Does not start a stopped Ubuntu, initialize/format a disk, or start services.
[CmdletBinding()]
param([switch]$Apply)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Distro = 'Ubuntu'
$DataUuid = 'a28de356-4ba1-4a21-93f5-744b9b9d8be0'
$Published = 'C:\wsl-disks\scripts\storage-20260927-v2'
$LinuxPublished = '/opt/sunmoon/admin/storage/storage-20260927-v2'
$Maintenance = 'C:\wsl-disks\sunmoon-data.maintenance'
$StatusFile = 'C:\wsl-disks\sunmoon-data-automation-status.json'
if (-not $Apply) {
    [pscustomobject]@{DryRun=$true;Distro=$Distro;Uuid=$DataUuid;MaintenanceMarker=$Maintenance;StartsStoppedDistro=$false;CreatesOrFormatsDisk=$false;StartsServices=$false} | ConvertTo-Json
    return
}
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) { throw 'The registered task requires highest privileges for the Ubuntu owner' }
$State = [ordered]@{CheckedAt=(Get-Date).ToString('o');Distro=$Distro;Uuid=$DataUuid;Result='pending';AttachedByThisRun=$false;ServicesStarted=$false}
$ResultCode = 0
try {
    if (Test-Path -LiteralPath $Maintenance) {
        $State.Result = 'maintenance-skip'
    } else {
        # Listing running distributions does not issue a launch command for Ubuntu.
        $Running = @(wsl.exe --list --running --quiet | ForEach-Object { ($_ -replace "`0", '').Trim() })
        if ($LASTEXITCODE -ne 0) { throw 'Cannot query running WSL distributions' }
        if ($Running -notcontains $Distro) {
            $State.Result = 'ubuntu-stopped-skip'
        } else {
            $Attach = Join-Path $Published 'attach-vhds.ps1'
            if ((Get-FileHash -LiteralPath $Attach -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'dc65e5f02495fac2054fd1ce3464229ce476447468571c7e243e00d33a2ab4e0') { throw 'Published attach digest differs' }
            if ((Get-Content -LiteralPath 'C:\wsl-disks\sunmoon-data.uuid' -Raw).Trim() -ne $DataUuid) { throw 'Data UUID receipt differs' }
            $Expected = @{
                'check-storage-mounts.sh' = 'be63dddb1ce85d7de949d35b2a439c25aae8b27d6c3f7e5cc8ef748105515407'
                'sunmoon-data-storage.py' = 'e542c9cdbc68abe291d5ab47af466540e632627201d7ac0d1e9e04e30fab99c5'
            }
            foreach ($Name in $Expected.Keys) {
                $Actual = (wsl.exe -d $Distro -u root -- sha256sum "$LinuxPublished/$Name")
                if ($LASTEXITCODE -ne 0 -or $Actual.Split()[0] -ne $Expected[$Name]) { throw 'Linux storage helper digest differs' }
            }
            $Check = "$LinuxPublished/check-storage-mounts.sh"
            # Capture diagnostics; the public status file contains only a fixed result code.
            $PreviousPreference = $ErrorActionPreference
            try {
                # In Windows PowerShell 5.1 native stderr with 2>&1 can become an
                # ErrorRecord. A failed guard is expected when attachment is needed;
                # inspect its exit status instead of aborting before repair.
                $ErrorActionPreference = 'Continue'
                $CheckOutput = @(wsl.exe -d $Distro -u root -- nsenter --target 1 --mount -- bash $Check --layout sunmoon-data --expected-uuid $DataUuid --require-service-visibility 2>&1)
                $CheckExit = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $PreviousPreference
            }
            if ($CheckExit -eq 0) {
                $State.Result = 'already-mounted'
            } else {
                # Recheck the maintenance marker before any attach operation.
                if (Test-Path -LiteralPath $Maintenance) { throw 'Maintenance began during check; attachment skipped' }
                & $Attach -Mode SunmoonData -Distro $Distro -ExpectedUuid $DataUuid -CheckScript $Check -Apply | Out-Null
                if (-not $?) { throw 'Existing-disk attachment failed' }
                $State.Result = 'mounted-and-checked'
                $State.AttachedByThisRun = $true
            }
        }
    }
} catch {
    $State.Result = 'failed'
    $State['Error'] = $_.Exception.Message
    $ResultCode = 1
} finally {
    $Temp = $StatusFile + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    $State | ConvertTo-Json | Set-Content -LiteralPath $Temp -Encoding UTF8
    Move-Item -LiteralPath $Temp -Destination $StatusFile -Force
    $State | ConvertTo-Json
}
exit $ResultCode
