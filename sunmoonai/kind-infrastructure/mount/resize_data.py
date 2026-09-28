#!/usr/bin/env python3
"""Existing whole-disk ext4, 100 -> 230 GiB only. Never format or start services.

Windows owns VHDX expansion. Linux release journal is required before grow.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

STATE = Path('/var/lib/sunmoon/maintenance/data230-20260928-v1')
UUID = 'a28de356-4ba1-4a21-93f5-744b9b9d8be0'
MARKER = Path('/mnt/c/wsl-disks/sunmoon-data.maintenance')
TARGET = 230*1024**3


def run(args,timeout=30):
    p=subprocess.run(args,capture_output=True,text=True,timeout=timeout)
    if p.returncode:raise ValueError('Command failed: '+args[0])
    return p.stdout.strip()


def save(state):
    with tempfile.NamedTemporaryFile(mode='w',dir=STATE,delete=False) as out:
        json.dump(state,out,indent=2);out.write('\n');out.flush();os.fsync(out.fileno())
        temp=out.name
    os.replace(temp,STATE/'state.json')
    fd=os.open(STATE,os.O_RDONLY|os.O_DIRECTORY)
    try:os.fsync(fd)
    finally:os.close(fd)


def load():
    if os.geteuid()!=0 or os.readlink('/proc/self/ns/mnt')!=os.readlink('/proc/1/ns/mnt'):
        raise ValueError('Run as root in PID1 mount namespace')
    if not MARKER.exists():raise ValueError('Maintenance marker missing')
    s=json.loads((STATE/'state.json').read_text())
    if s['uuid']!=UUID or s['target_bytes']!=TARGET:raise ValueError('Resize authorization differs')
    p=Path(s['backup_manifest'])
    if p.resolve()!=p or p.stat().st_uid!=0 or p.stat().st_mode&0o077:
        raise ValueError('Backup manifest protection differs')
    if hashlib.sha256(p.read_bytes()).hexdigest()!=s['backup_manifest_sha256']:
        raise ValueError('Backup manifest changed')
    for unit in ('docker.service','docker.socket','containerd.service','sunmoon-space-monitor.timer','sunmoon-space-monitor.service'):
        if run(['systemctl','show',unit,'-p','ActiveState','--value'])!='inactive':
            raise ValueError('Service must remain stopped: '+unit)
    return s


def device():
    rows=run(['blkid','-t','UUID='+UUID,'-o','device']).splitlines()
    if len(rows)!=1:raise ValueError('Expected exactly one original UUID')
    d=rows[0]
    if run(['blkid','-s','TYPE','-o','value',d])!='ext4':raise ValueError('Expected existing ext4')
    info=json.loads(run(['lsblk','-J','-b','-o','PATH,TYPE,SIZE',d]))['blockdevices']
    if len(info)!=1 or info[0]['type']!='disk' or info[0].get('children'):
        raise ValueError('Expected original whole disk with no partitions')
    return d,int(run(['blockdev','--getsize64',d]))


def unmounted(d):
    st=os.stat(d); number=f'{os.major(st.st_rdev)}:{os.minor(st.st_rdev)}'
    seen=set()
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():continue
        try:
            namespace=os.readlink(proc/'ns/mnt')
            if namespace in seen:continue
            lines=(proc/'mountinfo').read_text().splitlines();seen.add(namespace)
        except FileNotFoundError:continue
        for row in lines:
            if row.split()[2]==number:raise ValueError('Data disk remains mounted in a process namespace')


def main(action):
    s=load();d,size=device();unmounted(d)
    if action=='ready':
        if s['phase']!='ready-for-windows-expansion' or size!=100*1024**3:
            raise ValueError('Not released for first 100 -> 230 expansion')
        print(json.dumps({'ready':True,'uuid':UUID,'target_bytes':TARGET}));return
    if s['phase'] not in ('ready-for-windows-expansion','growing-ext4','filesystem-grown') or size!=TARGET:
        raise ValueError('Wrong phase or VHDX size; refuse filesystem write')
    if action=='grow':
        s['phase']='growing-ext4';save(s)
        p=subprocess.run(['e2fsck','-f','-p',d],capture_output=True,timeout=900)
        (STATE/'e2fsck.log').write_bytes(p.stdout+p.stderr)
        if p.returncode not in (0,1):raise ValueError('Filesystem check needs manual review; retain private log')
        p=subprocess.run(['resize2fs',d],capture_output=True,timeout=900)
        (STATE/'resize2fs.log').write_bytes(p.stdout+p.stderr)
        if p.returncode:raise ValueError('Filesystem growth failed; retain private log')
        run(['sync'],timeout=180)
    fields={}
    for line in run(['dumpe2fs','-h',d]).splitlines():
        if ':' in line:
            k,v=line.split(':',1);fields[k.strip()]=v.strip()
    if fields.get('Filesystem UUID')!=UUID or int(fields['Block count'])*int(fields['Block size'])!=TARGET:
        raise ValueError('Filesystem size/UUID verification failed')
    s.update(phase='filesystem-grown',filesystem_bytes=TARGET);save(s)
    print(json.dumps({'filesystem_grown':True,'uuid':UUID,'bytes':TARGET,'services_started':False}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['ready','grow','verify'])
    p.add_argument('--apply',action='store_true');a=p.parse_args()
    if not a.apply:print(json.dumps({'dry_run':True,'action':a.action,'target_gib':230,'formats':False}))
    else:
        os.umask(0o077)
        try:main(a.action)
        except Exception as e:raise SystemExit('Resize stopped: '+str(e) if isinstance(e,ValueError)
                                              else 'Resize stopped: '+type(e).__name__) from None
