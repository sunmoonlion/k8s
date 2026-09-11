# 轮次 refact：重写 `working/development-lifecycle-agent.md`

> 本文件是本轮**唯一**的可变参数来源。不变的流程规则在
> [`../../round-protocol.md`](../../protocol/round-protocol.md)，不在这里重复。
>
> ✅ **本轮已于 2026-09-04 发布**：最终稿 1603 行进 master `7fd2bde8`；
> 全流程产物保留在标签 `refact/{luna,kimi,cursor,qwen,integration,baseline-master}`。
> 因各分支已重置到发布点，下面的 `arbiter_branch` 指向标签而非分支，
> 以便 `round-status.py --verify` 事后仍可复算。
>
> ⚠ **本轮开始于 `round-protocol` 改造之前**，产物落在旧路径 `working/` 而非
> `rounds/refact/`；本文件是**回填**的，用于让 `round-status.py` 能判定这一轮。
> 路径迁移不在本轮做——协议自己规定「任务书冻结后不得中途修改」。

```toml
round_id  = "refact"
status    = "DONE"
tier      = "T2"
final_path = "sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md"
round_dir  = "sunmoonai/docs/dev-plan/working"
prefix     = "refact"
baseline   = "f8bc48e3"
proposers  = ["luna", "kimi", "cursor", "qwen"]
arbiter        = "opus"
arbiter_branch = "refact/integration^{commit}"
acceptor       = "qwen"
excused_objection = ["kimi"]
anchor_roots      = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "."]
frozen_sections   = ["5.", "7.", "12.", "13.", "14.", "附录 A", "附录 B"]
mechanical_absent = ["无 Profile 字段表::financial_query|knowledge_retrieve|investment-finance-analysis-v1", "Node 误判不得复活::需要系统 Node(?!.*不得复活)"]
```

## 档位裁定

**T2**，命中两条判据：**权威层**（本文是 `AGENTS.md` 指定「开发 Agent 接任务前必须读取」
的文档，会成为后续开发的依据）与**已知对立**（五份 2026-09-02 提案稿对执行层路线已有互不
相容的主张）。

## 题目与验收标准

题目原文是 `refact-task.md`，该文已随提交 `38d24fda` 从主线删除（内容当时保留在标签
`refact/integration`）。要读原文：

```
git show eb60ff1c:sunmoonai/docs/dev-plan/refact-task.md
```

验收标准是该文 §12 的 11 条，**已冻结**。这一轮的产出经后续几轮吸收，现在的落点是
[`../../agent-dev-refact.md`](../../archive/agent-dev-refact.md)。

## 角色

| 角色 | 谁 | 依据 |
| --- | --- | --- |
| 提案 / 评优 | luna、kimi、cursor、qwen | 任务书 §13 |
| 裁决与整合 | opus（不参赛、不写评审、不验收） | 任务书 §13 |
| 验收 | **qwen** | 裁定 R2：原指定 kimi 经 R1 免除属「不可用」，按顺位 `kimi(4)→qwen(5)→cursor(12)` |
| 确认 | 项目所有者 | 人，手动 |

裁定记录：`refact-integration:sunmoonai/docs/dev-plan/working/refact-rulings.md`（R1、R2、R3）。
**跨分支产物不写成 markdown 链接**——`doc-gate.py` 按当前分支的 git 索引判定，链到别的分支必然失败；
按「取件与检视面」的规矩写「分支:路径」即可。

## 待自动化

按 `round-protocol.md`「执行者与触发方式」，本轮实际由人做、但归类为「可自动」的动作：

| 动作 | 本轮由谁做 | 阻塞点 |
| --- | --- | --- |
| 把「继续」送到各参与方 | 项目所有者手动粘贴 | **阻塞在通道，不在脚本**：cursor 与 qoder(qwen) 是 GUI 应用，无命令行入口；kimi 与 luna 走 VS Code 插件、由 cc-switch 全局切换配置，并行调用会串号。四家里最多覆盖一到两家 |

**空着不等于没有，等于没记**——上表是本轮的自动化欠账，附具体阻塞原因。


## 下游未决项（本轮不做，记录待立轮）

2026-09-04 在协议改造过程中发现的两条，**都属 T2**（权威层 + 不可逆），
不在本轮顺手做——本轮已进 ⑤ 验收，动这些等于中途改题。

### U1 — 两份 lifecycle 文档合并为「一份流程 + 一节人的权力」

`development-lifecycle-agent.md`（1161 行）与 `development-lifecycle-human.md`（823 行）
同构重复约 1984 行，cursor 与 qwen 的评审都指认过。human 版自己的 §10–§18 已标注
「以下各节对人和 agent 同样成立」。

**触发这一条的新事实**：四家助手全部有非交互 CLI（`agent -p`、`qoder -p`、`kimi -p`、
`codex exec`），全部 CLI 化之后，人与 agent 的**入口差异消失**——都是
「收到固定指令 → 跑 `round-status` 定位 → 读落盘通知 → 在自己 worktree 干活 →
按同一命名交付 → 按 commit 冻结」。`round-protocol.md` 从头到尾没有分人和 agent 两套，
就是这个结果。

**但权力差异不消失，也不该消失**：冻结题目与标准、⑥ 确认、省事方向裁定的确认、
推翻裁定、承担最终责任——五条只有人能做，与装多少 CLI 无关。

故目标形态是**一份流程文档 + 一节「人独有的权力与责任」**，不是两份同构文档。

**前置**：CLI 通道打通（`agent` 与 `qoder` 尚未安装、未登录）。
在此之前这条处于 `defined`，不是 `wired`。

### U2 — supervisor 的第四套同名物，与规则骨架共用

本轮裁决稿 §0.3 消歧了三套：调度监督器（控制面确定性代码）、执行监督 Agent
（Attempt 内）、产品子 Task 编排（属 `request-lifecycle.md`），并写明
「三套名字并列写在这里，是为了下一轮整合时不必再撞一次」。

**下一轮就撞出了第四套**：`round-protocol.md` 的轮次组织者。该文件全文仅 1 处
"supervisor"，自称「组织者 / 裁决方」，从未与那三套对齐。

而它与 `development-lifecycle-agent.md` §6「Agent 作为 supervisor」是**同一件事的两个实例**：

| round-protocol | agent 文 §6 |
| --- | --- |
| 轮次组织者 | Agent 作为 supervisor |
| 四家助手 | Work Unit 的执行者 |
| ① 提案 N 家并行 | fan-out 派工 |
| ② 互评 + ③ 裁决 | 收候选、选优、整合 |
| ⑤ 验收、停止规则 | §6.4–6.8 候选隔离、角色分离、评审裁决、停止规则 |

**一处差异不能抹平**：跨厂商 subagent 的独立性是真的（不同训练、不同失败模式），
同 runtime 派生执行者的独立性要靠机制造出来、相关性高。这直接影响
「多家说法一致但都没取证，输给一家带 `file:line` 的」这条规则的含金量——
**同源 subagent 的『一致』信息量低得多，因为它们可能一起错**。
本轮有反例可对照：三家独立走到同一个准确表述（`RunBudget` 生产引用的表述），
那个一致是有含金量的。

**目标**：两处共用规则骨架，差异分别标注；并给第四套定名，与前三套并列。

### U3 — 记一条方法论上的发现

`development-lifecycle-agent.md` 描述的系统在生产里从未实现（`ToolExecutionPort`
生产引用数 0、`AGENT_V4_TRAFFIC_ENABLED: 'false'`），一直停在 `defined`。

而本轮的流程本身——派工、隔离、冻结、互评、裁决、异议、验收——
**就是那份文档的第一个实现**，只是执行体是四个厂商的助手加人，不是它设想的 runtime。

由此它获得了一条此前没有的验证途径：**先在这一层跑通，再往下实现。**
本轮已在真正实现之前逮到三个缺陷：无异议轮、无逾期判据、无裁量留痕——
三条都已补进 `round-protocol.md`。
