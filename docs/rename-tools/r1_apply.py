"""R1 在真仓上的执行（k8s/docs/rename.md R1，0028）：顺序是为子仓结构定的，先在草稿复刻上演练过。

用法：python3 r1_apply.py <八组仓的上一级目录>   （仓的顶层目录名到 R3 才改，这里仍是 investment-app / runtime）
1. 在改名前的状态下算出全部改名计划（rename_rules.moves）；
2. 父仓里 git mv 子仓目录（同时改好 .gitmodules 的路径与子仓的工作区配置）——必须在替换内容之前，否则 .gitmodules 已被改、git mv 找不到子仓；
3. 子仓内部、父仓自身的其余改名，各在所属仓里 git mv；挪空的旧目录删掉，还有未跟踪内容的列出；
4. 替换内容（rename_rules.apply，列文件含子仓）；
5. 手工补丁（manual_patch）；
6. k8s：改名后的 knowbench 组件目录里旧的 *.sops.yaml git rm（存储从空的开始，秘密按新名全新生成）。
不提交、不推送：提交与推送按 rename.md R1 逐仓做。
"""

from __future__ import annotations

import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import manual_patch  # noqa: E402
import rename_rules as rr  # noqa: E402

PARENTS = ["tpl-app", "knowfeed-app", "knowbase-app", "knowlab-app", "knowmart-app", "investment-app", "runtime", "k8s"]


def git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True).stdout


def submodules(root: Path) -> dict[str, str]:
    """子仓相对路径 → 所属父仓。"""
    out = {}
    for parent in PARENTS:
        for line in git(root / parent, "submodule", "status").splitlines():
            path = line.split()[1]
            out[f"{parent}/{path}"] = parent
    return out


def owner(rel: str, subs: dict[str, str]) -> str:
    """一个文件属于哪个仓（最深的子仓，否则父仓）。"""
    best = rel.split("/", 1)[0]
    for sub in subs:
        if rel.startswith(sub + "/") and len(sub) > len(best):
            best = sub
    return best


def mv(repo: Path, old: str, new: str) -> None:
    (repo / new).parent.mkdir(parents=True, exist_ok=True)
    git(repo, "mv", old, new)


def main(root: Path) -> None:
    subs = submodules(root)
    plan = rr.moves(root)  # 旧 → 新，全部在改名前算
    # 2 子仓目录
    sub_new = {}
    for sub, parent in subs.items():
        probe = next((n for o, n in plan.items() if o.startswith(sub + "/")), None)
        if probe is None:
            continue
        depth = sub.count("/") + 1
        new_sub = "/".join(probe.split("/")[:depth])
        if new_sub != sub:
            mv(root / parent, sub.split("/", 1)[1], new_sub.split("/", 1)[1])
            sub_new[sub] = new_sub
            print(f"子仓  {sub} → {new_sub}")
    # 3 其余改名
    count = defaultdict(int)
    moved = {}  # 子仓目录挪过之后的实际旧路径 → 新路径
    for old, new in sorted(plan.items()):
        repo = owner(old, subs)
        if repo in subs:  # 子仓里的文件：子仓目录已整体移动，只做子仓内部的改名
            root_old, root_new = repo, sub_new.get(repo, repo)
            inner_old, inner_new = old[len(root_old) + 1:], new[len(root_new) + 1:]
            if inner_old != inner_new:
                mv(root / root_new, inner_old, inner_new)
                count[root_new] += 1
                moved[f"{root_new}/{inner_old}"] = new
        else:
            parent = old.split("/", 1)[0]
            mv(root / parent, old.split("/", 1)[1], new.split("/", 1)[1])
            count[parent] += 1
            moved[old] = new
    for repo, n in sorted(count.items()):
        print(f"改名  {repo}: {n} 个文件")
    # 3b 挪空了的旧目录删掉；还剩东西的（未跟踪的缓存之类）列出来，人看过再删
    new_dirs = {str(Path(n).parent) for n in moved.values()}
    new_dirs |= {str(a) for n in new_dirs for a in Path(n).parents}
    retired = {str(a) for o in moved for a in Path(o).parents if str(a) not in new_dirs and str(a) != "."}
    for d in sorted(retired, key=lambda x: -x.count("/")):
        path = root / d
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    for d in sorted(retired):
        path = root / d
        if path.is_dir() and str(Path(d).parent) not in retired:
            print(f"残留  {d}（{sum(1 for _ in path.rglob('*'))} 项，未跟踪）")
    # 4 替换内容
    counts = defaultdict(lambda: defaultdict(int))
    changed = 0
    for rel in rr.scope(root):
        path = root / rel
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, FileNotFoundError):
            continue
        new = rr.apply(text, rel, counts)
        if new != text:
            path.write_text(new, encoding="utf-8")
            changed += 1
    print(f"内容  {changed} 个文件")
    # 5 手工补丁
    manual_patch.main(root)
    print("补丁  完成")
    # 6 k8s：存储从空的开始，秘密按新名全新生成；旧密文在，stage 会按「已有库不许换口令」拒绝生成
    k8s = root / "k8s"
    removed = 0
    for sops in sorted((k8s / "gitops/components/app-platform/knowbench-app").rglob("*.sops.yaml")):
        git(k8s, "rm", "-q", "-f", str(sops.relative_to(k8s)))
        removed += 1
    print(f"k8s   旧 sops {removed} 个已 git rm")


if __name__ == "__main__":
    main(Path(sys.argv[1]).expanduser())
