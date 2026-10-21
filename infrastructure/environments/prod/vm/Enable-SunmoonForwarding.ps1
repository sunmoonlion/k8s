#requires -Version 5.1
#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$LogPath = 'C:\ProgramData\Sunmoon\prod-vm\forwarding.log'
$Deadline = (Get-Date).AddMinutes(20)
$LastWaitLog = [datetime]::MinValue

function Write-ForwardingLog {
    param([Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value ('{0:o} {1}' -f [DateTimeOffset]::Now, $Message)
}

if (-not (Test-Path -LiteralPath (Split-Path -Parent $LogPath))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null
}

while ($true) {
    $ipv4 = @(Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue)
    $vmnet = @($ipv4 | Where-Object { $_.InterfaceAlias -eq 'VMware Network Adapter VMnet8' })
    $wsl = @($ipv4 | Where-Object { $_.InterfaceAlias -like 'vEthernet (WSL*' })

    if ($vmnet.Count -eq 1 -and $wsl.Count -eq 1) { break }

    $now = Get-Date
    if (($now - $LastWaitLog).TotalMinutes -ge 1) {
        Write-ForwardingLog ('waiting; vmnet8_count={0}; wsl_count={1}' -f $vmnet.Count, $wsl.Count)
        $LastWaitLog = $now
    }
    if ($now -ge $Deadline) {
        Write-ForwardingLog ('timeout; vmnet8_count={0}; wsl_count={1}' -f $vmnet.Count, $wsl.Count)
        exit 1
    }
    Start-Sleep -Seconds 10
}

foreach ($iface in @($vmnet[0], $wsl[0])) {
    $before = [string]$iface.Forwarding
    try {
        if ($before -ne 'Enabled') {
            Set-NetIPInterface -InterfaceIndex $iface.InterfaceIndex -AddressFamily IPv4 -Forwarding Enabled -ErrorAction Stop
        }
        $afterIface = Get-NetIPInterface -InterfaceIndex $iface.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop
        $after = [string]$afterIface.Forwarding
        Write-ForwardingLog ('interface={0}; index={1}; before={2}; after={3}' -f $iface.InterfaceAlias, $iface.InterfaceIndex, $before, $after)
        if ($after -ne 'Enabled') { throw 'IPv4 forwarding did not become Enabled' }
    }
    catch {
        Write-ForwardingLog ('interface={0}; index={1}; before={2}; error={3}' -f $iface.InterfaceAlias, $iface.InterfaceIndex, $before, $_.Exception.Message)
        exit 1
    }
}

exit 0
