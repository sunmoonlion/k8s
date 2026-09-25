"""Real scaffold -> instance overlay -> final bundle, without cluster access."""

from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

SCRIPTS = Path(__file__).resolve().parents[1]
PLATFORM = SCRIPTS.parent
sys.path.insert(0, str(SCRIPTS))
import development_release
import render_info_release_base as common


class RuntimeReferenceTest(unittest.TestCase):
    def item(self, role="worker"):
        names = ["DATABASE_URL", "CELERY_BROKER_URL"]
        if role == "worker":
            names.append("CELERY_RESULT_BACKEND")
        return {
            "env": [
                common.env_ref(
                    name,
                    "test-backend-runtime",
                    f"{role.upper()}_{name}",
                    optional=name == "CELERY_RESULT_BACKEND",
                )
                for name in names
            ]
        }

    def test_preserves_reference_and_does_not_alias_input(self):
        for role in ("api", "worker", "scheduler"):
            with self.subTest(role=role):
                item = self.item(role)
                expected = copy.deepcopy(item["env"])
                actual = common.runtime_role_env(item, role)
                self.assertEqual(actual, expected)
                actual[0]["valueFrom"]["secretKeyRef"]["key"] = "changed"
                self.assertEqual(item["env"], expected)

    def test_missing_duplicate_inline_wrong_role_and_optional_fail_closed(self):
        original = self.item()
        broken = []
        for name in ("DATABASE_URL", "CELERY_BROKER_URL", "CELERY_RESULT_BACKEND"):
            item = copy.deepcopy(original)
            item["env"] = [e for e in item["env"] if e["name"] != name]
            broken.append(item)
        item = copy.deepcopy(original)
        item["env"].append(copy.deepcopy(item["env"][0]))
        broken.append(item)
        item = copy.deepcopy(original)
        item["env"][0] = {"name": "DATABASE_URL", "value": "synthetic-not-a-url"}
        broken.append(item)
        for field, value in (
            ("key", "API_DATABASE_URL"),
            ("key", "DATABASE_URL"),
            ("name", "old-shared-credentials"),
            ("optional", True),
        ):
            item = copy.deepcopy(original)
            item["env"][0]["valueFrom"]["secretKeyRef"][field] = value
            broken.append(item)
        item = copy.deepcopy(original)
        item["env"][1]["valueFrom"]["secretKeyRef"]["name"] = "other-backend-runtime"
        broken.append(item)
        for index, item in enumerate(broken):
            with self.subTest(case=index), self.assertRaises(common.RenderError):
                common.runtime_role_env(item, "worker")
        with self.assertRaises(common.RenderError):
            common.runtime_role_env(original, "migration")


class RenderingChecks:
    app: str

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix=f"b7m-{cls.app}-render-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.output = Path(cls.temp.name) / "bundle"
        cls.deployment = PLATFORM / f"{cls.app}-app/deployment"
        subprocess.run(
            [
                sys.executable,
                str(cls.deployment / "render.py"),
                "--output-dir",
                str(cls.output),
                "--release-id",
                "b7m-render-test",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        cls.release = json.loads((cls.output / "release.json").read_text())
        cls.runtime = list(
            yaml.safe_load_all((cls.output / "20-runtime.yaml").read_text())
        )
        cls.prior = list(
            yaml.safe_load_all((cls.deployment / "bundle/20-runtime.yaml").read_text())
        )

    def test_final_runtime_inherits_template_and_preserves_domain_overlay(self):
        credential_names = {
            "DATABASE_URL",
            "CELERY_BROKER_URL",
            "CELERY_RESULT_BACKEND",
        }
        refs = []
        for role in ("api", "worker", "scheduler"):
            with self.subTest(role=role):
                role_credential_names = set(credential_names)
                if self.app == "knowledge" and role == "api":
                    role_credential_names.update(
                        {"S3_ACCESS_KEY_ID", "S3_SECRET_ACCESS_KEY"}
                    )
                name = f"{self.app}-backend-{role}"
                deployment = common.resource(self.runtime, "Deployment", name)
                item = common.container(deployment, role)
                prior_deployment = common.resource(self.prior, "Deployment", name)
                prior = common.container(prior_deployment, role)
                runtime = common.runtime_role_env(item, role)
                for entry in runtime:
                    ref = entry["valueFrom"]["secretKeyRef"]
                    self.assertEqual(ref["name"], f"{self.app}-backend-runtime")
                    refs.append((ref["name"], ref["key"]))
                self.assertEqual(
                    [e for e in item["env"] if e["name"] not in role_credential_names],
                    [e for e in prior["env"] if e["name"] not in role_credential_names],
                )
                for field in ("envFrom", "volumeMounts"):
                    self.assertEqual(item.get(field), prior.get(field))
                self.assertEqual(
                    deployment["spec"]["template"]["spec"].get("volumes"),
                    prior_deployment["spec"]["template"]["spec"].get("volumes"),
                )
                self.assertEqual(
                    deployment["spec"]["template"]["metadata"]["annotations"][
                        "sunmoonai.com/release-id"
                    ],
                    "b7m-render-test",
                )
                if role == "worker":
                    self.assertEqual(
                        item["readinessProbe"]["exec"]["command"],
                        ["python", "-m", "app.cli.worker_readiness"],
                    )
                    self.assertEqual(item["readinessProbe"]["timeoutSeconds"], 8)
        self.assertEqual(len(refs), len(set(refs)))

    def test_external_secret_inventory_and_migration_boundary(self):
        self.assertIn(f"{self.app}-backend-runtime", self.release["external_secrets"])
        self.assertNotIn(
            f"{self.app}-backend-postgresql-conn", self.release["external_secrets"]
        )
        self.assertNotIn(f"{self.app}-backend-broker", self.release["external_secrets"])
        migration = list(
            yaml.safe_load_all((self.output / "10-migration.yaml").read_text())
        )
        item = next(d for d in migration if d["kind"] == "Job")["spec"]["template"][
            "spec"
        ]["containers"][0]
        self.assertEqual(
            {e["valueFrom"]["secretKeyRef"]["name"] for e in item["env"]},
            {f"{self.app}-backend-migration-postgresql-conn"},
        )
        subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "verify-formal-instance.py"),
                "--bundle",
                str(self.output),
            ],
            check=True,
            capture_output=True,
            timeout=10,
        )

    def test_development_finalizer_preserves_runtime_contract(self):
        # Exercise the real finalizer over a real renderer result. Only Git
        # attestation is simulated: this test does not certify candidate images.
        with tempfile.TemporaryDirectory(prefix="b7m-finalize-") as directory:
            root = Path(directory)
            output = root / "bundle"
            output.mkdir()
            for filename in (*self.release["resources"], "release.json"):
                (output / filename).write_bytes((self.output / filename).read_bytes())
            source = root / f"{self.app}-app"
            versions = source / f"{self.app}-backend/app/alembic/versions"
            versions.mkdir(parents=True)
            (versions / "fixture.py").write_text(
                "revision = '20260913_0009'\ndown_revision = None\n"
            )
            lock = {
                "kind": "development-source-lock",
                "formal_release": False,
                "repository": f"{self.app}-app",
                "components": [
                    {
                        "path": f"{self.app}-{component}",
                        "commit": "a" * 40,
                        "tree": "b" * 40,
                    }
                    for component in development_release.ROLES.values()
                ],
            }
            (source / "development-source-lock.json").write_text(json.dumps(lock))
            candidate = {
                "kind": "kind-development-release-input",
                "logical_app": self.app,
                "migration_head": "20260913_0009",
                "images": self.release["images"],
                "development_source_lock": lock,
                "runtime_identity_mode": development_release.IDENTITY_MODE,
            }
            input_path = root / "input.json"
            input_path.write_text(json.dumps(candidate))

            def git_output(command, **kwargs):
                if command[-2:] == ["status", "--porcelain"]:
                    return ""
                self.assertEqual(command[-2], "rev-parse")
                return ("a" if command[-1] == "HEAD" else "b") * 40 + "\n"

            with patch.object(
                development_release.subprocess, "check_output", side_effect=git_output
            ):
                development_release.render(output, input_path, root / "k8s")
            runtime = list(yaml.safe_load_all((output / "20-runtime.yaml").read_text()))
            for role in ("api", "worker", "scheduler"):
                item = common.resource(
                    runtime, "Deployment", f"{self.app}-backend-{role}"
                )
                original = common.resource(
                    self.runtime, "Deployment", f"{self.app}-backend-{role}"
                )
                self.assertEqual(
                    item["spec"]["template"]["spec"],
                    original["spec"]["template"]["spec"],
                )
                annotations = item["spec"]["template"]["metadata"]["annotations"]
                self.assertEqual(
                    annotations["sunmoonai.com/release-id"], "b7m-render-test"
                )
                self.assertEqual(annotations["sunmoonai.com/source-commit"], "a" * 40)
            configs = list(yaml.safe_load_all((output / "00-prerequisites.yaml").read_text()))
            config = common.resource(configs, "ConfigMap", self.app + "-backend-config")
            self.assertEqual(config["data"]["CELERY_TASK_TOPOLOGY_PREDECLARED"], "true")
            finalized = json.loads((output / "release.json").read_text())
            self.assertEqual(finalized["runtime_identity_mode"], development_release.IDENTITY_MODE)
            subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "verify-formal-instance.py"),
                    "--bundle",
                    str(output),
                ],
                check=True,
                capture_output=True,
                timeout=10,
            )


class InfoRenderingTest(RenderingChecks, unittest.TestCase):
    app = "info"


class KnowledgeRenderingTest(RenderingChecks, unittest.TestCase):
    app = "knowledge"

    def test_mcp_api_receives_optional_dataset_store_credentials(self):
        api = common.resource(self.runtime, "Deployment", "knowledge-backend-api")
        env = common.container(api, "api")["env"]
        for name in ("S3_ACCESS_KEY_ID", "S3_SECRET_ACCESS_KEY"):
            with self.subTest(name=name):
                entry = next(item for item in env if item["name"] == name)
                ref = entry["valueFrom"]["secretKeyRef"]
                self.assertEqual(ref["name"], "knowledge-backend-s3")
                self.assertEqual(ref["key"], name)
                self.assertIs(ref["optional"], True)


class InvestmentRenderingTest(RenderingChecks, unittest.TestCase):
    app = "investment"


if __name__ == "__main__":
    unittest.main()
