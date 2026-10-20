#!/usr/bin/env python3
"""docs 按内容拆（SDD 0038 第三节）用的搬家与改链工具。

两步：`--move` 按下面的对照表 `git mv`；`--rewrite` 把仓里活文档的链接按搬后的位置重算——
markdown 链接 `[..](相对路径)` 先按文件搬家前的位置解析成仓内绝对路径，再映射到新位置，再从文件的新位置重算相对路径；
文中直接写的仓内路径（`docs/dev-investment-agent/...` 这种）按前缀替换。不改 scripts/results/（回执只增不改）。
`--dry-run` 只报数。只用标准库。
"""
import argparse
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())

# 旧 → 新（仓内相对路径）。长前缀在前，整目录搬家的写目录。
MAP = [
    ("docs/design", "docs/design"),
    ("docs/process/pipeline.md", "docs/process/pipeline.md"),
    ("docs/process/turn", "docs/process/turn"),
    ("docs/process/switch-test", "docs/process/switch-test"),
    ("docs/process/tools", "docs/process/tools"),
    ("docs/process/README.md", "docs/process/README.md"),
    ("docs/ops/jenkins-使用说明.md", "docs/ops/jenkins-使用说明.md"),
    ("docs/process/rename-2026-10-15/README.md", "docs/process/rename-2026-10-15/README.md"),
    ("docs/process/rename-2026-10-15/receipts", "docs/process/rename-2026-10-15/receipts"),
    ("docs/process/rename-2026-10-15/tools", "docs/process/rename-2026-10-15/tools"),
    ("docs/reference/行业/专家市场架构对比分析和借鉴.md", "docs/reference/行业/专家市场架构对比分析和借鉴.md"),
    ("docs/reference/行业/竞品比较分析.md", "docs/reference/行业/竞品比较分析.md"),
    ("docs/project-guide/账号-电脑-link-会合点.md", "docs/project-guide/账号-电脑-link-会合点.md"),
]
SKIP_DIRS = {".git", "node_modules", ".venv", ".build", ".tools"}
SKIP_PREFIX = ("scripts/results/",)
TEXT_EXT = {".md", ".py", ".sh", ".ps1", ".yaml", ".yml", ".j2", ".txt", ".groovy", ".json"}
LINK_RE = re.compile(r"\]\(([^)\s]+)\)")


def map_path(rel: str) -> str:
    for old, new in MAP:
        if rel == old or rel.startswith(old + "/"):
            return new + rel[len(old):]
    return rel


def unmap_path(rel: str) -> str:
    for old, new in MAP:
        if rel == new or rel.startswith(new + "/"):
            return old + rel[len(new):]
    return rel


def iter_files():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            p = pathlib.Path(dirpath) / name
            rel = p.relative_to(ROOT).as_posix()
            if rel.startswith(SKIP_PREFIX) or p.suffix not in TEXT_EXT:
                continue
            if p.name in {"pre-commit", "pre-merge-commit"} or p.suffix in TEXT_EXT:
                yield p, rel
    for hook in (ROOT / ".githooks").glob("*"):
        if hook.is_file():
            yield hook, hook.relative_to(ROOT).as_posix()


def rewrite_text(rel_new: str, text: str):
    """rel_new：文件搬家后的仓内路径。返回 (新文本, 改链数, 改前缀数)。"""
    rel_old = unmap_path(rel_new)
    old_dir = pathlib.PurePosixPath(rel_old).parent
    new_dir = pathlib.PurePosixPath(rel_new).parent
    links = 0

    def fix_link(m):
        nonlocal links
        target = m.group(1)
        if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#") or target.startswith("/"):
            return m.group(0)
        path, sep, anchor = target.partition("#")
        if not path:
            return m.group(0)
        old_abs = os.path.normpath(str(old_dir / path)) if str(old_dir) != "." else os.path.normpath(path)
        if old_abs.startswith("../"):
            return m.group(0)
        new_abs = map_path(old_abs)
        new_rel = os.path.relpath(new_abs, str(new_dir) if str(new_dir) != "." else ".")
        if new_rel == path:
            return m.group(0)
        links += 1
        return "](" + new_rel + sep + anchor + ")"

    out = LINK_RE.sub(fix_link, text)
    prefixes = 0
    for old, new in MAP:
        # 不碰「提交号:路径」这种历史引用
        pattern = re.compile(r"(?<![:\w])" + re.escape(old) + r"(?=$|[/\s`'\")\]#,，。；：)])", re.M)
        out, n = pattern.subn(new, out)
        prefixes += n
    return out, links, prefixes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--move", action="store_true")
    ap.add_argument("--rewrite", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if a.move:
        for old, new in MAP:
            src, dst = ROOT / old, ROOT / new
            if not src.exists():
                print(f"skip (absent): {old}")
                continue
            if a.dry_run:
                print(f"would move {old} -> {new}")
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            subprocess.check_call(["git", "-C", str(ROOT), "mv", "-k", old, new])
            print(f"moved {old} -> {new}")
    if a.rewrite:
        total_files = total_links = total_prefixes = 0
        for p, rel in iter_files():
            try:
                text = p.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            out, links, prefixes = rewrite_text(rel, text)
            if out != text:
                total_files += 1
                total_links += links
                total_prefixes += prefixes
                if not a.dry_run:
                    p.write_text(out, encoding="utf-8")
        print(f"rewrite: files {total_files}, links {total_links}, prefixes {total_prefixes}{' (dry run)' if a.dry_run else ''}")


if __name__ == "__main__":
    sys.exit(main())
