# WSL 空间回收与磁盘压缩方案

日期：2026-09-27。**所有者已批准 R1 ≥7 天档和 R4 的 7 个重复文件，本轮已执行并复盘；R2 延后到宿主 Harbor 恢复及全目录摘要验收之后，R3 取消。WSL 压缩并入入口切换维护窗口，由所有者操作，不启用自动收缩。数据盘上限已明确为 100 GiB。** 统一目标及新数据盘方案见 [主方案](storage-and-harbor-placement-decision.md)。


**本轮最后决定：剩余清理统一放到迁移与验收结束后执行，现在不再追加。清理是必须完成的收尾项，不能以“已迁移”直接结束任务。** 已完成 R1/R4 的记录不变；执行边界仍受 Harbor 验收、原缓存时龄、远程分支审阅及容器/卷保护约束。

## 1. 禁止事项与审批边界

### 本次重构临时物料必须最终清理

2026-09-28 所有者明确要求：本次 refactor 产生的本机临时目录、文件，及东京服务器下载中转物料，在最终收尾全部清理。当前仍是整理/迁移阶段，尚未实施此轮清理；不能只留下方案就宣称交付完成。

执行前以本次命令/下载回执重新定位准确路径、大小、用途、最终副本和引用；以下是已记录的候选，**不是已完成的全量盘点，也不保证当前仍存在**：

| 位置 | 已知本次临时物料候选 |
| --- | --- |
| WSL `/tmp` | `/tmp/luna-shellcheck-20260928`、旧 `/tmp/luna-shellcheck-package`、`/tmp/luna-harbor-v2.13.2-source.tar.gz`、`/tmp/luna-adapter-v0.38.0-source.tar.gz`、`/tmp/luna-containerd-config-p_jbny13`；其他临时脚本/输出按回执逐项补齐 |
| 本地物料目录内试验产物 | `releases/scanner-patches-20260927-v1`、`releases/harbor-scanner-osfix-20260927-v1` 等已取消方案产物；现用 releases、锁文件及唯一安装包先核引用，不视为临时垃圾 |
| 东京 `txy-tokyo` | `/home/zym/sunmoon-scanner-patches-20260927-v1`、`/home/zym/trivy-db-20260927-v1`、`/home/zym/sunmoon-nginx-sni-20260927-v1`、`/home/zym/sunmoon-traefik-20260927-v1`、`/home/zym/.cache/sunmoon-artifacts/kubeadm-1.36.4-linux-amd64`；其余下载/中转/半文件及 ShellCheck 包按本次记录补齐 |

收尾步骤：

1. 查本次任务记录和实际目录，生成本机、东京两份精确清单；拒绝软链越界、其他任务文件或用途不明对象，不能执行 `/tmp/*`、整个用户缓存或物料根目录的通配删除。
2. 正式离线物料已回传唯一物料根并通过 SHA/版本/部署引用核验后，东京下载副本、导出 tar、半文件、公开下载脚本及临时日志均删除。远端本次拉取的 Docker 镜像单列精确 ID，先核无他人/现有容器使用；禁止全局 prune 或顺带删除容器、卷。
3. 本地临时下载、解包工具、试验工作目录和脚本删除；应保留的验收结论、公共摘要、操作步骤先写回正式文档或结果文件，真实口令/密钥只留既定私有位置，不保留临时泄露副本。
4. 仍受保护的旧节点/卷、Harbor 数据/必要备份和云端未验证历史代码按原退出条件办理；从“本次临时目录”中识别出来并列出保留依据，不靠改名逃避最终清理，也不把它们误当下载缓存。
5. 结束再次盘点本机和东京候选路径，报告已删清单、Linux/远端实际释放量、仍需保留项与退出条件。VHDX 压缩收益另按维护窗口记录，不与逻辑文件释放量混算。

- 禁止 `docker system prune`、`docker volume prune`、`docker container prune`，也禁止以其他命令达到清理容器/卷的同样效果。
- 所有 KIND 节点容器和关联 Docker 卷均保护，包括停止状态的旧节点。切换后观察期内，它们是回退保障，不是“unused 垃圾”。旧 kind-worker2 和它的沙箱持久卷明确保留。
- 不直接删除 `/var/lib/docker/overlay2`、Docker/containerd content、snapshot、卷目录或数据库目录；镜像回收只能通过对应运行时、精确审定对象执行。
- 不清空 `/data/kind-local-storage`，不在旧路径叠挂新盘，不删唯一冷备份、唯一离线自举材料或尚未校验的“重复文件”。
- 本表每类均独立审批，不把“同意清构建缓存”扩展为删除镜像/归档。审批对象应有清单文件 SHA256、精确 ID/路径、回收估计、保留依据和时间窗口；实施前再次核对引用漂移。
- 先回收 Linux 文件系统空间，再于维护窗口压缩 VHDX；两者收益分开记录。不得承诺 `du` 减少多少，C 盘就立刻增加多少。

## 2. 只读盘点

基础快照：WSL 文件系统已用约 459.00 GiB，系统 VHDX 文件逻辑大小 480.45 GiB，C 盘剩余约 231.96 GiB。旧静态卷 17.186 GiB、两个 worker 动态卷合计 0.240 GiB、Harbor 冷备份 16.851 GiB；详见 [数据盘容量记录](../../scripts/results/luna-data-disk-sizing.20260927.json)。

原始证据：[目录盘点](../../scripts/results/luna-wsl-space-inventory.20260927.json)、[Docker/CRI 引用盘点](../../scripts/results/luna-docker-space-inventory.20260927.json)。全根扫描超过 180 秒后停止，只停止本轮 du 进程，改用有界分目录扫描；不把超时当盘点成功。目录总量与 Docker 报告可能重叠、包含共享层或绑定挂载，不能直接相加。测量不停止服务，运行期新增写入会造成变化。

| 盘点项 | 用量 / 状态 | 如何解读 |
| --- | --- | --- |
| `/home/zymun` | 88.25 GiB | 包含下面的物料、开发仓和用户工具，不能再逐项相加 |
| `packages-to-be-installed` | 40.07 GiB | 其中历史镜像导出约 15.35 GiB、releases 24.36 GiB |
| Harbor 保留批次 | 18.61 GiB | 包含冷备份 16.85 GiB 和恢复物料等，当前保留 |
| 模板物料批次 | 4.54 GiB 分配空间 | 逻辑长度约 4.02 GiB；大量小文件会有块开销，和前次逻辑大小并不矛盾 |
| `/usr` / `/tmp` | 11.16 GiB / 约 5.5 MiB | 系统软件不纳入本轮清理；临时目录收益很小 |
| `/var/lib/docker` | 92.18 GiB | 其中卷目录 90.98 GiB；卷保护不清理，不能以大为由删除 |
| Docker 镜像层 API | 245.29 GiB | 和构建缓存的共享内容重叠，不能两项相加 |
| 构建缓存 API | 194.03 GiB / 2220 条 | 158.04 GiB 与镜像共享；非共享记录约 36.00 GiB |
| 宿主镜像引用 | 208 个镜像、205 个无宿主容器引用 | 仍可能是 KIND 内镜像、自举/回退/离线输入，不自动等于安全候选 |
| 宿主容器 | 六个运行 KIND 节点 + 一个原有停止容器 | 全部保留；未来停止旧节点也按保护对象处理 |

### 分项估计与批准卡

| 顺序 | 本轮可讨论的回收量 | 影响 | 可恢复性 / 当前决定 |
| --- | --- | --- | --- |
| R1 构建缓存 | 原批准 854 条、29.68 GiB；实际删除 **375 条 / 5.947 GiB** | 重建相应构建缓存会增加耗时 | 已执行。195 条父缓存时间被清理动作刷新，它们及上游共 479 条 / 23.73 GiB 被 7 天门禁保留 |
| R2-A Harbor 同摘要应用镜像 | **105 个镜像 + 244 条仅关联该集合的缓存；含共享内容去重估计 34.51 GiB** | 下次从宿主 Harbor 按 digest 恢复；构建缓存需重建 | 尚未执行。宿主 Harbor 全目录验收通过后，实施前复核引用、摘要及保留集合 |
| R2-B 其余未被宿主容器引用镜像 | **100 个**，API 独有层合计 **32.97 GiB**（未扣保护）；35 个找到至少一种核验来源，65 个无已证实来源 | 不可恢复版本必须保留；自举/离线/回退输入另有保护 | 逐镜像结果已列，不能把有来源等同于可删。与 R2-A 同样延后 |
| R3 节点镜像 | **取消，实际释放 0** | 不对将删除/重建的节点做镜像 GC | 节点容器、卷、镜像不动 |
| R4 重复物料 | **7 个文件 / 0.547 GiB** 已删除；试验工作目录约 3.12 GiB 继续保留 | 正式同摘要副本和全部备份保留 | 7 对文件再次 SHA256、大小、独立 inode 核对后执行；试验目录等远程助手审分支后由所有者决定 |

物理 `/var/lib/containerd` 逐文件统计在 120 秒上限内未完成（退出 124），没有给它编造精确 du 总量；Docker `/system/df` API 的镜像层记录已完整取得并用于镜像/缓存估计。其余列出的 du 值都来自成功完成的对应目录扫描。

R1 候选 ID 清单：[luna-build-cache-candidates.20260927.json](../../scripts/results/luna-build-cache-candidates.20260927.json)。目前只读核实 builder `default`（docker driver，Buildx v0.33.0 / BuildKit v0.29.0）。本轮实施前检查了实际 builder、InUse/共享/时间条件是否漂移；任何新使用者出现就移出候选。缓存、镜像和节点记录存在共享/压缩/快照差异，以上数字**不相加为总回收承诺**。

## 3. 按安全程度排序的回收单元

### R1：构建缓存

限定具体 builder，排除 InUse 和仍在运行构建使用的项；优先旧的中间构建层。包归档、Git bundle、已验收 pnpm store 不在 Docker 构建缓存授权内。

本轮按所有者选择固定 builder `default` 和原 854 条 ID，执行前再次检查 InUse=false、Shared=false、LastUsedAt ≥7 天。原清单 854 条均通过，runtime du 预览集合也严格相同；没有纳入新出现的缓存。

实际运行命令由 [批次脚本](../../cicd-platform/materials/space_reclaim_20260927.py) 生成：`docker buildx prune --builder default --force --filter 'id~=^(原清单ID的正则并集)$' --filter until=168h --filter 'private=""'`。不使用 `--all`，不清镜像/容器/卷；BuildKit 自身在执行时排除 InUse。最初 `shared=false` 预览为零，门禁在删除前拦截；已查明本机版本布尔字段是存在性条件，改用经同集合预览验证的 `private=""`。[Docker 参数说明](https://docs.docker.com/reference/cli/docker/buildx/prune/)、[Buildx 0.33.0 转换源码](https://github.com/docker/buildx/blob/v0.33.0/commands/prune.go)、[BuildKit 0.29.0 过滤源码](https://github.com/moby/buildkit/blob/v0.29.0/cache/manager.go)。这不是可跨版本盲用的命令模板。

实际删除 375 条，缓存记录大小合计 **6,386,095,842 字节 / 5.947 GiB**，CLI 报告 Total 6.386GB（十进制）。清理过程中 195 条父缓存的 LastUsedAt 更新到本轮时刻，按父子/别名关系回溯覆盖剩余 479 条 / 23.730 GiB；未放宽 7 天限制，也未把候选预算报成释放量。剩余部分后续重新按时龄与依赖盘点。

影响是后续构建缓存失效、耗时增加，删除不能原样撤销。本轮正式工具/依赖归档、Git bundle、pnpm store、镜像和冷备份都保留。R1 前后文件系统已用下降约 5.946 GiB，在线写入会影响差值。完整预检、命令、输出及保护对象比较见第 7 节。

### R2：两类镜像与关联缓存（尚未实施）

门禁：**宿主机独立 Harbor 恢复完成，按所有项目/仓库/顶层与子清单/标签做全目录摘要比对通过，然后才能执行 R2。** 当前仍是旧集群 Harbor，隔离恢复演练不能满足此门禁。清理期间须暂停构建、拉取和发布，重新冻结实际 ID/摘要/引用清单；现存七个宿主容器（包括停止容器）引用的三个节点镜像直接排除。

#### A. 本机与 Harbor 具有相同摘要的应用镜像

应用集合按 `app-images` 项目认定。共有 **105 个本机唯一 image ID**，包含多个标签指向同一 ID 的去重，不能只数标签。关联缓存确认 **244 条**：以镜像 RootFS 的 ChainID 为起点，读取只读 BuildKit 元数据、buildx 父子关系和 mutable/immutable 别名；仅选关联此集合、没有集合外后代依赖且非 InUse 的记录。未能证明专属关系的缓存保留。

估算不是 `image Size + cache Size`：把本地 OCI content 按 digest 去重、解压 snapshot 按键及父链去重，减去全部保留镜像、缓存和容器的引用。得到 **content 6.274 GiB + snapshot 28.240 GiB = 34.514 GiB**。244 条缓存的 API 大小已与这两个集合重叠，不另加。额外 lease、编码变体与实际 GC 时机可能使释放更少；这是规划估计，验收仍以运行时和文件系统实际差值为准。多架构镜像未在本机落盘的其他平台内容不计本机空间。

摘要核对方法：

1. 使用现有本机凭据，在 TLS 校验开启、绕过公网代理的前提下只 GET Harbor API；管理员视图分页总数一致，枚举 3 项目、64 仓库、165 顶层/429 含子清单制品、164 标签，保留本轮目录快照。凭据只在内存使用。
2. 从 Docker inspect 的 OCI descriptor 获取本机 index/manifest 摘要，读取本机 content 对描述符字节计算 SHA256，再与 Harbor 的制品 digest 精确相等。不能用相同标签、config ID 或“层看起来一样”代替 manifest/index digest。
3. 例如 `harbor.sunmoonai.com:30443/app-images/sandbox@sha256:dbafbcd4eba426fe2a8aa89545214a90b80ae38d508bf1bcee55dda7d41502af` 本机与 Harbor 相同。人工复核可运行 `docker manifest inspect --verbose <完整repo@sha256>` 并核查 Descriptor.digest；普通 inspect 输出的 config.digest 不是镜像 index 摘要。
4. 宿主 Harbor 恢复后重做全目录比对和每个候选的按摘要可拉取检查；镜像层目录/数据库/加密密钥的恢复验收仍按主方案执行。镜像删除不加 force、不递归删父镜像；缓存先冻结精确 ID，运行时出现新引用即移出。

清单与算法：[分类与共享层估算](../../scripts/results/luna-r2-classification.20260927.json)、[Harbor 目录](../../scripts/results/luna-r2-harbor-catalog.20260927.json)、[只读估算脚本](../../cicd-platform/materials/space_r2_inventory.py)。缓存元数据库读取仅用于此次版本的盘点，绝不写库或据此直接删底层文件。

#### B. 其余镜像逐个核对恢复来源

**100 个**，API 独有层合计 **32.973 GiB**，该数未计某些共享层、未扣自举/回退/离线保护，不能作为安全释放承诺。其中 **20 个**在 Harbor 其他项目有同摘要，**32 个**在现有 tar 中找到精确 OCI 描述符并校验全部 linux/amd64 必需 config/layer 的 SHA256；二者重叠 17 个，合计 **35 个**至少一种已核验来源。另 **65 个**未证实来源，全部保留；没有因为无 tag 或无容器引用就删。

只读取已有镜像归档，未解包到宿主目录、未 docker load/pull、未新增容器。逐项 image ID、标签、Harbor repo@digest、离线 tar 路径和验证方法见 [100 个镜像恢复来源清单](../../scripts/results/luna-r2-archive-sources.20260927.json)。有来源仍需扣除 KIND/Harbor 自举、发布/回退与验收物料的保护集合；**本轮这一类实际释放 0，未确定可以删除的最终总量**。同版本同文件名不算恢复证明，公网可重新下载也不算本地已核验来源。

### R3：已取消

所有者明确取消，不在即将删除或重建的节点内清镜像。历史 41.52 GiB 为未去重的只读盘点记录，不再列为回收预算；节点、容器、卷保持原样，旧 kind-worker2 继续保护。

### R4：离线物料、导出包、重复备份

区分“可再生成的 scratch 工作目录”和“恢复输入”。T0–T4 留下的临时源码、node_modules、venv、store 副本可列候选，先保留原结果/log/产物指纹及正式源码 bundle、工具、原包归档；不能只因为体积大就删。

大型 tar、重复镜像导出、复制的冷备份要按大小 + SHA256 + 来源/引用核对：相同文件名或版本号不能证明内容相同。至少保留当前可用及明确回退批次、Harbor 冷备份/密钥/完整目录、对应启动镜像。没有通过独立恢复的第二副本不能替代唯一备份。家庭网络和远程服务器到期因素必须纳入恢复成本。

本轮已经比对出的 R4 候选：

| 子项 | 分配空间估计 | 保留与恢复依据 |
| --- | --- | --- |
| 旧下载尝试中的 node/Calico 镜像 tar、kind/kubectl，及工具接收目录的 pnpm/uv/Node | **0.547 GiB**，7 个文件 | 全文件 SHA256、大小与正式批次一致，独立 inode/单链接；保留正式副本及来源收据，删除后可由其复制恢复 |
| `work/offline-trial-1790472978821158770` | 约 1.99 GiB | 待远程审阅后保留 result、构建日志与必要产物，再从 bundle/归档重建 |
| `work/archive-hydration-1790472807004102080` | 约 0.89 GiB | 临时 hydrate 工作目录，保留派生锁说明，正式归档/store 不动 |
| 两次 `work/offline-negative-*` 工作目录 | 合计约 0.24 GiB | 先保留两次 result 与失败/成功日志，之后可由同一输入重建 |
| Harbor 冷备份、当前/回退物料、历史 images 导出目录 | **本轮建议回收 0** | 未证明存在可替代且已验收的独立恢复副本；不因有同名镜像而删除 |

逐文件摘要与保留副本在 [重复物料候选清单](../../scripts/results/luna-duplicate-materials-candidates.20260927.json)。7 个文件经本轮批准、复核后已删除；正式副本均保留。临时工作目录估计已排除上述工具接收目录，不重复计数；最终收益还需扣去要另行保留的少量结果与产物。

影响：丢失唯一离线来源会使恢复依赖公网，丢失唯一备份不可逆。因此最后处理；只有逐路径、保留副本、完整性及恢复依据齐全的项目才交批准。回收前保留小型证据，不删除文件后再声称可以验摘要。

## 4. WSL VHDX 压缩维护窗口

**压缩与入口切换合并为同一个维护窗口，由所有者在 Windows 管理员 PowerShell 操作。** 具体维护卡确认时间、端口配置、停服范围和恢复人后执行；本轮未关闭 WSL、未压缩、未切换入口。明确不启用 WSL 自动收缩或自动稀疏化，不设置 sparseVhd、不运行 set-sparse、不安装自动压缩任务。

### 4.1 窗口前准备

1. R1/R4 获批项完成后（R3 取消，R2 依赖 Harbor 验收），记录 Linux `df -B1 /`、各清理类别差值、Docker/节点引用与数据清单；不得以压缩代替内容清理。
2. 取得数据库一致性备份、对象存储与 `~/private` 备份，复核 Harbor 备份和必要恢复材料。现有 C 盘空间不足以再复制一份约 480 GiB 系统 VHDX；不能把“同盘完整 VHDX 复制”写成已完成保护。
3. 确认实际所有发行版/后台服务与 Windows 上会自动启动 WSL 的终端、IDE、计划任务。约定预计 30–60 分钟窗口（不是完成保证），中途不强行终止压缩或断电。
4. 保存所有节点/容器的运行与停止状态、restart policy、卷名和挂载，按明确清单停止写入任务和数据库，再停止计划内服务；原本停止的回退节点保持停止。不运行任何 rm/prune。
5. 文件系统 sync；在已批准窗口做 `sudo fstrim -v /`，记录结果。若未来还压缩新数据 VHDX，再单独对已确认挂载的 `/mnt/sunmoon-data` trim；不把裸路径不存在时的结果当成功。不用写满空闲空间的 zero-fill 手段。
6. 暂停可能重启 WSL 的相关任务，记录原状态用于恢复。新 `sunmoon-data-mount` 已注册：先创建 `C:\wsl-disks\sunmoon-data.maintenance`、Disable 该任务并等待运行实例结束，再关闭 WSL；完整命令见 [存储索引](../mount/README.md#压缩维护先暂停自动任务完毕再恢复)。恢复挂载并核对后才解除标记和恢复任务。WSL 关闭会影响全部发行版；这项影响必须先明确。

### 4.2 合并维护窗口的顺序

1. 窗口前完成独立数据盘挂载门禁、宿主 Harbor 同版本恢复与全目录比对、备用端口 TLS/SNI 代理测试；这几项不以压缩成功替代。R2 如安排在该窗口前，必须先满足其 Harbor 门禁。
2. 冻结发布/构建与旧服务写入，完成最终一致性备份与迁移增量确认，保存精确运行状态和 restart policy。停止旧控制面只释放入口，不删除容器/卷；先按维护卡防止 WSL 恢复时它自动抢回 30443。
3. 按上节停止写入、sync/trim；所有者关闭 WSL并压缩，记录前后 Length/C 盘 free。
4. 所有者恢复 WSL，先验证新盘 UUID 与两条 bind，再启动宿主 Harbor；旧控制面维持停止，由已验过的 TLS 代理接管 30443，默认应用域名按主方案过渡转发。核验 Harbor 全目录、TLS、域名分流、推拉和受影响旧端口。
5. 失败回退：停止新代理/过渡监听，确认端口空闲，按原运行状态恢复旧控制面及原 Harbor/入口，核验原 UID；不要同时运行争用 30443 的两套入口。压缩阶段不能中断 DiskPart，端口接管失败的 30 分钟回退上限从压缩结束后算。

整个窗口含压缩，预计 60–90 分钟，仍须按现场盘大小、备份/恢复耗时确认；不能沿用“仅端口切换 30 分钟”作为整体停服承诺。正式集群仍在宿主 Harbor 和代理验收通过后创建。

### 4.3 所有者执行的关闭、压缩与大小记录

下列示例只针对本次已定位的 Ubuntu 系统 VHDX，使用 Windows 内置 DiskPart，不要求安装 Hyper-V PowerShell 模块。动态盘必须已分离或只读附加才能 compact，参见 [Microsoft compact vdisk](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/compact-vdisk)。

```powershell
$ErrorActionPreference = 'Stop'
$SystemVhd = 'C:\Users\zymun\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx'
$BeforeLength = (Get-Item -LiteralPath $SystemVhd).Length
$BeforeFree = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
wsl.exe --list --verbose
wsl.exe --shutdown
if ($LASTEXITCODE -ne 0) { throw 'WSL 未正常关闭，禁止压缩' }
wsl.exe --list --running
# 必须确认没有运行的发行版；任何自动重启先调查，勿强制压缩。
$CompactScript = Join-Path $env:TEMP 'sunmoon-compact-system-vhdx.txt'
@(('select vdisk file="{0}"' -f $SystemVhd),'compact vdisk','exit') | Set-Content -LiteralPath $CompactScript -Encoding Ascii
diskpart.exe /s $CompactScript
if ($LASTEXITCODE -ne 0) { throw '压缩报告失败，保留输出并停止后续修改' }
$AfterLength = (Get-Item -LiteralPath $SystemVhd).Length
$AfterFree = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
[pscustomobject]@{
  BeforeVhdBytes=$BeforeLength; AfterVhdBytes=$AfterLength
  VhdLengthReductionBytes=($BeforeLength-$AfterLength)
  BeforeCFreeBytes=$BeforeFree; AfterCFreeBytes=$AfterFree
  CFreeIncreaseBytes=($AfterFree-$BeforeFree)
} | Format-List
```

DiskPart 文本若包含失败，即使退出码为 0 也不能当通过。压缩成功也可能不缩小；如存在稀疏分配或 Windows 其他并发写入，Length 差与 C 盘 free 差不完全一致，必须同时报告。[Optimize-VHD 文档](https://learn.microsoft.com/en-us/powershell/module/hyper-v/optimize-vhd?view=windowsserver2025-ps)同样说明压缩可能成功但大小不变。不能把 480.45−459.00 当作保证可返还空间。

### 4.4 恢复核对

先启动 Ubuntu，执行新的挂载流程/UUID 校验（若届时已建立数据 VHDX），再启动受门禁约束的 Harbor/正式集群。复核 `df -B1 /`、目标目录内容、PV/PVC、Harbor 全目录摘要及入口；按维护前的精确状态恢复其余服务和计划任务。**不要把原本停止的旧回退节点一并启动**，也不要为解决端口冲突删除它们。

记录压缩前后 VHDX 文件长度、C 盘 free、Linux used、开始/结束时间、实际停服与恢复结果。压缩没有直接 undo；文件系统/数据异常时立即停止新写入并按已核验备份恢复，不继续 compact 或 fsck 猜测修复。

## 5. 长期措施（同样待批准后实施）

### 5.1 Harbor 保留与 GC

按项目区分运行制品、回退制品、开发临时制品。把现有及观察期内旧环境引用的全部 digest/index/子清单、签名/附件纳入保留集合；以版本标签或其他可执行规则保护，不能只在文字里写“保留当前”。

开发临时制品可提出“最近若干版本 + 指定天数”的容量预算，例如最近 10 个构建、14 天作为讨论起点；运行/回退/不可重建版本不套用。先导出全目录并做 retention dry-run，逐项审阅差异，再删除获批制品；registry GC另在明确窗口运行，并复核摘要和实际物理收益。不能只删 tag 就宣称 blob 已释放，也不能默认重启旧的复制/清理定时任务。

定期报项目增长、dangling/untagged、备份大小和数据盘水位；容量达到门槛先阻止新增大任务，不自动清理受保护版本。Harbor 升级与策略变更分开审批。

### 5.2 构建结束后的缓存生命周期

每次构建只清自己的临时工作目录与本次新增的匿名中间对象；既有停止容器/节点/卷不属于构建清理范围。物料准备批次、源码 bundle、原包归档与派生 build cache 分开保存。

为具体 builder 配缓存容量/年龄预算，在任务结束且无活跃使用者时清过期缓存；共享缓存有租约/互斥，成功和失败任务都保留小型日志、输入锁与产物摘要。不无条件清空全部缓存，否则每次构建重新依赖公网。内容相同的离线物料按摘要复用，新批次引用旧内容时不能回收其唯一副本。

## 6. 交付与逐项批准

将只读结果、候选清单、引用排除规则及估算范围交所有者；每次批准仅覆盖 R1、R2、R3 或 R4 中指定批次。压缩按所有者决定并入入口切换维护卡；Harbor 保留策略另行审定。未批准项继续保持现状，不能拿一个总体空间目标推导删除授权。

## 7. 本轮实际执行与复盘

证据汇总：[实际回收结果](../../scripts/results/luna-reclaim-summary.20260927.json)、[清理前](../../scripts/results/luna-reclaim-before.20260927.json)、[清理后](../../scripts/results/luna-reclaim-after.20260927.json)、[R1 预检与命令](../../scripts/results/luna-reclaim-r1.20260927.json)、[R1 原始输出](../../scripts/results/luna-reclaim-r1-output.20260927.txt)、[R4 逐文件结果](../../scripts/results/luna-reclaim-r4.20260927.json)。原候选文件保持历史原样，其 approved=false 是批准前快照；本轮授权与实绩以本节和新结果为准。

| 项目 | 实际结果 |
| --- | --- |
| R1 | 删除 375 条，API/CLI 口径 5.947 GiB；该步骤 ext4 已用下降 5.946 GiB；479 条被年龄及父链门禁保留 |
| R4 | 删除 7 个副本，文件分配量 587,493,376 字节 / 0.547 GiB；该步骤 ext4 已用下降 587,403,264 字节 |
| 整体 ext4 | 清理前 459.022 GiB → 清理后 452.535 GiB，净下降 **6.487 GiB**；各步骤间有在线写入，不强行把数字相等化 |
| C 盘 | 清理前 231.858 GiB → 清理后 231.859 GiB，变化约 1.77 MiB，不能归为压缩收益 |
| 系统 VHDX | 前后均 515,879,469,056 字节 / 480.450 GiB；本轮未压缩 |
| 保护核对 | 208 个宿主镜像 ID、7 个容器 ID/状态、全部 Docker 卷名集合前后相同；未修改集群、入口和备份 |
| R2 / R3 / 试验目录 | R2 实际释放 0；R3 取消、释放 0；试验目录继续保留、释放 0 |

100 GiB 动态数据盘按清理后 C 盘余量静态预测：长满后约余 131.86 GiB；再扣 20 GiB 备份/临时预算、2 GiB 元数据，余 109.86 GiB，仍大于 50 GiB。创建前必须重测，不能预支尚未进行的 VHDX 压缩收益。

规则自检：C-D1 只删除可核验重复副本；C-R1/C-R2 保留恢复输入和精确摘要，未改变发布基线。新增脚本只用于获批回收和只读盘点；不是新部署流程、不是生产端到端验收。

## 8. 必须执行的最终清理清单

新增物料目录范围：见 [集群升级物料对应与最终清理](cluster-material-retirement.md)。25 个旧集群包约 0.946 GiB、1 个已被替代的新整合包约 0.267 GiB，当前只是退役候选，实际释放 0。平台版本不变、Harbor 原始冷备与旧客户端保留；脚本动态引用和新版依赖闭包未完成前不得删除。不能把目录全部约 40.81 GiB 视作可回收量。

所有者明确要求“等最后再一起清理，但一定要清理”。以下收尾项未结清，不得宣称本次整体迁移完成：

- [ ] 宿主 Harbor 恢复和全目录摘要验收通过，平台/应用/入口验收完成，远程助手已审阅分支。
- [ ] 对 R1 剩余 479 条、R2-A、R2-B 和 R4 三类试验工作目录重新盘点，冻结当时的精确 ID/路径、引用与恢复来源；旧数量仅作追踪，不能盲删。
- [ ] 重新盘点 packages-to-be-installed 的整套集群物料候选，完成版本替代、安装引用及回退保留核对，按逐文件清单回收并记录实际释放量。
- [ ] 在已有授权边界内完成最终清理；不满足时龄或恢复/审阅条件的逐项说明保留原因。R3 取消，任何容器/卷、观察期旧节点、唯一备份均不属于清理对象。
- [ ] 重新盘点，逐项报告删除数量、运行时/文件分配字节、Linux 实际净变化，以及 C 盘 free / VHDX Length；保留命令和失败记录。
- [ ] 所有者按入口切换维护卡完成 WSL 关闭与手动压缩；不为等待清理而自行新增停服窗口。如最终文件回收晚于该窗口，报告“ext4 已回收、宿主空间未压缩返还”，由所有者安排后续手动维护，不自动压缩。
- [ ] 回头更新《物料提交备齐方案和方法.md》和网络/部署参考，固化本次实际步骤和注意事项，再交付最终结果。

这份清单记录必须做的工作，不授权删除尚未证实可恢复的对象，也不把“留待最后”当成已完成。


### 最终收尾新增登记：数据库演练（2026-09-27）

获批演练已通过，`/data/harbor/rehearsals/pg17-20260927T040000Z` 实际占 182,140,928 字节，3 个新容器已停止并保留，无新增匿名卷。目录/dump 是恢复证据，当前全部保留；最终收尾先评估后续 Harbor 恢复是否仍依赖这些文件，未批准前不删。此登记不新增容器/卷删除授权；所有禁止 prune/删除旧容器与卷的约束继续有效。最终须报告实际回收量，不能把此占用预记为已释放。
