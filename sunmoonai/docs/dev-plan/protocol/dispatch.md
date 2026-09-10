# 投喂

> 本文件由 `round-dispatch.py --write-md` 生成，不要手改；`--check-md` 查它有没有被改过。
> 两段话的原文在 `round-dispatch.py` 的 `PASTE_ROUTINE` / `PASTE_STALE`。

## 一、每个环节都贴这一段

五个窗口贴同一段，不分环节、不用改字。现在该做哪一步，各家自己算。

```text
看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。

⚠ 只认主线那一份。你 worktree 里的同名文件是投影，从 ① 起就不再跟进主线，
几乎一定是旧的。GO.md 开头有一条 diff 自检，先跑它。不要把主线合并进你的分支。
```

⚠ 路径必须是 `~/master/k8s/` 开头的绝对路径。写成相对路径，对方会读到自己 worktree 里的旧文件。

贴完查谁交了：

```bash
cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py
```

看「缺」那一行。**以产物出现为准**，不以对方说「做完了」为准。

## 二、对方说「缺东西 / 字段是空的 / 没有这个文件」时

先别判它错。核实一下：主线上有、它分支上没有，就是它读了旧副本——这是供给的问题，不是它的问题。
这时贴下面这段；`{轮次}` `{环节}` 换成状态输出里的轮次名和当前环节号：

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

## 三、让脚本替你打印

```bash
cd ~/master/k8s
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste                 # 当前环节还缺谁，就打印给谁的
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste <家名>          # 只打印给这一家的
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste <家名> --stale  # 打印第二节那段，槽已填好
```

`--paste`、`--stale` 照抄，只有 `<家名>` 要换。脚本只打印，不发送。

## 不用命令行投喂

一次性命令行（`codex exec` / `agent -p` / `qoder -p`）会用权限开关把审批提前答掉，
所有者当场批不了。2026-09-10 所有者判定不用。各家的命令行形态仍登记在 `agents.toml`。
