#!/usr/bin/env python3
"""One approved batch only: R1 frozen cache IDs, R4 seven duplicate files.

No image/container/volume deletion. R2 is a separate, deferred decision.
Run from the luna checkout; each action writes a new evidence file.
"""
import argparse
import datetime as dt
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import socket
import stat
import subprocess

RESULTS = Path(__file__).resolve().parents[2] / 'scripts/results'


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def save(path, data):
    with path.open('x') as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False)
        stream.write('\n')


class Docker(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(240)
        self.sock.connect('/var/run/docker.sock')


def get(path):
    conn = Docker('localhost', timeout=240)
    conn.request('GET', path)
    response = conn.getresponse()
    body = response.read()
    conn.close()
    if response.status != 200:
        raise RuntimeError(f'Docker GET {path}: {response.status}')
    return json.loads(body)


def disk():
    # WSL/DrvFS stat only: no visible Windows/PowerShell process during cleanup.
    v = os.statvfs('/')
    win = os.statvfs('/mnt/c')
    vhd = Path('/mnt/c/Users/zymun/AppData/Local/Packages/CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc/LocalState/ext4.vhdx')
    return {'at': now(), 'root_used_bytes': (v.f_blocks-v.f_bfree)*v.f_frsize,
            'root_available_bytes': v.f_bavail*v.f_frsize,
            'windows': {'C_TotalBytes': win.f_blocks*win.f_frsize,
                        'C_FreeBytes': win.f_bavail*win.f_frsize,
                        'WSL_VHDX_FileLength': vhd.stat().st_size},
            'windows_measurement': 'WSL stat; physical VHDX allocation not verified'}


def protected():
    containers = get('/containers/json?all=1')
    volumes = get('/volumes').get('Volumes') or []
    return {'containers': sorted([{'id': c['Id'], 'names': c['Names'],
                                   'image_id': c['ImageID'], 'state': c['State']}
                                  for c in containers], key=lambda c: c['id']),
            'volumes': sorted(v['Name'] for v in volumes),
            'images': sorted(i['Id'] for i in get('/images/json?all=1'))}


def snapshot(output):
    data = get('/system/df')
    save(output, {'at': now(), 'disk': disk(), 'protected': protected(),
                  'layers_bytes': data['LayersSize'],
                  'images': [{k: i.get(k) for k in ['Id', 'RepoTags', 'RepoDigests', 'Size', 'SharedSize', 'Containers']}
                             for i in data['Images']],
                  'build_cache': [{k: c.get(k) for k in ['ID', 'Parents', 'Type', 'Size', 'InUse', 'Shared', 'UsageCount', 'LastUsedAt', 'CreatedAt']}
                                  for c in data['BuildCache']]})
    print('Snapshot saved:', output, flush=True)


def r1(output, maximum_bytes=None):
    manifest = RESULTS / 'luna-build-cache-candidates.20260927.json'
    raw = manifest.read_bytes()
    frozen = json.loads(raw)
    ids = set(frozen['cache_ids'])
    if len(ids) != 854 or any(not re.fullmatch('[a-z0-9]+', i) for i in ids):
        raise RuntimeError('Unexpected approved batch')
    data = get('/system/df')
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=7)
    live = {c['ID']: c for c in data['BuildCache']}
    candidates, exclusions = [], []
    for ident in sorted(ids):
        c = live.get(ident)
        if c is None:
            exclusions.append({'id': ident, 'reason': 'already absent'})
            continue
        last = c.get('LastUsedAt')
        if not last or c['InUse'] or c['Shared'] or dt.datetime.fromisoformat(last.replace('Z', '+00:00')) > cutoff:
            exclusions.append({'id': ident, 'reason': 'reference/age drift'})
            continue
        candidates.append({k: c.get(k) for k in ['ID', 'Size', 'InUse', 'Shared', 'LastUsedAt']})
    candidates.sort(key=lambda c:(c['LastUsedAt'],c['ID']))
    if maximum_bytes is not None:
        selected, total = [], 0
        for row in candidates:
            if total + row['Size'] <= maximum_bytes:
                selected.append(row);total += row['Size']
            else:
                exclusions.append({'id':row['ID'],'reason':'outside approved partial size cap'})
        candidates=selected
    if not candidates:
        raise RuntimeError('No eligible candidates; no prune issued')
    pattern = '^(' + '|'.join(c['ID'] for c in candidates) + ')$'
    # v0.29.0 boolean fields are existence selectors, not strings "true"/"false".
    # Buildx v0.33.0 requires key=value; quoted empty value matches private=true.
    # BuildKit prune itself skips InUse records; also exclude them above.
    filters = ['id~=' + pattern, 'until=168h', 'private=""']
    # Read-only preview with the exact runtime filters before using them for prune.
    preview_cmd = ['docker', 'buildx', 'du', '--builder', 'default', '--format', '{{.ID}}']
    for f in filters:
        preview_cmd += ['--filter', f]
    preview = subprocess.run(preview_cmd, capture_output=True, text=True, timeout=240, check=True)
    preview_ids = set(preview.stdout.split())
    if not preview_ids or not preview_ids.issubset({c['ID'] for c in candidates}):
        raise RuntimeError('Runtime preview escaped approved candidate intersection')
    state = {'approved_by': 'owner message 2026-09-27 R1 >=7 days',
             'manifest_sha256': hashlib.sha256(raw).hexdigest(), 'builder': 'default',
             'partial_batch_maximum_bytes': maximum_bytes,
             'partial_batch_authorization': 'owner 2026-09-28 request to reclaim some additional cache' if maximum_bytes else None,
             'candidates': candidates, 'exclusions': exclusions, 'preview_ids': sorted(preview_ids),
             'api_candidate_bytes': sum(c['Size'] for c in candidates),
             'before_disk': disk(), 'before_protected': protected(), 'started_at': now()}
    save(output.with_suffix('.preflight.json'), state)
    cmd = ['docker', 'buildx', 'prune', '--builder', 'default', '--force']
    for f in filters:
        cmd += ['--filter', f]
    log = output.with_suffix('.prune.log')
    with log.open('x') as stream:
        proc = subprocess.run(cmd, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    state.update({'exit_code': proc.returncode, 'finished_at': now(), 'after_disk': disk(),
                  'after_protected': protected(), 'command': cmd, 'output_log': str(log)})
    state['protected_unchanged'] = state['before_protected'] == state['after_protected']
    save(output, state)
    print(json.dumps({k: state[k] for k in ['exit_code', 'api_candidate_bytes', 'protected_unchanged']}), flush=True)
    if proc.returncode or not state['protected_unchanged']:
        raise RuntimeError('Inspect recorded result before further work')


def fingerprint(path):
    if path.is_symlink() or path.resolve() != path:
        raise RuntimeError('Symlink path refused')
    with path.open('rb') as stream:
        st = os.fstat(stream.fileno())
        if not stat.S_ISREG(st.st_mode) or st.st_nlink != 1:
            raise RuntimeError('Expected singly linked regular file')
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return st, digest


def r4(output):
    manifest = RESULTS / 'luna-duplicate-materials-candidates.20260927.json'
    raw = manifest.read_bytes()
    batch = json.loads(raw)['candidates']
    if len(batch) != 7:
        raise RuntimeError('Expected the approved seven-file batch')
    evidence = {'approved_by': 'owner message 2026-09-27 R4 seven verified duplicates',
                'manifest_sha256': hashlib.sha256(raw).hexdigest(), 'before_disk': disk(), 'files': []}
    for row in batch:
        source, kept = Path(row['candidate']), Path(row['retained_copy'])
        if not source.is_relative_to('/home/zymun/packages-to-be-installed/releases'):
            raise RuntimeError('Outside approved release root')
        a, ha = fingerprint(source)
        b, hb = fingerprint(kept)
        if ha != hb or ha != row['sha256'] or a.st_size != row['bytes'] or (a.st_dev, a.st_ino) == (b.st_dev, b.st_ino):
            raise RuntimeError('Duplicate verification failed')
        evidence['files'].append({'path': str(source), 'retained_copy': str(kept), 'sha256': ha,
                                  'bytes': a.st_size, 'allocated_bytes': a.st_blocks*512,
                                  'identity': [a.st_dev, a.st_ino, a.st_size, a.st_mtime_ns], 'deleted': False})
    save(output.with_suffix('.preflight.json'), evidence)
    # All seven pairs were checked before the first unlink; each is rechecked immediately before unlink.
    with output.with_suffix('.journal.jsonl').open('x') as journal:
        for row in evidence['files']:
            source = Path(row['path'])
            a, ha = fingerprint(source)
            b, hb = fingerprint(Path(row['retained_copy']))
            if [a.st_dev, a.st_ino, a.st_size, a.st_mtime_ns] != row['identity'] or ha != hb or ha != row['sha256']:
                raise RuntimeError('File changed after approval check')
            source.unlink()
            row['deleted'] = True
            journal.write(json.dumps(row) + '\n')
            journal.flush()
            os.fsync(journal.fileno())
    evidence['after_disk'] = disk()
    evidence['allocated_bytes_unlinked'] = sum(r['allocated_bytes'] for r in evidence['files'])
    save(output, evidence)
    print('Verified duplicate files removed:', len(evidence['files']), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['snapshot', 'r1', 'r4'])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--max-gib', type=int, choices=range(1,6), help='R1 only: cap partial batch to at most 5 GiB of API size')
    args = parser.parse_args()
    if args.max_gib and args.action != 'r1':
        parser.error('--max-gib applies only to r1')
    if args.output.exists() or args.output.with_suffix('.preflight.json').exists():
        raise RuntimeError('Evidence already exists; do not repeat a completed or interrupted batch')
    if args.action == 'r1':
        r1(args.output, args.max_gib*1024**3 if args.max_gib else None)
    else:
        {'snapshot':snapshot, 'r4':r4}[args.action](args.output)
