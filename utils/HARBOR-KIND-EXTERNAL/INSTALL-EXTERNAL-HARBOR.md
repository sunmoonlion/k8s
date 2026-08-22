## 在 WSL 上创建「集群外 Harbor」的实操步骤

> 建议把 Harbor 官方安装包（`harbor-online-installer-*.tgz`）也统一放在本目录下的 `packages/` 子目录，方便归档和备份。

---

### 1. 准备目录与安装包存放位置

- **推荐规划**：
  - 文档与脚本目录：`~/master/k8s/utils/HARBOR-KIND-EXTERNAL/`
  - Harbor 官方安装包存放：`~/master/k8s/utils/HARBOR-KIND-EXTERNAL/packages/`

```bash
mkdir -p ~/master/k8s/utils/HARBOR-KIND-EXTERNAL/packages
cd ~/master/k8s/utils/HARBOR-KIND-EXTERNAL/packages
```

> 以后如果重新下载 `harbor-online-installer-*.tgz`，也统一放在 `packages/` 目录，便于管理和迁移。

---

### 2. 安装 docker / docker compose 插件（仅第一次）

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin

# 将当前用户加入 docker 组，重新登录终端后生效
sudo usermod -aG docker "$USER"
```

重新打开一个 WSL 终端，确认：

```bash
docker --version
docker compose version
```

---

### 3.（可选）开启 WSL 代理以加速下载

如果访问 GitHub 较慢，可以在 `toggle-wsl-proxy.sh` 所在目录执行：

```bash
cd ~/toolboxes/Vlinux/utils/set-up-tools/proxy-setting
source ./toggle-wsl-proxy.sh on
```

> 仅对当前终端有效，新开终端需要重新执行一次。

---

### 4. 下载并解压 Harbor 官方安装包

在你刚才的 `packages/` 目录下执行（版本号可按需要调整，这里以 `v2.11.0` 为例）：

```bash
cd ~/master/k8s/utils/HARBOR-KIND-EXTERNAL/packages

wget https://github.com/goharbor/harbor/releases/download/v2.11.0/harbor-online-installer-v2.11.0.tgz

tar xzf harbor-online-installer-v2.11.0.tgz
mv harbor ../harbor-runtime
cd ../harbor-runtime
```

说明：

- `packages/` 下只放压缩包备份；
- 实际运行 Harbor 的目录使用 `~/master/k8s/utils/HARBOR-KIND-EXTERNAL/harbor-runtime`，便于将来迁移或备份整个目录。

---

### 5. 生成并编辑 `harbor.yml`

在 `harbor-runtime` 目录内：

```bash
cp harbor.yml.tmpl harbor.yml
```

然后编辑 `harbor.yml`，确保以下关键字段为：

```yaml
hostname: harbor.sunmoonai.com

https:
  port: 30443
  certificate: /data/harbor/certs/harbor.crt
  private_key: /data/harbor/certs/harbor.key

data_volume: /data/harbor
```

- `hostname` 必须为 `harbor.sunmoonai.com`（与所有脚本 / Chart 一致）。
- `https.port` 使用 `30443`，与现在 Kind / 脚本中访问的端口一致。
- `data_volume` 指向 **宿主机持久化目录**，后续不要随便删除，否则 Harbor 数据会丢失。

---

### 6. 复用现有 Traefik 证书为 Harbor 提供 TLS

你已经有一套 `SunMoonAI Root CA` + `harbor.sunmoonai.com` 的服务器证书，直接复用即可：

```bash
sudo mkdir -p /data/harbor/certs

sudo cp \
  ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/server-cert/server.crt \
  /data/harbor/certs/harbor.crt

sudo cp \
  ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/server-cert/server.key \
  /data/harbor/certs/harbor.key

sudo chown -R root:root /data/harbor
```

> 前提：这对证书的 CN/SAN 中已经包含 `harbor.sunmoonai.com`，与当前环境保持一致。

---

### 7. 使用 docker‑compose 启动 Harbor

在 `harbor-runtime` 目录内执行：

```bash
cd ~/master/k8s/utils/HARBOR-KIND-EXTERNAL/harbor-runtime

sudo ./prepare
sudo ./install.sh
```

第一次执行会拉取若干 Harbor 相关镜像，请耐心等待。

---

### 8. 验证 Harbor 服务是否正常

#### 8.1 进程状态

```bash
cd ~/master/k8s/utils/HARBOR-KIND-EXTERNAL/harbor-runtime
docker compose ps
```

确认 `harbor-core` / `harbor-portal` / `harbor-registry` 等容器均为 `Up`。

#### 8.2 HTTP(S) 接口连通性

```bash
curl -k https://harbor.sunmoonai.com:30443/api/v2.0/projects
```

- 返回 JSON 或 `401`（未认证）都说明服务已就绪。

---

### 9. 配置 WSL 侧 hosts + CA + 登录

运行已有的脚本即可（该脚本会：

- 写入 `/etc/hosts` 中的 `harbor.sunmoonai.com`；
- 分发 Root CA 到 `/etc/docker/certs.d/harbor.sunmoonai.com:30443/ca.crt`；
- 可选地执行 `docker login`）：

```bash
cd ~/master/k8s/sunmoonai/kind-infrastructure
./wsl-setup-harbor-hosts-and-login.sh --login
```

执行成功后，你可以在 WSL 中直接验证：

```bash
docker login harbor.sunmoonai.com:30443
```

---

### 10. 后续运维：启动 / 停止 / 升级

#### 10.1 启停命令

在 `harbor-runtime` 目录中：

```bash
# 停止
cd ~/master/k8s/utils/HARBOR-KIND-EXTERNAL/harbor-runtime
sudo docker compose down

# 启动
cd ~/master/k8s/utils/HARBOR-KIND-EXTERNAL/harbor-runtime
sudo docker compose up -d
```

> **注意**：Harbor 数据存放在 `/data/harbor`，只要不删除该目录，重启 / 重新安装都不会丢数据。

#### 10.2 将来升级 Harbor

1. 在 `packages/` 目录下载新的 `harbor-online-installer-*.tgz`。
2. **备份旧的 `harbor-runtime` 目录和 `/data/harbor`。**
3. 按 Harbor 官方升级文档执行 `./prepare` 和 `./install.sh`（保持 `hostname`、`https.port`、`data_volume` 不变）。

---

### 11. 与 Kind / 业务脚本的关系

- 所有 k8s 部署脚本仍然使用：
  - `harbor.sunmoonai.com:30443/k8s-images/...`
- 你在 Kind 上做的：
  - `deploy-kind.sh`（创建 / 重建集群）
  - 各平台 `deploy-*-platform-all.sh`

都只会从这个外部 Harbor 拉镜像，不会影响 Harbor 本身：

- **重建 Kind 不会删 Harbor**；
- **重建 Kind 不会强制重新 push 镜像**（除非你自己手动执行 push 脚本）。

