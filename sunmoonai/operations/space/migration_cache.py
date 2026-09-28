#!/usr/bin/env python3
"""One migration cleanup authorized by owner: all unused default-builder cache.

Default plan. --apply requires a new receipt path. Images/containers/volumes are
inventoried before and after; no age limit, no automatic recurring policy.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'sunmoonai/cicd-platform/materials'))
from space_reclaim_20260927 import get, disk, protected, save, now


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--apply',action='store_true')
    p.add_argument('--output',type=Path)
    a=p.parse_args()
    if not a.apply:
        print(json.dumps({'dry_run':True,'builder':'default','selection':'all unused build cache; includes internal/frontend cache',
          'age_or_size_limit':None,'keeps':'in-use cache, all Docker images, containers, volumes and Harbor data',
          'authorization':'owner migration request 2026-09-28; rebuilding accepted',
          'recurring_deletion':False}));return
    if os.geteuid()!=0 or a.output is None or not a.output.is_absolute():
        raise ValueError('Root and new absolute receipt path required')
    if a.output.resolve()!=a.output or not a.output.parent.is_dir():raise ValueError('Unsafe receipt path')
    for path in (a.output,a.output.with_suffix('.intent.json'),a.output.with_suffix('.prune.log')):
        if path.exists():raise ValueError('Existing attempt; inspect it rather than repeating')
    os.umask(0o077)
    data=get('/system/df')
    candidates=[r for r in data['BuildCache'] if not r['InUse']]
    ids=sorted(r['ID'] for r in candidates)
    if not ids or len(ids)!=len(set(ids)) or any(not re.fullmatch('[a-z0-9]+',i) for i in ids):
        raise ValueError('No unique eligible cache identities')
    selector='id~=^('+'|'.join(ids)+')$'
    if len(selector)>100000:raise ValueError('Candidate selector too large; split into reviewed batches')
    fmt='{"ID":{{json .ID}},"Reclaimable":{{json .Reclaimable}},"Shared":{{json .Shared}}}'
    out=subprocess.run(['docker','buildx','du','--builder','default','--format',fmt,'--filter',selector],
                       capture_output=True,text=True,timeout=240,check=True)
    rows=[json.loads(line) for line in out.stdout.splitlines()]
    if {r['ID'] for r in rows}!=set(ids) or any(r['Reclaimable'] not in (True,'true') for r in rows):
        raise ValueError('Cache became in use or identity changed before cleanup')
    state={'schema':1,'started_at':now(),'scope':'all unused default-builder cache for this migration only',
           'owner_authorization':'2026-09-28: caches no longer needed during migration; rebuild later',
           'candidate_count':len(ids),'ids':ids,'candidate_sha256':hashlib.sha256('\n'.join(ids).encode()).hexdigest(),
           'cache_private_api_bytes':sum(r['Size'] for r in candidates if not r['Shared']),
           'cache_shared_bytes_not_additive':sum(r['Size'] for r in candidates if r['Shared']),
           'before_disk':disk(),'before_protected':protected(),'completed':False}
    save(a.output.with_suffix('.intent.json'),state)
    command=['docker','buildx','prune','--builder','default','--all','--force','--filter',selector]
    result=None
    try:
        with a.output.with_suffix('.prune.log').open('x') as stream:
            result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=1200)
        remaining=subprocess.run(['docker','buildx','du','--builder','default','--format','{{.ID}}','--filter',selector],
                                 capture_output=True,text=True,timeout=240,check=True)
        still=set(remaining.stdout.split())
        if not still<=set(ids):raise ValueError('Post-cleanup cache selection escaped original identities')
        state.update(exit_code=result.returncode,removed_count=len(set(ids)-still),retained_ids=sorted(still))
    finally:
        state['finished_at']=now()
        state['after_disk']=disk();state['after_protected']=protected()
        state['protected_unchanged']=state['before_protected']==state['after_protected']
        state['filesystem_used_decrease_bytes']=state['before_disk']['root_used_bytes']-state['after_disk']['root_used_bytes']
        state['c_free_change_bytes']=state['after_disk']['windows']['C_FreeBytes']-state['before_disk']['windows']['C_FreeBytes']
        state['completed']=state.get('exit_code')==0 and state['protected_unchanged']
        save(a.output,state)
    print(json.dumps({k:state[k] for k in ('completed','candidate_count','removed_count','protected_unchanged',
        'filesystem_used_decrease_bytes','c_free_change_bytes')},indent=2))
    if not state['completed']:raise ValueError('Cleanup incomplete; inspect retained receipts')


if __name__=='__main__':
    try:main()
    except Exception as e:
        raise SystemExit('Migration cache cleanup failed: '+(str(e) if isinstance(e,ValueError) else type(e).__name__)) from None
