# 迁移完成后要做的事（账本）

> 规则（所有者 2026-09-28）：本地助手做集群迁移期间，凡是会影响迁移的部分，远程**不动，只记账**。
> 迁移完成、所有者说「luna 做完了」之后，按这张表逐项处理，处理完的划掉并写上提交。
> 远程在此期间只改三个应用仓库的代码与本文档目录。
> **2026-10-06 起规则变了**（所有者定）：本地助手的额度用完，新体系（`infrastructure/`、`gitops/`）由远程接着做完，本地由 Cursor 按 `switch-test/inbox/` 的待办协助调试。luna 的分支已并进 `fable`，以后都在 `fable` 上改、在 `fable` 工位上跑。旧 `sunmoonai/` 树冻结不删（所有者定）。这张表接着用：每一行在新体系里的落点见 [`platform-kind-v1-review.md`](platform-kind-v1-review.md) 第四节。

## 怎么记

一行一件事：要做什么、为什么、是哪次改动带来的。只记会落到部署、集群、镜像、网络、存储上的事；应用代码自己的待办不记在这里。

## 账

| # | 要做的 | 为什么 | 来自 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | info 后端：数据库迁移到 `20260927_0012` | 采集批次、数据集、向知识服务登记的三张表与两列 | info-backend `1516f9f`、`f66a36f`、`688ebc7` | 待办 |
| 2 | knowledge 后端：数据库迁移到 `20260927_0007` | 数据集登记表 | knowledge-backend `a41299f` | 待办 |
| 3 | info 的配置：`KNOWLEDGE_APP_DATASET_URL` | 向知识服务登记数据集 | info-backend `688ebc7` | 待办 |
| 4 | knowledge 的配置：打开 `knowledge_dataset_registry_enabled`；`knowledge_dataset_allowed_buckets` 写 info 的桶 | 多数据集 | knowledge-backend `a41299f` | 待办 |
| 5 | knowledge 的存储账号对 info 的桶只读 | 知识服务按登记的位置自己取数据集文件 | 同上 | 待办 |
| 6 | knowledge 的配置：打开 `knowledge_semantic_engine_enabled`；`knowledge_semantic_cache_dir` 指到可写的目录 | 语义层 | knowledge-backend `98e83a0` | 待办 |
| 7 | knowledge 后端镜像增大约 600 MB；镜像仓库留出空间 | 语义层的依赖 | 同上 | 待办 |
| 8 | info 的出站网络策略：放行巨潮（`www.cninfo.com.cn`、`static.cninfo.com.cn`）与东方财富（`emweb.securities.eastmoney.com`） | 采集。新集群的网络策略真正生效，不放行就采不了 | info-backend `1516f9f` | 待办 |
| 9 | 三个后端与网页重新构建、发版 | 2026-09-27 以来的全部改动 | 各仓库 `fable` | 待办 |
| 10 | 数据盘上限 230 GiB | 所有者 2026-09-28 定（先定 260，随后改为 230）。由本地助手在迁移里实施。迁移完成后远程只核对：info 的原件留存与转存的水位按 230 GiB 计算 | 决策文档 2026-09-28 | 已定，本地助手实施 |
| 11 | 外存储：内网另一台机器上装什么服务；从集群到它的出站放行 | 年报原件的转存与备份；所有者已定方向，做法未定 | 决策文档 2026-09-28 | 等所有者定 |
| 12 | 在新集群上跑通最小闭环（`0008-info` 段五） | 验收 `MVP-09` | — | 等集群 |
| 13 | info 的配置（可不配，有默认值）：`SECURITY_REPORT_MAX_BYTES`（默认 128 MiB）、`SECURITY_REPORT_TIMEOUT_SECONDS`（默认 180）、`SECURITY_QUALITY_HARD_YEARS`（默认 10，等所有者定） | 年报单份的大小与时限；质量检查硬性拦截的年数 | info-backend `e6032c1`、`cd0af51` | 待办 |
| 14 | info 后端容器的内存上限核一下：单份年报最大按 128 MiB 读进内存，再加 PDF 抽取 | 以前单份上限是 40 MB；建库实测峰值约 220 MB，是在小年报上测的 | 同上 | 待办 |
| 15 | 年报抽取接进流程时：抽一份年报约 20 到 75 秒、占一个核；要不要单独的工作进程 | 远程机上实测（小机器，内存紧张时更慢）。现在还没接进任何流程，**暂时不用做任何事** | info-backend `1529b15` | 等段八 |
| 16 | info 的库在跑迁移之前要装好扩展 `uuid-ossp`（`CREATE EXTENSION "uuid-ossp" WITH SCHEMA public`） | info 的迁移链用到 `uuid_generate_v4()`，自己不建扩展；新平台是从空库初始化，不装就在第 6 个迁移上失败。knowledge 的迁移链自己建，不需要 | 2026-09-29 本机联调发现；info-backend 迁移 `20260811_0006` 起 | 待办 |
| 17 | 存储账号的权限核对：info 对自己的桶要能读、写、列；知识服务对 info 的桶只要「按键读对象、按版本读对象」两项，不需要列、不需要写 | 本机联调在这组最小权限下整条链能跑通；桶要开版本保留，登记里带着版本标识 | 2026-09-29 本机联调 | 待办 |
| 18 | info 的配置（可不配，默认开）：`SECURITY_STATEMENT_FALLBACK_ENABLED` | 年报的关键数字表认不出来时，从合并报表取 | info-backend `b8a872f` | 待办 |
| 19 | info 的建库任务变慢、变重：认不出关键数字表的年报每份多花 20 到 75 秒；报表是图片的年报更慢。远程机上实测紫金矿业建一次约 9 分钟，进程常驻内存最高约 1.2 GB（加页数上限之前）、约 0.5 GB（之后） | 工作进程的超时与内存上限要够；与第 14 行一起核 | 同上 | 待办 |
| 20 | investment 的部署清单里这些配置项后端不再读取，可以去掉：`AGENT_V4_TRAFFIC_ENABLED`、`AGENT_PILOT_*`、`AGENT_REDIS_KEY_PREFIX`、`KNOWLEDGE_RETRIEVAL_*` | 旧运行时已删。留着不会出错（后端忽略不认识的配置项），只是没有用 | investment-backend `0c1a030` | 待办 |
| 21 | investment 到知识服务的检索身份绑定（`sunmoonai-investment-knowledge-retrieve`）没有使用方了。**所有者 2026-09-29 定：撤销** | 检索客户端随旧运行时一起删了。工作台经沙箱里的 MCP 访问知识服务，不走这条。撤销时一并处理：知识服务那一侧给它留的绑定与白名单、父仓库里的契约消费锁 | 同上 | 待办。**2026-10-06 暂缓**：新体系里 knowledge 的接收端把 ingest 与 retrieve 两个绑定写死成一对（阶段依赖、校验、运行声明、检查），关掉 investment 这一个会让 knowledge 的阶段图断掉（待办 23 实测 `Disabled dependency: investment-service-identity`）。第 10 步先按原样部署，撤销要先改共用模板，另开一轮 |
| 22 | investment 的数据库权限清单仍然列着旧运行时的表 | 表还在，清单暂时不用改。以后用新的迁移删表时，清单同步改 | 同上 | 待办 |
| 23 | investment 后端镜像变小：去掉了 langgraph、langchain 等依赖（依赖包从 100 多个减到 62 个）；`scripts/`、`eval/` 不再进镜像。info、knowledge 的镜像也不再含 `scripts/` | 重新构建时核对 | investment-backend `0c1a030`、info-backend `d191528`、knowledge-backend `8edc66f` | 待办 |
| 24 | 部署目录里的集成测试把可靠投递的引用改到新路径 `app.infrastructure.messaging.durable_tasks`，然后删掉四个后端里只做转发的旧文件 `app/application/services/durable_tasks.py`。涉及：tpl-app `k8s-deployment/integration/` 4 个文件（`runtime_identity_worker.py`、`test_runtime_identity_lifecycle.py`、`test_runtime_database_policy_pg.py`、`test_runtime_identity_joint.py`）；k8s 仓 `app-platform/scripts/integration/` 2 个文件（`test_info_database_policy_pg.py`、`test_knowledge_database_policy_pg.py`）；三个应用仓若有同样的部署目录，一并查 | 可靠投递的代码挪到了基础设施层。旧路径现在还能用，所以**迁移期间什么都不用改**，这些测试照常能跑 | 工程结构整改 A6 甲，tpl-backend `f27dabe` | 待办（本地助手改引用，远程随后删旧文件）。补丁同第 25 行 |
| 25 | 部署目录里的集成测试 `test_runtime_database_policy_pg.py` 的 `test_api_real_identity_upsert_and_immutable_binding` 要跟着登录服务改：它用 `AuthService("admin")` 构造，并替换登录服务模块里的 `get_postgres`，新后端里这两处都不成立。**由本地助手做**（所有者 2026-09-29 定）：各工位对齐、它的工位拿到新后端之后，打上远程备好的补丁。交接单与补丁：[`handoff-luna/2026-09-29-a6/`](handoff-luna/2026-09-29-a6/README.md) | 登录服务改成经端口引用（A6 乙）。对齐之前它的工位里后端还是旧的，测试照旧能跑 | 工程结构整改 A6 乙，tpl-backend `058c663` | 待办（本地助手） |
| 26 | info 后端：数据库迁移到 `20260929_0013` | 采集申请的两张表、关注清单的两张表（连同第一批十家）、采集批次上多两列（记建库被拒绝） | info-backend `3b5d037` | 待办 |
| 27 | info 的配置（都可不配，有默认值）：`SECURITY_REQUEST_MAX_OPEN`（默认 5）。~~`SECURITY_REQUEST_SOURCES_JSON`、`KNOWLEDGE_WEB_BASE_URL`~~ 2026-09-29 改了名，并入第 36 项的两个共用配置，**这两个旧名字不要再配** | 采集申请 | info-backend `3b5d037`、`c55b2a8` | 待办 |
| 28 | info 的数据库权限清单里加上新的四张表：`api` 身份对 `security_request`、`security_request_requester`、`security_watchlist`、`security_watchlist_log` 要能读写；`worker` 身份对 `security_ingestion` 的新两列要能写 | 不加的话，申请的接口和建库任务记拒绝原因都会被数据库拒绝 | 同上 | 待办（权限清单在部署目录里，归本地助手） |
| 29 | investment 后端：数据库迁移到 `20260929_0012` | 项目表；对话加种类、项目、名字；委托加项目。已有的会话各自归入一个项目 | investment-backend `ef0211c` | 待办 |
| 30 | investment 的数据库权限清单里加上新表 `workbench_projects`：`api` 身份要能读写，`runner` 身份要能读 | runner 每一轮都要读项目所在的机器与目录 | 同上 | 待办 |
| 31 | 沙箱镜像里 Codex 的配置关掉 `multi_agent` 与 `goals` | 子代理与「目标」是账外的：事件不进账、费用不进预算。工作台起线时已经关了，镜像里再关一道 | investment-backend `4897cf4`；[账本](structure-ledger.md) H30 | 待办 |
| 32 | 供给器认得两个新的项：`records_mcp_url`、`records_mcp_token`，并把它们写进沙箱里 Codex 的配置（一个新的工具服务，名字建议 `sunmoon_workbench`） | 专家读本项目别的对话与底稿。供给器不认得之前，investment 这边的开关不要打开 | investment-backend `5098d7b` | 待办 |
| 33 | investment 的配置：`WORKBENCH_RECORDS_MCP_ENABLED`（默认关）、`WORKBENCH_RECORDS_MCP_URL`（沙箱访问工作台这个地址用的，集群内的地址）、`WORKBENCH_RECORDS_MCP_RATE_PER_MINUTE`（默认 60） | 同上。第 32 项做完、在集群上验过之后再打开 | 同上 | 待办 |
| 34 | 沙箱到 investment 后端的网络放行：沙箱要能访问 `/api/mcp/workbench` | 同上。现在沙箱只访问知识服务与会合点 | 同上 | 待办 |
| 35 | 本机的沙箱镜像 `sunmoon/sandbox:dev` 是远程 2026-09-29 按仓库里的 Dockerfile 重新构建的（原来的不在了）。只读用了 `sandbox-platform` 目录，没有改它 | 本机联调要用 | — | 只是告知 |
| 36 | 三个应用后端的配置：`CROSS_APP_SOURCES_JSON`（谁可以把用户带到这里、各自的回跳地址）、`CROSS_APP_TARGETS_JSON`（带用户去哪、各自网页端的地址）。都可不配；写错了启动时就报错。要配的内容：investment 去 info、knowledge；knowledge 去 info；info 去 knowledge；info、knowledge 认 investment 带来的用户，回跳地址写 investment 网页端的地址 | 跨应用跳转。不配的话页面上没有去别的应用的链接，也没有「回到原处」，别的不受影响 | [`cross-app-links`](SDD/architecture/cross-app-links.md)；四个后端 `742fc11`、`c55b2a8`、`966d6d5`、`f99c398` | 待办 |
| 37 | 四个网页端的仓库（模板与三个应用）现在有 `fable` 分支了，原来没有。对齐工位时要把它们算进去 | 远程在这四个仓库里第一次提交 | 同上 | 只是告知 |
| 38 | investment 后端多了一个配置 `WORKBENCH_MODEL_PRICES_JSON`（模型单价）。不配就用代码里带的默认值（`kimi-k3`）。要配的话，网页后端与 runner 两个进程要配成一样的 | 2026-10-04 实时花费 | 同上 | 只是告知；换模型时要配 |
| 39 | info-admin-frontend 现在也有 `fable` 分支了（2026-10-04 第一次提交）。对齐工位时算进去 | 远程第 8 步 | 同上 | 只是告知 |
| 40 | knowledge 后端多了两个配置，都可不配：`KNOWLEDGE_DATASET_TITLE`（默认数据集在数据目录页上叫什么，不配就显示标识）、`KNOWLEDGE_CATALOG_RATE_PER_MINUTE`（数据目录页面接口的限流，默认 120）。没有数据库迁移。数据目录页的「申请入库」要第 36 行的 `CROSS_APP_TARGETS_JSON` 里有 info | 远程第 9 步，knowledge-backend `8c4f5f4` | 同上 | 只是告知 |
| 41 | knowledge-admin-frontend 现在也有 `fable` 分支了（2026-10-04 第一次提交）。对齐工位时算进去 | 远程第 9 步 | 同上 | 只是告知 |
| 42 | 四个后端（模板与三个应用）的镜像要用 2026-10-04 之后的 `fable` 重新构建，才带上「会话在提交后不让对象过期」的修复（账本 H66）。只改了代码，没有新配置、没有数据库迁移。luna 在它自己的分支上为了让真链路走下去而带的同一处改动，要和 `fable` 上的写法一字不差（`postgres.py` 里的 `make_session_factory`），合并时才不冲突 | luna 2026-10-04 在真链路上发现，远程在 `fable` 上修 | 同上 | 待办 |
| 43 | **合并 luna 的分支（`platform-kind-v1`）时要对的一件事**：luna 在它的分支上也修了第 42 行这个故障（所有者 2026-10-04 告知：「它已经修了」），两边各修了一遍，写法多半不同。合并时四个后端的 `app/infrastructure/storage/postgres.py` 会冲突或重复。处理办法：以 `fable` 的为准（`make_session_factory` 一处建会话、测试从那里取、`tests/test_session_config.py` 守着）；先看 luna 那边除了这一行还改了什么（它说过要「先修模板，再同步实例」，可能动了别的文件和测试），有 `fable` 没有的东西逐项判断要不要留；合并后四套测试全跑，`test_session_config.py` 必须是绿的（它会抓出第二处建会话工厂的地方） | luna 与远程各修了一遍 | 合并 luna 的分支时 | **已做** 2026-10-06：合并时四个后端的 `postgres.py` 以 fable 为准（tpl-backend `834dff5`、info `89d6598`、knowledge `f75996b`、investment `a49577a`），四仓 `test_session_config.py` 绿 |
| 44 | luna 的分支 `platform-kind-v1` 远程已看过（2026-10-06），结论和 43 行待办在新体系里的落点见 [`platform-kind-v1-review.md`](platform-kind-v1-review.md)。要点：新体系是另起的一套，旧 `sunmoonai/` 没动；应用钉的是 master 版源码和 master 版的迁移版本；合并方向建议 `platform-kind-v1` → `fable` | 所有者 2026-10-04 让远程先看 | 合并前 | **已做** 2026-10-06：看过，并进了 fable（k8s `997cc610`，父仓 tpl `6579f30`、info `6729dd0`、investment `8bb0a42`、knowledge `116930f`，十二个子仓各一个合并提交）。所有者定：15d 接受；三件任务重排；旧树暂不删；远程接手新体系 |
| 45 | **退役旧的**（所有者 2026-10-06 提）：第 7 步在新集群上人手点通之后，单独一轮：1）旧 kind 三个容器、它的卷、`/data/kind-local-storage` 下旧 Harbor 的数据与镜像——先按 ID 盘点、冷备并核对，再按 ID 删，不用 `prune`；2）新 Harbor 里从旧集群搬来的 `app-images` 项目（relay v1-r3、旧沙箱、旧供给器、旧应用镜像）——现网切到 `platform/` 项目的新镜像并验过后删，再跑一次 Harbor GC | 旧东西占着盘。**2026-10-06 盘点**（本地助手，只读）：在跑的 Harbor 只有一套（`sunmoon-registry.service`，数据 `/data/harbor/platform-kind-v1` 16G，`/mnt/sunmoon-data/harbor` 是同一处）；旧数据两处：`/data/kind-local-storage/harbor` 17G（旧 kind 集群里的 Harbor）、`/var/backups/sunmoon-harbor/host-managed-20260927-v1`（luna 第一次迁移的外置 Harbor 备份，root 700，没量大小）。另有 `sunmoon-space-monitor.timer` 每小时只读查容量 | 第 7 步之后，另批 | 待办 |
| 46 | **部署计划要能查出「Job 名没变但模板变了」**：第 27 轮四个应用的 redis / service-identity Job 因后端镜像换了而撞上 Kubernetes 的「Job 模板不可改」，`application-deployment-plan` 事先没有查出。已把 redis / rabbitmq / identity / service-identity 四种 Job 的名字改成和迁移 Job 一样带后端镜像摘要（镜像一换名字就换）；计划里还应对照已晋级的 Git 对象，凡是同名 Job 而 spec.template 不同就拒绝 | 远程 | 第 10 步之后 | 2026-10-06 记 |
| 47 | **`platform-deploy OBJECT=all` 没有把 ops 控制台三个镜像（pgadmin、redisinsight、flower）发布到 Harbor**，Pod ImagePullBackOff；`service_image_ids` 和阶段图都含它们，发布那一段 failed=0 却没发。第 27 轮续五先手动 `services-publish` 这三项并贴日志查原因 | 远程 | 第 27 轮续五 | 2026-10-06 记 |
| 48 | **应用自己的随机秘密要有显式的轮换入口**：现在 `domain_secrets` 的随机值只在第一次准备时生成，私有文件存在就不动、缺了就拒绝；换格式或轮换只能手工删主备私有文件并 `git rm` 密文候选再暂存（第 27 轮换 investment 的 Fernet 密钥就是这样做的）。应做成 `platform-account-*` 那样带回执的轮换 | 远程 | 第 10 步之后 | 2026-10-06 记 |
