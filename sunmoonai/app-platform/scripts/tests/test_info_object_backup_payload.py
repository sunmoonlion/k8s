import hashlib
import importlib.util
import io
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("objects", Path(__file__).resolve().parents[1] / "info_object_backup_payload.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class ObjectBackupTest(unittest.TestCase):
    def row(self):
        return {"bucket":"info", "object_key":"info/original/a", "version_id":"v1",
                "sha256":hashlib.sha256(b"abc").hexdigest(), "size_bytes":3}

    def test_only_approved_bucket_prefix_and_bounded_size(self):
        row = self.row()
        target.validate_reference(row, "info")
        for change in ({"bucket":"other"}, {"object_key":"other/a"},
                       {"size_bytes":target.MAX_OBJECT_BYTES+1}, {"sha256":"bad"}):
            with self.assertRaises(ValueError):
                target.validate_reference(row | change, "info")

    def client(self, body=b"abc", version="v1"):
        class Client:
            def get_object(self, **params):
                self.params = params
                self.stream = io.BytesIO(body)
                return {"Body":self.stream, "VersionId":version, "ContentLength":len(body)}
        return Client()

    def test_exact_version_never_falls_back(self):
        client = self.client()
        body, details = target.fetch_reference(client, self.row())
        self.assertEqual(client.params["VersionId"], "v1")
        self.assertEqual(body, b"abc")
        self.assertTrue(client.stream.closed)
        self.assertFalse(details["reference_was_unversioned"])
        for client in (self.client(version="v2"), self.client(body=b"xyz"), self.client(body=b"a")):
            with self.assertRaises(ValueError):
                target.fetch_reference(client, self.row())
            self.assertTrue(client.stream.closed)

    def test_unversioned_still_requires_recorded_content(self):
        row = self.row() | {"version_id":None}
        client = self.client(version="latest")
        _, details = target.fetch_reference(client, row)
        self.assertNotIn("VersionId", client.params)
        self.assertIsNone(row["version_id"])
        self.assertTrue(details["reference_was_unversioned"])
        with self.assertRaises(ValueError):
            target.fetch_reference(self.client(body=b"xyz"), row)
