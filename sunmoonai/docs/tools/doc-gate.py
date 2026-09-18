#!/usr/bin/env python3
"""文档不变量门禁——由 pre-commit hook 自动调用，不需要谁记得跑。

**为什么这一个可以留，而 check-docs.py / check-cross-repo.py 被删了**

那两个脚本落在「纪律」层：要人记得跑。更糟的是其中一条的结论取决于工作区状态——
同一份文档在三台机器上分别报 0 / 4 / 95 条失败，取决于子模块是否初始化。
「看起来在把关，其实不牢」。

本脚本按两条硬约束设计，正面避开那两个坑：

1. **不依赖人记得跑**：由版本化的 `.githooks/pre-commit` 自动触发。装一次
   （`git config core.hooksPath .githooks`）对本仓全部 worktree 生效，因为它们
   共享同一个 `.git`。装没装是可判定的，见 `--selfcheck`。
2. **结论不取决于工作区状态**：链接目标一律对照 **git 索引**（`git ls-files`）解析，
   不看文件系统。因此未跟踪的草稿、未初始化的子模块、本机临时文件都不影响判定；
   同一个 commit 在任何机器上结论相同。本仓当前无子模块，且本脚本只看本仓，
   不跨仓——跨仓检查正是被删那条的失败点。

**只检查确定性的、本仓内的三件事**，做不成的不硬做（见 `constraints.md`
「保证这些被遵守的三层」：做不成的老实标 ⚠）：

- L1 仓内相对链接的目标必须在 git 索引里存在；
- L2 `§N` / `§N.M` 章节引用必须能在**同一份文件**里找到对应标题（仅对
  `SELF_CONTAINED` 声明自足的文档；引用别的文档章节的记录类文件不适用）；
- L3 Markdown 表格每行列数必须与表头一致。

用法：
    doc-gate.py --staged      # hook 用：检查本次提交暂存的文档 + 主线不变量
    doc-gate.py <文件>...     # 检查指定文件
    doc-gate.py --all         # 检查门禁范围（GATED）内的全部文档
    doc-gate.py --survey      # 巡检全仓 docs/，只报告不拦截（退出码恒 0）
    doc-gate.py --selfcheck   # 只报告 hook 是否已安装
退出码：0 通过，1 有失败，2 用法错误。
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import PurePosixPath

DOC_ROOT = "sunmoonai/docs/"

# 门禁范围：本次提交碰到这些文件时，pre-commit 会拦。
# 一个在合法内容上大面积报错的检查不是门禁，是噪音，上线当天所有人就会 --no-verify。
# 因此规矩是：**先把范围内清零，再把范围扩进来**。`--survey` 用于巡检（只报不拦）。
# 扩范围的前提是「扩之前先清零」——带着存量失败上线的门禁会被 --no-verify 掉。
GATED = ("sunmoonai/docs/",)

# 豁免：按路径前缀（EXEMPT）或路径片段（EXEMPT_MARKERS）跳过的文档；`--all` 会报出豁免了几份。
# 新增豁免前先想清楚：豁免的只能是冻结副本，不是活文档——整目录豁免会把活文档的坏链一起放过。
EXEMPT: tuple[str, ...] = ()
# 豁免任务目录下的 `thread/`。turn 交回即冻结，其中的交回物与任务书只对交回那一刻负责；
# 之后被链接的文件改名或移动，冻结原件里的链接必然断，却不能再改。要看当时的样子，按提交去看。
EXEMPT_MARKERS: tuple[str, ...] = ("/thread/",)


def exempt(path: str) -> bool:
    return path.startswith(EXEMPT) or any(m in path for m in EXEMPT_MARKERS)


# 声明「自足」的文档：§N 引用必须指向**本文件内**的标题。
# 其他文档（裁决书、整合记录、评审）引用的是别的文档的章节，不适用本项。
SELF_CONTAINED = (
    "sunmoonai/docs/product/product-contract.md",
    # 加入：所有者问「为何不把 GO.md 和 round-protocol.md 合并」。
    # 查实 GO.md §四 四条规范内容在协议里各有一份，而**没有任何东西保证两份一致**
    # ——正是 §0.0 第 3 条骂的「第二份说明书」。合并不是修法（见 GO.md §四抬头），
    # 修法是让它降为**被核对的引用**：四条各注出处 §，本门验那个 § 真的存在。
    "sunmoonai/docs/dev-agent-task/protocol/GO.md",
)

USAGE = "用法: doc-gate.py <文件>... | --all | --survey | --selfcheck"

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
SECTION_REF_RE = re.compile(r"§(\d+(?:\.\d+)*)")
HEADING_RE = re.compile(r"^#{1,6}\s+(\d+(?:\.\d+)*)[.\s]")
TABLE_DIVIDER_RE = re.compile(r"^\|[\s:|-]+\|\s*$")
INLINE_CODE_RE = re.compile(r"`[^`]*`")


def cell_count(line: str) -> int:
    """列数 = 未转义、且不在行内代码里的竖线数。"""
    stripped = INLINE_CODE_RE.sub("", line).replace("\\|", "")
    return stripped.count("|")
SKIP_LINK_PREFIXES = ("http://", "https://", "mailto:", "#")


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True
    ).stdout


def tracked_paths() -> set[str]:
    """git 索引里的全部路径。判定基准是索引，不是文件系统。"""
    # **必须用 -z**：`git ls-files` 默认开 core.quotepath，非 ASCII 文件名会被输出成
    # 带引号的八进制转义（"…call-\342\221\241.md"），于是索引集合里那个字符串
    # 永远匹配不上真实路径。后果是**任何文件名含非 ASCII 的文件在本门眼里都不存在**，
    # 指向它的链接一律被判死链。实测：qwen 的评审稿链接 `../call-②.md`
    # 被拦，而该文件确在索引里（`git ls-files --error-unmatch` 为真）。
    # 这道门此前一直「正常」，只是因为在此之前没有文档链接过这类文件名。
    return set(git("ls-files", "-z").split("\0")) - {""}


def exists_in_index(norm: str, tracked: set[str]) -> bool:
    """索引里没有目录条目，因此目录按前缀判断：有文件在其下即存在。"""
    if norm in tracked:
        return True
    prefix = norm.rstrip("/") + "/"
    return any(t.startswith(prefix) for t in tracked)


def normalize(base: PurePosixPath, target: str) -> str:
    parts: list[str] = []
    for part in PurePosixPath(*(base / target).parts).parts:
        if part == "..":
            if parts:
                parts.pop()
        elif part != ".":
            parts.append(part)
    return "/".join(parts)


def blob(path: str) -> str | None:
    """读暂存区的内容；读不到（例如刚被删除）返回 None。"""
    try:
        return git("show", f":{path}")
    except subprocess.CalledProcessError:
        return None


def check_links(path: str, text: str, tracked: set[str]) -> list[str]:
    """L1：仓内相对链接的目标必须在 git 索引里。"""
    problems = []
    base = PurePosixPath(path).parent
    for lineno, line in enumerate(text.splitlines(), 1):
        for target in LINK_RE.findall(line):
            target = target.split("#", 1)[0].split(" ", 1)[0].strip()
            if not target or target.startswith(SKIP_LINK_PREFIXES):
                continue
            if target.startswith("/"):
                problems.append(f"{path}:{lineno}: 绝对路径链接不可移植: {target}")
                continue
            norm = normalize(base, target)
            if not exists_in_index(norm, tracked):
                problems.append(f"{path}:{lineno}: 链接目标不在 git 索引里: {target}")
    return problems


def headings_of(text: str) -> set[str]:
    out = set()
    for line in text.splitlines():
        m = HEADING_RE.match(line)
        if m:
            out.add(m.group(1))
    return out


def check_section_refs(
    path: str, text: str, tracked: set[str], cache: dict[str, set[str]]
) -> list[str]:
    """L2：§N 引用必须有对应标题。

    引用可能指向本文件，也可能指向同一行里点名的另一份文档——后者正是最容易
    悄悄失效的一类：文件还在、链接还通，但对方重编号后指向的内容全变了，
    链接检查器抓不到。因此这里按「同一行点到哪份文档，就查哪份」解析。
    """
    own = headings_of(text)
    # ⚠ **不要在这里因为 own 为空就早退。**实测：`GO.md` 的标题是
    # 「一、二、三」而非阿拉伯数字，`HEADING_RE` 认不出 → `own` 为空 → 整个函数
    # 当场返回，把它对 `round-protocol.md` 的 §N 引用一条都不查，而门照报「通过」。
    # 把 §17 改成不存在的 §99，`--all` 仍然 226 份全过——**检查是摆设**。
    # 跨文档引用恰恰是本函数注释里点名「最容易悄悄失效」的那一类，
    # 而「本文件自己没有编号标题」与「不必检查它引用别人」毫无关系。
    # 后面已有 `if not valid: continue` 兜底：确实无处可对照时才跳过那一条引用。
    base = PurePosixPath(path).parent
    problems = []
    lines = text.splitlines()
    for lineno, line in enumerate(lines, 1):
        refs = SECTION_REF_RE.findall(line)
        if not refs:
            continue
        # 点名的其它文档：看本行和上一行——引用常落在链接的续行上
        window = line + "\n" + (lines[lineno - 2] if lineno >= 2 else "")
        others: set[str] = set()
        for target in LINK_RE.findall(window) + re.findall(r"`([^`]+\.md)`", window):
            target = target.split("#", 1)[0].strip()
            if not target.endswith(".md") or target.startswith(SKIP_LINK_PREFIXES):
                continue
            norm = normalize(base, target) if "/" in target else normalize(base, target)
            if norm != path and norm in tracked:
                others.add(norm)
        # 同一处可能既引本文件、又引对方文档，取并集，避免把正确引用判成失败
        valid, where = set(own), "本文件"
        if others:
            for o in others:
                if o not in cache:
                    body = blob(o)
                    cache[o] = headings_of(body) if body else set()
                valid |= cache[o]
            where = "本文件或 " + "、".join(sorted(others))
        if not valid:
            continue
        for ref in refs:
            if ref not in valid:
                problems.append(
                    f"{path}:{lineno}: 章节引用无对应标题: §{ref}（应在 {where} 内）"
                )
    return problems


def check_tables(path: str, text: str) -> list[str]:
    """L3：表格每行列数与表头一致。"""
    problems = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if (
            lines[i].startswith("|")
            and i + 1 < len(lines)
            and TABLE_DIVIDER_RE.match(lines[i + 1])
        ):
            width = cell_count(lines[i])
            j = i
            while j < len(lines) and lines[j].startswith("|"):
                if cell_count(lines[j]) != width:
                    problems.append(
                        f"{path}:{j + 1}: 表格列数 {cell_count(lines[j]) - 1} "
                        f"与表头 {width - 1} 不一致"
                    )
                j += 1
            i = j
        else:
            i += 1
    return problems


# ── 文档 thread 与文档 turn 的检查（规则要有载体）──────────────────────────
# 任务目录下 `thread/` 正好两级：
#     thread/0003-sdd-01k8f3m2qz/                  文档 thread，名字带阶段，对一个运行时 thread
#     thread/0003-sdd-01k8f3m2qz/0002-01k8h9t1cc/  文档 turn：user-message.md、response.md、turn.md、others/
# BRD、PRD、SDD 段的答是 response.md；SDP、UAT 段的产物在 worktree，turn.md 记分支与提交。
# 定稿在 PRD/ 与 SDD/ 下（architecture/ 与 modules/）。字段与形状见
# dev-agent-standards/lifecycle.md 与 dev-agent-standards/naming.md。
THREAD_PREFIX_RE = re.compile(r"^(?P<task>.+)/thread/(?P<rest>.+)$")
STAGES = ("brd", "prd", "sdd", "sdp", "uat")
THREAD_DIR_RE = re.compile(r"^(?P<num>\d{4})-(?P<stage>[a-z]+)(?:-(?P<id>[A-Za-z0-9][A-Za-z0-9._-]*))?$")
TURN_DIR_RE = re.compile(r"^(?P<num>\d{4})(?:-(?P<id>[A-Za-z0-9][A-Za-z0-9._-]*))?$")
MODULE_NAME_RE = re.compile(r"^(?P<num>\d{4})-(?P<name>[^/]+)$")
VERIFIES_RE = re.compile(r"^\d{4}/\d{4}$")
TURN_FILES = {"user-message.md", "response.md", "turn.md"}
DOC_STAGES = {"brd", "prd", "sdd"}          # 答在 turn 里
WORKTREE_STAGES = {"sdp", "uat"}            # 产物在 worktree
STATUSES = {"completed", "interrupted", "failed"}
VERDICTS = {"pass", "fail", "undecidable"}
REASONS = {"interrupted", "replaced", "review-ended", "budget-limited", "cancelled"}
# 运行时 id 在目录名里，回执里不再写一遍；执行者与会话写在任务书里。
OBSOLETE_TURN_FIELDS = ("provider_turn_id", "provider_thread_id", "thread", "executor")


def front_matter(text: str) -> dict[str, str] | None:
    """读 `---` 包起的 YAML 头（只认 `键: 值` 一层）；没有或没闭合返回 None。"""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    out: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return out
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return None


def head_blob(path: str) -> str | None:
    try:
        return git("show", f"HEAD:{path}")
    except subprocess.CalledProcessError:
        return None


def parse_thread_path(path: str) -> tuple[str, str, str, str] | None:
    """把 `<任务目录>/thread/<thread>/<turn>/<其余>` 拆开；层数不对返回 None。"""
    m = THREAD_PREFIX_RE.match(path)
    if not m:
        return None
    parts = m["rest"].split("/")
    if len(parts) < 3:
        return None
    return m["task"], parts[0], parts[1], "/".join(parts[2:])


def check_turn_md(base: str, fm: dict[str, str], stage: str) -> list[str]:
    problems: list[str] = []
    required = ["status", "completed_at", "commit"] + (["worktree"] if stage in WORKTREE_STAGES else [])
    for k in required:
        if not fm.get(k):
            problems.append(f"{base}/turn.md: 缺字段或为空：{k}")
    if stage in DOC_STAGES and fm.get("worktree"):
        problems.append(f"{base}/turn.md: 只有 sdp、uat 段填 worktree")
    for k in OBSOLETE_TURN_FIELDS:
        if fm.get(k):
            problems.append(f"{base}/turn.md: 回执里不写 {k}——运行时 id 在目录名里，执行者在任务书里")
    st = fm.get("status", "")
    if st and st not in STATUSES:
        problems.append(f"{base}/turn.md: status 只能是 completed、interrupted、failed，现为 {st}")
    if (st == "failed") != bool(fm.get("error")):
        problems.append(f"{base}/turn.md: error 只在 status 为 failed 时填，而且必须填")
    if st == "interrupted" and fm.get("reason") not in REASONS:
        problems.append(f"{base}/turn.md: status 为 interrupted 须填 reason：" + "、".join(sorted(REASONS)))
    if st != "interrupted" and fm.get("reason"):
        problems.append(f"{base}/turn.md: 只有 status 为 interrupted 才填 reason")
    needs = stage == "uat" and st == "completed"
    if needs and fm.get("verdict") not in VERDICTS:
        problems.append(f"{base}/turn.md: 交回 UAT 须填 verdict：pass、fail 或 undecidable")
    if not needs and fm.get("verdict"):
        problems.append(f"{base}/turn.md: 只有完成的 UAT turn 才填 verdict")
    return problems


def check_modules(tracked: set[str]) -> list[str]:
    """模块目录名是「四位号-短名」，在同一个 modules/ 里从 0001 起连续；PRD 与 SDD 两侧一致。"""
    problems: list[str] = []
    dirs: dict[str, set[str]] = {}          # <任务目录>/<PRD|SDD>/modules -> 模块名
    have_arch: set[str] = set()             # 有 architecture/ 的 <任务目录>/<PRD|SDD>
    finals: set[str] = set()                # 出现过的 <任务目录>/<PRD|SDD>
    for p in sorted(tracked):
        if not p.startswith(DOC_ROOT):
            continue
        m = re.match(r"^(?P<task>.+)/(?P<final>PRD|SDD)/(?P<rest>.+)$", p)
        if not m:
            continue
        finals.add(f"{m['task']}/{m['final']}")
        rest = m["rest"].split("/")
        if rest[0] == "architecture":
            have_arch.add(f"{m['task']}/{m['final']}")
        elif rest[0] == "modules" and len(rest) > 2:
            dirs.setdefault(f"{m['task']}/{m['final']}/modules", set()).add(rest[1])
    with_modules = {w.removesuffix("/modules") for w in dirs}
    for final in sorted(with_modules):
        if final not in have_arch:
            problems.append(f"{final}/: 有 modules/ 就必须有 architecture/")
    for where, names in sorted(dirs.items()):
        nums: dict[int, list[str]] = {}
        for name in sorted(names):
            mm = MODULE_NAME_RE.match(name)
            if not mm:
                problems.append(f"{where}/{name}: 模块目录名须是「四位号-短名」（如 0001-backend）")
                continue
            nums.setdefault(int(mm["num"]), []).append(name)
        for n, same in sorted(nums.items()):
            if len(same) > 1:
                problems.append(f"{where}/: 模块号 {n:04d} 对应多个目录：" + "、".join(same))
        if nums:
            gap = sorted(set(range(1, max(nums) + 1)) - set(nums))
            if gap:
                problems.append(f"{where}/: 模块号不连续，缺 " + "、".join(f"{g:04d}" for g in gap))
    # 同一模块在 PRD 与 SDD 两侧的号与短名一致（两侧都出现时才比）
    for where, names in sorted(dirs.items()):
        if not where.endswith("/SDD/modules"):
            continue
        other = dirs.get(where.replace("/SDD/modules", "/PRD/modules"))
        if other is None:
            continue
        only_sdd, only_prd = sorted(names - other), sorted(other - names)
        if only_sdd or only_prd:
            problems.append(f"{where.removesuffix('/SDD/modules')}: PRD 与 SDD 的模块不一致——"
                            f"只在 SDD：{'、'.join(only_sdd) or '无'}；只在 PRD：{'、'.join(only_prd) or '无'}")
    return problems


def check_threads(tracked: set[str], staged: list[tuple[str, str]] | None) -> tuple[list[str], int]:
    problems: list[str] = []
    tasks: dict[str, dict[str, dict[str, set[str]]]] = {}
    for p in sorted(tracked):
        if not (p.startswith(DOC_ROOT) and THREAD_PREFIX_RE.match(p)):
            continue
        parsed = parse_thread_path(p)
        if parsed is None:
            problems.append(f"{p}: thread/ 下正好两级——文档 thread、文档 turn")
            continue
        task, dthread, dturn, rest = parsed
        tasks.setdefault(task, {}).setdefault(dthread, {}).setdefault(dturn, set()).add(rest)

    nturns = 0
    runtime_ids: dict[str, list[str]] = {}
    for task, dthreads in sorted(tasks.items()):
        parsed_threads: dict[str, tuple[int, str, str | None]] = {}
        nums: dict[int, list[str]] = {}
        for name in sorted(dthreads):
            m = THREAD_DIR_RE.match(name)
            if not m or m["stage"] not in STAGES:
                problems.append(f"{task}/thread/{name}: thread 目录名须是「四位数字-阶段」或「四位数字-阶段-运行时 id」，"
                                f"阶段在 " + "、".join(STAGES) + " 之内")
                continue
            parsed_threads[name] = (int(m["num"]), m["stage"], m["id"])
            nums.setdefault(int(m["num"]), []).append(name)
        for n, same in sorted(nums.items()):
            if len(same) > 1:
                problems.append(f"{task}/thread/: 本地号 {n:04d} 对应多个目录：" + "、".join(sorted(same)))
        if nums:
            gap = sorted(set(range(1, max(nums) + 1)) - set(nums))
            if gap:
                problems.append(f"{task}/thread/: thread 编号不连续，缺 " + "、".join(f"{g:04d}" for g in gap))

        local_ids = set()
        for tname, (tnum, stage, tid) in sorted(parsed_threads.items()):
            for uname in dthreads[tname]:
                mu = TURN_DIR_RE.match(uname)
                if mu:
                    local_ids.add(f"{tnum:04d}/{int(mu['num']):04d}")

        for tname, (tnum, stage, tid) in sorted(parsed_threads.items()):
            if tid and tid != "none":
                runtime_ids.setdefault(tid, []).append(f"{task}/thread/{tname}")
            turn_nums: dict[int, list[str]] = {}
            for uname in sorted(dthreads[tname]):
                mu = TURN_DIR_RE.match(uname)
                if not mu:
                    problems.append(f"{task}/thread/{tname}/{uname}: turn 目录名须是四位数字，或「四位数字-运行时 id」")
                    continue
                turn_nums.setdefault(int(mu["num"]), []).append(uname)
            for n, same in sorted(turn_nums.items()):
                if len(same) > 1:
                    problems.append(f"{task}/thread/{tname}/: 本地号 {n:04d} 对应多个目录：" + "、".join(same))
            if turn_nums:
                gap = sorted(set(range(1, max(turn_nums) + 1)) - set(turn_nums))
                if gap:
                    problems.append(f"{task}/thread/{tname}/: turn 编号不连续，缺 " + "、".join(f"{g:04d}" for g in gap))

            for uname in sorted(dthreads[tname]):
                mu = TURN_DIR_RE.match(uname)
                if not mu:
                    continue
                nturns += 1
                base = f"{task}/thread/{tname}/{uname}"
                uid = mu["id"]
                if uid and uid != "none":
                    runtime_ids.setdefault(uid, []).append(base)
                files = dthreads[tname][uname]
                top = {f.split("/")[0] for f in files}
                stray = {f for f in top if f not in TURN_FILES and f != "others"}
                if stray:
                    problems.append(f"{base}: turn 里只放 user-message.md、response.md、turn.md 与 others/；多出：" + "、".join(sorted(stray)))
                has_response = "response.md" in files
                if stage in WORKTREE_STAGES and has_response:
                    problems.append(f"{base}: {stage} 段的产物在 worktree，turn 里不放 response.md")
                um = blob(f"{base}/user-message.md") if "user-message.md" in files else None
                if um is None:
                    problems.append(f"{base}: 缺 user-message.md（任务书）")
                    continue
                fm = front_matter(um)
                if fm is None:
                    problems.append(f"{base}/user-message.md: 缺 YAML 头（--- 包起的固定字段）")
                    continue
                if not fm.get("executor"):
                    problems.append(f"{base}/user-message.md: 缺字段或为空：executor")
                if stage == "uat":
                    v = fm.get("verifies", "")
                    if not v:
                        problems.append(f"{base}/user-message.md: uat 段须填 verifies（验收的是哪个 turn）")
                    elif not VERIFIES_RE.match(v):
                        problems.append(f"{base}/user-message.md: verifies 写成「thread 号/turn 号」，如 0004/0001，现为 {v}")
                    elif v not in local_ids:
                        problems.append(f"{base}/user-message.md: verifies 指向不存在的 turn：{v}")
                elif fm.get("verifies"):
                    problems.append(f"{base}/user-message.md: 只有 uat 段才填 verifies")
                if "turn.md" not in files:
                    continue
                if fm.get("executor") == "unassigned":
                    problems.append(f"{base}: 还没派出去（executor: unassigned），不应有 turn.md")
                if stage in DOC_STAGES and not has_response:
                    problems.append(f"{base}: 已交回（有 turn.md），{stage} 段必须有 response.md")
                if not uid:
                    problems.append(f"{base}: 已交回（有 turn.md），目录名须带运行时 turn id；执行环境不给 id 的写 -none")
                if not tid:
                    problems.append(f"{task}/thread/{tname}: 其下已有交回的 turn，thread 目录名须带运行时 thread id")
                tm = front_matter(blob(f"{base}/turn.md") or "")
                if tm is None:
                    problems.append(f"{base}/turn.md: 缺 YAML 头（--- 包起的固定字段）")
                    continue
                problems += check_turn_md(base, tm, stage)

    for rid, where in sorted(runtime_ids.items()):
        if len(where) > 1:
            problems.append(f"运行时 id {rid} 出现在多处：" + "、".join(sorted(where)))

    problems += check_modules(tracked)
    if staged is not None:
        problems += check_frozen(staged)
    return problems, nturns


def check_frozen(staged: list[tuple[str, str]]) -> list[str]:
    """交回即冻结：HEAD 里已有 turn.md 的那个 turn 不许改、删、加文件；已发出的任务书不许改、删。"""
    problems: list[str] = []
    cache: dict[str, tuple[bool, bool]] = {}
    for status, path in staged:
        if not path.startswith(DOC_ROOT):
            continue
        parsed = parse_thread_path(path)
        if parsed is None:
            continue
        task, dthread, dturn, rest = parsed
        base = f"{task}/thread/{dthread}/{dturn}"
        if base not in cache:
            um = head_blob(f"{base}/user-message.md")
            fm = front_matter(um) if um else None
            cache[base] = (head_blob(f"{base}/turn.md") is not None,
                           um is not None and not (fm and fm.get("sent_at") == "pending"))
        returned, sent = cache[base]
        if returned:
            problems.append(f"{path}: 已交回（有 turn.md），冻结——不改、不删、不加文件；要改就开新的 turn")
        elif status in ("M", "D") and rest == "user-message.md" and sent:
            problems.append(f"{path}: 任务书已发出，冻结；要改就开新的 turn")
    return problems


def hook_installed() -> bool:
    try:
        return git("config", "--get", "core.hooksPath").strip() == ".githooks"
    except subprocess.CalledProcessError:
        return False


def main(argv: list[str]) -> int:
    if not argv:
        print(USAGE, file=sys.stderr)
        return 2

    if argv[0] == "--selfcheck":
        if hook_installed():
            print("doc-gate: hook 已安装（core.hooksPath=.githooks）")
            return 0
        print(
            "doc-gate: hook 未安装。执行一次即可，对本仓全部 worktree 生效：\n"
            "    git config core.hooksPath .githooks",
            file=sys.stderr,
        )
        return 1

    # **必须在仓根跑。**`git ls-files` 在子目录下只列该子目录的文件，且路径相对子目录，
    # 于是 `p.startswith(DOC_ROOT)` 全不命中，脚本会安静地报「0 份文档通过」——
    # 分不出「真的没有文档」和「站错了地方」。零命中必须能区分这两者，故在此拦住。
    top = git("rev-parse", "--show-toplevel").strip()
    here = os.path.realpath(os.curdir)
    if here != os.path.realpath(top):
        print(
            f"doc-gate: 必须在仓根运行。当前 {here}\n"
            f"          请改为：cd {top} && python3 {os.path.relpath(__file__, top)} ...",
            file=sys.stderr,
        )
        return 2

    tracked = tracked_paths()

    # SELF_CONTAINED 是按路径写死的名单。文档一旦改名或移动，名单就静默失去作用，
    # 门照样报「通过」——和 archive/ 静默跳过、quotepath 静默跳过是同一类病。
    # 名单里的路径必须在索引中真实存在，否则拒绝运行。
    missing = [p for p in SELF_CONTAINED if p not in tracked]
    if missing:
        print(
            "doc-gate: SELF_CONTAINED 名单已失效，以下路径不在 git 索引中：\n"
            + "".join(f"    {m}\n" for m in missing)
            + "          文档被移动或改名后须同步本名单，否则「自足」一项静默不再检查。",
            file=sys.stderr,
        )
        return 2

    mode = argv[0]
    survey = argv[0] == "--survey"
    if argv[0] == "--staged":
        # hook 用：自己算本次提交暂存的文档。即使一份文档都没动，也仍要跑主线不变量,
        # 因为「合并把主线独有文档删掉」这件事本身就不体现为对某份文档的修改。
        staged = git(
            "diff", "--cached", "--name-only", "--diff-filter=ACMR"
        ).splitlines()
        argv = [p for p in staged if p.endswith(".md")] or ["--none"]
    if survey:
        targets = [
            p for p in sorted(tracked) if p.startswith(DOC_ROOT) and p.endswith(".md")
        ]
    elif argv[0] == "--all":
        targets = [
            p
            for p in sorted(tracked)
            if p.startswith(GATED) and not exempt(p) and p.endswith(".md")
        ]
        # **豁免必须可见。**只报「N 份通过」而不报「另有 M 份被豁免」，
        # 读者无从知道门的覆盖范围，那是「覆盖不全比没有更危险」的形态。
        exempted = [p for p in sorted(tracked)
                    if p.startswith(GATED) and exempt(p) and p.endswith(".md")]
        if exempted:
            print(f"（另有 {len(exempted)} 份在豁免内，未检查：{EXEMPT} + 片段 {EXEMPT_MARKERS}）")
    elif argv[0] == "--none":
        targets = []
    else:
        # hook 传入暂存文件；只对门禁范围内的拦截
        targets = [
            p
            for p in argv
            if p.endswith(".md") and p.startswith(GATED) and not exempt(p)
        ]

    problems: list[str] = []
    heading_cache: dict[str, set[str]] = {}
    checked = 0
    skipped: list[str] = []
    for path in targets:
        text = blob(path)
        if text is None:
            # **不能静默跳过。**`blob()` 读的是 git 索引，一份还没 `git add` 的新文档
            # 在这里返回 None；原来直接 continue，`checked` 停在 0，末尾照样打印
            # 「0 份文档通过」并退出 0 —— **假通过**，而且方向正是本文件开头警告的那个
            # （「这次的方向是假失败（安全侧），但同一个毛病换个方向就是假通过」）。
            # 实测：手动过一份新写的 call-④.md，门报「通过」，一个字没看。
            # 钩子那条路（--staged）不受影响，暂存的文件必在索引里；受影响的是
            # **提交前手动过门**，而那恰恰是新文档第一次被检查的时机。
            skipped.append(path)
            continue
        checked += 1
        problems += check_links(path, text, tracked)
        if path in SELF_CONTAINED:
            problems += check_section_refs(path, text, tracked, heading_cache)
        problems += check_tables(path, text)

    staged_changes: list[tuple[str, str]] | None = None
    if mode == "--staged":
        raw = git("diff", "--cached", "--name-status", "--no-renames", "-z").split("\0")
        staged_changes = [(raw[i], raw[i + 1]) for i in range(0, len(raw) - 1, 2)]
    thread_problems, nturns = check_threads(tracked, staged_changes)
    problems += thread_problems

    if problems and survey:
        print(f"doc-gate 巡检: {checked} 份文档，{len(problems)} 处待修（不拦提交）\n")
        for p in problems:
            print(f"  {p}")
        return 0

    if problems:
        print(f"doc-gate: {checked} 份文档，{len(problems)} 处失败\n", file=sys.stderr)
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        print(
            "\n判定基准是 git 索引：新增的文件要先 git add，链接才算得上存在。",
            file=sys.stderr,
        )
        return 1

    if skipped:
        print(
            f"doc-gate: {len(skipped)} 份指定的文档不在 git 索引中，**一个字都没检查**：\n"
            + "".join(f"    {p}\n" for p in skipped)
            + "          判定基准是索引，不是工作区。先 `git add` 再过门。\n"
            + f"          （另有 {checked} 份已检查并通过）",
            file=sys.stderr,
        )
        return 2

    what = "编号、字段与冻结" if staged_changes is not None else "编号与字段"
    print(f"doc-gate: {checked} 份文档通过" + (f"；{nturns} 个 turn 的{what}检查通过" if nturns else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
