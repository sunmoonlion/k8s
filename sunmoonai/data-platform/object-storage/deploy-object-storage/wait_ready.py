#!/usr/bin/env python3
"""Wait for the ObjectStore's own StatefulSets and Pods; never infer from Helm alone."""
import argparse
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / 'sunmoonai/registry-platform'))
from pull_secret import Target, SecretError, dns_name  # noqa: E402


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--namespace', required=True)
    p.add_argument('--name', required=True)
    p.add_argument('--timeout', type=int, default=300)
    a = p.parse_args()
    dns_name(a.namespace); dns_name(a.name, subdomain=True)
    if not 1 <= a.timeout <= 600:
        raise SecretError('Readiness timeout must be 1..600 seconds')
    target = Target()
    deadline = time.monotonic() + a.timeout
    while time.monotonic() < deadline:
        target.check()
        store = json.loads(target.command('get', 'objectstore', a.name, '-n', a.namespace, '-o', 'json'))
        if store['metadata'].get('deletionTimestamp'):
            raise SecretError('ObjectStore is being deleted')
        pools = store.get('status', {}).get('pools') or []
        expected_pools = store.get('spec', {}).get('pools') or []
        ready = bool(pools) and len(pools) == len(expected_pools)
        expected_pods = 0
        names = set()
        configured_pods = sum(x.get("servers", 0) for x in expected_pools)
        owners = set()
        for pool in pools:
            name = pool.get('ssName')
            if not name:
                ready = False
                continue
            dns_name(name, subdomain=True)
            if name in names:
                raise SecretError("Duplicate pool StatefulSet in ObjectStore status")
            names.add(name)
            raw = target.command('get', 'statefulset', name, '-n', a.namespace, '-o', 'json', '--ignore-not-found')
            if not raw.strip():
                ready = False
                continue
            sts = json.loads(raw)
            meta, spec, status = sts['metadata'], sts['spec'], sts.get('status', {})
            if not any(o.get('uid') == store['metadata']['uid'] for o in meta.get('ownerReferences', [])):
                raise SecretError('Pool StatefulSet belongs to a different ObjectStore')
            replicas = spec.get('replicas', 1)
            ready = ready and (not meta.get('deletionTimestamp') and replicas > 0
                and status.get('observedGeneration', 0) >= meta['generation']
                and status.get('readyReplicas', 0) == replicas
                and bool(status.get('currentRevision'))
                and status.get('currentRevision') == status.get('updateRevision'))
            expected_pods += replicas
            owners.add(meta['uid'])
        pods = json.loads(target.command('get', 'pods', '-n', a.namespace, '-o', 'json'))['items']
        own = [x for x in pods if any(o.get('uid') in owners for o in x['metadata'].get('ownerReferences', []))]
        ready = ready and expected_pods == configured_pods and len(own) == expected_pods and all(
            not x['metadata'].get('deletionTimestamp') and any(
                c.get('type') == 'Ready' and c.get('status') == 'True'
                for c in x.get('status', {}).get('conditions', [])) for x in own)
        if ready:
            print(f'ObjectStore StatefulSets and Pods ready: {a.namespace}/{a.name}; S3 authentication separately required')
            return
        time.sleep(min(3, max(0, deadline - time.monotonic())))
    raise SecretError('ObjectStore readiness timed out; resources retained')


if __name__ == '__main__':
    try:
        main()
    except SecretError as e:
        raise SystemExit(str(e)) from None
    except (OSError, ValueError, KeyError, TypeError):
        raise SystemExit('ObjectStore readiness failed; raw API data withheld') from None
