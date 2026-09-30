# 独立 Harbor：配置与生命周期

当前单元使用 Harbor **2.15.2 官方离线包**、官方 `prepare` 镜像、Compose **5.5.1** 与 systemd。数据库、Valkey、Trivy 均使用该官方包配套镜像，按归档 manifest 摘要固定。镜像与版本来自发布锁，不从站点配置覆盖。

## 日常操作

在 `platform/` 执行，全部经过同一 Ansible playbook：

```sh
make registry-plan    # 查看配置路径和端口，并检查宿主挂载
make registry-deploy  # 配置并启动；已运行且配置相同则复核
make registry-status  # 查看 systemd 状态；不要求数据盘已挂载
make registry-stop    # 停止本次新 Harbor；不删除容器、卷或数据
make registry-start   # 核挂载后启动，等待健康并核验认证
```

首次需要先完成 `make prepare-harbor-materials` 和 `make install-binaries BINARIES=compose`。当前入口要求宿主已有 Docker、systemd、OpenSSL、无交互 sudo 和已正确附加的数据盘。全新宿主引导尚未完成。

修改配置、镜像或资源策略时先 `registry-stop`，再 `registry-deploy`。运行中发现配置变化会拒绝应用，防止文件与实际进程不一致；停服部署会重新运行官方生成器，允许重试先前中断的配置生成。单独 `registry-start` 使用已部署配置，不吸收仓库中的修改。`registry_enabled: false` 会阻止部署和启动，仍允许停止与查看。

## 目录与入口

| 位置 | 用途 |
| --- | --- |
| `release.yaml` | 服务集合、资源上限、健康依赖和证书期限 |
| `../environments/kind/site.yaml` | 开关、路径、域名、后端端口与磁盘 UUID |
| `/etc/sunmoon/registry/private/` | 独立随机管理员与数据库凭据，root:0600 |
| `/etc/sunmoon/registry/tls/` | 独立 CA、私钥和服务器证书；私钥 root:0600 |
| `/opt/sunmoon/registry/` | 官方生成配置、校验过的 Compose、挂载守卫；不依赖工作树运行 |
| `/data/harbor/platform-kind-v1/data/` | 新 Harbor 的数据库、镜像层、加密密钥及扫描器数据 |
| `/data/harbor/platform-kind-v1/logs/` | 官方组件保留的日志目录 |

父目录 root:0700。凭据不进 Git、不打印到命令或 Ansible 输出。管理员密码仅在数据库首次初始化时生效，不能通过改本地文件当作密码轮换；后续部署会实际登录，文件与数据库不符就失败。现有凭据不会自动重建；证书/密钥只剩半对时停止并要求检查，不自动覆盖身份。

新后端只监听 **127.0.0.1:11443**，正式地址仍设为 **harbor.sunmoonai.com:30443**。30443 当前仍由旧入口提供服务。**后端健康与管理员认证通过，不代表正式域名的 Docker token 流程和镜像推拉已经通过。**后者必须在新入口接好后验收。

服务器证书为私有 CA 签发，期限 1825 天，CA 3650 天。SAN 包含正式域名与 127.0.0.1。部署检查信任链、域名、至少 30 天剩余有效期，以及证书和私钥公钥匹配。当前证书到期于 2031-09-29 UTC。浏览器、Docker 和未来 KIND 节点的正式域名信任配置仍需随入口切换完成，未替换旧服务证书。

## 官方生成器与安全边界

不执行官方 `install.sh`（含 `compose down -v`），也不执行安装包的 `prepare` 包装脚本（它会尝试搬动全局 `/data/secretkey`、`/data/defaultalias`）。直接运行同版本官方 `prepare` 镜像的 `prepare --with-trivy`：仅挂载本实例配置、数据和指定证书，不使用 privileged 或整个宿主根目录挂载，生成时禁用网络。

官方生成的 Compose 原件保留。小型 override 只负责 digest、资源限制、宿主端口、日志策略、健康依赖和重启归属。使用 Compose 原生合并，不增加部署状态管理器。

systemd 是唯一重启管理者，Compose 前台运行、容器 `restart: no`。任一组件退出后停止整组，由 systemd 经过挂载守卫重启；120 秒内最多启动 3 次。依赖组件通过官方镜像自带健康检查后才启动调用方，避免首次初始化时 jobservice 抢先访问 core。

每次启动检查精确挂载点、ext4、UUID、bind 子目录、宿主与 Docker 所见 inode/设备号，以及实例目录确在同一数据盘。检查失败不启动。停止与状态查询不依赖挂载预检。挂载守卫只保证启动前状态，**不能替代运行期磁盘故障监控**。

unit 已安装，**尚未启用开机自启**：自动附盘、Docker 与服务的完整开机顺序仍须实际验证。本轮的进程启停验收不等于 WSL 重启验收。

## 日志与删除授权

所有者已批准：每容器 Docker `local` 日志最多 **3 份 × 20 MiB**，自动轮转；共 10 个容器，按配置约 600 MiB 上限，不含存储元数据和额外组件文件。Compose 不向 journald 再转发容器输出，journal 保留生命周期消息；查看某组件日志可用 `sudo docker logs --tail 100 sunmoon-registry-core-1`，分享前检查敏感内容。

Harbor jobservice 使用标准输出日志。未启用镜像保留规则、垃圾回收或备份删除；上传残留清理也设为关闭。日志授权不延伸到镜像、数据和备份。长期容量监控与其他删除策略仍为后续工作。

## 验收范围与剩余项

本单元实际启动 10 个官方服务，验证证书校验后的 `/api/v2.0/health`、管理员身份接口，以及匿名 `/v2/` 返回 401。重复部署与停止/启动结果见根目录 `CHECKPOINT.md`。

Trivy 配置为离线、跳过自动更新；**漏洞数据库尚未准备，容器 healthy 不代表能扫描**。还须完成数据库物料及真实镜像扫描。

尚未完成：30443 新入口与完整镜像推拉、配置/数据备份及恢复演练、开机与 WSL 重启、KIND 重建持久化、平台和应用部署、整套一键部署与统一启停。备份必须同时覆盖 `/etc/sunmoon/registry` 与实例 data（含 Harbor 加密密钥），并固定本次发布输入；只复制镜像层不构成可恢复备份。

本单元退回方法：`make registry-stop`，保留新实例目录等待处理；旧入口、旧 Harbor、集群和受保护备份没有切换或删除。
