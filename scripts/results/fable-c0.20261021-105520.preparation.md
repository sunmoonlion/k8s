# fable-c0：ISO 与停机准备回执（luna）

WS=fable；准备基线 `4a7578bf05ec8efa8492a1e2faf5aa4fb98faa30`；卡仍留在 inbox/luna，尚未完成整张 C0。

结论：**准备段 pass；整张 C0 undecidable**。安装 ISO 与应答 ISO 已就绪，所有者已同意「校验通过后可以立即停机」。本回执落盘时尚未停服务、关闭 WSL、执行 fstrim 或 DiskPart；压缩实绩、恢复结果与虚拟机核对须另附后续回执，不把准备通过当作 C0 完成。

## 已完成

- 已通过 GitHub SSH 443 拉取 fable；最近远程文档提交不改变 C0 规格。
- 按卡安装 xorriso，退出 0；新增安装日志见 `fable-c0-xorriso.20261021-103444.txt`。
- `C:\iso\ubuntu-24.04.3-live-server-amd64.iso`：**3,303,444,480 字节（约 3.08 GiB）**。按卡从 Noble 官方签名清单选择第一个匹配的 24.04 live-server amd64 文件。
- SHA256SUMS、SHA256SUMS.gpg 来自 `https://releases.ubuntu.com/noble/`；`gpgv --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg` 验证 Ubuntu CD Image Automatic Signing Key (2012) 的签名通过，指纹 `843938DF228D22F7B3742BC0D94AA3F0EFE21092`。
- 系统 ISO SHA-256：`c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b`，实际完整文件校验通过。
- `C:\iso\sunmoon-prod-seed.iso`：**380,928 字节**。hostname=`sunmoon-prod`，user=`sunmoon`，IP=`192.168.80.10/24`，gateway=`192.168.80.2`，SSH 使用既有 `~/.ssh/id_rsa.pub`，禁止 SSH 口令登录。
- 随机生成了独立控制台口令，只有哈希进入应答 ISO；明文仅存在本机 `~/private/prod-vm/console-password.txt`（父目录 0700，文件 0600），供所有者本人查阅，不写入 Git、日志或本回执。
- 从生成的 ISO 回读 YAML，核对身份、SSH 公钥、IP、网关、最小盘安装选择及无未替换占位符；Netplan 在临时根目录实际 generate 通过，未应用到本机；late-commands 的 `sh -n` 通过。
- 原生 `make -C infrastructure preflight`：`ok=5 changed=0 failed=0`，退出 0，原文见 `fable-c0-preflight.20261021-104817.txt`。

## 就地修与下载执行调整

卡已授权 VM 脚本/模板中的阻断错误就地修：应答模板原先只按 `eth0` 名匹配，不能覆盖 VMware 常用的 ens/enp 命名。给这台单网卡虚拟机增加 `match: {name: "e*"}` 和 `set-name: eth0`，保持卡定的 IP、网关、规格和核对命令。按 [Netplan 官方匹配与命名规则](https://netplan.readthedocs.io/en/stable/netplan-yaml/) 执行上述实际配置生成验证；尚未在 VMware 真机应用。

初次经当前代理下载 Ubuntu 校验文件报 curl 35，单次直连取得文件并通过 GPG 校验，未改全局代理。官方站单连接下载慢，先转清华同文件断点续传，随后调整为 4 个有界 Range 请求，逐段核对 HTTP 206、Content-Range 和长度，合并后按官方签名清单验整张 SHA-256。只在最终完整文件验证后删除本次自行创建的临时分段；没有清理既有缓存、镜像、容器、卷或数据。

两次主动终止的单连接记录分别保留在 `fable-c0-iso.20261021-103548.txt`、`fable-c0-iso-tuna.20261021-103736.txt`，`exit=143`；最终完整下载见 `fable-c0-iso-parallel.20261021-104455.txt`，`exit=0`。应答生成原文见 `fable-c0-seed.20261021-1037.txt`。

## 已备好的 Windows 停机与恢复材料

固定目录：`C:\wsl-disks\maintenance\c0-20261021\`（在 Windows 盘上，关闭 WSL 后仍可执行）。

- `start-window.ps1`：先核所有者账号、批准时间（2 小时窗）、已审文件哈希与运行中的发行版范围；记录压缩前盘点；原生 preflight/status/stop；维护标记、暂停既有附盘任务、sync、两个文件系统 fstrim；再交离线 worker。
- `compact-offline.ps1`：默认只读预览。Apply 再核停服状态与文件哈希，关闭 WSL，确认无运行发行版、两块精确 VHDX 均已释放；只对原系统盘和 `C:\wsl-disks\sunmoon-data.vhdx` 执行 DiskPart compact。检查原生退出码和成功/失败文本，不能只认退出码 0。不修改盘容量、UUID、路径、服务或集群身份。
- 恢复通过既有 `sunmoon-data-mount` 任务先附数据盘再启动 Ubuntu，原生 preflight → platform-start → jenkins-start/jenkins-agent-start → platform-status → kubectl get nodes；离线压缩报错也走恢复分支。`-Recover` 只恢复，不再压缩。未经过真实停机验证，失败时保留日志、停止并按 RECOVERY.txt 排查，不冒充已恢复。
- 两份脚本 Windows PowerShell 5.1 解析通过；参数绑定、DiskPart 命令生成及 7 个服务状态空行归一化核对通过；默认预览退出 0。主机单位输出有间隔空行，已在停服判定前过滤，避免误数。
- `RECOVERY.txt`：执行、查看日志、恢复步骤。`prepared-preview.log`：只读预览原文。
- `reviewed.json`：所有者本次停机批准时间 `2026-10-21T02:49:54.350819+00:00`；worker SHA256 `90B53AFC760754947657B3D13840A234F6DEA600FF14475252B298C9F282EBBB`；launcher SHA256 `65651879E467E9C69F53482EE8C391805FBF3941EEC91ABF42C593338793A4C8`。
- 运行时 `window-before.json` 记录 trim 前 C 空闲；`before.json`/`after.json` 记录离线压缩前后；`recovered.json` 记录服务恢复后的空闲。最终以实际数值回报回收量，不保证账面约 180 GiB 全部回收。

约束自查：C-R12 新控制台口令留本机私有目录，既有身份未变；C-R13 服务启停复用原生 Make/Ansible，Windows 文件仅本次人工离线维护材料；C-R18 已明确停机、恢复和失败边界；C-R19 没有执行数据/缓存清理。

## 未完成与现场基线

- 压缩及其恢复结果：尚未执行；准备回执推回后按本次批准启动。
- Windows VMware 两个常见安装目录均未检测到 `vmware.exe`；安装与界面建机仍是卡指定的所有者操作。向所有者交付 `infrastructure/environments/prod/vm/README-vmware.md` 和上述两个 ISO 路径。
- VMware 虚拟机尚未创建，SSH、/data、32 GB/8 核及出站核对均没查。
- 当前主平台、Jenkins、入口服务在运行；`sunmoon-platform-boot.service` 已在 **09:58:10 CST** 进入 failed（ExecMainStatus=1），早于本次维护；没有因此重启或修改服务，停机恢复将按原生手动入口验实际结果。

本回执的退出码只对应准备段，不代表整张 C0 已完成。

exit=0
