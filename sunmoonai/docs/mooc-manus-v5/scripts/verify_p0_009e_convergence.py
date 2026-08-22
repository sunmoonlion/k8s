#!/usr/bin/env python3
"""Fail-closed P0-009E instance-foundation convergence gate.

This gate never treats a skipped check as success. It validates committed and
clean component repositories, strictly typed prior evidence, exact kernel
alignment, deterministic replay from the pre-migration tag, rollback evidence,
business-deployment invariance, secret hygiene, and a reachable clean KIND
cluster before writing alignment markers.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

K8S = Path("/home/zymun/master/k8s")
TPL = Path("/home/zymun/master/tpl-app")
EVIDENCE = K8S / "sunmoonai/docs/evidence/v5/V5-P0-009E"
LOCK_FILE = EVIDENCE / "alignment-lock.json"
RELEASE_ID = "p0-008b-b6-unified-20260729"
FREEZE_TAG = "p0-009a-pre-20260729"

TEMPLATE_COMMITS = {
    "admin-frontend": "fb69795b04e0b888a2917c3936f7f80aeac79cc9",
    "admin-backend": "69e634b8e5b06da9d1dcd01c9b1350e0571d74bd",
    "web-frontend": "1db9377d38dac5510331149d9122f8d375d83fe3",
    "web-backend": "289f2c46410e0aa2891fdf3da28242ceb1a33bdb",
}

APPS: dict[str, dict[str, Any]] = {
    "info": {
        "parent": Path("/home/zymun/master/info-app"),
        "branch": "codex-1",
        "evidence": "V5-P0-009B",
        "admin_task": "V5-P0-009B-browser-pair",
        "web_task": "V5-P0-009B-web-pair",
        "rollback_task": "V5-P0-009B-rollback",
        "domain_needles": ["dispatch_crawl_url", "delivery_outbox_batch_size"],
    },
    "knowledge": {
        "parent": Path("/home/zymun/master/knowledge-app"),
        "branch": "codex-1",
        "evidence": "V5-P0-009C",
        "admin_task": "V5-P0-009C-browser-pair",
        "web_task": "V5-P0-009C-web-pair",
        "rollback_task": "V5-P0-009C-rollback-drill",
        "domain_needles": [
            "retrieval_auth_casdoor_application",
            "dispatch_knowledge_ingestion",
            "ragflow_api_base",
        ],
    },
    "research": {
        "parent": Path("/home/zymun/research-app"),
        "branch": "codex-1",
        "evidence": "V5-P0-009D",
        "admin_task": "V5-P0-009D-browser-pair",
        "web_task": "V5-P0-009D-web-pair",
        "rollback_task": "V5-P0-009D-rollback",
        "domain_needles": [
            "knowledge_retrieval_service_application",
            "dispatch_agent_graph",
            "agent_v4_traffic_enabled",
        ],
    },
}

SURFACES = ("admin-frontend", "admin-backend", "web-frontend", "web-backend")
KERNEL_REL_PATHS = (
    "app/domain/security/principal.py",
    "app/application/services/auth_service.py",
    "app/infrastructure/security/oidc.py",
    "app/infrastructure/storage/postgres.py",
    "app/infrastructure/storage/redis.py",
)
OIDC_SERVICE_ACCESSOR = '''    async def get_key_set(
        self, metadata: OidcMetadata, *, force_refresh: bool = False
    ) -> KeySet:
        """Public JWKS accessor used by service-to-service verifiers."""
        return await self._get_key_set(metadata, force_refresh=force_refresh)

'''
IMAGE_DIGEST_RE = re.compile(
    r"^harbor\.sunmoonai\.com:30443/app-images/"
    r"[a-z0-9-]+@sha256:[0-9a-f]{64}$"
)
SECRET_PATTERNS = (
    re.compile(
        r"(?i)client_secret[\"']?\s*[:=]\s*[\"']"
        r"(?!change-me|placeholder|xxx)[^\"']{12,}"
    ),
    re.compile(r"(?i)-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(
        r"(?i)password[\"']?\s*[:=]\s*[\"']"
        r"(?!change-me|placeholder|xxx)[^\"']{8,}"
    ),
)


def run(cmd: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> str:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        env=env,
        check=True,
        text=True,
        capture_output=True,
    )
    return proc.stdout.strip()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text())
    require(isinstance(value, dict), f"{path} must contain a JSON object")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def component_repos() -> dict[str, Path]:
    repos: dict[str, Path] = {}
    for app, meta in APPS.items():
        for surface in SURFACES:
            repos[f"{app}-{surface}"] = meta["parent"] / f"{app}-{surface}"
    return repos


def assert_clean_repositories() -> dict[str, str]:
    heads: dict[str, str] = {}
    for name, repo in component_repos().items():
        status = run(["git", "-C", str(repo), "status", "--porcelain"])
        require(not status, f"{name} has uncommitted or untracked files")
        heads[name] = run(["git", "-C", str(repo), "rev-parse", "HEAD"])
    return heads


def image_ref(payload: dict[str, Any], side: str) -> str:
    direct = payload.get(f"{side}_image")
    nested = payload.get(side)
    value = direct or (nested.get("image") if isinstance(nested, dict) else None)
    require(isinstance(value, str), f"missing {side} image")
    require(IMAGE_DIGEST_RE.fullmatch(value) is not None, f"invalid image digest: {value}")
    return value


def verify_prior_evidence() -> dict[str, Any]:
    freeze_path = K8S / "sunmoonai/docs/evidence/v5/V5-P0-009A/freeze.json"
    freeze = load_json(freeze_path)
    require(freeze.get("task") == "V5-P0-009A", "freeze task mismatch")
    require(freeze.get("result") == "passed", "P0-009A freeze did not pass")
    require(freeze.get("template_release_id") == RELEASE_ID, "freeze release mismatch")
    require(set(freeze.get("apps", {})) == set(APPS), "freeze app set mismatch")

    report: dict[str, Any] = {"freeze": str(freeze_path), "pairs": {}, "rollback": {}}
    for app, meta in APPS.items():
        evidence_dir = K8S / f"sunmoonai/docs/evidence/v5/{meta['evidence']}"
        result_md = evidence_dir / "result.md"
        require(result_md.exists(), f"missing {result_md}")
        require(
            re.search(r"(?m)^.*ACCEPTED.*$", result_md.read_text()) is not None,
            f"{meta['evidence']} result is not ACCEPTED",
        )

        admin = load_json(evidence_dir / "admin-pair.json")
        web = load_json(evidence_dir / "web-pair.json")
        rollback = load_json(evidence_dir / "rollback.json")
        require(admin.get("task") == meta["admin_task"], f"{app} admin task mismatch")
        require(web.get("task") == meta["web_task"], f"{app} web task mismatch")
        require(admin.get("result") == "passed", f"{app} admin pair failed")
        require(web.get("result") == "passed", f"{app} web pair failed")
        require(rollback.get("task") == meta["rollback_task"], f"{app} rollback task mismatch")
        require(rollback.get("result") == "passed", f"{app} rollback not fully passed")

        unchanged = load_json(evidence_dir / "business-deployments-unchanged.json")
        require(unchanged.get("result") == "passed", f"{app} business comparison failed")
        before = unchanged.get("pre", unchanged.get("before"))
        after = unchanged.get("post", unchanged.get("after"))
        require(isinstance(before, dict) and before, f"{app} business before missing")
        require(before == after, f"{app} business deployments changed")
        require(not unchanged.get("changed", []), f"{app} reports changed business deployments")

        report["pairs"][f"{app}-admin"] = {
            "result": "passed",
            "frontend_image": image_ref(admin, "frontend"),
            "backend_image": image_ref(admin, "backend"),
        }
        report["pairs"][f"{app}-web"] = {
            "result": "passed",
            "frontend_image": image_ref(web, "frontend"),
            "backend_image": image_ref(web, "backend"),
        }
        report["rollback"][app] = "passed"
    require(len(report["pairs"]) == 6, "expected exactly six pair results")
    return report


def verify_shared_contracts() -> dict[str, Any]:
    manifest = load_json(TPL / "template-release-manifest.json")
    require(manifest.get("template_release_id") == RELEASE_ID, "template release mismatch")
    defaults = {
        item.get("module"): item.get("commit")
        for item in manifest.get("default_components", [])
        if isinstance(item, dict)
    }
    expected = {
        f"tpl-{surface}": commit for surface, commit in TEMPLATE_COMMITS.items()
    }
    require(defaults == expected, f"default component set/commit mismatch: {defaults}")
    matrix = load_json(TPL / "frontend-pairing-matrix.json")
    require(bool(matrix.get("pairs") or matrix.get("pairings")), "pairing matrix is empty")
    return {"template_release_id": RELEASE_ID, "default_components": defaults}


def verify_identity_domain_and_recovery() -> dict[str, Any]:
    report: dict[str, Any] = {}
    for app, meta in APPS.items():
        parent = meta["parent"]
        require(
            run(["git", "-C", str(parent), "branch", "--show-current"]) == meta["branch"],
            f"{app} parent is not on {meta['branch']}",
        )
        admin_cfg = (parent / f"{app}-admin-backend/app/core/config.py").read_text()
        web_cfg = (parent / f"{app}-web-backend/app/core/config.py").read_text()
        celery = (
            parent
            / f"{app}-admin-backend/app/app/infrastructure/messaging/celery_producer.py"
        ).read_text()
        required = (
            f'app_slug: str = "{app}"',
            f'casdoor_application: str = "sunmoonai-{app}-admin"',
            f'service_name: str = "{app}-admin-backend"',
        )
        for needle in required:
            require(needle in admin_cfg, f"{app} admin identity missing {needle}")
        for needle in (
            f'app_slug: str = "{app}"',
            f'casdoor_application: str = "sunmoonai-{app}-web"',
        ):
            require(needle in web_cfg, f"{app} web identity missing {needle}")
        for needle in meta["domain_needles"]:
            require(needle in admin_cfg + celery, f"{app} domain marker missing {needle}")
        for other in set(APPS) - {app}:
            require(
                f'app_slug: str = "{other}"' not in admin_cfg + web_cfg,
                f"{app} leaked {other} identity",
            )
        recovery = parent / "docs/P0-009-DOMAIN-RECOVERY.md"
        require(recovery.exists(), f"{app} recovery manifest missing")
        require(FREEZE_TAG in recovery.read_text(), f"{app} recovery tag missing")
        report[app] = {"identity": "passed", "domain": "passed", "recovery": str(recovery)}
    return report


def verify_archive_hygiene() -> dict[str, Any]:
    violations: list[str] = []
    for name, repo in component_repos().items():
        tracked = run(["git", "-C", str(repo), "ls-files"]).splitlines()
        for rel in tracked:
            lower = rel.lower()
            if "domain-keep" in lower:
                violations.append(f"{name}:{rel}")
            if lower.startswith("docs/") and (
                Path(lower).name.startswith(".env")
                or "query_engine" in lower
                or lower.endswith((".dll", ".node", ".so", ".dylib"))
            ):
                violations.append(f"{name}:{rel}")
    require(not violations, f"archived secret/generated/binary files remain: {violations[:8]}")

    evidence_dirs = [
        K8S / f"sunmoonai/docs/evidence/v5/{meta['evidence']}" for meta in APPS.values()
    ]
    evidence_dirs.append(EVIDENCE)
    scanned = 0
    for directory in evidence_dirs:
        for path in directory.glob("*"):
            if not path.is_file() or path.name in {"convergence.json", "alignment-lock.json"}:
                continue
            try:
                text = path.read_text()
            except UnicodeDecodeError:
                violations.append(str(path))
                continue
            scanned += 1
            for pattern in SECRET_PATTERNS:
                if pattern.search(text):
                    violations.append(str(path))
                    break
    require(not violations, f"secret-like evidence/archive content: {violations[:8]}")
    return {"result": "passed", "evidence_files_scanned": scanned}


def verify_kernel_drift() -> dict[str, Any]:
    template_root = TPL / "tpl-admin-backend/app"
    report: dict[str, Any] = {}
    for app, meta in APPS.items():
        app_root = meta["parent"] / f"{app}-admin-backend/app"
        files: dict[str, Any] = {}
        for rel in KERNEL_REL_PATHS:
            template_path = template_root / rel
            app_path = app_root / rel
            require(template_path.exists() and app_path.exists(), f"missing kernel file {app}:{rel}")
            template_text = template_path.read_text()
            app_text = app_path.read_text()
            status = "identical"
            if app_text != template_text:
                only_allowed_accessor = (
                    app in {"knowledge", "research"}
                    and rel == "app/infrastructure/security/oidc.py"
                    and app_text.replace(OIDC_SERVICE_ACCESSOR, "", 1) == template_text
                    and app_text.count(OIDC_SERVICE_ACCESSOR) == 1
                )
                require(only_allowed_accessor, f"unexplained kernel drift: {app}:{rel}")
                status = "allowed_service_jwks_accessor"
            files[rel] = {
                "template_sha256": sha256_file(template_path),
                "instance_sha256": sha256_file(app_path),
                "status": status,
            }
        report[app] = {"result": "passed", "files": files}
    return report


def verify_rollback_tags() -> dict[str, Any]:
    report: dict[str, Any] = {}
    for name, repo in component_repos().items():
        tag_commit = run(["git", "-C", str(repo), "rev-parse", f"{FREEZE_TAG}^{{commit}}"])
        require(tag_commit, f"{name} freeze tag missing")
        report[name] = tag_commit
    return {"tag": FREEZE_TAG, "repos": report}


def clean_room_replay(work_root: Path, heads: dict[str, str]) -> dict[str, Any]:
    """Apply the complete freeze-to-target binary patch and compare Git trees."""
    report: dict[str, Any] = {}
    for name, repo in component_repos().items():
        destination = work_root / name
        run(
            [
                "git",
                "clone",
                "--quiet",
                "--no-checkout",
                "--shared",
                str(repo),
                str(destination),
            ]
        )
        run(["git", "checkout", "--quiet", FREEZE_TAG], cwd=destination)
        target = heads[name]
        patch = subprocess.run(
            ["git", "-C", str(repo), "diff", "--binary", FREEZE_TAG, target, "--", "."],
            check=True,
            capture_output=True,
        ).stdout
        applied = subprocess.run(
            ["git", "apply", "--index", "--binary", "-"],
            cwd=destination,
            input=patch,
            check=False,
            capture_output=True,
        )
        require(
            applied.returncode == 0,
            f"{name} clean-room patch failed: {applied.stderr.decode(errors='replace')[-300:]}",
        )
        replay_tree = run(["git", "write-tree"], cwd=destination)
        target_tree = run(["git", "-C", str(repo), "rev-parse", f"{target}^{{tree}}"])
        require(replay_tree == target_tree, f"{name} clean-room tree mismatch")
        report[name] = {
            "from_tag": FREEZE_TAG,
            "target_commit": target,
            "target_tree": target_tree,
            "patch_bytes": len(patch),
            "result": "passed",
        }
    return report


def verify_or_create_alignment_lock(heads: dict[str, str]) -> dict[str, Any]:
    current = {
        name: {
            "commit": commit,
            "tree": run(["git", "-C", str(component_repos()[name]), "rev-parse", f"{commit}^{{tree}}"]),
        }
        for name, commit in sorted(heads.items())
    }
    if LOCK_FILE.exists():
        lock = load_json(LOCK_FILE)
        require(lock.get("template_release_id") == RELEASE_ID, "alignment lock release mismatch")
        require(lock.get("repositories") == current, "component HEAD/tree drifted from alignment lock")
        return {"result": "matched", "repositories": current}
    write_json(
        LOCK_FILE,
        {
            "task": "V5-P0-009E",
            "template_release_id": RELEASE_ID,
            "freeze_tag": FREEZE_TAG,
            "repositories": current,
        },
    )
    return {"result": "created", "repositories": current}


def verify_kind_hygiene(kubeconfig: Path, namespace: str) -> dict[str, Any]:
    kubectl = shutil.which("kubectl")
    require(kubectl is not None, "kubectl is unavailable")
    require(kubeconfig.exists(), f"kubeconfig missing: {kubeconfig}")
    env = os.environ.copy()
    env["KUBECONFIG"] = str(kubeconfig)
    names = run(
        [
            kubectl,
            "--request-timeout=15s",
            "-n",
            namespace,
            "get",
            "deploy,svc,ingressroute,job",
            "-o",
            "name",
        ],
        env=env,
    ).splitlines()
    leftovers = [name for name in names if "p0-009" in name]
    require(not leftovers, f"P0-009 isolation resources remain: {leftovers}")
    nodes = run(
        [kubectl, "--request-timeout=15s", "get", "nodes", "-o", "json"],
        env=env,
    )
    node_items = json.loads(nodes).get("items", [])
    require(node_items, "KIND returned no nodes")
    require(
        all(
            any(c.get("type") == "Ready" and c.get("status") == "True" for c in item["status"]["conditions"])
            for item in node_items
        ),
        "one or more KIND nodes are not Ready",
    )
    return {"result": "passed", "namespace": namespace, "isolation_leftovers": []}


def remove_alignment_markers() -> None:
    for meta in APPS.values():
        marker = meta["parent"] / "docs/INSTANCE_FOUNDATION_ALIGNED.json"
        marker.unlink(missing_ok=True)


def write_alignment_markers(report: dict[str, Any]) -> None:
    for app, meta in APPS.items():
        marker = meta["parent"] / "docs/INSTANCE_FOUNDATION_ALIGNED.json"
        write_json(
            marker,
            {
                "status": "INSTANCE_FOUNDATION_ALIGNED",
                "template_release_id": RELEASE_ID,
                "app": app,
                "task": "V5-P0-009E",
                "component_commits": {
                    name: value
                    for name, value in report["source_heads"].items()
                    if name.startswith(f"{app}-")
                },
                "pairs": {
                    "admin": report["prior"]["pairs"][f"{app}-admin"],
                    "web": report["prior"]["pairs"][f"{app}-web"],
                },
                "traffic_cutover": False,
                "remote_git_push": False,
            },
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-root", type=Path, default=Path("/tmp/p0-009e-clean-room"))
    parser.add_argument("--kubeconfig", type=Path, default=Path.home() / ".kube/kind-config")
    parser.add_argument("--namespace", default="app-platform-dev")
    args = parser.parse_args()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    remove_alignment_markers()
    if args.work_root.exists():
        shutil.rmtree(args.work_root)
    args.work_root.mkdir(parents=True)

    report: dict[str, Any] = {
        "task": "V5-P0-009E",
        "template_release_id": RELEASE_ID,
        "result": "failed",
        "p0_008c_unlocked": False,
        "business_traffic_unchanged": False,
        "remote_git_push": False,
    }
    try:
        heads = assert_clean_repositories()
        report["source_heads"] = heads
        report["prior"] = verify_prior_evidence()
        report["shared_contracts"] = verify_shared_contracts()
        report["identity_domain_recovery"] = verify_identity_domain_and_recovery()
        report["archive_hygiene"] = verify_archive_hygiene()
        report["kernel_drift"] = verify_kernel_drift()
        report["rollback_tags"] = verify_rollback_tags()
        report["clean_room"] = clean_room_replay(args.work_root, heads)
        report["kind_hygiene"] = verify_kind_hygiene(args.kubeconfig, args.namespace)
        report["alignment_lock"] = verify_or_create_alignment_lock(heads)
        report["result"] = "passed"
        report["instance_foundation_aligned"] = sorted(APPS)
        report["p0_008c_unlocked"] = True
        report["business_traffic_unchanged"] = True
        write_alignment_markers(report)
        write_json(EVIDENCE / "convergence.json", report)
        write_json(EVIDENCE / "drift-report.json", report["kernel_drift"])
        print(
            json.dumps(
                {
                    "task": "V5-P0-009E",
                    "result": "passed",
                    "aligned": report["instance_foundation_aligned"],
                },
                ensure_ascii=False,
            )
        )
        return 0
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
        write_json(EVIDENCE / "convergence.json", report)
        print(json.dumps(report, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
