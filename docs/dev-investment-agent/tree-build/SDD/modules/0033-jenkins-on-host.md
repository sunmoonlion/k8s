# 宿主上的 Jenkins：把发布卡变成流水线（0033，B 段）

> 状态：**B 段进行中**。2026-10-20 所有者「可以开始 B」；第八节第 1 步的代码已写（`infrastructure/jenkins/`，卡 `switch-test/inbox/luna/2026-10-20-fable-b1-jenkins-controller.md`（本地机由 luna 跑，所有者 2026-10-20）），第九节四条按本页建议做、所有者事后确认。两处落地时与原稿不同：数据目录用数据盘整盘挂载点下的 `/mnt/sunmoon-data/jenkins`，不另加 `/data/jenkins` 的 bind（同一块盘，少一个挂载单元）；TLS 由随附的已锁 HAProxy 镜像终止，证书由 registry 的本地 CA 就地签发，Jenkins 自己只听回环 HTTP。原起草说明：2026-10-18 远程 Fable 起草，所有者当天「那你先把 Jenkins 那一页设计写出来」。依据：决定记录 2026-10-06「CI 用 Jenkins、CD 在冷建时换 Argo CD」「晋级时打 Git tag」、2026-10-12「发布攒批」；CHECKPOINT 主线 B；[`总纲/运行拓扑.md`](../../../../总纲/运行拓扑.md) 第二部分（原 `发布链.md`，2026-10-20 合并进来）；0010 第九节。**不动代码**，审定后再排实现。只写一页：做什么、放哪、怎么跑、不做什么、怎么验。

## 一、要解决什么

现在一次发布是一张卡（如 `switch-test/done/2026-10-18-qwen-006-small-release.md`），Qwen 在本地机上逐段敲：核对 → 改钉 → 构建 → 暂存 → 计划 → 提交 → 发布 → 晋级 → 部署 → 检查 → 推送。每张卡都是同一串 `make` 目标，变的只有钉到哪几个提交。人敲的毛病这两张卡都出过：qwen-006 漏了迁移头，停在暂存才发现；zsh 没有 `PIPESTATUS`，退出码要绕着写；回执靠手抄。

Jenkins 要做的只有一件事：**把这串固定的 `make` 目标按固定顺序跑，每一步的退出码、日志、产物自动留下；晋级那一步停下来等人批。** 它不渲染、不部署、不管密文，这些仍是 `infrastructure/` 里的程序。

## 二、边界

| 是 | 不是 |
| --- | --- |
| 宿主上的一个容器（控制器）加宿主上的一个代理进程 | 不进集群，没有 Kaniko，不和 Flux、以后的 Argo 抢活 |
| 只调 `make -C infrastructure platform-*`、`flux-release`、`flux-source-apply`、`application-check` 这些现成入口 | 不写第二条发布逻辑；入口改名（0010 第九节 B 段收敛）随它一起做，流水线只认收敛后的名字 |
| 手动触发，带参数（分支、哪几个应用、钉法、说明） | 不在每次 push 时自动发布：10-12 定的攒批不变 |
| 晋级前 `input` 停下，只有所有者的账号能批 | 不自动晋级，不自动部署现网 |
| 晋级后自动打 `release-<YYYYMMDD>-<序号>` tag（10-06 定） | 不自己造版本号 |
| Jenkins 里不存任何平台秘密 | 私有输入照旧只在宿主 `services_config_dir` 的 0600 文件里 |

## 三、放哪：控制器在容器里，干活的代理在宿主上

决定记录写的是「放宿主、容器、能用 Docker 和 Harbor」。落到细处要拆成两半，原因是准备任务对宿主的要求太多：

| 发布链要用的 | 在容器里要什么 |
| --- | --- |
| `prepare.yaml`：建节点目录、改 sysctl、读写 0600 私有文件、签 TLS | 非交互 sudo、宿主文件系统 |
| 数据盘 bind 只在 PID 1 的挂载命名空间里（10-06 待办 19），Makefile 会自动 `nsenter` | 对 PID 1 的 `nsenter` 权限，等于 root |
| 构建镜像、推 Harbor | docker socket |
| `flux-source-apply`、检查 | kubeconfig |
| 构建从 k8s 旁边并列的 `<app>-app/<子仓>` 导出源码（`applications/build.yaml` 第 64 行） | 七个仓并列的工作区 |

把这些都塞进一个容器，就是一个拿着宿主 root 的容器，比现在更差。所以：

- **控制器**：官方 Jenkins LTS 镜像，走物料锁（和 Harbor 一样，`artifacts/` 下载校验、skopeo 发布到宿主 Harbor，不从公网直拉）；Compose 加 systemd 单元 `sunmoon-jenkins.service`，并入 `sunmoon-platform.target` 用 `Wants=`（10-06 `Requires=` 连带停机那次的教训）；数据目录 `/data/jenkins`，和 `/data/harbor` 一样是数据盘上的 bind；只绑回环 `127.0.0.1:<端口>`。它只做界面、任务定义、历史、审批、产物。
- **代理**：一个 inbound agent（JNLP 走回环连控制器），作为今天跑发布卡的那个宿主用户，由 systemd 单元 `sunmoon-jenkins-agent.service` 带起，所以天然在 PID 1 的命名空间里，`nsenter` 都省了。sudo、docker、kubeconfig、私有文件都是这个用户今天已有的，不新给任何权限。工作区在 `/data/jenkins/workspace/`，里面自己 clone 一份 k8s 和六个应用仓并列，**不碰 `~/worktrees/*`**（五个工位是人的，CI 不进去 checkout）。
- **界面怎么到**：宿主入口 HAProxy（`entry_cluster_routes`）加一条 SNI 路由 `jenkins.sunmoonai.com` → 回环端口，内网用 30443 访问；**边缘不加这个域名**（0013：边缘只转 knowbench、casdoor、relay，未列出的 404），Jenkins 从公网不可达。
- **账号**：第一版本地管理员，口令按密码表的 Jenkins 项走 `platform-account-*` 导入（CHECKPOINT「Jenkins 待组件接入」就是这一项）；Casdoor 单点登录等 D 段一起接，不单独做。

`infrastructure/jenkins/` 做成和 `registry/`、`entry/` 同形的宿主模块：`config.yaml`（版本、端口、目录）、`materials.yaml`、模板、`README.md`；Make 入口 `jenkins-plan / jenkins-deploy / jenkins-start / jenkins-stop / jenkins-status`。流水线定义 `Jenkinsfile` 放 k8s 仓根，跟着分支走。

## 四、流水线就是发布卡

一条主流水线 `release`，参数四个：`BRANCH`（k8s 和应用仓都用这个分支）、`APPS`（哪几个应用）、`PIN`（`heads` = 钉到各应用父仓在该分支的头，或 `file` = 用一份改钉清单）、`NOTE`（一句话，进提交说明和回执）。阶段和卡的小节一一对应：

| 阶段 | 跑什么 | 停下的条件 |
| --- | --- | --- |
| 1 核对 | 拉 `BRANCH`，`platform-status`，工作区干净 | 集群不在、工作区脏 |
| 2 改钉 | 按 `PIN` 改 `sources.yaml`；**新加一条前置核对**：钉到的后端的 alembic 头和该应用 `config.yaml` 的 `expected_schema_revision` 对得上 | 对不上就停在这里，不进构建（qwen-006 那一次会在这停） |
| 3 构建 | 每个应用 `platform-build OBJECT=app-platform/<app>-app` | 任一非 0 |
| 4 暂存 | `platform-stage OBJECT=…`；把 `git diff --stat gitops` 和剔掉摘要后的工作负载差异存成产物 | 任一非 0 |
| 5 计划 | `application-deployment-plan APP=…` | 任一非 0 |
| 6 提交 | `git commit`（作者 `sunmoon-ci`，说明带 `NOTE` 和构建号） | — |
| 7 发布 | `flux-release`，`source-candidate.yaml` 存成产物 | 非 0 |
| **8 晋级：人批** | `input`：页面上摆出候选的声明摘要、Git 修订、第 4 步的差异产物；只有所有者账号可点；24 小时没人批就中止（候选留在 Harbor，无害） | 拒绝或超时 |
| 9 写指针 | 写 `flux-source.yaml`，提交 `release(kind): 晋级到 …`，打 `release-<日期>-<序号>` tag | — |
| 10 部署 | `flux-source-apply` | 非 0 |
| 11 检查 | 每个应用 `application-check APP=…`；`platform-check` 选中对象 | 非 0 |
| 12 推送与回执 | `git push origin BRANCH` 连 tag；生成回执 `scripts/results/release-<构建号>.<时间>.md`（和今天 Qwen 的回执同一格式），随推送带上 | — |

任何一步停下，**`gitops/` 工作区回到干净**（第 6 步之前用 `git checkout -- gitops sources.yaml`，第 6 步之后已经是提交，留着给人看，不会被发布：发布器只打包已提交且晋级过的）。浏览器走查（卡的第五节）仍是人做，不进流水线。

第二条流水线 `render-check`，可选：push 到任一工位分支时只跑 `application-render APP=…`（改到的应用）和第 2 阶段那条迁移头核对，不暂存、不碰 Harbor，几分钟出结果。这是攒批之外唯一的自动动作，只读。

推送凭据：代理用宿主用户今天已有的 git 凭据推，Jenkins 不存第二份。

## 五、和现有规矩怎么对上

- **人的分工**：卡还是 Opus 写，但卡从「命令清单」变成「参数加走查清单」；Qwen 不再敲发布链，只做走查的集群侧核对。回执仍进 `scripts/results/`，只增不改。
- **秘密**：日志里不能出现口令、令牌、age 私钥。`make` 目标今天就不打印它们；流水线层再加一道 `grep` 已知模式，命中就把该次构建标红并打码产物。
- **分支**：流水线在哪个分支触发就提交到哪个分支，不碰 master；合到 master 仍按所有者指令由人做。
- **重复跑**：同样的钉、同样的源码，构建出同样的镜像摘要（构建本来就是从 Git 对象导出的），第二次跑到第 4 步会显示「无差异」并停在第 6 步前，不空发。
- **C 段**：加参数 `SITE`（默认 `kind`），别的不变。**D 段**：第 7 到 10 步换成 Argo 的对应动作（晋级 = 钉 Git 提交号），1 到 6 步原样保留。这就是为什么流水线只认 `platform-*` 入口、不认内部剧本名。

## 六、不做

不进集群、不装 Kaniko、不做 push 即发布、不在 Jenkins 里存平台秘密、不开公网、不做 Casdoor 登录（D 段）、不管 Harbor 保留与 GC（账 106 另做）、不替代维护窗口的人工判断。

## 七、怎么验

1. **等价**：同一组钉，流水线跑一遍、手跑一遍，`image.lock` 里的镜像摘要和 `gitops/` 差异逐字节相同。
2. **审批关**：一个非所有者账号点不了第 8 步；超时中止后 `flux-source.yaml` 没变、现网没动。
3. **失败路径**：故意把一个应用的 `expected_schema_revision` 写旧，流水线停在第 2 步，`gitops/` 干净，Harbor 没多镜像。
4. **开机恢复**：`wsl --shutdown` 后控制器和代理随 `sunmoon-platform.target` 自己起来，队列里的构建不丢（账 104 的一部分）。
5. **边界**：从东京边缘访问 `jenkins.sunmoonai.com` 得 404；内网 30443 能开；日志全文 `grep` 不到已知秘密模式。
6. **第一次真发布**：qwen 线下一张小卡用流水线发，所有者在第 8 步点批，走查照旧。过了，之后的卡都走它。

## 八、顺序

1. 宿主模块 `infrastructure/jenkins/`：控制器起来、入口路由、账号导入（不碰现网集群）。**代码已写（2026-10-20），等 luna 跑卡 fable-b1。**
2. 代理单元加 `render-check`（只读），先在 render 上验代理的 sudo、命名空间、并列仓。
3. `release` 流水线跑到第 5 步为止（在 `sources.yaml` 副本上，不提交）。
4. 全程一次，含人批（第七节第 6 条）。
5. 0010 第九节 B 段的入口收敛：删转接名，流水线改认收敛后的名字。

每步做完停下给所有者看；和 Opus 的产品线没有共用文件，唯一交叉是第 4 步要借一张真卡。

## 九、要所有者定的

1. 控制器在容器、代理在宿主这个拆法（第三节）。我建议这样拆，不建议把 sudo、nsenter、docker socket 都给一个容器。
2. 界面只开内网、第一版本地管理员、Casdoor 登录等 D 段。
3. 推送用宿主用户已有的 git 凭据，Jenkins 不存第二份。
4. `render-check` 这条只读的自动检查要不要（第四节末）。我建议要，它能在卡写出来之前就抓住迁移头这类错。
