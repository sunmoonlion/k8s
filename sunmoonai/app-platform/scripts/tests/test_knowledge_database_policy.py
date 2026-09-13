"""Pure Knowledge policy checks, collected by the normal platform suite."""

import sys
import unittest
from pathlib import Path

sys.path.insert(
    0, str(Path(__file__).resolve().parents[2] / "knowledge-app/deployment")
)
import knowledge_database_policy as policy

PRINCIPALS = {role: "knowledge_test_" + role for role in policy.common.ROLES}


class KnowledgeDatabasePolicyTests(unittest.TestCase):
    def compile(self, **kwargs):
        return policy.knowledge_grants(
            **{
                "schema": "public",
                "principals": PRINCIPALS,
                "columns": policy.TABLE_COLUMNS,
                **kwargs,
            }
        )

    def test_common_prefix_and_domain_boundary(self):
        base = policy.common.template_grants(
            schema="public", principals=PRINCIPALS, columns=policy.common.TABLE_COLUMNS
        )
        statements = self.compile()
        self.assertEqual(statements[: len(base)], base)
        self.assertEqual(len(policy.TABLE_COLUMNS), 10)
        for sql in statements[len(base) :]:
            for forbidden in ("DELETE", "TRUNCATE", "ALL ", "scheduler", "migration"):
                self.assertNotIn(forbidden, sql)
            self.assertTrue(
                any(f'."{table}" ' in sql for table in policy.DOMAIN_COLUMNS)
            )
            if sql.startswith(("GRANT INSERT", "GRANT UPDATE")):
                self.assertIn(" (", sql)
            if "knowledge_provider_operation" in sql:
                self.assertNotIn(PRINCIPALS["api"], sql)

    def test_drift_fails_closed(self):
        for table in policy.TABLE_COLUMNS:
            for added in (False, True):
                with self.subTest(table=table, added=added):
                    columns = dict(policy.TABLE_COLUMNS)
                    if added:
                        columns[table] = columns[table] | {"unknown"}
                    else:
                        del columns[table]
                    with self.assertRaises(policy.common.PolicyError):
                        self.compile(columns=columns)
        with self.assertRaises(policy.common.PolicyError):
            self.compile(
                columns={**policy.TABLE_COLUMNS, "future_table": frozenset({"id"})}
            )

    def test_invalid_principals_and_schema(self):
        for principals in (
            {},
            {**PRINCIPALS, "worker": PRINCIPALS["api"]},
            {**PRINCIPALS, "api": 'bad";'},
        ):
            with self.assertRaises(policy.common.PolicyError):
                self.compile(principals=principals)
        with self.assertRaises(policy.common.PolicyError):
            self.compile(schema='public";')

    def test_updates_do_not_change_source_identity_or_intent(self):
        for names, table in (
            (policy.JOB_UPDATES, "knowledge_ingestion_job"),
            (policy.VERSION_UPDATES, "knowledge_document_version"),
        ):
            self.assertLessEqual(set(names), policy.DOMAIN_COLUMNS[table])
            self.assertTrue(
                set(names).isdisjoint(
                    {
                        "id",
                        "source_app",
                        "source_document_id",
                        "source_document_version_id",
                        "dataset_key",
                        "target_dataset",
                        "payload",
                        "idempotency_key",
                        "source_artifact_refs",
                        "created_at",
                    }
                )
            )


if __name__ == "__main__":
    unittest.main()
