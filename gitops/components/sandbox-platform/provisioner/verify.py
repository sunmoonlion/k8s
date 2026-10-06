#!/usr/bin/env python3
"""Verify sandbox provisioner healthz inside the cluster without printing tokens."""
import argparse
import json
import subprocess
import sys


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ['kubectl', 'kubeconfig', 'namespace']:
        parser.add_argument('--' + key, required=True)
    args = parser.parse_args()
    require(args.namespace.startswith('sandbox-'), 'Unexpected sandbox namespace')
    probe = "curl --silent --show-error --fail --max-time 10 http://127.0.0.1:8080/healthz"
    result = subprocess.run(
        [args.kubectl, '--kubeconfig', args.kubeconfig, '--request-timeout=30s',
         '-n', args.namespace, 'exec', 'deployment/sandbox-provisioner', '--', 'sh', '-ec', probe],
        check=False, capture_output=True, text=True)
    require(result.returncode == 0, result.stderr.strip() or 'provisioner healthz exec failed')
    body = json.loads(result.stdout)
    require(body.get('ok') is True and body.get('image_configured') is True, 'Provisioner healthz payload is incomplete')
    print(json.dumps({'passed': True, 'namespace': args.namespace, 'healthz': True,
        'scope': 'In-cluster /healthz; per-user sandbox create/update/delete and restricted PSS of dynamic pods require a rebuilt image'}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'passed': False, 'reason': str(error)}))
        raise SystemExit(1)
