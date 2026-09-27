# 集群外 Harbor、统一仓库模块与正式 KIND 存储方案

> **统一目标：以后只有一套部署代码，加上两种建集群的方式。本地把平台和应用跑通，云上除了建集群那一步，其余走的是同一条路。**

版本 0.7，2026-09-27。**100 GiB 数据盘已创建，所有者执行 v2 修复后，助手独立复核 PID 1/Docker 的挂载可见性通过。** registry-platform 已有官方 2.13.2 安装包锁与断点下载入口，包已核验；部署/恢复/SSH 模块尚未实现。未改部署开关、未安装/迁移/停服/建群，未连接云主机。R1/R4 历史回收见第 8 节，剩余清理留到最终验收。

## 1. 已确定的目标与顺序

架构分界：底层只有 KIND 与云端 kubeadm 两种建群适配器；建群后输出相同的集群名、kubeconfig、节点/存储能力和仓库地址契约，后续证书信任、入口、数据平台、认证、应用、CI/CD 与验收调用同一套模块。宿主盘、SSH 传输和本地端口分流是参数/环境适配，不复制平台/应用部署逻辑。每个拟改文件审阅时都回答“这是建群差异、环境参数，还是错误地增加了另一条部署路？”云端 steps 只编排共享模块，不能再内置第二份 Harbor/应用安装逻辑。

1. `sunmoon-kind-136` 仅作一次性验证，**本集群不承载正式数据，切换前会重建**。保留当前演练状态，不再安装平台组件。
2. 正式 KIND 名为 `sunmoon-kind-main`，1 控制面 + 2 工作节点，三个节点都配置两类独立宿主挂载：动态 local-path 和历史静态卷路径。
3. 本地与云上 Harbor 全部在 Kubernetes 之外，统一采用 **Harbor 官方 2.13.2 安装方式**，新增独立 `sunmoonai/registry-platform/` 模块。一个执行核心，local/SSH 只决定传输与执行位置。
4. 本地部署位置是 WSL；云上是明确配置的独立仓库主机。目前没有云服务器，云上仅统一代码和离线演练，明确标注“未经实机验证”。
5. 外部仓库名始终是 `harbor.sunmoonai.com:30443`。保持域名、外部端口、现有证书与制品镜像引用不变；本地由 TLS 直通代理按 SNI 分流，云上独立仓库主机直接监听此端口，无须该代理。
6. **先完成宿主机 Harbor 和入口代理的部署、迁移、验证，再创建正式集群**；新集群只是仓库使用方。
7. 当前旧集群、旧 Harbor、冷备份继续保留。新 `harbor-restore-20260926` 的 8 个控制器保持 0，六卷保留，不直接晋升正式实例。**旧 kind-worker2 不得删除**，它上面的沙箱卷需独立保留。

“同版本”指 Harbor 保持 2.13.2；Bitnami chart 切换官方安装包仍涉及布局、配置与运行身份变化，不能把旧数据库数据目录直接挂到新镜像。升级另开单元。

## 2. 实际磁盘归属与挂载设计

### 2.1 当前磁盘事实

2026-09-27 在沙箱之外只读执行 findmnt/lsblk；[原始记录](../../scripts/results/luna-storage-entry-inspection.20260927.json)。

| 路径 | 实际来源 | 结论 |
| --- | --- | --- |
| `/` | `/dev/sdd`，ext4，约 1 TiB | WSL 发行版系统盘 |
| `/data` | 同一 `/dev/sdd` | 普通系统盘目录 |
| `/data/kind-local-storage` | 同一 `/dev/sdd` | 旧卷也在 WSL 系统盘，并非独立数据盘 |
| `/data/kind-clusters` | 目前不存在 | 若按现状新建，将落在上述 WSL 系统盘 |
| `/var/lib/docker` | `/dev/sdd[/var/lib/docker]` | 仍与系统盘同一设备 |
| `/mnt/pv-kind-ext4` | 无该挂载 | 历史 VHD 数据盘流程当前未启用 |

系统盘 UUID 为 `693faed3-cebb-473e-81ae-fd88f1fc76b4`；设备名可能变化，后续以 UUID/实际 mount 复核。`/etc/fstab` 当前只有未配置提示。现有配置 `KIND_PV_STORAGE_MODE=native` 与上述事实一致。随后 Windows 只读查询已确认该 WSL VHDX 位于 C 盘，见第 2.3 节。

所有者已决定新建独立 VHDX，见第 2.3–2.6 节；上表只记录改变前的事实。**禁止在旧 `/data/kind-local-storage` 上挂载任何东西**，也不迁移或遮蔽其现有内容。新的虚拟数据盘与 WSL 系统盘都在宿主 C 盘同一块物理硬盘上，不能防硬件故障。

### 2.2 正式 KIND 六条挂载

每个节点的宿主子目录独立，节点内路径保持部署包要求：

| 节点 | 动态卷宿主目录 → 节点内 | 静态卷宿主目录 → 节点内 |
| --- | --- | --- |
| control-plane | `/data/kind-clusters/sunmoon-kind-main/control-plane/local-path` → `/var/local-path-provisioner` | `/data/kind-clusters/sunmoon-kind-main/control-plane/static` → `/data/kind-local-storage` |
| worker | `/data/kind-clusters/sunmoon-kind-main/worker/local-path` → `/var/local-path-provisioner` | `/data/kind-clusters/sunmoon-kind-main/worker/static` → `/data/kind-local-storage` |
| worker2 | `/data/kind-clusters/sunmoon-kind-main/worker2/local-path` → `/var/local-path-provisioner` | `/data/kind-clusters/sunmoon-kind-main/worker2/static` → `/data/kind-local-storage` |

示意片段，尚未应用：

```yaml
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: /data/kind-clusters/sunmoon-kind-main/control-plane/local-path
        containerPath: /var/local-path-provisioner
      - hostPath: /data/kind-clusters/sunmoon-kind-main/control-plane/static
        containerPath: /data/kind-local-storage
  - role: worker
    extraMounts:
      - hostPath: /data/kind-clusters/sunmoon-kind-main/worker/local-path
        containerPath: /var/local-path-provisioner
      - hostPath: /data/kind-clusters/sunmoon-kind-main/worker/static
        containerPath: /data/kind-local-storage
  - role: worker
    extraMounts:
      - hostPath: /data/kind-clusters/sunmoon-kind-main/worker2/local-path
        containerPath: /var/local-path-provisioner
      - hostPath: /data/kind-clusters/sunmoon-kind-main/worker2/static
        containerPath: /data/kind-local-storage
```

静态卷继续使用 `/data/kind-local-storage/postgresql`、`redis`、`redis-nodebull`、`mongodb`、`neo4j`、`object-storage`、`casdoor` 等路径。Harbor 历史 `/data/kind-local-storage/harbor/...` 清单保留，但新正式集群不部署 Harbor，也不把宿主 Harbor 数据目录挂入任何节点。

仓库静态 PV 的 `nodeAffinity` 存在写死 `kind-worker` 的条目（包括 PostgreSQL、Casdoor）。未来渲染必须改成实际 `sunmoon-kind-main-worker` 等目标，按组件明确落点；不能只换 extraMounts 后沿用旧节点亲和性。同一节点内路径在三个节点映射不同目录，不能靠跨节点重新调度找回原卷。保留控制面污点，分别核对 StorageClass、provisioner 路径、UID/GID、PV Retain 策略与数据库恢复方法，不使用递归 777。

### 2.3 C 盘容量与新数据盘

2026-09-27 10:21（Asia/Shanghai）刷新后的只读结果见 [容量与用量记录](../../scripts/results/luna-data-disk-sizing.20260927.json)；较早路径盘点见 [容量记录](../../scripts/results/luna-data-disk-capacity.20260927.json)：

| 项目 | 当前值 |
| --- | --- |
| Windows C 盘总量 / 剩余 | 924.38 GiB / **231.96 GiB**（剩余 249,066,225,664 字节） |
| Ubuntu 系统 ext4.vhdx 文件逻辑大小 | **480.45 GiB**（515,879,469,056 字节） |
| Ubuntu ext4 文件系统已用 | **459.00 GiB**（492,848,263,168 字节） |
| Ubuntu ext4 文件系统显示可用 | 496.64 GiB；这是虚拟文件系统余量，**不能替代 C 盘实际剩余量** |

系统 VHDX 位于 `C:\Users\zymun\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx`。文件 Length 不是精确 NTFS 实际分配量，未据此声称完成了稀疏占用测量；C 盘 free 是本轮容量上限判断的依据。

新盘固定为 `C:\wsl-disks\sunmoon-data.vhdx`，动态扩展、**上限 100 GiB（所有者本轮明确决定）**，ext4，整盘文件系统；所有者已创建，UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`；运行时按 UUID 定位，不绑定 `/dev/sde`。

```text
C:\wsl-disks\sunmoon-data.vhdx
  → UUID=<创建后记录> → /mnt/sunmoon-data
      ├─ kind-clusters/ → bind /data/kind-clusters
      │                    └─ sunmoon-kind-main/<节点>/{local-path,static}
      └─ harbor/        → bind /data/harbor
```

用量采用 `du -x -B1` 的实际分配字节，避免把稀疏文件逻辑长度当已占用空间。统计时未停服，是容量快照，不是数据库一致性备份。

| 用量 | 实际字节 / GiB |
| --- | --- |
| 旧 `/data/kind-local-storage` 总计 | 18,453,749,760 / **17.186 GiB** |
| 其中 Harbor | 18,116,395,008 / 16.872 GiB（已含在上行，不能重复相加） |
| 旧 worker 动态 local-path | 237,010,944 / 0.221 GiB |
| 旧 worker2 动态 local-path | 21,168,128 / 0.020 GiB |
| 数据基线合计 | 18,711,928,832 / **17.427 GiB** |
| Harbor 冷备份完整批次 | 18,093,715,456 / **16.851 GiB**（归档逻辑长度 18,093,661,241 字节） |

以全部旧静态数据 + 两个 worker 动态卷作为保守数据基线，即便部分业务最终全新初始化也不先扣减：`17.427 × 3 = 52.281 GiB`；向上取整并留文件系统余量，最初建议上限 60 GiB；**所有者本轮决定改为 100 GiB**，提供更大的增长余量。冷备份继续在新数据盘之外单独保存，因此不重复计入新盘承载数据。若改成把该冷备份也放进新盘，口径会变成 `(17.427 + 16.851) × 3 = 102.834 GiB`，需重新审定，不能把 100 GiB 视为仍满足该扩大后的三倍口径。

按当前 C 盘剩余计算，新盘长满 100 GiB 后仍约剩 `231.96 − 100 = 131.96 GiB`，**没有假设删除旧数据或缩小 WSL 系统 VHDX**。目前冷备份已计入 C 盘已用；再额外保留一份同等备份，约剩 115.11 GiB，仍超过 50 GiB。实际创建前重新测量，必须满足 `C盘剩余 − 批准上限 − 新增备份/临时文件预算 − VHDX元数据余量 ≥ 50 GiB`，不满足就停止，不能靠清理用户数据凑数。

建议另外计入 20 GiB 新备份/临时预算和 2 GiB 元数据余量，100 GiB 方案静态预测仍留 109.96 GiB。后续 Windows/WSL 其他写入可能改变容量：监控 C 盘余量，低于 80 GiB 告警，按预计写入量执行 50 GiB 保底门禁；新数据盘低于 20 GiB 告警、低于 10 GiB 停止新增大批次。动态 VHDX 删除文件后不保证立即归还宿主空间，不把“上限不预分配”等同于“不会耗尽 C 盘”。

### 2.4 沿用现有挂载流程，但先改掉旧目标

主入口继续使用仓库 `kind-infrastructure/deploy-kind/attach-vhds.ps1`、开机/登录计划任务与 `deploy-kind/check-storage-mounts.sh`。`mount/` 中现有备查副本应变成明确转发/弃用提示，避免保留两套会漂移的逻辑。

**旧版 attach 曾写死 E 盘并卸载旧目录，本轮已替换该入口，历史代码保留在 Git 历史中。**现行 `SUNMOON_DATA_LAYOUT_V1` 默认打印计划，只有所有者明确加 `-Apply` 才处理新盘。mount/ 两个入口转发到 deploy-kind 的同一实现。新增 `sunmoon-data-storage.py` 执行 check/setup/mount，setup/mount 默认只打印；不会格式化、卸载、启动 Docker 或关闭 WSL。创建/格式化单独由所有者执行 `initialize-sunmoon-data.ps1 -Apply`，已有盘一律拒绝重新创建。

检查入口扩展新模式：

- 新盘必须是期望 UUID 的 ext4，设备号不同于根文件系统；两个 bind 的设备/inode 与各自源子目录一致，不能仅因目录存在就通过。
- `/data/kind-local-storage` 的实际来源及目录身份与操作前一致；禁止把它加入新 fstab 或 attach 目标。
- 三节点六条挂载和实际 nodeAffinity 一起验；磁盘缺失/只读/空间不足立即失败，不能 fallback 为系统盘普通目录。
- 所有新 Harbor 与新 KIND 启动路径先经过该检查。systemd 依赖真实 mount + Docker；防止 Docker restart policy 在挂盘之前自动拉起这些新容器并写错盘。新容器启动由受挂载门禁约束的服务管理，不改变旧节点的当前策略。
- `nofail` 仅允许 Ubuntu 在盘未附加时启动排障，不允许 Harbor/新 KIND 绕过检查启动。未挂载时宿主目标目录保持空，不自动初始化数据。

### 2.5 两层备份与范围

| 层 | 范围 / 目的 | 保存与恢复 |
| --- | --- | --- |
| 同盘备份 | 数据库一致性导出、对象存储、Harbor 完整 registry/逻辑库/配置/密钥、`~/private`；防误删和升级失败 | 版本化批次可存 WSL 系统盘的 `~/private/backups/sunmoon/<批次>`，与新 VHDX 分开但物理盘相同；空间门禁、校验、恢复演练、明确保留期；不声称防硬盘故障 |
| 机器外备份 | **仅数据库、对象存储、`~/private`** | 落点待所有者定：移动硬盘，或客户端加密后上传对象存储；尚无外传授权，不新增云账号/费用 |

机器外范围中的数据库包括 Harbor/Casdoor/业务数据库，以及需要持久化的 Redis 等；密钥/证书的规范备份放在 `~/private`，确保 Harbor 加密密钥进入该范围。Harbor 镜像层、Docker 缓存和普通包归档不自动纳入机器外层；物理盘全损时，仅有此范围外的本地镜像将无法凭这层备份恢复，这个范围限制要记录。

预留接口：`backup plan --scope databases,object-storage,private`、`backup export --target <external-disk|encrypted-object-store>`、`backup verify`、`backup restore --into <隔离目录>`（尚未实现）。配置只记录目标引用、加密公钥/密钥获取方法和凭据文件引用，不打印秘密。归档根目录、临时目录与目标目录必须在排除表中，避免备份 `~/private` 时递归包含历史备份。外部加密的恢复密钥须另由所有者保存，不能只放在被加密的同一备份里。

### 2.6 所有者本人执行的管理员 PowerShell 步骤

完整、可直接粘贴的命令统一维护在 [所有者 100 GiB 数据盘操作卡](owner-data-disk-100g.md)，包含固定版本脚本发布及 SHA256、首次创建/格式化/挂载、计划任务和中断续接。旧的内联创建/fstab 命令由该卡替代，避免两套实现漂移。

执行顺序：先发布四个固定脚本到 Windows 和 root 所有的 `/opt/sunmoon/admin/storage/storage-20260927-v2`，首次才运行创建脚本。本机已有 VHDX，第 2a 节修复已执行并复核通过：在 PID 1 挂载空间执行附盘检查，并核对 Docker 可见性；不要再次创建/格式化。正确后再注册附盘任务。任何哈希/容量/UUID/挂载冲突都停止。现有 RemoteSigned 拒绝直接执行 UNC 未签名脚本，因此卡中先本地发布；不调整系统执行策略，仍被拒绝时由所有者处理签名。

本轮完成 PowerShell Parser、bash -n、ShellCheck、Python AST，以及 Linux 只打印/缺盘拒绝/旧 native 检查；[只读证据](../../scripts/results/luna-data-storage-preparation.20260927.json)。**所有者已执行创建/格式化及 v2 挂载修复，助手从普通 WSL 会话复核通过；[实测结果](../../scripts/results/luna-data-storage-v2-mounted.20260927.json)。计划任务和重启验收未完成。**新 Harbor/KIND 启动服务与挂载门禁的集成尚待后续单元，不把检查脚本存在等同于服务已受保护。

首次管理员附盘依据 [Microsoft WSL 文档](https://learn.microsoft.com/en-us/windows/wsl/wsl2-mount-disk)。自动任务用发行版所属用户，登录前执行不保证；旧任务如仍引用旧脚本须先审查。重启验收与手动压缩并入入口切换窗口，当前不关闭 WSL。旧路径不得叠挂新盘；机器外备份落点仍待所有者决定。

## 3. 独立仓库模块：拟建结构与接口

**以下文件和命令是待实现设计，不是当前已存在的运行入口。**

```text
sunmoonai/registry-platform/
  README.md                         # 版本、部署/备份/恢复、云端未经实机验证
  registry-platform.sh              # plan / prepare / install / verify / backup / restore
  lib/config.sh                     # 校验显式配置；不从 master IP 推导仓库主机
  lib/runner.sh                     # 唯一执行边界：local / ssh / dry-run
  lib/harbor.sh                     # 官方离线包及 prepare/install/Compose 生命周期
  lib/backup-restore.sh             # 逻辑库、registry 全目录、密钥/证书和清单
  config/local-wsl.example.conf
  config/cloud.example.conf
  templates/harbor.yml.tmpl          # 不存凭据；生成文件留私有工作目录
  templates/local-sni-proxy.conf     # 仅本地入口；云端不用
  artifacts.lock.json               # 2.13.2 包、镜像、Compose、代理等摘要
  docs/first-cloud-checklist.md
```

所有者已授权修改 `sunmoonai/infrastructure/`。本轮“继续”已推进存储准备代码；以下仓库模块及云端接线尚未实现，不能把设计接口当可执行命令。

### 3.1 参数与职责

| 参数组（拟定） | 内容 |
| --- | --- |
| `REGISTRY_TRANSPORT` | `local` 或 `ssh`，不维护两套安装逻辑 |
| `REGISTRY_SSH_HOST/USER/PORT/IDENTITY_FILE` | 独立仓库主机；云端必填，私钥仅文件引用，不上传私钥 |
| `REGISTRY_PRIVATE_IP/PUBLIC_IP` | 集群可达地址；优先私网，不能缺项后猜第一个 master |
| `REGISTRY_ADDRESS/EXTERNAL_URL` | 固定 `harbor.sunmoonai.com:30443` / `https://harbor.sunmoonai.com:30443` |
| `REGISTRY_VERSION` | 固定 `2.13.2`，应用版本升级拒绝隐式发生 |
| `REGISTRY_INSTALL_ROOT` | 例如 `/opt/sunmoon/registry/harbor-2.13.2` |
| `REGISTRY_DATA_ROOT` | 本地 `/data/harbor`（绑定到新数据盘），与所有 KIND 卷隔离 |
| `REGISTRY_BACKUP_ROOT` | 独立批次目录；另配置异机/独立介质复制目标 |
| `REGISTRY_CERT_FILE/KEY_FILE/CA_FILE` | 现有证书和私钥的私有文件引用，内容不写日志/提交 |
| `REGISTRY_BIND_ADDRESS/HTTPS_PORT` | 本地 `127.0.0.1:18443`；云端明确主机地址和 `30443` |
| `REGISTRY_LOCAL_SNI_PROXY` | 本地 true，云端 false |
| `REGISTRY_SECRET_INPUT_DIR` | 受限权限的秘密输入目录，仅读取指定文件 |

云端各 C1/C2/C3 可引用同一仓库主机配置；若处在不同网络，分别配置对同一逻辑域名的可达解析。代码统一不等于现在已有云仓库或跨环境自动同步。禁止环境切换时把本机 `127.0.0.1` 写进云节点。

### 3.2 官方安装与独立生命周期

使用官方 `harbor-offline-installer-v2.13.2.tgz` 的 prepare/install/Compose 流程，先锁定离线包及来源校验、全部自举镜像和宿主 Docker/Compose 版本；不依赖将要迁出的 Harbor 来提供唯一自举副本。安装包及可选签名获取方式见 [官方安装文档](https://goharbor.io/docs/2.13.0/install-config/download-installer/)，版本源见 [v2.13.2 发布](https://github.com/goharbor/harbor/releases/tag/v2.13.2)。

同一脚本在本机运行或将经过校验的必要模块/物料发送到明确 SSH 主机后运行。远程临时目录、锁、SHA 校验、原配置备份、实际目标身份和步骤结果均持久化；SSH 严格主机校验、有界超时、不自动修改 sudo 权限。迁移数据、私钥只能发送到获准的仓库主机，不能使用公开下载中转缓存。

新目标的 `harbor.yml` 指定 data_volume、原 TLS、external_url；本地内部监听 18443 不得改变 token realm、重定向或制品引用中的外部 30443。[官方 2.13.2 配置模板](https://raw.githubusercontent.com/goharbor/harbor/v2.13.2/make/harbor.yml.tmpl)支持 external_url 和外部数据库。生成 Compose 如需限制回环绑定，必须审阅合并结果，不能因追加 override 留下原来的全网监听。

## 4. Bitnami 27.0.3 / Harbor 2.13.2 迁往官方同版本

### 4.1 必须分开处理的输入

| 输入 | 迁移方法与门禁 |
| --- | --- |
| PostgreSQL | 同一冻结时点逻辑导出/导入，保留 schema、数据、序列、所有者/必要角色与权限；不直接搬旧 PGDATA |
| registry 层与清单 | 复制实际 filesystem root 的完整内容，保留 blob、repository links、manifest/index、附件和引用结构；按逐件摘要验证 |
| core 加密密钥 | Bitnami `core.secretKey`（实际挂到 `/etc/core/key`）原字节带走，映射到官方生成配置的实际密钥路径，不能自动生成替代 |
| token 签名材料/内部共享秘密 | 盘点 core token key/cert、core/jobservice 共享秘密、registry HTTP secret 等，逐项映射和验证；不能只复制 TLS 证书 |
| 外部 TLS | 沿用原证书链、CA、私钥，验证内容指纹；不得重新签发来掩盖配置问题 |
| 配置与身份 | 保留项目、仓库、tag、robot/用户、配额、保留规则、复制规则等；验证密文可解密及原凭据可用，日志只输出结果 |
| Redis/作业/扫描 | 盘点队列和历史日志；冻结/排空作业，禁止重放破坏性队列。目标重新建立运行缓存，原 Redis/日志/Trivy 快照留存；恢复策略写明，不能默默丢弃 |

**数据库版本门禁：**现场 PostgreSQL 镜像为 `bitnami/postgresql:17.6.0-debian-12-r4`。官方 Harbor 2.13.2 安装包内数据库主版本尚未实机确认，不能默认兼容。优先方案是使用官方 Harbor 的 external_database 配置，另起集群外、独立目录的 PostgreSQL **17.6**（固定已核验镜像摘要），逻辑恢复后接入 Harbor；这仍是官方 Harbor 部署，避免暗中降级数据库。若最终选择安装包内数据库，必须先证明其版本/扩展兼容且恢复演练通过，再审阅确定，不自动 fallback。

导出工具应匹配源 17 系列，实际 `pg_dump --version`/服务端版本进入收据。`pg_dump -Fc` 保存应用数据库，角色/授权另行受限保存并映射；恢复到新建空库，任何 SQL/pg_restore 错误均失败。不能强行恢复到低版本再忽略错误；参见 [PostgreSQL pg_dump 文档](https://www.postgresql.org/docs/17/app-pgdump.html)。

### 4.2 迁移与备份顺序（待实施批准）

1. 从实际旧实例刷新全目录、版本、存储与私有配置清单，核验现有冷备份仍可读；429 条制品等历史数量只作基线，不硬编码成最新数量。
2. 先准备独立目标与离线物料，在备用端口/独立网络演练。禁止对当前停用的新集群恢复副本进行改造。
3. 正式导出窗口：暂停推送、复制/扫描/清理/GC/upload purge 等写入方，等待在途任务结束，记录原副本数和开关。仅开 read_only 不足以冻结后台写入；必要时停 core/registry/jobservice 写入组件，数据库保留用于导出。
4. 保持同一冻结窗口取得逻辑数据库、registry 最终增量和秘密快照，记录每份 SHA256、源目录/挂载及文件清单。第一次预复制可在线进行，但不作为最终一致性备份。
5. 新目标先起独立数据库，导入到空库；放置 registry、原密钥与证书，按目标容器真实 UID/GID 赋权。官方 prepare 不得覆盖原密钥，启动前检查实际挂载路径和字节指纹。
6. Harbor 先只读启动，后台复制/GC等保持停用。验证全部项目/仓库/顶层和子清单/附件/tag/digest，逐个校验 blob 与引用；兼容 OCI 与 Docker manifest/index 的 Accept 类型。仅查数量、随便 pull 一个镜像都不够。
7. 在隔离客户端网络使用原域名/SNI/30443 访问候选代理，验证 token realm、TLS、权限和实际未缓存摘要拉取；不改全局 hosts。完成全部只读对比后，在明确的试验项目验证 push/pull/delete 和所需后台任务，保留新建测试制品的差异记录。
8. 完成入口接管后再开放业务写入，且只有新实例可写。旧实例保留冻结状态和冷备份，保留期由实施卡明确。任务规则启用必须逐条审阅，不能恢复后直接运行原清理任务。

全目录摘要验收采用冻结输入的完整规范化目录 + 原始 manifest/blob SHA；Harbor DB 采用逻辑结构、行数/关键关系和应用 API 语义校验，不要求不同 PostgreSQL 实例的物理文件哈希相同。还需证明原 robot/加密配置可用，所有秘密内容留在私有目录。

### 4.3 备份恢复与回退

仓库模块长期备份至少包括：Harbor 版本和镜像摘要、逻辑数据库、完整 registry、密钥/证书、生成前配置及实际 Compose、作业/扫描状态说明、文件清单和恢复收据。同盘保存完整恢复批次；机器外只备份数据库、对象存储、`~/private`，按第 2.5 节的所有者范围执行，不默认外传完整镜像层。先独立恢复验证，不删旧冷备份。

**开放新写入前**可以停止候选并恢复原入口/原 Harbor 副本与开关；**开放写入后**不能直接切回旧库丢弃新写入，必须再次冻结并完成增量/反向恢复方案。Compose 停止不得附带删 volume，数据目录不递归清空；密钥丢失不能靠重置密码恢复。

## 5. 本地 30443 TLS 直通入口

### 5.1 最终拓扑

```text
客户端 https://<域名>:30443
  → WSL 宿主 TLS/SNI 直通代理 :30443（不解密、不持有业务私钥）
     ├─ harbor.sunmoonai.com → 127.0.0.1:18443 → 宿主 Harbor TLS
     └─ 其他域名 / 无 SNI   → 127.0.0.1:19443 → 正式 KIND Traefik NodePort :30443
```

代理建议使用带 stream/ssl_preread 模块的固定版本 NGINX，安装方式、离线包/镜像摘要在实施卡锁定；技术依据是 [NGINX ssl_preread](https://nginx.org/en/docs/stream/ngx_stream_ssl_preread_module.html)。配置核心为 SNI 精确匹配 Harbor、default 指向 Traefik；不用 HTTP Host 重写、不终止 TLS、不注入 PROXY protocol。长时间镜像上传及 WebSocket/流式应用所需超时需实测。

正式集群 extraPortMappings 将**节点 30443 映到宿主 127.0.0.1:19443**，不能再次占用外部 30443。外部域名/端口/证书均不变，18443/19443 只是内部下一跳。代理自启动须在 Docker/WSL 网络就绪后；Harbor 内部端口仅回环可达，外部监听范围不能比既有规则扩大。回环、WSL、Windows 到入口和 KIND 节点到宿主地址分别验收，节点不能把 Harbor 解析为自己的 127.0.0.1。

TLS 终止仍在 Harbor 与 Traefik，沿用各自证书；推拉认证 URL 不得泄露内部端口。云端独立仓库主机由 Harbor 自身 TLS :30443 直接服务，不部署此 SNI 分流层。

### 5.2 现有端口占用：必须独立审批的维护影响

现场 `docker port kind-control-plane` 显示 `30443/tcp → 0.0.0.0:30443`。无法让新宿主代理同时绑定同一地址/端口，也不能通过修改 kind YAML 给已有节点动态移除端口。当前控制面还发布宿主 80、30444、30445、30446，直接停止它会同时影响这些入口和旧 Kubernetes API。

**本方案建议的过渡方式，尚未获实施授权：**先在备用端口完成宿主 Harbor 和候选代理验证；在明确的整体维护窗口内暂停旧发布/沙箱控制任务，保留全部旧节点和数据，停止（不删除）旧 `kind-control-plane` 释放端口，再由宿主代理接管 30443。非 Harbor TLS 暂转旧 worker 的 NodePort；现场 Traefik `externalTrafficPolicy=Cluster`，需在停控制面前确认工作节点实际可达。若要保持 80/30444/30445/30446，可为这些原有入口另设简单 TCP 过渡转发，目标为对应旧 worker NodePort，实施卡列出后才执行；否则必须明确停服范围，不能声称其他入口不受影响。

**旧 API 不可用是这一方案的真实代价。**依赖 API 的沙箱创建/控制、调度和发布不可保证继续，已有 Pod/NodePort 转发也只作短时过渡。旧 worker2 不停止、不删除；保护其 Docker `/var` volume，禁止 prune。若所有者不能接受控制面维护影响，则先停在候选验证状态，另审旧控制面端口迁移方案；不能静默修改 Docker 内部元数据或重启整个 daemon。

维护卡应为每个阶段设置超时与恢复人；压缩与入口切换合并一个所有者操作窗口，预计整体 60–90 分钟（需现场确认）；压缩后端口接管/验证失败的回退上限 30 分钟，失败则停新代理/过渡监听、启动原控制面、恢复旧 Harbor 和入口并核验原 UID。正式集群建群是后续单元；仅在代理/Harbor 已验证且旧 API 停机期间的业务安排获准后开始，不以“等建完再说”无限延长维护。

此处记录的是可评审的停服方案，不是现在要求停止旧控制面。实际执行前还必须审阅精确转发配置、当前节点 IP、服务依赖、冷备份、恢复命令与维护窗口。

## 6. 云端基础设施与所有集群使用方改造（代码计划）

### 6.1 统一仓库消费开关

批准实施后修改 `cicd-platform/deploy-cicd-platform-all/deploy-cicd-platform-all.conf`：

```sh
C1_harbor_enabled="false"
C2_harbor_enabled="false"
C3_harbor_enabled="false"
KIND_harbor_enabled="false"
```

全部镜像仓库逻辑地址使用 `harbor.sunmoonai.com:30443`；云集群解析到独立仓库主机，KIND 解析到 WSL 可达入口。配置改变**不得触发卸载当前 Harbor**。现有集群内脚本/chart 保留，头部（chart 用合法 YAML 注释）加：

> 历史路径，云上新路径实机验证前不删。

需同时审查 `step13`、KIND 总入口及直接 deploy-harbor 调用，不能只关总配置仍从另一入口安装。旧路径手动用于回退必须明确选择历史模式，不能作为缺少新配置时的自动 fallback。保留旧离线自举镜像及备份，不因新流程不使用就清理。

### 6.2 infrastructure 修改位置与步骤顺序

| 文件/入口 | 拟修改内容 |
| --- | --- |
| `deploy-infrastructure-all/deploy-infrastructure-all.conf` | 新增独立仓库主机、SSH、地址、目录、版本、物料/证书引用与是否管理仓库的配置；无云主机时留明确未配置值，执行模式失败关闭 |
| `steps/step10_registry_platform.sh`（新文件，名称待代码审阅） | 在 step11 前调用 registry-platform；先验配置/离线物料/已有证书，再显式 install/verify；已经部署的共享仓库只核验，不由每个集群重复初始化 |
| `steps/step11_load-initial-images.sh` | Harbor IP/域名/端口读取仓库主机配置；去掉默认 master IP 与 `.local` 兜底；仍保留 Kubernetes 自举镜像离线导入；新路径不再为集群预装 Harbor 组件 |
| `steps/step13_ingress_and_harbor.sh` | 新路径只装入口；建议新建 `step13_ingress.sh`，旧文件保留历史标注，新总入口不调用其中 Harbor 部分。失败应向上返回，不只 log_warn 后报完成 |
| 两个总入口 `.sh` 与 `-menu.sh` | 同步 steps 数组、单步路由、菜单/帮助、包需求收集与演练；不能只修改其中一个 |
| `utils/common.sh` / 配置映射公共入口 | 新仓库配置和 dry-run 透传；影响到的共享函数单独审阅 |

拟执行顺序为：原 step00–step10 → **仓库证书前置只读校验 + registry-platform** → step11 节点镜像/仓库信任配置 → step12 其余证书工作（不得轮换已被仓库使用的 CA）→ step13 入口。需核对现有 step12 为“生成/轮换 CA”，不能让仓库部署依赖一个未来步骤才生成的证书：本次复用已有证书；新云环境缺证书则在 registry 步骤前单独获准签发，不运行隐式轮换。原 reset 步骤也不能因执行总入口被自动授权。

仓库自举不依赖 Kubernetes step11：官方安装器、运行时与镜像先送至仓库主机。节点使用独立物料启动，再从已验仓库拉取；避免“仓库等节点镜像、节点镜像又等仓库”的循环。step02 和 step11 中任何 registry mirror/CA 逻辑需核对最终新配置，证书缺失立即失败，不启用 insecure。

### 6.3 dry-run 必须真正不执行

云端 SSH 执行及步骤顺序代码的脚本头部和 README 均标注 **“未经实机验证”**。计划接口示例（待实现）：

```text
registry-platform.sh plan --config <配置> --transport local --dry-run
registry-platform.sh install --config <配置> --transport ssh --dry-run
CLUSTER=C1 deploy-infrastructure-all.sh --dry-run
```

演练只解析经校验的非秘密配置，在 stdout 输出顺序、目标、路径、命令形态和需要的秘密引用；不执行 ssh/scp/rsync/sudo/docker/kubectl/curl、不开端口、不建目录、不 chmod、不探测远端、不改 known_hosts。预检也必须走同一 dry-run 边界，不能先 source 带副作用脚本再决定不执行。秘密不放命令参数/日志；路径参数使用数组和明确引用，不使用 eval 拼接。

批准写代码后需取得实际结果：所有新增/修改 shell 通过 `bash -n` 与 `shellcheck`，local 与 C1/C2/C3 的 dry-run 明确打印 registry 在 step11 前、step13 只有入口、各集群 Harbor 开关 false；在无服务器、无凭据条件下也能产生计划或明确缺项，不能暗中联网。**当前没有新脚本，所以本轮不宣称这些检查已经通过。** 静态/演练通过也不能去掉“未经实机验证”。

### 6.4 首次上云核对清单

- 确认实际仓库主机、SSH host key/权限、CPU 架构、Docker/Compose 版本、数据盘 UUID/挂载和空间；不能照抄本地 `/dev/sdd`。
- 固定实际包/镜像摘要、传输校验；确保自举不依赖现有集群或公网临时下载。
- 核验 FQDN、证书 SAN/链/有效期、私钥权限、外部 URL 与 30443；单独仓库主机无 SNI 代理，数据库/Redis 端口不公开。
- 核验安全组和路由：每个 C1/C2/C3 节点、CI builder 到仓库可达；优先私网；DNS/hosts 不指向 master 或 WSL。
- 首次在空的独立目录部署并验 health、TLS、认证、push/pull/delete、digest；用独立 namespace/测试项目，不能拿业务库试错。
- 核验节点 containerd 对正式域名的 CA/config_path 真正生效，实际未缓存 digest 拉取且重启后持久；禁止跳过 TLS。
- 实际跑云端 registry-before-step11 和 ingress-only step13，确认菜单/单步/总流程一致、失败中断、幂等不会覆盖数据或重新生成密钥。
- 完成逻辑备份 + registry + 密钥的隔离恢复和全目录摘要比对、独立介质复制，以及断点、空间不足、SSH 中断后的人工恢复检查。
- 确认宿主自启动和维护/回退窗口；无外网时既有批次仍可恢复。记录云环境独有实际证据后，才审阅移除未验证标记与历史路径保留限制。

## 7. 分单元实施与交付门禁

| 单元 | 交付 | 当前状态 |
| --- | --- | --- |
| P0 方案审阅 | 本文、磁盘/端口事实、范围与停服方案 | 总体方向已定，新增决定已同步；本轮另完成明确批准的 R1/R4 回收，部署未执行 |
| P1 统一代码与离线物料 | registry-platform、四环境关闭集群内安装、云 steps/dry-run、bash -n/shellcheck 证据、历史标记、存储脚本适配 | 已完成新数据盘脚本及只读检查；registry-platform、集群消费配置、云接线/物料仍待完成，无云端实操 |
| P1b 数据盘 | 所有者本人创建/附加 C 盘 VHDX，验证两条新 bind、启动门禁、备份接口 | 管理员操作由所有者执行；须在导入 Harbor 和建正式集群前完成 |
| P2 本地候选恢复 | 同版本官方 Harbor，PG17 逻辑恢复、密钥映射、全目录摘要及备用入口验证 | 待批准独立目录/容器/迁移演练 |
| P3 本地入口维护 | 新冻结备份、所有者关闭 WSL/压缩、挂载复核、30443 接管与原端口影响处理、TLS/全部域名/推拉/回退验证 | 需精确实施卡与停服批准；不能默认停止旧控制面 |
| P4 正式 KIND | sunmoon-kind-main 六条挂载、静态 PV 节点亲和性、正式 registry 信任与实际拉取 | 必须 P3 通过后；建群不是业务切换 |
| P5 平台与业务 | 空库初始化、业务入口切换、CI/CD，最后业务 E2E | 另列方案；Harbor 镜像与沙箱保留要求继续有效 |

创建正式集群后记录新的 kube-system UID、独立 kubeconfig 和版本匹配 kubectl，再更新 inbox 门禁。此前当前业务 inbox 仍指向旧 `kind`；进入 P3 控制面停机窗口时必须暂停，不能让远程助手继续向不可用 API 发版。

本轮交回文件、实际当前集群与工具路径见 [交接说明](luna-handoff-and-inbox-targets.md)。本轮只有存储准备脚本和只读检查落地；registry-platform、云配置改造、迁移和云代码测试尚未完成，停服切换须遵守实施卡。


## 8. WSL 回收与所有者最新决定

详见 [空间回收与压缩方案](wsl-space-reclamation-plan.md)。所有者批准 R1 的 ≥7 天档和 R4 的 7 个已比对副本，本轮已复核并执行：375 条构建缓存约 5.947 GiB、7 文件约 0.547 GiB，ext4 总净下降 6.487 GiB。R1 其余 479 条因清理过程中父缓存时间刷新及依赖保留，没有放宽年龄限制。

R2 分为 105 个 Harbor 同摘要应用镜像及 244 条专属缓存（去重估算 34.514 GiB），以及其余 100 个镜像（35 个有核验来源、65 个未证实来源）；**宿主 Harbor 恢复并通过全目录摘要比对后才可实施 R2**。R3 取消。试验工作目录等远程助手审过分支后再定；冷备份、正式物料、所有容器和卷继续保护。

严禁 docker system prune、docker volume prune、docker container prune 及等效容器/卷删除。压缩与入口切换并入 P3 同一维护窗口，由所有者执行；不开启 WSL 自动收缩/稀疏化。记录 VHDX Length、C盘 free、Linux used 和数据/入口验证，当前没有压缩或切换。100 GiB 数据盘预算不依赖未兑现的压缩收益。

长期措施含 Harbor 保留规则先 dry-run/保护当前和回退摘要、独立 GC 窗口，以及构建结束后仅回收本任务临时物和受预算控制的缓存。机器外备份范围仍严格是数据库、对象存储和 ~/private。

所有者随后明确：**剩余清理统一放在迁移与验收结束后，且必须执行**。最终收尾须按空间方案第 8 节逐项结清并重新盘点；现在不再追加清理。R3 取消与容器/卷保护不变。压缩仍并入入口切换由所有者操作；最终清理如果晚于该窗口，其 Linux 回收与宿主返还分开报告，不能擅自再关闭 WSL。
