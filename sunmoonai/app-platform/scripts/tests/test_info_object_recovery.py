import hashlib
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("recovery", Path(__file__).resolve().parents[1] / "recover_info_objects_20260707.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class Client:
    def __init__(self, existing=False, fail_at=None):
        self.existing, self.fail_at, self.puts = existing, fail_at, []

    def list_object_versions(self, **kwargs):
        return {"Versions":[{}] if self.existing else [], "IsTruncated":False}

    def put_object(self, **kwargs):
        if len(self.puts) == self.fail_at:
            raise RuntimeError("synthetic timeout")
        self.puts.append(kwargs)
        return {"VersionId":"v" + str(len(self.puts))}

    def get_object(self, **kwargs):
        put = self.puts[-1]
        return {"Body":io.BytesIO(put["Body"]), "VersionId":kwargs["VersionId"],
                "ContentLength":len(put["Body"]), "Metadata":put["Metadata"]}


class RecoveryTest(unittest.TestCase):
    def setUp(self):
        self.bodies = {name:name.encode() for name in target.EXPECTED}
        expected = {name:(target.EXPECTED[name][0],len(body),hashlib.sha256(body).hexdigest())
                    for name,body in self.bodies.items()}
        self.patcher = patch.object(target, "EXPECTED", expected)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def test_condition_and_exact_version_verification(self):
        client, state = Client(), {"written":[], "in_flight":None}
        target.apply_missing(client, self.bodies, state)
        self.assertEqual(len(client.puts), 4)
        self.assertTrue(all(p["IfNoneMatch"] == "*" and p["Bucket"] == target.BUCKET
                            and p["Key"] in {target.PREFIX+n for n in target.EXPECTED} for p in client.puts))
        self.assertTrue(all(r["verified"] for r in state["written"]))
        self.assertIsNone(state["in_flight"])

    def test_drift_or_existing_object_stops_before_write(self):
        for existing, candidates in ((True,self.bodies), (False,self.bodies | {"raw.html":b"wrong"})):
            client = Client(existing=existing)
            with self.assertRaises(target.RecoveryError):
                target.apply_missing(client, candidates, {"written":[]})
            self.assertEqual(client.puts, [])

    def test_partial_failure_preserves_receipts_and_stops(self):
        client, state = Client(fail_at=1), {"written":[], "in_flight":None}
        with self.assertRaises(RuntimeError):
            target.apply_missing(client, self.bodies, state)
        self.assertEqual(len(client.puts), 1)
        self.assertEqual(len(state["written"]), 1)
        self.assertTrue(state["written"][0]["verified"])
        self.assertEqual(state["in_flight"], "clean.md")

    def test_database_references_must_match_all_four(self):
        rows = [{"bucket":target.BUCKET, "object_key":target.PREFIX+n, "version_id":None,
                 "artifact_type":kind, "size_bytes":size, "sha256":sha}
                for n,(kind,size,sha) in target.EXPECTED.items()]
        target.assert_references(rows)
        for changed in (rows[:-1], rows + rows[:1], [rows[0] | {"version_id":"new"}] + rows[1:]):
            with self.assertRaises(target.RecoveryError):
                target.assert_references(changed)
