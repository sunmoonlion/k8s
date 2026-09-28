# Harbor 集群外迁移与全流程统一方案

> 以后只有一套部署代码，加上两种建集群的方式。本地把平台和应用跑通，云上除了建集群那一步，其余走的是同一条路。

日期：2026-09-27。适用范围：**本机 KIND 与云端 `sunmoonai/infrastructure/`，共用仓库及部署代码。** 状态：**所有者已明确不逐项审方案，授权助手按目标判断和推进；停机/删除/Windows 管理员操作仍遵守既有边界。** 这是 [存储与 Harbor 主方案](storage-and-harbor-placement-decision.md) 的实施范围补充；本文件管理跨脚本改动和重建验收，原容量、管理员操作、回退与最终清理约束继续有效。

## 1. 现状与本轮边界

已完成：100 GiB 独立 VHDX 挂载核对、PG17.6逻辑恢复、官方Harbor2.13.2配置与原密钥映射，以及宿主隔离只读恢复完整验收。4400个registry文件和429个HTTP清单摘要通过，11个新容器停止保留。现有入口和业务仍使用旧 `kind` 中的 Harbor，正式入口尚未切换。

本批次使用 `registry-platform/recovery_candidate.py`、`recovery_run.py`、`recovery_verify.py` 及三个定向修复入口完成恢复；实测结果见 [恢复执行卡](../../registry-platform/docs/host-recovery-plan.md)。它们是固定批次迁移工具，正式统一部署入口仍须参数化并吸收本轮修复，不能把临时Compose当作已完成的本地/云端部署代码。

本次覆盖：安装、启停、集群总控、重建/重置保护、镜像推拉、证书与认证、CI/CD、备份恢复、物料与运行文档。云端只修改代码及离线演练，不连接云主机实施。

## 2. 目标结构与职责

```text
仓库主机配置（唯一来源，含凭据文件引用）
  └─ registry-platform 同一实现：local 执行 / SSH 执行
       ├─ 官方 Harbor 2.13.2 + 外部 PostgreSQL 17.6
       ├─ /data/harbor → /mnt/sunmoon-data/harbor（本机）
       ├─ 独立启停、挂盘门禁、备份与恢复
       └─ 本机独立 TLS/SNI 代理 :30443
            ├─ harbor.sunmoonai.com → 127.0.0.1:18443
            └─ 其他应用域名 → 集群入口 127.0.0.1:19443

共享部署总控
  ├─ 仓库预检/明确初始化（独立于集群生命周期）
  ├─ 建群适配：KIND / kubeadm
  └─ 同一条信任与认证分发 → 平台 → 应用 → CI/CD 流程
```

云端独立仓库主机直接提供 `harbor.sunmoonai.com:30443`，不部署本机 SNI 代理。外部域名、端口、项目、镜像引用保持不变；路由到哪个主机由配置明确给出，不再从 master IP、Pod/Service IP 推导。

### 生命周期必须分开

- `registry install/start/stop/restart/status/backup/restore` 只管理 registry-platform 自己登记的资源。停止不删除数据；普通入口不提供销毁数据操作。
- 集群 `create/start/stop/rebuild/reset` 只管理明确集群名、UID 和节点清单，不调用 Harbor stop/down，不操作 `/data/harbor`、独立仓库网络或代理。
- 总控正常部署仅检查已运行 Harbor；初始化必须是明确阶段。停止集群或平台默认不停止仓库。需要全机维护时单独列出仓库停机影响。
- Harbor、PG、SNI 代理不以任何 Kubernetes API、Helm release、PVC、Ingress 或 KIND 网络为启动条件。代理中应用后端不可达时，只影响对应域名，不能让 Harbor 路由失效。
- 所有 KIND extraMounts 只允许各节点专属目录，禁止包含 `/data/harbor`、`/mnt/sunmoon-data` 整盘、Docker socket 或仓库秘密目录。
- 新 Harbor 启动前检查预期 UUID、实际 bind、服务挂载空间和容量；盘没挂就失败，不能在系统盘普通目录初始化。不要用容器 restart 策略绕过门禁。

## 3. 核实发现的旧依赖

| 现场代码 | 发现 | 处理方向 |
| --- | --- | --- |
| `kind-infrastructure/deploy-kind/deploy-kind.sh` | 直接调用集群内 deploy-harbor | 移除新流程调用，改为独立仓库预检与消费者初始化 |
| `infrastructure/steps/step13_ingress_and_harbor.sh` | 同时安装入口和 Harbor | step13 只部署入口；旧文件名保留兼容转发/说明 |
| `kind-infrastructure/wsl-setup-harbor-login.sh` | 从 kubectl 控制面地址推导 Harbor IP | 使用仓库配置；无集群时也可登录 |
| `kind-infrastructure/kind-up.sh` | 存在旧 PV 根目录递归清理、创建 Harbor 目录、重建集群逻辑 | 去除新路径上的仓库管理；重建绑定指定集群，不执行目录清空 |
| `infrastructure/steps/step00_reset.sh` | 存在停止 Docker、清理 /var/lib/docker、广泛删除 PV/PVC 路径 | 先验证目标主机角色；仓库主机拒绝进入集群重置；不以默认动作清除存储/运行时 |
| `cicd-platform/jenkins/kaniko-build-pipeline.groovy` | 存在 `--insecure-registry` | 配置真实 CA 与凭据后启用严格 TLS，移除不安全参数 |
| `kind-infrastructure/sync-docker-harbor-ca.sh` | 有 Docker 重启路径 | 显式列出影响，不能在推送/登录时隐式重启整个 Docker |

以上为只读发现，不表示已修复。`step00_reset` 等旧脚本当前不得直接用于本机迁移或验证。

## 4. 文件修改清单

下列路径均相对 `k8s/sunmoonai/`，特别标明的 `k8s/utils/` 除外。此表是评审范围；实施时逐文件记录 diff 与验收，禁止按关键词全仓替换。

| 类别 | 纳入的入口/文件 | 拟修改内容与完成条件 |
| --- | --- | --- |
| 独立仓库安装启停 | `registry-platform/`：统一入口、配置读取、local/SSH 执行器、官方包与 Compose 渲染、systemd 单元、状态检查 | 同一份实现由参数选本机/远程；官方 2.13.2，PG17.6 独立目录；唯一配置来源；精确资源身份；离线缺项即失败；停启不删除数据 |
| 本机入口 | `registry-platform/` 代理配置/生命周期；`ingress-platform/traefik/` 部署配置；`kind-infrastructure/deploy-kind/kind-cluster.yaml` | 30443 由独立代理持有，Harbor/应用分流；集群只承接 19443；原 TLS、SNI、token realm 与引用不变；切换安排维护窗口 |
| 总控 | `deploy-sunmoonai-all/deploy-sunmoonai-all.{sh,conf}`；`cicd-platform/deploy-cicd-platform-all/deploy-cicd-platform-all.{sh,conf}` | 仓库作为独立前置，不在集群启停中管理；C1/C2/C3/KIND 的 harbor_enabled 全为 false；仓库不通时明确失败 |
| KIND 建群与重建 | `kind-infrastructure/kind-up.sh`、`deploy-kind/deploy-kind.{sh,conf}`、`deploy-kind/kind-cluster.yaml`、`kind-cli.sh`、`isolated/` 相关入口 | 固定批准版本与工具；三节点独立两条数据挂载；移除自动安装 Harbor 与原 PV 根清空；只操作显式目标；保留旧节点 |
| 云端编排 | `infrastructure/deploy-infrastructure-all/` 总控、菜单与配置；新增 step11 前仓库步骤；`steps/step11_load-initial-images.sh`、`step12_ca_generation.sh`、`step13_ingress_and_harbor.sh`、`step00_reset.sh` | 新增独立仓库主机配置；step11 读仓库地址，step13 只装入口；CA 在仓库安装前准备/校验，后续不得自动重建；重置排除仓库主机；所有入口共用顺序 |
| Docker/节点解析与信任 | `kind-infrastructure/apply-kind-registry-config.sh`、`apply-kind-harbor-tls.sh`、`apply-kind-node-harbor-hosts.sh`、`wsl-setup-harbor-hosts.sh`、`sync-docker-harbor-ca.sh`、`ensure-kind-ca.sh` | 节点地址来自仓库主机配置；不依赖旧控制面 IP；Docker、containerd、Pod 分别验 TLS；containerd 按实际版本处理；无 skip_verify |
| 统一认证与证书 | `kind-infrastructure/wsl-setup-harbor-login.sh`；`k8s/utils/unified-cert-secret-management/`、`secret-management/lib/secret-data.sh`、`cluster-config-mapping.sh`；`app-platform/utils/generate-harbor-registry-secret.sh` | CA 公共证书和凭据来源在集群之外；续签保留根 CA；私钥留私有目录；登录 password-stdin/受限文件；集群内 Secret 是可重建分发副本 |
| 镜像推拉与预检 | `kind-infrastructure/push-to-harbor/`；`k8s/utils/registry-push-management/`、`harbor-image-check.sh`；`cicd-platform/harbor/utils/harbor-image-management/`；`app-platform/scripts/build-push-app-images.sh` | 共用仓库地址、CA 与认证配置；既有 tag 不等于摘要相同；manifest/index、子清单和 blob 验证；部署以摘要锁定；独立宿主推送不依赖 kubectl |
| CI/CD | `cicd-platform/jenkins/kaniko-build-pipeline.groovy`、`incubator-app-bff-pipeline.groovy`、`deploy-jenkins/`、`resources/custom-values/`；`app-platform/scripts/development_release.py` 和发布渲染入口 | 构建/推送/发布共用配置，显式注入 CA 和项目级最小权限 robot；移除硬编码节点地址和不安全 TLS；集群重建后可重新分发凭据并完成真实流水线 |
| 其他消费方 Secret | `data-platform/`、`ops-platform/`、`messaging-platform/`、`app-platform/` 下各 `harbor-registry-secret` 入口和共享生成逻辑 | 逐处确认没有把旧 Harbor Service/Secret 当唯一来源；优先改共享实现，局部只接参数，保持 namespace 与权限隔离 |
| 备份恢复 | `registry-platform/` 新宿主备份/恢复入口；`cicd-platform/materials/harbor_{cold_backup,restore,verify_backup,inventory,...}.py` | 新备份不依赖 K8s Pod/PVC；同一冻结点 PG 逻辑导出、registry、密钥/配置/证书；逐件摘要及恢复演练；旧工具保留原批次能力，不改写历史结果 |
| 存储与运维 | `kind-infrastructure/deploy-kind/check-storage-mounts.sh`、`attach-vhds.ps1` 相关门禁集成；`registry-platform/` 启动单元 | 挂盘先于服务；计划任务和重启实际验收；控制 C 盘容量；管理员 Windows 操作仍由所有者完成 |
| 历史脚本/chart（原盘点范围，已删除目录见第 9 节） | `cicd-platform/harbor/deploy-harbor/`、`resources/harbor/`、`resources/harbor-bitnami-native/`、旧静态 PV；`k8s/utils/HARBOR-KIND-EXTERNAL/` 历史说明 | 标注“历史路径，云上新路径实机验证前不删”；入口/chart 可读元数据处标注，不修改旧 tgz；禁止新总控误调用或引入另一套 2.11 部署实现 |
| 文档与物料 | 本方案、主方案、交接文档、唯一《物料提交备齐方案和方法.md》、模块 README、云端首部署清单、变更文件列表 | 固定包/镜像/Compose/代理摘要与依赖闭包；记录失败和修复、实际执行命令、集群 UID/kubeconfig/kubectl；迁移完成后回填复用方法 |

证书 5 年续签单独纳入证书阶段：迁移核对先保留原证书，随后用原 CA 重新签发内部叶证书并统一分发；不隐式改变根 CA 或 Harbor 内部签名密钥。公网站点证书策略单独管理。长期证书仍有到期告警和泄露轮换流程。

## 5. 顺序与批准边界

1. **按所有者授权改代码**：统一参数/生命周期与调用链，补齐源文件清单；现有服务不变。静态检查和无副作用 dry-run 覆盖本地/云端分支，云端脚本头和文档标注“未经实机验证”。
2. **宿主隔离恢复（已完成）**：同版本、备用回环端口、独立网络与新数据目录；从已验冷备份逻辑恢复 PG、复制 registry、保留原密钥。只读运行，关闭破坏性后台任务；全目录/manifest/blob/原凭据验收后停止并保留演练资源。具体证据与失败修复见恢复执行卡。
3. **准备正式入口**：宿主 Harbor 与独立 SNI 代理先验证；随后才建正式集群。因为旧控制面当前持有 30443，真实接管与 WSL 压缩/重启仍须维护窗口，所有者执行 Windows 管理员部分。
4. **正式一致性迁移**：冻结旧写入和后台任务，补最终逻辑导出及 registry 差异；候选再次全量核对，确认唯一新写入口。历史冷备份成功不能代替最新数据迁移。切换前保留回退点，新写入后回退需回迁新数据，不能直接启动旧库写入。
5. **独立性与重建验收**：按第 6 节实施，先只读，再在专属试验项目执行受控推拉。不得用旧 `kind`、旧 `kind-worker2` 或现有恢复卷做删除试验。
6. **平台、应用和 CI/CD**：走共享部署入口；验收构建/推送/按摘要发布，最后才做业务 E2E。
7. **最终收尾**：观察期后按原批准类别重新盘点并清理；仍禁止全局 prune、容器/卷清理。回填物料手册、网络文档和实测空间。清理不可漏做，不提前做。

本方案确认不自动授权现有集群删除、正式切入口、停旧 Harbor、远程主机操作、CA 轮换或数据销毁。每个停机/破坏性单元仍提交绑定实际资源身份的执行卡；已明确批准的准备不重复确认。

## 6. “重建集群不影响 Harbor 数据”的强制验收

### 6.1 准入条件

宿主 Harbor 与代理先独立运行并验收；备份可恢复；停止业务写入及 GC/保留/复制/扫描/上传清理等会改变目录的任务。记录新旧资源清单、仓库挂载 UUID/路径、目录身份、Harbor/PG/代理容器 ID 和启动时间。

**试验目标建议为新建的空载 `sunmoon-kind-main`**：首次建群后、尚未部署业务和持久数据前，验证一次重建。执行卡必须列该批次节点 ID、kube-system UID、两类挂载、KIND 工具绝对路径和独立 kubeconfig。当前没有建这个集群，也没有重建授权。

所有者此前禁止任何容器/卷清理。实际 KIND 重建必然删除目标节点容器，因此必须另行明确批准**仅这批新建空载节点的重建例外**；不因同意本方案自动解除禁令。若未批准，只能完成停启验证，并将“重建验证”保持待办，不能报告通过。

### 6.2 三阶段核对

| 阶段 | 实际操作 | 必须采集的证据 |
| --- | --- | --- |
| 重建前 | 冻结写入，取得完整目录及 registry 全文件清单；从 Docker、一个新节点实际拉取固定摘要 | 项目/仓库/tag/顶层与子 manifest/附件集合，manifest/blob SHA256，文件相对路径/大小/摘要；数据库逻辑结构与必要身份；TLS/原凭据可用 |
| 集群离线期间 | 按批准卡停止并删除这批新空节点；保持 Harbor/PG/代理运行；无 Kubernetes API 可用时继续从宿主访问原域名30443 | Harbor/PG/代理 ID、启动时间和数据挂载不变；完整目录相同、登录和实际拉取成功；持续探测记录可用性。应用域名可暂不可用，不应影响 Harbor |
| 重建后 | 同一参数化建群入口重建并分发 CA/消费者凭据；节点不预载试验镜像 | kube-system UID 已变化证明是真重建；新三节点全部 Ready、存储挂载正确；在新节点实际拉取原 digest、受控运行；全目录/registry 文件与重建前一致 |

比对的是 registry 静态文件和 Harbor 逻辑数据，**不能要求运行中的 PostgreSQL 数据文件/WAL 逐字节一致**。访问计数、pull 时间、会话、日志等预期变化应单独登记，不能因此忽略 manifest/blob、项目、tag、账号/robot 等身份变化。

只读比对全部完成后，在明确的验收项目使用有限权限测试凭据 push 一个新制品，再以 pull-only 身份拉取；无权限身份的 push 必须被拒。验收制品独立登记，保留到最终清理。随后真实 CI 执行“内部物料构建 → 推 Harbor → 记录 digest → 新集群部署 → 拉取成功”，完整证明重建后的消费者配置。

### 6.3 失败判定与回退

以下任一情况判失败：仓库引用节点挂载/PVC、删除节点导致任何仓库数据缺失、集群 API 消失后仓库认证/备份无法使用、代理依赖集群存活而停止、摘要变化、TLS 绕过、只用缓存镜像假冒实际拉取。

失败只停止本次新增工作，保留所有现场和原服务；按执行卡恢复目标入口。新集群不启用业务写入，不自动删除备份/重试覆盖数据。若没有真实重建证据，最终报告必须写“未验证”，不得以配置审阅或容器重启代替。

本地独立性只涵盖 KIND 生命周期。Harbor 与 KIND 仍共用 WSL、Docker daemon、VHDX 所在 C 盘和物理硬盘；关闭 WSL/重启 Docker会影响服务，物理盘故障不在此保障范围。

## 7. 备份、云端与交付门禁

- 宿主备份读取明确配置及 Docker/PG 生命周期，不调用 kubectl 读取唯一密钥或寻找数据目录；无集群时也能 backup/verify/restore 到独立空目录。
- 同盘完整备份覆盖 registry + PG 逻辑库/角色 + 加密密钥/证书/配置，冻结顺序可回放；最新备份要有实际恢复证明，失败记录保留。
- 机器外仅数据库、对象存储、`~/private`；落点待所有者定，不私自上传镜像层或凭据。新盘与系统盘在同一物理 C 盘，不防硬件故障。
- 云端 dry-run 必须在 SSH、scp/rsync、sudo、文件写入等执行边界之前生效，不能先连远程探测才声称“只打印”。通过 bash -n、shellcheck；附首次上云主机身份/空间/防火墙/TLS/信任/推拉/恢复/重置隔离核对表。
- 最终交付：完整文件改动列表、本地 luna 完整提交号（不 push）、本地验收证据、云端未验证清单、后续 inbox 对应集群/UID/kubeconfig/kubectl。当前仍按旧 kind 的交接配置，不提前切换门禁。

## 8. 所有者最新授权与执行状态

所有者表示“不审方案，只要保证实现目标”，技术判断和实施推进由助手负责，不再重复请求逐项审稿。整体范围包括云端 infrastructure 代码；当前只有本机实操，云端只做 dry-run/静态核对。宿主隔离只读恢复已通过，正式生命周期接线与切换仍未完成。真实停机切换、受保护旧资源删除及必须由所有者完成的 Windows 管理员动作，不因免审技术方案而自动放行。

版本范围更新（2026-09-27，所有者最新决定）：数据库及数据引擎保持既定版本；其他平台组件允许按安全维护、兼容性和迁移需要评估升级，不再一概冻结，也不自动全部换成最新版。Traefik 已明确获准升级，目标为 3.7.13、配套 chart 41.6.0；镜像、CRD、权限、配置和离线物料须同步，实际兼容性与入口验收仍待完成。其他组件若升级，逐项记录原版本、目标版本、原因及验证结果。

Harbor 的实际状态需与版本决策区分：旧集群 Bitnami chart 27.0.3 所运行的 Harbor 为 2.13.2，宿主隔离恢复使用官方 Harbor 2.13.2；变化是打包来源和部署位置，Harbor 应用版本尚未升级，正式入口也尚未切换。当前迁移基线仍为 Harbor 2.13.2、PostgreSQL 17.6、Redis 8.2.1。后续若评估升级 Harbor，应明确其数据库依赖和迁移行为，不能以升级 Harbor 为由顺带变更已冻结的数据引擎版本。

物料根保持 `~/packages-to-be-installed`，新版按 releases 批次准备，部署脚本同步精确引用；最终验收后才按清单删除被替代旧包。详见 [整套集群物料对应](cluster-material-retirement.md)。

## 9. 镜像脚本退役与保留清单（2026-09-28）

镜像发布统一入口为 `./sunmoon harbor publish --batch <绝对路径 JSON>`，由 `registry-platform/publish.py` 调用锁定的 Skopeo，将核验后的 OCI 归档发布到 Harbor。日常参数见 [统一发布说明](../../registry-platform/docs/publication.md)。部署从 Harbor 拉取；发布失败必须报错，不再以“镜像已经塞进 KIND 节点”当作发布成功。

**当前状态：发布器与离线工具已准备，真实推送/消费者拉取尚待验收；应用构建和 CI 的旧发布调用尚未全部接入。** 下表记录代码入口的实际退役状态，不代表正式入口切换或整个镜像链已经验收。

### 9.1 已退役的旧实现

以下路径均相对仓库根 `k8s/`。按所有者最新要求，已覆盖的旧操作目录直接删除，不再保留转发、退役提示、废弃配置或占位 README。历史代码仅集中在 `legacy/`；日常从根目录 `./sunmoon` 操作。

| 旧入口/功能 | 当前处置 | 替代与覆盖范围 |
| --- | --- | --- |
| `sunmoonai/kind-infrastructure/push-to-harbor/push-images-to-harbor.sh` | 整个 `push-to-harbor/` 操作目录已删除；旧实现仅在 `legacy/local/` 禁用归档 | 使用显式 OCI 批次。旧 `--img-file`、`--tar-dir`、节点回退和清理参数不兼容；旧 `.conf` 不再读取 |
| `utils/registry-push-management/loadimage.sh` | 整个 `registry-push-management/` 操作目录及旧配置已删除；旧实现仅在 `legacy/cloud/` 禁用归档 | 替代原隐式加载/推送；旧 SSH 调度不自动转成新发布流程，云端接线与实机验证仍待完成 |
| `utils/registry-push-management/registry-push-menu.sh` | 随 `registry-push-management/` 删除，不再保留转发入口；禁用归档在 `legacy/cloud/` | 批次 JSON 和独立仓库配置替代菜单；不执行旧菜单的清理动作 |
| `sunmoonai/kind-infrastructure/load-images/load-kind-images.sh` | 整个 `load-images/` 操作目录、配置和默认列表已删除；原实现加拒绝执行头仅留在 `legacy/local/` | 平台/应用镜像走发布器；建群 Calico 导入由 `formal/cluster.py` 接管。不再接受任意列表、扫描 tar 目录或默认选旧 `kind` |
| `sunmoonai/kind-infrastructure/kind-cli.sh` 的 `kind_ctr_import_tar_to_all_nodes()`、`kind_docker_save_and_ctr_import_all_nodes()` | 本次移除：活动代码唯一调用方是上行旧加载器；旧推送器的调用已在禁用归档内 | 不再提供通用节点注入或导入标记跳过。`kind-cli.sh` 本身保留 CLI 路径帮助函数，仍供三个节点信任/解析脚本引用；完整旧函数可从本次基线提交恢复审阅 |
| `sunmoonai/kind-infrastructure/deploy-kind/build-kind-node-image/build-kind-node-image.sh` | 已退役，原路径拒绝执行；禁用归档在 `legacy/local/` | 正式流程使用锁定的官方 KIND 节点镜像，再导入锁定的 CNI 物料；不再把 Harbor/平台镜像预装到自制节点镜像 |
| 旧说明中的 `sunmoonai/kind-infrastructure/load-initial-images-kind.sh` | 当前仓库没有此文件；删除活动说明中“兼容包装可调用”的说法 | 不恢复该入口。云端同名近似的 step11 不是这个脚本，见下表 |

另外两处已删除的操作目录：

| 目录 | 处置与替代 |
| --- | --- |
| `utils/HARBOR-KIND-EXTERNAL/` | 两份旧说明指针和 Harbor 2.11 在线安装包全部删除。当前部署用 `sunmoonai/registry-platform/`；历史说明集中在 `legacy/local/`，不作为操作手册 |
| `sunmoonai/cicd-platform/harbor/utils/harbor-image-management/` | 仅剩的拒绝执行脚本和 README 一并删除。旧云实现仍集中在 `legacy/cloud/` 等待云实机退出条件 |

旧加载器 `.conf`、默认镜像列表、旧发布配置和 tar 占位目录均已删除；删除前确认这些目录没有未跟踪文件或实际镜像 tar。归档摘要、原提交、替代入口和退出条件以 [legacy 清单](../../../legacy/manifest.json)为准。本次导入帮助函数的历史基线为 `27e1c8628e45ade3fbdfb5a6eb9bebe9ddadba68`。

### 9.2 必须保留的导入与检查

Skopeo 向仓库发布镜像不会把镜像装进节点。离线建群时，网络插件尚未就绪，需保留受锁文件约束的自举导入。

| 保留项 | 用途与边界 |
| --- | --- |
| `sunmoonai/kind-infrastructure/formal/cluster.py` | 正式建群加载官方节点归档；`install-cni` 只向记录的三个节点导入锁定 Calico 归档，并核节点身份、挂载、版本和物料。Kubernetes 系统镜像由官方节点载荷提供；不作为普通平台/应用镜像发布入口 |
| `sunmoonai/kind-infrastructure/isolated/cluster.py` | 隔离验证批次的按锁导入；`sunmoon-kind-136` 仍是一次性验证环境，不承载正式数据、不自动转正 |
| `sunmoonai/infrastructure/materials/image_import.py` | kubeadm 路径的锁定自举镜像校验/导入；云端未经实机验证，不因统一发布而移除 |
| `sunmoonai/infrastructure/steps/step11_load-initial-images.sh` | 文件名保留，实际已转发仓库消费者步骤；仓库安装与生命周期属于独立模块，不恢复原集群内 Harbor 预加载 |
| `sunmoonai/registry-platform/host_prepare.py` | 独立 Harbor 启动所需镜像的宿主 Docker 导入。仓库自身启动不能依赖先从自身拉取；与 KIND 节点注入不同 |
| `utils/check-node-images.sh`、`check-local-images.sh`、`check-remote-node-images.sh`、`harbor-image-check.sh` | 镜像盘点/检查入口，不是发布器；不能仅因名字带 image 一并删除。具体目标与访问配置仍须按各入口要求核对 |

### 9.3 尚未覆盖的调用与最终删除条件

- `sunmoonai/app-platform/scripts/build-push-app-images.sh` 仍有 `docker push`；`sunmoonai/cicd-platform/jenkins/kaniko-build-pipeline.groovy` 仍有构建器直接发布。后续须接入统一物料/摘要发布与凭据流程，逐调用方验收，不能把这两项标作已退役或已经统一。
- `utils/packages-management/packages-management.sh` 仍有远端 `ctr import` 分支；它是旧综合物料工具，本次未停用整个工具，也未验证这条旧分支。新建群走锁定自举入口，不能把该分支列为新正式流程的一部分；剩余功能拆分和调用核对后再决定退役。
- 已归档本地实现待正式 Harbor、实际 Docker/节点/CI 推拉、空载重建独立性与观察期通过后清理；云端归档遵守“历史路径，云上新路径实机验证前不删”。本次已核对仓内调用并删除上述无依赖的原操作目录及废弃配置。仓外人工脚本若仍引用旧路径，须改用统一入口；不恢复兼容层。
- 本次额外删除的是旧目录内已被替代的 Harbor 2.11 在线安装包（11,576 字节），不是镜像层归档。正式物料根、现有镜像、节点、容器、卷、Harbor 数据和备份不受影响。本次没有调用 Docker/Kubernetes、实际发布镜像或进行运行时清理；既定最终本机/东京临时物料清理仍须另按清单完成。
