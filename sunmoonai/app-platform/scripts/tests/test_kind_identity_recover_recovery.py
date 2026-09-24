import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest


SCRIPT_DIR = Path(__file__).resolve().parent
if not (SCRIPT_DIR / "kind_identity_recover.py").exists():
    SCRIPT_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPT = SCRIPT_DIR / "kind_identity_recover.py"
spec = importlib.util.spec_from_file_location("kind_identity_recover", SCRIPT)
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class Common:
    @staticmethod
    def encoded(value):
        return json.dumps(value, ensure_ascii=False, indent=2, default=str) + "\n"

    @staticmethod
    def private_write(path, data):
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data.encode() if isinstance(data, str) else data)


class Preparation:
    @staticmethod
    def source_hashes():
        return {"fixture": "a" * 64}


class DevelopmentRelease:
    RUNTIME_ROLES = ("api", "worker", "scheduler")


class Tests(unittest.TestCase):
    def test_role_inventory_requires_three_login_roles_and_retired_legacy(self):
        names = ("api", "worker", "scheduler")
        roles = [{"name": "investment_backend_" + role, "login": True,
                  "inherit": False, "super": False, "create_db": False,
                  "create_role": False, "replication": False, "bypass_rls": False}
                 for role in names]
        roles += [
            {"name": "investment_backend_user", "login": False},
            {"name": "investment_backend_user_migration", "login": True,
             "super": False, "create_db": False, "create_role": False,
             "replication": False, "bypass_rls": False},
        ]
        inventory = {"roles": roles, "memberships": []}
        self.assertEqual(target.validate_database_roles(inventory, "investment"),
                         {"runtime_roles_login": 3, "old_login_disabled": True})
        inventory["roles"][3]["login"] = True
        with self.assertRaisesRegex(ValueError, "runtime_role_state_mismatch"):
            target.validate_database_roles(inventory, "investment")

    def test_recovered_receipts_match_deployment_loader(self):
        modules = (DevelopmentRelease, None, Common, Preparation)
        args = type("Args", (), {"app": "investment", "cluster_uid": "fixture-cluster"})()
        secret = {"metadata": {"uid": "live-secret-uid"}, "data": {"opaque": "never printed"}}
        release = {"logical_app": "investment", "release_id": "kind-wb-20260925"}
        inventory = {"revisions": ["20260924_0008"]}
        observed = {
            "secret": secret,
            "release_id": "kind-b7-20260919",
            "secret_uid": "live-secret-uid",
            "release": release,
            "inventory": inventory,
            "role_evidence": {"runtime_roles_login": 3, "old_login_disabled": True},
            "pg_probe_count": 18,
            "amqp_proof": {"authenticated_roles": 3, "foreign_vhost_denied": 3,
                           "messages_touched": False},
        }
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "private-output"
            root.mkdir(mode=0o700)
            digest = target.write_receipts(root, args, observed, modules)
            raw = (root / "plan.private.json").read_bytes()
            plan = json.loads(raw)
            applied = json.loads((root / "applied.json").read_text())
            complete = json.loads((root / "database-activation/complete.json").read_text())
            self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
            self.assertEqual(applied["plan_sha256"], digest)
            self.assertEqual(plan["release_id"], complete["release_id"])
            self.assertTrue(plan["recovered_from_live"])
            self.assertTrue(applied["live_amqp_login_verified"])
            self.assertTrue(complete["old_login_disabled"])
            for path in (root / "plan.private.json", root / "applied.json",
                         root / "database-activation/complete.json"):
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertNotIn(b"never printed", (root / "recovery-summary.json").read_bytes())


if __name__ == "__main__":
    unittest.main()
