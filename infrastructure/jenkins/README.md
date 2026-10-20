# 宿主上的 Jenkins 控制器

设计见 [SDD 0033](../../docs/dev-investment-agent/tree-build/SDD/modules/0033-jenkins-on-host.md)；**给所有者看的、从打开页面讲起的用法在 [使用说明](使用说明.md)**，本页是维护者的。控制器是官方 LTS 镜像，走物料锁（[上游镜像锁](../artifacts/upstream-images.lock.json)、[宿主归档锁](../artifacts/host-archives.lock.json)，归属 `host/jenkins`），Compose 加 systemd 单元 `sunmoon-jenkins.service`，数据在数据盘，只绑回环。随附一个用已锁 HAProxy 镜像的 TLS 终止器：宿主入口按 SNI 把 `jenkins.sunmoonai.com` 直通到它，所以只在内网 30443 上能开，边缘（SDD 0013）不转发这个域名。控制器里不存任何平台秘密；它不渲染、不部署、不管密文，这些仍是本目录别的程序。

干活的**代理**是宿主进程（第 2 步起）：inbound agent 作为今天跑发布卡的那个宿主用户（`jenkins_agent_user` = `cluster_operator`）跑在 `sunmoon-jenkins-agent.service` 下，经回环 `jenkins_http_port` 连控制器的节点 `host`；JRE（锁 `temurin-jre`）与 `agent.jar`（从我们自己的控制器取）装在 `jenkins_runtime_dir`，不依赖人的工位；它干活用的仓在数据盘 `jenkins_repos_dir`（k8s 与六个应用仓并列，像 `~/worktrees/<工位>`，从 `jenkins_repo_source_workspace` 工位各仓的 origin 克隆，子仓按 gitlink 走同一把 SSH 钥匙），`.venv`、`.tools` 装在那份 k8s 克隆里。控制器里的 76 个插件从文件锁进 `jenkins_runtime_dir/ref-plugins/`，容器启动时拷进 JENKINS_HOME 并钉住。`release` 流水线是第 3、4 步，不在本页。

**render-check（第 2 步，只读）**：控制器里的任务 `render-check`（首次启动由 `init.groovy.d/03-render-check.groovy` 建，之后不覆盖），定时 `jenkins_render_check_cron` 在代理上跑仓里的 [`ci/render-check.groovy`](../../ci/render-check.groovy)：把 k8s 与各应用仓更新到 `BRANCH` 头；分支头没变就 `NOT_BUILT` 不跑；变了就对 `APPS` 逐个 `application-deployment-plan`（迁移头核对）和 `application-render`（只写 `.build/`），把候选与 `gitops/` 已提交的差异（剔掉摘要行）存成产物。不暂存、不提交、不发布、不碰 Harbor。手动跑一次并等结果：`make -C infrastructure jenkins-agent-check`。

**release（第 3 步起）**：任务 `release`（首启脚本 `04-release.groovy` 建，不覆盖人改过的，无定时器，不并发），参数 `BRANCH` / `APPS`（空格分隔，空 = 六个）/ `PIN`（`keep` 按已提交的 `sources.yaml`；`heads` 用 [`ci/pin-sources.py`](../../ci/pin-sources.py) 钉到各应用父仓在 `BRANCH` 的头和父仓记录的子仓 gitlink）/ `NOTE`。任务体 [`ci/release.groovy`](../../ci/release.groovy)，阶段对应发布卡的小节：1 核对（工作区干净、应用仓到分支头、`platform-status`）→ 2 改钉（改 `sources.yaml`，再逐应用 `application-deployment-plan` 核迁移头，不对就停在这里不进构建）→ 3 构建（`platform-build OBJECT=app-platform/<app>-app`，产物 `3-image-locks.txt`）→ 4 暂存（`platform-stage`，`gitops/` 里不得出现密钥字样，产物 `4-gitops-touched.txt`、`4-gitops.stat`、剔掉镜像与摘要行的 `4-workload.diff`）→ 5 计划（再跑一次 `application-deployment-plan`）。→ 5.5 无差异就标 `NOT_BUILT` 不发 → 6 提交（`deploy(<apps>): <NOTE>（release #n）`，作者 `sunmoon-ci`）→ 7 发布（`flux-release`，候选存产物 `7-source-candidate.yaml`）→ **8 人批**（Jenkins `input`，在 node 外面不占执行器；只有 `jenkins_human_account` 能点；`APPROVAL_TIMEOUT_MINUTES` 到时中止）→ 9 写指针（候选拷进 `environments/kind/flux-source.yaml`，提交 `release(kind): 晋级到 …`，tag `release-<YYYYMMDD>-<序号>`）→ 10 部署（`flux-source-apply`，再等各应用的 kustomization Ready）→ 11 检查（`application-check`）→ 12 推送与回执（流水线写 `scripts/results/release-<n>.<时间>.md`，提交，连 tag 推到 `BRANCH`）。秘密样子核查（age 私钥、PEM 私钥、JWT、Harbor 机器人口令）在前半段收尾、写回执前、后半段收尾各做一次，命中就标红并打码。**半路停下**：第 6 阶段之前撤干净；之后提交留在代理克隆的 `abandoned/release-<n>` 分支不推，构建说明写明集群动没动；第 11 阶段没过流水线不退回，退回是人的维护窗口动作（指针改回上一版再 `flux-source-apply`）。产物在构建页，原件在 `jenkins_repos_dir/k8s/infrastructure/.build/release/<构建号>/`。命令行：`make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="一句话" APPROVAL_TIMEOUT_MINUTES=1440`（`RELEASE_BRANCH` 默认 fable；参数经 urlencode，中文可以，不要引号），等结束（上限 90 分钟 + 审批时长），控制台存 `infrastructure/.build/jenkins/release-<n>.log`；人批仍在页面上点。构建会把镜像推进 Harbor（候选，无害；保留与 GC 是账 106）。

**没有 Jenkins 时**：流水线只是按顺序敲本目录的 make 入口，控制器或代理坏了，人照发布卡手敲同一串命令，结果一样（qwen-001 到 017 就是这么发的）。各应用仓 `mybuild/` 里的 `build-image.sh`、`push-image.sh` 是更早那套，所有者 2026-10-20 决定留着当应急：能单独出一个镜像，但不写 `image.lock.yaml`、不改 gitops 声明，产物不进部署链。

## 安装、启停和前提

需要 registry 已部署（本地 CA 在 `registry_config_dir/tls/`，控制器证书由它签）、入口模块、Docker、systemd、非交互 sudo、可见的数据盘；物料与工具按 [artifacts](../artifacts/README.md)、[tools](../tools/README.md)。代理准备会在自己的 k8s 克隆里通过原生 `install-flux` 安装按锁校验的 Flux CLI，供 release 的候选发布与晋级使用。首次使用：

```sh
make -C infrastructure prepare-host-materials          # 拉取并归档已锁的 jenkins、haproxy、skopeo 镜像
make -C infrastructure platform-account-import OBJECT=jenkins   # 密码表第 13 项 → 首次预设（只写预设，不动服务器）
make -C infrastructure jenkins-plan
make -C infrastructure jenkins-deploy
make -C infrastructure entry-stop && make -C infrastructure entry-deploy   # 入口加 jenkins 这条 SNI 路由（改活着的监听要先停）
make -C infrastructure jenkins-status
```

代理：`make -C infrastructure jenkins-materials`（控制器之外再取插件与 JRE）→ 控制器 `jenkins-stop` + `jenkins-deploy`（放插件与两份新的启动脚本，运行配置变了要先停）→ `jenkins-agent-plan` → `jenkins-agent-deploy` → `jenkins-agent-status` → `jenkins-agent-check`。

日常控制：`jenkins-stop`、`jenkins-start`、`jenkins-status`；代理 `jenkins-agent-stop/start/status`（`platform-stop` 先停代理再停控制器）。plan 只看配置；deploy 校验镜像与 Compose、建目录、准备口令与证书、写运行配置、`haproxy -c` 离线核一遍、加入 `sunmoon-platform.target`（单元自己的 `WantedBy`，目标那边是 Wants，单独停 Jenkins 不会带停别的）并启动；运行配置有变化时拒绝 deploy，先 `jenkins-stop`。deploy 与 start 都等到经 TLS 后端能打开登录页、管理员能通过认证、匿名被拒，才算成功。

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
| `jenkins_agent_user` / `jenkins_agent_name` | 文本 | 代理以哪个宿主用户跑（= `cluster_operator`，不新给权限）、控制器里的节点名与标签；改节点名要删旧节点。 |
| `jenkins_agent_dir` / `jenkins_repos_dir` | 文本 | 数据盘上代理自己的目录与它干活用的仓；都在 `jenkins_data_dir` 下一级。 |
| `jenkins_repo_source_workspace` | 文本 | 克隆各仓时从哪个工位读 origin 地址（只读地址，不读那个工位的文件）。 |
| `jenkins_tools_binaries` | 列表 | 仓克隆里要装的工具（`install-binaries`）；sops、age 另由 `install-secrets-tools` 装。 |
| `jenkins_render_check_cron` / `_branch` / `_apps` | 文本 | render-check 的定时、默认分支与默认应用；只在首次建任务时生效，之后在 Jenkins 里改。 |

| 内容 | 位置/责任 |
|---|---|
| 本地管理员口令 | `jenkins_config_dir/private/admin-password`，root 0600；独立备份 `jenkins_credential_backup_dir/admin-password`；首次预设 `private/presets/admin-password`（密码表第 13 项导入） |
| 容器读的那一份 | `jenkins_runtime_dir/secrets/admin-password`，容器用户 1000 只读 0400；只在第一次启动建账号时读 |
| 服务证书与私钥 | `jenkins_config_dir/tls/server.{key,crt}`，由 registry 本地 CA 就地签发（不复制 CA 私钥）；HAProxy 用的合并件 `jenkins_runtime_dir/tls/jenkins.pem`，root:10001 0640 |
| 运行配置 | `jenkins_runtime_dir/{compose.yaml,haproxy.cfg,init.groovy.d/,storage.json,check-storage.py,docker-compose}`；`init.groovy.d/` 里的脚本带 `.override` 后缀，镜像入口每次启动都把它们覆盖进 `JENKINS_HOME/init.groovy.d/`（不带后缀的同名文件已存在就不拷，改过的脚本会悄悄不生效）；脚本自己判断任务、节点、账号是否已存在，存在就只补缺的属性 |
| Jenkins 自己的数据 | `jenkins_data_dir/home`（JENKINS_HOME），容器用户 1000，0700 |
| 代理节点的接入密钥 | 控制器首启写在 `JENKINS_HOME/secrets/sunmoon/agent-host.secret`（容器用户 0600）；部署剧本（root）读它，给代理用户一份 `jenkins_runtime_dir/secrets/agent-host.secret` 0400 |
| 插件与 JRE | `jenkins_runtime_dir/ref-plugins/<名>.jpi`（容器用户，只读挂进 `ref/plugins`）、`jenkins_runtime_dir/jre/<版本>/`（`jre/current` 指向它）、`jenkins_runtime_dir/agent.jar` |
| 代理干活的仓 | `jenkins_repos_dir/{k8s,<app>-app/…}`，代理用户所有；`.build/` 里有 root 写的候选（和人的工位一样） |

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
- 内网：浏览器开 `https://jenkins.sunmoonai.com:30443/`，证书由平台 CA 签（和 Harbor 一样），用第 13 项登录。**前置**：本机 Windows 的 hosts 要有 `127.0.0.1 jenkins.sunmoonai.com`（和别的内网域名一样，用 `switch-test/windows_hosts_add.ps1` 加；2026-10-20 第一次走查就是缺这一行报 `DNS_PROBE_FINISHED_NXDOMAIN`）；剧本里的 `curl --resolve` 只验入口路由，验不了这一步。
- 边缘：从东京边缘访问同一域名得 404（0013 未列出的域名）。
- 宿主：`sudo curl --cacert /etc/sunmoon/registry/tls/ca.crt https://127.0.0.1:18443/login` 200（CA 在 root 0700 的目录里，要 sudo）；`http://127.0.0.1:18080/login` 200（代理用）；`ss -ltn` 里三个端口都只在 127.0.0.1。
- 代理：`jenkins-agent-status` 退出 0（节点在线）；`systemctl show sunmoon-jenkins-agent.service` 里 `User=` 是宿主用户、`UnitFileState=enabled`；Jenkins 页面「节点」里 `host` 在线、执行器 1。
- render-check：`jenkins-agent-check` 退出 0，结果 `SUCCESS`（或 `NOT_BUILT` 表示分支头没变），控制台日志在 `infrastructure/.build/jenkins/render-check-<n>.log`；产物 `diff.txt` 在任务页。
- 边缘：不关证书校验地验「边缘没有这个域名」：`openssl s_client -servername jenkins.sunmoonai.com -connect <边缘IP>:30443` 回的是 Traefik 的默认自签证书（主题不是 jenkins.sunmoonai.com），`curl`（不加 `-k`）退出 60。有合法证书且回 200 才算泄露。
- 有没有构建在跑（重启控制器前要看）：`build.xml` 在构建进行中就已写着 `<result>SUCCESS</result>` 占位，不能拿它判；看 `<duration>0</duration>`（进行中）加 `jobs/*/builds/*/log` 的 mtime 还在长，以及 `queue.xml` 里有没有 `BuildableItem`/`WaitingItem`。定时器每 10 分钟一发，「扫一次再停」之间有窗口，被打断的定时构建会自行恢复但那次记 FAILURE，无害（2026-10-20 回执 fable-b3 第二版）。
- release：`jenkins-release-run APPS=tpl PIN=keep` 退出 0，结果 `SUCCESS`，构建页有 `infrastructure/.build/release/<n>/` 下的产物；跑完代理仓 `git status --short --untracked-files=no` 为空。
- 控制器单元 `SuccessExitStatus=130 143`：`jenkins-stop` 后单元是 `inactive`，不再 `failed`（第 3 步改的）。
- 开机：`wsl --shutdown` 后随 `sunmoon-platform.target` 自己起来（0033 第七节第 4 条，账 104 的一部分）。
