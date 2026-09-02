# dev-plan — 代码要符合什么、接下来建什么

> 最后更新：2026-08-29

本目录管**开发**。判据是：**改了这里的东西，代码要跟着改。**

项目现在长什么样在 [`../project-guide/`](../project-guide/)（那里改了，
只说明代码先变了）；我们怎么共事在 [`../working/`](../working/)（那里改了，
代码不用动）。

| 文件 | 内容 | 什么时候读 |
| --- | --- | --- |
| [`constraints.md`](constraints.md) | **代码必须符合的规则**，39 条按数据/契约/身份/拓扑/发布/智能体分组，每条标注谁在执行 | **动代码前** |
| [`development-plan.md`](development-plan.md) | 要建什么、为什么这么建：起点、智能体通用/专用两分、四本账、执行层租用、三个阶段 | 想知道方向时 |
| [`implementation-plan.md`](implementation-plan.md) | **任务本体**：每件事怎么做、怎么算做完。条目格式、测试层次、交付规则 | 要动手时 |
| [`handoff.md`](handoff.md) | **状态与交接**：当前阶段、已就位的、未决项 U1–U5、不能倒退的输入 | 接手时先读 |
| [`codex-reference/`](codex-reference/) | **本分支自己的调研材料**：Codex 机制、SQLBot、WrenAI、沙箱、现状诊断。各分支只放自己写的那份——并行提案时不该互相看见 | 定 U1–U5 时 |
| [`agent-discipline.md`](agent-discipline.md) | 多助手协作的行为规范：三种模式、隔离原则、提案包构造、评审两阶段、吸收处置 | 让多个助手并行做事时 |
| [`parallel-proposals.py`](parallel-proposals.py) | 上一条的自动化实现，隔离由机制保证 | 同上 |

## 三份文档的分工，别混写

| | 写什么 | 不写什么 |
| --- | --- | --- |
| `constraints.md` | 必须遵守的 | 现状、计划 |
| `development-plan.md` | 目标与理由 | 进度、任务 |
| `implementation-plan.md` | 任务：怎么做、怎么算做完 | 状态叙述、架构论证 |
| `handoff.md` | **状态**：做到哪、卡在哪、什么不能倒退 | 论证与实施步骤 |

混写的后果是具体的：论证和状态放一起，读计划的被状态打断，查进度的要翻过论证；
规则和计划放一起，两边都不好用。
