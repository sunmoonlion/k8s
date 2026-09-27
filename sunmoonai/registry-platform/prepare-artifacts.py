#!/usr/bin/env python3
"""Download the locked public official installer, resumably; never install/load it.

Default is a pure plan. --apply uses an isolated local material directory.
Local code only; SSH/cloud deployment is not implemented or validated here.
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.home() / 'packages-to-be-installed/releases/registry-platform-2.13.2-linux-amd64')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--attempts', type=int, default=3)
    parser.add_argument('--seconds-per-attempt', type=int, default=180)
    args = parser.parse_args()
    lock = HERE / 'artifacts.lock.json'
    manifest = json.loads(lock.read_text())
    if manifest['harbor_version'] != '2.13.2' or not 1 <= args.attempts <= 5 or not 10 <= args.seconds_per_attempt <= 300:
        raise ValueError('Unsupported version or unbounded retry policy')
    root = args.root.expanduser().absolute()
    allowed = Path.home() / 'packages-to-be-installed/releases'
    if not root.is_relative_to(allowed) or root == allowed or root.resolve() != root:
        raise ValueError('Use a nonsymlink batch under ~/packages-to-be-installed/releases')
    print(json.dumps({'dry_run': not args.apply, 'root': str(root), 'artifacts': manifest['artifacts']}, indent=2), flush=True)
    if not args.apply:
        return
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (root / '.prepare.lock').open('a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
        receipt = {'started_at': dt.datetime.now(dt.timezone.utc).isoformat(),
                   'manifest_sha256': digest(lock), 'attempts': [], 'complete': False}
        for item in manifest['artifacts']:
            name = item['name']
            if Path(name).name != name or item['url'] != 'https://github.com/goharbor/harbor/releases/download/v2.13.2/'+name:
                raise ValueError('Unexpected upstream artifact')
            target = root / name
            partial = root / (name+'.partial')
            for path in [target, partial]:
                if path.is_symlink():
                    raise ValueError('Artifact symlink refused')
            if target.exists():
                if target.stat().st_size != item['bytes'] or digest(target) != item['sha256']:
                    raise ValueError('Existing final artifact differs; preserve and investigate')
                continue
            for attempt in range(args.attempts):
                if partial.exists() and partial.stat().st_size == item['bytes']:
                    break
                if partial.exists() and partial.stat().st_size > item['bytes']:
                    raise ValueError('Oversize partial retained for inspection')
                if shutil.disk_usage(root).free < 20*1024**3:
                    raise RuntimeError('Material volume reserve below 20 GiB')
                command = ['curl', '--fail', '--location', '--silent', '--show-error',
                           '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '15',
                           '--max-time', str(args.seconds_per_attempt), '--max-filesize', str(item['bytes']),
                           '--continue-at', '-', '--output', str(partial), item['url']]
                result = subprocess.run(command, capture_output=True, text=True, timeout=args.seconds_per_attempt+30)
                receipt['attempts'].append({'artifact': name, 'attempt': attempt+1,
                                            'exit_code': result.returncode,
                                            'partial_bytes': partial.stat().st_size if partial.exists() else 0})
                print(json.dumps(receipt['attempts'][-1]), flush=True)
                if result.returncode == 0:
                    break
            if not partial.exists() or partial.stat().st_size != item['bytes'] or digest(partial) != item['sha256']:
                filename = 'incomplete-'+dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')+'.json'
                (root / filename).write_text(json.dumps(receipt, indent=2)+'\n')
                raise RuntimeError('Installer incomplete or checksum mismatch; partial retained, no install/load performed')
            partial.rename(target)
        receipt['complete'] = True
        receipt['completed_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
        receipt['artifacts'] = [{'name': i['name'], 'bytes': (root/i['name']).stat().st_size,
                                 'sha256': digest(root/i['name'])} for i in manifest['artifacts']]
        output = root / ('verified-'+dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')+'.json')
        with output.open('x') as stream:
            json.dump(receipt, stream, indent=2)
            stream.write('\n')
        print('Verified installer only:', output, flush=True)


if __name__ == '__main__':
    main()
