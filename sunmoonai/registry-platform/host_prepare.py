#!/usr/bin/env python3
"""Prepare a NEW independent Harbor instance from admitted recovery inputs.

Default prints only. --apply writes private config, imports missing official
images and copies registry content; never starts containers or switches ingress.
Local/cloud share rendering. Cloud host storage/SSH 未经实机验证.
"""
import argparse
import copy
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import stat
import subprocess
import tarfile
from types import SimpleNamespace

import yaml
from harbor_inputs import sha
from official_prepare import nested
from runtime_inspect import inputs, read
from runtime_config import validate_site, render
from runtime_files import render as render_files, file_permissions

GUARD = Path('/opt/sunmoon/admin/storage/storage-20260927-v2/check-storage-mounts.sh')
BASE = Path('/data/harbor/instances')


def run(argv, content=None, timeout=60):
    result = subprocess.run(argv, input=content, capture_output=True, timeout=timeout)
    if result.returncode:
        raise ValueError('Host preparation command failed: ' + argv[0] + '; private diagnostics retained in memory only')
    return result.stdout


def docker(*argv, **kwargs):
    return run(['docker', '--host', 'unix:///var/run/docker.sock', *argv], **kwargs)


def write(path, raw, uid=0, mode=0o600):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())
        os.fchown(stream.fileno(), uid, uid); os.fchmod(stream.fileno(), mode)


def directory(path, uid=0, mode=0o700):
    path.mkdir(mode=mode, exist_ok=False)
    os.chown(path, uid, uid); os.chmod(path, mode)


def load(path):
    config = json.loads(read(path))
    if config.get('schema') != 1:
        raise ValueError('Unsupported host preparation schema')
    validate_site(config['runtime'])
    if config['runtime']['write_enabled']:
        raise ValueError('Fresh restoration starts read-only; enabling writes is a separate transition')
    for field in ('source', 'tls_batch', 'installer', 'registry_archive', 'logical_export'):
        value = Path(config[field])
        if not value.is_absolute() or value.resolve() != value:
            raise ValueError('Explicit nonsymlink preparation inputs required')
    if not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', config['storage_uuid']):
        raise ValueError('Explicit data filesystem UUID required')
    if set(config['logical_sha256']) != {'registry.dump', 'globals.sql'}:
        raise ValueError('Both logical database exports must have explicit SHA256 pins')
    return config


def storage(config, minimum_gib=40):
    if os.geteuid() != 0:
        raise ValueError('Root required for host preparation and exact file ownership')
    if config['runtime']['platform'] == 'wsl':
        if GUARD.resolve() != GUARD or GUARD.stat().st_uid != 0 or GUARD.stat().st_mode & 0o022:
            raise ValueError('Storage guard ownership changed')
        run(['bash', str(GUARD), '--layout', 'sunmoon-data', '--expected-uuid', config['storage_uuid'],
             '--min-free-gib', str(minimum_gib), '--require-service-visibility'])
    else:
        # Future independent cloud host: explicitly mounted data disk, never root fallback.
        mounts = json.loads(run(['findmnt', '--json', '--mountpoint', '/data/harbor', '-o', 'TARGET,UUID,FSTYPE,OPTIONS']))['filesystems']
        if (len(mounts) != 1 or mounts[0]['uuid'] != config['storage_uuid']
                or mounts[0]['fstype'] not in ('ext4', 'xfs') or 'rw' not in mounts[0]['options'].split(',')):
            raise ValueError('Cloud registry data mount differs from explicit UUID/type')
        if Path('/data/harbor').stat().st_dev == Path('/').stat().st_dev:
            raise ValueError('Cloud registry data must not fall back to the system filesystem')
        pids = [1, int(run(['systemctl', 'show', 'docker', '--property=MainPID', '--value']).strip())]
        for pid in pids:
            if pid < 1:
                raise ValueError('Docker must be running for service mount inspection')
            view, actual = os.stat('/proc/' + str(pid) + '/root/data/harbor'), os.stat('/data/harbor')
            if (view.st_dev, view.st_ino) != (actual.st_dev, actual.st_ino):
                raise ValueError('Cloud service mount view differs')
    for path in (Path('/data/harbor'), BASE):
        if path.resolve() != path:
            raise ValueError('Symlinked instance parent refused')
        if path.exists() and (path.stat().st_uid != 0 or path.stat().st_mode & 0o022):
            raise ValueError('Instance parent ownership/mode differs')
    available = os.statvfs('/data/harbor')
    if available.f_bavail * available.f_frsize < minimum_gib * 1024**3:
        raise ValueError('Insufficient admitted data disk headroom')


def alias(record):
    return 'sunmoon-offline/harbor-runtime:2.13.2-' + record['id'].removeprefix('sha256:')


def resolve_images(config, records):
    result = copy.deepcopy(records)
    for role, record in result.items():
        if role in ('postgresql', 'redis'):
            continue
        original = record['id']
        image = json.loads(docker('image', 'inspect', alias(record)))[0]
        if image['Id'] != original:
            sock = Path(config['docker_content_socket'])
            if sock.resolve() != sock or not stat.S_ISSOCK(sock.stat().st_mode) or sock.stat().st_uid != 0:
                raise ValueError('Explicit root-owned Docker content socket required')
            def content(digest):
                if not re.fullmatch(r'sha256:[a-f0-9]{64}', digest):
                    raise ValueError('Invalid Docker content digest')
                raw = run(['ctr', '--address', str(sock), '--namespace', 'moby', 'content', 'get', digest])
                if 'sha256:' + hashlib.sha256(raw).hexdigest() != digest:
                    raise ValueError('Docker content hash mismatch')
                return json.loads(raw)
            manifest = content(image['Id'])
            if manifest.get('config', {}).get('digest') != original:
                raise ValueError('Docker manifest points to a different official image config')
            loaded = content(original)
            if loaded['rootfs']['diff_ids'] != image['RootFS']['Layers']:
                raise ValueError('Loaded image layer identities differ from official config')
        record['source_config_sha256'] = original.removeprefix('sha256:')
        record['id'] = image['Id']
    verify_images(result)
    return result


def import_missing(installer, records, root):
    existing = set(docker('image', 'ls', '--format', '{{.Repository}}:{{.Tag}}').decode().splitlines())
    missing = {record['id'] for role, record in records.items()
               if role not in ('postgresql', 'redis') and alias(record) not in existing}
    if not missing:
        return 0
    if any(role in ('postgresql', 'redis') and record['id'] in missing for role, record in records.items()):
        raise ValueError('Original PostgreSQL/Redis offline source must be admitted first')
    outer, inner = nested(installer)
    with outer, inner:
        for member in inner:
            if member.name == 'manifest.json':
                manifest = json.load(inner.extractfile(member)); break
    selected = [copy.deepcopy(item) for item in manifest if 'sha256:' + item['Config'].removesuffix('.json') in missing]
    if len(selected) != len(missing):
        raise ValueError('Missing runtime images not uniquely covered by official installer')
    wanted = set()
    for item in selected:
        digest = item['Config'].removesuffix('.json')
        item['RepoTags'] = ['sunmoon-offline/harbor-runtime:2.13.2-' + digest]
        wanted.update([item['Config'], *item['Layers']])
    found = set()
    archive = root / 'runtime-import.tar'
    outer, inner = nested(installer)
    with outer, inner, tarfile.open(archive, 'x') as output:
        for member in inner:
            if member.name not in wanted:
                continue
            if (not member.isfile() or member.name in found or PurePosixPath(member.name).is_absolute()
                    or '..' in PurePosixPath(member.name).parts):
                raise ValueError('Unexpected runtime image archive member')
            found.add(member.name)
            output.addfile(member, inner.extractfile(member))
        if found != wanted:
            raise ValueError('Incomplete selected official image archive')
        raw = json.dumps(selected).encode(); entry = tarfile.TarInfo('manifest.json'); entry.size = len(raw)
        output.addfile(entry, io.BytesIO(raw))
    docker('load', '--input', str(archive), timeout=240)
    return len(missing)


def verify_images(records):
    for record in records.values():
        image = json.loads(docker('image', 'inspect', record['id']))[0]
        if (image['Id'] != record['id'] or image['Architecture'] != 'amd64' or image['Os'] != 'linux'
                or set(image['Config'].get('Volumes') or {}) != set(record['volumes'])):
            raise ValueError('Loaded runtime image identity/volumes differ')


def registry_copy(config, root):
    archive = Path(config['registry_archive'])
    if archive.stat().st_size != config['registry_bytes'] or sha(archive) != config['registry_sha256']:
        raise ValueError('Frozen registry archive changed')
    destination = root / 'registry'; expected = {}; names = set(); total = 0
    with tarfile.open(archive) as tar:
        for item in tar:
            relative = PurePosixPath(item.name)
            if relative.is_absolute() or '..' in relative.parts or str(relative) in names or not (item.isdir() or item.isfile()):
                raise ValueError('Unsafe or duplicate registry archive member')
            names.add(str(relative)); path = destination / relative
            if item.isdir():
                path.mkdir(parents=True, exist_ok=True, mode=0o750)
                continue
            path.parent.mkdir(parents=True, exist_ok=True, mode=0o750)
            digest = hashlib.sha256()
            with tar.extractfile(item) as src, path.open('xb') as dst:
                for block in iter(lambda: src.read(1024**2), b''):
                    dst.write(block); digest.update(block)
                dst.flush(); os.fsync(dst.fileno())
            expected[str(relative)] = {'bytes': item.size, 'sha256': digest.hexdigest()}; total += item.size
    print('Registry extracted; independently rereading every file for SHA256', flush=True)
    for name, value in expected.items():
        path = destination / name
        if path.stat().st_size != value['bytes'] or sha(path) != value['sha256']:
            raise ValueError('Registry copy digest/length mismatch')
        parts = PurePosixPath(name).parts
        if 'blobs' in parts and parts[-1] == 'data' and parts[-2] != value['sha256']:
            raise ValueError('Blob content differs from its digest path')
    for path in [destination, *destination.rglob('*')]:
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            raise ValueError('Unexpected copied registry inode')
        os.chown(path, 10000, 10000); os.chmod(path, 0o750 if path.is_dir() else 0o640)
    write(root / 'registry-files.json', (json.dumps(expected, sort_keys=True) + '\n').encode())
    return {'files': len(expected), 'bytes': total, 'all_file_sha256_match': True}


def prepare(config, resume=False):
    storage(config)
    root = Path(config['runtime']['root'])
    if root.resolve() != root or (root.exists() and not resume) or (resume and not root.is_dir()):
        raise ValueError('New instance directory required; existing attempts are retained')
    if not BASE.exists():
        directory(BASE)
    lock_path = Path('/data/harbor/.instance-preparation.lock')
    fd = os.open(lock_path, os.O_CREAT | os.O_NOFOLLOW | os.O_RDWR, 0o600)
    with os.fdopen(fd, 'rb+') as lock:
        if os.fstat(lock.fileno()).st_uid != 0 or os.fstat(lock.fileno()).st_mode & 0o077:
            raise ValueError('Unsafe instance lock file')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        args = SimpleNamespace(**{k: Path(config[k]) for k in ('source', 'tls_batch', 'installer')}, ca_sha256=config['ca_sha256'])
        upstream, generated, preserved, tls, records, _ = inputs(args)
        if docker('compose', 'version', '--short').decode().strip() != '5.1.3':
            raise ValueError('Unadmitted Compose version')
        names = set(docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines())
        if any(config['runtime']['deployment'] + '-' + role in names for role in records):
            raise ValueError('Instance container name already exists')
        for name, digest in config['logical_sha256'].items():
            if name not in ('registry.dump', 'globals.sql') or sha(Path(config['logical_export']) / name) != digest:
                raise ValueError('Logical database export changed')
        if resume:
            original_config = json.loads(read(root / 'host-config.json'))
            # The first attempt predated the explicit content socket field only.
            original_config.setdefault('docker_content_socket', config['docker_content_socket'])
            if original_config != config or (root / 'preparation.json').exists() or any((root / 'registry').iterdir()):
                raise ValueError('Resume requires the same pre-copy, container-free configuration attempt')
            rows = [line[len('requirepass '):] for line in read(root / 'redis.conf').decode().splitlines() if line.startswith('requirepass ')]
            if len(rows) != 1:
                raise ValueError('Retained Redis credential missing or ambiguous')
            password = json.loads(rows[0])
        else:
            directory(root)
            write(root / 'host-config.json', (json.dumps(config, indent=2) + '\n').encode())
            password = secrets.token_urlsafe(32)
        files = render_files(generated, preserved, tls, password, False)
        compose = render(upstream, config['runtime'], records)
        for name in ('registry', 'core-data', 'redis', 'database', 'job-logs'):
            if not resume:
                directory(root / name, 1001 if name in ('redis', 'database') else 10000, 0o750)
        # Empty upstream directories are mount sources too.
        dirs = {root / name for name in ('config/core/certificates', 'config/shared/trust-certificates')}
        for name in files:
            parent = (root / name).parent
            while parent != root:
                dirs.add(parent); parent = parent.parent
        for path in sorted(dirs, key=lambda p: len(p.parts)):
            if not resume:
                directory(path, 1001 if path == root / 'pg-config' else 10000, 0o750)
        immutable = {}
        for name, raw in files.items():
            uid, _, mode = file_permissions(name)
            if resume:
                if read(root / name) != raw or (root / name).stat().st_uid != uid or stat.S_IMODE((root / name).stat().st_mode) != mode:
                    raise ValueError('Retained private runtime input changed; no overwrite')
            else:
                write(root / name, raw, uid, mode)
            immutable[name] = hashlib.sha256(raw).hexdigest()
        if resume:
            if yaml.safe_load(read(root / 'compose.yaml')) != compose:
                raise ValueError('Retained Compose differs beyond unresolved image identities')
            write(root / 'compose-before-image-resolution.yaml', read(root / 'compose.yaml'))
        imported = import_missing(args.installer, records, root)
        records = resolve_images(config, records)
        compose = render(upstream, config['runtime'], records)
        destination = root / ('compose-resolved.new' if resume else 'compose.yaml')
        write(destination, yaml.safe_dump(compose, sort_keys=False).encode())
        if resume:
            os.replace(destination, root / 'compose.yaml')
            write(root / 'host-config-before-image-resolution.json', read(root / 'host-config.json'))
            write(root / 'host-config.new', (json.dumps(config, indent=2) + '\n').encode())
            os.replace(root / 'host-config.new', root / 'host-config.json')
        immutable['compose.yaml'] = sha(root / 'compose.yaml')
        immutable['host-config.json'] = sha(root / 'host-config.json')
        resolved = json.loads(docker('compose', '-f', str(root / 'compose.yaml'), '--profile', '*', 'config', '--format', 'json'))
        if set(resolved['services']) != set(records):
            raise ValueError('Effective Compose service set differs')
        for role in ('core', 'registryctl', 'jobservice'):
            values = dict(line.split('=', 1) for line in files['config/' + role + '/env'].decode().splitlines() if '=' in line)
            if any(resolved['services'][role]['environment'].get(k) != v for k, v in values.items()):
                raise ValueError('Compose altered private environment bytes')
        print('Private runtime configuration and eight image identities verified; copying frozen registry', flush=True)
        registry = registry_copy(config, root)
        storage(config, minimum_gib=20)
        receipt = {'schema': 1, 'prepared': True, 'runtime': config['runtime'], 'images': records,
                   'immutable_files': immutable, 'registry': registry, 'database_restored': False,
                   'containers_created': False, 'services_started': False, 'imported_images': imported,
                   'effective_env_preserved': True}
        write(root / 'preparation.json', (json.dumps(receipt, indent=2) + '\n').encode())
        return {k: v for k, v in receipt.items() if k not in ('immutable_files', 'images')}


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--config', type=Path, required=True)
    p.add_argument('--apply', action='store_true'); p.add_argument('--resume-before-copy', action='store_true'); args = p.parse_args()
    config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'runtime': config['runtime'], 'registry_archive_bytes': config['registry_bytes'],
                          'new_directory_only': True, 'services_started': False, 'entry_switch': False}, indent=2)); return
    print(json.dumps(prepare(config, resume=args.resume_before_copy), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Host preparation stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld; partial output retained')) from None
