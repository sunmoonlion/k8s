#!/usr/bin/env python3
"""Fail closed unless the configured data disk is visible to host and Docker."""
import json
import os
from pathlib import Path
import subprocess
import sys


def output(argv):
    return subprocess.check_output(argv, text=True, timeout=30).strip()


def main():
    with open(sys.argv[1], encoding='utf-8') as stream:
        config = json.load(stream)
    for expected in config['mounts']:
        rows = json.loads(output(['findmnt', '--json', '--target', expected['target'],
                                  '--output', 'TARGET,FSTYPE,UUID,FSROOT']))['filesystems']
        if len(rows) != 1 or any(rows[0].get(k) != v for k, v in {
                'target': expected['target'], 'fstype': 'ext4',
                'uuid': config['uuid'], 'fsroot': expected['fsroot']}.items()):
            raise ValueError(f"Storage identity mismatch: {expected['target']}")
    root = Path(config['data_root'])
    if str(root.resolve()) != str(root) or not root.is_dir():
        raise ValueError('Data root is missing or is a symlink')
    actual = os.stat(root)
    host = f'{actual.st_dev}:{actual.st_ino}'
    docker = output(['docker', 'run', '--rm', '--pull=never', '--network=none', '--read-only',
                     '--entrypoint=stat', '--mount', f'type=bind,source={root},target=/probe,readonly',
                     config['probe_image'], '-c', '%d:%i', '/probe'])
    if host != docker:
        raise ValueError('Docker does not see the configured host data root')
    for directory in ([] if '--mounts-only' in sys.argv[2:] else config['directories']):
        path = Path(directory)
        if not path.is_dir() or path.resolve() != path or not path.is_relative_to(root):
            raise ValueError(f'Invalid instance directory: {directory}')
        if os.stat(path).st_dev != actual.st_dev:
            raise ValueError(f'Instance directory is on a different filesystem: {directory}')
    print('Registry storage identity and Docker visibility verified.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as exc:
        sys.exit(f'Registry storage check failed: {exc}')
