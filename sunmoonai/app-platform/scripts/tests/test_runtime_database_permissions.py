"""Inventory safety contracts; real SQL evidence is separate from these fakes."""

import asyncio
import contextlib
import copy
import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import audit_runtime_database_permissions as audit


class Result:
    def __init__(self, rows):
        self.rows = rows

    def mappings(self):
        return self

    def all(self):
        return self.rows


class Connection:
    def __init__(self):
        self.statements = []
        self.rows = {section: [] for section in audit.QUERIES}
        self.rows["identity"] = [
            {
                "server_version_num": "170006",
                "transaction_read_only": "on",
                "transaction_isolation": "repeatable read",
                "principal": "synthetic_runtime",
                "session_principal": "synthetic_runtime",
            }
        ]

    async def exec_driver_sql(self, sql):
        self.statements.append(sql)
        for section, query in audit.QUERIES.items():
            if sql.startswith(query):
                return Result(self.rows[section])
        return Result([])


class InventoryTest(unittest.IsolatedAsyncioTestCase):
    async def test_read_only_setup_precedes_bounded_queries(self):
        connection = Connection()
        report = await audit.collect(connection)
        self.assertEqual(report["status"], "collected")
        self.assertEqual(report["permission_acceptance"], "not_evaluated")
        self.assertEqual(report["inventory"], connection.rows)
        self.assertEqual(connection.statements[:4], list(audit.SETUP))
        for sql in connection.statements[4:]:
            self.assertTrue(sql.strip().startswith("SELECT "))
            self.assertTrue(sql.endswith("LIMIT 2001"))
            self.assertNotIn("pg_authid", sql)
            self.assertNotIn("pg_shadow", sql)
            self.assertNotIn("rolpassword", sql)
            self.assertNotIn("prosrc", sql)
        self.assertIn("any_column_update", audit.QUERIES["relations"])
        self.assertIn("can_set_owner", audit.QUERIES["relations"])
        self.assertIn("security_definer", audit.QUERIES["functions"])
        # asyncpg decodes PostgreSQL internal "char" as bytes, not JSON text.
        self.assertIn("c.relkind::text AS kind", audit.QUERIES["relations"])
        self.assertIn(
            "d.defaclobjtype::text AS object_type", audit.QUERIES["default_acl"]
        )

    async def test_invalid_context_stops_before_catalog_inventory(self):
        for field, bad in (
            ("server_version_num", "150000"),
            ("transaction_read_only", "off"),
            ("transaction_isolation", "read committed"),
            ("session_principal", "different_login"),
        ):
            with self.subTest(field=field):
                connection = Connection()
                connection.rows["identity"][0][field] = bad
                with self.assertRaises(audit.AuditError):
                    await audit.collect(connection)
                self.assertEqual(len(connection.statements), 5)
        for rows in ([], [{}, {}]):
            connection = Connection()
            connection.rows["identity"] = rows
            with self.assertRaises(audit.AuditError):
                await audit.collect(connection)

    async def test_overflow_does_not_silently_truncate(self):
        connection = Connection()
        connection.rows["relations"] = [{"name": "fixture"}] * (audit.MAX_ROWS + 1)
        with self.assertRaises(audit.AuditError):
            await audit.collect(connection)
        connection.rows["relations"].pop()
        self.assertEqual(
            len((await audit.collect(connection))["inventory"]["relations"]),
            audit.MAX_ROWS,
        )

    async def test_errors_and_serialization_failures_are_redacted(self):
        async def broken():
            raise RuntimeError("synthetic://user:do-not-print@host/database")

        async def unserializable():
            return {"partial": "do-not-print", "bad": object()}

        for run, category in ((broken, "unclassified"), (unserializable, "type_error")):
            with (
                self.subTest(run=run.__name__),
                contextlib.redirect_stdout(io.StringIO()) as output,
            ):
                self.assertEqual(await audit.emit(run), 1)
                self.assertEqual(
                    json.loads(output.getvalue()),
                    {
                        "status": "failed",
                        "reason": "permission_inventory_unavailable",
                        "category": category,
                    },
                )

    async def test_query_failure_exposes_only_fixed_section_and_sqlstate(self):
        class DriverError(Exception):
            sqlstate = "42601"

        error = RuntimeError("do-not-print")
        error.orig = DriverError("do-not-print")

        async def failed_statement(_statement):
            raise error

        connection = Connection()
        connection.exec_driver_sql = failed_statement

        async def run():
            await audit.collect(connection)

        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(await audit.emit(run), 1)
            self.assertEqual(
                json.loads(output.getvalue()),
                {
                    "status": "failed",
                    "reason": "catalog_query_failed",
                    "section": "setup",
                    "sqlstate": "42601",
                },
            )
        error.orig.sqlstate = "do-not-print"
        redacted = audit.QueryError("do-not-print", error)
        self.assertIsNone(redacted.sqlstate)
        self.assertEqual(redacted.section, "setup")

    async def test_deadline_redacts_and_external_cancellation_propagates(self):
        async def slow():
            await asyncio.sleep(10)

        with (
            patch.object(audit, "TOTAL_TIMEOUT", 0.001),
            contextlib.redirect_stdout(io.StringIO()) as output,
        ):
            self.assertEqual(await audit.emit(slow), 1)
            self.assertEqual(json.loads(output.getvalue())["status"], "failed")

        async def cancelled():
            raise asyncio.CancelledError()

        with contextlib.redirect_stdout(io.StringIO()) as output:
            with self.assertRaises(asyncio.CancelledError):
                await audit.emit(cancelled)
            self.assertEqual(output.getvalue(), "")

    async def test_success_emits_one_complete_report(self):
        report = await audit.collect(Connection())

        async def run():
            return copy.deepcopy(report)

        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(await audit.emit(run), 0)
            self.assertEqual(json.loads(output.getvalue()), report)


if __name__ == "__main__":
    unittest.main()
