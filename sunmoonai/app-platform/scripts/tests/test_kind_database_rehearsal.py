"""No cluster/Docker access; exercise backup safety invariants."""
import argparse
import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("rehearsal", Path(__file__).resolve().parents[1] / "kind_database_rehearsal.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class DatabaseRehearsalTest(unittest.TestCase):
    def test_private_exclusive_regular_output(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "backup"
            target.private_write(path, b"synthetic")
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            with self.assertRaises(FileExistsError):
                target.private_write(path, b"overwrite")
            link = Path(directory) / "link"
            link.symlink_to(path)
            with self.assertRaises(OSError):
                target.private_write(link, b"overwrite")
            self.assertEqual(path.read_bytes(), b"synthetic")

    def test_identifiers_are_bounded_not_quoted_input(self):
        self.assertEqual(target.quote_identifier("info_document"), '"info_document"')
        for name in ('public.x', 'x"; DROP DATABASE x', '../file', 'x'*64):
            with self.subTest(name=name), self.assertRaises(target.RehearsalError):
                target.quote_identifier(name)

    def test_cluster_must_match_uid_and_actual_kind_nodes(self):
        args = argparse.Namespace(cluster_uid="approved")
        def results(*_args, **_kwargs):
            return next(replies)
        for uid, provider, expected in (("approved", "kind://docker/kind", True),
                                        ("other", "kind://docker/kind", False),
                                        ("approved", "aws://node", False)):
            replies = iter((json.dumps({"metadata":{"uid":uid}}).encode(),
                            json.dumps({"items":[{"spec":{"providerID":provider}}]}).encode()))
            with patch.object(target, "kubectl", side_effect=results):
                if expected:
                    target.verify_kind(args)
                else:
                    with self.assertRaises(target.RehearsalError):
                        target.verify_kind(args)

    def test_fingerprint_projects_original_columns_and_sorts_rows(self):
        sql = target.row_fingerprint_sql("outbox_message", ["id", "payload"])
        self.assertIn('SELECT "id","payload" FROM public."outbox_message"', sql)
        self.assertIn('ORDER BY row_to_json(t)::text', sql)
        self.assertNotIn('DELETE', sql)

    def test_restore_does_not_create_privileged_roles(self):
        role = {"rolname":"info_backend_user", "rolsuper":False, "rolcreaterole":False,
                "rolcreatedb":False, "rolreplication":False, "rolbypassrls":False,
                "rolcanlogin":True, "rolinherit":True, "rolpassword":None,
                "rolconnlimit":-1, "rolvaliduntil":None}
        self.assertIn('PASSWORD NULL', target.role_sql([role]))
        for mutation in ({"rolsuper":True},{"rolpassword":"'; SELECT 1;--"},{"rolconnlimit":4}):
            with self.subTest(mutation=mutation), self.assertRaises(target.RehearsalError):
                target.role_sql([role | mutation])

    def test_catalog_normalization_preserves_constraint_semantics_and_acl(self):
        a = {"constraints":[{"definition":"CHECK (status = ANY ((ARRAY['pending'::character varying, 'published'::character varying])::text[]))"}],
             "acl":[{"acl":["a=r/owner","owner=arwd/owner"]}]}
        b = {"constraints":[{"definition":"CHECK (status = ANY (ARRAY[('pending'::character varying)::text, ('published'::character varying)::text]))"}],
             "acl":a["acl"]}
        self.assertEqual(target.comparable_catalog(a), target.comparable_catalog(b))
        self.assertIn(")::text[]", a["constraints"][0]["definition"])
        b["constraints"][0]["definition"] = b["constraints"][0]["definition"].replace("published", "deleted")
        self.assertNotEqual(target.comparable_catalog(a), target.comparable_catalog(b))
        self.assertEqual(target.comparable_catalog(a)["acl"], a["acl"])


if __name__ == "__main__":
    unittest.main()
