# agent 开发任务

每一层都是同一个模式，各家任务通用：

- `composition/`：本层的组成设计——整体怎么划分、各部分承担什么、彼此怎么交互；
- `components/`：各组成部分，每个部分是一个子任务，内部递归同一模式；叶子任务没有 `components/`。
- 子任务目录名是「四位号-短名」，号在同一个父节点下从 `0001` 起递增；本目录是项目本身，不编号。见 [`thread-numbering.md`](thread-numbering.md)。

任何一层用到哪个开发阶段，按 [`dev-agent-standards/`](../dev-agent-standards/) 的规范写。

本任务的生命周期见 [产品合同](product-contract.md) §8。
第一层分前端与后端，Agent / runtime 与验收器归后端；责任划分依合同第 9 节。

```text
thread/                           文档 thread（对一个运行时 thread）→ 文档 turn；两级目录名都是「本地号-运行时 id」
                                  turn 里是任务书 user-message.md、回执 turn.md，交回物按类型放 sdd/、sdp/、uat/
composition/                      SDD：前后端的划分与交互、总体设计
components/
├── 0001-backend/
│   ├── thread/      0001-none：turn 0001–0003
│   ├── composition/
│   └── components/  0001-intake · 0002-agent-execution
│                    0003-interrupt-resume · 0004-acceptance-commit（各有 thread/ 与 composition/）
└── 0002-frontend/
    ├── thread/      0001-none：turn 0001
    └── composition/
```

## 从哪里读起

| 要找什么 | 在哪 |
| --- | --- |
| 产品合同 | [`product-contract.md`](product-contract.md) |
| 代码必须遵守的规则（39 条，本平台所有任务共用） | [`composition/constraints.md`](composition/constraints.md) |
| agent 项目的开发流程 | [`components/0001-backend/composition/pipeline.md`](components/0001-backend/composition/pipeline.md) |
| 多方竞争协议（本平台的具体做法） | [`composition/protocol/`](composition/protocol/)；所依据的通用规范见 [`../dev-agent-standards/protocol/`](../dev-agent-standards/detailed-rules/protocol/competition-rules.md) |
| 每次派工的任务书 | 各 turn 的 `user-message.md`，如 [`thread/0001-none/user-message.md`](thread/0001-none/0001-none/user-message.md) |
| 文档 thread 与文档 turn 怎么编号 | [`thread-numbering.md`](thread-numbering.md) |
| 开发计划：要建什么、为什么 | [`composition/development-plan.md`](composition/development-plan.md) |
| 与项目无关的通用开发规范 | [`../dev-agent-standards/`](../dev-agent-standards/) |

门禁脚本在 [`../tools/`](../tools/)。
