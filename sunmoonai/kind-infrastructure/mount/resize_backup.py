#!/usr/bin/env python3
"""Fixed local data-disk expansion backup; default plan, no source deletion.

Reuse verified immutable system-disk backup members by byte offset/hash, store
all other file contents once. Manifest includes ownership, modes and xattrs.
Restore writes only a new system-disk directory; never overwrites live data.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import tarfile
import sys

import system_compaction as maintenance

SOURCE = Path('/mnt/sunmoon-data')
BACKUP = Path('/var/backups/sunmoon-data/preexpand-230-20260928-v1')
EXISTING = Path('/var/backups/sunmoon-harbor/host-managed-20260927-v1')
RESTORE = Path('/var/backups/sunmoon-data/preexpand-230-20260928-restored')
GIB = 1024**3


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def save(name, data):
    maintenance.source.save(BACKUP/name, data)


def frozen():
    s=maintenance.source.read_manifest(maintenance.STATE/'state.json')
    maintenance.guard(s)
    if any(c['state']=='running' for c in maintenance.protected()['containers']):
        raise ValueError('All retained containers must remain stopped')
    maintenance.check_storage()
    if not Path('/mnt/c/wsl-disks/sunmoon-data.maintenance').exists():
        raise ValueError('Maintenance marker required')


def budget(extra=0):
    # Native Windows allocation confirmed by owner at 2026-09-28T14:41:36Z.
    # Reject a changed data VHDX length; a fresh native probe is then required.
    p=Path('/mnt/c/wsl-disks/sunmoon-data.vhdx')
    if p.stat().st_size != 93050634240:
        raise ValueError('Data VHDX length changed; recheck native allocation')
    v=os.statvfs('/mnt/c'); free=v.f_bavail*v.f_frsize
    if free-(230*GIB-93050634240)-22*GIB-extra < 50*GIB:
        raise ValueError('Backup would violate full-data-growth C reserve')
    v=os.statvfs(BACKUP)
    if v.f_bavail*v.f_frsize-extra < 22*GIB:
        raise ValueError('System filesystem backup margin insufficient')


def reference_index():
    manifest=json.loads((EXISTING/'backup.json').read_text())
    if not manifest['complete'] or not manifest['restore_verified']:
        raise ValueError('Verified complete Harbor backup required')
    records={}; archives={}
    for name,record in manifest['files'].items():
        p=EXISTING/name
        if p.resolve()!=p or not p.is_relative_to(EXISTING) or sha(p)!=record['sha256']:
            raise ValueError('Retained backup file changed')
        records[(p.stat().st_size,record['sha256'])]={'path':str(p),'offset':0}
        archives[str(p)]=record['sha256']
        if name in ('runtime.tar','volumes/registry.tar'):
            with tarfile.open(p,'r:') as archive:
                for member in archive:
                    if not member.isfile(): continue
                    with archive.extractfile(member) as stream:
                        digest=hashlib.file_digest(stream,'sha256').hexdigest()
                    records[(member.size,digest)]={'path':str(p),'offset':member.offset_data}
    return records,archives


def tree():
    rows={}; dev=SOURCE.stat().st_dev
    for p in [SOURCE,*sorted(SOURCE.rglob('*'))]:
        s=p.lstat()
        if s.st_dev!=dev:raise ValueError('Nested filesystem in data disk')
        kind=('file' if stat.S_ISREG(s.st_mode) else 'dir' if stat.S_ISDIR(s.st_mode)
              else 'symlink' if stat.S_ISLNK(s.st_mode) else None)
        if kind is None:raise ValueError('Special file needs review before backup')
        r={'kind':kind,'mode':stat.S_IMODE(s.st_mode),'uid':s.st_uid,'gid':s.st_gid,
           'mtime_ns':s.st_mtime_ns,'inode':s.st_ino,
           'xattrs':{n:base64.b64encode(os.getxattr(p,n,follow_symlinks=False)).decode()
                     for n in os.listxattr(p,follow_symlinks=False)}}
        if kind=='file':
            r.update(bytes=s.st_size,sha256=sha(p))
            after=p.stat()
            if (s.st_size,s.st_mtime_ns,s.st_ino)!=(after.st_size,after.st_mtime_ns,after.st_ino):
                raise ValueError('File changed while frozen')
        elif kind=='symlink':r['target']=os.readlink(p)
        rows[str(p.relative_to(SOURCE))]=r
    return rows


def capture():
    frozen()
    if BACKUP.exists():raise ValueError('Backup exists; inspect/verify instead of overwrite')
    BACKUP.mkdir(parents=True,mode=0o700)
    if BACKUP.resolve()!=BACKUP or BACKUP.stat().st_dev!=Path('/').stat().st_dev:
        raise ValueError('Backup must be on the system filesystem')
    os.chmod(BACKUP.parent,0o700)
    (BACKUP/'blobs').mkdir(mode=0o700)
    budget()
    save('state.json',{'complete':False,'phase':'indexing','created_at':maintenance.now()})
    index,archives=reference_index()
    print('Retained independent backup verified; hashing data disk',flush=True)
    rows=tree(); files=sum(r['kind']=='file' for r in rows.values())
    print(json.dumps({'files':files,'phase':'copying unique contents'}),flush=True)
    copied=0; refs={}
    for name,r in rows.items():
        if r['kind']!='file':continue
        key=(r['bytes'],r['sha256'])
        if key not in index:
            dest=BACKUP/'blobs'/r['sha256'];budget(r['bytes']+GIB)
            with (SOURCE/name).open('rb') as src,dest.open('xb') as out:
                os.chmod(dest,0o600);shutil.copyfileobj(src,out,4*1024**2)
                out.flush();os.fsync(out.fileno())
            if sha(dest)!=r['sha256']:raise ValueError('Copied content differs')
            copied+=r['bytes'];index[key]={'path':str(dest),'offset':0}
        refs[r['sha256']]=index[key]
    if tree()!=rows:raise ValueError('Source changed across backup')
    frozen()
    save('manifest.json',{'schema':1,'source':str(SOURCE),'uuid':maintenance.source.load(maintenance.source.CONFIG)['storage_uuid'],
        'files':rows,'contents':refs,'retained_files':archives,'new_content_bytes':copied,
        'complete':True,'independent_full_restore_verified':False})
    verify()
    save('state.json',{'complete':True,'phase':'verified','completed_at':maintenance.now(),
                       'manifest_sha256':sha(BACKUP/'manifest.json'),'new_content_bytes':copied})
    print(json.dumps({'complete':True,'files':files,'new_content_bytes':copied,'backup':str(BACKUP)}))


def reference(record,size):
    p=Path(record['path'])
    if p.resolve()!=p or not (p.is_relative_to(EXISTING) or p.is_relative_to(BACKUP/'blobs')):
        raise ValueError('Unexpected backup reference')
    with p.open('rb') as stream:
        stream.seek(record['offset']);left=size
        while left:
            block=stream.read(min(left,4*1024**2))
            if not block:raise ValueError('Truncated content')
            left-=len(block);yield block


def verify():
    m=json.loads((BACKUP/'manifest.json').read_text()); seen=set()
    for path,digest in m['retained_files'].items():
        p=Path(path)
        if not p.is_relative_to(EXISTING) or p.resolve()!=p or sha(p)!=digest:
            raise ValueError('Independent backup reference changed')
    for r in m['files'].values():
        if r['kind']!='file' or r['sha256'] in seen:continue
        h=hashlib.sha256()
        for block in reference(m['contents'][r['sha256']],r['bytes']):h.update(block)
        if h.hexdigest()!=r['sha256']:raise ValueError('Content verification failed')
        seen.add(r['sha256'])
    print(json.dumps({'verified_unique_contents':len(seen)}),flush=True)
    return m


def restore():
    m=verify()
    if RESTORE.exists():raise ValueError('Restore target exists; never overwrite')
    needed=sum(r.get('bytes',0) for r in m['files'].values())
    budget(needed)
    RESTORE.mkdir(mode=0o700)
    # Files/dirs before symlinks: never follow a restored symlink while writing.
    rows=sorted(m['files'].items(),key=lambda item:(item[1]['kind']=='symlink',len(Path(item[0]).parts)))
    for name,r in rows:
        p=RESTORE/name
        if '..' in Path(name).parts or Path(name).is_absolute() or p.parent.resolve()!=p.parent:
            raise ValueError('Unsafe restore member')
        if r['kind']=='dir':p.mkdir(mode=0o700,exist_ok=name=='.')
        elif r['kind']=='symlink':p.symlink_to(r['target'])
        else:
            with p.open('xb') as out:
                for block in reference(m['contents'][r['sha256']],r['bytes']):out.write(block)
            if sha(p)!=r['sha256']:raise ValueError('Restored file differs')
    for name,r in reversed(rows):
        p=RESTORE/name;os.chown(p,r['uid'],r['gid'],follow_symlinks=False)
        if r['kind']!='symlink':os.chmod(p,r['mode'])
        for n,v in r['xattrs'].items():os.setxattr(p,n,base64.b64decode(v),follow_symlinks=False)
        os.utime(p,ns=(r['mtime_ns'],r['mtime_ns']),follow_symlinks=False)
    print(json.dumps({'restored_to':str(RESTORE),'live_data_modified':False}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['capture','verify','restore']);p.add_argument('--apply',action='store_true')
    a=p.parse_args()
    if not a.apply:print(json.dumps({'dry_run':True,'action':a.action,'backup':str(BACKUP),'source_deleted':False}))
    elif os.geteuid()!=0:raise SystemExit('Root required')
    else:
        os.umask(0o077)
        try:globals()[a.action]()
        except Exception as e:raise SystemExit('Backup stopped: '+type(e).__name__+'; retain private state') from None
