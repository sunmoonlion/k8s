# 命名与编号

thread、turn 与模块的目录名怎么起、号怎么排、与运行时怎么对。生命周期本身见 [任务的生命周期](lifecycle.md)。

只用四个词：**文档 thread**、**文档 turn**（我们的记账单位，就是下面这些目录）、**运行时 thread**、**运行时 turn**（执行环境里的东西，只有 id）。

## 名字

**thread 目录名 = 四位本地号 + 阶段 + 运行时 id；turn 目录名 = 四位本地号 + 运行时 id。**

```text
0003-sdd-01k8f3m2qz          0002-01k8h9t1cc
└┬─┘ └┬┘ └────┬───┘          └┬─┘ └────┬───┘
 │    │       └ 运行时 thread id       └ 运行时 turn id
 │    └ 阶段：brd · prd · sdd · sdp · uat
 └ 本地号：排先后、给人引用
```

- 本地号与运行时 id 合起来唯一——这是唯一性的全部来源。
- 本地号四位数字，按派出顺序递增，从 `0001` 起，**不跳号、不复用**；中断、失败、被替换的照样占住自己的号。
- id **写全不截断**；执行环境不给 id 的写 `-none`。
- 派出时可以先不带 id；**写 `turn.md` 时必须已经带上**，turn 与它所在的 thread 都要带。
- 改名只发生在交回之前。带了 `turn.md` 的目录连同名字一起冻结。

## 形状

```text
<任务目录>/thread/
├── 0001-brd-01k8f3m2qz/            BRD 段
│   ├── 0001-01k8h2r5bb/
│   │   ├── user-message.md         问
│   │   ├── response.md             答
│   │   ├── turn.md                 回执
│   │   └── others/                 可选：追加的材料与附件
│   └── 0002-01k8h9t1cc/
├── 0002-prd-01k8p0p0p0/
├── 0003-sdd-01k8q1q1q1/
├── 0004-sdp-01k8r5r5r5/            turn 里没有 response.md，产物在 worktree
└── 0005-uat-01k8s7s7s7/            测试在 worktree 的 test/
```

- **thread 号在任务目录内统一递增**，不按阶段分段；**turn 号在每个 thread 内从 `0001` 重起**。
- BRD、PRD、SDD 三段：答是 `response.md`，一个 turn 只有一份。
- SDP、UAT 两段：turn 里**不放** `response.md`，`turn.md` 里记 `worktree`（分支名）与 `commit`。
- 行文引用只用本地号：`turn 0003/0002` 指第 `0003` 个 thread 的第 `0002` 个 turn；验收 turn 的 `verifies` 也这么填。

## 与运行时怎么对

| 方向 | 关系 |
| --- | --- |
| 一个文档 thread → 运行时 thread | 一对一：一个目录对一个运行时 thread |
| 一个文档 turn → 运行时 turn | 一对多：工具往返、自动接着跑、重试都算这一次派工；名字里带的是**入口**那个 |
| 反过来 | 一般不发生；真出现就是异常，交人看 |

**运行时换了 thread，就新开一个文档 thread 目录**：resume、fork、上下文压缩后重开各是一个新的运行时 thread。接着做什么，写在新 thread 第 `0001` 个 turn 的用户消息里。

运行时 id **不参与任何层级判断**，只作回溯锚点：层级由本地号定。

## 并行

同一问发给几家，就是几个文档 thread 各开一个 turn——各家本来就在各自的运行时 thread 里。几个 thread 阶段相同、号各自往下排，用户消息各存各的：确实是各发了一次，各自冻结。定稿写明以哪一家为底。

## 模块也编号

`PRD/modules/` 与 `SDD/modules/` 下的模块目录名是「四位号 + 短名」。**号只在同一个 `modules/` 里递增**，每一层都从 `0001` 起；任务目录本身不编号。

```text
dev-agent-task/                             项目，不编号
├── thread/
├── PRD/
│   ├── architecture/
│   └── modules/0001-backend/  0002-frontend/
└── SDD/
    ├── architecture/
    └── modules/
        ├── 0001-backend/                   子任务：内部同样是 thread/ + PRD/ + SDD/
        │   └── SDD/modules/0001-intake/ 0002-agent-execution/ …
        └── 0002-frontend/
```

- 同一个模块在 `PRD/modules/` 与 `SDD/modules/` 下**用同一个号与短名**。
- 模块目录与实现时 worktree 里的模块目录一一对应；**以定稿为准**：要改结构，先改这里。
- **不在整棵树里统一编号**：那样要有一处统一取号，几个分支同时建模块就会抢号；子树挪了位置，号也跟着失效。
- 跨节点引用时前面带上模块路径，如 `0001-backend/0002-agent-execution` 的 `0003/0002`。

## 门禁查这几条

编号与形状要能被机器判，[`../tools/doc-gate.py`](../tools/doc-gate.py) 查：

| 查什么 | 判据 |
| --- | --- |
| thread 目录名 | `<四位数字>-<阶段>` 或 `<四位数字>-<阶段>-<运行时 id>`，阶段在 brd、prd、sdd、sdp、uat 之内 |
| turn 目录名 | `<四位数字>` 或 `<四位数字>-<运行时 id>`；有 `turn.md` 的，turn 与所在 thread 都必须带 id |
| 层数 | `thread/` 下正好两层：thread、turn；turn 里只放 `user-message.md`、`response.md`、`turn.md` 与 `others/` |
| turn 内容 | 必有 `user-message.md`；BRD、PRD、SDD 段有 `turn.md` 时必须有 `response.md`；SDP、UAT 段不得有 `response.md`，`turn.md` 必须有 `worktree` 与 `commit` |
| 用户消息的字段 | `executor`、`verifies` 两行齐全；`verifies` 仅 UAT 段有值，写「thread 号/turn 号」且指到存在的 turn，其余写「无」 |
| 回执的字段 | `status`、`worktree`、`commit` 三行齐全；SDP、UAT 段的 `worktree` 与 `commit` 有值，文档段两者同为「无」或同时填 |
| 编号连续 | thread 号在任务目录内、turn 号在各 thread 内，都从 `0001` 起不跳号、不复用 |
| 名字唯一 | 同一个本地号只有一个目录；同一个运行时 id 不出现在两处 |
| 模块编号 | 模块目录名合乎「四位号-短名」，在同一个 `modules/` 里从 `0001` 起连续、不复用；同一模块在 PRD 与 SDD 两侧号与短名一致 |
| 定稿目录 | `PRD/` 与 `SDD/` 下必须有 `architecture/` |
