# NFS + 多 StorageClass 存储运维规范（适用于本地磁盘 + NFS 聚合方案）

> 本文档用于**明确当前集群的存储使用模型、职责边界与风险处理方式**。
>
> 目标不是“自动化存储”，而是：
> **在没有云盘、没有分布式存储的前提下，安全、可控地充分利用 3 个 node 的本地磁盘容量。**

---

## 1. 架构背景与前提

### 1.1 集群条件

- 3 台 Kubernetes Node：`node1 / node2 / node3`
- 每个 node：
  - 有本地磁盘
  - 运行一个 NFS Server
- **每个 NFS Server 均可访问 3 个 node 的磁盘**（通过挂载或其他方式）

### 1.2 核心设计思想

- **StorageClass 用于区分 NFS I/O 入口节点**
- **NFS Server 负责磁盘路径与真实磁盘的映射**
- **磁盘使用权与容量规划由人工管理**

> Kubernetes 仅负责 PVC 生命周期，不负责存储调度与容量均衡。

---

## 2. StorageClass 设计规范

### 2.1 StorageClass 的语义定义（非常重要）

> **一个 StorageClass = 一个 NFS I/O 入口节点**

而不是：
- 存储能力
- 磁盘类型
- 自动调度策略

### 2.2 StorageClass 命名规范（强制）

```text
sc-nfs-node1
sc-nfs-node2
sc-nfs-node3
```

看到 StorageClass 名称即可明确：

> PVC 的 I/O 从哪个 node 进入

### 2.3 StorageClass 示例

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sc-nfs-node1
provisioner: nfs.csi.k8s.io
parameters:
  server: <node1-ip>
  share: /exports
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

---

## 3. NFS Server 与磁盘映射规则（核心规则）

### 3.1 导出目录与磁盘的绑定关系

**强制规则：一个导出目录，只映射一块真实磁盘**

示例（node1 上）：

```text
/exports/disk-node1  → node1 本地磁盘
/exports/disk-node2  → 挂载的 node2 磁盘
/exports/disk-node3  → 挂载的 node3 磁盘
```

### 3.2 磁盘使用权规则（红线）

> **同一块真实磁盘，在任意时刻，只允许一个 NFS Server 以 RW 方式导出**

推荐绑定策略：

```text
disk-node1 → 仅由 NFS(node1) RW 导出
disk-node2 → 仅由 NFS(node2) RW 导出
disk-node3 → 仅由 NFS(node3) RW 导出
```

其他 NFS Server：
- 不挂载
- 或只读（RO）
- 或完全不可见

---

## 4. PVC 使用规范

### 4.1 强制要求

- ❌ 禁止使用 default StorageClass
- ❌ 禁止省略 `storageClassName`
- ❌ 禁止修改已有 PVC 的 StorageClass

### 4.2 PVC 示例

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-a-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: sc-nfs-node2
  resources:
    requests:
      storage: 100Gi
```

含义：
- PVC 的 I/O 从 node2 进入
- 后端磁盘由 NFS(node2) 统一管理

---

## 5. 容量管理与监控（K8s 不负责）

### 5.1 事实说明

- StorageClass 不感知真实磁盘容量
- PVC 创建不会校验剩余空间
- **容量规划完全依赖人工**

### 5.2 容量台账（强烈建议）

```text
磁盘名        真实位置        总量    已用    负责人
disk-node1    node1:/data     2T      1.3T    张三
disk-node2    node2:/data     2T      0.8T    李四
disk-node3    node3:/data     4T      3.2T    王五
```

### 5.3 磁盘水位检查

```bash
df -h /exports/disk-*
```

阈值建议：

- ≥ 70%：预警
- ≥ 85%：禁止新 PVC
- ≥ 90%：必须迁移数据

---

## 6. 数据迁移规范（唯一允许方式）

### 6.1 严禁操作

- ❌ 热切换 StorageClass
- ❌ 多 NFS Server 同时写同一磁盘
- ❌ 在线修改挂载路径

### 6.2 正确迁移流程

1. 停止应用或切换为只读
2. 创建新 PVC（指定新 SC）
3. 使用 rsync 迁移数据

```bash
rsync -av --numeric-ids /old/ /new/
```

4. 修改 Pod 挂载
5. 验证数据
6. 下线旧 PVC

---

## 7. 主要风险点与处理方式（重点）

### 风险 1：多 NFS Server 同时写同一磁盘（致命）

**后果：**
- 文件系统损坏
- 数据不可恢复

**处理方式：**
- 明确磁盘“主控 NFS Server”
- 文档 + 人工流程约束
- 禁止共享 RW 导出

---

### 风险 2：NFS Server 单点故障

**影响：**
- 所有使用该 SC 的 PVC 不可用

**处理方式：**
- NFS Server 节点不跑业务 Pod
- 不进行强制 SC 切换
- 恢复 node 后再恢复服务

---

### 风险 3：磁盘空间耗尽

**影响：**
- 应用异常
- 写入失败

**处理方式：**
- 容量台账
- 定期检查 df
- 提前迁移 PVC

---

## 8. 官方总结说明（可用于对外说明）

> *“我们使用多个 StorageClass 来区分 NFS I/O 入口节点，
> NFS Server 后端映射多台 node 的本地磁盘资源，
> 通过人工规划磁盘使用权与容量来充分利用现有磁盘能力。
> Kubernetes 负责生命周期管理，但不承担存储调度职责。”*

---

## 9. 最终结论

- 架构：✔ 合理
- 使用方式：✔ 正确
- 风险：✔ 已识别、可控制

**前提：**

> 使用工程纪律，替代分布式存储系统的自动化能力。

---

（文档结束）

