#!/usr/bin/env python3
"""One hidden, read-only native allocation query for explicit capacity admission.

Not called by the hourly monitor. WSL interop unavailable => admission fails.
"""
import base64
import json
from pathlib import Path
import subprocess


def probe():
    script = Path(__file__).with_name('windows-capacity.ps1').read_text()
    encoded = base64.b64encode(script.encode('utf-16le')).decode('ascii')
    result = subprocess.run([
        '/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe',
        '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden',
        '-EncodedCommand', encoded], capture_output=True, timeout=45)
    if result.returncode:
        raise ValueError('Windows allocation probe failed; no capacity admission')
    value = json.loads(result.stdout.decode('utf-8-sig'))
    for key in ('CFreeBytes', 'DataVhdLength', 'DataVhdAllocatedBytes'):
        if type(value.get(key)) is not int or value[key] < 0:
            raise ValueError('Invalid Windows allocation measurement')
    if value.get('PhysicalAllocationVerified') is not True:
        raise ValueError('Native allocation verification missing')
    policy = json.loads(Path(__file__).with_name('policy.json').read_text())
    maximum = policy['capacity']['data_maximum_gib']
    if type(maximum) is not int or maximum != value.get('TargetGiB'):
        raise ValueError('Windows probe and configured maximum differ')
    value['remaining_data_growth_bytes'] = max(
        0, maximum*1024**3-value['DataVhdAllocatedBytes'])
    return value


if __name__ == '__main__':
    try:
        print(json.dumps(probe()))
    except Exception as error:
        raise SystemExit('Capacity query failed: '+type(error).__name__) from None
