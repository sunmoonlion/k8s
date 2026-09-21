# agent 开发任务

把 SunMoonAI 建出来的任务树。每一层都是同一个模式（见 [turn 的投影](../dev-human/turn-project.md)）：

- `thread/`：一问一答，目录名带种类（prd、sdd、imp、uat）；
- `PRD/`：PRD 类的定稿——要什么、做到什么算满足；**不分模块**；
- `SDD/`：SDD 类的定稿，**三样**——`architecture/` 管模块之间的关系，`modules/<模块>.md` 说每块本身是什么，
  `submodules/<模块>/` 是它往下的子任务，内部递归同一模式；
- `rules/`：这一层的约束、纪律与开发提醒——四类都要守，所以与上面三样平级。

模块名是「四位号-短名」，在同一层里从 `0001` 起连续、不复用；`modules/*.md` 与 `submodules/*/` 同号同名。
见 [命名与编号](../dev-human/naming.md)。

```text
PRD/                              requirement.md（要什么）· functions.md（全部 F-*）
rules/                            constraints.md（代码规则，按主题分组）· agent-dev-guide.md
SDD/
├── architecture/                 lifecycle.md（先读：系统长什么样、一条请求怎么走完）
│                                 channels · trust · engineering · objects · task-contract · approval · invariants
├── modules/                      0001-backend.md · 0002-desktop.md · 0003-runtime.md
└── submodules/
    ├── 0001-backend/             其 SDD/ 下再切七块：ledger · router · orchestrator
    │                             bridge · interrupt · acceptance · delivery
    ├── 0002-desktop/             内部划分未定，见其 SDD/architecture/ 的未决
    └── 0003-runtime/             还没开过 SDD turn
```

**第一层三块**，按运行位置、信任域、发布方式切：后端（服务器）、桌面应用与本地 runtime（都在用户电脑上，
但 runtime 碰得到 key 与结果正文、桌面应用碰不到）。官网、管理后台、知识服务与八个既有 Next.js 前端
本轮不开发，见 [本轮范围外](SDD/architecture/lifecycle.md)。

产品合同不在任务树里：它是[跨节点的权威契约](../product/product-contract.md)，各层走到自己的定稿时，
把属于那一层的内容搬进定稿，并在合同的「去向」表里登记。搬走即从合同删除，一条内容只有一处。

两个子任务的内部关系各在自己那一层：
[后端七块](SDD/submodules/0001-backend/SDD/architecture/blocks.md)、
[桌面应用](SDD/submodules/0002-desktop/SDD/architecture/README.md)（内部划分未定）。
