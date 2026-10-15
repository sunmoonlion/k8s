"""R5.1 渲染比对（k8s/docs/rename.md R5.1）：改名前的渲染产物 vs 这次 stage 出来的，逐个 k8s 对象比。

用法（在 k8s 仓根，stage 之后、提交之前）：
  .venv 或任何带 PyYAML 的 python3 docs/rename-tools/r5_render_diff.py <改名前的提交> > 报告.txt

做法：两边都读 gitops/components/**/{workload,kustomization}.yaml 与 gitops/clusters/kind/stages.yaml（加密的 *.sops.yaml、
image.lock.yaml 只比文件在不在）。旧的一边先用 rename_rules 把名字换成新名，再按 (kind, 命名空间, 名字) 配对；名字里的
12 位摘要片段、镜像摘要、config-sha256 一类注解先抹平。逐对象报：相同 / 有差异（附差异）/ 只在旧 / 只在新。

最要紧的一项「不可变 Job」：新渲染里的 Job，若**原样同名**（不经换名）已在旧渲染里、内容却变了，Flux 套用时会被
Kubernetes 拒绝（Job 模板不可改）——这类列在最前面，有一条就停。
"""

from __future__ import annotations

import difflib
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rename_rules as rr  # noqa: E402

RENDERED = re.compile(r"^gitops/(components/.*/(workload|kustomization)\.yaml|clusters/kind/stages\.yaml)$")
OPAQUE = re.compile(r"^gitops/components/.*/([^/]*\.sops\.yaml|image\.lock\.yaml)$")
DIGEST_IN_NAME = re.compile(r"(?<=-)[0-9a-f]{12}(?=-|$)")
IMAGE_DIGEST = re.compile(r"@sha256:[0-9a-f]{64}")
VOLATILE_ANNOTATION = re.compile(r"(config-sha256|checksum|sha256)")
# 比对专用的补充换名（只套在旧的一边）：渲染产物里按应用名拼出的对象名（info-public-sites-out）、
# YAML 字符串里 JSON 的键（CROSS_APP_TARGETS_JSON）——源头模板已改，规则不必管渲染产物
EXTRA = [
    (re.compile(r"(?<![\w.-])info-(?=[a-z0-9])"), "knowfeed-"),
    (re.compile(r'(?<=[{,] )"info":|(?<=\{)"info":'), '"knowfeed":'),
    (re.compile(r'(?<=[{,] )"knowledge":|(?<=\{)"knowledge":'), '"knowbase":'),
]


def extra(text: str) -> str:
    for pat, repl in EXTRA:
        text = pat.sub(repl, text)
    return text


def git(*args: str) -> str:
    return subprocess.run(["git", "-c", "core.quotepath=off", *args], check=True, capture_output=True, text=True).stdout


def files_at(ref: str | None) -> dict[str, str]:
    if ref is None:
        names = git("ls-files", "--cached", "--others", "--exclude-standard", "gitops").splitlines()
        return {n: Path(n).read_text(encoding="utf-8") for n in names if (RENDERED.match(n) or OPAQUE.match(n)) and Path(n).exists()}
    names = git("ls-tree", "-r", "--name-only", ref, "gitops").splitlines()
    return {n: git("show", f"{ref}:{n}") for n in names if RENDERED.match(n) or OPAQUE.match(n)}


def mapped_path(path: str) -> str:
    return rr.apply(path, "k8s/" + path, _sink())


def _sink():
    from collections import defaultdict
    return defaultdict(lambda: defaultdict(int))


def objects(_path: str, text: str) -> list[dict]:
    out = []
    for doc in yaml.safe_load_all(text):
        if isinstance(doc, dict) and doc.get("kind"):
            out.append(doc)
    return out


def scrub(obj):
    if isinstance(obj, dict):
        res = {}
        for k, v in obj.items():
            if k == "annotations" and isinstance(v, dict):
                v = {ak: av for ak, av in v.items() if not VOLATILE_ANNOTATION.search(ak)}
            res[k] = scrub(v)
        return res
    if isinstance(obj, list):
        return [scrub(x) for x in obj]
    if isinstance(obj, str):
        return DIGEST_IN_NAME.sub("<d>", IMAGE_DIGEST.sub("@sha256:<d>", obj))
    return obj


def key(obj: dict) -> tuple[str, str, str]:
    meta = obj.get("metadata", {})
    return (obj["kind"], meta.get("namespace", ""), str(meta.get("name", "")))


def norm_key(k: tuple[str, str, str]) -> tuple[str, str, str]:
    return (k[0], k[1], DIGEST_IN_NAME.sub("<d>", k[2]))


def main() -> None:
    old_ref = sys.argv[1]
    old_files, new_files = files_at(old_ref), files_at(None)

    old_exact: dict[tuple, dict] = {}
    old_mapped: dict[tuple, tuple[str, dict]] = {}
    for path, text in old_files.items():
        if not RENDERED.match(path):
            continue
        for obj in objects(path, text):
            old_exact[key(obj)] = obj
        mtext = extra(rr.apply(text, "k8s/" + mapped_path(path), _sink()))
        for obj in objects(path, mtext):
            old_mapped[norm_key(key(obj))] = (path, obj)
    new_objs: dict[tuple, tuple[str, dict]] = {}
    new_exact: dict[tuple, dict] = {}
    for path, text in new_files.items():
        if not RENDERED.match(path):
            continue
        for obj in objects(path, text):
            new_exact[key(obj)] = obj
            new_objs[norm_key(key(obj))] = (path, obj)

    # 1. 不可变 Job
    risks = []
    for k, obj in new_exact.items():
        if k[0] == "Job" and k in old_exact and json.dumps(old_exact[k], sort_keys=True) != json.dumps(obj, sort_keys=True):
            risks.append(k)
    print("== 1. 不可变 Job：原样同名、内容变了（有一条就停）")
    for k in sorted(risks):
        print(f"  !! {k[0]} {k[1]}/{k[2]}")
    print(f"  共 {len(risks)} 条")

    # 2. 逐对象
    same, changed, only_old, only_new = [], [], [], []
    for k in sorted(set(old_mapped) | set(new_objs)):
        if k not in new_objs:
            only_old.append(k)
        elif k not in old_mapped:
            only_new.append(k)
        else:
            a = yaml.safe_dump(scrub(old_mapped[k][1]), allow_unicode=True, sort_keys=True).splitlines()
            b = yaml.safe_dump(scrub(new_objs[k][1]), allow_unicode=True, sort_keys=True).splitlines()
            (same if a == b else changed).append((k, a, b))
    print(f"\n== 2. 对象统计：相同 {len(same)}，有差异 {len(changed)}，只在旧 {len(only_old)}，只在新 {len(only_new)}")
    print("\n== 3. 只在旧（换名后在新渲染里找不到）")
    for k in only_old:
        print(f"  - {k[0]} {k[1]}/{k[2]}   （{old_mapped[k][0]}）")
    print("\n== 4. 只在新")
    for k in only_new:
        print(f"  + {k[0]} {k[1]}/{k[2]}   （{new_objs[k][0]}）")
    print("\n== 5. 有差异（旧的已换名；摘要与 config-sha256 已抹平）")
    for k, a, b in changed:
        print(f"\n--- {k[0]} {k[1]}/{k[2]}   （{new_objs[k][0]}）")
        for line in list(difflib.unified_diff(a, b, lineterm="", n=1))[2:80]:
            print("  " + line)

    # 6. 加密文件与镜像锁：只看在不在
    print("\n== 6. 加密秘密与镜像锁（只比在不在；内容每次都不同）")
    old_opaque = {mapped_path(p) for p in old_files if OPAQUE.match(p)}
    new_opaque = {p for p in new_files if OPAQUE.match(p)}
    for p in sorted(old_opaque - new_opaque):
        print(f"  - {p}")
    for p in sorted(new_opaque - old_opaque):
        print(f"  + {p}")
    print(f"  两边都有 {len(old_opaque & new_opaque)} 个")
    print(f"\nexit={1 if risks else 0}")
    sys.exit(1 if risks else 0)


if __name__ == "__main__":
    main()
