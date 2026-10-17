"""改名替换引擎（k8s/docs/rename.md R1，0028）：investment → knowbench、runtime 仓 → sunmoon-link。

用法：python3 rename_rules.py <八组仓的上一级目录> [--apply] [--report 报告.json]
不加 --apply 只统计、不写盘。先把要留的写法换成占位符保护起来，按顺序套规则，再换回。

和上一次（0025，info / knowledge）不同：范围内单独出现的 investment 几乎都指这个应用（2026-10-17 逐词盘点：
424 种写法里只有「investment judgement(s) / advice」等几处是领域词），所以规则是「整词换」加一张保留清单；
runtime 是普通词（清单字段、库角色后缀、秘密目录、契约名），只换明确指仓的写法。
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------- 范围
REPOS = ["tpl-app", "knowfeed-app", "knowbase-app", "knowlab-app", "knowmart-app", "investment-app", "runtime", "k8s"]
SKIP = re.compile(
    r"^k8s/sunmoonai/"  # 冻结的旧体系
    r"|/(results|thread|history|hold|node_modules|\.venv|\.next|dist)/|/switch-test/(done|inbox)/"
    r"|/eval/reports/|/preview/fixtures/|/alembic/versions/|^runtime/probe/"
    r"|(^|/)CHECKPOINT[^/]*\.md$|/switch-test/review-log\.md$"  # 历史记录
    r"|^k8s/docs/rename|/tree-build/(decisions|owner-decisions-now)\.md$"  # 手册与回执；决定记录（原话与当时的名字）
    r"|/SDD/modules/00(25|28)-"  # 两次改名方案本身
    r"|(^|/)(pnpm-lock\.yaml|package-lock\.json)$"
)
# gitops 组件目录里的渲染产物与密文：只随目录 git mv，内容由 R5 的 stage / 构建重新生成（密文在 R1 删，见 r1_apply）
RENDERED = re.compile(
    r"^k8s/gitops/components/.*/(workload\.yaml|kustomization\.yaml|image\.lock\.yaml|[^/]*\.sops\.yaml)$"
)
TEXT_SUFFIX = {
    ".py", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".json", ".yaml", ".yml", ".j2", ".toml", ".md", ".sh",
    ".txt", ".cfg", ".ini", ".env", ".example", ".conf", ".mdc", ".html", ".css", ".sql", ".lock", ".k8s",
    ".ps1", "",
}

# ---------------------------------------------------------------- 要留的写法（占位保护）
KEEP = [
    r"dev-investment-agent",  # 文档目录（所有者定：这次不改）
    r"「[^」\n]*[Ii]nvestment[^」\n]*」",  # 引号里的原话不改
    r"(?:PRD/)?apps/investment(?:-expert)?\.md", r"(?<![\w-])investment(?:-expert)?\.md",  # 设计文档的文件名当编号用
    # 领域词：投资本身（分身内容与合规说明里）
    r"\b(?:an|all) investment\b",
    r"\binvestment (?:judgements?|advice|advisers?|advisory|decisions?|logic|ideas?|thesis|views?|recommendations?)\b",
    r"\bInvestment (?:judgements?|advice|advisers?|advisory|decisions?|logic|ideas?|thesis|views?|recommendations?)\b",
]

# ---------------------------------------------------------------- 改：按类按序
R: list[tuple[str, str, Any]] = []


def rule(cls: str, pattern: str, repl: Any) -> None:
    R.append((cls, pattern, repl))


# 1 runtime 仓（只换明确指仓的写法）
rule("runtime 仓", r"(?<=sunmoonlion/)runtime(?=\.git\b|[\s/\"'`)]|$)", "sunmoon-link")
rule("runtime 仓", r"(worktrees/(?:cursor|fable|kimi|luna|qwen|astra|\$WS|\$ws|\$\{WS\}|<工位>)/)runtime(?![\w-])", r"\1sunmoon-link")
rule("runtime 仓", r"(?<=master/)runtime(?![\w-])", "sunmoon-link")
rule("runtime 仓", r"(\$\{?WS\}?/)runtime(?![\w-])", r"\1sunmoon-link")  # 本地联调脚本：RUNTIME="$WS/runtime"
rule("runtime 仓", r"(?<=\.\./)runtime(?=/agent\b|[\s`'\")]|$)", "sunmoon-link")
rule("runtime 仓", r"(?<![\w./-])runtime(?=/agent(?![\w-]))", "sunmoon-link")
rule("runtime 仓", r"`runtime`(?=\s*(?:仓|/agent))", "`sunmoon-link`")
rule("runtime 仓", r"(?<=客户端仓\*\* \| )`runtime`", "`sunmoon-link`")  # 术语表
rule("runtime 仓", r"（`runtime` / `desktop-app`）", "（`sunmoon-link` / `desktop-app`）")  # 本地代理仓自己的入口说明
rule("runtime 仓", r"(?<![\w./`-])runtime(?=\s*仓)", "sunmoon-link")
rule("runtime 仓", r"(客户端仓\s?`?)runtime\b", r"\1sunmoon-link")
# 2 investment → knowbench：整词（包括复合写法里的那一段），大小写各一
rule("应用名", r"INVESTMENT", "KNOWBENCH")
rule("应用名", r"Investment", "Knowbench")
rule("应用名", r"investment", "knowbench")
# 3 页面上的「投资工作台」改「工作台」（0028 第一节）
rule("页面文案", r"投资工作台", "工作台")


def scope(root: Path) -> list[str]:
    files: list[str] = []
    for repo in REPOS:
        out = subprocess.run(["git", "-c", "core.quotepath=off", "-C", str(root / repo), "ls-files", "--recurse-submodules"],
                             capture_output=True, text=True)
        names = out.stdout.splitlines() if out.returncode == 0 else []
        for n in names:
            rel = f"{repo}/{n}"
            if SKIP.search(rel) or RENDERED.search(rel):
                continue
            if Path(rel).suffix not in TEXT_SUFFIX and not Path(rel).name.startswith(("Makefile", "Dockerfile", ".env")):
                continue
            files.append(rel)
    return files


LOCK_NAME = re.compile(r'(?m)^name = "investment-(backend)"$')


def apply(text: str, rel: str, counts: dict) -> str:
    if rel.endswith("uv.lock"):  # 锁文件只改项目自身名字那一行
        new, n = LOCK_NAME.subn(r'name = "knowbench-\1"', text)
        if n:
            counts["锁文件"][rel] += n
        return new
    kept: list[str] = []

    def hide(m: re.Match) -> str:
        kept.append(m[0])
        return f"\x00{len(kept) - 1}\x00"

    for pat in KEEP:
        text = re.sub(pat, hide, text)
    for cls, pat, repl in R:
        text, n = re.subn(pat, repl, text)
        if n:
            counts[cls][rel] += n
    return re.sub(r"\x00(\d+)\x00", lambda m: kept[int(m[1])], text)


def moves(root: Path) -> dict[str, str]:
    """要 git mv 的：旧路径 → 新路径（仓的顶层目录名不在这里改，那是 R3）。路径上只用 investment 的规则。"""
    dirs: dict[str, str] = {}
    renamed: dict[str, str] = {}

    def new_path(rest: str) -> str:
        kept: list[str] = []

        def hide(m: re.Match) -> str:
            kept.append(m[0])
            return f"\x00{len(kept) - 1}\x00"

        for pat in KEEP:
            rest = re.sub(pat, hide, rest)
        rest = rest.replace("investment", "knowbench").replace("Investment", "Knowbench")
        return re.sub(r"\x00(\d+)\x00", lambda m: kept[int(m[1])], rest)

    listing: dict[str, list[str]] = {}
    for repo in REPOS:
        listing[repo] = subprocess.run(["git", "-c", "core.quotepath=off", "-C", str(root / repo), "ls-files", "--recurse-submodules"],
                                       capture_output=True, text=True).stdout.splitlines()
        for n in listing[repo]:
            rel = f"{repo}/{n}"
            if SKIP.search(rel):  # 历史记录、已有迁移等不按自己的名字改，只随改了名的上级目录走
                continue
            new = f"{repo}/{new_path(n)}"
            if new == rel:
                continue
            renamed[rel] = new
            old_parts, new_parts = rel.split("/"), new.split("/")
            for i in range(1, len(old_parts)):
                if old_parts[:i] != new_parts[:i]:
                    dirs["/".join(old_parts[:i])] = "/".join(new_parts[:i])
    out = {}
    for repo, names in listing.items():
        for n in names:
            rel = f"{repo}/{n}"
            if rel in renamed:
                out[rel] = renamed[rel]
                continue
            parts = rel.split("/")
            for i in range(len(parts) - 1, 0, -1):
                head = "/".join(parts[:i])
                if head in dirs:
                    out[rel] = dirs[head] + "/" + "/".join(parts[i:])
                    break
    return out


def main() -> None:
    root = Path(sys.argv[1]).expanduser()
    write = "--apply" in sys.argv
    report = sys.argv[sys.argv.index("--report") + 1] if "--report" in sys.argv else None
    counts: dict = defaultdict(lambda: defaultdict(int))
    for rel in scope(root):
        path = root / rel
        try:
            old = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
        new = apply(old, rel, counts)
        if write and new != old:
            path.write_text(new, encoding="utf-8")
    summary = {cls: {"files": len(v), "hits": sum(v.values())} for cls, v in counts.items()}
    print(json.dumps(summary, ensure_ascii=False, indent=1))
    if report:
        Path(report).write_text(json.dumps({k: dict(v) for k, v in counts.items()}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
