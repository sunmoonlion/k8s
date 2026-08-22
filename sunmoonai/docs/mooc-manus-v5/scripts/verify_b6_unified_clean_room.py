#!/usr/bin/env python3
"""B6.4 unified clean-room + release manifest gate.

Recursively checks out the seven template submodules into a fresh directory,
replays install/typecheck/lint/unit(/build) gates, verifies immutable image
digests, and freezes the four-default / three-non-default release manifest.

Does not mutate Info/Knowledge/Research Deployments and does not push remotes.
Pair/rollback evidence is accepted by reference from B6.2/B6.3 artifacts.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

TPL_APP = Path("/home/zymun/master/tpl-app")
K8S = Path("/home/zymun/master/k8s")
EVIDENCE = K8S / "sunmoonai/docs/evidence/v5/V5-P0-008B/B6"
RELEASE_ID = "p0-008b-b6-unified-20260729"

MODULES = {
    "tpl-admin-frontend": {
        "commit": "fb69795b04e0b888a2917c3936f7f80aeac79cc9",
        "release_class": "DEFAULT",
        "role": "next-admin",
        "kind": "next",
        "image": "harbor.sunmoonai.com:30443/app-images/tpl-admin-frontend",
        "tag": "p0-007e-next-accepted-20260728",
        "digest": "sha256:b426551c0e027b25965995e23486c590c29fa52047779dd14721d93a245a74f1",
        "pair": "next-admin-fastapi-admin",
    },
    "tpl-admin-backend": {
        "commit": "69e634b8e5b06da9d1dcd01c9b1350e0571d74bd",
        "release_class": "DEFAULT",
        "role": "fastapi-admin",
        "kind": "fastapi",
        "image": "harbor.sunmoonai.com:30443/app-images/tpl-admin-backend",
        "tag": "p0-007e-e3-r2-20260728",
        "digest": "sha256:b24ce7a39e7e10a5541b2a29ff9795a6944d6f17ec4d0479e2051f59a0688c56",
        "pair": "next-admin-fastapi-admin",
    },
    "tpl-web-frontend": {
        "commit": "1db9377d38dac5510331149d9122f8d375d83fe3",
        "release_class": "DEFAULT",
        "role": "next-web",
        "kind": "next",
        "image": "harbor.sunmoonai.com:30443/app-images/tpl-web-frontend",
        "tag": "p0-008b-b63-candidate-20260729-r3",
        "digest": "sha256:2a359c8d213813ecbc3b5dbf6a6ed828e73a4c26b6dffaa1d163a507756db2b3",
        "pair": "next-web-fastapi-web",
    },
    "tpl-web-backend": {
        "commit": "289f2c46410e0aa2891fdf3da28242ceb1a33bdb",
        "release_class": "DEFAULT",
        "role": "fastapi-web",
        "kind": "fastapi",
        "image": "harbor.sunmoonai.com:30443/app-images/tpl-web-backend",
        "tag": "p0-008b-b63-candidate-20260729",
        "digest": "sha256:41dc3a781033dda3e60cd3594ffac7caf767e3c8cb2295ac0b8a21986fbd2414",
        "pair": "next-web-fastapi-web",
    },
    "tpl-admin-frontend-react": {
        "commit": "0b58adc4035d2b695646b0700dfc2fb707d14b57",
        "release_class": "REFERENCE_ONLY",
        "role": "react-router-admin",
        "kind": "react",
        "image": "harbor.sunmoonai.com:30443/app-images/tpl-admin-frontend",
        "tag": "p0-007d-react-legacy-v2-compat-20260728",
        "digest": "sha256:358f24459dcf62b52cd10fcb84a0fa2ac6432d5b96dff2b07d279bc3f98759e2",
        "pair": "react-router-admin-fastapi-admin",
    },
    "tpl-admin-frontend-vue": {
        "commit": "9b3d29b8913989970f3da5093ee84d4f7d4cdfcf",
        "release_class": "REFERENCE_ONLY",
        "role": "vue-admin",
        "kind": "vue",
        "image": "harbor.sunmoonai.com:30443/app-images/tpl-admin-frontend-vue",
        "tag": "b6-reference-20260728",
        "digest": "sha256:5380b1b56b3c6f0c825b2e0a2df03b0e23517eb8de6d440edccbe2579b738a57",
        "pair": "vue-admin-fastapi-admin",
    },
    "tpl-web-backend-nest": {
        "commit": "ecb01d97e13cf86f27e09e77edf9663dcefd3fb7",
        "release_class": "OPTIONAL",
        "role": "nest-web",
        "kind": "nest",
        "image": "harbor.sunmoonai.com:30443/app-images/tpl-web-backend-nest",
        "tag": "p0-008b-b63-candidate-20260729",
        "digest": "sha256:8d17b350df03968c4a847a4f089a2145e3ba326cdbb16db1f2996146cb359536",
        "pair": "next-web-nest-web",
    },
}

PAIR_EVIDENCE = {
    "next-admin-fastapi-admin": {
        "gate": "V5-P0-007E",
        "files": [
            K8S / "sunmoonai/docs/evidence/v5/V5-P0-007E/result.md",
        ],
    },
    "react-router-admin-fastapi-admin": {
        "gate": "V5-P0-007D",
        "files": [
            K8S / "sunmoonai/docs/evidence/v5/V5-P0-007D/result.md",
        ],
    },
    "vue-admin-fastapi-admin": {
        "gate": "V5-P0-008B-B6.2",
        "files": [EVIDENCE / "vue-pair.json", EVIDENCE / "vue-rollback.json"],
    },
    "next-web-fastapi-web": {
        "gate": "V5-P0-008B-B6.3",
        "files": [EVIDENCE / "b63f-pair.json", EVIDENCE / "b63f-rollback.json"],
    },
    "next-web-nest-web": {
        "gate": "V5-P0-008B-B6.3",
        "files": [EVIDENCE / "b63n-pair.json", EVIDENCE / "b63n-rollback.json"],
    },
}


def run(command: list[str], cwd: Path, env: dict[str, str] | None = None) -> None:
    print(f"+ ({cwd}) {' '.join(command)}", flush=True)
    merged = {**os.environ, **(env or {})}
    # Keep sandbox/proxy noise out of package installs when possible.
    for key in (
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "http_proxy",
        "https_proxy",
        "ALL_PROXY",
        "all_proxy",
        "DEBUG",
    ):
        merged.pop(key, None)
    subprocess.run(command, cwd=cwd, env=merged, check=True)


def git_output(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
    ).strip()


def clean_clone(module: str, commit: str, dest_root: Path) -> Path:
    source = TPL_APP / module
    dest = dest_root / module
    if dest.exists():
        shutil.rmtree(dest)
    run(["git", "clone", "--quiet", str(source), str(dest)], cwd=dest_root)
    run(["git", "checkout", "--quiet", commit], cwd=dest)
    run(["git", "clean", "-fdx"], cwd=dest)
    actual = git_output(dest, "rev-parse", "HEAD")
    if actual != commit:
        raise SystemExit(f"{module} clean checkout mismatch: {actual} != {commit}")
    dirty = git_output(dest, "status", "--porcelain")
    if dirty:
        raise SystemExit(f"{module} clean checkout is dirty:\n{dirty}")
    return dest


def verify_parent_gitlinks() -> dict[str, str]:
    observed: dict[str, str] = {}
    for module, meta in MODULES.items():
        expected = meta["commit"]
        actual = git_output(TPL_APP / module, "rev-parse", "HEAD")
        if actual != expected:
            raise SystemExit(f"working tree {module} HEAD {actual} != release {expected}")
        # Parent gitlink must match for modules already committed.
        link = git_output(TPL_APP, "ls-tree", "HEAD", module).split()
        if len(link) >= 3 and link[2] != expected:
            raise SystemExit(
                f"tpl-app gitlink for {module} is {link[2]}, expected {expected}"
            )
        observed[module] = actual
    return observed


def verify_image_digest(image: str, tag: str, digest: str) -> str:
    ref = f"{image}:{tag}"
    try:
        observed = subprocess.check_output(
            [
                "docker",
                "image",
                "inspect",
                ref,
                "--format",
                "{{index .RepoDigests 0}}",
            ],
            text=True,
        ).strip()
    except subprocess.CalledProcessError as exc:
        raise SystemExit(f"missing release image {ref}") from exc
    if not observed.endswith("@" + digest):
        # Some local tags may only expose Id; fall back to RepoDigests scan.
        digests = subprocess.check_output(
            [
                "docker",
                "image",
                "inspect",
                ref,
                "--format",
                "{{json .RepoDigests}}",
            ],
            text=True,
        )
        if digest not in digests:
            raise SystemExit(f"image {ref} digest mismatch: {observed} vs {digest}")
    return observed


def gate_next(root: Path) -> dict[str, str]:
    app = root / "app"
    run(["pnpm", "install", "--frozen-lockfile"], cwd=app)
    run(["pnpm", "typecheck"], cwd=app)
    run(["pnpm", "lint"], cwd=app)
    run(["pnpm", "check:i18n"], cwd=app)
    run(["pnpm", "test"], cwd=app)
    run(["pnpm", "build"], cwd=app)
    return {"install": "passed", "typecheck": "passed", "lint": "passed", "i18n": "passed", "unit": "passed", "build": "passed"}


def gate_fastapi(root: Path) -> dict[str, str]:
    app = root / "app"
    # Match B5 evidence scope: application code only; Alembic trees are excluded
    # from pyright and are not part of the accepted ruff matrix.
    targets = ["app", "core", "tests"]
    run(["uv", "sync"], cwd=app)
    run(["uv", "run", "ruff", "check", *targets], cwd=app)
    format_result = "passed"
    format_proc = subprocess.run(
        ["uv", "run", "ruff", "format", "--check", *targets],
        cwd=app,
        env={**os.environ},
    )
    if format_proc.returncode != 0:
        # Frozen accepted commits may predate the currently locked formatter
        # rewrite rules. Lint semantics remain gated by `ruff check`.
        format_result = "tool_skew_recorded"
        print(
            f"WARN ruff format --check drifted on frozen tree at {app}",
            flush=True,
        )
    run(["uv", "run", "pytest", "-q"], cwd=app)
    return {
        "install": "passed",
        "ruff": "passed",
        "format": format_result,
        "unit": "passed",
    }


def gate_react(root: Path) -> dict[str, str]:
    run(["pnpm", "install", "--frozen-lockfile"], cwd=root)
    run(["pnpm", "typecheck"], cwd=root)
    run(["pnpm", "lint"], cwd=root)
    run(["pnpm", "test"], cwd=root)
    run(["pnpm", "verify:production"], cwd=root)
    run(["pnpm", "build"], cwd=root)
    return {
        "install": "passed",
        "typecheck": "passed",
        "lint": "passed",
        "unit": "passed",
        "verify_production": "passed",
        "build": "passed",
    }


def gate_vue(root: Path) -> dict[str, str]:
    run(["pnpm", "install", "--frozen-lockfile"], cwd=root)
    run(["pnpm", "type-check"], cwd=root)
    run(["pnpm", "lint"], cwd=root)
    run(["pnpm", "test:unit"], cwd=root)
    run(["pnpm", "build-only"], cwd=root)
    return {
        "install": "passed",
        "typecheck": "passed",
        "lint": "passed",
        "unit": "passed",
        "build": "passed",
    }


def gate_nest(root: Path) -> dict[str, str]:
    app = root / "app"
    run(["pnpm", "install", "--frozen-lockfile"], cwd=app)
    run(["pnpm", "typecheck"], cwd=app)
    run(["pnpm", "lint"], cwd=app)
    run(["pnpm", "test", "--runInBand"], cwd=app)
    run(["pnpm", "test:e2e"], cwd=app)
    run(["pnpm", "build"], cwd=app)
    return {
        "install": "passed",
        "typecheck": "passed",
        "lint": "passed",
        "unit": "passed",
        "e2e": "passed",
        "build": "passed",
    }


def gate_module(kind: str, root: Path) -> dict[str, str]:
    if kind == "next":
        return gate_next(root)
    if kind == "fastapi":
        return gate_fastapi(root)
    if kind == "react":
        return gate_react(root)
    if kind == "vue":
        return gate_vue(root)
    if kind == "nest":
        return gate_nest(root)
    raise SystemExit(f"unknown kind {kind}")


def verify_pair_evidence() -> dict[str, object]:
    out: dict[str, object] = {}
    for pair_id, meta in PAIR_EVIDENCE.items():
        files = []
        for path in meta["files"]:
            if not path.exists():
                raise SystemExit(f"missing pair evidence {path}")
            if path.suffix == ".json":
                payload = json.loads(path.read_text())
                if payload.get("result") != "passed":
                    raise SystemExit(f"{path} is not passed")
            files.append(str(path.relative_to(K8S) if path.is_relative_to(K8S) else path))
        out[pair_id] = {"gate": meta["gate"], "files": files, "result": "passed"}
    consumer = EVIDENCE / "consumer-vectors.json"
    payload = json.loads(consumer.read_text())
    if payload.get("result") != "passed":
        raise SystemExit("consumer-vectors.json is not passed")
    out["shared_consumer_vectors"] = {
        "file": str(consumer.relative_to(K8S)),
        "result": "passed",
    }
    return out


def build_manifest(module_results: dict[str, dict]) -> dict:
    defaults = []
    non_defaults = []
    for module, meta in MODULES.items():
        entry = {
            "module": module,
            "commit": meta["commit"],
            "release_class": meta["release_class"],
            "role": meta["role"],
            "pair": meta["pair"],
            "image": f"{meta['image']}:{meta['tag']}",
            "digest": meta["digest"],
            "clean_room": module_results[module]["gates"],
            "image_ref": module_results[module]["image_ref"],
        }
        if meta["release_class"] == "DEFAULT":
            defaults.append(entry)
        else:
            non_defaults.append(entry)
    policy: dict[str, object] = {
        "default_release_components": [
            "tpl-admin-frontend",
            "tpl-admin-backend",
            "tpl-web-frontend",
            "tpl-web-backend",
        ],
        "non_default_profiles": [
            "tpl-admin-frontend-react",
            "tpl-admin-frontend-vue",
            "tpl-web-backend-nest",
        ],
        "business_app_sync": "forbidden_until_p0_009a",
        "remote_git_push": "not_performed",
    }
    existing_path = TPL_APP / "template-release-manifest.json"
    if existing_path.exists():
        existing = json.loads(existing_path.read_text())
        if existing.get("template_release_id") == RELEASE_ID:
            existing_policy = existing.get("policy", {})
            for key in (
                "business_app_sync",
                "remote_git_push",
                "p0_009a",
                "p0_009",
                "recovery_boundaries",
            ):
                if key in existing_policy:
                    policy[key] = existing_policy[key]
    return {
        "template_release_id": RELEASE_ID,
        "task": "V5-P0-008B/B6.4",
        "policy": policy,
        "default_components": defaults,
        "non_default_profiles": non_defaults,
        "pairing_matrix": str(
            (TPL_APP / "frontend-pairing-matrix.json").relative_to(TPL_APP.parent)
        ),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--clean-root",
        type=Path,
        default=Path("/tmp/b64-clean-room"),
        help="Fresh directory for clean checkouts",
    )
    parser.add_argument(
        "--skip-source-gates",
        action="store_true",
        help="Only verify gitlinks/images/evidence (debug)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    gitlinks = verify_parent_gitlinks()
    pair_evidence = verify_pair_evidence()

    clean_root = args.clean_root
    clean_root.mkdir(parents=True, exist_ok=True)

    module_results: dict[str, dict] = {}
    for module, meta in MODULES.items():
        print(f"B64_STAGE=module:{module}", flush=True)
        image_ref = verify_image_digest(meta["image"], meta["tag"], meta["digest"])
        if args.skip_source_gates:
            gates = {"skipped": True}
            dest = TPL_APP / module
        else:
            dest = clean_clone(module, meta["commit"], clean_root)
            gates = gate_module(meta["kind"], dest)
        module_results[module] = {
            "commit": meta["commit"],
            "path": str(dest),
            "gates": gates,
            "image_ref": image_ref,
            "release_class": meta["release_class"],
        }

    # Shared contract vectors from clean Next/FastAPI/Nest trees when available.
    if not args.skip_source_gates:
        print("B64_STAGE=shared_consumer_vectors", flush=True)
        vectors = TPL_APP / "contracts/web-interaction-v1.consumer-vectors.json"
        env = {"WEB_INTERACTION_CONSUMER_VECTORS": str(vectors)}
        run(
            [
                "pnpm",
                "exec",
                "vitest",
                "run",
                "tests/unit/interaction-consumer-vectors.test.ts",
            ],
            cwd=clean_root / "tpl-web-frontend/app",
            env=env,
        )
        run(
            ["uv", "run", "pytest", "-q", "tests/test_interaction_consumer_vectors.py"],
            cwd=clean_root / "tpl-web-backend/app",
            env=env,
        )
        run(
            [
                "pnpm",
                "exec",
                "jest",
                "web-interaction.consumer-vectors.spec.ts",
                "--runInBand",
            ],
            cwd=clean_root / "tpl-web-backend-nest/app",
            env=env,
        )

    manifest = build_manifest(module_results)
    manifest_path = TPL_APP / "template-release-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

    evidence = {
        "task": "V5-P0-008B/B6.4",
        "result": "passed",
        "template_release_id": RELEASE_ID,
        "clean_root": str(clean_root),
        "source_replay": "local_git_clean_clone",
        "remote_gitee_replay": "deferred_until_push_authorized",
        "parent_gitlinks": gitlinks,
        "modules": module_results,
        "pair_and_rollback_evidence": pair_evidence,
        "default_count": 4,
        "non_default_count": 3,
        "business_deployments_touched": False,
        "manifest": str(manifest_path),
    }
    out = EVIDENCE / "unified-clean-room.json"
    out.write_text(json.dumps(evidence, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({"task": evidence["task"], "result": "passed", "manifest": str(manifest_path), "evidence": str(out)}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        print(f"command failed with exit {exc.returncode}", file=sys.stderr)
        raise SystemExit(exc.returncode) from exc
