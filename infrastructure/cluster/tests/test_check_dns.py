import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "check-dns.py"
SPEC = importlib.util.spec_from_file_location("check_dns", MODULE_PATH)
check_dns = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(check_dns)


class CheckDnsTests(unittest.TestCase):
    def test_only_long_running_application_workloads_set_ndots_two(self):
        root = Path(__file__).parents[3] / "gitops/components/app-platform"
        expected = {
            "common/backend/runtime/workload.yaml.j2",
            "common/web/workload.yaml.j2",
            "common/admin/workload.yaml.j2",
            "auth-app/casdoor/workload.yaml.j2",
        }
        actual = {
            path.relative_to(root).as_posix()
            for path in root.rglob("workload.yaml.j2")
            if "options: [{name: ndots, value: '2'}]" in path.read_text()
        }
        self.assertEqual(actual, expected)

    def test_job_templates_do_not_override_dns_options(self):
        root = Path(__file__).parents[3] / "gitops/components/app-platform"
        jobs = [
            path
            for path in root.rglob("workload.yaml.j2")
            if "kind: Job" in path.read_text()
        ]
        self.assertTrue(jobs, "no Job workload templates found")
        offenders = [str(path) for path in jobs if "name: ndots" in path.read_text()]
        self.assertEqual(offenders, [])

    def test_accepts_absent_search_and_valid_domains(self):
        self.assertEqual(
            check_dns.parse_resolv_conf("nameserver 10.0.0.2\nsearch svc.cluster.local example.org\n"),
            {"nameservers": ["10.0.0.2"], "search": ["svc.cluster.local", "example.org"]},
        )
        self.assertEqual(
            check_dns.parse_resolv_conf("nameserver 10.0.0.2\n"),
            {"nameservers": ["10.0.0.2"], "search": []},
        )

    def test_rejects_cidr_slash_and_invalid_domain(self):
        for suffix in ("172.16.8.0/22", "example/path", "bad_.example"):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                check_dns.parse_resolv_conf(f"nameserver 10.0.0.2\nsearch {suffix}\n")

    def test_rejects_missing_nameserver(self):
        with self.assertRaisesRegex(ValueError, "no valid nameserver"):
            check_dns.parse_resolv_conf("search cluster.local\n")

    def test_latency_threshold_is_inclusive_at_200ms(self):
        check_dns.validate_latency([1.5, 200.0])
        with self.assertRaisesRegex(ValueError, "check the host DNS suffix"):
            check_dns.validate_latency([1.5, 200.1])


if __name__ == "__main__":
    unittest.main()
