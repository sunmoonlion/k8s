"""Protect the twelve build/publish selections from cross-app result reuse."""
import subprocess
import unittest
from pathlib import Path

INFRA = Path(__file__).resolve().parents[2]


class BuildSelection(unittest.TestCase):
    def test_all_twelve_build_and_publication_arguments(self):
        for app in ['tpl', 'info', 'knowledge', 'investment']:
            for role in ['backend', 'web', 'admin']:
                with self.subTest(app=app, role=role):
                    repository = app + '-' + (role if role == 'backend' else role + '-frontend')
                    build = subprocess.check_output(['make', '-n', 'application-build-' + role, 'APP=' + app], cwd=INFRA, text=True)
                    publish = subprocess.check_output(['make', '-n', 'application-publish-' + role, 'APP=' + app], cwd=INFRA, text=True)
                    self.assertIn('applications/build.yaml', build)
                    self.assertIn('application_name=' + app + ' build_component=' + role, build)
                    self.assertIn(repository + '-images.lock.json', publish)
                    self.assertIn('"publication_image_ids":["' + repository + '"]', publish)
                    self.assertIn('application-publish-' + app + '-' + role, publish)
                    if app != 'tpl':
                        self.assertNotIn('tpl-', publish)

    def test_invalid_app_or_component_rejected_before_execution(self):
        for selector in ['APP=other', 'APP=%', 'APP=tpl info', 'APP=', 'COMPONENT=other', 'COMPONENT=%', 'COMPONENT=web admin']:
            with self.subTest(selector=selector):
                result = subprocess.run(['make', '-n', 'application-source-plan', selector], cwd=INFRA, text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('ansible-playbook', result.stdout)


if __name__ == '__main__':
    unittest.main()
