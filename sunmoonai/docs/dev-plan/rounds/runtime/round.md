# 轮次 runtime：只有一个运行时，开发是它的第一个 Task Profile

> 本文件是本轮**唯一**的可变参数来源。不变的流程规则在
> [`../../round-protocol.md`](../../round-protocol.md)，不在这里重复。
> 背景与题目细则见同目录 [`task.md`](task.md)。
>
> ⚠ **本文件尚未冻结。**`status = "DRAFT"` 不在 `round-protocol.md`「本轮定义」
> 规定的枚举（`ACTIVE` / `DONE` / `ABORTED`）之内——**这是协议的一个缺口**：
> 协议没有为「工单起草中、尚未经 H1 冻结」定义取值，而 `refact-fable.md` §3.1.1
> 把 `DRAFT` / `FROZEN` 归为 **Artifact 状态**、此时 Task 处于 `VALIDATING`。
> 本轮按 Artifact 状态理解，取值 `DRAFT`；H1 冻结时改 `ACTIVE`。
> **该缺口须补进 `protocol-v2` 的待决清单，不在本轮解决。**

```toml
round_id   = "runtime"
status     = "DRAFT"                 # H1 冻结后改 ACTIVE；见上方缺口说明
tier       = "T2"
final_path = "sunmoonai/docs/dev-plan/runtime-architecture.md"
round_dir  = "sunmoonai/docs/dev-plan/rounds/runtime"
prefix     = "runtime"
baseline   = "7e8464c2"
proposers  = ["luna", "kimi", "cursor", "fable", "qwen"]
arbiter        = "opus"
arbiter_branch = "opus"              # ③ 裁决时钉到具体 commit
acceptor       = ""                  # 按协议「⑤ 验收 与 ⑥ 确认」的规则算出；fable 不得担任
anchor_roots      = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "."]
frozen_sections   = []               # 本轮无基座；只读输入见「只读输入」一节
mechanical_absent = [
  '两个 Profile 不得复活::开发 Profile|产品 Profile|Profile A|Profile B|两个 Profile',
  'human 不得作为执行者 kind::kind\s*=\s*"human"',
]
```

## 档位裁定

**T2**，命中三条判据：

- **不可逆**：本轮结论决定产品运行时的对象模型，后续所有实现依赖它；
- **权威层**：会成为 `request-lifecycle.md` 内核修订的输入（`task.md` §3.2）；
- **已知对立**：上一轮的最终稿 `refact-fable.md` 采用「两个 Profile」，本轮前提是它错了——
  其作者 fable 也在参赛方名单内，对立是明确的。

**另注**：本轮参赛方里 fable 无命令行入口（Cursor 桌面应用），
所以本轮**不可能全自动分发**——这本身是 `task.md` §2.4 那条「开销盈亏线」的一个现实样本。

## 题目

产出一份方案，落在共享最终路径 `sunmoonai/docs/dev-plan/runtime-architecture.md`，
覆盖 `task.md` §3 的三块（P1 一个运行时 / P2 Interaction 双向带载荷 /
P3 执行者可观测粒度）与贯穿的必答 Q。

## 基座

**无，新建文件。**

## 只读输入（不得直接修改；要改写进候选正文）

| 文件 | 版本锚 |
| --- | --- |
| `sunmoonai/docs/dev-plan/refact-fable.md` | 927 行，sha256[:16] `89303624bfd9ef27`，master `7e8464c2` |
| `sunmoonai/docs/dev-plan/working/request-lifecycle.md` | 647 行，sha256[:16] `6fcd3973ede30b88`，末次提交 `70a7dd50` |

机械判：候选分支相对 `7e8464c2` 的 diff 中，这两个文件必须无改动。

## 验收标准

见 [`task.md`](task.md) §8 的 9 条。**H1 冻结后不得为了让产出通过而修改。**

## 角色

| 角色 | 谁 | 依据 |
| --- | --- | --- |
| 提案 / 互评 | luna、kimi、cursor、fable、qwen | `task.md` §9；五家、三个独立组 |
| 裁决与整合 | opus（不参赛、不写评审、不验收） | `task.md` §9 |
| 验收 | 按协议规则算出，**fable 不得担任** | 「验收方不得是基座作者」——fable 是被推翻那份稿的作者 |
| 确认 | 项目所有者 | 人，手动 |

**裁决方的利益申报**：`task.md` §3.1/§3.2/§3.4 中标为 OP-1 / OP-2 / OP-3 的三样由裁决方提出。
按 `task.md` §5，这三条**裁决权归所有者，裁决方不判自己的东西**；
「同意 opus 的框架」不计入优点，有理由地推翻按加分记。

## 待自动化

| 动作 | 本轮由谁做 | 阻塞点 |
| --- | --- | --- |
| 把环节通知送到 luna / kimi / cursor / qwen | 脚本可生成，执行待定 | `round-dispatch.py` 只生成不执行，且 `status != ACTIVE` 时拒绝生成 |
| **把环节通知送到 fable** | **只能所有者手工投喂** | **fable 无命令行入口**——它跑在 Cursor 桌面应用里。投喂前须先把应用打开在 `~/worktrees/fable/k8s`（`task.md` §6.1） |
| fable 的 `agents.toml` 条目 | **写不了 `argv`** | 登记表每条都假定执行者可由 argv 调起，没有「存在但不可自动分发」这一形状（`task.md` §6.4） |
| cursor 钉 `--model` | **尚未做** | `agents.toml` 只在 `protocol-v2` 分支，该分支有五条待所有者裁定；未钉之前 cursor 走 `auto`，独立性登记不成立（`task.md` §6.2.1） |
| fable 的模型登记 | **不可机械核验** | 模型在 GUI 里选，不经任何命令行参数——本轮独立性折算里唯一不可复核的输入 |

**空着不等于没有，等于没记。**

## 开轮前置（未全部满足不得冻结）

1. fable 的 worktree 已建（✅ 2026-09-05，`~/worktrees/fable/k8s` @ `7e8464c2`）；
2. 身份判别命令已实测六处全对（✅ 2026-09-05，`task.md` §6.2）；
3. cursor 的 `--model` 已钉死并登记（fable 的钉不了，按口述事实登记）；
4. `agents.toml` 的落点已定（`protocol-v2` 或本轮工单写死）；
5. H1：所有者冻结 `task.md` §8 的 10 条；
6. `refact-fable.md` §8 第 7 条作废、其余八条的处置，已记入
   `rounds/refact-fable/rulings.md`——**未记录的裁定无效**。
