# agent 开发任务

每一层都是同一个任务目录的模式（见 [任务的生命周期](../dev-agent-standards/lifecycle.md)）：

- `thread/`：一段段问答，目录名带阶段（brd、prd、sdd、sdp、uat）；
- `PRD/`：BRD 的定稿——`architecture/` 写模块之间的结构与关系，`modules/` 写各模块要满足什么；
- `SDD/`：PRD 的定稿——`architecture/` 与 `modules/`，其中 `modules/<模块>/` 就是子任务，内部递归同一模式；
- 子任务目录名是「四位号-短名」，在同一个 `modules/` 里从 `0001` 起编号；本目录是项目本身，不编号。见 [命名与编号](../dev-agent-standards/naming.md)。

```text
thread/0001-prd-none/0001-none/    一问一答：user-message.md · response.md · turn.md · others/
PRD/                              development-plan.md · architecture/ · modules/
SDD/
├── architecture/                  前后端的划分与交互、总体设计
├── constraints.md                 代码必须遵守的规则
├── agent-dev-guide.md
└── modules/
    ├── 0001-backend/              thread/ · PRD/ · SDD/（其 SDD/modules/ 下四个模块）
    └── 0002-frontend/
protocol/                          多方竞争协议在本平台的具体做法
```

产品合同不在任务目录里：它是[跨节点的权威契约](../product/product-contract.md)，各层走到自己的定稿时，把属于那一层的内容取出来写进定稿，并在合同的「去向」表里登记。第一层分前端与后端，Agent 与 runtime、验收器归后端。

## 从哪里读起

| 要找什么 | 在哪 |
| --- | --- |
| 产品合同 | [`../product/product-contract.md`](../product/product-contract.md) |
| 代码必须遵守的规则（39 条，本平台所有任务共用） | [`SDD/constraints.md`](SDD/constraints.md) |
| agent 项目的开发流程 | [`SDD/modules/0001-backend/SDD/pipeline.md`](SDD/modules/0001-backend/SDD/pipeline.md) |
| 多方竞争协议（本平台的具体做法） | [`protocol/`](protocol/)；所依据的通用规范见 [`../dev-agent-standards/protocol/`](../dev-agent-standards/detailed-rules/protocol/competition-rules.md) |
| 每次派工的用户消息 | 各 turn 的 `user-message.md`，如 [`thread/0001-prd-none/0001-none/user-message.md`](thread/0001-prd-none/0001-none/user-message.md) |
| thread、turn 与模块怎么编号 | [`../dev-agent-standards/naming.md`](../dev-agent-standards/naming.md) |
| 开发计划：要建什么、为什么 | [`PRD/development-plan.md`](PRD/development-plan.md) |
| 与项目无关的通用开发规范 | [`../dev-agent-standards/`](../dev-agent-standards/) |

门禁脚本在 [`../tools/`](../tools/)。
