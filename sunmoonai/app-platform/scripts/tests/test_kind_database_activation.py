"""Post-migration activation must complete before any new runtime starts."""
import argparse
from contextlib import ExitStack
import importlib.util
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import kind_database_activation as target


class ActivationTest(unittest.TestCase):
    def test_formal_release_does_not_use_kind_bootstrap(self):
        with patch.object(target.development_release, "guard") as guard:
            target.activate(None, {"formal_release": True}, Mock())
            guard.assert_not_called()

    def test_no_preparation_fails_closed(self):
        with self.assertRaisesRegex(target.common.RehearsalError, "directory_required"):
            target.load_preparation(argparse.Namespace(), {"logical_app": "info"})

    def test_preparation_requires_exact_release_digest_and_live_auth_proof(self):
        bundle = SCRIPTS.parent / "info-app/deployment/bundle/release.json"
        release = json.loads(bundle.read_bytes())
        plan = {"app": "info", "release_id": release["release_id"],
                "release_sha256": hashlib.sha256(bundle.read_bytes()).hexdigest()}
        raw = target.preparation.encoded(plan)
        applied = {"applied": True, "live_amqp_login_verified": True, "plan_sha256": hashlib.sha256(raw).hexdigest()}
        for changes in ({}, {"applied": False}, {"live_amqp_login_verified": False}, {"plan_sha256": "wrong"}):
            with tempfile.TemporaryDirectory() as folder, self.subTest(changes=changes):
                root = Path(folder)
                target.common.private_write(root / "plan.private.json", raw)
                target.common.private_write(root / "applied.json", target.preparation.encoded(applied | changes))
                args = argparse.Namespace(identity_preparation=root)
                if changes:
                    with self.assertRaisesRegex(target.common.RehearsalError, "release_mismatch"):
                        target.load_preparation(args, release)
                else:
                    self.assertEqual(target.load_preparation(args, release)[1], plan)
                    with self.assertRaisesRegex(target.common.RehearsalError, "release_mismatch"):
                        target.load_preparation(args, release | {"release_id": "different"})

    def test_inventory_guard_is_before_role_creation_in_same_transaction(self):
        sql = "BEGIN;\nSET LOCAL search_path=pg_catalog;\nCREATE ROLE synthetic;\nCOMMIT;\n"
        result = target.guarded_transaction("info", "{}", sql, 'public."outbox_message"')
        self.assertLess(result.index("LOCK TABLE"), result.index("CREATE ROLE"))
        self.assertLess(result.index("activation inventory changed"), result.index("CREATE ROLE"))
        self.assertTrue(result.startswith("BEGIN;"))
        self.assertTrue(result.endswith("COMMIT;\n"))
        with self.assertRaisesRegex(target.common.RehearsalError, "layout_changed"):
            target.guarded_transaction("info", "{}", "BEGIN; COMMIT;", "x")

    def test_all_entries_stop_at_failed_migration_or_activation(self):
        for app in ("info", "knowledge", "investment"):
            spec = importlib.util.spec_from_file_location(app + "_activation_entry",
                SCRIPTS.parent / (app + "-app/deployment/deploy.py"))
            entry = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(entry)
            for failure in (None, "migration", "activation"):
                with self.subTest(app=app, failure=failure), ExitStack() as stack:
                    events = []
                    for name in ("external_secret_gate", "reconcile_external_state"):
                        if hasattr(entry, name):
                            stack.enter_context(patch.object(entry, name))
                    stack.enter_context(patch.object(entry, "run"))
                    stack.enter_context(patch.object(entry, "apply_file", side_effect=lambda a, name: events.append(name)))
                    def phase(name):
                        def call(*args):
                            events.append(name)
                            if name == failure:
                                raise target.common.RehearsalError("synthetic")
                        return call
                    stack.enter_context(patch.object(entry, "run_migration", side_effect=phase("migration")))
                    stack.enter_context(patch.object(entry.kind_database_activation, "activate", side_effect=phase("activation")))
                    data = {"namespace": "app-platform-dev", "release_id": "synthetic",
                            "deployment_replicas": {}, "legacy_deployments": []}
                    if failure:
                        with self.assertRaises(target.common.RehearsalError):
                            entry.apply(argparse.Namespace(timeout=1), data)
                        self.assertNotIn("20-runtime.yaml", events)
                        if failure == "migration":
                            self.assertNotIn("activation", events)
                    else:
                        entry.apply(argparse.Namespace(timeout=1), data)
                        self.assertLess(events.index("migration"), events.index("activation"))
                        self.assertLess(events.index("activation"), events.index("20-runtime.yaml"))
