# Kind 集群部署说明

本文档说明如何在本项目下从零部署 Kind 集群并完成平台初始化，所有步骤均在 **WSL** 中执行。一键部署脚本与配置位于本目录（`deploy-kind/`），其余脚本位于上级目录 `kind-infrastructure/`。

---

## 1. 前置条件

- **WSL**：已安装并可使用
- **Docker**：已安装且运行正常（`docker info` 可用）
- **Kind**：已安装（如 `kind version`）
- **kubectl**：已安装（可选，用于后续部署与验证）

配置与连接方式见 `k8s/utils/k8s-admin.conf` 中 `cluster_mode=kind`、`default_cluster=KIND` 及 `[KIND]` 段；详见《kind使用指南.md》。

---

## 2. 部署步骤

### 2.0 一键部署（推荐）

在 WSL 中执行一次即可完成 NFS 检查/安装、创建集群与平台初始化、镜像预加载、WSL Harbor 域名解析：

```bash
cd k8s/sunmoonai/kind-infrastructure/deploy-kind
./deploy-kind.sh
```

- 配置：同目录 **`deploy-kind.conf`**（NFS 目录、是否生成本地根 CA、registry 配置/镜像预加载/Harbor hosts、Harbor 域名与 IP 等）
- 可选参数：`--skip-ca-init` 跳过本地根 CA 生成，`--skip-registry-config` 跳过 Kind 节点 containerd 镜像拉取配置，`--skip-images` 跳过镜像预加载，`--skip-harbor-hosts` 跳过 WSL 的 Harbor 域名配置

以下为分步说明，脚本均在上级目录 `kind-infrastructure/`。

### 2.1 一次性：安装 NFS 服务（WSL）

若尚未在 WSL 上配置 NFS，执行一次：

```bash
cd k8s/sunmoonai/kind-infrastructure
./wsl-setup-nfs-server.sh
```

用于在 WSL 上安装并导出 NFS 目录，供集群内 StorageClass `nfs-2` 使用。

### 2.2 每次使用：创建集群并做平台初始化

每次要用 Kind 时（含首次、或关机/重启后），在 WSL 执行：

```bash
cd k8s/sunmoonai/kind-infrastructure
./kind-up.sh
```

该脚本会依次：创建 Kind 集群（已存在则跳过）→ 设置 KUBECONFIG → 命名空间初始化 → NFS 存储初始化（StorageClass **nfs-2**）。执行完成后，新开终端需运行连接管理器或 `export KUBECONFIG=~/.kube/kind-config`。

### 2.3 可选：生成本地根 CA（与远程 Step12 同用途）

Kind 不执行 infrastructure 步骤，因此不会运行 Step12；后续部署 Traefik TLS、Harbor 等需要根 CA 签发服务器证书。在 WSL 执行一次（一键部署时默认执行）：

```bash
cd k8s/sunmoonai/kind-infrastructure
./ensure-kind-ca.sh
```

在本地生成根 CA（ca.crt/ca.key）到与 Traefik 一致的路径（`TRAEFIK_CA_LOCAL_DIR`，默认见 deploy-traefik.conf）；若已存在则跳过。与远程 **Step12** / unified-cert-secret-management 的 init 模式同用途。

### 2.4 可选：Kind 节点 containerd 镜像拉取配置（与远程 Step02 对齐）

在 `kind-up.sh` 完成后、预加载镜像前，可执行一次（一键部署时默认执行）：

```bash
cd k8s/sunmoonai/kind-infrastructure
./apply-kind-registry-config.sh
```

在 Kind 各节点内写入 `/etc/containerd/certs.d/`（hosts.toml），与远程 Step02 的 mirror/direct 逻辑一致；配置来源为 `deploy-infrastructure-all.conf` 的 `STEP02_REGISTRY_*`，可在 `deploy-kind.conf` 中覆写。

### 2.5 可选：预加载 Traefik / Harbor 所需镜像

在 `kind-up.sh` 完成后、部署 Traefik 与 Harbor 前，在 WSL 执行一次：

```bash
cd k8s/sunmoonai/kind-infrastructure
./load-images/load-kind-images.sh（或兼容包装 ../load-initial-images-kind.sh）
```

与远程 **Step11** 的镜像预加载等效；镜像列表与 `deploy-infrastructure-all.conf` 中 `STEP_IMAGE_*` 同源。

### 2.6 可选：WSL 宿主机 Harbor 域名解析与登录。

在 WSL 中执行（默认添加 Harbor 解析到 Kind control-plane IP，并可选登录 Harbor）：

```bash
cd k8s/sunmoonai/kind-infrastructure
./wsl-setup-harbor-hosts.sh          # 仅写 /etc/hosts
./wsl-setup-harbor-login.sh          # 分发 CA + docker/nerdctl 登录
```

集群外 Harbor 时：`HARBOR_IP=该入口IP ./wsl-setup-harbor-hosts.sh`。也可在 **`deploy-kind.conf`** 中设置 `HARBOR_IP` 后执行一键部署。  
Harbor 未部署时可只跑 hosts 脚本；部署后需在 WSL 拉取/推送镜像时，可再执行：`./wsl-setup-harbor-login.sh`（或 `HARBOR_ADMIN_PASSWORD=xxx ./wsl-setup-harbor-login.sh`）。

### 2.7 仅改配置在远程与 Kind 间切换

同一套脚本与配置可在**远程集群（C1/C2 等）**与 **Kind** 之间切换，**只需改一处配置**：

- **配置文件**：`k8s/utils/k8s-admin.conf`
- **切到 Kind**：`[GLOBAL]` 中设 `cluster_mode=kind`、`default_cluster=KIND`
- **切回远程**：`cluster_mode=remote`（或 `direct`）、`default_cluster=C1`（或目标集群）

效果：

- **deploy-infrastructure-all.sh**：当目标为 Kind 时会提示“仅用于远程集群”并退出，需用本目录 **deploy-kind.sh** 做 Kind 初始化。
- **各组件部署**（Traefik、Harbor、业务等）：自动使用 Kind 的 kubeconfig，无需改脚本或组件配置。
- **Kind 下行为**：节点镜像检查（check_remote_images）跳过；部署前推镜像到 Harbor 使用 **push-to-harbor**（远程则使用 registry-push-management/loadimage.sh）；Traefik 节点 iptables、Harbor 阶段 4「自动创建项目并推送镜像」跳过。

证书与镜像拉取：Kind 使用 **ensure-kind-ca.sh**（unified-cert combo **TRAEFIK_KIND_KIND**）与 **apply-kind-registry-config.sh**，与远程 Step12/Step02 逻辑一致，配置可来自 deploy-infrastructure-all.conf 或在 deploy-kind.conf 覆写。

### 2.8 备忘：Kind 为何不执行 Harbor「阶段4 推镜像」

Traefik 与 Harbor 共用同一套脚本（如 `deploy-harbor.sh`）。阶段4「自动创建项目并推送控制平面镜像」在脚本内根据 **K8S_TARGET_MODE** 分支：

- **远程（C1/C2…）**：执行 `auto_create_project_and_push_images`，通过 SSH 在控制平面节点上用 nerdctl 把镜像推到 Harbor。
- **Kind**：当 `K8S_TARGET_MODE=kind` 时**跳过**阶段4，因 Kind 无远程节点与 SSH，该逻辑不适用；Kind 的镜像由 `load-kind-images.sh`、`push-to-harbor` 等处理。

详见 `cicd-platform/harbor/deploy-harbor/deploy-harbor.sh` 中阶段4 上方的块注释。

---

## 3. 可选配置说明

### 3.1 本目录配置（deploy-kind.conf）

- `NFS_EXPORT_DIR`：NFS 导出目录，须与 wsl-setup-nfs-server、kind-up 一致
- `DEPLOY_KIND_RUN_CA_INIT`：一键部署时是否生成本地根 CA（与远程 Step12 同用途，供 Traefik/Harbor 等签发证书）
- `DEPLOY_KIND_RUN_REGISTRY_CONFIG`：一键部署时是否在 Kind 节点内写入 containerd 镜像拉取配置（与远程 Step02 对齐）
- `DEPLOY_KIND_RUN_IMAGES` / `DEPLOY_KIND_RUN_HARBOR_HOSTS`：一键部署时是否执行镜像预加载、Harbor hosts
- `HARBOR_HOST` / `HARBOR_IP`：WSL 访问 Harbor 时使用的域名与解析 IP
- `KIND_PV_STORAGE_MODE` / `KIND_PV_HOST_PATH`：Kind worker hostPath PV 的存储模式与路径（默认 native + `/data/kind-local-storage`）
- 可选覆写 `STEP02_REGISTRY_ENABLE`、`STEP02_REGISTRY_MIRRORS`、`STEP02_REGISTRY_DIRECT`（默认从 infrastructure 的 deploy-infrastructure-all.conf 读取）

### 3.2 集群拓扑与 Harbor（kind-cluster.yaml）

- 默认 1 control-plane + 2 worker；Traefik NodePort 通过 control-plane 的 extraPortMappings 映射到宿主机。Worker 数量与端口映射见上级目录 **`kind-cluster.yaml`**，需自定义时修改后重新执行 `kind-up.sh`。
- **集群内** Harbor 解析：`kind-cluster.yaml` 中通过 extraHosts 将 `harbor.sunmoonai.com` 指向固定 IP（默认 172.18.0.3，即第一个 worker）。**创建集群前须事先确定 Traefik 会跑在哪个节点**，并修改该 IP，否则集群内拉取 Harbor 镜像会失败，需改配置后重建集群。与远程 Step11 的 /etc/hosts 等效。

### 3.3 存储（Kind 本地 PV）

- **`KIND_PV_STORAGE_MODE`**（`deploy-kind.conf`）  
  - **`native`（默认）**：`KIND_PV_HOST_PATH`（默认 `/data/kind-local-storage`）为 WSL 发行版根分区上的普通目录；`kind-up.sh` 会 `sudo mkdir -p` 并放宽权限，**不需要** Windows 侧 E 盘、独立 vhdx 或 `attach-vhds.ps1`。数据随发行版磁盘（通常为 `%LOCALAPPDATA%\Packages\...\ext4.vhdx`），请自行关注磁盘空间。  
  - **`vhd`**：沿用旧方案，要求 `wsl --mount` + WSL `/etc/fstab` 挂载 `/mnt/docker-ext4`、`/mnt/pv-kind-ext4` 与 bind 到 `KIND_PV_HOST_PATH`；详见 `docs/wsl的vhdx挂载.md` 与 `attach-vhds.ps1`。  
- **`KIND_PV_HOST_PATH`**：须与 `kind-cluster.yaml` 里 worker 的 `extraMounts.hostPath` **保持一致**；改路径需同时改两处。  
- 集群内动态存储：应用与组件在 values 中指定 `storageClassName: nfs-2` 即可，与远程 dev 一致（与上述 hostPath 无关）。

### 3.4 镜像拉取顺序（与远程的差异）

**远程（infrastructure）** 的拉取顺序由以下两步共同决定：

1. **Step11**：先把所需镜像从本机目录以 `.tar` 形式加载到各节点（**本地已存在则直接用**）。
2. **Step02**：在各节点配置 containerd 的 **`/etc/containerd/certs.d/`**（hosts.toml）：
   - **REGISTRY_MIRRORS**：按“有序回退链”配置，例如 `docker.io=https://harbor.sunmoonai.com:30443/proxy-docker,https://registry-1.docker.io`，即先走 **Harbor 代理**，失败再回退到 **官方仓库**；
   - **REGISTRY_DIRECT**：为私有仓库 `harbor.sunmoonai.com:30443` 配置直连，便于 push/pull 私有镜像。

因此远程实际顺序为：**先用本地已加载镜像 → 再拉取时先 Harbor（含代理/直连）→ 再回退到官方镜像**。配置来源：`infrastructure/steps/step02_runtime.sh` 与 `deploy-infrastructure-all.conf` 中的 `STEP02_REGISTRY_*`。

**Kind 当前**：

- **本地**：通过 `load-images/load-kind-images.sh`（或 `load-initial-images-kind.sh` 包装）预加载的镜像，与远程 Step11 等效。
- **镜像拉取配置** 有两种方式（二选一）：
  - **方式一（推荐）**：脚本 **`apply-kind-registry-config.sh`**，在一键部署时于 kind-up 之后、load-initial-images 之前自动执行，在节点内写入 `/etc/containerd/certs.d/`（hosts.toml）；配置来自 `deploy-infrastructure-all.conf` 的 `STEP02_REGISTRY_*`（可于 `deploy-kind.conf` 覆写），改配置无需重建集群。
  - **方式二**：在 **kind-cluster.yaml** 中用 **extraMounts** 将宿主机目录（如 `registry-config/<registry>/hosts.toml`）挂入各节点的 `/etc/containerd/certs.d/`，创建集群时即生效；需在创建集群前生成好 hosts.toml，改配置需重建集群。示例与注释见 `kind-infrastructure/kind-cluster.yaml` 顶部。

---

## 4. 验证

```bash
export KUBECONFIG=~/.kube/kind-config   # 或通过连接管理器
kind get clusters
kubectl get nodes
kubectl get ns
kubectl get storageclass
```

---

## 5. 脚本与文件说明（kind-infrastructure 目录）

| 脚本/目录 | 说明 |
|-----------|------|
| **`deploy-kind/`** | 一键部署：`deploy-kind.sh`（按顺序调用本目录各脚本）、`deploy-kind.conf`（配置）、`deploy-kind.md`（本文档）。 |
| **`kind-up.sh`** | 创建集群 + 命名空间 + NFS（被 deploy-kind.sh 调用或单独使用）。 |
| **`ensure-kind-ca.sh`** | 在 WSL 本地生成本地根 CA（与远程 Step12 同用途），供 Traefik/Harbor 等后续部署签发证书；若已存在则跳过。 |
| **`apply-kind-registry-config.sh`** | 在 Kind 各节点内写入 containerd `/etc/containerd/certs.d/`（与远程 Step02 对齐）；一键部署时在 kind-up 之后、load-initial-images 之前执行。 |
| `load-images/load-kind-images.sh` | 等效远程 Step11：在宿主机 docker pull 后 kind load，将 Traefik/Harbor 等镜像预加载到集群；支持 conf 与多列表文件。 |
| `apply-namespaces-existing-cluster.sh` | 被 kind-up.sh 调用。对现成集群按配置创建命名空间（与 Step07 同源）。 |
| `apply-nfs-existing-cluster.sh` | 被 kind-up.sh 调用；需 WSL 上已跑过 wsl-setup-nfs-server.sh。 |
| `wsl-setup-nfs-server.sh` | 在 WSL 中安装 nfs-kernel-server 并导出 `/data/kind-nfs`（一次性）。 |
| `wsl-setup-harbor-hosts.sh` / `wsl-setup-harbor-login.sh` | ① 在 WSL 写 `/etc/hosts`（harbor.sunmoonai.com → Kind control-plane IP 或外部 Harbor IP）；② 根据需要分发 CA 并配置 docker/nerdctl 登录（Harbor 未部署时可先只跑 hosts，部署后再跑 login）。 |

---

## 6. 参考

- 日常使用与故障排除：《kind使用指南.md》
- 配置与 deploy-infrastructure-all 同源：k8s-admin.conf、deploy-infrastructure-all.conf（如《kind使用指南.md》第 5.7 节）。本目录为 Kind 部署唯一说明入口，上级目录无 README。
