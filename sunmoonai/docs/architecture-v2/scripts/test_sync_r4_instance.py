from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("sync_r4_instance.py")
SPEC = importlib.util.spec_from_file_location("sync_r4_instance", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class InstantiateTests(unittest.TestCase):
    def test_only_explicit_exact_values_are_instantiated(self) -> None:
        source = b"\n".join(
            (
                b"grid-template-columns: 1fr 1fr;",
                b"template: `%s | title`,",
                b"'@babel/template': '7.28.6',",
                b"service = 'tpl-backend'",
            )
        )

        result = MODULE.instantiate(
            source,
            [{"from": "tpl-backend", "to": "info-backend"}],
            "app/example.ts",
        )

        self.assertIn(b"grid-template-columns", result)
        self.assertIn(b"template: `%s | title`", result)
        self.assertIn(b"@babel/template", result)
        self.assertIn(b"info-backend", result)

    def test_path_scoped_substitution_does_not_leak(self) -> None:
        substitutions = [
            {
                "glob": "app/env/server-schema.ts",
                "from": "default('tpl')",
                "to": "default('info')",
            }
        ]

        self.assertEqual(
            MODULE.instantiate(
                b"default('tpl')", substitutions, "app/env/server-schema.ts"
            ),
            b"default('info')",
        )
        self.assertEqual(
            MODULE.instantiate(
                b"default('tpl')", substitutions, "app/contracts/auth.ts"
            ),
            b"default('tpl')",
        )


class ResolutionTests(unittest.TestCase):
    def test_target_resolution_is_forced_during_initial_sync(self) -> None:
        resolution = {"strategy": "target"}

        self.assertTrue(
            MODULE.resolution_is_forced(resolution, steady_state=False)
        )

    def test_target_resolution_is_not_reapplied_in_steady_state(self) -> None:
        resolution = {"strategy": "target"}

        self.assertFalse(
            MODULE.resolution_is_forced(resolution, steady_state=True)
        )

    def test_local_and_merge_resolutions_remain_explicit_in_steady_state(self) -> None:
        self.assertTrue(
            MODULE.resolution_is_forced(
                {"strategy": "local"}, steady_state=True
            )
        )
        self.assertTrue(
            MODULE.resolution_is_forced(
                {"strategy": "merge"}, steady_state=True
            )
        )


if __name__ == "__main__":
    unittest.main()
