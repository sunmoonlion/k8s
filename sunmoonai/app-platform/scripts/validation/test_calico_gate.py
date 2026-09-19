"""Gate safety/diagnostic regression, using fake CLIs; never calls Docker/KIND."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from calico_dns_ready import wait_for_records
from calico_probe_result import matches_expected

SCRIPT = Path(
    os.environ.get(
        "CALICO_GATE_TEST_SCRIPT",
        Path(__file__).with_name("verify_r3_network_policy_calico.sh"),
    )
)


class CalicoGateTests(unittest.TestCase):
    def executable(self, root, name, code):
        path = root / name
        path.write_text(f"#!{sys.executable}\n" + code, encoding="utf-8")
        path.chmod(0o700)
        return str(path)

    def test_preexisting_cluster_is_never_deleted(self):
        self.before_creation(existing=True)

    def test_owned_cleanup_uses_only_its_kubeconfig(self):
        self.owned_cleanup(fails=False)

    def test_failed_cleanup_is_not_reported_as_success(self):
        self.owned_cleanup(fails=True)

    def owned_cleanup(self, *, fails):
        source = SCRIPT.read_text()
        function = (
            "cleanup() {"
            + source.split("cleanup() {", 1)[1].split("\n}\n", 1)[0]
            + "\n}\n"
        )
        with tempfile.TemporaryDirectory(prefix="calico-cleanup-unit-") as directory:
            root = Path(directory)
            work = root / "owned-work"
            work.mkdir()
            calls = root / "kind-calls"
            kind = self.executable(
                root,
                "fake-kind",
                """
import os, sys
from pathlib import Path
Path(os.environ['GATE_TEST_CALLS']).write_text(' '.join(sys.argv[1:]))
raise SystemExit(int(os.environ['GATE_DELETE_EXIT']))
""",
            )
            setup = """set -euo pipefail
WORK_DIR="$1"
KIND_BIN="$2"
CLUSTER_NAME=luna-owned-unit
CLUSTER_CREATED=true
KEEP_CLUSTER=false
KUBECONFIG_PATH="$WORK_DIR/kubeconfig"
"""
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    setup + function + "\ncleanup\n",
                    "gate",
                    str(work),
                    kind,
                ],
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "GATE_TEST_CALLS": str(calls),
                    "GATE_DELETE_EXIT": "42" if fails else "0",
                },
                timeout=10,
            )
            self.assertEqual(result.returncode, 1 if fails else 0)
            self.assertEqual(
                calls.read_text(),
                f"delete cluster --name luna-owned-unit --kubeconfig {work}/kubeconfig",
            )
            self.assertEqual(work.exists(), fails)

    def test_bootstrap_failure_cannot_delete_unowned_cluster(self):
        self.before_creation(existing=False)

    def before_creation(self, *, existing):
        with tempfile.TemporaryDirectory(prefix="calico-gate-unit-") as directory:
            root = Path(directory)
            bundle = root / "bundle"
            bundle.mkdir()
            (bundle / "release.json").write_text(
                json.dumps({"app": "info", "namespace": "test"})
            )
            (bundle / "30-network-policies.yaml").write_text("")
            calls = root / "kind-calls"
            kind = self.executable(
                root,
                "fake-kind",
                """
import os, sys
from pathlib import Path
with Path(os.environ['GATE_TEST_CALLS']).open('a') as log:
    log.write(' '.join(sys.argv[1:]) + '\\n')
if sys.argv[1:] == ['get', 'clusters'] and os.environ['GATE_TEST_EXISTS'] == '1':
    print('luna-unit-policy')
""",
            )
            self.executable(root, "curl", "raise SystemExit(44)\n")
            env = {
                **os.environ,
                "PATH": str(root) + os.pathsep + os.environ["PATH"],
                "KIND_BIN": kind,
                "KUBECTL_BIN": "/bin/true",
                "DOCKER_BIN": "/bin/true",
                "R3_POLICY_CLUSTER_NAME": "luna-unit-policy",
                "R3_CALICO_MANIFEST_CACHE": str(root / "absent"),
                "R3_CALICO_ARCHIVE_DIR": str(root / "cache"),
                "GATE_TEST_CALLS": str(calls),
                "GATE_TEST_EXISTS": "1" if existing else "0",
            }
            result = subprocess.run(
                ["bash", str(SCRIPT), "--bundle", str(bundle)],
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            try:
                self.assertEqual(
                    result.returncode, 1 if existing else 44, result.stderr
                )
                self.assertNotIn("delete cluster", calls.read_text())
                self.assertNotIn("create cluster", calls.read_text())
            finally:
                # The actual gate intentionally retains failed diagnostics. Remove
                # only its unique mktemp path from this fake-CLI unit test.
                for path in re.findall(
                    r"retained at (/tmp/architecture-v2-r3-calico\.[^\s]+)",
                    result.stderr,
                ):
                    target = Path(path).resolve()
                    if target.parent == Path("/tmp") and target.name.startswith(
                        "architecture-v2-r3-calico."
                    ):
                        shutil.rmtree(target)

    def test_failed_probe_keeps_logs_and_pod_until_outer_diagnostics(self):
        source = SCRIPT.read_text()
        function = (
            "probe() {" + source.split("probe() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
        )
        with tempfile.TemporaryDirectory(prefix="calico-probe-unit-") as directory:
            root = Path(directory)
            calls = root / "kubectl-calls"
            fake = self.executable(
                root,
                "fake-kubectl",
                """
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with Path(os.environ['GATE_TEST_CALLS']).open('a') as log:
    log.write(' '.join(args) + '\\n')
if args[0] == 'get':
    print('Failed' if any('jsonpath' in a for a in args) else json.dumps({'status': {'phase': 'Failed'}}))
elif args[0] == 'logs':
    print('wget: bad address: info-backend')
""",
            )
            command = """set -euo pipefail
WORK_DIR="$1"
FAKE_K="$2"
NAMESPACE=test
BACKEND_SERVICE=info-backend
CLIENT_IMAGE=fake
SCRIPT_DIR="$3"
k() { "$FAKE_K" "$@"; }
"""
            command += function + "\nprobe example label=true Succeeded\n"
            result = subprocess.run(
                ["bash", "-c", command, "gate", str(root), fake, str(SCRIPT.parent)],
                env={**os.environ, "GATE_TEST_CALLS": str(calls)},
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("bad address", (root / "example.log").read_text())
            self.assertEqual(
                json.loads((root / "example.json").read_text())["status"]["phase"],
                "Failed",
            )
            self.assertEqual(
                sum(
                    line.startswith("delete pod")
                    for line in calls.read_text().splitlines()
                ),
                1,
            )
            self.assertIn("diagnostics=", result.stderr)

    def test_dns_startup_requires_both_exact_service_addresses(self):
        elapsed, records, logs = (
            [0],
            {"backend.": "10.0.0.1", "provider.": "10.0.0.2"},
            [],
        )

        def resolve(name):
            if elapsed[0] == 0:
                raise OSError("DNS not ready")
            if elapsed[0] == 1 and name == "provider.":
                return "10.0.0.9"
            return records[name]

        result = wait_for_records(
            records,
            resolve=resolve,
            now=lambda: elapsed[0],
            sleep=lambda delay: elapsed.__setitem__(0, elapsed[0] + delay),
            emit=logs.append,
            budget=3,
        )
        self.assertEqual(result, 0)
        self.assertEqual(elapsed[0], 2)
        self.assertEqual(len(logs), 6)

    def test_dns_never_ready_fails_at_startup_budget(self):
        elapsed = [0]
        result = wait_for_records(
            {"backend.": "10.0.0.1"},
            resolve=lambda _: "10.0.0.9",
            now=lambda: elapsed[0],
            sleep=lambda delay: elapsed.__setitem__(0, elapsed[0] + delay),
            emit=lambda _: None,
            budget=3,
        )
        self.assertEqual(result, 2)
        self.assertEqual(elapsed[0], 3)

    def test_probe_verdict_rejects_non_network_failures(self):
        for phase, code, reason, log, expected, accepted in [
            ("Succeeded", 0, "Completed", "", "Succeeded", True),
            ("Failed", 1, "Error", "wget: download timed out\n", "Failed", True),
            ("Failed", 1, "Error", "wget: bad address 'backend'", "Failed", False),
            (
                "Failed",
                1,
                "Error",
                "wget: can't connect: Connection refused",
                "Failed",
                False,
            ),
            ("Failed", 137, "OOMKilled", "wget: download timed out", "Failed", False),
            ("Failed", 124, "Error", "", "Failed", False),
            ("Pending", 1, "Error", "wget: download timed out", "Failed", False),
            ("Succeeded", 0, "Completed", "", "Failed", False),
        ]:
            with self.subTest(phase=phase, code=code, reason=reason, log=log):
                pod = {
                    "status": {
                        "phase": phase,
                        "containerStatuses": [
                            {
                                "state": {
                                    "terminated": {"exitCode": code, "reason": reason}
                                }
                            }
                        ],
                    }
                }
                self.assertEqual(matches_expected(pod, log, expected), accepted)


if __name__ == "__main__":
    unittest.main()
