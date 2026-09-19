"""The committed development inputs, declaration and bundles are one release.

No cluster calls. Rendering also checks the component commit/tree and migration
head; this is not evidence that a release was applied or live permissions work.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import deployment_config


class CommittedCandidatesTest(unittest.TestCase):
    def test_all_bundles_reproduce_and_match_declarations(self):
        for app in ("info", "knowledge", "investment"):
            with self.subTest(app=app), tempfile.TemporaryDirectory(prefix="committed-release-") as temp:
                root = SCRIPTS.parent / (app + "-app")
                deployment = root / "deployment"
                bundle = deployment / "bundle"
                release = json.loads((bundle / "release.json").read_text())
                self.assertIs(release["formal_release"], False)
                self.assertEqual(release["runtime_identity_mode"], "independent-v1")
                declaration = deployment_config.load_base(root / f"deploy-{app}-app-all/deploy-{app}-app-all.conf")
                deployment_config.validate_release(declaration, release)
                output = Path(temp) / "bundle"
                command = [sys.executable, "-B", str(deployment / "render.py"), "--output-dir", str(output),
                           "--release-id", release["release_id"], "--development-input", str(deployment / "development-input.json")]
                if app == "knowledge":
                    command += ["--ingestion-dataset-bindings-file", str(deployment / "ingestion-dataset-bindings.kind.json")]
                subprocess.run(command, check=True, capture_output=True, text=True, timeout=30)
                for name in (*release["resources"], "release.json"):
                    self.assertEqual((output / name).read_bytes(), (bundle / name).read_bytes(), name)
                subprocess.run([sys.executable, "-B", str(SCRIPTS / "verify-formal-instance.py"),
                                "--bundle", str(bundle)], check=True, capture_output=True, timeout=10)
