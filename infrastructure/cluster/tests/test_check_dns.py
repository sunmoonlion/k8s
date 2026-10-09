import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "check-dns.py"
SPEC = importlib.util.spec_from_file_location("check_dns", MODULE_PATH)
check_dns = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(check_dns)


class CheckDnsTests(unittest.TestCase):
    def test_all_app_platform_workload_templates_set_ndots_two(self):
        templates = sorted(
            (Path(__file__).parents[3] / "gitops/components/app-platform").rglob("workload.yaml.j2")
        )
        missing = [str(path) for path in templates if "options: [{name: ndots, value: '2'}]" not in path.read_text()]
        self.assertTrue(templates, "no app-platform workload templates found")
        self.assertEqual(missing, [])

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
