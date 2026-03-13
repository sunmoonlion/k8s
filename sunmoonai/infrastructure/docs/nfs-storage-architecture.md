## NFS 存储架构与落盘关系说明

> 适用范围：当前 `step09_storage` / `apply-nfs-existing-cluster` 初始化出的 NFS 存储（`nfs-storage`、`nfs-1`、`nfs-2` 等），以及各平台组件 dev-values 中使用的 `storageClass` 配置。

### 1. Pod / PVC / PV / StorageClass 关系

- **Pod**
  - 一个 Pod 可以挂载 **0~N 个 PVC**。
- **PVC (PersistentVolumeClaim)**
  - 每个 PVC 只能指定 **一个 `storageClassName`**。
  - 一个 PVC 最终只会绑定 **一个 PV**（1:1）。
- **PV (PersistentVolume)**
  - 一个 PV 只能绑定到 **一个 PVC**。
  - 后端实际存储位置由 PV 上的 backend 字段决定：
    - NFS：`spec.nfs.server` + `spec.nfs.path`
    - 本地盘：`spec.hostPath.path` + `spec.nodeAffinity`（绑定某个节点）
- **StorageClass**
  - 定义「**如何创建 PV**」：`provisioner`、`reclaimPolicy`、`volumeBindingMode` 等。
  - 一个 StorageClass 可以被很多 PVC 使用，但 **每个 StorageClass 只能有一个 `provisioner`**。

> **落盘位置永远以 PV 为准**：先 `kubectl get pvc` 找到 PVC → 看 `spec.volumeName` → `kubectl get pv <name> -o yaml` → 通过 `spec.nfs.*` 或 `spec.hostPath.*` 确认真实节点与目录。

---

### 2. 远程集群：多 NFS 服务器 + 多 StorageClass

在 `deploy-infrastructure-all.conf` 中，NFS 相关核心配置：

```bash
# NFS 服务器 1 → 建议给 Harbor 专用盘
STEP09_NFS_SERVER_1_ENABLED=true
STEP09_NFS_SERVER_1_PATH="/data/nfs-storage-1"   # SERVER_1 的 NFS 导出目录

# 统一 NFS StorageClass（方案1）
STEP09_NFS_STORAGE_CLASS_NAME="nfs-storage"
STEP09_NFS_STORAGE_DEFAULT_CLASS=false
STEP09_NFS_STORAGE_RECLAIM_POLICY="Delete"
STEP09_NFS_STORAGE_VOLUME_BINDING_MODE="Immediate"

# 为每个 NFS 服务器创建独立 StorageClass（方案2，当前实际在用）
STEP09_NFS_CREATE_SEPARATE_STORAGE_CLASSES=true
STEP09_NFS_STORAGE_CLASS_PREFIX="nfs"            # 生成 nfs-1、nfs-2、nfs-3...
```

`step09_storage.sh` 中，根据上述配置创建独立的 StorageClass：

```yaml
# 片段：为每个启用的 NFS server 创建独立 SC
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-<idx>   # 例如 nfs-1 / nfs-2
provisioner: cluster.local/nfs-provisioner-<idx>-nfs-subdir-external-provisioner
volumeBindingMode: ${STEP09_NFS_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_NFS_STORAGE_RECLAIM_POLICY}
```

结合 `STEP09_NFS_SERVER_X_PATH`：

- `nfs-1` → 通过 `nfs-provisioner-1` 指向 **SERVER_1 的 `/data/nfs-storage-1`**
- `nfs-2` → 通过 `nfs-provisioner-2` 指向 **SERVER_2 的 `/data/nfs-storage-2`**（依配置而定）

> **结论**：当前系统中，`storageClassName: nfs-1` / `nfs-2` 等，等价于显式选择落到对应 NFS 服务器的对应目录下。

---

### 3. KIND 集群：与远程一致的 `nfs-2`

KIND 场景由 `kind-infrastructure/apply-nfs-existing-cluster.sh` 初始化 NFS 存储：

```yaml
# 片段：在 KIND 中创建统一的 nfs-2 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${KIND_NFS_STORAGE_CLASS_NAME}  # 默认 nfs-2
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: cluster.local/${PROVISIONER_NAME}-nfs-subdir-external-provisioner
volumeBindingMode: ${NFS_VOLUME_BINDING_MODE}
reclaimPolicy: ${NFS_RECLAIM_POLICY}
```

说明：

- KIND 中同样使用 `nfs-subdir-external-provisioner`，但 NFS server 通常是 **WSL/宿主机导出的 NFS 目录**，具体由脚本前半部分根据本机 IP + `KIND_NFS_PATH` 计算。
- 这样 dev-values 里统一写 `storageClass: "nfs-2"`，在远程与 KIND 上都能复用同一套配置，只是 NFS server / path 不同。

> **落盘定位方式与远程相同**：仍然通过 `kubectl get pvc` → `kubectl get pv` → 看 `spec.nfs.server` + `spec.nfs.path`。

---

### 4. 统一 StorageClass `nfs-storage` 与多 SC 的区别

当前 Step09 支持两种模式：

- **统一 SC（方案1）**：
  - 创建名为 `nfs-storage` 的 StorageClass。
  - 后端可由单个或多个 NFS server 支撑（由 provisioner 的实现与部署方式决定）。
  - 应用只写：

    ```yaml
    storageClassName: nfs-storage
    ```

  - 实际落到哪个 NFS 目录，由 **provisioner 内部逻辑** 决定，应用侧不可控。

- **多个 SC（方案2，当前实际使用）**：
  - 为每个启用的 NFS server 创建 `nfs-1`、`nfs-2` 等独立 SC。
  - 应用通过 `storageClassName` 显式指定：

    ```yaml
    # Harbor 专用盘示例
    storageClassName: nfs-1

    # 应用数据盘示例
    storageClassName: nfs-2
    ```

  - 落盘到哪个节点、哪个目录是**可预期的**：
    - `nfs-1` → SERVER_1 的 `/data/nfs-storage-1/...`
    - `nfs-2` → SERVER_2 的 `/data/nfs-storage-2/...`

> 当前仓库中：Harbor、PostgreSQL、Redis、Traefik 等 dev-values 中都显式写了 `storageClass: nfs-1` / `nfs-2`，因此 **实际在用的是「多个 SC + 多 NFS 服务器」的方案2**，`nfs-storage` 更多是保留项。

---

### 5. 删除 Harbor 镜像持久化存储的注意事项

> 下面以 Harbor 为例，说明「删除持久化存储」时的行为与步骤。其它组件（PostgreSQL、Redis 等）类似。

1. **确认 Harbor 使用的 StorageClass 与 PVC**

   ```bash
   # 找出 Harbor 所在命名空间（示例：cicd-platform-dev）
   kubectl get pods -A | grep harbor-core

   # 列出 Harbor 相关 PVC
   kubectl get pvc -n cicd-platform-dev | grep harbor
   ```

2. **从 PVC 找到 PV 与实际存储位置**

   ```bash
   # 以 harbor-registry 为例
   PV_NAME=$(kubectl get pvc harbor-registry -n cicd-platform-dev -o jsonpath='{.spec.volumeName}')
   kubectl get pv "$PV_NAME" -o yaml | sed -n '1,80p'
   ```

   重点关注：

   - `spec.storageClassName` → 使用的是 `nfs-1` / `nfs-2` 或 `nfs-storage`
   - NFS 后端：

     ```yaml
     spec:
       nfs:
         server: 10.x.x.x
         path: /data/nfs-storage-1/subdir-xxxx
     ```

3. **删除 PVC 与 PV 后，底层目录是否被删除**

   由两层配置共同决定：

   - **StorageClass.reclaimPolicy**（当前通过 `STEP09_NFS_STORAGE_RECLAIM_POLICY` / `NFS_RECLAIM_POLICY` 控制）：
     - `Delete`：PVC 删除后，PV 对象会被删除；
     - `Retain`：PVC 删除后，PV 保留在 Kubernetes 中。
   - **NFS provisioner 的 `archiveOnDelete` 等参数**（在 nfs-subdir-external-provisioner 的 Helm values 中配置）：
     - 一般：`archiveOnDelete=true` 时，删除 PVC 会把 NFS 目录重命名为 `archived-...` 而不是物理删除；
     - `archiveOnDelete=false` 且 `reclaimPolicy=Delete` 时，PVC 删除会直接删除对应子目录。

4. **静态 NFS PV 的特殊情况**

   若是手工创建的静态 NFS PV（`spec.nfs.server/path` 写死），即使 `reclaimPolicy=Delete`，**Kubernetes 只会删除 PV 对象，不会自动清理 NFS 服务端的真实目录**。

   这类目录需要登录 NFS 服务器（例如 `/data/nfs-storage-1` 所在节点）后，手动删除对应子目录或整个目录。

---

### 6. 快速排查/定位落盘位置的命令备忘

```bash
# 1）查看某命名空间下所有 PVC 及其 StorageClass
kubectl get pvc -n <namespace>

# 2）从 PVC 跳到 PV
kubectl get pvc <pvc-name> -n <namespace> -o jsonpath='{.spec.volumeName}'

# 3）查看 PV 后端（确认 NFS server + path 或 hostPath + nodeAffinity）
kubectl get pv <pv-name> -o yaml | sed -n '1,80p'

# 4）查看某个 StorageClass 的配置（远程/KIND 通用）
kubectl get sc <storage-class-name> -o yaml
```

以上就是当前项目中 NFS 存储（远程 + KIND）的整体架构和「Pod → PVC → PV → 实际落盘」的关系说明，可作为后续排查存储问题和清理持久化数据的参考文档。
