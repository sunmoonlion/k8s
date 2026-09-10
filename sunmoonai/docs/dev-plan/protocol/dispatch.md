# 投喂 ｜ 交互窗口贴的话 · 命令行命令

> ⚠ **本文件由 `round-dispatch.py --write-md` 生成，不要手改。**
> 真源两处：执行者登记在 `agents.toml`；两段话术在 `round-dispatch.py` 的
> `PASTE_ROUTINE` / `PASTE_STALE`（`--paste` 用的也是这两段，同一份）。
> 核对是否漂移：`python3 round-dispatch.py --check-md`

> ⚠ **一份通用，不分环节。**发出去的话每个环节都一样——
> 「现在该做哪一步」由各家自己跑 `round-status.py` 算出，再读它打出的通知路径。

## 一、交互窗口投喂（当前做法）

所有者把各家开成交互会话，逐窗口贴下面的话。**审批、提问都在窗口里当场处理。**

### 常规派发——整段贴，一个空都不用填

```text
看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。

⚠ 只认主线那一份。你 worktree 里的同名文件是投影，从 ① 起就不再跟进主线，
几乎一定是旧的。GO.md 开头有一条 diff 自检，先跑它。不要把主线合并进你的分支。
```

### 对方报「缺东西 / 字段是空的 / 没有这个文件」时

⚠ **先别信它搞错了。**F-17 那次对方报的四条全对——在它的分支上。
先核实**主线上**是什么、**它分支上**是什么；两边不一样就贴这段
（`{轮次}` `{环节}` 两处要填，用 `--paste <家名> --stale` 可自动填）：

```text
你报的那几条我核实过，属实——但都是「在你的分支上」属实。
你的分支从 ① 起就冻结了，之后主线上写进去的裁定、工单改动、环节通知，你的工作区里一个都没有。
这是供给方的错，不是你的错，你的停止判为正确行为，不计任何不利处置。

从现在起，通知、工单、裁定、判定命令**一律去主线读**。**不要把主线合并进你的分支。**

先自检，确认你手上那份是旧的：

  diff <(git -C ~/master/k8s show master:sunmoonai/docs/dev-plan/GO.md) \
       sunmoonai/docs/dev-plan/GO.md >/dev/null \
    && echo "一致" || echo "⚠ 本地已过期——只认主线那份"

然后从主线重新开始：

  R=~/master/k8s/sunmoonai/docs/dev-plan/rounds/{轮次}
  cat ~/master/k8s/sunmoonai/docs/dev-plan/GO.md
  ls $R/*call-*.md         # ⚠ 以这个结果为准，不要凭「哪些环节历史上有通知」推断
  cat $R/*call-{环节}.md
  cat $R/round.md
  cat $R/rulings.md        # ⚠ 裁定可能在你冻结之后才写，这里通常就是你困惑的来源
  ( cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py )
```

### 自动填

```bash
cd ~/master/k8s
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste                 # 当前环节还缺的家
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste <家名>          # 指名一家
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste <家名> --stale  # 用上面第二段
```

`--paste` 是字面开关，照抄；只有 `<家名>` 要换。脚本只打印，不发送。

### 为什么路径全是写死的

F-17：`GO.md` 早就写着「通知去主线读」，但那句话只在主线那一版上——要读到它，
得先知道去主线读。**所有者贴的这句话是全系统唯一不经过投影的通道**，
所以它必须自带绝对路径 `~/master/k8s/…`；相对路径会被解析到参赛方 worktree 里的过期副本。

## 二、命令行命令（当前不用）

> ⚠ **不用的理由：下面每条命令里的权限开关会把审批提前答掉**——
> 预授权范围内静默同意，超出范围静默拒绝退出，「让人当场批一下」在这条路上结构上不存在。
> 2026-09-06 实测端到端没走完（`rounds/executor-adapter/task.md` §1.0）。
> 保留它**只作记录**：这是各执行者确实存在的命令行形态。
> ⚠ **它不是将来自动化的路。**命令行下审批只能被预先答掉，没有第三种结局。
> 若要自动化，唯一候选是 SDK 审批回调——审批请求回到调用方、再转给人批，
> 即「派发自动、审批仍由人」，不是无人值守。**未验证、未建**（`rounds/executor-adapter/`，
> 仅对 codex 取过证：其默认审批处理器全部自动同意，须改掉；审批挂起期间会话收不到其它事件）。

> ⚠ **列的是登记表里的全部执行者，不是某一轮的参赛方。**
> 某一轮投谁，以该轮 `round.md` 的 `proposers` 为准——
> 多敲一家不会报错，但那一家的产物会让 `round-status.py` 认不出，白跑一次。

### 敲之前知道两件事

1. ⚠ **成功判据是产物出现，不是命令返回 0。**
   `cursor` 未加 `--trust` 时会拒绝执行**却仍返回 0**；
   `codex exec` 默认 read-only 时会把活干完但写不进去，退出码同样是 0。
2. ⚠ **`codex exec` 会阻塞等 stdin**（打印 `Reading additional input from stdin...`）。
   下面 `luna` / `kimi` 两条末尾的 `< /dev/null` **不能省**——
   实测省掉后挂 17 分 29 秒、CPU 时间 00:00:00，一步没跑。

### luna

```bash
cd /home/zym/worktrees/luna/k8s && env CODEX_HOME=/home/zym/.codex-official codex exec --skip-git-repo-check -s workspace-write --cd /home/zym/worktrees/luna/k8s '看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。只认主线那一份；你 worktree 里的同名文件是旧投影。你是被一次性命令行叫起来的，没有人在看你的输出——第五节按「命令行」那一支做。' < /dev/null
```

### kimi

```bash
cd /home/zym/worktrees/kimi/k8s && env CODEX_HOME=/home/zym/.codex-kimi codex exec --skip-git-repo-check -s workspace-write --cd /home/zym/worktrees/kimi/k8s '看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。只认主线那一份；你 worktree 里的同名文件是旧投影。你是被一次性命令行叫起来的，没有人在看你的输出——第五节按「命令行」那一支做。' < /dev/null
```

### cursor

```bash
cd /home/zym/worktrees/cursor/k8s && agent -p '看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。只认主线那一份；你 worktree 里的同名文件是旧投影。你是被一次性命令行叫起来的，没有人在看你的输出——第五节按「命令行」那一支做。' --output-format text --trust --model cursor-grok-4.6-high
```

### qwen

```bash
cd /home/zym/worktrees/qwen/k8s && qoder -p '看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。只认主线那一份；你 worktree 里的同名文件是旧投影。你是被一次性命令行叫起来的，没有人在看你的输出——第五节按「命令行」那一支做。' -w /home/zym/worktrees/qwen/k8s --permission-mode accept_edits
```

### opus

```bash
cd /home/zym/worktrees/opus/k8s && claude -p '看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。只认主线那一份；你 worktree 里的同名文件是旧投影。你是被一次性命令行叫起来的，没有人在看你的输出——第五节按「命令行」那一支做。' --permission-mode acceptEdits --model opus
```

### 不在本表内：owner

⚠ **人，不是执行者。**没有 worktree、没有命令行入口，**不能投喂**。
它登记在 `agents.toml` 里的唯一理由：让 `round.md` 的 `principal`
能解析到真实存在的东西——否则 `principal = "banana"` 也会通过
（2026-09-09 实测确实通过了）。

### fable —— 无命令行入口

⚠ **不能用命令投喂**：它没有一次性命令行入口。
把它的界面/会话打开在 `/home/zym/worktrees/fable/k8s`，然后发这一句：

```text
看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。只认主线那一份；你 worktree 里的同名文件是旧投影。你是被一次性命令行叫起来的，没有人在看你的输出——第五节按「命令行」那一支做。
```

## 三、贴完 / 敲完之后

```bash
cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py
```

看的是**产物出现没有**。要读内容再开检视面：

```bash
python3 sunmoonai/docs/dev-plan/protocol/round-review.py --round <轮次>
python3 sunmoonai/docs/dev-plan/protocol/round-review.py --round <轮次> --close
```
