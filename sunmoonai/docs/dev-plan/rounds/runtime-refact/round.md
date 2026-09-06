# 工单：`runtime-refact` 轮

> 题目、只读输入、边界、验收标准见 [`runtime-refact-task.md`](runtime-refact-task.md)。
> 流程怎么走见 [`../../protocol/round-protocol.md`](../../protocol/round-protocol.md)，不在这里重复。

```toml
round_id   = "runtime-refact"
status     = "ACTIVE"                # H-1 / H-2 已裁，见 rulings.md
tier       = "T2"                    # 权威层 + 已知对立 + 不可逆（两份源稿随后删除）
final_path = "sunmoonai/docs/dev-plan/agent-dev-guide.md"
round_dir  = "sunmoonai/docs/dev-plan/rounds/runtime-refact"
prefix     = "runtime-refact"
baseline   = "ed0b5136"              # 只读输入按这个 commit 取
proposers  = ["luna", "kimi", "cursor", "qwen"]   # R3：fable 于 ① 期间退赛，N 5→4
arbiter        = "opus"              # R1：所有者 2026-09-06 裁定
arbiter_branch = "runtime-refact/arbiter"
acceptor       = ""                  # ③ 之后由处置表算出，不得事后更换
anchor_roots      = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "~/master/investment-app", "."]
frozen_sections   = []               # 本轮无基座；冻结的是任务书 §8，不是最终稿的某一节
mechanical_absent = [
  'M4 已证伪的设计不得复活::amend_schema|amend\.mode|回执仓|候选仓|三道边界',
  'M5 两个 Profile 不得复活::开发 Profile|产品 Profile|两个 Profile',
  'M6 human 不得作为执行者 kind::kind\s*=\s*"human"',
]
```

## 为什么 `final_path` 是一个新文件名

候选写在**共享最终路径的同名文件**（各自 worktree 里）。本轮产物是一份新稿，
路径取 `agent-dev-guide.md`，与既有文件互不覆盖。
⑦ 发布之后，`agent-dev-refact.md` 与两份源稿的去留由所有者定。

## 两件已裁的事（见 [`rulings.md`](rulings.md)）

| 编号 | 裁定 | 后果 |
| --- | --- | --- |
| **R1** | **opus 任裁决方** | 它同时是参考作品 `agent-dev-refact.md` 的作者，故按 `round-protocol.md` §8.2「起草人回避」声明：候选与该文一致**既不加分也不减分**，冲突且论证扎实的应当更高。⑤ 验收方由处置表算出，**不得是 opus** |
| **R3** | **fable 退赛，`N` 5 → 4** | ① 环节按 §14.1「该家不出候选，不阻塞其余」。`call-①.md` **不改**（发布后不得再改）。独立性后果见 `rulings.md` 该条下的说明 |
| **R2** | **五家不得读 `agent-dev-refact.md`** | 该文移出只读输入，任务书 §3.1 改为禁止条款，各家须在覆盖声明里写明是否遵守。⚠ **靠纪律不靠机制**——文件就在各家工作区的主线上，打得开 |

`arbiter` 此前留空是**有意的**（属「无默认，必须显式填」，agent 不得代填），
现按 `R1` 填入，`status` 改 `ACTIVE`，可以发 ① 了。

## 本轮的特殊之处

以往漏一条，源稿还在旁边；**这一轮的两份源稿在 ⑥ 之后会被删除**，
漏一条它就只存在于 git 历史里。逐节落点表（任务书 D2）因此是交付物而不是附赠，
且验收会抽查落点是否属实——**声称落点而该节没有内容的，比不写落点表扣得更重**。
