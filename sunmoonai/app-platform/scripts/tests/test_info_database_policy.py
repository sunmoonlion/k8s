"""Pure Info overlay gate; collected by the existing platform unittest suite."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "info-app/deployment"))
import info_database_policy as policy

PRINCIPALS = {role: "info_test_" + role for role in policy.common.ROLES}


class InfoDatabasePolicyTests(unittest.TestCase):
    def compile(self, **kwargs):
        return policy.info_grants(
            **{
                "schema": "public",
                "principals": PRINCIPALS,
                "columns": policy.TABLE_COLUMNS,
                **kwargs,
            }
        )

    def test_preserves_common_prefix_and_domain_boundary(self):
        expected = policy.common.template_grants(
            schema="public", principals=PRINCIPALS, columns=policy.common.TABLE_COLUMNS
        )
        statements = self.compile()
        self.assertEqual(statements[: len(expected)], expected)
        self.assertEqual(len(policy.TABLE_COLUMNS), 15)
        for sql in statements[len(expected) :]:
            self.assertNotIn("legacy", sql)
            self.assertNotIn("scheduler", sql)
            self.assertNotIn("migration", sql)
            self.assertNotIn("DELETE", sql)
            self.assertNotIn("ALL ", sql)
            self.assertTrue(any(f'."{t}" ' in sql for t in policy.ACTIVE_TABLES))

    def test_schema_drift_fails_closed(self):
        for table in policy.TABLE_COLUMNS:
            with self.subTest(table=table):
                changed = dict(policy.TABLE_COLUMNS)
                changed[table] = changed[table] | {"unreviewed"}
                with self.assertRaises(policy.common.PolicyError):
                    self.compile(columns=changed)
                changed = dict(policy.TABLE_COLUMNS)
                del changed[table]
                with self.assertRaises(policy.common.PolicyError):
                    self.compile(columns=changed)
        with self.assertRaises(policy.common.PolicyError):
            self.compile(
                columns={**policy.TABLE_COLUMNS, "new_table": frozenset({"id"})}
            )

    def test_invalid_principals_and_identifiers(self):
        for names in (
            {},
            {**PRINCIPALS, "worker": PRINCIPALS["api"]},
            {**PRINCIPALS, "api": 'injection";'},
        ):
            with self.assertRaises(policy.common.PolicyError):
                self.compile(principals=names)
        with self.assertRaises(policy.common.PolicyError):
            self.compile(schema='public";')

    def test_column_grants_only_and_identity_not_mutable(self):
        for updates in (policy.API_UPDATES, policy.WORKER_UPDATES):
            for table, names in updates.items():
                columns = set(names.split())
                self.assertLessEqual(columns, policy.DOMAIN_COLUMNS[table])
                self.assertTrue(
                    columns.isdisjoint(
                        {
                            "id",
                            "canonical_identity",
                            "canonical_url",
                            "target_dataset",
                            "target_app",
                            "write_protocol_version",
                            "created_at",
                        }
                    )
                )
        for sql in self.compile():
            if any(f'."{t}" ' in sql for t in policy.ACTIVE_TABLES) and sql.startswith(
                ("GRANT INSERT", "GRANT UPDATE")
            ):
                self.assertIn(" (", sql)


if __name__ == "__main__":
    unittest.main()
