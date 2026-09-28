# 宿主机使用独立镜像仓库

唯一实现为 `registry-platform/client.py`，根入口 `./sunmoon harbor client`。
本地和云主机使用相同实现，以 `--config` 或 `REGISTRY_CONFIG_FILE` 选择独立仓库配置。
没有显式配置且 CLUSTER 为空或 KIND 时使用 `config/local-wsl.conf`；云集群必须显式选择仓库配置；不读取旧建群配置，不查询当前 Kubernetes context。
这是**执行命令的宿主机**的消费配置，不能代替 KIND 节点、远程节点或 CI 容器的配置。
云端 SSH 调度接线和实机运行仍未验证，此工具本身不会执行 SSH。

## 操作分开、默认只打印

```bash
./sunmoon harbor client hosts
./sunmoon harbor client trust
./sunmoon harbor client check
./sunmoon harbor client login
```

以上均不会改文件、读取口令、联网、启动 Windows 或重启 Docker。
地址固定 `harbor.sunmoonai.com:30443`；域名解析读取 `REGISTRY_CLIENT_ADDRESS`，
CA 读取 `REGISTRY_CA_FILE`，按 `REGISTRY_CA_SHA256` 核验。配置是所有者维护的可信 Shell 文件，不接受外部下载的任意配置。

明确进入客户端配置阶段后，才加 `--apply`：

| 操作 | 实際影响与失败条件 |
| --- | --- |
| `hosts --apply` | 需 root，更新本机 `/etc/hosts` 中精确的 Harbor 域名，保留同一行其他别名；无合法客户端 IP 则失败 |
| `trust --apply` | 需 root，CA 摘要正确且能解析后，安装到 Docker 的 `harbor.sunmoonai.com:30443`、无端口及 `:443` 三个精确目录，以及系统 CA；随后执行 `update-ca-certificates`；任何一步失败返回非零 |
| `check --apply` | 无凭据直接 TLS GET `/v2/`，校验 CA、域名、HTTP 200/401 和 Registry v2 响应头；不使用终端 HTTP(S) 代理 |
| `login --apply` | 先执行同样的 TLS 预检，再为当前用户运行 Docker 登录；口令只经 stdin；失败/超时返回非零 |

证书操作不会重启 Docker，也不删除系统中其他 CA。三个 Docker 目录兼容之前已存在的同域名端口别名，
避免旧脚本按域名前缀通配改动其他仓库目录。文件逐个原子替换，整组不是事务；系统 CA 刷新失败时不能报告成功，可修复原因后重复执行。

提权执行时要显式保留用户 CA 路径，避免 `sudo` 的 HOME 变化选中 root 的私有目录。例如在仓库根：

```bash
sudo ./sunmoon harbor client hosts --apply
sudo env REGISTRY_CA_FILE="$HOME/private/registry-platform/tls-20260927-five-year/ca.crt" \
  ./sunmoon harbor client trust --apply
./sunmoon harbor client check --apply
./sunmoon harbor client login --username '<专用机器人账号>' \
  --password-file "$HOME/private/registry-platform/client-password" --apply
```

口令文件由所有者或既有密钥流程准备，须为当前用户所有、绝对路径、非软链、权限 0600 或 0400、单行非空，
内容不提交 Git。不要把口令写在命令行。Docker 登录会按现有 Docker credential helper/config 保存凭据；
这里不替换 credential helper，不自动登录 root 或 nerdctl。账号应限定到所需项目和推拉权限。

日常也可在 `.conf` 设置 `REGISTRY_CREDENTIALS_FILE`，使用一个私有 JSON 同时提供仓库、用户名和密码，
随后运行 `./sunmoon harbor client login --apply`。格式、覆盖顺序、只读与发布账号分离见
[配置对照](../../operations/configuration.md)。默认路径只是一项配置，不代表已创建真实文件。

**当前公开入口仍是旧 KIND，迁移尚未切换。** 本批只有静态检查和默认计划，未执行上述 `--apply`。
客户端检查最多证明所解析端点的 TLS 和 Registry v2 可达，不证明它是新宿主实例、账号可推拉、镜像完整或正式入口已切换。

## 兼容入口与调用方

- `kind-infrastructure/wsl-setup-harbor-hosts.sh` → `client hosts`。
- `kind-infrastructure/sync-docker-harbor-ca.sh` → `client trust`。
- `kind-infrastructure/wsl-setup-harbor-login.sh` → `client login`。

三个兼容入口均转发参数，默认计划；旧的 `HARBOR_ADMIN_PASSWORD`、自动交互登录、
`SYNC_DOCKER_RESTART_DOCKER` 不再触发动作。需要实际操作时按本页显式选择动作和私有文件。
`push-images-to-harbor.sh` 不再在推送前自动刷新系统信任，先完成客户端配置再推送。
PostgreSQL、RabbitMQ、pgAdmin、RedisInsight 的四处旧镜像工具空检查已删除，它们原本没有执行镜像操作。

## 尚未完成的共用链路

1. Secret 公共库已取消从总控/建群配置补凭据；平台总控、应用生成器、十二个组件调用点和 RAGFlow 已支持显式私有文件。既有配置中的历史凭据值与其他调用链仍待逐项退役，不声称所有私有输入已迁好。
2. 旧 Harbor 镜像工具及 KIND 推送工具的物料加载、标签、真实推拉需继续收口；本页不宣称镜像发布链已完成统一。
3. Docker daemon 的 NO_PROXY 与终端环境不同；本工具不自动更改 daemon 代理或重启它。节点 containerd 和 CI 的域名、CA、NO_PROXY、imagePullSecrets 分别验收。
4. 正式验收包含新入口身份核对、Docker Engine 和节点按 digest 拉取、真实 CI 推送/拉取、重建 KIND 后 Harbor 摘要和数据不变。

| 规则 | 本批处理 |
| --- | --- |
| C-I8 | 缺配置、CA 摘要不符、登录失败均明确失败，不自动跳过 |
| C-R1/C-R2 | 不改既定版本、离线锁及发布 digest；当前只整理客户端入口 |
| C-D1 | 不创建第二个数据主档，不改变仓库实例或入口 |

回退代码使用本批之前的 Git 提交审阅恢复；不能直接运行旧脚本来回退现场证书或代理。

## 组件镜像检查

`./sunmoon harbor images check --component postgresql` 默认计划；`--apply` 进行严格 TLS、私有账号的 manifest 查询。
不查 Harbor Pod、不自动补推；缺失与认证/网络错误分别返回失败。具体边界和配置见 [检查说明](../../docs/harbor-component-image-ensure.md)。
