from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import development_release as target


def candidate():
    return {
        "architecture": target.ARCHITECTURE, "formal_release": False,
        "deployment_target": "KIND", "namespace": "app-platform-dev",
        "logical_app": "info", "resource_app": "info", "release_id": "kind-test",
        "migration_head": "20260911_0007",
        "images": {role: f"harbor.sunmoonai.com:30443/app-images/info-{component}@sha256:" + "a" * 64
                   for role, component in target.ROLES.items()},
        "development_source_lock": {
            "kind": "development-source-lock", "formal_release": False, "repository": "info-app",
            "components": [{"path": "info-" + component, "commit": "a" * 40, "tree": "b" * 40}
                           for component in target.ROLES.values()]},
    }


class DevelopmentReleaseTest(unittest.TestCase):
    def test_valid_candidate(self):
        target.validate(candidate())

    def test_rejects_formal_flag_wrong_target_tags_and_incomplete_lock(self):
        mutations = [
            {"formal_release": True}, {"deployment_target": "PRODUCTION"},
            {"namespace": "production"}, {"resource_app": "knowledge"},
            {"migration_head": "head"}, {"images": {"backend": "info:latest"}},
            {"development_source_lock": {}},
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                target.validate(candidate() | mutation)
        data = candidate()
        data["development_source_lock"]["components"][0]["commit"] = "abc"
        with self.assertRaises(ValueError):
            target.validate(data)

    def test_formal_release_keeps_existing_entry(self):
        run = Mock()
        target.guard(argparse.Namespace(), {"formal_release": True}, run)
        run.assert_not_called()

    def test_plan_requires_explicit_kind_without_cluster_access(self):
        run = Mock()
        with self.assertRaisesRegex(ValueError, "explicit"):
            target.guard(argparse.Namespace(cluster=None, action="plan"), candidate(), run)
        target.guard(argparse.Namespace(cluster="KIND", action="plan"), candidate(), run)
        run.assert_not_called()

    def test_actual_cluster_identity_is_checked(self):
        run = Mock(return_value=argparse.Namespace(stdout=json.dumps({"items": [{"spec": {"providerID": "aws://node"}}]})))
        with self.assertRaisesRegex(ValueError, "non-KIND"):
            target.guard(argparse.Namespace(cluster="KIND", action="server-dry-run"), candidate(), run)

    def test_apply_requires_matching_restored_backup_and_quiescent_writers(self):
        with tempfile.TemporaryDirectory() as directory:
            backup = Path(directory) / "database.dump"
            backup.write_bytes(b"test-backup")
            receipt_path = Path(directory) / "receipt.json"
            receipt = {"cluster_uid": "kind-uid", "logical_app": "info", "release_id": "kind-test",
                       "restore_verified": True, "backup_file": str(backup),
                       "sha256": hashlib.sha256(backup.read_bytes()).hexdigest()}
            receipt_path.write_text(json.dumps(receipt))
            args = argparse.Namespace(cluster="KIND", action="apply", component="all", backup_receipt=receipt_path)
            responses = {
                "nodes": {"items": [{"spec": {"providerID": "kind://docker/kind/node"}}]},
                "namespace": {"metadata": {"uid": "kind-uid"}},
                "deployments": {"items": [{"metadata": {"name": "info-backend-api"}, "spec": {"replicas": 0}}]},
                "pods": {"items": []},
            }
            def run(_args, _verb, resource, *items, **kwargs):
                return argparse.Namespace(stdout=json.dumps(responses[resource]))
            target.guard(args, candidate(), run)
            responses["pods"]["items"] = [{"metadata": {"labels": {"app.kubernetes.io/component": "backend-worker"}}}]
            with self.assertRaisesRegex(ValueError, "Pods still exist"):
                target.guard(args, candidate(), run)
            responses["pods"]["items"] = []
            responses["deployments"]["items"][0]["spec"]["replicas"] = 1
            with self.assertRaisesRegex(ValueError, "stop old"):
                target.guard(args, candidate(), run)
            for key, value in (("cluster_uid", "another"), ("restore_verified", False), ("sha256", "bad")):
                broken = copy.deepcopy(receipt)
                broken[key] = value
                receipt_path.write_text(json.dumps(broken))
                with self.subTest(key=key), self.assertRaises(ValueError):
                    target.guard(args, candidate(), run)


if __name__ == "__main__":
    unittest.main()
