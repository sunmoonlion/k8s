# SunMoonAI 项目总览

> 最后更新：2026-10-15 ｜ 按新体系（架构 C：公网边缘 + 内网站点 + 本地代理，网页是产品界面）全文重写，取代 2026-09-22 的旧体系版本。
>
> **本文件是进入这个项目的入口。**读完它，你应当知道：这个产品是什么、改动落在哪个仓、东西跑在哪里、怎么发布、去哪里查更细的。
> 细节都在指路的文档里；本文不写易腐的值（提交号、镜像摘要、迁移头、版本号、副本数）。与代码冲突时**永远以代码为准**，并请指出本文件需要更新。
>
> 改名进行中（2026-10-14 起，见 [`k8s/docs/rename.md`](../../../docs/rename.md)）：`info-app` → `knowfeed-app`、`knowledge-app` → `knowbase-app`、`advisor-app` → `knowmart-app`。仓与代码已是新名字；本机集群在改名 R5 晋级之后才换成新名字，在那之前跑的仍是 `info-*`、`knowledge-*`。

---

## 1. 这个项目是什么

**投研专家。**用户已经能用 AI 助手（Codex）做很多事；我们存在的理由是在裸 AI 做不好的地方做好。"做好"靠三样捆在一起：**专业知识**（数据、口径、引用，经 MCP 给 Codex）、**方法**（专家包：怎么拆步、每步给什么料、何时停下问人、做对没有）、**评测闭环**（金标准、分段判定、改动回归）。**不做投资咨询**：产出是研究底稿，结论由用户填。

一句话：**用户在网页里用自己的 Codex 做研究；做不好时请专家驾驶同一个 Codex，把可验收的底稿交回，结果就在用户的工作区里。循环在我们的沙箱，工具在用户机器，界面是网页，公网只有薄边缘。**

| 前提（定了不再讨论） | 意思 |
| --- | --- |
| 两层决策权，同一个 Codex 实例 | 第一层用户自驾；第二层专家（顾问）按方法驾驶同一个 thread、同一个工作区、同一个模型账户；方向盘显式交接 |
| 不垫付 token（BYOK） | 用户的模型 key 加密存在工作台，只进他自己的沙箱 |
| 工作区在本地 | 用户的文件在他的电脑上；本地代理只让沙箱读写他加进白名单的目录 |
| 循环在云、执行在本机 | Codex app-server 跑在我们内网的每用户沙箱里，exec-server 跑在用户电脑上 |
| 界面是网页 | 只装一个小的本地代理，不做桌面应用 |
| 边缘 + 内网 | 公网只有无状态的薄边缘；业务在内网，深处只出站 |

需求的真源是 [需求](../dev-investment-agent/tree-build/PRD/requirement.md)；用户看得见的三个应用见 [`PRD/apps/`](../dev-investment-agent/tree-build/PRD/apps/README.md)；一次求助的九站见 [流水线](../dev-investment-agent/pipeline.md)。

**现在有什么**（2026-10-15）：网页里的聊天、工作、专家三种对话与项目；每用户一个沙箱、会合点、供给器；Windows 本地代理（经网页一行命令安装、配对）；专家包 `DATA_QUERY`（问数）、`FIN_REVIEW`（财报体检）、`FIN_FORECAST`（财务预测），按版本上架；knowfeed 的证券采集（巨潮、东方财富）与申请审批；knowbase 的数据集登记、语义层与 MCP 工具；公网边缘已上线三个域名。**还没有**：knowmart（专家市场，只有设计 [0018](../dev-investment-agent/tree-build/SDD/modules/0018-advisor-market.md)）、评测三道门的自动化、机器外备份。

## 2. 仓

**平台各仓必须并列放置**（部署与构建按同级相对路径互相引用）。四个应用父仓各用 gitlink 引三个组件子仓，所以 Git 仓不止这几个：推送**子仓先、父仓后**；一个工作树可能出现「父仓在、子仓未初始化」。

| 仓 | 职责 | 子仓 |
| --- | --- | --- |
| `tpl-app` | 模板：一个标准应用长什么样，其余应用由它实例化；公共缺陷先修模板再同步实例 | 后端、网页、管理端 |
| [`knowfeed-app`](repos/knowfeed-app.md) | 采集：从公开来源取原件、建数据集、质量检查、向 knowbase 登记；采集申请与审批 | 同上 |
| [`knowbase-app`](repos/knowbase-app.md) | 知识：数据集目录、口径、语义层，经 MCP 给 Codex；文档入库与检索（RAGFlow）；两套跨仓契约的提供方 | 同上 |
| `investment-app` | 产品主应用：网页、工作台后端（会话、方向盘、专家包、账、验收、交付）、给沙箱的投资记录 MCP、本地代理安装包的发放 | 同上 |
| `knowmart-app` | 专家市场（未建，0018 设计；由 tpl-app 实例化） | — |
| `k8s` | 部署：宿主、仓库、入口、建群、Flux、全部平台组件与应用的部署声明；本文档也在此 | 无业务源码 |
| `runtime` | 本地代理 `sunmoon-agent`（Node，装在用户电脑；将改名 `agent`） | 不参与集群部署，不要求并列 |

工位与同步：主目录 `~/master/<仓>`，工位 `~/worktrees/<工位>/<仓>`（`mb` 管理，见 `toolboxes` 里的 `model-switch`）；两台机器之间只经 Git origin 往来，所有者用 `~/switch-test/human-local.sh` / `human-remote.sh` 同步（转发到 k8s 仓里的同名脚本）。

## 3. 东西跑在哪里

### 3.1 正式拓扑（所有者 2026-09-26 定，开发期与服务用户都这样）

两条不变量：**深处只出站**（内网与用户电脑只发起连接），**边缘无状态**（任一台可替换）。

```text
用户电脑                公网边缘（云 VM，无状态）            内网站点（只出站）
──────────              ──────────────────────              ────────────────────────────────
浏览器 ──https 443──▶   Traefik（TLS、证书）──▶ frps  ◀──隧道（frpc 主动连出）── frpc ─▶ 内网 Traefik ─▶ 应用、Casdoor
本地代理 ─wss 443──▶    会合点 relay  ◀──wss 出站──────────────────────────── 沙箱 Pod（每用户一个）
                                       ◀──wss 出站（管理通道）──────────────── investment runner
                                                                               供给器 ─▶ Kubernetes API（建/删沙箱）
                                                                               沙箱 ─MCP─▶ investment-api、knowbase-api
                                                                               沙箱 ─https 出站─▶ 模型厂商
```

### 3.2 现网（2026-10-15）

- **内网站点 = 所有者机器的 WSL**：宿主上的 Harbor 与入口 HAProxy（`30443`，只看 SNI 分流、不解密），一个三节点 KIND 集群 `sunmoon-kind`，数据盘挂在 `/mnt/sunmoon-data`。集群里跑全部平台组件与四个应用、会合点（暂在集群里）、供给器与沙箱。
- **公网边缘 = 东京云 VM**（远程助手所在的机器）：Traefik + frps，2026-10-10 上线。对公网只放三个域名：`investment`、`casdoor`、`relay.sunmoonai.com`，经 frp 隧道回到集群。其余域名（knowfeed、knowbase、各管理端、Harbor）只在所有者机器上经 hosts 访问。要再暴露域名：DNS、`infrastructure/edge/config.yaml` 的 `edge_domains` 与 `gitops/components/ingress-platform/frpc/config.yaml` 的 `frpc_domains`（两份名单相同）、边缘重新部署、frpc 发布。
- 集群里的后端**不按公网名互连**：访问 Casdoor、会合点、供给器一律走集群内 Service（`*_BACKCHANNEL_ENDPOINT` 等）；公网名只出现在交给浏览器与本地代理的地址里。

拓扑的图、各组件管什么、一次「工作」的顺序：[`k8s/docs/拓扑.md`](../../../docs/拓扑.md)；裁定与风险：[拓扑设计](../dev-investment-agent/tree-build/SDD/architecture/topology.md)；边缘：[0013](../dev-investment-agent/tree-build/SDD/modules/0013-edge.md) 与 `k8s/infrastructure/edge/`。

## 4. 三个应用与数据怎么流

| 应用 | 用户来做什么 | 管理员来做什么 |
| --- | --- | --- |
| investment | 聊天、让代理干活、请专家；管工作区与项目 | 「缺数据的需求」（链去 knowfeed 管理端发起采集）、研究运行时 |
| knowbase | 看有哪些公司的数据、数据到哪一天、口径怎么算 | 数据集版本、登记、工具调用情况 |
| knowfeed | 申请「我要这家公司的数据」、看进度 | 批准申请、发起采集、看批次、关注清单 |

```text
公开网站 ──采集──▶ knowfeed ──原件、数据集文件──▶ 对象存储（knowfeed 的桶）
                      │ 登记「有一个新版本」（服务身份 knowbase:ingest）
                      ▼
                  knowbase ──按登记的位置只读取文件 ──▶ 语义层 / RAGFlow 索引（可重建的派生物）
                      │ MCP 工具（sunmoon_knowbase）
                      ▼
沙箱里的 Codex ◀── 方向盘在用户或专家手里 ──── investment runner（工作台管理者）
                      │ 事件
                      ▼
                investment 的页面
```

| 规则 | 说明 |
| --- | --- |
| 一件事只在一个应用里办 | 别的应用要用，就用普通链接把人带过去（新标签页，带业务参数、`from`、`ref`），不各做一份 |
| Codex 不直接连 knowfeed | 只经 knowbase 的工具拿数据；没过质量检查的数据 knowfeed 不登记，knowbase 就没有 |
| 每个结果带出处 | 数据集、版本、数据时点 |
| 跨应用只经版本化 HTTP 契约 | **禁止跨应用直接读写对方的库、桶、Redis 键**；契约的 schema 真源在提供方，锁文件在调用方（[契约](topics/contracts.md)） |
| 每步只写自己的库 | 跨应用不用分布式事务；投递走 Outbox/Inbox，消费方幂等；broker ACK 不等于业务提交 |

investment 内部：三种对话（聊天、工作、专家，[0017](../dev-investment-agent/tree-build/SDD/modules/0017-three-kinds-of-conversation.md)）；工作区 = 本地代理里加的白名单目录，项目是其下子目录（[0024](../dev-investment-agent/tree-build/SDD/modules/0024-new-project.md)）；后端进程 `runner`（工作台管理者，将改名 `manager`）连沙箱、下指令、收事件、算费用、管项目与专家流程；专家包按版本上架，新委托绑定委托当时上架的版本；本地代理的安装包经 investment 的 `agent-releases` 发放。设计按块在 [`SDD/modules/`](../dev-investment-agent/tree-build/SDD/modules/)。

## 5. 一个标准应用长什么样

四个应用父仓拓扑相同（由模板规定）；领域目录、路由、迁移、依赖各不相同，是受控的扩展点（判据见 [`repos/tpl-app.md`](repos/tpl-app.md)）。

```text
<名>-app/
├── <名>-backend/          FastAPI，Admin / Web / Internal 三面共用一个工程
├── <名>-admin-frontend/   Next.js 管理端
└── <名>-web-frontend/     Next.js 网页端
```

- **后端一个不可变镜像，多个运行角色**：API（Deployment + Service）、Worker（Celery）、Scheduler（Celery beat，单副本）、Migration（一次性 Job）；investment 另有 `runner`。各角色有独立 ServiceAccount、数据库与 broker 身份。入口在 `app/bootstrap/`。
- **分层**：`domain/`、`application/`（服务、DTO、Port）、`infrastructure/`（ORM、外部适配、Celery、存储）、`interfaces/`（`http/` 是模板面，`endpoints/` 是领域面）；`application` 不得 import `interfaces`。
- **前端**：Next.js 16 + React 19 + Tailwind v4 + shadcn + next-intl，`output: 'standalone'`，源码在内层 `app/`；路由边界是 `proxy.ts`；请求只走同源 `/api/`；会话经 server-only 的 `BACKEND_INTERNAL_URL` 读；**OIDC 全在后端，token 不进浏览器存储**；网页的预览模式用录下来的样例回放（`preview/fixtures/`）。

## 6. 部署（`k8s` 仓）

单机 WSL 里的 KIND 是第一期；同一套组件声明以后用于云端建群。Make 是公开入口，Ansible 编排，Flux 拥有集群声明；不另设 CLI 或部署状态机。职责与约束见 [`docs/platform-kind-v1/architecture.md`](../../../docs/platform-kind-v1/architecture.md)，实际验证过的范围见 [`verification.md`](../../../docs/platform-kind-v1/verification.md)，日常导航见 `infrastructure/README.md`。

| 目录 | 管什么 |
| --- | --- |
| `infrastructure/host`、`registry`、`entry`、`cluster`、`flux` | 宿主（WSL、挂盘、容量、开机恢复）、Harbor、入口 HAProxy、KIND 建群、Flux 与发布源 |
| `infrastructure/services`、`applications`、`components` | 平台组件、四个应用、组件阶段图的 Make / Ansible 入口；`applications/sources.yaml` 钉各应用父仓与子仓的提交，`component-images.yaml` 钉自研镜像（会合点、沙箱、供给器）的源码提交 |
| `infrastructure/edge` | 公网边缘（只在边缘机上跑） |
| `infrastructure/artifacts`、`environments` | 物料与镜像锁；环境（`site.yaml` 的命名空间、根路径，`flux-source.yaml` 的已晋级源） |
| `gitops/components/<平台>/…` | 组件声明：每个组件目录里 `config.yaml`、`stage.yaml`、`README.md` 是真源，`workload.yaml`、`kustomization.yaml`、`*.sops.yaml`、`image.lock.yaml` 是生成的 |
| `gitops/clusters/kind` | 集群根：阶段图 `stages.yaml`（由各组件 `stage.yaml` 汇总生成） |

| 平台目录 | 装什么 | 命名空间 |
| --- | --- | --- |
| `app-platform` | `auth-app/casdoor`；四个应用；`common/`（应用共用的部署机制，不经 tpl 转接） | `app-platform-dev` |
| `data-platform` | PostgreSQL、Redis / Valkey、对象存储、RAGFlow（+ Infinity、text-embeddings）、ELK、Neo4j、MongoDB；应用的建库 Job | `data-platform-dev` |
| `messaging-platform` | RabbitMQ 与应用的 vhost 初始化 | `messaging-platform-dev` |
| `ingress-platform` | 内网 Traefik（TLS 终止、按 Host 路由；**不做授权**）、frpc | `ingress-platform-dev` |
| `ops-platform` | pgAdmin、RedisInsight、Flower、Mongo Express | `ops-platform-dev` |
| `relay-platform` / `sandbox-platform` | 会合点 / 供给器与沙箱镜像 | `relay-platform-dev` / `sandbox-platform-dev` |
| `foundations` | 跨命名空间的基础对象（网络策略、拉取凭据、存储） | — |

**发布链**（一张发布卡的标准动作，样板见 `switch-test/done/` 里的卡）：

```text
改 sources.yaml / component-images.yaml 的钉
  → make platform-build OBJECT=…        构建镜像推 Harbor，改写 image.lock
  → make platform-stage OBJECT=…        渲染声明、按私有目录里的输入生成 SOPS 密文（有副作用：可能建私有目录、远端数据集）
  → make application-deployment-plan    核迁移头、Job 代次
  → git commit                           固定 Git 对象
  → make flux-release                    打成不可变 OCI 候选推 Harbor
  → 晋级：改 environments/kind/flux-source.yaml 并提交
  → make flux-source-apply / flux-source-status
  → make application-check APP=…
```

要点：秘密在宿主私有目录里主备两份、逐字节一致，已有身份丢失就停、不重新生成；Flux 根与各阶段都是 **`prune: false`**，删掉的声明不会自动删集群对象（要精确退役）；完成的 Job 由 Flux 持有，内容不可改，改了要换代次；回退 = 把 `flux-source.yaml` 退回已验证的源再 apply，数据库 schema 与持久数据不随 Git 回退。

**`k8s/sunmoonai/`** 是 2026-10-06 起冻结的旧体系，计划整体移出（[改名手册「冻结解除之后」](../../../docs/rename.md#冻结解除之后不属于改名但要有人做)）；其中还活着的只有 `docs/dev-investment-agent/`（手册、派活卡、回执、同步脚本、门禁工具）、`docs/project-guide/`（本文档集）、`relay-platform/` 与 `sandbox-platform/`（自研镜像源码）、`scripts/` 里的联调脚本与发布卡回执。

## 7. 身份

**两类身份，互不通用**：浏览器会话不能用于服务间调用，服务令牌不构成用户身份。身份提供方是 Casdoor（`auth-app`）。

| 类别 | 机制 |
| --- | --- |
| 浏览器 | Casdoor OIDC（授权码 + PKCE）→ 后端会话 cookie。每个应用的 Admin 与 Web 是两个独立的安全边界：各有 client、回调、cookie 名、会话命名空间、Origin 策略 |
| 作用域 | 「应用名:动作」：Admin 必须有 `<名>:admin`（如 `knowfeed:admin`），Web 不要求作用域；管理端只收 built-in 组织的令牌，网页端只收配置的用户组织（0014 U2） |
| 服务间 | client credentials，按关系各一个身份与组织：knowfeed → knowbase `knowbase:ingest`，investment → knowbase `knowbase:retrieve`；接收方核 audience、主体绑定表、作用域 |
| 沙箱 | investment 给每个沙箱签发短期令牌：调投资记录 MCP 与 knowbase MCP；模型 key 只在沙箱进程环境里 |
| 本地代理 | 网页里一行命令安装与配对；连会合点用 investment 签发、会合点就地验签的令牌 |

细节：[身份](topics/identity.md)（部分仍是旧体系的写法，以代码为准）；组织与入口把关：[0014](../dev-investment-agent/tree-build/SDD/modules/0014-user-organization.md)。

## 8. 规则来自哪里

| 层 | 在哪 | 违反后果 |
| --- | --- | --- |
| 动代码前必读的规则 `C-*` | [`rules/constraints.md`](../dev-investment-agent/tree-build/rules/constraints.md) | 方案不进入讨论 |
| 不变量 `I1`–`I14` | [`SDD/architecture/invariants.md`](../dev-investment-agent/tree-build/SDD/architecture/invariants.md) | 同上 |
| 结构不变量测试 | 各后端 `app/tests/test_kernel_invariants.py` | 测试失败 |
| 启动期配置校验 | 各后端 `core/config.py` | **进程起不来**，不降级运行 |
| 部署准备的断言 | 各组件 `prepare.yaml`（名字、作用域、路径、身份按应用名拼出并核对） | stage 失败 |
| 人的批准点 | [`turn/approvals.md`](../dev-investment-agent/turn/approvals.md) | 不能自动通过 |

## 9. 动手前必知的红线

| 红线 | 违反会怎样 |
| --- | --- |
| 跨应用直接读写对方的库、桶、Redis 键 | 破坏领域所有权，没有门禁能救 |
| 用可变 tag 代替固定摘要部署 | 发布链拒收；部署只认 `image.lock` 里的摘要 |
| 手改渲染产物（`workload.yaml`、`*.sops.yaml`、`image.lock.yaml`） | 下一次 stage 覆盖或校验失败；改真源再 stage |
| 契约 schema 在调用方另建副本 | 第二真源；升级必须提供方先改、两端测试过后才动锁 |
| 先改实例再改模板 | 公共缺陷必须先修 tpl-app 再同步实例 |
| 迁移链分叉或与测试里的清单不一致 | 测试失败 |
| 重新生成已有身份、清私有目录、为清状态删 PVC 或 force apply | 身份与数据对不上，可能不可恢复 |
| 集群内组件按公网名互连 | 公网解析一变就连错；要连就加 backchannel 变量 |
| 把评测、验收、批准写成「系统会自动」 | 不得假设还不存在的自动化（[流水线](../dev-investment-agent/pipeline.md)） |
| 秘密进日志、回执、Git | 口令、令牌、私钥只在私有目录与 SOPS 里 |

描述能力状态用四个递进的词：**defined**（schema、表、Port 在）→ **wired**（有生产调用方）→ **deployable**（配置与门禁允许部署）→ **runtime-verified**（有对应环境、版本、场景的运行证据）。「文件存在」只到 defined。

## 10. 去哪查

| 我要… | 读 |
| --- | --- |
| 知道这个产品要什么 | [需求](../dev-investment-agent/tree-build/PRD/requirement.md)、[`PRD/apps/`](../dev-investment-agent/tree-build/PRD/apps/README.md)、[待定决策](../dev-investment-agent/tree-build/decisions.md) |
| 知道某块怎么设计 | [`SDD/architecture/`](../dev-investment-agent/tree-build/SDD/architecture/README.md)、[`SDD/modules/`](../dev-investment-agent/tree-build/SDD/modules/) |
| 动代码前必读的规则 | [`rules/constraints.md`](../dev-investment-agent/tree-build/rules/constraints.md) |
| 一次求助 / 一次委托怎么走 | [流水线](../dev-investment-agent/pipeline.md)、[`turn/`](../dev-investment-agent/turn/README.md) |
| 拓扑、谁连谁 | [`k8s/docs/拓扑.md`](../../../docs/拓扑.md) |
| 部署、发版、某个组件怎么维护 | `k8s/infrastructure/README.md`、各组件目录的 `README.md`、[平台架构](../../../docs/platform-kind-v1/architecture.md)、[验收边界](../../../docs/platform-kind-v1/verification.md) |
| 派活卡、回执、两台机器怎么同步 | `../dev-investment-agent/switch-test/`（`inbox/`、`done/`、`human-*.sh`） |
| 改某个仓的代码 | [`repos/`](repos/) 对应文件（部分仍是旧体系的写法，以代码为准） |
| 跨应用契约、数据、身份 | [`topics/`](topics/) 对应文件（同上） |
| 改名进行到哪 | [`k8s/docs/rename.md`](../../../docs/rename.md) |
| 查当前钉的提交 / 镜像摘要 / 已晋级的源 | `infrastructure/applications/sources.yaml`、各组件 `image.lock.yaml`、`infrastructure/environments/kind/flux-source.yaml` |
| 查集群里实际跑的 | `export KUBECONFIG=~/.kube/sunmoon-kind.config; kubectl -n app-platform-dev get deploy -o wide`（所有者机器） |
| 复核本文的某条断言 | **读代码**，别的都不算数 |

## 两种修改语义

| 目录 | 语义 | 怎么改 |
| --- | --- | --- |
| 本文、`repos/`、`topics/` | **现状投影** | 覆盖式重写：直接替换旧条文，只写当前有效的事实；历史由 Git 承担 |
| `governance.md` | **规则** | 改动前要有共识；改完检查依赖它的文档 |
| `tree-build/decisions.md` 等决定记录 | **记录** | 只追加；所有者的原话保持原样 |

## 已知缺口

- `repos/`、`topics/`、`governance.md` 还有旧体系（`k8s/sunmoonai/` 下的平台目录、`bundle/` 与 `deploy.py` 发布链）的写法，待按本文重写。
- 公网边缘只暴露三个域名；knowfeed、knowbase 与各管理端只在所有者机器上可用。
- 单机 KIND：数据主备同在一块物理盘，机器外备份未落地；真实 KIND 删除重建、DNS 与系统证书信任等仍在 [验收边界](../../../docs/platform-kind-v1/verification.md#未完成项) 的未完成项里。
- knowmart（专家市场）只有设计；评测的自动化门未接。
