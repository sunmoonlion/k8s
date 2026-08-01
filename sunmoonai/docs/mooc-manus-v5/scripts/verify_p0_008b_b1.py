#!/usr/bin/env python3
"""Verify the committed P0-008B/B1 paired Web source baseline."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


ADMIN_SHA = "1561e5d02251ccc0f96fa48e272e4c5072a1e2c3"
FRONTEND_SHA = "f5340ac9c9b63d8179b9a5dc8feff3e85fb213ab"
BACKEND_SHA = "f5bedfb3ebd8ad3696545b1d0feb0a945ee1866f"
PARENT_SHA = "fe297396b07a05d684f985beac4f0292058f11b4"
NODE_VERSION = "24.18.0"
NODE_ENGINE = ">=24.18.0 <25"
PNPM_VERSION = "pnpm@10.24.0"
NODE_IMAGE_DIGEST = (
    "sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc"
)

BUSINESS_WEB_SNAPSHOTS = {
    "info": (
        "abdbf63849c847b4301c37d31dec12405e2d3257",
        "ffbc54ea2fe739495cdbd73ce174ec8c70bbd79e",
    ),
    "knowledge": (
        "2f4f68257062ea006e8e03ccd8e06844db7c1ad6",
        "ada118c984e6338998d7f405579e3a4cd5434e76",
    ),
    "research": (
        "ea42d2974f1063ede160c8a547f49e616d6948aa",
        "0714115ab64a730033f3544bdf2de78ed06aba81",
    ),
}


def git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def require_text(path: Path, *needles: str) -> str:
    text = path.read_text()
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path} is missing required B1 markers: {missing}")
    return text


def assert_clean_commit(repo: Path, expected: str) -> None:
    if git(repo, "rev-parse", "HEAD") != expected:
        raise AssertionError(f"{repo} is not at the frozen B1 commit")
    if git(repo, "status", "--porcelain"):
        raise AssertionError(f"{repo} has uncommitted changes")


def assert_gitlink(parent: Path, path: str, expected: str) -> None:
    fields = git(parent, "ls-tree", "HEAD", "--", path).split()
    if len(fields) < 3 or fields[:2] != ["160000", "commit"]:
        raise AssertionError(f"{path} is not a gitlink in tpl-app")
    if fields[2] != expected:
        raise AssertionError(f"{path} does not point at its B1 commit")


def validate_runtime_files(repo: Path, package_path: str) -> dict[str, object]:
    package = json.loads((repo / package_path).read_text())
    if package["packageManager"] != PNPM_VERSION:
        raise AssertionError(f"{repo.name} pnpm baseline drifted")
    if package["engines"]["node"] != NODE_ENGINE:
        raise AssertionError(f"{repo.name} Node compatibility drifted")
    if package["engines"]["pnpm"] != "10.24.x":
        raise AssertionError(f"{repo.name} pnpm compatibility drifted")
    for version_file in (".nvmrc", ".node-version"):
        if (repo / version_file).read_text().strip() != NODE_VERSION:
            raise AssertionError(f"{repo.name} {version_file} drifted")
    require_text(repo / "mybuild/Dockerfile", NODE_VERSION, NODE_IMAGE_DIGEST)
    return package


def validate_admin(repo: Path) -> None:
    assert_clean_commit(repo, ADMIN_SHA)
    package = validate_runtime_files(repo, "package.json")
    if package["dependencies"]["react-router"] != "^8.2.0":
        raise AssertionError("admin React Router baseline drifted")
    require_text(repo / "mybuild/Dockerfile", "pnpm@10.24.0")


def validate_frontend(repo: Path) -> None:
    assert_clean_commit(repo, FRONTEND_SHA)
    package = validate_runtime_files(repo, "app/package.json")
    if package["dependencies"]["next"] != "16.2.2":
        raise AssertionError("frontend Next baseline drifted")
    if package["dependencies"]["react"] != "19.2.4":
        raise AssertionError("frontend React baseline drifted")
    for script in ("check:i18n", "test", "test:e2e", "check"):
        if script not in package["scripts"]:
            raise AssertionError(f"frontend script missing: {script}")

    require_text(
        repo / "app/next.config.ts",
        "output: 'standalone'",
        "poweredByHeader: false",
        "reactStrictMode: true",
    )
    require_text(
        repo / "app/env/client.ts",
        "must be a same-origin absolute path",
        "NEXT_PUBLIC_API_URL",
    )
    require_text(
        repo / "app/env/server.ts",
        "import 'server-only'",
        "parseServerEnv",
    )
    require_text(
        repo / "app/app/[locale]/(dashboard)/dashboard/page.tsx",
        "force-dynamic",
        "revalidate = 0",
        "authenticated-workspace",
    )
    require_text(
        repo / "app/app/[locale]/page.tsx",
        "setRequestLocale",
        "PublicHome",
    )
    for relative in (
        "app/app/[locale]/loading.tsx",
        "app/app/[locale]/error.tsx",
        "app/app/[locale]/not-found.tsx",
        "app/app/robots.ts",
        "app/app/sitemap.ts",
        "app/vitest.config.mts",
        "app/playwright.config.ts",
        "app/tests/e2e/rendering.e2e.ts",
    ):
        if not (repo / relative).is_file():
            raise AssertionError(f"frontend B1 file missing: {relative}")

    dockerfile = require_text(
        repo / "mybuild/Dockerfile",
        "ARG NODE_VERSION=24.18.0",
        "NEXT_TELEMETRY_DISABLED=1",
        "USER nextjs",
        'CMD ["server.js"]',
    )
    if "NEXT_PUBLIC_CASDOOR" in dockerfile:
        raise AssertionError("frontend image contains a browser-exposed identity secret")
    if git(repo, "ls-files", "--", "app/.env.local"):
        raise AssertionError("frontend still tracks app/.env.local")


def validate_backend(repo: Path) -> None:
    assert_clean_commit(repo, BACKEND_SHA)
    package = validate_runtime_files(repo, "app/package.json")
    if package["dependencies"]["jose"] != "6.2.3":
        raise AssertionError("backend JOSE baseline drifted")
    for script in ("typecheck", "lint", "lint:all", "test:e2e", "check"):
        if script not in package["scripts"]:
            raise AssertionError(f"backend script missing: {script}")

    tracked = set(git(repo, "ls-files").splitlines())
    forbidden_tracked = {"app/.env", "db-access-bootstrap/.env.local.k8s.db"}
    if tracked & forbidden_tracked:
        raise AssertionError("backend still tracks generated credentials")

    env_contract = require_text(
        repo / "app/src/common/config/environment.ts",
        "NODE_TLS_REJECT_UNAUTHORIZED",
        "Environment validation failed for:",
        "CASDOOR_CLIENT_SECRET",
        "SSH_PASSWORD",
    )
    if "'123456'" not in env_contract:
        raise AssertionError("known default SSH credential is not explicitly rejected")

    k8s_env = (repo / "app/.env.k8s").read_text()
    for forbidden in (
        "NODE_TLS_REJECT_UNAUTHORIZED=0",
        "DATABASE_URL=REQUIRED_SECRET",
        "CASDOOR_CLIENT_SECRET=REQUIRED_SECRET",
        "REDIS_PASSWORD=REQUIRED_SECRET",
    ):
        if forbidden in k8s_env:
            raise AssertionError(f"unsafe tracked deployment placeholder remains: {forbidden}")

    for relative in (
        "app/src/common/cache/cache-common.module.ts",
        "app/src/common/cache/redis-common.module.ts",
        "app/src/conditional/conditional.module.ts",
    ):
        text = (repo / relative).read_text()
        if "'example'" in text or "password: '123456'" in text:
            raise AssertionError(f"default credential remains in {relative}")

    require_text(
        repo / "mybuild/Dockerfile",
        "pnpm@10.24.0",
        "npm_config_registry=${NPM_REGISTRY}",
        "http_proxy=${HTTP_PROXY}",
        "app/pnpm-workspace.yaml",
        "USER appuser",
    )
    require_text(
        repo / ".dockerignore",
        "app/node_modules/",
        "app/dist/",
        "app/.env.*",
    )


def validate_business_web_unchanged(workspace: Path) -> None:
    for app, (frontend, backend) in BUSINESS_WEB_SNAPSHOTS.items():
        parent = workspace / f"{app}-app"
        if git(parent / f"{app}-web-frontend", "rev-parse", "HEAD") != frontend:
            raise AssertionError(f"{app} Web Frontend changed before P0-008C")
        if git(parent / f"{app}-web-backend", "rev-parse", "HEAD") != backend:
            raise AssertionError(f"{app} Web Backend changed before P0-008C")


def main() -> None:
    workspace = Path.home()
    parent = workspace / "tpl-app"
    admin = parent / "tpl-admin-frontend"
    frontend = parent / "tpl-web-frontend"
    backend = parent / "tpl-web-backend"

    assert_clean_commit(parent, PARENT_SHA)
    assert_gitlink(parent, "tpl-admin-frontend", ADMIN_SHA)
    assert_gitlink(parent, "tpl-web-frontend", FRONTEND_SHA)
    assert_gitlink(parent, "tpl-web-backend", BACKEND_SHA)
    validate_admin(admin)
    validate_frontend(frontend)
    validate_backend(backend)
    validate_business_web_unchanged(workspace)

    print(
        json.dumps(
            {
                "task": "V5-P0-008B-B1-source",
                "result": "passed",
                "admin_commit": ADMIN_SHA,
                "frontend_commit": FRONTEND_SHA,
                "backend_commit": BACKEND_SHA,
                "parent_commit": PARENT_SHA,
                "node_version": NODE_VERSION,
                "node_image_digest": NODE_IMAGE_DIGEST,
                "business_web_repositories_unchanged": True,
                "secrets_printed": False,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
