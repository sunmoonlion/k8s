# 专用新节点的 OS、运行时和 Kubernetes 安装

**云上未经实机验证。** 本轮完成代码、静态检查和只打印预演，没有在 WSL、东京机或 C1/C2 安装软件或启动服务。这不是旧节点原地升级工具。主锁仍不完整，真实安装被拒绝。

统一目标：只有一套部署代码和两种建群入口。本文是 kubeadm 的新主机入口；平台服务版本保持原样。KIND 使用节点镜像，不对 KIND 容器执行本页程序。

## 入口与顺序

| 步骤 | 共用控制入口 | 节点程序 |
| --- | --- | --- |
| step01_os_baseline.sh | node-step.sh → node_control.py，phase=os | os_install.py |
| step02_runtime.sh | 同上，phase=runtime | node_install.py |
| step03_k8s_binaries.sh | 同上，phase=kubernetes | node_install.py |

在 k8s 仓根目录：

```bash
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step01_os_baseline.sh --dry-run
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step02_runtime.sh --dry-run
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step03_k8s_binaries.sh --dry-run
```

三个脚本省略参数也只打印。真实执行必须显式 `--apply`；总控正式 deploy 在完整物料门禁通过后才传入该参数。总控已改为 `sync-cluster-materials --apply` 精确同步，旧全目录同步不再是集群层入口；平台物料同步仍待统一，不能宣布整个总控已可部署。

旧 step01–03 的通配符选包、在线补装、忽略错误、自动生成 containerd 默认配置、沿用旧 deb 版本的实现已替换。当前云配置仍1.30.4、主锁1.36.4，版本不符会拒绝真实执行；后续 init/join/Calico 适配完成时再成套切配置。

## 身份与控制文件

未来主机须通过可信控制台预先核对 SSH 指纹、hostname、machine-id，在 Git 外私有配置填写 `Cn_SERVER_n_EXPECTED_HOSTNAME` 和 `Cn_SERVER_n_MACHINE_ID`（32位小写十六进制）。不能安装时读取后自动接受。沿用 USER、PUBLIC_IP/LOCAL_IP、SSH_PORT、SECRET（密钥路径）、DIR；不输出口令。新主机应已设置正确 hostname，程序不会改 hostname 或覆盖 hosts。

1. 本机核完整锁、版本、全部126文件 SHA 和明确主机身份。
2. SSH 使用密钥/agent、严格 known_hosts、端口和超时；不密码重试，不沿用 WSL 代理。
3. 只经 stdin JSON/base64 发送白名单公开控制程序和锁到 `sudo -n`，不传业务源码、私钥、凭据或 kubeconfig。
4. 远端先核机器身份并拒绝 WSL/Docker/Harbor/已有集群，再发布到 `/opt/sunmoon/bootstrap/<内容摘要>/`。目录 root 所有且其他用户不可写，文件0444；已有不同内容、软链接、未知文件拒绝执行。
5. Python 用 `-B -E -s`，不写字节码，不读外部 Python 环境变量和用户 site-packages。节点程序再次核远端物料后执行一个阶段。

## OS 离线安装

目标为专用新 Ubuntu24.04 amd64、systemd/cgroup v2。发行版镜像应预装 Python≥3.11、rsync、APT/dpkg、gpgv、Ubuntu archive keyring 等自举工具；缺失就先准备匹配镜像，不在线临时安装。

- 核三个 Release 签名、索引与94包后，复制到 root 所有的 staging 目录，再核实际读取字节的 SHA。APT 不直接消费普通用户可改的包。
- APT 用隔离配置、空 sources/list、实际已装包状态，参数只给明确本地 deb，`--no-download --no-remove`。先 simulate，要求计划内包/版本均属于锁。
- 拒绝降级、未完成 dpkg 事务、foreign architecture、chrony/ntp 等竞争时钟服务；不删软件、不自动修 dpkg、不在线回退。
- 安装会执行 Ubuntu 维护脚本，可能更新系统库/systemd，因此只准入专用新节点。错误保留日志，不重复重试命令、不宣称可自动回滚系统包。
- 要求无活动 swap、fstab 无启用 swap，避免自动改磁盘配置。专用 modules/sysctl 文件有不同内容/权限/归属即拒绝覆盖。
- 核实际包版本；加载 overlay/br_netfilter、设置转发，要求 nft iptables；启动 systemd-timesyncd，并要求时钟同步成功才继续。未同步时查 NTP 可达性后再续接。
- 完成记录在 `/var/lib/sunmoon/bootstrap/<批次>-os-<OS锁摘要前缀>/complete.json`。runtime/kubernetes 要匹配同一机器、主锁和 OS 锁；仅有命令存在不算前置完成。

运行时/工具白名单见 [节点安装说明](locked-node-materials.md)。runtime 启动 containerd；kubernetes 仅 enable kubelet，等待 kubeadm。此时不代表集群就绪。

## 首次上云核对清单

1. 区分仓库主机和新集群节点，不把 Harbor/Docker 主机用于此入口。
2. 可信控制台核指纹和机器身份；确认发行版、架构、systemd/cgroup、内核模块、无swap、空间、NTP。
3. 填全各节点身份，审三个只打印结果的版本、物料根、目标和顺序。
4. 完整适配门禁通过后精确同步，核控制文件归属/权限和远端 SHA；不手改 closure_complete 赶进度。
5. 先在一台可重建新节点执行 OS，审模拟/实际日志，确认无删除/降级/APT外网下载，检查包版本、转发、nft、NTP和完成记录。
6. 再执行 runtime/kubernetes，核版本、CRI RuntimeReady、完成日志与 kubelet 状态；不越过未验收的 init/join/Calico。
7. 记录实际结果后才改“未经实机验证”。失败保留现场；若需销毁新云资源，另按所有者流程处理，不自动 reset/删卷。

旧 KIND、Harbor入口、数据和 inbox 目标未切换。后续仍需 kubeadm v1beta4、控制面镜像导入、Calico、独立Harbor/平台接线及最终清理。
