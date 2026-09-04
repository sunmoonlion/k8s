#!/usr/bin/env python3
"""环节判定：从产物反推当前环节，不看任何人的声明。

**为什么它不是第三个被删的脚本**（见 `constraints.md`「保证这些被遵守的三层」）：

1. **不靠人记得跑**：它是 `round-protocol.md`「收到『继续』时怎么办」第 4 问的机器化——
   每个执行者收到固定指令后的第一个动作就是跑它。它挂在必经路径上，
   与 `doc-gate.py` 挂在 pre-commit 是同一种做法。
2. **结论不取决于工作区状态**：一切判定对照 **git 提交**（`git show <分支>:<路径>`），
   不看工作区文件。同一个仓库状态在任何机器上给出同一结论。

用法：
    round-status.py                # 自动找 status=ACTIVE 的轮次
    round-status.py --round refact # 指定轮次
    round-status.py --json         # 机器可读输出
    round-status.py --verify       # 机械验收：把 ⑤ 里机器能判的部分判掉

退出码：0 正常；2 用法错误或找不到 ACTIVE 轮次。
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROUNDS_DIR = "sunmoonai/docs/dev-plan/rounds"


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, check=True)
    return Path(out.stdout.strip())


def git(*args: str) -> tuple[int, str]:
    p = subprocess.run(["git", *args], capture_output=True, text=True)
    return p.returncode, p.stdout.strip()


def committed(branch: str, path: str) -> bool:
    """该分支的提交里有没有这个文件。不看工作区。"""
    return git("show", f"{branch}:{path}")[0] == 0


def blob_lines(branch: str, path: str) -> int:
    code, out = git("show", f"{branch}:{path}")
    return len(out.splitlines()) if code == 0 else 0


def parse_round(md: Path) -> dict:
    """round.md 里的机器可读块：```toml 之后的 key = value 行。

    人读正文，机器读这个块——同一份文件，两个读者，不产生第二个真源。
    """
    text = md.read_text(encoding="utf-8")
    m = re.search(r"```toml\n(.*?)```", text, re.S)
    if not m:
        return {}
    cfg: dict = {}
    for line in m.group(1).splitlines():
        line = line.split("#", 1)[0].strip()
        if not line or "=" not in line:
            continue
        k, v = (x.strip() for x in line.split("=", 1))
        if v.startswith("["):
            cfg[k] = [s.strip().strip('"') for s in v.strip("[]").split(",") if s.strip()]
        else:
            cfg[k] = v.strip('"')
    return cfg


def find_active(root: Path, want: str | None) -> tuple[str, dict]:
    base = root / ROUNDS_DIR
    if not base.is_dir():
        sys.exit(f"没有 {ROUNDS_DIR}/ —— 本仓还没有按 round-protocol 建轮次目录")
    found = []
    for d in sorted(base.iterdir()):
        md = d / "round.md"
        if not md.is_file():
            continue
        cfg = parse_round(md)
        if want and d.name == want:
            return d.name, cfg
        if not want and cfg.get("status") == "ACTIVE":
            found.append((d.name, cfg))
    if want:
        sys.exit(f"找不到轮次 {want}")
    if not found:
        sys.exit("没有 status=ACTIVE 的轮次")
    if len(found) > 1:
        sys.exit(f"有多个 ACTIVE 轮次：{[n for n, _ in found]} —— 协议规定同时只允许一个")
    return found[0]


def artifact(cfg: dict, stage: str, who: str) -> str:
    return f"{cfg['round_dir']}/{cfg['prefix']}-{stage}-{who}.md"


def stage_table(cfg: dict) -> list[dict]:
    """每个环节：谁该交、交了没。判据即命令，结论只依赖 git 提交。"""
    proposers = cfg.get("proposers", [])
    arb = cfg.get("arbiter_branch", "")
    final_path = cfg["final_path"]
    rounds: list[dict] = []

    # ① 提案：候选写在共享最终路径同名文件
    rows = {w: committed(w, final_path) and blob_lines(w, final_path) != blob_lines("master", final_path)
            for w in proposers}
    rounds.append({"stage": "① 提案", "who": proposers, "done": rows})

    # ② 互评
    rows = {w: committed(w, artifact(cfg, "review", w)) for w in proposers}
    rounds.append({"stage": "② 互评", "who": proposers, "done": rows})

    # ③ 裁决：裁决稿 + 处置记录都在整合分支上
    disp = f"{cfg['round_dir']}/{cfg['prefix']}-disposition.md"
    rows = {"裁决稿": committed(arb, final_path), "处置记录": committed(arb, disp)}
    rounds.append({"stage": "③ 裁决", "who": [cfg.get("arbiter", "?")], "done": rows})

    # ④ 异议：只发给被处置到的家；经裁定免除的不计
    excused = cfg.get("excused_objection", [])
    who4 = [w for w in proposers if w not in excused]
    rows = {w: committed(w, artifact(cfg, "objection", w)) for w in who4}
    for w in excused:
        rows[f"{w}(免除)"] = True
    rounds.append({"stage": "④ 异议", "who": who4, "done": rows})

    # ⑤ 验收
    acc = cfg.get("acceptor", "")
    rows = {acc: committed(acc, artifact(cfg, "acceptance", acc))} if acc else {}
    rounds.append({"stage": "⑤ 验收", "who": [acc] if acc else [], "done": rows})

    # ⑥ 确认：人的动作，不可由命令判定
    rounds.append({"stage": "⑥ 确认", "who": ["human"], "done": None})
    return rounds


# ---------------------------------------------------------------- 机械验收

def _sections(text: str, keys: list[str]) -> dict[str, str]:
    """按 '## <key>' 切段。冻结节的标题本身就是冻结的，所以可以按标题定位。"""
    out: dict[str, str] = {}
    for key in keys:
        pat = re.compile(rf"^## {re.escape(key)}.*?(?=^## |\Z)", re.S | re.M)
        m = pat.search(text)
        out[key] = m.group(0) if m else ""
    return out


def verify(cfg: dict) -> int:
    """机械验收：只判机器能判的，判不了的显式交回给人。

    **这不是替代 ⑤ 验收**，是把 ⑤ 里的机械部分从人手里拿走，
    让验收方只面对真正需要判断的部分。判不了的一律标「人判」，不许默认通过。
    """
    import hashlib

    arb = cfg["arbiter_branch"]
    final_path = cfg["final_path"]
    disp = f"{cfg['round_dir']}/{cfg['prefix']}-disposition.md"
    fails = 0

    def line(tag: str, ok: bool | None, msg: str) -> None:
        nonlocal fails
        mark = {True: "✅", False: "❌", None: "🔶人判"}[ok]
        if ok is False:
            fails += 1
        print(f"  {mark} {tag}  {msg}")

    print("═══ 机械验收 ═══\n")

    # 1. 冻结区逐字节
    frozen = cfg.get("frozen_sections", [])
    if not frozen:
        line("冻结区", None, "round.md 未声明 frozen_sections，无法判定")
    else:
        base = git("show", f"master:{final_path}")[1]
        head = git("show", f"{arb}:{final_path}")[1]
        bs, hs = _sections(base, frozen), _sections(head, frozen)
        bad = [k for k in frozen
               if not bs[k] or hashlib.sha256(bs[k].encode()).digest()
               != hashlib.sha256(hs[k].encode()).digest()]
        line("冻结区逐字节", not bad,
             f"{len(frozen)} 节全部一致" if not bad else f"不一致：{bad}")

    # 2. 处置记录与提交范围双向对账
    # 只对账「触及裁决稿」的提交：协议要求「一条主张一个提交」，指的是主张；
    # 环节通知、裁定记录是另一类产物，不该被要求登记进处置记录。
    code, log = git("log", "--format=%h %s", f"master..{arb}", "--", final_path)
    commits = [l.split(" ", 1) for l in log.splitlines()] if code == 0 else []
    dtext = git("show", f"{arb}:{disp}")[1]
    unlogged = [f"{h} {t[:28]}" for h, t in commits if h not in dtext]
    line("提交→处置记录", not unlogged,
         f"{len(commits)} 个触及裁决稿的提交全部登记" if not unlogged
         else f"{len(unlogged)} 个提交未登记：{unlogged[:4]}")

    claimed = set(re.findall(r"`([0-9a-f]{7,8})`", dtext))
    known = {h for h, _ in commits} | {cfg.get("baseline", "")}
    ghosts = sorted(c for c in claimed if c not in known
                    and git("cat-file", "-e", c)[0] != 0)
    line("处置记录→提交", not ghosts,
         "记录里的 commit 都存在" if not ghosts else f"不存在的 commit：{ghosts}")

    # 3. 外部仓锚点：路径存在且行号可达
    text = git("show", f"{arb}:{final_path}")[1]
    anchors = re.findall(r"~/repo/([A-Za-z0-9_.-]+)/([A-Za-z0-9_./-]+):(\d+)", text)
    broken = []
    for repo, rel, ln in anchors:
        f = Path.home() / "repo" / repo / rel
        if not f.is_file():
            broken.append(f"{repo}/{rel} 不存在")
        else:
            try:
                if len(f.read_text(errors="ignore").splitlines()) < int(ln):
                    broken.append(f"{repo}/{rel}:{ln} 行号越界")
            except OSError:
                broken.append(f"{repo}/{rel} 读不了")
    line("外部仓锚点", not broken,
         f"{len(anchors)} 处路径与行号可达" if not broken else f"{broken[:4]}")
    line("锚点语义", None, f"{len(anchors)} 处锚点是否**支持**其断言——机器判不了，抽查交人")

    # 4. 编号出处：I1–I8 两文档重叠，裸引用有歧义
    bare = len(re.findall(r"(?<![A-Za-z0-9_-])I[1-8](?![0-9])", text))
    line("编号出处", None,
         f"裸 I1–I8 共 {bare} 处；两套 I 系列区间重叠，逐处是否写明出处文档交人判")

    # 5. 可机械判的验收标准
    for tag, pat, want in cfg_checks(cfg):
        hits = len(re.findall(pat, text))
        line(tag, (hits == 0) if want == "absent" else (hits > 0),
             f"命中 {hits} 处")

    print()
    print(f"机械判定失败 {fails} 项；标「人判」的项**不许默认通过**，须由验收方逐项给结论。")
    return 1 if fails else 0


def cfg_checks(cfg: dict) -> list[tuple[str, str, str]]:
    """round.md 可声明 mechanical_absent：一批「必须零命中」的正则。"""
    out = []
    for item in cfg.get("mechanical_absent", []):
        tag, _, pat = item.partition("::")
        out.append((tag, pat, "absent"))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--round")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()

    root = repo_root()
    name, cfg = find_active(root, args.round)
    for req in ("final_path", "round_dir", "prefix"):
        if req not in cfg:
            sys.exit(f"round.md 的 toml 块缺字段：{req}")

    if args.verify:
        return verify(cfg)

    table = stage_table(cfg)
    current = None
    for r in table:
        if r["done"] is None:
            current = r["stage"]
            break
        if not all(r["done"].values()):
            current = r["stage"]
            break
    if current is None:
        current = "⑦ 清理与发布"

    if args.json:
        print(json.dumps({"round": name, "cfg": cfg, "stages": table,
                          "current": current}, ensure_ascii=False, indent=2))
        return 0

    print(f"轮次 {name}   档位 {cfg.get('tier','?')}   状态 {cfg.get('status','?')}")
    print(f"共享最终路径 {cfg['final_path']}")
    print(f"基座 {cfg.get('baseline','无')}   裁决方 {cfg.get('arbiter','?')}"
          f"（{cfg.get('arbiter_branch','?')}）   验收方 {cfg.get('acceptor','未定')}")
    print()
    for r in table:
        if r["done"] is None:
            print(f"  {r['stage']}   —— 人的动作，不可由命令判定")
            continue
        marks = "  ".join(f"{k}{'✅' if v else '⬜'}" for k, v in r["done"].items())
        state = "完成" if all(r["done"].values()) else "进行中"
        print(f"  {r['stage']}   {state}   {marks}")
    print()
    print(f"当前环节：{current}")
    missing = []
    for r in table:
        if r["stage"] == current and r["done"]:
            missing = [k for k, v in r["done"].items() if not v]
    if missing:
        print(f"缺：{'、'.join(missing)}")
    print()
    print("判据即命令，结论只依赖 git 提交；工作区文件不参与判定。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
