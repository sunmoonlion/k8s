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
    doc-gate.py <文件>...     # 检查指定文件（hook 传入暂存的文档）
    doc-gate.py --all         # 检查门禁范围（GATED）内的全部文档
    doc-gate.py --survey      # 巡检全仓 docs/，只报告不拦截（退出码恒 0）
    doc-gate.py --selfcheck   # 只报告 hook 是否已安装
退出码：0 通过，1 有失败，2 用法错误。
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import PurePosixPath

DOC_ROOT = "sunmoonai/docs/"

# 门禁范围：本次提交碰到这些文件时，pre-commit 会拦。
# 一个在合法内容上大面积报错的检查不是门禁，是噪音，上线当天所有人就会 --no-verify。
# 因此规矩是：**先把范围内清零，再把范围扩进来**。`--survey` 用于巡检（只报不拦）。
# 2026-09-02：全仓 117 份文档已清零，范围由 dev-plan/working/ 扩到整个 docs/。
# 扩范围的前提是「扩之前先清零」——带着存量失败上线的门禁会被 --no-verify 掉。
GATED = ("sunmoonai/docs/",)

# 例外：codex-reference/ 是**各分支自己**的研究笔记（README.md 第 17 行：各分支只放
# 自己写的那份），不是共享权威文档；agent 文 §5.2 也定它「只作研究输入，不具规范
# 效力」。这类笔记按其性质会引用外部仓的绝对路径作取证出处，用共享文档的链接标准
# 去卡它，只会逼作者绕过门禁。巡检（--survey）仍然覆盖它。
EXEMPT = ("sunmoonai/docs/dev-plan/codex-reference/",)

# 声明「自足」的文档：§N 引用必须指向**本文件内**的标题。
# 其他文档（裁决书、整合记录、评审）引用的是别的文档的章节，不适用本项。
SELF_CONTAINED = (
    "sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md",
    "sunmoonai/docs/dev-plan/working/development-lifecycle-human.md",
    "sunmoonai/docs/dev-plan/working/request-lifecycle.md",
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
    return set(git("ls-files").splitlines())


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
    if not own:
        return []
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

    tracked = tracked_paths()
    survey = argv[0] == "--survey"
    if survey:
        targets = [
            p for p in sorted(tracked) if p.startswith(DOC_ROOT) and p.endswith(".md")
        ]
    elif argv[0] == "--all":
        targets = [
            p
            for p in sorted(tracked)
            if p.startswith(GATED) and not p.startswith(EXEMPT) and p.endswith(".md")
        ]
    else:
        # hook 传入暂存文件；只对门禁范围内的拦截
        targets = [
            p
            for p in argv
            if p.endswith(".md") and p.startswith(GATED) and not p.startswith(EXEMPT)
        ]

    problems: list[str] = []
    heading_cache: dict[str, set[str]] = {}
    checked = 0
    for path in targets:
        text = blob(path)
        if text is None:
            continue
        checked += 1
        problems += check_links(path, text, tracked)
        if path in SELF_CONTAINED:
            problems += check_section_refs(path, text, tracked, heading_cache)
        problems += check_tables(path, text)

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

    print(f"doc-gate: {checked} 份文档通过")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
