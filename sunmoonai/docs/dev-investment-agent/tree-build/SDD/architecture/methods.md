# 方法与专家包

> 方法收在工作台，随专家包版本化；下发给 Codex 的只有当前这一步。谁来编排见 [`0001-workbench`](../modules/0001-workbench.md)。

## 方法怎么到 Codex

```text
专家包（工作台）── 这一步的方法文本 + 工具清单 ──▶ turn 输入（②）──▶ 沙箱里的 Codex
                                                       └── MCP 工具（⑥）──▶ 知识服务
```

- **文本**随 turn 输入注入，只给这一步；
- **工具**在知识服务侧，每步 turn 注册这一步允许的清单；换步换清单；
- **判据、阈值、为什么**留在工作台的验收规则里，不进注入面；
- 注入文本不出现下一步的线索。

旧树"runtime 代理 MCP 回后端二次校验"那条链退役：循环在沙箱里，工作台是它的唯一客户端，本来就看得到每次调用。

### MCP 与 skills：自己建内容，经 Codex 配置接入（探针 `REPORT-2026-09-24-skills-mcp-resolution.md`）

| 东西 | 谁建 | 配在哪 | 备注 |
| --- | --- | --- | --- |
| 知识服务 MCP（HTTP） | 我们（`0006`） | 沙箱 `config.toml` 的 `[mcp_servers.sunmoon]`，`bearer_token_env_var` 指向按用户注入的 token，由镜像入口脚本生成 | **鉴权在服务端按 token 范围逐调用做**，不靠 Codex 的工具列表过滤（tools/list 在 thread 开头取一次，换步不保证重取） |
| `sunmoon-data` skill：怎么用我们的数据、口径、引用格式、底稿模板 | 我们 | 沙箱 `CODEX_HOME/skills/`，随镜像版本 | 第一层自驾就生效，这就是价值检验的 B 臂 |
| 专家包方法（每一步做什么） | 我们 | **不是 skill**，工作台按步注入 turn 输入 | 做成 skill 等于整包交出去 |
| 用户项目里的 `.agents/skills/`、`AGENTS.md` | 用户 | 跟着 cwd，经 exec-server 从用户机器读 | 已验可见 |
| 用户全局 `~/.codex/skills/`、模型与审批偏好 | 用户 | **不生效**：app-server 只读沙箱自己的 `CODEX_HOME` | 偏好经网页设置页写进沙箱配置；全局 skills 第一期放项目里，同步进沙箱是后续功能 |
| 用户自己的 HTTP MCP | 用户 | 执行端 `CODEX_HOME` 的 `[mcp_servers]`（编排端专门读这一段）；执行端 `CODEX_HOME` 是代理的，不是用户的 `~/.codex`，代理要合并过去 | stdio 型未验，预计起在沙箱端 |

## 编排就是逐步发 turn

顾问不调模型（`C-A9`）。它做的事：读游标，取步骤契约，组装 turn 输入，发 `turn/start`，等 `turn/completed`，取交回物，做确定性检查，需要语义判断的派验收 turn，按 `on_reject` 决定下一步。一个 Task 的全部 turn 在同一个 thread 上。

## 专家包

```text
pack_id + version（签名）
profile_ref                      对应的 Task Profile
workflow[]                       步骤序列与 step_contract
method_texts{step_id: ref}       版本化的方法文本
tools{step_id: [mcp_tool]}
auto_allow                       顾问驾驶时自动放行的工具级动作
acceptance_rules                 确定性检查 + 验收 turn 的提示
quality_signals[]                自驾时触发求助提示的规则
eval_set_ref                     发布门用的评测集
answers                          六问：解决什么、需要什么、不解决什么、何时完成、何时拒绝或交回、效果与成本
```

真人专家写包；包里只写研究步骤与计算方法，不写判断规则（`F-POS-02`）。改包必须过发布评测（`0007-eval`）。

## 编排不构成保密

每一步的文本在下发那次仍可见；重复观察能重建序列。真正抄不走的是数据、服务端计算与口径、评测闭环（[价值](../../PRD/value.md)）。

## 最小实例

第 23 到 25 课的问数五阶段做第一份专家包：`rewrite → sql_generate → sql_execute → normalize → final`。每阶段一步一个 turn；SQL 执行是知识服务上的 MCP 工具；真值是 `truth_queries` 加 `result_fingerprint`。它用来把机制跑通，之后换成勾稽切口。

**跨 Task 上下文**：项目背景、偏好、历史决定由工作台记在 Session 与 Task 上；长期记忆不做（第一期）。
