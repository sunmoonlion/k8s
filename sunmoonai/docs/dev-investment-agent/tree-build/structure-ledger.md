# 工程结构整改的账本

> 2026-09-29 所有者要求：「你上面留待后面做的，你记好账，不要忘记了」。
> 规则在 [`SDD/architecture/engineering.md`](SDD/architecture/engineering.md)「工程结构」。
> 这里只记**说过要做、还没做**的事。做完一项，把状态改成「已做」并写上提交；不删行。
> 会动到部署的事另外记在 [迁移完成后要做的事](pending-after-migration.md)，这里只写一行指过去。

## 怎么读

| 列 | 含义 |
| --- | --- |
| 等什么 | 这件事现在为什么不做。写「不等」的，轮到就做 |
| 状态 | 待做 / 进行中 / 已做 / 等所有者定 |

## 一、整改的步骤

| # | 内容 | 等什么 | 状态 |
| --- | --- | --- | --- |
| A1 | 规则写进工程架构文档 | — | 已做，k8s `3d755f0c` |
| A2 | 删除旧运行时、15 个旧脚本；镜像不含脚本与评测目录 | — | 已做，investment-backend `0c1a030` |
| A3 | 删除旧运行时的历史设计文档（3 份 v4 文档、18 份 ADR） | — | 已做，investment-backend `0c22ea6` |
| A4 | 工作台 5 个应用层文件改依赖方向：经端口引用，组装放到 `bootstrap` | — | 已做，investment-backend `656a93d`。行为不变：测试 479 过、5 跳过，57 条路由逐条相同。这一步里新发现的事记在下面第七节（H1 至 H7）；A5 查出的是 H8 至 H14 |
| A5 | 加自动检查（`import-linter`），违反就不通过。共四条契约：原来的三条硬规则，加所有者 2026-09-29 定的第四条（H5） | — | 已做。模板 tpl-backend `bcda893`；info-backend `240b01a`；knowledge-backend `db38178`；investment-backend `9caac46`。旧账放行清单：模板 10 条，info 27 条，knowledge 28 条，investment 12 条。A6 之后：模板 1 条，info 18 条，knowledge 19 条，investment 3 条。A7 甲 之后：info 12 条（其中 1 条是例外）。H1、H2、H12 之后：investment 1 条，knowledge 18 条 |
| A6 甲 | 模板带来的可靠投递改依赖方向：代码挪到基础设施层。连同 H8、H9。先改模板，再同步到三个后端 | — | 已做。模板 tpl-backend `f27dabe`；info-backend `d3a4202`；knowledge-backend `23586c4`；investment-backend `1584de1`。旧路径留了一个只做转发的文件（H15） |
| A6 乙 | 模板带来的登录服务改依赖方向：经端口引用，组装放到 `bootstrap` | — | 已做。模板 tpl-backend `058c663`；info-backend `c54388b`；knowledge-backend `7f12225`；investment-backend `6abae02`。部署目录里有一个集成测试要跟着改，归本地助手；所有者 2026-09-29 同意派任务给它，补丁与交接单在 [`handoff-luna/2026-09-29-a6/`](handoff-luna/2026-09-29-a6/README.md)，见迁移账本第 25 行 |
| A7 甲 | info：两个采集器经端口取数；数据集写文件挪到基础设施层（H11）；原件对账整个挪到基础设施层 | — | 已做，info-backend `89f4d77`。放行清单 18 条减到 12 条 |
| A7 乙 | info：采集服务（`info_crawl_service.py`，1933 行）与它的投递（`delivery_outbox.py`）改依赖方向。**规模比 2026-09-29 早些时候说的「5 个旧文件」大得多**：110 处直接操作数据库会话，9 个表模型，约 20 个测试文件（约 3900 行）和部署目录里一个 497 行的集成测试都直接依赖它的内部写法（替换模块里的名字 8 处）。要分几步做：先把对外的六样（取数、对象存储、知识服务、搜索、并发名额、排队）改成经端口；再把纯计算搬出去；最后是数据库这一层（实体与表的映射分开，加仓储）。做完后从放行清单里删 10 条 | 集群迁移完成 | 待做。**所有者 2026-09-29 定：等集群迁移完成再做** |
| A8 | knowledge 的 5 个旧文件改依赖方向（入库 3、检索、投递，共约 1670 行），连同 H12。与 A7 乙 是同一种情况：部署目录里的集成测试直接依赖它们的内部写法（替换模块里的名字 9 处）。做完后从放行清单里删 17 条 | 集群迁移完成 | 待做。**所有者 2026-09-29 定：等集群迁移完成再做**。其中 H12（数据集查询）不牵连部署目录，已先做 |

## 二、删除旧运行时之后留下的尾巴

| # | 内容 | 等什么 | 状态 |
| --- | --- | --- | --- |
| B1 | 数据库里旧运行时的表，用一个新的迁移去掉 | 集群迁移完成。删表要和数据库权限清单一起改（见 B4） | 待做 |
| B2 | 部署清单里后端不再读取的配置项 | 集群迁移完成 | 见迁移账本第 20 行 |
| B3 | 撤销投资应用到知识服务的检索身份。**所有者 2026-09-29 定：撤销** | 集群迁移完成 | 见迁移账本第 21 行 |
| B4 | 数据库权限清单里旧运行时的表 | 与 B1 一起 | 见迁移账本第 22 行 |
| B5 | 父仓库里的检索契约消费锁 `investment-app/contracts/knowledge-retrieval-provider-lock.json`，以及 `contracts/README.md` 里对它的说明 | 与 B3 一起。检索身份撤销时一并删 | 待做 |
| B6 | 知识服务那一侧：检索接口给投资应用留的身份绑定与白名单 | 与 B3 一起 | 待做 |
| B7 | k8s 仓的「投资应用仓库说明」（`project-guide/repos/investment-app.md`）重写。现在只在开头加了过时提示 | A4 做完，工作台的结构定下来之后 | 待做 |
| B8 | k8s 仓 `project-guide/topics/contracts.md` 里关于检索契约消费方的说明 | 与 B3 一起 | 待做 |

## 三、模板层面的

| # | 内容 | 等什么 | 状态 |
| --- | --- | --- | --- |
| C1 | 模板带来的 2 个脚本（`scripts/pair_fixture.py`、`scripts/delivery_runtime_probe.py`）：前一个是前端测试用的夹具，该放到测试目录；后一个是 2026-09-11 的探针，该删。三个后端和模板都有 | 先在模板里改，再同步 | 待做 |
| C2 | 三个后端的 `domain/models`、`domain/repositories`、`domain/services` 是空的占位目录 | 同上 | 待做 |
| C3 | 接口层两套放法并存（`interfaces/endpoints/` 与 `interfaces/http/`）。工作台路由挪到 `http/web`；别的随改随挪 | A4 做完 | 待做 |
| C4 | 规则与自动检查的契约写进模板 | — | 已做，随 A5（tpl-backend `bcda893`，含 `CLAUDE.md`） |

## 四、前端

所有者 2026-09-29：「前端暂时先不动吧，我们等会一起讨论，因为前端的结构我要大改」。

| # | 内容 | 等什么 | 状态 |
| --- | --- | --- | --- |
| D1 | 前端的结构（三层，还是按功能切片，还是别的） | 所有者主持讨论 | **2026-10-04 已定**：按功能切片，`features/<功能>/` 下分取数、状态、渲染。第 7 步在 investment 里先用，之后进模板 |
| D2 | 网页设计的七件事（W1 至 W7，见 [近期要定的事](owner-decisions-now.md)）。W7 已定：在本地用样例数据看页面 | 所有者 | 等所有者定 |
| D3 | 首页挂着的旧研究工作区（investment-web-frontend `components/research/`，约 829 行）与管理端的旧运行时面板（investment-admin-frontend `components/research/`） | D1 定了之后，随前端改造删 | 待做 |
| D4 | 预览模式：前端连样例数据，不连后端 | — | 已做，2026-10-04，见 [`0002-web-preview`](SDD/modules/0002-web-preview.md)。做成了网页端之外的一个进程，网页端的代码一行不改，所以没有等 D1 |
| D5 | 工作台 4 个组件里取数、状态、渲染混在一起 | D1 定了之后重写 | 2026-10-04 做完：旧的四个组件都没有了，页面全部按功能分 |

## 五、暂缓的建议

这些是远程提的，所有者没有定。

| # | 内容 | 等什么 | 状态 |
| --- | --- | --- | --- |
| E1 | 会合点、沙箱供给器、沙箱桥的代码从 k8s 仓挪到 `runtime` 仓 | 集群迁移完成；所有者定 | 等所有者定 |
| E2 | 迁移验收后在本机开虚拟机，单独验云上建集群那几步 | 本地助手评估；所有者定 | 等所有者定 |

## 六、别人的东西，不归远程清理

| # | 内容 | 归谁 | 说明 |
| --- | --- | --- | --- |
| F1 | 远程机家目录下 `sunmoon-nginx-sni-20260927-v1`、`sunmoon-registry-publisher-20260928-v1`、`sunmoon-scanner-patches-20260927-v1`、`sunmoon-scanner-stable-20260927-v1`、`sunmoon-traefik-20260927-v1`，合计约 660 MB | 本地助手 | 是它借远程机下载公开物料时留下的，已登记在它的最终清理清单里。所有者 2026-09-29 问过要不要删，远程建议等迁移验收之后按它的清单清 |

## 七、做 A4、A5 时新发现的

2026-09-29 改工作台依赖方向（H1 至 H7）与接上自动检查（H8 至 H14）时看到的。都不违反「应用层不引用基础设施层」这一条的字面，所以 A4 没有动它们；但按分层的本意，它们放错了地方。
编号用 H，是为了不和 [网页差距盘点](SDD/modules/0002-web-gap.md) 里的后端契约缺口 G1 至 G7 撞号。

| # | 内容 | 位置 | 等什么 | 状态 |
| --- | --- | --- | --- | --- |
| H1 | 应用层里放着对外的实现：会合点管理通道的 WebSocket 实现 `WsRelayAdmin`、供给器的 HTTP 实现 `HttpProvisioner`（直接用 `httpx`、`websockets`）。接口 `RelayAdmin` 已经有了，只是实现没有挪走 | investment-backend `application/workbench/provisioning.py` | — | 已做，investment-backend `0d55ab6`。实现挪到 `infrastructure/workbench/`，端口补上 `Provisioner`、`RelayAdmin`、`Cipher`；四个类的代码逐字相同。会合点管理通道原来没有测试，这次补了 |
| H2 | 应用层里放着 Redis 发布的实现 `Publisher` | investment-backend `application/workbench/runner.py` | — | 已做，investment-backend `0d55ab6`。挪到 `infrastructure/workbench/publisher.py`，改名 `RedisPublisher`，端口 `EventPublisher` |
| H3 | 应用层里直接用签名库签发令牌（`joserfc`） | investment-backend `application/workbench/tokens.py` | 同上。先定规则：签名算不算「外部」 | 待做 |
| H4 | 基础设施层引用了应用层的数据结构与异常（`application/dto/outbox`、`application/errors`）。方向是「外层引用内层」，规则允许。原来 `durable_tasks` 与基础设施层互相引用，已随 A6 甲解开 | 三个后端（模板带来的） | — | 已做，随 A6 甲 |
| H5 | 自动检查多加一条：应用层与领域层不直接引用数据库、网络、消息这类库 | 规则 | — | 已做，随 A5。**所有者 2026-09-29 定：加** |
| H6 | 端口 `WorkbenchStore` 有 64 个方法，是照着现有的仓储原样列的。以后按用途拆成几个小端口（会话、委托、待办、凭据……） | investment-backend `application/ports/workbench.py` | 不急。工作台下一次大改时顺带做 | 待做 |
| H7 | 端口上有 `commit()`、`flush()`：应用层原来有 7 处直接操作数据库会话，为了行为不变，这次原样搬到端口上。更干净的做法是全部改用 `transaction()` | investment-backend `application/workbench/advisor.py`、`ledger.py` | 不急。要改提交点，得单独做、单独测 | 待做 |
| H8 | outbox 端口的方法签名里直接写了数据库会话的类型（`sqlalchemy`） | 三个后端与模板 `application/ports/outbox.py` | — | 已做，随 A6 甲。事务句柄改成不透明的类型，端口只负责原样交给实现 |
| H9 | 审计上下文直接读网页框架的请求对象（`starlette`） | 三个后端与模板 `application/audit_context.py` | — | 已做，随 A6 甲。应用层只收请求头；读请求的那一行留在组装层 |
| H10 | 领域层的身份规则用了 `httpx`。**查过之后认为不该改**：这份规则是冻结的（文件开头写明不许就地改，迁移 0008 也用它），用的只是 `httpx.URL` 解析地址，不发请求；换成别的解析器，地址归一的结果可能不同，已有文档的身份会变。建议记为例外，在放行清单里注明，不算旧账 | info-backend `domain/info_identity_v1.py` | — | **所有者 2026-09-29 定：同意记为例外。** 放行清单里已注明原因，不算旧账，不用还 |
| H11 | 数据集文件的写入实现放在了应用层（直接用 `sqlite3`）。远程 2026-09-27 写的 | info-backend | — | 已做，随 A7 甲。各张表的排法留在应用层（`dataset/tables.py`），写文件挪到 `infrastructure/securities/dataset_file.py` |
| H12 | 数据集文件的查询实现放在了应用层（直接用 `sqlite3`）。远程 2026-09-24 写的 | knowledge-backend `application/services/dataset_query.py` | — | 已做，knowledge-backend `9bba92a`。规则（只读检查、按名字找口径、出处）留在应用层；读 SQLite 文件的实现挪到 `infrastructure/datasets/`，改名 `SqliteDatasetQueries`。7 个方法的代码逐字相同 |
| H13 | 模板与 knowledge 的 `tests/test_kernel_invariants.py` 有一行超长，代码检查报 1 个错。改之前就有，不是这次引入的 | tpl-backend、knowledge-backend | 随 A6 在模板里改 | 待做 |
| H14 | 模板的三个子仓（后端与两个前端）在远程工作区里原来没有 `fable` 分支。这次给 tpl-backend 建了；两个前端还没有 | tpl-app 的子仓 | 要动模板前端时再建 | 做了一半：2026-09-29 做跨应用跳转时给四个网页端的仓库（模板与三个应用）建了。四个管理端的仓库还没有 |
| H15 | 可靠投递的旧路径 `app/application/services/durable_tasks.py` 现在只做转发，为的是部署目录里的集成测试还能跑。它是应用层引用基础设施层，在放行清单里占 1 条 | 三个后端与模板 | 集群迁移完成。与迁移账本第 24 行一起做：先改集成测试的引用，再删这个文件 | 待做 |
| H16 | info、knowledge 应用层里的旧文件（A7 乙、A8 的那几个）仍然经旧路径用可靠投递。改它们的时候，把「排队」「确认租约还在」做成各自存储端口上的方法，不再直接引用 | info-backend、knowledge-backend | 随 A7 乙、A8 | 待做 |
| H17 | 接口层的模块在加载时从 `bootstrap` 取接好的登录服务。更彻底的做法是由组装层在建应用时把它交给接口层。要动路由和现有测试替换假对象的方式 | 三个后端与模板 `interfaces/http/` | 不急 | 待做 |
| H18 | 本机联调脚本起对象存储时偶尔抢跑（容器首次启动会自己重启一次），`up` 第一次可能失败，重跑即可 | k8s 仓 `scripts/local-integration/dataset-chain/run.sh` | 不急 | 待做 |
| H19 | k8s 仓部署目录里 info、knowledge 的两个集成测试，直接引用了 info 的采集服务与 knowledge 的入库、检索、投递服务，并替换这些模块里的名字（info 8 处、knowledge 9 处）。A7 乙、A8 每做一步，这两个测试都要跟着改。办法同 A6：远程先备好补丁并在草稿副本里验证，再交给本地助手 | k8s 仓 `app-platform/scripts/integration/` | 随 A7 乙、A8 | 待做 |
| H20 | 远程此前一直把 info 的 `test_abrupt_process_exit_releases_source_lock` 记为「原来就不过」。**记错了**：是远程跑测试时数据库地址写成了 `postgresql://`，那个测试起的子进程连不上；写成 `postgresql+asyncpg://` 就通过。代码没有问题。2026-09-28 以来各份记录里的「1 个失败」都是这个原因 | 远程的测试环境 | — | 已查清（2026-09-29）。以后跑测试一律用带驱动名的地址 |
| H23 | 远程 2026-09-29 回答所有者时说「两个前端没有任何页面调用来源、采集器、采集任务、文档这些接口」。**说错了**：当时查的目录不存在，查不到东西不等于没有。实际上 info 管理端有一个旧页面「Info crawl」（2026-07），能列文档、建采集任务。证券采集确实没有页面 | 远程的回答 | — | 已更正（2026-09-29），写进 [`0008-info-intake`](SDD/modules/0008-info-intake.md)「现状」 |
| H21 | 供给器的配置里混着两样东西：怎么连供给器（地址、令牌），和新建沙箱默认用哪个模型。后一样是业务设置，应用层现在经供给器的 `config` 去读。以后分开：默认模型单独交给应用层 | investment-backend `infrastructure/workbench/provisioner.py` | 不急 | 待做 |
| H22 | 跑测试用的两个数据库地址写法不同：`DELIVERY_TEST_DATABASE_URL` 要带驱动名（`postgresql+asyncpg://`），`AGENT_TEST_DATABASE_URL` 不能带（`postgresql://`）。写反了会有测试失败或报错，而且报的错看不出是地址的问题 | 三个后端的测试 | 不急。把两处的写法统一，或在测试开头检查并给出明白的提示 | 待做 |

## 七之二、做工作台第 4 步时新发现的

2026-09-29 做项目、对话的种类、专家这一面的接口时看到的。前六条是在真的 Codex 0.155.1 上跑出来的。全文见 [`0001-workbench-projects`](SDD/modules/0001-workbench-projects.md)。

| # | 内容 | 位置 | 等什么 | 状态 |
| --- | --- | --- | --- | --- |
| H24 | 联调驱动从 `scripts/` 搬到 `tests/drivers/` 之后路径算错，搬家后一直跑不起来，没有人发现 | investment-backend `tests/drivers/workbench_chain_driver.py` | — | 已做，`4897cf4` |
| H25 | 联调驱动等事件时不给沙箱的租约续期（租约 10 秒）。模型一慢，连接就被当成丢了，审批答复失败。租约是后来加的，驱动没跟上 | 同上 | — | 已做，`4897cf4` |
| H26 | 推理摘要的增量事件被记进了账：后缀名单里没有 0.155.1 的新名字。一轮几十条；读事件的接口一次最多 500 条，几轮之后就取不全 | investment-backend `application/workbench/runner.py` | — | 已做，`4897cf4`。凡是增量都不入账 |
| H27 | 页面要流式显示，增量事件要「发给页面但不入账」。现在是既不入账也不发 | 同上 | 第 7 步做聊天页时 | 待做 |
| H28 | 同一条线上换了情形，Codex 不告诉模型手里的工具变了；模型按自己先前说过的话行事 | — | — | 已做，`4897cf4`。换情形时往线里插一段说明 |
| H29 | 被只读拦下的命令，Codex 不发事件：命令在用户机器上执行了、写被拒了，账里没有这条命令。聊天页显示不出「试过、被拒」，审计少一条 | Codex 0.155.1 | 可能的补法：一轮结束后用 `thread/items/list` 对一遍账。要不要做，等做聊天页时看 | 待定 |
| H30 | 模型会起子代理、会设「目标」让线自己接着跑，都是账外的：事件不进账，费用不进预算 | — | — | 已做，`4897cf4`，起线与重新装载线时关掉。沙箱镜像的配置里也该关，作为第二道，见 [迁移账本](pending-after-migration.md) 31 |
| H31 | 专家包里「退回第 k 步」没有次数上限：退回之后这一步再不过，还会再退回，只有预算能拦住 | investment-backend `application/workbench/advisor.py` | 要不要给退回也设上限，是专家包的规矩，请所有者定 | 待定 |
| H32 | 机器在不在线没有真的跟踪：登记时写在线，之后没有人改（初稿缺口 G6）。聊天「机器不在线时不给执行环境」、请专家「机器不在线交不出去」这两支代码有、测试有，现在实际走不到 | investment-backend | 本地代理的心跳经会合点报给工作台。要动会合点与本地代理 | 待做 |
| H33 | 设置页里审批策略能选 `on-failure`，Codex 0.155.1 已经不认。后端按 `on-request` 发 | investment-web | 第 7 步 | 待做 |
| H34 | 专家一步的费用按占位的单价算。联调里机制烟测两步记了 1.02 | investment-backend `application/workbench/advisor.py` 的 `Pricing` | 2026-10-04 已做：按公开单价（配置里），每次调用相加。原来还拿累计当一步的用量，一并改了 | 已做 |
| H35 | 读项目记录的工具服务用的限流是进程内计数，多个进程各算各的 | investment-backend `interfaces/mcp/workbench_mcp.py` | 知识服务的工具也是这样。要换成共用的计数时一起换 | 待做 |
| H36 | 专家这一面新加的读取（步骤、待办、底稿）每次都从账里现算。委托多了、事件多了会慢 | investment-backend `application/workbench/expert_desk.py` | 真的慢了再说 | 待定 |
| H37 | 三个应用网页端的登录契约里，应用名的名单是 `tpl`、`info`、`knowledge`、`research`；investment 的那一份另加了 `investment`。`research` 是 investment 以前的名字，名单没有清 | 四个网页端 `contracts/auth.ts` | 做页面时一起清。先在模板里改 | 待做 |
| H38 | 配置文件（`core/config.py`）现在引用了领域层（跨应用跳转的规则）。以前 `core` 不引用 `app`。为的是规则只写一处，配置写错了启动时就能报 | 四个后端 | 远程认为可以接受：领域层是最里面的一层，谁都可以引用它。所有者或评审认为不行的话，退路是把校验挪到组装层 | 待定 |
| H39 | 跑 `ruff format` 时带上了整个 `tests` 目录，顺手重排了模板里 7 个无关的测试文件的格式。发现后原样恢复了，没有提交。这些文件本来就不合现在的格式，代码检查不查它们 | tpl-backend `tests/` | 以后只对自己动过的文件跑格式化 | 已处理 |
| H40 | 预算可能被最后一步超出：一步花多少事先不知道，只按预留的数判断够不够。样例里上限 1.00、实际花了 1.20 | investment-backend `application/workbench/advisor.py` | 所有者 2026-10-04 定：不设上限，实时显示加随时能停。给了上限时这个问题仍然在，但页面不再给上限 | 不再适用 |
| H41 | 沙箱列表接口把沙箱令牌的引用返回给了浏览器；按需拉起的沙箱，这个引用就是令牌本身。第一期留下的，原来的测试还断言它在返回里 | investment-backend `interfaces/endpoints/workbench_routes.py` | — | 已做，随第 6 步 |
| H42 | 沙箱列表、拉起沙箱的返回里还有沙箱的内部地址。不是密钥，浏览器用不着；旧页面在显示它 | 同上；investment-web `contracts/workbench.ts` | 第 7 步重做页面时去掉 | 待做 |
| H43 | 旧的工作台页面认不得契约第 2 版的数据（不属于项目的聊天没有机器），列表显示为空 | investment-web `components/workbench/` | 第 7 步整个重做，不修旧页面 | 待做 |
| H44 | 本机联调（`workbench-chain.sh`、`workbench-modes.sh`）的项目目录在 runtime 仓库里，Codex 会读到仓库的 `AGENTS.md`。不影响这两个脚本验的东西；录磁带的脚本已改到仓库之外 | k8s `scripts/local-integration/` | 顺手时改 | 待做 |
| H45 | 专家在真数据上从头到尾跑一遍（真的 Codex、真的知识服务、真的数据集）还没有做过。样例里专家各步的交回物是照格式写的 | — | 把数据集这条链的联调和工作台的联调接起来。迁移完成后在集群上做也可以 | 待做 |
| H46 | 管理端（四个 `*-admin-frontend`）没有预览 | — | 第 8 步做 info 管理端的页面时加，用同一个记录器 | 待做 |
| H47 | 被打断的那一次模型调用，花费记不到：Codex 只在一次调用做完时报用量。停下的那一刻显示的数比真实账单少（最多一次调用） | investment-backend `application/workbench/runner.py` | 没有办法从 Codex 拿到。页面上写明「估算」。要更准只能去读模型厂商的账单接口 | 记下，不做 |
| H48 | 模型单价是手工查了写进配置的（`WORKBENCH_MODEL_PRICES_JSON`），厂商改价不会自己跟上；写缓存按 5 分钟档算（Codex 不报是哪一档） | investment-backend `domain/workbench/pricing.py` | 换模型或厂商改价时改配置。接口里带着「单价是哪天查的」 | 记下 |
| H49 | 没有硬性的花费上限之后，「退回第 k 步」没有次数上限（`I7`）就更要紧：没人看着时专家可以一直来回 | investment-backend 专家包 | 所有者定 `I7` | 待定 |
| H50 | 本机联调的驱动在等专家做完时不续沙箱的租约，之后那一段会先掉线再重连。不影响结论（重连正好验了「重报的用量不重复记」），但日志里有一行 `lease lost` | investment-backend `tests/drivers/workbench_chain_driver.py` | 等的时候让 runner 接着转 | 小事，待做 |
| H51 | MCP 的询问（Codex 调 MCP 工具前要的那一次确认）现在一律自动同意，理由是只挂了我们自己的知识服务。接用户自己的连接器之前必须改成问用户，否则第三方工具不经用户就能被调用 | investment-backend `application/workbench/runner.py` 的 `_on_elicitation` | 做连接器（`V5`）时改：我们自己的服务照旧，其余开一条待办让用户答 | 待做，连接器的前提 |
| H52 | 正式构建下每一页都有一条内容安全策略的报错：「加载中」那一页（`app/[locale]/loading.tsx`）的脚本没有带随机数，被浏览器拦了。页面照常显示，但那个加载中的界面可能出不来 | 模板与各应用网页端的 `proxy.ts`、`app/[locale]/loading.tsx` | 在模板里查清 Next 16 给哪些脚本带随机数，再同步 | 待做 |
| H53 | 管理端（四个 `*-admin-frontend`）的字体变量也指向它自己，页面用的是浏览器默认字体。网页端 2026-10-04 已改 | 各管理端 `app/globals.css` | 做管理端页面时一起改（管理端的仓库还没有 `fable` 分支） | 待做 |
| H54 | 模型的话不是边出边显示：一个字一个字的事件被后端丢掉了，既不进账也不推给页面 | investment-backend `application/workbench/runner.py`（按后缀跳过） | 这类事件不进账，但推给页面；页面把它接在当前这一轮上 | 待做，所有者看过聊天页之后排 |
| H55 | 网页端的契约是手写的（zod），不是从后端的接口定义生成的（`F-WEB-06`）。后端这些接口没有声明返回的结构。现在靠「对着真接口录下来的样例逐份检查」兜着 | investment-web-frontend `contracts/workbench-v2.ts` | 后端给这些接口补上返回的结构之后再生成 | 记下 |
| H56 | 工作页的「改动」栏只列得出用 Codex 的补丁工具改的文件。现在用的模型（kimi-k3）改文件走命令行，Codex 不单独报，所以真用起来这一栏多半是空的。起线时 Codex 还提示「找不到 kimi-k3 的模型信息，用默认的」，默认的信息里可能就没有给它补丁工具 | 沙箱里 Codex 的模型配置（`sandbox-platform`，本地助手的目录） | 查 Codex 怎么给一个模型配上补丁工具，在沙箱的配置里给 kimi-k3 配上；或者在本地代理那边按目录的前后差别来报改动 | 待查。动沙箱配置要等迁移之后 |
| H57 | 第 7 步做完后，`lib/workbench/routes.ts` 里「哪些页已经做好」的清单全都是「做好了」，相关的判断成了多余的 | investment-web-frontend `lib/workbench/routes.ts` 与用到 `isBuilt` 的地方 | 留着：以后加「技能」「连接器」「助理」的页时还要用同一个办法。那时不用就删 | 记下 |
| H58 | 首页挂着的旧研究工作区（账本 D3）还在：`components/research/` 与 `lib/interaction/`。第 7 步没有碰公开首页与登录过渡页 | investment-web-frontend | 做公开首页（初稿 4.8）时删 | 待做 |

## 八、自动检查怎么用

| 项 | 说明 |
| --- | --- |
| 契约在哪 | 各后端 `app/pyproject.toml` 的 `[tool.importlinter]`。四个仓的契约逐字相同，只有放行清单不同 |
| 怎么跑 | `uv run pytest` 会跑（`tests/test_layering.py`）；也可以单独 `uv run lint-imports` |
| 放行清单 | 只减不增。还掉一条旧账就删一条；清单里写的引用已经不存在时检查会报错，所以删不掉队 |
| 查不到的 | 只看「谁引用了谁」。把实现写在应用层、但没有引用被禁的库的代码查不到（例如 H2 的 Redis 发布：连接是别人传进来的）。这类靠评审 |

