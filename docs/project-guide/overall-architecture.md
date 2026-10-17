# SunMoonAI 项目总览

> 最后更新：2026-10-16 ｜ 按当日所有者的定位（knowlab、分身、knowmart 私有模式）与改名完成、`k8s/sunmoonai/` 移出后的现状重写。
>
> **本文件是进入这个项目的入口。**读完它，你应当知道：这个产品是什么、改动落在哪个仓、东西跑在哪里、怎么发布、去哪里查更细的。细节都在指路的文档里；本文不写易腐的值（提交号、镜像摘要、迁移头、版本号、副本数）。与代码冲突时**永远以代码为准**，并请指出本文件需要更新。

---

## 1. 这个项目是什么

**把用户自己的研究方法做成他自己的分身。**用户带来一个想法（最好是一份 skill）和自己的数据；我们在 **knowlab** 里把它工程化、测试好，交付成一个**分身**（英文 knowbot）；分身存在 **knowmart** 里属于他的位置；用户在 **knowbench 工作台**里「请」自己的分身，用自己的数据跑。

| 前提（定了不再讨论） | 意思 |
| --- | --- |
| 我们创建，用户使用 | 创建（工程化与测试）是我们的价值；使用是用户自己在工作台里跑，不由我们替他跑出结果再交给他 |
| 投资逻辑与数据都是用户的 | 平台不带自己的投资逻辑、不给自己的数据；工程测试可以用我们的数据，结果不交给用户；验收只用用户的数据（约束 `C-L1`–`C-L5`） |
| 分身只归用户自己 | 只能请自己的分身，一个人可以有多个；不得导出、分享、出售；knowmart 现在是私有模式，后端强制按所有者过滤 |
| 不垫付 token（BYOK） | 用户的模型 key 加密存在工作台，只进他自己的沙箱 |
| 循环在云、执行在本机 | Codex app-server 跑在内网的每用户沙箱里；要碰用户本机文件时，exec-server 跑在用户电脑上的**本地代理**（英文 sunmoon-link）里 |
| 界面是网页，边缘 + 内网 | 只装一个小的本地代理，不做桌面应用；公网只有无状态的薄边缘，业务在内网，深处只出站 |

为什么这样定：规避证券投资咨询类监管——平台不向用户提供自己的投资分析或建议（[0026](../dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)「五、合规分析」，对外收费前取得书面法律意见）。knowmart 对外开放（有资格的开发者把分身上架给别人用）是**持牌以后**的下一步。

需求的真源是 [需求](../dev-investment-agent/tree-build/PRD/requirement.md)；做到哪了、每一站谁做见 [流水线](../dev-investment-agent/pipeline.md)；所有者的决定见 [决策](../dev-investment-agent/tree-build/decisions.md)。

**现在有什么**（2026-10-16）：knowbench 工作台（聊天、工作、「专家」三种对话与项目——「专家」将改叫「分身」；每用户一个沙箱、会合点、供给器；Windows 本地代理经网页一行命令安装配对）；knowfeed 采集、knowbase 数据集与语义层（经 MCP 给沙箱）；我们作为第一个普通用户在做的分身「中国A股上市公司财务分析与预测」（[0023](../dev-investment-agent/tree-build/SDD/modules/0023-fin-forecast.md)）。**还没上线**：knowlab-app、knowmart-app 已建成空应用并部署；分身的创建、存放与「请」代码写了大半，未部署（[分身](topics/knowbot.md)）。

## 2. 仓

**平台各仓必须并列放置**（部署与构建按同级相对路径互相引用）。应用父仓各用 gitlink 引三个组件子仓：推送**子仓先、父仓后**；一个子仓的提交要被父仓记下才算进了那个应用的版本。

| 仓 | 职责 | 说明 |
| --- | --- | --- |
| [`tpl-app`](repos/tpl-app.md) | 模板：一个标准应用长什么样，其余应用由它实例化；公共缺陷先修模板再同步实例 | 三个子仓：后端、网页、管理端 |
| [`knowfeed-app`](repos/knowfeed-app.md) | 采集：从公开来源取原件、建数据集、质量检查、向 knowbase 登记 | 同上 |
| [`knowbase-app`](repos/knowbase-app.md) | 加工入库：数据集目录、口径、语义层，经 MCP 给沙箱；文档入库与检索（RAGFlow） | 同上 |
| [`knowbench-app`](repos/knowbench-app.md) | 工作台：网页、工作台后端（对话、项目、分身运行、账、验收、交付）、给沙箱的记录 MCP、本地代理安装包的发放 | 同上 |
| `knowlab-app` | 创建分身：受理、工程化、测试、交付（[0026](../dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)、[0027](../dev-investment-agent/tree-build/SDD/modules/0027-knowbot-first-path.md)） | 由 tpl-app 实例化；三个子仓 |
| `knowmart-app` | 存放分身与「请」（先做私有模式，[0018](../dev-investment-agent/tree-build/SDD/modules/0018-advisor-market.md)、[0027](../dev-investment-agent/tree-build/SDD/modules/0027-knowbot-first-path.md)） | 由 tpl-app 实例化；三个子仓 |
| [`k8s`](repos/k8s.md) | 部署与项目文档：宿主、仓库、入口、建群、Flux、全部平台组件与应用的部署声明；本目录也在此 | 无业务源码（自研的会合点、沙箱、供给器源码除外） |
| [`sunmoon-link`](repos/sunmoon-link.md) | 本地代理（英文 sunmoon-link，命令现在还叫 `sunmoon-agent`，下次发 Windows 版时改），装在用户电脑上 | 不参与集群部署 |

工位与同步：主目录 `~/master/<仓>`，工位 `~/worktrees/<工位>/<仓>`（`mb` 管理）；两台机器（远程机写、本地机跑）之间只经 Git origin 往来，所有者用 `~/switch-test/human-local.sh`、`human-remote.sh` 同步；派活卡与回执在 [`switch-test/`](../dev-investment-agent/switch-test/README.md)。

## 3. 东西跑在哪里

### 3.1 正式拓扑（所有者 2026-09-26 定，开发期与服务用户都这样）

两条不变量：**深处只出站**（内网与用户电脑只发起连接），**边缘无状态**（任一台可替换）。

```text
用户电脑                公网边缘（云 VM，无状态）            内网站点（只出站）
──────────              ──────────────────────              ────────────────────────────────
浏览器 ──https 443──▶   Traefik（TLS、证书）──▶ frps  ◀──隧道（frpc 主动连出）── frpc ─▶ 内网 Traefik ─▶ 应用、Casdoor
本地代理 ─wss 443──▶    会合点 relay  ◀──wss 出站──────────────────────────── 沙箱 Pod（每用户一个）
                                       ◀──wss 出站（管理通道）──────────────── knowbench 工作台管理者
                                                                               供给器 ─▶ Kubernetes API（建/删沙箱）
                                                                               沙箱 ─MCP─▶ knowbench-api、knowbase-api
                                                                               沙箱 ─https 出站─▶ 模型厂商
```

### 3.2 现网

- **内网站点 = 所有者机器的 WSL**：宿主上的 Harbor 与入口 HAProxy（`30443`，只看 SNI 分流、不解密），一个三节点 KIND 集群 `sunmoon-kind`，数据盘挂在 `/mnt/sunmoon-data`。
- **公网边缘 = 东京云 VM**：Traefik + frps，对公网只放 `knowbench`、`casdoor`、`relay.sunmoonai.com`；knowfeed、knowbase 与各管理端只在所有者机器上可用。
- 集群里的后端**不按公网名互连**：访问 Casdoor、会合点、供给器一律走集群内 Service（`*_BACKCHANNEL_ENDPOINT` 等）；公网名只出现在交给浏览器与本地代理的地址里。

拓扑的图与一次「工作」的顺序：[`k8s/docs/拓扑.md`](../拓扑.md)；裁定与风险：[拓扑设计](../dev-investment-agent/tree-build/SDD/architecture/topology.md)。

## 4. 应用与数据怎么流

两条线：**数据线**（knowfeed → knowbase，我们自己的数据）与**分身线**（knowlab → knowmart → 运行方，用户的方法与数据）。分身线上的分身运行时**不接**数据线的数据（`C-L2`）。分身线的架构见[分身](topics/knowbot.md)：knowlab、knowmart 已建成空应用，分身相关代码已写一部分、未部署。

```text
数据线                                             分身线
公开网站 ──采集──▶ knowfeed                        用户：想法 / skill ＋ 自己的数据
                    │ 登记新版本（服务身份 knowbase:ingest）      │
                    ▼                               knowlab（创建草稿 → 管理端核出处、调运行方测试）
                 knowbase ── 语义层 / RAGFlow 索引           │ 测试通过才交付
                    │（内部工具；以后 knowmart 的数据线）   knowmart（私有：只有本人看得见，只放能用的版本）
                    ▼                                       │ 请（跳过去选、跳回）
                 （现在仍经 MCP sunmoon_knowbase 接进沙箱，  运行方（现在是 knowbench 工作台）：用户请自己的分身，自己跑
                   工作台对用户开放前改为默认不接，0026）
```

| 应用 | 用户来做什么 | 管理员来做什么 |
| --- | --- | --- |
| knowbench | 聊天、让代理干活、请自己的分身；管工作区与项目 | 「缺数据的需求」（链去 knowfeed 管理端发起采集）、研究运行时 |
| knowbase | 看有哪些数据、数据到哪一天、口径怎么算 | 数据集版本、登记、工具调用情况 |
| knowfeed | （网页端没有功能页） | 批准申请、发起采集、看批次、关注清单 |

管理端的业务页按应用角色 `admin`/`operator` 显示，现行部署没配角色白名单，admin 只看得到「治理控制台」「设置」（[待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 98）。

| 规则 | 说明 |
| --- | --- |
| 一件事只在一个应用里办 | 别的应用要用，就用普通链接把人带过去（新标签页，带业务参数、`from`、`ref`），不各做一份 |
| 跨应用只经版本化 HTTP 契约 | **禁止跨应用直接读写对方的库、桶、Redis 键**；契约的 schema 真源在提供方，锁文件在调用方（[契约](topics/contracts.md)） |
| 每步只写自己的库 | 跨应用不用分布式事务；投递走 Outbox/Inbox，消费方幂等 |
| 新数据先定归属 | 新增数据实体先答五问（`C-D12`）；原始证据先存再处理、不覆盖（`C-D13`）（[数据](topics/data.md)） |

knowbench 内部：三种对话（[0017](../dev-investment-agent/tree-build/SDD/modules/0017-three-kinds-of-conversation.md)）；工作区 = 本地代理里加的白名单目录；底稿与结果放右边栏。

## 5. 一个标准应用长什么样

应用父仓拓扑相同（由模板规定）；领域目录、路由、迁移、依赖各不相同，是受控的扩展点（[`repos/tpl-app.md`](repos/tpl-app.md)）。

```text
<名>-app/
├── <名>-backend/          FastAPI，Admin / Web / Internal 三面共用一个工程
├── <名>-admin-frontend/   Next.js 管理端
└── <名>-web-frontend/     Next.js 网页端
```

- **后端一个不可变镜像，多个运行角色**：API、Worker（Celery）、Scheduler（Celery beat，单副本）、Migration（一次性 Job）；knowbench 另有工作台管理者（代码里叫 runner）。
- **分层**：`domain/`、`application/`（服务、DTO、Port）、`infrastructure/`（ORM、外部适配、Celery、存储）、`interfaces/`（`http/` 是模板面，`endpoints/` 是领域面）；结构不变量在 `app/tests/test_kernel_invariants.py`。
- **前端**：Next.js + React + Tailwind + shadcn + next-intl，`output: 'standalone'`，源码在内层 `app/`；请求只走同源 `/api/`；会话由后端的 cookie 承载。
- 各仓还留着旧体系的部署材料（应用父仓的 `dev-to-prod-deploy/`、后端的 `db-provisioner/` 与 `*-access-bootstrap/`、tpl-app 的 `k8s-deployment/`）：**现行部署不用它们**，部署只在 `k8s` 仓。

## 6. 部署与发布（`k8s` 仓）

单机 WSL 里的 KIND 是第一期；同一套组件声明以后用于云端建群。Make 是公开入口，Ansible 编排，Flux 拥有集群声明。部署相关的规矩（入口与编排、配置归属、分层、镜像来源、升级、操作副作用、清理）在 [`constraints.md`](../dev-investment-agent/tree-build/rules/constraints.md)「发布」`C-R*`，还没做完的平台目标在 [待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 104–109，目录见 [`repos/k8s.md`](repos/k8s.md)。

**发布链**（一张发布卡的标准动作，样板见 `switch-test/done/` 里的卡）：

```text
改 infrastructure/applications/sources.yaml（应用）或 component-images.yaml（会合点、沙箱、供给器）的钉
  → make platform-build OBJECT=…        构建镜像推 Harbor，改写 image.lock
  → make platform-stage OBJECT=…        渲染声明、按私有目录里的输入生成 SOPS 密文（有副作用）
  → make application-deployment-plan    核迁移头、Job 代次
  → git commit                           固定 Git 对象
  → make flux-release                    打成不可变 OCI 候选推 Harbor
  → 晋级：改 environments/kind/flux-source.yaml 并提交
  → make flux-source-apply / flux-source-status
  → make application-check APP=…
```

现在由人照发布卡跑；后期改由流水线触发，约束不变。要点：秘密在宿主私有目录里主备两份、逐字节一致，已有身份丢失就停、不重新生成；Flux 根与各阶段都是 **`prune: false`**，删掉的声明不会自动删集群对象，下线旧对象要专门清理（样板：改名时的清理工具，Git 历史 `3951246c:docs/rename-tools/r6_cleanup.py`）。组件 prepare 的先后顺序有一个已知隐患，修好前别跑 `platform-stage OBJECT=all`（[待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 97）。

## 7. 身份

**两类身份，互不通用**：浏览器会话不能用于服务间调用，服务令牌不构成用户身份。身份提供方是 Casdoor（`auth-app`）。

| 类别 | 机制 |
| --- | --- |
| 浏览器 | Casdoor OIDC 授权码 → 后端会话 cookie。每个应用的 Admin 与 Web 是两个独立边界：各有 client、回调、cookie、会话命名空间、Origin |
| 组织 | 管理端只收 `built-in` 组织的令牌（admin 只用于 Casdoor 和管理后台）；网页端只收 `sunmoonai` 组织（所有者日常用自己的 sunmoonai 账号，[0014](../dev-investment-agent/tree-build/SDD/modules/0014-user-organization.md)） |
| 服务间 | client credentials，按关系各一个身份：knowfeed → knowbase `knowbase:ingest`，knowbench → knowbase `knowbase:retrieve`；接收方核 audience 与主体绑定表。分身线的新关系（`knowmart:deliver`、`knowmart:summon`、`knowbench:testrun`）走通用机制 `common/backend/service-client`，已写未部署（[分身](topics/knowbot.md) §4） |
| 沙箱 | knowbench 给每个沙箱签发短期令牌：调记录 MCP 与 knowbase MCP；模型 key 只在沙箱进程环境里 |
| 本地代理 | 网页里一行命令安装与配对；连会合点用 knowbench 签发、会合点就地验签的短期令牌，可吊销 |

## 8. 规则来自哪里

| 层 | 在哪 | 违反后果 |
| --- | --- | --- |
| 动代码前必读的规则 `C-*`（含合规 `C-L*`） | [`rules/constraints.md`](../dev-investment-agent/tree-build/rules/constraints.md) | 方案不进入讨论 |
| 不变量 `I1`–`I14` | [`SDD/architecture/invariants.md`](../dev-investment-agent/tree-build/SDD/architecture/invariants.md) | 同上 |
| 结构不变量测试 | 各后端 `app/tests/test_kernel_invariants.py` | 测试失败 |
| 启动期配置校验 | 各后端 `core/config.py` | **进程起不来**，不降级运行 |
| 部署准备的断言 | 各组件 `prepare.yaml` | stage 失败 |
| 文档门禁 | `docs/dev-investment-agent/tools/doc-gate.py`、`anchor-gate.py`（钩子 `.githooks/`） | 提交被拒 |
| 人的批准点 | [`turn/approvals.md`](../dev-investment-agent/turn/approvals.md) | 不能自动通过 |

## 9. 动手前必知的红线

| 红线 | 违反会怎样 |
| --- | --- |
| 平台带自己的投资逻辑、给用户自己的数据、评价投资效果、让分身流出给别人 | 碰监管（`C-L1`–`C-L5`） |
| 跨应用直接读写对方的库、桶、Redis 键 | 破坏领域所有权，没有门禁能救 |
| 用可变 tag 代替固定摘要部署 | 发布链拒收；部署只认 `image.lock` 里的摘要 |
| 手改渲染产物（`workload.yaml`、`*.sops.yaml`、`image.lock.yaml`） | 下一次 stage 覆盖或校验失败；改真源再 stage |
| 契约 schema 在调用方另建副本 | 第二真源；升级必须提供方先改、两端测试过后才动锁 |
| 先改实例再改模板 | 公共缺陷必须先修 tpl-app 再同步实例 |
| 重新生成已有身份、清私有目录、为清状态删 PVC 或 force apply | 身份与数据对不上，可能不可恢复 |
| 集群内组件按公网名互连 | 公网解析一变就连错；要连就加 backchannel 变量 |
| 把评测、验收、批准写成「系统会自动」 | 不得假设还不存在的自动化（[流水线](../dev-investment-agent/pipeline.md)） |
| 秘密进日志、回执、Git | 口令、令牌、私钥只在私有目录与 SOPS 里 |
| 把「部署了」当成「可以对外服务」 | 对外前逐项过上线门（`C-R10`）；单机 KIND 不是生产高可用 |

描述能力状态用四个递进的词：**defined**（schema、表、Port 在）→ **wired**（有生产调用方）→ **deployable**（配置与门禁允许部署）→ **runtime-verified**（有运行证据）。

## 10. 去哪查

| 我要… | 读 |
| --- | --- |
| 知道这个产品要什么 | [需求](../dev-investment-agent/tree-build/PRD/requirement.md)、[`PRD/apps/`](../dev-investment-agent/tree-build/PRD/apps/README.md)、[决策](../dev-investment-agent/tree-build/decisions.md) |
| 知道某块怎么设计 | [`SDD/architecture/`](../dev-investment-agent/tree-build/SDD/architecture/README.md)、[`SDD/modules/`](../dev-investment-agent/tree-build/SDD/modules/) |
| 动代码前必读的规则 | [`rules/constraints.md`](../dev-investment-agent/tree-build/rules/constraints.md) |
| 一次求助 / 一次委托怎么走 | [流水线](../dev-investment-agent/pipeline.md)、[`turn/`](../dev-investment-agent/turn/README.md) |
| 拓扑、谁连谁 | [`k8s/docs/拓扑.md`](../拓扑.md) |
| 部署、发版、某个组件怎么维护 | `k8s/README.md`、`infrastructure/` 与各组件目录的 `README.md`、[规则「发布」](../dev-investment-agent/tree-build/rules/constraints.md#发布) |
| 派活卡、回执、两台机器怎么同步 | [`switch-test/`](../dev-investment-agent/switch-test/README.md)（`inbox/`、`done/`、`human-*.sh`）；回执在各仓 `scripts/results/` |
| 改某个仓的代码 | [`repos/`](repos/) 对应文件 |
| 跨应用契约、数据、分身 | [`topics/`](topics/) 对应文件（分身：[`topics/knowbot.md`](topics/knowbot.md)） |
| 还没做的事 | [待办账](../dev-investment-agent/tree-build/pending-after-migration.md)、[接下来做什么](staging.md)；改名（info→knowfeed、knowledge→knowbase，2026-10-14 至 16）的手册与回执已删，按 Git 历史 `3951246c:docs/rename.md` 取 |
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

- 分身线代码未部署（0027 P4 第二部分待所有者定、P5 未做，P6 一次发布）；工作台的「专家」还没改叫「分身」，内置专家包还是对全体用户可选、沙箱还默认接 knowbase 数据服务——工作台对用户开放前要改完（[0026](../dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)「四」）。
- 管理端业务页受角色缺口所限看不到；admin 的旧沙箱待按 0014 U4 回收（[待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 98、99）。
- 单机 KIND：数据主备同在一块物理盘，机器外备份未落地；开机恢复的剩余验证、Harbor 持久化实测、长期空间管理、灾备、云端建群见 [待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 104–109。
- 评测的自动化门未接；`scripts/test_switch_test_sync.py` 有 3 个用例早就失败。
