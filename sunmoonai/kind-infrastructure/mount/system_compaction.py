#!/usr/bin/env python3
"""One local maintenance: journal, stop six existing KIND nodes, trim; never compact.

Windows shutdown/compaction belongs to the owner's Windows assistant. Default
prints a plan. No container/volume/image removal, scaling, or entry migration.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'sunmoonai/registry-platform'))
sys.path.insert(0, str(ROOT / 'sunmoonai/cicd-platform/materials'))
import source_snapshot as source
from space_reclaim_20260927 import get, disk, protected

STATE = Path('/var/lib/sunmoon/maintenance/precompact-20260928-v1')
SNAPSHOT = Path('/data/harbor/source-snapshots/precompact-20260928-v1')
CREDENTIALS = Path('/home/zymun/.docker/config.json')
NAMES = {c + '-' + n for c in ('kind', 'sunmoon-kind-136')
         for n in ('control-plane', 'worker', 'worker2')}
CHECK = '/opt/sunmoon/admin/storage/storage-20260928-v3/check-storage-mounts.sh'
CHECK_SHA = 'be63dddb1ce85d7de949d35b2a439c25aae8b27d6c3f7e5cc8ef748105515407'


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def run(args, timeout=180):
    p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if p.returncode:
        raise ValueError('Command failed; diagnostics withheld: ' + args[0])
    return p.stdout


def docker(*args, timeout=180):
    return run(['docker', '--host', 'unix:///var/run/docker.sock', *args], timeout)


def check_storage():
    if hashlib.sha256(Path(CHECK).read_bytes()).hexdigest() != CHECK_SHA:
        raise ValueError('Published storage checker changed')
    return json.loads(run(['nsenter', '--target', '1', '--mount', '--', 'bash', CHECK,
        '--layout', 'sunmoon-data', '--expected-uuid', source.load(source.CONFIG)['storage_uuid'],
        '--require-service-visibility']))


def save(state):
    source.save(STATE / 'state.json', state)


def view(ident):
    obj = get('/containers/' + ident + '/json')
    return {'id': obj['Id'], 'name': obj['Name'].lstrip('/'), 'image': obj['Image'],
        'status': obj['State']['Status'], 'exit_code': obj['State']['ExitCode'],
        'restart': obj['HostConfig']['RestartPolicy'], 'stop_signal': obj['Config'].get('StopSignal'),
        'labels': {k: v for k, v in (obj['Config'].get('Labels') or {}).items() if k.startswith('io.x-k8s.kind')},
        'ports': obj['HostConfig'].get('PortBindings') or {},
        'mounts': sorted([{k: m.get(k) for k in ('Type', 'Name', 'Source', 'Destination', 'RW')}
                          for m in obj['Mounts']], key=lambda m: m['Destination'])}


def guard(state):
    actual = protected()
    wanted = state['protected_before']
    if actual['volumes'] != wanted['volumes'] or actual['images'] != wanted['images']:
        raise ValueError('Protected image/volume inventory changed')
    def identities(rows):
        return [{k: v for k, v in row.items() if k != 'state'} for row in rows]
    if identities(actual['containers']) != identities(wanted['containers']):
        raise ValueError('Protected container inventory changed')
    selected = {n['id'] for n in state['nodes']}
    for row, original in zip(actual['containers'], wanted['containers']):
        if row['id'] not in selected and row != original:
            raise ValueError('A previously stopped candidate changed state')
    for node in state['nodes']:
        current = view(node['id'])
        if any(current[k] != node[k] for k in ('id', 'name', 'image', 'labels', 'ports', 'mounts', 'stop_signal')):
            raise ValueError('Recorded node identity/mounts changed: ' + node['name'])


def cri(node):
    rows = json.loads(docker('exec', node['id'], 'crictl', 'ps', '-o', 'json'))['containers']
    return [{'node': node['id'], 'id': c['id'], 'name': c['metadata']['name'],
             'pod': c.get('labels', {}).get('io.kubernetes.pod.name', ''),
             'namespace': c.get('labels', {}).get('io.kubernetes.pod.namespace', '')}
            for c in rows if c['state'] == 'CONTAINER_RUNNING']


def rank(c):
    name = c['name'] + '/' + c['pod']
    if 'kube-controller-manager' in name or 'kube-scheduler' in name:
        return 0
    if 'harbor-jobservice' in name or 'harbor-trivy' in name:
        return 5
    if c['namespace'] == 'kube-system':
        return 99 if 'etcd' in name else 95 if 'kube-apiserver' in name else 90
    if c['namespace'] == 'local-path-storage':
        return 90
    if any(x in name for x in ('postgresql', 'mysql', 'redis', 'rabbitmq', 'mongodb', 'elasticsearch', 'neo4j', 'object-storage-pool')):
        return 80
    return 20


def disposable_probe(c, info):
    if (c['namespace'] != 'sunmoon-infra-check' or c['name'] != 'probe'
            or view(c['node'])['labels'].get('io.x-k8s.kind.cluster') != 'sunmoon-kind-136'):
        return False
    # Existing validation PVC reader runs only sleep; stopping it retains the PVC
    # and node volume. It is not a database or the protected old worker2 sandbox.
    if c['pod'] == 'pvc-reader':
        detail = json.loads(docker('exec', c['node'], 'crictl', 'inspect', c['id']))
        return detail.get('info', {}).get('runtimeSpec', {}).get('process', {}).get('args') == ['sleep', '3600']
    return all(re.fullmatch(r'/var/lib/kubelet/pods/[0-9a-f-]+/(?:volumes/kubernetes.io~(?:empty-dir|projected)/[^/]+|etc-hosts|containers/probe/[^/]+)',
                           m.get('hostPath', '')) for m in info.get('mounts', []))


def reviewed_timeout(c, info):
    if disposable_probe(c, info):
        return True
    # Observed old RAGFlow entrypoint did not exit during its full 120s grace.
    # Its external database is stopped later; only readonly config/token mounts
    # and kubelet hosts/termination files are present. Retain all node storage.
    reviewed_component = (c['name'] == 'ragflow' and c['namespace'] == 'app-platform-dev'
                          and c['pod'].startswith('ragflow-sunmoonai-')) or (
                          c['name'] == 'local-path-provisioner' and c['namespace'] == 'local-path-storage')
    return (reviewed_component
            and view(c['node'])['labels'].get('io.x-k8s.kind.cluster') in ('kind', 'sunmoon-kind-136')
            and bool(info.get('mounts'))
            and all(m.get('readonly') or m.get('containerPath') in ('/etc/hosts', '/dev/termination-log')
                    for m in info['mounts']))


def node_shutdown(state, node):
    obj = get('/containers/' + node['id'] + '/json')
    intent = next(e for e in state['events'] if e.get('intent') == 'stop-node' and e['node'] == node['id'])
    p = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', 'logs', '--since', intent['at'], node['id']],
                       capture_output=True, timeout=30, check=True)
    log = p.stdout + p.stderr
    plain = re.sub(rb'\x1b\[[0-9;]*[A-Za-z]', b'', log)
    targets = any(b'Reached target' in line and b'Unmount All Filesystems' in line for line in plain.splitlines()) and any(
        b'Reached target' in line and b'Shutdown' in line for line in plain.splitlines())
    detached = (b'All filesystems' in plain and (b'detached' in plain or b'unmounted' in plain)) or targets
    detail = obj['State']
    # Observed systemd container halt returns 130 with the full detach marker.
    # Never accept 130 merely because it is commonly associated with SIGINT.
    if (detail['Status'] != 'exited' or detail.get('Error') or detail['ExitCode'] not in (0, 130)
            or (detail['ExitCode'] == 130 and not detached)):
        raise ValueError('Node shutdown lacks required completion evidence: ' + node['name'])
    state.setdefault('node_shutdown', {})[node['name']] = {
        'exit_code': detail['ExitCode'], 'finished_at': detail['FinishedAt'],
        'filesystem_detach_marker': detached, 'log_sha256': hashlib.sha256(log).hexdigest(),
        'docker_stop_timeout': -1}
    save(state)


def prepare():
    if STATE.exists():
        raise ValueError('Existing maintenance journal; inspect/recover instead of repeating')
    check_storage()
    snap = source.read_manifest(SNAPSHOT / 'state.json')
    if not snap.get('completed') or not snap.get('services_restored'):
        raise ValueError('Completed fresh logical backup and recovered source required')
    for filename, record in snap['files'].items():
        if source.sha(SNAPSHOT / filename) != record['sha256']:
            raise ValueError('Logical snapshot file changed')
    entry = source.old.inspect()
    inventory = protected()
    all_containers = [view(c['id']) for c in inventory['containers']]
    nodes = [c for c in all_containers if c['status'] == 'running']
    if any(c['status'] != 'running' and c['restart']['Name'] not in ('no', 'on-failure') for c in all_containers):
        raise ValueError('A stopped container might restart with Docker; review its policy first')
    if {n['name'] for n in nodes} != NAMES or any(n['stop_signal'] != 'SIGRTMIN+3' for n in nodes):
        raise ValueError('Running set differs from six admitted systemd KIND nodes')
    for n in nodes:
        if n['labels'].get('io.x-k8s.kind.cluster') not in ('kind', 'sunmoon-kind-136'):
            raise ValueError('Node ownership differs')
        if docker('exec', n['id'], 'systemctl', 'is-enabled', 'kubelet').strip() != 'enabled':
            raise ValueError('Kubelet must be enabled to recover on node boot')
    client = source.api(CREDENTIALS)
    config, _ = client.get('/configurations')
    readonly = config['read_only']['value']
    if type(readonly) is not bool:
        raise ValueError('Invalid original readonly value')
    STATE.mkdir(mode=0o700, parents=True)
    state = {'schema': 1, 'started_at': now(), 'phase': 'recorded', 'ready_for_windows_shutdown': False,
             'nodes': nodes, 'all_container_config_before': all_containers,
             'protected_before': inventory, 'disk_before': disk(),
             'snapshot': str(SNAPSHOT), 'entry_before': entry, 'original_read_only': readonly,
             'monitor_active': run(['systemctl', 'is-active', 'sunmoon-space-monitor.timer']).strip(),
             'events': []}
    save(state)
    quiesce(state, snap, client)


def quiesce(state, snap, client=None, resume=False):
    nodes = state['nodes']
    try:
        if not resume:
            state['phase'] = 'freezing'; save(state)
            source.set_readonly(client, True)
            workers, _ = client.get('/jobservice/pools/all/workers')
            queues, _ = client.get('/jobservice/queues')
            if any(w.get('job_id') for w in workers) or any(q.get('count', 0) for q in queues):
                raise ValueError('Harbor jobs remain active; no forced cancellation')
        run(['systemctl', 'stop', 'sunmoon-space-monitor.timer', 'sunmoon-space-monitor.service'])
        running = [n for n in nodes if view(n['id'])['status'] == 'running']
        for n in running:
            guard(state)
            state['events'].append({'intent': 'restart-no-and-stop-kubelet', 'node': n['id'], 'at': now()}); save(state)
            docker('update', '--restart=no', n['id'])
            docker('exec', n['id'], 'systemctl', 'stop', 'kubelet')
        # Re-read after kubelets stop; there can be no kubelet-driven replacement.
        containers = [c for n in running for c in cri(n)]
        state.setdefault('containers_to_stop', containers); state['phase'] = 'stopping-workloads'; save(state)
        for c in sorted(containers, key=lambda c: (rank(c), c['node'], c['id'])):
            state['events'].append({'intent': 'stop-cri', **c, 'at': now()}); save(state)
            before = json.loads(docker('exec', c['node'], 'crictl', 'inspect', c['id']))['status']
            probe = disposable_probe(c, before)
            docker('exec', c['node'], 'crictl', '--timeout=150s', 'stop', '--timeout', '10' if probe else '120', c['id'], timeout=170)
            info = json.loads(docker('exec', c['node'], 'crictl', 'inspect', c['id']))['status']
            if info['state'] != 'CONTAINER_EXITED' or (info.get('exitCode') == 137 and not reviewed_timeout(c, info)):
                raise ValueError('Workload did not stop normally: ' + c['pod'])
            state['events'].append({'stopped_cri': c['id'], 'exit_code': info.get('exitCode'), 'at': now()}); save(state)
        if any(cri(n) for n in running):
            raise ValueError('CRI workloads remain running')
        state['phase'] = 'stopping-nodes'; save(state)
        for n in sorted(running, key=lambda n: n['name'].endswith('control-plane')):
            guard(state)
            state['events'].append({'intent': 'stop-node', 'node': n['id'], 'at': now()}); save(state)
            # No Docker SIGKILL timeout fallback. A host-side deadline fails closed.
            docker('stop', '--time', '-1', n['id'], timeout=180)
            node_shutdown(state, n)
        for n in nodes:
            node_shutdown(state, n)
        guard(state)
        state['registry_after_stop'] = source.content(snap, source.read_manifest(source.ARCHIVE / 'backup.json')['registry']['files'])
        state['protected_after'] = protected()
        if any(c['state'] == 'running' for c in state['protected_after']['containers']):
            raise ValueError('A Docker container is still running')
        state['phase'] = 'stopping-docker'; save(state)
        run(['systemctl', 'stop', 'docker.service', 'docker.socket', 'containerd.service'])
        run(['sync'])
        state['trim_output'] = run(['fstrim', '-v', '/'], timeout=600).strip()
        run(['sync'])
        state.update(phase='ready-for-windows', ready_for_windows_shutdown=True,
                     prepared_at=now(), disk_after=disk())
        save(state)
        print(json.dumps({'ready_for_windows_shutdown': True, 'journal': str(STATE / 'state.json'),
              'nodes_stopped': len(nodes), 'registry': state['registry_after_stop'],
              'trim': state['trim_output']}, indent=2), flush=True)
    except BaseException as exc:
        state.update(interrupted_phase=state['phase'], phase='interrupted-needs-review', error_type=type(exc).__name__)
        save(state)
        raise


def resume_prepare():
    state = source.read_manifest(STATE / 'state.json')
    if (state['phase'] != 'interrupted-needs-review' or state['ready_for_windows_shutdown']
            or {n['name'] for n in state['nodes']} != NAMES
            or len([e for e in state['events'] if e.get('intent') == 'restart-no-and-stop-kubelet']) < 6):
        raise ValueError('Journal is not an interrupted post-freeze maintenance')
    check_storage()
    guard(state)
    # Review every recorded stop, including the intent interrupted before receipt.
    by_id = {n['id']: n for n in state['nodes']}
    for c in state.get('containers_to_stop', []):
        if view(c['node'])['status'] != 'running':
            continue
        info = json.loads(docker('exec', by_id[c['node']]['id'], 'crictl', 'inspect', c['id']))['status']
        if info['state'] == 'CONTAINER_EXITED' and info.get('exitCode') == 137:
            if not reviewed_timeout(c, info):
                raise ValueError('Unreviewed workload was killed; restore/review required')
            state['events'].append({'reviewed_timeout': c['id'], 'pod': c['pod'], 'exit_code': 137, 'at': now()})
    save(state)
    quiesce(state, source.read_manifest(SNAPSHOT / 'state.json'), resume=True)


def restore():
    state = source.read_manifest(STATE / 'state.json')
    # The owner first mounts the existing data disk with the fixed Windows helper.
    run(['systemctl', 'start', 'docker.service'])
    check_storage()
    guard(state)
    state['ready_for_windows_shutdown'] = False; state['phase'] = 'restoring'; save(state)
    for n in sorted(state['nodes'], key=lambda n: not n['name'].endswith('control-plane')):
        current = view(n['id'])
        if current['status'] != 'running':
            docker('start', n['id'])
        # Supports interrupted preparation before the node was stopped.
        deadline = time.monotonic() + 120
        while True:
            try:
                docker('exec', n['id'], 'systemctl', 'start', 'kubelet', timeout=30)
                break
            except Exception:
                if time.monotonic() > deadline:
                    raise ValueError('Node systemd/kubelet did not start: ' + n['name'])
                time.sleep(3)
    deadline = time.monotonic() + 600
    while True:
        try:
            entry = source.old.inspect()
            source.old.kub_raw('wait', '--for=condition=Ready', 'nodes', '--all', '--timeout=30s', timeout=40)
            break
        except Exception:
            if time.monotonic() > deadline:
                raise ValueError('Old cluster/Harbor recovery incomplete; retain readonly')
            time.sleep(5)
    c = source.api(CREDENTIALS)
    before = source.read_manifest(SNAPSHOT / 'catalog-before.json')
    if not source.equal_catalog(before, c.collect()):
        raise ValueError('Recovered Harbor catalog differs; retain readonly')
    for n in state['nodes']:
        if n['restart']['Name'] != 'on-failure' or n['restart']['MaximumRetryCount'] != 1:
            raise ValueError('Unexpected original restart policy; manual review required')
        docker('update', '--restart=on-failure:1', n['id'])
    source.set_readonly(c, state['original_read_only'])
    if state['monitor_active'] == 'active':
        run(['systemctl', 'start', 'sunmoon-space-monitor.timer', 'sunmoon-space-monitor.service'])
    guard(state)
    state.update(phase='services-restored', restored_at=now(), entry_after=entry,
                 disk_restored=disk(), services_restored=True)
    save(state)
    print(json.dumps({'services_restored': True, 'cluster_uid': entry['old_cluster_uid'],
          'harbor_catalog_equal': True, 'journal': str(STATE / 'state.json')}, indent=2))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('prepare', 'resume-prepare', 'restore', 'status'))
    p.add_argument('--apply', action='store_true')
    a = p.parse_args()
    if not a.apply:
        print(json.dumps({'dry_run': True, 'action': a.action, 'nodes': sorted(NAMES),
              'journal': str(STATE), 'deletes': False, 'windows_shutdown': False})); return
    if os.geteuid() != 0:
        raise ValueError('Root required')
    os.umask(0o077)
    if a.action == 'prepare':
        prepare()
    elif a.action == 'resume-prepare':
        resume_prepare()
    elif a.action == 'restore':
        restore()
    else:
        state = source.read_manifest(STATE / 'state.json')
        print(json.dumps({k: state.get(k) for k in ('phase', 'ready_for_windows_shutdown', 'prepared_at', 'services_restored')}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Maintenance stopped: ' + (str(error) if isinstance(error, ValueError) else type(error).__name__)
                         + '; inspect ' + str(STATE / 'state.json')) from None
