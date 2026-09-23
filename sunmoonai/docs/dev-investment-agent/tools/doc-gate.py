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
#
# ⚠ **豁免只到「冻结件」为止，且只豁免字段与格式。**原来整片 `/thread/` 连链接一起放过，
# 于是**还没发出的任务书**——它每天都在改，链接也随时能修——的坏链一条都查不到。
# 实测代价：后端模块重切后改名，七份任务书里三份的模块链接指向改名前的
# `0001-kernel.md` / `0004-gateway.md` / `0005-interaction.md`，全是死链，`--all` 照报通过。
# 任务书里的链接恰恰大量指向模块文件，而模块文件正是最常改名的东西。
# 现在：未冻结的 turn 文件**查链接**（见 `thread_live`），字段与格式仍走 turn 专用检查。
EXEMPT_MARKERS: tuple[str, ...] = ("/thread/",)


def exempt(path: str) -> bool:
    return path.startswith(EXEMPT) or any(m in path for m in EXEMPT_MARKERS)


def thread_live(path: str) -> bool:
    """turn 文件里还没冻结的那些——链接仍改得动，因此仍要查链接。

    判据与 `check_frozen` 同源，避免「门说冻结、这里说没冻」两套尺子：
    本 turn 已有 `turn.md`（已交回）则整个 turn 冻结；未交回时，`user-message.md`
    以 `executor` 是否还是 `unassigned` 判是否已发出，同 turn 的其余文件未冻结。
    冻结件的链接改不了，查出来也只是死账，所以照旧不查。
    """
    parsed = parse_thread_path(path)
    if parsed is None:
        return False
    task, dthread, dturn, rest = parsed
    if blob(f"{task}/thread/{dthread}/{dturn}/turn.md") is not None:
        return False
    if rest == "user-message.md":
        return (front_matter(blob(path) or "") or {}).get("executor") == "unassigned"
    return True


# 声明「自足」的文档：§N 引用必须指向**本文件内**的标题。
# 其他文档（裁决书、整合记录、评审）引用的是别的文档的章节，不适用本项。
SELF_CONTAINED = (
    # 加入：所有者问「为何不把 GO.md 和竞争协议合并」。
    # 查实 GO.md「四条不能违反的」在协议里各有一份，而**没有任何东西保证两份一致**。
    # 合并不是修法，修法是让它降为**被核对的引用**：四条各注出处，本门验那个出处真的存在。
    # ⚠ 那四条现已改成**按标题引用**（协议「通用纪律」要求），所以本项对它已无实际拦截力；
    # 名单留着是为了：将来谁再往这两处写 §N，当场判失败。
    "sunmoonai/docs/dev-investment-agent/turn/protocol/GO.md",
)
# 产品合同已拆散（需求进 tree-build/PRD/，责任投影进 SDD/architecture/ownership.md，
# 决策与欠账进 tree-build/decisions.md），原条目随之移除——**这道自检当场报了名单失效**，
# 说明它有用：名单按路径写死，文档一改名或删除就静默失去作用。

USAGE = "用法: doc-gate.py <文件>... | --all | --frozen | --survey | --selfcheck"

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


ENTRY_FILES = ("AGENTS.md", "CLAUDE.md")
ENTRY_PATH_RE = re.compile(r"`(sunmoonai/docs/[A-Za-z0-9/._-]+)`")


def check_entry_pointers(tracked: set[str]) -> list[str]:
    """仓根入口文件里的纯文本路径必须存在。

    **为什么单列一条**：`AGENTS.md` 是每个 agent 进仓读的第一份文件，而它
    ①不在 `sunmoonai/docs/` 下，门禁范围够不着；②写的是反引号裹的纯路径，
    不是 markdown 链接，`LINK_RE` 也匹配不上。**两层都漏，指针死了没人知道。**
    实测：产品合同拆散后，`AGENTS.md` 指着它的那一行死了一整天没被发现。
    """
    problems = []
    for name in ENTRY_FILES:
        text = blob(name)
        if text is None:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for target in ENTRY_PATH_RE.findall(line):
                if not exists_in_index(target.rstrip("/"), tracked):
                    problems.append(f"{name}:{lineno}: 入口指针已失效: {target}")
    return problems


def frozen_link_survey(paths: list[str], tracked: set[str]) -> tuple[int, list[str]]:
    """冻结原件的链接旁路检查：只报「指向当前索引里没有的路径」的那些，不判失败。

    **为什么要旁路。**`/thread/` 下的交回物冻结后不许回改，于是原来整片豁免、
    链接一条不查。但「不可修改」不等于「不检查」，也不等于「仍然有效」。

    **为什么只报、不判。**原件不许回改，判失败会让门永久拦住每一次提交。

    ⚠ **本函数刻意不去断言这些链接「当初是好的」还是「当初就坏」。**
    试过两次，两次都得出假结论：
      一版用 `git log -1` 取「冻结提交」——取到的是**目录重排的搬运提交**，
      它的树里早没有旧目录，于是每条链接都被判成「冻结时即坏链」；
      二版改成遍历该文件全部历史，仍然错——这些链接是按文件**原来的路径**
      写的相对路径，而我一直用它**现在的路径**去解析，`../../../../../` 落点根本不同。
    要判准就得同时跟踪路径重命名并逐版本换基准解析，成本远超收益。
    **所以这里只报「今天解析不到」这个事实**，剩下的交给下面那条命令。
    """
    dangling: list[str] = []
    total = 0
    for path in paths:
        text = blob(path) or ""
        base = PurePosixPath(path).parent
        for lineno, line in enumerate(text.splitlines(), 1):
            for target in LINK_RE.findall(line):
                target = target.split("#", 1)[0].split(" ", 1)[0].strip()
                if not target or target.startswith(SKIP_LINK_PREFIXES) or target.startswith("/"):
                    continue
                total += 1
                if not exists_in_index(normalize(base, target), tracked):
                    dangling.append(f"{path}:{lineno}: {target}")
    return total, dangling


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



def check_readme_names(path: str, text: str, tracked: set[str]) -> list[str]:
    """L3：README 里点名的 `*.md` 必须真实存在。

    **为什么单给 README 加这一条。**README 的职责是说明目录里有哪些文件，所以它天然
    要复述文件名——而复述出来的名字**门禁原来查不到**：`check_links` 只查
    `[文字](路径)` 形式的链接，反引号里的 `foo.md`、以及 ```text 树状图里的文件名
    都不是链接。实测代价：一天里删掉七八份文件，每次链接都改对了，两份 README 的
    树却同时留着 `functions.md`、`agent-dev-guide.md` 两个已删文件，还漏列了
    architecture/ 下新增的四份。新人照树去找，找不到。

    判据：README 的**目录树代码块**与**文件说明表首列**里形如 `<名字>.md` 的点名，
    必须在**该 README 所在目录或其子目录**下存在。

    ⚠ **判据的边界**：同名文件在子树里**任何位置**存在就算数。所以「本目录的
    `functions.md` 删了，但子模块下还有同名的」这一类漏得掉。要抓那一类得按
    完整相对路径比对，而 README 的树状图本来就不写完整路径——代价大于收益，不做。只查 README，且只查这两处——正文散提的文件名可能是
    运行时才产生的（竞争实例的 `round.md`、任务目录的 `response.md`），按存在性查会误报。
    """
    if PurePosixPath(path).name != "README.md":
        return []
    # 范围是**这份 README 所在目录及其子目录**——它说明的就是这些。
    # 放到全仓找会漏：同名文件在别的模块下还存在时（`functions.md` 就是），
    # 本目录删掉了也查不出来。
    base = str(PurePosixPath(path).parent) + "/"
    here = {PurePosixPath(q).name for q in tracked
            if q.startswith(base) and q.endswith(".md")}
    # **只查两处点名**：代码块里的目录树，和「文件 | 内容」这类说明表的首列。
    # README 正文里还会提到运行时才产生的文件（每次竞争实例里的 `round.md`、
    # 任务目录里的 `response.md`），那些不是仓里的固定文件，按存在性查会误报。
    problems, seen, in_code = [], set(), False
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        is_table_head = line.startswith("| ") and line.count("|") >= 3
        if not (in_code or is_table_head):
            continue
        if is_table_head:
            line = line.split("|")[1]   # 只看首列
        for m in re.finditer(r'(?<![\w/.-])([A-Za-z0-9][\w.-]*\.md)(?![\w/])', line):
            name = m.group(1)
            if name in seen or name in here:
                continue
            # 链接形式由 check_links 负责；这里只管没做成链接的点名
            if f"]({name}" in line or f"/{name}" in line:
                continue
            seen.add(name)
            problems.append(f"{path}:{lineno}: README 点名了不存在的文件: {name}")
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
#     thread/0003-sdd-01k8f3m2qz/                  文档 thread，名字带种类，对一个运行时 thread
#     thread/0003-sdd-01k8f3m2qz/0002-01k8h9t1cc/  文档 turn：user-message.md、response.md、turn.md、others/
# PRD、SDD 段的答是 response.md；IMP、UAT 段的产物在 worktree，turn.md 记分支与提交。
# 定稿在 PRD/（一份需求，不分模块）与 SDD/ 下（architecture/ 与 modules/）。字段与形状见
# turn/turn-project.md 与 turn/naming.md。
THREAD_PREFIX_RE = re.compile(r"^(?P<task>.+)/thread/(?P<rest>.+)$")
KINDS = ("prd", "sdd", "imp", "uat")
THREAD_DIR_RE = re.compile(r"^(?P<num>\d{4})-(?P<kind>[a-z]+)(?:-(?P<id>[A-Za-z0-9][A-Za-z0-9._-]*))?$")
TURN_DIR_RE = re.compile(r"^(?P<num>\d{4})(?:-(?P<id>[A-Za-z0-9][A-Za-z0-9._-]*))?$")
MODULE_NAME_RE = re.compile(r"^(?P<num>\d{4})-(?P<name>[^/]+)$")
VERIFIES_RE = re.compile(r"^\d{4}/\d{4}$")
TURN_FILES = {"user-message.md", "response.md", "turn.md"}
DOC_KINDS = {"prd", "sdd"}                  # 答在 turn 里
WORKTREE_KINDS = {"imp", "uat"}             # 产物在 worktree
STATUSES = {"completed", "interrupted", "failed"}
NONE = "无"          # 固定字段集里用不上的那一项
# 运行时 id 在目录名里，回执里不再写一遍；执行者与会话写在任务书里。
OBSOLETE_TURN_FIELDS = ("provider_turn_id", "provider_thread_id", "provider_record",
                        "thread", "executor", "completed_at", "reason", "error", "verdict")


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


def head_files(prefix: str) -> set[str]:
    """HEAD 里该前缀下的全部被跟踪文件。用于判断一棵任务子树是不是被整体删除。"""
    try:
        out = git("ls-tree", "-r", "--name-only", "HEAD", "--", prefix)
    except subprocess.CalledProcessError:
        return set()
    return {ln for ln in out.splitlines() if ln}


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


def check_turn_md(base: str, fm: dict[str, str], kind: str, strict: bool = False) -> list[str]:
    """`strict` = 这份 turn.md 正在本次提交里被写入（hook 的 --staged）。

    字段名从 `worktree` 改成 `branch`：它装的一直是**分支名**，不是 worktree 路径，
    而路径、worktree、branch、commit 是四种不同对象，名字错位让自动化没法可靠定位交回物。
    **已冻结的 turn.md 不回改**，所以旧名必须继续收；但新写的一律用 `branch`——
    这个边界由 `strict` 机械划开，不靠谁记得。
    """
    problems: list[str] = []
    has_new, has_old = "branch" in fm, "worktree" in fm
    if has_new and has_old:
        problems.append(f"{base}/turn.md: `branch` 与旧名 `worktree` 不得并存，只留 `branch`")
    if strict and has_old and not has_new:
        problems.append(f"{base}/turn.md: 字段名是 `branch`（它填的是分支名）；`worktree` 是旧名，只有已冻结的原件才保留")
    key = "branch" if has_new else "worktree"
    for k in ("status", key, "commit"):
        if not fm.get(k):
            problems.append(f"{base}/turn.md: 缺字段或为空：{k}（用不上写「无」，不删行）")
    on_branch = {k: fm.get(k, "") not in ("", NONE) for k in (key, "commit")}
    if kind in WORKTREE_KINDS and not all(on_branch.values()):
        problems.append(f"{base}/turn.md: {kind} 类的产物在分支上，{key} 与 commit 都要填")
    if kind in DOC_KINDS and on_branch[key] != on_branch["commit"]:
        problems.append(f"{base}/turn.md: {key} 与 commit 要么都写「无」（答在当前分支上），要么都填（答在另一条分支上）")
    for k in OBSOLETE_TURN_FIELDS:
        if fm.get(k):
            problems.append(f"{base}/turn.md: 回执里不写 {k}——运行时 id 在目录名里，执行者在用户消息里，时间与提交 git 有，中断或失败的原因写正文")
    st = fm.get("status", "")
    if st and st not in STATUSES:
        problems.append(f"{base}/turn.md: status 只能是 completed、interrupted、failed，现为 {st}")
    return problems


def check_modules(tracked: set[str]) -> list[str]:
    """模块只在 SDD/ 下划。modules/<名>.md 说每块是什么，submodules/<名>/ 是它往下的子任务；有子任务必须有说明（反之不强制）；
    名字合乎「四位号-短名」，从 0001 起连续；PRD/ 下三样都不得有。"""
    problems: list[str] = []
    dirs: dict[str, set[str]] = {}          # <任务目录>/<PRD|SDD>/submodules -> 模块名
    descs: dict[str, set[str]] = {}         # <任务目录>/<PRD|SDD>/modules -> 说明文件名（去 .md）
    have_arch: set[str] = set()             # 有 architecture/ 的 <任务目录>/<PRD|SDD>
    finals: set[str] = set()                # 出现过的 <任务目录>/<PRD|SDD>
    # **按路径段逐层扫，不用贪婪正则。**一个路径可能穿过好几层任务目录
    # （`…/SDD/submodules/X/SDD/submodules/Y/…`），贪婪匹配只认得最后一层，
    # 于是「文件全在自己 PRD/ 下」的模块在父层就消失了——检查会报假错。
    for p in sorted(tracked):
        if not p.startswith(DOC_ROOT):
            continue
        seg = p.split("/")
        for i, part in enumerate(seg[:-1]):
            if part not in ("PRD", "SDD"):
                continue
            final = "/".join(seg[: i + 1])
            finals.add(final)
            rest = seg[i + 1 :]
            if rest[0] == "architecture":
                have_arch.add(final)
            elif rest[0] == "submodules" and len(rest) > 2:
                dirs.setdefault(f"{final}/submodules", set()).add(rest[1])
            elif rest[0] == "modules" and len(rest) == 2 and rest[1].endswith(".md"):
                descs.setdefault(f"{final}/modules", set()).add(rest[1][:-3])
    for final in sorted(finals):
        if final.endswith("/PRD") and (final in have_arch
                                       or f"{final}/modules" in descs
                                       or f"{final}/submodules" in dirs):
            problems.append(f"{final}/: 需求侧不分模块，PRD/ 下不得有 architecture/、modules/ 或 submodules/"
                            "（模块只在 SDD/ 下划）")
    with_modules = {w.removesuffix("/submodules") for w in dirs}
    for final in sorted(with_modules):
        if final not in have_arch:
            problems.append(f"{final}/: 有 submodules/ 就必须有 architecture/")
    # **modules/ 是这一层对每块的说明，submodules/ 是它往下的子任务——同号同名一一对应。**
    # 少一边就是「分了模块却没说它是什么」或「说了却没有落点」，两种都会让读的人钻错层。
    for final in sorted(with_modules):
        d = dirs.get(f"{final}/submodules", set())
        c = descs.get(f"{final}/modules", set())
        # **单向**：有子任务就必须先说清它是什么；反过来不强制——
        # 划分定下来时先写说明、子任务等真要派工时再建，是正常的中间态
        # （`turn-project.md`：不预先建还没派出的子任务）。
        only_sub = sorted(d - c)
        if only_sub:
            problems.append(f"{final}/: 这些模块有子任务却没有说明——"
                            f"补 modules/<名>.md：{'、'.join(only_sub)}")
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
    return problems


def check_threads(tracked: set[str], staged: list[tuple[str, str]] | None) -> tuple[list[str], int]:
    problems: list[str] = []
    # ⚠ **R100 不算「新写」**：字节完全相同的改名，内容一个字没动。
    # 整棵子树搬家时（dev-human → turn、dev-agent → tree），已冻结的 turn 会以 R100
    # 出现；把它们当成新写，就会要求冻结原件改用新字段名——而原件正是不许回改的。
    # 首版漏了这一条，`git mv` 之后当场 4 处假失败。
    staged_paths = None if staged is None else {
        c[1] for c in staged if not (c[0] == "R100")
    }
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
            if not m or m["kind"] not in KINDS:
                problems.append(f"{task}/thread/{name}: thread 目录名须是「四位数字-种类」或「四位数字-种类-运行时 id」，"
                                f"种类在 " + "、".join(KINDS) + " 之内")
                continue
            parsed_threads[name] = (int(m["num"]), m["kind"], m["id"])
            nums.setdefault(int(m["num"]), []).append(name)
        for n, same in sorted(nums.items()):
            if len(same) > 1:
                problems.append(f"{task}/thread/: 本地号 {n:04d} 对应多个目录：" + "、".join(sorted(same)))
        if nums:
            gap = sorted(set(range(1, max(nums) + 1)) - set(nums))
            if gap:
                problems.append(f"{task}/thread/: thread 编号不连续，缺 " + "、".join(f"{g:04d}" for g in gap))

        local_ids = set()
        for tname, (tnum, kind, tid) in sorted(parsed_threads.items()):
            for uname in dthreads[tname]:
                mu = TURN_DIR_RE.match(uname)
                if mu:
                    local_ids.add(f"{tnum:04d}/{int(mu['num']):04d}")

        for tname, (tnum, kind, tid) in sorted(parsed_threads.items()):
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
                if kind in WORKTREE_KINDS and has_response:
                    problems.append(f"{base}: {kind} 类的产物在 worktree，turn 里不放 response.md")
                um = blob(f"{base}/user-message.md") if "user-message.md" in files else None
                if um is None:
                    problems.append(f"{base}: 缺 user-message.md（任务书）")
                    continue
                fm = front_matter(um)
                if fm is None:
                    problems.append(f"{base}/user-message.md: 缺 YAML 头（--- 包起的固定字段）")
                    continue
                for k in ("executor", "verifies"):
                    if not fm.get(k):
                        problems.append(f"{base}/user-message.md: 缺字段或为空：{k}（用不上写「无」，不删行）")
                if kind == "uat":
                    v = fm.get("verifies", "")
                    if v == NONE:
                        problems.append(f"{base}/user-message.md: uat 段须填 verifies（验收的是哪个 turn）")
                    elif not VERIFIES_RE.match(v):
                        problems.append(f"{base}/user-message.md: verifies 写成「thread 号/turn 号」，如 0004/0001，现为 {v}")
                    elif v not in local_ids:
                        problems.append(f"{base}/user-message.md: verifies 指向不存在的 turn：{v}")
                elif fm.get("verifies") != NONE:
                    problems.append(f"{base}/user-message.md: 只有 uat 段才填 verifies，其余写「无」")
                if "turn.md" not in files:
                    continue
                if fm.get("executor") == "unassigned":
                    problems.append(f"{base}: 还没派出去（executor: unassigned），不应有 turn.md")
                if kind in DOC_KINDS and not has_response:
                    problems.append(f"{base}: 已交回（有 turn.md），{kind} 类必须有 response.md")
                if not uid:
                    problems.append(f"{base}: 已交回（有 turn.md），目录名须带运行时 turn id；执行环境不给 id 的写 -none")
                if not tid:
                    problems.append(f"{task}/thread/{tname}: 其下已有交回的 turn，thread 目录名须带运行时 thread id")
                tm = front_matter(blob(f"{base}/turn.md") or "")
                if tm is None:
                    problems.append(f"{base}/turn.md: 缺 YAML 头（--- 包起的固定字段）")
                    continue
                # ⚠ strict 必须**按文件**判，不能按模式判：`--staged` 模式下
                # check_threads 仍遍历全树，按模式传会把每一份已冻结的原件都判失败
                # （首版就是这么写的，当场 19 处假失败）。只有本次提交真正写入的
                # 那几份才算「新写」。
                problems += check_turn_md(
                    base, tm, kind,
                    strict=staged_paths is not None and f"{base}/turn.md" in staged_paths,
                )

    for rid, where in sorted(runtime_ids.items()):
        if len(where) > 1:
            problems.append(f"运行时 id {rid} 出现在多处：" + "、".join(sorted(where)))

    problems += check_modules(tracked)
    if staged is not None:
        problems += check_frozen(staged)
    return problems, nturns


def check_frozen(staged: list[tuple[str, str, str | None]]) -> list[str]:
    """交回即冻结：HEAD 里已有 turn.md 的那个 turn 不许改、删、加文件；已发出的任务书不许改、删。

    两处例外都是「整体退役」，判据窄且必须同时成立：整棵任务目录、或整条 thread——
    其下 HEAD 里的每个文件本次都被删除，且只删不改。抽掉一个 turn、只删一部分、
    边删边改，一律照旧拦住。

    **冻结的是内容与归属，不是路径。**整棵子树改名时，turn 只是跟着上层走，内容零改动——
    这不是篡改。放行的判据很窄：`R100`（字节完全相同）**且** thread 名、turn 名、文件名三者都没变，
    只有上层任务目录不同。turn 内部改名（`response.md` → 别的名字）、跨 turn 搬运、
    相似度不足 100% 的改名，一律照旧拦住；搬完之后再改内容，下一次提交会以 `M` 被拦。
    """
    problems: list[str] = []
    cache: dict[str, tuple[bool, bool]] = {}
    deleted = {p for st, p, _ in staged if st == "D"}
    touched = {p for st, p, _ in staged if st != "D"}
    retired: set[str] = set()
    checked_retire: set[str] = set()
    retired_thread: set[str] = set()
    checked_thread: set[str] = set()
    for status, path, old_path in staged:
        if not path.startswith(DOC_ROOT):
            continue
        if status == "R100" and old_path is not None:
            was, now = parse_thread_path(old_path), parse_thread_path(path)
            if was and now and was[1:] == now[1:]:
                continue  # 整体搬迁：thread、turn、文件名都没变，只是上层目录搬了
        parsed = parse_thread_path(path)
        if parsed is None:
            continue
        task, dthread, dturn, rest = parsed
        if task in retired:
            continue
        if status == "D" and task not in checked_retire:
            checked_retire.add(task)
            # **整棵任务目录退役**：该目录下 HEAD 里的每个文件本次都被删除，且只删不改。
            # 冻结防的是篡改——抽掉一个不利的 turn、或改写当时的问答；整棵树不再生长
            # 是另一回事。判据必须同时成立，单独删一个 turn 或只删一部分照旧拦。
            head = head_files(task + "/")
            if head and head <= deleted and not (head & touched):
                retired.add(task)
                continue
        thread_dir = f"{task}/thread/{dthread}"
        if thread_dir in retired_thread:
            continue
        if status == "D" and thread_dir not in checked_thread:
            checked_thread.add(thread_dir)
            # **整条 thread 退役**：这条 thread 下 HEAD 里的每个文件本次都被删除，且只删不改。
            # 用途是「这条 thread 不作数，定稿就是定稿」——所有者明确选择不保留推导过程时。
            # 与上面的「整棵任务目录退役」对称，判据同样必须同时成立：
            # 抽掉其中一个 turn、只删一部分、或边删边改，一律照旧拦住。
            # ⚠ 删之前打标签留档：内容只在 git 历史里，文件系统上不再有。
            head = head_files(thread_dir + "/")
            if head and head <= deleted and not (head & touched):
                retired_thread.add(thread_dir)
                continue
        base = f"{task}/thread/{dthread}/{dturn}"
        if base not in cache:
            um = head_blob(f"{base}/user-message.md")
            fm = front_matter(um) if um else None
            # **「发出」的标记是 `executor`**：还没派出去写 `unassigned`（见用户消息模板）。
            # 早先用的 `sent_at: pending` 随字段集精简去掉了，这里跟着改——否则任何提交过的
            # 用户消息都算已发出，连没派出去的也改不了。
            cache[base] = (head_blob(f"{base}/turn.md") is not None,
                           um is not None and (fm or {}).get("executor") != "unassigned")
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
    link_targets: list[str] = []
    if survey:
        targets = [
            p for p in sorted(tracked) if p.startswith(DOC_ROOT) and p.endswith(".md")
        ]
        link_targets = [p for p in sorted(tracked)
                        if p.startswith(GATED) and exempt(p) and p.endswith(".md")
                        and thread_live(p)]
    elif argv[0] == "--all":
        targets = [
            p
            for p in sorted(tracked)
            if p.startswith(GATED) and not exempt(p) and p.endswith(".md")
        ]
        exempted = [p for p in sorted(tracked)
                    if p.startswith(GATED) and exempt(p) and p.endswith(".md")]
        link_targets = [p for p in exempted if thread_live(p)]
        # **豁免必须可见。**只报「N 份通过」而不报「另有 M 份被豁免」，
        # 读者无从知道门的覆盖范围，那是「覆盖不全比没有更危险」的形态。
        frozen_only = [p for p in exempted if not thread_live(p)]
        if frozen_only:
            total, dangling = frozen_link_survey(frozen_only, tracked)
            print(f"冻结原件：{len(frozen_only)} 份，**不查字段与格式**；"
                  f"其中 {total} 条仓内链接里，{total - len(dangling)} 条目标现存，"
                  f"{len(dangling)} 条指向当前索引里没有的路径")
            if dangling:
                print("    这些是按旧目录结构写的相对路径。**原件不许回改**——"
                      "要顺着它们读，按文件名在历史里找：")
                print("        git log --all --follow --format='%h %ad %s' --date=short -- '**/<文件名>'")
                print("    ⚠ 它们既不算通过，也不算失败；**不在门的覆盖范围内**。")
                for d in dangling[:6]:
                    print(f"        {d}")
                if len(dangling) > 6:
                    print(f"        …… 还有 {len(dangling) - 6} 条，全部清单用 `doc-gate.py --frozen`")
    elif argv[0] == "--frozen":
        # 只报冻结原件的链接清单。单独一个模式，因为它是**覆盖范围之外**的材料，
        # 不该混在「通过」里，也不该每次 --all 都刷几十行。
        frozen_only = [p for p in sorted(tracked)
                       if p.startswith(GATED) and exempt(p) and p.endswith(".md")
                       and not thread_live(p)]
        total, dangling = frozen_link_survey(frozen_only, tracked)
        print(f"冻结原件 {len(frozen_only)} 份，仓内链接 {total} 条，"
              f"其中 {len(dangling)} 条指向当前索引里没有的路径：")
        for d in dangling:
            print(f"    {d}")
        print("\n原件不许回改。要顺着某一条读，按文件名在历史里找：")
        print("    git log --all --follow --format='%h %ad %s' --date=short -- '**/<文件名>'")
        return 0
    elif argv[0] == "--none":
        targets = []
    else:
        # hook 传入暂存文件；只对门禁范围内的拦截
        inrange = [p for p in argv if p.endswith(".md") and p.startswith(GATED)]
        targets = [p for p in inrange if not exempt(p)]
        link_targets = [p for p in inrange if exempt(p) and thread_live(p)]

    problems: list[str] = check_entry_pointers(tracked)
    heading_cache: dict[str, set[str]] = {}
    checked = 0
    skipped: list[str] = []
    # 未冻结的 turn 文件只查链接：字段与格式归 `check_threads` 的 turn 专用检查管，
    # 拿正文文档那套（自足 §N、表格）去套任务书只会误报。
    link_only = set(link_targets)
    nlinks = 0
    for path in sorted(link_only):
        text = blob(path)
        if text is None:
            skipped.append(path)
            continue
        nlinks += 1
        problems += check_links(path, text, tracked)
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
        problems += check_readme_names(path, text, tracked)

    staged_changes: list[tuple[str, str]] | None = None
    if mode == "--staged":
        # **开启改名识别**：冻结的是内容与归属，不是路径。整棵子树搬家时，已交回的 turn
        # 会以 R100（字节完全相同）出现；`--no-renames` 会把它拆成删+增，从源头抹掉区分的可能。
        raw = git("diff", "--cached", "--name-status", "-M100%", "-z").split("\0")
        staged_changes = []
        i = 0
        while i + 1 < len(raw) and raw[i]:
            st = raw[i]
            if st[0] in ("R", "C"):
                staged_changes.append((st, raw[i + 2], raw[i + 1]))
                i += 3
            else:
                staged_changes.append((st, raw[i + 1], None))
                i += 2
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
    # ⚠ **「通过」必须带覆盖范围。**只报通过数，读者会把「门是绿的」读成「全都验过了」，
    # 而豁免的那些一个字没查。检查过的和没覆盖的分两行报，不混在一句里。
    print(f"doc-gate: 活文档 {checked} 份检查通过"
          + (f"；另有 {nlinks} 份未冻结的 turn 文件**只查了链接**" if nlinks else "")
          + (f"；{nturns} 个 turn 的{what}检查通过" if nturns else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
