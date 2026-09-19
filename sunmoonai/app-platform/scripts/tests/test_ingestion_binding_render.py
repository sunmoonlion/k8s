"""Explicit ingestion authority is independent from retrieval configuration."""

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import yaml

PLATFORM = Path(__file__).resolve().parents[2]
RENDERER = PLATFORM / "knowledge-app/deployment/render.py"
K8S = PLATFORM.parents[1]
spec = importlib.util.spec_from_file_location("knowledge_binding_renderer", RENDERER)
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)


class IngestionBindingRenderingTest(unittest.TestCase):
    def test_default_is_empty_not_derived_from_retrieval(self):
        bindings, policy = renderer.ingestion_bindings(None, K8S)
        self.assertEqual(bindings, "{}")
        self.assertTrue(policy.is_file())

    def test_rejects_invalid_duplicate_and_aliased_authority(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "bindings.json"
            for raw in (
                '[]', '{"a":{}}',
                '{"a":{"dataset_id":"id","dataset_name":"a"},"a":{}}',
                '{"a":{"dataset_id":"id","dataset_name":"a"},'
                '"b":{"dataset_id":"id","dataset_name":"b"}}',
            ):
                source.write_text(raw)
                with self.subTest(raw=raw), self.assertRaises(ValueError):
                    renderer.ingestion_bindings(source, K8S)

    def test_explicit_binding_is_hashed_and_reaches_runtime_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "bindings.json"
            expected = {"synthetic": {"dataset_id": "synthetic-id", "dataset_name": "synthetic"}}
            source.write_text(json.dumps(expected))
            output = root / "bundle"
            subprocess.run([
                sys.executable, str(RENDERER), "--output-dir", str(output),
                "--release-id", "binding-unit-test",
                "--ingestion-dataset-bindings-file", str(source),
            ], check=True, capture_output=True, text=True, timeout=30)
            docs = list(yaml.safe_load_all((output / "00-prerequisites.yaml").read_text()))
            config = next(d["data"] for d in docs if d.get("kind") == "ConfigMap"
                          and d["metadata"]["name"] == "knowledge-backend-config")
            self.assertEqual(json.loads(config["INGESTION_DATASET_BINDINGS"]), expected)
            release = json.loads((output / "release.json").read_text())
            self.assertEqual(release["renderer_inputs_sha256"]["ingestion-dataset-bindings-input"],
                             hashlib.sha256(source.read_bytes()).hexdigest())
            digest = hashlib.sha256(json.dumps(config, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            runtime = list(yaml.safe_load_all((output / "20-runtime.yaml").read_text()))
            for role in ("api", "worker", "scheduler"):
                deployment = next(d for d in runtime if d["kind"] == "Deployment"
                                  and d["metadata"]["name"] == f"knowledge-backend-{role}")
                self.assertEqual(deployment["spec"]["template"]["metadata"]["annotations"]
                                 ["sunmoonai.com/config-sha256"], digest)
                self.assertIn({"configMapRef": {"name": "knowledge-backend-config"}},
                              deployment["spec"]["template"]["spec"]["containers"][0]["envFrom"])


if __name__ == "__main__":
    unittest.main()
