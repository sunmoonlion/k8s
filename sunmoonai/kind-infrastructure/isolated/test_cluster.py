"""Local guards; these tests never contact Docker or Kubernetes."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
import yaml
from unittest.mock import patch

from cluster import Cluster, HERE, atomic, clean_env, safe_path, sha


class Guards(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.profile = json.loads((HERE / 'profile.json').read_text())
        self.profile['kubeconfig'] = str(self.root / 'new.config')
        self.profile['old_kubeconfig'] = str(self.root / 'old.config')
        self.path = self.root / 'profile.json'

    def cluster(self):
        self.path.write_text(json.dumps(self.profile))
        return Cluster(self.path, str(self.root / 'artifacts'))

    def fixture(self):
        self.profile['images'] = [{'id': 'node'}]
        self.profile['files'] = [{'path': 'bin/kind', 'sha256': ''}]
        root = self.root / 'artifacts'
        atomic(root / 'bin/kind', 'kind')
        self.profile['files'][0]['sha256'] = sha(root / 'bin/kind')
        c = self.cluster()
        state = {'schema': 1, 'profile_sha256': c.profile_sha, 'files': self.profile['files'], 'images': [], 'generated': []}
        for path in ['images/node.tar', 'kind.yaml', 'charts/calico.yaml']:
            atomic(root / path, path)
            item = {'path': path, 'sha256': sha(root / path)}
            if path.startswith('images/'):
                item['id'] = 'node'; state['images'].append(item)
            else:
                state['generated'].append(item)
        atomic(root / 'manifest.lock.json', json.dumps(state))
        return c

    def test_complete_batch_has_no_external_calls(self):
        c = self.fixture()
        with patch.object(c, 'run', side_effect=AssertionError('offline validation invoked an external command')):
            c.validate()

    def test_missing_and_corrupt_artifacts_fail(self):
        c = self.fixture()
        (c.root / 'images/node.tar').write_text('corrupt')
        with self.assertRaises(ValueError): c.validate()
        (c.root / 'images/node.tar').unlink()
        with self.assertRaises(ValueError): c.validate()

    def test_profile_change_is_not_silently_accepted(self):
        c = self.fixture(); c.profile_sha = 'wrong'
        with self.assertRaises(ValueError): c.validate()

    def test_path_traversal_and_symlink_rejected(self):
        for name in ['../outside', '/tmp/outside']:
            with self.assertRaises(ValueError): safe_path(self.root, name)
        (self.root / 'escape').symlink_to('/tmp')
        with self.assertRaises(ValueError): safe_path(self.root, 'escape/file')

    def test_old_name_kubeconfig_and_cidr_protected(self):
        original = copy.deepcopy(self.profile)
        for key, value in [('name', 'kind'), ('kubeconfig', original['old_kubeconfig']), ('service_subnet', original['pod_subnet'])]:
            self.profile = copy.deepcopy(original); self.profile[key] = value
            with self.assertRaises(ValueError): self.cluster()

    def test_existing_kubeconfig_stops_before_any_command(self):
        c = self.fixture(); c.kubeconfig.write_text('existing')
        with patch.object(c, 'run', side_effect=AssertionError('should stop first')):
            with self.assertRaises(ValueError): c.preflight()

    def test_existing_cluster_stops_before_creation(self):
        c = self.fixture()
        with patch.object(c, 'run', return_value='kind\nsunmoon-kind-136\n') as run:
            with self.assertRaises(ValueError): c.preflight()
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][1:], ['get', 'clusters'])

    def test_environment_does_not_give_nodes_proxy(self):
        with patch.dict(os.environ, {'HTTP_PROXY': 'example', 'https_proxy': 'example', 'KUBECONFIG': 'old'}):
            result = clean_env()
        self.assertNotIn('HTTP_PROXY', result)
        self.assertNotIn('https_proxy', result)
        self.assertNotIn('KUBECONFIG', result)

    def test_install_uses_normalized_containerd_archive_name(self):
        c = self.fixture()
        item = {'id': 'probe', 'path': 'images/probe.tar',
                'archive_tag': 'sunmoon-offline/probe:locked',
                'reference': 'docker.io/library/busybox@sha256:locked'}
        with patch.object(c, 'validate', return_value={'images': [item]}), \
             patch.object(c, 'assert_target'), patch.object(c, 'run') as run:
            c.install()
        tags = [call.args[0] for call in run.call_args_list if 'tag' in call.args[0]]
        self.assertEqual(len(tags), 3)
        for command in tags:
            self.assertEqual(command[-2:], ['docker.io/' + item['archive_tag'], item['reference']])

    def test_vxlan_render_removes_both_bird_health_checks(self):
        c = self.fixture()
        upstream = {'apiVersion': 'apps/v1', 'kind': 'DaemonSet', 'metadata': {'name': 'calico-node'},
                    'spec': {'template': {'spec': {'containers': [{
                        'name': 'calico-node', 'image': 'quay.io/calico/node:v3.32.2', 'env': [],
                        'readinessProbe': {'exec': {'command': ['-bird-ready']}},
                        'livenessProbe': {'exec': {'command': ['-bird-live']}}}]}}}}
        atomic(c.root / 'charts/calico-upstream.yaml', yaml.safe_dump(upstream))
        state = {'images': [{'id': 'node', 'archive_tag': 'sunmoon-offline/node:locked'},
                            {'id': 'calico-node', 'source': 'quay.io/calico/node:v3.32.2',
                             'reference': 'quay.io/calico/node@sha256:locked'}]}
        c.render(state)
        rendered = yaml.safe_load((c.root / 'charts/calico.yaml').read_text())
        container = rendered['spec']['template']['spec']['containers'][0]
        self.assertEqual(container['readinessProbe']['exec']['command'], ['/bin/calico-node', '-felix-ready'])
        self.assertEqual(container['livenessProbe']['exec']['command'], ['/bin/calico-node', '-felix-live'])
        self.assertEqual(container['imagePullPolicy'], 'Never')

    def test_accepted_profile_reuses_all_committed_image_digests(self):
        c = Cluster(HERE / 'profile.json', str(self.root / 'artifacts'))
        release = json.loads((HERE / 'artifacts.lock.json').read_text())
        expected = {x['id']: x['index_digest'] for x in release['images']}
        self.assertEqual({x['id']: x['index_digest'] for x in c.image_sources()}, expected)


if __name__ == '__main__':
    unittest.main()
