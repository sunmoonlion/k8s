#!/usr/bin/env python3
"""Fetch locked public cluster artifacts; no private inputs or cloud deployment.

Works locally or on the approved download host with the same manifest/script.
Default validates/plans; --apply downloads only beneath an explicit artifact root.
Never installs, runs containers, changes services or cleans existing material.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time


def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest',type=Path,required=True);p.add_argument('--root',type=Path,required=True);p.add_argument('--apply',action='store_true');a=p.parse_args()
    data=json.loads(a.manifest.read_text());root=a.root.expanduser().resolve()
    files=data['files']
    if not a.apply:
        print(json.dumps({'dry_run':True,'batch':data['batch'],'files':len(files),'root':str(root),'install':False}));return
    root.mkdir(parents=True,exist_ok=True,mode=0o700)
    receipts=[]
    for item in files:
        relative=Path(item['path'])
        if relative.is_absolute() or '..' in relative.parts or not item['url'].startswith('https://') or len(item['sha256'])!=64:
            raise RuntimeError('Invalid locked artifact')
        dest=root/relative
        if dest.resolve()!=dest: raise RuntimeError('Symlink material path refused')
        dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():
            if digest(dest)!=item['sha256']:raise RuntimeError('Existing material checksum differs; preserve it')
            receipts.append({'path':item['path'],'sha256':item['sha256'],'bytes':dest.stat().st_size,'reused':True});continue
        partial=dest.with_name(dest.name+'.part')
        if partial.is_symlink():raise RuntimeError('Symlink partial refused')
        success=False
        for attempt in range(3):
            if shutil.disk_usage(root).free<6*1024**3:raise RuntimeError('Less than 6 GiB free; no cleanup attempted')
            result=subprocess.run(['curl','--fail','--location','--proto','=https','--proto-redir','=https',
                '--connect-timeout','15','--max-time','180','--continue-at','-','--output',str(partial),item['url']],
                stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=190)
            if result.returncode==0:
                if digest(partial)!=item['sha256']:raise RuntimeError('Downloaded checksum mismatch; partial retained')
                if item.get('bytes') is not None and partial.stat().st_size!=item['bytes']:raise RuntimeError('Downloaded size mismatch')
                partial.rename(dest);success=True;break
            print(json.dumps({'path':item['path'],'attempt':attempt+1,'curl_exit':result.returncode,'partial_retained':True}),flush=True)
            time.sleep(attempt+1)
        if not success:raise RuntimeError('Bounded download attempts exhausted')
        receipts.append({'path':item['path'],'sha256':item['sha256'],'bytes':dest.stat().st_size,'reused':False})
        print('Verified '+item['path'],flush=True)
    receipt=root/('receipt-'+str(time.time_ns())+'.json')
    receipt.write_text(json.dumps({'batch':data['batch'],'files':receipts,'installed':False},indent=2)+'\n')
    print(json.dumps({'completed':True,'files':len(receipts),'bytes':sum(i['bytes'] for i in receipts),'receipt':str(receipt)}))


if __name__=='__main__':main()
