# Read-only Windows allocation probe. No disks, services, tasks or files changed.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not ('SunmoonFileAllocation' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SunmoonFileAllocation {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern uint GetCompressedFileSizeW(string name, out uint high);
}
'@
}
$Vhd = 'C:\wsl-disks\sunmoon-data.vhdx'
$Item = Get-Item -LiteralPath $Vhd
if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'VHDX reparse point refused' }
[uint32]$High = 0
$Low = [SunmoonFileAllocation]::GetCompressedFileSizeW($Vhd, [ref]$High)
if ($Low -eq [uint32]::MaxValue -and [Runtime.InteropServices.Marshal]::GetLastWin32Error() -ne 0) { throw 'File allocation query failed' }
$Allocated = [uint64]$High * 4294967296 + [uint64]$Low
$Free = [int64](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
$Growth = [Math]::Max([int64]0, ([int64]230GB - [int64]$Allocated))
[pscustomobject]@{
    CheckedAt=(Get-Date).ToUniversalTime().ToString('o')
    CFreeBytes=$Free
    DataVhdLength=[int64]$Item.Length
    DataVhdAllocatedBytes=$Allocated
    TargetGiB=230
    ProjectedCFreeBytes=$Free-$Growth
    ProjectedWith22GiBMargin=$Free-$Growth-22GB
    RequiredReserveBytes=50GB
    PhysicalAllocationVerified=$true
} | ConvertTo-Json
