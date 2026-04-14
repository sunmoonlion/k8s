# K8s 持久化方式及本项目持久化方案设计

> 更新时间：2026-04-14

---

## 一、K8s 持久化方式全景

### 1.1 分类总览

```
K8s 持久化方式
├── 第一大类：直接挂载（Volume，Pod 级别，不经过 PV/PVC 体系）
│   ├── 临时挂载：emptyDir
│   ├── 持久挂载：hostPath
│   └── hostPath 变种：Local Volume（hostPath + nodeAffinity）
│
└── 第二大类：通过 PV/PVC 体系挂载
    ├── 静态供应（Static Provisioning）
    │   ├── 管理员手动创建 PV，PVC 按 storageClassName + 容量匹配绑定
    │   └── PVC 通过 volumeName 精确绑定指定 PV
    │
    └── 动态供应（Dynamic Provisioning）
        └── StorageClass + Provisioner 自动创建 PV
            ├── local-path-provisioner（Rancher，轻量，Kind 内置）
            ├── NFS Provisioner（共享存储）
            └── 其他（Longhorn、Ceph、云厂商 CSI 等）
```

---

### 1.2 第一大类：直接挂载（Volume）

直接在 Pod spec 中定义，与 PV/PVC 无关，生命周期跟着 Pod 或节点走。

#### 1.2.1 emptyDir（临时挂载）

```yaml
volumes:
  - name: cache
    emptyDir: {}
```

- Pod 启动时创建，Pod 销毁时随之消失
- 同一 Pod 内多个容器可共享
- 适合：缓存、临时计算文件、容器间共享数据

#### 1.2.2 hostPath（持久挂载）

```yaml
volumes:
  - name: data
    hostPath:
      path: /data/myapp
      type: DirectoryOrCreate
```

- 挂载节点（宿主机）上的指定目录
- Pod 销毁后数据留在那台节点上
- 致命缺点：Pod 重新调度到其他节点后找不到数据

#### 1.2.3 Local Volume（hostPath + nodeAffinity）

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-local-pv
spec:
  storageClassName: ""
  hostPath:
    path: /data/myapp
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [my-node-1]
```

- 本质是 hostPath，但通过 `nodeAffinity` 告诉 K8s 调度器：使用此 PV 的 Pod 必须调度到指定节点
- 补了 hostPath 最大的漏洞——Pod 漂移后找不到数据
- 代价：数据与节点强绑定，该节点宕机则数据不可用（无高可用）

**三者对比**

| | emptyDir | hostPath | Local Volume |
|--|--|--|--|
| 数据生命周期 | Pod 生命周期 | 节点上永久 | 节点上永久 |
| Pod 重调度 | 新 Pod 空盘 | 新节点上无数据 | 强制回原节点 |
| 经过 PV/PVC | 否 | 否 | 是（静态 PV） |
| 生产可用性 | 不建议持久化 | 不建议 | 单节点场景可用 |

---

### 1.3 第二大类：通过 PV/PVC 体系

PV（PersistentVolume）是集群级别的存储资源，PVC（PersistentVolumeClaim）是 Pod 对存储的申请。两者解耦后，Pod 只关心"我要多大、什么访问模式的存储"，不关心底层怎么实现。

#### 1.3.1 静态供应（Static Provisioning）

管理员提前手动创建 PV，PVC 创建时 K8s 去找匹配的 PV 绑定。

> 静态供应是**一种供应方式**，PVC 绑定 PV 有两种写法：

**写法一：条件匹配**（K8s 自动从可用 PV 中找满足条件的）

匹配条件：`storageClassName` 相同 + `accessModes` 兼容 + 容量满足（三者同时满足）。有多个候选 PV 时选容量最接近的。

```yaml
# 管理员创建 PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 8Gi
  accessModes: [ReadWriteOnce]
  storageClassName: ""          # 空 = 不走 SC，只能静态绑定
  hostPath:
    path: /data/myapp
---
# 用户创建 PVC，不写 volumeName，K8s 按条件自动匹配
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 8Gi
  storageClassName: ""          # 与 PV 的 storageClassName 一致，才能匹配
```

**写法二：精确指定**（volumeName，直接点名绑哪个 PV）

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  volumeName: my-pv             # 跳过匹配逻辑，1:1 绑定
  storageClassName: ""
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 8Gi
```

> **补充：Helm 层的 existingClaim**
>
> 这不是第三种绑定方式，而是 Helm Chart 的约定——跳过 PVC 创建，直接引用一个已存在的 PVC。
> 该 PVC 本身可能是静态绑定的，也可能是动态创建的，与供应方式无关。
>
> ```yaml
> # Helm values.yaml
> persistence:
>   existingClaim: my-pvc       # Helm 不再创建 PVC，直接用这个
> ```

#### 1.3.2 动态供应（Dynamic Provisioning）

用户创建 PVC 时，K8s 通过 StorageClass 找到对应 Provisioner，由 Provisioner 自动创建 PV 并绑定。

```yaml
# 1. 管理员创建 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer

---
# 2. 用户创建 PVC，触发自动建 PV
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  storageClassName: local-path
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 8Gi
```

**常见 Provisioner 对比**

| Provisioner | 适合场景 | 高可用 | 数据位置 |
|--|--|--|--|
| rancher.io/local-path | 开发 / 单节点 / Kind | 否 | 节点本地目录 |
| NFS Provisioner | 多 Pod 共享读写 | 依赖 NFS 服务器 | NFS 服务器 |
| Longhorn | 生产多副本 | 是（多副本） | 节点本地，跨节点复制 |
| 云厂商 CSI（如 AWS EBS）| 云原生生产 | 依赖云服务 | 云存储 |

---

### 1.4 静态供应 vs 动态供应

| | 静态供应 | 动态供应 |
|--|--|--|
| PV 创建者 | 管理员手动 | Provisioner 自动 |
| 适合场景 | 固定数据目录、集群重建后复用数据 | 按需创建、不关心数据在哪 |
| 路径/UUID | 管理员指定，固定 | Provisioner 生成，含 UUID |
| 数据复用 | 容易（路径固定）| 困难（UUID 变化）|
| 运维成本 | 需提前建 PV | 零操作 |

---

## 二、本项目持久化方案

### 2.1 环境分层

项目按运行环境分三层，每条路只有一种做法，无开关：

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 1：Kind（WSL 本地开发）                                 │
│    静态 hostPath PV（*-kind-pv-pvc.yaml）+ dev-values-kind.yaml│
│    数据固定写入 WSL /data/kind-local-storage/，集群重建后保留   │
├──────────────────────────────────────────────────────────────┤
│  Layer 2：Remote（C1/C2，真实 K8s 集群）                       │
│    动态 local-path SC + dev-values.yaml                       │
│    数据在节点容器内（含 UUID 路径），重建后丢失                  │
├──────────────────────────────────────────────────────────────┤
│  Layer 3：Production                                         │
│    动态 fast-ssd SC + prod-values.yaml                        │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 StorageClass 设计

| 环境 | SC 名称 | Provisioner | 创建方式 |
|--|--|--|--|
| Kind | 不使用 SC（静态 PV，`storageClassName: ""`）| 无 | 手动 apply *-kind-pv-pvc.yaml |
| Remote | `local-path` | rancher.io/local-path | step09 脚本安装 local-path-provisioner |
| Production | `fast-ssd` | 云厂商 CSI | 集群初始化时配置 |

> Kind 内置了 local-path-provisioner（SC 名为 `standard`，kind-up 时会创建 `local-path` 别名），但本项目在 Kind 下使用静态 hostPath PV，不依赖 provisioner。

### 2.3 Kind 部署机制

Kind 下唯一的部署方式，无模式开关：

```
WSL 宿主机                     Kind 第一个 worker 节点（容器）      Pod
/data/kind-local-storage   →  /data/kind-local-storage        →  静态 PV → PVC → Pod
（集群删除后仍在）            （extraMounts 挂入，kind-cluster.yaml）
```

**关键设计点**

| 特征 | 说明 |
|--|--|
| `storageClassName: ""` | 不走 SC，纯静态绑定，provisioner 不参与 |
| `persistentVolumeReclaimPolicy: Retain` | PVC 删除后 PV 和数据保留 |
| `hostPath.type: DirectoryOrCreate` | 目录不存在时自动创建 |
| `nodeAffinity` 指向 `kind-worker` | 强制 Pod 调度到 extraMounts 所在节点 |
| 路径固定（无 UUID）| YAML 写一次永久有效，无需更新脚本 |
| extraMounts 挂在第一个 worker | control-plane 不承载有状态负载 |

**集群重建后数据自动恢复**：WSL 宿主机目录始终存在，重建集群后 apply 同一份 `*-kind-pv-pvc.yaml`，Pod 绑回原目录，数据即恢复。

**想清空数据**：`rm -rf /data/kind-local-storage/<component>/*`，无需改部署方式。

### 2.4 各组件 Kind 静态 PV 配置

有状态组件分两组，反映历史演进中的完整度差异：

**第一组：已有静态 PV 支持（6 个）**

| 组件 | 平台 | Kind PV 路径 | Kind PV 容量 |
|--|--|--|--|
| PostgreSQL | data-platform | `/data/kind-local-storage/postgresql` | 8 Gi |
| Redis | data-platform | `/data/kind-local-storage/redis` | 5 Gi |
| MongoDB | data-platform | `/data/kind-local-storage/mongodb` | 8 Gi |
| Neo4j | data-platform | `/data/kind-local-storage/neo4j` | 20 Gi |
| Elasticsearch | data-platform | `/data/kind-local-storage/elasticsearch` | 8 Gi |
| RabbitMQ | messaging-platform | `/data/kind-local-storage/rabbitmq` | 10 Gi |

**第二组：待补充静态 PV（4 个）**

| 组件 | 平台 | Kind PV 路径 |
|--|--|--|
| Harbor | cicd-platform | `/data/kind-local-storage/harbor` |
| Jenkins | cicd-platform | `/data/kind-local-storage/jenkins` |
| Casdoor | app-platform | `/data/kind-local-storage/casdoor` |
| pgAdmin | ops-platform | `/data/kind-local-storage/pgadmin` |

**WSL 目录初始化（一次性）**

```bash
sudo mkdir -p /data/kind-local-storage/{postgresql,redis,mongodb,neo4j,elasticsearch,rabbitmq,harbor,jenkins,casdoor,pgadmin}
sudo chmod -R 777 /data/kind-local-storage
```

**生产配置（不涉及重构）**

| 组件 | SC | 容量 | 副本数 |
|--|--|--|--|
| PostgreSQL | fast-ssd | 100 Gi | primary×1，replica×2 |
| Redis | fast-ssd | 20 Gi | master×1，replica×2 |
| MongoDB | fast-ssd | 100 Gi | 3（ReplicaSet）|
| Neo4j | fast-ssd | 100 Gi | 3 |
| Elasticsearch | fast-ssd | 100 Gi | master×3 |
| RabbitMQ | fast-ssd | 50 Gi | 3 |

### 2.5 文件结构

**第一组（已有静态 PV）每个组件**：

```
resources/custom-values/
├── dev-values.yaml           ← Remote 使用，动态 local-path
├── dev-values-kind.yaml      ← Kind 使用，existingClaim 指向静态 PVC
├── <component>-kind-pv-pvc.yaml  ← Kind 专用静态 hostPath PV/PVC
└── prod-values.yaml          ← 生产，fast-ssd
```

**第二组（待补充）每个组件**：

```
resources/custom-values/
├── dev-values.yaml           ← 当前 Kind + Remote 共用（待拆分）
├── dev-values-kind.yaml      ← 待新建
├── <component>-kind-pv-pvc.yaml  ← 待新建
└── prod-values.yaml          ← 不动
```

### 2.6 关键代码位置

| 内容 | 位置 |
|--|--|
| Kind 集群配置（extraMounts 在 kind-worker）| `sunmoonai/kind-infrastructure/deploy-kind/kind-cluster.yaml` |
| local-path SC 别名 manifest | `sunmoonai/kind-infrastructure/manifests/storageclass-local-path.yaml` |
| SC 别名自动应用逻辑 | `sunmoonai/kind-infrastructure/apply-namespaces-existing-cluster.sh` |
| Remote SC 安装脚本 | `sunmoonai/infrastructure/steps/step09_storage.sh` |
| Remote SC 配置 | `sunmoonai/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf`（STEP09_LOCAL_STORAGE_CLASS_NAME） |
| 静态 PV/PVC（第一组，已有）| `sunmoonai/<platform>/<component>/resources/custom-values/*-kind-pv-pvc.yaml` |
| 静态 PV/PVC（第二组，待建）| harbor / jenkins / casdoor / pgadmin 对应目录 |
