# C0 建机通过；请接续部署卡并跟进首次开机网卡改名时序（luna → Fable）

所有者已安装 VMware Workstation Pro 26H1u1，在 GUI 完成 Ubuntu 自动安装、移除两张 CD/DVD 并重新开机。C0 基础验收通过，卡移 done；回执 `scripts/results/fable-c0.20261021-1813.md`。

本地 WSL 可直接 `ssh sunmoon@192.168.80.10`，公钥登录与 sudo -n 正常。实际资源：**1×8 核、48 GiB 内存、60 GiB 系统盘 + 300 GiB ext4 数据盘 `/data`**，UEFI、NAT VMnet8，网关 192.168.80.2。48 GiB 是会话讨论后所有者实际建成的内存，300 GiB 已由所有者明确纠正，未调回旧卡的 32 / 200。控制台口令保留本机私有目录，不进入回执。该地址是本机私网，不代表远程主机可直接访问，后续仍请派本地执行卡。

Windows IPv4 转发由所有者要求助手执行，UAC 后仅对 WSL 和 VMnet8 两接口开启并核验；SSH、固定 IP/网关、/data fstab、出站 HTTPS 跟随重定向 HTTP=200/TLSverify=0、ping 零丢包全部通过。VMware 安装包下载来源及有效 Broadcom 数字签名已在回执明确记录。

## 一个未修的启动告警

首次系统盘启动，本次唯一 failed unit 是 `systemd-networkd-wait-online.service`。事实（CST）：

- 18:02:17，networkd/wait-online 启动，生成的参数等待 eth0。
- 18:04:17，等待两分钟超时，exit=1。
- 18:04:18，networkd 才记录 **ens33 → eth0**，随后重新配置、重启 networkd。
- 当前 eth0 routable/configured/online，192.168.80.10/24 与默认路由正常，实际 SSH 与出站均可用。

生成配置来自现有单网卡模板 `match: {name: "e*"}` + `set-name: eth0`；原文含 wait-online unit/drop-in、.link/.network 的非秘密字段及完整相关 journal：`scripts/results/fable-c0.boot-network.20261021-180943.txt`。疑改名时序问题，但触发延迟改名的具体机制尚未证实。

本地没有禁用 wait-online、reset-failed、手工 netplan apply 或调整来宾 systemd；没有为复现再重启 VM，也未动 WSL/开发集群。请远程决定后续用何原生入口修启动时序、安排重启验收。此告警不影响已完成的 C0 SSH/磁盘/网络验收，但无人值守启动仍待后续验证。

VMware 操作说明同步了实际 48 GiB、1 个处理器×8 核、创建后 Add 数据盘和固件菜单位置；备用 Hyper-V 脚本未执行或改内存默认值。
