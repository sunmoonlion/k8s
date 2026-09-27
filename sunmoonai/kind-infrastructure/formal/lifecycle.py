#!/usr/bin/env python3
"""Explicit lifecycle of the recorded formal KIND only; default prints a plan.

Every start requires the UUID and Docker mount view. Missing source directories
are never created. Stop retains nodes/volumes and works with low disk capacity.
No automatic boot service is installed here. Runtime is pending formal creation.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import stat
import time

import cluster as c


def inspect_nodes(cluster):
    expected = cluster.state['nodes']
    names = [c.p.NAME+'-'+s for s in c.SUFFIXES]
    if set(expected) != set(names) or len(set(expected.values())) != 3:
        raise ValueError('Three fully recorded node identities required')
    ids = c.docker('ps','-aq','--no-trunc','--filter','label=io.x-k8s.kind.cluster='+c.p.NAME).decode().split()
    if set(ids) != set(expected.values()):
        raise ValueError('Formal node set changed; no automatic adoption')
    result = []
    for name, desired in zip(names,c.p.document(cluster.lock)['nodes']):
        obj=json.loads(c.docker('inspect',expected[name]))[0]
        if (obj['Id']!=expected[name] or obj['Name']!='/'+name
                or obj['Image']!=cluster.state['node_image_id']
                or (obj['Config'].get('Labels') or {}).get('io.x-k8s.kind.cluster')!=c.p.NAME
                or obj['HostConfig']['RestartPolicy']['Name']!='no'
                or obj['State']['Status'] not in ('created','exited','running')):
            raise ValueError('Formal node identity/image/restart/state differs')
        wanted={m['containerPath']:m['hostPath'] for m in desired['extraMounts']}
        for target,source in wanted.items():
            mounts=[m for m in obj['Mounts'] if m['Destination']==target]
            if (len(mounts)!=1 or mounts[0]['Type']!='bind' or mounts[0]['Source']!=source or not mounts[0]['RW']):
                raise ValueError('Formal persistent bind contract differs')
        ports={str(m['containerPort'])+'/tcp':[{'HostIp':m['listenAddress'],'HostPort':str(m['hostPort'])}]
               for m in desired.get('extraPortMappings',[])}
        if name.endswith('-control-plane'):
            ports['6443/tcp']=[{'HostIp':'127.0.0.1','HostPort':str(c.p.API_PORT)}]
        if (obj['HostConfig'].get('PortBindings') or {})!=ports:
            raise ValueError('Formal node port bindings differ')
        result.append(obj)
    return result


def act(action):
    cluster=c.Cluster()
    nodes=inspect_nodes(cluster)
    if action=='check':
        return {'cluster':c.p.NAME,'nodes':{n['Name']:n['State']['Status'] for n in nodes},'runtime_verified':False}
    if action=='stop':
        failures=[]
        for obj in reversed(nodes):
            try:
                if obj['State']['Running']:
                    c.docker('stop','--time','90',obj['Id'],timeout=105)
            except Exception:
                failures.append(obj['Name'])
        after=inspect_nodes(cluster)
        if failures or any(n['State']['Running'] for n in after):
            raise ValueError('Some formal nodes did not stop; all retained')
        return {'stopped':list(cluster.state['nodes']),'deleted':False}
    c.storage(c.load_harbor(c.HARBOR_CONFIG),minimum_gib=20)
    for desired in c.p.document(cluster.lock)['nodes']:
        for mount in desired['extraMounts']:
            path=Path(mount['hostPath'])
            if (path.resolve()!=path or not path.is_dir() or path.stat().st_dev!=c.p.STORAGE.stat().st_dev
                    or path.stat().st_uid!=0 or path.stat().st_mode & 0o022):
                raise ValueError('Persistent source absent/changed; never recreate a missing mount directory')
    if cluster.state.get('phase')!='cni-ready' or not cluster.state.get('uid'):
        raise ValueError('Recorded CNI-ready cluster required; partial creation needs separate recovery')
    # Starting a retained node can reacquire its public ports. Refuse collisions
    # before starting any node, including a restarted old control-plane.
    for obj in nodes:
        if not obj['State']['Running']:
            for bindings in (obj['HostConfig'].get('PortBindings') or {}).values():
                for binding in bindings:
                    with socket.socket() as sock:
                        sock.bind((binding['HostIp'],int(binding['HostPort'])))
    started=[]
    try:
        for obj in nodes:
            if not obj['State']['Running']:
                c.docker('start',obj['Id']); started.append(obj['Id'])
        deadline=time.monotonic()+180
        while True:
            try:
                # kub validates pinned client, kubeconfig and recorded UID.
                version=json.loads(cluster.kub('version','-o','json'))
                if any(version[k]['gitVersion']!='v1.36.4' for k in ('clientVersion','serverVersion')):
                    raise ValueError('Formal client/server version differs')
                break
            except Exception:
                if time.monotonic()>=deadline:
                    raise ValueError('Formal API identity/readiness deadline') from None
                time.sleep(3)
        cluster.kub('wait','--for=condition=Ready','nodes','--all','--timeout=300s')
        cluster.nodes()
    except Exception:
        # Only undo starts made here; do not stop pre-existing running nodes.
        failures=[]
        for identity in reversed(started):
            try:
                c.docker('stop','--time','90',identity,timeout=105)
            except Exception:
                failures.append(identity)
        if failures:
            raise ValueError('Formal start failed and some newly started nodes could not be stopped; retain for recovery') from None
        raise
    return {'started_ids':started,'uid':cluster.state['uid'],'ready':True,'deleted':False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('check','start','stop'))
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    if not args.apply:
        print(json.dumps({'dry_run':True,'cluster':c.p.NAME,'action':args.action,
                          'missing_storage':'refuse without mkdir','old_nodes_touched':False,
                          'delete':False,'autostart_installed':False})); return
    if os.geteuid()!=0:
        raise ValueError('Root required for node lifecycle')
    # The creation lock must already exist; lifecycle never creates paths on an
    # unmounted filesystem. Stop remains available even if capacity is low.
    descriptor=os.open('/data/kind-clusters/.formal-create.lock',os.O_RDWR|os.O_NOFOLLOW)
    with os.fdopen(descriptor,'rb+') as handle:
        info=os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or stat.S_IMODE(info.st_mode)!=0o600:
            raise ValueError('Unsafe formal lifecycle lock')
        fcntl.flock(descriptor,fcntl.LOCK_EX|fcntl.LOCK_NB)
        print(json.dumps(act(args.action),indent=2))


if __name__=='__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Formal lifecycle stopped: '+(str(error) if isinstance(error,ValueError)
                         else type(error).__name__+'; raw diagnostics withheld')) from None
