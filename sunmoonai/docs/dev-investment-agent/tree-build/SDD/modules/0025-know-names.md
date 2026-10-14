# 三个应用改名：knowgather、knowbase、knowmart（0025）

> 状态：所有者 2026-10-14 定名字（「用 knowgather」「knowbase」「我打算用 knowmart」）与做法（「改名要你亲自做，不能让 cursor 做」「让 Qwen 在本地跑」）。同日所有者定深度：**乙，连存数据的名字一起改**（「用乙」）。远程写方案并实施代码与配置；本地集群上的切换与数据搬迁由 Qwen 照远程写的步骤跑。

## 一、名字

| 现在 | 改成 | 管什么 | 域名（网页 / 管理端） |
| --- | --- | --- | --- |
| `info-app` | **`knowgather-app`** | 采集：从公开来源取原文、登记数据集 | `knowgather.sunmoonai.com` / `knowgather-admin.sunmoonai.com` |
| `knowledge-app` | **`knowbase-app`** | 加工入库：把采集来的东西抽取、切分、索引，供检索 | `knowbase.sunmoonai.com` / `knowbase-admin.sunmoonai.com` |
| `advisor-app`（0018，只有骨架） | **`knowmart-app`** | 知识市场：上架、购买知识；专家是第一种上架的知识（请专家 = 买知识） | `knowmart.sunmoonai.com` / `knowmart-admin.sunmoonai.com` |

一条链：**knowgather 采集 → knowbase 加工入库 → knowmart 上架卖**。组件照现有规矩：`<名>-app/<名>-backend`、`<名>-web-frontend`、`<名>-admin-frontend`。knowmart 还没有代码和部署，直接用新名字建，不算迁移；0018 里的 advisor 一并改。

「knowledge」作普通词的地方不改：投资工作台的「本地知识库」、专家的「云上知识库」、MCP 工具里的知识检索，都是概念，不是应用名。

## 二、影响面（2026-10-14 盘点）

| 类 | 例子 | 量 |
| --- | --- | --- |
| 仓 | gitee `sunmoonlion/info-app`、`knowledge-app`；五仓同步脚本 `config.sh` 的仓名表；两台机器上每个工位的检出目录（五仓必须并列） | 2 仓 × 6 工位 × 2 台 |
| 仓内目录与说明 | `info-backend/`、`info-web-frontend/`、`info-admin-frontend/`，`mybuild/`、`.cursor/rules`、`AGENTS.md` | 约 60 个文件 |
| gitops 与部署机制 | `gitops/components/app-platform/info-app/…`；`infrastructure/applications/` 的应用名表与 `deploy.yaml` / `verify.yaml` 里写死的 `'info'`、`'knowledge'`；`sources.yaml` 两块 | 约 55 个文件 |
| k8s 对象名 | `info-api`、`info-worker`、迁移 Job、`<app>-knowledge-service` Secret 等，都由应用名派生 | 随应用名自动变 |
| 镜像 | Harbor 里 `info-*`、`knowledge-*` 镜像仓库 | 6 个镜像仓库 |
| 身份（Casdoor） | 应用 `sunmoonai-info-web/admin`、客户端 `sunmoon-kind-info-web/admin` 与回调地址；服务身份 `sunmoonai-info-knowledge-ingest`、组织 `sunmoon-workload-info-knowledge`、作用域 `knowledge:ingest`；knowledge 那边对应一套 | 每个应用 3–4 个 |
| 跨应用 | 投资、knowledge 的 `CROSS_APP_TARGETS` 键 `info` / `knowledge`；网页 `lib/cross-app/destinations.ts`；后端 `domain/cross_app.py`；`ALLOWED_HOSTS` | 约 10 处 |
| 代码里的应用键与变量 | `KNOWLEDGE_APP_SERVICE_*`、`KNOWLEDGE_RETRIEVAL_SERVICE_*`、`KNOWLEDGE_APP_DATASET_URL`、`knowledge_service` 配置键、`source_app='info-app'` | 约 30 处 |
| **已存的数据** | 数据库 `info` / `knowledge` 与用户 `*_runtime` / `*_migrator`；对象存储桶 `info-originals`（采集的原文）；RabbitMQ vhost `info` / `knowledge` 与队列；Redis 键前缀 `info:*`；knowledge 库里每条入库记录的 `source_app='info-app'`；所有者机器上的私有目录 `/etc/sunmoon/applications/sunmoon-kind/info`（秘密）与备份目录 | 见第三节 |
| 文档 | `k8s/sunmoonai/docs` 下 PRD / SDD / 决策 / 历史回执 | 约 80 份；历史回执与冻结原件不改 |

## 三、改多深：定为乙（所有者 2026-10-14）

| 方案 | 改什么 | 不改什么 | 风险与成本 |
| --- | --- | --- | --- |
| 甲：外壳全改，存数据的名字不动 | 仓、目录、组件名、k8s 对象、镜像、域名、Casdoor 应用与客户端、跨应用键、代码里的应用键与环境变量、文档；`source_app` 的值改成 `knowgather-app`（knowbase 库里一条迁移 `UPDATE`） | 数据库名与用户、桶 `info-originals`、vhost、Redis 前缀、私有目录与备份目录：在 config 里照旧写 `info…` / `knowledge…`，旁边注明「存储名，沿用改名前」 | 不搬数据，切换时只是换部署、换身份；回退简单。缺点：存储层还看得到旧名 |
| **乙（定）：连存数据的名字一起改** | 甲的全部 + 库改名（`ALTER DATABASE … RENAME`、角色改名）、桶复制到 `knowgather-originals` 再删旧桶、vhost 重建、Redis 键改名、私有目录与 SOPS 密文重做、备份目录换名 | 无 | 要停服搬数据；桶里的原文要整体复制并核对；秘密要重新生成并进 SOPS；任何一步出错都要按备份恢复。工作量约是甲的两倍 |
| 丙：只改用户看得见的 | 域名、Casdoor 显示名、页面上的名字 | 其余全部 | 最省事，但仓、目录、配置里仍是 info / knowledge，以后读代码的人会对不上；不推荐 |

远程原推荐甲（不搬数据）；所有者定乙：改完以后存储层也不再出现 info / knowledge，一次到位。代价是要停服搬数据，所以第四节多了备份、搬迁、核对三道。

## 四、怎么做（乙）

分工：**代码、配置、gitops、搬迁脚本、核对全部由远程（Opus）亲手写**；仓改名与同步配置由所有者在 gitee 与本地做（只有所有者有权限）；**必须在所有者本地集群上执行的部分由 Qwen 照远程写的步骤跑，远程逐段审回执**；不经 Cursor。

### 4.1 存数据的名字怎么换

| 存储 | 改名前 | 改名后 | 怎么换 | 核对 |
| --- | --- | --- | --- | --- |
| PostgreSQL 库 | `info`、`knowledge` | `knowgather`、`knowbase` | 停服后 `ALTER DATABASE … RENAME TO …`（不复制数据） | 各表行数改名前后相同；`alembic current` 不变 |
| 库角色 | `info_runtime`、`info_migrator`、`knowledge_runtime`、`knowledge_migrator` | `knowgather_*`、`knowbase_*` | `ALTER ROLE … RENAME TO …`，随后按新名重设口令（口令随秘密重做） | 新角色能连、权限与改名前相同 |
| 对象存储桶 | `info-originals`（采集原文），knowledge 侧的桶 | `knowgather-originals`，knowbase 侧对应新桶 | 建新桶 → 整桶复制 → 逐对象核对数量与校验和 → 库里记着桶名的行一并 `UPDATE` → 新服务跑通后旧桶保留到下一次备份再删 | 对象数、总字节、抽样校验和一致；库里不再出现旧桶名 |
| RabbitMQ | vhost `info` / `knowledge`、用户、队列 `info.default` | `knowgather` / `knowbase` vhost、用户、`knowgather.default` | 停服前先等队列排空；新建 vhost、用户、队列；旧的删 | 旧队列切换前为空；新队列能收发 |
| Redis | 键前缀 `info:*`、用户 `info_runtime` | `knowgather:*`、`knowgather_runtime` | 新建用户与 ACL；旧键是缓存与锁，**不搬**，切换后让它过期或清掉（实施时逐个确认没有只存在 Redis 里的业务数据） | 新用户只能碰新前缀 |
| 秘密 | 私有目录 `/etc/sunmoon/applications/sunmoon-kind/info`、`…/knowledge` 与各 `*.sops.yaml` | `…/knowgather`、`…/knowbase` | 按新名重新生成（照现有 bootstrap / provision 任务的做法，revision 加一），进 SOPS；旧目录保留到切换验收后再删 | 新密文能解、旧明文不进 Git |
| 备份目录 | `/mnt/sunmoon-data/backups/applications/sunmoon-kind/info` 等 | `…/knowgather`、`…/knowbase` | 新目录起用；切换前那份备份留在旧目录不动 | — |
| 已存的引用 | knowbase 库里入库记录的 `source_app='info-app'`；投资里若存了跨应用地址 | `knowgather-app` | 一条数据迁移（带回退迁移） | 库里不再出现旧值 |

### 4.2 步骤

逐条命令、每段停点与各角色分工见执行手册 [`k8s/docs/rename.md`](../../../../../../docs/rename.md)（R0–R7），执行以手册为准。

| 步 | 谁 | 做什么 | 停点 |
| --- | --- | --- | --- |
| 0 | 所有者 | 先发完卡 47、48；通知别的工位暂停碰 info / knowledge | 卡 47、48 上线 |
| 1 | 所有者 | gitee 上把两个仓改名为 `knowgather-app`、`knowbase-app`；`~/five-repos-sync/config.sh` 换仓名；两台机器上各工位的检出目录换名、改 remote | 远程核对各工位 remote 与目录 |
| 2 | 远程 | 两个应用仓内：目录、构建、说明、代码里的应用键与环境变量、`source_app` 与桶名的数据迁移；单测、构建全过 | 远程自测通过 |
| 3 | 远程 | k8s：gitops 目录、应用名表、`deploy.yaml` / `verify.yaml`、存储名（库、角色、桶、vhost、Redis、私有目录、备份目录）、Casdoor 声明、域名、跨应用；投资后端与网页的跨应用键；渲染比对（除了名字，渲染出的对象逐项相同）；写好第 4–6 步给 Qwen 的逐条步骤 | 渲染比对通过 |
| 4 | Qwen（本地） | **备份**：两个库 `pg_dump`、两个桶的对象清单与校验和、私有目录打包（不出机器）；记行数与对象数 | 远程审：备份完整 |
| 5 | Qwen（本地） | **停服与搬迁**：旧名字的 API / Worker / Scheduler 停到 0 副本、等队列排空；按 4.1 改库名与角色、复制桶并核对、建新 vhost 与 Redis 用户、生成新秘密；跑数据迁移 | 远程审：行数、对象数、校验和一致 |
| 6 | Qwen（本地） | **起新服**：构建新镜像、部署新名字（新 Casdoor 应用与客户端、新服务身份）；`application-check APP=knowgather / knowbase / investment`；浏览器打开两个新域名能登录、能看到原有数据；投资里跨应用跳转与知识检索可用 | 远程审回执 |
| 7 | Qwen（本地） | **下线旧的**：旧 Deployment / Job / Secret、旧 Casdoor 应用与客户端、旧 vhost 与 Redis 用户；旧桶、旧私有目录、Harbor 旧镜像仓库保留到下一次备份后再删 | 远程审回执 |
| 8 | 远程 | 文档：PRD / SDD / 决策 / 总览 / 各仓 AGENTS 换名 | — |

域名：现在 `info.sunmoonai.com:30443` 只在所有者机器的集群入口上用（边缘公网只放 investment、casdoor、relay）。新域名的解析与证书由 Qwen 在第 6 步核对：通配证书则不用换，否则随部署签新证书。

回退：第 4 步前什么都没碰现网。第 5 步做了一半：库与角色改回旧名（`RENAME` 可逆）、旧桶没删、旧秘密目录没删，旧部署恢复副本即可。第 6 步失败：新名字停到 0 副本，库与角色改回旧名、数据迁移跑回退迁移，`sources.yaml` 与应用名表回到改名前的提交、重新发布；实在不行用第 4 步的备份恢复。
