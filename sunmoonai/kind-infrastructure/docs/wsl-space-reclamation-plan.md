# WSL 空间回收与磁盘压缩方案

日期：2026-09-27。**只读盘点与方案；所有回收、保留策略变更和 WSL 关闭/压缩都待所有者逐项批准。** 统一目标及新数据盘方案见 [主方案](storage-and-harbor-placement-decision.md)。

## 1. 禁止事项与审批边界

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
| R1 构建缓存 | **约 29.68 GiB**：default builder，854 条未使用、非共享且 ≥7 天未用记录 | 后续构建变慢；历史构建可能需要重新准备依赖 | 不能原样撤销删除；能从完整物料重建的才有离线恢复保证。**待逐项批准** |
| R2 宿主无容器引用镜像 | 候选独有层合计 **59.41 GiB**，尚未扣保护集合 | 下次需 load/pull，缺原料可能失败 | 未验证归档/仓库可恢复的不能删；此数是盘点口径而非承诺收益。**本轮尚无已确认安全删除总量** |
| R3 节点未用镜像 | 六节点未命中 CRI 容器引用、非 pinned 记录大小合计 **41.52 GiB**，未去重/未扣系统与回退依赖 | Pod 重建可能拉取、慢或失败 | 物理释放可能远小于记录大小；停止旧节点不 GC。先核对完整物料，**待另批** |
| R4 离线物料/导出/备份 | 已逐字节 SHA256 核对的重复文件 **0.55 GiB**；另有可再生成试验工作目录约 **3.12 GiB**，保留结果后估计合计不超过 **3.67 GiB** | 丢唯一物料会依赖公网，丢唯一备份不可逆 | 保留当前/回退批次和冷备份；具体候选见后续细表，**待另批** |

物理 `/var/lib/containerd` 逐文件统计在 120 秒上限内未完成（退出 124），没有给它编造精确 du 总量；Docker `/system/df` API 的镜像层记录已完整取得并用于镜像/缓存估计。其余列出的 du 值都来自成功完成的对应目录扫描。

R1 候选 ID 清单：[luna-build-cache-candidates.20260927.json](../../scripts/results/luna-build-cache-candidates.20260927.json)。目前只读核实 builder `default`（docker driver，Buildx v0.33.0 / BuildKit v0.29.0）。批准前检查实际 builder、InUse/共享/时间条件是否漂移；任何新使用者出现就移出候选。缓存、镜像和节点记录存在共享/压缩/快照差异，以上数字**不相加为总回收承诺**。

## 3. 按安全程度排序的回收单元

### R1：构建缓存

限定具体 builder，排除 InUse 和仍在运行构建使用的项；优先旧的中间构建层。包归档、Git bundle、已验收 pnpm store 不在 Docker 构建缓存授权内。

审批时固定 builder `default`、候选 ID 清单，以及 `until=168h`、非共享、非 InUse 条件；建议从 ≥30 天的约 27.66 GiB 起，或批准 ≥7 天的约 29.68 GiB，两者是包含关系不能重复计量。实际命令需按 buildx 支持的 id/年龄/共享过滤精确生成并再审阅，使用构建器自身的缓存清理能力；不使用 system/container/volume prune。构建工具支持的缓存边界参考 [Docker buildx prune](https://docs.docker.com/reference/cli/docker/buildx/prune/)。

影响：下次构建变慢，缺少固定原料时可能需要重新下载。可恢复性是“从已校验物料重建”，不是原样撤销删除；先证明对应物料仍在。清理后重新记录缓存与 df 差值，不将共享 image 层重复计收益。

### R2：未被任何容器引用的宿主镜像

对 `docker ps -a` 的全部容器建立 image ID 引用集合，包含 stopped/created。排除运行与回退节点镜像、Harbor 旧/新自举、当前/回退业务摘要、只有这一份副本的镜像，以及虽无容器引用但被验收批次引用的镜像。

候选必须有原始 registry digest 或已校验离线归档；逐 image ID/标签列清单，使用运行时精确删除，禁用 force 和递归父镜像清理。不存在“未使用就都删”的授权。多个 tag 指向相同 ID 只计一次；共享层需按实际差值计量。

影响：将来使用时需重新 load/pull；公网不稳定时只接受本机可验证的恢复来源。删除不是直接可逆，离线归档/可信 registry 可恢复；恢复来源未经验证的候选本轮不计安全可回收量。

### R3：KIND 节点内未使用的镜像

分节点只读盘点 CRI images、所有运行/停止 CRI container 引用和 pinned 镜像；同时排除 Pod sandbox/pause、Kubernetes/Calico、当前清单、副本重启、回退版本及唯一离线镜像。当前无 Pod 引用不代表 Deployment scale=0 或演练副本不需要它。

停止的旧节点不为盘点而启动，也不在观察期做节点内 GC。对活跃节点，只对所有者明确批准的镜像 ID 调用 CRI 删除；不手工删 content/snapshot，不执行全节点一键 rmi/prune，不重启 containerd。镜像记录大小包含共享与压缩/解压差异，不能直接等同可释放的物理空间。

影响：Pod 重建可能重新拉镜像、变慢或因仓库不可达而失败；风险高于宿主缓存。需要离线归档及恢复路径，优先等仓库与正式环境验收后处理。旧节点/卷仍保护不变。

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

逐文件摘要与保留副本在 [重复物料候选清单](../../scripts/results/luna-duplicate-materials-candidates.20260927.json)。这些仅为候选，未删除。临时工作目录估计已排除上述工具接收目录，不重复计数；最终收益还需扣去要另行保留的少量结果与产物。

影响：丢失唯一离线来源会使恢复依赖公网，丢失唯一备份不可逆。因此最后处理；只有逐路径、保留副本、完整性及恢复依据齐全的项目才交批准。回收前保留小型证据，不删除文件后再声称可以验摘要。

## 4. WSL VHDX 压缩维护窗口

压缩本身也需要单独批准；**由所有者在 Windows 管理员 PowerShell 完成关闭 WSL 和压缩，助手不能执行到关闭自身环境后无人接管。** 本轮不运行下面的命令。

### 4.1 窗口前准备

1. R1–R4 按获批项完成后，记录 Linux `df -B1 /`、各清理类别差值、Docker/节点引用与数据清单；不得以压缩代替内容清理。
2. 取得数据库一致性备份、对象存储与 `~/private` 备份，复核 Harbor 备份和必要恢复材料。现有 C 盘空间不足以再复制一份约 480 GiB 系统 VHDX；不能把“同盘完整 VHDX 复制”写成已完成保护。
3. 确认实际所有发行版/后台服务与 Windows 上会自动启动 WSL 的终端、IDE、计划任务。约定预计 30–60 分钟窗口（不是完成保证），中途不强行终止压缩或断电。
4. 保存所有节点/容器的运行与停止状态、restart policy、卷名和挂载，按明确清单停止写入任务和数据库，再停止计划内服务；原本停止的回退节点保持停止。不运行任何 rm/prune。
5. 文件系统 sync；在已批准窗口做 `sudo fstrim -v /`，记录结果。若未来还压缩新数据 VHDX，再单独对已确认挂载的 `/mnt/sunmoon-data` trim；不把裸路径不存在时的结果当成功。不用写满空闲空间的 zero-fill 手段。
6. 暂停可能重启 WSL 的相关任务，记录原状态用于恢复。WSL 关闭会影响全部发行版；这项影响必须先明确。

### 4.2 所有者执行的关闭、压缩与大小记录

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

### 4.3 恢复核对

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

将只读结果、候选清单、引用排除规则及估算范围交所有者；每次批准仅覆盖 R1、R2、R3 或 R4 中指定批次。压缩和 Harbor 保留策略各为独立审批项。未批准项继续保持现状，不能拿一个总体空间目标推导删除授权。
