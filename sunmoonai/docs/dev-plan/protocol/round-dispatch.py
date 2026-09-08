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
FIXED_INSTRUCTION = "按 round-protocol 定位当前环节，做你该做的那一步。"


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



MD_PATH = HERE / "dispatch.md"


def md_projection(write: bool) -> int:
    """把 agents.toml 投影成一份可直接敲的 dispatch.md。

    ⚠ **这是投影，不是真源。**真源是 agents.toml——手改 dispatch.md 会在下次
    `--check-md` 时被判出来。之所以要这份 md 而不是让人跑脚本：所有者要**自己看着敲**，
    脚本代跑会把 CLI 的交互吞掉，而 qoder 一类交互多的执行者一旦被吞就只能干等
    （2026-09-07 实测 `codex exec` 挂 17 分 29 秒、CPU 全 0，从外面看像在推进）。

    ⚠ **一份就够，不按环节分。**投喂的那句话每个环节都一样，
    所以 ①②④⑤⑦ 共用这一份；「现在是哪个环节」由各家自己读 call-<环节>.md 判定。
    """
    home = str(Path.home())
    cfg = load_agents()
    lines = [
        "# 投喂命令 ｜ 直接敲",
        "",
        "> ⚠ **本文件由 `round-dispatch.py --write-md` 从 `agents.toml` 生成，不要手改。**",
        "> 真源是 `agents.toml`；改了那边就重新生成。核对是否漂移：",
        "> `python3 round-dispatch.py --check-md`",
        "",
        "> ⚠ **一份通用，不分环节。**发出去的话每个环节都一样——",
        "> 「现在该做哪一步」由各家自己读该轮的 `call-<环节>.md` 判定。",
        "",
        "> ⚠⚠ **`dev-plan-refact` 轮不走这条路。**所有者已把五家各开成一个交互会话，",
        "> 投喂方式是在各窗口说一句「看一下 `sunmoonai/docs/dev-plan/GO.md`，照做」——",
        "> **这样 agent 卡住时人当场能处理，而一次性命令把交互吞掉就只能干等**。",
        "> 本文件保留，因为它记录的是各执行者**确实存在的**命令行形态（将来自动化要用）。",
        "",
        "> ⚠ **本文件列的是登记表里的全部执行者，不是某一轮的参赛方。**",
        "> 某一轮投谁，以该轮 `round.md` 的 `proposers` 为准——",
        "> 多敲一家不会报错，但那一家的产物会让 `round-status.py` 认不出，白跑一次。",
        "",
        "## 敲之前知道两件事",
        "",
        "1. ⚠ **成功判据是产物出现，不是命令返回 0。**",
        "   `cursor` 未加 `--trust` 时会拒绝执行**却仍返回 0**；",
        "   `codex exec` 默认 read-only 时会把活干完但写不进去，退出码同样是 0。",
        "2. ⚠ **`codex exec` 会阻塞等 stdin**（打印 `Reading additional input from stdin...`）。",
        "   下面 `luna` / `kimi` 两条末尾的 `< /dev/null` **不能省**——",
        "   实测省掉后挂 17 分 29 秒、CPU 时间 00:00:00，一步没跑。",
        "",
        "## 命令",
        "",
    ]
    manual = []
    for name, a in cfg.items():
        if name == "meta":
            continue
        cwd = a.get("worktree", "").replace("{home}", home)
        if "argv" not in a:
            manual.append((name, cwd))
            continue
        argv = [x.replace("{home}", home).replace("{cwd}", cwd)
                 .replace("{prompt}", FIXED_INSTRUCTION) for x in a["argv"]]
        redir = " < /dev/null" if str(a.get("close_stdin", "")).lower() == "true" else ""
        lines += [f"### {name}", "",
                  "```bash",
                  f"cd {shlex.quote(cwd)} && {' '.join(shlex.quote(x) for x in argv)}{redir}",
                  "```", ""]
    for name, cwd in manual:
        lines += [f"### {name} —— 无命令行入口", "",
                  f"⚠ **不能用命令投喂**：它没有一次性命令行入口。",
                  f"把它的界面/会话打开在 `{cwd}`，然后发这一句：", "",
                  "```text", FIXED_INSTRUCTION, "```", ""]
    lines += [
        "## 敲完之后",
        "",
        "```bash",
        "cd ~/master/k8s && python3 sunmoonai/docs/dev-plan/protocol/round-status.py",
        "```",
        "",
        "看的是**产物出现没有**。要读内容再开检视面：",
        "",
        "```bash",
        "python3 sunmoonai/docs/dev-plan/protocol/round-review.py --round <轮次>",
        "python3 sunmoonai/docs/dev-plan/protocol/round-review.py --round <轮次> --close",
        "```",
        "",
    ]
    text = "\n".join(lines)
    if write:
        MD_PATH.write_text(text, encoding="utf-8")
        print(f"已生成 {MD_PATH}（{len(lines)} 行投影）")
        return 0
    if not MD_PATH.exists():
        print(f"✗ {MD_PATH} 不存在——跑一次 --write-md", file=sys.stderr)
        return 1
    cur = MD_PATH.read_text(encoding="utf-8")
    if cur == text:
        print("✓ dispatch.md 与 agents.toml 一致")
        return 0
    print("✗ dispatch.md 已与 agents.toml 漂移——重跑 --write-md", file=sys.stderr)
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--round")
    ap.add_argument("--stage", help="环节序号或名字前缀，如 4 / ④")
    ap.add_argument("--write-md", action="store_true",
                    help="把可直接敲的命令生成为 dispatch.md（投影，非真源）")
    ap.add_argument("--check-md", action="store_true",
                    help="核对 dispatch.md 是否仍与 agents.toml 一致；不一致退出 1")
    ap.add_argument("--all", action="store_true", help="给全部参与方，不只缺的")
    args = ap.parse_args()

    if args.write_md or args.check_md:
        return md_projection(write=args.write_md)


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
