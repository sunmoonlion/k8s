# fable-c1 停在第一节：卡与 C1 代码同一提交，「先渲染改前基线」的前提无法成立

WS=fable，本地 Qwen，2026-10-21 19:52 CST。执行到 `docs/process/switch-test/inbox/qwen/2026-10-21-fable-c1-site-identity.md` 第一节即停，**未渲染、未改任何代码、未碰集群/gitops/Harbor/Jenkins**，卡仍留在 `inbox/qwen/`（中途停下不移 done/）。

## 现象（一句话）

卡面第一节要求「先别拉代码、在 `c2d0dbb5` 或更早渲染改前基线」，但**这张卡本身就是在 C1 提交 `76a6334f1` 里创建的**——要读到卡就必须 `git pull` 到 `76a6334f1`，而一 pull，HEAD 就已经是 C1，第一节前提（第 25 行「不能已经是 C1 的提交」）当场不成立。卡面自己写的处置就是「真是那样就停，写 inbox/fable」，我照办。

## 证据（只读）

```text
$ git log --diff-filter=A --format='%h %s' -- docs/process/switch-test/inbox/qwen/2026-10-21-fable-c1-site-identity.md
76a6334f1 C1 集群身份与路径参数化（0039 停点 C1）：… 卡 fable-c1（qwen，字节对比）
# 创建卡的提交 == C1 提交 == 76a6334f1

$ git show --name-only --format= 76a6334f1 | grep -E 'switch-test|site.yaml|environments/kind'
docs/process/switch-test/inbox/qwen/2026-10-21-fable-c1-site-identity.md   ← 卡
infrastructure/environments/kind/README.md                                  ← C1 代码
infrastructure/environments/kind/site.yaml                                  ← C1 代码
# 卡与被验收的 C1 代码在同一提交里同批进来

HEAD   = 76a6334f1（C1）
HEAD~1 = c2d0dbb5d（正是卡面第一节要的基线提交）
C1 = 单个提交：c2d0dbb5d → 76a6334f1，65 files changed, +235/−142
工作区干净；未渲染，~/sunmoon-probe-runs 下未新建本轮目录
```

平台线固定第一步（README）是 `cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable`。「pull 才能拿到卡」与「拿到卡时 HEAD 必须还没到 C1」这两条，对一张**和代码同提交投放**的卡来说互斥，不是执行顺序能绕开的。

## 请远程重发时考虑的三种改法（只是建议，我没动代码）

1. **基线改成显式提交号，用临时 worktree 取**：卡面第一节不再依赖「pull 之前」，而是 `git worktree add --detach <tmp> c2d0dbb5d` 在父提交渲染「改前」，再在当前 `76a6334f1` 渲染「改后」，逐字节 diff。非破坏、历史完整，卡的真实意图（验证重构前后输出一致）100% 能达成。**这条最省事，我这边随时可跑，等您一句话或重发卡。**
2. **卡与代码分两提交、卡在前**：把卡单独放一个提交先推，代码 C1 后推。这样本地助手 pull 到「只有卡、还没 C1」时能先渲染基线，再 pull C1 渲染改后。但要远程控制提交投放顺序。
3. **卡面直接写明从 `HEAD~1` 取基线**：第一节改成 `git stash`-free 的 `git worktree`/`checkout HEAD~1` 渲染，把「先别拉代码」换成「从父提交渲染改前」，与平台线 pull-first 不再冲突。

## 我这轮的边界

- 只做了只读取证（git log/show/rev-parse、status），没有 `make components-render`、没有 `platform-plan`、没有 diff，`$P` 未创建。
- 卡未移 done/，仍在 inbox/qwen/。
- 本页 + 停点回执 `scripts/results/fable-c1.20261021-1952.md` 一并提交推 origin/fable。
- 判据一字未改；停点依据是卡面第 25 行自己写的处置。
