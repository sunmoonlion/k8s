# SUNMOON_DATA_LAYOUT_V1 -- local Windows/WSL only; owner executes -Apply.
# First creation only. Existing VHDX always fails closed; never reformat on rerun.
[CmdletBinding()]
param(
    [string]$Distro = 'Ubuntu',
    [string]$LinuxScriptDirectory = '/home/zymun/worktrees/luna/k8s/sunmoonai/kind-infrastructure/deploy-kind',
    [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Vhd = 'C:\wsl-disks\sunmoon-data.vhdx'
$ExpectedBytes = [int64]230 * 1GB
$UuidFile = 'C:\wsl-disks\sunmoon-data.uuid'
if ($Distro -notmatch '^[a-zA-Z0-9._-]+$') { throw 'Invalid distro name' }
if ($LinuxScriptDirectory -notmatch '^/[a-zA-Z0-9._/-]+$') { throw 'Invalid Linux script directory' }
$Helper = "$LinuxScriptDirectory/sunmoon-data-storage.py"
if (-not $Apply) {
    [pscustomobject]@{
        DryRun=$true; Vhd=$Vhd; MaximumGiB=230; Type='dynamic, whole-disk ext4'
        Distro=$Distro; Helper=$Helper
        RequiredCFreeGiB=302; ReservedAfterGrowthGiB=50
        Order='check -> create -> unique new device/size/no-signature guard -> mkfs -> persist UUID -> setup -> check'
        Protected='/data/kind-local-storage; old containers/volumes; existing VHDX files'
    } | ConvertTo-Json
    return
}
$Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $Admin) { throw 'Owner must run in Administrator PowerShell' }
if ((Test-Path -LiteralPath $Vhd) -or (Test-Path -LiteralPath $UuidFile)) { throw 'Existing VHDX/UUID receipt: stop. Inspect and resume; never recreate or reformat.' }
$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
if ([int64]$Disk.FreeSpace -lt ($ExpectedBytes + 50GB + 20GB + 2GB)) { throw 'C: capacity guard failed (230+50+20+2 GiB)' }
& wsl.exe -d $Distro -u root -- test -f $Helper
if ($LASTEXITCODE -ne 0) { throw 'Reviewed Linux storage helper missing' }
& wsl.exe -d $Distro -u root -- test -d /data/kind-local-storage
if ($LASTEXITCODE -ne 0) { throw 'Legacy storage path missing; inspect before creating disk' }
$Before = @(& wsl.exe -d $Distro -u root -- lsblk -dnpo NAME)
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate baseline block devices' }
New-Item -ItemType Directory -Path 'C:\wsl-disks' -Force | Out-Null
$Stamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
$DiskpartFile = "C:\wsl-disks\create-sunmoon-data-$Stamp.txt"
@(('create vdisk file="{0}" maximum=235520 type=expandable' -f $Vhd),'exit') | Set-Content -LiteralPath $DiskpartFile -Encoding Ascii
& diskpart.exe /s $DiskpartFile
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Vhd -PathType Leaf)) { throw 'DiskPart failed; retain output and stop' }
& wsl.exe --mount --vhd $Vhd --bare
if ($LASTEXITCODE -ne 0) { throw 'Attach failed; VHDX retained. Do not rerun creation.' }
$After = @(& wsl.exe -d $Distro -u root -- lsblk -dnpo NAME)
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate attached block devices' }
$New = @(Compare-Object $Before $After | Where-Object SideIndicator -eq '=>' | ForEach-Object { $_.InputObject.Trim() })
if ($New.Count -ne 1 -or $New[0] -notmatch '^/dev/[a-zA-Z0-9]+$') { throw 'Not exactly one new block device; stop before formatting' }
$Device = $New[0]
$Size = (& wsl.exe -d $Distro -u root -- blockdev --getsize64 $Device)
if ($LASTEXITCODE -ne 0 -or [int64]$Size.Trim() -ne $ExpectedBytes) { throw 'New block device is not 230 GiB' }
$Layout = @(& wsl.exe -d $Distro -u root -- lsblk -nrpo NAME,TYPE $Device)
if ($LASTEXITCODE -ne 0 -or $Layout.Count -ne 1 -or $Layout[0] -notmatch '\sdisk\s*$') { throw 'Expected a whole disk without partitions' }
$Mounted = @(& wsl.exe -d $Distro -u root -- lsblk -nro MOUNTPOINTS $Device)
if ($LASTEXITCODE -ne 0 -or ($Mounted -join '').Trim()) { throw 'Device has mounts; refuse formatting' }
$Signatures = @(& wsl.exe -d $Distro -u root -- wipefs --no-act --noheadings $Device)
if ($LASTEXITCODE -ne 0 -or ($Signatures -join '').Trim()) { throw 'Device has signatures or probe failed; refuse formatting' }
& wsl.exe -d $Distro -u root -- mkfs.ext4 -L sunmoon-data -m 1 $Device
if ($LASTEXITCODE -ne 0) { throw 'Formatting failed; retain disk and inspect, never force/reformat' }
$Uuid = (& wsl.exe -d $Distro -u root -- blkid -s UUID -o value $Device).Trim()
if ($LASTEXITCODE -ne 0 -or $Uuid -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') { throw 'No valid UUID after formatting' }
$Uuid | Set-Content -LiteralPath $UuidFile -Encoding Ascii
& wsl.exe -d $Distro -u root -- nsenter --target 1 --mount -- python3 $Helper setup --expected-uuid $Uuid --apply
if ($LASTEXITCODE -ne 0) { throw 'Linux setup incomplete. UUID receipt retained; resume setup, never recreate the disk.' }
& wsl.exe -d $Distro -u root -- nsenter --target 1 --mount -- bash "$LinuxScriptDirectory/check-storage-mounts.sh" --layout sunmoon-data --expected-uuid $Uuid --require-service-visibility
if ($LASTEXITCODE -ne 0) { throw 'Final guard failed; do not start new services' }
[pscustomobject]@{Vhd=$Vhd;MaximumGiB=230;Uuid=$Uuid;Distro=$Distro;State='mounted; no services started'} | ConvertTo-Json
