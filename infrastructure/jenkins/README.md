# 宿主上的 Jenkins 控制器

设计见 [SDD 0033](../../docs/dev-investment-agent/tree-build/SDD/modules/0033-jenkins-on-host.md)。控制器是官方 LTS 镜像，走物料锁（[上游镜像锁](../artifacts/upstream-images.lock.json)、[宿主归档锁](../artifacts/host-archives.lock.json)，归属 `host/jenkins`），Compose 加 systemd 单元 `sunmoon-jenkins.service`，数据在数据盘，只绑回环。随附一个用已锁 HAProxy 镜像的 TLS 终止器：宿主入口按 SNI 把 `jenkins.sunmoonai.com` 直通到它，所以只在内网 30443 上能开，边缘（SDD 0013）不转发这个域名。控制器里不存任何平台秘密；它不渲染、不部署、不管密文，这些仍是本目录别的程序。

干活的代理（inbound agent，宿主进程）、只读的 `render-check`、`release` 流水线是 0033 第八节的第 2 到 4 步，不在本页。

## 安装、启停和前提

需要 registry 已部署（本地 CA 在 `registry_config_dir/tls/`，控制器证书由它签）、入口模块、Docker、systemd、非交互 sudo、可见的数据盘；物料与工具按 [artifacts](../artifacts/README.md)、[tools](../tools/README.md)。首次使用：

```sh
make -C infrastructure prepare-host-materials          # 拉取并归档已锁的 jenkins、haproxy、skopeo 镜像
make -C infrastructure platform-account-import OBJECT=jenkins   # 密码表第 13 项 → 首次预设（只写预设，不动服务器）
make -C infrastructure jenkins-plan
make -C infrastructure jenkins-deploy
make -C infrastructure entry-stop && make -C infrastructure entry-deploy   # 入口加 jenkins 这条 SNI 路由（改活着的监听要先停）
make -C infrastructure jenkins-status
```

日常控制：`jenkins-stop`、`jenkins-start`、`jenkins-status`。plan 只看配置；deploy 校验镜像与 Compose、建目录、准备口令与证书、写运行配置、`haproxy -c` 离线核一遍、加入 `sunmoon-platform.target`（单元自己的 `WantedBy`，目标那边是 Wants，单独停 Jenkins 不会带停别的）并启动；运行配置有变化时拒绝 deploy，先 `jenkins-stop`。deploy 与 start 都等到经 TLS 后端能打开登录页、管理员能通过认证、匿名被拒，才算成功。

## 配置、数据与秘密位置

当前值以 [config.yaml](config.yaml) 为准。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `jenkins_enabled` | 开关 | 部署/启动准入；不代替停止、卸载或删除数据。 |
| `jenkins_hostname` | 文本 | 与入口 SNI 路由、证书 SAN、Jenkins 根地址联动；边缘不开。 |
| `jenkins_project` | 文本 | Compose 实例名。 |
| `jenkins_https_port` / `jenkins_http_port` / `jenkins_agent_port` | 整数 | 都只绑 127.0.0.1；改端口要同时改入口路由（https）与第 2 步的代理单元（http、agent）。 |
| `jenkins_config_dir` / `jenkins_runtime_dir` | 文本 | 目录责任；已有输入需完整恢复与路径守卫。 |
| `jenkins_data_dir` | 文本 | 必须是数据盘整盘挂载点下的一级子目录（0033 原写 `/data/jenkins`，改为不另加 bind：同一块盘、少一个挂载单元）。 |
| `jenkins_memory` / `jenkins_cpus` | 资源 | 控制器容器上限；构建不在控制器上跑。 |
| `jenkins_certificate_days` | 整数 | 服务证书有效期；到期前 30 天 deploy 会拒绝。 |

| 内容 | 位置/责任 |
|---|---|
| 本地管理员口令 | `jenkins_config_dir/private/admin-password`，root 0600；独立备份 `jenkins_credential_backup_dir/admin-password`；首次预设 `private/presets/admin-password`（密码表第 13 项导入） |
| 容器读的那一份 | `jenkins_runtime_dir/secrets/admin-password`，容器用户 1000 只读 0400；只在第一次启动建账号时读 |
| 服务证书与私钥 | `jenkins_config_dir/tls/server.{key,crt}`，由 registry 本地 CA 就地签发（不复制 CA 私钥）；HAProxy 用的合并件 `jenkins_runtime_dir/tls/jenkins.pem`，root:10001 0640 |
| 运行配置 | `jenkins_runtime_dir/{compose.yaml,haproxy.cfg,init.groovy.d/,storage.json,check-storage.py,docker-compose}` |
| Jenkins 自己的数据 | `jenkins_data_dir/home`（JENKINS_HOME），容器用户 1000，0700 |

## 物料（都在 [文件锁](../artifacts/files.lock.json) 与 [上游镜像锁](../artifacts/upstream-images.lock.json)，归属 `host/jenkins`）

| 物料 | 版本 | 给谁用 | 怎么来的 |
| --- | --- | --- | --- |
| 控制器镜像 `jenkins/jenkins` | 2.580.1-lts-jdk21（linux/amd64 manifest `sha256:5e70c4e8…`） | 第 1 步控制器 | 多架构索引解析到 amd64，归档按 docker save 锁 sha256 |
| 插件闭包 76 个 `.hpi`（`jenkins-plugin-<名>`） | 各自钉死，见锁 | 第 2 步起：流水线、Git、凭据绑定、时间戳、清工作区、读 YAML、阶段视图 | 2026-10-20 用官方镜像里的 `jenkins-plugin-cli` 按 2.580.1 对 `updates.jenkins.io` 解出的依赖闭包；种子 7 个：workflow-aggregator、git、credentials-binding、timestamper、ws-cleanup、pipeline-utility-steps、pipeline-stage-view；下载地址 `updates.jenkins.io/download/plugins/<名>/<版本>/<名>.hpi`（跳转到镜像站，字节与解析时相同，抽查过 git、timestamper）。官方镜像不带插件，运行时不从公网装 |
| 代理 JRE `temurin-jre` | Temurin 21.0.12.1+1（jre，linux x64） | 第 2 步宿主代理（inbound agent 要 Java 17 或 21） | Adoptium 发布包，sha256 与其 `.sha256.txt` 一致；包内 `bin/java`、`lib/server/libjvm.so` 另锁 |

取物料：`make -C infrastructure fetch-artifacts ARTIFACTS=<id,…>`（插件可一次给全部 `jenkins-plugin-*` 的 id）。第 2 步的剧本把插件放进控制器的 `ref/plugins/`、把 JRE 装到 `.tools/`，都按锁校验后才用。

## 账号

第一版只有本地管理员 `admin`：`platform-account-plan/import/view OBJECT=jenkins` 走 [host/accounts.md](../host/accounts.md) 的同一套。导入只写预设；第一次启动时 `init.groovy.d/01-platform.groovy` 用预设建账号、关匿名读、执行器数设 0、固定 agent 端口、设根地址，之后不再覆盖（改口令在 Jenkins 界面里做，真值与表的同步以后随轮换协议接）。预设缺失时 deploy 生成随机口令写进私有文件并备份，从不覆盖已有身份；控制器已初始化而口令文件丢了，必须从独立备份恢复，拒绝重新生成。Casdoor 单点登录等 D 段一起接。

## 怎么验

- `jenkins-status` 退出 0，`ActiveState=active`。
- 内网：浏览器开 `https://jenkins.sunmoonai.com:30443/`，证书由平台 CA 签（和 Harbor 一样），用第 13 项登录。
- 边缘：从东京边缘访问同一域名得 404（0013 未列出的域名）。
- 宿主：`curl --cacert /etc/sunmoon/registry/tls/ca.crt https://127.0.0.1:18443/login` 200；`http://127.0.0.1:18080/login` 200（代理用）；`ss -ltn` 里三个端口都只在 127.0.0.1。
- 开机：`wsl --shutdown` 后随 `sunmoon-platform.target` 自己起来（0033 第七节第 4 条，账 104 的一部分）。
