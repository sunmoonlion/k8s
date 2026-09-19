from __future__ import annotations

import argparse
import base64
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
        "runtime_identity_mode": target.IDENTITY_MODE,
        "migration_head": "20260911_0007",
        "images": {role: f"harbor.sunmoonai.com:30443/app-images/info-{component}@sha256:" + "a" * 64
                   for role, component in target.ROLES.items()},
        "development_source_lock": {
            "kind": "development-source-lock", "formal_release": False, "repository": "info-app",
            "components": [{"path": "info-" + component, "commit": "a" * 40, "tree": "b" * 40}
                           for component in target.ROLES.values()]},
    }


def runtime_secret(app="info"):
    data = {}
    for role in target.RUNTIME_ROLES:
        data[f"{role.upper()}_DATABASE_URL"] = (
            f"postgresql+asyncpg://{app}_backend_{role}:{role * 32}"
            f"@postgresql-sunmoonai.data-platform-dev.svc.cluster.local:5432/{app}_admin")
        data[f"{role.upper()}_CELERY_BROKER_URL"] = (
            f"amqp://{app}-backend-{role}-v2:{(role + 'broker') * 32}"
            f"@rabbitmq-sunmoonai.messaging-platform-dev.svc.cluster.local:5672/{app}-development")
    return {"metadata": {"name": app + "-backend-runtime", "namespace": "app-platform-dev"},
            "data": {key: base64.b64encode(value.encode()).decode() for key, value in data.items()}}


class RuntimeSecretTest(unittest.TestCase):
    def test_all_app_contracts(self):
        for app in ("info", "knowledge", "investment"):
            target.verify_runtime_secret_contract(runtime_secret(app), app)

    def test_rejects_shared_roles_wrong_targets_extra_keys_and_malformed_urls(self):
        original = runtime_secret()
        key = "API_DATABASE_URL"
        url = base64.b64decode(original["data"][key]).decode()
        variants = [None, {}, runtime_secret("knowledge")]
        for changed in (url.replace("postgresql+asyncpg", "postgresql+psycopg"),
                        url.replace("info_backend_api", "info_backend_user"),
                        url.replace("info_admin", "knowledge_admin"),
                        url.replace(":5432", ":5433"), url.replace("postgresql-sunmoonai", "other-host"),
                        url + "?options=unsafe", url + "#private", "broken", url.replace("api" * 32, "short"),
                        url.replace("api" * 32, "worker" * 32), url.replace(":5432", ":notaport")):
            secret = copy.deepcopy(original)
            secret["data"][key] = base64.b64encode(changed.encode()).decode()
            variants.append(secret)
        for value in ("%%%", "\\udcff", 5):
            secret = copy.deepcopy(original)
            secret["data"][key] = value
            variants.append(secret)
        extra = copy.deepcopy(original)
        extra["data"]["WORKER_CELERY_RESULT_BACKEND"] = ""
        variants.append(extra)
        for secret in variants:
            with self.subTest(secret_type=type(secret)), self.assertRaisesRegex(ValueError, "credentials not displayed"):
                target.verify_runtime_secret_contract(secret, "info")

    def test_gate_rejects_missing_mode_and_query_failure(self):
        run = Mock()
        data = candidate()
        del data["runtime_identity_mode"]
        with self.assertRaisesRegex(ValueError, "explicit"):
            target.runtime_secret_gate(None, data, run)
        run.assert_not_called()
        for response in (argparse.Namespace(returncode=1, stdout="private"),
                         argparse.Namespace(returncode=0, stdout="private")):
            run.return_value = response
            with self.assertRaisesRegex(ValueError, "cannot read"):
                target.runtime_secret_gate(None, candidate(), run)


class ExistingBindingTest(unittest.TestCase):
    def test_matching_binding_is_read_only_and_drift_fails_closed(self):
        data = {"RETRIEVAL_AUTH_" + key: base64.b64encode(b"synthetic").decode() for key in (
            "CASDOOR_APPLICATION", "DISCOVERY_URL", "BACKCHANNEL_ENDPOINT", "AUDIENCE", "SUBJECT_ALLOWLIST", "REQUIRED_SCOPE")}
        active = {"data": data, "metadata": {
            "labels": {"sunmoonai.com/active-caller": "investment"},
            "annotations": {"architecture.sunmoonai.com/source-secret": "knowledge-investment-retrieval-service-binding"}}}
        for broken in (False, True):
            result = copy.deepcopy(active)
            if broken:
                result["metadata"]["labels"]["sunmoonai.com/active-caller"] = "research"
            run = Mock(side_effect=[argparse.Namespace(stdout=json.dumps({"data": data}), returncode=0),
                                   argparse.Namespace(stdout=json.dumps(result), returncode=0)])
            if broken:
                with self.assertRaisesRegex(ValueError, "no automatic reconciliation"):
                    target.existing_retrieval_binding_gate(None, candidate(), run)
            else:
                target.existing_retrieval_binding_gate(None, candidate(), run)
            self.assertEqual(run.call_count, 2)
            self.assertTrue(all(c.args[1] == "get" for c in run.call_args_list))

    def test_query_failure_is_not_missing_then_create(self):
        run = Mock(return_value=argparse.Namespace(returncode=1, stdout="private"))
        with self.assertRaisesRegex(ValueError, "no automatic reconciliation"):
            target.existing_retrieval_binding_gate(None, candidate(), run)
        self.assertEqual(run.call_count, 1)


class DevelopmentReleaseTest(unittest.TestCase):
    def test_valid_candidate(self):
        target.validate(candidate())

    def test_rejects_formal_flag_wrong_target_tags_and_incomplete_lock(self):
        mutations = [
            {"formal_release": True}, {"deployment_target": "PRODUCTION"},
            {"namespace": "production"}, {"resource_app": "knowledge"},
            {"migration_head": "head"}, {"images": {"backend": "info:latest"}},
            {"development_source_lock": {}},
            {"runtime_identity_mode": "unknown"},
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
                "secret": runtime_secret(),
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
