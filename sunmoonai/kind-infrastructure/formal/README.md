# 正式 KIND 准备入口

目标仍是：一套平台和应用部署代码，KIND / kubeadm 两种建群方式。

`prepare.py` 实现 **plan / render / check**；`cluster.py` 新增 **create / install-cni / preflight**，创建/安装默认只打印，实际分支尚未执行。它们为 `sunmoon-kind-main` 准备建群参数、复核本地物料和现场条件；**不能把本单元当作正式建群完成**。旧 `deploy-kind/deploy-kind.conf` / `kind-cluster.yaml` 是 1.27.3 历史路径，不用于新正式集群。

## 日常配置

唯一正式配置为 [deploy-kind.json](deploy-kind.json)，prepare、create、install-cni、lifecycle 都读取它。
不再通过改 Python 常量调整日常参数，也不读取旧 `deploy-kind/deploy-kind.conf`。

```bash
./sunmoon kind prepare
./sunmoon kind prepare render
# 临时选完整配置，路径必须绝对；仍只打印。
./sunmoon kind cluster create --config /home/zymun/worktrees/luna/k8s/sunmoonai/kind-infrastructure/formal/deploy-kind.json
```

也可通过 `SUNMOON_KIND_CONFIG` 指定文件；直接调用 Python 后端时使用这个环境变量。
统一入口的 `--config` 优先于环境变量。计划输出配置路径、完整配置摘要和身份摘要，便于确认采用哪一份。

| 字段 | 控制内容 | 限制 |
| --- | --- | --- |
| `cluster` / `storage_uuid` | 明确目标集群和数据盘 | 本次只准已批准的 main 和既定 UUID；不允许通过改值动旧集群 |
| `materials_root` | 已验收离线批次目录 | 仍按原 profile/lock 验证全部 SHA，不提供任意版本替代 |
| `kubeconfig` / `kubeconfig_owner` | 新凭据文件路径与所有者 | 创建前确认用户存在；现有文件不覆盖，创建后核文件摘要 |
| `pod_cidr` / `service_cidr` | Pod/Service 网段 | 私有 IPv4、互不重叠，实际创建前再核主机与旧集群冲突 |
| `api_port` / `port_mappings` | API 和五项既定业务端口映射 | API 与 TLS 下一跳仍回环监听；宿主 30443 留给独立入口，不可重复占用 |
| `limits` | 内存、Docker、数据盘、C 盘余量与初始预算 | 可调严格，不能降低已批准下限；100 GiB 数据盘仍按既定值核容量 |
| `timeouts` | API/节点/rollout 等待和创建命令时限 | 正整数；传给对应等待命令与外层进程时限 |

三节点、六条挂载、静态卷节点内路径、受管存储检查器以及禁止自动删除/重建属于架构约束，不提供关闭开关。
正式 SNI profile 的下一跳必须与配置中的 TLS hostPort 一致；过渡入口仍按其旧 worker 身份核验。

建群在受保护 `.state/state.json` 保存配置快照、完整摘要、身份摘要以及原有 KIND YAML/物料摘要。
limits/timeouts 不计入身份摘要，可以调整等待时间或提高容量要求；身份参数变化会使后续启停/CNI 拒绝操作，
需恢复原配置或另走审核迁移。stop 不做容量检查，因此提高余量门槛不会阻止正常停止。
正式集群尚未创建，不为缺新身份字段的未知状态补默认值或自动认领节点。

本次默认配置与配置化之前的 KIND YAML 逐字节一致：3 节点、6 bind，SHA256
`6619929978256872f3f3fce2ff7426efafdfc34fd4d44b0badb48390368a1351`。
只做静态解析和默认计划/渲染，未实际执行 create、CNI、启停或现场检查。

## 当前默认输入

| 项目 | 值 |
| --- | --- |
| 集群 / 节点数 | `sunmoon-kind-main`，1 控制面 + 2 worker |
| Kubernetes / KIND / Calico | 1.36.4 / 0.33.0 / 3.32.2 |
| 节点镜像 | 原官方 kindest/node 1.36.4，复用 `../isolated/artifacts.lock.json` 的精确镜像身份与归档摘要 |
| API | `127.0.0.1:17443` |
| Pod / Service 网段 | `10.246.0.0/16` / `10.98.0.0/16`；实际创建前重新查冲突 |
| kubeconfig | `/home/zymun/.kube/sunmoon-kind-main.config`，独立新文件 |
| 数据盘 | UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`，100 GiB |
| 每节点挂载 | 独立 `local-path` → `/var/local-path-provisioner`；独立 `static` → `/data/kind-local-storage` |
| TLS 下一跳 | 宿主 `127.0.0.1:19443` → 控制面节点 `30443` |
| 其余原有端口 | 保留 80、30444、30445、30446 的原监听范围，需维护窗口释放 |
| Harbor | 宿主服务；统一 `harbor.sunmoonai.com:30443`；不挂入任何 KIND 节点 |

六条宿主路径来自已批准的[存储方案](../docs/storage-and-harbor-placement-decision.md#22-正式-kind-六条挂载)。节点镜像别名仅用于 KIND 读取本地已导入镜像；未来创建器必须核对真实 image ID，不能按可变别名直接信任。数据平台静态 PV 仍需逐项渲染 nodeAffinity；本工具不创建 PV 或改权限。

## 当前可执行命令

在 `k8s` 仓库根目录：

```sh
# 只打印，不访问 Docker/API，不建目录、不下载。
python3 -B sunmoonai/kind-infrastructure/formal/prepare.py

# 只向 stdout 输出 KIND 配置；不是完整部署包，不直接拿它手工建群。
python3 -B sunmoonai/kind-infrastructure/formal/prepare.py render

# 只读本机检查；root 用于已发布挂载检查与 Docker socket。
sudo -n python3 -B sunmoonai/kind-infrastructure/formal/prepare.py check
```

`check` 完整重读 10 个已验收离线文件的 SHA256，并与仓内验收锁一致比较；不写旧物料目录。检查存储 UUID 与 PID 1/Docker 可见性、目标路径不存在、端口、主机路由、旧/验证集群网段和容量。通过显式本地 Docker socket 查询；两个已知控制面的 `kubectl` 仅执行 ConfigMap GET，不使用当前 kubeconfig，也不输出凭据。

容量同时读 Windows C 实际 free 和数据 VHDX Length。初始建群暂计系统盘 10 GiB、元数据 2 GiB、新数据盘 2 GiB；扣除数据 VHDX 长满 100 GiB 的潜在增长后 C 必须余 50 GiB，数据盘必须余 20 GiB。**这是初始建群预算，不包含独立 Harbor 恢复副本或业务数据库增长，也不是磁盘配额**。后续执行器需在动作前复核并追踪实际增量。

`prepare.py` 退出码：0 为计划/渲染成功；1 为输入、物料或现场读取失败；2 为检查已完成但尚不准建群。P3及创建器实机验收尚未完成，`ready_for_creation` 明确为 false，不可用参数跳过。此准备检查要求旧/验证控制面仍运行；P3 停旧控制面后使用下面的创建器核对维护前快照与容器身份，不能为通过准备检查重启占端口的旧控制面。

## 正式创建器（代码已实现，尚未实机建群）

```sh
# 默认仅打印，两个命令不需要 root、不执行 Docker/API。
python3 -B sunmoonai/kind-infrastructure/formal/cluster.py create
python3 -B sunmoonai/kind-infrastructure/formal/cluster.py install-cni

# 只读准入。实际入口 profile 必须显式传入，不能用38443候选替代。
# 当前使用最终preview仅检查拒绝路径，不表示该代理已经部署。
sudo -n python3 -B sunmoonai/kind-infrastructure/formal/cluster.py preflight --entry-config sunmoonai/registry-platform/config/sni-local-formal.preview.json
```

`create --apply --entry-config <已接管30443的profile>` 的前置条件：系统盘 managed 完整备份 `restore_verified=true` 并重新校验全部归档/成员；宿主实例处于已对账只读模式、无未闭合转换、基础服务运行；公开30443的代理必须有准确受管ID/配置/镜像，严格TLS指向新叶且realm不变；旧控制面已经由另一个获准维护操作停止，两个旧worker运行且三节点ID/镜像/挂载/端口与快照一致；新目录/kubeconfig/节点不存在，端口/路由/真实容量满足预算。脚本不会代替维护操作停旧节点，也不将一个布尔批准参数当作验收证据。

实际创建路径在独立盘创建六个空目录与0700的 `.state`，用锁定归档导入官方节点镜像并核真实ID，再用精确KIND工具创建；使用 `--retain`，失败不自动删除、不原地重建。新节点在创建返回或常规异常收尾时设 `restart=no`，记录精确ID、显式kubeconfig摘要和首次kube-system UID。**进程被强杀/断电时不保证 finally 收尾，重启后必须检查未完成状态和新节点restart策略；存储门禁自动启动/这种中断恢复尚未实现，不可视为生产启动验收完成。**已存在半成品拒绝重跑create，需先人工检查其状态，不清理现有卷。

`install-cni --apply` 只接受已登记三个新节点/同镜像/实际六挂载/停止自动重启，以及未漂移的kubeconfig/UID和1.36.4客户端服务端。固定Calico镜像离线导入，复用 `infrastructure/materials/cluster_config.py` 的共用渲染（KIND只传eth0探测参数），系统预载镜像设置Never；等待节点Ready和4个系统控制器 rollout。它不部署平台、不改inbox，不等于静态PV/真实镜像拉取或业务验收。

本轮：AST与两默认计划通过，共用Calico云端输入在重构前后输出一致；生成38个正式KIND Calico对象。只读preflight实际以“managed备份独立恢复未通过”拒绝，未建任何新目录/容器。证据见[执行器检查](../../scripts/results/luna-formal-kind-executor.20260928.json)。云上仍未经实机验证。

## 本轮实际结果与未完成项

实际输出见[预检记录](../../scripts/results/luna-formal-kind-preflight.20260927.json)：物料摘要、挂载与网段检查完成；17443/19443 空闲，80/30444–30446 占用。尚未创建宿主六个子目录、kubeconfig 或新节点，未更改旧节点与入口。未执行应用测试套件。

进入创建前仍须完成：

1. 新managed备份独立恢复已于2026-09-28完成；创建前仍复核同一批次及全部归档摘要，旧布局结果不代替新批次。
2. P3 [维护步骤](../../registry-platform/docs/entry-maintenance.md)、所有者 WSL 压缩与旧控制面停机窗口；38443过渡候选已验，正式切换执行器尚待实现，入口故障须能恢复旧控制面。
3. 正式 30443 SNI / Harbor 的 TLS、认证推拉与回退验收。
4. 正式创建器/CNI实机验收、存储门禁启动入口及现有共享平台模块接线。不得直接运行历史自动重建入口，也不得直接运行裸 `kind create` 跳过门禁。

建群后记录真实 UID，验六条实际 Docker mount、静态 PV、仓库信任与真实拉取，再部署平台。重建集群不影响 Harbor 数据必须实测。业务 inbox 仍用旧 `kind` 和原 kubeconfig / 1.27.3 kubectl。**最终清理仍是必须完成的收尾项，目前不执行。**

| 规则 | 本单元处理 |
| --- | --- |
| C-R1 / C-R2 | 复用已提交物料锁，全 SHA 验证；正式创建前仍须核 node ID |
| C-D8 | 不更改数据服务版本、表结构或现有数据 |
| C-I8 | 现场/物料异常停止；缺失阶段不判通过 |
| C-T5 | 本地 luna 提交，未 push；代码审阅不等于完成迁移验收 |


## 显式启停入口（尚未实机运行）

`lifecycle.py check/start/stop`默认只打印，实际动作用`--apply`。复用创建锁和精确节点ID，start只接受已记录CNI-ready的main：先核UUID、Docker挂载视角与20GiB余量，六个宿主目录必须原已存在/非软链/同盘，不自动mkdir；核镜像、挂载、restart=no及全部端口。启动后核原kube-system UID、固定1.36.4客户端/服务端并等所有节点Ready。失败只停止本次启动的节点，不自动删除或重建。

stop保留所有容器/卷，不受容量门槛阻止；仍需现存可读的受管状态和正确节点身份。缺盘导致无法读取状态时不猜测节点或创建状态目录。check只读。实际仅执行了默认计划/AST和缺正式状态的check拒绝路径；未建main，不能宣称真实启停通过。systemd、固定代码发布与管理员开机附盘的自动接线尚未安装；强杀创建进程的恢复仍需单独实现。
