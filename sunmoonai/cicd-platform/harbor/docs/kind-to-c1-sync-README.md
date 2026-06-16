# Kind Harbor → 远程 C1 Harbor 镜像同步

本文档记录从本地 Kind Harbor 向远程集群 C1 Harbor 同步镜像的配置方法、踩坑说明与日常使用流程。

## 架构说明

两套 Harbor 是**独立实例**，共用逻辑域名 `harbor.sunmoonai.com:30443`，但物理上各跑在各集群内：

```text
WSL / 宿主机
  harbor.sunmoonai.com:30443  → 本地 Kind Harbor（开发、构建、验证）
  harbor-c1.sunmoonai.com:30443 → 远程 C1 Harbor（同步目标 + 可选 Web UI）

Kind 集群内
  harbor.sunmoonai.com        → 本地 Harbor（节点拉镜像）
  复制到 remote-c1            → Push 到远程

C1 集群内
  harbor.sunmoonai.com:30443  → 本集群 Harbor（不变）
```

网络方向：**内网/WSL 能访问远程；远程不能访问 Kind**。同步只能 **Kind → 远程（Push）**，不能反向拉取。

---

## 一、踩坑记录（重新配置时必读）

### 1. 不要用 IP 填「新建目标」或访问远程 API

Traefik 按 **Host 头** 路由，不用域名会 404：

```bash
# 失败
curl https://101.126.151.0:30443/v2/          # → 404

# 成功
curl -H "Host: harbor.sunmoonai.com" https://101.126.151.0:30443/v2/  # → 401
```

**目标 URL 应使用**：`https://harbor-c1.sunmoonai.com:30443`（不要用裸 IP）。

### 2. `harbor-c1` 不能只配 `extraHosts`（会 404 Web UI）

Harbor Chart 的 `extraHosts` 仅把 `/` 指到 **core**，不含 **portal**：

| 路径 | 需要组件 |
|------|----------|
| `/api/`、`/v2` | core |
| `/`、`/harbor` | portal |

仅用 `extraHosts` 时，API 正常但浏览器访问 `/harbor` 会 **404**。  
**正确做法**：远程 `dev-values.yaml` 使用 `extraRules`，为 `harbor-c1` 配齐 core + portal 路由（与主域名一致）。  
**不要改** `hostname` / `externalURL`（仍为 `harbor.sunmoonai.com`），集群内访问方式不变。

### 3. WSL 的 `/etc/hosts` 对 Kind Pod 无效

在 WSL 加 `101.126.151.0 harbor-c1.sunmoonai.com` 只影响本机 `docker`/`curl`。  
Kind Harbor UI 里「测试连接」由 **harbor-core Pod** 发起，必须在 **Kind** 侧配置 `hostAliases`（见 `dev-values-kind.yaml`）。

### 4. 「测试连接失败」：token 回调域名撞车

远程 registry 认证返回的 realm 仍是 `https://harbor.sunmoonai.com:30443/service/token`。  
Kind Pod 内 `harbor.sunmoonai.com` 常解析到 `127.0.0.1`，导致：

```text
dial tcp 127.0.0.1:30443: connect: connection refused
```

**处理**：Kind 的 `core` / `jobservice` 的 `hostAliases` 同时包含：

```yaml
- ip: <C1 公网 IP>    # 见 infrastructure deploy-infrastructure-all.conf
  hostnames:
    - harbor-c1.sunmoonai.com
    - harbor.sunmoonai.com
```

仅配 `harbor-c1` 不够，必须包含 `harbor.sunmoonai.com` 指向远程 IP。

### 5. C1 部署 Harbor 阶段 4 卡在「服务完全初始化」

`deploy-harbor.sh` 健康检查在本机用 `jq` 解析 API 响应，WSL **未安装 jq** 时会一直显示「等待 Harbor 服务完全初始化」。

```bash
sudo apt-get install -y jq
```

Harbor 本身可能已正常，装 jq 后重试或等待下一轮检查即可通过。

### 6. C1 滚动更新时 `harbor-core` ImagePullBackOff

新 Pod 调度到无本地缓存的节点（如 `hsy-local-3`）时，会从 `docker.io` 拉 `bitnami/harbor-core` 超时。  
**处理**：用 `nerdctl load` 将 `bitnami_harbor-core_*.tar` 载入该节点，并 tag 为 `docker.io/bitnami/harbor-core:<版本>`。

### 7. 复制进度长期显示 30%（8/27）不是卡死

UI 成功率 **只统计 Succeed**，不含 InProgress。大镜像（如 `ragflow` ~7GB、`elasticsearch` ~600MB）跨网 Push 很慢，属正常。  
查看任务详情或 API：`failed=0` 且有多项 `InProgress` 时继续等待即可。

### 8. 复制规则「仓库扁平化」选「无替换」

源、目标项目名一致时（`app-images` → `app-images`），应选 **无替换**。  
「替换 1 级」可能改变仓库路径，导致 C1 部署配置中的镜像名对不上。

### 9. Stopped 的复制任务记录不能删

复制任务表是**执行历史**，UI 无单条删除。Stopped 不影响新任务，直接再点「复制」即可；已有镜像通常会跳过。

### 10. `hostAliases` 中的 IP 随环境变化

当前 C1 Harbor 入口 IP 配置在：

`k8s/sunmoonai/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf`

```text
C1_STEP11_HARBOR_PUBLIC_IP="101.126.151.0"   # 示例，以实际为准
```

换节点或换集群后需同步更新 `dev-values-kind.yaml` 中的 `hostAliases.ip`。

---

## 二、相关配置文件

| 文件 | 作用 |
|------|------|
| `resources/custom-values/dev-values.yaml` | 远程 C1：`harbor-c1` 的 `extraRules`（core + portal） |
| `resources/custom-values/dev-values-kind.yaml` | Kind：`core` / `jobservice` 的 `hostAliases` |
| `deploy-harbor/deploy-harbor.conf` | `HARBOR_EXTERNAL_HOST`、管理员密码等 |
| `infrastructure/.../deploy-infrastructure-all.conf` | C1 节点 IP、`HARBOR_ADMIN_PASSWORD` |

---

## 三、一次性配置步骤

### 3.1 WSL `/etc/hosts`

```text
101.126.151.0  harbor-c1.sunmoonai.com
```

本地 Kind 仍用原有 `harbor.sunmoonai.com` 解析，不要改成远程 IP。

### 3.2 部署 / 更新 Harbor

```bash
# 远程 C1（应用 dev-values.yaml 中的 harbor-c1 路由）
cd ~/k8s/sunmoonai/cicd-platform/harbor/deploy-harbor
CLUSTER=C1 ./deploy-harbor.sh deploy

# 本地 Kind（应用 dev-values-kind.yaml 中的 hostAliases）
CLUSTER=KIND ./deploy-harbor.sh deploy
```

### 3.3 Kind UI：注册远程目标

**系统管理 → 仓库管理 → 新建目标**

| 字段 | 值 |
|------|-----|
| 提供者 | Harbor |
| 目标名 | `remote-c1` |
| 目标 URL | `https://harbor-c1.sunmoonai.com:30443` |
| 访问 ID | `admin` |
| 访问密码 | 与 `deploy-harbor.conf` 中 `HARBOR_ADMIN_PASSWORD` 一致 |
| 验证远程证书 | **取消勾选** |

点「测试连接」应成功。

### 3.4 Kind UI：新建复制规则

建议两条，模式均为 **Push**，触发器可先选手动，稳定后改「基于事件」。

**规则 1：`kind-to-c1-app-images`**

| 字段 | 值 |
|------|-----|
| 源名称 | `app-images/**` |
| 资源 | image |
| 目标名称空间 | `app-images` |
| 仓库扁平化 | 无替换 |

**规则 2：`kind-to-c1-k8s-images`**

| 字段 | 值 |
|------|-----|
| 源名称 | `k8s-images/**` |
| 目标名称空间 | `k8s-images` |
| 仓库扁平化 | 无替换 |

---

## 四、日常使用流程

```text
1. 本地改代码
2. 构建并推到 Kind Harbor
3. Kind 上验证通过
4. 复制规则同步到 remote-c1（手动或事件触发）
5. C1 部署应用
```

### 4.1 构建推到 Kind

```bash
cd ~/k8s/sunmoonai/app-platform
CLUSTER=KIND ./scripts/build-push-app-images.sh
```

### 4.2 触发复制

Kind Harbor → **复制管理** → 选中规则 → **复制**。

远程已有且 digest 相同的制品会跳过；仅新增或变更的会传输。

### 4.3 部署 C1

```bash
cd ~/k8s/sunmoonai/app-platform/deploy-app-platform-all
./deploy-app-platform-all.sh --cluster C1 deploy
```

### 4.4 验证远程镜像

- Web UI：`https://harbor-c1.sunmoonai.com:30443/harbor`
- 检查项目 `app-images`、`k8s-images` 中 tag（如 `1.0.0`）是否齐全

### 4.5 备选：WSL 手动同步（不用复制规则时）

```bash
docker login harbor-c1.sunmoonai.com:30443

skopeo copy --src-tls-verify=false --dest-tls-verify=false \
  docker://harbor.sunmoonai.com:30443/app-images/<镜像>:<tag> \
  docker://harbor-c1.sunmoonai.com:30443/app-images/<镜像>:<tag>
```

---

## 五、快速自检命令

```bash
# 远程 harbor-c1 API
curl -sk https://harbor-c1.sunmoonai.com:30443/api/v2.0/ping

# 远程 harbor-c1 Web UI
curl -sk -o /dev/null -w "%{http_code}\n" https://harbor-c1.sunmoonai.com:30443/harbor

# Kind 内域名解析（应指向远程 IP，非 127.0.0.1）
kubectl exec -n cicd-platform-dev deploy/sunmoonai-harbor-core -c core -- \
  getent hosts harbor-c1.sunmoonai.com harbor.sunmoonai.com

# 复制任务 API（Kind Harbor）
curl -sk -u 'admin:<密码>' \
  'https://harbor.sunmoonai.com:30443/api/v2.0/replication/executions?page_size=5'
```

---

## 六、域名职责速查

| 域名 | 谁用 | 用途 |
|------|------|------|
| `harbor.sunmoonai.com` | Kind 集群内、本地构建 | 本地 Harbor |
| `harbor-c1.sunmoonai.com` | WSL、Kind 复制目标 | 远程 C1 Harbor（同步 + 可选 UI） |
| `harbor.sunmoonai.com` | C1 集群内 | 远程集群拉镜像（不变） |
