param(
    [Parameter(Mandatory=$true)][string]$DataVhdPath,
    [Parameter(Mandatory=$true)][UInt64]$DataMaximumGiB,
    [Parameter(Mandatory=$true)][UInt64]$MinimumFreeGiB,
    [UInt64]$PlannedBytes = 0
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$Vhd = Get-Item -LiteralPath $DataVhdPath
if ($Vhd.PSIsContainer -or ($Vhd.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Data VHD must be a regular file, not a reparse point'
}
if ([IO.Path]::GetPathRoot($Vhd.FullName) -ne 'C:\') { throw 'This budget is for the C drive only' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SunmoonAllocatedSize {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern uint GetCompressedFileSizeW(string path, out uint high);
}
'@
[UInt32]$High = 0
[UInt32]$Low = [SunmoonAllocatedSize]::GetCompressedFileSizeW($Vhd.FullName, [ref]$High)
$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
if ($Low -eq [UInt32]::MaxValue -and $LastError -ne 0) {
    throw "Cannot read VHD allocated size: Win32 error $LastError"
}
[UInt64]$Allocated = [UInt64]$High * [UInt64]4294967296 + [UInt64]$Low
[Int64]$Maximum = [Int64]$DataMaximumGiB * [Int64]1GB
# Cast both operands: PowerShell must not pick Math.Max(Int32, Int32).
[Int64]$Growth = [Math]::Max([Int64]0, ($Maximum - [Int64]$Allocated))
[Int64]$Free = (Get-PSDrive -Name C).Free
[Int64]$Reserve = [Int64]$MinimumFreeGiB * [Int64]1GB
[Int64]$After = $Free - $Growth - [Int64]$PlannedBytes
$Report = [ordered]@{
    checked_at_utc = [DateTime]::UtcNow.ToString('o')
    c_free_bytes = $Free
    data_vhd_length = $Vhd.Length
    data_vhd_allocated_bytes = $Allocated
    configured_data_maximum_bytes = $Maximum
    future_data_growth_bytes = $Growth
    planned_bytes = $PlannedBytes
    remaining_after_growth_and_plan_bytes = $After
    minimum_free_bytes = $Reserve
    passes = ($After -ge $Reserve)
    scope = 'Configured VHD growth plus requested operation; excludes other future system disk growth'
}
$Report | ConvertTo-Json -Compress
if (-not $Report.passes) { exit 2 }
