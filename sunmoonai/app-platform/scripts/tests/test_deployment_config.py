from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("deployment_config", ROOT / "deployment_config.py")
assert SPEC and SPEC.loader
CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONFIG)


class DeploymentConfigTest(unittest.TestCase):
    def test_profile_requires_explicit_enablement(self):
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory) / "C1.conf"
            profile.write_text(
                'PROFILE_VERSION=1\nPROFILE_ENABLED=false\nDISABLED_REASON="not gated"\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(CONFIG.ConfigError, "not gated"):
                CONFIG.load_profile(profile)

    def test_enabled_profile_is_credential_free_and_bounded(self):
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory) / "KIND.conf"
            profile.write_text(
                "PROFILE_VERSION=1\nPROFILE_ENABLED=true\n"
                "KUBECONFIG=~/.kube/kind-config\nTIMEOUT=300\n",
                encoding="utf-8",
            )
            loaded = CONFIG.load_profile(profile)
            self.assertEqual(loaded["TIMEOUT"], "300")
            self.assertNotIn("PASSWORD", loaded)
            self.assertNotIn("SECRET", loaded)


if __name__ == "__main__":
    unittest.main()
