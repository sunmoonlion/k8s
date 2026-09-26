#!/usr/bin/env python3
"""Prepare an explicit template build batch; never deploy, push, or prune."""
import argparse
import base64
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import tarfile
import tempfile
import time
import uuid

HERE = Path(__file__).resolve().parent


def digest(path, algorithm='sha256'):
    h = hashlib.new(algorithm)
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    data = json.dumps(value, indent=2) + '\n'
    fd, tmp = tempfile.mkstemp(dir=path.parent)
    with os.fdopen(fd, 'w') as stream:
        stream.write(data)
    os.replace(tmp, path)


class Batch:
    def __init__(self, profile):
        self.profile = Path(profile)
        self.p = json.loads(self.profile.read_text())
        self.root = Path(self.p['root']).expanduser()
        self.sources = Path(self.p['source_root']).expanduser()
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.root.chmod(0o700)
        for name in ['sources', 'images', 'tools', 'packages', 'work', 'evidence']:
            (self.root / name).mkdir(exist_ok=True, mode=0o700)
        path = self.root / 'preparation.json'
        self.state = json.loads(path.read_text()) if path.exists() else {
            'profile_sha256': digest(self.profile), 'batch': self.p['batch'], 'artifacts': {}, 'checks': []}
        if self.state['profile_sha256'] != digest(self.profile):
            raise ValueError('Profile changed; create a different batch')

    def save(self):
        write(self.root / 'preparation.json', self.state)

    def budget(self):
        used = sum(p.stat().st_size for p in self.root.rglob('*') if p.is_file() and not p.is_symlink())
        if used >= self.p['max_bytes'] or shutil.disk_usage(self.root).free < 20 * 1024**3:
            raise RuntimeError('Batch storage threshold reached; retained completed artifacts')

    def run(self, args, timeout=300, attempts=1, expected=0):
        self.budget()
        for attempt in range(1, attempts + 1):
            stamp = dt.datetime.now().strftime('%Y%m%dT%H%M%S%f')
            log = self.root / 'evidence' / (stamp + '.log')
            print('RUN', Path(str(args[0])).name, 'attempt', attempt, 'log', log.name, flush=True)
            start = time.monotonic()
            code = -1
            with log.open('w') as out:
                try:
                    proc = sp.run([str(a) for a in args], stdout=out, stderr=sp.STDOUT, timeout=timeout)
                    code = proc.returncode
                except sp.TimeoutExpired:
                    out.write('\nTIMEOUT: command stopped; partial artifacts retained\n')
            log.chmod(0o600)
            write(log.with_suffix('.json'), {'command': [str(a) for a in args], 'exit_code': code,
                'attempt': attempt, 'seconds': round(time.monotonic() - start, 2)})
            text = log.read_text(errors='replace')
            if code == expected:
                return text
            print('FAILED', code, str(log), flush=True)
            if attempt < attempts:
                time.sleep(3 * attempt)
        raise RuntimeError('Command did not meet its expected exit code; see retained evidence')

    def artifact(self, relative, **metadata):
        path = self.root / relative
        item = {'path': relative, 'sha256': digest(path), 'bytes': path.stat().st_size, **metadata}
        self.state['artifacts'][relative] = item
        self.save()
        return item

    def exists(self, relative):
        item = self.state['artifacts'].get(relative)
        if item:
            if digest(self.root / relative) != item['sha256']:
                raise ValueError('Artifact changed: ' + relative)
            return True
        if (self.root / relative).exists():
            raise ValueError('Unrecorded artifact; inspect before reusing: ' + relative)
        return False

    def download(self, url, relative, checksum=None, algorithm='sha256'):
        if self.exists(relative):
            return self.root / relative
        if not url.startswith('https://'):
            raise ValueError('Only HTTPS public downloads')
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        partial = target.with_suffix(target.suffix + '.partial')
        self.run(['curl', '--fail', '--silent', '--show-error', '--location', '--proto', '=https',
            '--proto-redir', '=https', '--connect-timeout', '15', '--max-time', '300',
            '--output', partial, url], timeout=320, attempts=3)
        if checksum and digest(partial, algorithm) != checksum:
            raise ValueError('Upstream checksum mismatch: ' + relative)
        os.replace(partial, target)
        self.artifact(relative, source=url, upstream_algorithm=algorithm if checksum else None,
                      upstream_checksum=checksum, verification='upstream-checksum' if checksum else 'TLS-metadata')
        return target

    def container(self, image, command, mounts, online=False, timeout=900, extra_env=None):
        name = 'sunmoon-material-' + uuid.uuid4().hex[:12]
        args = ['docker', 'run', '--rm', '--name', name, '--label', 'sunmoonai.material-trial=true',
            '--pull=never', '--network=bridge' if online else '--network=none',
            '--cap-drop=ALL', '--security-opt=no-new-privileges', '--pids-limit=512', '--memory=8g',
            '--user', f'{os.getuid()}:{os.getgid()}', '-e', 'HOME=/tmp/home', '-e', 'CI=true']
        if online:
            for key in ['HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'http_proxy', 'https_proxy', 'no_proxy']:
                if os.environ.get(key): args += ['-e', key]
        for key, value in (extra_env or {}).items():
            args += ['-e', key + '=' + value]
        for source, dest, ro in mounts:
            args += ['--mount', f'type=bind,source={source},target={dest}' + (',readonly' if ro else '')]
        args += [image, 'sh', '-ec', 'mkdir -p /tmp/home; ' + command]
        try:
            return self.run(args, timeout=timeout)
        finally:
            # --rm normally already cleaned the container; only remove our own
            # randomly named, labelled temporary container after a CLI timeout.
            found = sp.run(['docker', 'inspect', '--format', '{{index .Config.Labels "sunmoonai.material-trial"}}', name], capture_output=True, text=True)
            if found.returncode == 0 and found.stdout.strip() == 'true':
                sp.run(['docker', 'rm', '-f', name], stdout=sp.DEVNULL, stderr=sp.DEVNULL, check=True)

    def snapshot(self):
        for repo in self.p['repositories']:
            source = self.sources / repo['path']
            actual = self.run(['git', '-C', source, 'rev-parse', 'HEAD']).strip()
            if actual != repo['commit'] or self.run(['git', '-C', source, 'status', '--porcelain']).strip():
                raise ValueError('Source does not match clean approved commit: ' + repo['path'])
            key = repo['path'].replace('/', '--')
            bundle = 'sources/' + key + '.bundle'
            if not self.exists(bundle):
                partial = self.root / (bundle + '.partial')
                self.run(['git', '-C', source, 'bundle', 'create', partial, 'HEAD'], timeout=600)
                self.run(['git', '-C', source, 'bundle', 'verify', partial])
                os.replace(partial, self.root / bundle)
                self.artifact(bundle, repo=repo['path'], commit=actual, visibility='private-local-only')
            dest = self.root / 'work' / 'source' / repo['path']
            if (dest / '.git').exists():
                if self.run(['git', '-C', dest, 'rev-parse', 'HEAD']).strip() != actual:
                    raise ValueError('Restored source changed')
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            self.run(['git', 'clone', '--no-hardlinks', self.root / bundle, dest], timeout=300)
            self.run(['git', '-C', dest, 'checkout', '--detach', actual])
        parent = self.root / 'work/source/tpl-app'
        self.run(['git', '-C', parent, 'submodule', 'status'])
        self.state['checks'].append({'name': 'source-restored-from-bundles', 'passed': True})
        self.save()

    def bases(self):
        for key, reference in self.p['images'].items():
            relative = 'images/' + key + '.tar'
            if self.exists(relative): continue
            d = json.loads(self.run(['docker', 'image', 'inspect', reference]))[0]
            if d['Architecture'] != 'amd64' or d['Os'] != 'linux':
                raise ValueError('Wrong image platform')
            self.run(['docker', 'save', '--platform', 'linux/amd64', '-o', self.root / (relative + '.partial'), reference], timeout=600)
            os.replace(self.root / (relative + '.partial'), self.root / relative)
            self.artifact(relative, reference=reference, docker_image_id=d['Id'])

    def tools(self):
        meta = json.loads(self.download('https://registry.npmjs.org/pnpm/' + self.p['pnpm'], 'tools/pnpm-metadata.json').read_text())
        algorithm, encoded = meta['dist']['integrity'].split('-', 1)
        self.download(meta['dist']['tarball'], 'tools/pnpm.tgz', base64.b64decode(encoded).hex(), algorithm)
        meta = json.loads(self.download('https://pypi.org/pypi/uv/' + self.p['uv'] + '/json', 'tools/uv-metadata.json').read_text())
        choices = [x for x in meta['urls'] if x['filename'].endswith('manylinux_2_17_x86_64.manylinux2014_x86_64.whl')]
        if len(choices) != 1: raise ValueError('Expected one uv Linux amd64 wheel')
        entry = choices[0]
        self.download(entry['url'], 'tools/' + entry['filename'], entry['digests']['sha256'])
        node = 'node-v' + self.p['node'] + '-linux-x64.tar.xz'
        base = 'https://nodejs.org/dist/v' + self.p['node'] + '/'
        sums = self.download(base + 'SHASUMS256.txt', 'tools/node-SHASUMS256.txt').read_text()
        expected = next(line.split()[0] for line in sums.splitlines() if line.split()[-1] == node)
        self.download(base + node, 'tools/' + node, expected)

    def packages(self):
        """Prepare only locked dependencies in disposable manifest workspaces."""
        front = self.root / 'work/frontend-dependencies'
        back = self.root / 'work/backend-dependencies'
        for dest, source, files in [
            (front, 'tpl-web-frontend', ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml']),
            (back, 'tpl-backend', ['pyproject.toml', 'uv.lock']),
        ]:
            dest.mkdir(exist_ok=True)
            for name in files:
                src = self.root / 'work/source/tpl-app' / source / 'app' / name
                target = dest / name
                if target.exists() and digest(target) != digest(src):
                    raise ValueError('Dependency manifest changed: ' + name)
                shutil.copy2(src, target)
        for name in ['pnpm-store', 'uv-cache', 'pyright-cache']:
            (self.root / 'packages' / name).mkdir(exist_ok=True)
        tools = (self.root / 'tools', '/tools', True)
        self.container(self.p['images']['node'], '''
mkdir /tmp/pnpm
tar -xzf /tools/pnpm.tgz -C /tmp/pnpm
cd /work
node /tmp/pnpm/package/bin/pnpm.cjs fetch --frozen-lockfile --ignore-scripts --store-dir /cache --network-concurrency=3 --fetch-retries=2 --fetch-timeout=20000
''', [tools, (front, '/work', False), (self.root / 'packages/pnpm-store', '/cache', False)],
            online=True, timeout=600, extra_env={'npm_config_registry': 'https://registry.npmjs.org', 'NODE_USE_ENV_PROXY': '1'})
        self.state['checks'].append({'name': 'frontend-packages-fetched', 'passed': True,
                                    'lock_sha256': digest(front / 'pnpm-lock.yaml')})
        self.save()
        self.container(self.p['images']['python'], '''
python -m pip install --no-index --no-deps --target /tmp/bootstrap /tools/uv-0.11.32-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
python -c "import tarfile; tarfile.open('/tools/node-v24.18.0-linux-x64.tar.xz').extractall('/tmp/node', filter='data')"
export PATH=/tmp/node/node-v24.18.0-linux-x64/bin:/tmp/bootstrap/bin:$PATH
cd /work
uv sync --locked --no-managed-python --python /usr/local/bin/python
.venv/bin/pyright --version
''', [tools, (back, '/work', False), (self.root / 'packages/uv-cache', '/cache/uv', False),
            (self.root / 'packages/pyright-cache', '/cache/pyright', False)], online=True, timeout=600,
            extra_env={'UV_CACHE_DIR': '/cache/uv', 'UV_LINK_MODE': 'copy', 'UV_HTTP_RETRIES': '2',
                       'UV_HTTP_TIMEOUT': '20', 'UV_CONCURRENT_DOWNLOADS': '3',
                       'PYRIGHT_PYTHON_CACHE_DIR': '/cache/pyright',
                       'npm_config_registry': 'https://registry.npmjs.org', 'npm_config_fetch_retries': '2',
                       'npm_config_fetch_timeout': '20000', 'NODE_USE_ENV_PROXY': '1'})
        self.state['checks'].append({'name': 'backend-packages-fetched', 'passed': True,
                                    'lock_sha256': digest(back / 'uv.lock')})
        self.save()

    def plan(self):
        print(json.dumps({'profile': self.p, 'scope': 'template source restore and offline build trial; no deployment or registry push',
            'source_delivery': 'self-contained local Git bundles', 'network': 'prepare: explicit proxy; trial: Docker network none and pull never',
            'existing_artifacts': len(self.state['artifacts'])}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', default=str(HERE / 'profile.json'))
    parser.add_argument('action', choices=['plan', 'snapshot', 'bases', 'tools', 'packages'])
    args = parser.parse_args()
    batch = Batch(args.profile)
    with open(batch.root / '.operation.lock', 'a') as gate:
        fcntl.flock(gate, fcntl.LOCK_EX | fcntl.LOCK_NB)
        getattr(batch, args.action)()


if __name__ == '__main__':
    main()
