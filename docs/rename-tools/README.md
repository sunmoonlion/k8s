# 改名工具（R1 用；k8s/docs/rename.md）

R1 之前由 Opus 在远程机草稿目录里准备，先在从 origin 复刻的五组仓（含子仓，与真仓同结构）上整套跑过、跑完的副本上各仓测试对照过，存这里备查。R1 时照此执行（在工具的副本里跑，不在被改的 k8s 仓里跑）：

```bash
cp -r ~/worktrees/qwen/k8s/docs/rename-tools /tmp/rename-tools
python3 /tmp/rename-tools/r1_apply.py ~/worktrees/qwen     # 改名计划 → 子仓目录 git mv → 其余 git mv → 内容替换 → 手工补丁 → k8s 收尾；不提交、不推送
python3 /tmp/rename-tools/residual.py ~/worktrees/qwen cfg # 残留逐行过（再跑一次 code）
```

`r1_apply.py` 输出里的「残留」行是挪空后还剩未跟踪内容（缓存之类）的旧目录，看过再删。

跑完之后还有一步：知识库管理端的预览样例是知识后端录的，内容里有应用名，要用改名后的知识后端重录（知识后端的 `.venv` 随子仓目录挪了位置，先 `uv sync`）：

```bash
cd ~/worktrees/qwen/knowledge-app/knowbase-backend/app && uv sync
PREVIEW_ADMIN_FIXTURES_OUT=~/worktrees/qwen/knowledge-app/knowbase-admin-frontend/app/preview/fixtures \
  DELIVERY_TEST_DATABASE_URL=<临时库> ENV=test uv run pytest -q tests/test_preview_fixtures.py
```

投资网页的预览样例不重录：它整体早已过时，重录会带进大量与改名无关的变化（另立事项）。样例里工具调用事件带 MCP 服务名，网页测试按新名断言，所以 `manual_patch.py` 只把样例里的 `sunmoon_knowledge` 换成 `sunmoon_knowbase`（278 处），别的不动。

| 文件 | 是什么 |
| --- | --- |
| `rename_rules.py` | 替换引擎：按「改与留的界线」逐类规则 + 保留清单（占位保护）；套到路径上得出要 `git mv` 的目录与文件（**目录下全部跟踪文件都随目录走**，含不在替换范围里的已有迁移、图片、锁文件）；`uv.lock` 只改项目自身名字那一行；冻结件（已有迁移、为 0008 冻结的 `info_identity_v1.py` 扫描）、决定记录（`decisions.md`、`owner-decisions-now.md`）、改名方案 0025 与改名卡不改。应用名作值的规则（带引号的 `'info'`、YAML 键、流式清单、`application_name: info`、Makefile 取值表、标签）只在部署机制、后端代码与测试、网页代码里生效；网页测试与预览配置里应用名作对象键（`{ info: … }`）另有一条 |
| `r1_apply.py` | 真仓执行顺序（见文件头）：子仓目录必须在替换内容之前由父仓 `git mv`，否则 `.gitmodules` 已被改、git 找不到子仓 |
| `manual_patch.py` | 手工补丁：放入新迁移、迁移链清单测试补上它；测历史迁移 0007 / 0008 的测试——把新迁移包在外面、旧结构时段的 SQL 用旧表名、预检挪到降级后、写入前把查找路径限定在本测试的模式；知识库数据集登记测试的期望键；重算知识库契约清单与两个下游锁文件的 sha256；投资网页样例里的 MCP 服务名 |
| `migrations/knowfeed_20261015_0014_rename.py` | 采集后端新迁移：只改结构——四张 `info_*` 表改 `knowfeed_*`，名字带它们的约束 / 索引 / 序列改名（在 `current_schema()` 里找）。不改数据（所有者定：现有数据都不要，新库从空的开始） |
| `tests/test_knowfeed.sh` | 新迁移的独立验证：旧末端 + 模拟行 → 升级 → 回退 → 再升级 |
| `residual.py` | 残留盘点：同一范围、同一保留清单下还单独出现 `info` / `knowledge` 的行 |
| `r3_checkout.sh` | R3 检出换名（一台机器上一组仓：备份、按新名 clone、remote 照旧布局、挂出五个工位）；必须 bash 跑 |
| `r5_render_diff.py` | R5.1 渲染比对：改名前后的渲染产物逐个 k8s 对象比，「原样同名、内容变了」的 Job 单列（有就停） |
| `r5_windows_hosts.ps1` | R5.2 Windows hosts：四个新域名加到旧名所在行；先备份；纯 ASCII（Windows PowerShell 5.1 按 ANSI 读无 BOM 脚本） |
| `r6_cleanup.py` | R6 下线旧对象：清单写死（改名前配置 `4be661df` 抄出的旧名字），默认只列；`delete <类> --confirm <类>` 一次删一类，删前核归属记号、删后再列；不在清单的只列不删 |
| `r6_windows_hosts.ps1` | R6 Windows hosts：从有效行去掉四个旧域名，要求同行已有对应新名字；先备份；可用 `RENAME_HOSTS_FILE` 在副本上演练 |
| `scan.sh` | 盘点用的 grep |

2026-10-15 验证（最终名字 knowfeed / knowbase，采集器仍叫 collector）：新迁移独立验证通过（4 表、22 个对象改名，回退复原）；复刻上整套跑通；stage 图改名前后（名字换算后）一致；各仓测试改名前后对照见 `R1-opus` 回执。

第一版规则在网页检查和残留盘点里暴露过漏改，已补，记在这里免得再犯：部署配置里不带引号的应用名（`application_names: [tpl, info, knowledge, investment]`、`stage.yaml` 的 `application_name: info`、Makefile 的 `$(filter $(APP),tpl info knowledge investment)`、`redis_key_pattern: knowledge:*`、`part-of: knowledge`、traefik `service_access_hosts` 的键）；校验里按应用名拼出的身份名（`'-knowledge-' + service_relation`）；投资→知识库的组织名；网页 `.env*` 的 `AUTH_APP` / `NEXT_PUBLIC_APP_NAME`；预览配置与测试里的对象键；投资网页设置里 MCP 来源的键 `mcp_sources.knowledge`（后端已改 `knowbase`，网页不改会被后端拒绝）；开发连接串的口令半边。
