# `tree-build/` 目录

**把 [九站](../pipeline.md) 一格一格改成脚本的那棵树**——每改一格是树上一个节点,
节点的定稿拼起来就是那条链。
一次一问一答**怎么走**在 [`../turn/`](../turn/README.md),**新人先读那边**。

这里的内容**本项目专有**;那边的规矩跨项目通用。

## 树上每个 turn 的题目

⚠ **只能是两种之一:**

| 可以问 | 例子 |
| --- | --- |
| **某一环节怎么脚本化** | 「受理这一环节怎么建」→ `0002-router`;「交付这一环节怎么建」→ `0007-delivery` |
| **某一环节需要什么料** | 知识服务、方法库、自有数据——它们不是环节,是给「执行」那一格供的料 |

**不能问**「某个领域的业务怎么做」。投资研究怎么做,是这条链**跑起来之后**处理的东西,
不是造它的题目。领域约束(定位、`F-POS-*`、范围)写在树根的 [`PRD/`](PRD/requirement.md),
横向作用于所有节点,但**不是任何一个节点的题目**。

⚠ **造这些 turn 的时候,多数环节还是人在做。**九站里只有「执行」那一格自动化了,
其余都是人。所以:

- **写用户消息时不得假设还不存在的自动化**——不能写「系统会自动验收」,验收那一格现在是人;
- **每改完一格,后续 turn 的写法要跟着变**——派发自动化之后,再写 turn 就不用交代投喂了。

## 每一层都是同一个模式

见 [turn 的投影](../turn/turn-project.md):

- `thread/`：**一串同种类的一问一答**，目录名带种类（prd、sdd、imp、uat）；一问一答是它下面的一个 **turn**；
- `PRD/`：PRD 类的定稿——要什么、做到什么算满足；**不分模块**；
- `SDD/`：SDD 类的定稿，**三样**——`architecture/` 管模块之间的关系，`modules/<模块>.md` 说每块本身是什么，
  `submodules/<模块>/` 是它往下的子任务，内部递归同一模式；
- `rules/`：这一层的代码约束——四类都要守，所以与上面三样平级。

模块名是「四位号-短名」，在同一层里从 `0001` 起连续、不复用；`modules/*.md` 与 `submodules/*/` 同号同名。
见 [命名与编号](../turn/naming.md)。

```text
decisions.md                      还没定的决策点 D*、还没验的事项 ⚠
PRD/
├── requirement.md                要什么、做到什么算满足；定位与 F-POS-*
├── value.md                      核心价值与价值检验、评测集的最小形状
├── knowledge.md                  资料与知识服务（本轮范围外）
└── acceptance.md                 产品验收矩阵 AT-*
rules/constraints.md              代码规则，按主题分组；另有风险与应对、反模式
SDD/
├── architecture/                 components.md 先读：系统由哪几部分组成、本轮建哪三块
│                                 另有 channels · trust · engineering · objects · task-contract
│                                 · approval · invariants · state-machine · routing · profile
│                                 · methods · ownership（谁负责哪些 F-*/I-*/AT-*）
├── modules/                      0001-backend.md · 0002-desktop.md · 0003-runtime.md
└── submodules/
    ├── 0001-backend/             PRD/ · SDD/（内部切七块）· thread/
    ├── 0002-desktop/             PRD/ · SDD/ · thread/；内部划分待定
    └── 0003-runtime/             PRD/；还没开过任何 turn
```

**功能义务 `F-*` 不在这一层**：单模块的在各自模块里，跨两模块的定义放主要承担方那一份。

**第一层三块**，按运行位置、信任域、发布方式切：后端（服务器）、桌面应用与本地 runtime（都在用户电脑上，
但 runtime 独持模型 key、桌面应用独持结果私钥，见 [数据流与信任边界](SDD/architecture/trust.md)）。官网、管理后台、知识服务与八个既有 Next.js 前端
本轮不开发，见 [本轮范围外](SDD/architecture/components.md)。

**需求的真源是 [`PRD/requirement.md`](PRD/requirement.md)**，不另设跨层的产品契约：
一条内容只有一处，要什么就去 `PRD/`，谁负责去 [`SDD/architecture/ownership.md`](SDD/architecture/ownership.md)，
还没定与还没验去 [`decisions.md`](decisions.md)，分期与许可在 [`project-guide/`](../../project-guide/staging.md)。

两个子任务的内部关系各在自己那一层：
[后端七块](SDD/submodules/0001-backend/SDD/architecture/blocks.md)、
[桌面应用](SDD/submodules/0002-desktop/SDD/architecture/structure.md)（内部划分待定，那份里逐项标了现状）。
