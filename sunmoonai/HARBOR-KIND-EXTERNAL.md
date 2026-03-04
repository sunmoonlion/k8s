## Kind 本地开发使用「集群外 Harbor」方案说明

> 目标：  
> - **不改任何镜像地址 / Helm values**（仍然是 `harbor.sunmoonai.com:30443/k8s-images/...`）  
> - 把 Harbor 从 Kind 集群里「搬到 WSL 宿主机」，用 docker-compose 起  
> - 以后可以随便重建 Kind 集群，而 **Harbor 和镜像数据始终保留**

---

### 一、当前设计的痛点回顾

- 现在 Harbor 是 **用 Helm 部署在 Kind 集群里** 的（命名空间 `cicd-platform-dev`）。  
- 每次重建 Kind 集群，相当于：
  - Harbor Pod 也会被删掉重建；
  - 如果同时把 Harbor 的持久卷也当作“一次性环境”，那么镜像相当于被清空；
  - 需要再次跑 `push-to-harbor/push-images-to-harbor.sh`，把整包 `.tar` 推到 Harbor，**非常耗时**。
- 只要满足这三个条件：
  1) Harbor 在 Kind 集群里  
  2) 重建 Kind = 也重建 Harbor  
  3) Harbor 数据卷不做持久化 / 重用  
  → 重建就一定会重新 push，没有真正的省时空间。

---

### 二、目标架构（不改镜像地址）

保持所有脚本、Chart 中的镜像地址不变：

- 仍然使用：
  - `harbor.sunmoonai.com:30443/k8s-images/postgresql:...`
  - `harbor.sunmoonai.com:30443/k8s-images/mongodb:...`
  - 等等……

只做一件事：

- 把域名 **`harbor.sunmoonai.com:30443` 的服务实现**，从  
  「**集群内 Helm Harbor**」  
  换成  
  「**WSL 宿主机 docker-compose Harbor**」。

这样：

- Kind 只是一个普通的 k8s 集群，**把 Harbor 当外部 registry**；  
- 你爱怎么 `kind delete cluster` / 重建都行，Harbor 和其中的镜像不受影响（只要不删 Harbor 的数据目录）。

---

### 三、修改点总览（最小改动）

1. **关闭集群内 Harbor 的自动部署和自动推镜像**（仅改开关，不删脚本）
2. **在 WSL 上用官方安装包 + docker-compose 起一个 Harbor**
3. **继续使用现有的 hosts / registry / 证书脚本，让 Kind 节点和 WSL 都信任 `harbor.sunmoonai.com:30443`**
4. 所有 `*_IMAGE_REGISTRY` / push 脚本里的地址 **完全不改**。

下面按步骤展开。

---

### 四、关闭「集群内 Harbor 自动部署 + 自动 push」

文件：`kind-infrastructure/deploy-kind/deploy-kind.conf`

把以下开关先关掉（只改 true/false，**不删逻辑**）：

```bash
DEPLOY_KIND_RUN_HARBOR="false"          # 不再在 Kind 集群中安装 Harbor
DEPLOY_KIND_RUN_PUSH_TO_HARBOR="false"  # 不再在一键流程末尾自动 push 镜像
```

说明：

- 这不会影响现有 Helm chart / YAML，只是 **deploy-kind 一键流程不再自动动 Harbor**。  
- 将来如果想恢复「集群内 Harbor」模式，只需把这两行改回 `true`，然后按原远程流程部署即可。

> 可选（手动清理）：  
> 已经部署在 Kind 里的 Harbor release 可以以后有空再卸载：  
> `helm -n cicd-platform-dev uninstall sunmoonai-harbor`

---

### 五、在 WSL 上用 docker-compose 起 Harbor

#### 5.1 安装依赖（仅在 WSL 中执行一次）

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker "$USER"  # 重新登录 shell 后生效
```

#### 5.2 下载 Harbor 官方安装包

```bash
cd ~/downloads
wget https://github.com/goharbor/harbor/releases/download/v2.11.0/harbor-online-installer-v2.11.0.tgz
tar xzf harbor-online-installer-v2.11.0.tgz
cd harbor
```

> 版本号可按需要调整，这里只是示例。

#### 5.3 生成并编辑 `harbor.yml`

```bash
cp harbor.yml.tmpl harbor.yml
```

重点修改以下字段（仅示意，实际保留其它默认值）：

```yaml
hostname: harbor.sunmoonai.com

https:
  port: 30443
  certificate: /data/harbor/certs/harbor.crt
  private_key: /data/harbor/certs/harbor.key

data_volume: /data/harbor
```

- `hostname`：必须为 `harbor.sunmoonai.com`，与现有脚本保持一致。  
- `https.port`：30443，对应现在所有脚本中用到的 `harbor.sunmoonai.com:30443`。  
- `data_volume`：Harbor 所有数据（包括镜像）持久化目录，**今后千万别随便删**。

#### 5.4 准备证书

建议沿用现有的 `SunMoonAI Root CA`，为 `harbor.sunmoonai.com` 签一张服务器证书：

```bash
sudo mkdir -p /data/harbor/certs
sudo cp /path/to/harbor.crt /data/harbor/certs/
sudo cp /path/to/harbor.key /data/harbor/certs/
sudo chown -R root:root /data/harbor
```

> 若不想重新生成证书，也可以直接复用原来集群内 Harbor 用的那一对 key+crt，只要 CN/SAN 中包含 `harbor.sunmoonai.com`。

#### 5.5 安装 Harbor（生成 docker-compose 并启动）

```bash
sudo ./prepare
sudo ./install.sh
```

安装完成后，验证 Harbor 是否工作：

```bash
curl -k https://harbor.sunmoonai.com:30443/api/v2.0/projects
```

- 有 JSON / 401 等合理响应即可。

也可以通过：

```bash
docker compose ps
```

查看 `harbor-core` / `harbor-portal` / `harbor-registry` 等容器是否都是 `Up`。

---

### 六、域名解析与证书信任（保持脚本兼容）

#### 6.1 WSL 宿主机解析

你已有脚本：`kind-infrastructure/wsl-setup-harbor-hosts-and-login.sh`，大致做了：

- 写 `/etc/hosts`：`harbor.sunmoonai.com -> 某个 IP（control-plane 或 127.0.0.1）`
- 安装 `SunMoonAI Root CA` 为系统 CA
- 在 `/etc/docker/certs.d/harbor.sunmoonai.com:30443/ca.crt` 下放 CA，方便 Docker 客户端用 TLS 访问

这套逻辑 **仍然适用**，只需要保证：

- `/etc/hosts` 里 `harbor.sunmoonai.com` 指向的是 **WSL 内能访问到 Harbor 容器的 IP/端口**。  
  - 若 Harbor 暴露在 WSL 的 `127.0.0.1:30443`，则 hosts 指向 127.0.0.1 即可。  
  - 若通过 Docker bridge 网络 IP 暴露，按原文档里推荐的 IP 写入即可。

#### 6.2 Kind 节点解析

你已有脚本：`kind-infrastructure/apply-kind-node-harbor-hosts.sh`，负责：

- 在 **每个 Kind node 容器** 的 `/etc/hosts` 里写：
  - `harbor.sunmoonai.com <某个固定 IP>`

这也可以继续复用，只要保证：

- 这个 IP + 30443 能从 node 内访问到 WSL 宿主机上的 Harbor。

> 例如：  
> - WSL 内 Harbor 监听在 `172.18.0.1:30443`（Docker bridge IP），  
> - 则在 `deploy-kind.conf` 里设置：  
>   `HARBOR_IP="172.18.0.1"`  
>   `HARBOR_PORT="30443"`  
>   然后由 `apply-kind-node-harbor-hosts.sh` 写入 hosts。

#### 6.3 containerd registry 配置

你现有的 `apply-kind-registry-config.sh` 会根据 `STEP02_REGISTRY_*` 生成 containerd 的 registry 配置：

- 设置 mirrors / direct registry
- 可指定 `harbor.sunmoonai.com:30443` 为 direct registry 或镜像源

这部分逻辑也可以保持不变——只要保证：

- `harbor.sunmoonai.com:30443` 在 node 里解析到的，就是 **WSL Harbor**。
- 节点信任 `SunMoonAI Root CA`（你之前已经有统一 CA 分发脚本，可以重用）。

---

### 七、后续使用方式

#### 7.1 日常：重建 Kind / 重跑业务，不动 Harbor

- 重建 Kind：

```bash
cd ~/k8s/sunmoonai/kind-infrastructure
./deploy-kind/deploy-kind.sh
```

- 部署各平台（只动业务，不动 Harbor）：

```bash
export KUBECONFIG=$HOME/.kube/kind-config
cd ~/k8s/sunmoonai/deploy-sunmoonai-all
./deploy-sunmoonai-all.sh deploy sunmoonai development false
```

此时：

- Harbor 仍然是 WSL 上 docker-compose 起的那个；  
- Kind 中的所有组件仍然从 `harbor.sunmoonai.com:30443` 拉镜像，但目标是外部 Harbor。

#### 7.2 推镜像

推镜像有两种方式，脚本都不用改：

1. 直接 Docker：
   ```bash
   docker login harbor.sunmoonai.com:30443
   docker push harbor.sunmoonai.com:30443/k8s-images/xxx:tag
   ```

2. 继续使用现有脚本：
   ```bash
   cd ~/k8s/sunmoonai/kind-infrastructure/push-to-harbor
   ./push-images-to-harbor.sh   # 按 push-images-to-harbor.conf 中的默认配置
   ```

由于 Harbor 已经不在 k8s 里，**push 的速度只取决于本机 I/O 和网络，不会受到重建 Kind 的影响**。

---

### 八、需要「切回集群内 Harbor」时怎么做？

如果有一天你又想回到“Harbor 跟着集群走”的模式：

1. 把外部 Harbor 停掉（保留 `/data/harbor` 以免误删数据）。  
2. 在 `deploy-kind/deploy-kind.conf` 中重新打开：
   ```bash
   DEPLOY_KIND_RUN_HARBOR="true"
   DEPLOY_KIND_RUN_PUSH_TO_HARBOR="true"
   ```
3. 按以前的远程文档，重新在 Kind 集群中安装 Harbor 并 push 镜像。

脚本和镜像地址始终是同一套，不存在“双份配置”的问题。

---

### 九、小结

- **核心变化只有两点**：
  1. 不再在 Kind 集群里自动安装 Harbor / 自动 push 镜像  
  2. 换成在 WSL 上用 docker-compose 起一个始终存在的 Harbor
- **所有脚本中的镜像地址、push/pull 逻辑完全不改**：
  - `harbor.sunmoonai.com:30443/k8s-images/...`
  - `*_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"`
  - `push-to-harbor.sh` 的目标地址
- 收益：
  - 重建 Kind 集群不再触发“重新推整包镜像”的长等待；  
  - Harbor 的数据（项目 / 用户 / 镜像）持久保留，只要不删 `/data/harbor` 就安全。

