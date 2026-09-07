#!/usr/bin/env python3
"""环节判定：从产物反推当前环节，不看任何人的声明。

**为什么它不是第三个被删的脚本**（见 `constraints.md`「保证这些被遵守的三层」）：

1. **不靠人记得跑**：它是 `round-protocol.md`「收到『继续』时怎么办」第 4 问的机器化——
   每个执行者收到固定指令后的第一个动作就是跑它。它挂在必经路径上，
   与 `doc-gate.py` 挂在 pre-commit 是同一种做法。
2. **结论不取决于工作区状态**：一切判定对照 **git 提交**（`git show <分支>:<路径>`），
   不看工作区文件。同一个仓库状态在任何机器上给出同一结论。

用法：
    round-status.py                  # 自动找 status=ACTIVE 的轮次
    round-status.py --round runtime  # 指定轮次（值是 rounds/ 下的目录名）
    round-status.py --json           # 机器可读输出
    round-status.py --round runtime --verify   # 机械验收：把 ⑤ 里机器能判的部分判掉

退出码：
    0  正常；`--verify` 时表示机械判定零失败
    1  `--verify` 有失败项（标「人判」的不计入）
    2  用法错误：找不到指定轮次、没有 ACTIVE 轮次、有多个 ACTIVE、round.md 缺字段

同目录的配套：`round-dispatch.py`（只生成环节通知，不执行）、`agents.toml`（五家登记）、
`README.md`（协议条文与本目录文件的对应表）。

调用方式同时写在 `round-protocol.md`「两个脚本怎么调」一节——
那一节里的每条命令都以能实跑为准，改了参数名必须同步改那一节。
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


def die(msg: str) -> None:
    """用法错误一律退 2。

    `sys.exit(<字符串>)` 把字符串打到 stderr 之后退的是 **1**，不是 2；
    本文件的 docstring 一直写着 2。调用方按 2 判分支就会全部落空。
    """
    print(msg, file=sys.stderr)
    raise SystemExit(2)


def git(*args: str) -> tuple[int, str]:
    p = subprocess.run(["git", *args], capture_output=True, text=True)
    return p.returncode, p.stdout.strip()


_TREE: dict[str, set[str]] = {}


def tree(ref: str) -> set[str]:
    """某个 ref 的全部文件路径。缓存，避免逐文件起 git 进程。"""
    if ref not in _TREE:
        code, out = git("ls-tree", "-r", "--name-only", ref)
        _TREE[ref] = set(out.splitlines()) if code == 0 else set()
    return _TREE[ref]


def committed(branch: str, path: str) -> bool:
    """该 ref 的提交里有没有这个文件。不看工作区。

    空字符串直接判否：`git show :<路径>` 取的是**索引**，
    工单里 arbiter_branch 缺省时会静默地拿暂存区当分支答。
    """
    return bool(branch) and path in tree(branch)


ARCH_SUBDIRS = ("reviews/", "")


def artifact_paths(cfg: dict, kind: str, who: str | None = None) -> list[str]:
    """一件产物可能落在哪几个路径上。

    协议正文写 `rounds/<id>/<kind>-<名>.md`，但实跑出现过两种变体：

    · 评审/异议/验收归档进 `reviews/` 子目录（`refact-fable`、`runtime` 两轮）。
      这两处已被**已发布**文档当证据锚引用（`runtime-architecture.md @ ceb7291c:454/458/461`、
      `refact-fable.md @ ceb7291c:23/29/38/43`），改名等于让已发布的证据链失效，所以不改文件、改判据。
    · 处置记录与环节通知带 `<round-id>-` 前缀（`runtime`、`_fixups` 两轮）。

    四种组合全找过才算缺。2026-09-06 之前只按一个拼法找，把已经走完七环节发布掉的
    `runtime` 轮判成「当前环节 ①，缺五家」——**覆盖不全的判据会给假答案**，
    这次的方向是假失败（安全侧），但同一个毛病换个方向就是假通过。
    """
    stem = f"{kind}-{who}" if who else kind
    return [f"{cfg['round_dir']}/{sub}{pre}{stem}.md"
            for sub in ARCH_SUBDIRS for pre in ("", f"{cfg['prefix']}-")]


def refs_for(cfg: dict, name: str, who: str | None) -> list[str]:
    """一件产物可能提交在哪个 ref 上。

    轮次结束后各家分支会被回收（`runtime/*` 现在一个都不在了），产物归档进主线。
    只认 `<轮次>/<家>` 分支的话，每一轮做完之后都会被自己判成「没做」。
    """
    # `<轮次>/<家>` 与**裸的 `<家>`** 都要认。环节通知说的是「commit 到你自己的分支」，
    # 各家对此的落法不一致：2026-09-06 runtime-refact ① 实测，luna / cursor 建了
    # `runtime-refact/<家>`，qwen 直接提交在 `qwen` 上。只认前者会把**照指示做的那家
    # 判成没交**，进而按逾期处理——判据把合规者判出局，比漏判更危险。
    refs = ([f"{name}/{who}", who] if who else []) + [cfg.get("arbiter_branch", ""), "master", "HEAD"]
    return [r for r in refs if r]


def locate(cfg: dict, name: str, kind: str, who: str | None = None) -> tuple[str, str] | None:
    """产物在哪个 ref 的哪个路径上；找不到返回 None。"""
    for path in artifact_paths(cfg, kind, who):
        for ref in refs_for(cfg, name, who):
            if committed(ref, path):
                return path, ref
    return None


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
        die(f"没有 {ROUNDS_DIR}/ —— 本仓还没有按 round-protocol 建轮次目录")
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
        die(f"找不到轮次 {want}")
    if not found:
        die("没有 status=ACTIVE 的轮次")
    if len(found) > 1:
        die(f"有多个 ACTIVE 轮次：{[n for n, _ in found]} —— 协议规定同时只允许一个")
    return found[0]


def stage_table(cfg: dict, name: str) -> list[dict]:
    """每个环节：谁该交、交了没。判据即命令，结论只依赖 git 提交。

    `skip_stages` 是唯一能让一个环节不算数的东西，而且必须**写在工单里**。
    参与方为空**不等于**该环节完成——`all({})` 为真，会让空环节被静默跳过，
    那正是协议「判据自身的质量」点名的那类错。要跳过就明写，不许靠空集合默认。
    """
    proposers = cfg.get("proposers", [])
    skip = set(cfg.get("skip_stages", []))
    final_path = cfg["final_path"]
    arb = cfg.get("arbiter_branch", "")
    rounds: list[dict] = []

    def add(tag: str, who: list[str], rows: dict) -> None:
        rounds.append({"stage": tag, "who": who, "done": rows,
                       "skipped": tag[0] in skip})

    # ① 提案：轮次进行中，候选在各家分支的共享最终路径上；
    #    归档后在 rounds/<id>/[reviews/]candidate-<名>.md。两处认一处。
    rows = {}
    for w in proposers:
        # 候选可能在：该家的任一 ref 上的共享最终路径（进行中），或归档后的 candidate 文件。
        # **不要只查一个 ref** —— 见 refs_for 的注释。
        live = any(committed(r, final_path)
                   and blob_lines(r, final_path) != blob_lines("master", final_path)
                   for r in refs_for(cfg, name, w))
        rows[w] = live or locate(cfg, name, "candidate", w) is not None
    add("① 提案", proposers, rows)

    # ② 互评
    add("② 互评", proposers,
        {w: locate(cfg, name, "review", w) is not None for w in proposers})

    # ③ 裁决：裁决稿 + 处置记录
    add("③ 裁决", [cfg.get("arbiter", "?")],
        {"裁决稿": committed(arb, final_path) or committed("master", final_path),
         "处置记录": locate(cfg, name, "disposition") is not None})

    # ④ 异议：只发给被处置到的家；经裁定免除的不计
    excused = cfg.get("excused_objection", [])
    who4 = [w for w in proposers if w not in excused]
    rows = {w: locate(cfg, name, "objection", w) is not None for w in who4}
    rows.update({f"{w}(免除)": True for w in excused})
    add("④ 异议", who4, rows)

    # ⑤ 验收
    acc = cfg.get("acceptor", "")
    add("⑤ 验收", [acc] if acc else {},
        {acc: locate(cfg, name, "acceptance", acc) is not None} if acc else {})

    # ⑥ 确认：人的动作，但**留下的痕迹**是机器可查的。
    #    这一轮自己的规矩就写在 rulings.md 抬头：「回执只认落盘——对话里说『同意』不算」，
    #    「人确认 = 是 的行，以所有者 commit 为生效时刻」。那一列就是判据。
    #    早先把 ⑥ 一律标成「不可由命令判定」，等于让**任何**轮次都到不了 ⑦，
    #    于是每一轮走完都会跟自己的 status=DONE 打架。人判的是内容，不是有没有落盘。
    pend = pending_rulings(cfg, name)
    if pend is None:
        rounds.append({"stage": "⑥ 确认", "who": ["human"], "done": None,
                       "skipped": "⑥" in skip})
    else:
        add("⑥ 确认", ["human"],
            {f"rulings.md 无待确认（{len(pend)} 条待）" if pend else "rulings.md 全部已确认": not pend})
    return rounds


def _cells(row: str) -> list[str]:
    """切一行 markdown 表格。

    **先剥掉行内代码再切**：裁定行里出现过 `... || echo "❌ 不在 git 仓内"`，
    反引号里的 `||` 会被当成两个空单元格，把后面每一列都推错位——
    `R4` 的「人确认」因此读成空，看上去像「没确认」。
    """
    masked = re.sub(r"`[^`]*`", "◇", row)
    return [c.strip() for c in masked.strip().strip("|").split("|")]


def pending_rulings(cfg: dict, name: str) -> list[str] | None:
    """rulings.md 里「人确认」尚未落成「是」的裁定编号。

    返回 None = 这一轮没有 rulings.md，机器判不了，交回给人。
    """
    hit = locate(cfg, name, "rulings")
    if not hit:
        return None
    text = git("show", f"{hit[1]}:{hit[0]}")[1]
    lines = text.splitlines()
    col = None
    for i, ln in enumerate(lines):
        cells = _cells(ln)
        if "人确认" in cells:
            col = cells.index("人确认")
            start = i + 2          # 跳过 |---| 分隔行
            break
    if col is None:
        return None
    pend = []
    for ln in lines[start:]:
        if not ln.startswith("|"):
            break
        cells = _cells(ln)
        if len(cells) <= col or not cells[0]:
            continue
        val = cells[col].replace("*", "")
        if not val.startswith("是"):
            pend.append(cells[0])
    return pend


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

    arb = cfg.get("arbiter_branch") or "master"
    final_path = cfg["final_path"]
    hit = locate(cfg, cfg.get("round_id", ""), "disposition")
    disp = hit[0] if hit else f"{cfg['round_dir']}/disposition.md"
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
    if cfg.get("status") != "ACTIVE":
        # ⑦ 发布后 `master..<裁决方>` 不再是「本轮新增的提交」：裁决稿已并入主线，
        # 剩下的差集是发布方式的产物（squash / cherry-pick），与登记完整性无关。
        # 这一项**只在 ⑤ 之前有意义**，事后跑会报出与产物无关的失败。
        # 不静默跳过——标「人判」并说明为什么判不了，见协议 §8.1 第 2 条。
        line("提交→处置记录", None,
             f"轮次 status={cfg.get('status')}，非 ACTIVE：发布后该对账失去意义，"
             f"不判（此刻差集 {len(unlogged)} 个，不构成结论）")
    else:
        line("提交→处置记录", not unlogged,
             f"{len(commits)} 个触及裁决稿的提交全部登记" if not unlogged
             else f"{len(unlogged)} 个提交未登记：{unlogged[:4]}")

    claimed = set(re.findall(r"`([0-9a-f]{7,8})`", dtext))
    known = {h for h, _ in commits} | {cfg.get("baseline", "")}
    ghosts = sorted(c for c in claimed if c not in known
                    and git("cat-file", "-e", c)[0] != 0)
    line("处置记录→提交", not ghosts,
         "记录里的 commit 都存在" if not ghosts else f"不存在的 commit：{ghosts}")

    # 3. 锚点：路径存在且行号可达
    #    两种写法都要覆盖——只认 ~/repo/ 全路径会漏掉大半：
    #    2026-09-04 首版正则只匹配全路径，17 处通过，而短路径形式的 33 处
    #    （`00-prerequisites.yaml:109`、`protocol/README.md:52`）一处未验，
    #    是验收方手工核到才暴露的。**覆盖不全的检查比没有检查更危险**，
    #    因为它会报「通过」。
    text = git("show", f"{arb}:{final_path}")[1]
    # 每个根带一个前缀：`~/repo/codex/lib.rs` 要先剥掉 `~/repo/codex/` 才能
    # 和该仓 ls-files 的相对路径比对。首版漏了这一步，全路径锚点全部误报「找不到」。
    roots: list[tuple[Path, str]] = []
    for r in cfg.get("anchor_roots", []):
        if r == ".":
            roots.append((repo_root(), ""))
        else:
            roots.append((Path(r.replace("~", str(Path.home()))), r.rstrip("/") + "/"))
    index: dict[Path, list[str]] = {}
    for rp, _ in roots:
        code, out = git("-C", str(rp), "ls-files")
        index[rp] = out.splitlines() if code == 0 else []

    anchors = set(re.findall(
        r"(?<![A-Za-z0-9_/.-])((?:~/repo/)?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*"
        r"\.(?:py|ts|md|rs|toml|yaml|yml|json|sh))[:：](\d+)", text))
    ok = miss = amb = out_of_range = 0
    bad: list[str] = []
    for rel, ln in sorted(anchors):
        hits: list[Path] = []
        for rp, prefix in roots:
            # 带前缀的锚点只在对应的根里找；短路径按后缀在各根里找
            # （`protocol/README.md` 命中 `packages/sdk/protocol/README.md`）
            want = rel[len(prefix):] if prefix and rel.startswith(prefix) else rel
            if prefix and not rel.startswith(prefix) and rel.startswith("~/repo/"):
                continue  # 指名了别的仓
            for f in index[rp]:
                if f == want or f.endswith("/" + want):
                    hits.append(rp / f)
        hits = sorted(set(hits))
        if not hits:
            miss += 1; bad.append(f"{rel}:{ln} 找不到")
        elif len(hits) > 1:
            amb += 1
        else:
            try:
                n = len(hits[0].read_text(errors="ignore").splitlines())
                if n < int(ln):
                    out_of_range += 1; bad.append(f"{rel}:{ln} 越界（共 {n} 行）")
                else:
                    ok += 1
            except OSError:
                miss += 1; bad.append(f"{rel}:{ln} 读不了")
    line("锚点路径与行号", miss == 0 and out_of_range == 0,
         f"共 {len(anchors)} 处：{ok} 可达、{amb} 路径有歧义交人、"
         f"{miss} 找不到、{out_of_range} 行号越界"
         + (f"　{bad[:3]}" if bad else ""))
    if amb:
        line("歧义锚点", None, f"{amb} 处短路径在多个根下都能匹配，需人确认指的是哪一个")
    line("锚点语义", None, f"{len(anchors)} 处锚点是否**支持**其断言——机器判不了，抽查交人")

    # 3b. AT-* 锚定计数：区分「用于锚定」与「范围引用」
    ats = set(re.findall(r"AT-\d{2}", text))
    rng = set(re.findall(r"AT-(\d{2})`?\s*[…\.]{1,3}\s*`?AT-(\d{2})", text))
    endpoints = {f"AT-{a}" for a, b in rng} | {f"AT-{b}" for a, b in rng}
    anchored = ats - endpoints
    line("AT-* 锚定计数", None,
         f"全文 {len(ats)} 个不同编号，其中 {len(endpoints)} 个来自范围引用；"
         f"**用于锚定的 {len(anchored)} 个** —— 是否足够由人判")

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
            die(f"round.md 的 toml 块缺字段：{req}")

    if args.verify:
        return verify(cfg)

    table = stage_table(cfg, name)
    current = None
    for r in table:
        if r["skipped"]:
            continue                      # 工单明写跳过，才跳过
        if r["done"] is None:
            current = r["stage"]
            break
        if not r["done"]:
            # 参与方还没指派（例：验收方由规则算出，工单里留空）。
            # **空集合不是「全部完成」**——all({}) 为真会让当前环节直接跳过这一环，
            # 那是协议「判据自身的质量」点名的那类错：覆盖不全的检查会报「通过」。
            current = r["stage"]
            break
        if not all(r["done"].values()):
            current = r["stage"]
            break
    if current is None:
        current = "⑦ 清理与发布"

    # 声明 vs 计算。**声明不参与计算**——脚本存在的理由就是不看任何人的声明；
    # 但两者对不上是个信号，不许静默采信任一方，也不许让声明改掉算出来的结论。
    declared = cfg.get("status", "?")
    done = current == "⑦ 清理与发布"
    conflict = ""
    if declared == "DONE" and not done:
        conflict = (f"⚠ round.md 声明 DONE，按产物却算到「{current}」。"
                    "二者必有一错：要么产物没归档到判据找得到的地方，要么这一轮其实没走完。")
    elif declared == "ACTIVE" and done:
        conflict = "⚠ 七个环节的产物都齐了，round.md 却还是 ACTIVE——该走 ⑦ 收尾并改 status。"

    if args.json:
        print(json.dumps({"round": name, "cfg": cfg, "stages": table,
                          "current": current, "conflict": conflict},
                          ensure_ascii=False, indent=2))
        return 0

    print(f"轮次 {name}   档位 {cfg.get('tier','?')}   状态 {cfg.get('status','?')}")
    print(f"共享最终路径 {cfg['final_path']}")
    print(f"基座 {cfg.get('baseline','无')}   裁决方 {cfg.get('arbiter','?')}"
          f"（{cfg.get('arbiter_branch','?')}）   验收方 {cfg.get('acceptor','未定')}")
    print()
    for r in table:
        if r["skipped"]:
            print(f"  {r['stage']}   跳过   —— 工单 skip_stages 明写")
            continue
        if r["done"] is None:
            print(f"  {r['stage']}   —— 人的动作，不可由命令判定")
            continue
        marks = "  ".join(f"{k}{'✅' if v else '⬜'}" for k, v in r["done"].items())
        if not r["done"]:
            state, marks = "未指派", "⚠ 参与方为空，不可判——不是「完成」"
        else:
            state = "完成" if all(r["done"].values()) else "进行中"
        print(f"  {r['stage']}   {state}   {marks}")
    print()
    print(f"当前环节：{current}")
    missing = []
    for r in table:
        if r["stage"] != current:
            continue
        if r["done"] == {}:
            print("缺：本环节参与方尚未指派——工单里该字段为空，按协议规则算出后填入")
        elif r["done"]:
            missing = [k for k, v in r["done"].items() if not v]
    if missing:
        print(f"缺：{'、'.join(missing)}")
    if conflict:
        print()
        print(conflict)
    print()
    print("判据即命令，结论只依赖 git 提交；工作区文件不参与判定。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
