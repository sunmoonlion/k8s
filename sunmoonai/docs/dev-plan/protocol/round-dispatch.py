#!/usr/bin/env python3
"""投喂：打印所有者要贴进各家窗口的那段话。只打印，不发送。

状态不自己算，一律调 `round-status.py --json` 取。家名对照 `agents.toml` 校验。

用法：
    round-dispatch.py                  # 当前环节还缺谁，就打印给谁的
    round-dispatch.py cursor           # 只打印给这一家（不检查它缺不缺）
    round-dispatch.py --all            # 给全部参赛方
    round-dispatch.py --stage 4        # 按指定环节算缺谁，接 4 或 ④
    round-dispatch.py --round runtime  # 指定轮次（与 round-status.py 同名同义）

退出码：
    0  正常打印（或本环节没有要贴的对象）
    2  拒绝：轮次不是 ACTIVE、家名不是登记的执行者、指定的环节不存在，或 round-status.py 判定失败

不打印命令行一次性投喂的命令：那条路会用权限开关把审批提前答掉，所有者当场批不了，
2026-09-10 判定不用。各家的命令行形态仍登记在 agents.toml。
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


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



# 所有者贴进各家窗口的那段话，本脚本打印的就是它。原文只在这里，别处不存副本。
PASTE_ROUTINE = r"""看一下 ~/master/k8s/sunmoonai/docs/dev-plan/GO.md，照做。

⚠ 只认主线那一份。你 worktree 里的同名文件是投影，从 ① 起就不再跟进主线，
几乎一定是旧的。GO.md 开头有一条 diff 自检，先跑它。不要把主线合并进你的分支。
"""


def paste(st: dict, stage: str, targets: list[str]) -> int:
    """打印交互窗口里要贴的话，每家一段。只打印，不发送。

    路径在 PASTE_ROUTINE 里写死为主线绝对路径：相对路径会被解析到参赛方
    worktree 里的旧副本（findings.md F-17）。对方若仍报「缺东西」，是供给出了错，
    该修的是脚本或文档，不另设给人用的应对话术（所有者 2026-09-10）。
    """
    for name in targets:
        print("─" * 72)
        print(f"# → 贴给 {name}    （轮次 {st['round']}   环节 {stage}）")
        print("─" * 72)
        print(PASTE_ROUTINE.rstrip("\n"))
    print("─" * 72)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="打印所有者要贴进各家窗口的那段话")
    ap.add_argument("who", nargs="?", metavar="家名",
                    help="只打印给这一家；省略则给当前环节还缺的每一家")
    ap.add_argument("--round", help="轮次，即 rounds/ 下的目录名；省略则取唯一 ACTIVE 的那一轮")
    ap.add_argument("--stage", help="按指定环节算缺谁，接 4 或 ④")
    ap.add_argument("--all", action="store_true", help="给全部参赛方，不只缺的")
    args = ap.parse_args()

    st = status(args.round)
    cfg = st["cfg"]
    agents = load_agents()
    # 能投喂的只有执行者：排除配置段 meta 和人（agents.toml 里 kind = "human" 的 owner）。
    execs = [n for n, a in agents.items() if n != "meta" and a.get("kind") != "human"]

    # 已完结的轮次不投喂：它没有「当前环节」，照着贴等于把各家叫去重做做完的事。
    if cfg.get("status") != "ACTIVE":
        print(f"轮次 {st['round']} 的 status = {cfg.get('status')}，不是 ACTIVE，不投喂。",
              file=sys.stderr)
        return 2

    stage, missing = missing_of(st, args.stage)

    if args.who:
        # 指名一家时不检查它缺不缺：所有者可能要对已交过的一家重贴一次。
        # 但必须是登记的执行者，否则会打出一段给不存在的窗口的话。
        if args.who not in execs:
            print(f"{args.who!r} 不是登记的执行者；可选：{'、'.join(execs)}", file=sys.stderr)
            return 2
        who = [args.who]
    else:
        pool = cfg.get("proposers", []) if args.all else missing
        # ③ 这类环节的 missing 装的是产物名（「裁决稿、处置记录」），不是家名，滤掉。
        who = [w for w in pool if w in execs]
        if not who:
            why = (f"本环节缺的是产物不是家（{'、'.join(missing)}）" if missing
                   else "本环节该交的都交了")
            print(f"轮次 {st['round']}   当前环节 {stage}：{why}，没有要贴的对象。"
                  f"要指名一家：round-dispatch.py <家名>", file=sys.stderr)
            return 0
    return paste(st, stage, who)


if __name__ == "__main__":
    sys.exit(main())
