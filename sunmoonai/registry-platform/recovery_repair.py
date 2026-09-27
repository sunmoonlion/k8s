#!/usr/bin/env python3
"""Repair this stopped recovery attempt only; default plan, no service startup.

Retains original containers/data/receipts. Adds missing read-only nested mountpoint
and a separate Redis 8.2.1 container, matching the source version. No deletion.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import yaml
from harbor_inputs import sha,write_new
from recovery_candidate import RUN,PROJECT,bind
from recovery_run import STATE,persist,cmd

REDIS='bitnami/redis@sha256:0d2c5324b7373522e1fce60d657d60c851aa2921b211fd795f20c8515bee429e'


def main():
    os.umask(0o077)
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--apply',action='store_true');a=p.parse_args()
    if not a.apply:
        print(json.dumps({'dry_run':True,'registry_mountpoint':'config/registry/root.crt','redis_version':'8.2.1','retain_old_redis':True,'start_services':False}));return
    if os.geteuid()!=0 or RUN.resolve()!=RUN:raise RuntimeError('Root and exact candidate path required')
    state=json.loads(STATE.read_text())
    if state.get('completed') or not state.get('database_reconciled') or state.get('stop_errors'):
        raise RuntimeError('Unexpected recovery phase')
    for identity in state['created'].values():
        if json.loads(cmd(['docker','inspect',identity]))[0]['State']['Running']:
            raise RuntimeError('All recovery containers must be stopped')
    record=RUN/'repair-original-redis.json'
    if record.exists():raise RuntimeError('Repair already exists; inspect instead of repeating')
    image=json.loads(cmd(['docker','image','inspect',REDIS]))[0]
    if REDIS not in image.get('RepoDigests',[]) or image['Config'].get('Volumes'):
        raise RuntimeError('Source Redis identity or volumes changed')
    name=PROJECT+'-redis-821'
    if name in cmd(['docker','ps','-a','--format','{{.Names}}']).splitlines():raise RuntimeError('Replacement name collision')
    before={p:sha(RUN/p) for p in ['compose.yaml','preparation.json','run-state.json']}
    for f in before: write_new(RUN/('before-repair-'+f),(RUN/f).read_bytes())
    write_new(record,(json.dumps({'complete':False,'before_sha256':before,'reason':'Nested mountpoint absent; preserve source Redis 8.2.1'})+'\n').encode())
    crt=RUN/'config/registry/root.crt';write_new(crt,(RUN/'signing/root.crt').read_bytes());os.chown(crt,10000,10000);os.chmod(crt,0o400)
    directory=RUN/'redis-821';directory.mkdir(mode=0o700);os.chown(directory,1001,1001)
    compose=yaml.safe_load((RUN/'compose.yaml').read_text())
    redis={'image':image['Id'],'container_name':name,'user':'1001:1001','entrypoint':['/opt/bitnami/redis/bin/redis-server'],
           'command':['--bind','0.0.0.0','--protected-mode','yes','--dir','/data','--save','','--appendonly','no'],
           'volumes':[bind(directory,'/data',False)],'tmpfs':['/tmp:rw,nosuid,nodev,noexec,size=32m,mode=1777'],
           'read_only':True,'cap_drop':['ALL'],'security_opt':['no-new-privileges:true'],'restart':'no','pull_policy':'never',
           'networks':['harbor'],'mem_limit':'512m','cpus':1,'pids_limit':128,
           'logging':{'driver':'local','options':{'max-size':'10m','max-file':'2'}}}
    compose['services']['redis']=redis
    (RUN/'compose.yaml').write_text(yaml.safe_dump(compose,sort_keys=False))
    state['intended'].append(name);persist(state)
    identity=cmd(['docker','create','--name',name,'--label','com.docker.compose.project='+PROJECT,
                  '--label','com.docker.compose.service=redis','--network',PROJECT,'--network-alias','redis',
                  '--restart=no','--pull=never','--user','1001:1001','--read-only','--cap-drop=ALL',
                  '--security-opt=no-new-privileges','--memory=512m','--cpus=1','--pids-limit=128',
                  '--tmpfs','/tmp:rw,nosuid,nodev,noexec,size=32m,mode=1777',
                  '--log-driver=local','--log-opt','max-size=10m','--log-opt','max-file=2',
                  '--mount','type=bind,src='+str(directory)+',dst=/data',
                  '--entrypoint','/opt/bitnami/redis/bin/redis-server',image['Id'],*redis['command']]).strip()
    state['retained_original_redis']=state['created']['redis'];state['created']['redis']=identity;persist(state)
    spec=json.loads(cmd(['docker','inspect',identity]))[0]
    if any(m['Type']=='volume' for m in spec['Mounts']) or spec['HostConfig'].get('PortBindings') or spec['State']['Running']:
        raise RuntimeError('Replacement Redis isolation mismatch')
    prep=json.loads((RUN/'preparation.json').read_text());prep['immutable_files']['config/registry/root.crt']=sha(crt);prep['immutable_files']['compose.yaml']=sha(RUN/'compose.yaml')
    prep['redis_version']='8.2.1';(RUN/'preparation.json').write_text(json.dumps(prep,indent=2)+'\n')
    result={'complete':True,'before_sha256':before,'redis_version':'8.2.1','redis_image':REDIS,'new_container':identity,
            'old_redis_retained':True,'nested_mountpoint_present':True,'services_started':False}
    record.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='before_sha256'},indent=2))


if __name__=='__main__':
    try:main()
    except Exception as exc:raise SystemExit('[recovery-repair] '+(str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__+'; details withheld')) from None
