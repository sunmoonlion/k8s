#!/usr/bin/env python3
"""round-review：给人开检视面，用完拆掉。

**为什么需要它**：候选落在各家的 `<轮次>/<家>` 分支上，而所有者的 checkout 在 master。
⚠ **所有者读不到那些分支**——这不是权限问题，是 git 的工作方式：一个 checkout 一次只能
在一个分支上。协议 §7.2「检视面」就是为这件事立的，但此前每轮都靠人临时敲命令，
**没有工具，于是每轮都要重新想一遍，而且容易忘**（2026-09-07 本轮起草者又忘了一次）。

三条来自协议 §7.2 的硬规矩，本脚本按它们实现：

  1. **一个分支只能被一棵 worktree 检出。**所以检视面一律 `--detach` 到 commit 上，
     不占分支——否则持有该分支的那一家会被踢掉；
  2. **检视面不是产物落点。**开出来的是只读参照；任何人不得往里写；
  3. **用完删。**长期挂着的检视 worktree 会被误当成第九个参与方。

用法：
    round-review.py --round <轮次> [--stage ①] [--path <相对路径>]   # 开
    round-review.py --round <轮次> --close                          # 拆
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                      capture_output=True, text=True).stdout.strip()
REVIEW_ROOT = Path.home() / "review"


def sh(*args: str, cwd: str | None = None) -> tuple[int, str]:
    p = subprocess.run(args, cwd=cwd or ROOT, capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr).strip()


def round_cfg(name: str) -> dict:
    f = Path(ROOT) / "sunmoonai/docs/dev-plan/rounds" / name / "round.md"
    if not f.exists():
        sys.exit(f"找不到 {f}")
    text = f.read_text(encoding="utf-8")
    cfg: dict[str, object] = {}
    for k in ("final_path", "baseline", "prefix"):
        m = re.search(rf"^{k}\s*=\s*\"([^\"]*)\"", text, re.M)
        if m:
            cfg[k] = m.group(1)
    m = re.search(r"^proposers\s*=\s*\[(.*?)\]", text, re.M | re.S)
    cfg["proposers"] = re.findall(r'"([^"]+)"', m.group(1)) if m else []
    return cfg


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--round", required=True)
    ap.add_argument("--close", action="store_true", help="拆掉本轮全部检视面")
    ap.add_argument("--path", help="只报某个相对路径的存在性；缺省用 round.md 的 final_path")
    args = ap.parse_args()

    cfg = round_cfg(args.round)
    families = cfg["proposers"]
    rel = args.path or cfg.get("final_path", "")

    if args.close:
        n = 0
        for fam in families:
            d = REVIEW_ROOT / f"{args.round}-{fam}"
            if d.exists():
                rc, out = sh("git", "worktree", "remove", "--force", str(d))
                print(f"  {'✓' if rc == 0 else '✗'} 拆 {d}" + ("" if rc == 0 else f"：{out}"))
                n += rc == 0
        sh("git", "worktree", "prune")
        print(f"\n拆掉 {n} 个。⚠ 检视面用完就拆，长期挂着会被误当成参与方。")
        return 0

    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    print(f"轮次 {args.round}   检视路径 {rel or '(未定)'}\n")
    opened, missing = [], []
    for fam in families:
        branch = f"{args.round}/{fam}"
        rc, _ = sh("git", "rev-parse", "--verify", "--quiet", branch)
        if rc != 0:
            print(f"  ⚠ {fam:8s} 分支 {branch} 不存在——该家尚未开工")
            missing.append(fam)
            continue
        d = REVIEW_ROOT / f"{args.round}-{fam}"
        if not d.exists():
            # --detach：不占分支。占了的话该家的 worktree 会被踢掉（协议 §7.2）
            rc, out = sh("git", "worktree", "add", "--detach", str(d), branch)
            if rc != 0:
                print(f"  ✗ {fam:8s} 开检视面失败：{out}")
                continue
        else:
            # ⚠ 已存在的检视面**不会自己跟进**：它 detach 在开的时候那个 commit 上，
            # 该家之后再提交，这里还是旧内容——而看起来一切正常。
            # 每次跑都刷到分支当前头，并检查退出码（§8c.1 补：写入之后必须验证）。
            want = sh("git", "rev-parse", branch)[1]
            have = sh("git", "-C", str(d), "rev-parse", "HEAD")[1]
            if want != have:
                rc, out = sh("git", "-C", str(d), "checkout", "--detach", "--force", branch)
                if rc != 0:
                    print(f"  ✗ {fam:8s} 刷新失败，仍停在 {have[:8]}：{out}")
                    continue
                got = sh("git", "-C", str(d), "rev-parse", "HEAD")[1]
                if got != want:
                    print(f"  ✗ {fam:8s} 刷新后仍不一致：want {want[:8]} got {got[:8]}")
                    continue
                print(f"  ↻ {fam:8s} 已刷新 {have[:8]} → {want[:8]}")
        head = sh("git", "-C", str(d), "rev-parse", "--short=8", "HEAD")[1]
        target = d / rel if rel else None
        if target and target.exists():
            lines = sum(1 for _ in target.open(encoding="utf-8", errors="replace"))
            rc, sha = sh("sha256sum", str(target))
            print(f"  ✓ {fam:8s} {d}")
            print(f"      HEAD {head}   {rel} —— {lines} 行   sha256 {sha.split()[0][:16]}")
        else:
            print(f"  ⚠ {fam:8s} {d}")
            print(f"      HEAD {head}   ⚠ **{rel} 不存在**——该家还没交，或交到了别的路径")
        opened.append(fam)

    print(f"\n开了 {len(opened)} 个检视面" + (f"，{len(missing)} 家还没开工" if missing else ""))
    print(f"""
⚠ 三条（协议 §7.2）：
  · 检视面是 **--detach 的只读参照**，不占分支——所以不会把任何一家踢出它自己的 worktree；
  · **不要往检视面里写**。要改稿在整合面上改，不在这儿；
  · 读完拆掉：`round-review.py --round {args.round} --close`

看内容直接进目录读，或：
  diff <(cat ~/review/{args.round}-luna/{rel}) <(cat ~/review/{args.round}-kimi/{rel})""")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
