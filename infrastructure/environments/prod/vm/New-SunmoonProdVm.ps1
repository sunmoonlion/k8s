<#
生产站点的虚拟机（SDD 0039；所有者 2026-10-21 定：本地机 Hyper-V，32 GB）。
所有者在「以管理员身份运行」的 PowerShell 里执行。幂等：已有的交换机、NAT、虚拟机不重建，只报出来。
用法：
  .\New-SunmoonProdVm.ps1 -IsoPath D:\iso\ubuntu-24.04.3-live-server-amd64.iso -SeedIso D:\iso\sunmoon-prod-seed.iso
可选：-VmRoot D:\Hyper-V -MemoryGB 32 -Cpu 8 -OsDiskGB 60 -DataDiskGB 200 -Subnet 192.168.80.0/24
#>
param(
  [Parameter(Mandatory = $true)][string]$IsoPath,
  [Parameter(Mandatory = $true)][string]$SeedIso,
  [string]$VmName = 'sunmoon-prod',
  [string]$SwitchName = 'sunmoon-prod',
  [string]$Subnet = '192.168.80.0/24',
  [string]$GatewayIp = '192.168.80.1',
  [string]$VmRoot = 'D:\Hyper-V',
  [int]$MemoryGB = 32,
  [int]$Cpu = 8,
  [int]$OsDiskGB = 60,
  [int]$DataDiskGB = 200
)
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '要在管理员 PowerShell 里跑' }
foreach ($f in @($IsoPath, $SeedIso)) { if (-not (Test-Path $f)) { throw "找不到文件：$f" } }
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -ne 'Enabled') { throw 'Hyper-V 没启用：设置 → 可选功能 → Hyper-V，启用后重启再来' }

# 1 内部交换机 + NAT（固定网段，和 Default Switch 那个会变的网段不同）
$prefixLen = [int]($Subnet.Split('/')[1])
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
  $overlap = Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq $Subnet }
  if ($overlap) { throw "网段 $Subnet 已被占用（$($overlap.InterfaceAlias)），换一个 -Subnet" }
  New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
  Write-Host "建了内部交换机 $SwitchName"
} else { Write-Host "交换机 $SwitchName 已在" }
$ifIndex = (Get-NetAdapter | Where-Object { $_.Name -like "*($SwitchName)*" }).ifIndex
if (-not (Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $GatewayIp })) {
  New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $GatewayIp -PrefixLength $prefixLen | Out-Null
  Write-Host "宿主侧网关 $GatewayIp/$prefixLen"
}
if (-not (Get-NetNat -Name "$SwitchName-nat" -ErrorAction SilentlyContinue)) {
  New-NetNat -Name "$SwitchName-nat" -InternalIPInterfaceAddressPrefix $Subnet | Out-Null
  Write-Host "建了 NAT $SwitchName-nat（$Subnet 出站走宿主）"
} else { Write-Host 'NAT 已在' }
# WSL 里的助手要能 SSH 到虚拟机：宿主在两个虚拟网卡之间转发
foreach ($nic in (Get-NetIPInterface -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "*($SwitchName)*" -or $_.InterfaceAlias -like 'vEthernet (WSL*' })) {
  if ($nic.Forwarding -ne 'Enabled') { Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Forwarding Enabled; Write-Host "转发已开：$($nic.InterfaceAlias)" }
}

# 2 虚拟机：第二代、UEFI 证书模板给 Ubuntu、固定内存、两块盘
$vmDir = Join-Path $VmRoot $VmName
if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) { Write-Host "虚拟机 $VmName 已在，不重建"; Get-VM $VmName | Format-List Name,State,MemoryStartup,ProcessorCount; exit 0 }
New-Item -ItemType Directory -Force -Path $vmDir | Out-Null
$osVhd = Join-Path $vmDir "$VmName-os.vhdx"; $dataVhd = Join-Path $vmDir "$VmName-data.vhdx"
New-VM -Name $VmName -Generation 2 -MemoryStartupBytes ([int64]$MemoryGB * 1GB) -SwitchName $SwitchName -Path $VmRoot -NewVHDPath $osVhd -NewVHDSizeBytes ([int64]$OsDiskGB * 1GB) | Out-Null
Set-VM -Name $VmName -ProcessorCount $Cpu -StaticMemory -AutomaticStartAction Nothing -AutomaticStopAction ShutDown -CheckpointType Disabled
New-VHD -Path $dataVhd -SizeBytes ([int64]$DataDiskGB * 1GB) -Dynamic | Out-Null
Add-VMHardDiskDrive -VMName $VmName -Path $dataVhd
Set-VMFirmware -VMName $VmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Add-VMDvdDrive -VMName $VmName -Path $IsoPath
Add-VMDvdDrive -VMName $VmName -Path $SeedIso
$dvd = Get-VMDvdDrive -VMName $VmName | Select-Object -First 1
Set-VMFirmware -VMName $VmName -FirstBootDevice $dvd
Start-VM -Name $VmName
Write-Host "已开机。打开 Hyper-V 管理器连接 $VmName 的控制台：安装器会问「Continue with autoinstall?」，输入 yes；之后全自动，装完会自己关机。"
Write-Host "关机后回到这里跑：Get-VMDvdDrive -VMName $VmName | Remove-VMDvdDrive；Start-VM $VmName"
