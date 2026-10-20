# SDD 0038：B 段第 5 步——入口收敛、docs 按内容拆、infrastructure 分层、仓改名 sunmoonun

> 地图位置：横切「交付链」的入口；文档树；仓本身。来源：0033 第八节第 5 步、0010 第九节 B 段、架构总纲第六节第 3、4、7 条。状态：**设计，待所有者定第十一节**（2026-10-21 凌晨，Fable）。B1 到 B4 已闭合，B5 是 B 段最后一步，纯整理，不碰集群里跑的东西。

## 一、要解决什么

四件事都是「名字和位置」的债，总纲定了要在 B5 一张卡里清：

| 件 | 今天的样子 | 要变成 |
| --- | --- | --- |
| A 入口收敛 | `infrastructure/Makefile` 110 个目标，其中发布链 56 个分在四个目录名下，五个是纯转接名（`application-render/stage/validate-release` → `services-render/stage/validate-release` → `components/render.yaml`），同一份剧本三个名字 | 一个剧本一个名字；`platform-*` 公开入口加每模块五个动作 |
| B docs 拆 | `docs/dev-investment-agent/` 里混着设计（tree-build 191 文件）、过程（switch-test 108、turn 21、tools 4、pipeline.md）；仓里 117 个文件 260 处引用这个路径 | `docs/design/`、`docs/process/`、新 `docs/ops/`；`project-guide/`、`总纲/` 不动 |
| C infrastructure 分层 | 13 个模块平铺，看不出哪层 | 按总纲七层分组 |
| D 仓改名 | 根仓叫 `k8s`，两台机各五个工位加 master 都叫这个名，Jenkins 代理克隆、同步脚本、测试、文档全写死 | `sunmoonun` |

## 二、A 入口收敛：做多少

0010 第九节 B 段原稿要做四样：删转接名；`applications/` 改名 `build/` 只留构建链；应用的 plan 和两份 verify 并进 `components/`；对象选择从 `host/` 挪出。**其中后三样动的目录（`applications/`、`services/`、`components/`、`flux/`）D 段整段换掉**（渲染层改 Helm/Kustomize 进 `gitops/`，Flux 换 Argo，代码地图第七节原话）。现在把 verify 合并、把选择机制搬家，是把要拆的房子先精装一遍。

**建议 B5 只做名字，不搬代码**：

| 目标 | 处置 | 理由 | 谁在用（要跟着改） |
| --- | --- | --- | --- |
| `application-render` | **删**，改调 `components-render OBJECT=app-platform/<app>-app` | 纯转接 | `ci/render-check.groovy`、jenkins README、使用说明 |
| `application-stage` | **删**，用 `platform-stage OBJECT=…`（它本来就是公开入口，发布卡和流水线用的都是它） | 纯转接 | 无活的调用者 |
| `application-validate-release` | **删**，改调 `components-validate-release OBJECT=…` | 纯转接 | 无活的调用者 |
| `services-render` / `services-stage` / `services-validate-release` | **改名** `components-render` / `components-stage` / `components-validate-release` | 剧本在 `components/`，名字叫 services 是历史 | `platform-stage-selected`、`application-bootstrap`、`services-bootstrap`、README |
| `services-plan/materials/verify-materials/publish` 与 `application-plan/materials/verify-materials/publish` | **留**（实施时改的判断，2026-10-21）：两家都调 `artifacts/publish.yaml`，但变量集不同（平台组件按 `SERVICE_IMAGES` 选镜像，应用按 `application_base_image_ids` 加容量操作名），不是转接名而是同一剧本的两种参数化；合成一个名字要加选择变量、改两处编排，D 段随 `applications/` 一起处理 | — | — |
| `topology-render/stage/validate` | **改名** `components-topology-render/stage/validate`？——不，保留：`topology` 是独立对象，名字清楚 | — | — |
| `platform-*`（14）、模块五动作（registry/entry/jenkins/jenkins-agent/cluster/edge/flux）、`application-deployment-plan`、`application-check(-public)`、`application-source-plan`、`application-build-*/publish-*/lock-*`、`component-*`、`flux-release/source-apply/source-status`、`secrets-*`、物料与工具那几个 | **留** | 真入口，流水线、卡、README 都认这些名 | — |
| `*-bootstrap`（flux/foundations/services/application）、`jenkins-materials` | **留**（它们是编排用的复合目标，不是转接） | — | — |
| `help` | 重写：按层列公开入口 | 现在只列一半 | — |

净效果：110 → 约 100 个目标，三个名字指同一剧本的情况消失，`services-*` 只剩真正属于 `services/` 的（tools、chart、credentials、check、ragflow 两个）。`applications/` 改名 `build/`、两份 verify 合并、选择机制搬家**写进 D 段的设计**，那时和渲染层一起动。

另一个选项是按 0010 原稿全做（估两三天，含两份 verify 567+ 行的合并和回归），D 段再推翻。不建议。

## 三、B docs 按内容拆

### 3.1 去向

| 现在 | 去 | 说明 |
| --- | --- | --- |
| `docs/design/` 整个（PRD、SDD、rules、decisions、structure-ledger、pending-after-migration、平台代码地图、暂停时的状态、knowbot-todolist、owner-decisions-now、platform-kind-v1-review） | `docs/design/` | 总纲第 3 条：整体搬，不在搬的时候重组内部 |
| `docs/process/pipeline.md`、`turn/`、`switch-test/`、`tools/` | `docs/process/` 同名 | 过程：怎么开工、怎么交接、卡与回执、门禁工具 |
| `docs/ops/jenkins-使用说明.md` | `docs/ops/jenkins-使用说明.md` | 第一份运维说明；模块 README 留给维护者 |
| `docs/process/rename-2026-10-15/README.md`、`rename-receipts/`、`rename-tools/` | `docs/process/rename-2026-10-15/` | 10-15 改名那次的手册、回执、工具，是过去的过程 |
| `docs/reference/行业/专家市场架构对比分析和借鉴.md`、`docs/reference/行业/竞品比较分析.md` | `docs/reference/行业/` | 行业与竞品研究，和 reference 里现有分类一致 |
| `docs/project-guide/账号-电脑-link-会合点.md` | `docs/project-guide/` | 所有者说是给人看懂的解释页，放第一次进项目的人读的那组 |
| `docs/project-guide/`、`docs/总纲/`、`docs/reference/`、`docs/README.md` | 不动 | — |

搬完 `docs/dev-investment-agent/` 为空，删掉。`docs/README.md`「先读这三页」「按任务进入」改路径。

### 3.2 引用怎么改

260 处引用分三类：

| 类 | 处置 |
| --- | --- |
| 活文档里的链接（docs、infrastructure 下 14 个 README、`AGENTS.md`、`README.md`、`CLAUDE.md`） | 工具改：写 `docs/process/tools/relocate-links.py`，输入「旧前缀 → 新前缀」表，对每个 markdown 重算相对链接（被搬的文件浅了一层，`../../../../../scripts/results/` 这类要重算），改完跑 doc-gate、anchor-gate 和一个新的「相对链接都能解析」检查 |
| 门禁与钩子（`.githooks/pre-commit`、`pre-merge-commit`、`tools/doc-gate.py` 的 `DOC_ROOT`、`anchor-gate.py` 的 `DOCS`、`scripts/test_switch_test_sync.py`、`switch-test/*.sh` 里的路径） | 手改，同一提交 |
| `scripts/results/` 下 33 份历史回执里的链接 | **不改**。results 只增不改是规矩，回执是当时的记录；链接失效可以接受，README 记一句「2026-10-21 之前的回执里 `docs/dev-investment-agent/…` 读作 `docs/design/` 或 `docs/process/`」 |

### 3.3 牵连到活的流程

- `inbox/` 的路径变了：卡的第一步从 `docs/process/switch-test/inbox/<名>/` 变 `docs/process/switch-test/inbox/<名>/`。搬的那张卡本身要写清楚，之后的卡用新路径；本地助手的习惯要改一次。
- 所有者的 `~/switch-test` 转发脚本 `exec` 的是仓里 `human-local.sh` 的绝对路径（含 `k8s/docs/process/switch-test`），要重装一次转发（`human-local.sh` 自带装转发的分支）。
- Opus 的产品线页（总览第 3、6 节、tree-build 下它的卡与账）**路径跟着搬、内容不动**，恢复时它看到的是新位置；在 `暂停时的状态.md` 顶上加一行指路。

### 3.4 停点 2 做成（2026-10-21）

按 3.1 的表搬完（`git mv` 386 条，含 `dev-investment-agent/README.md` → `process/README.md` 并重写为过程索引；新建 `ops/README.md`）。链接由 `docs/process/tools/relocate-links.py` 重算：140 个文件、231 条相对链接、180 处直写路径；`check-links.py` 搬前搬后都是 16 处坏链、同一批；修掉 4 条会卡钩子的之后剩 12 条——luna 核对（卡 b5-2）后更正分布：9 条在 `done/` 里的历史卡（当初移进 `done/` 时就断），2 条在 `docs/reference/技术笔记/Flower使用文档.md`（指向已删的 `sunmoonai/` 树，参考资料，留着），1 条在 `infrastructure/services/README.md`（`layout.yaml` 早搬去了 `components/`，已改指过去）。都在搬之前就有。手改的：`doc-gate.py` 的 `DOC_ROOT` 与入口正则、`anchor-gate.py` 的 `DOCS`（都改成 design/process/ops/project-guide 四个根）、`.githooks/pre-commit` 注释、`tools/README.md`、`project-guide` 三页里链接的显示文字、`turn/README.md` 一句、`.cursor/rules/sunmoonai-architecture.mdc`、`docs/README.md`（Jenkins 一行改成已验 release，新加「找设计、过程、运维说明」一行并写明旧回执路径怎么读）、`暂停时的状态.md` 顶上给 Opus 的指路、总纲第五节两处标「已做」；`done/` 里两条会卡住提交钩子的坏链顺手修正（指向 0033 与同目录的 qwen-012 卡）。不改的：`scripts/results/`、`rename-2026-10-15/` 里的原文、0028/decisions 里的历史叙述。`scripts/test_switch_test_sync.py` 3 个失败在搬之前就有（远程在搬前的 HEAD 上验过），与本步无关。本地助手要知道：**收件箱现在在 `docs/process/switch-test/inbox/<名>/`**，卡里的拉取、回执、`git mv` 路径都按新的写；`human-local.sh` 装的转发要重装一次。

## 四、C infrastructure 按层分组：建议只写对照、不搬目录

13 个模块按总纲的层：

| 层 | 模块 |
| --- | --- |
| 1 物料 | `artifacts/`、`tools/` |
| 2 站点 | `environments/`（站点参数）、`edge/`（公网边缘） |
| 3 宿主 | `host/`（盘、开机、账号、对象选择）、`registry/`、`entry/`、`jenkins/` |
| 4 集群 | `cluster/` |
| 5 平台（集群内共享）与交付链的平台侧 | `flux/`、`services/`、`components/` |
| 6 应用（部署面） | `applications/` |

真搬成 `infrastructure/{materials,site,host,cluster,platform,apps}/…` 要改：Makefile 里全部 `-i host/inventory.yaml <模块>/x.yaml` 路径、CONFIG_FILES、每个剧本里 `playbook_dir + "/../<模块>/…"` 的相对引用（`artifacts/files.lock.json`、`../.build`、应用仓的 `../../../<app>-app`）、生命周期模板、Jenkins 代理里的路径、十几份 README。而第 5 层三个目录 D 段就没了，`applications/` D 段改名。**建议 B5 把这张对照表写进 `infrastructure/README.md` 顶上（每个模块 README 加一行「所在层」），目录到 D 段和渲染层一起搬**——那时要搬的少一半，而且是必须重写的时候。

### 4.1 停点 3 做成（2026-10-21）

`infrastructure/README.md` 顶上加了「模块 → 所在层 → 管什么」对照表（13 个模块；`flux/`、`services/`、`components/` 标「暂住，D 段挪」，`applications/` 标「D 段改名 build/」，`host/` 里的对象选择标「交付链的事，D 段随渲染层搬」），每个模块 README 标题下加一行「所在层」，`environments/` 补了 README。目录一个没搬。停点 1 由 luna 在真机验过（卡 fable-b5-1：23 个公开入口通、6 个旧名无、render-check #43 用 `components-render` 跑到 SUCCESS）；停点 2、3 的变基推送后，由卡 fable-b5-2 验新路径与所有者的转发器。

## 五、D 仓改名 k8s → sunmoonun

### 5.1 仓里要改的（代码提交，先做）

| 在哪 | 改什么 |
| --- | --- |
| `infrastructure/jenkins/agent.yaml` | `jenkins_repos` 的第一项 `"k8s"` → 新变量 `jenkins_root_repo`（`config.yaml` 里 `sunmoonun`），`workspace.yaml`、两份 groovy 引导的 `dir('…/k8s')`、`ci/release.groovy` 的 `"${reposDir}/k8s"` 都改读这个名（引导由模板带入，任务体从 `env` 或参数取） |
| `docs/process/switch-test/human-local.sh`、`human-remote.sh`、`align_workstations.sh`、`scripts/test_switch_test_sync.py` | 仓名常量 |
| 活文档里的 `~/worktrees/<ws>/k8s`、`/mnt/sunmoon-data/jenkins/repos/k8s` | 改；历史回执不改 |
| `AGENTS.md`、`README.md`、总纲 | 仓名 |

**5.1 已做（2026-10-21，所有者「先把仓内准备做了」）**：`jenkins_root_repo`（config.yaml，今天 `k8s`）进了 `agent.yaml`、`workspace.yaml`、两份引导、`ci/release.groovy`（`main` 多一个 `rootRepo` 参数，引导传入）；三个同步脚本和 `scripts/test_switch_test_sync.py` 改读 `ROOT_REPO`（默认 `k8s`）。改名那天：`jenkins_root_repo: sunmoonun`、三处 `ROOT_REPO` 默认值、活文档里的 `~/worktrees/<ws>/k8s` 与 `repos/k8s`，一笔提交。

**仓内那一笔也做了（2026-10-21，所有者「现在就可改仓名，不过我让 qwen 改」）**：`jenkins_root_repo: sunmoonun`、三个脚本与测试的默认值、`release.groovy` 的默认参数、17 份活文档里的路径（`worktrees/<ws>/k8s`、`master/k8s`、`repos/k8s`、`sunmoonlion/k8s`），`project-guide/repos/k8s.md` 改名 `sunmoonun.md`。历史文档与回执不改。机器侧：远程 Fable 自己做，**本地机由 Qwen 做**（卡 fable-b5-4，代替 luna；luna 的 b5-2 并入该卡）。

### 5.2 两台机器上要做的（一次坐下来做完，所有者在场）

顺序固定，先远程后本地，每步可回退（改回去就是）：

1. **GitHub、Gitee 改仓名**（所有者在网页上点）。两站都保留旧名重定向，一段时间内旧地址还能用，所以第 2 到 4 步的时间窗里不会断。
2. **远程机**（Fable 自己做）：停下所有写操作；`~/master/k8s` → `~/master/sunmoonun`；五个 `~/worktrees/<ws>/k8s` → `…/sunmoonun`；在主仓 `git worktree repair` 加各工作树的 `.git` 文件指回；`git remote set-url` 换新地址（GitHub、Gitee 两个 push 地址）；`git status`、`git fetch` 验。
3. **本地机**（luna 按卡做，卡头带就地修授权）：同样的目录改名与 `worktree repair`；Jenkins：`jenkins-agent-stop` → 代理克隆 `/mnt/sunmoon-data/jenkins/repos/k8s` 改名 `sunmoonun`（连 `k8s@tmp` 删掉）→ `jenkins-agent-deploy`（按新 `jenkins_root_repo` 核对、装工具）→ 控制器 `jenkins-stop`/`jenkins-deploy`（两份引导的目录变了）→ `jenkins-agent-start` → `jenkins-agent-check` 跑一次 render-check 到 SUCCESS；所有者的 `~/switch-test` 转发重装。
4. 其它工位的助手（Opus 在 qwen 工位、luna 自己的 luna 工位）下次开工前告知：目录名变了，分支不变。

**5.2 做成（2026-10-21 凌晨）**：所有者 `gh repo rename` 改 GitHub、用 Gitee 接口改 Gitee；远程机 Fable 自己做（主仓 `set-url`、六个目录、`worktree repair`、独立 `gitee` 远程一并改）；本地机 Qwen 按卡做（回执 `scripts/results/fable-b5-4.20261021-0226.md`）：七节全过，六目录改名、十处 gitdir 修好、代理克隆改名、控制器与代理重装、两份任务配置里都是 `repos/sunmoonun`、render-check #51 在新路径 SUCCESS 423 秒、转发器重写。实施时的三处「怎么执行」：GitHub 核验与拉取改走 SSH（本机 https 到 GitHub 握手被掐），工位与代理克隆的 `origin` 都设 SSH，推送地址「GitHub SSH 在前、Gitee https 在后」（代理准备按第二个设 `mirror`）。**遗留两处（都在仓外）**：本地机主仓独立的 `gitee` 远程仍指 `k8s.git`（Gitee 旧路径有重定向，先能用）；所有者自己的 `~/five-repos-sync/config.sh` 第 20 行 `REPOS` 里还是 `"k8s"`，要改成 `"sunmoonun"`。工作树内部名 `.git/worktrees/k8s1` 之类不改，无影响。**停点 4 闭合，B5 闭合。**

### 5.3 不变的

应用仓的名字和路径（`<app>-app/`）不变；`sunmoon-link` 不变；分支名不变；`infrastructure/`、`gitops/` 内部相对路径不变（构建链找应用仓是 `../../../<app>-app`，与根仓名无关）。

### 2.1 停点 1 做成（2026-10-21）

改了：Makefile（删 3 个转接名；`services-render/stage/validate-release` → `components-render/stage/validate-release`，调用处 `platform-stage-selected`、`platform-deploy-selected`、`services-bootstrap`、`application-bootstrap` 跟改；`help` 按层重写；要 APP 的目标清单去掉删的三个）、`ci/render-check.groovy`（改调 `components-render OBJECT=`）、`03-render-check.groovy.j2`（引导文本变了就更新任务定义，和 04 一样）、`deploy.yaml` 的提示语、19 份活文档里的名字（services/applications/components/jenkins README、kibana ui README、13 份应用组件 README、运行拓扑、代码地图）。远程验过：23 个公开入口 `make -n` 全通，6 个旧名 `No rule`，`make help` 可读。历史回执、CHECKPOINT、0010/0033 设计原文里的旧名不改。`capacity_operation: services-render` 这类容量操作标签不改（它们是容量例外表的键，不是入口）。顺带发现 `applications/tests/test_build_selection.py` 在改之前就有 15 个失败（它假定每个应用只带自己的 config，而 `CONFIG_FILES` 早已含六个应用的全部 config）——与本步无关，记给 D 段随 `applications/` 处理。

## 六、顺序与停点

总纲说「一张卡」，指的是**一次整理期、不夹别的活**；实际分四个停点，前三个是仓里的提交、第四个要两台机器和网页：

| 停点 | 内容 | 谁做 | 验 |
| --- | --- | --- | --- |
| 1 入口收敛 | 第二节的改名与删除、`help`、`ci/render-check.groovy` 改调新名、README | Fable 改，luna 跑 | `make -n` 全部公开目标；`platform-status`；`jenkins-agent-check`（render-check 走新名）SUCCESS |
| 2 docs 拆 | 第三节；门禁与钩子；`relocate-links.py` 与链接检查 | Fable 改，luna 跑门禁 | doc-gate、anchor-gate、链接检查全过；`human-local.sh` 转发重装后能用 |
| 3 分层对照 | 第四节的表与每模块一行 | Fable | 读 |
| 4 仓改名 | 第五节 | 所有者点网页，Fable 远程，luna 本地 | 两机 `git status`/`fetch` 干净；render-check SUCCESS；一次 `release` 无差异跑到 NOT_BUILT（证明代理路径全通） |

停点 1 到 3 可以连着做；停点 4 单独约时间。每个停点后所有者看一眼再往下。

## 七、风险

- 链接改坏：靠工具加检查，不靠手；搬之前先跑一遍检查记下基线，搬之后同样为零新增失效。
- 改名窗口里有人推送：第 5.2 步开始前所有工位推干净，期间不写；重定向保证旧地址仍通。
- Jenkins 代理克隆路径写死在首启脚本里：控制器要重装一次（`.override` 已验，会生效）。
- 两份 Jenkins 任务配置里旧路径残留：引导文本变了 `04` 会自更新，`03` 也加同样的自更新分支（现在只在建任务时写一次）。
- 历史回执链接失效：接受，README 记一句。

## 八、要改的文件（估）

Makefile（约 40 行）、`ci/render-check.groovy`（1 行）、`03-render-check.groovy.j2`（自更新分支）、jenkins `config.yaml`/`agent.yaml`/`workspace.yaml`/两份引导（根仓名变量）、`.githooks/` 两份、`tools/` 两个门禁加两个新脚本、`AGENTS.md`、`README.md`、`docs/README.md`、`infrastructure/README.md` 加 13 个模块 README 各一行、`human-local.sh` 等三个脚本、`scripts/test_switch_test_sync.py`；`git mv` 约 330 个文件；链接改写约 230 处（不含历史回执）。

## 九、怎么验（汇总）

1. `make -C infrastructure help` 列出的每个名字 `make -n` 都能展开；被删的名字 `make -n` 报「No rule」。
2. render-check 用新名跑到 SUCCESS；`release` 无差异跑到 NOT_BUILT。
3. 门禁三项为零：doc-gate、anchor-gate、链接检查（新写，纳入 pre-commit）。
4. 改名后两台机器五个工位 `git status` 干净、`git fetch` 成功、`git worktree list` 路径全对。
5. 所有者在浏览器照使用说明走一遍 Jenkins（说明搬到 `docs/ops/` 之后链接仍通）。

## 十、不做

不改 `gitops/` 一个字；不动集群；不改分支名；不改应用仓；不改 `environments/` 的站点参数（那是 C 段）；不合并两份 verify、不搬对象选择、不改 `applications/` 目录名（D 段）。

## 十一、要所有者定的

1. 入口收敛按第二节「只做名字」（推荐），还是按 0010 原稿全做。
2. infrastructure 分组按第四节「先写对照、目录 D 段搬」（推荐），还是现在就搬目录。
3. 第 3.1 节几处零散文件的去向（两份研究进 `reference/行业/`，会合点说明进 `project-guide/`，10-15 改名资料进 `process/rename-2026-10-15/`）。
4. 历史回执里的链接不改（推荐）。
5. 仓改名约在哪天做：要所有者在网页上点两次，再有一两个小时两台机器都不写。
