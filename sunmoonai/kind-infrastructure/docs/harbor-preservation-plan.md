# 私有 Harbor 保留：现场、备份窗口与恢复顺序

日期：2026-09-26。状态：所有者已批准并完成完整冷备份，原 Harbor 服务已恢复；归档/内部 blob 校验通过，隔离恢复尚未执行。

## 1. 已完成的准备

用户要求保留私有 Harbor 的全部镜像。旧业务数据无需迁移的决定不适用于 Harbor。

- 旧集群：`~/.kube/kind-config`，命名空间 `cicd-platform-dev`，Helm release `sunmoonai-harbor`，chart `harbor-27.0.3`，Harbor `2.13.2`。
- 使用已有系统管理员权限只读分页盘点：3 个项目、64 个仓库、165 个顶层制品、164 个 tag。顶层有 28 个无标签制品；132 个索引进一步引用子清单，遍历后共 429 个仓库内制品记录。不能将子清单或证明附件当作可丢弃的无标签垃圾。
- 所有 GET 请求保留 TLS 校验；凭据只从本地 Docker 认证文件读入内存。目录是在线盘点，不能证明盘点期间无人写入；备份窗口内还需重新取得冻结目录。
- `Harbor /health` 返回 healthy。没有改变旧服务、副本、只读设置、保留策略或数据。
- 恢复输入已导出至 `~/packages-to-be-installed/releases/harbor-preserve-20260926/preparation/`：67 项相关 Kubernetes 资源、Helm values/manifest、匹配版本本地 chart，以及节点内 8 个实际启动镜像；总计约 902 MiB，逐文件 SHA256 记录在 `preparation.json`。这是恢复输入，**不是数据卷备份**。
- 私有资源与 Secret 位于上述目录的 `private/`，目录权限 0700、文件 0600；未写入 Git、未传远程。chart 源码与实际 Helm release 一并保存，恢复时以原 release 清单/配置核对差异。

目录证据：[完整制品目录](../../scripts/results/luna-harbor-catalog.20260926.complete.json)、[卷元数据](../../scripts/results/luna-harbor-preservation.20260926.inventory.json)。可重复只读入口：`../../cicd-platform/materials/harbor_inventory.py`、`harbor_prepare.py`。输出使用新路径，保留旧证据。

## 2. 真实存储与容量

| 内容 | 节点 / 路径 | 实际占用字节 |
| --- | --- | ---: |
| registry | kind-worker：`/data/kind-local-storage/harbor/registry` | 17,890,197,504 |
| PostgreSQL | kind-worker：`/data/kind-local-storage/harbor/database` | 192,745,472 |
| Redis | kind-worker：`/data/kind-local-storage/harbor/redis` | 28,905,472 |
| jobservice | kind-worker：`/data/kind-local-storage/harbor/jobservice` | 16,384 |
| 静态 Trivy 目录（当前未挂载） | kind-worker：`/data/kind-local-storage/harbor/trivy` | 4,096 |
| 实际 Trivy PVC | kind-worker2：`/var/local-path-provisioner/pvc-c0fef3d5-b9e0-46fb-8cc2-d380423897e9_cicd-platform-dev_data-sunmoonai-harbor-trivy-0` | 12,288 |

五个静态目录经 Docker bind mount 直接对应 WSL 宿主 `/data/kind-local-storage/harbor/`；实际 Trivy 位于 kind-worker2 的 Docker `/var` volume，PV 回收策略是 Delete。两处均保留，不能只备份宿主目录就宣称完整。

数据总量约 16.9 GiB；物料盘当时约 540 GiB 可用。PVC 的 20 GiB 等声明值不是实际使用量，也不代表 hostPath 有硬配额。

## 3. 已批准并执行的单元：一次完整冷备份

选择短暂停止 Harbor 写入与组件，保证数据库和镜像文件在复制期间静止。本机没有需维持对外付费服务的约束，完整冷备份较容易验证。正式恢复先保持相同 Harbor/PostgreSQL/Redis 版本，升级另行设计。

### 范围和影响

- 仅旧集群 `cicd-platform-dev` 的 7 个 Harbor 控制器：4 个 Deployment（core、jobservice、portal、registry）和 3 个 StatefulSet（postgresql、redis-master、trivy），名称统一以前缀 `sunmoonai-harbor-` 标识，当前均为 1 副本。操作使用精确资源名，不按模糊匹配批量缩容。
- 窗口内 Harbor 推送、拉取和页面不可用。已有业务容器继续运行；如果容器重建需要拉取镜像，可能暂时等待。窗口期间暂停镜像发布和依赖 Harbor 的新部署。
- 预计 10–30 分钟，以实际本机复制速度为准；45 分钟为停服阶段上限。超时或任何归档失败，保留未完成文件与日志，优先恢复原副本和原配置，不宣称备份成功。
- 不删除集群、PVC、PV、源目录或镜像；不升级组件、不切换业务入口、不执行 GC。
- 备份根为 `~/packages-to-be-installed/releases/harbor-preserve-20260926/`，新建不可覆盖的 `backup-<UTC时间>/`。本次备份增量上限 30 GiB；开始前至少 100 GiB 可用。后续恢复副本和可移植导出另计，不能用构建试验预算冒充全部恢复预算。

### 已确认后执行的顺序

1. 复核旧 API、release/版本、控制器 UID/副本数、PVC/PV/节点路径、现有健康状态和空间。保存精确的恢复清单和原 `read_only` 值；检测 HPA 或其他会重新启动组件的控制器，有冲突先停止本单元。
2. 设置 Harbor 只读，检查并等待已有推送、复制、扫描、GC 等任务结束；未能在窗口上限内静止就恢复原只读设置并退出，不强行忽略活动任务。新建冻结制品目录与配置副本。
3. 停止 jobservice、trivy 及 core/portal/registry，确认 Pod 完全退出；随后优雅停止 PostgreSQL 与 Redis。没有强制删除 Pod 或强杀数据库的自动回退。停止完成后重新记录持久化路径和冻结状态。
4. 在源节点内使用 tar 读取精确路径，将字节流直接写入宿主私有备份目录；保留数值 UID/GID、权限、符号链接和必要扩展属性。registry、database、redis、jobservice、两处 Trivy 分开归档。使用 `.partial`，命令成功、tar 可读且 SHA256 计算完成后才改为完成文件名。禁止向源目录解包或改权限。
5. 确认六份归档与冻结资源、目录、启动镜像、chart 的文件清单齐全；原始数据目录不动。即使归档失败，也按保存状态恢复：先数据库和 Redis，再 registry/core/portal/trivy/jobservice；等待健康后恢复原 `read_only` 值。原来是只读就继续保持只读。
6. 核对旧 Harbor healthy、7 个控制器恢复原副本及制品摘要/tag 清单无丢失。报告窗口实际耗时、备份大小、SHA256、失败与修复。**备份完成仍不授权清理旧环境。**

实现要求：先持久化恢复状态再修改服务；中断处理自动尝试恢复，异常退出留下可人工继续的精确命令。不能保证断电时脚本能运行，恢复指令必须脱离脚本进程保存。不要把 `finally` 当作断电恢复能力。

## 4. 冷备份后的单元：隔离恢复与可移植导出

备份确认后，形成具体恢复 manifests 与差异再实施：在新 `sunmoon-kind-136` 使用独立 namespace、独立 PV/PVC/路径和临时访问入口，禁止复用旧 PV、访问旧数据库或向旧目录写入。先恢复相同版本的 Harbor 与完整状态；再从恢复副本导出可移植 OCI 制品，为将来云端或不同 chart 提供独立恢复路径。

恢复验证必须包括：完整项目/仓库/tag/digest 对比，索引子清单与证明附件保持，实际 blob 校验/拉取、Harbor 自举不依赖旧 registry、新集群按正常 TLS/凭据拉取需要的运行镜像。目录比对相同不能替代镜像层确实可读取。

当前本机备份和源数据在同一 WSL 磁盘：可以保护集群重建过程，不能作为主机磁盘损坏时的唯一灾备副本。后续将含凭据的完整备份加密后保存到另一个由所有者选择的存储位置；本次不把私有制品或凭据上传公开下载中转主机。

依据：[Harbor 2.13 官方备份恢复说明](https://goharbor.io/docs/2.13.0/administration/backup-restore/)提示在线文件备份、后台清理和内存状态的限制。本文据本机 hostPath/Bitnami 部署选择完整停止后的备份流程，不将官方 Velero 示例直接当成本机已验证脚本。

## 5. 本次执行结果与可重复命令

所有者答复“现在执行冷备份”后，运行 `harbor_cold_backup.py`。批次名是显式目录标识；实际开始时间为 2026-09-26 14:54:48 UTC，原服务恢复于 14:59:57 UTC。停服务/归档阶段约 95 秒，包含前置与逐项恢复的整体操作约 5 分 10 秒。

```sh
cd ~/worktrees/luna/k8s/sunmoonai/cicd-platform/materials
# 此命令会停服；仅作为本次已批准操作的记录。
# 重做必须使用新目录并确认新的维护窗口，不能直接重用本目录。
python3 harbor_cold_backup.py --output \
  ~/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z

# 只读校验，可针对该批次重新执行。
python3 harbor_verify_backup.py \
  ~/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z
```

- 六份归档总计 16.85 GiB，文件 SHA256 全部复核通过。registry 内 1509 个 blob 的内容与路径摘要一致；429 个制品 manifest、1211 个描述符依赖摘要均存在。记录在备份目录 `verification.json`，SHA256 为 `d1eb514df536323a15efa33bd2e92b5baddd128daf703cd909aca7d79140a359`。
- 原 Harbor healthy，7 个控制器恢复 1/1 Ready，恢复原 `read_only=false`；无恢复警告。备份前后项目/仓库（含空项目）、tag/digest 和索引子清单一致。比较逻辑后续补充空项目覆盖，使用已保存的前后目录重新比对通过，未再次停服。
- 入口使用 Traefik 默认 TLSStore。额外保存 `ingress-platform-dev/traefik-tls-secret`、TLSStore 和本机 Harbor 客户端 CA，放入 `preparation/private/`；完整性索引 `preparation/tls-addendum.json`。Secret 内容仅存在私有备份中。
- 自动恢复入口与原副本状态保存在备份目录 `RECOVER-SERVICES.txt` 和 `state.json`。运行脚本的原始副本为 `backup-script.py`；实现入口保存在本仓 `cicd-platform/materials/`。
- [脱敏结果与归档散列](../../scripts/results/luna-harbor-cold-backup.20260926.json) 可入 Git。归档完整不证明恢复后的服务可用；未恢复到新集群、未切换入口、未删除旧数据。

同时推进的模板物料：东京主机公开下载回传 6 份文件，本机重新核验上游摘要；Node/pnpm/uv 在实际基镜像、非 root、`--network=none --pull=never` 下运行成功。本地 pnpm 包预取仍遇到 ECONNRESET，重试耗尽退出 1；没有关闭 TLS 校验或将完整构建标记为成功。
