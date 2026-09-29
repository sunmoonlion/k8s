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
| A4 | 工作台 5 个应用层文件改依赖方向：经端口引用，组装放到 `bootstrap` | — | 已做，investment-backend `656a93d`。行为不变：测试 479 过、5 跳过，57 条路由逐条相同。这一步里新发现的事记在下面第七节（H1 至 H7） |
| A5 | 加自动检查（`import-linter`），违反三条硬规则就不通过 | A4 做完 | 待做 |
| A6 | 模板带来的 2 个文件（登录服务、可靠投递）改依赖方向：先改模板，再同步到三个后端 | A5 做完 | 待做 |
| A7 | info 的 5 个旧文件改依赖方向（采集器 2、采集服务、投递、原件对账） | A6 做完 | 待做 |
| A8 | knowledge 的 5 个旧文件改依赖方向（入库 3、检索、投递） | A6 做完 | 待做 |

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
| C4 | 规则与自动检查的契约写进模板 | A5 做完 | 待做 |

## 四、前端

所有者 2026-09-29：「前端暂时先不动吧，我们等会一起讨论，因为前端的结构我要大改」。

| # | 内容 | 等什么 | 状态 |
| --- | --- | --- | --- |
| D1 | 前端的结构（三层，还是按功能切片，还是别的） | 所有者主持讨论 | 等所有者定 |
| D2 | 网页设计的七件事（W1 至 W7，见 [近期要定的事](owner-decisions-now.md)）。W7 已定：在本地用样例数据看页面 | 所有者 | 等所有者定 |
| D3 | 首页挂着的旧研究工作区（investment-web-frontend `components/research/`，约 829 行）与管理端的旧运行时面板（investment-admin-frontend `components/research/`） | D1 定了之后，随前端改造删 | 待做 |
| D4 | 预览模式：前端连样例数据，不连后端 | D1 定了之后 | 待做 |
| D5 | 工作台 4 个组件里取数、状态、渲染混在一起 | D1 定了之后重写 | 待做 |

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

## 七、做 A4 时新发现的

2026-09-29 改工作台依赖方向时看到的。都不违反「应用层不引用基础设施层」这一条的字面，所以 A4 没有动它们；但按分层的本意，它们放错了地方。
编号用 H，是为了不和 [网页差距盘点](SDD/modules/0002-web-gap.md) 里的后端契约缺口 G1 至 G7 撞号。

| # | 内容 | 位置 | 等什么 | 状态 |
| --- | --- | --- | --- | --- |
| H1 | 应用层里放着对外的实现：会合点管理通道的 WebSocket 实现 `WsRelayAdmin`、供给器的 HTTP 实现 `HttpProvisioner`（直接用 `httpx`、`websockets`）。接口 `RelayAdmin` 已经有了，只是实现没有挪走 | investment-backend `application/workbench/provisioning.py` | A5 做完。挪到基础设施层，在 `bootstrap` 里接上 | 待做 |
| H2 | 应用层里放着 Redis 发布的实现 `Publisher` | investment-backend `application/workbench/runner.py` | 同上 | 待做 |
| H3 | 应用层里直接用签名库签发令牌（`joserfc`） | investment-backend `application/workbench/tokens.py` | 同上。先定规则：签名算不算「外部」 | 待做 |
| H4 | 基础设施层引用了应用层的数据结构与异常（`application/dto/outbox`、`application/errors`、`application/services/durable_tasks`）。方向是「外层引用内层」，规则允许；但其中 `durable_tasks` 与基础设施层互相引用，要随 A6 一起解开 | 三个后端（模板带来的） | A6 | 待做 |
| H5 | 自动检查的契约要不要再加一条：应用层不直接引用 `sqlalchemy`、`httpx`、`websockets`、`redis` 这类库。加了才能挡住 H1、H2 这种「没引用基础设施层、但自己就是基础设施」的写法 | 规则 | A5 时提给所有者定 | 等所有者定 |
| H6 | 端口 `WorkbenchStore` 有 64 个方法，是照着现有的仓储原样列的。以后按用途拆成几个小端口（会话、委托、待办、凭据……） | investment-backend `application/ports/workbench.py` | 不急。工作台下一次大改时顺带做 | 待做 |
| H7 | 端口上有 `commit()`、`flush()`：应用层原来有 7 处直接操作数据库会话，为了行为不变，这次原样搬到端口上。更干净的做法是全部改用 `transaction()` | investment-backend `application/workbench/advisor.py`、`ledger.py` | 不急。要改提交点，得单独做、单独测 | 待做 |

