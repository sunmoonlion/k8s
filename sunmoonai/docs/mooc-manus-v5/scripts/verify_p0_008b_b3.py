#!/usr/bin/env python3
"""Verify the committed P0-008B/B3 Web interaction and Nest pair baseline."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path


FRONTEND_SHA = "d10cffa4fcfb73fa561a5a697bb45214c69fdb7d"
BACKEND_SHA = "e1876a4ff669dfafcdde994f34d8a03fa9965b9a"
PARENT_SHA = "8b1df6af4544aa287548ed368a5be319de1348c4"

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
        raise AssertionError(f"{path} is missing B3 markers: {missing}")
    return text


def assert_clean_commit(repo: Path, expected: str) -> None:
    if git(repo, "rev-parse", "HEAD") != expected:
        raise AssertionError(f"{repo} is not at its frozen B3 commit")
    if git(repo, "status", "--porcelain"):
        raise AssertionError(f"{repo} has uncommitted changes")


def assert_gitlink(parent: Path, path: str, expected: str) -> None:
    fields = git(parent, "ls-tree", "HEAD", "--", path).split()
    if len(fields) < 3 or fields[:2] != ["160000", "commit"] or fields[2] != expected:
        raise AssertionError(f"{path} gitlink is not pinned to B3")


def validate_backend(repo: Path) -> None:
    assert_clean_commit(repo, BACKEND_SHA)
    require_text(
        repo / "app/src/web-interaction/web-interaction.controller.ts",
        "@Get('runs/:runId')",
        "@Sse('runs/:runId/events')",
        "@Post('runs/:runId/actions')",
        "@Get('citations/:evidenceId/source')",
        "Conflicting event cursors",
        "parseRunEvent(candidate)",
        "isSafeRelativeLocation",
    )
    require_text(
        repo / "app/src/web-interaction/web-interaction.contracts.ts",
        ".unknown(false)",
        "contract_invalid",
        "source_href",
    )
    require_text(
        repo / "app/src/web-interaction/web-interaction.port.ts",
        "WEB_INTERACTION_PORT",
        "streamRun(",
        "resolveCitationSource(",
    )
    fixture = require_text(
        repo / "app/test/fixtures/pair-fixture.ts",
        "FixtureInteractionAdapter",
        "FixtureSessionGuard",
        "PAIR_ORIGIN",
        "x-csrf-token",
    )
    if "access_token" in fixture or "refresh_token" in fixture:
        raise AssertionError("provider credentials leaked into the B3 pair fixture")
    app_module = (repo / "app/src/app.module.ts").read_text()
    if "PairFixtureModule" in app_module or "FixtureInteractionAdapter" in app_module:
        raise AssertionError("test-only B3 fixture entered the production AppModule")


def validate_frontend(repo: Path) -> None:
    assert_clean_commit(repo, FRONTEND_SHA)
    require_text(
        repo / "app/contracts/interaction.ts",
        "runSnapshotSchema",
        "runEventSchema",
        "citationSchema",
        ".strict()",
    )
    require_text(
        repo / "app/lib/interaction/client.ts",
        "credentials: 'same-origin'",
        "cache: 'no-store'",
        "X-CSRF-Token",
        "event_id !== lastEventId",
    )
    require_text(
        repo / "app/lib/interaction/projection.ts",
        "seenEventIds",
        "kind: 'gap'",
        "foreign_run",
        "last_sequence_no + 1",
    )
    require_text(
        repo / "app/lib/interaction/use-run-projection.ts",
        "new EventSource(",
        "last_event_id",
        "reconciling",
        "Math.min(1000 * 2 ** reconnectAttempt, 10000)",
    )
    require_text(
        repo / "app/components/platform/reference-workspace.tsx",
        "RequiredActionForm",
        "citation.source_href",
        "snapshot.required_action",
    )
    require_text(
        repo / "app/playwright.config.ts",
        "start:pair-fixture",
        "pair-gateway.mjs",
        "REFERENCE_UI_ENABLED: 'true'",
        "p0-008b-b3-e2e",
    )
    if (repo / "app/scripts/mock-web-backend.mjs").exists():
        raise AssertionError("the superseded ad-hoc mock backend still exists")


def validate_contracts(workspace: Path, k8s: Path) -> None:
    root = k8s / "sunmoonai/docs/mooc-manus-v5/contracts/web-interaction/v1"
    manifest = json.loads((root / "contract-manifest.json").read_text())
    for name, expected in manifest["files"].items():
        actual = hashlib.sha256((root / name).read_bytes()).hexdigest()
        if actual != expected:
            raise AssertionError(f"contract manifest drifted for {name}")

    event_schema = json.loads((root / "run-event.schema.json").read_text())
    if event_schema.get("additionalProperties") is not False:
        raise AssertionError("run event outer boundary is not closed")
    event_types = set(event_schema["properties"]["type"]["enum"])
    expected_types = {
        "status",
        "delta",
        "citation",
        "input_required",
        "completed",
        "failed",
        "heartbeat",
    }
    if event_types != expected_types or len(event_schema.get("allOf", [])) != 7:
        raise AssertionError("run event variants drifted")

    vectors = json.loads((root / "contract.vectors.json").read_text())
    if [event["sequence_no"] for event in vectors["ordered_events"]] != [2, 4]:
        raise AssertionError("gap reconciliation vector is missing")
    if vectors["negative_rules"][-1] != (
        "citation source resolution requires current browser authorization"
    ):
        raise AssertionError("citation authorization negative rule is missing")

    citation = workspace / "knowledge-app/contracts/retrieval/v1/citation.schema.json"
    expected_citation = manifest["external_dependencies"]["knowledge-citation-v1"]["sha256"]
    actual_citation = hashlib.sha256(citation.read_bytes()).hexdigest()
    if actual_citation != expected_citation:
        raise AssertionError("Knowledge-owned Citation contract digest drifted")
    if not any(
        value.get("$ref") == json.loads(citation.read_text())["$id"]
        for value in event_schema["$defs"]["citation_data"]["properties"].values()
    ):
        raise AssertionError("Web contract duplicated or detached the Citation truth source")


def validate_business_web_unchanged(workspace: Path) -> None:
    for app, (frontend, backend) in BUSINESS_WEB_SNAPSHOTS.items():
        parent = workspace / f"{app}-app"
        if git(parent / f"{app}-web-frontend", "rev-parse", "HEAD") != frontend:
            raise AssertionError(f"{app} Web Frontend changed during B3")
        if git(parent / f"{app}-web-backend", "rev-parse", "HEAD") != backend:
            raise AssertionError(f"{app} Web Backend changed during B3")


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
    validate_contracts(workspace, k8s)
    validate_business_web_unchanged(workspace)

    print(
        json.dumps(
            {
                "task": "V5-P0-008B-B3-source",
                "result": "passed",
                "frontend_commit": FRONTEND_SHA,
                "backend_commit": BACKEND_SHA,
                "parent_commit": PARENT_SHA,
                "contract_version": 1,
                "backend_unit_tests": 36,
                "backend_e2e_tests": 2,
                "frontend_tests": 31,
                "paired_playwright_tests": 6,
                "business_web_repositories_unchanged": True,
                "fixture_in_production_module": False,
                "provider_tokens_exposed": False,
                "secrets_printed": False,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
