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

**平面对照面（`--flat`）**：检视面是每家一棵完整仓，要对比五家得钻五条五层深的路径。
人读起来是「散放」。`--flat` 把各家**同一件产物**摆进同一个目录，逐字节复制，
并写一份 MANIFEST 记录每份来自哪个 commit、多少行、sha256。

⚠ **它是投影，不是第二真源。**权威永远是各家分支上的 commit；对照面可随时删掉重建。
判定一律以 `round-status.py` 为准，不看这里。

用法：
    round-review.py --round <轮次> [--stage ①] [--path <相对路径>]   # 开
    round-review.py --round <轮次> --flat                           # 开 + 建平面对照面
    round-review.py --round <轮次> --close                          # 拆（含对照面）
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
    for k in ("baseline", "prefix", "round_dir"):
        m = re.search(rf"^{k}\s*=\s*\"([^\"]*)\"", text, re.M)
        if m:
            cfg[k] = m.group(1)
    # final_path 可以是字符串，也可以是（可能跨行的）字符串列表——多交付物轮次用后者。
    # ⚠ 只认字符串形式会让列表形式**静默解析成空**，检视面就报「路径未定」而不报错，
    #    与 F-7 同型（判据静默退化）。故两种都认，都认不出就报错。
    m = re.search(r"^final_path\s*=\s*\"([^\"]*)\"", text, re.M)
    if m:
        cfg["final_path"] = [m.group(1)]
    else:
        m = re.search(r"^final_path\s*=\s*\[(.*?)\]", text, re.M | re.S)
        if not m:
            sys.exit(f"{f}: final_path 既不是带引号的字符串，也不是数组——无法确定检视路径")
        cfg["final_path"] = re.findall(r'"([^"]+)"', m.group(1))
    m = re.search(r"^proposers\s*=\s*\[(.*?)\]", text, re.M | re.S)
    cfg["proposers"] = re.findall(r'"([^"]+)"', m.group(1)) if m else []
    return cfg


def build_flat(round_id: str, families: list, rels: list, cfg: dict) -> None:
    """把各家同一件产物摆进同一个目录，逐字节复制 + MANIFEST。

    ⚠ **投影，不是第二真源。**权威是各家分支上的 commit。
    这里的文件是 `git show <分支>:<路径>` 的逐字节副本，改它不改变任何判定。

    为什么需要：检视面是每家一棵完整仓，对比五家要钻五条深路径——
    agent 可以 `git show` 随便取，人不行。投影的必要性由受众决定（findings F-2）。
    """
    import hashlib
    root = REVIEW_ROOT / round_id
    if root.is_dir():
        import shutil
        shutil.rmtree(root)          # 每次重建，避免上一轮的残留冒充当前产物
    root.mkdir(parents=True)

    # 要摆的产物 = final_path 各条 + 该家的评审（若已交）
    rd = cfg.get("round_dir", "")
    items = [(Path(r).stem, r) for r in rels]
    if rd:
        items.append(("review", f"{rd}/reviews/review-<家>.md"))

    lines = [f"# `{round_id}` 平面对照面 · MANIFEST", "",
             "> ⚠ **本目录是投影，不是第二真源。**权威是各家分支上的 commit；",
             "> 这里每个文件都是 `git show <分支>:<路径>` 的**逐字节副本**。",
             "> 判定一律以 `round-status.py` 为准，不看这里。**可随时删掉重建。**", "",
             "重建：`round-review.py --round " + round_id + " --flat`", "",
             "| 产物 | 家 | 来源 commit | 源路径 | 行 | sha256 |",
             "| --- | --- | --- | --- | --- | --- |"]
    n = 0
    for label, tmpl in items:
        d = root / label
        d.mkdir(exist_ok=True)
        for fam in families:
            branch = f"{round_id}/{fam}"
            rel = tmpl.replace("<家>", fam)
            rc, blob = sh("git", "show", f"{branch}:{rel}")
            if rc != 0:
                continue
            head = sh("git", "rev-parse", "--short=8", branch)[1]
            data = blob if blob.endswith("\n") else blob + "\n"
            (d / f"{fam}.md").write_text(data, encoding="utf-8")
            sha = hashlib.sha256(data.encode()).hexdigest()[:16]
            lines.append(f"| {label} | {fam} | `{head}` | `{rel}` | "
                         f"{len(data.splitlines())} | `{sha}` |")
            n += 1
        if not any(d.iterdir()):
            d.rmdir()

    lines += ["", "⚠ **sha256 是本副本的**。要核它与分支一致，跑：", "",
              "```bash", "cd ~/master/k8s",
              'git show "' + round_id + '/<家>:<源路径>" | sha256sum',
              "```", "",
              "⚠ 若某家某件产物缺行，是该家还没交，**不是复制失败**——",
              "以 `round-status.py` 为准。"]
    (root / "MANIFEST.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\n  平面对照面 {root}")
    print(f"      {n} 份产物已按「产物类别 / 家」摆开，MANIFEST.md 记来源与 sha256")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--round", required=True)
    ap.add_argument("--close", action="store_true", help="拆掉本轮全部检视面")
    ap.add_argument("--path", help="只报某个相对路径的存在性；缺省用 round.md 的 final_path")
    ap.add_argument("--flat", action="store_true",
                    help="另建平面对照面：各家同一件产物摆在一起，附 MANIFEST")
    args = ap.parse_args()

    cfg = round_cfg(args.round)
    families = cfg["proposers"]
    # 逐条报，不是只报第一条：多交付物轮次里「只交了其中一份」恰恰是要看见的形态
    rels = [args.path] if args.path else list(cfg.get("final_path") or [])

    if args.close:
        n = 0
        for fam in families:
            d = REVIEW_ROOT / f"{args.round}-{fam}"
            if d.exists():
                rc, out = sh("git", "worktree", "remove", "--force", str(d))
                print(f"  {'✓' if rc == 0 else '✗'} 拆 {d}" + ("" if rc == 0 else f"：{out}"))
                n += rc == 0
        sh("git", "worktree", "prune")
        flat = REVIEW_ROOT / args.round
        if flat.is_dir():
            import shutil
            shutil.rmtree(flat)
            print(f"  ✓ 删平面对照面 {flat}")
        print(f"\n拆掉 {n} 个。⚠ 检视面用完就拆，长期挂着会被误当成参与方。")
        return 0

    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    print(f"轮次 {args.round}   检视路径 " +
          ("；".join(rels) if rels else "(未定)") + "\n")
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
        # ⚠ 逐条报，不是只报第一条：多交付物轮次里「只交了其中一份」
        # 恰恰是要看见的形态（dev-plan-refact 第一版就是缺 ①a 而通过了）。
        present = []
        print(f"  · {fam:8s} {d}")
        print(f"      HEAD {head}")
        for r in rels:
            target = d / r if r else None
            if target and target.exists():
                lines = sum(1 for _ in target.open(encoding="utf-8", errors="replace"))
                rc, sha = sh("sha256sum", str(target))
                print(f"      ✓ {r} —— {lines} 行   sha256 {sha.split()[0][:16]}")
                present.append(r)
            else:
                print(f"      ⚠ **{r} 不存在**——该家还没交，或交到了别的路径")
        if rels and len(present) < len(rels):
            print(f"      ⚠ {fam} 交付不全：{len(present)}/{len(rels)}")
        opened.append(fam)

    if args.flat:
        build_flat(args.round, families, rels, cfg)

    print(f"\n开了 {len(opened)} 个检视面" + (f"，{len(missing)} 家还没开工" if missing else ""))
    print(f"""
⚠ 三条（协议 §7.2）：
  · 检视面是 **--detach 的只读参照**，不占分支——所以不会把任何一家踢出它自己的 worktree；
  · **不要往检视面里写**。要改稿在整合面上改，不在这儿；
  · 读完拆掉：`round-review.py --round {args.round} --close`

看内容：""")
    if args.flat:
        print(f"  · 平面对照面（推荐给人读）：ls ~/review/{args.round}/")
        print(f"    同一件产物的五家摆在一起，来源与 sha256 见该目录 MANIFEST.md")
        print(f"    对比两家：diff ~/review/{args.round}/pipeline/{{luna,kimi}}.md")
    else:
        print(f"  · 平面对照面（推荐给人读）：加 --flat 重跑一次即可生成")
    print(f"  · 完整仓（agent 用）：~/review/{args.round}-<家>/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
