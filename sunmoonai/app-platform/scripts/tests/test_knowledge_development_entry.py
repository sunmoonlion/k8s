"""Development upgrades preserve and verify the existing retrieval binding."""
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location(
    "knowledge_deploy", SCRIPTS.parent / "knowledge-app/deployment/deploy.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class DevelopmentEntryTest(unittest.TestCase):
    def test_development_validates_without_mutating_helper(self):
        data = {"formal_release": False}
        with patch.object(target.subprocess, "run") as subprocess, patch.object(
                target.development_release, "runtime_secret_gate") as identity, patch.object(
                target.development_release, "existing_retrieval_binding_gate") as binding:
            target.reconcile_external_state(None, data)
            subprocess.assert_not_called()
            identity.assert_called_once_with(None, data, target.run)
            binding.assert_called_once_with(None, data, target.run)

    def test_binding_failure_has_no_write_fallback(self):
        with patch.object(target.subprocess, "run") as subprocess, patch.object(
                target.development_release, "runtime_secret_gate"), patch.object(
                target.development_release, "existing_retrieval_binding_gate", side_effect=ValueError("drift")):
            with self.assertRaisesRegex(ValueError, "drift"):
                target.reconcile_external_state(None, {"formal_release": False})
            subprocess.assert_not_called()
