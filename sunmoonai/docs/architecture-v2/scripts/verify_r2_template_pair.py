#!/usr/bin/env python3
"""Verify both Next surfaces against one real Architecture v2 Backend.

The gate is intentionally destructive only to its own ``arch-v2-r2-*`` Docker
resources.  It never mutates KIND, Harbor, or a developer database.
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

ROOT = Path(
    os.environ.get(
        "SUNMOONAI_WORKSPACE_ROOT",
        str(Path(__file__).resolve().parents[5]),
    )
).resolve()
ADMIN_DIR = ROOT / "tpl-app/tpl-admin-frontend/app"
WEB_DIR = ROOT / "tpl-app/tpl-web-frontend/app"

NETWORK = "arch-v2-r2-template-pair"
POSTGRES = "arch-v2-r2-postgres"
REDIS = "arch-v2-r2-redis"
BACKEND = "arch-v2-r2-backend"
ADMIN = "arch-v2-r2-admin"
WEB = "arch-v2-r2-web"
CONTAINERS = (WEB, ADMIN, BACKEND, REDIS, POSTGRES)

BACKEND_PORT = 18093
ADMIN_GATEWAY_PORT = 18100
WEB_GATEWAY_PORT = 18101
ADMIN_NEXT_PORT = 18102
WEB_NEXT_PORT = 18103

DB_PASSWORD = "architecture-v2-r2-ephemeral"
DB_URL = (
    "postgresql+asyncpg://tpl_r2:architecture-v2-r2-ephemeral@"
    f"{POSTGRES}:5432/tpl_r2"
)

OUTBOX_PROGRAM = r'''
import asyncio

from app.application.dto.outbox import OutboxEvent
from app.infrastructure.repositories.outbox import SqlOutboxRepository
from app.infrastructure.storage.postgres import get_postgres


async def main():
    postgres = get_postgres()
    await postgres.init()
    repository = SqlOutboxRepository()
    event = OutboxEvent(
        topic="template.contract.test.v1",
        aggregate_key="aggregate-1",
        deduplication_key="architecture-v2-r2-outbox-1",
        payload={"contract_version": 1},
        headers={"operation_id": "architecture-v2-r2"},
    )
    async with postgres.session_factory() as session:
        first = await repository.enqueue(session, event)
        duplicate = await repository.enqueue(session, event)
        assert first == duplicate
        await session.commit()
    async with postgres.session_factory() as session:
        claimed = await repository.claim_batch(
            session, owner="r2-gate", limit=10, lease_seconds=30
        )
        assert len(claimed) == 1 and claimed[0].id == first
        await session.commit()
    async with postgres.session_factory() as session:
        await repository.mark_published(
            session, message_id=first, owner="r2-gate"
        )
        assert await repository.claim_inbox_once(
            session, consumer="r2-consumer", message_id=first
        )
        assert not await repository.claim_inbox_once(
            session, consumer="r2-consumer", message_id=first
        )
        await session.commit()
    await postgres.shutdown()


asyncio.run(main())
'''


class GateError(RuntimeError):
    pass


def run(
    *command: str,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        env=env,
        text=True,
        check=True,
        capture_output=capture,
    )


def docker(*arguments: str, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return run("docker", *arguments, capture=capture)


def cleanup(gateways: list[subprocess.Popen[str]]) -> None:
    for process in gateways:
        if process.poll() is None:
            process.terminate()
    for process in gateways:
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    for name in CONTAINERS:
        subprocess.run(
            ["docker", "rm", "-f", name],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    subprocess.run(
        ["docker", "network", "rm", NETWORK],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def request(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    payload: dict[str, object] | None = None,
    timeout: float = 10,
) -> tuple[int, dict[str, str], bytes]:
    data = None
    request_headers = dict(headers or {})
    if payload is not None:
        data = json.dumps(payload).encode()
        request_headers.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(
        url, data=data, headers=request_headers, method=method
    )
    try:
        with OPENER.open(req, timeout=timeout) as response:
            return response.status, dict(response.headers.items()), response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, dict(exc.headers.items()), exc.read()


def wait_http(url: str, *, expected: int = 200, timeout: float = 90) -> None:
    deadline = time.monotonic() + timeout
    last: object = None
    while time.monotonic() < deadline:
        try:
            status, _, _ = request(url, timeout=2)
            last = status
            if status == expected:
                return
        except (OSError, TimeoutError) as exc:
            last = type(exc).__name__
        time.sleep(0.5)
    raise GateError(f"timed out waiting for {url}; last={last}")


def expect_status(url: str, expected: int, **kwargs: Any) -> bytes:
    status, _, body = request(url, **kwargs)
    if status != expected:
        raise GateError(f"expected HTTP {expected} for {url}, got {status}")
    return body


def session(surface: str, *, roles: tuple[str, ...]) -> str:
    now = datetime.now(UTC)
    return json.dumps(
        {
            "contract_version": 1,
            "principal": {
                "actor_type": "user",
                "subject": f"arch-v2-{surface}-subject",
                "issuer": "https://identity.example.test",
                "app": "tpl",
                "surface": surface,
                "audience": f"tpl-{surface}-r2",
                "actor_id": "b42cf3bb-d63e-5df5-a884-9c34286f2608",
                "display_name": "Paired E2E User",
                "email": f"{surface}@example.test",
                "roles": list(roles),
                "scopes": ["tpl:admin"] if surface == "admin" else [],
                "authenticated_at": now.isoformat(),
                "expires_at": (now + timedelta(hours=1)).isoformat(),
                "policy_version": f"tpl-{surface}-v2",
            },
            "csrf_token": "csrf-token-value-that-is-long-enough-1234",
        },
        separators=(",", ":"),
    )


def seed_session(key: str, value: str) -> None:
    result = docker(
        "exec",
        REDIS,
        "redis-cli",
        "SET",
        key,
        value,
        "EX",
        "3600",
        capture=True,
    )
    if result.stdout.strip() != "OK":
        raise GateError("failed to seed an opaque browser session")


def image_user(image: str) -> str:
    return docker(
        "image", "inspect", image, "--format", "{{.Config.User}}", capture=True
    ).stdout.strip()


def assert_runtime_has_no_proxy(image: str) -> None:
    payload = docker(
        "image", "inspect", image, "--format", "{{json .Config.Env}}", capture=True
    ).stdout
    values = json.loads(payload)
    forbidden = (
        "HTTP_PROXY=",
        "HTTPS_PROXY=",
        "http_proxy=",
        "https_proxy=",
    )
    if any(item.startswith(forbidden) for item in values):
        raise GateError(f"build proxy leaked into runtime image {image}")


def start_gateway(directory: Path, port: int, next_port: int) -> subprocess.Popen[str]:
    env = os.environ.copy()
    env.update(
        {
            "PAIR_GATEWAY_PORT": str(port),
            "NEXT_UPSTREAM_PORT": str(next_port),
            "PAIR_FIXTURE_PORT": str(BACKEND_PORT),
        }
    )
    return subprocess.Popen(
        ["node", "scripts/pair-gateway.mjs"],
        cwd=directory,
        env=env,
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def run_playwright(directory: Path, base_url: str) -> None:
    env = os.environ.copy()
    env["PLAYWRIGHT_BASE_URL"] = base_url
    run("pnpm", "exec", "playwright", "test", cwd=directory, env=env)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--backend-image", default="tpl-backend:arch-v2-r2-20260801"
    )
    parser.add_argument(
        "--admin-image", default="tpl-admin-frontend:arch-v2-r2-20260801"
    )
    parser.add_argument(
        "--web-image", default="tpl-web-frontend:arch-v2-r2-20260801"
    )
    args = parser.parse_args()
    gateways: list[subprocess.Popen[str]] = []

    def stop(_signum=None, _frame=None):
        cleanup(gateways)
        raise KeyboardInterrupt

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    cleanup(gateways)

    try:
        if image_user(args.backend_image) != "appuser":
            raise GateError("Backend runtime image must use appuser")
        if image_user(args.admin_image) != "nextjs":
            raise GateError("Admin runtime image must use nextjs")
        if image_user(args.web_image) != "nextjs":
            raise GateError("Web runtime image must use nextjs")
        assert_runtime_has_no_proxy(args.backend_image)
        assert_runtime_has_no_proxy(args.admin_image)
        assert_runtime_has_no_proxy(args.web_image)

        docker("network", "create", NETWORK)
        docker(
            "run",
            "-d",
            "--name",
            POSTGRES,
            "--network",
            NETWORK,
            "-e",
            "POSTGRESQL_USERNAME=tpl_r2",
            "-e",
            f"POSTGRESQL_PASSWORD={DB_PASSWORD}",
            "-e",
            "POSTGRESQL_DATABASE=tpl_r2",
            "bitnami/postgresql:17.6.0-debian-12-r4",
        )
        docker(
            "run",
            "-d",
            "--name",
            REDIS,
            "--network",
            NETWORK,
            "-e",
            "ALLOW_EMPTY_PASSWORD=yes",
            "bitnami/redis:8.2.1-debian-12-r0",
        )

        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            postgres_ready = subprocess.run(
                [
                    "docker",
                    "exec",
                    "-e",
                    f"PGPASSWORD={DB_PASSWORD}",
                    POSTGRES,
                    "pg_isready",
                    "-U",
                    "tpl_r2",
                    "-d",
                    "tpl_r2",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            ).returncode == 0
            redis_ready = subprocess.run(
                ["docker", "exec", REDIS, "redis-cli", "PING"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            ).returncode == 0
            if postgres_ready and redis_ready:
                break
            time.sleep(0.5)
        else:
            raise GateError("ephemeral PostgreSQL/Redis did not become ready")

        docker(
            "run",
            "--rm",
            "--network",
            NETWORK,
            "-e",
            f"DATABASE_URL={DB_URL}",
            "-e",
            f"MIGRATION_DATABASE_URL={DB_URL}",
            "--entrypoint",
            "python",
            args.backend_image,
            "-m",
            "app.bootstrap.migration",
            "upgrade",
            "head",
        )

        docker(
            "run",
            "--rm",
            "--network",
            NETWORK,
            "-e",
            "ENV=test",
            "-e",
            f"DATABASE_URL={DB_URL}",
            args.backend_image,
            "python",
            "-c",
            OUTBOX_PROGRAM,
        )

        docker(
            "run",
            "--rm",
            "--network",
            NETWORK,
            "-e",
            f"DATABASE_URL={DB_URL}",
            "-e",
            f"MIGRATION_DATABASE_URL={DB_URL}",
            "--entrypoint",
            "alembic",
            args.backend_image,
            "-c",
            "/app/alembic.ini",
            "downgrade",
            "base",
        )
        docker(
            "run",
            "--rm",
            "--network",
            NETWORK,
            "-e",
            f"DATABASE_URL={DB_URL}",
            "-e",
            f"MIGRATION_DATABASE_URL={DB_URL}",
            "--entrypoint",
            "python",
            args.backend_image,
            "-m",
            "app.bootstrap.migration",
            "upgrade",
            "head",
        )
        migration_head = docker(
            "exec",
            "-e",
            f"PGPASSWORD={DB_PASSWORD}",
            POSTGRES,
            "psql",
            "-U",
            "tpl_r2",
            "-d",
            "tpl_r2",
            "-Atc",
            "SELECT version_num FROM alembic_version",
            capture=True,
        ).stdout.strip()
        if migration_head != "20260801_0002":
            raise GateError(
                f"migration roundtrip ended at {migration_head!r}, expected head"
            )

        worker_without_broker = subprocess.run(
            [
                "docker",
                "run",
                "--rm",
                args.backend_image,
                "python",
                "-c",
                "import app.bootstrap.worker",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if worker_without_broker.returncode == 0:
            raise GateError("Worker bootstrap accepted a missing broker")
        for module in ("app.bootstrap.worker", "app.bootstrap.scheduler"):
            docker(
                "run",
                "--rm",
                "--network",
                NETWORK,
                "-e",
                f"CELERY_BROKER_URL=redis://{REDIS}:6379/0",
                args.backend_image,
                "python",
                "-c",
                f"import {module}",
            )

        docker(
            "run",
            "-d",
            "--name",
            BACKEND,
            "--network",
            NETWORK,
            "-p",
            f"{BACKEND_PORT}:8000",
            "-e",
            f"DATABASE_URL={DB_URL}",
            "-e",
            "REDIS_HOST=" + REDIS,
            "-e",
            "ADMIN_CASDOOR_CLIENT_ID=tpl-admin-r2",
            "-e",
            "WEB_CASDOOR_CLIENT_ID=tpl-web-r2",
            "-e",
            f"ADMIN_FRONTEND_BASE_URL=http://127.0.0.1:{ADMIN_GATEWAY_PORT}",
            "-e",
            f"ADMIN_FRONTEND_ALLOWED_ORIGINS=http://127.0.0.1:{ADMIN_GATEWAY_PORT}",
            "-e",
            f"WEB_FRONTEND_BASE_URL=http://127.0.0.1:{WEB_GATEWAY_PORT}",
            "-e",
            f"WEB_FRONTEND_ALLOWED_ORIGINS=http://127.0.0.1:{WEB_GATEWAY_PORT}",
            "-e",
            "ALLOWED_HOSTS=127.0.0.1,localhost,arch-v2-r2-backend",
            "-e",
            "REFERENCE_INTERACTION_ENABLED=true",
            "-e",
            "DEPLOYMENT_ID=arch-v2-r2-backend",
            args.backend_image,
        )
        wait_http(f"http://127.0.0.1:{BACKEND_PORT}/health/ready")

        seed_session(
            "tpl:auth:admin:session:e2e-session",
            session("admin", roles=("admin",)),
        )
        seed_session(
            "tpl:auth:admin:session:operator-session",
            session("admin", roles=("operator",)),
        )
        seed_session(
            "tpl:auth:web:session:e2e-session",
            session("web", roles=("member",)),
        )

        base = f"http://127.0.0.1:{BACKEND_PORT}"
        for surface in ("admin", "web"):
            body = expect_status(f"{base}/api/auth/{surface}/me", 401)
            error = json.loads(body)["error"]
            if error["code"] != "auth_required":
                raise GateError("anonymous error envelope is not stable")

        admin_cookie = {"Cookie": "sunmoonai_tpl_admin_sid=e2e-session"}
        web_cookie = {"Cookie": "sunmoonai_tpl_web_sid=e2e-session"}
        admin_payload = json.loads(
            expect_status(f"{base}/api/auth/admin/me", 200, headers=admin_cookie)
        )
        web_payload = json.loads(
            expect_status(f"{base}/api/auth/web/me", 200, headers=web_cookie)
        )
        if admin_payload["user"]["surface"] != "admin":
            raise GateError("Admin session surface mismatch")
        if web_payload["user"]["surface"] != "web":
            raise GateError("Web session surface mismatch")
        expect_status(
            f"{base}/api/auth/web/me",
            401,
            headers={"Cookie": "sunmoonai_tpl_web_sid=operator-session"},
        )

        expect_status(
            f"{base}/api/admin/v1/diagnostics/tasks/ping",
            403,
            method="POST",
            headers=admin_cookie,
        )
        expect_status(
            f"{base}/api/admin/v1/diagnostics/tasks/ping",
            503,
            method="POST",
            headers={
                **admin_cookie,
                "Origin": f"http://127.0.0.1:{ADMIN_GATEWAY_PORT}",
                "X-CSRF-Token": "csrf-token-value-that-is-long-enough-1234",
            },
        )

        run_id = "00000000-0000-5000-8000-000000000001"
        snapshot = json.loads(
            expect_status(f"{base}/api/web/v1/runs/{run_id}", 200, headers=web_cookie)
        )
        if snapshot["run_id"] != run_id:
            raise GateError("real Backend Web interaction contract mismatch")
        expect_status(
            f"{base}/api/web/v1/runs/{run_id}", 401, headers=admin_cookie
        )

        docker(
            "run",
            "-d",
            "--name",
            ADMIN,
            "--network",
            NETWORK,
            "-p",
            f"{ADMIN_NEXT_PORT}:3000",
            "-e",
            "DEPLOYMENT_ENV=test",
            "-e",
            "AUTH_APP=tpl",
            "-e",
            f"APP_ORIGIN=http://127.0.0.1:{ADMIN_GATEWAY_PORT}",
            "-e",
            f"BACKEND_INTERNAL_URL=http://{BACKEND}:8000",
            "-e",
            "DEPLOYMENT_ID=arch-v2-r2-admin-e2e",
            args.admin_image,
        )
        docker(
            "run",
            "-d",
            "--name",
            WEB,
            "--network",
            NETWORK,
            "-p",
            f"{WEB_NEXT_PORT}:3000",
            "-e",
            "DEPLOYMENT_ENV=test",
            "-e",
            "AUTH_APP=tpl",
            "-e",
            f"APP_ORIGIN=http://127.0.0.1:{WEB_GATEWAY_PORT}",
            "-e",
            f"BACKEND_INTERNAL_URL=http://{BACKEND}:8000",
            "-e",
            "DEPLOYMENT_ID=arch-v2-r2-web-e2e",
            "-e",
            "REFERENCE_UI_ENABLED=true",
            args.web_image,
        )
        wait_http(f"http://127.0.0.1:{ADMIN_NEXT_PORT}/healthz")
        wait_http(f"http://127.0.0.1:{WEB_NEXT_PORT}/en")

        gateways.extend(
            (
                start_gateway(ADMIN_DIR, ADMIN_GATEWAY_PORT, ADMIN_NEXT_PORT),
                start_gateway(WEB_DIR, WEB_GATEWAY_PORT, WEB_NEXT_PORT),
            )
        )
        wait_http(f"http://127.0.0.1:{ADMIN_GATEWAY_PORT}/__gateway_health")
        wait_http(f"http://127.0.0.1:{WEB_GATEWAY_PORT}/__gateway_health")
        run_playwright(ADMIN_DIR, f"http://127.0.0.1:{ADMIN_GATEWAY_PORT}")
        run_playwright(WEB_DIR, f"http://127.0.0.1:{WEB_GATEWAY_PORT}")

        result = {
            "task": "architecture-v2-r2-template-pair",
            "result": "passed",
            "backend_role": "api",
            "migration_head": migration_head,
            "migration_roundtrip": "passed",
            "outbox_and_inbox": "passed",
            "worker_and_scheduler_bootstrap": "passed",
            "admin_playwright": "10/10",
            "web_playwright": "6/6",
            "surface_isolation": True,
            "csrf_fail_closed": True,
            "runtime_non_root": True,
            "build_proxy_in_runtime": False,
            "credentials_printed": False,
        }
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (GateError, subprocess.CalledProcessError) as exc:
        print(
            json.dumps(
                {
                    "task": "architecture-v2-r2-template-pair",
                    "result": "failed",
                    "error": str(exc),
                },
                ensure_ascii=False,
                indent=2,
            ),
            file=sys.stderr,
        )
        return 1
    finally:
        cleanup(gateways)


if __name__ == "__main__":
    raise SystemExit(main())
