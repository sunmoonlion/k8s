#!/usr/bin/env python3
"""Bounded, local, read-only Harbor recovery rehearsal. Plan by default.

run --apply needs owner approval of docs/host-recovery-plan.md. Stops and retains
all newly created containers on success/failure; no down/rm/prune/volume deletion.
Does not switch 30443, alter clusters, or operate cloud hosts (未经实机验证).
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

from harbor_inputs import sha, write_new
from recovery_candidate import RUN, PROJECT, PG, PG_RUN, SERVICES, BACKUP
from rehearsal_retirement import assert_active

MATERIALS=Path(__file__).resolve().parents[1]/'cicd-platform/materials'
sys.path.insert(0,str(MATERIALS))
from harbor_inventory import Catalog, NoRedirect
from harbor_cold_backup import catalog_identity
import ssl
import urllib.request as http

spec=importlib.util.spec_from_file_location('pg_rehearsal',Path(__file__).with_name('database-rehearsal.py'))
pg=importlib.util.module_from_spec(spec); spec.loader.exec_module(pg)
STATE=RUN/'run-state.json'
COMPOSE=['docker','compose','--project-name',PROJECT,'-f',str(RUN/'compose.yaml')]
END=None


def cmd(argv,stdin=None,timeout=120):
    if argv[:2] not in (['docker', 'inspect'], ['docker', 'ps'], ['docker', 'stop']):
        assert_active(RUN)
    if END is not None:
        timeout=min(timeout,END-time.monotonic())
        if timeout<=0: raise RuntimeError('Recovery deadline exceeded')
    result=subprocess.run(argv,input=stdin,capture_output=True,timeout=timeout)
    if result.returncode: raise RuntimeError('Recovery command failed: '+argv[0]+'; private details withheld')
    return result.stdout.decode()


def persist(state):
    pg.save(STATE,state)


def client():
    # Use existing owner's Docker credential; never copy it into Git or a command line.
    addresses={row[4][0] for row in socket.getaddrinfo('harbor.sunmoonai.com',18443,type=socket.SOCK_STREAM)}
    if not addresses or not addresses<={'127.0.0.1','::1'}:
        raise RuntimeError('Candidate hostname is not loopback')
    credentials=json.loads(Path('/home/zymun/.docker/config.json').read_text())
    auth=credentials.get('auths',{}).get('harbor.sunmoonai.com:30443',{}).get('auth')
    if not auth: raise RuntimeError('Missing existing Harbor credential')
    c=Catalog.__new__(Catalog); c.auth=auth; c.base='https://harbor.sunmoonai.com:18443/api/v2.0'
    c.client=http.build_opener(http.ProxyHandler({}),NoRedirect(),http.HTTPSHandler(context=ssl.create_default_context()))
    c.calls=0; c.deadline=min(time.monotonic()+900,END or float('inf'))
    return c


def stop(state):
    errors=[]
    # Resolve all journalled intents, including a replacement retained by version repair.
    order=['proxy','portal','core','registryctl','registry','redis','postgresql','init']
    owned=[]
    for name in state.get('intended',[]):
        try:
            p=subprocess.run(['docker','inspect',name],capture_output=True,timeout=10)
            if p.returncode:
                if name in cmd(['docker','ps','-a','--format','{{.Names}}']).splitlines():
                    raise RuntimeError('Container exists but cannot inspect')
                continue
            item=json.loads(p.stdout)[0]; label=item['Config'].get('Labels') or {}
            if label.get('sunmoonai.registry.recovery')==PROJECT:
                role='init'
            else:
                role=label.get('com.docker.compose.service')
                if label.get('com.docker.compose.project')!=PROJECT or role not in order:
                    raise RuntimeError('Container ownership changed')
            owned.append((order.index(role),name,item['Id']))
        except Exception: errors.append(name)
    for _,name,identity in sorted(owned):
        try:
            subprocess.run(['docker','stop','--time','20',identity],capture_output=True,timeout=30,check=True)
            check=json.loads(subprocess.check_output(['docker','inspect',identity],timeout=10))[0]
            if check['State']['Running']: raise RuntimeError('Container still running')
        except Exception: errors.append(name)
    state['stop_errors']=errors; persist(state)
    if errors: raise RuntimeError('Could not stop owned recovery roles: '+','.join(errors))


def run():
    global END
    assert_active(RUN)
    if os.geteuid()!=0 or RUN.resolve()!=RUN: raise RuntimeError('Root and exact candidate path required')
    if STATE.exists(): raise RuntimeError('Run already exists; use stop, never recreate containers')
    prep=json.loads((RUN/'preparation.json').read_text())
    if prep.get('prepared') is not True: raise RuntimeError('Preparation incomplete')
    for name,digest in prep['immutable_files'].items():
        if sha(RUN/name)!=digest: raise RuntimeError('Prepared configuration changed')
    pg.storage_guard(); pg.inspect_image()
    # Database exports are immutable and checked again immediately before use.
    for name,digest in [('registry.dump','8690de0139c8e97d6f885b46023ea834c26b246b6f3d27077d7932d2ec8535a4'),
                        ('globals.sql','db88e2684931daccddc3f5a252b14cdb1d6d5c5ca8ba33eec1608a9bff8d34e1')]:
        if sha(PG_RUN/name)!=digest: raise RuntimeError('Logical export changed')
    if any((RUN/'database').iterdir()): raise RuntimeError('Target database must be empty')
    names=[PROJECT+'-'+n for n in [*SERVICES,'postgresql','init']]
    if set(names)&set(cmd(['docker','ps','-a','--format','{{.Names}}']).splitlines()):
        raise RuntimeError('Recovery container name collision')
    if PROJECT in cmd(['docker','network','ls','--format','{{.Name}}']).splitlines():
        raise RuntimeError('Recovery network already exists')
    with socket.socket() as sock: sock.bind(('127.0.0.1',18443))
    END=time.monotonic()+2400
    state={'completed':False,'intended':names,'created':{},'phase':'initializing'}
    write_new(STATE,(json.dumps(state,indent=2)+'\n').encode())
    try:
        # Compose renders only data already verified above, and is never printed.
        cfg=json.loads(cmd(COMPOSE+['config','--format','json']))
        db=cfg['services']['postgresql']
        argv=['docker','create','--name',PROJECT+'-init','--label','sunmoonai.registry.recovery='+PROJECT,
              '--network=none','--restart=no','--pull=never','--read-only','--user','1001:1001',
              '--cap-drop=ALL','--security-opt=no-new-privileges','--log-driver=none',
              '--memory=1g','--cpus=2','--pids-limit=128','--tmpfs','/tmp:rw,nosuid,nodev,noexec,size=128m,mode=1777']
        for key,value in db['environment'].items(): argv+=['--env',key+'='+value]
        for m in db['volumes']:
            argv+=['--mount','type=bind,src='+m['source']+',dst='+m['target']+(',readonly' if m.get('read_only') else '')]
        argv+=['--entrypoint',PG+'initdb',db['image'],'-D','/bitnami/postgresql/data','-U','postgres',
               '--auth-local=trust','--auth-host=reject','--locale=C','--encoding=UTF8']
        init=cmd(argv).strip(); state['created']['init']=init; persist(state)
        cmd(['docker','start',init])
        if cmd(['docker','wait',init],timeout=90).strip()!='0': raise RuntimeError('Database initialization failed')
        cmd(COMPOSE+['create','--pull','never','--no-build'],timeout=120)
        network=json.loads(cmd(['docker','network','inspect',PROJECT]))[0]
        if not network.get('Internal'): raise RuntimeError('Recovery network is not internal')
        for role in [*SERVICES,'postgresql']:
            item=json.loads(cmd(['docker','inspect',PROJECT+'-'+role]))[0]
            state['created'][role]=item['Id']; persist(state)
            if any(m['Type']=='volume' for m in item['Mounts']) or item['HostConfig']['Privileged'] or item['HostConfig']['RestartPolicy']['Name']!='no':
                raise RuntimeError('Unexpected runtime volume/privilege/restart policy')
            if set(item['NetworkSettings']['Networks'])!={PROJECT}:
                raise RuntimeError('Unexpected attached network')
            if item['Config']['Image']!=cfg['services'][role]['image']:
                raise RuntimeError('Created image identity changed')
            ports=item['HostConfig'].get('PortBindings') or {}
            expected={'8443/tcp':[{'HostIp':'127.0.0.1','HostPort':'18443'}]} if role=='proxy' else {}
            if ports!=expected: raise RuntimeError('Unexpected port binding')
        database=state['created']['postgresql']; cmd(['docker','start',database])
        rehearsal=pg.Rehearsal(RUN,BACKUP); rehearsal.ready(database)
        rehearsal.psql(database,(PG_RUN/'globals.sql').read_text().replace('CREATE ROLE postgres;\n',''),'postgres')
        # Restore into a freshly initialized PostgreSQL 17.6 target.
        with (PG_RUN/'registry.dump').open('rb') as stream:
            p=subprocess.run(['docker','exec','-i',database,PG+'pg_restore','-h','/tmp','-U','postgres','--exit-on-error',
                              '--create','--dbname=postgres'],stdin=stream,capture_output=True,timeout=180)
            if p.returncode: raise RuntimeError('Logical restore failed; details withheld')
        expected=json.loads((PG_RUN/'inventory.json').read_text())
        if rehearsal.inventory(database)!=expected: raise RuntimeError('Restored database reconciliation failed')
        state['database_reconciled']=True; state['phase']='starting-read-only-harbor'; persist(state)
        verify_application(state)
    finally:
        END=None
        stop(state)
    print(json.dumps({'completed':state['completed'],'database_reconciled':True,'catalog':state['catalog'],
                      'registry_http':state['registry_http'],'new_containers_stopped':not state['stop_errors'],
                      'entry_switched':False},indent=2))


def verify_application(state):
    for role in ['redis','registry','registryctl','core','portal','proxy']:
        cmd(['docker','start',state['created'][role]])
    c=client(); ready=time.monotonic()+180
    while True:
        try:
            config,_=c.get('/configurations')
            if config['read_only']['value'] is not True: raise RuntimeError('Harbor must remain read-only')
            break
        except Exception:
            if time.monotonic()>ready: raise RuntimeError('Read-only Harbor readiness failed') from None
            time.sleep(3)
    catalog=c.collect(); write_new(RUN/('catalog-restored-'+str(time.time_ns())+'.json'),(json.dumps(catalog,indent=2)+'\n').encode())
    baseline=json.loads((BACKUP/'catalog-before.json').read_text())
    def artifacts(v):
        return {(r['name'],a['digest']):json.dumps(a,sort_keys=True) for p in v['projects'] for r in p['repositories'] for a in r['artifacts']}
    if catalog_identity(catalog)!=catalog_identity(baseline) or artifacts(catalog)!=artifacts(baseline):
        raise RuntimeError('Full restored catalog differs from frozen backup')
    state['catalog']=catalog['summary']; state['phase']='catalog-verified'; persist(state)
    # Registry HTTP verification is a separate mandatory acceptance step.
    from recovery_verify import verify_registry
    state['registry_http']=verify_registry(c,catalog,END)
    state['completed']=True; state['phase']='verified'; persist(state)


def resume():
    assert_active(RUN)
    global END
    if os.geteuid()!=0: raise RuntimeError('Root required')
    state=json.loads(STATE.read_text())
    if state.get('completed') or not state.get('database_reconciled') or state.get('stop_errors'):
        raise RuntimeError('Resume requires a reconciled, stopped, incomplete candidate')
    repair=json.loads((RUN/'repair-original-redis.json').read_text())
    if not repair.get('complete'): raise RuntimeError('Approved version/mount repair incomplete')
    prep=json.loads((RUN/'preparation.json').read_text())
    for name,digest in prep['immutable_files'].items():
        if sha(RUN/name)!=digest: raise RuntimeError('Prepared configuration changed')
    pg.storage_guard()
    END=time.monotonic()+2400
    try:
        cmd(['docker','start',state['created']['postgresql']])
        pg.Rehearsal(RUN,BACKUP).ready(state['created']['postgresql'])
        verify_application(state)
    finally:
        END=None;stop(state)
    print(json.dumps({'completed':state['completed'],'catalog':state['catalog'],'registry_http':state['registry_http'],
                      'new_containers_stopped':not state['stop_errors'],'entry_switched':False},indent=2))


def main():
    os.umask(0o077)
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('action',choices=['run','resume','stop']); parser.add_argument('--apply',action='store_true'); args=parser.parse_args()
    if not args.apply:
        print(json.dumps({'dry_run':True,'action':args.action,'project':PROJECT,'port':'127.0.0.1:18443','deadline_minutes':40,
                          'new_containers':8,'delete':False,'stop_after_acceptance':True,'switch_30443':False},indent=2)); return
    if args.action=='run': run()
    elif args.action=='resume': resume()
    else:
        if os.geteuid()!=0: raise RuntimeError('Root required')
        stop(json.loads(STATE.read_text())); print('Owned recovery containers stopped and retained')


if __name__=='__main__':
    try: main()
    except Exception as exc:
        raise SystemExit('[recovery-run] FAIL: '+(str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__+'; private details withheld')) from None
