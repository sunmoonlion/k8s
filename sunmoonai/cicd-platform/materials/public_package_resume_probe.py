#!/usr/bin/env python3
"""Interrupt only our public downloader process group, then verify safe reuse."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess as sp
import time

from public_package_fetch import checksum


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=Path, required=True)
    args = parser.parse_args()
    root = args.batch.resolve()
    allowed = Path.home() / '.cache/sunmoon-artifacts'
    if not root.is_relative_to(allowed): raise ValueError('Only the approved public staging root is allowed')
    manifest = json.loads((root / 'public-package-manifest.json').read_text())
    entries = sorted(manifest['artifacts'], key=lambda x: (root / 'archives' / x['path']).stat().st_size)
    small, large = entries[0], entries[-1]
    work = root / ('interruption-proof-' + str(time.time_ns()))
    archives = work / 'archives'; archives.mkdir(parents=True)
    subset = {'schema': 1, 'artifacts': [small, large]}
    plan = work / 'public-subset.json'; plan.write_text(json.dumps(subset, indent=2) + '\n')
    completed = archives / small['path']; completed.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / 'archives' / small['path'], completed)
    before = checksum(completed, small['algorithm'])
    assert before == small['checksum']
    command = ['python3', str(root / 'public_package_fetch.py'), str(plan), '--root', str(archives), '--minutes', '2']
    partial = (archives / large['path']).with_suffix('.tgz.partial' if large['path'].endswith('.tgz') else '.whl.partial')
    with (work / 'interrupted.log').open('wb') as log:
        process = sp.Popen(command + ['--limit-rate', '32k'], stdout=log, stderr=sp.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                if process.poll() is not None: raise RuntimeError('Downloader exited before interruption')
                if partial.exists() and partial.stat().st_size > 0: break
                time.sleep(0.1)
            else: raise RuntimeError('No partial transfer to interrupt')
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=10)
    if (archives / large['path']).exists(): raise RuntimeError('Incomplete download was admitted')
    if not partial.exists() or not partial.stat().st_size: raise RuntimeError('No retained partial evidence')
    interrupted_size = partial.stat().st_size
    with (work / 'resumed.log').open('wb') as log:
        sp.run(command, stdout=log, stderr=sp.STDOUT, check=True, timeout=150)
    receipt = json.loads(sorted(archives.glob('receipt-*.json'))[-1].read_text())
    if not receipt['complete']: raise RuntimeError('Resume did not complete')
    reused = next(x for x in receipt['artifacts'] if x['path'] == small['path'])
    if not reused.get('reused'): raise RuntimeError('Completed artifact was not reused')
    for item in [small, large]:
        if checksum(archives / item['path'], item['algorithm']) != item['checksum']:
            raise RuntimeError('Recovered archive does not match original lock')
    report = {'passed': True, 'work': str(work), 'manifest_sha256': checksum(plan, 'sha256'),
              'completed_artifact_reused': small['path'], 'interrupted_artifact': large['path'],
              'partial_bytes_at_interruption': interrupted_size, 'incomplete_artifact_not_admitted': True,
              'original_lock_checksums_passed': True,
              'resume_semantics': 'Reuse verified completed artifacts; restart incomplete curl download. rsync handles transfer resume separately.'}
    (work / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
