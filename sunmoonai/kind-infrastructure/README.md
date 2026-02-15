# Kind / 现成集群平台初始化

本目录提供 **创建 Kind 集群** 与 **对现成集群做平台初始化**（命名空间 + 本地存储）。配置与 k8s-admin.conf、deploy-infrastructure-all 同源，详见仓库根目录《现成集群平台初始化.md》。

## 1. 创建 Kind 集群

| 文件 | 说明 |
|------|------|
| `create-kind-cluster.sh` | 创建 Kind 集群，集群名与 kubeconfig 路径从 `k8s/utils/k8s-admin.conf` 的 [KIND] 读取。 |
| `kind-cluster.yaml` | Kind 集群拓扑默认：**1 control-plane + 2 workers**；worker 数量也可由脚本参数或环境变量指定。 |

**Worker 数量配置（任选其一）：**

- **环境变量**：`KIND_WORKER_COUNT=6 ./create-kind-cluster.sh`
- **脚本参数**：`./create-kind-cluster.sh 6`
- **不指定**：使用 `kind-cluster.yaml`（默认 2 workers）；要改默认可编辑该文件增删 `- role: worker` 行。

```bash
./create-kind-cluster.sh          # 默认 2 workers（或按 kind-cluster.yaml）
./create-kind-cluster.sh 6        # 6 个 workers
KIND_WORKER_COUNT=8 ./create-kind-cluster.sh   # 8 个 workers
```

创建完成后，kubeconfig 会写入 k8s-admin.conf 中配置的路径（如 `~/.kube/kind-config`）。使用：`export KUBECONFIG=~/.kube/kind-config` 或通过连接管理器连接。

## 2. 平台初始化（命名空间 + 存储）

| 脚本 | 作用 |
|------|------|
| **`setup-kind-platform.sh`** | **阶段三入口**：按顺序执行命名空间 + 存储，一键完成平台初始化。 |
| `apply-namespaces-existing-cluster.sh` | 按 Step07 配置创建命名空间（platform-environment），使用当前 KUBECONFIG。 |
| `apply-storage-local-existing-cluster.sh` | 按 Step09 本地存储配置安装 local-path-provisioner 并创建 StorageClass，使用当前 KUBECONFIG。 |

**使用**：先创建集群并设置 KUBECONFIG，再执行（二选一）：

```bash
./setup-kind-platform.sh
```

或分步执行：

```bash
./apply-namespaces-existing-cluster.sh
./apply-storage-local-existing-cluster.sh
```

配置从 `../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf` 读取；无该文件时使用脚本内默认值。
