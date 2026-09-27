#!/usr/bin/env python3
"""Bounded read-path acceptance and cleanup for the approved isolated restore."""
import base64
import copy
import datetime as dt
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess as sp
import time
import tomllib
import urllib.error
import urllib.parse
import urllib.request

from harbor_restore import BATCH, BACKUP, RUN, KUBE, NS, HOST, ADDRESS, command, apply, stop
from harbor_cold_backup import write, catalog_identity
from harbor_inventory import Catalog

WORKER = 'sunmoon-kind-136-worker2'
REGISTRY = HOST + ':18443'
SOURCE = 'harbor.sunmoonai.com:30443'
DIGEST = 'sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc'
REF = REGISTRY + '/k8s-images/node@' + DIGEST
POD = 'restore-pull-proof'
CERTDIR = '/etc/containerd/certs.d/' + REGISTRY
CONFIG = '/etc/containerd/config.toml'
CANDIDATE = '/etc/containerd/harbor-restore-candidate.toml'


def node(args, data=None):
    return command(['docker', 'exec', '-i', WORKER] + args, data=data)


def put(path, data):
    node(['tee', path], data)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def runtime_ready():
    info = json.loads(node(['crictl', 'info']))
    conditions = {c['type']: c['status'] for c in info['status']['conditions']}
    if not conditions.get('RuntimeReady') or not conditions.get('NetworkReady'):
        raise RuntimeError('New worker2 runtime/CNI not ready')


def gateway_node_access():
    """Allow the same approved node identity after service SNAT via Calico VXLAN."""
    pods = json.loads(command(KUBE + ['-n', NS, 'get', 'pod', '-l', 'app=restore-gateway', '-o', 'json']))['items']
    if len(pods) != 1: raise RuntimeError('Expected one gateway Pod')
    gateway_ip = str(ipaddress.IPv4Address(pods[0]['status']['podIP']))
    route = json.loads(node(['ip', '-j', 'route', 'get', gateway_ip]))[0]
    source = str(ipaddress.IPv4Address(route['prefsrc']))
    interfaces = json.loads(node(['ip', '-j', '-4', 'address', 'show']))
    addresses = {a['local'] for i in interfaces if i['ifname'] in ['eth0', 'vxlan.calico']
                 for a in i.get('addr_info', [])}
    if source not in addresses or route['dev'] not in ['eth0', 'vxlan.calico']:
        raise RuntimeError('Gateway route does not use an expected node interface')
    name = 'restore-gateway-node-access'
    policy = json.loads(command(KUBE + ['-n', NS, 'get', 'networkpolicy', name, '-o', 'json']))
    rule = policy['spec']['ingress'][0]
    if (policy['spec']['podSelector'] != {'matchLabels': {'app': 'restore-gateway'}} or
        rule['ports'] != [{'port': 8443, 'protocol': 'TCP'}]):
        raise RuntimeError('Gateway policy scope changed')
    peer = {'ipBlock': {'cidr': source + '/32'}}
    if peer not in rule['from']:
        patch = [{'op': 'test', 'path': '/metadata/resourceVersion', 'value': policy['metadata']['resourceVersion']},
                 {'op': 'add', 'path': '/spec/ingress/0/from/-', 'value': peer}]
        write(RUN / 'gateway-policy-before-vxlan.json', policy)
        write(RUN / 'gateway-vxlan-patch.json', patch)
        command(KUBE + ['-n', NS, 'patch', 'networkpolicy', name, '--type=json',
                       '--patch-file', str(RUN / 'gateway-vxlan-patch.json')])
    write(RUN / 'gateway-route.json', {'node': WORKER, 'gateway_pod_ip': gateway_ip, 'route': route,
                                      'allowed_source': source + '/32', 'port': 8443})


def enable_trust():
    if (RUN / 'trust.json').exists():
        previous = json.loads((RUN / 'trust.json').read_text())
        if not previous['restored']: raise RuntimeError('Trust state exists; recover first')
        (RUN / 'trust.json').rename(RUN / ('trust-previous-' + str(time.time_ns()) + '.json'))
    node(['test', '!', '-e', CERTDIR])
    node(['test', '!', '-e', CANDIDATE])
    originals = {CONFIG: node(['cat', CONFIG]), '/etc/hosts': node(['cat', '/etc/hosts'])}
    effective = node(['containerd', 'config', 'dump'])
    before = tomllib.loads(effective.decode())
    key = 'io.containerd.cri.v1.images'
    if before['plugins'][key]['registry']['config_path'] != '':
        raise RuntimeError('Runtime configuration differs from approval')
    needle = b"[plugins.'io.containerd.cri.v1.images'.registry]\n      config_path = ''"
    if effective.count(needle) != 1: raise RuntimeError('Ambiguous runtime registry section')
    candidate = effective.replace(needle, needle[:-2] + b"'/etc/containerd/certs.d'")
    expected = copy.deepcopy(before)
    expected['plugins'][key]['registry']['config_path'] = '/etc/containerd/certs.d'
    if tomllib.loads(candidate.decode()) != expected: raise RuntimeError('Unexpected configuration delta')
    ca = (BATCH / 'preparation/private/harbor-client-ca.crt').read_bytes()
    hosts = ('server = "https://' + REGISTRY + '"\n[host."https://' + REGISTRY + '"]\n'
             '  capabilities = ["pull", "resolve"]\n  ca = "' + CERTDIR + '/ca.crt"\n').encode()
    installed = {CONFIG: candidate, '/etc/hosts': originals['/etc/hosts'] +
                 ('\n' + ADDRESS + ' ' + HOST + '\n').encode(),
                 CERTDIR + '/ca.crt': ca, CERTDIR + '/hosts.toml': hosts,
                 CANDIDATE: candidate}
    for i, (path, raw) in enumerate(originals.items()): (RUN / ('trust-original-' + str(i))).write_bytes(raw)
    state = {'node': WORKER, 'originals': {p: {'file': 'trust-original-' + str(i), 'sha256': digest(v)}
             for i, (p, v) in enumerate(originals.items())},
             'installed': {p: digest(v) for p, v in installed.items()}, 'changed': [],
             'created_dirs': [], 'restored': False}
    write(RUN / 'trust.json', state)
    put(CANDIDATE, candidate); state['changed'].append(CANDIDATE); write(RUN / 'trust.json', state)
    parsed = tomllib.loads(node(['containerd', '--config', CANDIDATE, 'config', 'dump']).decode())
    if parsed != expected: raise RuntimeError('Candidate effective configuration changed other fields')
    parent_exists = sp.run(['docker', 'exec', WORKER, 'test', '-d', '/etc/containerd/certs.d']).returncode == 0
    if not parent_exists:
        state['created_dirs'].append('/etc/containerd/certs.d'); write(RUN / 'trust.json', state)
        node(['mkdir', '/etc/containerd/certs.d'])
    state['created_dirs'].append(CERTDIR); write(RUN / 'trust.json', state)
    node(['mkdir', CERTDIR])
    for path in [CERTDIR + '/ca.crt', CERTDIR + '/hosts.toml', '/etc/hosts', CONFIG]:
        # Journal before mutation so an interrupted write is visible to recovery.
        state['changed'].append(path); write(RUN / 'trust.json', state)
        put(path, installed[path])
    node(['systemctl', 'restart', 'containerd'])
    runtime_ready()
    command(KUBE + ['wait', '--for=condition=Ready', 'node/' + WORKER, '--timeout=120s'], timeout=130)
    print('Temporary CRI trust configured on new worker2 only', flush=True)


def restore_trust():
    path = RUN / 'trust.json'
    if not path.exists(): return
    state = json.loads(path.read_text())
    if state['restored']: return
    for target in reversed(state['changed']):
        if target not in state['originals'] and sp.run(['docker', 'exec', WORKER, 'test', '-e', target]).returncode == 1:
            continue
        current = node(['cat', target])
        original = state['originals'].get(target)
        if original and digest(current) == original['sha256']: continue
        if digest(current) != state['installed'][target]:
            raise RuntimeError('Temporary file changed; preserve for manual recovery: ' + target)
        if original:
            raw = (RUN / original['file']).read_bytes()
            if digest(raw) != original['sha256']: raise RuntimeError('Original file checksum changed')
            put(target, raw)
        else:
            node(['rm', '--', target])
    for directory in reversed(state.get('created_dirs', [])):
        if sp.run(['docker', 'exec', WORKER, 'test', '-d', directory]).returncode == 0:
            node(['rmdir', directory])
    if CONFIG in state['changed']:
        node(['systemctl', 'restart', 'containerd'])
        runtime_ready()
    command(KUBE + ['wait', '--for=condition=Ready', 'node/' + WORKER, '--timeout=120s'], timeout=130)
    for target, original in state['originals'].items():
        if digest(node(['cat', target])) != original['sha256']: raise RuntimeError('Original restoration mismatch')
    state['restored'] = True; write(path, state)
    print('Original worker2 files restored; runtime change reverted when applicable', flush=True)


def collect(client, name):
    config, _ = client.get('/configurations')
    if config['read_only']['value'] is not True: raise RuntimeError('Restored Harbor is not read-only')
    catalog = client.collect(); write(RUN / name, catalog)
    baseline = json.loads((BACKUP / 'catalog-before.json').read_text())
    if catalog_identity(catalog) != catalog_identity(baseline): raise RuntimeError('Restored catalog mismatch')
    # Compare all collected artifact fields including accessories, independently of ordering.
    def artifacts(c):
        return {(r['name'], a['digest']): json.dumps(a, sort_keys=True)
                for p in c['projects'] for r in p['repositories'] for a in r['artifacts']}
    if artifacts(catalog) != artifacts(baseline): raise RuntimeError('Artifact metadata mismatch')
    return catalog['summary']


def registry_manifest(client):
    target = 'https://localhost:18443/v2/k8s-images/node/manifests/' + DIGEST
    accept = ('application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, '
              'application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json')
    try:
        with client.client.open(urllib.request.Request(target, headers={'Accept': accept}), timeout=20) as response:
            raise RuntimeError('Private registry unexpectedly accepted anonymous manifest request')
    except urllib.error.HTTPError as exc:
        if exc.code != 401: raise RuntimeError('Unexpected registry authentication status') from None
        challenge = dict(re.findall(r'(\w+)="([^"]+)"', exc.headers.get('WWW-Authenticate', '')))
    realm = urllib.parse.urlsplit(challenge['realm'])
    if (realm.scheme, realm.hostname, realm.port, realm.path) != ('https', HOST, 18443, '/service/token'):
        raise RuntimeError('Unexpected registry token destination')
    token_url = 'https://localhost:18443/service/token?' + urllib.parse.urlencode({
        'service': challenge['service'], 'scope': 'repository:k8s-images/node:pull'})
    request = urllib.request.Request(token_url, headers={'Authorization': 'Basic ' + client.auth})
    with client.client.open(request, timeout=20) as response: token = json.load(response)['token']
    request = urllib.request.Request(target, headers={'Accept': accept, 'Authorization': 'Bearer ' + token})
    with client.client.open(request, timeout=20) as response:
        content = response.read(); reported = response.headers.get('Docker-Content-Digest')
    if 'sha256:' + digest(content) != DIGEST or reported != DIGEST:
        raise RuntimeError('Registry manifest content digest mismatch')
    return {'digest': DIGEST, 'bytes': len(content), 'tls_verified': True, 'authenticated': True}


def proof_pod():
    images = json.loads(node(['crictl', 'images', '-o', 'json']))['images']
    if any(DIGEST in ref for i in images for ref in i.get('repoDigests', [])):
        raise RuntimeError('Selected digest was cached before pull')
    write(RUN / 'pull-cache-before.json', {'digest': DIGEST, 'present': False})
    auth = json.loads((Path.home() / '.docker/config.json').read_text())['auths'][SOURCE]['auth']
    cfg = base64.b64encode(json.dumps({'auths': {REGISTRY: {'auth': auth}}}).encode()).decode()
    secret = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': 'restore-pull-auth', 'namespace': NS},
              'type': 'kubernetes.io/dockerconfigjson', 'data': {'.dockerconfigjson': cfg}}
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': POD, 'namespace': NS}, 'spec': {
        'nodeSelector': {'kubernetes.io/hostname': WORKER}, 'restartPolicy': 'Never',
        'automountServiceAccountToken': False, 'activeDeadlineSeconds': 900,
        'imagePullSecrets': [{'name': 'restore-pull-auth'}],
        'securityContext': {'runAsNonRoot': True, 'runAsUser': 1000, 'seccompProfile': {'type': 'RuntimeDefault'}},
        'containers': [{'name': 'node', 'image': REF, 'imagePullPolicy': 'Always',
            'command': ['node', '-e', 'console.log(process.version); setInterval(()=>{},1000)'],
            'resources': {'requests': {'cpu': '10m', 'memory': '32Mi'}, 'limits': {'cpu': '200m', 'memory': '128Mi'}},
            'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True,
                                'capabilities': {'drop': ['ALL']}}}]}}
    apply([secret, pod])
    command(KUBE + ['-n', NS, 'wait', '--for=condition=Ready', 'pod/' + POD, '--timeout=240s'], timeout=250)
    actual = json.loads(command(KUBE + ['-n', NS, 'get', 'pod', POD, '-o', 'json']))
    events = json.loads(command(KUBE + ['-n', NS, 'get', 'events', '--field-selector',
                                      'involvedObject.uid=' + actual['metadata']['uid'], '-o', 'json']))
    write(RUN / 'pull-pod.json', actual); write(RUN / 'pull-events.json', events)
    if not any(e['reason'] == 'Pulled' and 'Successfully pulled' in e.get('message', '') for e in events['items']):
        raise RuntimeError('Missing successful runtime pull event')
    version = command(KUBE + ['-n', NS, 'logs', POD]).decode().strip()
    image = json.loads(node(['crictl', 'inspecti', REF]))
    write(RUN / 'pull-image.json', image)
    if not any(DIGEST in r for r in image['status']['repoDigests']): raise RuntimeError('Pulled digest mismatch')
    print('Actual cross-node TLS pull and Node startup passed:', version, flush=True)
    return {'reference': REF, 'node': WORKER, 'version': version,
            'image_id': actual['status']['containerStatuses'][0]['imageID'], 'cache_absent_before': True}


def network_proof():
    old_ip = command(['docker', 'inspect', '--format', '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}',
                      'kind-control-plane']).decode().strip()
    script = """const net=require('net'); const targets=JSON.parse(process.argv[1]);
    (async()=>{for(const t of targets){const result=await new Promise(resolve=>{
      const s=net.connect(t.port,t.host); let done=false; const end=v=>{if(!done){done=true;s.destroy();resolve(v)}};
      s.setTimeout(3000,()=>end('timeout'));s.on('connect',()=>end('connected'));s.on('error',()=>end('error'));
    });console.log(JSON.stringify({...t,result}));}})();"""
    targets = [{'host': 'sunmoonai-harbor-core', 'port': 80}, {'host': old_ip, 'port': 30443},
               {'host': '101.126.151.0', 'port': 30443}]
    # Positive external control: old Harbor is reachable at the exact old node IP from WSL.
    import socket
    with socket.create_connection((old_ip, 30443), timeout=5): pass
    rows = [json.loads(line) for line in command(KUBE + ['-n', NS, 'exec', POD, '--', 'node', '-e', script,
                                     json.dumps(targets)]).decode().splitlines()]
    if rows[0]['result'] != 'connected' or any(r['result'] != 'timeout' for r in rows[1:]):
        raise RuntimeError('Network isolation proof failed')
    write(RUN / 'network-proof.json', {'old_endpoint_positive_control': True, 'pod_results': rows,
                                      'cloud_target_availability_not_proven': True})
    return rows


def main():
    os.umask(0o077)
    state = json.loads((RUN / 'state.json').read_text())
    if state['stage'] != 'read-path-running': raise RuntimeError('Restore not ready for acceptance')
    actual = json.loads(command(KUBE + ['get', 'ns', NS, '-o', 'json']))
    if actual['metadata']['uid'] != state['namespace_uid']: raise RuntimeError('Namespace identity changed')
    result = {'started_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'passed': False,
              'jobservice_validated': False, 'full_harbor_health_claimed': False, 'cleanup_errors': []}
    forward = None
    if (RUN / 'acceptance.json').exists():
        (RUN / 'acceptance.json').rename(RUN / ('acceptance-previous-' + str(time.time_ns()) + '.json'))
    try:
        old = Catalog(SOURCE)
        health, _ = old.get('/health'); cfg, _ = old.get('/configurations')
        if health.get('status') != 'healthy' or cfg['read_only']['value'] is not False:
            raise RuntimeError('Old Harbor baseline changed')
        result['old_before'] = {'health': health['status'], 'read_only': False}
        log = (RUN / 'port-forward.log').open('wb')
        forward = sp.Popen(KUBE + ['-n', NS, 'port-forward', '--address', '127.0.0.1',
                                  'service/restore-gateway', '18443:18443'], stdout=log, stderr=sp.STDOUT)
        write(RUN / 'port-forward-process.json', {'pid': forward.pid, 'argv': forward.args,
              'started_at': dt.datetime.now(dt.timezone.utc).isoformat()})
        log.close()
        client = Catalog('localhost:18443', credential_host=SOURCE)
        for _ in range(15):
            if forward.poll() is not None: raise RuntimeError('Port-forward exited')
            try: client.get('/users/current'); break
            except (RuntimeError, json.JSONDecodeError): time.sleep(1)
        result['catalog'] = collect(client, 'catalog-restored.json')
        result['manifest_before_restart'] = registry_manifest(client)
        print('Full restored catalog matches cold backup', flush=True)
        gateway_node_access()
        enable_trust()
        result['pull'] = proof_pod()
        result['network'] = network_proof()
        command(KUBE + ['-n', NS, 'rollout', 'restart', 'deployment/sunmoonai-harbor-registry'])
        command(KUBE + ['-n', NS, 'rollout', 'status', 'deployment/sunmoonai-harbor-registry', '--timeout=180s'], timeout=190)
        result['catalog_after_registry_restart'] = collect(client, 'catalog-after-restart.json')
        result['manifest_after_restart'] = registry_manifest(client)
        result['passed'] = True
    except Exception as exc:
        result['error'] = str(exc)
        print('Acceptance stopped:', str(exc), flush=True)
    finally:
        for name, action in [
            ('delete-temporary-pod', lambda: command(KUBE + ['-n', NS, 'delete', 'pod', POD, '--ignore-not-found', '--wait=true', '--timeout=90s'])),
            ('stop-restored-workloads', stop), ('restore-node-trust', restore_trust)]:
            try: action()
            except Exception as exc: result['cleanup_errors'].append({'action': name, 'error': str(exc)})
        if forward is not None:
            forward.terminate()
            try: forward.wait(timeout=10)
            except sp.TimeoutExpired: forward.kill(); forward.wait()
        try:
            old = Catalog(SOURCE); health, _ = old.get('/health'); cfg, _ = old.get('/configurations')
            result['old_after'] = {'health': health.get('status'), 'read_only': cfg['read_only']['value']}
            if health.get('status') != 'healthy' or cfg['read_only']['value'] is not False:
                result['cleanup_errors'].append({'action': 'old-harbor-check', 'error': 'Baseline changed'})
        except Exception as exc: result['cleanup_errors'].append({'action': 'old-harbor-check', 'error': str(exc)})
        result['completed_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
        write(RUN / 'acceptance.json', result)
    print(json.dumps(result, ensure_ascii=False), flush=True)
    if not result['passed'] or result['cleanup_errors']: raise SystemExit(1)


if __name__ == '__main__':
    with (RUN / 'restore.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        main()
