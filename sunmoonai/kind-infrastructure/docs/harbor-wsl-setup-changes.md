## Harbor WSL 登录与推送调试纪要（2026-03-04）

这份文档记录了今天从 WSL 上 `docker login` Harbor 失败，到最终打通「登录 + 一键推送镜像」整条链路的关键过程，供以后排障和回顾设计思路使用。

---

### 一、最初症状

- 在 WSL 中执行：
  - `docker login harbor.sunmoonai.com -u admin -p ...`
- 相继遇到的错误：
  - `context deadline exceeded`
  - `SSL certificate problem: unable to get local issuer certificate`
  - 之后是 `login attempt to http://harbor.sunmoonai.com/v2/ failed with status: 502 Bad Gateway`
  - 再后来变成 `EOF`、`connect: connection refused` 等。

`curl` 直接访问 Harbor 时，能看到证书是自签 CA，但系统默认不信任。

---

### 二、Harbor 暴露方式与端口梳理

- Kind 集群端口映射（`kind-cluster.yaml`）：
  - `containerPort: 30443` → `hostPort: 443`（控制面容器）
- 集群内：
  - Traefik/Harbor 对外暴露 NodePort：**30443**
- WSL 访问思路几轮演进：
  1. 一开始在 WSL 访问 `harbor.sunmoonai.com` → `127.0.0.1:443`，证书是自签 CA。
  2. 发现 Docker 把 **127.0.0.0/8** 视为 insecure registry，容易退回 HTTP，配合自签证书导致各种 502/EOF。
  3. 最终方案：**WSL 不再用 127.0.0.1，而是直连 Kind control-plane 的内网 IP：`<InternalIP>:30443`**，例如 `172.18.0.2:30443`。

---

### 三、证书与 CA 分发改造

已有脚本：`wsl-setup-harbor-hosts-and-login.sh`，原设计仅：

- 写 `/etc/hosts`：`127.0.0.1 harbor.sunmoonai.com`
- 将 Harbor 根 CA 拷贝到：
  - `/etc/docker/certs.d/harbor.sunmoonai.com:30443/ca.crt`

问题与改造：

- **问题 1：端口不一致**
  - 用户常用 `docker login harbor.sunmoonai.com`（默认 443），但 certs.d 只为 `harbor.sunmoonai.com:30443` 配了 CA。
  - Docker 找证书是按「主机:端口」拆目录的，导致有 CA 却没被用上。
- **问题 2：仅信任 certs.d，不信任系统 CA**
  - 尤其在 Docker 29+ 或涉及 containerd 的情况下，系统 CA 也有价值。

最终改造：

- WSL 侧访问统一采用：`harbor.sunmoonai.com:30443`。
- `wsl-setup-harbor-hosts-and-login.sh`：
  - `/etc/hosts` 中将 `harbor.sunmoonai.com` 指到 Kind control-plane IP（后文自动检测）。
  - 将根 CA 拷贝到：
    - `/etc/docker/certs.d/harbor.sunmoonai.com:30443/ca.crt`
  - 同时将 CA 安装到系统信任：
    - `/usr/local/share/ca-certificates/sunmoonai-harbor-ca.crt` + `update-ca-certificates`。

验证结果：

- `curl -vk --noproxy '*' https://harbor.sunmoonai.com:30443/v2/` 能成功握手，返回 401（未认证，预期行为）。

---

### 四、Docker 代理与 NO_PROXY 问题（EOF 的根因）

调试中发现：

- `systemctl show docker --property=Environment` 显示：
  - `HTTP_PROXY=http://172.28.32.1:7890`
  - `HTTPS_PROXY=http://172.28.32.1:7890`
  - `NO_PROXY=localhost,127.0.0.1`
- 也就是说 **dockerd 默认所有 HTTPS 请求都走代理**。
- 对 Harbor 的访问路径变成：
  - `dockerd → 172.28.32.1:7890 (代理) → CONNECT harbor.sunmoonai.com:30443` → 被拒绝或中断 → `EOF`。

解决方案：

- 修改 `/etc/systemd/system/docker.service.d/http-proxy.conf`：
  - 将 `NO_PROXY` 扩展为：
    - `NO_PROXY=localhost,127.0.0.1,harbor.sunmoonai.com,.sunmoonai.com,<Kind control-plane IP 可选>`
- 使得 Docker 对 `harbor.sunmoonai.com:30443` 直连，不再经过代理。

效果：

- 错误从 `EOF` 变成 `connect: connection refused`，说明路径已直连到 `172.18.0.2:30443`，后续问题来自集群本身（Traefik 未监听）。

---

### 五、Traefik/Harbor 集群侧问题与修复

在错误变为 `connection refused` 后，排查 K8s 集群：

- `kubectl get pods -n ingress-platform-dev`：
  - `traefik-sunmoonai-... 0/1 Unknown`。
- `kubectl describe pod` 显示：
  - `FailedMount`：`data` PVC 挂载超时，Pod 不断重建。
- 导致：**没有进程在监听 NodePort 30443**，WSL 访问自然是 connection refused。

后续通过重新部署/确保 NFS Provisioner 正常等方式恢复：

- Traefik Pod `1/1 Running`。
- Harbor 全部 Pod `Running`。
- `curl --noproxy '*' https://harbor.sunmoonai.com:30443/v2/` → 401。
- `docker login harbor.sunmoonai.com:30443` → `Login Succeeded`。

至此，**集群内外链路都打通**。

---

### 六、配置通用化与自动检测 IP

为避免写死 IP（如 `172.18.0.2`）在 Kind 重建后失效，对配置做了通用化处理：

- `deploy-kind.conf` 中：
  - `HARBOR_IP=""`（留空表示自动检测）。
  - 保留 `HARBOR_NODE_IP="172.18.0.2"` 作为集群内使用。
- `wsl-setup-harbor-hosts-and-login.sh` 中：
  - 若 `HARBOR_IP` 为空，则通过 `kubectl` 自动获取当前 Kind control-plane 的 `InternalIP`：
    - `kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'`
  - 获取失败时退回 `HARBOR_NODE_IP`，再退回默认值。
  - `/etc/hosts`：
    - 若已有 `harbor.sunmoonai.com` 记录但 IP 不符，会自动更新为当前检测到的 IP。

这样，**重建 Kind、IP 变化后，不需要手工改 WSL 侧配置**。

---

### 七、一键脚本行为调整（deploy-kind.sh）

为兼顾「开发方便」与「生产推送可控」，对 `deploy-kind.sh` 做了两类改造。

1. **步骤 7：仅负责 WSL 侧基础环境**
   - 原先在此步骤尝试自动 `docker login`，现在改为：
     - 只调用 `wsl-setup-harbor-hosts-and-login.sh` 做 `/etc/hosts` 和 CA 分发；
     - 显式 `unset HARBOR_ADMIN_PASSWORD`，让脚本内部不会自动登录；
     - 避免 Harbor 启动慢导致一键脚本失败。

2. **可选推送步骤：受 `DEPLOY_KIND_RUN_PUSH_TO_HARBOR` 控制**
   - 当 `DEPLOY_KIND_RUN_PUSH_TO_HARBOR="true"` 且配置了镜像来源时（`DEPLOY_KIND_PUSH_IMAGE_FILES` 或 `DEPLOY_KIND_PUSH_TAR_DIRS`）：
     1. **等待 Harbor 就绪**：
        - 使用 `wait_for_harbor` 函数循环请求 `/v2/`，最长 `HARBOR_WAIT_TIMEOUT`（默认 300s）。
        - 未就绪则 `exit 1`，一键脚本失败。
     2. **自动登录 Harbor**：
        - 需在 `deploy-kind.conf` 中配置 `HARBOR_ADMIN_PASSWORD`；
        - 通过 `docker login harbor.sunmoonai.com:30443` 登录，失败则 `exit 1`。
     3. **推送镜像**：
        - 调用 `push-to-harbor/push-images-to-harbor.sh`，并通过 `--img-file/--tar-dir` 传入来源。
        - 任何一步失败都会让 `deploy-kind.sh` 以非 0 退出。

目前推荐配置（示例）：

- `DEPLOY_KIND_RUN_PUSH_TO_HARBOR="true"`
- `DEPLOY_KIND_PUSH_TAR_DIRS="../../../../packages-to-be-installed/images"`  
  → 解析为 `/home/zymun/packages-to-be-installed/images`，该目录下有大量 `.tar` 文件。

---

### 八、常见错误及快速定位

1. **TLS 或 CA 问题：**
   - `curl https://harbor.sunmoonai.com:30443/v2/` 提示证书不受信任：
     - 检查 `wsl-setup-harbor-hosts-and-login.sh` 是否已正确分发 CA 到 `certs.d` 和系统 CA。

2. **EOF / HTTP 502：**
   - 多半是 **Docker 通过代理访问 Harbor**：
     - 检查 `systemd` 的 `http-proxy.conf` 中 `NO_PROXY` 是否包含 `harbor.sunmoonai.com,.sunmoonai.com`。

3. **connection refused：**
   - 多半是 **Traefik/Harbor Pod 未就绪或端口未监听**：
     - `kubectl get pods -n ingress-platform-dev` 看 Traefik 状态；
     - 用 `curl --noproxy '*' https://harbor.sunmoonai.com:30443/v2/` 验证。

4. **“未指定任何镜像来源” 报错：**
   - 原因：
     - `DEPLOY_KIND_PUSH_IMAGE_FILES` / `DEPLOY_KIND_PUSH_TAR_DIRS` 解析后目录不存在或目录中无 `.tar`；
     - 或未配置 `DEFAULT_IMAGE_FILES` / `DEFAULT_TAR_DIR` 且没传 `--img-file/--tar-dir`。
   - 排查：
     - 确认 `DEPLOY_KIND_PUSH_TAR_DIRS` 解析后的绝对路径是否指向含 `.tar` 的目录，例如：
       - `DEPLOY_KIND_PUSH_TAR_DIRS="../../../../packages-to-be-installed/images"` → `/home/zymun/packages-to-be-installed/images`。

---

### 九、小结

最终稳定方案核心点：

- **访问路径**：WSL 统一使用 `harbor.sunmoonai.com:30443`，并通过 `/etc/hosts` 指向 Kind control-plane IP。
- **证书信任**：CA 同时分发到 Docker `certs.d` 和系统 CA。
- **代理绕过**：在 `NO_PROXY` 中加入 `harbor.sunmoonai.com,.sunmoonai.com`（可选再加当前 Kind 节点 IP）。
- **IP 自动检测**：Kind 重建后，脚本自动通过 `kubectl` 获取 control-plane IP，不再写死。
- **一键推送**：只在需要推送时严格等待 Harbor、自动登录，并在镜像源或登录失败时立即终止流程。

这套设计兼顾了本机开发易用性（hosts+CA 自动配置、可选自动登录）与一键部署的可预期性（有推送需求时严格校验、失败即止）。 
# Harbor WSL 登录相关改动说明

## 改动清单与必要性

| 位置 | 改动内容 | 必要性 | 说明 |
|------|----------|--------|------|
| **deploy-kind.conf** | `HARBOR_IP="172.18.0.2"` | ✅ 必要 | 用 127.0.0.1 时 Docker 将 127.0.0.0/8 视为 insecure，强制走 HTTP → 502 |
| **deploy-kind.conf** | `HARBOR_PORT="30443"` | ✅ 必要 | 直连 Kind 节点只能用 Traefik NodePort 30443；节点上无 443 监听 |
| **wsl-setup-harbor-hosts-and-login.sh** | 默认 IP/端口 172.18.0.2 / 30443 | ✅ 必要 | 与 conf 一致，保证脚本单独跑时也正确 |
| **wsl-setup-harbor-hosts-and-login.sh** | 已存在 hosts 但 IP 不符时自动更新 | ✅ 建议保留 | 从 127 切到 172.18.0.2 时无需手改 /etc/hosts |
| **wsl-setup-harbor-hosts-and-login.sh** | CA 分发到 `certs.d/harbor.sunmoonai.com:30443` | ✅ 必要 | Docker 按「主机:端口」找证书，当前只用 :30443 |
| **wsl-setup-harbor-hosts-and-login.sh** | CA 同时分发到 `certs.d/harbor.sunmoonai.com`（无端口） | ⚪ 可选 | 仅当有人用 `docker login harbor.sunmoonai.com`（默认 443）时才需要；当前统一用 :30443 可删 |
| **wsl-setup-harbor-hosts-and-login.sh** | 根 CA 加入系统信任（ca-certificates + update-ca-certificates） | ⚪ 可选 | EOF 最终是代理导致，非证书；保留可提高 containerd/其他工具兼容性 |
| **/etc/docker/daemon.json** | `"insecure-registries": []` | ❌ 非必要 | 无法覆盖 127.0.0.0/8 默认行为，可还原为仅 `data-root` |
| **/etc/systemd/.../http-proxy.conf** | `NO_PROXY` 增加 `harbor.sunmoonai.com,.sunmoonai.com`（建议再加当前 Kind control-plane IP，或留空 HARBOR_IP 让脚本自动检测后按提示加） | ✅ 必要 | 否则 dockerd 走 HTTPS 代理访问 Harbor → EOF；用主机名可通用，集群重建后 IP 变也无需改 |

## 与一键推送 Harbor 相关的行为说明

- **可选推送步骤**：当 `DEPLOY_KIND_RUN_PUSH_TO_HARBOR="true"` 且配置了 `DEPLOY_KIND_PUSH_IMAGE_FILES` / `DEPLOY_KIND_PUSH_TAR_DIRS` 时，`deploy-kind.sh` 会在末尾调用 `push-to-harbor/push-images-to-harbor.sh`，并做三件事：  
  1. **等待 Harbor 就绪**：循环调用 `/v2/`，最长等待 `HARBOR_WAIT_TIMEOUT`（默认 300 秒），日志类似：`等待 Harbor 就绪 (harbor.sunmoonai.com:30443，最长 300s)...` → `Harbor /v2/ 已响应`。  
  2. **自动登录 Harbor**：使用 `HARBOR_ADMIN_PASSWORD` 执行 `docker login harbor.sunmoonai.com:30443`，成功会打印 `Login Succeeded`。  
  3. **执行镜像推送**：将配置的镜像列表或 tar 目录中的镜像推送到 Harbor。
- **常见报错**：若日志中出现  
  `未指定任何镜像来源，请设置 conf 中 DEFAULT_IMAGE_FILES 或 DEFAULT_TAR_DIR，或使用 --img-file/--tar-dir`，说明：  
  - 通过 `DEPLOY_KIND_PUSH_IMAGE_FILES` / `DEPLOY_KIND_PUSH_TAR_DIRS` 传入的路径为空或目录下没有 `.tar` 文件；或者  
  - 直接调用 `push-images-to-harbor.sh` 时未在 `push-images-to-harbor.conf` 中配置 `DEFAULT_IMAGE_FILES` / `DEFAULT_TAR_DIR`。  
  这类错误与 Harbor / WSL 登录无关，只需检查推送源路径是否正确（例如 `DEPLOY_KIND_PUSH_TAR_DIRS` 指向的目录是否存在 `.tar`）。

## 结论

- **必须保留**：`HARBOR_IP=172.18.0.2`、`HARBOR_PORT=30443`、hosts 更新逻辑、CA 分发到 `...:30443`、Docker 的 `NO_PROXY` 扩展。
- **可简化**：脚本里只保留对 `harbor.sunmoonai.com:30443` 的 certs.d 分发即可；系统 CA 和 daemon.json 的 `insecure-registries` 可按需保留或还原。
