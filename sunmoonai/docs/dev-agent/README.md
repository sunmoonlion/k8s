# agent 开发任务

每一层都是同一个任务目录的模式（见 [turn 的投影](../dev-human/turn-project.md)）：

- `thread/`：一问一答，目录名带种类（prd、sdd、imp、uat）；
- `PRD/`：PRD 类的定稿——要什么、做到什么算满足；**不分模块**；
- `SDD/`：SDD 类的定稿——`architecture/` 划模块，`modules/<模块>/` 就是子任务，内部递归同一模式；
- `rules/`：这一层的约束、纪律与开发提醒（代码规则、开发指导）——四类都要守，所以与上面三样平级；
- 子任务目录名是「四位号-短名」，在同一个 `modules/` 里从 `0001` 起编号；本目录是项目本身，不编号。见 [命名与编号](../dev-human/naming.md)。

```text
thread/0001-prd-none/0001-none/    一问一答：user-message.md · response.md · turn.md · others/
PRD/                              requirement.md（要什么）· development-plan.md
SDD/
├── architecture/                  lifecycle.md（轮廓）· components · channels · trust · engineering
├── constraints.md                 代码必须遵守的规则
├── agent-dev-guide.md
└── modules/
    ├── 0001-backend/              thread/ · PRD/ · SDD/（其 SDD/modules/ 下四个模块）
    ├── 0002-desktop/            Electron 桌面应用
    └── 0003-runtime/            本地 runtime，独立成仓
```

产品合同不在任务目录里：它是[跨节点的权威契约](../product/product-contract.md)，各层走到自己的定稿时，把属于那一层的内容取出来写进定稿，并在合同的「去向」表里登记。第一层分前端与后端，Agent 与 runtime、验收器归后端。

## 从哪里读起

旧开发遗留任务暂存在 [独立待接收清单](../legacy-backlog/README.md)，等新架构讨论后再逐项
接收。本次没有据此改动下面的正式任务树；三部分职责划分不代表放弃 B-S 结构。

| 要找什么 | 在哪 |
| --- | --- |
| 产品合同 | [`../product/product-contract.md`](../product/product-contract.md) |
| 代码必须遵守的规则（39 条，本平台所有任务共用） | [`SDD/constraints.md`](rules/constraints.md) |
| 多方竞争：规则与本平台的做法 | 都在人版：[`../dev-human/competition.md`](../dev-human/competition.md) 与 [`../dev-human/protocol/`](../dev-human/protocol/README.md) |
| 每次派工的用户消息 | 各 turn 的 `user-message.md`，如 [`thread/0001-prd-none/0001-none/user-message.md`](thread/0001-prd-none/0001-none/user-message.md) |
| thread、turn 与模块怎么编号 | [`../dev-human/naming.md`](../dev-human/naming.md) |
| 开发计划：要建什么、为什么 | [`PRD/development-plan.md`](PRD/development-plan.md) |
| 与项目无关的通用开发规范 | [`../dev-human/`](../dev-human/) |

**两边怎么分**：换一个 agent、换一个项目仍然成立的，写进 [`../dev-human/`](../dev-human/)；
本目录只放通用规范在本任务上的具体化，以及只对本任务成立的规定，并链接回所依据的那一条。
standards 不引用任何具体任务。

门禁脚本在 [`../tools/`](../tools/)。
