"""catalog_diff reports only the differing catalog entries, keyed by object, after the proven normalization."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import catalog_diff as target


def catalog(acl=None, default=("x=r/o",)):
    return {"tables": [{"tablename": "t", "tableowner": "o"}],
            "columns": [{"table_name": "t", "column_name": "id", "ordinal_position": 1, "data_type": "uuid",
                         "udt_name": "uuid", "is_nullable": "NO", "column_default": None}],
            "constraints": [{"table_name": "t", "name": "t_pkey", "definition": "PRIMARY KEY (id)"}],
            "indexes": [], "triggers": [],
            "acl": [{"relname": "t", "relkind": "r", "acl": acl, "owner": "o"}],
            "default_acl": [{"creator": "o", "schema": "public", "kind": "r", "acl": list(default)}]}


class Test(unittest.TestCase):
    def test_identical_is_empty_and_acl_change_is_named(self):
        self.assertEqual(target.diff(catalog(), catalog()), {})
        result = target.diff({"catalog": catalog(acl=["o=arwdDxt/o"])}["catalog"], catalog(acl=None))
        self.assertEqual(sorted(result), ["acl"])
        self.assertEqual(result["acl"]["changed"]["t"]["restored"]["acl"], None)
        self.assertEqual(result["acl"]["changed"]["t"]["baseline"]["acl"], ["o=arwdDxt/o"])

    def test_cli_reads_baseline_wrapper_and_exit_codes(self):
        with tempfile.TemporaryDirectory() as d:
            base, rest = Path(d) / "baseline.private.json", Path(d) / "restore-1-catalog.private.json"
            base.write_text(json.dumps({"catalog": catalog(), "rows": {"t": {"count": 1, "md5": "x"}}}))
            rest.write_text(json.dumps(catalog(default=("x=r/o", "y=r/o"))))
            self.assertEqual(target.main(["x", str(base), str(rest)]), 1)
            rest.write_text(json.dumps(catalog()))
            self.assertEqual(target.main(["x", str(base), str(rest)]), 0)


if __name__ == "__main__":
    unittest.main()
