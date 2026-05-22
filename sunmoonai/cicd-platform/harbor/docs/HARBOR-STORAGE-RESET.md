# Harbor 静态存储：全自动清盘与重装

Harbor 使用 **hostPath 静态 PV**。清盘或重装后若目录属主为 `root:root`，PostgreSQL / Redis（uid **1001**）会失败，对外表现为 **HTTP 503**。

**正常操作不需要登录节点手工删目录**——由 `deploy-harbor.sh` 与 `kind-up.sh` 自动完成 SSH/本地清盘、`chown`、Helm 部署与工作负载重启。

---

## 1. 全自动入口（与现有总控一致）

### Kind 整机重来（推荐）

`deploy-kind.conf`：

```bash
RECREATE_KIND_CLUSTER_IF_EXISTS="true"
CLEAN_PV_DATA_ON_RECREATE="true"
```

然后一条总控（与你们一直用的方式相同）：

```bash
export CLUSTER=KIND KUBECONFIG=$HOME/.kube/kind-config
cd k8s/sunmoonai/deploy-sunmoonai-all
./deploy-sunmoonai-all.sh deploy sunmoonai development false
```

流程自动包含：`kind-up` 删集群 → 清 `/data/kind-local-storage`（含隐藏文件）→ `chown harbor` → `deploy-kind` → `deploy-harbor deploy`（部署前再次 ensure 权限）。

### 仅 Harbor 重来（Kind 或 C1）

```bash
cd k8s/sunmoonai/cicd-platform/harbor/deploy-harbor
export CLUSTER=KIND   # 或 C1
export KUBECONFIG=...   # Kind 用 ~/.kube/kind-config

./deploy-harbor.sh clean sunmoonai
```

`clean` **全自动**执行：

1. 卸载 Helm、删 PVC/PV  
2. **SSH 到存储节点**（C1 为 `hsy-local-3`）或 **WSL sudo**（Kind）清空 `harbor/*` 并 `chown 1001:1001`  
3. 默认 `HARBOR_CLEAN_AUTO_REDEPLOY=true`：**紧接着自动 `deploy`**，无需再敲第二条命令  

### 不卸 Helm、只修盘权限（少见）

```bash
./deploy-harbor.sh reset-host-data sunmoonai
```

自动：宿主机清盘 + chown + **kubectl 删除/重启 Harbor Pod**。

---

## 2. 路径（脚本自动处理，无需记）

| 环境 | 节点 | 宿主机路径 |
|------|------|------------|
| Kind | `kind-worker` | `/data/kind-local-storage/harbor/*` |
| C1/C2 | `HARBOR_STORAGE_NODE_HOSTNAME`（默认 `hsy-local-3`） | `/data/local-storage/harbor/*` |

配置：`deploy-harbor.conf` 的 `HARBOR_STORAGE_*`、`KIND_HARBOR_STORAGE_BASE_PATH`；SSH 节点来自 `deploy-infrastructure-all.conf` 的 `C1_SERVER_n_CLUSTER_HOSTNAME`。

---

## 3. 脚本内自动化说明

| 时机 | 行为 |
|------|------|
| `deploy` | 安装前 `harbor_host_storage_prepare false`（mkdir + chown，不删数据） |
| `clean` | 清 K8s + 宿主机；默认自动 `deploy` |
| `reset-host-data` | 清宿主机 + `restart_harbor_workloads` |
| `kind-up`（`CLEAN_PV_DATA_ON_RECREATE=true`） | 清 PV + harbor `chown` |
| Helm values | registry / postgresql / redis 的 `fix-storage-owner` initContainer |

**不要用 `rm 目录/*` 清盘**（删不掉隐藏文件）；脚本使用 `find -mindepth 1 -delete`。

---

## 4. 故障排查（仅当自动化失败时）

| 现象 | 处理 |
|------|------|
| `无法解析存储节点 SSH` | 核对 `HARBOR_STORAGE_NODE_HOSTNAME` 与 `C1_SERVER_*_CLUSTER_HOSTNAME` |
| `远程宿主机 Harbor 目录准备失败` | 检查 aly-ecs → 节点 3 的 SSH、`sudo` |
| 关闭 clean 后自动重装 | `deploy-harbor.conf` → `HARBOR_CLEAN_AUTO_REDEPLOY=false` |

仅在 SSH 完全不可用时，才需要在存储节点上对照旧版命令手工执行；那不是常规流程。

---

## 5. 相关文件

- `deploy-harbor/deploy-harbor.sh` — `harbor_host_storage_prepare`、`clean`、`reset-host-data`
- `deploy-harbor/deploy-harbor.conf` — `HARBOR_CLEAN_AUTO_REDEPLOY`
- `kind-infrastructure/kind-up.sh` — Kind 重建清 PV
- `resources/custom-values/dev-values.yaml` / `dev-values-kind.yaml`
