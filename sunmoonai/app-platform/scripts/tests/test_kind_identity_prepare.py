import base64
import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import kind_identity_prepare as target


class IdentityPreparationTest(unittest.TestCase):
    def plan(self):
        names = {r: "info-backend-" + r + "-v2" for r in target.development_release.RUNTIME_ROLES}
        users = [{"name": name, "tags": [], "hashing_algorithm": "rabbit_password_hashing_sha256",
                  "password_hash": target.broker.password_hash(str(i) * 48, b"salt")}
                 for i, name in enumerate(names.values(), 1)]
        live = target.broker.broker_plan("info-development", "info.admin.default", names)
        live["permissions"] = []
        plan = target.broker.preparation_plan(live, live, vhost="info-development", queue="info.admin.default", principals=names, users=users)
        original = {"metadata": {"uid": "same-uid", "resourceVersion": "123"},
                    "data": {"load_definition.json": target.b64(target.encoded(live)), "unrelated": "unchanged"}}
        return {"new_names": list(names.values()), "vhost": "info-development", "operations": plan["operations"],
                "runtime_secret": {"synthetic": True}, "startup_definitions": plan["startup"],
                "startup_patch": target.startup_patch(original, plan["startup"])}

    def test_cas_only_replaces_definition_key(self):
        patch = self.plan()["startup_patch"]
        self.assertEqual([op["op"] for op in patch], ["test", "test", "test", "replace"])
        self.assertEqual(patch[0]["path"], "/metadata/uid")
        self.assertEqual(patch[1]["path"], "/metadata/resourceVersion")
        self.assertEqual(patch[-1]["path"], "/data/load_definition.json")

    def ports(self, plan):
        bodies = {op["path"]: op["body"] for op in plan["operations"]}
        def api(method, path, body=None, missing=False):
            if missing:
                return None
            if method == "PUT":
                return None
            if path.endswith("/permissions"):
                return [{"vhost": plan["vhost"]}]
            return bodies[path]
        return {"api": Mock(side_effect=api), "create_secret": Mock(return_value={}), "patch_secret": Mock(return_value={}),
                "get_secret": Mock(return_value={"data": {"load_definition.json": target.b64(target.encoded(plan["startup_definitions"]))}}),
                "journal": Mock()}

    def test_success_is_six_narrow_puts_and_no_retirement(self):
        plan = self.plan()
        ports = self.ports(plan)
        target.apply_preparation(plan, **ports)
        puts = [call for call in ports["api"].call_args_list if call.args[0] != "GET"]
        self.assertEqual(len(puts), 6)
        self.assertTrue(all(c.args[0] == "PUT" for c in puts))
        self.assertEqual(ports["journal"].call_args_list[-1].args[1],
                         {"database_activated": False, "old_identities_retired": False})

    def test_each_earlier_failure_stops_later_writes(self):
        for failed in ("create_secret", "patch_secret", "get_secret", "journal"):
            with self.subTest(failed=failed):
                plan = self.plan()
                ports = self.ports(plan)
                ports[failed].side_effect = RuntimeError("private failure")
                with self.assertRaises(RuntimeError):
                    target.apply_preparation(plan, **ports)
                self.assertFalse(any(c.args[0] != "GET" for c in ports["api"].call_args_list))

    def test_name_conflict_does_not_create_secret_or_patch(self):
        plan = self.plan()
        ports = self.ports(plan)
        ports["api"].side_effect = None
        ports["api"].return_value = {"name": "conflict"}
        with self.assertRaisesRegex(target.common.RehearsalError, "name_conflict"):
            target.apply_preparation(plan, **ports)
        ports["create_secret"].assert_not_called()
        ports["patch_secret"].assert_not_called()

    def test_secret_has_distinct_owned_role_urls(self):
        passwords = {kind: {r: str(i) * 48 for i, r in enumerate(target.development_release.RUNTIME_ROLES, 1 + offset)}
                     for kind, offset in (("database", 0), ("broker", 3))}
        for app in target.common.APPS:
            secret = target.runtime_secret(app, "test", passwords)
            self.assertEqual(len(secret["data"]), 6)
            self.assertEqual(secret["metadata"]["namespace"], "app-platform-dev")

    def test_private_reader_rejects_public_files_and_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / "plan"
            target.common.private_write(file, b"synthetic")
            self.assertEqual(target.private_read(file), b"synthetic")
            link = root / "link"
            link.symlink_to(file)
            with self.assertRaises(OSError):
                target.private_read(link)
            file.chmod(0o644)
            with self.assertRaises(target.common.RehearsalError):
                target.private_read(file)
