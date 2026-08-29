#!/usr/bin/env python3
"""跨仓硬规则检查。

**为什么需要它**：`test_kernel_invariants.py` 管仓内结构，`check-docs.py` 管文档，
`test_dormant_capabilities.py` 管休眠声明——三者都够不着**跨仓**的规则。
原 ADR 里能机械判定的六条硬禁令就落在这个缝里，
于是一直靠人记得（gitlink 与 digest 两条，2026-08-29 之前是手工跑的）。

**用法**

    python3 check-cross-repo.py --repos /path/to/worktree
    python3 check-cross-repo.py --repos . --offline   # 跳过要连远端的检查

每条检查都必须**能真失败**。只报"通过"而从不失败的检查是装饰品——
加新检查时，先把它弄失败一次再提交。
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
import sys
from pathlib import Path

APPS = ("tpl", "info", "knowledge", "investment")
INSTANCE_APPS = ("info", "knowledge", "investment")
COMPONENTS = ("backend", "admin-frontend", "web-frontend")

# 受管凭据：浏览器身份、服务身份、数据库/中间件连接。
# 镜像拉取凭据（harbor-registry-secret）不属此列，三个 App 共用是正常的。
MANAGED_CREDENTIAL = re.compile(
    r"browser-identity|postgresql-conn|redis-conn|-broker$|-s3$"
    r"|elasticsearch$|-client$|service-binding$"
)


def rule_gitlink_reachable(root: Path, offline: bool) -> list[str]:
    """父仓不得出现悬空 gitlink（原 ADR-0008）。

    子仓提交没推送时，别人克隆父仓会拉不到那个 commit。
    """
    if offline:
        return []
    problems = []
    for app in APPS:
        parent = root / f"{app}-app"
        if not (parent / ".git").exists():
            continue
        for comp in COMPONENTS:
            sub = parent / f"{app}-{comp}"
            if not sub.exists():
                continue
            link = _git(parent, "rev-parse", f"HEAD:{app}-{comp}")
            if not link:
                continue
            branch = _git(sub, "rev-parse", "--abbrev-ref", "HEAD")
            remote = f"origin/{branch}" if branch != "HEAD" else "origin/HEAD"
            ok = subprocess.run(
                ["git", "-C", str(sub), "merge-base", "--is-ancestor", link, remote],
                capture_output=True,
            ).returncode == 0
            if not ok:
                problems.append(
                    f"悬空 gitlink  {app}-app 指向 {app}-{comp}@{link[:8]}，"
                    f"但它不在 {remote} 上——先推子仓，再推父仓"
                )
    return problems


def rule_bundle_digest_matches_release(root: Path) -> list[str]:
    """部署 bundle 引用的 digest 必须与发布清单一致（原 ADR-0013）。

    发布采用 exact-digest-alias：晋级靠打别名，禁止重新构建。
    bundle 若指向别的 digest，说明有人绕过了门禁。
    """
    manifest = (
        root
        / "k8s/sunmoonai/docs/architecture-v2/evidence/R7-release/release-manifest.json"
    )
    if not manifest.exists():
        return []
    images = json.loads(manifest.read_text(encoding="utf-8"))["images"]
    problems = []
    for app in INSTANCE_APPS:
        rel = (
            root
            / f"k8s/sunmoonai/app-platform/{app}-app/deployment/bundle/release.json"
        )
        if not rel.exists():
            continue
        for role, ref in json.loads(rel.read_text(encoding="utf-8"))["images"].items():
            want = images.get(f"{app}-{role}", {}).get("digest")
            got = ref.split("@")[-1]
            if want and want != got:
                problems.append(
                    f"digest 不符  {app}-{role}  bundle={got[:19]}… "
                    f"R7 清单={want[:19]}…"
                )
    return problems


def rule_no_implicit_migration_on_startup(root: Path) -> list[str]:
    """迁移由独立 Job 执行，API/Worker/Scheduler 启动不得隐式升级数据库（原 ADR-0010）。"""
    problems = []
    for app in APPS:
        for role in ("api", "worker", "scheduler"):
            f = root / f"{app}-app/{app}-backend/app/app/bootstrap/{role}.py"
            if not f.exists():
                continue
            text = f.read_text(encoding="utf-8")
            if re.search(r"command\.upgrade|alembic.*upgrade", text):
                problems.append(
                    f"隐式迁移  {app}-backend 的 {role}.py 里有 alembic upgrade——"
                    f"迁移只能由 migration.py 这个独立 Job 执行"
                )
    return problems


def rule_no_cross_app_tables(root: Path) -> list[str]:
    """禁止跨 App 直接读表（原 ADR-0007 / 0010）。

    判据：某个 App 的 ORM 模型里不得出现别的 App 的表名前缀。
    跨 App 只能走版本化契约、服务身份与 Outbox。
    """
    others = {
        "info": ("knowledge_", "investment_"),
        "knowledge": ("info_", "investment_"),
        "investment": ("info_", "knowledge_"),
    }
    problems = []
    for app, prefixes in others.items():
        d = root / f"{app}-app/{app}-backend/app/app/infrastructure/models"
        if not d.is_dir():
            continue
        for f in d.glob("*.py"):
            text = f.read_text(encoding="utf-8")
            for m in re.finditer(r'__tablename__\s*=\s*"([a-z_]+)"', text):
                name = m.group(1)
                if name.startswith(prefixes):
                    problems.append(
                        f"跨 App 表  {app}-backend 定义了 {name}——"
                        f"跨 App 只能走契约，不能直接建/读别人的表"
                    )
    return problems


def rule_no_hostpath_exchange(root: Path) -> list[str]:
    """不以共享宿主机目录作为正式交换协议（原 ADR-0004）。"""
    problems = []
    base = root / "k8s/sunmoonai/app-platform"
    if not base.is_dir():
        return []
    for f in base.glob("*/deployment/bundle/*.yaml"):
        if "hostPath" in f.read_text(encoding="utf-8"):
            problems.append(
                f"hostPath  {f.relative_to(root)} 用了宿主机目录——"
                f"跨 App 交换必须走对象引用 + 内容哈希"
            )
    return problems


def rule_managed_credentials_not_shared(root: Path) -> list[str]:
    """浏览器、服务、数据库凭据禁止复用（原 ADR-0009）。

    镜像拉取凭据不在此列——那不是这三类之一，共用是正常的。
    """
    seen: dict[str, list[str]] = collections.defaultdict(list)
    base = root / "k8s/sunmoonai/app-platform"
    for f in base.glob("*/deployment/bundle/release.json"):
        d = json.loads(f.read_text(encoding="utf-8"))
        for s in d.get("external_secrets", []):
            if MANAGED_CREDENTIAL.search(s):
                seen[s].append(d["logical_app"])
    return [
        f"凭据复用  {name} 被 {apps} 共用——浏览器/服务/数据库凭据必须各自独立"
        for name, apps in seen.items()
        if len(set(apps)) > 1
    ]


def _git(repo: Path, *args: str) -> str:
    try:
        return subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True,
            text=True,
            timeout=30,
        ).stdout.strip()
    except Exception:
        return ""


CHECKS = (
    ("gitlink 可达", rule_gitlink_reachable),
    ("digest 与发布清单一致", rule_bundle_digest_matches_release),
    ("启动不隐式迁移", rule_no_implicit_migration_on_startup),
    ("无跨 App 直接建表", rule_no_cross_app_tables),
    ("无 hostPath 交换", rule_no_hostpath_exchange),
    ("受管凭据不复用", rule_managed_credentials_not_shared),
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repos", type=Path, default=Path("."))
    ap.add_argument("--offline", action="store_true", help="跳过需要连远端的检查")
    args = ap.parse_args()
    root = args.repos.resolve()

    problems: list[str] = []
    for name, fn in CHECKS:
        found = fn(root, args.offline) if fn is rule_gitlink_reachable else fn(root)
        problems += found
        print(f"  {'✗' if found else '✓'} {name}")

    if problems:
        print()
        for p in problems:
            print(f"  {p}")
        print(f"\n不通过: {len(problems)}")
        return 1
    print("\n✓ 跨仓规则全部通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
