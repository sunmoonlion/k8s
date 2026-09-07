#!/usr/bin/env python3
"""③ 裁决：机械条 M1–M7 的判据。**判据即命令**，结论不取决于裁决方的印象。

用法：python3 check-mechanical.py [家名...]
退出码：0 全部通过；1 有失败项；2 用法错误。

⚠ 本脚本首跑必须与人工结论对照后才可当门禁（`round-protocol.md` §8.1 第 4 条）。
⚠ 零命中一律区分「真的没有」与「没查到」：取不到候选时报「无法判定」，不报「不通过」。
"""
from __future__ import annotations
import re, subprocess, sys

FAMILIES = ["luna", "kimi", "cursor", "qwen"]
PATH = "sunmoonai/docs/dev-plan/agent-dev-guide.md"
SRC = {"refact-fable": 31, "runtime-architecture": 33}   # 两份源稿的节数，实测得出


def blob(fam: str) -> str | None:
    for ref in (f"runtime-refact/{fam}", fam):
        p = subprocess.run(["git", "show", f"{ref}:{PATH}"], capture_output=True, text=True)
        if p.returncode == 0:
            return p.stdout
    return None


def landing_rows(text: str) -> dict[str, list[tuple[str, str]]]:
    """落点表：第一格是源稿名的行。返回 {源稿: [(节号标题, 落点)]}"""
    out: dict[str, list[tuple[str, str]]] = {k: [] for k in SRC}
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in re.sub(r"`[^`]*`", "◇", line).strip("|").split("|")]
        if len(cells) < 3:
            continue
        src = cells[0].strip("* ")
        # **别只认全名**：任务书只规定了「| 源 |」这一格，没规定写法。
        # 首跑时本函数只认 refact-fable / runtime-architecture，把用 F / R 缩写的
        # 那一家判成「落点表 0 行」——判据覆盖不全，冤枉了合规的候选。
        alias = {"refact-fable": ("refact-fable", "refactfable", "F", "F."),
                 "runtime-architecture": ("runtime-architecture", "runtimearchitecture", "R", "R.")}
        for key, names in alias.items():
            if src in names or src.replace("-", "") == key.replace("-", ""):
                out[key].append((cells[1], cells[2]))
                break
    return out


def check(fam: str) -> list[tuple[str, bool | None, str]]:
    t = blob(fam)
    if t is None:
        return [("取件", None, f"两个 ref 都取不到 {PATH}——**无法判定**，不等于不通过")]
    r: list[tuple[str, bool | None, str]] = []
    rows = landing_rows(t)
    tot = sum(len(v) for v in rows.values())
    detail = "；".join(f"{k} {len(v)}/{n}" for (k, n), v in zip(SRC.items(), rows.values()))
    r.append(("M1 落点表 64 节", tot == 64, f"共 {tot} 行（{detail}）"))

    bad = [s for v in rows.values() for s, land in v
           if not land or (("故意不要" in land or "不要" in land) and len(land) < 15)]
    r.append(("M2 每行有落点或≥15字理由", not bad,
              "全部满足" if not bad else f"{len(bad)} 行不满足：{[b[:18] for b in bad[:3]]}"))

    # M4 / M5：任务书原文是「出现必须在**被证伪**语境内并明确标注」。
    # 因此命中**不等于**不通过——**一律交人核语境，不自动判负**。
    banned = ["amend_schema", "amend.mode", "回执仓", "候选仓", "三道边界"]
    hits = {w: t.count(w) for w in banned if t.count(w)}
    r.append(("M4 已证伪设计", None if hits else True,
              "零命中" if not hits else f"命中 {hits} —— 交人核语境"))

    m5 = [w for w in ["开发 Profile", "产品 Profile", "两个 Profile"] if w in t]
    r.append(("M5 两个 Profile", None if m5 else True,
              "无" if not m5 else f"命中 {m5} —— 交人核语境"))

    m6 = re.findall(r'kind\s*=\s*"human"', t)
    r.append(("M6 human 不作执行者 kind", not m6, "无" if not m6 else f"命中 {len(m6)} 处"))

    # 「没查」的写法各家不同：**没查什么**：… / 没查：… / not_checked。
    # 首跑的正则要求「没查」后直接跟冒号，把写成 **没查什么**： 的那家判负——同一类覆盖不全。
    has_cov = bool(re.search(r"覆盖声明|coverage", t))
    # 第三种写法：**标题 + 列表**（`### 9.2 没查什么` 换行后跟条目），没有冒号。
    # 首跑的正则只认冒号形式，把写成标题的那家判负——同一类覆盖不全，本条已第二次栽。
    m = (re.search(r"(没查|未查|not[_ ]?checked)[^：:\n]{0,6}[*）)\s]*[：:]\s*(\S[^\n]{10,})", t)
         or re.search(r"#+[^\n]*(没查|未查)[^\n]*\n+\s*[-*|]?\s*(\S[^\n]{10,})", t))
    r.append(("M7 覆盖声明含「没查什么」", has_cov and bool(m),
              f"覆盖声明 {'有' if has_cov else '无'}；「没查」具体内容 "
              + (f"有：{m.group(2)[:34]}…" if m else "无")))
    return r


def main(argv: list[str]) -> int:
    fams = argv or FAMILIES
    fails = 0
    for fam in fams:
        print(f"\n══ {fam} ══")
        for tag, ok, msg in check(fam):
            mark = {True: "✅", False: "❌", None: "🔶无法判定"}[ok]
            if ok is False:
                fails += 1
            print(f"  {mark} {tag:26} {msg}")
    print(f"\n机械判定失败 {fails} 项。标「无法判定」的**不计入通过**，须人给结论。")
    print("M3（两道门禁）与 M4 的语境判定不在本脚本内，由裁决方另跑并留痕。")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
