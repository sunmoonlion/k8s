# R1-opus — 改内容，推到旧名字的仓

- 执行人：Opus（远程机 qwen 工位）
- 时间：2026-10-15 12:00（远程机时间）
- 依据：`k8s/docs/rename.md` R1 节；工具 `k8s/docs/rename-tools/`（`c064cfb4`、`4aded34f`）。

## 1. 怎么做的

1. 先在草稿目录里验证：从 origin 复刻五组仓（含子仓）整套跑 `r1_apply.py`；再按真仓的布局（`~/master/<仓>` 加挂出的工位，子仓的 git 目录在 `.git/worktrees/…/modules/` 下）演练一遍执行和逐仓提交，两次结果逐文件相同。跑完的副本上各仓测试与检查见第 4 节。
2. 真仓：`python3 r1_apply.py ~/worktrees/qwen`（工具从副本运行）→ 用改名后的知识后端重录知识库管理端的预览样例 → 逐仓提交（先子仓后父仓）→ 按 R1 推送块推送。
3. 真仓结果与演练的副本逐文件比对：只差两处——
   - 知识库管理端样例 `full/0002.json` 里录制时间 `superseded_at` 不同（每次录都不同）；
   - `k8s/docs/拓扑.md` 4 行（`knowledge-api / info-api` → `knowbase-api / knowfeed-api`）。原因：git 默认把中文文件名转义输出，复刻里规则对不上路径、跳过了这类文件；k8s 仓配置了 `core.quotepath=false`，真跑时处理到了。已修工具（`4aded34f`，列文件时关掉转义），并把各仓全部 18 个中文名文件过了一遍：只有这一份有要改的内容，4 处改得对。

## 2. 第一版规则的漏改（验证中发现，已补进工具后才真跑）

网页检查与残留盘点暴露的，补规则后整套重跑过：

- 部署配置里不带引号的应用名：`infrastructure/applications/config.yaml` 的 `application_names`、Makefile 的取值表 `$(filter $(APP),tpl info knowledge investment)`、六个 `stage.yaml` 的 `application_name`、`redis_key_pattern: knowledge:*`、`part-of: knowledge` 标签、traefik `service_access_hosts` 的键与模板里的 `'knowledge'`、elk 采集的应用表与按序比对的清单、知识库只读前缀的校验 `^info/`。漏了会在 R5 渲染时直接失败（`stages.py` 按目录名 `<名>-app` 去应用名表里认应用）。
- 校验里按应用名拼出的身份名与作用域：`'sunmoonai-' + application_name + '-knowledge-' + …`、`'knowledge:' + service_relation`；投资→知识库的组织名 `sunmoon-workload-investment-knowledge`；身份描述 `:knowledge:managed-by-gitops`。
- 网页：`.env*` 的 `AUTH_APP`、`NEXT_PUBLIC_APP_NAME`；预览配置与测试里应用名作对象键（`{ info: … }`）、`from=`；投资网页设置里 MCP 来源的键 `mcp_sources.knowledge`（后端 `MCP_SOURCES` 已改 `knowbase`，网页不改，保存设置会被后端拒绝）。
- 开发连接串 `://info:info@` 的口令半边（域名规则先改了用户名）；后端 `scripts/pair_fixture.py` 的 `app=`；`APP_SLUG`、`APP_DB_NAME`、`REDIS_KEY_PREFIX`。
- 放宽范围带出的误改已排除：两处日志级别 `"info"`、traefik CRD 里的 `info:` 字段、Python 参数名 `info: DatasetInfo`。
- 决定记录（`decisions.md`、`owner-decisions-now.md`）、0025、改名卡不再被替换（原话与当时的名字保留）。
- 投资网页样例不重录，只把其中 MCP 服务名 `sunmoon_knowledge` 换成 `sunmoon_knowbase`（278 处），网页测试按新名断言。

## 3. 提交与推送（全部已推到旧名字的仓的 `qwen` 分支；推后逐仓核对 `ahead=0`，两个父仓 GitHub 与 gitee 都是新提交）

| 仓 | 提交 | 改动 |
| --- | --- | --- |
| info-app/knowfeed-admin-frontend | `3f01f34` | 36 个文件 |
| info-app/knowfeed-backend | `ecce5c7` | 92 个文件（含新迁移 `20261015_0014_knowfeed_rename.py`） |
| info-app/knowfeed-web-frontend | `327c526` | 27 个文件 |
| knowledge-app/knowbase-admin-frontend | `1ae7ed7` | 41 个文件（含重录的 4 个样例） |
| knowledge-app/knowbase-backend | `1d8fa10` | 73 个文件 |
| knowledge-app/knowbase-web-frontend | `3fd9312` | 27 个文件 |
| investment-app/investment-admin-frontend | `c3c1e1d` | 15 个文件 |
| investment-app/investment-backend | `a6e6ceb` | 31 个文件 |
| investment-app/investment-web-frontend | `0dd55a5` | 34 个文件 |
| tpl-app/tpl-admin-frontend | `8f8338e` | 4 个文件 |
| tpl-app/tpl-backend | `3c3d252` | 7 个文件 |
| tpl-app/tpl-web-frontend | `3b83285` | 12 个文件 |
| info-app | `1fd9da0` | 22 个文件（`.gitmodules`、子仓目录 `git mv`） |
| knowledge-app | `ba6c77c` | 26 个文件（同上） |
| investment-app | `eb1f800` | 8 个文件 |
| tpl-app | `af00d65` | 5 个文件 |
| runtime | `8cac5ab` | 2 个文件 |
| k8s | `c5905fe2` | 242 个文件（gitops 两个应用目录 `git mv`；旧 `*.sops.yaml` 已 `git rm`；knowfeed 后端 `expected_schema_revision: '20261015_0014'`、`migration_job_revision: v3`） |

`.gitmodules` 里子仓的路径、名字、地址都是新名字（`https://github.com/sunmoonlion/knowfeed-backend.git` 等），R2 改仓名后才有效。

各类替换（只统计原地修改的文件；随目录改名又改了内容的不计）：组件 279 个文件 / 1001 处；应用名 156 / 583；中文里的应用名 133 / 532；MCP 29 / 295；环境变量 56 / 249；域名 42 / 149；配置字段 36 / 145；存储 63 / 117；表与事件 20 / 105；作用域 35 / 84；部署键 17 / 66；cookie 18 / 61；代码名 21 / 58；标题 18 / 26；跨应用身份 14 / 18；页面文案 6 / 14；页面路径 7 / 12；应用身份 3 / 4；锁文件 2 / 2；source_app 1 / 1。

## 4. 测试与检查（在与真仓结果逐文件相同的副本上跑）

| 仓 | 改名后 | 说明 |
| --- | --- | --- |
| knowfeed 后端 | 1144 通过、13 跳过、1 失败、13 出错 | 13 个出错是 `test_schema_readiness` 要 Redis，改名前同样；1 个失败 `test_artifact_contract_payload_validates_against_provider_schema` 按父仓目录名找知识库契约，模拟 R3 的目录名后通过。改名前同一环境 1141 通过、4 失败 |
| knowbase 后端 | 960 通过、9 跳过、0 失败、13 出错 | 13 个出错同上（Redis）。重算契约哈希后契约测试全过 |
| 投资后端 | 1087 通过、5 跳过 | |
| tpl 后端 | 340 通过、5 跳过 | |
| knowfeed 管理端 / 网页 | 69 通过 / 90 通过、2 跳过 | 类型检查、构建通过 |
| knowbase 管理端 / 网页 | 83 通过 / 90 通过、2 跳过 | 同上；管理端用重录的样例 |
| 投资网页 | 263 通过、2 跳过 | 同上；样例只换 MCP 服务名 |
| tpl 网页 | 81 通过、2 跳过 | 同上 |
| k8s `infrastructure` 测试 | 与改名前相同 | 改名后多出的 2 个失败（`test_python_sources` 按 `<名>-app` 找后端）模拟 R3 目录名后通过；其余失败改名前就有 |
| k8s stage 图 | 改名前后一致 | `stages.py graph` 两边各 73 个阶段、41 个对象，名字换算后逐项相同 |
| k8s 提交门禁 | 通过 | doc-gate 62 份活文档、anchor-gate |
| 新迁移 0014 | 通过 | 独立验证：4 表、22 个对象改名，回退复原、再升级正常 |

另核：knowfeed / knowbase 后端 `config.yaml` 的库、角色、vhost、队列、Redis 用户与键前缀、私有与备份目录都等于 `common/backend/prepare.yaml` 按应用名拼出的期望值。

## 5. 留给后面的

- 渲染产物（`workload.yaml`、`kustomization.yaml`、`image.lock.yaml`）里还是旧名字，R5 的 stage 重新生成。
- R5、R6 的逐条命令：Opus 在 R5 开始前填进手册，R5 状态写「可执行」之前 Qwen 不开始 R5。
- 说明文字里个别没换的写法（如 k8s `AGENTS.md` 的「tpl/info/knowledge/investment」），在 R7 文档一并处理。
- 投资网页预览样例整体重录：独立事项，不属于改名。
