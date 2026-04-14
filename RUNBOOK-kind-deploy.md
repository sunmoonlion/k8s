# Kind 集群部署 Runbook

> **用途**：新对话启动时，Claude 先读此文件，即可无缝接续上次工作。
> **最后更新**：2026-04-14（持久化重构 + NFS 全清理完成后）

---

## 一、项目是什么

**仓库**：`gitee.com/sunmoonlion/k8s`，本地路径 `C:\Users\Administrator\Desktop\k8s`（Windows）或 `/mnt/c/Users/Administrator/Desktop/k8s`（WSL）。

这是 SunMoonAI 平台的 K8s 基础设施仓库，管理所有组件的 Helm 部署脚本和配置。
- **Kind**：本地开发集群（WSL 中运行，Docker 容器模拟节点）
- **Remote（C1/C2）**：远程真实集群
- **Production**：生产集群（暂不涉及）

**当前阶段**：Kind 本地环境搭建与调试，重心在数据平台和基础服务。

---

## 二、最近做了什么（本轮重构，2026-04-14）

### 2.1 持久化重构（commit `8887c60`）

**背景**：原有 init/reuse 双模式设计从 NFS 时代遗留，逻辑根本上存在缺陷（两个模式的数据路径不通，reuse 依赖 init 但路径不衔接）。彻底废弃，改为：

| 环境 | 供应方式 | values 文件 |
|---|---|---|
| Kind | 静态 hostPath PV（预建 PV/PVC YAML） | `dev-values-kind.yaml` |
| Remote | 动态 local-path（provisioner 自动） | `dev-values.yaml` |
| Prod | 动态 fast-ssd | `prod-values.yaml` |

**Kind 持久化核心原理**：
- WSL 宿主机目录 `/data/kind-local-storage/` → extraMounts 挂入 Kind worker 节点 → 静态 PV 的 hostPath 指向同一路径 → `kind delete cluster` 后数据仍在 WSL
- 所有静态 PV nodeAffinity 指向 `kind-worker`（第一个 worker，不是 control-plane）

**文件命名约定**（重构后）：
- `dev-values-kind.yaml` — Kind 专用 values（含 `existingClaim`）
- `dev-values.yaml` — Remote 专用 values（动态 SC）
- `*-kind-pv-pvc.yaml` — Kind 静态 PV/PVC 定义（部署前 `kubectl apply`，幂等）

**涉及组件**（共 10 个，分两组）：

第一组（data-platform + messaging）：
- postgresql、redis、mongodb、neo4j、elasticsearch（`data-platform-dev` 命名空间）
- rabbitmq（`messaging-platform-dev` 命名空间）

第二组（新增 Kind 支持）：
- harbor、jenkins（`cicd-platform-dev` 命名空间）
- casdoor（`app-platform-dev` 命名空间）
- pgadmin（`ops-platform-dev` 命名空间）

**脚本改动**：所有 10 个组件的部署脚本均改为：
```bash
local cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"
if [[ "$cluster_lower" == "kind" ]]; then
    kubectl apply -f *-kind-pv-pvc.yaml   # 幂等，每次部署前 apply
    helm upgrade --install ... -f dev-values-kind.yaml
else
    helm upgrade --install ... -f dev-values.yaml
fi
```

### 2.2 NFS 全面清理（commit `9cd6b21`）

删除了所有 NFS 相关文件和内容，包括：
- NFS 脚本/包：`wsl-setup-nfs-server.sh`、`download-nfs-chart.sh`、`nfs-subdir-*.tgz`
- NFS 文档：`nfs的选择.md`、`nfs-storage-architecture.md` 等
- NFS 时代 PV 模板：6 个 `*-dev-pv-pvc.template.yaml`
- `utils/重建持久化数据/` 整目录
- 所有 `.conf` 文件中的 `PERSIST_MODE` / `SUNMOONAI_GLOBAL_PERSIST_MODE` 块
- 所有 values 文件中的 `nfs-storage` toleration
- 所有 app `.conf` 中的 `PVC_STORAGE_CLASS=nfs-1` → 改为 `local-path`

**有意保留不动**：`prod-values.yaml` 中的 `nfs-storage` SC（生产环境待单独验证）、`infrastructure/steps/step09_storage.sh`（远端集群基础设施）。

---

## 三、Kind 集群节点结构

```yaml
# kind-cluster.yaml 当前结构
- role: control-plane      # 无 extraMounts，不跑有状态组件
- role: worker             # 第一个 worker：extraMounts /data/kind-local-storage
- role: worker             # 第二个 worker：无 extraMounts，跑无状态组件
```

StorageClass 情况：
- `standard`（内置，local-path-provisioner）— Remote 用
- `local-path`（alias，由 `manifests/storageclass-local-path.yaml` 创建）— 同上
- 静态 PV（`storageClassName: ""`）— Kind 专用，不走任何 SC

---

## 四、WSL 目录初始化（首次或重建集群后执行一次）

```bash
sudo mkdir -p /data/kind-local-storage/{postgresql,redis,mongodb,neo4j,elasticsearch,rabbitmq,harbor,jenkins,casdoor,pgadmin}
sudo chmod -R 777 /data/kind-local-storage
```

各组件数据路径：

| 组件 | WSL 路径 | PVC 名称 |
|---|---|---|
| PostgreSQL | `/data/kind-local-storage/postgresql` | `postgresql-sunmoonai-dev-pvc` |
| Redis | `/data/kind-local-storage/redis` | `redis-sunmoonai-dev-pvc` |
| MongoDB | `/data/kind-local-storage/mongodb` | `mongodb-sunmoonai-dev-pvc` |
| Neo4j | `/data/kind-local-storage/neo4j` | `neo4j-sunmoonai-dev-pvc` |
| Elasticsearch | `/data/kind-local-storage/elasticsearch` | `elasticsearch-sunmoonai-dev-pvc` |
| RabbitMQ | `/data/kind-local-storage/rabbitmq` | `rabbitmq-sunmoonai-dev-pvc` |
| Harbor | `/data/kind-local-storage/harbor` | `harbor-sunmoonai-trivy-dev-pvc` |
| Jenkins | `/data/kind-local-storage/jenkins` | `jenkins-sunmoonai-dev-pvc` |
| Casdoor | `/data/kind-local-storage/casdoor` | `casdoor-sunmoonai-dev-pvc` |
| pgAdmin | `/data/kind-local-storage/pgadmin` | `pgadmin-sunmoonai-dev-pvc` |

---

## 五、Kind 部署流程

### 5.1 前置条件

```bash
# WSL 中确认 Docker 在运行
docker info

# 确认 kind 已安装
kind version

# 确认 kubectl 已安装
kubectl version --client
```

### 5.2 创建集群

```bash
cd /mnt/c/Users/Administrator/Desktop/k8s/sunmoonai/kind-infrastructure/deploy-kind
bash deploy-kind.sh
```

或通过总控（设置 `infrastructure_enabled=true`）：

```bash
CLUSTER=kind bash deploy-sunmoonai-all.sh deploy sunmoonai development false
```

### 5.3 部署各平台组件

```bash
cd /mnt/c/Users/Administrator/Desktop/k8s/sunmoonai/deploy-sunmoonai-all
CLUSTER=kind bash deploy-sunmoonai-all.sh deploy sunmoonai development false
```

> `CLUSTER=kind` 这个环境变量是触发静态 PV 分支的关键，缺少它会走 Remote 逻辑。

### 5.4 单独部署某个组件（调试用）

```bash
# 以 postgresql 为例
CLUSTER=kind bash /mnt/c/.../sunmoonai/data-platform/postgresql/deploy-postgresql/deploy-postgresql.sh deploy sunmoonai data-platform-dev development false
```

### 5.5 验证持久化

```bash
# 部署后检查 PV 是否绑定
kubectl get pv,pvc -A | grep sunmoonai

# 检查数据是否写到 WSL 宿主机
ls /data/kind-local-storage/postgresql/
```

### 5.6 验证集群重建后数据恢复

```bash
kind delete cluster
# 重新走 5.2 → 5.3
# 验证 /data/kind-local-storage/ 下数据仍在
# 部署后 PVC 重新绑定，组件读到旧数据
```

---

## 六、关键文件索引

```
k8s/
├── RUNBOOK-kind-deploy.md              ← 本文件
├── k8s持久化方式及本项目持久化方案设计.md   ← 持久化架构完整说明
├── 再次重构方案.md                      ← 本轮重构的设计决策记录
├── sunmoonai/
│   ├── kind-infrastructure/
│   │   └── deploy-kind/
│   │       ├── kind-cluster.yaml       ← Kind 集群定义（节点 + extraMounts）
│   │       └── deploy-kind.sh          ← Kind 集群一键部署脚本
│   ├── deploy-sunmoonai-all/
│   │   ├── deploy-sunmoonai-all.sh     ← 总控部署脚本
│   │   └── deploy-sunmoonai-all.conf   ← 总控配置（开关各平台）
│   └── data-platform/postgresql/
│       └── resources/custom-values/
│           ├── dev-values-kind.yaml    ← Kind 专用（existingClaim）
│           ├── dev-values.yaml         ← Remote 专用（动态 SC）
│           └── postgresql-kind-pv-pvc.yaml  ← Kind 静态 PV/PVC
```

---

## 七、已知问题 / 待确认事项

1. **Harbor PVC**：harbor 的 `dev-values-kind.yaml` 只挂了 `trivy` 子组件的 PVC（其余组件用内置 PG/Redis，无需额外 PVC）。如果 harbor 本身的 registry 存储也需要持久化，需要额外添加。

2. **prod-values.yaml 中的 SC**：仍为 `nfs-storage`，等生产环境验证时统一改为 `fast-ssd`。

3. **Casdoor app.conf**：Casdoor 的 `/conf/app.conf` 需要在首次部署后手动写入（PVC 挂载覆盖了镜像内置文件），参见 `casdoor/resources/custom-values/dev-values-kind.yaml` 中的注释。

4. **infrastructure/steps/step09_storage.sh**：仍含 NFS provisioner 安装逻辑，远端集群基础设施待单独重构。

---

## 八、Admin 密码速查

- Casdoor admin：`ChangeMeASAP123!`
- Harbor admin：见 `deploy-sunmoonai-all.conf` 中 `HARBOR_ADMIN_PASSWORD`

---

> **新对话启动口令**：「读 RUNBOOK-kind-deploy.md，然后接续工作」
