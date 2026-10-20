#!/usr/bin/env python3
"""release 流水线第 2 阶段「改钉」（SDD 0033 第四节）：把 sources.yaml 里列出的应用钉到各自父仓在某分支的头，
三个子仓取父仓在那个提交里记录的 gitlink（和 Qwen 发布卡 3.1 节手改的结果一样）。只改给出的应用，别的行不动。
只用标准库；输入都按正则校验，因为它们来自 Jenkins 参数。退出码：0 改好（含「没变化」），2 输入不对，3 仓里查不到。
"""
import argparse
import pathlib
import re
import subprocess
import sys

COMPONENTS = {"backend": "{app}-backend", "web": "{app}-web-frontend", "admin": "{app}-admin-frontend"}


def git(repo, *args):
    return subprocess.check_output(["git", "-C", repo, *args], text=True).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repos", required=True, help="k8s 与 <app>-app 并列的目录")
    ap.add_argument("--branch", required=True)
    ap.add_argument("--apps", required=True, help="空格分隔")
    ap.add_argument("--file", default="infrastructure/applications/sources.yaml")
    a = ap.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9._/-]{1,80}", a.branch) or ".." in a.branch:
        sys.exit(2)
    apps = a.apps.split()
    if not apps or any(not re.fullmatch(r"[a-z][a-z0-9]{1,20}", x) for x in apps):
        sys.exit(2)
    repos = pathlib.Path(a.repos)
    path = pathlib.Path(a.file)
    text = path.read_text()
    changed = 0
    for app in apps:
        parent = repos / f"{app}-app"
        if not (parent / ".git").exists():
            print(f"{app}: no repo at {parent}", file=sys.stderr)
            sys.exit(3)
        try:
            head = git(parent, "rev-parse", "--verify", f"refs/remotes/origin/{a.branch}^{{commit}}")
        except subprocess.CalledProcessError:
            print(f"{app}: origin/{a.branch} not found", file=sys.stderr)
            sys.exit(3)
        want = {"parent_revision": head}
        for key, pattern in COMPONENTS.items():
            sub = pattern.format(app=app)
            entry = git(parent, "ls-tree", head, "--", sub)
            m = re.fullmatch(r"160000 commit ([0-9a-f]{40})\t" + re.escape(sub), entry)
            if not m:
                print(f"{app}: {sub} is not a gitlink in {head[:10]}", file=sys.stderr)
                sys.exit(3)
            want[f"{key}_parent_revision"] = m.group(1)
            want[f"{key}_revision"] = m.group(1)
        block = re.search(rf"(?m)^  {app}:\n(?:^    .*\n)*", text)
        if not block:
            print(f"{app}: not in {path}", file=sys.stderr)
            sys.exit(3)
        new = block.group(0)
        for key, value in want.items():
            new, n = re.subn(rf"(?m)^(    {key}: )[0-9a-f]{{40}}$", rf"\g<1>{value}", new)
            if n != 1:
                print(f"{app}: key {key} not found exactly once", file=sys.stderr)
                sys.exit(3)
        if new != block.group(0):
            changed += sum(1 for x, y in zip(block.group(0).splitlines(), new.splitlines()) if x != y)
            text = text.replace(block.group(0), new, 1)
        print(f"{app}: parent {head[:10]} backend {want['backend_revision'][:10]} web {want['web_revision'][:10]} admin {want['admin_revision'][:10]}")
    path.write_text(text)
    print(f"changed lines: {changed}")


if __name__ == "__main__":
    main()
