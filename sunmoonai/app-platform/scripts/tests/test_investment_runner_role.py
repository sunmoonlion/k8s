"""The investment base render carries the workbench runner role (0001-workbench 第五个进程角色)."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import formal_component_deploy


class InvestmentRunnerRoleTest(unittest.TestCase):
    def test_base_render_has_runner_deployment_policy_and_config(self):
        with tempfile.TemporaryDirectory(prefix="investment-runner-") as temp:
            output = Path(temp) / "base"
            subprocess.run(
                [sys.executable, "-B", str(SCRIPTS / "render_investment_release_base.py"),
                 "--output-dir", str(output)],
                check=True, capture_output=True, text=True, timeout=60,
            )
            runtime = [d for d in yaml.safe_load_all((output / "20-runtime.yaml").read_text()) if d]
            runner = next(d for d in runtime if d["kind"] == "Deployment"
                          and d["metadata"]["name"] == "investment-r5-backend-runner")
            self.assertEqual(runner["spec"]["replicas"], 1)
            container = runner["spec"]["template"]["spec"]["containers"][0]
            self.assertEqual(container["command"], ["python", "-m", "app.bootstrap.runner"])
            env = {e["name"]: e for e in container["env"]}
            self.assertEqual(env["DATABASE_URL"]["valueFrom"]["secretKeyRef"]["key"], "API_DATABASE_URL")
            self.assertEqual(env["REDIS_PASSWORD"]["valueFrom"]["secretKeyRef"]["name"], "investment-backend-redis-conn")
            self.assertIn("WORKBENCH_RUNNER_ID", env)
            self.assertFalse(any(d["kind"] == "HorizontalPodAutoscaler"
                                 and d["metadata"]["name"].endswith("backend-runner") for d in runtime))
            api = next(d for d in runtime if d["kind"] == "Deployment"
                       and d["metadata"]["name"] == "investment-r5-backend-api")
            api_env = {e["name"]: e for e in api["spec"]["template"]["spec"]["containers"][0]["env"]}
            self.assertTrue(api_env["WORKBENCH_CREDENTIAL_KEY"]["valueFrom"]["secretKeyRef"]["optional"])

            prerequisites = [d for d in yaml.safe_load_all((output / "00-prerequisites.yaml").read_text()) if d]
            config = next(d for d in prerequisites if d["kind"] == "ConfigMap"
                          and d["metadata"]["name"] == "investment-r5-backend-config")["data"]
            self.assertEqual(config["WORKBENCH_ENABLED"], "true")
            self.assertEqual(config["WORKBENCH_REDIS_KEY_PREFIX"], "investment:workbench")
            self.assertTrue(any(d["kind"] == "ServiceAccount"
                                and d["metadata"]["name"] == "investment-r5-backend-runner" for d in prerequisites))

            policies = [d for d in yaml.safe_load_all((output / "30-network-policies.yaml").read_text()) if d]
            runner_policy = next(d for d in policies if d["metadata"]["name"] == "investment-r5-backend-runner-egress")
            ports = {p["port"] for rule in runner_policy["spec"]["egress"] for p in rule["ports"]}
            self.assertEqual(ports, {5432, 6379, 47800})
            self.assertEqual(sum(1 for d in policies if d["metadata"]["name"] == "investment-r5-backend-runner-egress"), 1)

    def test_runner_is_a_runtime_component(self):
        self.assertIn("backend-runner", formal_component_deploy.RUNTIME_COMPONENTS)
        self.assertIn("backend-runner", formal_component_deploy.COMPONENTS)


if __name__ == "__main__":
    unittest.main()
