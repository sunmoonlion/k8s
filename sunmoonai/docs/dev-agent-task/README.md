# agent 开发任务

每一层都是同一个模式，各家任务通用：

- `composition/`：本层的组成设计——整体怎么划分、各部分承担什么、彼此怎么交互；
- `components/`：各组成部分，每个部分是一个子任务，内部递归同一模式；叶子任务没有 `components/`。

任何一层用到哪个开发阶段，按 [`dev-agent-standards/`](../dev-agent-standards/) 的规范写。

本任务的生命周期见 [request-lifecycle.md](composition/request-lifecycle.md) 第 5 节；叶子目录名保留阶段编号。
第一层分前端与后端，Agent / runtime 与验收器归后端（所有者 2026-09-14 定）；责任划分依合同第 9 节。

```text
task.md                           任务书（PRD）：初稿，待所有者确认
turns/                            每次派工到交回（turn）：01–03 为模拟补建
composition/                      SDD：前后端的划分与交互、总体设计
components/
├── frontend/
│   ├── composition/
│   └── components/  05-interaction
└── backend/
    ├── composition/
    └── components/  02-intake · 04-agent-execution
                     05-interrupt-resume · 06-acceptance-commit
```

## 从哪里读起

| 要找什么 | 在哪 |
| --- | --- |
| 产品请求生命周期合同 | [`composition/request-lifecycle.md`](composition/request-lifecycle.md) |
| 代码必须遵守的规则（39 条，本平台所有任务共用） | [`composition/constraints.md`](composition/constraints.md) |
| agent 项目的开发流程 | [`components/backend/composition/pipeline.md`](components/backend/composition/pipeline.md) |
| 多方竞争协议（本平台的具体做法） | [`composition/protocol/`](composition/protocol/)；所依据的通用规范见 [`../dev-agent-standards/protocol/`](../dev-agent-standards/protocol/competition-rules.md) |
| 任务书 | [`task.md`](task.md)（初稿，待所有者确认） |
| 开发计划：要建什么、为什么 | [`composition/development-plan.md`](composition/development-plan.md) |
| 与项目无关的通用开发规范 | [`../dev-agent-standards/`](../dev-agent-standards/) |

原 `dev-plan/` 各节的去向见 MIGRATION.md（2026-09-15 删除，原文见提交 `e7ab0e0b`）；`dev-plan/` 已删除，原样存于 tag `dev-plan-final`；门禁脚本在 [`../tools/`](../tools/)。
