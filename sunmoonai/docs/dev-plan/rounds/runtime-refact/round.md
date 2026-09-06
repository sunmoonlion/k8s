# 工单：`runtime-refact` 轮

> 题目、只读输入、边界、验收标准见 [`runtime-refact-task.md`](runtime-refact-task.md)。
> 流程怎么走见 [`../../protocol/round-protocol.md`](../../protocol/round-protocol.md)，不在这里重复。

```toml
round_id   = "runtime-refact"
status     = "DRAFT"                 # H-1 / H-2 裁定后改 ACTIVE
tier       = "T2"                    # 权威层 + 已知对立 + 不可逆（两份源稿随后删除）
final_path = "sunmoonai/docs/dev-plan/agent-dev-guide.md"
round_dir  = "sunmoonai/docs/dev-plan/rounds/runtime-refact"
prefix     = "runtime-refact"
baseline   = "aed7896a"                 # 只读输入与参考作品都按这个 commit 取
proposers  = ["luna", "kimi", "cursor", "fable", "qwen"]
arbiter        = ""                  # ⚠ H-1 待所有者裁定；无默认，不得由 agent 填
arbiter_branch = ""                  # 同上
acceptor       = ""                  # ③ 之后由处置表算出，不得事后更换
anchor_roots      = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "~/master/investment-app", "."]
frozen_sections   = ["8. 验收标准（**本节随本文一并冻结，逐条编号，⑤ 验收逐条给结论**）"]
mechanical_absent = [
  'M4 已证伪的设计不得复活::amend_schema|amend\.mode|回执仓|候选仓|三道边界',
  'M5 两个 Profile 不得复活::开发 Profile|产品 Profile|两个 Profile',
  'M6 human 不得作为执行者 kind::kind\s*=\s*"human"',
]
```

## 为什么 `final_path` 是一个新文件名

候选写在**共享最终路径的同名文件**（各自 worktree 里）。参考作品
`agent-dev-refact.md` 要在本轮全程可读，所以新稿另取路径 `agent-dev-guide.md`，
两者不互相覆盖。⑦ 发布之后，`agent-dev-refact.md` 的去留由所有者定
（它是参考作品，不是本轮产物）。

参考作品按 commit 取，**不得作为起点**：

```
git show aed7896as 裁决：整合快，但它是参考作品的作者，自我制衡弱（已按「起草人回避」声明立场不作判据）／ 从五家指一家裁决：制衡强，但多一轮上下文传递 |
| **H-2** | 五家能不能读参考作品 | 给：省掉重复核查，但候选会向它收敛，而独立性正是开这一轮的理由 ／ 不给：独立性强，但今天核出的六条结论五家各自重核（每条约两分钟） |

**不预设，也不建议。**裁定写进 `rulings.md` 后，本文件 `status` 改 `ACTIVE`、
填 `arbiter` 与 `arbiter_branch`，然后才发 ①。

## 本轮的特殊之处

以往漏一条，源稿还在旁边；**这一轮的两份源稿在 ⑥ 之后会被删除**，
漏一条它就只存在于 git 历史里。逐节落点表（任务书 D2）因此是交付物而不是附赠，
且验收会抽查落点是否属实。
