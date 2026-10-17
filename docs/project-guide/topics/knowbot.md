# 分身（knowbot）：创建、存放、运行

> 最后更新：2026-10-17 ｜ 设计真源 [0027](../../dev-investment-agent/tree-build/SDD/modules/0027-knowbot-first-path.md)（第一条通路）、[0026](../../dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)（定位与合规） ｜ 规则 [`C-L1`–`C-L5`](../../dev-investment-agent/tree-build/rules/constraints.md#合规)
>
> **现状**：0027 P1–P5 的代码都已写、已测、已推送，**未部署**，随 0027 P6 与改名的集群切换（0028 R5）一起发布：服务身份与内部入口（P1）、单点登录（P1b）、knowmart（P2）、knowlab 的受理、草稿、测试、交付与「我的数据」（P3、P5）、knowbench 的「请分身」（P4 第一部分）、作为运行方有人值守地跑测试（P4 第二部分，0027 §3.4）、分身运行时读用户数据（P5，0027 §3.5）。**不做**：knowlab 后端调模型起草清单（所有者定「暂时不用」，运营照用户的方法手工写清单）。集群里的 knowlab、knowmart 现在还是空应用；运行方只有工作台 knowbench（2026-10-17 由 investment 改名，[0028](../../dev-investment-agent/tree-build/SDD/modules/0028-knowbench-rename.md)）。

## 1. 是什么，谁做什么

分身是**用户的方法工程化之后、用用户自己的数据运行**的那一份东西。逻辑与数据都来自用户，我们只做工程化与测试；分身只归做它的用户，不导出、不分享、不出售（`C-L1`–`C-L5`）。

| 应用 | 职责 | 不做 |
| --- | --- | --- |
| **knowlab** | 网页端：用户提交想法（六问或 skill）、上传数据、给验收用例，看「我在做的分身」与测试报告。后端：创建分身草稿。管理端（网页＋后端，我们的运营）：核规则出处、发起测试、出报告；测试通过才交付 knowmart | 不运行分身；不存工作台的运行结果 |
| **knowmart**（私有模式） | 存放**测试通过**的分身与版本（只插不改）；网页端「我的分身」（列出、停用、从运行方跳来时「请这位」）；给运行方按所有者取清单 | 不存用户数据文件；不运行；不出现市场、上架、购买、价格 |
| **运行方**（现在只有 knowbench 工作台） | 用户「请」自己的分身来跑；给 knowlab 提供无人值守的「跑测试」 | 不改分身清单；不读别人的分身 |

## 2. 一个分身从提交到使用

```text
用户（knowlab 网页端）      提交想法（六问或一份 skill）＋验收用例，同意数据用于测试；上传「我的数据」（PDF、Excel、CSV、文本）
我们（knowlab 管理端网页）  看提交与方法原文，照它手工写分身清单、贴进来建草稿（现在不调模型起草，所有者定「暂时不用」）；
                           清单里每条规则记出处，数据绑定只能指向这个用户自己的、没删的数据 —— 「待测试」
                           逐条核规则出处，核过才能发起测试（预算上限、超时）
knowlab 管理端后端          「测试中」→ 按草稿的运行方调登记的运行方跑测试（我们的测试账号与测试电脑）
运行方（knowbench）         每条用例开一个对话、按草稿快照建委托照常驱动；分身读用户数据经工作台转到 knowlab 读文字
                           跑到要人决定的地方（审批、开步前提问、反问）就报给 knowlab：运营在管理端答，投资判断转给用户，
                           用户在网页端「需要我回答的问题」里答；等人的时间不算超时，最长 3 天
knowlab 管理端后端          收结果（每条用例各步过没过，不含分析内容）
                           ├ 通过：交付 knowmart（版本只插不改，交付即可用）
                           └ 未通过：改清单出新草稿再测；「测试中」超时可退回重跑
用户（运行方，如工作台）    「请分身」→ 跳到 knowmart「我的分身」选一个 → 跳回，运行方向 knowmart 核验并取清单，
                           钉死这一版、缓存在自己库里，用户给输入自己跑；运行时只读这一版绑定的、他自己的数据
```

草稿、测试、报告、改版都属于「创建」，放在 knowlab；knowmart 只放能用的版本，所有读写都按所有者过滤，没有例外（持牌后的对外市场里也只该有正式发布的版本）。

## 3. 运行方：不写死 knowbench

以后的分身不一定都跑在工作台上，所以「谁来运行和测试」是可登记的：

- 分身清单外层必填 `runtime`（运行方，现在是 `knowbench`）。
- 测试协议是 knowlab 定的通用契约 `knowbot-test-run/v1`（真源 `knowlab-app/contracts/knowbot-test-run/v1/`，由 knowlab 后端模型生成）：请求是草稿清单、验收用例、数据绑定、预算上限、超时、最长等人时间；回每条用例的结果（各步验收通过与否、出错处），跑到要人决定的地方状态是 `waiting` 并列出问题，knowlab 用回答接口交回答案（有人值守，0027 §3.4）。测试跑出的分析内容**不给用户**，运行方只短期保留（7 天）供排查。
- 一个应用要成为运行方：实现这个契约，提供统一路径 `/api/internal/v1/knowbot-runtime/test-runs`；在 knowlab 配置里登记（出站服务身份 `<运行方>:testrun`）；在 traefik service-access 开内部入口；向 knowmart 声明自己是「取清单」的调用方。knowlab、knowmart 的代码不用改。
- knowmart 的「取清单」只给运行方是调用方自己的分身；用户从哪个运行方跳来「请」，就只能选运行方是它的分身。

## 4. 应用之间怎么连

跨应用一律走集群内 HTTPS 与服务身份（client credentials），按「调用方 × 目标 × 关系」各一个身份。机制是 [`common/backend/service-client`](../../../gitops/components/app-platform/common/backend/service-client/README.md)：调用方后端 config 的 `service_clients`，接收方的 `service_receivers`（接收方的校验参数从调用方配置推出来）；内部入口在 traefik service-access 的 `service_access_routes`，每个一张独立证书。

| 关系（scope） | 调用方 → 接收方 | 做什么 | 现状 |
| --- | --- | --- | --- |
| `knowmart:deliver` | knowlab → knowmart | 交付测试通过的版本：`POST /api/internal/v1/knowmart/deliveries`（幂等：同交付单号同内容回原结果，不同则 409） | 两端已写 |
| `knowmart:summon` | 运行方（knowbench）→ knowmart | 取清单：`GET /api/internal/v1/knowmart/owners/{所有者}/knowbots/{分身}@{版本}`（所有者由运行方从自己的登录会话里取；不是你的与不存在都是 404） | 两端已写 |
| `knowbench:testrun` | knowlab → 运行方（knowbench） | 跑测试：`POST /api/internal/v1/knowbot-runtime/test-runs`，契约 `knowbot-test-run/v1` | 两端代码已写（有人值守：等人回答的问题报给 knowlab，运营答跑法、用户答投资判断）；测试账号与测试电脑的部署声明已写，随 0027 P6（0028 R5）部署 |
| `knowlab:read` | 运行方（knowbench）→ knowlab | 读分身绑定的用户数据：`POST /api/internal/v1/knowlab/knowbot-data/{list,read}`，契约 `knowbot-data/v1`；运行方先按委托核（委托在跑、数据在这一版的绑定里），knowlab 再按草稿与交付记录核；读出来是文字，按页给 | 两端已写（0027 §3.5） |

接收方的环境变量是 `SERVICE_AUTH_<关系>_CALLERS` 加每个调用方一组 `SERVICE_AUTH_<关系>_<调用方>_*`；校验签名、签发方、受众（调用方 client_id）、精确主体与 scope，通过后知道是哪个调用方。knowbase 那一对旧关系（摄入、检索）仍走旧机制，迁移见待办账 115。

契约：

| 契约 | 真源 | 现状 |
| --- | --- | --- |
| 分身清单 `knowbot-manifest/v1`（外层） | `knowmart-app/contracts/knowbot/v1/`，由 knowmart 后端模型生成，测试核一致；knowlab 持锁 `knowlab-app/contracts/knowmart-knowbot-manifest-lock.json` | 已写 |
| 测试 `knowbot-test-run/v1` | `knowlab-app/contracts/knowbot-test-run/v1/`（请求、结果、回答三份 schema 与 `contract-manifest.json`），由 knowlab 后端 `app/domain/knowbots/test_run.py` 生成，测试核一致；knowbench 持锁 | 两端已写 |
| 读用户数据 `knowbot-data/v1` | `knowlab-app/contracts/knowbot-data/v1/`（列出、读取的请求与结果四份 schema），由 knowlab 后端 `app/domain/knowbots/data_read.py` 生成；knowbench 持锁 `knowbench-app/contracts/knowlab-knowbot-data-lock.json` | 两端已写 |

清单分两层：外层（格式标识、名字与说明、版本、运行方、`data_bindings`、`rule_sources`）归 knowmart，严格校验；里面的 `pack`（步骤、验收、底稿的形状）归运行方，按运行方自己的模型完整校验。摘要是外层规范 JSON 的 sha256（`sha256:<十六进制>`）。

## 5. 用户怎么「请」

- **跳转**：运行方界面点「请分身」，用跨应用链接（业务参数＋`from`＋`ref`）跳到 knowmart「我的分身」；选定后，knowmart 按 `from` 只从自己配置里查登记的回跳地址，带上 `knowbot=<分身>@<版本>` 跳回（链接里带来的地址一概不用）。运行方收到后再按自己的会话向 knowmart 核一次，伪造参数只会得到「找不到」。所有者原话：「我觉得还是跳，这样可以与以后保持一致」。
- **单点登录**：sunmoonai 组织的网页端在 Casdoor 开「保持登录会话」「自动登录」，一处登录处处免登，会话 12 小时；退出时跳 Casdoor 的 `/api/logout`（带 client_id，不存任何令牌）结束会话。管理端不开。已登录着的其他应用本地会话留到自己过期（最长 1 小时），全局单点退出见待办账 114。
- **钉死与缓存**：用户从 knowmart 跳回来时，工作台按会话向 knowmart 核验，把这一版的清单原文与摘要存进钉表（只插不改）；建委托时再把这一版的专家包快照与摘要写进委托，之后编排、底稿、验收都只读委托上的快照。knowmart 暂时不可用只影响新的「请」，不影响在跑的。工作台对分身包另有硬约束：工具与审批只能比平台默认更严、不许命令放行前缀、不许用数据线工具（`C-L2`）。

## 6. 硬边界落在哪

| 边界 | 强制点 |
| --- | --- |
| 投资逻辑只来自用户（`C-L1`） | 清单每条规则带出处；空缺回头问用户；knowlab 管理端发起测试前逐条核过 |
| 运行数据只来自用户（`C-L2`） | 清单 `data_bindings` 列死这一版能读的数据集；工作台按委托只转这些，knowlab 再核数据归属与交付记录（P5，0027 §3.5） |
| 分身只归用户自己（`C-L4`） | knowmart 所有读写按所有者过滤；没有导出、分享、上架入口；版本只插不改，数据库触发器兜底 |
| 测试只测运行正确（`C-L5`） | 报告只有每条用例通过与否和出错处，没有收益、胜率、评级；测试产出的分析内容不给用户 |
| 越权 | 服务身份按关系分、只给对应调用方；身份校验先于数据库会话；所有者只来自服务端会话，浏览器给不了 |

## 7. 代码在哪

| 部分 | 位置 |
| --- | --- |
| knowmart 后端 | `knowmart-backend/app/app/domain/knowbots/`（清单）、`application/services/knowbot_service.py`、`infrastructure/repositories/knowbots.py`、`infrastructure/security/relation_auth.py`、`interfaces/endpoints/knowbot_routes.py`、迁移 `alembic/versions/20261016_0004_knowbots.py` |
| knowmart 网页端 | `knowmart-web-frontend/app/app/[locale]/(dashboard)/knowbots/`、`components/knowbots/`、`contracts/knowbots.ts` |
| knowlab 后端 | `knowlab-backend/app/app/domain/knowbots/`（测试契约、草稿状态与提交形状）、`application/services/knowbot_service.py`、`infrastructure/external/service_client.py`（通用出站客户端）与 `knowbot_clients.py`（运行方登记、交付 knowmart）、`infrastructure/repositories/knowbots.py`、`interfaces/endpoints/knowbot_routes.py`、迁移 `alembic/versions/20261016_0004_knowbots.py` |
| knowlab 用户数据 | 后端 `app/domain/knowbots/datasets.py`（类型、大小、配额、绑定规则）、`application/services/knowbot_data.py`、`infrastructure/storage/object_storage.py`（`application-check` 用它在真实 API 里核对读写）、迁移 `20261016_0005_knowbot_datasets.py`；网页端 `components/knowbots/my-data.tsx`；部署 `knowlab-backend/storage/`、config 的 `object_storage` |
| knowlab 读用户数据（给运行方） | 后端 `app/domain/knowbots/data_read.py`（契约 `knowbot-data/v1` 与分页）、`data_schema.py`（生成 schema）、`application/services/knowbot_data_read.py`（按草稿与交付记录核）、`infrastructure/documents/text_extract.py`（PDF、Excel、CSV、文本抽文字，按 sha256 缓存）、`infrastructure/security/relation_auth.py`（关系 `read`）、`interfaces/endpoints/knowbot_data_routes.py`；部署 knowlab `service_receivers` 与 traefik `service_access_routes.knowlab` |
| knowlab 有人值守 | 后端 `application/services/knowbot_questions.py`、迁移 `20261016_0006_knowbot_questions.py`；管理端 `components/knowbots/open-questions.tsx`；网页端 `components/knowbots/my-questions.tsx` |
| knowlab 网页端、管理端 | 网页端 `app/[locale]/(dashboard)/knowbots/`（我在做的分身、`new` 提交一个想法）、`components/knowbots/`；管理端 `app/[locale]/(dashboard)/knowbots/`（分身草稿）、`components/knowbots/knowbot-drafts.tsx`。管理端导航入口要角色 `admin`/`operator`：身份初始化建好这两个角色、把 built-in 的 admin 放进 `admin`，各应用身份配置给 `ADMIN_AUTH_ROLE_ALLOWLIST=admin,operator`（待办账 98，已写未部署）；部署前直接输入地址进 |
| 部署 | `gitops/components/app-platform/common/backend/service-client/`、各应用后端 `config.yaml` 的 `service_clients` / `service_receivers`、`ingress-platform/traefik/service-access/` |
| 测试电脑 | sunmoon-link 仓 `agent/distribution/build-linux.mjs`（Linux 包）；部署 `knowbench-backend/test-computer/`、`agent-releases/config.yaml` 的 `linux` 一节与 `upload.py --tarball` |
| knowbench 运行方（跑测试） | 后端 `app/domain/workbench/test_runs.py`（契约解析、期望判定、用例结果）、`application/workbench/test_runs.py`（受理、状态、回答、推进器）、`application/workbench/interactions.py`（回答交互、停止委托，网页与测试共用）、`infrastructure/security/relation_auth.py`、`interfaces/endpoints/knowbot_runtime_routes.py`、迁移 `20261017_0020_knowbot_test_runs.py`；锁 `knowbench-app/contracts/knowlab-test-run-lock.json` |
| knowbench 读用户数据 | 后端 `application/workbench/knowbot_data.py`（按委托核）、`interfaces/mcp/workbench_mcp.py`（`list_my_data`、`read_my_data`）、`infrastructure/external/knowlab_data_client.py`；部署 `knowbench-backend/knowlab-read-identity/`；锁 `knowbench-app/contracts/knowlab-knowbot-data-lock.json` |
| knowbench 后端、网页端 | 后端 `app/domain/workbench/knowbots.py`（清单→专家包与硬约束）、`application/workbench/catalog.py`（分身目录、钉住、`pack_for_task`）、`infrastructure/external/knowmart_client.py`、`interfaces/http/web/workbench_expert.py`（`POST /api/workbench/knowbots/pin`）、迁移 `alembic/versions/20261016_0019_knowbot_pins.py`；网页端专家首页「请我的分身」、`components/workbench/knowbot-arrival.tsx`（收回跳）；锁 `knowbench-app/contracts/knowmart-knowbot-manifest-lock.json` |
| 单点登录 | 模板 `tpl-backend` 的 `auth_service.end_session`、两端退出接口与 `logged-out`；`common/backend/identity/provision.py.j2`；Casdoor `config.yaml` 的 `casdoor_session_lifetime_seconds` |
