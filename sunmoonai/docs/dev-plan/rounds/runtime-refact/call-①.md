# 环节通知 ① 提案 ｜ `runtime-refact` 轮

> 组织者产物。**收到这条就开工，不需要额外指令。**
> 发给：luna / kimi / cursor / fable / qwen（五家各自独立，互不可见）

## 第一件事：确认你是谁

```bash
r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "❌ 不在 git 仓内"
```

输出就是你的名字。**三条硬规矩**：

1. 命令跑不出名字就**停下问人**，不要继续，也不要靠推理猜；
2. 产品名、模型名、界面长什么样，**一律不是身份证据**；
3. **只写自己路径下的文件。**

## 你要做什么

读 [`runtime-refact-task.md`](runtime-refact-task.md)，按它交一份候选。
题目、只读输入、边界、验收标准全在那份文件里，本通知不复述。

一句话概括：**把 `refact-fable.md`（31 节）与 `runtime-architecture.md`（33 节）
融合成一份面向今后开发的完整指导文档**。这两份稿子在本轮结束后会被删除，
所以**漏了就没了**——逐节落点表是交付物，不是附赠。

## 落点

```
你的 worktree 的 sunmoonai/docs/dev-plan/agent-dev-guide.md
```

写完即 commit 到你自己的分支，**提交后不得再改**。
把该文件的 SHA-256 与所在 commit 记下来，② 互评时要用。

## 本轮的三条特别约束

1. **不得读 `sunmoonai/docs/dev-plan/agent-dev-refact.md`**（裁定 `R2`）。
   它是另一份融合尝试，读了会让你的稿子向它收敛，而独立性正是开这一轮的理由。
   任何方式都算读，包括 `git show` / `grep` / `rg`。
   **在你的覆盖声明里写明你是否遵守了这一条**——如实说「读了」不扣分，不如实说才扣。
2. **不得读任何其他家的 worktree 或分支**，直到你的候选提交为止。
3. **不受任何现有稿的结构、术语、篇幅、编号约束。**
   你认为该有而两份源稿都没有的东西，写进去并说明理由，**按加分记**。

## 取件

一律按 commit，不看工作区。本轮基线见工单 `round.md` 的 `baseline`：

```bash
git show <baseline>:sunmoonai/docs/dev-plan/refact-fable.md
git show <baseline>:sunmoonai/docs/dev-plan/runtime-architecture.md
```

⚠ `investment-app` 是**你 worktree 下的兄弟仓**，不在 k8s 内。
**fable 的工作区没有这个仓**——取不到就在覆盖声明里如实写「本条未独立复核」，
不要照抄任务书 §1.1 的结论当作自己的取证，也**不要去别家的 worktree 拿**。

## 交完之后

```bash
python3 sunmoonai/docs/dev-plan/protocol/round-status.py --round runtime-refact
```

看到自己那一格变 ✅ 就算交付完成。**成功判据是产物出现，不是命令返回 0。**

## 遇到这些情况，停下问人，不要自行决定

- 身份判别命令跑不出名字；
- 任务书 §8 的某条判据你认为不可判定或自相矛盾；
- 你需要读某份不在 §3 只读输入清单里的材料。

⚠ 最后一条要特别说：**任务书 §3 列的就是全部**。
漏列的材料不得事后用来扣你的分，但你也不得自行扩大取件范围——
需要什么就问，问了就有记录。
