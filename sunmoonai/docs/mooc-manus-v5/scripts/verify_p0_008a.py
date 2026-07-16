#!/usr/bin/env python3
"""Verify the frozen P0-008A Web architecture inputs without printing secrets."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


IXARTZ_SHA = "9926cc1f8664f67eca63065bf1c31bc4f60b09c2"
TPL_FRONTEND_SHA = "4db03b2e04025a8014237f00e63835a99ddd81ca"
TPL_BACKEND_SHA = "d1abfa3409aae93d62d36733d55f50021e104ba1"

IXARTZ_HASHES = {
    "LICENSE": "cc79352a90f66bb27020bc40cb7481e661de807875e4ece5533ee4d4d9d20616",
    "package.json": "282b8613b0dcbe641e9698702b08b7ef3772a895da9c85d8a8b081ca2c5b2508",
    "next.config.ts": "6651768a85259ca706b7fd741534a62231eba528e0d99b5be1c397bc2912662f",
    "src/libs/Env.ts": "8184052ba254478aaf0d97305b281212ffd87c38aa11c5029c3a823d958ebe65",
    "playwright.config.ts": "8acb5d4674b5c022721b3d8ae8230e9e8cceb3d5f79d7f5a3f6e5c41fccefa10",
    "vitest.config.ts": "71bc7d83e65556064bc0278262afbce6627e66bdad3a65ceb3b3e289cc9c2b66",
    ".github/workflows/CI.yml": "421016c4d2db8d47b79fe8014462c399980840ffeadf7fc4a243bd6511f51bf3",
}

TPL_FRONTEND_HASHES = {
    "app/package.json": "7cfbd584e383398540a229d5dc4165a3b07d08d58053e2321b401aff1ef8d1b7",
    "app/pnpm-lock.yaml": "ba938b76b26143e6f9e9617aebfef9cbadfd4291b3a5a4504032fd36b17d4f32",
    "app/next.config.ts": "99d26d0a5a2a7401e651f6380fb37a36a9fa9682213457d82e69b0ce9225bef1",
    "app/proxy.ts": "352b4cf8fb50540861f398e807221a5d74e9f02d954cfff78aaf9dbca2085c08",
    "app/.env.example": "2fca2078c07c7564a461d439bcf3db1897b83517733928fe8320cde565e58334",
    "app/.env.k8s": "746e875c5814ad8b526f723c31312d2e192c3efb0cd56ae168bf4a6ea556fbbc",
    "mybuild/Dockerfile": "a069b967429fe9ee754befceae523ffd8f42311245b583a27ca4b7c6c552128a",
}

WEB_PAIRS = {
    "info": {
        "parent": "37988c873e8dc4e6a7f019ee8eec26f90ce8c82d",
        "root": "info-app",
        "frontend_path": "info-web-frontend",
        "frontend": "abdbf63849c847b4301c37d31dec12405e2d3257",
        "backend_path": "info-web-backend",
        "backend": "ffbc54ea2fe739495cdbd73ce174ec8c70bbd79e",
    },
    "knowledge": {
        "parent": "2e410ad0ba8f813844147df39cda56269618a97e",
        "root": "knowledge-app",
        "frontend_path": "knowledge-web-frontend",
        "frontend": "2f4f68257062ea006e8e03ccd8e06844db7c1ad6",
        "backend_path": "knowledge-web-backend",
        "backend": "ada118c984e6338998d7f405579e3a4cd5434e76",
    },
    "research": {
        "parent": "81215951809ead1cb5b06df182937551b026ebed",
        "root": "research-app",
        "frontend_path": "research-web-frontend",
        "frontend": "ea42d2974f1063ede160c8a547f49e616d6948aa",
        "backend_path": "research-web-backend",
        "backend": "0714115ab64a730033f3544bdf2de78ed06aba81",
    },
}


def run_git(repo: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def assert_worktree_hashes(root: Path, expected: dict[str, str]) -> None:
    for relative, digest in expected.items():
        actual = sha256_bytes((root / relative).read_bytes())
        if actual != digest:
            raise AssertionError(
                f"hash mismatch for {root / relative}: expected {digest}, got {actual}"
            )


def assert_commit_file_hashes(
    repo: Path,
    commit: str,
    expected: dict[str, str],
) -> None:
    run_git(repo, "cat-file", "-e", f"{commit}^{{commit}}")
    for relative, digest in expected.items():
        content = subprocess.run(
            ["git", "-C", str(repo), "show", f"{commit}:{relative}"],
            check=True,
            capture_output=True,
        ).stdout
        actual = sha256_bytes(content)
        if actual != digest:
            raise AssertionError(
                f"historical hash mismatch for {repo}@{commit}:{relative}"
            )


def gitlink_at(repo: Path, commit: str, path: str) -> str:
    output = run_git(repo, "ls-tree", commit, "--", path)
    fields = output.split()
    if len(fields) < 3 or fields[0] != "160000" or fields[1] != "commit":
        raise AssertionError(f"{repo}@{commit}:{path} is not a gitlink: {output}")
    return fields[2]


def validate_ixartz(ixartz: Path) -> None:
    if run_git(ixartz, "rev-parse", "HEAD") != IXARTZ_SHA:
        raise AssertionError("ixartz worktree is not at the frozen source SHA")
    assert_worktree_hashes(ixartz, IXARTZ_HASHES)
    license_text = (ixartz / "LICENSE").read_text()
    if "MIT License" not in license_text:
        raise AssertionError("ixartz frozen source is not MIT licensed")

    package = json.loads((ixartz / "package.json").read_text())
    if package.get("engines", {}).get("node") != ">=24":
        raise AssertionError("ixartz Node hard requirement changed from reviewed input")
    dependencies = set(package.get("dependencies", {}))
    rejected = {
        "@arcjet/next",
        "@clerk/nextjs",
        "@sentry/nextjs",
        "drizzle-orm",
    }
    if not rejected.issubset(dependencies):
        raise AssertionError("ixartz rejected dependency facts changed")


def validate_template_frontend(repo: Path) -> None:
    assert_commit_file_hashes(repo, TPL_FRONTEND_SHA, TPL_FRONTEND_HASHES)
    if run_git(repo, "ls-files", "--", "app/.env.local"):
        raise AssertionError("template still tracks app/.env.local")
    if not (repo / "app/proxy.ts").is_file():
        raise AssertionError("Next 16 proxy.ts is missing")
    if (repo / "app/middleware.ts").exists():
        raise AssertionError("legacy middleware.ts still exists")

    package = json.loads((repo / "app/package.json").read_text())
    if package.get("packageManager") != "pnpm@10.24.0":
        raise AssertionError("template pnpm version drifted")
    if package.get("dependencies", {}).get("next") != "16.2.2":
        raise AssertionError("template Next baseline drifted")
    if package.get("dependencies", {}).get("react") != "19.2.4":
        raise AssertionError("template React baseline drifted")
    if "NEXT_PUBLIC_API_URL=/api" not in (repo / "app/.env.example").read_text():
        raise AssertionError("template no longer defaults to same-origin /api")


def validate_template_backend(repo: Path) -> None:
    run_git(repo, "cat-file", "-e", f"{TPL_BACKEND_SHA}^{{commit}}")
    service = run_git(
        repo,
        "show",
        f"{TPL_BACKEND_SHA}:app/src/access-control/auth/auth.service.ts",
    )
    controller = run_git(
        repo,
        "show",
        f"{TPL_BACKEND_SHA}:app/src/access-control/auth/auth.controller.ts",
    )
    required_legacy_facts = (
        "state: randomUUID()" in service,
        "parseIdTokenPayload" in service,
        "JSON.stringify(tokens)" in service,
        "`session:${sessionId}`" in service,
        "@Get('logout')" in controller,
    )
    if not all(required_legacy_facts):
        raise AssertionError("reviewed legacy Web BFF findings changed")
    if "code_challenge" in service or "nonce" in service:
        raise AssertionError("baseline unexpectedly contains unreviewed PKCE/nonce logic")


def validate_pairs(workspace: Path) -> None:
    for name, pair in WEB_PAIRS.items():
        root = workspace / pair["root"]
        run_git(root, "cat-file", "-e", f"{pair['parent']}^{{commit}}")
        frontend = gitlink_at(root, pair["parent"], pair["frontend_path"])
        backend = gitlink_at(root, pair["parent"], pair["backend_path"])
        if frontend != pair["frontend"] or backend != pair["backend"]:
            raise AssertionError(
                f"{name} Web pair snapshot drifted: frontend={frontend}, backend={backend}"
            )


def validate_adr(k8s: Path) -> None:
    adr = (
        k8s
        / "sunmoonai/docs/mooc-manus-v5/adr/ADR-014-next-web-template-rebaseline.md"
    ).read_text()
    required = (
        "状态：ACCEPTED",
        "Nest Web Backend 是默认 BFF",
        "## 10. BFF 路由 allowlist",
        "## 11. Route rendering matrix",
        "## 12. Cache owner matrix",
        "## 13. Stream/reconciliation 契约",
        "## 14. 环境、兼容与发布矩阵",
    )
    missing = [item for item in required if item not in adr]
    if missing:
        raise AssertionError(f"ADR-014 missing frozen decisions: {missing}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--workspace",
        type=Path,
        default=Path.home(),
        help="Workspace root containing k8s, tpl-app, app repos and repo clone",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    workspace = args.workspace.resolve()
    ixartz = workspace / "repo/Next-js-Boilerplate"
    tpl_frontend = workspace / "tpl-app/tpl-web-frontend"
    tpl_backend = workspace / "tpl-app/tpl-web-backend"
    k8s = workspace / "k8s"

    validate_ixartz(ixartz)
    validate_template_frontend(tpl_frontend)
    validate_template_backend(tpl_backend)
    validate_pairs(workspace)
    validate_adr(k8s)

    print(
        json.dumps(
            {
                "task": "V5-P0-008A",
                "result": "passed",
                "adr_status": "ACCEPTED",
                "ixartz_sha": IXARTZ_SHA,
                "tpl_web_frontend_baseline": TPL_FRONTEND_SHA,
                "tpl_web_backend_baseline": TPL_BACKEND_SHA,
                "web_pairs": sorted(WEB_PAIRS),
                "legacy_bff_findings_recorded": True,
                "secrets_printed": False,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
