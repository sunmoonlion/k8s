"""R1 的手工补丁（k8s/docs/rename.md R1，0028）：替换规则管不到、要逐处判断的几处。

用法：由 r1_apply.py 在替换内容之后调用；也可单独 python3 manual_patch.py <八组仓的上一级目录>。
1. 同步与对齐脚本里，runtime 作为仓名是裸词（`for r in $FIVE runtime`），只在这三个文件里整词换；
2. 拓扑说明里「将改名 agent」那句已过时（2026-10-16 作废，2026-10-17 改定 sunmoon-link）；
3. 契约：schema 里没有应用名，锁不用动（锁测试会核）；knowbase 检索契约的示例请求里有应用名（`policy_version`），
   它的 contract-manifest 按文件记了摘要，改过的文件重算摘要；
4. 录下来的预览样例不在替换范围里，但 knowfeed 管理端的样例里跨应用来源 `"app": "investment"` 有 4 处，
   页面测试按新名断言，只换这个键值（别的样例里没有应用名）。
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

SYNC_SCRIPTS = [
    "k8s/docs/dev-investment-agent/switch-test/human-local.sh",
    "k8s/docs/dev-investment-agent/switch-test/human-remote.sh",
    "k8s/docs/dev-investment-agent/switch-test/align_workstations.sh",
]


def edit(path: Path, pattern: str, repl: str, *, expect: int | None = None) -> int:
    text = path.read_text(encoding="utf-8")
    new, n = re.subn(pattern, repl, text)
    if expect is not None and n != expect:
        raise SystemExit(f"{path}: 期望改 {expect} 处，实际 {n} 处")
    path.write_text(new, encoding="utf-8")
    return n


def main(root: Path) -> None:
    for rel in SYNC_SCRIPTS:
        n = edit(root / rel, r"(?<![\w./$-])runtime(?![\w./-])", "sunmoon-link")
        print(f"补丁  {rel}: {n} 处 runtime")
    edit(root / "k8s/docs/拓扑.md", r"（将改名 `agent`）", "", expect=1)
    # 契约 schema 里没有应用名（2026-10-17 核过），锁不用动；各提供方与调用方的锁测试会核
    manifest_path = root / "knowbase-app/contracts/retrieval/v1/contract-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    changed = 0
    for name in manifest["files"]:
        digest = hashlib.sha256((manifest_path.parent / name).read_bytes()).hexdigest()
        if digest != manifest["files"][name]:
            manifest["files"][name] = digest
            changed += 1
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"补丁  knowbase 检索契约清单：重算 {changed} 个摘要")
    fixtures = sorted((root / "knowfeed-app/knowfeed-admin-frontend/app/preview/fixtures").rglob("*.json"))
    hits = sum(edit(f, r'"app": "investment"', '"app": "knowbench"') for f in fixtures)
    if hits != 4:
        raise SystemExit(f"knowfeed 管理端样例：期望 4 处，实际 {hits} 处")
    print(f"补丁  knowfeed 管理端预览样例：{hits} 处跨应用来源")


if __name__ == "__main__":
    main(Path(sys.argv[1]).expanduser())
