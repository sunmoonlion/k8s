# fable-c0b 实跑回执（luna）

WS=fable，分支 fable；所有者关闭客户端后从 Windows 独立启动器运行。本次离线压缩完成，19 个原生命令均 exit=0，两个 DiskPart 均有中文成功文本，result.json 的 Success=true，PrepareError/OfflineError/RecoveryError 均为 null。未删除盘内数据，未扩大虚拟盘。

## 实际空间

采用维护前与**恢复完成后**快照比较，单位 GiB=2^30 字节；不是虚拟盘标称容量。

| 项 | 11:56:29 CST 维护前（bytes） | 12:09:13 CST 恢复后（bytes） | 差额 |
| --- | ---: | ---: | ---: |
| C 盘空闲 | 137293406208 | 254913171456 | 增加 117619765248（109.54 GiB） |
| 系统 ext4.vhdx 文件长度 | 515737911296 | 508570894336 | 减少 7167016960（6.67 GiB） |
| sunmoon-data.vhdx 文件长度 | 180493484032 | 69965185024 | 减少 110528299008（102.94 GiB） |

C 盘空闲由 127.86 GiB 增至 237.41 GiB。12:03:58 的刚压缩完快照也保留，之后启动服务带来的盘文件增长没有从结果中排除。

原始 Windows 目录：`C:\wsl-disks\maintenance\c0b-20261021\runs\20261021-115628-880\`。未改原文件。完整 SHA-256 清单、三个快照、结果、19 条退出码、两次 DiskPart 全文及恢复启动/Jenkins/节点输出见 [原文汇集](fable-c0b.20261021-1220.raw.txt)；汇集只作编码转换。两个约 700 KiB 的 platform-status 完整输出保留在该 Windows 目录，哈希包含在汇集中。

## 回连核对与额外故障

独立脚本 12:09:13 恢复检查通过；但之后 12:09:27 有 systemd 停止记录，12:09:52 再次自动恢复，12:11:41 三个节点报 Docker/runc 创建 systemd scope/cgroup 失败。停止由谁触发、scope 失败原因尚未确定，不能将本次回执当作无人值守自动启动已可靠的证明。

回连后只通过原生 `make -C infrastructure platform-preflight`、`platform-start` 恢复，两者 exit=0；未改 runtime 源码、Docker 配置或 systemd 定义，未再次关 WSL/压缩。12:13:09 三节点重新 Ready。12:17:50 核对：

- 96 个 Flux 对象全部 Ready 且 observedGeneration 与当前 generation 一致。
- 273 个 Pod 均 Ready 或已 Succeeded。
- Harbor health=200，Knowbench 首页=307，Jenkins login=200；使用平台 CA 校验 TLS，没有跳过证书验证。
- cluster、registry、entry、jenkins、jenkins-agent 均 active/Result=success。
- Windows 附盘任务 Ready、Enabled=true、LastTaskResult=0；维护标记已清除。
- `sunmoon-platform-boot.service` 保留此次 failed/ExecMainStatus=1 记录，未 reset-failed 掩盖。

原文：`fable-c0b.return-preflight.20261021-121237.txt`、`fable-c0b.return-start.20261021-121258.txt`、`fable-c0b.return-checks.20261021-121750.txt`、`fable-c0b.return-windows.20261021-1219.txt`、`fable-c0b.return-boot-journal.20261021-1218.txt`。自动启动问题另投 inbox/fable，请远程处理，当前服务可用。

## 接续 C0

VMware 尚未安装，虚拟机尚未创建；C0 卡留在 inbox/luna。两张 ISO 已准备并经先前完整校验，当前文件仍在：

- `C:\iso\ubuntu-24.04.3-live-server-amd64.iso`（3303444480 bytes）。
- `C:\iso\sunmoon-prod-seed.iso`（380928 bytes）。

已将仓内 `infrastructure/environments/prod/vm/README-vmware.md` 原文复制到 `C:\iso\README-vmware.md`（仅 UTF-8 BOM 编码处理），另放 `C:\iso\sunmoon-prod-next-steps.txt`。按 C0 卡要求由所有者安装 VMware、在 GUI 建机；规格总共 8 vCPU、32 GiB、60+200 GB 两块动态盘、VMnet8 子网 192.168.80.0/24、网关 .2、VM .10，位置 `C:\VMs\sunmoon-prod`。所有者完成后再做 SSH 核对，不宣称 C0 已完成。

exit=0
