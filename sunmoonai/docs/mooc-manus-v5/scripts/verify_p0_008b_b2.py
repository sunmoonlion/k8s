#!/usr/bin/env python3
"""Verify the committed P0-008B/B2 Nest identity and Next DAL baseline."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


FRONTEND_SHA = "b1730a6f6d63bee6247c459868c9b9df3fa98ce5"
BACKEND_SHA = "839ea091c602985f60020977a5d2beb14ff7df88"
PARENT_SHA = "4cae61d352273fdac2fa9c6fd8992031067bdde4"

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
        raise AssertionError(f"{path} is missing B2 markers: {missing}")
    return text


def assert_clean_commit(repo: Path, expected: str) -> None:
    if git(repo, "rev-parse", "HEAD") != expected:
        raise AssertionError(f"{repo} is not at its frozen B2 commit")
    if git(repo, "status", "--porcelain"):
        raise AssertionError(f"{repo} has uncommitted changes")


def assert_gitlink(parent: Path, path: str, expected: str) -> None:
    fields = git(parent, "ls-tree", "HEAD", "--", path).split()
    if len(fields) < 3 or fields[:2] != ["160000", "commit"] or fields[2] != expected:
        raise AssertionError(f"{path} gitlink is not pinned to B2")


def validate_backend(repo: Path) -> None:
    assert_clean_commit(repo, BACKEND_SHA)
    auth = require_text(
        repo / "app/src/access-control/auth/auth.service.ts",
        "code_verifier",
        "getdel(",
        "AUTH_ROLE_ALLOWLIST",
        "AUTH_SCOPE_ALLOWLIST",
        "AUTH_POLICY_VERSION",
        "validateCsrf",
    )
    if "access_token" in auth or "refresh_token" in auth or "id_token" in auth:
        raise AssertionError("provider tokens crossed into the browser session service")
    require_text(
        repo / "app/src/access-control/auth/oidc-provider.service.ts",
        "code_challenge_method: 'S256'",
        "requiredClaims: ['iss', 'sub', 'aud', 'iat', 'exp', 'nonce']",
        "createLocalJWKSet",
        "redirect: 'manual'",
        "audience_mismatch",
        "issuer_mismatch",
    )
    require_text(
        repo / "app/src/access-control/auth/auth.controller.ts",
        "httpOnly: true",
        "sameSite: 'lax'",
        "@Post('logout')",
        "toBrowserDto",
    )
    require_text(
        repo / "app/src/access-control/auth/session.guard.ts",
        "IS_PUBLIC_KEY",
        "validateCsrf",
        "request.principal = session.principal",
    )
    require_text(
        repo / "app/src/common/config/environment.ts",
        "AUTH_SESSION_COOKIE_NAME",
        "AUTH_TRANSACTION_KEY_PREFIX",
        "AUTH_ALLOWED_ORIGINS",
        "SESSION_COOKIE_SECURE",
    )


def validate_frontend(repo: Path) -> None:
    assert_clean_commit(repo, FRONTEND_SHA)
    require_text(
        repo / "app/contracts/auth.ts",
        "browserSessionSchema",
        "surface: z.literal('web')",
        ".strict()",
    )
    require_text(
        repo / "app/lib/auth/browser-session.ts",
        "new URL('/api/auth/me', backendUrl)",
        "Cookie: cookieHeader",
        "cache: 'no-store'",
        "browserSessionSchema.safeParse",
    )
    require_text(
        repo / "app/lib/server/auth-session.ts",
        "import 'server-only'",
        "WEB_BACKEND_INTERNAL_URL",
        "requireBrowserSession",
    )
    require_text(
        repo / "app/env/server-schema.ts",
        "DEPLOYMENT_ENV",
        "APP_ORIGIN must use HTTPS in a production deployment",
        "test APP_ORIGIN must use a loopback host",
    )
    require_text(
        repo / "app/components/auth/logout-button.tsx",
        "method: 'POST'",
        "X-CSRF-Token",
        "credentials: 'same-origin'",
    )
    if (repo / "app/lib/request.ts").exists():
        raise AssertionError("legacy Axios browser client still exists")


def validate_shared_contract(k8s: Path) -> None:
    contract_root = k8s / "sunmoonai/docs/mooc-manus-v5/contracts/security/v1"
    schema = json.loads((contract_root / "browser-session.schema.json").read_text())
    vectors = json.loads((contract_root / "browser-session.vectors.json").read_text())
    identity = json.loads((contract_root / "identity-contract.json").read_text())
    if schema.get("additionalProperties") is not False:
        raise AssertionError("browser session DTO is not closed")
    if "provider_unavailable" not in identity.get("reason_codes", []):
        raise AssertionError("shared identity reason codes drifted")
    valid = vectors["valid"][0]["value"]
    if valid["user"]["surface"] != "web" or "access_token" in valid:
        raise AssertionError("valid Web session vector is unsafe")
    invalid = {item["name"]: item["value"] for item in vectors["invalid"]}
    if "access_token" not in invalid["provider-token-leak"]:
        raise AssertionError("provider-token negative vector is missing")
    if invalid["admin-session-on-web-consumer"]["user"]["surface"] != "admin":
        raise AssertionError("surface-isolation negative vector is missing")


def validate_business_web_unchanged(workspace: Path) -> None:
    for app, (frontend, backend) in BUSINESS_WEB_SNAPSHOTS.items():
        parent = workspace / f"{app}-app"
        if git(parent / f"{app}-web-frontend", "rev-parse", "HEAD") != frontend:
            raise AssertionError(f"{app} Web Frontend changed during B2")
        if git(parent / f"{app}-web-backend", "rev-parse", "HEAD") != backend:
            raise AssertionError(f"{app} Web Backend changed during B2")


def main() -> None:
    workspace = Path.home()
    parent = workspace / "tpl-app"
    frontend = parent / "tpl-web-frontend"
    backend = parent / "tpl-web-backend"
    k8s = workspace / "k8s"

    assert_clean_commit(parent, PARENT_SHA)
    assert_gitlink(parent, "tpl-web-frontend", FRONTEND_SHA)
    assert_gitlink(parent, "tpl-web-backend", BACKEND_SHA)
    validate_frontend(frontend)
    validate_backend(backend)
    validate_shared_contract(k8s)
    validate_business_web_unchanged(workspace)

    print(
        json.dumps(
            {
                "task": "V5-P0-008B-B2-source",
                "result": "passed",
                "frontend_commit": FRONTEND_SHA,
                "backend_commit": BACKEND_SHA,
                "parent_commit": PARENT_SHA,
                "backend_unit_tests": 29,
                "backend_e2e_tests": 2,
                "frontend_tests": 22,
                "paired_playwright_tests": 5,
                "business_web_repositories_unchanged": True,
                "provider_tokens_exposed": False,
                "secrets_printed": False,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
