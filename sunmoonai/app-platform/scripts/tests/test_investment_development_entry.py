"""No live subprocesses: prove development entry cannot replay legacy writers."""
import argparse
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location(
    "investment_deploy", SCRIPTS.parent / "investment-app/deployment/deploy.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class DevelopmentEntryTest(unittest.TestCase):
    def test_prepared_development_never_calls_legacy_helpers(self):
        args = argparse.Namespace()
        data = {"formal_release": False}
        with patch.object(target, "helper") as helper, patch.object(
                target.development_release, "runtime_secret_gate") as gate, patch.object(
                target.development_release, "existing_retrieval_binding_gate") as binding:
            target.reconcile_external_state(args, data)
            helper.assert_not_called()
            gate.assert_called_once_with(args, data, target.run)
            binding.assert_called_once_with(args, data, target.run)

    def test_failed_gate_does_not_fall_back_to_old_provisioning(self):
        with patch.object(target, "helper") as helper, patch.object(
                target.development_release, "runtime_secret_gate", side_effect=ValueError("unprepared")):
            with self.assertRaisesRegex(ValueError, "unprepared"):
                target.reconcile_external_state(None, {"formal_release": False})
            helper.assert_not_called()

    def test_formal_path_preserved(self):
        with patch.object(target, "helper") as helper, patch.object(
                target.development_release, "runtime_secret_gate") as gate:
            target.reconcile_external_state(None, {"formal_release": True})
            self.assertEqual([c.args[1] for c in helper.call_args_list], [
                "prepare-investment-broker-kind.sh", "prepare-investment-redis-acl-kind.sh",
                "reconcile-knowledge-active-retrieval-binding-kind.sh"])
            gate.assert_not_called()

    def test_development_migration_never_reenables_old_login(self):
        args = argparse.Namespace(timeout=30)
        for formal in (False, True):
            with self.subTest(formal=formal), patch.object(target, "run", return_value=Mock(returncode=0)), \
                    patch.object(target, "apply_file") as apply, patch.object(target, "set_formal_database_roles") as roles:
                target.run_migration(args, {"namespace": "app-platform-dev", "resource_app": "investment",
                                           "release_id": "test", "formal_release": formal})
                self.assertEqual(roles.call_count, int(formal))
                apply.assert_called_once_with(args, "10-migration.yaml")
