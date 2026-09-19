import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("restore", Path(__file__).resolve().parents[1] / "info_object_restore_payload.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class RestoreTest(unittest.TestCase):
    def row(self, version="v1", unversioned=False):
        return {"bucket":"development-info-originals", "object_key":"info/original/a",
                "resolved_version_id":version, "reference_was_unversioned":unversioned,
                "sha256":"a"*64, "size_bytes":4, "metadata":{}, "content_type":"text/plain"}

    def manifest(self, rows):
        return {"kind":"info-object-backup-v1", "live_writes":False, "references":rows}

    def test_shared_reference_restores_one_exact_version(self):
        plan = target.restore_plan(self.manifest([self.row(), self.row(unversioned=True)]))
        self.assertEqual(len(plan), 1)

    def test_captured_latest_is_restored_last(self):
        plan = target.restore_plan(self.manifest([self.row(unversioned=True), self.row("z")]))
        self.assertEqual([identity[2] for identity,row in plan], ["z", "v1"])

    def test_conflicting_snapshots_and_foreign_scope_fail_closed(self):
        for rows in ([self.row(unversioned=True), self.row("v2", True)],
                     [self.row(), self.row() | {"sha256":"b"*64}],
                     [self.row() | {"bucket":"another"}],
                     [self.row() | {"object_key":"other/a"}]):
            with self.assertRaises(ValueError):
                target.restore_plan(self.manifest(rows))
