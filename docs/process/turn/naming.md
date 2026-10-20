# 命名与编号

起名字之前先查；模块怎么编号；门禁查什么。一问一答本身**不编号**——见 [turn 的投影](turn-project.md)。

## 起新名之前

**先全仓 `grep` 一遍，撞了就换。**短名、字段名、对象名、目录名都算。

```sh
grep -rin '<新名>' --include='*.md' sunmoonai/docs
```

- 撞的判据不是「同名文件已存在」，而是**这个词在本项目里已经有别的意思**。
  `state` 没有同名文件，但满仓都是 Task 状态、`state_version`、状态机——拿它当模块名指不准。
- 行业里已有固定含义的词同样算撞：`gateway` 是入口、`registry` 是镜像仓库。
  名字得说清这一块是**什么角色**，不是它存着什么。
- 词汇表里的词是冻结的（见 [glossary.md](glossary.md)）：要改，先经所有者确认，然后**一次改遍全仓**——
  文件名、目录名、所有引用、门禁脚本里的常量，一次提交改完。分两次改，中间那一版必然有坏链。
- 改完再全仓 `grep` 一遍旧名，剩零个才算改完。

## `human-ai-turn/` 不编号

值得留的那一问放在 `human-ai-turn/` 下，名字是约定不是规则，里面只有 `user-message.md`（或按 prd、sdd、imp、uat 分子目录各一份）。
**没有本地号、没有运行时 id、没有回执。**引用一问时指文件路径与提交号，不指编号。

## 模块编号

`SDD/modules/` 下是「四位号-短名.md」（每块是什么），`SDD/submodules/` 下是同名目录（往下的子任务），两边一一对应。
**号只在同一个 `modules/` 里递增**，每一层都从 `0001` 起，不跳号、不复用；任务目录本身不编号。模块只在设计侧划，`PRD/` 下没有 `modules/`。

```text
tree-build/                             项目，不编号
├── human-ai-turn/                      可选
├── PRD/requirement.md                  需求：不分模块
├── rules/                              可选：约束、纪律与开发提醒
└── SDD/
    ├── architecture/
    ├── modules/0001-backend.md  0002-desktop.md  0003-runtime.md   每块是什么
    └── submodules/
        ├── 0001-backend/                   子任务：内部同样是 PRD/ + SDD/ + rules/（+ 可选 human-ai-turn/）
        │   └── SDD/submodules/0001-ledger/ 0002-router/ …
        └── 0002-desktop/
```

- 模块目录与实现时 worktree 里的模块目录一一对应；**以定稿为准**：要改结构，先改这里。
- **不在整棵树里统一编号**：那样要有一处统一取号，几个分支同时建模块就会抢号；子树挪了位置，号也跟着失效。
- 跨节点引用时前面带上模块路径，如 `0001-backend/0002-router`。

## 门禁查这几条

[`../tools/doc-gate.py`](../tools/doc-gate.py) 随提交跑，查：

| 查什么 | 判据 |
| --- | --- |
| 模块编号 | 合乎「四位号-短名」，在同一层里从 `0001` 起连续、不复用；`modules/*.md` 与 `submodules/*/` 同号同名一一对应 |
| 链接 | 仓内相对链接的目标必须在 git 索引里。`human-ai-turn/` 下的文件同样查——目录能随手删，死链风险反而更大 |
| 定稿目录 | 有 `SDD/submodules/` 就必须有 `SDD/architecture/`；有 `submodules/<X>/` 就必须有 `modules/<X>.md`（反之不强制）；`PRD/` 下三样都不得有 |

**不查 `human-ai-turn/` 的形状**：它是普通目录。

⚠ 上一版的 `thread/` 原件（编号、字段、冻结）门禁仍按旧规则查，只为防篡改历史——那些目录已退役、不再新增，
见 [`README.md`](README.md)「上一版留下的东西」。
