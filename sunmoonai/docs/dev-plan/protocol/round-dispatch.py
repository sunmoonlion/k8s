#!/usr/bin/env python3
"""分发：算出「现在该叫谁、说什么」，输出可直接执行的命令。

**当前只生成，不执行。**这是 `rounds/dev-plan-refact/inputs/automation-roadmap.md` 第 3 步：
先让人粘贴一轮，验证「判定」与「措辞」都对，再上真调用（第 4 步）。
理由写在 `round-protocol.md`「判据自身的质量」：一个检查第一次运行时，
最可能发现的是它自己判错了——分发脚本同理，而它判错的代价是四家同时干错的环节。

状态不自己算，一律调 `round-status.py --json` 取——**单一真源**。
调用方式不硬编码，从 `agents.toml` 读。

用法：
    round-dispatch.py                 # 当前环节缺谁，给谁的命令
    round-dispatch.py --round runtime # 指定轮次（与 round-status.py 同名同义）
    round-dispatch.py --all           # 不管缺不缺，给全部参与方的命令
    round-dispatch.py --stage 4       # 指定环节，接 4 或 ④（覆盖自动判定）
    round-dispatch.py --paste         # 交互会话贴的话：当前环节还缺的家
    round-dispatch.py --paste cursor  # 指名一家（不检查它缺不缺）
    round-dispatch.py --paste cursor --stale   # 对方报「缺东西」时用（F-17）

退出码：
    0  正常输出了命令
    2  拒绝分发：轮次不是 ACTIVE，或 round-status.py 判定失败

`--stage` 只在本脚本有；`round-status.py` 没有这个参数（它算环节，不指定环节）。
两者的调用方式同时写在 `round-protocol.md`「两个脚本怎么调」一节。
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# ⚠ **两条通道说同一句话，指同一份操作手册。**2026-09-09 查实：此前 CLI 这条路
# 指的是 `round-protocol.md`（法典，944 行），而它里面「你是谁」0 处、
# 「怎么提交」0 处、「卡住了怎么办」0 处。`executor-adapter` 记的现象正是
# 「cursor 写出产物但不提交（三次）」——当时归因给工具，但从没测过另一个解释：
# **它拿到的那份文档从头到尾没提过「提交」两个字。**
# 通道差异只在 GO.md §五 一处处理，其余五节两条通道通用。
FIXED_INSTRUCTION = (
    "看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。"
    "只认主线那一份；你 worktree 里的同名文件是旧投影。"
    "你是被一次性命令行叫起来的，没有人在看你的输出——第五节按「命令行」那一支做。")


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, check=True)
    return Path(out.stdout.strip())


def load_agents() -> dict:
    """极简 TOML 子集解析：够读本文件即可，不引三方依赖。"""
    text = (HERE / "agents.toml").read_text(encoding="utf-8")
    cfg: dict[str, dict] = {}
    sec = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            sec = line[1:-1]
            cfg[sec] = {}
            continue
        if sec is None or "=" not in line:
            continue
        k, v = (x.strip() for x in line.split("=", 1))
        if v.startswith("["):
            # argv 可能跨行；先收集到行尾配平为止
            buf = v
            cfg[sec][k] = buf
        else:
            cfg[sec][k] = v.strip('"')
    # argv 跨行的情况单独处理：直接用正则从原文抓
    for name in cfg:
        m = re.search(rf"\[{re.escape(name)}\](.*?)(?=\n\[|\Z)", text, re.S)
        if not m:
            continue
        a = re.search(r"argv\s*=\s*\[(.*?)\]", m.group(1), re.S)
        if a:
            cfg[name]["argv"] = [s.strip().strip('"')
                                 for s in re.findall(r'"([^"]*)"', a.group(1))]
    return cfg


def status(round_name: str | None) -> dict:
    cmd = [sys.executable, str(HERE / "round-status.py"), "--json"]
    if round_name:
        cmd += ["--round", round_name]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        # round-status.py 的用法错误一律退 2；这里必须**原样传出去**。
        # `sys.exit(<字符串>)` 退的是 1，会把「判定失败」伪装成另一种失败，
        # 而协议「8b · 退出码」写的是 2。同一个坑在 round-status.py 里已修过一次。
        print(p.stdout + p.stderr, file=sys.stderr)
        raise SystemExit(2 if p.returncode == 2 else p.returncode or 2)
    return json.loads(p.stdout)


CIRCLED = "①②③④⑤⑥⑦"


def norm_stage(hint: str) -> str:
    """`4` 与 `④` 都要认。

    2026-09-06 实测：`--stage 4` 传进来是字符串 `"4"`，而环节名是 `"④ 异议"`，
    `"④ 异议".startswith("4")` 恒为假 —— 循环走空后**静默退回当前环节**，
    而帮助文本与协议 §8b 都写着「覆盖自动判定」。
    文档说它能做的事它做不到，且不报错：这是「判据给假答案」的分发端形态。
    """
    hint = hint.strip()
    # `'④'.isdigit()` 在 Python 里为**真**（圈号带数字属性），但 `int('④')` 抛 ValueError。
    # 必须先要求 ASCII，否则传圈号进来直接崩在这一行。
    if hint.isascii() and hint.isdigit() and 1 <= int(hint) <= len(CIRCLED):
        return CIRCLED[int(hint) - 1]
    return hint


def missing_of(st: dict, stage_hint: str | None) -> tuple[str, list[str]]:
    cur = st["current"]
    want = norm_stage(stage_hint) if stage_hint else None
    for r in st["stages"]:
        if want and not r["stage"].startswith(want):
            continue
        if not want and r["stage"] != cur:
            continue
        if r["done"] is None:
            return r["stage"], []
        return r["stage"], [k for k, v in r["done"].items() if not v]
    if want:
        # 指名了一个不存在的环节。**不许静默退回当前环节**——
        # 那会让「我明明指定了 ④」和「④ 恰好就是当前环节」看起来一模一样。
        print(f"没有匹配 {stage_hint!r}（归一化为 {want!r}）的环节；"
              f"本轮的环节是：{'、'.join(r['stage'] for r in st['stages'])}",
              file=sys.stderr)
        raise SystemExit(2)
    return cur, []



# 交互窗口投喂的两段话术，`--paste` 打印的就是这两段。原文只在这里，别处不再存副本
# （此前另有 protocol/paste/ 目录和一份生成的投喂页，所有者 2026-09-10 先后判定都不要）。
# ⚠ 必须是原始字符串：过期投影那段有行尾反斜杠（diff 续行），普通字符串会把它吞掉。
PASTE_ROUTINE = r"""看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。

⚠ 只认主线那一份。你 worktree 里的同名文件是投影，从 ① 起就不再跟进主线，
几乎一定是旧的。GO.md 开头有一条 diff 自检，先跑它。不要把主线合并进你的分支。
"""

PASTE_STALE = r"""你报的那几条我核实过，属实——但都是「在你的分支上」属实。
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
"""


def paste(st: dict, stage: str, targets: list[str], stale: bool) -> int:
    """输出交互会话里**直接贴的那句话**，槽位从实况填。

    ⚠ **与不带 `--paste` 时打印的命令行命令，是两条能力不同的通道。**
    命令行命令是一次性的：**没有回话通道**，agent 需要一次往返就只能退出。
    `rounds/executor-adapter/task.md` §1.0 实测：那条路端到端**没走完**，
    四个决策点全部回落到人；同一个 cursor，`-p` 下三次都不提交，交互式跑一次即提交。
    所以两条路的**产出不同**，不能互相替代。
    ⚠ 2026-09-09 F-24 起两条路**指同一份 `GO.md`**，差异只在它 §五 一处；
    此前「CLI 的入口是 `round-protocol.md`」是意外，不是设计。

    ⚠ **模板里没有「路径」这个槽位，路径一律写死。**
    见 `rounds/dev-plan-refact/findings.md` F-17：靠人记得写对绝对路径，
    正是 2026-09-08 那次 ③ 停摆的根因。这里唯一会填错的是家名和环节，
    而这两样填错对方会立刻报错，不会静默读到旧的还以为是新的。

    用 `.replace()` 不用 `.format()`：模板是给人手改的，
    里面出现一个孤立的 `{` 不该让脚本崩掉。
    """
    text = PASTE_STALE if stale else PASTE_ROUTINE
    stage_ch = stage[0] if stage else "<环节>"
    for k, v in (("{轮次}", st["round"]), ("{环节}", stage_ch)):
        text = text.replace(k, v)
    left = [k for k in ("{轮次}", "{环节}", "{家名}") if k in text]

    for name in targets:
        print("─" * 72)
        print(f"# → 贴给 {name}    （轮次 {st['round']}   环节 {stage}）")
        print("─" * 72)
        print(text.replace("{家名}", name))
    print("─" * 72)
    if left:
        print(f"⚠ 模板里还有没填上的槽位：{'、'.join(left)} —— 贴之前自己补。")
    if not stale:
        print("⚠ 对方若回「缺东西 / 字段是空的 / 没有这个文件」，**先别信它搞错了**：")
        print("   核实主线上是什么、它分支上是什么。两边不一样就改用 --stale 那一份（F-17）。")
    print("⚠ 这是**贴进交互窗口**的文本，不是命令——人得在场。")
    print("   一次性命令那条路（不带 --paste 时打印的）没有回话通道，agent 卡住即退出，")
    print("   实测端到端没走完（rounds/executor-adapter/task.md §1.0）。两者不能互相替代。")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--round")
    ap.add_argument("--stage", help="环节序号或名字前缀，如 4 / ④")
    ap.add_argument("--all", action="store_true", help="给全部参与方，不只缺的")
    ap.add_argument("--paste", nargs="?", const="", metavar="家名",
                    help="输出**交互会话**里直接贴的话（≠ 不带参数时打印的一次性命令，"
                         "两者能力不同、产出不同，见 executor-adapter §1.0）；"
                         "不带家名则给当前环节还缺的家")
    ap.add_argument("--stale", action="store_true",
                    help="与 --paste 连用：用「过期投影」那一份（对方报缺东西时，见 F-17）")
    args = ap.parse_args()



    st = status(args.round)
    cfg = st["cfg"]
    agents = load_agents()
    home = str(Path.home())
    root = repo_root()

    # 已完结的轮次绝不分发——它没有「当前环节」，分发就是把人叫去做已经做完的事。
    # 照着分发等于把四家全叫起来重做一遍。首跑即撞上这一条。
    if cfg.get("status") != "ACTIVE":
        print(f"轮次 {st['round']} 的 status = {cfg.get('status')}，不是 ACTIVE，不分发。",
              file=sys.stderr)
        print("要查它走到哪一环，用 round-status.py --round <轮次>。", file=sys.stderr)
        return 2   # 拒绝执行要有区别于成功的退出码，否则调用方看不出被拒

    stage, missing = missing_of(st, args.stage)
    targets = cfg.get("proposers", []) if args.all else missing
    # 处置表算出的验收方等角色也可能是目标
    targets = [t for t in targets if t in agents]

    if args.paste is not None:
        # 指名一家时**不检查它缺不缺**：F-17 那种情况下对方已经动过，
        # 但因为读了过期投影而停在原地，此时它不在 missing 里，却正是要贴的对象。
        # ⚠ 但**必须检查它是不是一家**。两个坑首跑即撞上：
        #   1. 不指名时 `missing` 装的可能是**产物名**——③ 的 missing 是
        #      「裁决稿、处置记录」，照贴就会打出「贴给 处置记录」。
        #   2. 指名一个不存在的家时若不拦，会静默打出一份给虚构对象的话术，
        #      而人照着贴出去才发现没有这个窗口。协议 §8b：拒绝要有区别于成功的退出码。
        who = [args.paste] if args.paste else missing
        bad = [w for w in who if w not in agents]
        if args.paste and bad:
            print(f"{args.paste!r} 不在 agents.toml 里；登记的执行者是："
                  f"{'、'.join(agents)}", file=sys.stderr)
            return 2
        who = [w for w in who if w in agents]
        if not who:
            print(f"轮次 {st['round']}   当前环节 {stage}", file=sys.stderr)
            why = ("本环节缺的是产物不是家（%s），无法按家分发" % "、".join(missing)
                   if missing else "本环节该交的都交了")
            print(f"{why}；要指名一家就 --paste <家名>。", file=sys.stderr)
            return 0
        return paste(st, stage, who, args.stale)

    print(f"轮次 {st['round']}   当前环节 {stage}")
    if not targets:
        if missing:
            print(f"缺：{'、'.join(missing)} —— 但它们不在 agents.toml 里，无法分发")
        else:
            print("没有待分发的对象：本环节该交的都交了，或它是人的动作。")
        return 0

    # 通知路径按**实际存在的那个**报，不硬编码一种拼法。
    # 协议 §6 的规范形式是 `call-<环节>.md`；`<round-id>-call-<环节>.md` 是早期两轮的
    # 历史变体。硬编码前缀会把参与方指到一个不存在的文件，而他们是照协议去找的。
    import os
    stage_ch = stage[0] if stage else "<环节>"
    cands = [f"{cfg['round_dir']}/call-{stage_ch}.md",
             f"{cfg['round_dir']}/{cfg['prefix']}-call-{stage_ch}.md"]
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).stdout.strip()
    call_path = next((c for c in cands if os.path.exists(os.path.join(root, c))),
                     f"{cfg['round_dir']}/call-{stage_ch}.md")
    print(f"待分发 {len(targets)} 家：{'、'.join(targets)}\n")
    print("─" * 72)
    manual = []
    for name in targets:
        a = agents[name]
        cwd = a["worktree"].replace("{home}", home)
        prompt = FIXED_INSTRUCTION
        if "argv" not in a:
            # 登记表里存在、但没有命令行入口的执行者（例：fable 跑在 Cursor 桌面应用里）。
            # **不能静默跳过**——跳过就等于漏掉一家，而漏掉一家的代价见
            # round-protocol「产物、路径与命名」记的那次整轮作废事故。
            manual.append((name, cwd))
            print(f"\n# → {name}    工作目录 {cwd}")
            print(f"# ⚠ 无 argv：此家无命令行入口，**只能人工投喂**。")
            print(f"#   先把它的界面打开在 {cwd}，再把下面这句发给它：")
            print(f"#   {prompt}")
            continue
        argv = [x.replace("{home}", home).replace("{cwd}", cwd)
                 .replace("{prompt}", prompt) for x in a["argv"]]
        # close_stdin：codex exec 会打印 "Reading additional input from stdin..."
        # 并阻塞等 stdin 关闭（实测挂 17 分 29 秒、CPU 00:00:00，一步没跑，
        # 而按字节数判据看像「在推进」）。**必须由调用方显式关**，argv 里做不到——
        # argv 不经 shell，重定向不是参数。
        redir = " < /dev/null" if str(a.get("close_stdin", "")).lower() == "true" else ""
        print(f"\n# → {name}    工作目录 {cwd}")
        print(f"cd {shlex.quote(cwd)} && {' '.join(shlex.quote(x) for x in argv)}{redir}")
    print("\n" + "─" * 72)
    if manual:
        print(f"⚠ 上列 {len(manual)} 家无命令行入口，需人工投喂："
              f"{'、'.join(n for n, _ in manual)}")
        print("  本轮**不可能全自动分发**；这一项须记进 round.md 的「待自动化」。")
    print(f"""
说明：
  · 发出去的话是固定的那一句，不逐轮改写；环节通知落在 {call_path}，各家自取。
  · **成功判据是产物出现，不是命令返回 0。**cursor 未加 --trust 时会拒绝执行
    却仍返回 0（已在 argv 里带上 --trust）。核对用：
        python3 sunmoonai/docs/dev-plan/protocol/round-status.py
  · 本脚本只生成不执行（roadmap 第 3 步）。粘贴跑通一轮、确认判定与措辞无误后，
    再开第 4 步的真调用。""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
