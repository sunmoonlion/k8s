# fable-c1 停点回执：第一节前提不成立（卡与 C1 代码同一提交投放）

- 卡：`docs/process/switch-test/inbox/qwen/2026-10-21-fable-c1-site-identity.md`（远程 Fable 2026-10-21 写，19:50 进 inbox）
- 工位：`~/worktrees/fable/sunmoonun`，分支 fable，HEAD `76a6334f1`（C1 提交）
- 停点时刻：2026-10-21 19:52 CST
- 所有者裁定（本轮 AskUserQuestion）：**「按卡面停点写 inbox/fable」**——不渲染、不改代码、不就地恢复，请远程重发。
- 一句话结论：**卡在第一节前提即停**。卡面第一节要求「先别拉代码、在 `c2d0dbb5` 或更早渲染改前基线」，但平台线固定第一步是 `git pull --ff-only origin fable`，而这张卡本身就在 C1 提交 `76a6334f1` 里创建——pull 拿到卡的同时 HEAD 必然已是 C1，第 25 行「不能已经是 C1 的提交」当场不成立。卡面自定处置即「真是那样就停，写 inbox/fable」。

---

## 一、只读取证（未渲染、未改代码）

| 核对项 | 命令 | 结果 |
|---|---|---|
| 卡拉取 | `git pull --ff-only origin fable` | exit=0，带进 `76a6334f1`（含本卡与 C1 代码，66 files changed） |
| 当前 HEAD | `git rev-parse --short HEAD` | `76a6334f1`（C1 提交） |
| HEAD 的父 | `git rev-parse --short HEAD~1` | `c2d0dbb5d`（正是卡面第一节要的基线提交） |
| 卡由哪个提交创建 | `git log --diff-filter=A --format='%h %s' -- <卡路径>` | `76a6334f1`——**创建卡的提交 == C1 提交** |
| 卡与代码是否同批 | `git show --name-only --format= 76a6334f1 \| grep -E 'switch-test\|site.yaml\|environments/kind'` | 同一提交里既有卡，又有 `infrastructure/environments/kind/site.yaml`、`README.md`（C1 代码） |
| C1 改动规模 | `git diff --stat c2d0dbb5d 76a6334f1` | `65 files changed, 235 insertions(+), 142 deletions(-)`（单个提交） |
| 工作区 | `git status --short` | 空（干净） |
| 产物目录 | `ls -d ~/sunmoon-probe-runs` | 已存在（历史遗留），本轮**未**在其下新建 `c1-*` 目录 |

**判据结论**：卡面第 25 行「`git log` 的提交是 `c2d0dbb5` 或更早，不能已经是 C1 的提交」——实测 HEAD 就是 C1 提交 `76a6334f1`，**判据不成立**。这不是命令笔误（无从「改怎么执行」绕过），而是卡与被验收代码同一提交投放，与平台线 pull-first 规矩结构性互斥。

## 二、为什么无法「先渲染改前基线」

- 平台线规矩（`docs/process/switch-test/README.md`）：每张卡第一步固定 `cd ~/worktrees/<WS>/sunmoonun && git pull --ff-only origin <WS>`。
- 本卡第一步（第 16 行）也是 `cd ~/worktrees/fable/sunmoonun && git status --short && git log --oneline -1`，且第 13 行标题即「改前基线（**先别拉代码**）」。
- 冲突点：卡文件本身由 C1 提交 `76a6334f1` 引入。执行者要**读到**这张卡，就必须已经 pull 到 `76a6334f1`；而一旦 pull 到 `76a6334f1`，工作副本里的 `site.yaml` 等就已是 C1 后的版本，「改前」态在本地工作副本里已不存在。
- 因此卡面设想的「同一份工作副本，先渲染旧代码、再 pull 渲染新代码」在本卡的投放方式下不可实现。

## 三、恢复是可行的（但按裁定未做）

C1 只有一个提交、父提交 `c2d0dbb5d` 正是基线，故「改前 vs 改后」逐字节比对本可干净恢复：用临时 `git worktree add --detach <tmp> c2d0dbb5d` 渲染改前、当前 `76a6334f1` 渲染改后，再 `diff -r`。这属卡面之外的「怎么执行」改动，**所有者本轮裁定走卡面停点、不做就地恢复**，故我未执行，只在 inbox/fable 页里作为建议改法①列出，等远程重发或所有者另行授权。

## 四、边界与清理

- 未做：`make components-render`、`make platform-plan`、`make config`、任何 `diff`、第四节五条只读入口命令、render-check。
- 未碰：集群、gitops 声明、Harbor、Jenkins 数据、任何仓内代码文件。
- 无一次性 /tmp 日志产生（本轮只跑只读 git 命令）；`~/sunmoon-probe-runs` 下未新建目录，无需清理。
- 卡**未**移 done/，仍在 `inbox/qwen/`（中途停下不移）。
- 交付物：本回执 + `docs/process/switch-test/inbox/fable/2026-10-21-fable-c1-baseline-ordering.md`（给远程的一页，含三种建议改法）。

## 五、推回

只提交本回执与 inbox/fable 那一页，卡未移 done/（仍留 inbox/qwen/）。先 pull（Already up to date）后 push，GitHub SSH 与 Gitee https 各一行同号。补写本节后另有一笔只动本回执的补写提交。

```text
$ git add scripts/results/fable-c1.20261021-1952.md \
         docs/process/switch-test/inbox/fable/2026-10-21-fable-c1-baseline-ordering.md
$ git status --short
A  docs/process/switch-test/inbox/fable/2026-10-21-fable-c1-baseline-ordering.md
A  scripts/results/fable-c1.20261021-1952.md

$ git commit -m "fable-c1 停在第一节：卡与 C1 代码同一提交，pull-first 下改前基线前提不成立（qwen）"
[fable 490882ff4] …
 2 files changed, 88 insertions(+)
commit exit=0

$ git pull --ff-only origin fable
From github.com:sunmoonlion/sunmoonun
 * branch                fable      -> FETCH_HEAD
Already up to date.
pull exit=0

$ git push origin fable
To github.com:sunmoonlion/sunmoonun.git
   76a6334f1..490882ff4  fable -> fable
To https://gitee.com/sunmoonlion/sunmoonun.git
   76a6334f1..490882ff4  fable -> fable
push exit=0

$ git status --short        # 空
$ git rev-list --left-right --count origin/fable...HEAD
0       0
```
