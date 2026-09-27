# SUNMOON_DATA_LAYOUT_V1
# Mount/check in PID 1 namespace; WSL elevated sessions may have private mounts.
# Local WSL; owner-run admin operation. Default: print plan only.
# No shutdown, formatting, unmount, Docker restart, or legacy-path modification.
[CmdletBinding()]
param(
    [ValidateSet('SunmoonData')][string]$Mode = 'SunmoonData',
    [string]$Distro = 'Ubuntu',
    [string]$VhdPath = 'C:\wsl-disks\sunmoon-data.vhdx',
    [string]$ExpectedUuid = '',
    [string]$CheckScript = '/home/zymun/worktrees/luna/k8s/sunmoonai/kind-infrastructure/deploy-kind/check-storage-mounts.sh',
    [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Distro -notmatch '^[a-zA-Z0-9._-]+$') { throw 'Invalid distribution name' }
if ($VhdPath -cne 'C:\wsl-disks\sunmoon-data.vhdx') { throw 'This owner-approved layout uses only C:\wsl-disks\sunmoon-data.vhdx' }
if ($CheckScript -notmatch '^/[a-zA-Z0-9._/-]+/check-storage-mounts\.sh$') { throw 'Invalid check script path' }
$StorageScript = $CheckScript -replace 'check-storage-mounts\.sh$', 'sunmoon-data-storage.py'
if (-not $Apply) {
    [pscustomobject]@{
        DryRun=$true; Mode=$Mode; Distro=$Distro; VhdPath=$VhdPath
        ExpectedUuid=$ExpectedUuid; CheckScript=$CheckScript
        Actions='verify existing UUID or attach one VHD; mount only three new fstab targets; strict read-only check'
        Protected='/data/kind-local-storage; existing containers/volumes; Docker/WSL state'
    } | ConvertTo-Json
    return
}
if ($ExpectedUuid -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') { throw 'ExpectedUuid must come from the owner-created ext4 disk' }
$Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $Admin) { throw 'Owner must run in Administrator PowerShell' }
if (-not (Test-Path -LiteralPath $VhdPath -PathType Leaf)) { throw 'VHDX does not exist; use the owner creation procedure first' }
& wsl.exe -d $Distro -u root -- test -f $StorageScript
if ($LASTEXITCODE -ne 0) { throw 'Storage helper missing; no disk was attached' }
# A present expected UUID is checked by the Linux helper for uniqueness/size/type.
& wsl.exe -d $Distro -u root -- blkid -U $ExpectedUuid
if ($LASTEXITCODE -ne 0) {
    & wsl.exe --mount --vhd $VhdPath --bare
    if ($LASTEXITCODE -ne 0) { throw 'VHD attach failed; investigate, do not blindly unmount/retry' }
}
& wsl.exe -d $Distro -u root -- nsenter --target 1 --mount -- python3 $StorageScript mount --expected-uuid $ExpectedUuid --apply
if ($LASTEXITCODE -ne 0) { throw 'Mount validation failed; do not start Harbor/KIND' }
& wsl.exe -d $Distro -u root -- nsenter --target 1 --mount -- bash $CheckScript --layout sunmoon-data --expected-uuid $ExpectedUuid --require-service-visibility
if ($LASTEXITCODE -ne 0) { throw 'Final storage guard failed; do not start Harbor/KIND' }
Write-Output 'SUNMOON_DATA_LAYOUT_V1 mount check passed. No services were started.'
