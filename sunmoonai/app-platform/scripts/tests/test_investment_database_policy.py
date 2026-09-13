"""Normal platform suite: frozen Investment overlay and common grant boundary."""

import sys
import unittest
from pathlib import Path

sys.path.insert(
    0, str(Path(__file__).resolve().parents[2] / "investment-app/deployment")
)
import investment_database_policy as policy

PRINCIPALS = {role: "investment_test_" + role for role in policy.common.ROLES}


class InvestmentDatabasePolicyTests(unittest.TestCase):
    def compile(self, **kwargs):
        return policy.investment_grants(
            **{
                "schema": "public",
                "principals": PRINCIPALS,
                "columns": policy.TABLE_COLUMNS,
                **kwargs,
            }
        )

    def test_common_prefix_and_excluded_tables(self):
        base = policy.common.template_grants(
            schema="public", principals=PRINCIPALS, columns=policy.common.TABLE_COLUMNS
        )
        statements = self.compile()
        self.assertEqual(statements[: len(base)], base)
        self.assertEqual(len(policy.TABLE_COLUMNS), 18)
        for sql in statements[len(base) :]:
            for forbidden in (
                "DELETE",
                "TRUNCATE",
                "ALL ",
                "scheduler",
                "migration",
                "legacy",
            ):
                self.assertNotIn(forbidden, sql)
            self.assertTrue(any(f'."{t}" ' in sql for t in policy.DOMAIN_COLUMNS))
            if sql.startswith(("GRANT INSERT", "GRANT UPDATE")):
                self.assertIn(" (", sql)

    def test_inventory_drift_denied(self):
        for table in policy.TABLE_COLUMNS:
            for added in (False, True):
                with self.subTest(table=table, added=added):
                    columns = dict(policy.TABLE_COLUMNS)
                    if added:
                        columns[table] = columns[table] | {"unreviewed"}
                    else:
                        del columns[table]
                    with self.assertRaises(policy.common.PolicyError):
                        self.compile(columns=columns)
        with self.assertRaises(policy.common.PolicyError):
            self.compile(
                columns={**policy.TABLE_COLUMNS, "future_table": frozenset({"id"})}
            )

    def test_independent_roles_and_safe_identifiers(self):
        for principals in (
            {},
            {**PRINCIPALS, "worker": PRINCIPALS["api"]},
            {**PRINCIPALS, "api": 'bad";'},
        ):
            with self.assertRaises(policy.common.PolicyError):
                self.compile(principals=principals)
        with self.assertRaises(policy.common.PolicyError):
            self.compile(schema='public";')

    def test_reviewed_columns_and_append_only_events(self):
        for mapping in (
            policy.API_INSERTS,
            policy.WORKER_INSERTS,
            policy.API_UPDATES,
            policy.WORKER_UPDATES,
        ):
            for table, names in mapping.items():
                self.assertLessEqual(set(names.split()), policy.DOMAIN_COLUMNS[table])
        for mapping in (policy.API_UPDATES, policy.WORKER_UPDATES):
            self.assertNotIn("session_events", mapping)
            self.assertNotIn("agent_pilot_requests", mapping)
            for names in mapping.values():
                self.assertTrue(
                    set(names.split()).isdisjoint(
                        {
                            "id",
                            "session_id",
                            "thread_id",
                            "owner_actor_id",
                            "intent",
                            "tool_call_id",
                            "run_id",
                        }
                    )
                )
        self.assertEqual(
            set(policy.API_UPDATES["agent_execution_leases"].split()),
            {"epoch", "expires_at"},
        )
        self.assertNotIn("agent_execution_leases", policy.API_INSERTS)
        self.assertNotIn("agent_runs", policy.WORKER_INSERTS)


if __name__ == "__main__":
    unittest.main()
