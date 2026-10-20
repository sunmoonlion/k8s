#!/usr/bin/env python3
"""release 流水线第 2 阶段末尾「按钉对齐检出」：把 sources.yaml 里列出的应用仓检到钉住的提交——父仓到 parent_revision，
三个子仓到各自的 *_revision。构建链（applications/build.yaml）要求子仓 HEAD 恰等于钉的号且工作区干净，而第 1 阶段把各仓
检到的是分支头；钉落后于头时（PIN=keep 的常态）两者不同，不对齐就撞「拒绝构建未复核的修订」那道闸（2026-10-20 回执 fable-b3 第二版）。
只用标准库；退出码：0 对齐（含本来就在）；2 输入不对；3 仓里查不到或工作区不干净。
"""
import argparse
import pathlib
import re
import subprocess
import sys

COMPONENTS = {"backend": "{app}-backend", "web": "{app}-web-frontend", "admin": "{app}-admin-frontend"}


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repos", required=True)
    ap.add_argument("--apps", required=True)
    ap.add_argument("--file", default="infrastructure/applications/sources.yaml")
    a = ap.parse_args()
    apps = a.apps.split()
    if not apps or any(not re.fullmatch(r"[a-z][a-z0-9]{1,20}", x) for x in apps):
        sys.exit(2)
    text = pathlib.Path(a.file).read_text()
    repos = pathlib.Path(a.repos)
    for app in apps:
        block = re.search(rf"(?m)^  {app}:\n((?:^    .*\n)*)", text)
        if not block:
            print(f"{app}: not in {a.file}", file=sys.stderr)
            sys.exit(3)
        pins = dict(re.findall(r"(?m)^    (\w+): ([0-9a-f]{40})$", block.group(1)))
        parent = repos / f"{app}-app"
        try:
            git(parent, "checkout", "-q", "--detach", pins["parent_revision"])
            git(parent, "submodule", "update", "--init", "-q")
            for key, pattern in COMPONENTS.items():
                sub = parent / pattern.format(app=app)
                git(sub, "checkout", "-q", "--detach", pins[f"{key}_revision"])
        except (KeyError, subprocess.CalledProcessError) as exc:
            print(f"{app}: cannot align to pinned revisions: {exc}", file=sys.stderr)
            sys.exit(3)
        dirty = git(parent, "status", "--porcelain", "--untracked-files=all")
        if dirty:
            print(f"{app}: checkout not clean after aligning:\n{dirty}", file=sys.stderr)
            sys.exit(3)
        heads = " ".join(f"{k} {git(parent / p.format(app=app), 'rev-parse', 'HEAD')[:10]}" for k, p in COMPONENTS.items())
        print(f"{app}: parent {git(parent, 'rev-parse', 'HEAD')[:10]} {heads}")


if __name__ == "__main__":
    main()
