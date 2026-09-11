from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[3]


class InvestmentRedisDeclarationTest(unittest.TestCase):
    def test_stable_secret_and_app_only_key_channel_access(self):
        values = yaml.safe_load((ROOT / "data-platform/redis/resources/custom-values/dev-values-kind.yaml").read_text())
        entries = [entry for entry in values["auth"]["acl"]["users"] if entry["username"] == "investment_backend"]
        self.assertEqual(len(entries), 1)
        entry = entries[0]
        self.assertEqual(entry["existingSecret"], "investment-redis-credential")
        self.assertNotIn("password", entry)
        self.assertEqual(entry["keys"], "~investment:*")
        self.assertEqual(entry["channels"], "resetchannels &investment:*")
        for command in ("+publish", "+subscribe", "+unsubscribe", "-@dangerous"):
            self.assertIn(command, entry["commands"].split())
        self.assertNotIn("+@all", entry["commands"].split())

    def test_chart_fails_closed_for_missing_existing_secret(self):
        template = (ROOT / "data-platform/redis/resources/redis/templates/configmap.yaml").read_text()
        self.assertIn("if .existingSecret", template)
        self.assertIn('required "ACL user existingSecret/key must exist', template)


if __name__ == "__main__":
    unittest.main()
