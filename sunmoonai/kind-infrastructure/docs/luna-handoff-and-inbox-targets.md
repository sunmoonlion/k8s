# Luna 交接：文件范围与后续 inbox 目标

日期：2026-09-27。仅交回本地 `k8s/luna` 分支，所有者的脚本负责推回；未 push、未合并 fable。完整提交号在交回消息中，审阅对象是该提交，不能只按文件当前内容判断。

## 1. 做完与停下的边界

已完成：独立 KIND/Calico 物料与基础验证、旧 Harbor 冷备份和隔离只读恢复验证、模板前后端物料 T0–T4，以及复用手册。

尚未完成：正式环境重建/宿主挂载、Harbor 最终放置、平台/业务全新初始化、生产镜像与 CI/CD、全项目物料闭包、业务 E2E、云端部署。不能把本次单元完成解释为整个项目达到生产标准。

**`sunmoon-kind-136` 是一次性验证环境，本集群不承载正式数据，切换前会重建。** 不再往它安装平台/业务组件。Harbor 演练副本 8 控制器保持 0，六卷保留，未作为正式镜像源。

旧 `kind-worker2` 没有宿主持久化目录挂载，沙箱卷在它的容器内，**不要删除该节点容器**。`/data/kind-local-storage` 没有清空，旧 worker 的挂载未动。旧 Harbor 入口保持 `harbor.sunmoonai.com:30443`；所有者已确定以后本地/云端均部署在集群外，本地为 WSL；仍只写方案、尚未迁移。先读 [宿主挂载与 Harbor 决策方案](storage-and-harbor-placement-decision.md)。

## 2. 以后 inbox 用哪个集群

**当前业务类 inbox 沿用旧 `kind`。** 新验证集群只用于明确点名该集群的只读检查或另外获准的验证；不自动接收业务发布。正式新环境名已定为 sunmoon-kind-main，但尚未创建；完成建群后必须更新本表及门禁 UID。

| 项目 | 现有业务环境 | 一次性验证环境 |
| --- | --- | --- |
| 集群 | `kind` | `sunmoon-kind-136` |
| 服务端 / 对应客户端 | `v1.27.3` / `v1.27.3` | `v1.36.4` / `v1.36.4` |
| kubeconfig | `/home/zymun/.kube/kind-config` | `/home/zymun/.kube/sunmoon-kind-136.config` |
| kubectl | `/home/zymun/packages-to-be-installed/releases/kubectl-1.27.3-existing-kind-linux-amd64/bin/kubectl` | `/home/zymun/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64/bin/kubectl` |
| kube-system UID | `5d71ab3a-ea5a-4535-adc6-d7698d820249` | `f5b11e20-1428-48a0-8c7a-51bc9ef27896` |
| 节点 | 1 控制面 + 2 worker，均 Ready | 1 控制面 + 2 worker，均 Ready |
| 宿主持久卷挂载 | 仅旧 worker 有 `/data/kind-local-storage`；worker2 无 | 三个节点均无，不用于正式数据 |

2026-09-27 只读快照：[版本、UID、节点、系统 Pod 和演练副本数](../../scripts/results/luna-handoff-clusters.20260927.json)。两套 kube-system Pod 均 Running/Ready；节点 Ready 不能代替业务验收。

旧 kubectl 从现有 `kind-control-plane:/usr/bin/kubectl` 提取，源/副本摘要相同，已实测客户端版本及旧集群查询；SHA256 `ebafd9850219b73760675984df1d7cdb675e4695a43fdf9dfcce41d5066fe8d5`，出处在同批次 `provenance.json`。没有替换全局 PATH 的 kubectl。

后续执行者在自己的进程里明确选择环境，例如旧环境只读门禁：

```sh
export KUBECONFIG=/home/zymun/.kube/kind-config
export PATH=/home/zymun/packages-to-be-installed/releases/kubectl-1.27.3-existing-kind-linux-amd64/bin:$PATH
kubectl version -o json
kubectl get ns kube-system -o jsonpath='{.metadata.uid}'
kubectl get nodes
```

必须对照表中服务端版本和预期 UID；不符就停下调查。不要用现场 UID 自动覆盖门禁预期值，不要只依赖合并 kubeconfig 的 current-context。上面的命令只选目标，不构成 inbox 发布授权；若现有脚本硬编码别的路径，先审阅适配。默认 PATH 当时是 kubectl 1.36.0、kind 0.27.0，不是这两套已匹配工具。

## 3. 节点与 Harbor 事实

- 新集群由独立 `kind-infrastructure/isolated/cluster.py` 流程建立；KIND CLI 0.33.0。原 `deploy-kind.conf`、`kind-cluster.yaml` 和旧节点构建脚本未改。
- 新节点本地 tag `sunmoon-offline/node:597367624b4748b7`，来自官方 `kindest/node:v1.36.4` amd64 摘要 `sha256:597367624b4748b74b98e4fe2d661cd78063d02ecdaca702fd90572375b83e67`。拉取/重标/导出/导入，未另写 Dockerfile 构建节点镜像；镜像本身不预装 Harbor。
- 新节点未执行正式入口的 `apply-kind-registry-config.sh`，没有配置 `harbor.sunmoonai.com:30443` 正式 CRI 信任。恢复演练中只给新 worker2 设置过临时域名的信任，已撤销且复核原文件摘要；不能由此推断正式入口已可拉取。
- 旧 Harbor TLS 沿用原证书，WSL Docker 对既有 Node 摘要 pull 成功。`app-images` 39 仓库、`k8s-images` 25 仓库和空 `library` 项目保留。示例 `app-images/sandbox:0.155.1-r2` index digest 为 `sha256:dbafbcd4eba426fe2a8aa89545214a90b80ae38d508bf1bcee55dda7d41502af`。
- 冷备份根 `~/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z`；6 份数据归档 16.85 GiB；首轮只读恢复全部目录/读取通过，jobservice 保持 0，后台能力未验。现有源服务与备份同一主机，未形成独立介质灾备。
- 没有一份建新集群之前完整的旧 `kubectl get pv,pvc -A` 原始输出；有后续旧集群 20 PVC 盘点及 Harbor 冷备份存储元数据，不能把后补记录冒充更早快照。
- 原 luna-task 的 E2E 没有必须升级 KIND 的安装错误依据。本次升级来自所有者调整为生产实践评估后的独立批准；E2E 仍在后续，不应写成“1.27 装不了某组件所以升级”。

## 4. 哪些文件改了

本地评审总基线 `7896b339`（方案前），独立建群实施基线 `bee0b049ca9e84fead641928816fec4a6a1c6c48`；两者不可混为同一次提交。完整逐文件清单见 [文件列表](luna-changed-files.20260927.txt)。也可在所有者同步分支后执行：

```sh
git diff --stat 7896b339..luna
git diff --name-status 7896b339..luna
```

| 范围 | 内容及原因 |
| --- | --- |
| `kind-infrastructure/isolated/` | 新集群固定物料、远程准备、离线建群/验证入口；避免改动旧部署流程 |
| `kind-infrastructure/docs/` | 升级、Harbor 保留/演练、下一阶段、物料手册、宿主挂载与 Harbor 待决方案、交接 |
| `cicd-platform/materials/` | Harbor 目录/备份/恢复工具；模板 bundle、工具、包归档下载与离线试验。属于 Harbor/CI 构建物料职责，因此在 kind-infrastructure 之外 |
| `scripts/results/luna-*` | 不含凭据的真实结果、失败修复、清单和可追溯证据 |
| `CHECKPOINT.md` | 授权边界、恢复入口、已完成与待定事项 |

本轮没有改模板/实例应用源码、C1/C2 基础设施、业务 inbox 或网页。主机级变化不在 Git 分支内：已授权网络配置管理入口/配置及家目录《网络管理统一方案.md》、独立离线物料批次、两个独立 kubeconfig 和分版本工具。家目录网络变更清单、备份与恢复方法见该文档第 12–16 节；物料和私有备份不能随分支当成已同步，也不能提交凭据。

## 5. 下一步

所有者已确定统一部署代码、两种建群方式、独立数据 VHDX 和集群外 Harbor；容量建议 60 GiB 待审。远程助手先审阅本分支与方案；本地单元通过不代替独立审阅。审过后由所有者负责合并与派发后续 inbox。当前不启动新一轮部署或主动发送外部消息。新增 [WSL 空间回收与压缩方案](wsl-space-reclamation-plan.md) 也仅为只读盘点与待批候选，不能由审阅分支推导清理授权。
