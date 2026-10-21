# 用 VMware Workstation Pro 建 `sunmoon-prod`（Windows 家庭版，不动原系统）

所有者 2026-10-21：本地机是 Windows 家庭中文版，没有 Hyper-V 管理器，也不想升级。改用 VMware Workstation Pro（2024 年起个人使用免费），和 WSL2 共存。`New-SunmoonProdVm.ps1` 留给将来有 Hyper-V 的机器或云，这页是手点的清单。应答 ISO 照用（`make-seed-iso.sh`），装系统仍是全自动。

## 一次性准备（所有者）

1. Windows「启用或关闭 Windows 功能」里勾上 **Windows Hypervisor Platform**（WSL2 已经用着「虚拟机平台」，这个是给 VMware 和它共存用的），按提示重启。
2. 装 VMware Workstation Pro 17.6 或更新（Broadcom 网站注册免费账号下载，或 `winget install VMware.WorkstationPro`）。首次启动选「个人用途」。
3. 打开 VMware 的 编辑 → 虚拟网络编辑器 → 选 **VMnet8（NAT）** → 子网改成 `192.168.80.0`、掩码 `255.255.255.0` → 「NAT 设置」里网关 `192.168.80.2` → 应用。这一步要管理员权限，它会自己提示。

## 新建虚拟机（所有者，在 VMware 界面里）

| 步 | 选什么 |
| --- | --- |
| 文件 → 新建虚拟机 | **自定义（高级）**，硬件兼容性用默认最新 |
| 安装来源 | **稍后安装操作系统** |
| 客户机操作系统 | Linux → Ubuntu 64 位 |
| 名称与位置 | `sunmoon-prod`，位置 `D:\VMs\sunmoon-prod`（换盘就换路径） |
| 固件 | **UEFI**，安全引导可开可不开 |
| 处理器 | 处理器数 8（或 4×2），其余默认 |
| 内存 | 32768 MB |
| 网络 | **使用网络地址转换（NAT）**（就是 VMnet8） |
| 控制器、磁盘类型 | 默认 |
| 磁盘 | 创建新虚拟磁盘，**60 GB**，单个文件 |
| 完成前「自定义硬件」 | ① 新 CD/DVD → 使用 ISO → 选系统 ISO；② **再添加一个** CD/DVD → 使用 ISO → `sunmoon-prod-seed.iso`；③ 添加 → 硬盘 → 新建 **200 GB**，单个文件 |
| 开机 | 控制台里安装器问「Continue with autoinstall?」输 `yes` 回车。之后全自动，装完虚拟机自己关机 |
| 关机后 | 虚拟机 → 设置 → 把两个 CD/DVD 设备**移除**（或取消「启动时连接」）→ 开机 |

应答 ISO 生成时网关要写 VMware 的：`--gateway 192.168.80.2`（Hyper-V 那套是 `.1`）。

## 让 WSL 能连到它（所有者，管理员 PowerShell，两行）

```powershell
Get-NetIPInterface -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like 'VMware Network Adapter VMnet8' -or $_.InterfaceAlias -like 'vEthernet (WSL*' } | Set-NetIPInterface -Forwarding Enabled
Get-NetIPInterface -AddressFamily IPv4 | Where-Object { $_.Forwarding -eq 'Enabled' } | Select-Object InterfaceAlias
```

Windows 重启后这两处转发可能要再开一次。还是不通就把虚拟机的网络改成**桥接**（直接上家里的局域网，IP 另定），告诉远程改应答里的 IP 和网关。

## 之后

WSL 里 `ssh sunmoon@192.168.80.10` 进得去就算建好，核对项在站点 [README](../README.md)。
