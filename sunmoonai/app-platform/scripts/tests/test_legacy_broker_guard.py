import base64
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("legacy_guard",ROOT/"guard_legacy_broker.py")
target = importlib.util.module_from_spec(spec)
spec.loader.exec_module(target)


class LegacyGuardTest(unittest.TestCase):
    def secret(self,names=()):
        return {"metadata":{},"data":{"load_definition.json":base64.b64encode(json.dumps(
            {"users":[{"name":name} for name in names]}).encode()).decode()}}

    def test_legacy_or_bootstrap_allowed_read_only(self):
        target.verify_legacy_allowed(None,[])
        target.verify_legacy_allowed(self.secret(["old-worker"]),[])

    def test_any_takeover_evidence_blocks_even_without_marker(self):
        cases = [(self.secret(),["secret/info-backend-runtime"]),
                 (self.secret(["knowledge-backend-worker-v2"]),[]),
                 (self.secret()|{"metadata":{"annotations":{target.MARKER:"v1"}}},[]),
                 ({"data":{"load_definition.json":"broken"}},[]),
                 ({"metadata":{},"data":{}},[])]
        for secret,names in cases:
            with self.assertRaises(ValueError):
                target.verify_legacy_allowed(secret,names)

    def test_query_error_never_becomes_missing_secret(self):
        with patch("sys.argv",["guard"]),patch.object(target.subprocess,"run",
                return_value=SimpleNamespace(returncode=1,stdout="",stderr="private diagnostic")) as run:
            with self.assertRaisesRegex(ValueError,"query failed"):
                target.main()
            self.assertEqual(run.call_count,1)

    def test_calls_read_only_resources(self):
        with patch("sys.argv",["guard","--kubeconfig","/explicit"]),patch.object(target.subprocess,"run",
                return_value=SimpleNamespace(returncode=0,stdout="")) as run:
            target.main()
            self.assertEqual(run.call_count,4)
            for call in run.call_args_list:
                self.assertIn("get",call.args[0])
                self.assertIn("--ignore-not-found=true",call.args[0])
                self.assertIn("/explicit",call.args[0])

    def test_both_legacy_writers_guard_before_first_mutation(self):
        helper=(ROOT/"prepare-investment-broker-kind.sh").read_text()
        self.assertLess(helper.index("guard_legacy_broker.py"),helper.index("k patch secret"))
        helm=(ROOT.parents[1]/"messaging-platform/rabbitmq/deploy-rabbitmq/deploy-rabbitmq.sh").read_text()
        body=helm.split("execute_rabbitmq_deployment() {",1)[1]
        self.assertLess(body.index("guard_legacy_broker.py"),body.index("kubectl apply"))
        stable_path = ROOT.parents[1]/"messaging-platform/rabbitmq/deploy-rabbitmq"
        self.assertEqual((stable_path/"../../../app-platform/scripts/guard_legacy_broker.py").resolve(),
                         (ROOT/"guard_legacy_broker.py").resolve())
        self.assertIn('"$RABBITMQ_SCRIPT_DIR/../../../app-platform/scripts/guard_legacy_broker.py"',body)
