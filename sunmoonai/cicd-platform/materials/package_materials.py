#!/usr/bin/env python3
"""Lock-derived public archives and offline hydration for the template batch."""
import argparse
import base64
import fcntl
import itertools
import json
from pathlib import Path
import re
import shutil
import tarfile
import time
import tomllib
import urllib.parse
import zipfile

import yaml

from materials import Batch, HERE, digest, write


def platform_allowed(values, target):
    positive = [v for v in (values or []) if not v.startswith('!')]
    negative = [v[1:] for v in (values or []) if v.startswith('!')]
    return target not in negative and (not positive or target in positive)


def inputs(batch):
    """Recover planning inputs from bundles and query the exact offline Python base."""
    work = batch.root / 'work' / ('package-inputs-' + str(time.time_ns()))
    work.mkdir()
    for component, target, names in [
        ('tpl-web-frontend', 'frontend-dependencies', ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml']),
        ('tpl-backend', 'backend-dependencies', ['pyproject.toml', 'uv.lock']),
    ]:
        source = work / component
        restore_app(batch, component, source)
        destination = batch.root / 'work' / target
        destination.mkdir(exist_ok=True)
        for name in names:
            path = destination / name
            if path.exists() and digest(path) != digest(source / name):
                raise ValueError('Existing planning input changed: ' + name)
            shutil.copy2(source / name, path)
    tags = json.loads(batch.container(batch.p['images']['python'],
        "python -c 'import json;from pip._vendor.packaging.tags import sys_tags;print(json.dumps([str(t) for t in sys_tags()]))'", []))
    path = batch.root / 'packages/python-target-tags.json'
    if path.exists() and json.loads(path.read_text()) != tags:
        raise ValueError('Python target tags changed; use a new batch')
    write(path, tags)
    (batch.root / 'packages/pnpm-store').mkdir(exist_ok=True)
    print('Planning inputs restored from pinned bundles; exact Python target tags recorded', flush=True)


def plan(batch):
    root = batch.root
    front = root / 'work/frontend-dependencies/pnpm-lock.yaml'
    back = root / 'work/backend-dependencies/uv.lock'
    lock = yaml.safe_load(front.read_text())
    artifacts = []
    excluded = []
    for key, entry in lock['packages'].items():
        if set(entry['resolution']) != {'integrity'}: raise ValueError('Review non-registry npm dependency')
        name, version = key.rsplit('@', 1)
        if not re.fullmatch(r'(?:@[a-z0-9_.-]+/)?[a-z0-9_.-]+', name) or not re.fullmatch(r'[0-9][a-zA-Z0-9.+-]*', version):
            raise ValueError('Review unusual npm dependency')
        if not platform_allowed(entry.get('os'), 'linux') or not platform_allowed(entry.get('cpu'), 'x64'):
            excluded.append(key); continue
        algorithm, encoded = entry['resolution']['integrity'].split('-', 1)
        if algorithm != 'sha512': raise ValueError('Expected strong npm integrity')
        checksum = base64.b64decode(encoded, validate=True).hex()
        address = 'https://registry.npmjs.org/' + name + '/-/' + name.split('/')[-1] + '-' + version + '.tgz'
        artifacts.append({'ecosystem': 'npm', 'package': key, 'path': 'npm/' + checksum + '.tgz',
                          'algorithm': algorithm, 'checksum': checksum, 'urls': [address]})
    tags = json.loads((root / 'packages/python-target-tags.json').read_text())
    tag_order = {tag: i for i, tag in enumerate(tags)}
    for entry in tomllib.loads(back.read_text())['package']:
        if entry['source'] == {'virtual': '.'}: continue
        if entry['source'] != {'registry': 'https://pypi.tuna.tsinghua.edu.cn/simple'}:
            raise ValueError('Review non-public Python dependency')
        candidates = []
        for wheel in entry.get('wheels', []):
            filename = urllib.parse.unquote(urllib.parse.urlsplit(wheel['url']).path.rsplit('/', 1)[-1])
            py, abi, platform = filename[:-4].rsplit('-', 3)[-3:]
            compatible = ['-'.join(t) for t in itertools.product(py.split('.'), abi.split('.'), platform.split('.'))]
            order = min((tag_order[t] for t in compatible if t in tag_order), default=None)
            if order is not None: candidates.append((order, filename, wheel))
        if not candidates: raise ValueError('No target wheel; review source build for ' + entry['name'])
        _, filename, wheel = min(candidates, key=lambda c: c[0])
        algorithm, checksum = wheel['hash'].split(':', 1)
        original = wheel['url']
        canonical = 'https://files.pythonhosted.org' + urllib.parse.urlsplit(original).path
        artifacts.append({'ecosystem': 'python', 'package': entry['name'] + '==' + entry['version'],
                          'path': 'python/' + filename, 'algorithm': algorithm, 'checksum': checksum,
                          'bytes': wheel.get('size'), 'urls': [canonical, original]})
    result = {'schema': 1, 'platform': 'linux/amd64; npm musl and glibc; Python exact base tags',
              'artifacts': artifacts}
    path = root / 'packages/public-package-manifest.json'
    if path.exists() and json.loads(path.read_text()) != result: raise ValueError('Public manifest changed')
    write(path, result)
    write(root / 'packages/package-plan-private.json', {'source_lock_sha256': {'pnpm': digest(front), 'uv': digest(back)},
          'public_manifest_sha256': digest(path), 'excluded_non_target_npm_packages': excluded,
          'public_only_review': 'npm registry integrity-only entries; Python registry wheels; no app source, names or credentials exported'})
    print('Public plan:', len(artifacts), 'files;', len(excluded), 'non-target npm packages excluded', flush=True)


def verify(batch):
    root = batch.root
    manifest = root / 'packages/public-package-manifest.json'
    expected = json.loads((root / 'packages/package-plan-private.json').read_text())
    if digest(manifest) != expected['public_manifest_sha256']:
        raise ValueError('Public manifest changed since local planning')
    for name, path in [('pnpm', root / 'work/frontend-dependencies/pnpm-lock.yaml'),
                       ('uv', root / 'work/backend-dependencies/uv.lock')]:
        if digest(path) != expected['source_lock_sha256'][name]: raise ValueError('Source lock changed')
    receipt = []
    for item in json.loads(manifest.read_text())['artifacts']:
        path = root / 'packages/public-archives' / item['path']
        if digest(path, item['algorithm']) != item['checksum']:
            raise ValueError('Archive does not match original lock: ' + item['path'])
        receipt.append({'path': item['path'], 'sha256': digest(path), 'bytes': path.stat().st_size})
    write(root / 'packages/public-archives-verified.json', {'manifest_sha256': digest(manifest), 'artifacts': receipt})
    print('Verified locally against original lock hashes:', len(receipt), 'files', sum(x['bytes'] for x in receipt), 'bytes', flush=True)


def hydrate(batch):
    verify(batch)
    root = batch.root
    front = root / 'work/frontend-dependencies'
    manifest = json.loads((root / 'packages/public-package-manifest.json').read_text())
    work = root / 'work' / ('archive-hydration-' + str(time.time_ns()))
    work.mkdir()
    lock = yaml.safe_load((front / 'pnpm-lock.yaml').read_text())
    for item in manifest['artifacts']:
        if item['ecosystem'] == 'npm':
            lock['packages'][item['package']]['resolution']['tarball'] = 'file:/archives/' + item['path']
    # This temporary hydration input retains every dependency and original integrity.
    # Actual installation/build must use the unmodified source lockfile.
    (work / 'pnpm-lock.yaml').write_text(yaml.safe_dump(lock, sort_keys=False))
    shutil.copy2(front / 'pnpm-workspace.yaml', work / 'pnpm-workspace.yaml')
    archives = (root / 'packages/public-archives', '/archives', True)
    tools = (root / 'tools', '/tools', True)
    text = batch.container(batch.p['images']['node'], '''
mkdir /tmp/pnpm
tar -xzf /tools/pnpm.tgz -C /tmp/pnpm
cd /work
node /tmp/pnpm/package/bin/pnpm.cjs fetch --offline --frozen-lockfile --ignore-scripts --store-dir /cache
''', [tools, archives, (work, '/work', False), (root / 'packages/pnpm-store', '/cache', False)], timeout=600)
    print(text[-1500:], flush=True)
    batch.state['checks'].append({'name': 'frontend-store-hydrated-from-verified-archives', 'passed': True,
                                 'source_lock_sha256': digest(front / 'pnpm-lock.yaml')})
    batch.save()


def restore_app(batch, component, destination):
    relative = 'tpl-app/' + component
    commit = next(r['commit'] for r in batch.p['repositories'] if r['path'] == relative)
    bundle = 'sources/' + relative.replace('/', '--') + '.bundle'
    if not batch.exists(bundle): raise ValueError('Missing verified source bundle')
    # Restore from the bundle itself, without borrowing working-tree files/caches.
    repository = destination.parent / (component + '-git')
    batch.run(['git', 'clone', '--no-checkout', '--no-hardlinks', batch.root / bundle, repository])
    batch.run(['git', '-C', repository, 'cat-file', '-e', commit + '^{commit}'])
    archive = destination.parent / (component + '-source.tar')
    batch.run(['git', '-C', repository, 'archive', '--format=tar', '--output', archive, commit + ':app'])
    destination.mkdir()
    with tarfile.open(archive) as data: data.extractall(destination, filter='data')
    return commit


def trial(batch):
    verify(batch)
    for name in batch.state['artifacts']:
        if name.startswith(('tools/', 'images/')): batch.exists(name)
    root = batch.root
    work = root / 'work' / ('offline-trial-' + str(time.time_ns()))
    work.mkdir()
    report = {'network': 'Docker --network=none --pull=never; fresh application directories and venv',
              'source': {}, 'passed': False, 'work': str(work), 'started_ns': time.time_ns(),
              'scope': 'application artifacts and build checks; no OCI image publication or cluster deployment'}
    write(work / 'result.json', report)
    try:
        tools = (root / 'tools', '/tools', True)
        front = work / 'frontend'
        report['source']['frontend'] = restore_app(batch, 'tpl-web-frontend', front)
        lock_sha = digest(front / 'pnpm-lock.yaml')
        expected = json.loads((root / 'packages/package-plan-private.json').read_text())
        if lock_sha != expected['source_lock_sha256']['pnpm']: raise ValueError('Restored frontend lock mismatch')
        store = work / 'frontend-store'
        shutil.copytree(root / 'packages/pnpm-store', store)
        output = batch.container(batch.p['images']['node'], '''
mkdir /tmp/pnpm
tar -xzf /tools/pnpm.tgz -C /tmp/pnpm
ln -s /tmp/pnpm/package/bin/pnpm.cjs /tmp/pnpm/pnpm
export PATH=/tmp/pnpm:$PATH
cd /work
pnpm install --offline --frozen-lockfile --store-dir /cache --package-import-method=copy
pnpm build
pnpm prepare:standalone
test -s .next/standalone/server.js
''', [tools, (front, '/work', False), (store, '/cache', False)], timeout=900,
            extra_env={'NEXT_TELEMETRY_DISABLED': '1', 'PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD': '1',
                       'NEXT_PUBLIC_API_URL': '/api', 'NEXT_PUBLIC_APP_NAME': 'tpl',
                       'APP_ORIGIN': 'http://localhost:3000', 'BACKEND_INTERNAL_URL': 'http://127.0.0.1:8000',
                       'DEPLOYMENT_ID': 'offline-material-trial'})
        if digest(front / 'pnpm-lock.yaml') != lock_sha: raise ValueError('Frontend source lock changed during build')
        report['frontend'] = {'passed': True, 'lock_sha256': lock_sha,
                              'standalone_server_sha256': digest(front / '.next/standalone/server.js')}
        print(output[-2500:], flush=True); write(work / 'result.json', report)
        back = work / 'backend'
        report['source']['backend'] = restore_app(batch, 'tpl-backend', back)
        lock_sha = digest(back / 'uv.lock')
        if lock_sha != expected['source_lock_sha256']['uv']: raise ValueError('Restored backend lock mismatch')
        output = batch.container(batch.p['images']['python'], '''
python -m pip install --no-index --no-deps --target /tmp/bootstrap /tools/uv-0.11.32-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
python -c "import tarfile; tarfile.open('/tools/node-v24.18.0-linux-x64.tar.xz').extractall('/tmp/node', filter='data')"
export PATH=/tmp/node/node-v24.18.0-linux-x64/bin:/tmp/bootstrap/bin:$PATH
cd /work
uv export --locked --offline --all-groups --no-emit-project --format requirements-txt --output-file requirements-offline.txt
uv venv --no-managed-python --python /usr/local/bin/python
uv pip sync --python .venv/bin/python --offline --no-index --find-links /archives/python --require-hashes requirements-offline.txt
uv sync --locked --offline --no-managed-python --python /usr/local/bin/python
uv run --offline --locked ruff check app core
uv run --offline --locked ruff format --check app core
uv run --offline --locked pyright
uv run --offline --locked python -m compileall -q app core
''', [tools, (back, '/work', False), (root / 'packages/public-archives', '/archives', True)], timeout=600,
            extra_env={'UV_CACHE_DIR': '/tmp/uv-cache', 'UV_LINK_MODE': 'copy',
                       'PYRIGHT_PYTHON_IGNORE_WARNINGS': '1', 'PYRIGHT_PYTHON_GLOBAL_NODE': '1'})
        if digest(back / 'uv.lock') != lock_sha: raise ValueError('Backend source lock changed during build')
        report['backend'] = {'passed': True, 'lock_sha256': lock_sha,
                             'requirements_sha256': digest(back / 'requirements-offline.txt')}
        print(output[-3000:], flush=True)
        report['passed'] = True
    except Exception as exc:
        report['error'] = str(exc)
        raise
    finally:
        report['completed_ns'] = time.time_ns()
        write(work / 'result.json', report)
        write(root / 'offline-trial-latest.json', {'result': str(work / 'result.json'), 'passed': report['passed']})
    print('Offline application build checks passed:', work, flush=True)


def negative(batch):
    """Missing and corrupt wheel failures in disposable copies, followed by repair."""
    verify(batch)
    root = batch.root
    last = json.loads((root / 'offline-trial-latest.json').read_text())
    if not last['passed']: raise ValueError('Positive offline build must pass first')
    positive = Path(last['result']).parent
    work = root / 'work' / ('offline-negative-' + str(time.time_ns()))
    work.mkdir()
    wheels = work / 'wheels'
    shutil.copytree(root / 'packages/public-archives/python', wheels)
    selected = next(wheels.glob('fastapi-*.whl'))
    source = root / 'packages/public-archives/python' / selected.name
    requirement = positive / 'backend/requirements-offline.txt'
    report = {'scope': 'Python locked wheelhouse; fresh offline containers; source archives untouched', 'checks': []}
    def attempt(label, code):
        local = work / label; local.mkdir()
        shutil.copy2(requirement, local / 'requirements.txt')
        return batch.container(batch.p['images']['python'], '''
python -m pip install --no-index --no-deps --target /tmp/bootstrap /tools/uv-0.11.32-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
export PATH=/tmp/bootstrap/bin:$PATH
cd /work
uv venv --no-managed-python --python /usr/local/bin/python
uv pip sync --python .venv/bin/python --offline --no-index --find-links /wheels --require-hashes requirements.txt
''', [(root / 'tools', '/tools', True), (local, '/work', False), (wheels, '/wheels', True)],
           timeout=120, expected=code, extra_env={'UV_CACHE_DIR': '/tmp/uv-cache', 'UV_LINK_MODE': 'copy'})
    try:
        selected.rename(work / ('withheld-' + selected.name))
        text = attempt('missing', 1)
        if 'fastapi' not in text or 'No solution found' not in text: raise ValueError('Unexpected missing-wheel failure')
        report['checks'].append({'name': 'required-wheel-missing', 'passed': True, 'expected_exit': 1})
        shutil.copy2(source, selected)
        # Keep a structurally valid wheel so rejection must exercise the hash gate.
        with zipfile.ZipFile(selected, 'a') as archive: archive.comment = b'controlled-hash-mismatch'
        text = attempt('corrupted', 1)
        if 'Hash mismatch' not in text: raise ValueError('Unexpected corrupt-wheel failure')
        report['checks'].append({'name': 'wheel-hash-mismatch', 'passed': True, 'expected_exit': 1})
        shutil.copy2(source, selected)
        attempt('repaired', 0)
        report['checks'].append({'name': 'restored-wheelhouse-installs', 'passed': True, 'expected_exit': 0})
        verify(batch)
        report['canonical_archives_unchanged'] = True
    finally:
        write(work / 'result.json', report)
        write(root / 'offline-negative-latest.json', {'result': str(work / 'result.json'),
              'passed': len(report['checks']) == 3 and report.get('canonical_archives_unchanged', False)})
    print('Missing/corrupt/repaired offline wheelhouse checks passed:', work, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['inputs', 'plan', 'verify', 'hydrate', 'trial', 'negative'])
    args = parser.parse_args()
    batch = Batch(HERE / 'profile.json')
    with (batch.root / '.operation.lock').open('a') as gate:
        fcntl.flock(gate, fcntl.LOCK_EX | fcntl.LOCK_NB)
        globals()[args.action](batch)


if __name__ == '__main__':
    main()
