#!/usr/bin/env python3
"""Fetch only a reviewed public package manifest; no source or credentials needed."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
import urllib.parse

ALLOWED = {'registry.npmjs.org', 'files.pythonhosted.org', 'pypi.tuna.tsinghua.edu.cn'}


def checksum(path, algorithm):
    h = hashlib.new(algorithm)
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()


def fetch(item, root, deadline, minimum_free, limit_rate=None):
    relative = Path(item['path'])
    if relative.is_absolute() or '..' in relative.parts or len(relative.parts) != 2:
        raise ValueError('Unsafe artifact path')
    if item['algorithm'] not in ['sha256', 'sha512']: raise ValueError('Unsupported digest')
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if checksum(target, item['algorithm']) != item['checksum']: raise ValueError('Existing artifact changed')
        return {'path': item['path'], 'reused': True, 'bytes': target.stat().st_size}
    partial = target.with_suffix(target.suffix + '.partial')
    failures = []
    for address in item['urls']:
        url = urllib.parse.urlsplit(address)
        if url.scheme != 'https' or url.hostname not in ALLOWED or url.username or url.password or url.query:
            raise ValueError('Unapproved public URL')
        for attempt in range(2):
            if time.monotonic() > deadline: raise RuntimeError('Download time budget exhausted')
            if shutil.disk_usage(root).free < minimum_free: raise RuntimeError('Remote disk reserve reached')
            # Curl follows HTTPS only; the effective host is checked before admission.
            command = ['curl', '--fail', '--silent', '--show-error', '--location', '--proto', '=https',
                       '--proto-redir', '=https', '--connect-timeout', '10', '--max-time', '90',
                       '--max-filesize', str(200 * 1024**2), '--output', str(partial),
                       '--write-out', '%{url_effective}', address]
            if limit_rate: command += ['--limit-rate', limit_rate]
            p = subprocess.run(command, capture_output=True, text=True, timeout=100)
            if p.returncode == 0:
                if urllib.parse.urlsplit(p.stdout).hostname not in ALLOWED:
                    raise RuntimeError('Unexpected redirected host')
                if checksum(partial, item['algorithm']) != item['checksum']:
                    raise RuntimeError('Downloaded package checksum mismatch: ' + item['path'])
                partial.replace(target)
                return {'path': item['path'], 'source': address, 'effective_url': p.stdout,
                        'bytes': target.stat().st_size, 'prior_failures': failures}
            failures.append({'url': address, 'attempt': attempt + 1, 'exit_code': p.returncode})
            time.sleep(1)
    raise RuntimeError('Public package download failed: ' + item['path'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--minutes', type=int, default=20)
    parser.add_argument('--reserve-gib', type=int, default=8)
    parser.add_argument('--limit-rate', help='Optional per-download curl rate limit, e.g. 32k')
    args = parser.parse_args()
    args.root.mkdir(parents=True, exist_ok=True)
    data = json.loads(args.manifest.read_text())
    deadline = time.monotonic() + args.minutes * 60
    receipts = []
    failed = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs = {pool.submit(fetch, item, args.root, deadline, args.reserve_gib * 1024**3, args.limit_rate): item
                for item in data['artifacts']}
        for future in concurrent.futures.as_completed(jobs):
            try: receipts.append(future.result())
            except Exception as exc:
                failed.append({'path': jobs[future]['path'], 'error': str(exc)})
            if (len(receipts) + len(failed)) % 25 == 0:
                print('Completed', len(receipts), 'failed', len(failed), 'of', len(jobs), flush=True)
    report = {'manifest_sha256': checksum(args.manifest, 'sha256'),
              'artifacts': receipts, 'failures': failed, 'complete': not failed}
    (args.root / ('receipt-' + str(time.time_ns()) + '.json')).write_text(json.dumps(report, indent=2) + '\n')
    print('Complete:', not failed, 'files:', len(receipts), 'bytes:', sum(x['bytes'] for x in receipts), flush=True)
    if failed: raise SystemExit(1)


if __name__ == '__main__':
    main()
