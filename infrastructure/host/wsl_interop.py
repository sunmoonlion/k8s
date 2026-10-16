#!/usr/bin/env python3
"""Check/restore the missing WSL PE handler; --apply changes only that entry.

Local WSL only. No Windows process, reboot, proxy edit, polling, or changes to
other binfmt handlers. The installed boot service calls this once per boot.
"""
import argparse
import configparser
import json
import os
from pathlib import Path

ENTRY = Path('/proc/sys/fs/binfmt_misc/WSLInterop')
GENERATED = Path('/run/systemd/generator/systemd-binfmt.service.d/override.conf')
RULE = ':WSLInterop:M::MZ::/init:P'


def check(apply=False):
    if 'microsoft' not in Path('/proc/sys/kernel/osrelease').read_text().lower():
        raise ValueError('This helper applies only to WSL')
    config = configparser.ConfigParser()
    config.read('/etc/wsl.conf')
    if not config.getboolean('interop', 'enabled', fallback=True):
        raise ValueError('Interop explicitly disabled; do not override owner configuration')
    if Path('/proc/sys/fs/binfmt_misc/status').read_text().strip() != 'enabled':
        raise ValueError('binfmt globally disabled; do not enable it implicitly')
    generated = GENERATED.read_text()
    if RULE not in generated or not Path('/init').is_file():
        raise ValueError('Expected WSL-generated restoration rule is absent')
    changed = False
    if not ENTRY.exists():
        if not apply:
            return {'available': False, 'action': 'restore missing WSLInterop', 'dry_run': True}
        if os.geteuid() != 0:
            raise ValueError('Root required for explicit handler repair')
        if os.readlink('/proc/self/ns/mnt') != os.readlink('/proc/1/ns/mnt'):
            raise ValueError('Repair requires the systemd mount namespace')
        with ENTRY.with_name('register').open('w') as stream:
            stream.write(RULE+'\n')
        changed = True
    lines = ENTRY.read_text().splitlines()
    required = {'enabled', 'interpreter /init', 'offset 0', 'magic 4d5a'}
    if not required.issubset(lines) or not any(v in ('flags: P', 'flags: PF', 'flags: FP') for v in lines):
        raise ValueError('Existing WSL handler differs; inspect instead of replacing it')
    return {'available': True, 'handler_restored': changed,
            'windows_process_started': False, 'restart_performed': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.apply)))
    except Exception as error:
        raise SystemExit('WSL interop check failed: '+(str(error) if isinstance(error, ValueError)
                                                    else type(error).__name__)) from None
