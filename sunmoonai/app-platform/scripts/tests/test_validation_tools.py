"""Run retained validation regressions from the normal script test suite.

Only fake-CLI tests and --help are executed here; no live cluster is accessed.
"""

from __future__ import annotations

import os
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


VALIDATION = Path(__file__).resolve().parents[1] / "validation"


class ValidationToolsTest(unittest.TestCase):
    def test_handbook_allows_only_regular_nonexecutable_markdown(self):
        spec = importlib.util.spec_from_file_location(
            "validation_topology", VALIDATION / "verify_runtime_role_topology.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            handbook = root / "dev-to-prod-deploy"
            handbook.mkdir()
            (handbook / "README.md").write_text("# Handbook\n")
            errors = []
            module.check_deployment_handbook(root, errors)
            self.assertEqual(errors, [])
            bad = handbook / "deploy.sh"
            bad.write_text("exit 0\n")
            module.check_deployment_handbook(root, errors)
            self.assertTrue(errors)
            bad.unlink()
            doc = handbook / "README.md"
            doc.chmod(0o755)
            errors = []
            module.check_deployment_handbook(root, errors)
            self.assertTrue(errors)
            doc.chmod(0o644)
            link = handbook / "linked.md"
            link.symlink_to(doc)
            errors = []
            module.check_deployment_handbook(root, errors)
            self.assertTrue(errors)

    def test_retained_regressions(self):
        env = dict(os.environ)
        # Do not let a caller redirect the fake-CLI safety suite to another tool.
        env.pop("CALICO_GATE_TEST_SCRIPT", None)
        result = subprocess.run(
            [sys.executable, "-m", "unittest", "discover", "-s", str(VALIDATION),
             "-p", "test_*.py", "-v"],
            capture_output=True, text=True, env=env, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Ran 13 tests", result.stderr)

    def test_cli_entrypoints_resolve_without_old_directory(self):
        for name in ("sync_r4_instance.py", "verify_runtime_role_topology.py"):
            with self.subTest(tool=name):
                result = subprocess.run(
                    [sys.executable, str(VALIDATION / name), "--help"],
                    cwd="/tmp", capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("usage:", result.stdout)


if __name__ == "__main__":
    unittest.main()
