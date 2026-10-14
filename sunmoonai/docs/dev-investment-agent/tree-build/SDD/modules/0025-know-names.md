# 三个应用改名：knowgather、knowbase、knowmart（0025）

> 状态：所有者 2026-10-14 定名字（「用 knowgather」「knowbase」「我打算用 knowmart」）与做法（「改名要你亲自做，不能让 cursor 做」「让 Qwen 在本地跑」）。远程写方案，**待所有者定第三节的深度后实施**。

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

## 三、要所有者定：改多深

| 方案 | 改什么 | 不改什么 | 风险与成本 |
| --- | --- | --- | --- |
| **甲（推荐）：外壳全改，存数据的名字不动** | 仓、目录、组件名、k8s 对象、镜像、域名、Casdoor 应用与客户端、跨应用键、代码里的应用键与环境变量、文档；`source_app` 的值改成 `knowgather-app`（knowbase 库里一条迁移 `UPDATE`） | 数据库名与用户、桶 `info-originals`、vhost、Redis 前缀、私有目录与备份目录：在 config 里照旧写 `info…` / `knowledge…`，旁边注明「存储名，沿用改名前」 | 不搬数据，切换时只是换部署、换身份；回退简单。缺点：存储层还看得到旧名 |
| 乙：连存数据的名字一起改 | 甲的全部 + 库改名（`ALTER DATABASE … RENAME`、角色改名）、桶复制到 `knowgather-originals` 再删旧桶、vhost 重建、Redis 键改名、私有目录与 SOPS 密文重做、备份目录换名 | 无 | 要停服搬数据；桶里的原文要整体复制并核对；秘密要重新生成并进 SOPS；任何一步出错都要按备份恢复。工作量约是甲的两倍 |
| 丙：只改用户看得见的 | 域名、Casdoor 显示名、页面上的名字 | 其余全部 | 最省事，但仓、目录、配置里仍是 info / knowledge，以后读代码的人会对不上；不推荐 |

推荐甲：名字的作用是让人认得出谁管什么，存储层的名字只有运维脚本看得到；现在是开发期，等哪天重建数据时再顺手换存储名，代价接近零。

## 四、怎么做（甲）

分工：**代码、配置、gitops、迁移、核对全部由远程（Opus）亲手改**；仓改名与同步配置由所有者在 gitee 与本地做（只有所有者有权限）；**必须在所有者本地集群上执行的部分由 Qwen 照远程写的步骤跑，远程逐段审回执**；不经 Cursor。

| 步 | 谁 | 做什么 | 停点 |
| --- | --- | --- | --- |
| 0 | 所有者 | 先发完卡 47、48；通知别的工位暂停碰 info / knowledge | 卡 47、48 上线 |
| 1 | 所有者 | gitee 上把两个仓改名为 `knowgather-app`、`knowbase-app`；`~/five-repos-sync/config.sh` 换仓名；两台机器上各工位的检出目录换名、改 remote | 远程核对各工位 remote 与目录 |
| 2 | 远程 | 两个应用仓内：目录、构建、说明、代码里的应用键与环境变量、`source_app` 迁移；单测、构建全过 | 远程自测通过 |
| 3 | 远程 | k8s：gitops 目录、应用名表、`deploy.yaml` / `verify.yaml`、Casdoor 声明、域名、跨应用；投资后端与网页的跨应用键；渲染比对（除了名字，渲染出的对象逐项相同） | 渲染比对通过 |
| 4 | Qwen（本地） | 备份两个库与桶清单；构建新镜像；**先把旧名字的 API / Worker / Scheduler 停到 0 副本**（甲方案新旧共用同一个库和队列，不能两套同时跑），再部署新名字的应用（新 Casdoor 应用与客户端、新服务身份）；跑 `application-check APP=knowgather / knowbase / investment`；浏览器打开两个新域名能登录、能看到原有数据；投资里跨应用跳转与知识检索可用 | 远程审回执 |
| 5 | Qwen（本地） | 旧名字的对象下线：旧 Deployment / Job / Secret、旧 Casdoor 应用与客户端、Harbor 旧镜像仓库（保留到下一次备份后） | 远程审回执 |
| 6 | 远程 | 文档：PRD / SDD / 决策 / 总览 / 各仓 AGENTS 换名；`decisions.md` 记这次改名 | — |

域名：现在 `info.sunmoonai.com:30443` 只在所有者机器的集群入口上用（边缘公网只放 investment、casdoor、relay）。新域名的解析与证书由 Qwen 在第 4 步核对：通配证书则不用换，否则随部署签新证书。

回退：第 4 步前什么都没碰现网；第 4 步失败，先把新名字的停到 0 副本，旧名字的对象还在（第 5 步才删），把 `sources.yaml` 与应用名表回到改名前的提交、重新发布即可；数据没有搬，不用恢复（`source_app` 那条迁移有对应的回退迁移）。
