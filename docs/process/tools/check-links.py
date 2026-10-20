#!/usr/bin/env python3
"""活文档里的相对链接都能解析吗。扫全仓 markdown（不含 scripts/results/，回执是历史），报解析不到的 `[..](路径)`。
退出码：0 没有坏链；1 有。`--baseline 文件` 把结果写进文件；`--compare 文件` 只报比文件里多出来的（搬家前后对比用）。只用标准库。"""
import argparse
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
SKIP_DIRS = {".git", "node_modules", ".venv", ".build", ".tools"}
LINK_RE = re.compile(r"\]\(([^)\s]+)\)")


def broken():
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if not name.endswith(".md"):
                continue
            p = pathlib.Path(dirpath) / name
            rel = p.relative_to(ROOT).as_posix()
            if rel.startswith("scripts/results/"):
                continue
            try:
                text = p.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for m in LINK_RE.finditer(text):
                t = m.group(1)
                if re.match(r"^[a-z][a-z0-9+.-]*:", t) or t.startswith("#") or t.startswith("/"):
                    continue
                path = t.partition("#")[0]
                if not path:
                    continue
                if not (p.parent / path).exists():
                    out.append(f"{rel}: {t}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline")
    ap.add_argument("--compare")
    a = ap.parse_args()
    items = broken()
    if a.baseline:
        pathlib.Path(a.baseline).write_text("\n".join(items) + ("\n" if items else ""))
    if a.compare:
        base = set(pathlib.Path(a.compare).read_text().splitlines())
        items = [i for i in items if i not in base]
        print(f"check-links: {len(items)} new broken link(s) beyond baseline ({len(base)})")
    else:
        print(f"check-links: {len(items)} broken link(s)")
    for i in items[:80]:
        print("  " + i)
    return 1 if items else 0


if __name__ == "__main__":
    sys.exit(main())
