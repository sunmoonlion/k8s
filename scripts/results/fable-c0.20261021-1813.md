# fable-c0 回执：VMware 生产宿主虚拟机已建起（luna）

WS=fable，分支 fable；接续基线 `a3f999eb3`。**C0 基础建机验收通过**：所有者在 Windows GUI 安装 VMware、创建虚拟机、完成 Ubuntu 自动安装、移除两张 CD/DVD 并重新开机；本地工位 SSH、免密 sudo、两块磁盘、固定网络和出站 HTTPS 实测通过。卡移 done。

**保留一个启动告警**：第一次从系统盘启动时，networkd-wait-online 等待 eth0 两分钟超时，随后 ens33 才改名 eth0、网络正常。当前接口 online，SSH 与出站均正常；failed 记录保留，未禁用等待、reset-failed 或更改来宾网络。另交 inbox/fable 跟进，不将 C0 通过表述为生产部署或无人值守开机已验收。

## 实际规格与连接

| 项 | 已核对值 |
| --- | --- |
| Windows 虚拟化 | VMware Workstation Pro 26H1u1，26.0.1 build-25688693；WSL 同时运行 |
| 虚拟机与位置 | sunmoon-prod，`C:\VMs\sunmoon-prod\sunmoon-prod.vmx` |
| Ubuntu / 内核 | Ubuntu Server 24.04.3 安装 ISO；安装后内核 6.8.0-147-generic |
| 处理器 | 1 个处理器 × 8 核；来宾 nproc=8 |
| 内存 | 所有者 GUI 实际设 49152 MB（48 GiB）；MemTotal=50467389440 bytes，free -g 显示 47 GiB 可用总量 |
| 系统盘 | 60 GiB，sda1 为 1 GiB EFI，sda2 为 58.9 GiB ext4 根分区 |
| 数据盘 | **300 GiB**，整盘 ext4，标签 sunmoon-data，挂载 `/data` |
| 虚拟盘形式 | 两盘均 twoGbMaxExtentSparse，分段按需增长；没有立即分配全部标称容量 |
| 固件 | VMX firmware=efi，来宾 `/sys/firmware/efi` 存在 |
| 网卡 | NAT / VMnet8；MAC 00:0c:29:be:9f:13 |
| 固定网络 | eth0=192.168.80.10/24，默认网关 192.168.80.2 |
| 登录 | `ssh sunmoon@192.168.80.10`，使用既有本机 SSH 公钥；PasswordAuthentication=no；sudo -n 成功 |

内存 48 GiB 是本轮会话讨论后所有者实际创建的配置，与原卡最初的 32 GiB 不同；300 GiB 是所有者在会话中明确纠正的容量，拉回的新卡上限也已改为 300，但其操作示例与期望输出仍有旧 200 字样。本次按真实 48 GiB / 300 GiB 验收，未擅自将其调回旧值。备用 Hyper-V 脚本本次没有执行。

## ISO、安装器与 Windows 转发

- 系统 ISO：`C:\iso\ubuntu-24.04.3-live-server-amd64.iso`，3303444480 bytes，SHA256 `c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b`。完整哈希和 Ubuntu 官方签名清单校验见先前 [准备回执](fable-c0.20261021-105520.preparation.md)；本轮复用，没有重复下载或修改。
- 应答 ISO：`C:\iso\sunmoon-prod-seed.iso`，380928 bytes；既有网卡匹配就地修本次真机生效：来宾网卡命名 eth0，IP/网关保持卡定值。控制台口令未读取、未进入新回执或日志。
- Broadcom 网页账号 pending，所有者知情后使用 Internet Archive 的同版本安装包副本；Windows Authenticode=Valid，签发主体 Broadcom Inc，ProductVersion=26.0.1，SHA256 `3d775c3c2153600eef4642f95d519a514ba7e861400bda2598352bff792db473`。助手只下载与验证，安装由所有者操作。原始验证记录附在下方 host 原文。
- 安装中 `installing kernel` 长时间等待时，只读日志显示阿里云内核/固件下载，包括 112 MB Intel 无线固件、74.8 MB Marvell 固件等；所有者确认下载量继续增加。没有测得实时速度，不据此宣称镜像源稳定。安装器最终于 **17:54:44 CST** 请求正常关机，之后所有者移除 CD/DVD 再启动。
- 所有者要求助手执行 Windows 两条转发命令；管理员 UAC 确认后，仅将 VMnet8 与 WSL 两张 IPv4 接口由 Disabled 改为 Enabled，exit=0，后续再查仍 Enabled。完整脚本、前后状态、退出码见 [转发原文](fable-c0.forwarding.20261021-175953.txt)。未更改代理、防火墙、现有服务或 WSL 生命周期。

## SSH 与验收原文

首次主机密钥按卡的 TOFU 方法记录：先用 VMware Tools getGuestIPAddress、VMX MAC、Windows 邻居表将地址关联到这台唯一运行的 VM，再采集 ED25519 公钥；备份既有 known_hosts 后新增一个此前不存在的条目，未删除其他记录。之后连接均 StrictHostKeyChecking=yes。来宾读取的公钥指纹与首次记录一致：

```text
SHA256:wPjE3CPfKHi8NgXbGAilRRMJXXJWEr/4DaJzsZXdnn4
```

这是首次信任记录，不冒充独立带外的指纹核验。`known_hosts` 备份为本机 `~/.ssh/known_hosts.before-sunmoon-prod.20261021-180719`。

- [SSH 与硬件验收](fable-c0.verify.20261021-180719.txt)：主机名、用户名、sudo、UEFI、8 vCPU、48 GiB 配置对应可用内存、60 GiB 系统盘、300 GiB ext4 数据盘及标签、挂载、IP、网关均断言通过，ssh exit=0。首次非 sudo 读 cloud-init status 有配置权限警告；随后 sudo 查询无 error，cloud-init 为安装器留下的 marker 禁用状态，没有重新启用它。
- [网络与持久挂载](fable-c0.network.20261021-180813.txt)：`LABEL=sunmoon-data /data ext4 defaults,nofail 0 2` 已在 fstab；阿里云根地址先返回 301，跟随重定向后 HTTP=200、TLSverify=0，未关闭证书校验；ping 两包零丢包，ssh/ping exit=0。
- [Windows 与 VMX 元数据](fable-c0.host.20261021-181112.txt)：已装 VMware 版本、唯一运行 VM、Tools IP、MAC 对照、两接口转发 Enabled、CPU/内存/UEFI/动态盘描述及原始安装包签名结果。来宾 lsblk 没有 CD/DVD 设备。
- [开机网络等待原文](fable-c0.boot-network.20261021-180943.txt)：本次系统唯一 failed unit 为 networkd-wait-online。18:02:17 开始等待，18:04:17 超时，18:04:18 记录 ens33→eth0，随后 networkctl 显示 routable/configured/online。时间来自来宾 UTC，以上已换算 CST。疑网卡改名时序问题；触发后续改名的具体原因未证实，交远程处理。

## 本轮文件变更与边界

本轮只更新 VMware 操作说明里已实测的安装版本、处理器字段含义、48 GiB 内存、固件位置和创建后 Add 硬盘入口，并移除不能保证可用的 winget 下载示例；没有修改模板、重新安装系统或手工修来宾 systemd。先前 eth0 匹配的模板修复已在准备阶段提交，这轮只完成真实应用验收。

Windows 转发操作与后续验收已补记本机统一网络方案；来宾开机告警单独写入 inbox/fable。尚未部署 kubeadm、Harbor、Jenkins 或应用，后续继续由远程发卡、本地执行。

exit=0
