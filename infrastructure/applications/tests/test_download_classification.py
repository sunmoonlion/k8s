"""Evaluate the actual Ansible classifier against download/trust failures."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import yaml

INFRA = Path(__file__).resolve().parents[2]


class DownloadClassification(unittest.TestCase):
    def test_production_classifier(self):
        flow = yaml.safe_load((INFRA / 'applications/build-network.yaml').read_text())
        classifier = flow[0]['rescue'][0]
        cases = [
            ('uv sync', 'Failed to download: ConnectionError', True, False),
            ('pip install uv', 'ReadTimeoutError', True, False),
            ('corepack install', 'Error when performing the request: ECONNREFUSED', True, False),
            ('pnpm build', 'Compilation failed ECONNRESET', False, False),
            ('uv sync', 'Failed to download: certificate verify failed', True, True),
            ('uv sync', 'Failed to download: HTTP status client error (403 Forbidden)', True, True),
            ('pip install uv', 'Failed to download: 401 Client Error', True, True),
            ('pnpm install', 'ERR_PNPM_FETCH_404', True, True),
            ('uv sync', 'Failed to download: Hash mismatch', True, True),
        ]
        tasks = []
        for command, error, network, trust in cases:
            stderr = error + '\nERROR: failed to solve: process "/bin/sh -c ' + command + '" did not complete successfully'
            tasks.append({'name': 'Case ' + error, 'vars': {'image_build': {'stderr': stderr}}, 'block': [classifier, {'ansible.builtin.assert': {'that': ['download_failed == ' + str(network).lower(), 'trust_failed == ' + str(trust).lower()]}}]})
        with tempfile.TemporaryDirectory(prefix='sunmoon-classifier-test-') as temporary:
            p = Path(temporary) / 'cases.yaml'
            p.write_text(yaml.safe_dump([{'hosts': 'localhost', 'gather_facts': False, 'tasks': tasks}], sort_keys=False))
            result = subprocess.run([str(INFRA / '.venv/bin/ansible-playbook'), '-i', 'localhost,', '-c', 'local', str(p)], cwd=INFRA, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
