#!/usr/bin/env python3
"""Run one private administrative script in a uniquely owned client Pod."""
import argparse
import base64
import json
from pathlib import Path
import sys
import time
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'sunmoonai/registry-platform'))
from pull_secret import Target, SecretError, dns_name


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--namespace', required=True)
    p.add_argument('--image', required=True)
    p.add_argument('--pull-secret', required=True)
    a = p.parse_args()
    dns_name(a.namespace); dns_name(a.pull_secret)
    if not a.image.startswith('harbor.sunmoonai.com:30443/') or any(c.isspace() for c in a.image):
        raise SecretError('Client image must use the fixed Harbor')
    raw = sys.stdin.buffer.read(1048577)
    if len(raw) > 1048576:
        raise SecretError('Client payload too large')
    script, password, tail = raw.split(b'\0')
    if tail or not script:
        raise SecretError('Invalid client payload')
    target = Target(); target.check()
    name = 'dbctl-' + uuid.uuid4().hex
    labels = {'sunmoonai.com/dbctl-run': name}
    secret = {'apiVersion':'v1','kind':'Secret','metadata':{'name':name,'namespace':a.namespace,'labels':labels},
              'type':'Opaque','data':{'run.sh':base64.b64encode(script).decode(),
                                    'password':base64.b64encode(password).decode()}}
    pod = {'apiVersion':'v1','kind':'Pod','metadata':{'name':name,'namespace':a.namespace,'labels':labels},
           'spec':{'restartPolicy':'Never','activeDeadlineSeconds':300,'automountServiceAccountToken':False,
                   'imagePullSecrets':[{'name':a.pull_secret}],
                   'containers':[{'name':'client','image':a.image,'imagePullPolicy':'IfNotPresent',
                     'command':['bash','-se','/run/dbctl/run.sh'],
                     'env':[{'name':'PGPASSWORD','valueFrom':{'secretKeyRef':{'name':name,'key':'password'}}}],
                     'volumeMounts':[{'name':'private','mountPath':'/run/dbctl','readOnly':True}],
                     'securityContext':{'allowPrivilegeEscalation':False,'capabilities':{'drop':['ALL']},
                                        'seccompProfile':{'type':'RuntimeDefault'}}}],
                   'volumes':[{'name':'private','secret':{'secretName':name,'defaultMode':0o444}}]}}
    created = {}
    try:
        for kind, value in [('secret',secret), ('pod',pod)]:
            target.check()
            obj = json.loads(target.command('create','-f','-','-o','json', payload=json.dumps(value)))
            created[kind] = obj['metadata']['uid']
        deadline = time.monotonic() + 320
        while time.monotonic() < deadline:
            target.check()
            obj = json.loads(target.command('get','pod',name,'-n',a.namespace,'-o','json'))
            if obj['metadata']['uid'] != created['pod']:
                raise SecretError('Administrative Pod identity changed')
            phase = obj.get('status',{}).get('phase')
            if phase == 'Failed':
                raise SecretError('Administrative client failed; raw logs withheld')
            if phase == 'Succeeded':
                break
            time.sleep(2)
        else:
            raise SecretError('Administrative client deadline exceeded')
        # Deletion uses UID preconditions through the API; never adopt a replacement.
        for kind in ('pods','secrets'):
            key = kind[:-1]
            target.check()
            body = {'apiVersion':'v1','kind':'DeleteOptions','preconditions':{'uid':created[key]}}
            target.command('delete','--raw',f'/api/v1/namespaces/{a.namespace}/{kind}/{name}',
                           '-f','-',payload=json.dumps(body))
        print(f'Administrative client completed: {a.namespace}/{name}',file=sys.stderr)
    except Exception:
        print(f'Administrative run incomplete: {a.namespace}/{name}; preserve Pod/Secret for private recovery',file=sys.stderr)
        raise


if __name__ == '__main__':
    try:
        main()
    except SecretError as e:
        raise SystemExit(str(e)) from None
    except Exception:
        raise SystemExit('Client operation failed; diagnostic payload withheld') from None
