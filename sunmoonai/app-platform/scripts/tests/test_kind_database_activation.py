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


class UpgradeTest(unittest.TestCase):
    def upgrade_release(self):
        bundle = SCRIPTS.parent / "info-app/deployment/bundle/release.json"
        release = json.loads(bundle.read_bytes())
        release["release_id"] = "kind-next"
        release["migration_head"] = "20260924_0009"
        return release

    def preparation(self, folder, *, activated=True):
        root = Path(folder)
        plan = {"app": "info", "release_id": "kind-b7-20260919", "release_sha256": "moved"}
        raw = target.preparation.encoded(plan)
        digest = hashlib.sha256(raw).hexdigest()
        target.common.private_write(root / "plan.private.json", raw)
        target.common.private_write(root / "applied.json", target.preparation.encoded(
            {"applied": True, "live_amqp_login_verified": True, "plan_sha256": digest}))
        if activated:
            (root / "database-activation").mkdir(mode=0o700)
            target.common.private_write(root / "database-activation" / "complete.json",
                                        target.preparation.encoded({"release_id": "kind-b7-20260919"}))
        return root, digest

    def test_upgrade_reuses_the_applied_preparation_of_the_named_release(self):
        with tempfile.TemporaryDirectory() as folder:
            root, digest = self.preparation(folder)
            release = self.upgrade_release()
            release["runtime_identity_upgrade"] = {"prepared_release_id": "kind-b7-20260919",
                                                   "preparation_plan_sha256": digest}
            target.development_release.validate(release)
            args = argparse.Namespace(identity_preparation=root)
            self.assertEqual(target.load_preparation(args, release)[1]["release_id"], "kind-b7-20260919")
            for broken in ({"prepared_release_id": "kind-other", "preparation_plan_sha256": digest},
                           {"prepared_release_id": "kind-b7-20260919", "preparation_plan_sha256": "0" * 64}):
                with self.subTest(broken=broken), self.assertRaisesRegex(target.common.RehearsalError, "release_mismatch"):
                    target.load_preparation(args, release | {"runtime_identity_upgrade": broken})
            # without the upgrade declaration the moved bundle digest is refused as before
            with self.assertRaisesRegex(target.common.RehearsalError, "release_mismatch"):
                target.load_preparation(args, self.upgrade_release())
        with tempfile.TemporaryDirectory() as folder:
            root, digest = self.preparation(folder, activated=False)
            release = self.upgrade_release()
            release["runtime_identity_upgrade"] = {"prepared_release_id": "kind-b7-20260919",
                                                   "preparation_plan_sha256": digest}
            with self.assertRaisesRegex(target.common.RehearsalError, "release_mismatch"):
                target.load_preparation(argparse.Namespace(identity_preparation=root), release)

    def test_upgrade_declaration_is_validated(self):
        release = self.upgrade_release()
        for bad in ({"prepared_release_id": "kind-next", "preparation_plan_sha256": "a" * 64},
                    {"prepared_release_id": "kind-b7", "preparation_plan_sha256": "short"},
                    {"prepared_release_id": "kind-b7"}, "kind-b7"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                target.development_release.validate(release | {"runtime_identity_upgrade": bad})
        release["runtime_identity_upgrade"] = {"prepared_release_id": "kind-b7", "preparation_plan_sha256": "a" * 64}
        target.development_release.validate(release)
        with self.assertRaises(ValueError):
            target.development_release.validate({k: v for k, v in release.items() if k != "runtime_identity_mode"})

    def test_upgrade_runs_grants_only_and_records_intent(self):
        with tempfile.TemporaryDirectory() as folder:
            root, digest = self.preparation(folder)
            release = self.upgrade_release()
            release["runtime_identity_upgrade"] = {"prepared_release_id": "kind-b7-20260919",
                                                   "preparation_plan_sha256": digest}
            applied = {"plan_sha256": digest}
            inventory = {"marker": 1, "activity": []}
            calls = []
            sql = "BEGIN;\nSET LOCAL search_path=pg_catalog;\nGRANT SELECT ON TABLE public.x TO info_backend_api;\nCOMMIT;\n"
            with patch.object(target, "compile_upgrade", return_value=(sql, 'public."x"')) as compile_, \
                 patch.object(target, "admin_sql", side_effect=lambda ctx, app, text: calls.append(text) or json.dumps(inventory)), \
                 patch.object(target, "verify_logins", return_value=7) as logins, \
                 patch.object(target, "activation_sources", return_value={"s": "1"}):
                target.upgrade_identities(None, root, applied, release, "info", {"api": "x" * 48},
                                          json.dumps(inventory), inventory)
                compile_.assert_called_once_with("info", "20260924_0009", inventory)
                self.assertNotIn("CREATE ROLE", calls[0])
                self.assertLess(calls[0].index("LOCK TABLE"), calls[0].index("GRANT "))
                logins.assert_called_once()
                complete = json.loads((root / "database-upgrade-kind-next" / "complete.json").read_text())
                self.assertTrue(complete["grants_only"])
                intent = json.loads((root / "database-upgrade-kind-next" / "intent.json").read_text())
                self.assertEqual(intent["upgrade_of"], "kind-b7-20260919")
                # a second run re-probes only when nothing changed
                target.upgrade_identities(None, root, applied, release, "info", {"api": "x" * 48},
                                          json.dumps(inventory), inventory)
                self.assertEqual(logins.call_count, 2)
                self.assertEqual(len(calls), 2)  # transaction + catalog-after, no second transaction
                with self.assertRaisesRegex(target.common.RehearsalError, "drifted"):
                    target.upgrade_identities(None, root, applied, release, "info", {"api": "x" * 48},
                                              "{}", {"marker": 2, "activity": []})
