## SunmoonAI 镜像管理与按需推送方案（设计草案）

### 1. 设计目标

- **不在集群初始化阶段集中推送所有镜像到 Harbor**。
- **在组件部署阶段做镜像检查 + 按需推送/拉取**：
  - 哪个组件要部署，只为这个组件补齐它自己需要的镜像。
- **统一远程集群与 Kind 的“Harbor 之后”体验**：
  - Harbor 一旦可用，其它组件都通过 Harbor 拉取镜像，部署前有组件级镜像检查逻辑。

---

### 2. 集群类型与初始化职责

#### 2.1 远程集群（C1/C2 等）

- **初始化阶段（infrastructure 层）主要职责：**
  - 使用 `deploy-infrastructure-all`：
    - **Step11 初始镜像加载**：
      - 将 Traefik、Harbor 及其最小依赖（PostgreSQL、Redis 等）相关镜像打成 tar 包；
      - 分发到各节点并通过 `ctr import` / `nerdctl load` 预加载；
      - 目的是在 Harbor 不可用的前提下，仍然可以完成 Traefik + Harbor 的首次部署。
    - **Step02 registry 配置**：
      - 为各节点的 containerd 写入 `/etc/containerd/certs.d/*/hosts.toml`；
      - 配置 Harbor 代理（REGISTRY_MIRRORS）与 Harbor 直连（REGISTRY_DIRECT）。
  - **不负责**：为所有后续组件（数据平台、消息平台、业务应用）准备镜像，只保证基础设施组件能启动。

- **Harbor 就绪之后：**
  - 所有后续组件的镜像源统一为：
    - `harbor.sunmoonai.com:30443/<project>/<repo>:<tag>`
  - 组件部署前通过“组件级镜像检查 + 按需推送”来保证：
    - Harbor 中存在所需镜像；
    - （可选）节点本地已有镜像缓存。
  - 在基础设施阶段末尾，统一触发 **Traefik 与 Harbor 的部署脚本**（Step13），形成与 Kind 一致的“第一阶段”：
    - Step11 预加载 Traefik/Harbor/Redis/PostgreSQL 等镜像到所有节点；
    - Step12 生成/轮换统一根 CA；
    - Step13（`step13_ingress_and_harbor.sh`）在远程集群上顺序调用：
      - `ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh`
      - `cicd-platform/harbor/deploy-harbor/deploy-harbor.sh deploy`
    - 是否真正部署 Traefik/Harbor 仍由各组件自身配置文件中的开关决定，本步骤只负责在基础设施阶段统一触发部署调用。

#### 2.2 Kind 集群

- **初始化阶段（kind-infrastructure）主要职责：**
  - 使用 `kind-infrastructure/deploy-kind.sh`：
    - 创建 Kind 集群、配置 NFS、生成本地根 CA、配置节点 registry/TLS 等；
    - 始终在 Kind 集群中部署 Traefik 与 Harbor，不再提供开关。
  - 将 **Traefik + Harbor + 其最小依赖（PostgreSQL、Redis 等）** 视为 Kind 上的“第一批基础设施组件”。

- **Kind 第一阶段：节点镜像预烤策略**
  - Traefik / Harbor / PostgreSQL / Redis 等基础镜像**不通过 Harbor 在线拉取**，而是统一通过“烤进 Kind 节点镜像”的方式预置到所有节点：
    - 使用 `deploy-kind/build-kind-node-image/build-kind-node-image.sh`：
      - 从镜像列表或 tar 目录（由 `build-kind-node-image.conf` 配置）收集上述基础镜像；
      - 在 Docker build 过程中启动临时 containerd，执行 `ctr -n k8s.io images import` 将这些镜像导入到底层节点镜像；
      - 生成自定义节点镜像（如 `kindest/node:v1.27.3-sunmoonai`），并更新 `deploy-kind/kind-cluster.yaml` 中所有节点的 `image:`。
    - `deploy-kind.sh` 使用该自定义节点镜像创建 Kind 集群，此时 **每个节点一启动就已包含 Traefik/Harbor/PG/Redis 等镜像**，无需访问外部 registry。

- **Harbor 就绪之后：**
  - Kind 与远程集群在逻辑上尽量统一：
    - 组件镜像统一通过 Harbor 管理（容器运行时通过 `apply-kind-registry-config.sh` 配置 registry mirrors/direct，与远程 Step02 对齐）；
    - 部署前执行相同的“组件级镜像检查 + 按需推送”流程；
    - 差异只体现在：连接方式（`k8s-admin.conf` 中的 `cluster_mode=kind|remote`）、Harbor 域名解析路径等。

---

### 3. 组件级镜像检查流程（概念）

#### 3.1 镜像定义：required_images

- 每个组件的部署脚本提供一个函数，例如：

```bash
define_required_images() {
  local environment="$1"
  case "$environment" in
    "production")
      echo "harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0|true"
      ;;
    "development"|"dev")
      echo "harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0|true"
      ;;
  esac
}
```

- 返回格式为多行，每行：
  - `镜像全名|是否启用`，例如：`<registry>/<project>/<repo>:<tag>|true/false`。

#### 3.2 部署前检查的标准步骤

以组件 `X` 为例（PostgreSQL / RabbitMQ / 某业务 BFF）：

1. **准备镜像列表**
   - 在 `deploy-X.sh` 中：
     - `local required_images=$(define_required_images "$environment")`

2. **调用统一镜像检查函数**
   - 在执行 Helm 或 `kubectl apply` 之前，调用统一模板中的函数：
     - `check_component_images "$project_id" "$namespace" "postgresql" "$environment" "$required_images" "remote"`
   - 逻辑概念：
     - 遍历 `required_images` 列表；
     - 对每个启用镜像进行检查（见 3.3）。

3. **对缺失镜像执行“按需补齐”**
   - `check_component_images` 内部或之后，驱动“按需推送”流程，按集群模式分流：
     - **Kind**：使用 `sunmoonai/kind-infrastructure/push-to-harbor/push-images-to-harbor.sh`（本机 Docker → Harbor）；
     - **远程（C1/C2/...）**：使用 `utils/registry-push-management/loadimage.sh`（SSH 到节点 + nerdctl → Harbor）。
     - 从本地 tar / 本地 Docker / 其它 registry 拉取镜像后，推送到 Harbor 对应项目，再次验证 artifact 是否存在。

4. **决策与反馈**
   - 当所有必需镜像均存在于 Harbor 中：
     - 日志打印“镜像检查通过”，继续执行 Helm 部署。
   - 当仍有缺失镜像：
     - 严格模式：终止部署，并打印缺失镜像清单 + 推荐的手工命令。
     - 宽松模式：打印警告，允许部署流程继续（交给在线拉取）。

#### 3.3 检查维度（Harbor / 节点）

- **Harbor 维度（必选）**
  - 通过 Harbor API 检查 artifact 是否存在：
    - `GET /api/v2.0/projects/<project>/repositories/<repo>/artifacts/<tag>`。
  - 缺失则标记为 `missing_in_harbor`。

- **节点维度（可选）**
  - 使用 `kubectl get node <node> -o jsonpath='{.status.images[*].names[*]}'` 或 `crictl images`：
    - 检查某个镜像是否已经加载在节点的容器运行时中。
  - 使用场景：
    - 网络受限环境下，希望在部署前确保节点已经 preload 完成。
    - 或仅用于排查日志提示，不强制要求。

---

### 4. 配置与行为开关（草案）

#### 4.1 组件级配置（deploy-xxx.conf）

- **`ENABLE_OFFLINE_IMAGE_CHECK`**
  - `false`（默认）：在线模式。
    - 不强制 Harbor 提前准备镜像。
    - 建议：仍可执行镜像检查，但检查失败仅告警，不终止部署。
  - `true`：离线/半离线模式。
    - 部署前必须保证 Harbor 中镜像齐全。
    - 若检查失败 → 终止部署。

- **`FORCE_IMAGE_CHECK`**
  - `true`：即使 `ENABLE_OFFLINE_IMAGE_CHECK=false`，也执行一次严格镜像检查（运维手动触发时使用）。

- **可选：`IMAGE_CHECK_MODE`**
  - `remote`：仅检查 Harbor。
  - `remote+node`：同时检查节点镜像缓存（例如对数据库、消息队列等关键组件使用）。

#### 4.2 集群模式配置（Kind vs 远程）

- 在 `k8s-admin.conf` / 统一模板中通过 `cluster_mode` 或类似变量区分：
  - `cluster_mode=remote`：执行完整的远程集群检查逻辑。
  - `cluster_mode=kind`：
    - 初始化阶段可以跳过节点级严格检查（因为很多镜像可以在线拉取）。
    - 当 Kind + Harbor 稳定后，可选择启用与远程类似的镜像检查逻辑。

---

### 5. 与现有工具的关系

#### 5.1 `utils/unified-deployment-template.sh`

- **将承担的功能（计划恢复/重构）：**
  - `check_remote_images`：面向 Kubernetes 节点的镜像存在性检查。
  - `check_component_images`：组件级统一入口，封装：
    - Harbor 检查（仓库维度）。
    - 节点镜像检查（可选）。
    - 结果汇总与日志输出。
  - `generate_image_list`：输出需要准备的镜像列表及参考 `docker pull` 命令。

- **脚本自身命令行接口（可能恢复）：**
  - `setup-kubectl`：连接管理。
  - `check-images`：独立执行镜像检查。
  - `cleanup`：清理连接。

#### 5.2 镜像推送工具（按集群模式分流）

- **远程集群（C1/C2/...）**：`utils/registry-push-management/*`
  - 通过 SSH 在远程节点执行 nerdctl load/tag/push，推送到 Harbor。
  - 输入：组件镜像清单（如 `components-images/<component>-images.txt`）或单镜像引用。
  - 在 CI/CD 或人工脚本中直接调用 `loadimage.sh`（如 `push-from-list`）实现按需推送。

- **Kind 集群**：`sunmoonai/kind-infrastructure/push-to-harbor/*`
  - 在本机使用 Docker load/tag/push，推送到 Harbor（Kind 节点无 SSH，不适用 registry-push-management）。
  - 输入：镜像列表文件（`--img-file`）或 tar 目录（`--tar-dir`）。
  - 统一模板中的 `push_component_images_to_harbor` 会根据 `K8S_TARGET_MODE` 自动选择上述二者之一。

#### 5.3 检查类工具脚本

- `check-local-images.sh`：在单节点上直接检查 Docker/containerd/nerdctl 镜像。
- `check-remote-node-images.sh`：通过 `kubectl` 结合 Pod 信息从集群角度检查镜像版本一致性。
- `check-node-images.sh`：混合视角（Pod → 节点本地缓存），用于人工排查。

这些脚本定位为 **运维手工诊断工具**，不强制集成到自动部署流程中，但可在日志或文档中推荐使用。

---

### 6. 后续工作与细化方向

- **1）确定最小可行版本的行为边界**
  - 第一阶段是否先只做“Harbor 维度检查 + 日志提示”，暂不自动 push。
  - 或者在缺镜像时按集群模式调用对应工具（Kind：push-to-harbor；远程：registry-push-management）执行自动推送。

- **2）选择一个组件作为 POC 样板**
  - 推荐：PostgreSQL 或 RabbitMQ（依赖清晰、影响面适中）。
  - 为该组件补齐：
    - `define_required_images` 实现。
    - 部署脚本中插入镜像检查调用的位置与日志格式。

- **3）Kind vs 远程的差异抽象**
  - 确定哪些逻辑需要在 Kind 下“降级为告警但不断言失败”，以兼容本地开发体验。
  - 远程集群则可以使用更严格策略（特别是离线/半离线环境）。

---

### 7. 远程集群第一阶段：离线包分发（Step01 前置）

- **目标**：在不大改现有步骤结构的前提下，将集群初始化所需的离线工件（deb 包、运行时 tar、镜像 tar、基础 chart）在 **Step01（OS 基线）开始时一次性同步到所有远程节点的 `SERVER_n_DIR`，为 Step02/03/11/05 等后续步骤提供统一的离线源。

- **本机离线包目录（控制平面）**
  - 根目录：`$HOME/packages-to-be-installed`（沿用现有约定）。
  - 子目录：
    - `debs/`：Kubernetes / NFS / 工具等 deb 包（kubeadm/kubelet/kubectl/kubernetes-cni/nfs-kernel-server/socat 等）。
    - `tars/`：运行时安装包（例如 `nerdctl-full-*.tar.gz`、`crictl-*.tar.gz`）。
    - `images/`：各类镜像 tar（K8s 核心镜像、Traefik/Harbor/Redis/PostgreSQL/Elasticsearch/Kibana/Logstash/MongoDB/Neo4j/RabbitMQ/RedisInsight/pgAdmin/Flower/Jenkins 等）。
    - `charts/`：基础设施 Helm chart（如 `nfs-subdir-external-provisioner-*.tgz`、`tigera-operator-*.tgz` 等）。

- **远程节点离线包目录**
  - 每个节点通过 `SERVER_n_DIR`（`deploy-infrastructure-all.conf` 中配置，通常为 `~/packages-to-be-installed`）指定离线包根目录。
  - 目录结构：
    - `<SERVER_n_DIR>/debs/`
    - `<SERVER_n_DIR>/tars/`
    - `<SERVER_n_DIR>/images/`
    - `<SERVER_n_DIR>/charts/`
  - Step02/03/11 等步骤继续从这些目录中读取离线工件（保持现有逻辑不变），例如：
    - Step11 从 `<SERVER_n_DIR>/images/` 读取 `bitnami_harbor-core_*.tar` 等镜像；
    - Step02 从 `<SERVER_n_DIR>/tars/` 读取 `nerdctl-full-*.tar.gz`；
    - Step03 从 `<SERVER_n_DIR>/debs/` 读取 kubeadm/kubelet/kubectl 等 deb。

- **行为开关与配置（`deploy-infrastructure-all.conf`）**
  - 新增开关：
    - `PRE_SYNC_OFFLINE_PACKAGES="true|false"`  
      - `true`：Step01 在执行 OS 基线配置前，会从本机 `packages-to-be-installed` 将 `debs/`、`tars/`、`images/`、`charts/` 同步到每个节点的 `SERVER_n_DIR` 对应子目录。
      - `false`：保持现有行为，假定离线包已经通过其他方式（手工/CI）提前分发到远程节点。
  - 可选覆盖本机根目录：
    - `LOCAL_PACKAGES_ROOT="$HOME/packages-to-be-installed"`（默认值，如不配置则使用 `~/packages-to-be-installed`）。

- **Step01 中的实现思路（`step01_os_baseline.sh`）**
  - 在 `precheck`/`execute` 之前，增加一个“离线包预同步”阶段：
    - 从配置读取 `PRE_SYNC_OFFLINE_PACKAGES` 与 `LOCAL_PACKAGES_ROOT`；
    - 若 `PRE_SYNC_OFFLINE_PACKAGES=true`：
      - 遍历所有目标节点索引 `i`（`get_defined_server_indices`）；
      - 解析每个节点的 `DIR`（`get_server_var "$i" DIR` + `resolve_remote_dir`）；
      - 对 `debs`、`tars`、`images`、`charts` 四个子目录：
        - 若本机存在 `"$LOCAL_PACKAGES_ROOT/$sub"`，则：
          - 在远程节点上创建 `"$DIR/$sub"`；
          - 使用 `rsync -az` 或 `scp` 同步该目录内容到远程节点（可选带 `--delete` 保持一致性）。
    - 若 `PRE_SYNC_OFFLINE_PACKAGES=false`：
      - 仅输出日志提示“跳过离线包预同步”，后续 Step02/03/11 如缺包会维持原有错误提示。
  - 之后按原逻辑执行：
    - `_apply_swap_and_sysctl`、`_configure_iptables_mode`、`_set_hostname_and_hosts`、`_ensure_time_sync`；
    - 使用 `<SERVER_n_DIR>/debs` 中的离线 deb 安装 conntrack/socat 等依赖（若存在），否则回退在线安装。

