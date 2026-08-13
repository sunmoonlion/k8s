from __future__ import annotations

import argparse
import tempfile
import unittest
from pathlib import Path

import yaml

import sys


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import formal_component_deploy as target


class FormalComponentDeployTest(unittest.TestCase):
    def test_runtime_apply_selects_one_component_family(self) -> None:
        documents = [
            {
                "apiVersion": "apps/v1",
                "kind": "Deployment",
                "metadata": {"name": "demo-backend-api"},
            },
            {
                "apiVersion": "policy/v1",
                "kind": "PodDisruptionBudget",
                "metadata": {"name": "demo-backend-api"},
            },
            {
                "apiVersion": "apps/v1",
                "kind": "Deployment",
                "metadata": {"name": "demo-backend-worker"},
            },
        ]
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory)
            (bundle / "20-runtime.yaml").write_text(
                yaml.safe_dump_all(documents, sort_keys=False), encoding="utf-8"
            )
            calls: list[tuple[tuple[str, ...], str | None]] = []

            def run(_args, *items, **kwargs):
                calls.append((items, kwargs.get("input_text")))

            target.apply_runtime_component(
                args=argparse.Namespace(timeout=30),
                data={"resource_app": "demo", "namespace": "test"},
                bundle=bundle,
                component="backend-api",
                run=run,
                apply_file=lambda *_args, **_kwargs: None,
                dry_run=True,
            )

        self.assertEqual(calls[0][0], ("apply", "--dry-run=server", "-f", "-"))
        selected = [item for item in yaml.safe_load_all(calls[0][1] or "") if item]
        self.assertEqual(
            {(item["kind"], item["metadata"]["name"]) for item in selected},
            {
                ("Deployment", "demo-backend-api"),
                ("PodDisruptionBudget", "demo-backend-api"),
            },
        )
        self.assertEqual(len(calls), 1, "dry-run must not wait for rollout")

    def test_missing_deployment_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory)
            (bundle / "20-runtime.yaml").write_text("", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "missing Deployment"):
                target.apply_runtime_component(
                    args=argparse.Namespace(timeout=30),
                    data={"resource_app": "demo", "namespace": "test"},
                    bundle=bundle,
                    component="backend-worker",
                    run=lambda *_args, **_kwargs: None,
                    apply_file=lambda *_args, **_kwargs: None,
                )


if __name__ == "__main__":
    unittest.main()
