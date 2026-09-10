# dev-plan — 代码要符合什么、接下来建什么

> 最后更新：2026-08-29

本目录管**开发**。判据是：**改了这里的东西，代码要跟着改。**

项目现在长什么样在 [`../project-guide/`](../project-guide/)（那里改了，
只说明代码先变了）；我们怎么共事在 [`working/`](working/)（那里改了，
代码不用动）。

| 文件 | 内容 | 什么时候读 |
| --- | --- | --- |
| [`constraints.md`](constraints.md) | **代码必须符合的规则**，39 条按数据/契约/身份/拓扑/发布/智能体分组，每条标注谁在执行 | **动代码前** |
| [`development-plan.md`](development-plan.md) | 要建什么、为什么这么建：起点、智能体通用/专用两分、四本账、执行层租用、三个阶段 | 想知道方向时 |
| [`implementation-plan.md`](implementation-plan.md) | **任务本体**：每件事怎么做、怎么算做完。条目格式、测试层次、交付规则 | 要动手时 |
| [`handoff.md`](handoff.md) | **状态与交接**：当前阶段、已就位的、未决项 U1–U5、不能倒退的输入 | 接手时先读 |
| `~/codex-reference-archive/` | **各助手的历史调研材料**（仓外，按助手分目录：`cursor/` `kimi/` `luna/` `opus/` `qwen3.8/`）：Codex 机制、SQLBot、WrenAI、沙箱、现状诊断。**已归档，可直接读**——不再是提案期的独立材料，引用时注明是谁的稿 | 定 U1–U5 时 |
| [`agent-dev-guide.md`](agent-dev-guide.md) | **现行开发规范，这条谱系唯一的活文档**：不可变契约、运行时结构与**执行层/SDK 适配**、Task 执行与**并发处置**、人介入/权力表/**三道门与四档审批**、证据与等效、成本与绕过、演进路线、**反模式与失败实例**、词汇对照、Task 模板。§10 是四份源稿的逐节落点表（182 行） | 想知道系统怎么搭、怎么干活时 |
| [`archive/`](archive/) | **一条谱系的历史稿**：两份 lifecycle → `refact-fable` → `runtime-architecture` → 分叉为 `agent-dev-refact` 与现行的 `agent-dev-guide`。分两格——甲格已有逐节落点收据，乙格 197 节**还没有**，待 `dev-plan-refact` 轮并入。无规范效力 | 追溯来龙去脉时；`archive/README.md` 有轨迹图 |
| [`protocol/`](protocol/) | **流程规范 + 它的实现，放在一起**：`round-protocol.md`（七环节、档位 T0/T1/T2、裁量权与方向不对称、产物落点、环节判定、立判据的人怎么约束自己）与 `round-status.py` / `agents.toml` | 开一轮多家并行出稿前；跑流程脚本前 |
| [`anchor-gate.py`](anchor-gate.py) | **锚点门禁**：`doc-gate` 只查 markdown 链接，查不到 `` `文件.md:行` `` 这类纯文本锚点——实测删掉被引文件后 `doc-gate --all` 仍报通过。本脚本补这一类：钉 commit 的锚在该 commit 内解析、裸路径锚对当前索引与外部取证仓解析、`rounds/**` 按归档软判 | 删或改被引用的文档前 |
| [`scripts/check-no-owner-creds.sh`](scripts/check-no-owner-creds.sh) | **凭据卫生检查**（不是边界——本机 agent 可 `sudo`，能改它）：扫明文凭据、无口令 key、主仓是否对本机可写、提权面 | 边界变更前后 |
| [`doc-gate.py`](doc-gate.py) | **文档不变量门禁**：仓内链接、章节引用、表格列数。由 `.githooks/pre-commit` 自动触发，不需要谁记得跑；`--survey` 巡检全仓、`--selfcheck` 查是否已安装 | 不用主动读；提交文档时它自己会说话 |

## 各文档的分工，别混写

| | 写什么 | 不写什么 |
| --- | --- | --- |
| `constraints.md` | 必须遵守的 | 现状、计划 |
| `agent-dev-guide.md` | **架构与开发纪律：怎么搭、怎么干、为什么** | 任务清单、进度 |
| `development-plan.md` | 目标与理由 | 进度、任务 |
| `implementation-plan.md` | 任务：怎么做、怎么算做完 | 状态叙述、架构论证 |
| `handoff.md` | **状态**：做到哪、卡在哪、什么不能倒退 | 论证与实施步骤 |

混写的后果是具体的：论证和状态放一起，读计划的被状态打断，查进度的要翻过论证；
规则和计划放一起，两边都不好用。
