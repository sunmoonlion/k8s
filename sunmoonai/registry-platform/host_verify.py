#!/usr/bin/env python3
"""Bounded local read-only acceptance, then stop and retain the new Harbor.

Checks pinned live TLS leaf, preserved catalog and every manifest plus one layer.
No push, write-enable, entry switch or cluster operation. Cloud 未经实机验证.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import socket
import ssl
import sys
import time
import urllib.request as http

from host_prepare import load, write
from host_runtime import Instance
from runtime_inspect import read
from recovery_verify import verify_registry

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'cicd-platform/materials'))
from harbor_inventory import Catalog, NoRedirect
from harbor_cold_backup import catalog_identity


def client(instance, credentials, deadline):
    site = instance.config['runtime']
    if (site['platform'], site['bind_address'], site['https_port']) != ('wsl', '127.0.0.1', 18443):
        raise ValueError('This local acceptance adapter requires loopback18443; no implicit cloud target')
    addresses = {row[4][0] for row in socket.getaddrinfo('harbor.sunmoonai.com', 18443, type=socket.SOCK_STREAM)}
    if not addresses or not addresses <= {'127.0.0.1', '::1'}:
        raise ValueError('Canonical local hostname must resolve only to loopback')
    context = ssl.create_default_context(cafile=str(instance.root / 'ca-download/ca.crt'))
    expected = ssl.PEM_cert_to_DER_cert(read(instance.root / 'tls/server.crt').decode())
    with socket.create_connection(('127.0.0.1', 18443), timeout=10) as plain:
        with context.wrap_socket(plain, server_hostname='harbor.sunmoonai.com') as tls:
            if hashlib.sha256(tls.getpeercert(binary_form=True)).digest() != hashlib.sha256(expected).digest():
                raise ValueError('Live Harbor TLS leaf differs from the prepared five-year certificate')
    if credentials.stat().st_mode & 0o077:
        raise ValueError('Existing Docker credential file must be private')
    config = json.loads(read(credentials))
    auth = config.get('auths', {}).get('harbor.sunmoonai.com:30443', {}).get('auth')
    if not auth:
        raise ValueError('Existing owner Docker credential required; no authentication changes made')
    c = Catalog.__new__(Catalog)
    c.auth = auth; c.base = 'https://harbor.sunmoonai.com:18443/api/v2.0'
    c.client = http.build_opener(http.ProxyHandler({}), NoRedirect(), http.HTTPSHandler(context=context))
    c.calls = 0; c.deadline = deadline
    return c


def artifact_records(catalog, canonical_references=False):
    result = {}
    for project in catalog['projects']:
        for repository in project['repositories']:
            for original in repository['artifacts']:
                key = (repository['name'], original['digest'])
                if key in result:
                    raise ValueError('Duplicate artifact in catalog comparison')
                item = dict(original)
                # Only the API's relationship collection is order independent.
                # Every reference field and its multiplicity stay in the comparison;
                # nested arrays and raw OCI manifest/layer bytes are never normalized.
                if canonical_references and isinstance(item.get('references'), list):
                    item['references'] = sorted(item['references'], key=lambda v: json.dumps(v, sort_keys=True))
                result[key] = json.dumps(item, sort_keys=True)
    return result


def verify(instance, credentials):
    end = time.monotonic() + 900
    try:
        instance.start()
        ready = time.monotonic() + 180
        while True:
            try:
                c = client(instance, credentials, end)
                configuration, _ = c.get('/configurations')
                if configuration['read_only']['value'] is not True:
                    raise ValueError('New Harbor is not read-only')
                break
            except Exception:
                if time.monotonic() >= min(ready, end):
                    raise ValueError('New Harbor TLS/API readiness deadline; private diagnostics withheld') from None
                time.sleep(3)
        print('Live five-year TLS and read-only API verified; comparing complete catalog', flush=True)
        catalog = c.collect()
        backup = Path(instance.config['registry_archive']).parents[1]
        baseline = json.loads(read(backup / 'catalog-before.json'))
        write(instance.root / ('catalog-observed-' + str(time.time_ns()) + '.json'), (json.dumps(catalog) + '\n').encode())
        if catalog_identity(catalog) != catalog_identity(baseline) or artifact_records(catalog, True) != artifact_records(baseline, True):
            before, after = artifact_records(baseline), artifact_records(catalog)
            fields = {}; ordering_only = 0
            for key in before.keys() & after.keys():
                a, b = json.loads(before[key]), json.loads(after[key])
                for field in a:
                    if a[field] != b.get(field):
                        fields[field] = fields.get(field, 0) + 1
                        if isinstance(a[field], list) and isinstance(b.get(field), list) and sorted(json.dumps(v, sort_keys=True) for v in a[field]) == sorted(json.dumps(v, sort_keys=True) for v in b[field]):
                            ordering_only += 1
            summary = {'catalog_identity_same': catalog_identity(catalog) == catalog_identity(baseline),
                       'added_artifacts': len(after.keys() - before.keys()), 'missing_artifacts': len(before.keys() - after.keys()),
                       'differing_fields': fields, 'list_order_only_differences': ordering_only}
            write(instance.root / ('catalog-difference-' + str(time.time_ns()) + '.json'), (json.dumps(summary) + '\n').encode())
            print(json.dumps(summary), flush=True)
            raise ValueError('Full restored catalog differs from the frozen source')
        print('Catalog identical; verifying authenticated manifest bytes and a streamed layer', flush=True)
        http_result = verify_registry(c, catalog, end)
        result = {'completed': True, 'catalog': catalog['summary'], 'registry_http': http_result,
                  'five_year_leaf_live_verified': True, 'read_only': True, 'entry_switched': False,
                  'push_or_jobservice_verified': False, 'references_compared_as_complete_relationship_multisets': True}
        instance.state['read_only_acceptance'] = result; instance.persist()
    finally:
        instance.stop()
    return {**result, 'new_instance_stopped': True}


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True); p.add_argument('--docker-credentials', type=Path)
    p.add_argument('--apply', action='store_true'); args = p.parse_args()
    config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'deployment': config['runtime']['deployment'],
                          'start_and_stop_new_instance_only': True, 'deadline_minutes': 15, 'entry_switch': False})); return
    if not args.docker_credentials:
        raise ValueError('Explicit existing owner Docker credential file required')
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(verify(Instance(config), args.docker_credentials), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Host acceptance stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
