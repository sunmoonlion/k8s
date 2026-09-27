# Luna 工作检查点

**最新单元（2026-09-27 04:30 UTC）：官方 Harbor 配置准备完成。** `registry-platform/harbor_inputs.py` 已向 `/data/harbor/candidates/harbor-2.13.2-20260927` 写入原密钥/TLS/凭据；`official_prepare.py` 生成配置并复核。第一次在镜像 User 空串/null 比较处退出，修正后通过显式 `--resume-import` 继续；已完成目录不可重跑。生成器已停止，无网络/端口/匿名卷，43 卷不变、旧 Harbor healthy。官方 Compose 尚未准入运行，不可直接 up。下一步准备具体恢复运行配置、registry 层复制与逻辑数据库导入、全目录摘要验收；未启动宿主 Harbor，未切入口或清理。代码基线 a6e299d84efca31c6c017d2a792f6e0e1e593f96，交付为包含本记录的本地 luna 提交。详细步骤及失败记录见 `sunmoonai/registry-platform/docs/config-preparation.md`。用户询问内部证书 5 年有效期，已确认现叶证书到 2027-06-22、根 CA 到 2036-05-07；建议迁移核对后统一续签，未签发/替换或旋转 CA。下面为此前单元记录。

**当前单元（2026-09-27）：所有者批准“你执行”，PostgreSQL 17.6 冷备份逻辑恢复演练已完成。** 49 表/10,364 行、结构/权限/角色口令哈希/序列/扩展/large objects 一致；3 个新容器停止并保留，旧 7 容器/43 卷未变，旧 Harbor healthy。新盘副本占 182,140,928 字节，私有 dump/角色文件不入 Git。证据 `sunmoonai/scripts/results/luna-registry-database-rehearsal.20260927.json`，执行卡同模块 docs 下。不要重新执行已有批次。下一步准备官方 Harbor 2.13.2 的配置/密钥映射、registry 数据恢复和完整摘要验收；尚未安装 Harbor/切入口/改云接线。剩余清理最终必须做，禁止容器/卷清理仍有效。下文为历史记录。


当前单元：独立 KIND A/B、Harbor 冷备份及只读隔离恢复、模板前后端物料 T0–T4 均完成。物料原始下载失败已由公开归档路径解决；本次通过应用产物/后端静态构建检查，未组装生产 OCI 镜像或完成 CI/CD。正在交回本地 luna 单元；后续方向已由所有者确定，统一部署/独立数据盘/集群外 Harbor 的方案已获总体同意及补充决定；本轮仅实施明确获批的 R1/R4，部署/迁移/附盘/入口切换未执行。
实施基线 `bee0b049ca9e84fead641928816fec4a6a1c6c48`；交付提交是包含本检查点的 `luna` 提交（用 git log 定位）。

## 决定与边界

- 当前主要在本机 KIND，面向将来云端；不按付费试运营立即部署云端。
- 用户要求先了解现场、讨论方案、确定后实施；不必机械执行 fable 原任务次序。
- 批准 Kubernetes 1.36.4 / KIND 0.33.0 / Calico 3.32.2，保留旧 kind/入口/数据。
- 允许 txy-tokyo 下载公开物料并回传；没有远程建群或清理远程服务授权。
- 国内云也不保证下载公共镜像；后续 CI/CD 需内部物料供应与失败恢复设计，尚未实施。
- 所有者原有“基础软件离线包 + Harbor 预存镜像”方式继续保留；明确缺口是 Git 源码与 npm/Python 依赖供应。先检查实际依赖，再讨论内部仓库与同步方案，不先安装新平台。
- 业务端到端测试最后做；本次网络/PVC 检查是基础设施验收。
- 所有者最新确认：旧业务数据无需保留，业务全新初始化。**私有 Harbor 镜像数据必须保留**：默认覆盖全部现存制品及其 registry、数据库、配置、Secret/证书和存储恢复依赖；不能缩减为当前运行镜像。已完成冷备份、首轮隔离只读恢复和新节点实际拉取，但尚未导出可移植制品、切换入口或批准删除旧环境。旧 Harbor/相关卷/目录/必要缓存继续保留。
- 所有者先批准“现在执行冷备份”，随后以“按方案实施”批准 `harbor-isolated-restore-plan.md` 的明确恢复单元，包括只重启新 worker2 的 containerd 及回滚。两单元均完成；不包含迁移入口、后台作业启用或清理旧数据。
- 所有者要求编写《物料提交备齐方案和方法.md》，可直接交给 AI 准备物料和 CI/CD；试验通过后再更新为可复用的方法。现已按模板限定范围完成 T0–T4，并将手册更新为 0.3；全项目和 CI/CD 仍未通过。
- 手册仅维护在 k8s 的 `sunmoonai/kind-infrastructure/docs/`，按所有者要求不保留家目录副本。
- 所有者明确要求：本次迁移（新环境全新初始化与切换，不迁移旧业务数据）成功后，必须回头完善手册，以实际命令、版本、故障修复与验收证据固化经验，便于下次 AI 复现；此项是本次工作的收尾交付，未完成不能宣称整体收尾。

## 证据与恢复

[交付记录](sunmoonai/scripts/results/luna-kind136.20260926-2200.md) 包含命令、校验值、失败与修复、最终验收和边界。
最终原始验收：`/home/zymun/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64/verification-20260926T220335.json`。原始输出在同批次 `logs/`。
家目录统一网络规则：`/home/zymun/网络管理统一方案.md`。
新集群 kubeconfig `~/.kube/sunmoon-kind-136.config`；旧环境 `~/.kube/kind-config`。
验收命名空间和 PVC 留在新集群；不要把已有集群自动删建。

## 下一步

Harbor 结果：`sunmoonai/scripts/results/luna-harbor-cold-backup.20260926.json`；完整目录 `luna-harbor-catalog.20260926.complete.json`；方案 `sunmoonai/kind-infrastructure/docs/harbor-preservation-plan.md`。3 项目、64 仓库、165 顶层/429 含子清单制品、164 tags；6 份数据归档共 16.85 GiB。备份根 `~/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z`。`state.json` 保存恢复状态，`verification.json` 校验 1509 个 blob、429 个 manifest 与 1211 个层/config/子清单依赖摘要；隔离恢复 false。

服务恢复于 2026-09-26 14:59:57 UTC，7 个控制器均恢复 1/1 Ready、Harbor healthy、read_only=false，前后目录含空项目/仓库比对一致，无恢复警告。六份卷是停服后复制；输入和归档私有配置未入 Git。入口 TLS 额外依赖 `ingress-platform-dev/traefik-tls-secret`，已在 `preparation/private/` 保存，清单 `preparation/tls-addendum.json`。本机备份与源数据同磁盘，不是独立介质灾备。

隔离恢复方案 `sunmoonai/kind-infrastructure/docs/harbor-isolated-restore-plan.md` 已实施。原私有 59 资源清单在 `restore-plan-20260926/manifests-private.json`，SHA256 `3aef6e503b50786915931ab7b70da819de7f428bdee09a686e71ab44d17f0239` 保持不变；运行期精确网络补丁另存。新 namespace `harbor-restore-20260926`，worker 上独立 `/var/local-path-provisioner/harbor-restore-20260926/` 六目录；8 个固定 amd64 自举镜像已离线导入。**不要重新运行 prepare 或覆盖这些数据。**

本轮执行入口 `materials/harbor_restore.py`、`harbor_restore_verify.py`。原始证据在 `~/packages-to-be-installed/releases/harbor-preserve-20260926/restore-run-20260926/`，脱敏结果 `sunmoonai/scripts/results/luna-harbor-isolated-restore.20260926.json`。15:25 UTC 开始、15:44 读取验证及回滚通过，15:53:33 最终复核，约 28 分钟，小于 60 分钟窗口。容量保守上界 23.31 GiB（含两个节点原有全部 containerd 数据），小于 30 GiB；剩余 500.87 GiB。

结果：全部 3 项目/64 仓库/429 含子清单制品/164 tags 及元数据与备份一致；worker2 缓存原先不存在的 Node 摘要经新 TLS 域名实际拉取，启动 v24.18.0；网络负例和 registry 重建后读取通过。新副本 8 控制器为 0、无 Pod，6 PVC Bound/PV Retain；port-forward 关闭。worker2 原配置/hosts 按 SHA256 恢复，临时 CA 项撤回、containerd 重启后 RuntimeReady/NetworkReady，新三节点及 Calico Ready。旧 Harbor 7 控制器 Ready、healthy、read_only=false、完整目录不变。Service/独立存储保留，临时入口不在服务。

失败与修正：缺少 certs.d 父目录导致第一次中止；补齐目录与部分回滚。校验 HTTP Accept 缺少 OCI 单清单导致 404，旧环境对照复现后修正。worker2 经 VXLAN 的实际源为 `10.245.175.64`，原策略未含此地址；用 route/conntrack 确认后只追加该 /32 → 网关 8443，镜像拉取从超时恢复为成功（2.82 秒）。修正和历次失败 acceptance 均保留。验证脚本已固化路由/接口核对，最终单独验证幂等路径后网关停回 0。

恢复节点中断操作前先读 `trust.json` 和脚本 README；文件与本轮写入摘要不符时不强行覆盖。当前 trust.restored=true，无待处理回滚。下次恢复读取演练不能复用“原先未缓存”的断言，因为该 Node 镜像现在已缓存。

现场发现并已纳入方案：core/jobservice 原 hostAliases 指向 `101.126.151.0`，已在新清单删除；原有两条手动复制策略和两个清理类定时任务。首轮 jobservice 保持 0，只验证数据/镜像读取链路，不能宣称后台任务或全套 health 通过。出站限定本 namespace 和 DNS，registry upload purge 关闭，Trivy 禁联网更新。

恢复渲染发现原资源备份遗漏动态 Trivy PVC/PV 的元数据（instance 标签不一致），但其数据已归档校验。已按原绑定补读到 `preparation/private/storage-addendum.json`，校验与原因在 `preparation/storage-addendum.json`；renderer 已纳入。`harbor_prepare.py` 改为沿真实 Pod 的 PVC 引用补全元数据，未重跑冷备份。不要改写历史备份时点的事实。

构建物料试验批次：`~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`；入口在 `sunmoonai/cicd-platform/materials/`。已通过东京主机取得并以 rsync 回传 6 份公开工具文件，62,737,201 字节，复核 pnpm SRI/PyPI SHA256/Node 校验清单并登记 `preparation.json`。Node 24.18.0、pnpm 10.24.0、uv 0.11.32、Python 3.12.13 在实际基镜像的无网络非 root 临时容器中运行通过。远程磁盘阈值已改为 8 GiB，私有源码未上传。

本地 `materials.py packages` 在前端 pnpm fetch 阶段因 npm 官方源 ECONNRESET 有界重试后退出 1；日志 `evidence/20260926T225021131846.log`，命令信息为同名 JSON。后端包步骤未开始。已保存清单和独立缓存，可继续准备；工具通过不代表依赖闭包已齐。下一次可检查公开依赖清单后利用已授权远程中转，不能上传私有源码或应用凭据。

按 [物料操作手册](sunmoonai/kind-infrastructure/docs/物料提交备齐方案和方法.md) 生成执行卡，确定具体试验范围后，以模板前后端完成源码/子仓恢复、pnpm/uv/工具链物料与禁公网构建验证，再接真实 CI/CD。
[下一阶段方案](sunmoonai/kind-infrastructure/docs/production-readiness-next-plan.md) 保存平台全新初始化、可观测性与旧环境清理的顺序。业务 E2E 最后，云端包与旧部署脚本尚未升级。
不得把 A/B 通过写成整个项目达到生产标准。只本地提交，不 fetch/pull/rebase/push。


## 2026-09-27 当前交回与新约束

所有者要求本轮结束时明确改动文件、后续 inbox 集群/kubeconfig/kubectl，远程助手待所有者回传分支后审阅。本地提交，不 push；不主动向 inbox 或外部助手发消息。完整交接见 `kind-infrastructure/docs/luna-handoff-and-inbox-targets.md`（实际在 sunmoonai 下），逐文件清单一并保存。

所有者最新提醒已纳入：**sunmoon-kind-136 是一次性验证环境，不承载正式数据，切换前会重建**。当前不再往里面安装组件；正式化前要确定宿主挂载。旧 kind-worker2 无宿主目录挂载，沙箱持久卷在容器内部，禁止删除该节点容器。原“旧业务数据不保留”不能用来覆盖这一限制。新 Harbor 恢复副本 8 控制器继续为 0，六卷保留，不作为正式镜像源。所有者已选定本地与云上均在集群外运行 Harbor，本地为 WSL；不自动执行迁移。

方案 `sunmoonai/kind-infrastructure/docs/storage-and-harbor-placement-decision.md` 已按所有者决定更新：sunmoon-kind-main 三节点各挂 local-path 与 static 两目录，后者节点内保持 `/data/kind-local-storage`。上层部署代码统一，仅 KIND/kubeadm 两种建群适配；本地/云端 Harbor 都移出集群，官方 2.13.2，同版本逻辑库/registry/密钥恢复，云端仅统一代码、dry-run 与静态检查。仍只写方案，未获新代码、重建/迁移/清理执行授权。现有验收 PVC 数据在节点容器内，Pod 重建保留不代表节点删除持久。

业务 inbox 当前仍指向旧 kind：`~/.kube/kind-config`，匹配客户端 `~/packages-to-be-installed/releases/kubectl-1.27.3-existing-kind-linux-amd64/bin/kubectl`，UID `5d71ab3a-ea5a-4535-adc6-d7698d820249`。新验证环境 `~/.kube/sunmoon-kind-136.config`，客户端 `~/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64/bin/kubectl`，UID `f5b11e20-1428-48a0-8c7a-51bc9ef27896`。默认 PATH 工具不匹配，须显式选择；不改门禁预期 UID。只读现场快照 `sunmoonai/scripts/results/luna-handoff-clusters.20260927.json`。

模板离线构建结果 `sunmoonai/scripts/results/luna-materials-offline.20260927.{md,json}`。756 npm + 58 Python wheel，814 文件/276,598,294 字节，清单 SHA256 `decd851f3c4fa5721afa8c89d57325492dcad49be10c6dd379999dae406e55bb`。原锁不改，模板 Web 前端干净生产构建/standalone，后端离线安装/ruff/format/pyright/compileall 均通过；缺包、有效 ZIP 错误哈希、修复后成功及受控下载中断均通过。私有源码未上传，远程仅公开清单和下载/中断脚本。入口及完整方法在 `cicd-platform/materials/README.md`（sunmoonai 下）。

原始证据：批次根 `~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`；正例 `work/offline-trial-1790472978821158770/result.json`，负例 `work/offline-negative-1790473394048549144/result.json`，中断 `evidence/public-download-interruption.json`。首个损坏样本被 ZIP 检查拒绝，改成有效 ZIP comment 后明确 Hash mismatch；旧失败日志都保留。HTTP 半文件重取、完整文件复用；rsync 负责回传断点。

批次逻辑文件共约 4.02 GiB，低于 30 GiB；本机剩余约 496.64 GiB。结束时无本轮材料临时容器。原始归档不删，副本及历史日志保留；代码可 revert，无本单元集群回滚。管理前端只归档未构建；没有生产 Dockerfile 改动、OCI 发布、数据库/单元/E2E 测试、内部 Git/包仓或 CI/CD。下一步在所有者决策后推进正式存储与 Harbor 实施方案，不能直接沿旧文档将一次性验证集群晋升正式环境。


## 所有者最新存储决定与容量（2026-09-27 10:21）

拟新建 C:/wsl-disks/sunmoon-data.vhdx 动态 ext4 数据盘，挂 /mnt/sunmoon-data，分别 bind /data/kind-clusters 和 /data/harbor。**禁止在旧 /data/kind-local-storage 上挂载任何东西。**管理员 PowerShell 创建/附盘由所有者本人执行，方案包含完整审阅稿命令；现有 attach 脚本含旧 E 盘与旧路径卸载逻辑，不得直接执行。新脚本需沿用既有入口并扩展严格 UUID/挂载检查、启动门禁与开机/登录计划任务。

上限不固定 100G：实际静态数据 17.186 GiB、旧两 worker 动态卷合计 0.240 GiB，基线 17.427 GiB；三倍 52.281 GiB，**建议 60 GiB 待审**。Harbor 冷备份 16.851 GiB 单独留在新盘之外，不重复计入承载量。C 盘空闲 231.96 GiB；WSL 系统 VHDX 文件逻辑大小 480.45 GiB，ext4 已用 459.00 GiB。新盘长满 60 GiB、不回收任何旧数据时静态预计余 171.96 GiB；另留新备份/临时预算和元数据余量，创建前与运行期仍须守住至少 50 GiB。原始记录 `sunmoonai/scripts/results/luna-data-disk-sizing.20260927.json`。

新数据 VHDX 与系统 VHDX 在同一 C 盘物理硬盘，不防硬件故障。同盘备份防误删/升级失败；机器外只备数据库、对象存储、~/private，落点待所有者选移动硬盘或客户端加密对象存储；不外传、不创建资源。统一架构目标与全部后续改动清单以方案开头为准。本轮只做了只读调查和方案更新，没有执行方案中的 PowerShell、挂载、停服或部署。


## 新增只读空间盘点与回收方案

所有者要求解释 WSL 已用约 459 GiB 并逐项审批回收。新增 `sunmoonai/kind-infrastructure/docs/wsl-space-reclamation-plan.md`。严格禁止 docker system/volume/container prune 及任何等效的容器/卷清理；停止旧节点仍是观察期回退保障。回收顺序为构建缓存、宿主未引用镜像、节点未用镜像、离线物料/重复备份；每项给预算、影响和恢复依据，不自动实施。压缩要关闭 WSL，由所有者另开维护窗口；记录前后 VHDX Length/C盘free/Linux used，长期措施为 Harbor 保留与构建缓存生命周期。

Docker 只读 API 已得：2220 条构建缓存记录共 194.03 GiB，其中 158.04 GiB 与镜像共享，不能当全部可清。排除共享/InUse、7 天未用候选 854 条共 29.68 GiB，清单 `luna-build-cache-candidates.20260927.json`，未批准。宿主 208 镜像中 205 个未被宿主容器引用，仍须扣除 KIND/Harbor/离线与回退依赖；不能自动全部删除。六个运行节点与一个原有停止容器均保留。

全根 du 首轮超过 180 秒停止，改用有界分目录扫描；只停止了本轮对应 du 进程，未动服务。目录与 Docker/CRI 记录在 scripts/results/luna-{wsl,docker}-space-inventory.20260927.json。所有空间结果均为在线只读快照，不是新冷备份，也不代表清理/压缩已经完成。


空间回收盘点收尾：目录实际 du 为 home 88.25 GiB（含物料40.07 GiB）、Docker目录92.18 GiB（其中卷90.98 GiB，禁止清理）、usr11.16 GiB。containerd逐文件扫描120秒超时，不伪造其du总量；Docker API完整层记录245.29 GiB。宿主未引用镜像独有层合计59.41 GiB、节点未命中CRI引用记录合计41.52 GiB，均尚未扣系统/回退/自举保留集合，不能作为确定可回收量，也不能与缓存简单相加。

明确候选：R1 ≥7天、非共享、非InUse缓存29.68 GiB（若≥30天为27.66 GiB，两者包含）；R4七个独立inode重复文件全SHA相同0.547 GiB，清单 `luna-duplicate-materials-candidates.20260927.json`；审阅后可再生成的试验工作目录约3.12 GiB，保留结果/日志后才可提请删除。当前Harbor冷备份和正式物料建议回收0。所有候选未批准，未执行任何清理/压缩/停服。Docker/CRI盘点过程未启动原有停止容器。

交付机械检查：Python AST语法及新增JSON解析通过，git diff --check通过；前述获准模板T0–T4实际正负例已通过。统一部署/云SSH/dry-run/新挂载/压缩代码仍仅是方案，不能说bash -n或shellcheck验收过尚未编写的脚本。家目录网络手册已补§19记录实际离线物料结果与待审方案入口，没有改变运行配置。


## 本轮获批回收与 100 GiB 决定（2026-09-27）

本单元基线 c8b3ce6efb7bbb247917c728d6e94b0807f01f28。所有者批准 R1 ≥7 天档、R4 七个重复文件，明确 R2 必须在宿主 Harbor 恢复全目录验收后，R3 取消；试验目录待远程助手审分支后再定。另明确动态数据盘上限改为 **100 GiB**，更新主方案 PowerShell 为固定 100；创建仍由所有者本人操作。此前 60 GiB 待审文字均为历史建议，被本决定取代。

R1 854 条执行前均满足原条件，运行时精确 ID/年龄/非共享过滤，实际删除 375 条、6,386,095,842 字节（5.947 GiB）。195 条父缓存 LastUsedAt 在清理过程中刷新，它们与上游共 479 条 / 23.730 GiB 保留；不放宽 7 天门禁。最初 shared=false 预览零条在删除前停止，查本机版本源码后用 private="" 经同集合预览再执行。R4 七对文件重新核验 SHA256/大小/独立 inode 后删除副本，共 587,493,376 分配字节；正式副本和全部备份保留。操作脚本 space_reclaim_20260927.py 及证据见 scripts/results/luna-reclaim-*（sunmoonai 下）。

回收前后 root used 492,870,619,136 → 485,905,276,928 字节，净下降 6.487 GiB；VHDX Length 515,879,469,056 未变；Cfree 248,957,067,264，未压缩。208 个宿主镜像、7 个容器 ID/状态、卷名集合前后相同。所有节点/卷及旧 worker2 均保护，没有 system/container/volume prune 或等效操作。

R2 只读：105 个本地应用镜像与 Harbor exact index/manifest digest 相同；244 条经父子/别名关系筛选的专属缓存；content 6.274 + snapshot 28.240 = 34.514 GiB 去重规划估算，实际 GC/lease 可能降低收益，不是承诺。其余 100 镜像 API 独有层 32.973 GiB（未扣保护）：20 个 Harbor 来源、32 个 tar 精确描述符及必需 amd64 blobs 全 SHA256 来源，重叠17，合35个有核验来源，65个未证实继续保留。逐个来源 luna-r2-archive-sources.20260927.json；未执行 R2。

压缩与入口切换合并一个维护窗口，所有者操作；不启用自动收缩，不关闭本轮 WSL。主方案和空间方案已更新维护顺序、回退和实际量。业务 inbox 仍在旧 kind，~/.kube/kind-config，匹配 kubectl 1.27.3；sunmoon-kind-136 仅验证，新 main 尚未创建。下一步远程审阅本单元，再按主方案准备统一部署代码/物料和所有者附盘步骤；不把 R1/R4 完成说成迁移完成。

### 最新收尾指令（覆盖“立即继续回收”的安排）

所有者：“那就等最后再一起清理吧”“不过要记住一定要清理”。剩余回收延后到迁移与验收完成，作为不可遗漏的最终收尾门禁；现在停止追加清理。已经执行的 R1 375 条、R4 七文件不回写为未执行。待办：R1 剩余 479 条、R2 两类、远程审阅后的试验目录重新冻结清单并按授权执行；重新盘点各项实际量、更新物料手册与网络参考。来源/时龄不满足者保留并说明，绝不触碰容器/卷/观察期旧节点或唯一备份。空间方案第 8 节含逐项验收清单，未结清不能称整体迁移完成。

本轮机械检查：4 个新增 Python 脚本 AST、全部新增 JSON/JSONL 解析及 git diff --check 通过；R1/R4 前后保护对象一致。没有运行应用/云部署测试。家目录网络参考已追加第20节，未改运行配置。交付仍仅本地 luna 分支，不 push。

## 数据盘准备单元（基线 878c581ef3cb14c1d06896a1894d8d26962a857f）

修改 deploy-kind/attach-vhds.ps1 为显式 SunmoonData 模式、默认只打印，去掉旧 E 盘和任何卸载/重启操作；mount/ 两个副本改成转发。新增 initialize-sunmoon-data.ps1（所有者首次创建100GiB动态VHDX、唯一空设备防护）、sunmoon-data-storage.py（默认只打印的 setup/mount，以及只读 check）。检查含 UUID/ext4/rw、与系统盘不同设备、bind源inode一致、空间门禁、旧路径身份；setup只管理三条新fstab目标，有冲突失败，无自动fallback。旧native检查仍可用，新服务必须显式传 --layout sunmoon-data。

SHA256固定脚本与所有者执行卡已备齐。固定发布目录 C:/wsl-disks/scripts/storage-20260927-v1 与 /opt/sunmoon/admin/storage/storage-20260927-v1；不要让计划任务依赖临时worktree。owner-data-disk-100g.md 含完整命令、任务与中断续接。尚未运行任何Apply，未建盘、格式化、挂载、注册任务、改fstab或启动服务。

静态/只读结果 luna-data-storage-preparation.20260927.json：三PowerShell Parser通过；两shell bash -n/ShellCheck0.9.0通过；Python AST；Linux setup默认只打印、缺盘拒绝、旧native兼容通过。ShellCheck修正旧变量展开三处。Windows直接执行UNC默认plan被现有CurrentUser RemoteSigned拒绝，未修改/绕过策略；卡中给出本地固定副本发布供所有者操作，本地副本执行和真实挂盘/重启仍未验证。ShellCheck仅Ubuntu包下载解压/tmp，无系统安装。C盘剩余232.54GiB，目标VHDX不存在。

本单元只是存储前置，不是整个P1或迁移完成。registry-platform、官方Harbor2.13.2物料、PG17逻辑迁移、入口代理、云steps与消费开关仍待完成。先等待所有者按操作卡返回UUID及check输出，同时可继续独立准备仓库模块/物料。新服务启动门禁尚须实际接线，不得宣称已形成自动保护。
