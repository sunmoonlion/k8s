"""Offline package, permissions and deployment wiring checks; never touches AIStor."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.parse import urlsplit
import warnings
import zipfile

import yaml
from jinja2 import Environment, StrictUndefined

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
spec = importlib.util.spec_from_file_location('release_upload', HERE / 'upload.py')
upload = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upload)


def bundle(path='app/file.txt', *, duplicate=False):
    data = b'fixture installer file'
    manifest = dict(schema=1, platform='win32', architecture='x64', relayProtocol=1,
                    agentVersion='0.2.1', codexVersion='0.155.1', sourceRevision='a'*40,
                    files=[dict(path=path, size=len(data), sha256=hashlib.sha256(data).hexdigest())])
    body = json.dumps(manifest).encode()
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as z:
        z.writestr('bundle-manifest.json', body)
        z.writestr(path, data)
        if duplicate:
            with warnings.catch_warnings():
                warnings.simplefilter('ignore')
                z.writestr(path, data)
    release = dict(bucket='agent-releases', object_key='windows-x64/0.2.1/agent.zip', version='0.2.1',
                   source_revision='a'*40, codex_version='0.155.1', size_bytes=len(stream.getvalue()),
                   zip_sha256=hashlib.sha256(stream.getvalue()).hexdigest(), manifest_sha256=hashlib.sha256(body).hexdigest())
    stream.seek(0)
    return stream, release


def linux_bundle(*, link=False, platform='linux', tamper=False):
    """Linux 包（分身测试的测试电脑用）：.tar.gz，根目录下是包的内容。"""
    import tarfile
    data = b'fixture linux file'
    manifest = dict(schema=1, platform=platform, architecture='x64', relayProtocol=1,
                    agentVersion='0.4.1', codexVersion='0.155.1', sourceRevision='c'*40,
                    files=[dict(path='app/dist/cli.js', size=len(data), sha256=hashlib.sha256(data).hexdigest())])
    body = json.dumps(manifest).encode()
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w:gz') as t:
        def add(name, content):
            info = tarfile.TarInfo(name)
            info.size = len(content)
            t.addfile(info, io.BytesIO(content))
        root = tarfile.TarInfo('.')
        root.type = tarfile.DIRTYPE
        t.addfile(root)
        add('./bundle-manifest.json', body)
        add('./app/dist/cli.js', data + (b'x' if tamper else b''))
        if link:
            info = tarfile.TarInfo('./app/dist/evil')
            info.type = tarfile.SYMTYPE
            info.linkname = '/etc/passwd'
            t.addfile(info)
    release = dict(bucket='agent-releases', object_key='linux-x64/0.4.1/agent.tar.gz', version='0.4.1',
                   source_revision='c'*40, codex_version='0.155.1', size_bytes=len(stream.getvalue()),
                   tarball_sha256=hashlib.sha256(stream.getvalue()).hexdigest(),
                   manifest_sha256=hashlib.sha256(body).hexdigest())
    stream.seek(0)
    return stream, release


class LinuxBundleChecks(unittest.TestCase):
    def test_verified_linux_inventory(self):
        stream, release = linux_bundle()
        checked = upload.verify_tarball(stream, release)
        self.assertEqual(checked['files'], 2)
        self.assertEqual(checked['tarball_sha256'], release['tarball_sha256'])

    def test_links_tamper_platform_and_key_are_refused(self):
        for kind in ('link', 'tamper', 'platform'):
            stream, release = linux_bundle(**{kind: True} if kind != 'platform' else {'platform': 'win32'})
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                upload.verify_tarball(stream, release)
        stream, release = linux_bundle()
        with self.assertRaises(ValueError):
            upload.verify_tarball(stream, dict(release, object_key='windows-x64/0.4.1/agent.tar.gz'))
        stream, release = linux_bundle()
        with self.assertRaises(ValueError):
            upload.verify_tarball(stream, dict(release, tarball_sha256='0'*64))

    def test_linux_publish_uses_its_own_digest_and_content_type(self):
        stream, release = linux_bundle()
        writer, reader = Mock(), Mock()
        writer.request.side_effect = [(200, {}, None), (403, {}, None)]
        reader.request.side_effect = [(200, {'x-amz-meta-sha256': release['tarball_sha256'],
                                             'x-amz-meta-manifest-sha256': release['manifest_sha256']},
                                       (release['tarball_sha256'], release['size_bytes'])), (403, {}, None)]
        result = upload.publish(stream, release, writer, reader,
                                digest_key='tarball_sha256', content_type='application/gzip')
        self.assertTrue(result['readback_verified'])
        put = writer.request.call_args_list[0]
        self.assertEqual(put.kwargs['digest'], release['tarball_sha256'])
        self.assertEqual(put.kwargs['content_type'], 'application/gzip')

    def test_linux_release_is_pinned_and_make_targets_exist(self):
        cfg = yaml.safe_load((HERE / 'config.yaml').read_text())['investment_agent_releases']['linux']
        self.assertRegex(cfg['object_key'], r'^linux-x64/0\.4\.1/.+\.tar\.gz$')
        self.assertRegex(cfg['tarball_sha256'], '^[a-f0-9]{64}$')
        self.assertRegex(cfg['source_revision'], '^[a-f0-9]{40}$')
        makefile = (ROOT / 'infrastructure/Makefile').read_text()
        self.assertIn('agent-release-linux-upload agent-release-linux-verify:', makefile)
        self.assertIn('agent_release_platform=linux', makefile)


class UploadChecks(unittest.TestCase):
    def test_verified_inventory(self):
        stream, release = bundle()
        self.assertEqual(upload.verify_zip(stream, release)['files'], 2)
        self.assertEqual(stream.tell(), 0)

    def test_invalid_digests_and_identity(self):
        for field, value in [('zip_sha256', 'b'*64), ('manifest_sha256', 'b'*64), ('size_bytes', 1),
                             ('version', '0.3.0'), ('source_revision', 'c'*40), ('codex_version', '0.100.0')]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                stream, release = bundle()
                upload.verify_zip(stream, release | {field: value})

    def test_malicious_paths_and_duplicates(self):
        for path in ['../outside', '/absolute', 'app/../outside', 'app\\escape', 'app/NUL.txt', 'app/file.']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                upload.verify_zip(*bundle(path))
        with self.assertRaises(ValueError):
            upload.verify_zip(*bundle(duplicate=True))

    def test_publish_uses_distinct_credentials_and_repeat_never_overwrites(self):
        for status in (200, 412):
            stream, release = bundle()
            writer, reader = Mock(), Mock()
            writer.request.side_effect = [(status, {}, None), (403, {}, None)]
            reader.request.side_effect = [
                (200, {'x-amz-meta-sha256':release['zip_sha256'], 'x-amz-meta-manifest-sha256':release['manifest_sha256']},
                 (release['zip_sha256'], release['size_bytes'])), (403, {}, None)]
            result = upload.publish(stream, release, writer, reader)
            self.assertEqual(result['uploaded'], status == 200)
            self.assertEqual(writer.request.call_args_list[0].args, ('PUT', release['object_key']))
            self.assertEqual(reader.request.call_args_list[0].args, ('GET', release['object_key']))
            self.assertEqual(reader.request.call_args_list[1].kwargs['headers'], ('If-None-Match: *',))

    def test_conflict_and_bad_readback_stop(self):
        for status in (301, 307, 403, 409, 500):
            stream, release = bundle()
            writer, reader = Mock(), Mock()
            writer.request.return_value = status, {}, None
            with self.assertRaises(ValueError):
                upload.publish(stream, release, writer, reader)
            reader.request.assert_not_called()
        stream, release = bundle()
        writer, reader = Mock(), Mock()
        writer.request.return_value = 200, {}, None
        reader.request.return_value = 200, {}, ('bad', 0)
        with self.assertRaises(ValueError):
            upload.publish(stream, release, writer, reader)

    def test_curl_credentials_are_private_and_no_proxy_redirect_overrides(self):
        with tempfile.TemporaryDirectory() as folder:
            client = upload.S3Curl(Path(folder), 's3.example', 1234, '/ca', 'us-east-1', 'reader', 'a'*40)
            self.assertNotIn('a'*40, str(client.base))
            self.assertEqual(client.base[:2], ['curl', '-q'])
            self.assertEqual(client.config.stat().st_mode & 0o777, 0o600)
            self.assertNotIn('--location', client.base)
            self.assertIn('--cacert', client.base)
            self.assertIn('--aws-sigv4', client.base)

    def test_exact_bucket_policies_and_nonroot_job(self):
        cfg = yaml.safe_load((HERE/'config.yaml').read_text())['investment_agent_releases']
        rendered = Environment().from_string((HERE/'workload.yaml.j2').read_text()).render(
            investment_agent_releases=cfg, data_namespace='data-platform-dev', registry_address='registry.example',
            image_map={'aistor-mc':{'manifest_digest':'sha256:'+'a'*64}})
        policy, job = list(yaml.safe_load_all(rendered))
        for role, action in [('reader','s3:GetObject'), ('writer','s3:PutObject')]:
            statements = json.loads(policy['data'][role+'.json'])['Statement']
            self.assertEqual(statements, [dict(Effect='Allow', Action=[action], Resource=['arn:aws:s3:::agent-releases/*'])])
        self.assertTrue(job['spec']['template']['spec']['securityContext']['runAsNonRoot'])
        self.assertIn('mc anonymous set none owned/agent-releases', rendered)
        self.assertNotIn('ttlSecondsAfterFinished', rendered)
        self.assertFalse(cfg['enabled'], 'Candidate must remain unpublished')
        self.assertFalse(cfg['download_available'])

    def test_curl_signed_conditional_stream_and_final_headers(self):
        with tempfile.TemporaryDirectory() as folder, tempfile.TemporaryFile() as payload:
            payload.write(b'zip fixture')
            payload.seek(0)
            client = upload.S3Curl(Path(folder), 's3.example', 1234, '/ca', 'us-east-1', 'writer', 'a'*40)
            def process(argv, **kwargs):
                self.assertIn('If-None-Match: *', argv)
                self.assertIn('x-amz-content-sha256: ' + 'b'*64, argv)
                self.assertIn('/proc/self/fd/' + str(payload.fileno()), argv)
                self.assertEqual(kwargs['pass_fds'], (payload.fileno(),))
                self.assertNotIn('a'*40, str(argv))
                Path(argv[argv.index('--dump-header')+1]).write_text('HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nx-amz-meta-sha256: value\r\n\r\n')
                return Mock(stdout=io.BytesIO(b'response'), wait=Mock(return_value=0), poll=Mock(return_value=0))
            with patch.object(upload.subprocess, 'Popen', side_effect=process):
                status, headers, body = client.request('PUT', 'windows-x64/0.2.1/agent.zip', stream=payload, digest='b'*64, metadata='c'*64)
            self.assertEqual(status, 200)
            self.assertEqual(headers['x-amz-meta-sha256'], 'value')
            self.assertEqual(body, (hashlib.sha256(b'response').hexdigest(), 8))

    def test_graph_and_api_wiring(self):
        backend = HERE.parent
        stage = yaml.safe_load((backend/'stage.yaml').read_text())['stages']
        release_stage = next(s for s in stage if s['name'] == 'investment-agent-releases')
        self.assertEqual(release_stage['dependsOn'], ['object-storage'])
        runtime = next(s for s in stage if s['name'] == 'investment-runtime')
        self.assertIn('investment-agent-releases', runtime['dependsOn'])
        template = (ROOT/'gitops/components/app-platform/common/backend/runtime/workload.yaml.j2').read_text()
        self.assertEqual(template.count("agent_releases_enabled | default(false) and role == 'api'"), 3)
        self.assertIn("agent_releases_enabled | default(false) and role == \"api\"", template)
        prepare = (HERE/'prepare.yaml').read_text()
        self.assertIn('tasks/component-input.yaml', prepare)
        self.assertIn('tasks/encrypt.yaml', prepare)
        self.assertIn('secret_key=agent_release_private.reader_secret', prepare)

    def test_real_runtime_template_only_api_gets_reader(self):
        env = Environment(undefined=StrictUndefined)
        env.filters.update(to_json=json.dumps, bool=bool, urlsplit=lambda u,k:getattr(urlsplit(u),k))
        source = ROOT/'gitops/components/app-platform/common/backend/runtime/workload.yaml.j2'
        template = env.from_string(source.read_text())
        app = HERE.parent.parent
        cfg = yaml.safe_load((app/'config.yaml').read_text())['investment_deployment']
        cfg.update(yaml.safe_load((HERE.parent/'config.yaml').read_text())['investment_backend_deployment'])
        cfg.update(namespace='app-platform-dev', web_origin='https://investment.example:30443', admin_origin='https://investment-admin.example:30443')
        context = dict(application_name='investment', cfg=cfg, app_namespace='app-platform-dev', data_namespace='data-platform-dev', ingress_namespace='ingress-platform-dev',
                       deployment_id='fixture-release', runtime_config_digest='a'*64, registry_address='registry.example', cluster_pod_subnet='10.0.0.0/16',
                       storage_enabled=False, provider_enabled=False, receiver_enabled=False, service_enabled=False,
                       runner_enabled=True, domain_secrets_enabled=True,
                       app_images={'backend':yaml.safe_load((HERE.parent/'image.lock.yaml').read_text())},
                       lookup=lambda _, key: {'sandbox_namespace':'sandbox-platform-dev','relay_namespace':'relay-platform-dev'}[key])
        before = list(yaml.safe_load_all(template.render(**context, agent_releases_enabled=False)))
        after = list(yaml.safe_load_all(template.render(**context, agent_releases_enabled=True)))
        changed = []
        for old, new in zip(before, after, strict=True):
            if old != new:
                changed.append(new['metadata']['name'])
        self.assertEqual(changed, ['investment-api'])
        api = next(o for o in after if o['metadata']['name'] == 'investment-api' and o['kind'] == 'Deployment')
        pod = api['spec']['template']['spec']
        self.assertIn({'secretRef': {'name':'investment-agent-releases-runtime'}}, pod['containers'][0]['envFrom'])
        self.assertIn('agent-releases-ca', [v['name'] for v in pod['volumes']])


if __name__ == '__main__':
    unittest.main()
