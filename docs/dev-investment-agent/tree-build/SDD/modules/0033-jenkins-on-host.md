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

1. 宿主模块 `infrastructure/jenkins/`：控制器起来、入口路由、账号导入（不碰现网集群）。**2026-10-20 已在本地机做成**（卡 fable-b1，回执 `scripts/results/fable-b1.20261020-173741.md`、`…175616.md`）：归档 sha256 与锁一致；第 13 项预设导入；控制器 active/enabled、只绑回环；首启脚本建了管理员、关了匿名读；入口加路由后经 `jenkins.sunmoonai.com:30443` 登录页 200、Harbor 仍 200；`platform-status` 列出 Jenkins。所有者 2026-10-20 晚浏览器登录成功（「jenkins 登录进去了」）；边缘 404 核对随第 2 步的检查一起做。**第 1 步闭合。**
2. 代理单元加 `render-check`（只读），先在 render 上验代理的 sudo、命名空间、并列仓。**代码已写（2026-10-20 晚）**：`infrastructure/jenkins/agent.yaml`、`tasks/{plugins,workspace}.yaml`、单元与两份首启脚本模板、仓根 `ci/render-check.groovy`；卡 fable-b2。与原稿不同处：仓克隆放 `jenkins_data_dir/repos/`（不是 `/data/jenkins/workspace`）；render-check 不靠 push 触发（内网收不到 webhook），改定时看 origin 有没有新提交、没变就 `NOT_BUILT`；任务体放在仓里由控制器里一段短引导 `load`，控制器不需要访问 Git。**2026-10-20 夜已在本地机做成**（卡 fable-b2 → b2b → b2c → b2d → b2e 五张，回执 `scripts/results/fable-b2*.md`，前四张各停在我剧本的一处错：克隆循环项取错一层；子仓对象库要问源子仓自己的 git-common-dir；Ansible 不模板化字典键，crumb 头名带花括号被 HAProxy 400；`sh` 步默认 dash 不认 pipefail、候选路径写错）。最终 b2e（Qwen 跑）：代理 active/enabled、节点 `host` 在线；强制构建 #19 `SUCCESS` 395 秒，六应用迁移头核对与渲染全过，产物 `diff.txt` 22 行；边缘回 Traefik 默认证书、curl 退出 60（不泄露）；`platform-status` 列出两个单元。两件顺带发现：① `diff.txt` 显示渲染器已给 tpl-app 两个 ingress 生成 `/api/internal` 收敛规则，而 `gitops/` 里已提交的 tpl-app 声明没跟上（别的应用都有）——是产品线「有变化未暂存」，恢复产品线时处理，不是检查的毛病；② 代理只有一个执行器，定时构建会在 `node()` 里排队，任务已加「同时只跑一个」属性但要控制器重启才生效，与控制器单元 `SuccessExitStatus=143` 一起放第 3 步。所有者的使用说明在 [`infrastructure/jenkins/使用说明.md`](../../../../../infrastructure/jenkins/使用说明.md)。**第 2 步闭合。**
3. `release` 流水线跑到第 5 步为止（在 `sources.yaml` 副本上，不提交）。**代码已写（2026-10-20 夜）**：任务体 `ci/release.groovy`（阶段 1 核对 → 2 改钉 → 3 构建 → 4 暂存 → 5 计划，`finally` 里查已知秘密样子并打码产物、`git checkout -- gitops sources.yaml` 回到干净）、改钉脚本 `ci/pin-sources.py`（`PIN=heads`：父仓在分支的头 + 父仓记录的三个子仓 gitlink；`keep`：按已提交的钉）、首启脚本 `04-release.groovy`（任务 `release`，参数 BRANCH/APPS/PIN/NOTE，不并发，无定时器）、`make jenkins-release-run`（排一次并等结果，参数经 urlencode）；控制器单元 `SuccessExitStatus=130 143`；第 2 步留下的「同时只跑一个」随这次控制器重启生效。「副本」就是代理自己的 k8s 克隆（`jenkins_repos_dir/k8s`），不是人的工位。与第四节原稿不同处：第 2 阶段的前置核对直接用 `application-deployment-plan`（它就是 alembic 头对 `expected_schema_revision` 的核对，第 5 阶段暂存后再跑一次）；`PIN=file` 先不做，等有人要。**缺口（所有者 2026-10-20 问起）**：k8s 仓自己的三个自研镜像（relay、sandbox、sandbox-provisioner，`component-images.yaml` 钉本仓提交）走同一条 `platform-build OBJECT=…` 入口，但 `release` 只认 `APPS`，发它们仍要手跑；第 4 步定是加 `OBJECTS` 参数还是另开一个小任务。sunmoon-link 是装到用户电脑的程序，不进集群、不进流水线。**顺带观察（所有者 2026-10-20 贴的 `kubectl get pods -A`）**：`app-platform-dev` 里还跑着整套 `investment-*`（api/web/admin/worker/scheduler/runner，加 `data-platform-dev` 的 investment-redis、database，`messaging` 的 rabbitmq），是 10-15 改名前 knowbench 的旧名；`gitops/` 里已经没有任何 investment 的声明，是改名时没有带 prune 留下的孤儿工作负载，占资源与旧库。不归平台线修：产品线恢复时撤（或 D 段冷建自然消失，但旧库数据要先定去留）。卡 fable-b3（Qwen）：控制器重启、`release` 以 tpl、`PIN=keep` 试跑一遍到第 5 阶段。**2026-10-20 夜做成**（三版卡：Qwen 两版停在我的错——首启脚本挂 ref 目录要带 `.override` 才覆盖、等构建的 retries 没先转整数、`PIN=keep` 要按钉对齐检出；第三版 luna 一次过，回执 `scripts/results/fable-b3.20261020-230245.md`）：`release #2` SUCCESS 171 秒，七个阶段全进，`total=0`，归档 11 个文件与代理候选逐个 sha256 相同，结束后代理仓干净。**顺带验到第七节第 1 条「等价」的一半**：同一组钉重跑，三个镜像构建出同样的摘要（`已是这一份`），锁逐字节不变——构建从 Git 对象导出、基础镜像锁死，确实可重复；所以 `PIN=keep` 重跑是幂等的，第 4 阶段只剩模板比 tpl 已提交声明新的那两段 `/api/internal`（12 行）。我在卡里预期「3 个锁会变」是错的，DEPLOYMENT_ID 由摘要派生，不随构建次数变。**第 3 步闭合**；第 2 步留下的并发闸与单元 143 也随这步装上。
4. 全程一次，含人批（第七节第 6 条）。**代码已写（2026-10-20 深夜，按第十节）**：`ci/release.groovy` 十二个阶段全接上（5.5 无差异标 NOT_BUILT 不发；前半段一段 node，`input` 在 node 外、`submitter` 只允许所有者账号、`timeout` 按参数 `APPROVAL_TIMEOUT_MINUTES`，后半段另一段 node 先按提交号检回去；秘密样子核查在三处：前半段收尾、写回执前、后半段收尾；停在半路留 `abandoned/release-<n>` 分支）；`04-release.groovy` 三段引导、引导或参数集合变了就更新任务定义；`make jenkins-release-run` 加 `APPROVAL_TIMEOUT_MINUTES`，等待上限随之走，`NOT_BUILT` 也算过。与第十节不同处：第 11 阶段只跑 `application-check`，不跑 `platform-check`——它对应用对象是公网入口检查，边缘只放行三个域名，tpl 这类没有公网入口的应用会误判。卡 fable-b4（luna，带临时就地修授权）：控制器重启装新引导，三次跑——失败路径、超时路径、真发布 tpl 的 `/api/internal`。
5. 0010 第九节 B 段的入口收敛：删转接名，流水线改认收敛后的名字。

每步做完停下给所有者看；和 Opus 的产品线没有共用文件，唯一交叉是第 4 步要借一张真卡。

## 九、要所有者定的

1. 控制器在容器、代理在宿主这个拆法（第三节）。我建议这样拆，不建议把 sudo、nsenter、docker socket 都给一个容器。
2. 界面只开内网、第一版本地管理员、Casdoor 登录等 D 段。
3. 推送用宿主用户已有的 git 凭据，Jenkins 不存第二份。
4. `render-check` 这条只读的自动检查要不要（第四节末）。我建议要，它能在卡写出来之前就抓住迁移头这类错。

## 十、第 4 步的设计：release 的后半段与人批（2026-10-20 夜，待所有者定）

第 3 步验到：到第 5 阶段为止的前半段能跑、幂等、产物齐。第 4 步把第四节表里的第 6 到 12 阶段接上，并借一次真发布走完整条链。原则不变：每一阶段就是今天发布卡手敲的那一两条命令，流水线只按顺序敲、存证据、在第 8 阶段停下等人；D 段换 Argo 时第 7 到 10 阶段整段替换，别的不动。

### 10.1 阶段 6 到 12 落到命令

全部在代理的 k8s 克隆里（`jenkins_repos_dir/k8s`，第 1 阶段已检到 `origin/BRANCH` 的头）。提交身份固定 `sunmoon-ci <ci@sunmoonai.com>`（命令级 `-c`，不动宿主用户的全局配置），说明里带 `NOTE` 和构建号，像今天卡里的 `deploy(knowlab): …（qwen-013 一段）`。

| 阶段 | 跑什么（= 今天卡里的哪条） | 证据进产物 | 停下的条件 |
| --- | --- | --- | --- |
| 5.5 无差异就不发 | 第 5 阶段后看 `git status --porcelain -- gitops sources.yaml`；空就标 `NOT_BUILT`、说明「无差异，不发」，直接收尾 | — | 第五节「重复跑」那条 |
| 6 提交 | `git add infrastructure/applications/sources.yaml gitops && git commit -m "deploy(<APPS>): <NOTE>（release #n）"` | `6-commit.txt`（提交号、`--stat`） | — |
| 7 发布 | `make flux-release`（发布器只导出已提交对象、拒绝明文 Secret、发到 Harbor、写 `.build/flux/source-candidate.yaml`） | `7-source-candidate.yaml`（`sudo cat` 拷出来，无凭据） | 非 0 |
| 8 人批 | Jenkins `input`：摆出 NOTE、应用、`2-sources.diff`、`4-gitops.stat`、`4-workload.diff` 行数、候选 `digest` 与 `revision`、产物链接；`submitter` 只允许所有者账号；`timeout` 默认 24 小时，到时中止 | `8-approval.txt`（谁、何时） | 拒绝 → ABORTED；超时 → ABORTED |
| 9 写指针 | `sudo cat 候选 \| sudo tee environments/kind/flux-source.yaml`，`chown` 回代理用户，`git commit -m "release(kind): 晋级到 <短号>（release #n）"`，打 tag `release-<YYYYMMDD>-<当日序号>`（先 `git fetch --tags` 再数） | `9-pointer.txt`（指针内容、提交号、tag 名） | — |
| 10 部署 | `make flux-source-apply`（它自己等 OCI 源 Ready、根 kustomization Ready、generation 与摘要一致）；再 `kubectl -n flux-system wait kustomizations <app>-* --for=condition=Ready --timeout=30m` | `10-apply.log`、`10-wait.txt` | 非 0 |
| 11 检查 | 逐应用 `make application-check APP=`；`platform-check OBJECT=app-platform/<app>-app`（0033 第四节原文） | `11-check-<app>.log` | 非 0 |
| 12 推送与回执 | 流水线自己生成 `scripts/results/release-<n>.<时间>.md`（参数、改钉、镜像锁、gitops 差异、候选、批准人与时间、apply 与 check 的尾部），`git commit -m "release(kind): 回执 #n"`；`git push origin HEAD:refs/heads/<BRANCH>` 加 tag | 回执本身 | 推送非快进 → 停，提交留在代理克隆（见 10.3） |

第 10 阶段之后、第 11 之前不插人；第 11 不过就是「已部署但检查没过」，和今天手敲一样，由人看回执决定退回（退回 = 指针改回上一版再 apply，今天也是手做，这步**不进流水线**，第五节「不替代维护窗口的人工判断」）。

### 10.2 人批不能占着执行器

宿主代理只有一个执行器。`input` 要是写在 `node('host') {…}` 里面，等批的 24 小时里执行器被占着，render-check 跑不了、第二次 release 也排不进。所以引导脚本改成三段：

```groovy
def body
node('host') { dir(repos + '/k8s') { sh '更新到分支头'; body = load 'ci/release.groovy' } }
body.main(params, repos, approver)      // 在 node 外面
```

`ci/release.groovy` 自己开两段 `node('host')`：第 1 到 7 阶段一段，`input` 在两段之间（不占执行器，只占一个轻量的流水线线程），第 9 到 12 阶段另一段。两段之间代理克隆里的状态（第 6 阶段的提交、`.build/flux/` 的候选）留在盘上，第二段进来先核 `HEAD` 还是第 6 阶段那个提交、候选文件还在，才继续；期间 render-check 的定时构建照常跑（它结束时会 `git checkout -- gitops sources.yaml`，**不**会动已提交的东西，但会把 `k8s` 检到分支头——所以第二段开头要 `git checkout --detach <第 6 阶段的提交号>`，提交号存在第一段的产物里，不靠工作区）。

`approver` 从控制器配置（`jenkins_human_account.username`，今天是 `admin`）由引导传进来，任务体不写死账号。引导脚本变了要重新落盘：`04-release.groovy` 加一个分支——任务已存在但引导文本与模板不同时，只更新 `definition`，参数与人改过的别的属性不动（第 2 步「只建一次」的意思是不覆盖人的改动，不是永远不更新引导）。

### 10.3 停在半路怎么收

- 第 6 阶段之前停：和第 3 步一样，`finally` 里 `git checkout -- gitops sources.yaml`，什么都没留下。
- 第 6 阶段之后、第 12 之前停（发布失败、拒绝、超时、apply 或 check 非 0、推送非快进）：提交留在代理克隆里**不推**（第四节原文：发布器只打包已提交且晋级过的，不会被发布；但第 10 阶段之后已经 apply 了的，集群上就是新版，这时「没推」意味着 Git 上还看不到线上实际的指针——回执要把这点标红，人来补推或退回）。为了下一次构建的 `checkout --detach origin/BRANCH` 不把它丢进 reflog 深处，`finally` 里给它留一个本地分支 `abandoned/release-<n>`，并写进构建说明。
- 中止（拒绝或超时）：候选留在 Harbor（无害，账 106 的 GC 管），第 6 阶段的提交按上一条处理，集群没动。

### 10.4 要改的文件

`ci/release.groovy`（第 5.5 到 12 阶段、两段 node、`abandoned/` 分支、回执生成）、`infrastructure/jenkins/templates/04-release.groovy.j2`（三段引导、`approver`、引导变了就更新 definition、新参数 `APPROVAL_TIMEOUT_MINUTES` 默认 1440）、`jenkins-release-run` 的等待上限随审批超时走、README 与使用说明（人批那一节、退回怎么做）。宿主侧不需要新东西：push 用代理用户已有的 SSH 钥匙（第四节「Jenkins 不存第二份凭据」），`sudo` 已有。

### 10.5 怎么验（三次跑，由近到远）

1. **失败路径**（第七节第 3 条）：开一个临时分支 `fable-b4-test`，把 tpl 后端 `config.yaml` 的 `expected_schema_revision` 改旧并提交推上；`release BRANCH=fable-b4-test APPS=tpl PIN=keep`。要看到：停在第 2 阶段（`2-plan-tpl.log` 里 `Expected schema differs`），`gitops/` 干净，Harbor 没多镜像，什么都没提交。跑完删分支。
2. **人批路径**（第七节第 2 条的能验的一半）：`APPROVAL_TIMEOUT_MINUTES=2`，`APPS=tpl PIN=keep`，没人点；要看到：到第 8 阶段停、2 分钟后 ABORTED，`flux-source.yaml` 没变、现网没动、代理克隆里有 `abandoned/release-<n>` 指着第 6 阶段的提交，候选在 Harbor。「非所有者账号点不了」只有一个账号时验不了，记为按配置保证（`submitter`），等 D 段接 Casdoor 有第二个账号再验。
3. **真发布**（第七节第 6 条）：借今天已知的一处真实差异——tpl 两个 ingress 的 `/api/internal` 收敛规则（模板比 tpl 已提交的声明新，别的五个应用都已有）。`APPS=tpl PIN=keep NOTE="tpl ingress 补 /api/internal（release）"`，所有者在页面上点批。要看到：`deploy(tpl)` 与 `release(kind): 晋级到 …` 两个提交加 tag 推上 `fable`，`flux-source.yaml` 指到新候选，apply 过、`tpl-*` kustomization Ready、`application-check APP=tpl` 过、`scripts/results/release-<n>.*.md` 随推送带上；浏览器走查：`https://tpl.sunmoonai.com:30443/api/internal/x` 回 404。不碰产品线的代码，风险最小，又把一处已知漂移收掉。

### 10.5b 生产站点怎么用这条链（所有者 2026-10-20 深夜问起，C 段定）

结构同形：生产站点内网宿主上同样有 Harbor、控制器加代理、入口，集群在旁边；公网不可达。两点：① `docker build` 里的 `pip`/`npm` 要出站拉依赖（基础镜像从本地 Harbor 取，依赖走 `download-modes.json` 的源），内网宿主要么能出站到包源，要么站点内有包镜像。② 推荐**开发构建、生产只部署**：第 1 到 7 阶段在开发站点跑，镜像与声明包按摘要复制到生产 Harbor（Harbor 自带复制），生产 Jenkins 跑第 8 到 12 阶段；线上跑的和开发验过的是同一个摘要，生产宿主不需要构建工具和出站。流水线形状不变，多一个「复制到生产 Harbor」的阶段和 `SITE` 参数（第五节已预留）。

### 10.6 要所有者定的（2026-10-20 夜所有者：「按推荐」——五项都按推荐定）

1. 真发布用 tpl 的 `/api/internal` 这处（推荐），还是等产品线恢复借一张真卡。
2. 审批超时默认 24 小时；批准人就是 `admin`（第一版唯一账号）。
3. 回执由流水线生成并随推送带上（推荐），还是仍由本地助手手写。
4. tag 序号规则 `release-<YYYYMMDD>-<当日序号>`，与 10-07 到 10-09 手打的五个同形。
5. 第 11 阶段没过时流水线不退回、只标红交人（推荐；退回仍是人的维护窗口动作）。

