#!/usr/bin/env python3
"""把一次构建的「可审阅的部署镜像锁」（.build/applications/<repo>-deployment-image.yaml）写进组件目录的 image.lock.yaml。

只认四个字段：repository、digest、source_revision、deployment_id；来源文件缺字段或格式不对就拒绝。
目标已经是同一内容时不改文件（Git 工作区保持干净）。
"""
import re
import sys
from pathlib import Path

import yaml

FIELDS = ("repository", "digest", "source_revision", "deployment_id")


def main(source: str, target: str) -> int:
    src, dst = Path(source), Path(target)
    if not src.is_file():
        print(f"构建锁不存在：{src}（先 application-build-*）", file=sys.stderr)
        return 2
    data = yaml.safe_load(src.read_text())
    if not isinstance(data, dict) or set(data) != set(FIELDS):
        print(f"构建锁字段不对：{src} 有 {sorted(data) if isinstance(data, dict) else type(data)}", file=sys.stderr)
        return 2
    checks = {
        "repository": r"^[a-z][a-z0-9-]+$",
        "digest": r"^sha256:[a-f0-9]{64}$",
        "source_revision": r"^[a-f0-9]{40}$",
        "deployment_id": r"^[a-z][a-z0-9-]{5,90}$",
    }
    for key, pattern in checks.items():
        if not isinstance(data[key], str) or not re.fullmatch(pattern, data[key]):
            print(f"构建锁的 {key} 不合格式：{data[key]!r}", file=sys.stderr)
            return 2
    if dst.parent.name != data["repository"]:
        print(f"目标目录 {dst.parent.name} 和锁里的 repository {data['repository']} 不一致", file=sys.stderr)
        return 2
    body = "# Built and published through the native chain; written by application-lock-* after a successful publish.\n---\n" + "".join(
        f"{key}: {data[key]}\n" for key in FIELDS
    )
    if dst.is_file() and dst.read_text() == body:
        print(f"{dst}: 已是这一份（{data['digest'][:19]}）")
        return 0
    dst.write_text(body)
    print(f"{dst}: digest {data['digest'][:19]} source {data['source_revision'][:12]}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法：sync-image-lock.py <.build/applications/<repo>-deployment-image.yaml> <gitops/.../image.lock.yaml>", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1], sys.argv[2]))
