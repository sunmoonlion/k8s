#!/usr/bin/env python3
"""Verify the five template frontend/backend pairs and accepted Admin evidence."""

from __future__ import annotations

import json
from pathlib import Path


EXPECTED = {
    "next-admin-fastapi-admin": {
        "frontend": "tpl-admin-frontend",
        "backend": "tpl-admin-backend",
        "release_class": "DEFAULT",
        "status": "ACCEPTED",
        "gate": "V5-P0-007E",
    },
    "react-router-admin-fastapi-admin": {
        "frontend": "tpl-admin-frontend-react",
        "backend": "tpl-admin-backend",
        "release_class": "REFERENCE_ONLY",
        "status": "ACCEPTED",
        "gate": "V5-P0-007D",
    },
    "vue-admin-fastapi-admin": {
        "frontend": "tpl-admin-frontend-vue",
        "backend": "tpl-admin-backend",
        "release_class": "REFERENCE_ONLY",
        "status": "ACCEPTED",
        "gate": "V5-P0-008B-B6.2",
    },
    "next-web-fastapi-web": {
        "frontend": "tpl-web-frontend",
        "backend": "tpl-web-backend",
        "release_class": "DEFAULT",
        "status": "IN_PROGRESS",
        "gate": "V5-P0-008B-B6.3",
    },
    "next-web-nest-web": {
        "frontend": "tpl-web-frontend",
        "backend": "tpl-web-backend-nest",
        "release_class": "OPTIONAL",
        "status": "REVALIDATION_REQUIRED",
        "gate": "V5-P0-008B-B6.3",
    },
}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def assert_pair_matrix(tpl: Path) -> None:
    matrix = load_json(tpl / "frontend-pairing-matrix.json")
    if matrix.get("contract_version") != 1:
        raise AssertionError("frontend pairing contract must remain at version 1")
    pairs = matrix.get("pairs")
    if not isinstance(pairs, list) or len(pairs) != len(EXPECTED):
        raise AssertionError("frontend pairing matrix must contain exactly five pairs")
    actual = {item["id"]: item for item in pairs}
    if set(actual) != set(EXPECTED):
        raise AssertionError(
            f"frontend pairing ids drifted: {sorted(set(actual) ^ set(EXPECTED))}"
        )
    for pair_id, expected in EXPECTED.items():
        for key, value in expected.items():
            if actual[pair_id].get(key) != value:
                raise AssertionError(
                    f"{pair_id}.{key} expected {value!r}, got "
                    f"{actual[pair_id].get(key)!r}"
                )
        for repo_key in ("frontend", "backend"):
            if not (tpl / actual[pair_id][repo_key]).exists():
                raise AssertionError(
                    f"{pair_id} references missing repo "
                    f"{actual[pair_id][repo_key]}"
                )


def assert_accepted_admin_evidence(k8s: Path) -> None:
    evidence = k8s / "sunmoonai" / "docs" / "evidence" / "v5"
    react_pair = load_json(evidence / "V5-P0-007D" / "browser-pair.json")
    react_rollout = load_json(evidence / "V5-P0-007D" / "rollout.json")
    next_pair = load_json(evidence / "V5-P0-007E" / "browser-pair.json")
    vue_pair = load_json(evidence / "V5-P0-008B" / "B6" / "vue-pair.json")
    vue_rollout = load_json(
        evidence / "V5-P0-008B" / "B6" / "vue-rollback.json"
    )

    for name, result in (
        ("React Router Admin pair", react_pair),
        ("React Router Admin rollout", react_rollout),
        ("Next Admin pair", next_pair),
        ("Vue Admin pair", vue_pair),
        ("Vue Admin rollback", vue_rollout),
    ):
        if result.get("result") != "passed":
            raise AssertionError(f"{name} evidence is not passed")

    if react_pair.get("contract_version") != 1:
        raise AssertionError("React Router Admin pair contract drifted")
    if react_pair.get("anonymous") != 401 or react_pair.get("authenticated") != 200:
        raise AssertionError("React Router Admin identity pair evidence is incomplete")
    if react_pair.get("invalid_csrf") != 403 or react_pair.get("logout") != 204:
        raise AssertionError("React Router Admin mutation evidence is incomplete")
    if not react_rollout.get("unaffected_deployments_unchanged"):
        raise AssertionError("React Router Admin rollout changed unrelated Deployments")
    if react_rollout.get("rollback_continuity", {}).get("probes", 0) < 1:
        raise AssertionError("React Router Admin rollback continuity is absent")
    if react_rollout.get("forward_continuity", {}).get("probes", 0) < 1:
        raise AssertionError("React Router Admin forward continuity is absent")


def main() -> None:
    home = Path.home()
    tpl = home / "tpl-app"
    k8s = home / "k8s"
    assert_pair_matrix(tpl)
    assert_accepted_admin_evidence(k8s)
    print(
        json.dumps(
            {
                "task": "V5-P0-008B-B6-template-pairing-matrix",
                "result": "passed",
                "pair_count": len(EXPECTED),
                "accepted_admin_pairs": [
                    "next-admin-fastapi-admin",
                    "react-router-admin-fastapi-admin",
                    "vue-admin-fastapi-admin",
                ],
                "web_pairs_pending_b6_3": [
                    "next-web-fastapi-web",
                    "next-web-nest-web",
                ],
                "react_router_pair_evidence": "V5-P0-007D",
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
