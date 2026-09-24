"""Recovering the preparation record re-proves the live identities; it never writes to the cluster."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import kind_identity_recover as target


def runtime_secret(app="info"):
    data = {}
    for role in target.development_release.RUNTIME_ROLES:
        data[f"{role.upper()}_DATABASE_URL"] = (
            f"postgresql+asyncpg://{app}_backend_{role}:{role * 32}"
            f"@postgresql-sunmoonai.data-platform-dev.svc.cluster.local:5432/{app}_admin")
        data[f"{role.upper()}_CELERY_BROKER_URL"] = (
            f"amqp://{app}-backend-{role}-v2:{(role + 'broker') * 32}"
            f"@rabbitmq-sunmoonai.messaging-platform-dev.svc.cluster.local:5672/{app}-development")
    return {"metadata": {"name": app + "-backend-runtime", "namespace": "app-platform-dev"},
            "data": {key: base64.b64encode(value.encode()).decode() for key, value in data.items()}}


def live_secret(app="info", release_id="kind-b7-20260919"):
    secret = runtime_secret(app)
    secret["metadata"]["uid"] = "secret-uid-1"
    secret["metadata"]["annotations"] = {"sunmoonai.com/release-id": release_id,
                                         target.preparation.MARKER: "prepared-not-database-activated"}
    return secret


def unmarked_secret():
    secret = live_secret()
    del secret["metadata"]["annotations"][target.preparation.MARKER]
    return secret


def inventory(app="info", *, old_login=False, runtime_login=True):
    names = [(app + "_backend_" + r, runtime_login) for r in ("api", "worker", "scheduler")]
    names += [(app + "_backend_user_migration", True), (app + "_backend_user", old_login)]
    return {"roles": [{"name": n, "login": l} for n, l in names], "memberships": [],
            "revisions": ["20260911_0007"], "activity": []}


class RecoverTest(unittest.TestCase):
    def args(self, folder):
        return argparse.Namespace(app="info", kubeconfig=Path("/kube"), cluster_uid="kind-uid",
                                  prepared_release_id="kind-b7-20260919", output=Path(folder) / "recovered")

    def test_writes_a_reusable_record_only_after_every_live_proof(self):
        with tempfile.TemporaryDirectory() as folder, \
             patch.object(target.common, "verify_kind"), \
             patch.object(target.common, "get", return_value=live_secret()), \
             patch.object(target.activation, "admin_sql", return_value=json.dumps(inventory())), \
             patch.object(target.activation, "verify_logins", return_value=18) as logins, \
             patch.object(target.preparation, "verify_amqp", return_value={"authenticated_roles": 3}) as amqp, \
             patch.object(target.preparation, "source_hashes", return_value={"x": "1"}), \
             patch("subprocess.run") as run:
            run.return_value.returncode = 1  # output parent is not inside a git repository
            summary = target.recover(self.args(folder))
            root = Path(folder) / "recovered"
            plan_raw = target.preparation.private_read(root / "plan.private.json")
            plan = json.loads(plan_raw)
            applied = json.loads(target.preparation.private_read(root / "applied.json"))
            self.assertEqual(applied["plan_sha256"], hashlib.sha256(plan_raw).hexdigest())
            self.assertEqual(summary["plan_sha256"], applied["plan_sha256"])
            self.assertTrue(applied["applied"] and applied["live_amqp_login_verified"] and applied["recovered_from_live"])
            self.assertTrue(applied["old_identities_retired"])
            self.assertEqual(plan["release_id"], "kind-b7-20260919")
            self.assertEqual(plan["runtime_secret"]["data"], live_secret()["data"])
            reservation = json.loads(target.preparation.private_read(root / "reserve-runtime-secret-result.private.json"))
            self.assertEqual(reservation["metadata"]["uid"], "secret-uid-1")
            complete = json.loads(target.preparation.private_read(root / "database-activation" / "complete.json"))
            self.assertEqual(complete["release_id"], "kind-b7-20260919")
            logins.assert_called_once()
            amqp.assert_called_once()
            # the record is accepted by the upgrade route
            release = {"logical_app": "info", "runtime_identity_upgrade": {
                "prepared_release_id": "kind-b7-20260919", "preparation_plan_sha256": applied["plan_sha256"]}}
            target.activation.load_preparation(argparse.Namespace(identity_preparation=root), release)
            # no cluster write: only get/exec reads and probes were used
            self.assertFalse(any(c.args and c.args[0] and str(c.args[0][0]).startswith("kubectl") for c in run.call_args_list))

    def test_refuses_wrong_release_missing_identities_git_dir_and_writes_nothing(self):
        cases = [
            ("secret", live_secret(release_id="kind-other"), inventory(), "release_mismatch"),
            ("secret", unmarked_secret(), inventory(), "marker_mismatch"),
            ("inventory", live_secret(), inventory(runtime_login=False), "cannot_login"),
            ("inventory", live_secret(), {**inventory(), "roles": inventory()["roles"][3:]}, "not_activated"),
        ]
        for kind, secret, catalog, reason in cases:
            with tempfile.TemporaryDirectory() as folder, self.subTest(reason=reason), \
                 patch.object(target.common, "verify_kind"), \
                 patch.object(target.common, "get", return_value=secret), \
                 patch.object(target.activation, "admin_sql", return_value=json.dumps(catalog)), \
                 patch.object(target.activation, "verify_logins") as logins, \
                 patch.object(target.preparation, "verify_amqp") as amqp, \
                 patch("subprocess.run") as run:
                run.return_value.returncode = 1
                with self.assertRaisesRegex(target.common.RehearsalError, reason):
                    target.recover(self.args(folder))
                self.assertFalse((Path(folder) / "recovered").exists())
                logins.assert_not_called()
                amqp.assert_not_called()
        with tempfile.TemporaryDirectory() as folder, patch("subprocess.run") as run:
            run.return_value.returncode = 0  # inside a git repository
            with self.assertRaisesRegex(target.common.RehearsalError, "private_output_path_required"):
                target.recover(self.args(folder))


if __name__ == "__main__":
    unittest.main()
